// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-6.1, FR-6.2, FR-6.3, INV-7, INV-22
//          sprint.md Sprint 3 AC-5 (bootstrap, confirm-only)

import {RigFixture} from "./RigFixture.sol";
import {Rig} from "../../src/Rig.sol";

/// @title RigBootstrapTest — the one-time genesis state, and its exit.
/// @notice Bootstrap is confirm-only: no special economics are computed for it.
///         The ≈88%+/12%/zero-mint result is what the *ordinary* adaptive law
///         produces when `Qraw = 0` and the outgoing King happens to be the Hard
///         Reserve. This suite proves exactly that — that the result is a
///         consequence rather than a special case — and that the state cannot be
///         re-entered.
contract RigBootstrapTest is RigFixture {
    function setUp() public {
        _deploySystem();
    }

    /*----------  the genesis state (FR-6.1)  ------------------------------*/

    function test_TheReserveIsTheGenesisKingAndTheClockIsOff() public view {
        assertEq(rig.king(), address(reserve), "the ownerless Hard Reserve holds the throne");
        assertEq(rig.epochUPS(), 0, "the bootstrap clock is disabled in storage");
        assertEq(uint256(rig.scheduleStart()), 0, "the public schedule has not started");
        assertEq(uint256(rig.epochId()), 0, "no settlement has occurred");
        assertEq(uint256(rig.epochOpening()), BOOTSTRAP_OPENING, "the bootstrap Dutch decay anchors at its own opening");
    }

    function test_TheBootstrapStateIsVisibleThroughEpochState() public view {
        (address king_,, uint256 opening_, uint256 ups_, bool bootstrap_) = rig.epochState();
        assertEq(king_, address(reserve), "king");
        assertEq(opening_, BOOTSTRAP_OPENING, "opening");
        assertEq(ups_, 0, "ups");
        assertTrue(bootstrap_, "epochState reports the bootstrap flag");
    }

    /*----------  the first public takeover (FR-6.2/6.3)  -------------------*/

    /// @dev The whole of FR-6.3's economic result, asserted on one settlement.
    ///      Note what is *not* here: no bootstrap-specific split, no special
    ///      percentage. The King leg lands in Hard only because the Reserve is
    ///      the outgoing King.
    function test_TheFirstTakeoverRoutesEverythingButTheCapToHardAndMintsZero() public {
        uint256 bPre = reserve.backing();
        uint256 treasuryPre = weth.balanceOf(TREASURY);
        uint256 supplyPre = vux.totalSupply();
        uint256 price = rig.currentPrice();

        SettledRecord memory r = _takeRecorded(ALICE);

        // The adaptive law at Qraw = 0.
        uint256 expectedKing = (price * 8_000) / 10_000;
        uint256 expectedCap = (price * 1_200) / 10_000;
        uint256 expectedHardFloor = price - expectedKing - expectedCap;

        assertTrue(r.bootstrap, "the record marks it as the bootstrap settlement");
        assertEq(r.qRaw, 0, "the clock was disabled, so there was no raw opportunity (FR-6.1)");
        assertEq(r.qMint, 0, "bootstrap mints zero (INV-7)");
        assertEq(vux.totalSupply(), supplyPre, "total supply is untouched");

        assertEq(r.reserveLeg, expectedHardFloor, "hardTarget degenerated to hardFloor");
        assertEq(r.strategicLeg, expectedCap, "strategic degenerated to the floored 12% cap");
        assertEq(r.kingLeg, expectedKing, "the King leg is the ordinary 80%");

        // Physically: Hard received its own leg PLUS the King leg, because it was
        // the outgoing King. That is the ≈88%+ (INV-22).
        assertEq(reserve.backing() - bPre, expectedHardFloor + expectedKing, "Hard received hardFloor + the King leg");
        assertEq(r.dR, expectedHardFloor + expectedKing, "and the measured delta is exactly that");
        assertEq(weth.balanceOf(TREASURY) - treasuryPre, expectedCap, "Strategic received the floored 12% cap");
        assertEq(weth.balanceOf(address(rig)), 0, "P was fully exhausted");
    }

    /// @dev INV-22 as a proportion rather than as wei: Hard takes at least 88%,
    ///      Strategic at most 12%, and nothing is minted. Fuzzed over the whole
    ///      bootstrap epoch, since the price the first taker pays is their choice
    ///      of moment.
    function testFuzz_TheFirstTakeoverAlwaysSendsAtLeastEightyEightPercentToHard(uint256 delay) public {
        delay = bound(delay, 0, 2 * EPOCH_PERIOD);
        vm.warp(rig.epochStart() + delay);

        uint256 bPre = reserve.backing();
        SettledRecord memory r = _takeRecorded(ALICE);

        uint256 hardReceived = reserve.backing() - bPre;
        assertGe(hardReceived * 10_000, r.price * 8_800, "Hard received >= 88% of P");
        assertLe(r.strategicLeg * 10_000, r.price * 1_200, "Strategic received <= 12% of P");
        assertEq(hardReceived + r.strategicLeg, r.price, "the two destinations exhaust P");
        assertEq(r.qMint, 0, "and nothing was minted");
    }

    function test_ThePayerBecomesTheFirstPublicKingAtTheCurrentScheduleRate() public {
        _take(ALICE);

        assertEq(rig.king(), ALICE, "the payer holds the throne");
        assertEq(uint256(rig.scheduleStart()), block.timestamp, "the public clock starts now (prd.md:L176)");
        assertEq(uint256(rig.epochStart()), block.timestamp, "their epoch opens now");
        assertEq(rig.epochUPS(), INITIAL_UPS, "their epoch snapshots the current schedule rate, 4 VUX/s");
    }

    /// @dev No deployer, founder, operator, or partner receives bootstrap value
    ///      (FR-6.3). The only WETH destinations are Hard and Strategic; the only
    ///      VUX movement is none at all.
    function test_NoPrivilegedPartyReceivesBootstrapValue() public {
        uint256 deployerWethPre = weth.balanceOf(address(this));
        uint256 deployerVuxPre = vux.balanceOf(address(this));

        SettledRecord memory r = _takeRecorded(ALICE);

        assertEq(weth.balanceOf(address(this)), deployerWethPre, "the deploying account received no WETH");
        assertEq(vux.balanceOf(address(this)), deployerVuxPre, "and no VUX");
        assertEq(vux.balanceOf(ALICE), 0, "not even the payer receives VUX at bootstrap");
        assertEq(weth.balanceOf(address(reserve)) + weth.balanceOf(TREASURY), B0 + r.price, "every wei is accounted for");
    }

    /*----------  no second bootstrap (FR-6.3 acceptance)  ------------------*/

    /// @dev After the first takeover the state is structurally unreachable: the
    ///      Reserve can only become King again by calling `take`, and its entire
    ///      external surface is `redeem` plus views — it has no code path that
    ///      can call anything. The assertions below are the observable half of
    ///      that argument.
    function test_NoSecondBootstrapStateIsReachable() public {
        _consumeBootstrap();
        uint256 firstScheduleStart = rig.scheduleStart();

        for (uint256 i = 0; i < 5; i++) {
            vm.warp(rig.epochStart() + 600);
            SettledRecord memory r = _takeRecorded(BOB);

            assertFalse(r.bootstrap, "no later settlement is ever a bootstrap settlement");
            assertNotEq(rig.king(), address(reserve), "the Reserve never regains the throne");
            assertEq(uint256(rig.scheduleStart()), firstScheduleStart, "scheduleStart is written once and never again");

            vm.warp(rig.epochStart() + 600);
            _take(CAROL);
        }
    }

    /// @dev The structural argument for FR-6.3 is that the Reserve cannot call
    ///      `take` — its entire external surface is `redeem` plus views. This
    ///      test deliberately over-approximates the attacker by *fabricating*
    ///      that impossible caller with `vm.prank`, funding and approving on the
    ///      Reserve's behalf, and finds that settlement still refuses.
    ///
    ///      The reason is measurement, not authority. Paying pulls `P` out of the
    ///      payer, so a Reserve-funded takeover would *reduce* `B` mid-settlement
    ///      by more than the Hard leg puts back; `D_R = balanceOf(reserve) − B_pre`
    ///      is then negative and the subtraction reverts. Fail-closed, and one
    ///      layer below the `InconsistentReserveDelta` check.
    ///
    ///      So the Reserve can never be re-seated on the throne even by a caller
    ///      the EVM cannot produce, and no second bootstrap state exists.
    function test_AFabricatedReserveInitiatedTakeStillCannotReseatTheReserve() public {
        _consumeBootstrap();

        vm.warp(rig.epochStart() + 500);
        uint256 price = rig.currentPrice();
        weth.mint(address(reserve), price);
        vm.prank(address(reserve));
        weth.approve(address(rig), type(uint256).max);

        vm.expectRevert(); // arithmetic revert on the negative measured delta
        vm.prank(address(reserve));
        rig.take(type(uint256).max);

        assertEq(rig.king(), ALICE, "the throne did not change hands");
        assertNotEq(rig.king(), address(reserve), "the Reserve was not re-seated");
        assertNotEq(uint256(rig.scheduleStart()), 0, "the public clock is still running");
    }
}
