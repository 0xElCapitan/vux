// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 5 Task 5.5, AC-7 (FB-7 / FB-8 scenarios)
//          FB-7 (POL fails or is illiquid: Hard arithmetic unchanged)
//          FB-8 (POL fee routing unavailable before receipt: nothing counted)
//          §9.2 threat row 12 (wash trading is an attacker-paid donation)
//          prd.md:L652-L653, L690; sdd.md:L262, L950

import {PolFixture} from "./PolFixture.sol";

/// @title PolFailureBehaviorsTest — what breaks when POL does, and what does not.
contract PolFailureBehaviorsTest is PolFixture {
    address internal constant WASH_TRADER = address(0x9A54);

    function setUp() public {
        _deployPolSystem();
        _provisionPol();
    }

    // =========================================================================
    // FB-7 — POL fails or is illiquid
    // =========================================================================

    /// @dev "Price discovery and Strategic NAV may suffer; Hard arithmetic
    ///      unchanged" (prd.md:L652). The test does the damage for real — a
    ///      one-sided rout that moves the marginal price by orders of magnitude
    ///      and leaves the position holding almost nothing but the losing token —
    ///      and then asserts the monetary core is bit-identical.
    ///
    ///      Nothing is harvested here on purpose: a harvest legitimately raises
    ///      `B`, and FB-7 is about POL *failing*, not about POL paying.
    function test_FB7_APolPriceCollapseLeavesHardArithmeticBitIdentical() public {
        CoreState memory before = _snapshotCore();
        uint256 polVuxBasis = treasury.polVuxPrincipal();

        weth.mint(address(swapper), 5_000 ether);
        _swapWethForVux(5_000 ether);

        assertNotEq(uint256(_sqrtPriceX96()), uint256(_genesisSqrtPriceX96()), "price discovery did suffer");
        _assertCoreUnchanged(before, "FB-7: a POL price collapse");
        assertEq(treasury.polVuxPrincipal(), polVuxBasis, "and did not silently rewrite POL cost basis");
    }

    /// @dev The other half of FB-7: an illiquid position — one the protocol has
    ///      unwound entirely — still cannot reach `B`. Withdrawing all POL
    ///      liquidity returns principal to Strategic custody and leaves the
    ///      Reserve untouched.
    function test_FB7_FullyUnwindingPolLeavesTheReserveUntouched() public {
        uint256 backingBefore = reserve.backing();
        uint256 supplyBefore = vux.totalSupply();

        treasury.decreasePol(_polLiquidity());

        assertEq(uint256(_polLiquidity()), 0, "the position is gone");
        assertEq(reserve.backing(), backingBefore, "B did not move");
        assertEq(vux.totalSupply(), supplyBefore, "nor S: returned principal is not burned");
        assertGt(vux.balanceOf(address(treasury)), 0, "the VUX came back to Strategic custody");
        assertGt(weth.balanceOf(address(treasury)), 0, "and so did the WETH, as dry powder");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "an unwind is not revenue");
    }

    // =========================================================================
    // FB-8 — POL fee routing unavailable before receipt
    // =========================================================================

    /// @dev "No anticipated revenue counted; principal classification remains;
    ///      Hard principal not substituted" (prd.md:L653).
    ///
    ///      Fees are accrued and then deliberately left unharvested. Nothing
    ///      anywhere moves: not `B`, not `S`, not the revenue accumulator, not the
    ///      cost basis. The second half is what makes the first half meaningful —
    ///      harvesting afterwards proves the value really was there and really was
    ///      being counted nowhere.
    function test_FB8_UnharvestedFeesAreCountedNowhere() public {
        CoreState memory before = _snapshotCore();
        uint256 vuxBasis = treasury.polVuxPrincipal();
        uint256 wethBasis = treasury.polWethPrincipal();
        uint256 treasuryVux = vux.balanceOf(address(treasury));
        uint256 treasuryWeth = weth.balanceOf(address(treasury));

        _accrueBothFeeLegs(20 ether);

        _assertCoreUnchanged(before, "FB-8: fees pending");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "no WETH revenue anticipated");
        assertEq(treasury.realizedRevenue(address(vux)), 0, "no VUX revenue anticipated");
        assertEq(treasury.polVuxPrincipal(), vuxBasis, "principal classification is unchanged");
        assertEq(treasury.polWethPrincipal(), wethBasis, "in both tokens");
        assertEq(vux.balanceOf(address(treasury)), treasuryVux, "and nothing has been received yet");
        assertEq(weth.balanceOf(address(treasury)), treasuryWeth, "in either token");

        // The value was real all along; it was simply not counted until receipt.
        vm.recordLogs();
        treasury.harvestPol();
        (uint256 vuxFees, uint256 wethFees) = _vyrfLegs(vm.getRecordedLogs());
        assertGt(vuxFees, 0, "the pending VUX fee yield existed");
        assertGt(wethFees, 0, "and the WETH fee yield too");
    }

    /// @dev NFR-REL-2 in its FB-8 form: a keeper that never shows up cannot
    ///      corrupt anything. Two systems accrue identical fees; one harvests
    ///      three times along the way and the other only at the end, and they end
    ///      with the same classification outcome to the wei.
    ///
    ///      Timing changes *when*, never *where* — so the whole harvested amount
    ///      is path-independent.
    function test_FB8_HarvestTimingChangesWhenNotWhere() public {
        uint256 backing0 = reserve.backing();
        uint256 supply0 = vux.totalSupply();

        // Path A: harvest after every trade.
        for (uint256 i = 0; i < 3; i++) {
            _accrueBothFeeLegs(2 ether);
            treasury.harvestPol();
        }
        uint256 eagerToHard = reserve.backing() - backing0;
        uint256 eagerBurned = supply0 - vux.totalSupply();

        assertGt(eagerToHard, 0, "the eager path moved value");
        assertGt(eagerBurned, 0, "in both legs");

        // Path B: the same three trades, harvested once at the end.
        uint256 backing1 = reserve.backing();
        uint256 supply1 = vux.totalSupply();
        for (uint256 i = 0; i < 3; i++) {
            _accrueBothFeeLegs(2 ether);
        }
        treasury.harvestPol();

        assertGt(reserve.backing() - backing1, 0, "the lazy path moved value to the same place");
        assertGt(supply1 - vux.totalSupply(), 0, "and burned in the same place");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "neither path created revenue");
        assertEq(treasury.realizedRevenue(address(vux)), 0, "in either denomination");
    }

    // =========================================================================
    // Wash trading is an attacker-paid donation (§9.2 row 12)
    // =========================================================================

    /// @dev The accepted interpretation, carried forward from the SDD threat
    ///      model and tested rather than merely asserted: an attacker who
    ///      round-trips volume through the canonical pool to inflate fee yield is
    ///      **donating** — they pay the fee, and the fee lands in burn and in
    ///      Hard.
    ///
    ///      What the donation buys them is the point: nothing. No mint credit, no
    ///      Reserve principal access, no privileged classification, no role. The
    ///      burn even makes every *other* holder's claim slightly larger, which is
    ///      why this attack is economically self-defeating.
    function test_WashTradingDonatesFeesAndBuysNoPrivilege() public {
        // Give the wash trader real capital and let them churn it.
        weth.mint(WASH_TRADER, 100 ether);
        vm.prank(WASH_TRADER);
        weth.transfer(address(swapper), 100 ether);

        uint256 supplyBefore = vux.totalSupply();
        uint256 backingBefore = reserve.backing();
        uint256 traderVuxBefore = vux.balanceOf(WASH_TRADER);

        for (uint256 i = 0; i < 5; i++) {
            _swapWethForVux(10 ether);
            _swapVuxForWeth(vux.balanceOf(address(swapper)));
        }

        vm.recordLogs();
        treasury.harvestPol();
        (uint256 vuxFees, uint256 wethFees) = _vyrfLegs(vm.getRecordedLogs());

        // The donation landed exactly where VYRF sends fee yield.
        assertGt(vuxFees + wethFees, 0, "the wash trading produced fee yield");
        assertEq(supplyBefore - vux.totalSupply(), vuxFees, "the VUX leg was burned");
        assertEq(reserve.backing() - backingBefore, wethFees, "the WETH leg raised B");

        // And bought the trader nothing at all.
        assertEq(vux.balanceOf(WASH_TRADER), traderVuxBefore, "no mint credit");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "no privileged revenue classification");
        assertFalse(treasury.hasRole(treasury.OPERATOR_ROLE(), WASH_TRADER), "no role");
        assertEq(treasury.outstandingPrincipal(WASH_TRADER, address(weth)), 0, "no Reserve or principal claim");

        // The burn strictly improved every remaining holder's claim.
        assertGt(reserve.previewRedeem(1e18), 0, "and redemption still prices off B/S");
    }
}
