// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {ILSGModule, ILSGRewardProgram} from "./interfaces/ILSGModule.sol";
import {IStrategyAdapter} from "./interfaces/IStrategyAdapter.sol";
import {IVUXBurnable} from "./interfaces/IVUXBurnable.sol";

/// @title StrategicTreasury — first-class risk capital custody and the arithmetic
///        classification engine.
/// @notice Receives and accounts the Strategic residual leg and protocol-owned
///         risk capital, and never enters `B` (prd.md:L741). This is the
///         protocol's **only** privileged surface; the monetary core (`VUX`,
///         `HardReserve`, `Rig`) holds no role, no owner, and no admin, and
///         nothing here can reach it.
///
///         **Classification is arithmetic, not declaration** (sdd.md:L287).
///         There is no `declareProfit`, no operator declaration, no oracle, and
///         no mark or NAV storage cell anywhere in this contract. Every revenue
///         credit is the output of a mechanical guard applied to an amount the
///         treasury **measured on its own balances** — never an amount an
///         adapter reported (INV-30 is structural: `T_nav` is an off-chain
///         indexer analytic, never backing).
///
/// @dev **What this contract cannot do, by construction** (INV-23/24/33, FB-15/16):
///      it holds no reference to any `HardReserve`, `Rig`, or `VUX` privileged
///      function — none exist to hold. `hardReserve` is a plain transfer
///      destination, reachable only by the WETH-only accretion leg, which is
///      one-way. The only token authority it imports is `IVUXBurnable.burn`,
///      which acts on the caller's own balance. It cannot mint, cannot redeem,
///      cannot change routing, cannot supply VEM credit, and cannot repair a
///      Strategic loss from the Reserve: a 50%, 80%, or 100% Strategic loss
///      leaves `B`, redemption, VEM, and mint authority bit-identical, because
///      no code path connects them (FB-5, prd.md:L444).
///
/// @dev **The POL sleeve** (`mintPolPosition`, `increasePol`, `decreasePol`,
///      `buyVuxForPol`, `harvestPol`, the two pool callbacks, and the
///      `polVuxPrincipal`/`polWethPrincipal` cost-basis cells) is Sprint 5. It
///      owns the canonical full-range position **directly on the pool** — no
///      v3-periphery, no position NFT, and no standing approval of any token at
///      any time (sdd.md:L139, L239). The pool identity is verified and its
///      full-range tick bounds are derived at construction, because they are
///      immutable and the verification must happen once, at the only moment
///      there is no wiring authority to misuse (sdd.md:L140).
///
///      **Fee/principal separation is realized by ordering, not by `collect`.**
///      Under the pinned v3 semantics `collect` withdraws everything credited to
///      `tokensOwed` and cannot distinguish fees from principal once both are
///      there. So `harvestPol` pokes-then-collects (fees only), and
///      `decreasePol` collects fees *before* burning liquidity and sweeps the
///      resulting principal atomically in the same call — which is what makes
///      "outside a `decreasePol` execution, `tokensOwed` is fees only" a tested
///      fact rather than an accounting assumption (sdd.md:L141-L143, L260).
///
/// @dev **Provenance — PROV-5 / `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED`** (DELTA §3
///      "general realized-revenue classification/policy surface"). Implemented
///      from the accepted architecture (prd.md FR-8/FR-9/FR-12/FR-13,
///      sdd.md:L135-L148, §1.10, §1.11) only. No treasury, vault, adapter,
///      strategy-registry, reward-distributor, or signal-governance
///      implementation was consulted as an implementation source; the pinned
///      external signal-governance repository remains prohibited source
///      (PROV-4) and was not consulted. The similarity statement is recorded in
///      `grimoires/loa/a2a/sprint-4/evidence/prov-5-similarity-review.md`, kept
///      out of this file because naming those projects in Solidity source trips
///      the repository's own prohibited-source detector.
contract StrategicTreasury is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    // -------------------------------------------------------------------------
    // Accounting modes (§1.10)
    // -------------------------------------------------------------------------

    /// @notice The measurement discipline fixed per strategy at admission.
    /// @dev A single universal "revenue only after all principal returns" rule
    ///      was rejected by the operator for long-lived Strategies: a position
    ///      that stays deployed for years while paying genuine weekly cash yield
    ///      must be able to recognise that yield without pretending its
    ///      principal returned (sdd.md:L289). Each mode is a *permission set*
    ///      over the three flow primitives — `NETTING` = `returnFor` only;
    ///      `CLAIM` = `returnFor` + `harvestYield`; `UNITIZED` = all three
    ///      (sdd.md:L297).
    enum Mode {
        NETTING,
        CLAIM,
        UNITIZED
    }

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice The single delay in the entire system (sdd.md:L791).
    /// @dev Asymmetric by design: slow to add risk, instant to remove it. A
    ///      compromised operator's drain becomes an on-chain-visible pending
    ///      admission with a response window, while removal and recall stay
    ///      unblockable (§1.12; operator-accepted 2026-08-10 as the current
    ///      architecture constant).
    uint64 public constant ADMISSION_DELAY = 24 hours;

    /// @notice The sole operator authority. Held by the operator Safe.
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // `StrategicInflow.class` — the FR-9.1 classes (prd.md:L452, sdd.md:L504).
    // Class 1 (ContributedPrincipal) has no emitter here on purpose: the 12%
    // settlement leg arrives as a plain WETH transfer with no callback, so the
    // treasury is never invoked and cannot observe it. Its attribution lives in
    // `Rig.Settled` + `Rig.totalStrategicContributed` (sdd.md:L138), and the
    // untracked receipt defaults to principal-side inventory — never revenue
    // (sdd.md:L303 rule 5). Class 0 is never a treasury inflow; class 5
    // (UnrealizedMark) is never an event at all, because a mark is not a
    // transfer and has no cell here (INV-30).
    uint8 private constant CLASS_RETURNED_PRINCIPAL = 2;
    uint8 private constant CLASS_POL_FEE_YIELD = 3;
    uint8 private constant CLASS_OTHER_REVENUE = 4;

    // `StrategicOutflow.kind`. The accepted schema fixes the field, not the
    // enumeration; these are the four outflows this sprint can produce.
    uint8 private constant OUT_STRATEGY_DEPLOYMENT = 1;
    uint8 private constant OUT_HARD_ACCRETION = 2;
    uint8 private constant OUT_OPERATING_EXPENSE = 3;
    uint8 private constant OUT_SIGNALER_PROGRAM = 4;

    // The canonical Uniswap-v3 tick domain. Read as *facts of the verified
    // pool's tick space*, which the full-range bounds must be aligned inside —
    // not as reused implementation. The vendored `TickMath` that declares the
    // same two values compiles in the other (=0.7.6) unit and relies on
    // wrapping arithmetic that is deliberately never ported to 0.8.x
    // (foundry.toml).
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = 887272;

    // The endpoints of the same tick domain expressed as sqrt prices, read the
    // same way and for the same reason: they are *facts of the price space the
    // verified pool operates in* — `slot0.sqrtPriceX96` always lies within
    // `[MIN_SQRT_RATIO, MAX_SQRT_RATIO)` — used here only as the conservative
    // outer bounds of the full-range position (`_affordableLiquidity`). Not
    // reused implementation: no v3 library is imported, and none could be, since
    // the vendored `TickMath` that also declares these compiles in the other
    // (=0.7.6) unit on wrapping arithmetic that is never ported to 0.8.x.
    uint160 private constant MIN_SQRT_RATIO = 4295128739;
    uint160 private constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
    uint256 private constant Q96 = 1 << 96;

    // Operation-context types (§1.6, sdd.md:L255). `CTX_NONE` is *both* the
    // never-armed and the already-consumed state, which is why one check rejects
    // out-of-operation, wrong-type, and duplicate callbacks alike.
    uint8 private constant CTX_NONE = 0;
    uint8 private constant CTX_MINT = 1;
    uint8 private constant CTX_SWAP = 2;

    // -------------------------------------------------------------------------
    // Immutable identities (sdd.md:L140 — "Constructor immutables (complete)")
    // -------------------------------------------------------------------------

    /// @notice Canonical RH WETH.
    IERC20 public immutable weth;
    /// @notice The VUX token. The only authority imported is the self-burn.
    IERC20 public immutable vux;
    /// @notice The Hard Reserve — a transfer destination for the WETH-only
    ///         accretion leg, and nothing else. No function of it is called.
    address public immutable hardReserve;
    /// @notice `VuxPoolDeployer` — the canonical pool's exclusive CREATE2 namespace.
    address public immutable poolDeployer;
    /// @notice The canonical VUX/WETH pool.
    address public immutable pool;
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable feeTier;
    /// @notice Full-range bounds, aligned to the verified pool's `tickSpacing()`.
    int24 public immutable tickLower;
    int24 public immutable tickUpper;

    // -------------------------------------------------------------------------
    // Storage — the complete accounting-cell set (sdd.md:L140)
    // -------------------------------------------------------------------------

    struct Admission {
        /// @dev Deployment is permitted only while true. Cleared instantly by
        ///      `removeStrategy` and by nothing else.
        bool active;
        /// @dev Immutable while admitted; changing it requires remove + re-admit,
        ///      which re-runs the maturity delay (sdd.md:L147).
        Mode mode;
        /// @dev `UNITIZED` only: the single asset the unit ledger is denominated
        ///      in, fixed at first admission.
        address unitAsset;
    }

    struct AssetLimit {
        /// @dev Ceiling on `outstandingPrincipal[strategy][asset]`.
        uint256 cap;
        /// @dev `0` means this asset was never admitted for this strategy — the
        ///      cell doubles as the membership flag, so no separate bit exists to
        ///      fall out of step with it. Survives removal, so a removed strategy
        ///      can still return principal.
        uint64 maturesAt;
    }

    mapping(address strategy => Admission) private _admissions;
    mapping(address strategy => mapping(address asset => AssetLimit)) private _limits;
    /// @dev Admitted assets in admission order. Exists solely so the accepted
    ///      `closeStrategy(address)` signature — which takes no asset — can reach
    ///      every residual cell. Bounded by operator admissions.
    mapping(address strategy => address[]) private _strategyAssets;

    /// @notice Deployed-asset cost basis per (strategy, asset).
    mapping(address strategy => mapping(address asset => uint256)) public outstandingPrincipal;
    /// @notice `UNITIZED` position size, recorded by measured `principalUnits()` delta.
    mapping(address strategy => uint256) public unitsHeld;
    /// @notice Realized revenue credit per asset — the only thing `allocateRevenue`
    ///         can spend, and the arithmetic reason principal and marks are
    ///         non-distributable (FR-12, prd.md:L505-L506).
    mapping(address asset => uint256) public realizedRevenue;
    /// @notice The sole revenue earmark (sdd.md:L140; the former
    ///         `marketInfraBudget` is deleted, 2026-08-12 remediation, F-2).
    mapping(address asset => uint256) public signalerBudget;

    /// @notice Cost basis of the VUX held **inside the canonical POL position**.
    /// @dev These two cells are the position's basis, not the POL sleeve's whole
    ///      inventory: they rise by exactly what a mint/increase paid the pool
    ///      and fall by what a decrease got back (sdd.md:L143). Two consequences
    ///      are deliberate rather than incidental:
    ///
    ///      * **Quantization dust is not in them.** A liquidity unit is an
    ///        integer, so a mint consumes slightly less than the committed
    ///        amounts; the remainder never entered the position and stays bare
    ///        treasury inventory — principal-side by §1.10 rule 5, never revenue
    ///        (sdd.md:L168).
    ///      * **`buyVuxForPol` does not touch them.** Purchased VUX is POL
    ///        inventory awaiting deployment, not position basis; it enters
    ///        `polVuxPrincipal` when `increasePol` actually pays it to the pool.
    ///        Booking it at purchase *and* at deployment would double-count it,
    ///        and the accepted cell set is exactly the one listed at sdd.md:L140
    ///        — there is no third cell to hold an undeployed-inventory basis.
    ///        Its classification is carried by `VuxPurchasedForPol` plus the
    ///        arithmetic fact that no purchase path credits `realizedRevenue`.
    ///
    ///      Impermanent loss/gain shows up here as an asymmetry between basis and
    ///      what came back — and is never revenue in either direction (INV-28,
    ///      FR-11.3): a token that returns more than its basis leaves the excess
    ///      as principal-side inventory, and one that returns less simply
    ///      retires the basis it can.
    uint256 public polVuxPrincipal;
    /// @notice Cost basis of the WETH held inside the canonical POL position.
    uint256 public polWethPrincipal;

    /// @dev The single-use authorization a pool callback consumes (§1.6,
    ///      sdd.md:L255). Ordinary storage rather than transient storage on
    ///      purpose: transient storage would make this contract require a
    ///      Cancun-or-later chain, and `evm_version` is deliberately left unset
    ///      as an R-14 deployment-time fact (foundry.toml). Nothing is lost —
    ///      the context is armed and consumed inside one call, and the outer
    ///      operation reverts if it survives, so it can never persist across
    ///      transactions.
    struct OpContext {
        uint8 ctxType;
        uint256 maxVuxIn;
        uint256 maxWethIn;
    }

    OpContext private _ctx;

    /// @notice Recipient of actual approved operating expenses. Disclosed by event.
    address public opsRecipient;

    /// @notice The activated LSG module, or `address(0)` = inactive.
    /// @dev Launch value is `address(0)`: LSG ships inactive with an explicit
    ///      operator-controlled activation authority present (FR-13 acceptance,
    ///      prd.md:L522). No numeric threshold and no calendar date appears in
    ///      this contract (F-50) — readiness judgment stays off-chain and
    ///      operator-internal.
    address public lsgModule;

    /// @notice Monotonic id for signal consumptions (UC-9 observability).
    uint64 public allocationCount;

    // -------------------------------------------------------------------------
    // Errors (sdd.md §6.1)
    // -------------------------------------------------------------------------

    error ZeroAddress();
    error PoolFactoryMismatch(address expected, address actual);
    error PoolOwnerNotDead(address owner);
    error PoolTokensMismatch(address token0, address token1);
    error PoolFeeMismatch(uint24 expected, uint24 actual);
    error PoolTickSpacingInvalid(int24 tickSpacing);

    error StrategyNotAdmitted(address strategy);
    error CapExceeded(address strategy, address asset, uint256 requested, uint256 cap);
    error AdmissionNotMatured(address strategy, uint64 maturesAt);
    error ModeImmutable(address strategy, uint8 mode);
    error ModeForbidsFlow(address strategy, uint8 mode);
    error PrincipalUnitsDecreased(address strategy);
    error UnknownReturnAsset(address strategy, address asset);
    error UnitsExceedHeld(address strategy, uint256 units, uint256 held);
    error SlippageExceeded(uint256 amountOut, uint256 minOut);
    error StillAdmitted(address strategy);

    error RevenueExceedsRealized(address asset, uint256 requested, uint256 available);
    error HardLegMustBeWeth();
    error VuxRevenueMustBurn();

    error LSGInactive();
    error MalformedSignal();

    error PolPositionExists();
    error PolPositionMissing();
    error ZeroAmount();
    error PoolPriceOutOfRange(uint160 sqrtPriceX96);

    error CallbackUnauthorizedCaller(address caller);
    error CallbackContextMismatch(uint8 expected, uint8 active);
    error CallbackDirectionMismatch(int256 vuxDelta, int256 wethDelta);
    error CallbackAmountExceedsCommitment(address token, uint256 owed, uint256 committed);
    error CallbackDataNotEmpty(uint256 length);
    error CallbackNotConsumed();

    // -------------------------------------------------------------------------
    // Events (sdd.md §3.2 — accepted schema, reproduced exactly)
    // -------------------------------------------------------------------------

    event StrategicInflow(uint8 indexed class, address indexed asset, uint256 amount);
    event StrategicOutflow(uint8 indexed kind, address indexed target, address asset, uint256 amount);
    event StrategyAdmitted(
        address indexed strategy, address indexed asset, uint256 cap, uint8 mode, uint64 maturesAt
    );
    event StrategyRemoved(address indexed strategy, bool emergency);
    event ReturnedFromStrategy(
        address indexed strategy, address indexed asset, uint256 principalPart, uint256 revenuePart
    );
    event YieldHarvested(
        address indexed strategy, address indexed rewardAsset, uint256 amount, uint256 principalUnitsAfter
    );
    event UnitsRedeemed(
        address indexed strategy,
        uint256 units,
        uint256 amountOut,
        uint256 basisReleased,
        uint256 revenuePart,
        uint256 lossPart
    );
    event StrategyLossRealized(address indexed strategy, address indexed asset, uint256 amount);
    event RevenueAllocated(
        address indexed asset, uint256 toCompound, uint256 toHard, uint256 toOps, uint256 toSignalers
    );
    event SignalerProgramFunded(address indexed asset, uint256 amount, uint64 start, uint64 end);
    event VuxRevenueBurned(uint256 amount);
    event PolPositionChanged(int8 direction, uint256 vuxDelta, uint256 wethDelta, uint128 liquidityDelta);
    event VyrfHarvest(uint256 vuxFeesBurned, uint256 wethFeesToHard);
    event VuxPurchasedForPol(uint256 wethIn, uint256 vuxOut);
    event OpsRecipientSet(address indexed recipient);
    event LSGActivated(address indexed module);
    event LSGDeactivated(address indexed module);
    event SignalConsumed(uint64 indexed allocationId, uint256 totalDeployed, address[] strategies, uint256[] amounts);

    // -------------------------------------------------------------------------
    // Construction
    // -------------------------------------------------------------------------

    /// @notice Binds every identity permanently and grants both roles to the creator.
    ///
    /// @dev **Re-verification, not trust** (sdd.md:L140). The protocol-deployed
    ///      pool exists and is verified before this constructor runs (§1.4
    ///      genesis order); this re-verifies it anyway, against the pool itself:
    ///      its `factory()` must be `VuxPoolDeployer`, that deployer's `owner()`
    ///      must be permanently dead (so `setFeeProtocol`/`collectProtocol` are
    ///      unreachable forever), its token ordering must be the canonical sort
    ///      of `(vux, weth)`, and its fee must match. The full-range tick bounds
    ///      are then *derived* from the verified pool's own `tickSpacing()`
    ///      rather than passed in, so no argument exists that could put the
    ///      protocol's position on bounds the pool does not accept.
    ///
    ///      **No wiring authority exists at any time.** There is no `setPool`,
    ///      no initializer, no upgrade path, and no re-verification hook — the
    ///      pool cannot be replaced after construction because nothing can write
    ///      an immutable.
    ///
    ///      **Roles go to `msg.sender`** — the creator, structurally
    ///      `GenesisDeployer` (transient, in-transaction). There is deliberately
    ///      no `genesisOperator` argument, so the external genesis caller can
    ///      never receive authority and no argument exists to misconfigure
    ///      (sdd.md:L140, L724-L725). The Safe receives the roles through the
    ///      deployer's in-transaction grant + renounce (Sprint 7).
    ///
    /// @param weth_         Canonical RH WETH.
    /// @param vux_          The VUX token.
    /// @param hardReserve_  The Hard Reserve — accretion destination only.
    /// @param poolDeployer_ `VuxPoolDeployer`.
    /// @param pool_         The canonical pool it deployed.
    /// @param feeTier_      The pool's fee tier (an R-14 founder deployment fact,
    ///                      asserted here against the pool, never frozen here).
    constructor(
        address weth_,
        address vux_,
        address hardReserve_,
        address poolDeployer_,
        address pool_,
        uint24 feeTier_
    ) {
        if (
            weth_ == address(0) || vux_ == address(0) || hardReserve_ == address(0) || poolDeployer_ == address(0)
                || pool_ == address(0)
        ) revert ZeroAddress();

        address actualFactory = IUniswapV3Pool(pool_).factory();
        if (actualFactory != poolDeployer_) revert PoolFactoryMismatch(poolDeployer_, actualFactory);

        address deployerOwner = IUniswapV3Factory(poolDeployer_).owner();
        if (deployerOwner != address(0)) revert PoolOwnerNotDead(deployerOwner);

        (address t0, address t1) = vux_ < weth_ ? (vux_, weth_) : (weth_, vux_);
        address poolToken0 = IUniswapV3Pool(pool_).token0();
        address poolToken1 = IUniswapV3Pool(pool_).token1();
        if (poolToken0 != t0 || poolToken1 != t1) revert PoolTokensMismatch(poolToken0, poolToken1);

        uint24 poolFee = IUniswapV3Pool(pool_).fee();
        if (poolFee != feeTier_) revert PoolFeeMismatch(feeTier_, poolFee);

        int24 spacing = IUniswapV3Pool(pool_).tickSpacing();
        if (spacing <= 0 || spacing >= 16384) revert PoolTickSpacingInvalid(spacing);

        weth = IERC20(weth_);
        vux = IERC20(vux_);
        hardReserve = hardReserve_;
        poolDeployer = poolDeployer_;
        pool = pool_;
        token0 = t0;
        token1 = t1;
        feeTier = feeTier_;
        // Solidity truncates integer division toward zero, so both bounds land
        // strictly inside `[MIN_TICK, MAX_TICK]` and on a multiple of `spacing`.
        tickLower = (MIN_TICK / spacing) * spacing;
        tickUpper = (MAX_TICK / spacing) * spacing;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    // -------------------------------------------------------------------------
    // Admission registry (P0 code, P1 use — sdd.md:L147)
    // -------------------------------------------------------------------------

    /// @notice Admit `strategy` for `asset` under `cap`, deployable after
    ///         `ADMISSION_DELAY`.
    ///
    /// @dev The `mode` is fixed at admission and immutable thereafter. Changing
    ///      it means `removeStrategy` then `admitStrategy`, which re-runs the
    ///      full maturity delay — there is no in-place mode change, because a
    ///      mode is a permission set over the flow primitives and swapping it
    ///      under a live position would let one discipline's measurements be
    ///      re-read under another's guard (sdd.md:L147).
    ///
    ///      Re-admitting an already-admitted (strategy, asset) — to raise or
    ///      lower a cap — restarts the delay too. Raising a cap is adding risk,
    ///      and the asymmetry the delay exists to enforce does not distinguish
    ///      between the first unit of risk and the next one.
    ///
    ///      A mode change after removal additionally requires the unit ledger to
    ///      be empty: `unitsHeld` is meaningful only under `UNITIZED`, and
    ///      carrying a stale unit balance into a mode that cannot redeem it
    ///      would strand it outside every guard.
    function admitStrategy(address strategy, address asset, uint256 cap, uint8 mode)
        external
        onlyRole(OPERATOR_ROLE)
    {
        if (strategy == address(0) || asset == address(0)) revert ZeroAddress();
        if (mode > uint8(Mode.UNITIZED)) revert ModeImmutable(strategy, mode);

        Admission storage a = _admissions[strategy];
        Mode requested = Mode(mode);

        if (a.mode != requested) {
            if (a.active) revert ModeImmutable(strategy, uint8(a.mode));
            if (unitsHeld[strategy] != 0) revert ModeImmutable(strategy, uint8(a.mode));
            a.mode = requested;
            a.unitAsset = address(0);
        }
        if (requested == Mode.UNITIZED && a.unitAsset == address(0)) a.unitAsset = asset;
        a.active = true;

        AssetLimit storage l = _limits[strategy][asset];
        if (l.maturesAt == 0) _strategyAssets[strategy].push(asset);
        uint64 maturesAt = uint64(block.timestamp) + ADMISSION_DELAY;
        l.cap = cap;
        l.maturesAt = maturesAt;

        emit StrategyAdmitted(strategy, asset, cap, mode, maturesAt);
    }

    /// @notice Remove `strategy` from the admitted set. Instant, and unblockable
    ///         by any signal, module, or delay (UC-10, prd.md:L303-L306).
    /// @param emergency Disclosure of the operator's intent, carried by the
    ///        event. Both intents take the same instant path — a removal that
    ///        behaved differently under pressure would not be an emergency
    ///        control.
    function removeStrategy(address strategy, bool emergency) external onlyRole(OPERATOR_ROLE) {
        Admission storage a = _admissions[strategy];
        if (!a.active) revert StrategyNotAdmitted(strategy);
        a.active = false;
        emit StrategyRemoved(strategy, emergency);
    }

    // -------------------------------------------------------------------------
    // Deployment and recall
    // -------------------------------------------------------------------------

    /// @notice Deploy `amount` of `asset` to an admitted, matured strategy within
    ///         its cap. Books deployed Strategic principal (§1.10 rule 1).
    function deployToStrategy(address strategy, address asset, uint256 amount)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        _deploy(strategy, asset, amount);
    }

    /// @notice Pull `amount` of `asset` back from `strategy` and classify what
    ///         actually arrived.
    /// @dev Deliberately **not** gated on admission: recall must work after
    ///      removal, which is the whole point of "slow to add risk, instant to
    ///      remove it". It is also not cap-gated — a cap bounds exposure, and
    ///      reducing exposure can never breach one.
    function recallFromStrategy(address strategy, address asset, uint256 amount)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        uint256 before = IERC20(asset).balanceOf(address(this));
        IStrategyAdapter(strategy).recall(asset, amount);
        _classifyReturn(strategy, asset, IERC20(asset).balanceOf(address(this)) - before);
    }

    // -------------------------------------------------------------------------
    // The three flow primitives (§1.10)
    // -------------------------------------------------------------------------

    /// @notice Attributed principal return — permissionless, classified in-call.
    ///
    /// @dev Principal-first netting against `outstandingPrincipal[strategy][asset]`;
    ///      only the excess beyond full principal return credits revenue
    ///      (§1.10 rule 2). Under `NETTING` that *is* the whole recognition
    ///      rule; under the other modes it is the return leg alongside their own.
    ///
    ///      Only assets with outstanding principal, or the admitted deployment
    ///      asset, are accepted — arbitrary-asset "returns" cannot mint revenue.
    ///
    ///      The credited amount is the treasury's **measured receipt**, not the
    ///      `amount` argument. That is load-bearing rather than defensive: on a
    ///      fee-on-transfer asset, crediting the argument would retire more
    ///      principal than actually arrived, and the missing principal would
    ///      reappear later as revenue that was never earned.
    function returnFor(address strategy, address asset, uint256 amount) external nonReentrant {
        if (outstandingPrincipal[strategy][asset] == 0 && _limits[strategy][asset].maturesAt == 0) {
            revert UnknownReturnAsset(strategy, asset);
        }
        uint256 before = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        _classifyReturn(strategy, asset, IERC20(asset).balanceOf(address(this)) - before);
    }

    /// @notice Realise claim-style yield — permissionless, measured, units-intact.
    ///
    /// @dev The `CLAIM` discipline (sdd.md:L294): snapshot `principalUnits()`,
    ///      harvest, measure **the treasury's own balance deltas** in the
    ///      reported reward assets, and require the position not to have shrunk.
    ///      Same-asset yield is legitimate here precisely because the units did
    ///      not shrink — a "harvest" that shrank the position is a partial exit,
    ///      not yield, and reverts.
    ///
    ///      Permissionless because operational conveniences "may be assisted but
    ///      their absence must not corrupt classification" (prd.md:L690,
    ///      NFR-REL-2): a keeper is useful, never necessary, and an unharvested
    ///      reward is simply counted nowhere (FB-8).
    ///
    ///      Not gated on `active`: harvesting recovers value, and removal must
    ///      never trap it. It is gated on the mode, which a never-admitted
    ///      address fails by default (`NETTING`).
    ///
    ///      A duplicated reward asset is credited exactly once. Both occurrences
    ///      would otherwise measure the same delta and book it twice, which is
    ///      the one adapter lie that costs the adapter nothing to tell.
    function harvestYield(address strategy) external nonReentrant {
        Mode mode = _admissions[strategy].mode;
        if (mode == Mode.NETTING) revert ModeForbidsFlow(strategy, uint8(mode));

        address[] memory assets = IStrategyAdapter(strategy).rewardAssets();
        uint256 n = assets.length;
        uint256[] memory before = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            before[i] = IERC20(assets[i]).balanceOf(address(this));
        }

        uint256 unitsBefore = IStrategyAdapter(strategy).principalUnits();
        IStrategyAdapter(strategy).harvest();
        uint256 unitsAfter = IStrategyAdapter(strategy).principalUnits();
        if (unitsAfter < unitsBefore) revert PrincipalUnitsDecreased(strategy);

        for (uint256 i = 0; i < n; i++) {
            bool duplicate = false;
            for (uint256 j = 0; j < i; j++) {
                if (assets[j] == assets[i]) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) continue;

            uint256 gained = IERC20(assets[i]).balanceOf(address(this)) - before[i];
            if (gained == 0) continue;
            realizedRevenue[assets[i]] += gained;
            emit StrategicInflow(CLASS_OTHER_REVENUE, assets[i], gained);
            emit YieldHarvested(strategy, assets[i], gained, unitsAfter);
        }
    }

    /// @notice Redeem `units` of a `UNITIZED` position against its released cost basis.
    ///
    /// @dev `basisReleased = ceil(outstandingPrincipal × units / unitsHeld)`
    ///      (sdd.md:L295). The ceiling is the conservative direction: it releases
    ///      as much basis as possible per redemption, which minimises immediate
    ///      revenue. Excess measured proceeds over the released basis are
    ///      revenue; a shortfall is a **realized loss** — evented, never a
    ///      negative revenue credit.
    ///
    ///      Basis conservation is exact over a full unwind: the final redemption
    ///      has `units == unitsHeld`, so `ceil(basis × u / u) == basis` releases
    ///      whatever the ceilings left behind, and `Σ basisReleased` equals the
    ///      original basis to the wei.
    ///
    ///      `minOut` is applied to the treasury's **own measured receipt**, which
    ///      is why the adapter is given no `minOut` to honour or misreport.
    function redeemUnits(address strategy, uint256 units, uint256 minOut)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        Admission memory a = _admissions[strategy];
        if (a.mode != Mode.UNITIZED) revert ModeForbidsFlow(strategy, uint8(a.mode));

        uint256 held = unitsHeld[strategy];
        if (units == 0 || units > held) revert UnitsExceedHeld(strategy, units, held);

        address asset = a.unitAsset;
        uint256 basis = outstandingPrincipal[strategy][asset];
        uint256 basisReleased = Math.mulDiv(basis, units, held, Math.Rounding.Ceil);

        uint256 before = IERC20(asset).balanceOf(address(this));
        IStrategyAdapter(strategy).redeem(units);
        uint256 amountOut = IERC20(asset).balanceOf(address(this)) - before;
        if (amountOut < minOut) revert SlippageExceeded(amountOut, minOut);

        unitsHeld[strategy] = held - units;
        outstandingPrincipal[strategy][asset] = basis - basisReleased;

        uint256 revenuePart;
        uint256 lossPart;
        if (amountOut > basisReleased) {
            revenuePart = amountOut - basisReleased;
            realizedRevenue[asset] += revenuePart;
        } else {
            lossPart = basisReleased - amountOut;
        }

        emit UnitsRedeemed(strategy, units, amountOut, basisReleased, revenuePart, lossPart);
        uint256 principalPart = amountOut < basisReleased ? amountOut : basisReleased;
        if (principalPart != 0) emit StrategicInflow(CLASS_RETURNED_PRINCIPAL, asset, principalPart);
        if (revenuePart != 0) emit StrategicInflow(CLASS_OTHER_REVENUE, asset, revenuePart);
        if (lossPart != 0) emit StrategyLossRealized(strategy, asset, lossPart);
    }

    /// @notice Write off a removed strategy's residual principal as realized loss.
    ///
    /// @dev Loss-only, and that is what keeps it from being a declaration escape
    ///      hatch: a write-off can only *reduce* principal accounting, so no
    ///      sequence of closes can create a single wei of revenue (§1.10 rule 3).
    ///      `unitsHeld` is deliberately left intact — if a written-off position
    ///      ever pays out, `redeemUnits` will book the recovery against a zero
    ///      basis, i.e. entirely as revenue, which is exactly right once the
    ///      basis has already been recognised as a loss.
    function closeStrategy(address strategy) external onlyRole(OPERATOR_ROLE) {
        if (_admissions[strategy].active) revert StillAdmitted(strategy);

        address[] memory assets = _strategyAssets[strategy];
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 residual = outstandingPrincipal[strategy][assets[i]];
            if (residual == 0) continue;
            outstandingPrincipal[strategy][assets[i]] = 0;
            emit StrategyLossRealized(strategy, assets[i], residual);
        }
    }

    // -------------------------------------------------------------------------
    // The distribution surface (§1.10; four legs, 2026-08-12 remediation F-2)
    // -------------------------------------------------------------------------

    /// @notice Allocate realized revenue across the four P0 legs.
    ///
    /// @dev **Amounts are call-time arguments, never stored constants** — each
    ///      call is the disclosed policy act, evented in full (sdd.md:L308). No
    ///      ratio, percentage, or waterfall exists anywhere in this contract:
    ///      the founder-accepted `50/25/20/5/0` doctrine is future doctrine, not
    ///      a v1 constant, and is **not implemented by any P0 surface**
    ///      (FR-12.4, prd.md).
    ///
    ///      `toOps` is payment of an **actual approved operating expense** only.
    ///      It does not encode the future 25% Operator Reserve contribution,
    ///      whose credit/accumulation/sweep/allocator-exclusion mechanics are a
    ///      P1/future design obligation: no person holds a claim before an
    ///      approved expense is incurred, and no accumulator, credit ledger, or
    ///      sweep exists here to hold one.
    ///
    ///      There is no market-infrastructure leg and no `marketInfraBudget`
    ///      earmark. Market infrastructure remains a permitted Strategic use,
    ///      funded through Strategic capital deployment policy from Strategic
    ///      capital — never a dedicated realized-revenue waterfall leg
    ///      (FREEZE-Δ §5.1).
    ///
    ///      The accumulator bound `Σ ≤ realizedRevenue[asset]` is the whole
    ///      safety argument: principal and marks are arithmetically unreachable
    ///      because they were never credited here, so no configuration of this
    ///      surface can reach Reserve principal or mint (FR-12 negative
    ///      acceptance, prd.md:L505-L506). With zero realized revenue every
    ///      nonzero leg reverts (FB-9/FB-12).
    ///
    /// @param toCompound Revenue booked back to principal-side inventory. A book
    ///        transfer: the asset never leaves, it stops being distributable.
    /// @param toHard     One-way accretion to the Hard Reserve. WETH only —
    ///        `B` is raw WETH, and nothing unredeemable may strand in Reserve
    ///        custody.
    /// @param toOps      Payment of an actual approved operating expense.
    /// @param toSignalers Earmarked into `signalerBudget`, spendable only through
    ///        `fundSignalerProgram` on an active module.
    function allocateRevenue(address asset, uint256 toCompound, uint256 toHard, uint256 toOps, uint256 toSignalers)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        if (asset == address(vux)) revert VuxRevenueMustBurn();
        if (toHard != 0 && asset != address(weth)) revert HardLegMustBeWeth();

        uint256 total = toCompound + toHard + toOps + toSignalers;
        uint256 available = realizedRevenue[asset];
        if (total > available) revert RevenueExceedsRealized(asset, total, available);
        realizedRevenue[asset] = available - total;

        if (toHard != 0) {
            IERC20(asset).safeTransfer(hardReserve, toHard);
            emit StrategicOutflow(OUT_HARD_ACCRETION, hardReserve, asset, toHard);
        }
        if (toOps != 0) {
            address recipient = opsRecipient;
            if (recipient == address(0)) revert ZeroAddress();
            IERC20(asset).safeTransfer(recipient, toOps);
            emit StrategicOutflow(OUT_OPERATING_EXPENSE, recipient, asset, toOps);
        }
        if (toSignalers != 0) signalerBudget[asset] += toSignalers;

        emit RevenueAllocated(asset, toCompound, toHard, toOps, toSignalers);
    }

    /// @notice Burn the treasury's VUX-denominated realized revenue.
    /// @dev The only VUX-revenue treatment that exists (F-46, sdd.md:L318);
    ///      `allocateRevenue` rejects `asset == VUX` outright. It burns exactly
    ///      the credited revenue and zeroes the credit — never the treasury's
    ///      whole VUX balance, which would destroy POL inventory principal.
    function burnVuxRevenue() external onlyRole(OPERATOR_ROLE) nonReentrant {
        address token = address(vux);
        uint256 amount = realizedRevenue[token];
        if (amount != 0) {
            realizedRevenue[token] = 0;
            IVUXBurnable(token).burn(amount);
        }
        emit VuxRevenueBurned(amount);
    }

    /// @notice Set the recipient of approved operating-expense payments.
    function setOpsRecipient(address recipient) external onlyRole(OPERATOR_ROLE) {
        if (recipient == address(0)) revert ZeroAddress();
        opsRecipient = recipient;
        emit OpsRecipientSet(recipient);
    }

    // -------------------------------------------------------------------------
    // LSG P0 boundary (§1.11; module implementation is P1)
    // -------------------------------------------------------------------------

    /// @notice Activate an LSG module. The affirmative operator action FR-13.4
    ///         requires — there is no threshold and no date in this code.
    function activateLSG(address module) external onlyRole(OPERATOR_ROLE) {
        if (module == address(0)) revert ZeroAddress();
        lsgModule = module;
        emit LSGActivated(module);
    }

    /// @notice Sever signal consumption instantly. A module swap is deactivate
    ///         + activate; there is no in-place replacement.
    function deactivateLSG() external onlyRole(OPERATOR_ROLE) {
        address previous = lsgModule;
        if (previous == address(0)) revert LSGInactive();
        lsgModule = address(0);
        emit LSGDeactivated(previous);
    }

    /// @notice Deploy `totalWeth` of marginal Strategic capital, split by the
    ///         active module's signal.
    ///
    /// @dev The complete execution interface of §1.11 (sdd.md:L337), and the
    ///      complete extent of what a signal can do. The module supplies a
    ///      *relative split over already-admitted strategies* and nothing else:
    ///      the operator holds the trigger, the size, and the safety; the menu
    ///      is operator-admitted; caps clamp; removal and recall stay
    ///      unblockable. It cannot name a recipient outside the admitted
    ///      registry, cannot cause an admission, cannot raise a cap, and reaches
    ///      no monetary-core surface (INV-32/33; FR-13.3).
    ///
    ///      Ineligible entries (not admitted, not matured, no cap headroom, or a
    ///      `UNITIZED` target whose unit asset is not WETH) are skipped, and the
    ///      floor-rounded remainder is simply not deployed — rounding favours
    ///      *not* deploying. Repeated entries clamp against live headroom rather
    ///      than reverting the whole allocation.
    ///
    ///      The event snapshots exactly what was read, index-aligned with the
    ///      module's own answer, including the zeros (UC-9).
    function deployMarginalBySignal(uint256 totalWeth) external onlyRole(OPERATOR_ROLE) nonReentrant {
        address module = lsgModule;
        if (module == address(0)) revert LSGInactive();

        (address[] memory strategies, uint256[] memory weights) = ILSGModule(module).currentAllocationSignal();
        if (strategies.length != weights.length) revert MalformedSignal();

        address asset = address(weth);
        uint256 n = strategies.length;
        uint256[] memory amounts = new uint256[](n);

        uint256 totalWeight;
        for (uint256 i = 0; i < n; i++) {
            if (_eligibleForSignal(strategies[i], asset)) totalWeight += weights[i];
        }

        uint256 totalDeployed;
        if (totalWeight != 0) {
            for (uint256 i = 0; i < n; i++) {
                if (weights[i] == 0 || !_eligibleForSignal(strategies[i], asset)) continue;

                uint256 amount = Math.mulDiv(totalWeth, weights[i], totalWeight);
                uint256 outstanding = outstandingPrincipal[strategies[i]][asset];
                uint256 cap = _limits[strategies[i]][asset].cap;
                uint256 headroom = cap > outstanding ? cap - outstanding : 0;
                if (amount > headroom) amount = headroom;
                if (amount == 0) continue;

                _deploy(strategies[i], asset, amount);
                amounts[i] = amount;
                totalDeployed += amount;
            }
        }

        emit SignalConsumed(++allocationCount, totalDeployed, strategies, amounts);
    }

    /// @notice Fund a PROTOCOL-provenance signaler reward program from the earmark.
    /// @dev Requires an active module and spends `signalerBudget`, which only
    ///      `allocateRevenue` can fill — so signaler economics are
    ///      revenue-bounded by construction and can never reach principal
    ///      (FR-13.7). The exact amount is pushed and then registered; no
    ///      allowance, role, or standing authority is created for the module.
    function fundSignalerProgram(address asset, uint256 amount, uint64 start, uint64 end)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        address module = lsgModule;
        if (module == address(0)) revert LSGInactive();

        uint256 budget = signalerBudget[asset];
        if (amount > budget) revert RevenueExceedsRealized(asset, amount, budget);
        signalerBudget[asset] = budget - amount;

        IERC20(asset).safeTransfer(module, amount);
        ILSGRewardProgram(module).fundSignalerProgram(asset, amount, start, end);

        emit SignalerProgramFunded(asset, amount, start, end);
        emit StrategicOutflow(OUT_SIGNALER_PROGRAM, module, asset, amount);
    }

    // -------------------------------------------------------------------------
    // POL position operations (§1.4 sdd.md:L139; §1.6 sdd.md:L252-L258)
    // -------------------------------------------------------------------------

    /// @notice Create the canonical full-range POL position.
    ///
    /// @dev Genesis calls this once with the 150,000 VUX and the recorded POL
    ///      WETH already transferred in (sdd.md:L168). It is the same pool
    ///      operation as `increasePol`; the two differ only in which side of the
    ///      "does the position exist yet" question they accept, so each name
    ///      means what it says and neither can be used for the other's job by
    ///      accident.
    ///
    ///      `vuxAmt`/`wethAmt` are the **committed callback maxima** (§1.6): the
    ///      pool is paid exactly what it demands, and it can never demand more
    ///      than these. The VUX must already be here — existing or purchased
    ///      supply, never minted, because no mint path exists to call (INV-26).
    function mintPolPosition(uint256 vuxAmt, uint256 wethAmt) external onlyRole(OPERATOR_ROLE) nonReentrant {
        if (_positionLiquidity() != 0) revert PolPositionExists();
        _addLiquidity(vuxAmt, wethAmt);
    }

    /// @notice Add liquidity to the existing canonical POL position.
    /// @param vuxAmt  Maximum VUX the operation authorizes the pool to take.
    /// @param wethAmt Maximum WETH the operation authorizes the pool to take.
    function increasePol(uint256 vuxAmt, uint256 wethAmt) external onlyRole(OPERATOR_ROLE) nonReentrant {
        if (_positionLiquidity() == 0) revert PolPositionMissing();
        _addLiquidity(vuxAmt, wethAmt);
    }

    /// @notice Withdraw `liquidity` from the POL position — fees first, then
    ///         principal, atomically.
    ///
    /// @dev The ordering **is** the classification (sdd.md:L143), and it is a
    ///      security property rather than a stylistic one: `collect` withdraws
    ///      whatever is credited to `tokensOwed` and cannot tell fees from
    ///      principal once both are there. So:
    ///
    ///        1. poke + collect + classify the accrued fees as VYRF, exactly as
    ///           `harvestPol` would have — this is the only moment they can
    ///           still be told apart;
    ///        2. `burn(liquidity)` credits principal to a now-empty `tokensOwed`;
    ///        3. `collect` sweeps exactly that principal;
    ///        4. it books against the cost-basis cells, never as revenue.
    ///
    ///      No swap can interleave inside one transaction, so step 2 accrues
    ///      zero new fees and step 3's receipt is principal to the wei
    ///      (sdd.md:L260). `burn`/`collect` have no callbacks, so no context is
    ///      armed here and none can be.
    function decreasePol(uint128 liquidity) external onlyRole(OPERATOR_ROLE) nonReentrant {
        if (liquidity == 0) revert ZeroAmount();

        _pokeCollectAndClassifyFees();

        IUniswapV3Pool(pool).burn(tickLower, tickUpper, liquidity);
        (uint128 collected0, uint128 collected1) =
            IUniswapV3Pool(pool).collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);
        (uint256 vuxBack, uint256 wethBack) = _pairVuxWeth(collected0, collected1);

        uint256 vuxBasis = polVuxPrincipal;
        polVuxPrincipal = vuxBasis > vuxBack ? vuxBasis - vuxBack : 0;
        uint256 wethBasis = polWethPrincipal;
        polWethPrincipal = wethBasis > wethBack ? wethBasis - wethBack : 0;

        emit PolPositionChanged(-1, vuxBack, wethBack, liquidity);
        if (vuxBack != 0) emit StrategicInflow(CLASS_RETURNED_PRINCIPAL, address(vux), vuxBack);
        if (wethBack != 0) emit StrategicInflow(CLASS_RETURNED_PRINCIPAL, address(weth), wethBack);
    }

    /// @notice Buy VUX for POL with Strategic WETH on the canonical pool.
    ///
    /// @dev The answer to "how is protocol-owned VUX sourced for later POL
    ///      without minting" (sdd.md:L139): existing supply, bought in-protocol.
    ///      Custody never leaves this contract — there is no transfer-to-operator
    ///      step anywhere in the path — and the output is verified as **this
    ///      contract's own measured VUX balance delta**, not as a number the pool
    ///      returned (sdd.md:L258). Both bounds bind: `sqrtPriceLimitX96` inside
    ///      the swap, `minVuxOut` on the measured receipt after it.
    function buyVuxForPol(uint256 wethIn, uint256 minVuxOut, uint160 sqrtPriceLimitX96)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        if (wethIn == 0) revert ZeroAmount();

        uint256 vuxBefore = vux.balanceOf(address(this));

        _arm(CTX_SWAP, 0, wethIn);
        IUniswapV3Pool(pool).swap(address(this), token0 == address(weth), wethIn.toInt256(), sqrtPriceLimitX96, "");
        _requireConsumed();

        uint256 vuxOut = vux.balanceOf(address(this)) - vuxBefore;
        if (vuxOut < minVuxOut) revert SlippageExceeded(vuxOut, minVuxOut);

        emit VuxPurchasedForPol(wethIn, vuxOut);
    }

    /// @notice Harvest POL fee yield: VUX fees burn, WETH fees enter the Hard
    ///         Reserve. Permissionless, parameter-free, swap-free.
    ///
    /// @dev The frozen VYRF outcome (FR-11), realized in one call so that no
    ///      intermediate state exists in which collected fees are merely
    ///      *intended* for their destination. It is **deliberately
    ///      permissionless** because "operational conveniences … may be assisted
    ///      but their absence must not corrupt classification" (prd.md:L690,
    ///      NFR-REL-2): a keeper is useful, never necessary, and unharvested fees
    ///      sit inside the pool position counted nowhere until collected (FB-8).
    ///      Being parameter-free is what makes that safe — a caller chooses
    ///      *when*, never *where* or *how much*.
    ///
    ///      It touches `realizedRevenue` nowhere, which is the whole of INV-29's
    ///      "bypasses the general waterfall": `allocateRevenue` can spend only
    ///      that accumulator, so POL fee yield is arithmetically unreachable from
    ///      the distribution surface rather than merely un-routed to it.
    function harvestPol() external nonReentrant {
        if (_positionLiquidity() == 0) revert PolPositionMissing();
        _pokeCollectAndClassifyFees();
    }

    // -------------------------------------------------------------------------
    // Pool callbacks — context-authenticated, one-shot (§1.6 sdd.md:L252-L257)
    // -------------------------------------------------------------------------

    /// @notice Pay for liquidity the pool just credited to the POL position.
    ///
    /// @dev **Not `nonReentrant`, and that is the design** (sdd.md:L257): this
    ///      arrives while the outer operation still holds the guard, so taking it
    ///      here would deadlock every legitimate mint. The authentication is the
    ///      one-shot context instead — checked in the accepted order, consumed
    ///      before any payment, and required to have been consumed once the pool
    ///      call returns.
    ///
    ///      Payment is a direct `transfer`. No allowance is granted here or
    ///      anywhere else in this contract, so there is no standing approval for
    ///      a later caller to drain.
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external {
        // (1) forged caller — only the constructor-verified canonical pool.
        if (msg.sender != pool) revert CallbackUnauthorizedCaller(msg.sender);
        // (2) armed context type. A never-armed or already-consumed context reads
        //     `CTX_NONE`, so out-of-operation, wrong-type, and duplicate
        //     callbacks are all rejected right here.
        OpContext memory ctx = _ctx;
        if (ctx.ctxType != CTX_MINT) revert CallbackContextMismatch(CTX_MINT, ctx.ctxType);
        // (3) token direction, resolved against the immutable pool ordering.
        (uint256 vuxOwed, uint256 wethOwed) = _pairVuxWeth(amount0Owed, amount1Owed);
        // (4) neither side may exceed what the operation committed. This is also
        //     where a misdirected demand dies: a token the operation committed
        //     nothing to has a maximum of zero, so any amount owed on it fails.
        if (vuxOwed > ctx.maxVuxIn) revert CallbackAmountExceedsCommitment(address(vux), vuxOwed, ctx.maxVuxIn);
        if (wethOwed > ctx.maxWethIn) revert CallbackAmountExceedsCommitment(address(weth), wethOwed, ctx.maxWethIn);
        // (5) this contract passes no callback data, so any is malformed.
        if (data.length != 0) revert CallbackDataNotEmpty(data.length);

        delete _ctx; // consume BEFORE paying

        if (vuxOwed != 0) vux.safeTransfer(pool, vuxOwed);
        if (wethOwed != 0) weth.safeTransfer(pool, wethOwed);
    }

    /// @notice Pay the WETH input of a `buyVuxForPol` swap.
    /// @dev Same five checks, same consume-before-pay, same absence of approvals.
    ///      The direction check is load-bearing here in a way it is not for a
    ///      mint: exactly one delta may be positive, it must be the WETH side
    ///      (what the operation committed to spend), and the VUX side must be
    ///      strictly negative (what it is buying).
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (msg.sender != pool) revert CallbackUnauthorizedCaller(msg.sender);
        OpContext memory ctx = _ctx;
        if (ctx.ctxType != CTX_SWAP) revert CallbackContextMismatch(CTX_SWAP, ctx.ctxType);

        (int256 vuxDelta, int256 wethDelta) = token0 == address(vux)
            ? (amount0Delta, amount1Delta)
            : (amount1Delta, amount0Delta);
        if (wethDelta <= 0 || vuxDelta >= 0) revert CallbackDirectionMismatch(vuxDelta, wethDelta);

        uint256 wethOwed = uint256(wethDelta);
        if (wethOwed > ctx.maxWethIn) revert CallbackAmountExceedsCommitment(address(weth), wethOwed, ctx.maxWethIn);
        if (data.length != 0) revert CallbackDataNotEmpty(data.length);

        delete _ctx; // consume BEFORE paying

        weth.safeTransfer(pool, wethOwed);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /// @notice The admission record: active flag, accounting mode, and the
    ///         `UNITIZED` unit asset (zero for the other modes).
    function admissionOf(address strategy) external view returns (bool active, uint8 mode, address unitAsset) {
        Admission memory a = _admissions[strategy];
        return (a.active, uint8(a.mode), a.unitAsset);
    }

    /// @notice The per-(strategy, asset) cap and maturity. `maturesAt == 0` means
    ///         this asset was never admitted for this strategy.
    function limitOf(address strategy, address asset) external view returns (uint256 cap, uint64 maturesAt) {
        AssetLimit memory l = _limits[strategy][asset];
        return (l.cap, l.maturesAt);
    }

    /// @notice Assets ever admitted for `strategy`, in admission order.
    function strategyAssets(address strategy) external view returns (address[] memory) {
        return _strategyAssets[strategy];
    }

    // -------------------------------------------------------------------------
    // Internals
    // -------------------------------------------------------------------------

    /// @dev The one deployment path. `deployToStrategy` and
    ///      `deployMarginalBySignal` share it precisely so a signal-driven
    ///      deployment cannot be subject to weaker checks than a manual one
    ///      (sdd.md:L337 "deploys through the same §1.10 principal ledger").
    function _deploy(address strategy, address asset, uint256 amount) private {
        Admission memory a = _admissions[strategy];
        if (!a.active) revert StrategyNotAdmitted(strategy);
        if (a.mode == Mode.UNITIZED && asset != a.unitAsset) revert ModeForbidsFlow(strategy, uint8(a.mode));

        AssetLimit memory l = _limits[strategy][asset];
        if (l.maturesAt == 0) revert StrategyNotAdmitted(strategy);
        if (block.timestamp < l.maturesAt) revert AdmissionNotMatured(strategy, l.maturesAt);

        uint256 outstanding = outstandingPrincipal[strategy][asset] + amount;
        if (outstanding > l.cap) revert CapExceeded(strategy, asset, outstanding, l.cap);
        outstandingPrincipal[strategy][asset] = outstanding;

        IERC20(asset).safeTransfer(strategy, amount);

        if (a.mode == Mode.UNITIZED) {
            uint256 unitsBefore = IStrategyAdapter(strategy).principalUnits();
            IStrategyAdapter(strategy).deposit(asset, amount);
            unitsHeld[strategy] += IStrategyAdapter(strategy).principalUnits() - unitsBefore;
        }

        emit StrategicOutflow(OUT_STRATEGY_DEPLOYMENT, strategy, asset, amount);
    }

    /// @dev Principal-first netting over a **measured** receipt — the single
    ///      classification point for every inbound attributed flow, so
    ///      `returnFor` and `recallFromStrategy` cannot drift apart.
    function _classifyReturn(address strategy, address asset, uint256 received) private {
        uint256 outstanding = outstandingPrincipal[strategy][asset];
        uint256 principalPart = received < outstanding ? received : outstanding;
        uint256 revenuePart = received - principalPart;

        if (principalPart != 0) outstandingPrincipal[strategy][asset] = outstanding - principalPart;
        if (revenuePart != 0) realizedRevenue[asset] += revenuePart;

        emit ReturnedFromStrategy(strategy, asset, principalPart, revenuePart);
        if (principalPart != 0) emit StrategicInflow(CLASS_RETURNED_PRINCIPAL, asset, principalPart);
        if (revenuePart != 0) emit StrategicInflow(CLASS_OTHER_REVENUE, asset, revenuePart);
    }

    /// @dev The one liquidity-add path, shared so a "mint" and an "increase"
    ///      cannot drift into different rules. Books the **measured** amounts the
    ///      pool took, never the committed maxima: the difference between them is
    ///      the quantization dust, which never entered the position and must not
    ///      be booked as if it had.
    function _addLiquidity(uint256 vuxAmt, uint256 wethAmt) private {
        uint128 liquidity = _affordableLiquidity(vuxAmt, wethAmt);

        _arm(CTX_MINT, vuxAmt, wethAmt);
        (uint256 amount0, uint256 amount1) =
            IUniswapV3Pool(pool).mint(address(this), tickLower, tickUpper, liquidity, "");
        _requireConsumed();

        (uint256 vuxPaid, uint256 wethPaid) = _pairVuxWeth(amount0, amount1);
        polVuxPrincipal += vuxPaid;
        polWethPrincipal += wethPaid;

        emit PolPositionChanged(1, vuxPaid, wethPaid, liquidity);
    }

    /// @dev The largest liquidity the committed amounts can certainly afford.
    ///
    ///      v3 charges, for a position `[A, B]` at price `P`:
    ///        `amount0 = ceil(L·Q96·(sqrtB − sqrtP) / (sqrtB·sqrtP))`
    ///        `amount1 = ceil(L·(sqrtP − sqrtA) / Q96)`
    ///      Inverting needs `sqrtA`/`sqrtB`, i.e. `sqrtRatioAtTick` — which this
    ///      unit cannot have: the vendored `TickMath` compiles in the =0.7.6
    ///      unit, and porting or re-deriving it would be exactly the copied
    ///      third-party helper the provenance boundary forbids.
    ///
    ///      It does not need them. Substituting the *domain* endpoints for the
    ///      position's own bounds — `sqrtA → MIN_SQRT_RATIO`,
    ///      `sqrtB → MAX_SQRT_RATIO` — moves both estimates in the safe
    ///      direction, because `x/(x − p)` decreases in `x` and `1/(p − a)`
    ///      decreases as `a` falls. So each side is an **underestimate of the
    ///      true affordable liquidity**, hence so is their minimum, hence the
    ///      pool can never demand more than the committed maxima. (The same
    ///      conclusion holds if the price ever sat outside the full range: there
    ///      the true charge is one-sided and smaller still.)
    ///
    ///      What it costs is precision, bounded by `sqrtA/sqrtP + sqrtP/sqrtB`
    ///      — of order `1e-18` at any realistic price, i.e. dust. That dust stays
    ///      as principal-side inventory and is never revenue, which is the only
    ///      property anything downstream depends on.
    function _affordableLiquidity(uint256 vuxAmt, uint256 wethAmt) private view returns (uint128) {
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
        if (sqrtPriceX96 <= MIN_SQRT_RATIO || sqrtPriceX96 >= MAX_SQRT_RATIO) {
            revert PoolPriceOutOfRange(sqrtPriceX96);
        }

        (uint256 amount0, uint256 amount1) = _pairVuxWeth(vuxAmt, wethAmt);
        uint256 from0 =
            Math.mulDiv(amount0, Math.mulDiv(sqrtPriceX96, MAX_SQRT_RATIO, MAX_SQRT_RATIO - sqrtPriceX96), Q96);
        uint256 from1 = Math.mulDiv(amount1, Q96, sqrtPriceX96 - MIN_SQRT_RATIO);

        uint256 liquidity = from0 < from1 ? from0 : from1;
        if (liquidity == 0) revert ZeroAmount();
        return liquidity.toUint128();
    }

    /// @dev Poke the position so accrued fees land in `tokensOwed`, collect them,
    ///      and classify both legs in the same call — the complete VYRF outcome
    ///      (FR-11.1/11.2). Shared by `harvestPol` and `decreasePol` so the
    ///      classification cannot differ between them.
    ///
    ///      Neither leg is ever credited to `realizedRevenue`: VUX fee yield is
    ///      burned outright (never held, re-LP'd, redeemed, or recycled — FR-11.1)
    ///      and WETH fee yield goes one-way to the Hard Reserve (FR-11.2).
    function _pokeCollectAndClassifyFees() private {
        IUniswapV3Pool(pool).burn(tickLower, tickUpper, 0);
        (uint128 collected0, uint128 collected1) =
            IUniswapV3Pool(pool).collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);
        (uint256 vuxFees, uint256 wethFees) = _pairVuxWeth(collected0, collected1);

        if (vuxFees != 0) {
            emit StrategicInflow(CLASS_POL_FEE_YIELD, address(vux), vuxFees);
            IVUXBurnable(address(vux)).burn(vuxFees);
        }
        if (wethFees != 0) {
            emit StrategicInflow(CLASS_POL_FEE_YIELD, address(weth), wethFees);
            weth.safeTransfer(hardReserve, wethFees);
            emit StrategicOutflow(OUT_HARD_ACCRETION, hardReserve, address(weth), wethFees);
        }

        emit VyrfHarvest(vuxFees, wethFees);
    }

    /// @dev Arm the single-use callback authorization, immediately before the one
    ///      pool call that may consume it.
    function _arm(uint8 ctxType, uint256 maxVuxIn, uint256 maxWethIn) private {
        _ctx = OpContext({ctxType: ctxType, maxVuxIn: maxVuxIn, maxWethIn: maxWethIn});
    }

    /// @dev An authorization may neither survive its operation nor go unused: the
    ///      first would leave a live grant behind, the second means the pool
    ///      never called back and the operation's payment assumptions are void.
    function _requireConsumed() private view {
        if (_ctx.ctxType != CTX_NONE) revert CallbackNotConsumed();
    }

    /// @dev The POL position's key — owner + the immutable full-range bounds.
    function _positionLiquidity() private view returns (uint128 liquidity) {
        (liquidity,,,,) = IUniswapV3Pool(pool).positions(keccak256(abi.encodePacked(address(this), tickLower, tickUpper)));
    }

    /// @dev Convert between the pool's `(token0, token1)` ordering and this
    ///      contract's `(VUX, WETH)` accounting. The permutation is either the
    ///      identity or a single swap, so it is its own inverse and one helper
    ///      serves both directions. The ordering itself is a constructor-verified
    ///      immutable, which is what makes this the entirety of the callbacks'
    ///      token-direction resolution.
    function _pairVuxWeth(uint256 a, uint256 b) private view returns (uint256, uint256) {
        return token0 == address(vux) ? (a, b) : (b, a);
    }

    /// @dev Admitted + matured + cap headroom, and — for a `UNITIZED` target —
    ///      denominated in the signal's asset. Read twice per allocation (weight
    ///      sum, then split) so both passes see one definition.
    function _eligibleForSignal(address strategy, address asset) private view returns (bool) {
        Admission memory a = _admissions[strategy];
        if (!a.active) return false;
        if (a.mode == Mode.UNITIZED && asset != a.unitAsset) return false;

        AssetLimit memory l = _limits[strategy][asset];
        if (l.maturesAt == 0 || block.timestamp < l.maturesAt) return false;
        return outstandingPrincipal[strategy][asset] < l.cap;
    }
}
