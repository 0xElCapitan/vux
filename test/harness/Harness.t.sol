// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {BaseTest} from "./BaseTest.sol";

/// @dev External surface over the internal assertion helpers. `vm.expectRevert`
///      only observes external calls, so the failure paths are exercised
///      through this probe.
contract AssertionProbe is BaseTest {
    function eqUint(uint256 a, uint256 b) external pure {
        assertEq(a, b, "probe");
    }

    function eqBytes32(bytes32 a, bytes32 b) external pure {
        assertEq(a, b, "probe");
    }

    function isTrue(bool c) external pure {
        assertTrue(c, "probe");
    }

    function lt(uint256 a, uint256 b) external pure {
        assertLt(a, b, "probe");
    }
}

/// @title HarnessTest — the VUX-original test harness verifies itself.
/// @notice An assertion library that never fails would silently green the whole
///         suite, so the failure paths are asserted directly: each check proves
///         the helper reverts on a false claim AND that the reported message is
///         the expected one.
contract HarnessTest is BaseTest {
    AssertionProbe internal probe;

    function setUp() public {
        probe = new AssertionProbe();
    }

    function test_PassingAssertionsDoNotRevert() public pure {
        assertTrue(true, "true is true");
        assertFalse(false, "false is false");
        assertEq(uint256(7), uint256(7), "uint equality");
        assertEq(int256(-7), int256(-7), "int equality");
        assertEq(address(0xBEEF), address(0xBEEF), "address equality");
        assertEq(true, true, "bool equality");
        assertEq(keccak256("vux"), keccak256("vux"), "bytes32 equality");
        assertEq(bytes("vux"), bytes("vux"), "bytes equality");
        // Explicit `string` cast: a bare literal is ambiguous across the
        // assertEq overload set.
        assertEq(string("vux"), string("vux"), "string equality");
        assertNotEq(uint256(1), uint256(2), "uint inequality");
        assertNotEq(address(1), address(2), "address inequality");
        assertLt(1, 2, "lt");
        assertLe(2, 2, "le");
        assertGt(2, 1, "gt");
        assertGe(2, 2, "ge");
    }

    function test_FailingUintEqualityRevertsWithValues() public {
        vm.expectRevert(
            abi.encodeWithSelector(BaseTest.AssertionFailed.selector, "probe: got 1, expected 2")
        );
        probe.eqUint(1, 2);
    }

    function test_FailingBytes32EqualityReverts() public {
        vm.expectPartialRevert(BaseTest.AssertionFailed.selector);
        probe.eqBytes32(keccak256("a"), keccak256("b"));
    }

    function test_FailingAssertTrueReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(BaseTest.AssertionFailed.selector, "probe: expected true")
        );
        probe.isTrue(false);
    }

    function test_FailingOrderingReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(BaseTest.AssertionFailed.selector, "probe: expected 2 < 1")
        );
        probe.lt(2, 1);
    }

    /// @dev Fuzzed: equality must hold for every value, and inequality must be
    ///      reported for every distinct pair.
    function testFuzz_EqualityIsExact(uint256 a, uint256 b) public {
        assertEq(a, a, "reflexive");
        vm.assume(a != b);
        vm.expectPartialRevert(BaseTest.AssertionFailed.selector);
        probe.eqUint(a, b);
    }
}
