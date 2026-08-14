// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {ILSGModule, ILSGRewardProgram} from "../../src/interfaces/ILSGModule.sol";

/// @title MockLsgModule — TEST ONLY. A signal source, nothing more.
/// @notice The real module is P1 and is deliberately not built in this sprint —
///         no stake, no epoch, no weighting algorithm, no reward accrual, no
///         threshold, no calendar (sprint.md Sprint 4 P1 tripwire; F-50). What
///         Sprint 4 must test is the *treasury side* of the boundary: that
///         consumption is a read, that the split it produces is clamped by
///         admission and caps, and that nothing a module says can reach anything
///         else. A stored answer is therefore exactly the right fidelity — a
///         real weighting mechanism would test P1 code that does not exist.
///
///         `setMismatchedLengths` returns parallel arrays of different lengths,
///         the malformed answer the treasury must reject rather than interpret.
contract MockLsgModule is ILSGModule, ILSGRewardProgram {
    address[] private _strategies;
    uint256[] private _weights;
    bool public mismatchedLengths;

    struct Program {
        address token;
        uint256 amount;
        uint64 start;
        uint64 end;
    }

    Program[] public programs;

    function setSignal(address[] calldata strategies, uint256[] calldata weights) external {
        delete _strategies;
        delete _weights;
        for (uint256 i = 0; i < strategies.length; i++) {
            _strategies.push(strategies[i]);
        }
        for (uint256 i = 0; i < weights.length; i++) {
            _weights.push(weights[i]);
        }
    }

    function setMismatchedLengths(bool value) external {
        mismatchedLengths = value;
    }

    function currentAllocationSignal() external view returns (address[] memory strategies, uint256[] memory weights) {
        strategies = _strategies;
        weights = _weights;
        if (mismatchedLengths) weights = new uint256[](_weights.length + 1);
    }

    function fundSignalerProgram(address token, uint256 amount, uint64 start, uint64 end) external {
        programs.push(Program({token: token, amount: amount, start: start, end: end}));
    }

    function programCount() external view returns (uint256) {
        return programs.length;
    }
}
