// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {HardReserve} from "./HardReserve.sol";
import {Lens} from "./Lens.sol";
import {Rig} from "./Rig.sol";
import {StrategicTreasury} from "./StrategicTreasury.sol";
import {VUX} from "./VUX.sol";

/// @dev The native-wrap half of canonical WETH. Never vendored (prd.md:L725);
///      declared to the extent genesis calls it. Q-6 verified on a real
///      Robinhood Chain fork that `deposit{value:}` credits 1:1 from inside a
///      constructor and that the credit is spendable in that same constructor
///      (`test/fork/RhWethFork.t.sol`; evidence
///      `grimoires/loa/a2a/sprint-7/evidence/q6-native-wrap.md`).
interface IWethNative {
    function deposit() external payable;
}

/// @dev `VuxPoolDeployer`'s gate, declared for this (`=0.8.28`) compilation unit.
///      The contract itself compiles under `=0.7.6`, so no `=0.8.28` file can
///      import its type — bytecode has no version, and genesis calls the real
///      artifact through this declaration. `owner()` is read through the
///      vendored `IUniswapV3Factory` instead, which is the interface the pool
///      itself gates `setFeeProtocol` on.
interface IVuxPoolDeployerGate {
    function deployCanonicalPool(bytes32 salt, address token0, address token1, uint24 fee, int24 tickSpacing)
        external
        returns (address pool);
    function canonicalPool() external view returns (address);
}

/// @notice The complete genesis input set. A struct rather than a long argument
///         list because every field is an operator/founder deployment-time fact
///         (R-14) and a positional mistake among fourteen same-typed arguments
///         is exactly the failure this launch cannot afford.
/// @dev Every economic value here is **supplied**, never frozen in code: the
///      four USD targets are converted once, off-chain, pre-deployment
///      (prd.md:L321, FR-1.4) and the fee/tickSpacing pair stays an R-14 founder
///      fact — domain-checked by `VuxPoolDeployer`, never value-frozen.
struct GenesisParams {
    /// @dev Canonical RH WETH.
    address weth;
    /// @dev The inert, commitment-gated pool deployer created by tx1.
    address poolDeployer;
    /// @dev The commitment preimage's salt. A launch secret until the launch
    ///      block (sdd.md:L270).
    bytes32 salt;
    uint24 feeTier;
    int24 tickSpacing;
    /// @dev Deterministically encoded off-chain: floor `isqrt((n << 192) / d)`
    ///      over the token1-per-token0 orientation (sdd.md:L185). The pool
    ///      stores it verbatim, so the post-initialize check is exact equality.
    uint160 sqrtP0X96;
    /// @dev Exact genesis Hard backing, in WETH wei.
    uint256 b0;
    /// @dev The POL WETH leg, in WETH wei. `msg.value` must equal `wPol + b0`.
    uint256 wPol;
    uint256 bootstrapOpening;
    uint256 minimumOpening;
    uint256 decayFloor;
    /// @dev Receives both treasury roles before the constructor completes.
    address operatorSafe;
    /// @dev `P0` as the exact rational `p0Num / p0Den` — WETH wei per VUX wei.
    ///      The ratio and cushion laws are checked in exact wei arithmetic on
    ///      these recorded values, never re-derived from the Q64.96 encoding
    ///      (sdd.md:L185).
    uint256 p0Num;
    uint256 p0Den;
}

/// @title GenesisDeployer — the launch transaction.
/// @notice Genesis executes **inside this constructor**. There is no `genesis()`
///         entry point, no founder gate, and no callable launch surface at all:
///         nothing to trigger, front-run, or replay, because constructors run
///         exactly once by EVM law (sdd.md:L154-L155). Afterwards this is inert
///         bytecode — no authority, no balances, no roles, and no state-changing
///         function of any kind.
///
///         Launch is exactly two founder transactions (sdd.md:L266): **tx1**
///         deploys the inert `VuxPoolDeployer` with only a salted commitment;
///         **tx2** — this creation — carries `W_POL + B0` as native value, which
///         step 0 wraps in-transaction. No approval or transfer to a predicted
///         address is ever published.
///
/// @dev **The security theorem has two halves** (sdd.md:L156), and every check
///      below serves one of them:
///
///      1. *No step reads or writes a shared permissionless namespace.* The five
///         protocol contracts are plain `CREATE` in this account's exclusive
///         address space; the pool is `CREATE2` in `VuxPoolDeployer`'s exclusive
///         `0xff` namespace. Computing an address is not occupying it. The only
///         external contract genesis touches is canonical WETH.
///      2. *No assertion and no economic quantity depends on an
///         attacker-reachable balance.* Anyone may send WETH to any predicted
///         address before its code exists, so **every intended flow is verified
///         as a measured delta of that flow**, and the one authority-defined
///         balance — the Reserve, since `B ≡ WETH.balanceOf(reserve)` — is
///         sanitized inside its own constructor before its runtime exists.
///
///      Therefore no `require` here can be made to fail, and no economic
///      quantity altered, by any adversary, mempool observer, or block builder,
///      regardless of what they know or pre-fund. Address confidentiality
///      (sdd.md:L268) sits on top of this and is never the boundary.
///
/// @dev **Exactness is never weakened to tolerate contamination.** No check below
///      was relaxed to `>=` because prefunding is possible; contamination is
///      instead *classified* — sanitized, inventoried, or provably stuck — and
///      the closing assertions stay exact (sdd.md:L172-L184).
contract GenesisDeployer {
    using SafeERC20 for IERC20;

    /// @notice `keccak256` of the pinned `UniswapV3Pool` creation code.
    /// @dev Hard-coded rather than supplied, deliberately: refreeze §7 obligation
    ///      2 requires the wiring to use *exactly* this constant, and a supplied
    ///      one could be chosen to match whatever pool showed up.
    ///      `tools/provenance/verify-init-code-hash.sh` and
    ///      `test/provenance/PoolInitCodeHash.t.sol` keep it honest against the
    ///      compiled artifact, fail-closed.
    bytes32 public constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @dev The vendored `initialize` enforces these itself; genesis pre-asserts
    ///      them so a bad conversion record fails with a clear cause
    ///      (sdd.md:L192).
    uint160 private constant MIN_SQRT_RATIO = 4295128739;
    uint160 private constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// @dev `P0 / N0 == 11 / 10` (FR-1.4, prd.md:L321).
    uint256 private constant PREMIUM_NUM = 11;
    uint256 private constant PREMIUM_DEN = 10;

    // --- the deployed system (immutable record; no setter exists) ------------

    address public immutable weth;
    address public immutable poolDeployer;
    address public immutable reserve;
    address public immutable rig;
    address public immutable vux;
    address public immutable pool;
    address public immutable treasury;
    address public immutable lens;
    address public immutable operatorSafe;

    /// @notice Unsolicited WETH found at this address before genesis ran.
    uint256 public immutable wethPreSelf;
    /// @notice Unsolicited WETH the Reserve's constructor sanitized out to here.
    uint256 public immutable wethSanitizedFromReserve;
    /// @notice Total contamination swept to the treasury as unattributed
    ///         Strategic inventory — never founder capital, never revenue, never
    ///         mint credit.
    uint256 public immutable contaminationSwept;

    // --- errors ---------------------------------------------------------------

    error ZeroAddress();
    error FundingMismatch(uint256 sent, uint256 required);
    error WrapDeltaMismatch(uint256 measured, uint256 expected);
    error NoncePredictionOutOfDomain(uint256 nonce);
    error PredictedAddressMismatch(uint256 nonce, address predicted, address actual);
    error PoolAddressMismatch(address derived, address actual);
    error PoolFactoryMismatch(address expected, address actual);
    error PoolOwnerNotDead(address owner);
    error PoolTokensMismatch(address token0, address token1);
    error PoolFeeMismatch(uint24 expected, uint24 actual);
    error PoolTickSpacingMismatch(int24 expected, int24 actual);
    error SqrtPriceOutOfRange(uint160 sqrtPriceX96);
    error PoolPriceMismatch(uint160 expected, uint160 actual);
    error ReserveNotBornEmpty(uint256 balance);
    error ReserveFundingDeltaMismatch(uint256 measured, uint256 expected);
    error ContaminationArithmeticMismatch(uint256 residual, uint256 expected);
    error DeployerWethNotZero(uint256 balance);
    error DeployerVuxNotZero(uint256 balance);
    error GenesisSupplyMismatch(uint256 actual, uint256 expected);
    error ReserveSeedMismatch(uint256 actual, uint256 expected);
    error ReserveBackingMismatch(uint256 actual, uint256 expected);
    error PremiumRatioViolated(uint256 p0Num, uint256 p0Den, uint256 b0, uint256 s0);
    error CushionViolated(uint256 bootstrapOpening, uint256 cushion);
    error PolPositionEmpty();
    error PoolOneShotNotConsumed();
    error KingNotReserve(address king);
    error DeployerRoleNotRenounced(bytes32 role);
    error SafeRoleMissing(bytes32 role);

    // --- events ---------------------------------------------------------------

    /// @notice The complete genesis record, emitted once, at the end of the only
    ///         transaction this contract will ever participate in.
    event GenesisCompleted(
        address weth,
        address reserve,
        address rig,
        address vux,
        address pool,
        address treasury,
        address lens,
        address operatorSafe
    );

    /// @notice Contamination found at genesis, classified and swept.
    /// @dev Distinct from founder capital by construction: founder capital only
    ///      ever arrives as `msg.value` through the step-0 wrap. This amount
    ///      receives zero VEM mint credit and zero revenue classification
    ///      (sdd.md:L170, L177).
    event PreGenesisContaminationSwept(uint256 fromDeployer, uint256 fromReserve, uint256 total);

    // -------------------------------------------------------------------------

    /// @dev Locals for the deployment, carried between steps. Immutables cannot
    ///      be read during construction, so the record is assembled here and
    ///      written to the immutables once, at the end.
    struct Deployed {
        address reserve;
        address rig;
        address vux;
        address pool;
        address treasury;
        address lens;
        address token0;
        address token1;
        uint256 wethPreSelf;
        uint256 sanitized;
    }

    /// @param p The complete genesis input set. `msg.value` must equal
    ///          `p.wPol + p.b0` exactly — the founder contribution, carried as
    ///          native value and wrapped in-transaction.
    constructor(GenesisParams memory p) payable {
        if (p.weth == address(0) || p.poolDeployer == address(0) || p.operatorSafe == address(0)) revert ZeroAddress();
        if (msg.value != p.wPol + p.b0) revert FundingMismatch(msg.value, p.wPol + p.b0);

        Deployed memory d;

        _step0_snapshotAndWrap(p, d);
        _steps1to3_deployCoreAndVerifyNonces(p, d);
        _step4_deployAndVerifyCanonicalPool(p, d);
        _steps5to6_deployTreasuryAndLens(p, d);
        _step7_provisionPolAndFundReserve(p, d);
        _steps8to9_handOffAuthorityAndSweep(p, d);
        _step10_closingSelfVerification(p, d);

        weth = p.weth;
        poolDeployer = p.poolDeployer;
        reserve = d.reserve;
        rig = d.rig;
        vux = d.vux;
        pool = d.pool;
        treasury = d.treasury;
        lens = d.lens;
        operatorSafe = p.operatorSafe;
        wethPreSelf = d.wethPreSelf;
        wethSanitizedFromReserve = d.sanitized;
        contaminationSwept = d.wethPreSelf + d.sanitized;

        emit GenesisCompleted(p.weth, d.reserve, d.rig, d.vux, d.pool, d.treasury, d.lens, p.operatorSafe);
    }

    /*----------  STEP 0 — contamination snapshot + in-transaction funding  ----*/

    /// @dev The snapshot is taken *before* the wrap so that donations to this
    ///      address are separable from founder capital by arithmetic rather than
    ///      by trust. Only `msg.value` is wrapped — never `address(this).balance`
    ///      — so forced ETH pushed here by `selfdestruct` is left untouched and
    ///      unread, exactly as sdd.md:L184 requires.
    function _step0_snapshotAndWrap(GenesisParams memory p, Deployed memory d) private {
        d.wethPreSelf = IERC20(p.weth).balanceOf(address(this));

        IWethNative(p.weth).deposit{value: msg.value}();

        uint256 measured = IERC20(p.weth).balanceOf(address(this)) - d.wethPreSelf;
        if (measured != msg.value) revert WrapDeltaMismatch(measured, msg.value);
    }

    /*----------  STEPS 1-3 — CREATE nonces 1-3, predicted and verified  -------*/

    /// @dev The `VUX↔Rig` and `VUX↔HardReserve` immutable references are
    ///      2-cycles, so one edge of each must be built against a predicted
    ///      address (sdd.md:L157). Prediction is pure — `keccak256(rlp([this,
    ///      nonce]))[12:]` — and every prediction is checked against the actual
    ///      deployment in this same transaction. A mismatch reverts the entire
    ///      launch: mis-wiring cannot produce a partially usable deployment.
    function _steps1to3_deployCoreAndVerifyNonces(GenesisParams memory p, Deployed memory d) private {
        address predictedVux = _predict(address(this), 3);
        address predictedTreasury = _predict(address(this), 4);

        // 1. The Reserve sanitizes any pre-existing WETH to its creator (this
        //    deployer) inside its own constructor and requires itself born
        //    empty. The capability exists only in init code — the deployed
        //    runtime keeps no sweep, recovery, or admin path.
        uint256 beforeReserve = IERC20(p.weth).balanceOf(address(this));
        d.reserve = address(new HardReserve(p.weth, predictedVux)); //            nonce 1
        d.sanitized = IERC20(p.weth).balanceOf(address(this)) - beforeReserve;
        uint256 reserveBalance = IERC20(p.weth).balanceOf(d.reserve);
        if (reserveBalance != 0) revert ReserveNotBornEmpty(reserveBalance);

        // 2.
        d.rig = address(
            new Rig( //                                                           nonce 2
                p.weth,
                d.reserve,
                predictedVux,
                predictedTreasury,
                p.bootstrapOpening,
                p.minimumOpening,
                p.decayFloor
            )
        );

        // 3. VUX mints `GENESIS_POL_SUPPLY` to its creator (transiently, this
        //    deployer) and the single raw seed unit to the Reserve.
        d.vux = address(new VUX(d.rig, d.reserve)); //                            nonce 3
        if (d.vux != predictedVux) revert PredictedAddressMismatch(3, predictedVux, d.vux);
    }

    /*----------  STEP 4 — canonical pool: CREATE2, initialize, verify  --------*/

    /// @dev The pool is protocol-deployed, not taken from any shared factory: it
    ///      is born and initialized in the same atomic transaction, inside a
    ///      CREATE2 namespace only `VuxPoolDeployer` can write to. An adversary
    ///      who knows every input can compute this address and can pre-fund it,
    ///      and neither helps — EIP-684 collision needs code or nonce at the
    ///      target, which no third party can place, and v3 verifies payments as
    ///      within-operation balance deltas, so a pre-existing balance is
    ///      baseline rather than payment (sdd.md:L181).
    function _step4_deployAndVerifyCanonicalPool(GenesisParams memory p, Deployed memory d) private {
        (d.token0, d.token1) = d.vux < p.weth ? (d.vux, p.weth) : (p.weth, d.vux);

        if (p.sqrtP0X96 < MIN_SQRT_RATIO || p.sqrtP0X96 >= MAX_SQRT_RATIO) revert SqrtPriceOutOfRange(p.sqrtP0X96);

        // Commitment-gated one-shot: `keccak256(abi.encode(msg.sender, salt))`
        // must equal the commitment tx1 fixed. Binding to `msg.sender` is what
        // makes an extracted salt useless to an observer.
        d.pool = IVuxPoolDeployerGate(p.poolDeployer)
            .deployCanonicalPool(p.salt, d.token0, d.token1, p.feeTier, p.tickSpacing);

        // Atomically first: the pool only became callable this instant.
        IUniswapV3Pool(d.pool).initialize(p.sqrtP0X96);

        address derived = _deriveCanonicalPool(p.poolDeployer, d.token0, d.token1, p.feeTier);
        if (derived != d.pool) revert PoolAddressMismatch(derived, d.pool);

        address actualFactory = IUniswapV3Pool(d.pool).factory();
        if (actualFactory != p.poolDeployer) revert PoolFactoryMismatch(p.poolDeployer, actualFactory);

        address deployerOwner = IUniswapV3Factory(p.poolDeployer).owner();
        if (deployerOwner != address(0)) revert PoolOwnerNotDead(deployerOwner);

        address t0 = IUniswapV3Pool(d.pool).token0();
        address t1 = IUniswapV3Pool(d.pool).token1();
        if (t0 != d.token0 || t1 != d.token1) revert PoolTokensMismatch(t0, t1);

        uint24 actualFee = IUniswapV3Pool(d.pool).fee();
        if (actualFee != p.feeTier) revert PoolFeeMismatch(p.feeTier, actualFee);

        int24 actualSpacing = IUniswapV3Pool(d.pool).tickSpacing();
        if (actualSpacing != p.tickSpacing) revert PoolTickSpacingMismatch(p.tickSpacing, actualSpacing);

        (uint160 actualSqrtPrice,,,,,,) = IUniswapV3Pool(d.pool).slot0();
        if (actualSqrtPrice != p.sqrtP0X96) revert PoolPriceMismatch(p.sqrtP0X96, actualSqrtPrice);
    }

    /*----------  STEPS 5-6 — treasury (nonce 4) and Lens (nonce 5)  -----------*/

    /// @dev The `predict(4)` equality is doing double duty: it verifies the
    ///      treasury landed where the `Rig` was told it would, and it *proves*
    ///      the pool deployment consumed none of this account's nonces — the
    ///      CREATE2 ran in `VuxPoolDeployer`'s namespace and `initialize` is a
    ///      plain call (sdd.md:L157, L166).
    function _steps5to6_deployTreasuryAndLens(GenesisParams memory p, Deployed memory d) private {
        address predictedTreasury = _predict(address(this), 4);

        // The constructor receives every immutable identity it will ever need,
        // re-verifies its own wiring, and grants both roles to its creator —
        // this deployer, transiently. No role argument exists, so no external
        // party can ever receive authority.
        d.treasury = address(
            new StrategicTreasury(p.weth, d.vux, d.reserve, p.poolDeployer, d.pool, p.feeTier) //  nonce 4
        );
        if (d.treasury != predictedTreasury) revert PredictedAddressMismatch(4, predictedTreasury, d.treasury);

        d.lens = address(new Lens(d.rig)); //                                     nonce 5
    }

    /*----------  STEP 7 — POL provisioning and exact B0  ----------------------*/

    /// @dev The transient custody of the 150,000 POL VUX is non-discretionary by
    ///      construction: it exists only inside this transaction, only on this
    ///      code path, and a revert anywhere destroys the entire deployment
    ///      rather than stranding it (sdd.md:L186). The treasury pays the pool
    ///      out of its own balance through the one-shot authenticated mint
    ///      callback — no standing approval is created at any point.
    function _step7_provisionPolAndFundReserve(GenesisParams memory p, Deployed memory d) private {
        uint256 polVux = VUX(d.vux).GENESIS_POL_SUPPLY();

        IERC20(d.vux).safeTransfer(d.treasury, polVux);
        IERC20(p.weth).safeTransfer(d.treasury, p.wPol);
        StrategicTreasury(d.treasury).mintPolPosition(polVux, p.wPol);

        // Exact `B0`, delta-verified. The Reserve was born empty and nothing can
        // interleave inside one transaction, so the delta is the transfer.
        uint256 bPre = IERC20(p.weth).balanceOf(d.reserve);
        IERC20(p.weth).safeTransfer(d.reserve, p.b0);
        uint256 delta = IERC20(p.weth).balanceOf(d.reserve) - bPre;
        if (delta != p.b0) revert ReserveFundingDeltaMismatch(delta, p.b0);
    }

    /*----------  STEPS 8-9 — authority handoff, renounce, sanitizing sweep  ---*/

    function _steps8to9_handOffAuthorityAndSweep(GenesisParams memory p, Deployed memory d) private {
        StrategicTreasury t = StrategicTreasury(d.treasury);
        bytes32 adminRole = t.DEFAULT_ADMIN_ROLE();
        bytes32 operatorRole = t.OPERATOR_ROLE();

        // 8. Grant before renouncing — the admin role is what authorises the
        //    grant, so the order is load-bearing rather than stylistic.
        t.grantRole(adminRole, p.operatorSafe);
        t.grantRole(operatorRole, p.operatorSafe);

        // 9. Renounce. `renounceRole` requires the caller to confirm itself, so
        //    this cannot be done to us and cannot be done by us to anyone else.
        t.renounceRole(operatorRole, address(this));
        t.renounceRole(adminRole, address(this));

        // Every intended flow above was exact, so whatever WETH remains here is
        // precisely the contamination: donations to this address plus what the
        // Reserve's constructor sanitized out. Asserting that identity is what
        // proves no intended flow leaked — a plain `> 0` sweep would hide one.
        uint256 residual = IERC20(p.weth).balanceOf(address(this));
        uint256 expected = d.wethPreSelf + d.sanitized;
        if (residual != expected) revert ContaminationArithmeticMismatch(residual, expected);

        if (residual != 0) {
            // A bare transfer, which is exactly §1.10 rule 5: unattributed
            // principal-side Strategic inventory. Never revenue, never founder
            // capital, never mint credit.
            IERC20(p.weth).safeTransfer(d.treasury, residual);
        }
        emit PreGenesisContaminationSwept(d.wethPreSelf, d.sanitized, residual);

        uint256 left = IERC20(p.weth).balanceOf(address(this));
        if (left != 0) revert DeployerWethNotZero(left);
    }

    /*----------  STEP 10 — closing self-verification (all EXACT)  -------------*/

    /// @dev Any failure here reverts the complete launch transaction — and with
    ///      it, `GenesisDeployer` never comes into existence at all. There is no
    ///      partially-launched state to inherit or clean up.
    function _step10_closingSelfVerification(GenesisParams memory p, Deployed memory d) private view {
        VUX v = VUX(d.vux);
        uint256 s0 = v.GENESIS_POL_SUPPLY() + v.GENESIS_RESERVE_SEED();

        // Supply and the permanent Reserve seed.
        if (v.totalSupply() != s0) revert GenesisSupplyMismatch(v.totalSupply(), s0);
        uint256 seed = v.balanceOf(d.reserve);
        if (seed != v.GENESIS_RESERVE_SEED()) revert ReserveSeedMismatch(seed, v.GENESIS_RESERVE_SEED());

        // No protocol asset survives on the launch deployer. VUX cannot be
        // griefed here — it did not exist before this transaction — and the
        // WETH claim is made *after* the step-9 sanitizing sweep.
        uint256 vuxLeft = v.balanceOf(address(this));
        if (vuxLeft != 0) revert DeployerVuxNotZero(vuxLeft);

        // The exact frozen invariant, restored: the Reserve was born empty and
        // received exactly `B0`, so physical `N0 = B0/S0` and `P0/N0 = 1.10`
        // hold in actual state, and the first settlement's `B_pre` is `B0`.
        uint256 backing = IERC20(p.weth).balanceOf(d.reserve);
        if (backing != p.b0) revert ReserveBackingMismatch(backing, p.b0);

        _verifyBootstrapEconomics(p, s0);
        _verifyPoolAndPositionState(p, d);

        if (Rig(d.rig).king() != d.reserve) revert KingNotReserve(Rig(d.rig).king());

        _verifyRoleTopology(p, d);
    }

    /// @dev `P0/N0 = 1.10` and `BOOTSTRAP_OPENING <= P0*S0 - B0`, both in exact
    ///      wei arithmetic on the recorded conversion values — balance-independent
    ///      by design, and never re-derived from the Q64.96 encoding, which could
    ///      not represent the rational exactly (sdd.md:L185, L187).
    function _verifyBootstrapEconomics(GenesisParams memory p, uint256 s0) private pure {
        // P0 == (11/10) * B0/S0  ⟺  p0Num * 10 * S0 == p0Den * 11 * B0. Cross
        // multiplication keeps this an exact integer identity — no division, so
        // no rounding can make an unequal pair compare equal.
        //
        // Checked arithmetic is the overflow policy, and it is fail-closed by
        // construction: an operand set large enough to overflow reverts the
        // launch instead of wrapping into a false equality. Realistic values sit
        // ~30 orders of magnitude below the limit (the products are ~1e45), so
        // the branch is unreachable in practice and a 512-bit comparison would
        // be complexity bought for nothing.
        if (p.p0Num * PREMIUM_DEN * s0 != p.p0Den * PREMIUM_NUM * p.b0) {
            revert PremiumRatioViolated(p.p0Num, p.p0Den, p.b0, s0);
        }

        // Cushion: floor(P0 * S0) - B0. Floor is the conservative direction — it
        // can only make the cushion smaller and the inequality stricter.
        uint256 p0TimesS0 = Math.mulDiv(p.p0Num, s0, p.p0Den);
        uint256 cushion = p0TimesS0 > p.b0 ? p0TimesS0 - p.b0 : 0;
        if (p.bootstrapOpening > cushion) revert CushionViolated(p.bootstrapOpening, cushion);
    }

    /// @dev Pool identity coherent end-to-end, and the canonical position real
    ///      and owned by the treasury.
    function _verifyPoolAndPositionState(GenesisParams memory p, Deployed memory d) private view {
        StrategicTreasury t = StrategicTreasury(d.treasury);

        address derived = _deriveCanonicalPool(p.poolDeployer, d.token0, d.token1, p.feeTier);
        if (t.pool() != d.pool || derived != d.pool) revert PoolAddressMismatch(derived, t.pool());

        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(d.pool).slot0();
        if (sqrtPriceX96 != p.sqrtP0X96) revert PoolPriceMismatch(p.sqrtP0X96, sqrtPriceX96);

        (uint128 liquidity,,,,) =
            IUniswapV3Pool(d.pool).positions(keccak256(abi.encodePacked(d.treasury, t.tickLower(), t.tickUpper())));
        if (liquidity == 0) revert PolPositionEmpty();

        // The one-shot is consumed: `canonicalPool` is latched, so a second
        // `deployCanonicalPool` reverts for every caller forever.
        if (IVuxPoolDeployerGate(p.poolDeployer).canonicalPool() != d.pool) revert PoolOneShotNotConsumed();
    }

    /// @dev Exactly the Safe holds treasury authority; this deployer holds none.
    ///      The launch EOA is not named anywhere in the system — it was never
    ///      granted anything, so there is nothing to renounce on its behalf, and
    ///      `VUX`/`Rig`/`HardReserve`/`Lens` have no role surface at all.
    function _verifyRoleTopology(GenesisParams memory p, Deployed memory d) private view {
        StrategicTreasury t = StrategicTreasury(d.treasury);
        bytes32 adminRole = t.DEFAULT_ADMIN_ROLE();
        bytes32 operatorRole = t.OPERATOR_ROLE();

        if (!t.hasRole(adminRole, p.operatorSafe)) revert SafeRoleMissing(adminRole);
        if (!t.hasRole(operatorRole, p.operatorSafe)) revert SafeRoleMissing(operatorRole);
        if (t.hasRole(adminRole, address(this))) revert DeployerRoleNotRenounced(adminRole);
        if (t.hasRole(operatorRole, address(this))) revert DeployerRoleNotRenounced(operatorRole);
    }

    /*----------  address derivation  ------------------------------------------*/

    /// @dev `keccak256(rlp([deployer, nonce]))[12:]`. Genesis uses nonces 1-5
    ///      only; the single-byte RLP nonce encoding is valid for `1 <= n <=
    ///      0x7f`, and anything outside that reverts rather than silently
    ///      producing a wrong address.
    function _predict(address deployer, uint256 nonce) private pure returns (address) {
        if (nonce == 0 || nonce > 0x7f) revert NoncePredictionOutOfDomain(nonce);
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(uint8(nonce))))))
        );
    }

    /// @dev `create2(vuxPoolDeployer, keccak256(abi.encode(token0, token1, fee)),
    ///      POOL_INIT_CODE_HASH)` — upstream's exact salt and argument-free init
    ///      code, which is why the build constant still derives the address
    ///      (sdd.md:L192).
    function _deriveCanonicalPool(address deployer_, address token0, address token1, uint24 fee)
        private
        pure
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(token0, token1, fee));
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", deployer_, salt, POOL_INIT_CODE_HASH)))));
    }
}
