// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 8 Task 8.E2E (End-to-End Goal Validation, G-1…G-6)
//          INV-1 … INV-5, INV-10, INV-13, INV-18, INV-19, INV-20, INV-21, INV-22,
//          INV-23, INV-31, INV-32, INV-33, INV-34, INV-35
//          FB-5, FB-7
//          PRD Appendix A (frozen parameter table), FR-1, FR-2, FR-3, FR-4, FR-5,
//          FR-6, FR-7, FR-13 launch portion

import {GenesisFixture} from "../genesis/GenesisFixture.sol";
import {MockLsgModule} from "../mocks/MockLsgModule.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";

/// @title GoalValidationTest — the six PRD goals, exercised on the ASSEMBLED system.
///
/// @notice Every other suite in this repository tests a surface. This one tests
///         the *system that genesis actually produces*: it launches through the
///         real two-transaction choreography and then drives the full monetary
///         lifecycle across it — bootstrap, ordinary takeovers, every adaptive
///         routing regime, a halving boundary, redemption, Strategic failure,
///         and the LSG activation boundary.
///
///         The distinction matters because integration is where the frozen
///         parameters, the routing law, the VEM cap, and the treasury boundary
///         have to agree with each other rather than merely each be correct in
///         isolation. A per-contract suite cannot observe a disagreement between
///         two correct contracts.
///
/// @dev Goals G-3 (truthful UX), G-5 (provenance discipline) and G-6 (operator
///      reviewability) are not Solidity-observable: they live in the Playwright
///      copy suite, the indexer reconstruction, the CI gate set, and the evidence
///      pack. Their evidence is named in
///      `grimoires/loa/a2a/sprint-8/e2e-goal-validation.md`. Writing Solidity
///      that pretended to check them would be theatre.
///
///      Rehearsal economics throughout (`GenesisFixture`): the four USD targets
///      and the `(fee, tickSpacing)` pair are founder deployment facts (FR-1.4,
///      R-14). Nothing here freezes any of them.
contract GoalValidationTest is GenesisFixture {
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    address internal constant CAROL = address(0xCA401);

    function setUp() public {
        _runGenesis();
    }

    // =========================================================================
    // G-1 — Faithful monetary core
    // =========================================================================

    /// @dev The frozen parameter table (PRD Appendix A) checked against the
    ///      constants the deployed system actually carries. Read from the live
    ///      instance, not from a copy of the table, so a constant edited in
    ///      source fails here even if someone updates a comment to match.
    function test_G1_FrozenParametersMatchTheDeployedConstantsVerbatim() public view {
        assertEq(rig.SPLIT_KING_BP(), 8_000, "king split is not 80%");
        assertEq(rig.STRATEGIC_CAP_BP(), 1_200, "strategic cap is not 12%");
        assertEq(rig.BP_DENOM(), 10_000, "basis-point denominator");
        assertEq(rig.EPOCH_PERIOD(), 3_000, "epoch period");
        assertEq(rig.PRICE_MULTIPLIER(), 2, "successor price multiplier");
        assertEq(rig.INITIAL_UPS(), 4e18, "initial units-per-second");
        assertEq(rig.HALVING_PERIOD(), 30 days, "halving period");
        assertEq(rig.MAX_HALVINGS(), 8, "halving count");

        // The adaptive floor is a DERIVED constant, and deriving it here is the
        // point: `hardFloor = retained - strategicCap` must equal 8% of price.
        uint256 retainedBp = rig.BP_DENOM() - rig.SPLIT_KING_BP();
        assertEq(retainedBp - rig.STRATEGIC_CAP_BP(), 800, "the adaptive floor is not 8% of price");
    }

    /// @dev FR-1: the genesis table, exactly. Any nonzero discretionary balance
    ///      is a critical failure, so this asserts zero at every named class of
    ///      recipient rather than only checking the two that should be nonzero.
    function test_G1_GenesisStateIsExact() public view {
        assertEq(vux.totalSupply(), S0, "S0 is not 150,000e18 + 1");
        assertEq(vux.balanceOf(address(reserve)), 1, "the Reserve does not hold exactly 1 raw unit");
        assertEq(weth.balanceOf(address(reserve)), B0, "B0 mismatch");

        // The POL allocation is `pool + quantization dust`, not `pool` alone:
        // a v3 full-range mint consumes only what the liquidity math can place,
        // and the unplaceable remainder stays with the treasury as protocol-owned
        // inventory (sdd.md; asserted in the same form at
        // test/genesis/GenesisWiring.t.sol:287-289). Asserting `pool == POL_VUX`
        // here would be asserting a rounding behaviour v3 does not have.
        uint256 dust = vux.balanceOf(address(treasury));
        assertEq(vux.balanceOf(pool) + dust, POL_VUX, "the POL allocation is not fully placed or retained");
        assertLt(dust, 1e18, "retained VUX is not quantization dust but an unplaced allocation");

        // Conservation across the whole genesis: every raw unit is in the pool,
        // the dust, or the Reserve — and nowhere else. This is the check that
        // makes the zero-balance assertions below exhaustive rather than a list
        // of addresses someone remembered.
        assertEq(vux.balanceOf(pool) + dust + vux.balanceOf(address(reserve)), S0, "genesis supply is not fully accounted");

        assertEq(vux.balanceOf(address(genesis)), 0, "the deployer kept VUX");
        assertEq(vux.balanceOf(address(rig)), 0, "the Rig holds VUX");
        assertEq(vux.balanceOf(REHEARSAL_SAFE), 0, "the operator Safe received genesis VUX");
        assertEq(vux.balanceOf(address(this)), 0, "the launcher kept VUX");
        assertEq(weth.balanceOf(address(genesis)), 0, "the deployer kept WETH");
        assertEq(weth.balanceOf(address(rig)), 0, "the Rig retained WETH at genesis");
    }

    /// @dev FR-6 / INV-20: the bootstrap settlement mints zero and splits
    ///      ≈88%+ Hard / 12% Strategic, because the outgoing King IS the Reserve
    ///      so its 80% leg accrues to Hard instead of leaving the system.
    function test_G1_BootstrapTakeoverMintsZeroAndAccruesEightyEightPercentToHard() public {
        (address king0,,,, bool bootstrap0) = rig.epochState();
        assertEq(king0, address(reserve), "genesis King is not the Reserve");
        assertTrue(bootstrap0, "the system did not start in bootstrap");
        assertEq(lens.rawClockLimit(), 0, "the clock is not disabled during bootstrap");

        uint256 supplyBefore = vux.totalSupply();
        uint256 backingBefore = weth.balanceOf(address(reserve));
        uint256 strategicBefore = weth.balanceOf(address(treasury));

        uint256 price = _take(ALICE);

        assertEq(vux.totalSupply(), supplyBefore, "bootstrap minted VUX (INV-20)");

        uint256 kingLeg = (price * 8_000) / 10_000;
        uint256 retained = price - kingLeg;
        uint256 strategic = (price * 1_200) / 10_000;
        uint256 hard = retained - strategic + kingLeg;

        assertEq(weth.balanceOf(address(reserve)) - backingBefore, hard, "bootstrap Hard leg is not king+floor");
        assertEq(weth.balanceOf(address(treasury)) - strategicBefore, strategic, "bootstrap Strategic leg is not 12%");
        assertGe(hard * 10_000 / price, 8_800, "bootstrap Hard share fell below 88%");

        (,,,, bool bootstrapAfter) = rig.epochState();
        assertFalse(bootstrapAfter, "the system stayed in bootstrap after the first takeover");
        assertGt(rig.scheduleStart(), 0, "the schedule did not start at the bootstrap takeover");
    }

    /// @dev FR-4 across the FULL adaptive range, on the assembled system.
    ///
    ///      The three regimes are reached by controlling elapsed time, because
    ///      `dNeed = ceil(qRaw × B / S)` and `qRaw = min(elapsed, EPOCH_PERIOD) × UPS`.
    ///      Short reign → tiny `dNeed` → the floor binds. Long reign → `dNeed`
    ///      exceeds everything retained → Strategic gets nothing. This is the
    ///      range the sprint plan names: `D_need ≤ hardFloor` through `D_need > retained`.
    function test_G1_EveryAdaptiveRoutingRegimeIsObservedOnTheAssembledSystem() public {
        _take(ALICE); // leave bootstrap

        bool sawFloorBinding;
        bool sawNeedBinding;
        bool sawRetainedBinding;

        uint256[6] memory reigns = [uint256(1), 30, 200, 900, 2_000, 3_000];
        address[3] memory takers = [BOB, CAROL, ALICE];

        for (uint256 i = 0; i < reigns.length; i++) {
            vm.warp(block.timestamp + reigns[i]);

            uint256 bPre = weth.balanceOf(address(reserve));
            uint256 sPre = vux.totalSupply();
            uint256 tPre = weth.balanceOf(address(treasury));
            uint256 qRaw = lens.rawClockLimit();

            uint256 price = _take(takers[i % 3]);

            uint256 kingLeg = (price * 8_000) / 10_000;
            uint256 retained = price - kingLeg;
            uint256 hardFloor = retained - (price * 1_200) / 10_000;
            uint256 dNeed = qRaw == 0 ? 0 : _ceilDiv(qRaw * bPre, sPre);

            uint256 expectedHard = _min(retained, _max(hardFloor, dNeed));
            uint256 expectedStrategic = retained - expectedHard;

            uint256 observedStrategic = weth.balanceOf(address(treasury)) - tPre;
            assertEq(observedStrategic, expectedStrategic, "the Strategic leg does not follow the adaptive law");

            // INV-18/19 amended form: the floor is a floor and the cap is a cap.
            assertGe(expectedHard, hardFloor, "Hard fell below the 8% floor (INV-18)");
            assertLe(observedStrategic, (price * 1_200) / 10_000, "Strategic exceeded the 12% cap (INV-19)");

            if (dNeed <= hardFloor) sawFloorBinding = true;
            else if (dNeed >= retained) sawRetainedBinding = true;
            else sawNeedBinding = true;
        }

        assertTrue(sawFloorBinding, "regime 1 (D_need <= hardFloor) never occurred");
        assertTrue(sawNeedBinding, "regime 2 (hardFloor < D_need < retained) never occurred");
        assertTrue(sawRetainedBinding, "regime 3 (D_need >= retained) never occurred");
    }

    /// @dev FR-3: the schedule halves, and the assembled system keeps settling
    ///      correctly across the boundary rather than only before it.
    function test_G1_TakeoversContinueCorrectlyAcrossAHalvingBoundary() public {
        _take(ALICE); // bootstrap; starts the schedule
        uint256 start = rig.scheduleStart();

        vm.warp(start + 1);
        assertEq(rig.currentUPS(), rig.INITIAL_UPS(), "epoch 0 UPS is not the initial rate");
        _take(BOB);

        // Boundaries are derived from `HALVING_PERIOD` rather than written as
        // literal day counts. Two reasons, both real: a change to the constant
        // must move the boundary this test checks rather than silently leaving
        // it asserting the wrong instant, and the frozen value stays pinned in
        // exactly one place (the constants test above). Literal day counts here
        // also collide with the PRD §17 quarantine grep, which is correct to be
        // suspicious of bare durations in implementation artifacts.
        uint256 halving = rig.HALVING_PERIOD();

        // Cross the first halving.
        vm.warp(start + halving + 1);
        assertEq(rig.currentUPS(), rig.INITIAL_UPS() / 2, "UPS did not halve at the boundary");

        uint256 supplyBefore = vux.totalSupply();
        uint256 backingBefore = weth.balanceOf(address(reserve));
        _take(CAROL);
        assertGe(vux.totalSupply(), supplyBefore, "supply went backwards across a halving (INV-1)");
        assertGe(weth.balanceOf(address(reserve)), backingBefore, "backing went backwards across a halving (INV-13)");

        // And the second.
        vm.warp(start + (halving * 2) + 1);
        assertEq(rig.currentUPS(), rig.INITIAL_UPS() / 4, "UPS did not halve a second time");
        _take(ALICE);

        // The tail: after MAX_HALVINGS the rate stops halving rather than reaching
        // zero. Checked just past the last halving AND far beyond it, so the tail
        // is proven FLAT rather than merely reached.
        uint256 maxH = rig.MAX_HALVINGS();
        vm.warp(start + (halving * (maxH + 1)) + 1);
        assertEq(rig.currentUPS(), rig.INITIAL_UPS() / (2 ** maxH), "the tail rate is not the final halving");
        vm.warp(start + (halving * (maxH + 32)) + 1);
        assertEq(rig.currentUPS(), rig.INITIAL_UPS() / (2 ** maxH), "the tail rate decayed past MAX_HALVINGS");
    }

    /// @dev FR-7 / INV-10: redemption is the pro-rata hard claim on the physical
    ///      WETH balance, on a system that has actually been mined.
    function test_G1_RedemptionPaysProRataOnTheMinedSystem() public {
        _take(ALICE);
        vm.warp(block.timestamp + 1_500);
        _take(BOB);
        vm.warp(block.timestamp + 3_000);
        _take(CAROL);

        uint256 held = vux.balanceOf(BOB);
        assertGt(held, 0, "the mined King received no VUX to redeem");

        uint256 b = weth.balanceOf(address(reserve));
        uint256 s = vux.totalSupply();
        uint256 q = held / 2;
        uint256 expected = (q * b) / s; // floor division, Reserve-favouring

        uint256 wethBefore = weth.balanceOf(BOB);
        vm.prank(BOB);
        uint256 payout = reserve.redeem(q, BOB);

        assertEq(payout, expected, "payout is not the floor pro-rata share");
        assertEq(weth.balanceOf(BOB) - wethBefore, expected, "the payout did not arrive");
        assertEq(vux.totalSupply(), s - q, "redemption did not burn exactly q (INV-3)");
        assertEq(weth.balanceOf(address(reserve)), b - expected, "backing is not the physical balance (INV-10)");

        // Backing-per-unit must not fall: floor division favours the Reserve.
        assertGe((b - expected) * 1e18 / (s - q), (b * 1e18 / s) - 1, "redemption reduced backing per unit");
    }

    // =========================================================================
    // G-2 — Dual-treasury separation and failure independence
    // =========================================================================

    /// @dev FB-5 / INV-35 on the ASSEMBLED system: Strategic loss at 50%, 80%
    ///      and 100% leaves the monetary core bit-identical and creates no
    ///      Reserve claim. The per-surface suite proves the treasury's own
    ///      accounting; this proves the core cannot even observe the loss.
    function test_G2_StrategicLossAtEveryDepthLeavesTheCoreBitIdentical() public {
        _take(ALICE);
        vm.warp(block.timestamp + 3_000);
        _take(BOB);

        uint256[3] memory lossBp = [uint256(5_000), 8_000, 10_000];

        for (uint256 i = 0; i < lossBp.length; i++) {
            uint256 strategicHeld = weth.balanceOf(address(treasury));
            if (strategicHeld == 0) break;

            uint256 backingBefore = weth.balanceOf(address(reserve));
            uint256 supplyBefore = vux.totalSupply();
            address kingBefore = rig.king();
            uint256 epochBefore = rig.epochId();

            // Destroy Strategic value outright — the strongest form of the
            // failure, with no adapter cooperating in the accounting.
            uint256 burn = (strategicHeld * lossBp[i]) / 10_000;
            vm.prank(address(treasury));
            weth.transfer(address(0xDEAD), burn);

            assertEq(weth.balanceOf(address(reserve)), backingBefore, "Strategic loss moved backing (INV-35)");
            assertEq(vux.totalSupply(), supplyBefore, "Strategic loss changed supply");
            assertEq(rig.king(), kingBefore, "Strategic loss changed the throne");
            assertEq(rig.epochId(), epochBefore, "Strategic loss changed the epoch");

            // And the core keeps working afterwards, reading an untouched Reserve.
            vm.warp(block.timestamp + 1_000);
            uint256 backingPre = weth.balanceOf(address(reserve));
            _take(CAROL);
            assertGe(weth.balanceOf(address(reserve)), backingPre, "settlement after a Strategic loss reduced backing");
        }
    }

    /// @dev FB-7 / INV-31: no path exists by which Strategic distress reaches
    ///      Reserve principal. Asserted as *absence of capability* on the live
    ///      instance — the Reserve's entire external mutating surface is
    ///      `redeem`, so there is nothing for a rescue to call.
    function test_G2_NoRescuePathFromStrategicDistressToTheReserve() public {
        _take(ALICE);
        vm.warp(block.timestamp + 3_000);
        _take(BOB);

        uint256 backing = weth.balanceOf(address(reserve));

        // Drain Strategic completely.
        uint256 strategicHeld = weth.balanceOf(address(treasury));
        if (strategicHeld > 0) {
            vm.prank(address(treasury));
            weth.transfer(address(0xDEAD), strategicHeld);
        }
        assertEq(weth.balanceOf(address(treasury)), 0, "Strategic was not fully drained");

        assertEq(weth.balanceOf(address(reserve)), backing, "backing changed while Strategic went to zero");

        // The consequence a holder actually cares about: with Strategic at zero,
        // the hard claim is unchanged and still pays. "No rescue path" is only
        // meaningful if the thing it protects still works.
        uint256 held = vux.balanceOf(ALICE);
        assertGt(held, 0, "the mined King holds nothing to redeem");
        uint256 s = vux.totalSupply();
        uint256 expected = (held * backing) / s;

        vm.prank(ALICE);
        uint256 payout = reserve.redeem(held, ALICE);
        assertEq(payout, expected, "the hard claim changed after a total Strategic loss (INV-31)");

        // And no VUX-side authority was created in either direction by the loss.
        assertEq(vux.allowance(address(reserve), address(treasury)), 0, "the treasury holds an allowance over the Reserve");
        assertEq(vux.allowance(address(treasury), address(reserve)), 0, "the Reserve holds an allowance over the treasury");
    }

    // =========================================================================
    // G-4 — LSG-ready but inactive at launch
    // =========================================================================

    /// @dev FR-13 launch portion + INV-32…34 on the assembled system: LSG ships
    ///      inactive with the activation authority present, the lifecycle works,
    ///      and the boundaries are structurally unreachable.
    function test_G4_LsgShipsInactiveAndItsActivationLifecycleWorks() public view {
        assertEq(treasury.lsgModule(), address(0), "LSG is active at launch (INV-32)");
    }

    function test_G4_ActivationDeactivationLifecycleAndNegativeBoundaries() public {
        MockLsgModule module = new MockLsgModule();

        // Time alone never activates it — activation is affirmative (R-6).
        vm.warp(block.timestamp + 365 days);
        assertEq(treasury.lsgModule(), address(0), "time activated LSG");

        // Only the operator authority may activate.
        vm.prank(ALICE);
        vm.expectRevert();
        treasury.activateLSG(address(module));

        vm.prank(REHEARSAL_SAFE);
        treasury.activateLSG(address(module));
        assertEq(treasury.lsgModule(), address(module), "activation did not take effect");

        // Deactivation is instant — the emergency direction is never delayed.
        vm.prank(REHEARSAL_SAFE);
        treasury.deactivateLSG();
        assertEq(treasury.lsgModule(), address(0), "deactivation did not take effect");

        // INV-33/34: the module never holds authority over the monetary core.
        vm.prank(REHEARSAL_SAFE);
        treasury.activateLSG(address(module));
        assertEq(vux.balanceOf(address(module)), 0, "the module holds VUX");
        assertEq(weth.balanceOf(address(module)), 0, "the module holds WETH");
        assertEq(vux.allowance(address(treasury), address(module)), 0, "the module holds an allowance over the treasury");
    }

    // =========================================================================
    // helpers
    // =========================================================================

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _max(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? a : b;
    }

    function _ceilDiv(uint256 num, uint256 den) private pure returns (uint256) {
        return num == 0 ? 0 : (num - 1) / den + 1;
    }

    /// @dev Fund and take at the current price, mirroring `RigFixture._take` so
    ///      the assembled-system suite drives the throne the same way the
    ///      per-surface suites do.
    function _take(address who) private returns (uint256 price) {
        price = rig.currentPrice();
        weth.mint(who, price);
        vm.prank(who);
        weth.approve(address(rig), type(uint256).max);
        vm.prank(who);
        rig.take(type(uint256).max);
    }
}
