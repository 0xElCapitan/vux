// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @title IVUXBurnable — the VUX token surface the Strategic Treasury depends on.
/// @notice One member: the self-burn. Same narrow-interface discipline as `IVUX`
///         (Reserve) and `IVUXMintable` (Rig), and for the same structural
///         reason — a shared, wider interface would hand the treasury a
///         compile-time path to `mint` or `burnForRedemption`, the two
///         authorities the treasury must provably not reach (INV-5,
///         prd.md:L585; FR-10.3 no-redeem-path).
///
///         `burn` acts on the caller's own balance only, so it confers nothing:
///         the treasury can destroy VUX it owns and can do nothing to VUX it
///         does not. That is exactly the F-46 treatment — VUX-denominated
///         non-POL revenue is burned, and `burnVuxRevenue()` is the only path
///         (sdd.md:L318).
///
/// @dev Provenance: VUX-original (`GPL-3.0-or-later`). The allowlisted Miner
///      Manifold `IUnit.sol` declares four members (`mint`, `burn`, `setRig`,
///      `rig`); `burn(uint256)` overlaps only in the sense that both name the
///      ERC-20-conventional self-burn signature. No text is reproduced.
interface IVUXBurnable {
    /// @notice Burn `amount` of the caller's own VUX. No allowance, no third
    ///         party, no `from` parameter — there is nothing here to misdirect.
    function burn(uint256 amount) external;
}
