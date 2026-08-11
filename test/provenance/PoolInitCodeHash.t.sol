// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {BaseTest} from "../harness/BaseTest.sol";

/// @title PoolInitCodeHashTest — fail-closed reproduction of the accepted
///        `POOL_INIT_CODE_HASH` from the vendored `=0.7.6` compilation unit.
/// @notice Refreeze §7 obligation 1: the Foundry profile for the vendored unit
///         MUST reproduce `UniswapV3Pool` creation bytecode whose keccak256
///         equals the accepted constant, and CI MUST fail closed on mismatch
///         before any deployment code is accepted.
///
///         This reads the artifact produced by `FOUNDRY_PROFILE=v3core forge
///         build` (solc 0.7.6, optimizer on / 800 runs, evm_version istanbul,
///         bytecode_hash none) — it does not recompute the settings, so a
///         settings change shows up here as a hash mismatch, which is exactly
///         the intended failure.
contract PoolInitCodeHashTest is BaseTest {
    /// @dev Accepted constant — refreeze §7, cross-confirmed against upstream
    ///      v3-periphery `PoolAddress.sol` at the evidence pin.
    bytes32 internal constant ACCEPTED_POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @dev Creation-code length recorded by the accepted refreeze §7
    ///      reproduction. Checked separately so a truncated or empty artifact
    ///      fails loudly rather than as an opaque hash mismatch.
    uint256 internal constant ACCEPTED_CREATION_CODE_LENGTH = 22_728;

    string internal constant ARTIFACT = "out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json";

    function test_PoolInitCodeHashMatchesAcceptedConstant() public view {
        bytes memory creationCode = vm.parseJsonBytes(vm.readFile(ARTIFACT), ".bytecode.object");

        assertEq(creationCode.length, ACCEPTED_CREATION_CODE_LENGTH, "pool creation code length");
        assertEq(keccak256(creationCode), ACCEPTED_POOL_INIT_CODE_HASH, "POOL_INIT_CODE_HASH");
    }

    /// @dev `bytecode_hash = "none"` is a bytecode-affecting setting the accepted
    ///      refreeze enumerates. With it, solc still appends its default CBOR
    ///      tail `a164736f6c6343000706000a` = {solc: 0.7.6} and no metadata
    ///      hash — the mechanical confirmation recorded in refreeze §7.
    function test_CborTailConfirmsBytecodeHashNone() public view {
        bytes memory creationCode = vm.parseJsonBytes(vm.readFile(ARTIFACT), ".bytecode.object");

        bytes memory tail = new bytes(12);
        for (uint256 i = 0; i < 12; i++) {
            tail[i] = creationCode[creationCode.length - 12 + i];
        }
        assertEq(tail, hex"a164736f6c6343000706000a", "solc CBOR tail");
    }
}
