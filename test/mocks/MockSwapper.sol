// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/// @title MockSwapper — TEST ONLY. An ordinary third party trading the pool.
/// @notice Sprint 5's fee legs only exist if somebody actually swaps, so the
///         suite needs a counterparty. This is the whole of one: it pays what the
///         pool asks out of its own balance and keeps what it gets.
///
///         It is deliberately **not** a router and not derived from one — no
///         v3-periphery source is vendored, imported, or consulted (sprint.md
///         Sprint 5 "External dependencies: vendored pool only; no new source").
///         Everything a real trade needs that a router would otherwise provide —
///         path encoding, deadline handling, multicall, fee-on-transfer support,
///         permit — is absent, because a test counterparty needs none of it.
///
///         The treasury never trusts this contract with anything: it is an
///         unrelated pool user, exactly like a real trader would be.
contract MockSwapper {
    IUniswapV3Pool public immutable pool;

    error NotPool(address caller);

    constructor(IUniswapV3Pool pool_) {
        pool = pool_;
    }

    /// @notice Swap `amountSpecified` (positive = exact input) in `zeroForOne`
    ///         direction, paying from this contract's own balances.
    function swap(bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96)
        external
        returns (int256 amount0, int256 amount1)
    {
        return pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, "");
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (msg.sender != address(pool)) revert NotPool(msg.sender);
        if (amount0Delta > 0) IERC20(pool.token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(pool.token1()).transfer(msg.sender, uint256(amount1Delta));
    }
}
