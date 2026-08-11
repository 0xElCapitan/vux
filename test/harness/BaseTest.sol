// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {Vm} from "./Vm.sol";

/// @title BaseTest — VUX-original minimal assertion base for Foundry tests.
/// @notice Zero external test dependencies (no `forge-std`). Foundry treats a
///         reverting test function as a failing test, so every assertion here
///         simply reverts with a structured reason; no DSTest-style `failed()`
///         storage flag is needed or used.
///
///         Deliberately absent: approximate/tolerance assertions. VUX monetary
///         arithmetic is exact (floor division, Reserve-favouring), so an
///         `assertApproxEq*` helper would let a rounding regression pass. If a
///         future test genuinely needs one, it is added with a stated reason.
abstract contract BaseTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Raised by every failed assertion. `reason` carries the caller's
    ///      message plus the observed and expected values.
    error AssertionFailed(string reason);

    function fail(string memory reason) internal pure {
        revert AssertionFailed(reason);
    }

    function _mismatch(string memory what, string memory actual, string memory expected)
        private
        pure
        returns (string memory)
    {
        return string.concat(what, ": got ", actual, ", expected ", expected);
    }

    // --- boolean ------------------------------------------------------------

    function assertTrue(bool condition, string memory what) internal pure {
        if (!condition) fail(string.concat(what, ": expected true"));
    }

    function assertFalse(bool condition, string memory what) internal pure {
        if (condition) fail(string.concat(what, ": expected false"));
    }

    // --- equality -----------------------------------------------------------

    function assertEq(uint256 actual, uint256 expected, string memory what) internal pure {
        if (actual != expected) fail(_mismatch(what, vm.toString(actual), vm.toString(expected)));
    }

    function assertEq(int256 actual, int256 expected, string memory what) internal pure {
        if (actual != expected) fail(_mismatch(what, vm.toString(actual), vm.toString(expected)));
    }

    function assertEq(address actual, address expected, string memory what) internal pure {
        if (actual != expected) fail(_mismatch(what, vm.toString(actual), vm.toString(expected)));
    }

    function assertEq(bool actual, bool expected, string memory what) internal pure {
        if (actual != expected) fail(_mismatch(what, vm.toString(actual), vm.toString(expected)));
    }

    function assertEq(bytes32 actual, bytes32 expected, string memory what) internal pure {
        if (actual != expected) fail(_mismatch(what, vm.toString(actual), vm.toString(expected)));
    }

    function assertEq(bytes memory actual, bytes memory expected, string memory what) internal pure {
        if (keccak256(actual) != keccak256(expected)) {
            fail(_mismatch(what, vm.toString(actual), vm.toString(expected)));
        }
    }

    function assertEq(string memory actual, string memory expected, string memory what) internal pure {
        if (keccak256(bytes(actual)) != keccak256(bytes(expected))) {
            fail(_mismatch(what, actual, expected));
        }
    }

    function assertNotEq(uint256 actual, uint256 unexpected, string memory what) internal pure {
        if (actual == unexpected) fail(string.concat(what, ": expected value other than ", vm.toString(actual)));
    }

    function assertNotEq(address actual, address unexpected, string memory what) internal pure {
        if (actual == unexpected) fail(string.concat(what, ": expected address other than ", vm.toString(actual)));
    }

    // --- ordering -----------------------------------------------------------

    function assertLt(uint256 a, uint256 b, string memory what) internal pure {
        if (!(a < b)) fail(string.concat(what, ": expected ", vm.toString(a), " < ", vm.toString(b)));
    }

    function assertLe(uint256 a, uint256 b, string memory what) internal pure {
        if (!(a <= b)) fail(string.concat(what, ": expected ", vm.toString(a), " <= ", vm.toString(b)));
    }

    function assertGt(uint256 a, uint256 b, string memory what) internal pure {
        if (!(a > b)) fail(string.concat(what, ": expected ", vm.toString(a), " > ", vm.toString(b)));
    }

    function assertGe(uint256 a, uint256 b, string memory what) internal pure {
        if (!(a >= b)) fail(string.concat(what, ": expected ", vm.toString(a), " >= ", vm.toString(b)));
    }
}
