// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @title Vm — VUX-original minimal Foundry cheatcode interface.
/// @notice The accepted Sprint-1 test-harness decision is the VUX-original
///         minimal base: `forge-std` is NOT vendored and NOT imported, so no
///         source enters the repository outside the accepted provenance census
///         (sprint.md Sprint 1, operator-accepted interpretation 1).
///
///         This file is a VUX-authored *declaration* of the subset of the
///         Foundry test-VM ABI that VUX tests call. It copies no upstream text;
///         it is an interface to the local test runner, not a dependency.
///
///         Cheatcodes are declared here only when a VUX test needs them. The
///         address below is Foundry's well-known cheatcode account,
///         `address(uint160(uint256(keccak256("hevm cheat code"))))`.
interface Vm {
    // --- time and block context (Dutch pricing, halving schedule) ---
    function warp(uint256 newTimestamp) external;
    function roll(uint256 newBlockNumber) external;

    // --- caller identity (narrow-authority gate negatives) ---
    function prank(address sender) external;
    function startPrank(address sender) external;
    function stopPrank() external;

    // --- expected failures (negative suites) ---
    function expectRevert() external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    /// @dev Selector-only match. `expectRevert(bytes4)` requires the revert
    ///      payload to be exactly those four bytes, so an error carrying
    ///      arguments needs this variant.
    function expectPartialRevert(bytes4 revertData) external;

    // --- expected events (event-completeness assertions) ---
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;

    // --- balances and fixture addresses ---
    function deal(address to, uint256 give) external;
    function deal(address token, address to, uint256 give) external;
    function addr(uint256 privateKey) external pure returns (address);
    function label(address account, string calldata newLabel) external;

    // --- fuzzing ---
    function assume(bool condition) external pure;

    // --- filesystem and JSON (build-artifact provenance checks) ---
    function readFile(string calldata path) external view returns (string memory data);
    function parseJsonBytes(string calldata json, string calldata key) external pure returns (bytes memory);

    // --- formatting (assertion messages) ---
    function toString(uint256 value) external pure returns (string memory);
    function toString(int256 value) external pure returns (string memory);
    function toString(address value) external pure returns (string memory);
    function toString(bool value) external pure returns (string memory);
    function toString(bytes32 value) external pure returns (string memory);
    function toString(bytes calldata value) external pure returns (string memory);
}
