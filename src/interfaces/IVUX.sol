// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @title IVUX — the VUX token surface the Hard Reserve depends on.
/// @notice Declares exactly the two members `HardReserve` calls, and nothing
///         else. A wider interface would let a future consumer reach token
///         authority through this file rather than through the token's own
///         immutable gates, so it is deliberately not a mirror of the token ABI.
///
/// @dev Provenance: VUX-original (`GPL-3.0-or-later`). This reproduces no
///      declaration from the allowlisted Miner Manifold `IUnit.sol` — none of
///      that interface's four members (`mint`, `burn`, `setRig`, `rig`) appears
///      here. `totalSupply()` is the ERC-20 standard signature and
///      `burnForRedemption` is the VUX-original redemption-burn gate (sdd.md:L97),
///      which has no upstream counterpart.
interface IVUX {
    /// @notice Complete supply — no protocol-balance exclusion (INV-1, prd.md:L581).
    function totalSupply() external view returns (uint256);

    /// @notice Redemption-burn gate; reverts unless the caller is the token's
    ///         immutable `reserve`. The Reserve passes only `msg.sender`.
    function burnForRedemption(address from, uint256 q) external;
}
