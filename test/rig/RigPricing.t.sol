// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-2.2, FR-2.3, FR-2.4, FR-2.5, FR-3.1, FR-3.2, FR-3.3, FR-3.4,
//          INV-8, INV-9
//          sprint.md Sprint 3 AC-1 (price boundaries), AC-2 (UPS schedule)

import {RigFixture} from "./RigFixture.sol";
import {Rig} from "../../src/Rig.sol";

/// @title RigPricingTest — the Dutch price and the mining clock, at their edges.
/// @notice Both frozen functions are piecewise, so the interesting behaviour is
///         entirely at the joins: `t = 0`, `t = EPOCH_PERIOD`, past it, the point
///         the decay meets the floor, and each of the eight halving instants.
///         Every boundary below is asserted at the exact second, and — where a
///         boundary could be off by one — at the second either side of it.
contract RigPricingTest is RigFixture {
    function setUp() public {
        _deploySystem();
    }

    /*----------  Dutch price (FR-2.2/2.3/2.5)  --------------------------*/

    function test_PriceAtEpochOpenIsTheOpening() public view {
        assertEq(rig.currentPrice(), BOOTSTRAP_OPENING, "price(t=0) == opening");
    }

    function test_PriceDecaysLinearlyAcrossTheEpoch() public {
        uint256 start = rig.epochStart();

        vm.warp(start + 750);
        assertEq(rig.currentPrice(), BOOTSTRAP_OPENING - BOOTSTRAP_OPENING / 4, "price(t=750) == 75% of opening");

        vm.warp(start + 1_500);
        assertEq(rig.currentPrice(), BOOTSTRAP_OPENING / 2, "price(t=1500) == 50% of opening");

        vm.warp(start + 2_250);
        assertEq(rig.currentPrice(), BOOTSTRAP_OPENING - (BOOTSTRAP_OPENING * 2_250) / 3_000, "price(t=2250)");
    }

    /// @dev The `elapsed >= EPOCH_PERIOD` join must not fire one second early.
    ///
    ///      The rehearsal values cannot show this: a 25 ether opening meets the
    ///      0.5 ether floor at t = 2940, so at t = 2999 the price is already
    ///      floored and "the ramp ended" is indistinguishable from "the floor
    ///      clipped". A probe instance whose floor sits below the final ramp step
    ///      separates them. It is constructed for its price function alone —
    ///      `currentPrice` reads only this contract's own storage and immutables,
    ///      so the probe needs no wiring into the token.
    function test_TheExpiryJoinDoesNotFireOneSecondEarly() public {
        Rig probe =
            new Rig(address(weth), address(reserve), address(vux), TREASURY, 3_000 ether, MINIMUM_OPENING, 1 wei);
        uint256 start = probe.epochStart();

        vm.warp(start + EPOCH_PERIOD - 1);
        assertEq(probe.currentPrice(), 1 ether, "t=2999 is still the last step of the ramp");
        assertGt(probe.currentPrice(), 1 wei, "and it is well above this probe's floor");

        vm.warp(start + EPOCH_PERIOD);
        assertEq(probe.currentPrice(), 1 wei, "t=3000 lands exactly on the floor");
    }

    function test_PriceAtAndBeyondExpiryIsTheFloorForever() public {
        uint256 start = rig.epochStart();

        vm.warp(start + EPOCH_PERIOD);
        assertEq(rig.currentPrice(), DECAY_FLOOR, "price(t=3000) == DECAY_FLOOR");

        vm.warp(start + EPOCH_PERIOD + 1);
        assertEq(rig.currentPrice(), DECAY_FLOOR, "price(t=3001) == DECAY_FLOOR");

        vm.warp(start + 3_650 days);
        assertEq(rig.currentPrice(), DECAY_FLOOR, "price ten years later == DECAY_FLOOR: it waits, it does not expire");
    }

    /// @dev The floor clips the ramp *before* `EPOCH_PERIOD` whenever the opening
    ///      is low enough for the linear decay to reach it early. With the
    ///      minimum opening (5 ether) and a 0.5 ether floor, the ramp crosses the
    ///      floor at t = 2700.
    function test_TheFloorClipsTheRampBeforeExpiry() public {
        // Reach an epoch whose opening is exactly MINIMUM_OPENING: after the
        // bootstrap take, decay to the floor so 2×P is below the minimum.
        _consumeBootstrap();
        vm.warp(rig.epochStart() + EPOCH_PERIOD);
        _take(BOB);
        assertEq(rig.epochOpening(), MINIMUM_OPENING, "successor opened at the minimum");

        uint256 start = rig.epochStart();
        uint256 crossing = 2_700; // MINIMUM_OPENING × (1 − 2700/3000) == 0.5 ether

        vm.warp(start + crossing - 1);
        assertGt(rig.currentPrice(), DECAY_FLOOR, "one second before the crossing, still above the floor");

        vm.warp(start + crossing);
        assertEq(rig.currentPrice(), DECAY_FLOOR, "at the crossing the ramp equals the floor");

        vm.warp(start + crossing + 1);
        assertEq(rig.currentPrice(), DECAY_FLOOR, "past the crossing the floor clips the ramp, before expiry");
    }

    /// @dev Two properties that must hold at every instant of any epoch: the
    ///      price never rises within an epoch, and never falls below the floor.
    function testFuzz_PriceIsNonIncreasingAndFloored(uint256 tA, uint256 tB) public {
        uint256 start = rig.epochStart();
        tA = bound(tA, 0, 20_000);
        tB = bound(tB, tA, 20_000);

        vm.warp(start + tA);
        uint256 earlier = rig.currentPrice();
        vm.warp(start + tB);
        uint256 later = rig.currentPrice();

        assertLe(later, earlier, "price never rises within an epoch");
        assertGe(later, DECAY_FLOOR, "price never falls below DECAY_FLOOR");
        assertLe(earlier, BOOTSTRAP_OPENING, "price never exceeds the opening");
    }

    /*----------  successor opening ladder (FR-2.3)  ---------------------*/

    function test_SuccessorOpensAtTwiceThePaidPrice() public {
        _consumeBootstrap();

        // Take early in the epoch so 2×P clears MINIMUM_OPENING comfortably.
        uint256 paid = rig.currentPrice();
        assertGt(paid * 2, MINIMUM_OPENING, "this branch requires 2P > MINIMUM_OPENING");

        _take(BOB);
        assertEq(rig.epochOpening(), paid * 2, "successor opening == 2 x P");
    }

    function test_SuccessorOpensAtTheMinimumWhenTwicePriceIsBelowIt() public {
        _consumeBootstrap();

        // Let the epoch fully decay: P == DECAY_FLOOR == 0.5 ether, so 2P == 1
        // ether, which is below MINIMUM_OPENING == 5 ether.
        vm.warp(rig.epochStart() + EPOCH_PERIOD);
        uint256 paid = rig.currentPrice();
        assertEq(paid, DECAY_FLOOR, "fully decayed");
        assertLt(paid * 2, MINIMUM_OPENING, "this branch requires 2P < MINIMUM_OPENING");

        _take(BOB);
        assertEq(rig.epochOpening(), MINIMUM_OPENING, "successor opening == MINIMUM_OPENING");
    }

    /// @dev FR-2.4: the 2x multiplier is a price ladder only. Two settlements
    ///      identical except for their opening price mint identically, because
    ///      `Qraw` depends on elapsed time and the UPS snapshot alone.
    function test_ThePriceMultiplierHasNoIssuanceEffect() public {
        _consumeBootstrap();

        vm.warp(rig.epochStart() + 1_000);
        SettledRecord memory first = _takeRecorded(BOB);

        vm.warp(rig.epochStart() + 1_000);
        SettledRecord memory second = _takeRecorded(CAROL);

        assertGt(second.price, first.price, "the ladder did raise the price");
        assertEq(second.qRaw, first.qRaw, "identical elapsed time yields identical raw opportunity");
    }

    /*----------  UPS schedule (FR-3.1/3.3)  -----------------------------*/

    /// @dev The full frozen table: 4 / 2 / 1 / 0.5 / 0.25 / 0.125 / 0.0625 /
    ///      0.03125 / 0.015625 VUX per second (prd.md:L359). Each boundary is
    ///      asserted at the exact halving second and one second before it, so a
    ///      shifted comparison cannot pass.
    function test_UpsMatchesTheFrozenTableAtEveryHalvingBoundary() public {
        _consumeBootstrap();
        uint256 scheduleStart = rig.scheduleStart();

        uint256[9] memory expected = [
            uint256(4e18),
            2e18,
            1e18,
            0.5e18,
            0.25e18,
            0.125e18,
            0.0625e18,
            0.03125e18,
            0.015625e18
        ];

        for (uint256 halving = 0; halving < 9; halving++) {
            vm.warp(scheduleStart + halving * HALVING_PERIOD);
            assertEq(rig.currentUPS(), expected[halving], "UPS at the exact halving boundary");

            if (halving > 0) {
                vm.warp(scheduleStart + halving * HALVING_PERIOD - 1);
                assertEq(rig.currentUPS(), expected[halving - 1], "UPS one second before the boundary");
            }
        }
    }

    function test_TheTailIsPermanent() public {
        _consumeBootstrap();
        uint256 scheduleStart = rig.scheduleStart();

        vm.warp(scheduleStart + 240 days);
        assertEq(rig.currentUPS(), 0.015625e18, "day 240 is the tail");

        vm.warp(scheduleStart + 3_650 days);
        assertEq(rig.currentUPS(), 0.015625e18, "ten years in, still exactly the tail: a ninth halving never happens");

        vm.warp(scheduleStart + 36_500 days);
        assertEq(rig.currentUPS(), 0.015625e18, "a century in, still the tail");
    }

    function test_TheScheduleIsAtItsHeadBeforeTheClockStarts() public view {
        assertEq(uint256(rig.scheduleStart()), 0, "bootstrap: the public clock has not started");
        assertEq(rig.currentUPS(), INITIAL_UPS, "the first public epoch opens at the initial rate");
    }

    /*----------  epoch snapshot (FR-3.4)  --------------------------------*/

    /// @dev A halving during an open reign must not touch that reign's rate. The
    ///      epoch is opened just before a halving and settled well after it; the
    ///      settled `Qraw` must use the snapshot, not the current rate.
    function test_AHalvingDuringAnOpenReignDoesNotChangeItsSnapshot() public {
        _consumeBootstrap();
        uint256 scheduleStart = rig.scheduleStart();

        // Open BOB's epoch one second before the first halving.
        vm.warp(scheduleStart + HALVING_PERIOD - 1);
        _take(BOB);
        assertEq(rig.epochUPS(), INITIAL_UPS, "epoch snapshotted the pre-halving rate");

        // Settle it 100 seconds later — comfortably past the halving instant.
        vm.warp(scheduleStart + HALVING_PERIOD + 99);
        assertEq(rig.currentUPS(), INITIAL_UPS / 2, "the schedule itself has halved");

        SettledRecord memory r = _takeRecorded(CAROL);
        assertEq(r.qRaw, 100 * INITIAL_UPS, "Qraw used the opening snapshot, not the halved rate");
        assertEq(r.epochUPS, INITIAL_UPS / 2, "the successor epoch snapshots the halved rate");
    }

    /*----------  raw opportunity cap and expiry (FR-3.2, INV-8/9)  -------*/

    function test_QrawCapsAtExactlyThreeThousandSeconds() public {
        _consumeBootstrap();
        uint256 snapshotUps = rig.epochUPS();

        vm.warp(rig.epochStart() + EPOCH_PERIOD);
        SettledRecord memory atCap = _takeRecorded(BOB);
        assertEq(atCap.qRaw, EPOCH_PERIOD * snapshotUps, "Qraw at exactly 3000s == 3000 x epochUPS");
    }

    function test_QrawOneSecondShortOfTheCapIsOneSecondShort() public {
        _consumeBootstrap();
        uint256 snapshotUps = rig.epochUPS();

        vm.warp(rig.epochStart() + EPOCH_PERIOD - 1);
        SettledRecord memory r = _takeRecorded(BOB);
        assertEq(r.qRaw, (EPOCH_PERIOD - 1) * snapshotUps, "the cap does not round up to a full epoch");
    }

    /// @dev INV-8/INV-9: time beyond the cap accrues nothing, and it does not
    ///      accumulate silently for a later settlement either.
    function test_TimeBeyondTheCapCreatesNoCarry() public {
        _consumeBootstrap();
        uint256 snapshotUps = rig.epochUPS();

        vm.warp(rig.epochStart() + 100 * EPOCH_PERIOD);
        SettledRecord memory r = _takeRecorded(BOB);
        assertEq(r.qRaw, EPOCH_PERIOD * snapshotUps, "a reign 100x the cap still earns exactly the cap");

        // And the next epoch starts from zero, carrying nothing forward.
        vm.warp(rig.epochStart() + 10);
        SettledRecord memory next = _takeRecorded(CAROL);
        assertEq(next.qRaw, 10 * rig.epochUPS(), "the following epoch starts from zero");
    }

    function testFuzz_QrawIsElapsedCappedTimesTheSnapshot(uint256 elapsed) public {
        _consumeBootstrap();
        elapsed = bound(elapsed, 0, 50_000);
        uint256 snapshotUps = rig.epochUPS();

        vm.warp(rig.epochStart() + elapsed);
        SettledRecord memory r = _takeRecorded(BOB);

        uint256 eligible = elapsed > EPOCH_PERIOD ? EPOCH_PERIOD : elapsed;
        assertEq(r.qRaw, eligible * snapshotUps, "Qraw == min(elapsed, 3000) x snapshotted UPS");
        assertLe(r.qRaw, EPOCH_PERIOD * snapshotUps, "Qraw never exceeds the cap");
    }
}
