// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @title IStrategyAdapter — the measurement surface an admitted Strategy exposes.
/// @notice The §1.10 recognition architecture keeps classification **arithmetic,
///         not declaration**: there is no `declareProfit`, no operator
///         declaration, and no oracle (sdd.md:L289). What the treasury needs
///         from a Strategy is therefore not a claim about profit but the two
///         raw measurements the accepted guards are computed from — a position
///         size (`principalUnits`) and the list of assets a harvest may deliver
///         — plus the calls that make value move.
///
///         Every amount the treasury books is measured from **its own balance
///         deltas**, never from a return value here (sdd.md:L294). An adapter
///         that lies about `principalUnits()` to manufacture "revenue" can, by
///         the same lie, simply steal the funds: classification fraud is
///         strictly no more powerful than theft, and both are bounded by the
///         same admission diligence, per-(strategy, asset) caps, 24 h maturity,
///         instant removal, and Strategic-only blast radius (sdd.md:L302).
///
/// @dev **Not every member applies to every mode.** A mode is a permission set
///      over the flow primitives (sdd.md:L297), so it is also a permission set
///      over this interface:
///
///      | mode        | members the treasury calls                        |
///      |-------------|---------------------------------------------------|
///      | `NETTING`   | `recall`                                          |
///      | `CLAIM`     | `recall`, `principalUnits`, `rewardAssets`, `harvest` |
///      | `UNITIZED`  | `recall`, `principalUnits`, `rewardAssets`, `harvest`, `deposit`, `redeem` |
///
///      A `NETTING` target is expected to be opaque — "no verifiable position
///      handle" (sdd.md:L293) — and returns value by pushing it back through the
///      permissionless `returnFor`, which needs nothing from this interface.
///
/// @dev **Provenance:** `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` (DELTA §3). No
///      external vault, adapter, or strategy-registry implementation was
///      consulted; the shape is derived from the accepted §1.10 guards alone.
interface IStrategyAdapter {
    /// @notice The Strategy's current principal position size, in its own units.
    /// @dev Read only as a *delta* or as an ordering guard, never as a value:
    ///      `harvestYield` requires it not to have decreased across the harvest
    ///      (a "harvest" that shrank the position is not yield), and `UNITIZED`
    ///      deployment records units by the measured increase.
    function principalUnits() external view returns (uint256);

    /// @notice The assets a harvest may deliver.
    /// @dev The treasury measures its own balance delta in each of these and
    ///      credits nothing else, so an omitted asset is unrecognised revenue —
    ///      conservative — and a duplicated one is credited exactly once.
    function rewardAssets() external view returns (address[] memory);

    /// @notice Realise claim-style yield into the treasury's own balances.
    /// @dev Must push rewards to the caller. Whatever it reports is ignored.
    function harvest() external;

    /// @notice Take custody of `amount` of `asset`, already transferred, into the
    ///         unitized position.
    /// @dev `UNITIZED` only, and called *after* the transfer: the treasury pushes
    ///      first and instructs second, so no allowance ever exists.
    function deposit(address asset, uint256 amount) external;

    /// @notice Redeem `units` of the unitized position, pushing the proceeds to
    ///         the caller.
    /// @dev No `minOut` parameter: the slippage bound is applied by the treasury
    ///      against its own measured receipt, where it cannot be misreported.
    function redeem(uint256 units) external;

    /// @notice Return `amount` of `asset` to the caller.
    /// @dev The operator-held recall path. Instant and unblockable by design —
    ///      no signal, admission state, or module can gate it (UC-10,
    ///      prd.md:L303-L306).
    function recall(address asset, uint256 amount) external;
}
