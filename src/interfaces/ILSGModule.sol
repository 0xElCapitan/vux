// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @title ILSGModule — the signal-only LSG boundary (P0).
/// @notice The complete authority the treasury grants an activated LSG module:
///         one `view`. No transfer authority, no admission authority, no role.
///         "the treasury never grants the module any transfer, admission, or
///         role authority" (sdd.md:L146), which is what makes every
///         LSG-prohibited authority structurally unreachable rather than merely
///         un-exercised (FR-13.3, prd.md:L523; INV-33).
///
///         Consumption is a read: `deployMarginalBySignal` reads this, filters
///         to admitted + matured + cap-headroom targets, and deploys through the
///         same principal ledger as manual deployment (sdd.md:L337). The module
///         proposes a *split*; it can never propose a recipient, an amount, or a
///         moment.
///
/// @dev The module *implementation* is P1 and is deliberately absent from this
///      sprint — no weighting, no epoch, no stake, no reward logic, no
///      threshold, no calendar (sprint.md Sprint 4 P1 tripwire; F-50). Only the
///      interface, the activation slot, and the treasury-side consumption ship
///      at P0.
///
/// @dev **Provenance — `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED`** (DELTA §3/§4).
///      Designed from the PRD boundary only; the pinned external
///      signal-governance repository remains prohibited source (PROV-4) and was
///      not consulted (sdd.md:L324).
interface ILSGModule {
    /// @notice The current relative preference over admitted strategies.
    /// @dev Parallel arrays; weights are relative and unnormalized. The treasury
    ///      rejects a length-mismatched answer outright rather than guessing at
    ///      the intent of a module it does not implement.
    function currentAllocationSignal()
        external
        view
        returns (address[] memory strategies, uint256[] memory weights);
}

/// @title ILSGRewardProgram — the module-side entry point for PROTOCOL-provenance
///        signaler rewards.
/// @notice Split out of `ILSGModule` deliberately. The accepted signal interface
///         is exactly one `view` (sdd.md:L769-L772) and widening it would blur
///         the boundary argument above; this second, equally narrow interface
///         carries the one call the treasury's `fundSignalerProgram` must make
///         to register a revenue-funded program on the active module
///         (sdd.md:L779-L780). It confers nothing on the module: the treasury
///         pushes the exact funded amount and then calls, so no allowance, role,
///         or standing authority is created.
interface ILSGRewardProgram {
    /// @notice Register a PROTOCOL-provenance reward program funded by the
    ///         treasury's revenue-bounded earmark.
    function fundSignalerProgram(address token, uint256 amount, uint64 start, uint64 end) external;
}
