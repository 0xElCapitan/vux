// SPDX-License-Identifier: MIT AND GPL-3.0-or-later
pragma solidity =0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title VUX — the protocol token, with exactly two immutable authorities.
/// @notice ERC20 + ERC20Permit whose entire protocol-specific surface is three
///         functions: `mint` (only the immutable `rig`), `burn` (only the
///         caller's own balance), and `burnForRedemption` (only the immutable
///         `reserve`). There is no owner, no role, no pause, no upgrade path,
///         and no setter that can repoint either authority — the two trusted
///         addresses are fixed at construction and are unreachable thereafter
///         (sdd.md:L90, L97).
///
///         `S` is always the complete `totalSupply()` with no protocol-balance
///         exclusion (INV-1, prd.md:L581).
///
/// @dev **Genesis (INV-2/INV-3, FR-1.1, prd.md:L318).** The constructor mints
///      exactly `GENESIS_POL_SUPPLY` to its own creator — structurally the
///      `GenesisDeployer`, which LPs the full amount into the protocol-owned
///      canonical position before the genesis transaction ends — plus
///      `GENESIS_RESERVE_SEED` (one raw unit, the permanent `S_MIN`
///      denominator) to the Hard Reserve, and zero to every other address.
///      The POL recipient is `msg.sender` rather than a constructor parameter
///      precisely so that no argument exists to misdirect the genesis
///      allocation; the same structural choice the Reserve makes for its
///      sanitization receiver (sdd.md:L132). Genesis total supply is therefore
///      exactly `150_000e18 + 1` (INV-2, prd.md:L582).
///
///      **No general `burnFrom`.** The allowance-gated burn of an ancestor is
///      deliberately absent, not merely unused: redemption is one transaction
///      with no prior approval, so nothing needs it, and its absence is what
///      makes "no third party can burn a holder's VUX" a structural claim
///      rather than a policy (sdd.md:L97, L678; FR-7.4, prd.md:L251).
///
/// @dev **Events.** No token-specific event is declared. The accepted event
///      schema (sdd.md §3.2) assigns none to this contract: ERC-20 `Transfer`
///      from/to the zero address already carries every supply change, and the
///      *cause* of each change is carried by the co-emitted event of the
///      contract that caused it (`Redeemed`, `VyrfHarvest`, `Settled`), which is
///      what UC-6 supply attribution requires (prd.md:L267).
///
/// @custom:provenance miner-manifold
///      Materially derived from the allowlisted Miner Manifold surface
///      `contracts/Unit.sol` (blob `26d491eb…`) and
///      `contracts/interfaces/IUnit.sol` (blob `7069422c…`) at pinned commit
///      `bcffbf1eb963810acb14a1fd1c73d03a53a085a8` (PROV-2, prd.md:L761).
///      Upstream author: heesho. Upstream licence: MIT — its notice is
///      reproduced verbatim in `THIRD_PARTY_NOTICES.md`; this file therefore
///      declares `MIT AND GPL-3.0-or-later` per PROV-8. The byte-identical
///      upstream files remain in `vendor/miner-manifold-bcffbf1e/` as the
///      derivation reference; no other token implementation was consulted.
///
/// @custom:modifications 2026-08-11 — VUX modifications to the derived surface:
///      • `ERC20Votes` removed entirely (the token is immutable; any future
///        weighting is computed by an external module, never in the token —
///        sdd.md:L99). The `_afterTokenTransfer`/`_mint`/`_burn` overrides that
///        existed only to satisfy `ERC20Votes` went with it.
///      • `setRig()` and the mutable `rig` storage slot removed; `rig` is an
///        immutable constructor argument. `Unit__InvalidRig` becomes a
///        constructor-time `ZeroAddress` check, since there is no later call at
///        which the address could be re-validated.
///      • Constructor genesis mint added (POL inventory + Reserve seed);
///        upstream minted nothing at construction.
///      • `burnForRedemption` added — a second narrow immutable authority with
///        no upstream counterpart.
///      • Identity changed to name/symbol "VUX"; errors renamed to the accepted
///        `NotRig()`/`NotReserve()` schema (sdd.md §6.1).
///      • `Unit__Minted`/`Unit__Burned` events dropped as redundant with ERC-20
///        `Transfer` (see the events note above).
contract VUX is ERC20, ERC20Permit {
    /// @notice Genesis POL inventory minted to the creator (FR-1.1). Protocol
    ///         liquidity inventory — not a user, founder, or voting allocation.
    uint256 public constant GENESIS_POL_SUPPLY = 150_000e18;

    /// @notice The permanent one-raw-unit `S_MIN` denominator, minted to the
    ///         Hard Reserve, which has no code path that can ever move it.
    uint256 public constant GENESIS_RESERVE_SEED = 1;

    /// @notice The only address that may mint after genesis (INV-4/INV-5).
    address public immutable rig;

    /// @notice The only address that may call `burnForRedemption` (FR-7.4).
    address public immutable reserve;

    error NotRig();
    error NotReserve();
    error ZeroAddress();

    /// @param rig_     The immutable settlement contract; the sole post-genesis
    ///                 mint authority.
    /// @param reserve_ The immutable Hard Reserve; the sole redemption-burn
    ///                 authority and holder of the `S_MIN` seed.
    constructor(address rig_, address reserve_) ERC20("VUX", "VUX") ERC20Permit("VUX") {
        if (rig_ == address(0) || reserve_ == address(0)) revert ZeroAddress();
        rig = rig_;
        reserve = reserve_;

        _mint(msg.sender, GENESIS_POL_SUPPLY);
        _mint(reserve_, GENESIS_RESERVE_SEED);
    }

    /// @notice Mint `amount` to `to`. Only the immutable `rig` may call this;
    ///         every other caller reverts. There is no other mint path — no
    ///         treasury, POL, governance, recovery, migration, recapitalization,
    ///         or discretionary mint exists (INV-5, prd.md:L585).
    function mint(address to, uint256 amount) external {
        if (msg.sender != rig) revert NotRig();
        _mint(to, amount);
    }

    /// @notice Burn `amount` of the caller's own VUX. This is the treasury's
    ///         VYRF / F-46 burn path, since the treasury burns only VUX it owns.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Burn `q` VUX from `from` as part of redemption. Only the
    ///         immutable `reserve` may call this. The Reserve's immutable code
    ///         passes only `msg.sender`, so no caller can direct it at another
    ///         holder; this gate is the second, independent barrier.
    function burnForRedemption(address from, uint256 q) external {
        if (msg.sender != reserve) revert NotReserve();
        _burn(from, q);
    }
}
