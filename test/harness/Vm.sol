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
    /// @dev One emitted log, as returned by `getRecordedLogs`.
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    // --- time and block context (Dutch pricing, halving schedule) ---
    function warp(uint256 newTimestamp) external;
    function roll(uint256 newBlockNumber) external;
    /// @dev Reads the current timestamp through a call the optimizer cannot fold
    ///      away. Since Sprint 3 the VUX unit compiles with `via_ir` +
    ///      `optimizer` (foundry.toml), and `TIMESTAMP` is genuinely invariant
    ///      within a real transaction — so the optimizer is entitled to evaluate
    ///      `block.timestamp` once and reuse it. `vm.warp` violates that
    ///      assumption, which silently breaks any test that reads
    ///      `block.timestamp` both **before and after** a warp in one frame: both
    ///      reads collapse to the same value. Use this instead in that shape.
    ///      A single read per frame is unaffected.
    function getBlockTimestamp() external view returns (uint256);

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
    /// @dev `expectEmit` proves an event WAS emitted. Exhaustive claims — "the
    ///      genesis constructor credited no other address", "no sanitization
    ///      event fired" — are claims about the COMPLETE log set, which only
    ///      capture-and-enumerate can support.
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory logs);

    // --- raw storage inspection ---
    /// @dev FR-5.5 requires that no storage cell anywhere records the unmet
    ///      `Qraw − Qsafe`. That is a claim about the absence of state, which no
    ///      getter can demonstrate — a contract without a getter can still hold
    ///      the value. Reading the slots directly is the only way to assert it.
    function load(address target, bytes32 slot) external view returns (bytes32);

    // --- balances and fixture addresses ---
    function deal(address to, uint256 give) external;
    function deal(address token, address to, uint256 give) external;
    function addr(uint256 privateKey) external pure returns (address);
    function label(address account, string calldata newLabel) external;

    // --- CREATE address prediction ---
    /// @dev The VUX↔HardReserve immutable references form a 2-cycle, so one edge
    ///      is always constructed against a predicted address (sdd.md:L157). Test
    ///      fixtures reproduce that production topology rather than inventing a
    ///      setter, so they need the same prediction the deployer performs.
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);

    // --- fuzzing ---
    function assume(bool condition) external pure;

    // --- filesystem and JSON (build-artifact provenance checks) ---
    function readFile(string calldata path) external view returns (string memory data);
    function parseJsonBytes(string calldata json, string calldata key) external pure returns (bytes memory);
    /// @dev Object keys at `key`. Over a build artifact's `.methodIdentifiers`
    ///      this yields the contract's complete external signature set, which is
    ///      how the structural-absence claims are proven against the compiled
    ///      ABI rather than against the source text.
    function parseJsonKeys(string calldata json, string calldata key) external pure returns (string[] memory keys);

    // --- formatting (assertion messages) ---
    function toString(uint256 value) external pure returns (string memory);
    function toString(int256 value) external pure returns (string memory);
    function toString(address value) external pure returns (string memory);
    function toString(bool value) external pure returns (string memory);
    function toString(bytes32 value) external pure returns (string memory);
    function toString(bytes calldata value) external pure returns (string memory);
}
