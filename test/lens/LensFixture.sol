// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {RigFixture} from "../rig/RigFixture.sol";
import {Lens} from "../../src/Lens.sol";

/// @title LensFixture — the Rig topology with a Lens pointed at it.
/// @notice `Lens` reads the live monetary core, so its tests run against the
///         real `RigFixture` wiring rather than against stubs. A Lens over
///         mocked reads would only prove that the Lens can divide.
///
///         The Lens is deployed *after* genesis on purpose: it takes only the
///         Rig address and derives the Reserve and the token from it at call
///         time, so there is no deployment ordering to get right and no wiring
///         assertion to make. That absence is the design (sdd.md:L706).
abstract contract LensFixture is RigFixture {
    Lens internal lens;

    function _deployLens() internal {
        lens = new Lens(address(rig));
    }

    /// @dev Read the tier-2 estimate, then settle **in the same block**, and
    ///      return both the estimate and the record the settlement emitted.
    ///      Nothing between the two calls advances `block.timestamp`, so the
    ///      estimate and the settlement see identical price, backing and supply
    ///      — which is exactly the condition under which parity is claimed.
    function _estimateThenSettle(address contender)
        internal
        returns (
            uint256 estimateQmint,
            uint256 estPrice,
            uint256 estQRaw,
            uint256 estQSafe,
            SettledRecord memory record
        )
    {
        (estimateQmint, estPrice, estQRaw, estQSafe) = lens.estimateIfDisplacedNow();
        record = _takeRecorded(contender);
    }

    /// @dev Assert full four-field parity between a tier-2 estimate and the
    ///      settlement that immediately followed it.
    function _assertParity(
        uint256 estimateQmint,
        uint256 estPrice,
        uint256 estQRaw,
        uint256 estQSafe,
        SettledRecord memory r,
        string memory context
    ) internal pure {
        assertEq(estPrice, r.price, string.concat(context, ": price"));
        assertEq(estQRaw, r.qRaw, string.concat(context, ": qRaw"));
        assertEq(estQSafe, r.qSafe, string.concat(context, ": qSafeEst vs settled qSafe"));
        assertEq(estimateQmint, r.qMint, string.concat(context, ": estimateQmint vs settled qMint"));
    }
}
