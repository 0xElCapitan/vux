// SPDX-License-Identifier: MIT AND GPL-3.0-or-later
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IVUXMintable} from "./interfaces/IVUXMintable.sol";

/// @title Rig — the one throne: Dutch pricing, mining clock, adaptive settlement, VEM.
/// @notice Operates a single King-of-the-Hill throne paid exclusively in
///         canonical WETH. Its entire state-changing external surface is
///         `take(maxPrice)` — there is no owner, no role, no pause, no upgrade
///         path, no setter, and no second entry point (FR-16; prd.md:L740).
///
///         Every takeover payment `P` is exhausted by the frozen **adaptive
///         8%-floor routing law** (FR-4.1): the outgoing King takes a fixed 80%,
///         the Hard Reserve takes between the nominal-8%-plus-all-dust floor and
///         the entire retained 20% — as much as safe issuance actually needs —
///         and the Strategic Treasury takes whatever residual remains, capped at
///         a floor-rounded 12% and frequently zero. Issuance is then limited by
///         the **measured** Hard Reserve delta, never by the routed intent
///         (FR-5).
///
/// @dev **Storage layout is the accepted one** (sdd.md:L109-L122); the routing
///      and pricing constants are `constant`/`immutable` — not storage, not
///      settable, with no code path that could ever repoint them.
///
/// @custom:provenance miner-manifold
///      The **generic auction/throne skeleton** — Dutch decay over a fixed
///      epoch, epoch state (`epochId`/`epochStart`/`epochOpening`/`epochUPS`),
///      the shift-based halving schedule, the successor-opening ladder, the
///      pay-then-distribute-then-mint-then-rotate shape of the settlement
///      function, and the `nonReentrant` + `SafeERC20` posture — is adapted from
///      the allowlisted Miner Manifold `contracts/Rig.sol` (blob `d362ef35…`) at
///      pinned commit `bcffbf1eb963810acb14a1fd1c73d03a53a085a8` (PROV-2,
///      prd.md:L761). Upstream author: heesho. Upstream licence: MIT, reproduced
///      verbatim in `THIRD_PARTY_NOTICES.md`; this file therefore declares
///      `MIT AND GPL-3.0-or-later` per PROV-8. The byte-identical upstream file
///      remains in `vendor/miner-manifold-bcffbf1e/` as the derivation reference.
///
/// @custom:modifications 2026-08-13 — VUX modifications to the derived skeleton.
///      Removed from upstream: `Ownable` and every privileged setter
///      (`setHopper`/`setTeam`/`setDev`/`setUri`); the four-way static fee split
///      (80/15/2.5/2.5) and its team/dev/hopper recipients; the `uri`/`epochUri`
///      metadata surface; the `miner` recipient parameter (the payer *is* the
///      successor King — no argument exists to direct the throne elsewhere); the
///      `deadline`/`_epochId` guards (the Dutch price plus `maxPrice` is the
///      complete slippage statement, and an epoch-id guard would let a griefer
///      invalidate honest transactions by taking first); the `TAIL_UPS` clamp and
///      1-hour `EPOCH_PERIOD`. Changed: `EPOCH_PERIOD = 3_000 s`; decay clipped at
///      an immutable `DECAY_FLOOR` instead of reaching zero; successor opening
///      `max(MINIMUM_OPENING, 2 × P)` with an integer multiplier rather than a
///      1e18-scaled one; the halving schedule bounded at exactly eight halvings
///      to a permanent tail; `Qraw` capped at `EPOCH_PERIOD × epochUPS` (upstream
///      accrues unbounded).
///
///      **VUX-original clean-source surfaces (PROV-3, prd.md:L762).** Nothing
///      below was ported, adapted, or transliterated from upstream — each is
///      written from the PRD/SDD equations alone, and upstream contains no
///      counterpart to any of them: the adaptive routing law (`retained`,
///      `strategicCap`, `hardFloor`, `D_need`, `hardTarget`, the Strategic
///      residual), the Reserve-favouring dust arithmetic, the physical `D_R`
///      measurement, the `D_R` consistency rejection, the VEM cap
///      (`Qsafe`/`Qmint`), the bootstrap branch, and the `Settled` record.
///      Upstream mints `elapsed × ups` unconditionally to the outgoing miner with
///      no backing check of any kind; the entire VEM concept is VUX-original.
contract Rig is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*----------  ROUTING CONSTANTS (FR-4.1)  ---------------------------*/

    /// @notice Fixed outgoing-King share: `king = floor(P × 8000 / 10000)`.
    uint256 public constant SPLIT_KING_BP = 8_000;

    /// @notice Strategic **cap**, not a fixed leg (2026-08-12 adaptive-routing
    ///         supersession; sdd.md Appendix F, F-1). Strategic receives the
    ///         retained residual after Hard is satisfied, at most this much, and
    ///         legitimately zero for extended periods near backing.
    uint256 public constant STRATEGIC_CAP_BP = 1_200;

    uint256 public constant BP_DENOM = 10_000;

    /*----------  PRICING & CLOCK CONSTANTS  ----------------------------*/

    /// @notice Dutch decay window and the mining clock's eligible-second cap.
    uint256 public constant EPOCH_PERIOD = 3_000;

    /// @notice Successor price ladder. A price multiplier only — it has no
    ///         mining or issuance effect whatsoever (FR-2.4, prd.md:L337).
    uint256 public constant PRICE_MULTIPLIER = 2;

    /// @notice 4 VUX/second at schedule start (FR-3.1).
    uint256 public constant INITIAL_UPS = 4e18;

    uint256 public constant HALVING_PERIOD = 30 days;

    /// @notice Eight halvings, then the permanent tail `INITIAL_UPS >> 8`
    ///         = 0.015625 VUX/s (FR-3.3). The tail is produced by clamping the
    ///         shift, so no separate tail constant can drift away from it.
    uint256 public constant MAX_HALVINGS = 8;

    /*----------  IMMUTABLES  -------------------------------------------*/

    /// @notice Canonical RH WETH — the only accepted payment asset (FR-2.1).
    ///         Non-canonical payment is impossible because no other asset is
    ///         referenced anywhere in this contract.
    IERC20 public immutable weth;

    /// @notice The VUX token. This contract is its sole post-genesis mint
    ///         authority, and mints only inside VEM settlement.
    IVUXMintable public immutable vux;

    /// @notice The Hard Reserve. Also the genesis King, which is exactly how
    ///         bootstrap is detected — see `take`.
    address public immutable reserve;

    /// @notice Strategic residual destination. A plain WETH transfer target: no
    ///         callback, no interface, no authority in either direction. In
    ///         Sprint 3 this is the SDD/Sprint-approved plain address
    ///         (sdd.md:L138, sprint.md Sprint 3 Dependencies); `StrategicTreasury`
    ///         is Sprint 4 and is deliberately not built or referenced here.
    address public immutable treasury;

    /// @notice Bootstrap epoch opening (≈$50, one-shot converted pre-deployment).
    uint256 public immutable BOOTSTRAP_OPENING;

    /// @notice Successor-opening floor (≈$10).
    uint256 public immutable MINIMUM_OPENING;

    /// @notice Dutch price floor (≈$1) — a paid-handoff/dust-restart rule, never
    ///         an issuance, oracle, backing, or quote guarantee (FR-2.5).
    uint256 public immutable DECAY_FLOOR;

    /*----------  STATE (sdd.md:L109-L122)  -----------------------------*/

    /// @notice Current throne holder. Genesis value is `reserve`.
    address public king;

    /// @notice Timestamp the current epoch opened. At genesis this is the
    ///         deployment timestamp, which anchors the bootstrap Dutch decay.
    uint64 public epochStart;

    /// @notice Opening reference price for the current epoch (WETH wei).
    uint192 public epochOpening;

    /// @notice UPS snapshotted when the current epoch opened. A halving during an
    ///         already-open reign never touches it (FR-3.4).
    uint256 public epochUPS;

    /// @notice Set exactly once, at the first public takeover (prd.md:L176). Zero
    ///         means the public clock has not started — the bootstrap state.
    uint64 public scheduleStart;

    /// @notice Monotonic settlement counter.
    uint64 public epochId;

    /// @notice Cumulative Strategic contributed principal — the sum of the
    ///         variable residual legs. Accounting truth carried here until the
    ///         treasury consumes it in Sprint 4 (sprint.md Sprint 3 Dependencies).
    uint256 public totalStrategicContributed;

    /*----------  ERRORS (sdd.md §6.1)  ---------------------------------*/

    error ZeroAddress();
    /// @dev An opening price that would not survive the `uint192` storage cell.
    error OpeningTooLarge(uint256 opening);
    /// @dev Contender slippage guard.
    error PriceAboveMax(uint256 price, uint256 maxPrice);
    /// @dev The physically measured Hard Reserve delta is not the routed Hard
    ///      contribution. Measured reality disagreed with intent, so the whole
    ///      settlement reverts (prd.md:L231, L394).
    error InconsistentReserveDelta(uint256 expected, uint256 measured);

    /*----------  EVENTS (sdd.md §3.2)  ---------------------------------*/

    /// @notice The complete FR-14.1 settlement record. Every quantity an indexer
    ///         needs is here: `D_need` is re-derivable as
    ///         `ceil(qRaw × bPre / sPre)`, and each leg is stated as paid rather
    ///         than as a percentage, because the legs are variable by law.
    event Settled(
        uint64 indexed epochId,
        address indexed outgoingKing,
        address indexed newKing,
        bool bootstrap,
        uint256 price,
        uint256 kingLeg,
        uint256 strategicLeg,
        uint256 reserveLeg,
        uint256 bPre,
        uint256 sPre,
        uint256 dR,
        uint256 qRaw,
        uint256 qSafe,
        uint256 qMint,
        uint256 nextOpening,
        uint256 epochUPS
    );

    /// @dev One settlement's complete record. A memory struct rather than a
    ///      basket of locals: the 13-step outcome carries more live values than
    ///      the EVM's addressable stack window holds, and threading them through
    ///      memory keeps the steps in their specified order instead of splitting
    ///      them across helpers for the compiler's benefit.
    struct Settlement {
        uint64 epochId;
        address outgoingKing;
        address newKing;
        bool bootstrap;
        uint256 price;
        uint256 kingLeg;
        uint256 strategicLeg;
        uint256 reserveLeg;
        uint256 bPre;
        uint256 sPre;
        uint256 dR;
        uint256 qRaw;
        uint256 qSafe;
        uint256 qMint;
        uint256 nextOpening;
    }

    /*----------  CONSTRUCTOR  ------------------------------------------*/

    /// @notice Deploys the throne in its bootstrap state: the ownerless Hard
    ///         Reserve is the genesis King, and the public clock is off
    ///         (FR-6.1). `epochUPS = 0` states "clock disabled" in storage; the
    ///         `king == reserve` bootstrap test in `take` independently forces
    ///         `Qraw = 0`, so zero mining at bootstrap holds even if one of the
    ///         two were somehow wrong.
    ///
    /// @dev Validation is deliberately limited to what is structurally
    ///      load-bearing *for this contract*: non-zero dependencies, and openings
    ///      that survive the `uint192` price cell without silent truncation. The
    ///      economic relationships between the three converted USD targets
    ///      (≈$50 / ≈$10 / ≈$1) are deployment-time founder facts (R-14) verified
    ///      by `GenesisDeployer`'s closing self-verification in Sprint 7 —
    ///      re-asserting an ordering here would freeze an economic rule no
    ///      accepted authority states.
    ///
    /// @param vux_ At genesis this is a CREATE-predicted address whose equality
    ///             with the real deployment is verified in-transaction by the
    ///             `GenesisDeployer` (sdd.md:L163-L164).
    constructor(
        address weth_,
        address reserve_,
        address vux_,
        address treasury_,
        uint256 bootstrapOpening_,
        uint256 minimumOpening_,
        uint256 decayFloor_
    ) {
        if (weth_ == address(0) || reserve_ == address(0) || vux_ == address(0) || treasury_ == address(0)) {
            revert ZeroAddress();
        }
        // Both can reach `epochOpening`: the bootstrap opening directly, the
        // minimum opening through every successor ladder step.
        if (bootstrapOpening_ > type(uint192).max) revert OpeningTooLarge(bootstrapOpening_);
        if (minimumOpening_ > type(uint192).max) revert OpeningTooLarge(minimumOpening_);

        weth = IERC20(weth_);
        reserve = reserve_;
        vux = IVUXMintable(vux_);
        treasury = treasury_;
        BOOTSTRAP_OPENING = bootstrapOpening_;
        MINIMUM_OPENING = minimumOpening_;
        DECAY_FLOOR = decayFloor_;

        king = reserve_;
        epochStart = uint64(block.timestamp);
        // Cannot truncate: `bootstrapOpening_` was bounds-checked against
        // `type(uint192).max` above, and reverts rather than narrowing.
        // forge-lint: disable-next-line(unsafe-typecast)
        epochOpening = uint192(bootstrapOpening_);
        epochUPS = 0;
    }

    /*----------  SETTLEMENT  -------------------------------------------*/

    /// @notice Take the throne at the current Dutch price, settling the outgoing
    ///         reign atomically.
    ///
    /// @dev The accepted 13-step outcome (sdd.md:L196-L229) in
    ///      checks-effects-interactions order. The step numbers below are the
    ///      SDD's, and the two places where the order is load-bearing are called
    ///      out where they occur.
    ///
    ///      **Atomicity is the transaction boundary** (INV-21). There is no
    ///      partial-success path and no `try`/`catch` salvage: a failed leg, a
    ///      failed mint, an inconsistent measurement, or a failed payment reverts
    ///      every effect of the settlement together (sdd.md §6.1).
    ///
    ///      **No prohibited signal is readable here** (FR-4.3). The function's
    ///      complete input set is `block.timestamp`, this contract's own storage,
    ///      `WETH.balanceOf(reserve)`, and `VUX.totalSupply()` — which is exactly
    ///      the sanctioned adaptive input set `(P, Qraw, B_pre, S_pre)` plus own
    ///      throne state. No macro, market-price, NAV, Strategy-return,
    ///      ROOT/GIGA-price, calendar-phase, oracle, or operator-discretion
    ///      branch exists, because no such value is reachable from this contract
    ///      at all: it holds no reference that could supply one.
    ///
    /// @param maxPrice Contender slippage guard. The Dutch price falls with time,
    ///                 so a contender's risk is that a *rise* — a successor
    ///                 opening set by a competing takeover in the same block —
    ///                 lands above their limit.
    function take(uint256 maxPrice) external nonReentrant {
        Settlement memory s;

        // --- 1-2. identify the OUTGOING epoch and King, then fix P ----------
        // These four reads happen before any write, so successor state written
        // in step 12' below cannot reach back and rewrite whose reign is being
        // settled, which epoch it was, or who receives the mint (INV-21).
        s.outgoingKing = king;
        s.epochId = epochId;
        s.bootstrap = s.outgoingKing == reserve;
        s.price = currentPrice();
        if (s.price > maxPrice) revert PriceAboveMax(s.price, maxPrice);

        // --- 3. pre-settlement measurements ---------------------------------
        // `B_pre` is the physical Reserve balance and `S_pre` the complete
        // supply, both read before this settlement contributes anything.
        s.bPre = weth.balanceOf(reserve);
        s.sPre = vux.totalSupply();

        // --- 4. raw opportunity of the OUTGOING epoch ------------------------
        // Bootstrap's clock is disabled, so the genesis reign accrues nothing
        // (FR-6.1). Otherwise eligible time caps at EPOCH_PERIOD: beyond it the
        // opportunity simply stops accruing — it does not carry, bank, or become
        // owed (INV-8, INV-9, prd.md:L588-L589).
        if (!s.bootstrap) {
            uint256 elapsed = block.timestamp - epochStart;
            s.qRaw = Math.min(elapsed, EPOCH_PERIOD) * epochUPS;
        }

        // --- 5. collect payment ----------------------------------------------
        weth.safeTransferFrom(msg.sender, address(this), s.price);

        // --- 6. the adaptive legs --------------------------------------------
        (s.kingLeg, s.reserveLeg, s.strategicLeg) = _route(s.price, s.qRaw, s.bPre, s.sPre);

        // --- 7. Strategic residual, delivered and classified ------------------
        // Skipped when zero: a no-op transfer would emit a misleading ERC-20
        // `Transfer` and imply a contribution that did not happen (sdd.md:L215).
        if (s.strategicLeg != 0) {
            totalStrategicContributed += s.strategicLeg;
            weth.safeTransfer(treasury, s.strategicLeg);
        }

        // --- 8a. realize the Hard contribution --------------------------------
        // At bootstrap the outgoing King *is* the Reserve, so the 80% King leg
        // terminates at Hard as well. That is the whole of the ≈88%+ bootstrap
        // result — no special economics are computed for it (FR-6.2).
        uint256 hardContribution = s.bootstrap ? s.reserveLeg + s.kingLeg : s.reserveLeg;
        weth.safeTransfer(reserve, hardContribution);

        // --- 8b. measure reality, and reject any disagreement with it ---------
        // The routed amount is intent; `D_R` is what physically arrived. Only the
        // measurement is allowed to support issuance (FR-5.1, NFR-SEC-6), and a
        // mismatch — a fee-on-transfer asset, a hostile WETH upgrade, anything at
        // all — rejects the entire settlement rather than minting against a
        // number that was never delivered.
        //
        // The subtraction is itself a guard, one layer below the check: a
        // settlement that somehow *reduced* the Reserve's balance reverts on the
        // underflow rather than wrapping. That is the shape a Reserve-funded
        // takeover would have — payment leaves the payer — and it is refused
        // even though the Reserve has no code path that could call `take`.
        s.dR = weth.balanceOf(reserve) - s.bPre;
        if (s.dR != hardContribution) revert InconsistentReserveDelta(hardContribution, s.dR);

        // --- 9. VEM ------------------------------------------------------------
        (s.qSafe, s.qMint) = _vem(s.dR, s.sPre, s.bPre, s.qRaw);
        // Any `Qraw − Qsafe` shortfall is *not recorded anywhere*. There is no
        // cell for it in this contract, and that absence is the requirement:
        // unsupported opportunity expires with no carry, IOU, debt, makeup, or
        // entitlement of any kind (FR-5.5, INV-8).

        // --- 12'. EFFECTS: open the successor epoch ---------------------------
        // Committed before the mint and the outbound King transfer. Every value
        // the remaining steps use was captured in `s` before this point, so these
        // writes cannot influence the settlement they conclude.
        s.nextOpening = _successorOpening(s.price);

        king = msg.sender;
        epochStart = uint64(block.timestamp);
        epochOpening = uint192(s.nextOpening);
        epochUPS = currentUPS();
        epochId = s.epochId + 1;
        // Set once, at the first public takeover, and never reachable again: the
        // Reserve has no code path that can call `take`, so `king == reserve` can
        // never become true a second time and no second bootstrap exists
        // (FR-6.3 acceptance).
        if (s.bootstrap) scheduleStart = uint64(block.timestamp);

        // --- 10. mint to the OUTGOING King ------------------------------------
        // Skipped at zero, which is every bootstrap settlement and every
        // settlement whose measured backing supported nothing.
        if (s.qMint != 0) vux.mint(s.outgoingKing, s.qMint);

        // --- 11. deliver the King leg -----------------------------------------
        // Ordinary settlements only: at bootstrap this leg was already delivered
        // to the Reserve as part of step 8a.
        if (!s.bootstrap && s.kingLeg != 0) weth.safeTransfer(s.outgoingKing, s.kingLeg);

        // --- 13. record --------------------------------------------------------
        s.newKing = msg.sender;
        _emitSettled(s);
    }

    /// @dev The `Settled` record carries sixteen fields — more than the EVM's
    ///      addressable stack window holds alongside `take`'s live values, and
    ///      one more than a memory struct alone can feed (the struct pointer sits
    ///      below every pushed argument, so the last field would need a
    ///      seventeenth-deep reach). Hence two things: the emit gets its own
    ///      frame, and the final field is read from storage — it was written in
    ///      step 12' immediately above, and a storage slot needs no stack slot to
    ///      address. The alternative was enabling `via_ir` on the monetary core's
    ///      build, which Sprint 2 deliberately left off (`foundry.toml`); one log
    ///      statement is not a reason to change the compilation pipeline.
    ///
    ///      The field is the *successor* epoch's snapshotted UPS, which is what
    ///      the accepted schema means by `epochUPS` in a settlement record — it
    ///      is grouped with `nextOpening` for exactly that reason (sdd.md §3.2).
    function _emitSettled(Settlement memory s) private {
        emit Settled(
            s.epochId,
            s.outgoingKing,
            s.newKing,
            s.bootstrap,
            s.price,
            s.kingLeg,
            s.strategicLeg,
            s.reserveLeg,
            s.bPre,
            s.sPre,
            s.dR,
            s.qRaw,
            s.qSafe,
            s.qMint,
            s.nextOpening,
            epochUPS
        );
    }

    /*----------  VIEWS  -------------------------------------------------*/

    /// @notice The Dutch price now:
    ///         `max(DECAY_FLOOR, opening × (1 − min(t, 3000)/3000))`.
    /// @dev Written as `opening − opening×t/3000` so the single division floors
    ///      the *subtrahend*, which rounds the price up. That is the
    ///      Reserve-favouring direction, consistent with INV-16 everywhere else.
    function currentPrice() public view returns (uint256) {
        uint256 elapsed = block.timestamp - epochStart;
        uint256 opening = epochOpening;
        if (elapsed >= EPOCH_PERIOD) return DECAY_FLOOR;
        uint256 decayed = opening - (opening * elapsed) / EPOCH_PERIOD;
        return Math.max(DECAY_FLOOR, decayed);
    }

    /// @notice The schedule rate right now — the UPS the *next* epoch to open
    ///         will snapshot. It is not the rate any open epoch is earning.
    /// @dev Before the public clock starts, the schedule is at its head: the
    ///      first public epoch opens in the same transaction that sets
    ///      `scheduleStart`, so its elapsed schedule time is zero.
    function currentUPS() public view returns (uint256) {
        uint64 start = scheduleStart;
        if (start == 0) return INITIAL_UPS;
        uint256 halvings = Math.min((block.timestamp - start) / HALVING_PERIOD, MAX_HALVINGS);
        return INITIAL_UPS >> halvings;
    }

    /// @notice Complete throne state in one call.
    function epochState()
        external
        view
        returns (address king_, uint64 epochStart_, uint256 epochOpening_, uint256 epochUPS_, bool bootstrap_)
    {
        return (king, epochStart, epochOpening, epochUPS, king == reserve);
    }

    /*----------  INTERNAL  ----------------------------------------------*/

    /// @notice The adaptive 8%-floor routing law (FR-4.1; sdd.md Appendix F, F-1).
    ///
    /// @dev VUX-original clean source (PROV-3) — written from the PRD equation
    ///      set, with no upstream counterpart.
    ///
    ///      ```
    ///      king         = floor(P × 8000 / 10000)
    ///      retained     = P − king
    ///      strategicCap = floor(P × 1200 / 10000)
    ///      hardFloor    = retained − strategicCap
    ///      D_need       = ceil(Qraw × B_pre / S_pre)
    ///      hardTarget   = min(retained, max(hardFloor, D_need))
    ///      strategic    = retained − hardTarget
    ///      ```
    ///
    ///      Three properties are structural rather than asserted:
    ///
    ///      * **The legs exhaust `P`.** `king + retained == P` by construction,
    ///        and `hardTarget + strategic == retained` likewise. No dust can be
    ///        stranded in this contract.
    ///      * **All dust favours Hard.** `retained` absorbs the King leg's
    ///        flooring remainder and `strategicCap` floors downward, so the
    ///        rounding loss of both accrues inside `hardFloor` (INV-19).
    ///      * **`hardFloor` never underflows.** `retained >= ceil(0.2P) >= 0.2P`
    ///        while `strategicCap <= 0.12P`, so `strategicCap < retained` for
    ///        every `P`.
    ///
    ///      `D_need` rounds **up** — the contribution needed to mint the full raw
    ///      opportunity must not be understated — while every issuance quantity
    ///      rounds down (FR-5.3). When `D_need <= hardFloor` the law degenerates
    ///      to exactly the nominal split; when `D_need > retained` Hard takes all
    ///      retained capital, Strategic takes nothing, and issuance stays
    ///      VEM-limited. Both are intended outcomes with no compensating logic.
    function _route(uint256 price, uint256 qRaw, uint256 bPre, uint256 sPre)
        internal
        pure
        returns (uint256 kingLeg, uint256 hardTarget, uint256 strategicLeg)
    {
        kingLeg = (price * SPLIT_KING_BP) / BP_DENOM;
        uint256 retained = price - kingLeg;
        uint256 hardFloor = retained - (price * STRATEGIC_CAP_BP) / BP_DENOM;

        uint256 dNeed = qRaw == 0 ? 0 : Math.mulDiv(qRaw, bPre, sPre, Math.Rounding.Ceil);

        hardTarget = Math.min(retained, Math.max(hardFloor, dNeed));
        strategicLeg = retained - hardTarget;
    }

    /// @notice The VEM issuance cap (FR-5.2; sdd.md:L218).
    ///
    /// @dev VUX-original clean source (PROV-3). The derived skeleton mints
    ///      `elapsed × ups` with no backing check whatsoever; this cap has no
    ///      upstream counterpart.
    ///
    ///      ```
    ///      Qsafe = floor(D_R × S_pre / B_pre)
    ///      Qmint = min(Qraw, Qsafe)
    ///      ```
    ///
    ///      `Math.mulDiv` gives a full-precision 512-bit intermediate: the plain
    ///      `D_R × S_pre` product overflows at realistic backing and supply, and
    ///      reverting there would *deny* issuance rather than cap it — a denial
    ///      of the mining right, not a safety property. Flooring is the required
    ///      Reserve-favouring direction (INV-16, prd.md:L601).
    ///
    ///      The property this establishes is non-dilution (INV-13,
    ///      prd.md:L598): `Qmint <= floor(D_R × S_pre / B_pre)` is exactly
    ///      `B_pre × Qmint <= D_R × S_pre`, which rearranges to
    ///      `(B_pre + D_R)/(S_pre + Qmint) >= B_pre/S_pre`. Authorized issuance
    ///      therefore cannot reduce backing per unit, and when `Qsafe > Qraw` the
    ///      surplus contribution simply raises it.
    ///
    ///      `B_pre > 0` holds structurally: genesis funds the Reserve with
    ///      `B0 > 0`, and redemption cannot reach zero from a positive balance —
    ///      it pays `floor(B×q/S)` with `q <= S − S_MIN`, so a payout equal to the
    ///      whole balance would require `q >= S`. Were that ever false this
    ///      divides by zero and reverts, which is the correct failure: minting
    ///      against unmeasurable backing is worse than not minting.
    ///
    ///      Kept as a named function rather than inlined so the FR-5 acceptance
    ///      property can be exercised over the whole `(D_R, S_pre, B_pre, Qraw)`
    ///      domain, including tuples no reachable settlement can construct.
    function _vem(uint256 dR, uint256 sPre, uint256 bPre, uint256 qRaw)
        internal
        pure
        returns (uint256 qSafe, uint256 qMint)
    {
        qSafe = Math.mulDiv(dR, sPre, bPre);
        qMint = Math.min(qRaw, qSafe);
    }

    /// @notice Successor opening: `max(MINIMUM_OPENING, 2 × P)` (FR-2.3).
    /// @dev The clamp exists so the `uint192` price cell can never silently
    ///      truncate. It is unreachable in practice — the SDD records `P ≤ 2^192`
    ///      as impossible for WETH amounts (sdd.md:L229) — and matches the
    ///      derived skeleton's own `ABS_MAX_INIT_PRICE` treatment.
    function _successorOpening(uint256 price) internal view returns (uint256) {
        uint256 doubled = price > type(uint192).max / PRICE_MULTIPLIER
            ? uint256(type(uint192).max)
            : price * PRICE_MULTIPLIER;
        return Math.max(MINIMUM_OPENING, doubled);
    }
}
