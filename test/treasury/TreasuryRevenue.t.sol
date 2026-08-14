// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 4 AC-4 (allocateRevenue negatives, four legs),
//          AC-5 (no stored ratio), Task 4.5; FR-12 negative acceptance
//          (prd.md:L505-L506), FB-9, FB-12, F-46; sdd.md:L308-L318

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {TreasuryFixture} from "./TreasuryFixture.sol";

/// @title TreasuryRevenueTest — the bounded policy surface.
/// @notice The whole safety argument of the distribution surface is one
///         inequality: `Σ legs ≤ realizedRevenue[asset]`. Principal and marks are
///         not *forbidden* from being distributed — they are **arithmetically
///         unreachable**, because nothing ever credited them here. These tests
///         attack that from both sides: the bound itself, and the three
///         asset-shaped rejections that keep the legs honest.
contract TreasuryRevenueTest is TreasuryFixture {
    uint8 internal constant NETTING = 0;
    uint8 internal constant CLAIM = 1;

    uint256 internal constant CAP = 1_000 ether;

    MockStrategy internal strategy;

    function setUp() public {
        _deploySystem();
        strategy = _newStrategy();
        _fundTreasury(address(weth), 10_000 ether);
        treasury.setOpsRecipient(OPS_RECIPIENT);
    }

    /// @dev Credit `amount` of realized revenue in `asset` the only way the
    ///      contract allows: by actually delivering it. Deploy, then return more
    ///      than was deployed.
    function _earnRevenue(address asset, uint256 amount) internal {
        _admitMatured(address(strategy), asset, CAP, NETTING);
        _fund(ALICE, asset, amount);
        vm.prank(ALICE);
        IApproves(asset).approve(address(treasury), amount);
        vm.prank(ALICE);
        treasury.returnFor(address(strategy), asset, amount);
        assertEq(treasury.realizedRevenue(asset), amount, "revenue credited by delivery");
    }

    // =========================================================================
    // The accumulator bound
    // =========================================================================

    function test_TheFourLegsMayNotExceedRealizedRevenue() public {
        _earnRevenue(address(weth), 100 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategicTreasury.RevenueExceedsRealized.selector, address(weth), 100 ether + 1, 100 ether
            )
        );
        treasury.allocateRevenue(address(weth), 25 ether, 25 ether, 25 ether, 25 ether + 1);

        treasury.allocateRevenue(address(weth), 25 ether, 25 ether, 25 ether, 25 ether);
        assertEq(treasury.realizedRevenue(address(weth)), 0, "exactly the credit is spendable");
    }

    /// @dev FB-9 / FB-12: with zero realized revenue, every leg reverts. There is
    ///      no Reserve payroll and no automatic principal relabeling — costs
    ///      contract or receive separately disclosed funding.
    function test_WithZeroRevenueEveryLegReverts() public {
        _fundTreasury(address(weth), 5_000 ether); // principal-side inventory, plenty of it
        assertEq(treasury.realizedRevenue(address(weth)), 0, "no revenue realized");

        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), 1, 0, 0, 0);

        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), 0, 1, 0, 0);

        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), 0, 0, 1, 0);

        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), 0, 0, 0, 1);
    }

    /// @dev Principal in custody is not a budget. The treasury can be holding
    ///      thousands of WETH of Strategic principal and still be unable to pay a
    ///      single wei out of it (FR-12 negative acceptance).
    function test_PrincipalUnderCustodyIsNotDistributable() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 500 ether);
        treasury.recallFromStrategy(address(strategy), address(weth), 500 ether);

        assertGt(weth.balanceOf(address(treasury)), 500 ether, "the treasury physically holds the capital");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "and none of it is revenue");

        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), 0, 0, 1 ether, 0);
    }

    /// @dev The bound is per-asset, not global: revenue in one denomination
    ///      cannot be spent in another.
    function test_TheBoundIsPerAsset() public {
        _earnRevenue(address(weth), 100 ether);

        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(otherAsset), 0, 0, 1, 0);
    }

    // =========================================================================
    // The four legs
    // =========================================================================

    function test_TheHardLegIsAOneWayTransferThatRaisesBacking() public {
        _earnRevenue(address(weth), 100 ether);
        uint256 backingBefore = reserve.backing();

        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.RevenueAllocated(address(weth), 0, 40 ether, 0, 0);
        treasury.allocateRevenue(address(weth), 0, 40 ether, 0, 0);

        assertEq(reserve.backing() - backingBefore, 40 ether, "B rose by exactly the leg");
        assertEq(treasury.realizedRevenue(address(weth)), 60 ether, "and the credit fell by exactly the leg");
    }

    /// @dev `B` is raw WETH. Anything else would strand something unredeemable in
    ///      Reserve custody, so a non-WETH Hard leg is refused outright.
    function test_ANonWethHardLegIsRejected() public {
        _earnRevenue(address(otherAsset), 100 ether);

        vm.expectRevert(StrategicTreasury.HardLegMustBeWeth.selector);
        treasury.allocateRevenue(address(otherAsset), 0, 1, 0, 0);

        // The other three legs are unaffected: it is the Hard leg that is
        // WETH-only, not the whole surface.
        treasury.allocateRevenue(address(otherAsset), 10 ether, 0, 10 ether, 10 ether);
        assertEq(treasury.realizedRevenue(address(otherAsset)), 70 ether, "the other legs still work");
    }

    function test_TheOpsLegPaysTheDisclosedRecipient() public {
        _earnRevenue(address(weth), 100 ether);

        treasury.allocateRevenue(address(weth), 0, 0, 30 ether, 0);
        assertEq(weth.balanceOf(OPS_RECIPIENT), 30 ether, "an actual approved operating expense, paid");
    }

    /// @dev The launch state has no ops recipient, and revenue alone does not
    ///      create one: an operating expense needs a disclosed payee before it
    ///      can be paid.
    function test_TheOpsLegRequiresARecipient() public {
        StrategicTreasury fresh = new StrategicTreasury(
            address(weth), address(vux), address(reserve), address(poolDeployer), pool, FIXTURE_FEE
        );
        assertEq(fresh.opsRecipient(), address(0), "unset at launch");

        // Give `fresh` genuine revenue, so the accumulator bound is satisfied and
        // the missing recipient is the only thing left to fail on.
        fresh.admitStrategy(address(strategy), address(weth), CAP, NETTING);
        _fund(ALICE, address(weth), 10 ether);
        vm.prank(ALICE);
        weth.approve(address(fresh), 10 ether);
        vm.prank(ALICE);
        fresh.returnFor(address(strategy), address(weth), 10 ether);
        assertEq(fresh.realizedRevenue(address(weth)), 10 ether, "revenue is not the blocker");

        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        fresh.allocateRevenue(address(weth), 0, 0, 1, 0);
    }

    function test_SetOpsRecipientIsEventedAndRejectsZero() public {
        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.OpsRecipientSet(ALICE);
        treasury.setOpsRecipient(ALICE);
        assertEq(treasury.opsRecipient(), ALICE, "recipient rotated");

        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        treasury.setOpsRecipient(address(0));
    }

    /// @dev The signaler leg is an earmark, not a payment: the asset stays in
    ///      custody and only `fundSignalerProgram` can move it.
    function test_TheSignalerLegEarmarksWithoutMoving() public {
        _earnRevenue(address(weth), 100 ether);
        uint256 held = weth.balanceOf(address(treasury));

        treasury.allocateRevenue(address(weth), 0, 0, 0, 20 ether);

        assertEq(treasury.signalerBudget(address(weth)), 20 ether, "earmarked");
        assertEq(weth.balanceOf(address(treasury)), held, "nothing left custody");
        assertEq(treasury.realizedRevenue(address(weth)), 80 ether, "and it is no longer allocatable revenue");
    }

    /// @dev Compounding is a book transfer: revenue stops being distributable and
    ///      becomes principal-side inventory. Nothing moves, and that is the
    ///      point — the asset was already in custody.
    function test_TheCompoundLegIsABookTransfer() public {
        _earnRevenue(address(weth), 100 ether);
        uint256 held = weth.balanceOf(address(treasury));

        treasury.allocateRevenue(address(weth), 100 ether, 0, 0, 0);

        assertEq(weth.balanceOf(address(treasury)), held, "custody unchanged");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "but no longer distributable");

        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), 0, 0, 1, 0);
    }

    /// @dev All four legs in one call, each landing exactly where it should.
    function test_AllFourLegsCompose() public {
        _earnRevenue(address(weth), 100 ether);
        uint256 backingBefore = reserve.backing();

        treasury.allocateRevenue(address(weth), 40 ether, 30 ether, 20 ether, 10 ether);

        assertEq(reserve.backing() - backingBefore, 30 ether, "hard");
        assertEq(weth.balanceOf(OPS_RECIPIENT), 20 ether, "ops");
        assertEq(treasury.signalerBudget(address(weth)), 10 ether, "signalers");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "compound consumed the rest");
    }

    // =========================================================================
    // VUX revenue — burn only (F-46)
    // =========================================================================

    /// @dev Credit VUX-denominated revenue the honest way: a CLAIM strategy pays
    ///      a VUX reward and the treasury measures it.
    function _earnVuxRevenue(uint256 amount) internal {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        strategy.lieUnits(1);

        address[] memory rewards = new address[](1);
        rewards[0] = address(vux);
        strategy.setRewardAssets(rewards);
        vux.transfer(address(strategy), amount); // from the fixture's genesis POL inventory
        strategy.setHarvestAmount(address(vux), amount);

        treasury.harvestYield(address(strategy));
        assertEq(treasury.realizedRevenue(address(vux)), amount, "VUX revenue credited");
    }

    function test_AllocateRevenueRefusesVuxOutright() public {
        _earnVuxRevenue(10 ether);

        vm.expectRevert(StrategicTreasury.VuxRevenueMustBurn.selector);
        treasury.allocateRevenue(address(vux), 1, 0, 0, 0);

        // Even a wholly zero allocation is refused: the rejection is on the
        // asset, so no VUX call shape reaches the waterfall at all.
        vm.expectRevert(StrategicTreasury.VuxRevenueMustBurn.selector);
        treasury.allocateRevenue(address(vux), 0, 0, 0, 0);
    }

    /// @dev Burning reduces `S`, and it burns exactly the credited revenue —
    ///      never the treasury's whole VUX balance, which would destroy POL
    ///      inventory principal.
    function test_BurnVuxRevenueBurnsTheCreditAndLeavesInventoryAlone() public {
        _earnVuxRevenue(10 ether);
        vux.transfer(address(treasury), 25 ether); // POL-shaped inventory, not revenue

        uint256 supplyBefore = vux.totalSupply();
        uint256 heldBefore = vux.balanceOf(address(treasury));

        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.VuxRevenueBurned(10 ether);
        treasury.burnVuxRevenue();

        assertEq(supplyBefore - vux.totalSupply(), 10 ether, "S fell by exactly the credited revenue");
        assertEq(heldBefore - vux.balanceOf(address(treasury)), 10 ether, "inventory untouched");
        assertEq(vux.balanceOf(address(treasury)), 25 ether, "the POL-shaped inventory survives");
        assertEq(treasury.realizedRevenue(address(vux)), 0, "credit zeroed");
    }

    function test_BurningNothingIsANoOp() public {
        uint256 supplyBefore = vux.totalSupply();
        treasury.burnVuxRevenue();
        assertEq(vux.totalSupply(), supplyBefore, "no credit, no burn");
    }

    // =========================================================================
    // FR-12 negative acceptance: no configuration reaches Reserve principal or mint
    // =========================================================================

    /// @dev The Hard leg is the treasury's ONLY reach toward the Reserve and it
    ///      is one-way by construction: `B` can only rise. There is no argument,
    ///      no leg, and no sequence that reduces it — the Reserve exposes nothing
    ///      to call, so this is a property of the topology, not of the amounts.
    function test_NoAllocationCanReduceBackingOrMint() public {
        _earnRevenue(address(weth), 100 ether);

        uint256 backingBefore = reserve.backing();
        uint256 supplyBefore = vux.totalSupply();

        treasury.allocateRevenue(address(weth), 10 ether, 10 ether, 10 ether, 10 ether);
        treasury.allocateRevenue(address(weth), 60 ether, 0, 0, 0);

        assertGe(reserve.backing(), backingBefore, "B never falls through this surface");
        assertEq(reserve.backing(), backingBefore + 10 ether, "it rose by exactly the Hard leg");
        assertEq(vux.totalSupply(), supplyBefore, "and nothing minted");

        // The Reserve has no function the treasury could call to move principal:
        // its entire state-changing surface is `redeem`, which the treasury has
        // no code path to invoke (FR-10.3) and which would need VUX it holds.
        (bool ok,) = address(reserve).call(abi.encodeWithSignature("sweep(address,uint256)", address(weth), 1));
        assertFalse(ok, "no sweep exists on the Reserve");
    }

    /// @dev **Pinned behaviour, raised for review disposition (reviewer.md "Judgment Calls").**
    ///
    ///      `realizedRevenue` is an accumulator, not a segregated balance — the
    ///      accepted bound is `Σ legs <= realizedRevenue[asset]` (sdd.md:L312),
    ///      with no custody condition attached. So an operator who earns revenue,
    ///      redeploys the assets behind it as risk capital, and loses them leaves
    ///      the credit standing: the distribution surface refuses nothing, and a
    ///      later payout draws on whatever the treasury holds by then.
    ///
    ///      Two things bound it, and both are the accepted design rather than an
    ///      accident: the payout still cannot exceed the credit, and every step
    ///      is an operator act that grants no power the operator lacks — an
    ///      operator willing to do this could deploy principal to a strategy they
    ///      control instead (the fraud-<=-theft argument, sdd.md:L302). The
    ///      alternative — refusing to deploy revenue-backed assets until
    ///      `toCompound` has converted them — is a real design option that no
    ///      accepted authority states, so it is surfaced rather than imposed.
    function test_ARedeployedAndLostRevenueCreditRemainsOutstanding() public {
        _earnRevenue(address(weth), 100 ether);
        assertEq(treasury.realizedRevenue(address(weth)), 100 ether, "revenue earned");

        // Redeploy everything in custody, including the assets behind the credit.
        uint256 all = weth.balanceOf(address(treasury));
        treasury.admitStrategy(address(strategy), address(weth), all, NETTING); // cap raised for the whole balance
        vm.warp(vm.getBlockTimestamp() + treasury.ADMISSION_DELAY());
        treasury.deployToStrategy(address(strategy), address(weth), all);

        // ...and lose it.
        vm.prank(address(strategy));
        weth.transfer(address(0xD3AD), all);
        treasury.removeStrategy(address(strategy), true);
        treasury.closeStrategy(address(strategy));

        assertEq(weth.balanceOf(address(treasury)), 0, "nothing left in custody");
        assertEq(treasury.realizedRevenue(address(weth)), 100 ether, "yet the credit still stands");

        // With nothing in custody the physical legs simply fail — the credit is
        // not a claim the contract can honour out of thin air.
        vm.expectPartialRevert(bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)")));
        treasury.allocateRevenue(address(weth), 0, 0, 1 ether, 0);

        // But a later principal inflow makes the standing credit payable, and
        // that is precisely the behaviour under review.
        _fundTreasury(address(weth), 10 ether);
        treasury.allocateRevenue(address(weth), 0, 0, 10 ether, 0);
        assertEq(weth.balanceOf(OPS_RECIPIENT), 10 ether, "paid from a later inflow against the standing credit");
    }

    // =========================================================================
    // unauthorized callers (AC-7)
    // =========================================================================

    function test_EveryRevenueMutatorRejectsAnUnauthorizedCaller() public {
        _earnRevenue(address(weth), 10 ether);

        vm.startPrank(NON_OPERATOR);

        _expectUnauthorized();
        treasury.allocateRevenue(address(weth), 1, 0, 0, 0);

        _expectUnauthorized();
        treasury.burnVuxRevenue();

        _expectUnauthorized();
        treasury.setOpsRecipient(NON_OPERATOR);

        vm.stopPrank();
    }
}

interface IApproves {
    function approve(address spender, uint256 amount) external returns (bool);
}
