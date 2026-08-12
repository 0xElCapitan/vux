// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @title Artifact — VUX-original helpers for reasoning about compiled output.
/// @notice Structural-absence claims ("no sweep survives deployment", "no
///         `burnFrom` exists") are claims about the *compiled artifact*, not
///         about the source text. Reading the source and not finding a sweep
///         function proves nothing a reviewer could not already see; reading the
///         emitted bytecode and ABI does. These helpers are the mechanical part
///         of that, kept out of the test files so both the token and the Reserve
///         suites assert against one implementation.
library Artifact {
    // EVM opcodes whose presence or absence carries a structural claim.
    uint8 internal constant OP_CREATE = 0xf0;
    uint8 internal constant OP_CALL = 0xf1;
    uint8 internal constant OP_CALLCODE = 0xf2;
    uint8 internal constant OP_DELEGATECALL = 0xf4;
    uint8 internal constant OP_CREATE2 = 0xf5;
    uint8 internal constant OP_STATICCALL = 0xfa;
    uint8 internal constant OP_SELFDESTRUCT = 0xff;

    /// @notice Strip the trailing solc metadata section from a bytecode image.
    /// @dev solc appends CBOR metadata followed by a two-byte big-endian length
    ///      of that CBOR section. Those bytes are *data*, not code, so an
    ///      opcode walk must not see them: a stray `0xf4` inside a metadata hash
    ///      would otherwise read as a DELEGATECALL and turn a true
    ///      structural-absence claim into a random false positive. Deriving the
    ///      length from the suffix works whether `bytecode_hash` is `ipfs` or
    ///      `none`, so this does not silently depend on a build setting.
    ///      Returns the input unchanged if the suffix is not a plausible length.
    function stripMetadata(bytes memory code) internal pure returns (bytes memory stripped) {
        if (code.length < 2) return code;
        uint256 metaLen = (uint256(uint8(code[code.length - 2])) << 8) | uint256(uint8(code[code.length - 1]));
        if (metaLen == 0 || metaLen + 2 > code.length) return code;

        uint256 n = code.length - metaLen - 2;
        stripped = new bytes(n);
        for (uint256 i = 0; i < n; i++) {
            stripped[i] = code[i];
        }
    }

    /// @notice Count occurrences of `op` as an executed opcode.
    /// @dev Walks the image skipping PUSH1..PUSH32 immediates (`0x60`..`0x7f`),
    ///      so a byte that merely appears inside a pushed constant is not
    ///      mistaken for an instruction. PUSH0 (`0x5f`) carries no immediate.
    ///      Callers should pass `stripMetadata(...)` output.
    function countOpcode(bytes memory code, uint8 op) internal pure returns (uint256 n) {
        uint256 i = 0;
        while (i < code.length) {
            uint8 o = uint8(code[i]);
            if (o == op) n++;
            if (o >= 0x60 && o <= 0x7f) i += uint256(o) - 0x5f;
            i++;
        }
    }

    /// @notice Whether `op` appears as an executed opcode.
    function hasOpcode(bytes memory code, uint8 op) internal pure returns (bool) {
        return countOpcode(code, op) > 0;
    }

    /// @notice Raw byte-substring search over the whole image, metadata included.
    /// @dev Used for absence claims about 32-byte constants (event topics,
    ///      selectors). Deliberately NOT opcode-aware: for "this constant is
    ///      nowhere in the deployed image", searching every byte is the stronger
    ///      statement.
    function containsBytes(bytes memory haystack, bytes memory needle) internal pure returns (bool) {
        if (needle.length == 0 || needle.length > haystack.length) return false;
        uint256 last = haystack.length - needle.length;
        for (uint256 i = 0; i <= last; i++) {
            bool hit = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    hit = false;
                    break;
                }
            }
            if (hit) return true;
        }
        return false;
    }

    /// @notice ASCII substring search over artifact text (ABI JSON, metadata).
    function containsString(string memory haystack, string memory needle) internal pure returns (bool) {
        return containsBytes(bytes(haystack), bytes(needle));
    }

    /// @notice Whether `set` contains `value` (exact string equality).
    function contains(string[] memory set, string memory value) internal pure returns (bool) {
        bytes32 h = keccak256(bytes(value));
        for (uint256 i = 0; i < set.length; i++) {
            if (keccak256(bytes(set[i])) == h) return true;
        }
        return false;
    }
}
