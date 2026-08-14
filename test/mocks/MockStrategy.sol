// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IStrategyAdapter} from "../../src/interfaces/IStrategyAdapter.sol";

/// @title MockStrategy — TEST ONLY. An admitted Strategy, honest or adversarial.
/// @notice Stands in for the venue-side adapter across all three accounting
///         modes. Every switch below exists to reach a branch of the accepted
///         §1.10 guards that an honest adapter cannot reach, so the guards are
///         tested against the behaviour they were written for rather than
///         against a cooperative stub:
///
///         • `shrinkUnitsOnHarvest` makes `harvest()` reduce `principalUnits()`
///           — the "harvest" that is really a partial exit. It is the only way
///           to reach the units-intact guard (`PrincipalUnitsDecreased`).
///         • `rewardAssets` may list the same asset twice. A duplicate costs an
///           adversarial adapter nothing and would otherwise book one measured
///           delta as revenue twice.
///         • `redeemPayout` decouples what a redemption pays from what its units
///           are worth, which is how gain, shortfall, and total-loss redemptions
///           are produced on demand.
///         • `unitsPerAsset` decouples units from deposited amount, so basis
///           conservation is exercised on non-1:1 unit prices.
///         • `recallShortfallBp` returns less than asked. A recall that is
///           partially honoured must still classify exactly what arrived.
///         • `lieUnits` inflates `principalUnits()` without any backing flow —
///           the classification-fraud case the accepted argument bounds at
///           "no more powerful than theft" (sdd.md:L302).
contract MockStrategy is IStrategyAdapter {
    uint256 private _units;
    address[] private _rewardAssets;
    mapping(address => uint256) public harvestAmount;

    bool public shrinkUnitsOnHarvest;
    uint256 public unitsPerAsset = 1e18;
    uint256 public redeemPayout;
    address public redeemAsset;
    uint256 public recallShortfallBp;

    // --- configuration --------------------------------------------------------

    function setRewardAssets(address[] calldata assets) external {
        delete _rewardAssets;
        for (uint256 i = 0; i < assets.length; i++) {
            _rewardAssets.push(assets[i]);
        }
    }

    function setHarvestAmount(address asset, uint256 amount) external {
        harvestAmount[asset] = amount;
    }

    function setShrinkUnitsOnHarvest(bool value) external {
        shrinkUnitsOnHarvest = value;
    }

    /// @dev Units minted per whole deposited unit, in 1e18 fixed point.
    function setUnitsPerAsset(uint256 rate) external {
        unitsPerAsset = rate;
    }

    /// @dev What the NEXT `redeem` pays, regardless of units burned.
    function setRedeemPayout(address asset, uint256 amount) external {
        redeemAsset = asset;
        redeemPayout = amount;
    }

    function setRecallShortfallBp(uint256 bp) external {
        recallShortfallBp = bp;
    }

    /// @dev Manufacture units out of nothing.
    function lieUnits(uint256 extra) external {
        _units += extra;
    }

    // --- IStrategyAdapter -----------------------------------------------------

    function principalUnits() external view returns (uint256) {
        return _units;
    }

    function rewardAssets() external view returns (address[] memory) {
        return _rewardAssets;
    }

    function harvest() external {
        if (shrinkUnitsOnHarvest && _units > 0) _units -= 1;
        for (uint256 i = 0; i < _rewardAssets.length; i++) {
            uint256 amount = harvestAmount[_rewardAssets[i]];
            if (amount == 0) continue;
            // Cleared so a duplicated entry cannot pay twice: the treasury must
            // reject double-crediting on its own measurement, not be rescued by
            // the adapter paying only once.
            harvestAmount[_rewardAssets[i]] = 0;
            IERC20(_rewardAssets[i]).transfer(msg.sender, amount);
        }
    }

    function deposit(address, uint256 amount) external {
        _units += (amount * unitsPerAsset) / 1e18;
    }

    function redeem(uint256 units) external {
        _units -= units;
        uint256 payout = redeemPayout;
        redeemPayout = 0;
        if (payout != 0) IERC20(redeemAsset).transfer(msg.sender, payout);
    }

    function recall(address asset, uint256 amount) external {
        uint256 sent = amount - (amount * recallShortfallBp) / 10_000;
        if (sent != 0) IERC20(asset).transfer(msg.sender, sent);
    }
}
