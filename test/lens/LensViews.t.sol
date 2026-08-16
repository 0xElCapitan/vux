// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-14.1, FR-14.4, FR-15.1, FR-15.2, INV-8, INV-9, INV-16, F-16
//          sprint.md Sprint 6 Task 6.2, Deliverable 2

import {LensFixture} from "./LensFixture.sol";
import {Lens} from "../../src/Lens.sol";

/// @title LensViewsTest — the three-tier views, value by value.
/// @notice Tier 1 and the Reserve views are checked here; tier-2 parity against
///         real settlements is `LensEstimateParity.t.sol`, and the read-only
///         structural claim is `LensSurface.t.sol`.
contract LensViewsTest is LensFixture {
    uint256 internal constant RAY = 1e27;

    function setUp() public {
        _deploySystem();
        _deployLens();
    }

    // -----------------------------------------------------------------------
    // Wiring — derived, not supplied
    // -----------------------------------------------------------------------

    function test_LensDerivesEveryIdentityFromTheRig() public view {
        assertEq(address(lens.RIG()), address(rig), "Lens reports on the real Rig");
        // The Reserve and token are not constructor arguments at all, so a Lens
        // reporting one contract's price against another's backing is not a
        // mistake this deployment can make.
        (uint256 b, uint256 s,) = lens.hardStats();
        assertEq(b, reserve.backing(), "B is the real Reserve's backing");
        assertEq(s, vux.totalSupply(), "S is the real token's complete supply");
    }

    function test_ConstructorRejectsZeroRig() public {
        vm.expectRevert(Lens.ZeroAddress.selector);
        new Lens(address(0));
    }

    // -----------------------------------------------------------------------
    // Tier 1 — raw clock limit
    // -----------------------------------------------------------------------

    /// @dev The genesis reign's clock is disabled (FR-6.1). No amount of elapsed
    ///      time turns bootstrap into opportunity.
    function test_RawClockLimitIsZeroThroughoutBootstrap() public {
        assertEq(lens.rawClockLimit(), 0, "bootstrap starts at zero");

        vm.warp(block.timestamp + EPOCH_PERIOD * 10);
        assertEq(lens.rawClockLimit(), 0, "bootstrap accrues nothing however long it runs");
    }

    function test_RawClockLimitAccruesWithElapsedTime() public {
        _consumeBootstrap();
        uint256 ups = rig.epochUPS();

        vm.warp(block.timestamp + 100);
        assertEq(lens.rawClockLimit(), 100 * ups, "100s of clock");

        vm.warp(block.timestamp + 400);
        assertEq(lens.rawClockLimit(), 500 * ups, "500s of clock");
    }

    /// @dev INV-8 / INV-9: beyond `EPOCH_PERIOD` the opportunity stops accruing.
    ///      It does not carry, bank, or become owed — so the ceiling is flat, not
    ///      merely slower.
    function test_RawClockLimitStopsAtEpochPeriodAndNeverCarries() public {
        _consumeBootstrap();
        uint256 ups = rig.epochUPS();
        uint256 atCap = EPOCH_PERIOD * ups;

        vm.warp(block.timestamp + EPOCH_PERIOD);
        assertEq(lens.rawClockLimit(), atCap, "exactly at the cap");

        vm.warp(block.timestamp + 1);
        assertEq(lens.rawClockLimit(), atCap, "one second past the cap: unchanged");

        vm.warp(block.timestamp + 365 days);
        assertEq(lens.rawClockLimit(), atCap, "a year past the cap: still unchanged");
    }

    /// @dev The tier-1 ceiling must equal the `qRaw` the settlement actually
    ///      records, or the surface is showing a number the protocol does not use.
    function testFuzz_RawClockLimitEqualsSettledQRaw(uint256 elapsed) public {
        _consumeBootstrap();
        elapsed = bound(elapsed, 0, EPOCH_PERIOD * 3);

        vm.warp(block.timestamp + elapsed);
        uint256 shown = lens.rawClockLimit();

        SettledRecord memory r = _takeRecorded(BOB);
        assertEq(shown, r.qRaw, "tier 1 equals the settled raw opportunity");
    }

    // -----------------------------------------------------------------------
    // Reserve truth — B, S, B/S
    // -----------------------------------------------------------------------

    function test_HardStatsReportsGenesisState() public view {
        (uint256 b, uint256 s, uint256 bPerSRay) = lens.hardStats();
        assertEq(b, B0, "B is genesis backing");
        assertEq(s, S0, "S is genesis supply");
        assertEq(bPerSRay, (B0 * RAY) / S0, "B/S in ray");
    }

    /// @dev INV-16: every quantity rounds in the Reserve-favouring direction.
    ///      For a *disclosed* ratio that means flooring — understating backing
    ///      per unit rather than overstating it. Asserted on a value with a real
    ///      remainder, so a ceiling implementation would differ by one.
    function test_BackingPerVuxFloorsRatherThanRounds() public view {
        (uint256 b, uint256 s, uint256 bPerSRay) = lens.hardStats();

        assertNotEq((b * RAY) % s, 0, "the fixture's B/S has a remainder to floor");
        assertEq(bPerSRay, (b * RAY) / s, "floored");
        // Discriminating form: a ceiling implementation would put the product
        // strictly above `B x RAY` on exactly this remainder case.
        assertLe(bPerSRay * s, b * RAY, "the disclosed ratio never claims more backing than exists");
    }

    function test_HardStatsTracksSettlementAndRedemption() public {
        _consumeBootstrap();
        vm.warp(block.timestamp + 600);
        SettledRecord memory r = _takeRecorded(BOB);

        (uint256 b, uint256 s,) = lens.hardStats();
        assertEq(b, r.bPre + r.dR, "B advanced by the measured Hard delta");
        assertEq(s, r.sPre + r.qMint, "S advanced by the actual mint");
    }

    // -----------------------------------------------------------------------
    // wethNeededForFullQraw — F-16 round UP
    // -----------------------------------------------------------------------

    function test_WethNeededIsZeroWhenTheClockHasProducedNothing() public {
        // Bootstrap: no raw opportunity, so nothing is needed to support it.
        assertEq(lens.wethNeededForFullQraw(), 0, "no opportunity needs no WETH");

        _consumeBootstrap();
        assertEq(lens.wethNeededForFullQraw(), 0, "a fresh reign at t=0 likewise");
    }

    /// @dev `D_need = ceil(Qraw × B / S)`. Pinned from both sides: the value is
    ///      sufficient (`D × S >= Qraw × B`) and minimal (`(D−1) × S < Qraw × B`),
    ///      which together admit exactly the ceiling. A floor implementation
    ///      fails the first assertion whenever the division has a remainder.
    function testFuzz_WethNeededForFullQrawRoundsUp(uint256 elapsed) public {
        _consumeBootstrap();
        elapsed = bound(elapsed, 1, EPOCH_PERIOD);
        vm.warp(block.timestamp + elapsed);

        uint256 qRaw = lens.rawClockLimit();
        (uint256 b, uint256 s,) = lens.hardStats();
        uint256 needed = lens.wethNeededForFullQraw();

        assertGe(needed * s, qRaw * b, "sufficient: supports the full raw limit");
        assertLt((needed - 1) * s, qRaw * b, "minimal: one wei less does not");
        assertEq(needed, _ceilMulDiv(qRaw, b, s), "exactly ceil(Qraw x B / S)");
    }

    /// @dev The round-UP direction is the point of F-16, so it is asserted where
    ///      it is observable: a remainder case must exceed the floor by one.
    function test_WethNeededExceedsFloorWhenDivisionHasRemainder() public {
        _consumeBootstrap();
        vm.warp(block.timestamp + 777);

        uint256 qRaw = lens.rawClockLimit();
        (uint256 b, uint256 s,) = lens.hardStats();
        assertNotEq((qRaw * b) % s, 0, "the case chosen has a remainder");

        assertEq(lens.wethNeededForFullQraw(), _floorMulDiv(qRaw, b, s) + 1, "rounded up, not down");
    }

    /// @dev `D_need` is a threshold, and this is the threshold it is: a
    ///      settlement whose measured Hard delta reaches it mints the full raw
    ///      limit, and one that falls short mints strictly less. Both directions
    ///      are asserted, because only the pair pins the value — an
    ///      implementation off by one satisfies neither branch everywhere.
    ///
    ///      Both branches are reachable in this fixture: early in a reign the
    ///      adaptive law self-routes past `D_need` and the clock binds; late in
    ///      one the decayed price cannot reach it and VEM binds.
    function testFuzz_WethNeededIsTheFullMintThreshold(uint256 elapsed) public {
        _consumeBootstrap();
        elapsed = bound(elapsed, 1, EPOCH_PERIOD);
        vm.warp(block.timestamp + elapsed);

        uint256 needed = lens.wethNeededForFullQraw();
        SettledRecord memory r = _takeRecorded(BOB);

        if (r.dR >= needed) {
            assertEq(r.qMint, r.qRaw, "reaching D_need mints the full raw limit");
        } else {
            assertLt(r.qMint, r.qRaw, "falling short of D_need mints strictly less");
        }
    }

    /// @dev The two branches above are not hypothetical — each is exhibited.
    function test_BothMintThresholdBranchesAreReachable() public {
        _consumeBootstrap();
        uint256 start = block.timestamp;

        vm.warp(start + 60);
        uint256 neededEarly = lens.wethNeededForFullQraw();
        SettledRecord memory early = _takeRecorded(BOB);
        assertGe(early.dR, neededEarly, "early: the law self-routes past D_need");
        assertEq(early.qMint, early.qRaw, "early: clock-limited, full raw limit minted");

        vm.warp(block.timestamp + 2_900);
        uint256 neededLate = lens.wethNeededForFullQraw();
        SettledRecord memory late = _takeRecorded(CAROL);
        assertLt(late.dR, neededLate, "late: the decayed price cannot reach D_need");
        assertLt(late.qMint, late.qRaw, "late: VEM-limited, raw opportunity expires unminted");
    }

    // -----------------------------------------------------------------------
    // strategicContributed — contributed principal, never backing
    // -----------------------------------------------------------------------

    /// @dev The bootstrap settlement routes a Strategic residual of its own — its
    ///      `Qraw` is zero, so `D_need` is zero and the law degenerates to the
    ///      nominal split, leaving the full `strategicCap` as residual. The
    ///      running total therefore starts accumulating at the bootstrap, not at
    ///      the first ordinary settlement.
    function test_StrategicContributedStartsAtZeroAndAccumulatesEveryResidual() public {
        assertEq(lens.strategicContributed(), 0, "nothing contributed at genesis");

        _consumeBootstrap();
        uint256 fromBootstrap = lens.strategicContributed();
        assertGt(fromBootstrap, 0, "the bootstrap settlement routed a residual too");

        vm.warp(block.timestamp + 300);
        SettledRecord memory first = _takeRecorded(BOB);

        vm.warp(block.timestamp + 300);
        SettledRecord memory second = _takeRecorded(CAROL);

        assertEq(
            lens.strategicContributed(),
            fromBootstrap + first.strategicLeg + second.strategicLeg,
            "cumulative Strategic residual legs"
        );
        assertEq(lens.strategicContributed(), rig.totalStrategicContributed(), "agrees with the Rig");
    }

    /// @dev FR-14.4 / FR-9.1: Strategic value is not Hard backing. The two
    ///      surfaces are separate numbers and the Strategic total is not in `B`.
    function test_StrategicContributedIsNotCountedInBacking() public {
        _consumeBootstrap();
        vm.warp(block.timestamp + 1200);
        SettledRecord memory r = _takeRecorded(BOB);

        (uint256 b,,) = lens.hardStats();
        assertGt(lens.strategicContributed(), 0, "a residual leg was routed");
        assertEq(b, reserve.backing(), "B is the Reserve balance and nothing else");
        assertEq(b, r.bPre + r.dR, "B excludes every WETH the Treasury received");
        assertEq(weth.balanceOf(TREASURY), lens.strategicContributed(), "Strategic WETH sits outside the Reserve");
    }
}
