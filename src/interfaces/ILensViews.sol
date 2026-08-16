// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @title ILensViews — the exact read-only surface `Lens` is permitted to reach.
/// @notice `Lens` is a truth surface with no authority of any kind (FR-14,
///         sdd.md:L706-L715). The narrow-interface discipline `IVUX` /
///         `IVUXMintable` established for the monetary core applies here for the
///         same structural reason, and with more force: importing `Rig`,
///         `VUX`, or `IERC20` directly would hand `Lens` a compile-time path to
///         `take`, `mint`, `burnForRedemption`, `transfer`, and `approve`. The
///         requirement is that no such path exists, so the types that would
///         carry one are not imported at all.
///
///         Grouped in one file on purpose: these three declarations are a single
///         cohesive fact — "everything `Lens` may read, and nothing else" — and
///         reviewing that claim means reading one file rather than reassembling
///         it from three. Each interface is separately named so a future reader
///         can see which contract each member belongs to.
///
/// @dev Every member here is `view`. `Lens` therefore compiles to `STATICCALL`
///      for all outbound reads, which `test/lens/LensSurface.t.sol` asserts
///      against the deployed runtime image rather than against this comment.
///
/// @dev Provenance: VUX-original (`GPL-3.0-or-later`). `totalSupply()` and the
///      accessor shapes are ERC-20 / Solidity-standard signatures; no upstream
///      interface text is reproduced.

/// @notice The `Rig` members `Lens` reads. Deliberately **excludes** `take` — the
///         Rig's only state-changing function — so no typed settlement path
///         reaches `Lens`.
/// @dev `reserve()` and `vux()` are declared as `address` rather than as the
///      contract types `Rig` actually returns. The ABI encoding is identical
///      (a contract type is an `address`), so the call is the same call, but the
///      returned handle carries no authority members. `vux()` in particular
///      returns `IVUXMintable` on `Rig`; taking it as `address` is what keeps
///      `mint` unreachable from this contract.
interface IRigViews {
    function currentPrice() external view returns (uint256);

    function epochState()
        external
        view
        returns (address king, uint64 epochStart, uint256 epochOpening, uint256 epochUPS, bool bootstrap);

    function totalStrategicContributed() external view returns (uint256);

    function reserve() external view returns (address);

    function vux() external view returns (address);

    // Routing-law constants (`public constant` getters on `Rig`). Read from the
    // Rig rather than redeclared here, so the estimate cannot drift from the
    // settlement law by a copied literal.
    function EPOCH_PERIOD() external view returns (uint256);
    function SPLIT_KING_BP() external view returns (uint256);
    function STRATEGIC_CAP_BP() external view returns (uint256);
    function BP_DENOM() external view returns (uint256);
}

/// @notice The `HardReserve` member `Lens` reads. Excludes `redeem`.
/// @dev `B` is authority-defined as the Reserve's physical WETH balance
///      (INV-10, prd.md:L595), and `backing()` is that definition's on-chain
///      expression. Reading it here — rather than reaching for the WETH token
///      and calling `balanceOf` — means `Lens` holds no ERC-20 handle at all,
///      and so has no `transfer` or `approve` path even by address.
interface IReserveBacking {
    function backing() external view returns (uint256);
}

/// @notice The `VUX` member `Lens` reads. Excludes `mint`, `burnForRedemption`,
///         and the whole ERC-20 mutator surface.
interface ITokenSupply {
    /// @notice Complete supply — `S`. No protocol-balance exclusion (INV-1).
    function totalSupply() external view returns (uint256);
}
