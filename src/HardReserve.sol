// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IVUX} from "./interfaces/IVUX.sol";

/// @title HardReserve — the enforceable exit right.
/// @notice Holds raw canonical WETH and pays it out pro rata against burned
///         VUX. It does one monetary job and has no second one: no treasury, no
///         strategy, no NAV, no oracle, no yield, no receivable, no accounting
///         cell of any kind (prd.md:L739, FR-7.1).
///
///         Backing is *defined* as the physical balance:
///         `B = WETH.balanceOf(address(this))` (INV-10, prd.md:L595). Accretion
///         — settlement legs, VYRF WETH fees, donations — is a plain ERC-20
///         transfer in. There is deliberately no deposit function to gate and
///         no shadow balance to corrupt.
///
/// @dev **Structural absences are the design** (FR-7.2, INV-14, prd.md:L599).
///      The deployed contract has: no owner, no roles, no pause, no upgrade or
///      proxy path, no arbitrary call, no token approval, no sweep, no
///      successor or migration, no emergency or discretionary principal
///      movement, no `receive`/`fallback`, no payable function, no
///      `selfdestruct`, and no generic deposit. Its entire state-changing
///      external surface is `redeem`. This is enforced by *not writing* those
///      paths, and verified mechanically rather than by assertion — see
///      `test/reserve/ReserveSurface.t.sol` (ABI enumeration + runtime-opcode
///      absence) and `tools/provenance/inspect-runtime-surface.sh`.
///
/// @dev **Provenance — PROV-5 (prd.md:L764).** `VUX_ORIGINAL_CLEAN_SOURCE`.
///      Implemented from the canonical VUX equations and the accepted
///      architecture (prd.md FR-7, sdd.md:L125-L133) only. No redemption,
///      treasury, bonding, or reserve implementation from any prohibited or
///      unenumerated project was consulted as an implementation source. The
///      required similarity statement is recorded in
///      `grimoires/loa/a2a/sprint-2/evidence/prov-5-similarity-review.md`;
///      it is kept out of this file on purpose, because naming those projects
///      in Solidity source would trip the repository's own prohibited-source
///      detector (`tools/provenance/verify-census.sh`).
contract HardReserve is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The permanent supply floor: one raw VUX unit, held by this
    ///         contract, which has no code path that can transfer it. Redemption
    ///         may never reduce `S` below it, so the `B/S` denominator stays
    ///         live and full external redemption leaves a positive WETH
    ///         remainder (FR-7.5, prd.md:L419).
    uint256 public constant S_MIN = 1;

    /// @notice Canonical RH WETH — the only asset this contract holds or pays.
    IERC20 public immutable weth;

    /// @notice The VUX token. Redemption burns through its `reserve`-gated
    ///         `burnForRedemption`, so no allowance is ever needed.
    IVUX public immutable vux;

    error ZeroAddress();
    /// @dev `q` would push supply below `S_MIN`.
    error SupplyFloor(uint256 q, uint256 maxRedeemable);
    /// @dev Construction could not complete with a zero WETH balance.
    error NotBornEmpty(uint256 residual);

    /// @notice Accepted schema (sdd.md §3.2). `bPre`/`sPre` are the
    ///         pre-redemption values the payout was computed from, so an
    ///         indexer can re-derive `payout` from the log alone.
    event Redeemed(
        address indexed redeemer, address indexed to, uint256 q, uint256 payout, uint256 bPre, uint256 sPre
    );

    /// @notice Emitted only from the constructor (sdd.md §3.2) — see below.
    event PreGenesisWethSanitized(uint256 amount);

    /// @notice Deploys an empty Reserve, sanitizing any pre-existing WETH.
    ///
    /// @dev **Constructor-time contamination sanitization** (sdd.md:L132). `B`
    ///      is authority-defined as this address's physical WETH balance, and
    ///      anyone can transfer WETH to an address before its code exists. Left
    ///      alone, an adversary's prefunding would be baked into genesis backing
    ///      — distorting physical `N0 = B0/S0` and `P0/N0`, and suppressing early
    ///      `Qsafe` through an inflated `B_pre`. So the first act of
    ///      construction is to read that balance, send the *entire* pre-existing
    ///      amount to `msg.sender` — the creator, structurally the
    ///      `GenesisDeployer`; a fixed same-transaction receiver with no
    ///      parameter that could misdirect it — and require the balance to be
    ///      exactly zero before construction completes. Exactness is preserved,
    ///      never relaxed to `>=`, and the donation earns zero mint credit.
    ///
    ///      **This capability does not survive deployment.** Constructor code is
    ///      init code: it is executed once and discarded, and is not part of the
    ///      runtime bytecode. The deployed contract therefore contains no
    ///      transfer-out, sweep, recovery, or admin path at all. That is a
    ///      falsifiable claim about bytes, not a comment: the
    ///      `PreGenesisWethSanitized` topic is a 32-byte constant that must
    ///      appear in the creation bytecode and must NOT appear in the deployed
    ///      runtime bytecode, which is asserted in CI
    ///      (`test/reserve/ReserveSurface.t.sol`) and independently reproducible
    ///      via `tools/provenance/inspect-runtime-surface.sh`.
    ///
    /// @param weth_ Canonical RH WETH.
    /// @param vux_  The VUX token. At genesis this is a CREATE-predicted address
    ///              whose equality with the real deployment is verified
    ///              in-transaction by the `GenesisDeployer` (Sprint 7).
    constructor(address weth_, address vux_) {
        if (weth_ == address(0) || vux_ == address(0)) revert ZeroAddress();
        weth = IERC20(weth_);
        vux = IVUX(vux_);

        uint256 contaminated = IERC20(weth_).balanceOf(address(this));
        if (contaminated != 0) {
            IERC20(weth_).safeTransfer(msg.sender, contaminated);
            emit PreGenesisWethSanitized(contaminated);
        }

        // Re-read rather than assume the transfer moved the full amount: a
        // fee-on-transfer or rebasing token would leave a residual, and being
        // born non-empty must fail loudly rather than silently redefine `B0`.
        uint256 residual = IERC20(weth_).balanceOf(address(this));
        if (residual != 0) revert NotBornEmpty(residual);
    }

    /// @notice Redeem `q` VUX for a pro-rata share of the Reserve's WETH.
    ///
    /// @dev One transaction, no prior approval, zero fee (FR-7.4, prd.md:L251).
    ///      Ordering is CEI and is load-bearing: snapshot `B`/`S` *before* any
    ///      effect, compute against those pre-redemption values, burn, then pay.
    ///
    ///      `payout = floor(B × q / S)` is computed with `Math.mulDiv`, a
    ///      full-precision 512-bit intermediate — a plain `B * q` would overflow
    ///      for large backing and supply, and reverting there would be a denial
    ///      of the exit right, not a safety property. Flooring leaves the
    ///      remainder in the Reserve, which is the required Reserve-favoring
    ///      rounding direction (INV-16, prd.md:L601).
    ///
    ///      The burn source is `msg.sender` and nothing else. It is not a
    ///      parameter and not derived from one, so no caller can steer this
    ///      contract at another holder's balance; the token-side `onlyReserve`
    ///      gate is the independent second barrier.
    ///
    ///      Whole-transaction atomicity is the failure mode: a failed burn or a
    ///      failed/false-returning WETH transfer reverts everything. There is no
    ///      partial-success path (sdd.md §6.1).
    ///
    /// @param q  VUX to burn from the caller. Must leave `S >= S_MIN`.
    /// @param to Recipient of the WETH payout.
    /// @return payout WETH paid, `floor(B × q / S)` on pre-redemption values.
    function redeem(uint256 q, address to) external nonReentrant returns (uint256 payout) {
        // Malformed-input rejection, not a policy gate: it is static, applies to
        // no address but the caller's own argument, and blocks no redemption
        // that could otherwise pay out. Canonical WETH would credit the zero
        // address happily, destroying the payout after the burn had committed.
        if (to == address(0)) revert ZeroAddress();

        uint256 bPre = weth.balanceOf(address(this));
        uint256 sPre = vux.totalSupply();

        // `sPre >= S_MIN` always holds: the seed is minted to this contract at
        // genesis and no code path here can transfer or burn it. Were that ever
        // false, this subtraction panics rather than silently permitting a
        // redemption that drains the denominator.
        uint256 maxRedeemable = sPre - S_MIN;
        if (q > maxRedeemable) revert SupplyFloor(q, maxRedeemable);

        payout = Math.mulDiv(bPre, q, sPre);

        vux.burnForRedemption(msg.sender, q);
        weth.safeTransfer(to, payout);

        emit Redeemed(msg.sender, to, q, payout, bPre, sPre);
    }

    /// @notice `B` — raw canonical WETH physically held (INV-10).
    function backing() external view returns (uint256) {
        return weth.balanceOf(address(this));
    }

    /// @notice `floor(B × q / S)` at current state. A quotation, not an
    ///         entitlement: `B` and `S` move, and nothing here reserves value.
    function previewRedeem(uint256 q) external view returns (uint256) {
        return Math.mulDiv(weth.balanceOf(address(this)), q, vux.totalSupply());
    }
}
