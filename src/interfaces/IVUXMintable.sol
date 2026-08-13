// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @title IVUXMintable — the VUX token surface the Rig depends on.
/// @notice Declares exactly the two members `Rig` calls, and nothing else — the
///         same narrow-interface discipline `IVUX` applies for the Hard Reserve,
///         and for the same reason: a shared, wider interface would hand every
///         importer a compile-time path to authority it must not have.
///
///         Concretely, `HardReserve` imports `IVUX`. Adding `mint` there would
///         give the Reserve a typed call into the token's mint authority, which
///         is precisely the structural claim the architecture makes impossible
///         (INV-5, prd.md:L585). Two narrow interfaces cost one extra file and
///         keep each contract's reachable surface equal to its actual job.
///
/// @dev Provenance: VUX-original (`GPL-3.0-or-later`). The allowlisted Miner
///      Manifold `IUnit.sol` declares four members (`mint`, `burn`, `setRig`,
///      `rig`); only `mint` overlaps, and it is the ERC-20-conventional
///      `mint(address,uint256)` signature rather than a reproduction of that
///      file's text. `totalSupply()` is the ERC-20 standard signature.
interface IVUXMintable {
    /// @notice Complete supply — no protocol-balance exclusion (INV-1, prd.md:L581).
    ///         This is `S_pre` when read before a settlement's issuance.
    function totalSupply() external view returns (uint256);

    /// @notice Mint gate; reverts unless the caller is the token's immutable
    ///         `rig`. The Rig calls it only inside VEM settlement, only for the
    ///         outgoing King, and only for `Qmint` (INV-4, prd.md:L584).
    function mint(address to, uint256 amount) external;
}
