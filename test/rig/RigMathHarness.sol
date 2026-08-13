// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {Rig} from "../../src/Rig.sol";

/// @title RigMathHarness — external access to the two frozen pure formulas.
/// @notice The FR-4 and FR-5 acceptance criteria are stated as properties over
///         **all** `(P, Qraw, B_pre, S_pre)` and `(B_pre, S_pre, D_R, Qraw)`, but
///         a live settlement cannot construct all of those tuples: `D_R` is
///         determined by the routing law, not chosen, and `B_pre`/`S_pre` move
///         only in the ways settlement and redemption allow. Driving the pure
///         functions directly is what makes the quantifier real rather than
///         "every tuple we happened to be able to reach".
///
///         This is a subclass, not a reimplementation: the code under test is
///         the production code, reached through a thin `external pure` wrapper
///         that adds no arithmetic of its own.
///
/// @dev The wrappers are `pure`, which is itself a mechanical statement about
///      the law: neither formula can read storage, balances, timestamps, or any
///      other signal, because the compiler forbids it (FR-4.3).
contract RigMathHarness is Rig {
    constructor(address weth_, address reserve_, address vux_, address treasury_)
        Rig(weth_, reserve_, vux_, treasury_, 25 ether, 5 ether, 0.5 ether)
    {}

    function route(uint256 price, uint256 qRaw, uint256 bPre, uint256 sPre)
        external
        pure
        returns (uint256 kingLeg, uint256 hardTarget, uint256 strategicLeg)
    {
        return _route(price, qRaw, bPre, sPre);
    }

    function vem(uint256 dR, uint256 sPre, uint256 bPre, uint256 qRaw)
        external
        pure
        returns (uint256 qSafe, uint256 qMint)
    {
        return _vem(dR, sPre, bPre, qRaw);
    }
}
