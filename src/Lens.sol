// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IRigViews, IReserveBacking, ITokenSupply} from "./interfaces/ILensViews.sol";

/// @title Lens — the protocol's read-only truth surface.
/// @notice Aggregates the values every mining surface must show, in the exact
///         three-tier shape FR-15 requires (prd.md:L546):
///
///         | Tier | View | What it is |
///         |------|------|------------|
///         | 1 | `rawClockLimit` | the maximum the clock can produce for the open reign — time-only opportunity |
///         | 2 | `estimateIfDisplacedNow` | a live estimate under current price, supply and backing — it may rise or fall |
///         | 3 | — | actual minted VUX; **not** a Lens value, it is settled history read from `Settled` records |
///
///         Tier 3 is deliberately absent from this contract. Minted VUX is a
///         fact about completed settlements, and sourcing it from a live view
///         would invite the exact conflation FR-15.1 prohibits. The indexer
///         serves it from `settlement.q_mint` history (sdd.md:L631).
///
/// @notice **Nothing here is owned, earned, claimable, owed, or guaranteed.**
///         Tier 1 is a ceiling on what *could* be settled, not a balance: raw
///         opportunity is never described as already earned, owned, claimable,
///         owed, guaranteed, or debt (FR-15.2, prd.md:L547), it does not accrue
///         to anyone, and it expires unrecorded when a settlement cannot support
///         it — there is no cell for the shortfall anywhere in this protocol
///         (FR-5.5, INV-8). Tier 2 is a reading of present conditions and moves
///         with every one of them. Reading either value creates no entitlement
///         (FR-14 acceptance, prd.md:L539); only VUX actually minted by a
///         completed settlement has been mined.
///
/// @dev **Structurally read-only.** This contract has no storage beyond one
///      immutable, no `receive`/`fallback`, no payable function, no token
///      handle, no role, no owner, and no state-changing function of any kind.
///      Its outbound reads go through `ILensViews`, whose members are all
///      `view`, so the deployed runtime contains `STATICCALL` and no `CALL`,
///      `SSTORE`, `LOG*`, `CREATE*`, `DELEGATECALL`, or `SELFDESTRUCT`. That is
///      asserted against the compiled artifact in `test/lens/LensSurface.t.sol`
///      — the same method the Reserve's structural-absence claims use, and for
///      the same reason: "the source has no sweep" is exactly what a mistake
///      would also look like.
///
/// @dev **Provenance — PROV-5 (prd.md:L764).** `VUX_ORIGINAL_CLEAN_SOURCE`.
///      Written from the accepted view surface (sdd.md:L706-L715) and the frozen
///      equation set only. No upstream lens, oracle, or quoter implementation
///      was consulted as an implementation source.
contract Lens {
    /// @notice Ray precision (`1e27`) for `B/S`. Wei-per-VUX is a sub-1 quantity
    ///         at every realistic backing level, so an unscaled integer ratio
    ///         would read as zero; ray keeps 27 significant decimals of it.
    uint256 public constant RAY = 1e27;

    /// @notice The Rig this Lens reports on. Every other identity — the Reserve
    ///         and the token — is derived from it at call time rather than
    ///         supplied separately, so a Lens cannot be wired to report one
    ///         contract's price against another's backing.
    IRigViews public immutable RIG;

    error ZeroAddress();

    constructor(address rig) {
        if (rig == address(0)) revert ZeroAddress();
        RIG = IRigViews(rig);
    }

    /*----------  TIER 1  ------------------------------------------------*/

    /// @notice **Raw clock limit — the maximum from time.** The largest VUX
    ///         amount the open reign's clock can support if it were settled now.
    ///
    ///         This is a ceiling, not a balance. It is not earned, owned,
    ///         claimable, owed, or guaranteed, and the actual mint is whatever
    ///         the next settlement's measured backing contribution supports —
    ///         which may be less, and at bootstrap is nothing.
    ///
    /// @dev Mirrors `Rig.take` step 4 exactly: the genesis reign's clock is
    ///      disabled (FR-6.1), and eligible time caps at `EPOCH_PERIOD` — beyond
    ///      it opportunity stops accruing rather than carrying or banking
    ///      (INV-8, INV-9, prd.md:L588-L589).
    function rawClockLimit() public view returns (uint256) {
        (, uint64 epochStart,, uint256 epochUPS, bool bootstrap) = RIG.epochState();
        if (bootstrap) return 0;
        return Math.min(block.timestamp - epochStart, RIG.EPOCH_PERIOD()) * epochUPS;
    }

    /*----------  TIER 2  ------------------------------------------------*/

    /// @notice **VUX if displaced now — a live estimate. It may rise or fall,
    ///         and it is not claimable.** What a settlement executed in this
    ///         block would mint to the current King.
    ///
    ///         Every input moves: the Dutch price falls with time, backing and
    ///         supply move with every settlement and redemption, and a competing
    ///         takeover changes all of them at once. The value is a reading of
    ///         present conditions, not a promise about future ones, and holding
    ///         the throne confers no right to it.
    ///
    /// @param estimateQmint The VUX a settlement in this block would mint.
    /// @param price The Dutch price a contender would pay in this block.
    /// @param qRaw The tier-1 raw clock limit this estimate is capped by.
    /// @param qSafeEst The VEM cap — the most the routed Hard contribution could
    ///                 support without diluting `B/S`.
    ///
    /// @dev Parity is the requirement (sdd.md:L711): each returned value equals
    ///      the corresponding field of the `Settled` record a settlement in this
    ///      block would emit. `_hardToReserve` therefore reproduces the whole
    ///      routed-to-Hard amount — including `Rig.take` step 8a's bootstrap
    ///      case, where the outgoing King *is* the Reserve and the King leg
    ///      terminates at Hard as well. Omitting that branch would leave
    ///      `qSafeEst` understating the `qSafe` a bootstrap settlement actually
    ///      emits; `estimateQmint` is zero either way, because tier 1 is zero
    ///      during bootstrap.
    function estimateIfDisplacedNow()
        external
        view
        returns (uint256 estimateQmint, uint256 price, uint256 qRaw, uint256 qSafeEst)
    {
        price = RIG.currentPrice();
        qRaw = rawClockLimit();
        (uint256 b, uint256 s) = _backingAndSupply();
        (,,,, bool bootstrap) = RIG.epochState();

        // `Rig._vem`: Qsafe = floor(D_R × S_pre / B_pre); Qmint = min(Qraw, Qsafe).
        qSafeEst = Math.mulDiv(_hardToReserve(price, qRaw, b, s, bootstrap), s, b);
        estimateQmint = Math.min(qRaw, qSafeEst);
    }

    /*----------  RESERVE TRUTH  -----------------------------------------*/

    /// @notice Hard Reserve backing `B`, complete supply `S`, and backing per VUX
    ///         in ray.
    ///
    /// @dev `bPerSRay` floors, which understates rather than overstates backing
    ///      per unit — the Reserve-favouring direction every quantity in this
    ///      protocol rounds (INV-16, prd.md:L601).
    ///
    ///      A zero `S` divides by zero and reverts. That is the correct failure
    ///      and it is deliberately not branched around: `S` is structurally
    ///      positive after genesis (the Reserve holds `S_MIN` and has no code
    ///      path that can transfer it, FR-7.5), so a zero here means the caller
    ///      is reading a system that does not exist yet. Returning `0` would
    ///      present "no backing per VUX" as a measured fact; reverting lets the
    ///      surface say the data is unavailable, which is what would be true.
    function hardStats() public view returns (uint256 B, uint256 S, uint256 bPerSRay) {
        (B, S) = _backingAndSupply();
        bPerSRay = Math.mulDiv(B, RAY, S);
    }

    /// @notice The WETH contribution to Hard that would let the open reign's
    ///         full raw clock limit mint — the settlement law's `D_need` at the
    ///         current `Qraw`.
    ///
    ///         This is a measurement of what the law would require, not a bill
    ///         and not a promise. Nobody owes it, no settlement is obliged to
    ///         reach it, and reaching it entitles no one to anything: an actual
    ///         mint still depends on the payment a contender chooses to make and
    ///         on the backing measured when they make it.
    ///
    /// @dev Rounds **UP** (F-16, sdd.md:L713): the contribution needed to mint
    ///      the full raw opportunity must never be understated, while every
    ///      issuance quantity rounds down. Zero raw opportunity needs zero WETH,
    ///      and is returned without a division.
    function wethNeededForFullQraw() external view returns (uint256) {
        (uint256 b, uint256 s) = _backingAndSupply();
        return _dNeed(rawClockLimit(), b, s);
    }

    /*----------  STRATEGIC  ---------------------------------------------*/

    /// @notice Cumulative WETH principal the Rig has routed to the Strategic
    ///         Treasury as the settlement residual leg.
    ///
    /// @dev **Contributed principal — never backing.** Strategic value is not
    ///      Hard backing, is not redeemable, and does not appear in `B` or in
    ///      `B/S` (FR-14.4, FR-9.1). It is reported under its own name for
    ///      exactly that reason.
    function strategicContributed() external view returns (uint256) {
        return RIG.totalStrategicContributed();
    }

    /*----------  INTERNAL  ----------------------------------------------*/

    function _backingAndSupply() private view returns (uint256 b, uint256 s) {
        b = IReserveBacking(RIG.reserve()).backing();
        s = ITokenSupply(RIG.vux()).totalSupply();
    }

    /// @dev `D_need = ceil(Qraw × B_pre / S_pre)` — `Rig._route`'s ceiling term.
    function _dNeed(uint256 qRaw, uint256 b, uint256 s) private pure returns (uint256) {
        return qRaw == 0 ? 0 : Math.mulDiv(qRaw, b, s, Math.Rounding.Ceil);
    }

    /// @dev The WETH a settlement at `price` would deliver to the Reserve —
    ///      `Rig._route`'s `hardTarget`, plus `Rig.take` step 8a's King leg when
    ///      the outgoing King is the Reserve itself.
    ///
    ///      ```
    ///      king       = floor(P × 8000 / 10000)
    ///      retained   = P − king
    ///      hardFloor  = retained − floor(P × 1200 / 10000)
    ///      hardTarget = min(retained, max(hardFloor, D_need))
    ///      ```
    ///
    ///      The basis-point constants are read from the Rig rather than
    ///      redeclared, so this estimate cannot drift from the settlement law by
    ///      a copied literal. That the arithmetic still matches is not assumed:
    ///      `test/lens/LensEstimateParity.t.sol` fuzzes the estimate against
    ///      real settlements and compares it to the emitted `Settled` record.
    function _hardToReserve(uint256 price, uint256 qRaw, uint256 b, uint256 s, bool bootstrap)
        private
        view
        returns (uint256)
    {
        uint256 bpDenom = RIG.BP_DENOM();
        uint256 kingLeg = (price * RIG.SPLIT_KING_BP()) / bpDenom;
        uint256 retained = price - kingLeg;
        uint256 hardFloor = retained - (price * RIG.STRATEGIC_CAP_BP()) / bpDenom;

        uint256 hardTarget = Math.min(retained, Math.max(hardFloor, _dNeed(qRaw, b, s)));
        return bootstrap ? hardTarget + kingLeg : hardTarget;
    }
}
