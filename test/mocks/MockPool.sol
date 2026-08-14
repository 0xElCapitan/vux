// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @title MockPool — TEST ONLY. A pool that answers however the test says.
/// @notice Used for **negatives only**, and deliberately so. The positive
///         constructor verification runs against a real vendored pool deployed
///         by the real `VuxPoolDeployer` (sprint.md:L331 — "no mocks for
///         identity checks"); verifying the happy path against a mock would
///         verify the mock.
///
///         Two of the constructor's rejections are unreachable with real
///         contracts, which is exactly why they need one:
///
///         • a real `VuxPoolDeployer` has `owner()` as a compile-time constant
///           zero, so `PoolOwnerNotDead` can never fire against one, and
///         • a real `deployCanonicalPool` rejects out-of-domain `tickSpacing`
///           before a pool exists, so `PoolTickSpacingInvalid` can never fire
///           against a real pool.
///
///         A guard that no test can reach is indistinguishable from a guard that
///         does not work.
///
///         The same instance answers `owner()` as well as the pool immutables,
///         so a test can pass it as both `pool` and `poolDeployer` and control
///         every input the constructor reads.
contract MockPool {
    address public factory;
    address public token0;
    address public token1;
    uint24 public fee;
    int24 public tickSpacing;
    address public owner;

    constructor(address factory_, address token0_, address token1_, uint24 fee_, int24 tickSpacing_) {
        factory = factory_;
        token0 = token0_;
        token1 = token1_;
        fee = fee_;
        tickSpacing = tickSpacing_;
    }

    function setOwner(address owner_) external {
        owner = owner_;
    }
}
