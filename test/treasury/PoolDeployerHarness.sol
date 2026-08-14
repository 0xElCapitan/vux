// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {BaseTest} from "../harness/BaseTest.sol";

/// @notice The `VuxPoolDeployer` surface, declared for the `=0.8.28` test unit.
/// @dev `src/v3core/VuxPoolDeployer.sol` compiles in the other (`=0.7.6`)
///      compilation unit, so no `=0.8.28` file can import its type. Bytecode has
///      no version, though: the tests deploy the real artifact and call it
///      through this declaration. Nothing is mocked — this is the production
///      contract, byte-for-byte as CI built it.
interface IVuxPoolDeployer {
    function COMMITMENT() external view returns (bytes32);
    function canonicalPool() external view returns (address);
    function owner() external view returns (address);
    function parameters()
        external
        view
        returns (address factory, address token0, address token1, uint24 fee, int24 tickSpacing);
    function deployCanonicalPool(bytes32 salt, address token0, address token1, uint24 fee, int24 tickSpacing)
        external
        returns (address pool);
}

/// @title PoolDeployerHarness — cross-compilation-unit deployment for tests.
/// @notice Sprint 4's constructor verification is only worth anything against a
///         *real* pool: "no mocks for identity checks" (sprint.md:L331). A mock
///         pool would answer `factory()`/`token0()`/`fee()`/`tickSpacing()`
///         however the test wanted, which would verify the test rather than the
///         treasury. So the fixtures deploy the genuine `=0.7.6` artifacts and
///         let the genuine CREATE2 derivation produce the address.
abstract contract PoolDeployerHarness is BaseTest {
    string internal constant DEPLOYER_ARTIFACT = "out-v3core/VuxPoolDeployer.sol/VuxPoolDeployer.json";
    string internal constant POOL_ARTIFACT = "out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json";

    /// @dev Deploy the real `VuxPoolDeployer` with `commitment` as its
    ///      constructor argument.
    function _deployPoolDeployer(bytes32 commitment) internal returns (IVuxPoolDeployer) {
        bytes memory creationCode = vm.parseJsonBytes(vm.readFile(DEPLOYER_ARTIFACT), ".bytecode.object");
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(commitment));

        address deployed;
        assembly ("memory-safe") {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        if (deployed == address(0)) fail("VuxPoolDeployer deployment reverted");
        return IVuxPoolDeployer(deployed);
    }

    /// @dev `keccak256(UniswapV3Pool creation code)`, read from the compiled
    ///      artifact rather than from the accepted constant. Independence is the
    ///      point: `test/provenance/PoolInitCodeHash.t.sol` already asserts the
    ///      artifact equals the accepted constant, so deriving the address from
    ///      the artifact here and comparing against the deployed pool closes the
    ///      loop without either test assuming the other's conclusion.
    function _poolInitCodeHash() internal view returns (bytes32) {
        return keccak256(vm.parseJsonBytes(vm.readFile(POOL_ARTIFACT), ".bytecode.object"));
    }

    /// @dev The canonical pool address, recomputed from first principles:
    ///      `create2(deployer, keccak256(abi.encode(token0, token1, fee)),
    ///      POOL_INIT_CODE_HASH)` (sdd.md:L192).
    function _computePoolAddress(address deployer, address token0, address token1, uint24 fee)
        internal
        view
        returns (address)
    {
        bytes32 salt = keccak256(abi.encode(token0, token1, fee));
        return address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", deployer, salt, _poolInitCodeHash()))))
        );
    }

    /// @dev Canonical token sort — the pool's own ordering rule.
    function _sorted(address a, address b) internal pure returns (address token0, address token1) {
        return a < b ? (a, b) : (b, a);
    }
}
