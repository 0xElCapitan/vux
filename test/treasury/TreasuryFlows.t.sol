// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 4 AC-3 (mode-specific accounting), Task 4.4
//          INV-28 (returned principal is principal), INV-30 (marks are not revenue)
//          sdd.md:L289-L304 (§1.10 recognition architecture), L858

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {TreasuryFixture} from "./TreasuryFixture.sol";

/// @title TreasuryFlowsTest — the three primitives, one mode at a time.
/// @notice Every credit this contract makes is the output of a mechanical guard
///         applied to a **measured** amount. These tests exercise each guard at
///         the boundary it defends: the netting rule at exactly full return, the
///         units-intact rule at exactly one unit of shrinkage, the cost-basis
///         rule at exact conservation, and the write-off at the one thing it
///         must never do.
contract TreasuryFlowsTest is TreasuryFixture {
    uint8 internal constant NETTING = 0;
    uint8 internal constant CLAIM = 1;
    uint8 internal constant UNITIZED = 2;

    uint256 internal constant CAP = 1_000 ether;

    MockStrategy internal strategy;

    function setUp() public {
        _deploySystem();
        strategy = _newStrategy();
        _fundTreasury(address(weth), 10_000 ether);
    }

    function _returnAs(address who, address strategy_, address asset, uint256 amount) internal {
        _fund(who, asset, amount);
        vm.prank(who);
        IApprovable(asset).approve(address(treasury), amount);
        vm.prank(who);
        treasury.returnFor(strategy_, asset, amount);
    }

    // =========================================================================
    // returnFor — principal-first netting (all modes)
    // =========================================================================

    /// @dev Revenue exists only beyond FULL principal return. One wei short of
    ///      the deployed amount is still entirely principal.
    function test_NettingCreditsNoRevenueUntilPrincipalIsWhole() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);

        _returnAs(ALICE, address(strategy), address(weth), 100 ether - 1);
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 1, "one wei of principal left");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "not one wei of revenue yet");

        _returnAs(ALICE, address(strategy), address(weth), 1);
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "principal whole");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "still no revenue at exactly full return");

        _returnAs(ALICE, address(strategy), address(weth), 5 ether);
        assertEq(treasury.realizedRevenue(address(weth)), 5 ether, "only the excess is revenue");
    }

    /// @dev A single return that straddles the boundary splits, it does not pick
    ///      a side — and the split is what the event carries.
    function test_AStraddlingReturnSplitsIntoPrincipalAndRevenue() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);

        _fund(ALICE, address(weth), 130 ether);
        vm.prank(ALICE);
        weth.approve(address(treasury), 130 ether);

        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.ReturnedFromStrategy(address(strategy), address(weth), 100 ether, 30 ether);
        vm.prank(ALICE);
        treasury.returnFor(address(strategy), address(weth), 130 ether);

        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "principal retired");
        assertEq(treasury.realizedRevenue(address(weth)), 30 ether, "excess credited");
    }

    /// @dev INV-28: returned principal is principal. It is not revenue, and no
    ///      amount of it becomes distributable.
    function test_ReturnedPrincipalIsNeverDistributable() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 500 ether);
        _returnAs(ALICE, address(strategy), address(weth), 500 ether);

        assertEq(treasury.realizedRevenue(address(weth)), 0, "no revenue credit");
        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), 0, 0, 1, 0);
    }

    /// @dev Rule 2: only assets with outstanding principal, or the admitted
    ///      deployment asset, are accepted. An arbitrary-asset "return" cannot
    ///      mint revenue.
    function test_AnArbitraryAssetReturnIsRejected() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);

        _fund(ALICE, address(otherAsset), 10 ether);
        vm.prank(ALICE);
        otherAsset.approve(address(treasury), 10 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategicTreasury.UnknownReturnAsset.selector, address(strategy), address(otherAsset)
            )
        );
        vm.prank(ALICE);
        treasury.returnFor(address(strategy), address(otherAsset), 10 ether);
    }

    function test_AReturnForANeverAdmittedStrategyIsRejected() public {
        MockStrategy stranger = _newStrategy();
        _fund(ALICE, address(weth), 1 ether);
        vm.prank(ALICE);
        weth.approve(address(treasury), 1 ether);

        vm.expectPartialRevert(StrategicTreasury.UnknownReturnAsset.selector);
        vm.prank(ALICE);
        treasury.returnFor(address(stranger), address(weth), 1 ether);
    }

    /// @dev The credited amount is the measured receipt, not the argument. On an
    ///      under-delivering asset, crediting the argument would retire more
    ///      principal than arrived — and the gap would reappear later as revenue
    ///      that was never earned.
    function test_OnlyWhatActuallyArrivesRetiresPrincipal() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);

        weth.setTransferFeeBp(1_000); // 10% withheld in transit
        _fund(ALICE, address(weth), 100 ether);
        vm.prank(ALICE);
        weth.approve(address(treasury), 100 ether);
        vm.prank(ALICE);
        treasury.returnFor(address(strategy), address(weth), 100 ether);

        assertEq(
            treasury.outstandingPrincipal(address(strategy), address(weth)),
            10 ether,
            "only the 90 that arrived retired principal"
        );
        assertEq(treasury.realizedRevenue(address(weth)), 0, "and nothing became revenue");
    }

    /// @dev Permissionless by design: a strategy returns its own capital without
    ///      needing the operator to be awake.
    function test_ReturnForIsPermissionless() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 10 ether);

        _returnAs(NON_OPERATOR, address(strategy), address(weth), 10 ether);
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "anyone may attribute a return");
    }

    // =========================================================================
    // harvestYield — CLAIM
    // =========================================================================

    function test_NettingForbidsHarvest() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.ModeForbidsFlow.selector, address(strategy), NETTING));
        treasury.harvestYield(address(strategy));
    }

    /// @dev The `CLAIM` case the operator rejected the universal rule for:
    ///      long-lived principal that never exits, paying genuine yield. The
    ///      principal stays deployed and the yield is still recognised.
    function test_ClaimRecognisesYieldWhilePrincipalStaysDeployed() public {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        treasury.deployToStrategy(address(strategy), address(weth), 200 ether);
        strategy.lieUnits(200 ether); // an honest position handle, sized like the deposit

        address[] memory rewards = new address[](1);
        rewards[0] = address(otherAsset);
        strategy.setRewardAssets(rewards);
        otherAsset.mint(address(strategy), 7 ether);
        strategy.setHarvestAmount(address(otherAsset), 7 ether);

        treasury.harvestYield(address(strategy));

        assertEq(treasury.realizedRevenue(address(otherAsset)), 7 ether, "measured reward credited");
        assertEq(
            treasury.outstandingPrincipal(address(strategy), address(weth)), 200 ether, "principal untouched by yield"
        );
    }

    /// @dev Same-asset yield is legitimate here precisely because the units did
    ///      not shrink (sdd.md:L294).
    function test_ClaimRecognisesSameAssetYieldUnderIntactUnits() public {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);
        strategy.lieUnits(100 ether);

        address[] memory rewards = new address[](1);
        rewards[0] = address(weth);
        strategy.setRewardAssets(rewards);
        weth.mint(address(strategy), 3 ether);
        strategy.setHarvestAmount(address(weth), 3 ether);

        treasury.harvestYield(address(strategy));

        assertEq(treasury.realizedRevenue(address(weth)), 3 ether, "same-asset yield credited");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 100 ether, "principal intact");
    }

    /// @dev A "harvest" that shrank the position is a partial exit, not yield.
    function test_AHarvestThatShrinksThePositionReverts() public {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);
        strategy.lieUnits(100 ether);

        address[] memory rewards = new address[](1);
        rewards[0] = address(weth);
        strategy.setRewardAssets(rewards);
        weth.mint(address(strategy), 3 ether);
        strategy.setHarvestAmount(address(weth), 3 ether);
        strategy.setShrinkUnitsOnHarvest(true);

        vm.expectRevert(
            abi.encodeWithSelector(StrategicTreasury.PrincipalUnitsDecreased.selector, address(strategy))
        );
        treasury.harvestYield(address(strategy));
    }

    /// @dev A duplicated reward asset measures the same delta twice. Crediting it
    ///      twice would be revenue conjured from one flow — the cheapest lie an
    ///      adversarial adapter can tell.
    function test_ADuplicatedRewardAssetIsCreditedExactlyOnce() public {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        strategy.lieUnits(1);

        address[] memory rewards = new address[](3);
        rewards[0] = address(otherAsset);
        rewards[1] = address(otherAsset);
        rewards[2] = address(otherAsset);
        strategy.setRewardAssets(rewards);
        otherAsset.mint(address(strategy), 9 ether);
        strategy.setHarvestAmount(address(otherAsset), 9 ether);

        treasury.harvestYield(address(strategy));
        assertEq(treasury.realizedRevenue(address(otherAsset)), 9 ether, "one flow, one credit");
    }

    /// @dev Nothing harvested is nothing counted (FB-8) — and no event claiming
    ///      otherwise.
    function test_AnEmptyHarvestCreditsNothing() public {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        strategy.lieUnits(1);

        address[] memory rewards = new address[](1);
        rewards[0] = address(otherAsset);
        strategy.setRewardAssets(rewards);

        treasury.harvestYield(address(strategy));
        assertEq(treasury.realizedRevenue(address(otherAsset)), 0, "no anticipated revenue counted");
    }

    function test_HarvestYieldIsPermissionless() public {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        strategy.lieUnits(1);

        address[] memory rewards = new address[](1);
        rewards[0] = address(otherAsset);
        strategy.setRewardAssets(rewards);
        otherAsset.mint(address(strategy), 2 ether);
        strategy.setHarvestAmount(address(otherAsset), 2 ether);

        vm.prank(NON_OPERATOR);
        treasury.harvestYield(address(strategy));
        assertEq(treasury.realizedRevenue(address(otherAsset)), 2 ether, "a keeper is useful, never necessary");
    }

    // =========================================================================
    // redeemUnits — UNITIZED
    // =========================================================================

    function test_NonUnitizedModesForbidRedeemUnits() public {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.ModeForbidsFlow.selector, address(strategy), CLAIM));
        treasury.redeemUnits(address(strategy), 1, 0);
    }

    function test_DepositRecordsUnitsByMeasuredDelta() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        strategy.setUnitsPerAsset(0.5e18); // two assets per unit

        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);
        assertEq(treasury.unitsHeld(address(strategy)), 50 ether, "units are measured, not assumed");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 100 ether, "basis is the cost");
    }

    /// @dev Excess over the released basis is revenue; the basis itself is
    ///      principal coming home.
    function test_AGainRedemptionSplitsBasisFromRevenue() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);

        weth.mint(address(strategy), 20 ether);
        strategy.setRedeemPayout(address(weth), 120 ether);

        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.UnitsRedeemed(address(strategy), 100 ether, 120 ether, 100 ether, 20 ether, 0);
        treasury.redeemUnits(address(strategy), 100 ether, 0);

        assertEq(treasury.realizedRevenue(address(weth)), 20 ether, "gain is revenue");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "basis fully released");
        assertEq(treasury.unitsHeld(address(strategy)), 0, "units burned");
    }

    /// @dev A shortfall books as a realized LOSS — never as negative revenue,
    ///      and never as a revenue credit of any sign.
    function test_AShortfallRedemptionBooksALossAndNoRevenue() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);

        strategy.setRedeemPayout(address(weth), 60 ether);

        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.StrategyLossRealized(address(strategy), address(weth), 40 ether);
        treasury.redeemUnits(address(strategy), 100 ether, 0);

        assertEq(treasury.realizedRevenue(address(weth)), 0, "a loss creates no revenue");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "basis released in full");
    }

    /// @dev Total loss: the units pay nothing. The basis is still released, the
    ///      loss is still evented, and nothing anywhere becomes revenue.
    function test_ATotalLossRedemptionIsStillLossOnly() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);

        treasury.redeemUnits(address(strategy), 100 ether, 0);

        assertEq(treasury.realizedRevenue(address(weth)), 0, "no revenue from a total loss");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "basis gone");
    }

    /// @dev Σ basisReleased over a full unwind equals the original basis exactly,
    ///      ceilings and all. The unit price is deliberately not 1:1 and the
    ///      partials deliberately do not divide evenly, so every intermediate
    ///      release rounds up and the final one has to absorb whatever the
    ///      rounding left: 10 wei of basis against 30 units, released 7/7/7/9.
    function test_BasisReleaseConservesOverAFullUnwind() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        strategy.setUnitsPerAsset(3e18);
        treasury.deployToStrategy(address(strategy), address(weth), 10);
        assertEq(treasury.unitsHeld(address(strategy)), 30, "30 units against 10 wei of basis");

        treasury.redeemUnits(address(strategy), 7, 0); // ceil(10x7/30) = 3
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 7, "rounded up, as specified");
        treasury.redeemUnits(address(strategy), 7, 0); // ceil(7x7/23)  = 3
        treasury.redeemUnits(address(strategy), 7, 0); // ceil(4x7/16)  = 2
        treasury.redeemUnits(address(strategy), 9, 0); // ceil(2x9/9)   = 2

        assertEq(treasury.unitsHeld(address(strategy)), 0, "fully unwound");
        assertEq(
            treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "and the basis closed out to the wei"
        );
    }

    /// @dev `minOut` is applied to the treasury's own measured receipt, so the
    ///      adapter has nothing to misreport.
    function test_MinOutIsEnforcedAgainstTheMeasuredReceipt() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);
        strategy.setRedeemPayout(address(weth), 90 ether);

        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.SlippageExceeded.selector, 90 ether, 95 ether));
        treasury.redeemUnits(address(strategy), 100 ether, 95 ether);
    }

    function test_RedeemingMoreUnitsThanHeldReverts() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        treasury.deployToStrategy(address(strategy), address(weth), 100 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategicTreasury.UnitsExceedHeld.selector, address(strategy), 100 ether + 1, 100 ether
            )
        );
        treasury.redeemUnits(address(strategy), 100 ether + 1, 0);

        vm.expectPartialRevert(StrategicTreasury.UnitsExceedHeld.selector);
        treasury.redeemUnits(address(strategy), 0, 0);
    }

    // =========================================================================
    // closeStrategy — loss-only write-off
    // =========================================================================

    function test_CloseRequiresRemovalFirst() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.StillAdmitted.selector, address(strategy)));
        treasury.closeStrategy(address(strategy));
    }

    /// @dev A write-off can only reduce principal accounting. It is not a
    ///      declaration escape hatch, and no sequence of closes creates a wei of
    ///      revenue (§1.10 rule 3).
    function test_CloseWritesOffPrincipalAndCreatesNoRevenue() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.admitStrategy(address(strategy), address(otherAsset), CAP, NETTING);
        vm.warp(vm.getBlockTimestamp() + treasury.ADMISSION_DELAY());
        _fundTreasury(address(otherAsset), 100 ether);

        treasury.deployToStrategy(address(strategy), address(weth), 60 ether);
        treasury.deployToStrategy(address(strategy), address(otherAsset), 40 ether);
        treasury.removeStrategy(address(strategy), true);

        treasury.closeStrategy(address(strategy));

        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "WETH basis written off");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(otherAsset)), 0, "other basis written off");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "no revenue created");
        assertEq(treasury.realizedRevenue(address(otherAsset)), 0, "no revenue created");
    }

    /// @dev Closing twice is idempotent, and closing an empty strategy is a
    ///      no-op — neither can manufacture a second loss event or a credit.
    function test_CloseIsIdempotent() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 10 ether);
        treasury.removeStrategy(address(strategy), false);

        treasury.closeStrategy(address(strategy));
        treasury.closeStrategy(address(strategy));

        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "still zero");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "still no revenue");
    }

    /// @dev Recovery after a write-off is genuine revenue: the basis was already
    ///      recognised as a loss, so there is nothing left for it to be.
    function test_RecoveryAfterAWriteOffIsRevenue() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 50 ether);
        treasury.removeStrategy(address(strategy), true);
        treasury.closeStrategy(address(strategy));

        treasury.recallFromStrategy(address(strategy), address(weth), 50 ether);
        assertEq(treasury.realizedRevenue(address(weth)), 50 ether, "post-write-off recovery is revenue");
    }

    // =========================================================================
    // unauthorized callers (AC-7)
    // =========================================================================

    function test_EveryOperatorFlowRejectsAnUnauthorizedCaller() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        treasury.deployToStrategy(address(strategy), address(weth), 10 ether);

        vm.startPrank(NON_OPERATOR);

        _expectUnauthorized();
        treasury.redeemUnits(address(strategy), 1, 0);

        _expectUnauthorized();
        treasury.closeStrategy(address(strategy));

        vm.stopPrank();
    }
}

/// @notice `approve` on either mock token, without importing both types.
interface IApprovable {
    function approve(address spender, uint256 amount) external returns (bool);
}
