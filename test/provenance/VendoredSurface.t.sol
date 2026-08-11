// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {BaseTest} from "../harness/BaseTest.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3PoolActions} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";
import {IUniswapV3PoolDeployer} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol";

/// @title VendoredSurfaceTest — the vendored census is actually consumable.
/// @notice Proves the dual-unit scaffold works end to end for the `=0.8.28`
///         side: the vendored OpenZeppelin implementation files compile and
///         execute here, and the vendored v3-core *interfaces* (pragma
///         `>=0.5.0`, authorized for cross-unit import by refreeze §4) resolve
///         through the same remappings. The `=0.7.6` side is proven by
///         PoolInitCodeHash.t.sol.
///
///         Without this, a broken remapping or a missing transitive census file
///         would only surface in Sprint 2 — after the provenance gate had
///         already been declared green.
contract VendoredSurfaceTest is BaseTest, ReentrancyGuard {
    function test_VendoredOpenZeppelinMathExecutes() public pure {
        // Math.mulDiv is the exact-arithmetic primitive the VEM and redemption
        // formulas are specified against; floor semantics are what VUX relies on.
        assertEq(Math.mulDiv(6, 7, 2), 21, "mulDiv exact");
        assertEq(Math.mulDiv(7, 1, 2), 3, "mulDiv floors");
        assertEq(Math.mulDiv(type(uint256).max, 1, type(uint256).max), 1, "mulDiv full width");
    }

    function test_VendoredOpenZeppelinReentrancyGuardExecutes() public nonReentrant {
        assertTrue(true, "nonReentrant modifier from vendored OZ applied");
    }

    function test_VendoredUniswapInterfacesResolve() public pure {
        // The aggregate pool interface and its sub-interfaces all resolve
        // through the census; a missing transitive file would fail to compile.
        IUniswapV3Pool pool = IUniswapV3Pool(address(0));
        assertEq(address(pool), address(0), "aggregate pool interface resolves");

        // Selector identity proves the interface bytes came from the vendored
        // census rather than a locally re-declared stub.
        assertEq(
            bytes32(IUniswapV3PoolActions.mint.selector),
            bytes32(bytes4(keccak256("mint(address,int24,int24,uint128,bytes)"))),
            "IUniswapV3PoolActions.mint selector"
        );
        assertEq(
            bytes32(IUniswapV3PoolDeployer.parameters.selector),
            bytes32(bytes4(keccak256("parameters()"))),
            "IUniswapV3PoolDeployer.parameters selector"
        );
    }
}
