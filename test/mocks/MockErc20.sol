// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockErc20 — TEST ONLY. A plain ERC-20 that is not WETH.
/// @notice Sprint 4's treasury is multi-asset: strategies are admitted
///         per-(strategy, asset), rewards arrive in arbitrary denominations, and
///         the Hard accretion leg must reject everything except WETH. Those
///         assertions need an asset that is demonstrably *not* the WETH the
///         treasury was constructed against, which `MockWeth` cannot be.
///
///         Deliberately free of probe switches: `MockWeth` carries the
///         failure-injection surface, and duplicating it here would invite tests
///         to reach for the wrong token when they want a misbehaving one.
contract MockErc20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
