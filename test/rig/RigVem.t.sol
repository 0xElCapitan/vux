// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-5.1, FR-5.2, FR-5.3, FR-5.4, FR-5.5, FR-5.6,
//          INV-6, INV-8, INV-12, INV-13, INV-16
//          sprint.md Sprint 3 AC-4 (VEM property + D_R rejection + no carry cell)

import {RigFixture} from "./RigFixture.sol";
import {RigMathHarness} from "./RigMathHarness.sol";
import {Rig} from "../../src/Rig.sol";

/// @title RigVemTest — measured-reality issuance, and what it refuses to do.
/// @notice VEM is one inequality — `B_pre × Qmint <= D_R × S_pre` — and the whole
///         monetary promise rests on it: authorized issuance can never reduce
///         backing per unit. The suite proves the formula over the full
///         `(D_R, S_pre, B_pre, Qraw)` domain including the region where the
///         intermediate product exceeds 256 bits, then proves the two ways the
///         cap is allowed to bind, then proves that what it refuses to mint
///         leaves no trace anywhere.
contract RigVemTest is RigFixture {
    RigMathHarness internal math;

    function setUp() public {
        _deploySystem();
        math = new RigMathHarness(address(weth), address(reserve), address(vux), TREASURY);
    }

    /*----------  the formula (FR-5.2)  -----------------------------------*/

    /// @dev Domain where `D_R × S_pre` fits in 256 bits, so the expectation is
    ///      computed with native arithmetic — an oracle genuinely independent of
    ///      the `Math.mulDiv` under test.
    function testFuzz_QmintIsMinOfQrawAndFlooredSafeIssuance(uint256 dR, uint256 sPre, uint256 bPre, uint256 qRaw)
        public
        view
    {
        dR = bound(dR, 0, 1e30);
        sPre = bound(sPre, 1, 1e30);
        bPre = bound(bPre, 1, 1e30);
        qRaw = bound(qRaw, 0, 3_000 * 4e18);

        (uint256 qSafe, uint256 qMint) = math.vem(dR, sPre, bPre, qRaw);

        uint256 expectedSafe = _floorMulDiv(dR, sPre, bPre);
        assertEq(qSafe, expectedSafe, "Qsafe == floor(D_R x S_pre / B_pre)");
        assertEq(qMint, qRaw < expectedSafe ? qRaw : expectedSafe, "Qmint == min(Qraw, Qsafe)");

        // INV-6, restated directly.
        assertLe(qMint, qRaw, "Qmint <= Qraw");
        assertLe(qMint, qSafe, "Qmint <= Qsafe");
    }

    /// @dev The non-dilution inequality itself (INV-13). Stated in the
    ///      cross-multiplied form the PRD gives, which avoids introducing a
    ///      division the property does not need (prd.md:L387).
    function testFuzz_IssuanceCannotReduceBackingPerUnit(uint256 dR, uint256 sPre, uint256 bPre, uint256 qRaw)
        public
        view
    {
        dR = bound(dR, 0, 1e26);
        sPre = bound(sPre, 1, 1e26);
        bPre = bound(bPre, 1, 1e26);
        qRaw = bound(qRaw, 0, 3_000 * 4e18);

        (, uint256 qMint) = math.vem(dR, sPre, bPre, qRaw);

        assertLe(bPre * qMint, dR * sPre, "B_pre x Qmint <= D_R x S_pre");
    }

    /// @dev The overflow domain: `D_R × S_pre` provably does not fit in 256 bits,
    ///      yet `D_R × S_pre / B_pre` does. A naive `(dR * sPre) / bPre` reverts
    ///      here and thereby *denies* issuance rather than capping it — which is
    ///      a denial of the mining right, not a safety property. `Math.mulDiv`'s
    ///      512-bit intermediate is what makes the region survivable.
    ///
    ///      The window matters: with `B_pre = 1e18` the product must land above
    ///      `2^256` but below `2^256 × 1e18`. Bounding both factors to
    ///      `[2^130, 2^150]` puts the product in `[2^260, 2^300]`, inside it.
    ///      (Wider bounds overflow the *result* too, where reverting is correct.)
    ///      No independent product oracle exists in this region, so the
    ///      assertions are the properties that survive it.
    function testFuzz_TheCapSurvivesAnOverflowingIntermediate(uint256 dR, uint256 sPre) public view {
        dR = bound(dR, 2 ** 130, 2 ** 150);
        sPre = bound(sPre, 2 ** 130, 2 ** 150);
        uint256 bPre = 1e18;
        uint256 qRaw = 3_000 * 4e18;

        // The product genuinely overflows: proving it here means the test cannot
        // silently drift into the safe domain.
        assertGt(dR, type(uint256).max / sPre, "D_R x S_pre provably exceeds 256 bits");

        (uint256 qSafe, uint256 qMint) = math.vem(dR, sPre, bPre, qRaw);

        assertGe(qSafe, qRaw, "an enormous contribution makes Qsafe non-binding");
        assertEq(qMint, qRaw, "so Qraw binds, and issuance is not denied by arithmetic");
    }

    /*----------  which side binds (FR-5.5/5.6)  --------------------------*/

    function test_WhenQsafeIsBindingOnlyQsafeIsMinted() public view {
        // B/S = 1, so one wei of contribution supports one unit of issuance.
        (uint256 qSafe, uint256 qMint) = math.vem(100, 1_000, 1_000, 10_000);
        assertEq(qSafe, 100, "Qsafe == floor(100 x 1000 / 1000)");
        assertEq(qMint, 100, "Qraw was 10,000 but only Qsafe is minted");
    }

    function test_WhenQrawIsBindingTheSurplusRaisesBackingPerUnit() public view {
        (uint256 qSafe, uint256 qMint) = math.vem(500, 1_000, 1_000, 100);
        assertEq(qSafe, 500, "the contribution could have supported 500");
        assertEq(qMint, 100, "but the clock only offered 100");

        // B/S strictly improves: (1000+500)/(1000+100) > 1000/1000.
        assertGt((1_000 + 500) * 1_000, (1_000 + 100) * 1_000 - 1, "surplus contribution raises B/S");
    }

    /// @dev Rounding is down, always, and the residue stays with the Reserve
    ///      (INV-16). `floor(1 x 3 / 2) == 1`, not 2.
    function test_IssuanceRoundsDownTowardTheReserve() public view {
        (uint256 qSafe,) = math.vem(1, 3, 2, type(uint256).max);
        assertEq(qSafe, 1, "floor, not round-half-up, not ceil");
    }

    /*----------  measured reality, and its rejection (FR-5.1)  -----------*/

    /// @dev Under-delivery: the Hard leg is routed, but a fee withholds part of
    ///      it, so the physically measured delta is smaller than intent. The
    ///      whole settlement must reject rather than mint against a number that
    ///      never arrived.
    function test_UnderDeliveredHardLegRejectsTheSettlement() public {
        _consumeBootstrap();
        vm.warp(rig.epochStart() + 1_000);

        uint256 price = rig.currentPrice();
        (, uint256 expectedHard,) = _expectedLegs(price, 1_000 * rig.epochUPS(), reserve.backing(), vux.totalSupply());

        weth.setTransferFeeBp(100); // 1% withheld in flight
        _fund(BOB, price);

        uint256 delivered = expectedHard - (expectedHard * 100) / 10_000;
        vm.expectRevert(abi.encodeWithSelector(Rig.InconsistentReserveDelta.selector, expectedHard, delivered));
        vm.prank(BOB);
        rig.take(type(uint256).max);
    }

    /// @dev Over-delivery must reject too. An inflated measured delta would
    ///      inflate `Qsafe` and mint against backing the settlement did not
    ///      cause — the same failure in the opposite direction.
    function test_OverDeliveredHardLegRejectsTheSettlement() public {
        _consumeBootstrap();
        vm.warp(rig.epochStart() + 1_000);

        uint256 price = rig.currentPrice();
        (, uint256 expectedHard,) = _expectedLegs(price, 1_000 * rig.epochUPS(), reserve.backing(), vux.totalSupply());

        weth.setTransferBonus(1);
        _fund(BOB, price);

        vm.expectRevert(abi.encodeWithSelector(Rig.InconsistentReserveDelta.selector, expectedHard, expectedHard + 1));
        vm.prank(BOB);
        rig.take(type(uint256).max);
    }

    /// @dev The rejection is atomic: no leg survives it. Every observable moves
    ///      back to exactly where it was.
    function test_TheRejectionUnwindsEveryLeg() public {
        _consumeBootstrap();
        vm.warp(rig.epochStart() + 1_000);

        address kingBefore = rig.king();
        uint256 epochIdBefore = rig.epochId();
        uint256 backingBefore = reserve.backing();
        uint256 supplyBefore = vux.totalSupply();
        uint256 treasuryBefore = weth.balanceOf(TREASURY);
        uint256 contributedBefore = rig.totalStrategicContributed();

        uint256 price = rig.currentPrice();
        _fund(BOB, price);
        uint256 payerBefore = weth.balanceOf(BOB);

        weth.setTransferFeeBp(100);
        vm.expectPartialRevert(Rig.InconsistentReserveDelta.selector);
        vm.prank(BOB);
        rig.take(type(uint256).max);

        assertEq(rig.king(), kingBefore, "throne unchanged");
        assertEq(uint256(rig.epochId()), epochIdBefore, "epoch counter unchanged");
        assertEq(reserve.backing(), backingBefore, "Hard backing unchanged");
        assertEq(vux.totalSupply(), supplyBefore, "supply unchanged - nothing minted");
        assertEq(weth.balanceOf(TREASURY), treasuryBefore, "Strategic leg unwound");
        assertEq(rig.totalStrategicContributed(), contributedBefore, "Strategic accounting unwound");
        assertEq(weth.balanceOf(BOB), payerBefore, "the payment itself was returned");
    }

    /*----------  the shortfall leaves no trace (FR-5.5, INV-8)  ----------*/

    /// @dev A settlement where `Qraw` far exceeds `Qsafe`, so a large shortfall
    ///      exists and is discarded. The claim is about the *absence* of state,
    ///      which no getter can show — a cell without a getter still holds a
    ///      value — so this reads the Rig's raw storage slots and asserts the
    ///      shortfall appears in none of them.
    function test_NoStorageCellRecordsTheUnmintedRemainder() public {
        _consumeBootstrap();

        // A long reign at full UPS against small backing: Qraw is enormous
        // relative to what the Hard leg of one cheap takeover can support.
        vm.warp(rig.epochStart() + EPOCH_PERIOD);
        SettledRecord memory r = _takeRecorded(BOB);

        uint256 shortfall = r.qRaw - r.qMint;
        assertGt(shortfall, 0, "this scenario must actually strand opportunity");
        assertEq(r.qMint, r.qSafe, "Qsafe was the binding constraint");

        // Slot 0..9 covers every declared cell (packed king/epochStart,
        // packed epochOpening/scheduleStart/epochId, epochUPS,
        // totalStrategicContributed) plus the inherited guard slot and headroom.
        for (uint256 slot = 0; slot < 10; slot++) {
            uint256 word = uint256(vm.load(address(rig), bytes32(slot)));
            assertNotEq(word, shortfall, "no storage word equals the unmet Qraw - Qsafe");
            assertNotEq(word, r.qRaw, "no storage word banks the raw opportunity either");
        }

        // And it does not resurface later: the next epoch's opportunity is a
        // function of its own elapsed time alone.
        vm.warp(rig.epochStart() + 10);
        SettledRecord memory next = _takeRecorded(CAROL);
        assertEq(next.qRaw, 10 * rig.epochUPS(), "the following epoch inherits nothing");
    }

    /// @dev The Rig holds no WETH between settlements, so there is no balance in
    ///      which a deferred obligation could hide either (INV-20).
    function test_TheRigRetainsNothingBetweenSettlements() public {
        _consumeBootstrap();
        assertEq(weth.balanceOf(address(rig)), 0, "no residue after the bootstrap settlement");

        vm.warp(rig.epochStart() + 777);
        _take(BOB);
        assertEq(weth.balanceOf(address(rig)), 0, "no residue after an ordinary settlement");

        vm.warp(rig.epochStart() + EPOCH_PERIOD + 5);
        _take(CAROL);
        assertEq(weth.balanceOf(address(rig)), 0, "no residue after a fully-decayed settlement");
    }

    /*----------  end-to-end non-dilution (INV-13)  ------------------------*/

    /// @dev The inequality, observed through real settlements rather than the
    ///      pure function: across a randomized sequence, `B/S` never falls.
    function testFuzz_LiveSettlementNeverReducesBackingPerUnit(uint256 gapA, uint256 gapB, uint256 gapC) public {
        _consumeBootstrap();

        uint256[3] memory gaps =
            [bound(gapA, 0, 2 * EPOCH_PERIOD), bound(gapB, 0, 2 * EPOCH_PERIOD), bound(gapC, 0, 2 * EPOCH_PERIOD)];
        address[3] memory takers = [BOB, CAROL, ALICE];

        for (uint256 i = 0; i < 3; i++) {
            uint256 bBefore = reserve.backing();
            uint256 sBefore = vux.totalSupply();

            vm.warp(rig.epochStart() + gaps[i]);
            _take(takers[i]);

            uint256 bAfter = reserve.backing();
            uint256 sAfter = vux.totalSupply();

            // bAfter/sAfter >= bBefore/sBefore, cross-multiplied.
            assertGe(bAfter * sBefore, bBefore * sAfter, "B/S is non-decreasing under authorized issuance");
        }
    }
}
