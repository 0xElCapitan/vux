// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-14 acceptance (prd.md:L539), FR-15.1, FR-15.2, sdd.md:L711
//          sprint.md Sprint 6 Task 6.2 ("estimate parity against actual
//          settlement outcomes", "no-entitlement semantics")

import {LensFixture} from "./LensFixture.sol";

/// @title LensEstimateParityTest — tier 2 against the settlement it predicts.
/// @notice The tier-2 estimate is only truthful if it is the number a settlement
///         in this block would actually produce. That is not a claim source
///         review can settle: `Lens` reimplements the routing law rather than
///         calling into `Rig._route` (which is `internal`, and Sprint 3's
///         accepted implementation is not reopened to widen it). So the estimate
///         is compared field-by-field against the `Settled` record emitted by a
///         real settlement executed in the same block — the only comparison that
///         can catch a drifted constant or a missed branch.
///
///         The second half of this file asserts the other half of the
///         requirement: that reading any of it entitles the reader to nothing
///         (prd.md:L539).
contract LensEstimateParityTest is LensFixture {
    function setUp() public {
        _deploySystem();
        _deployLens();
    }

    // -----------------------------------------------------------------------
    // Parity
    // -----------------------------------------------------------------------

    /// @dev Bootstrap is the branch a naive reimplementation gets wrong: the
    ///      outgoing King *is* the Reserve, so `Rig.take` step 8a sends the King
    ///      leg to Hard as well, and a `hardTarget`-only estimate would understate
    ///      `qSafe`. `estimateQmint` is zero on both sides regardless — tier 1 is
    ///      zero during bootstrap — so this test is what holds the intermediate
    ///      field honest.
    function test_ParityAtBootstrap() public {
        vm.warp(block.timestamp + 450);

        (uint256 est, uint256 p, uint256 qRaw, uint256 qSafe, SettledRecord memory r) = _estimateThenSettle(ALICE);

        assertTrue(r.bootstrap, "the settlement under test really is the bootstrap");
        _assertParity(est, p, qRaw, qSafe, r, "bootstrap");
        assertEq(est, 0, "bootstrap mines nothing (FR-6.1)");
        assertEq(r.dR, r.reserveLeg + r.kingLeg, "and the King leg landed at Hard, as the estimate assumed");
    }

    function testFuzz_ParityOnOrdinarySettlements(uint256 elapsed) public {
        _consumeBootstrap();
        elapsed = bound(elapsed, 0, EPOCH_PERIOD * 2);
        vm.warp(block.timestamp + elapsed);

        (uint256 est, uint256 p, uint256 qRaw, uint256 qSafe, SettledRecord memory r) = _estimateThenSettle(BOB);

        assertFalse(r.bootstrap, "ordinary settlement");
        _assertParity(est, p, qRaw, qSafe, r, "ordinary");
    }

    /// @dev Parity must hold in both binding regimes, not just the common one.
    function test_ParityWhenTheClockBindsAndWhenVemBinds() public {
        _consumeBootstrap();

        vm.warp(block.timestamp + 60);
        (uint256 est1, uint256 p1, uint256 qRaw1, uint256 qSafe1, SettledRecord memory early) =
            _estimateThenSettle(BOB);
        _assertParity(est1, p1, qRaw1, qSafe1, early, "clock-limited");
        assertEq(early.qMint, early.qRaw, "clock-limited regime confirmed");

        vm.warp(block.timestamp + 2_900);
        (uint256 est2, uint256 p2, uint256 qRaw2, uint256 qSafe2, SettledRecord memory late) =
            _estimateThenSettle(CAROL);
        _assertParity(est2, p2, qRaw2, qSafe2, late, "VEM-limited");
        assertEq(late.qMint, late.qSafe, "VEM-limited regime confirmed");
        assertLt(late.qMint, late.qRaw, "and the shortfall expired unrecorded (INV-8)");
    }

    /// @dev Parity survives a moving `B` and `S`. A redemption changes both in
    ///      the same transaction, which is the state an estimate computed from
    ///      stale reads would get wrong.
    function test_ParityAfterRedemptionMovesBackingAndSupply() public {
        _consumeBootstrap();
        vm.warp(block.timestamp + 500);
        _takeRecorded(BOB); // ALICE is minted for her reign

        uint256 aliceBalance = vux.balanceOf(ALICE);
        assertGt(aliceBalance, 0, "ALICE mined VUX to redeem");

        (uint256 bBefore, uint256 sBefore,) = lens.hardStats();
        vm.prank(ALICE);
        reserve.redeem(aliceBalance / 2, ALICE);
        (uint256 bAfter, uint256 sAfter,) = lens.hardStats();
        assertLt(bAfter, bBefore, "backing fell");
        assertLt(sAfter, sBefore, "supply fell");

        vm.warp(block.timestamp + 700);
        (uint256 est, uint256 p, uint256 qRaw, uint256 qSafe, SettledRecord memory r) = _estimateThenSettle(CAROL);
        _assertParity(est, p, qRaw, qSafe, r, "post-redemption");
    }

    /// @dev Parity across a run of settlements, so a drift that only appears
    ///      after state has moved several times is caught.
    function test_ParityAcrossASequenceOfSettlements() public {
        _consumeBootstrap();

        address[3] memory contenders = [BOB, CAROL, ATTACKER];
        for (uint256 i = 0; i < contenders.length; i++) {
            vm.warp(block.timestamp + 400 * (i + 1));
            (uint256 est, uint256 p, uint256 qRaw, uint256 qSafe, SettledRecord memory r) =
                _estimateThenSettle(contenders[i]);
            _assertParity(est, p, qRaw, qSafe, r, string.concat("settlement #", vm.toString(i)));
        }
    }

    // -----------------------------------------------------------------------
    // No entitlement (prd.md:L539)
    // -----------------------------------------------------------------------

    /// @dev The estimate is not a floor, a reservation, or a promise. It falls
    ///      as the Dutch price decays, which is the concrete sense in which
    ///      "may rise or fall" is true rather than a disclaimer.
    function test_EstimateFallsAsThePriceDecays() public {
        _consumeBootstrap();
        uint256 start = block.timestamp;

        vm.warp(start + 1_500);
        (uint256 mid,,,) = lens.estimateIfDisplacedNow();

        vm.warp(start + 2_900);
        (uint256 later,,,) = lens.estimateIfDisplacedNow();

        assertGt(mid, 0, "there was something to lose");
        assertLt(later, mid, "the estimate fell with the price; nothing locked it in");
    }

    /// @dev Reading a truth surface is a read. It mints nothing, moves nothing,
    ///      and records no claim — asserted against every observable the protocol
    ///      has, not against the absence of a write in the source.
    function test_ReadingEveryViewChangesNoProtocolState() public {
        _consumeBootstrap();
        vm.warp(block.timestamp + 900);

        uint256 sBefore = vux.totalSupply();
        uint256 bBefore = reserve.backing();
        uint256 strategicBefore = rig.totalStrategicContributed();
        address kingBefore = rig.king();
        uint256 epochBefore = rig.epochId();
        uint256 callerBalanceBefore = vux.balanceOf(address(this));

        for (uint256 i = 0; i < 5; i++) {
            lens.rawClockLimit();
            lens.estimateIfDisplacedNow();
            lens.hardStats();
            lens.wethNeededForFullQraw();
            lens.strategicContributed();
        }

        assertEq(vux.totalSupply(), sBefore, "no VUX was minted by looking");
        assertEq(reserve.backing(), bBefore, "no WETH moved");
        assertEq(rig.totalStrategicContributed(), strategicBefore, "no contribution was booked");
        assertEq(rig.king(), kingBefore, "the throne did not change hands");
        assertEq(uint256(rig.epochId()), epochBefore, "no epoch advanced");
        assertEq(vux.balanceOf(address(this)), callerBalanceBefore, "the reader received nothing");
    }

    /// @dev The estimate describes the *throne-holder's* settlement, not the
    ///      reader's. Whoever reads it — including a contender about to displace
    ///      the King — receives nothing by having read it.
    function test_TheReaderOfTheEstimateReceivesNothing() public {
        _consumeBootstrap();
        vm.warp(block.timestamp + 800);

        vm.prank(ATTACKER);
        (uint256 est,,,) = lens.estimateIfDisplacedNow();
        assertGt(est, 0, "a non-trivial estimate was read");

        SettledRecord memory r = _takeRecorded(BOB);

        assertEq(vux.balanceOf(ATTACKER), 0, "the reader mined nothing");
        assertEq(vux.balanceOf(BOB), 0, "nor did the incoming King, whose reign has not settled");
        assertEq(r.outgoingKing, ALICE, "the mint belonged to the reign that ended");
        assertEq(vux.balanceOf(ALICE), r.qMint, "and it was exactly the settled amount");
    }

    /// @dev Raw opportunity that VEM could not support leaves no trace anywhere:
    ///      no carry, no IOU, no makeup on the next settlement (FR-5.5, INV-8).
    ///      The next reign starts from zero regardless of what the last one lost.
    function test_UnsupportedOpportunityIsNotCarriedIntoTheNextReign() public {
        _consumeBootstrap();

        vm.warp(block.timestamp + 2_900);
        SettledRecord memory starved = _takeRecorded(BOB);
        assertLt(starved.qMint, starved.qRaw, "this reign lost opportunity to VEM");

        // A fresh reign, one second in: the ceiling is one second of clock and
        // carries none of the previous shortfall.
        vm.warp(block.timestamp + 1);
        assertEq(lens.rawClockLimit(), rig.epochUPS(), "exactly one second of new opportunity");

        (uint256 est,, uint256 qRaw,) = lens.estimateIfDisplacedNow();
        assertEq(qRaw, rig.epochUPS(), "no shortfall was added back");
        assertLe(est, qRaw, "and the estimate is still capped by the clock");
    }
}
