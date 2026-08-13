// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-4.1, FR-4.2, FR-4.3, INV-18, INV-19, INV-20
//          sprint.md Sprint 3 AC-3 (randomized regime testing)

import {RigFixture} from "./RigFixture.sol";
import {RigMathHarness} from "./RigMathHarness.sol";

/// @title RigRoutingTest — the adaptive 8%-floor routing law, across every regime.
/// @notice The law has three regimes, separated by where `D_need` falls relative
///         to `hardFloor` and `retained`:
///
///         | regime                          | hardTarget | strategic       |
///         |---------------------------------|------------|-----------------|
///         | `D_need <= hardFloor`           | `hardFloor`| `strategicCap`  |
///         | `hardFloor < D_need <= retained`| `D_need`   | residual        |
///         | `D_need > retained`             | `retained` | `0`             |
///
///         Each is pinned by a worked example whose numbers are checked by hand,
///         then all three are swept by fuzzing. The properties that must hold in
///         *every* regime — leg exhaustion, the bracket on `hardTarget`, the cap
///         on Strategic, and dust landing in Hard — are asserted on every run
///         rather than per regime, and the sweep reports which regimes it
///         actually reached so a vacuous pass is visible.
contract RigRoutingTest is RigFixture {
    RigMathHarness internal math;

    function setUp() public {
        _deploySystem();
        math = new RigMathHarness(address(weth), address(reserve), address(vux), TREASURY);
    }

    /*----------  worked examples, one per regime  ------------------------*/

    /// @dev `P = 1000 wei`: king 800, retained 200, cap 120, hardFloor 80.
    ///      `D_need = ceil(0 × B/S) = 0 <= 80`, so the law degenerates to exactly
    ///      the prior static split — 80% / 8% / 12% (prd.md:L376).
    function test_RegimeOne_DegeneratesToTheStaticSplit() public view {
        (uint256 kingLeg, uint256 hardTarget, uint256 strategicLeg) = math.route(1_000, 0, B0, S0);

        assertEq(kingLeg, 800, "king == floor(P x 8000/10000)");
        assertEq(hardTarget, 80, "hardTarget == hardFloor == nominal 8%");
        assertEq(strategicLeg, 120, "strategic == strategicCap == floor(12%)");
        assertEq(kingLeg + hardTarget + strategicLeg, 1_000, "legs exhaust P");
    }

    /// @dev Same payment, but a raw opportunity that needs more than the floor.
    ///      `B_pre/S_pre = 1/2`, `Qraw = 300` → `D_need = ceil(300/2) = 150`,
    ///      which is between `hardFloor = 80` and `retained = 200`. Hard takes
    ///      exactly what issuance needs; Strategic takes the rest.
    function test_RegimeTwo_HardTakesExactlyWhatIssuanceNeeds() public view {
        (uint256 kingLeg, uint256 hardTarget, uint256 strategicLeg) = math.route(1_000, 300, 1_000, 2_000);

        assertEq(kingLeg, 800, "king leg is unaffected by the adaptive part");
        assertEq(hardTarget, 150, "hardTarget == D_need");
        assertEq(strategicLeg, 50, "strategic == retained - D_need == 200 - 150");
        assertEq(kingLeg + hardTarget + strategicLeg, 1_000, "legs exhaust P");
    }

    /// @dev `Qraw = 1000`, `B/S = 1/2` → `D_need = 500 > retained = 200`. Hard
    ///      takes all retained capital, Strategic takes nothing, and issuance is
    ///      simply VEM-limited — no compensating logic exists (FR-4.2).
    function test_RegimeThree_HardTakesAllRetainedAndStrategicIsZero() public view {
        (uint256 kingLeg, uint256 hardTarget, uint256 strategicLeg) = math.route(1_000, 1_000, 1_000, 2_000);

        assertEq(kingLeg, 800, "king leg still exactly 80%");
        assertEq(hardTarget, 200, "hardTarget == retained (clamped by min)");
        assertEq(strategicLeg, 0, "Strategic legitimately receives zero");
        assertEq(kingLeg + hardTarget + strategicLeg, 1_000, "legs exhaust P");
    }

    /*----------  dust and small-payment boundaries  -----------------------*/

    /// @dev All rounding remainders accrue inside `hardFloor`, so Hard is the
    ///      only leg that can gain from flooring and Strategic is the only one
    ///      that can lose (INV-19). At tiny payments the effect is total: every
    ///      retained wei goes to Hard.
    function test_DustFavoursHardAtTinyPayments() public view {
        for (uint256 price = 0; price <= 20; price++) {
            (uint256 kingLeg, uint256 hardTarget, uint256 strategicLeg) = math.route(price, 0, B0, S0);

            assertEq(kingLeg + hardTarget + strategicLeg, price, "legs exhaust even a dust payment");
            assertEq(kingLeg, (price * 8_000) / 10_000, "king leg floors");
            // `strategicCap = floor(P x 1200/10000)` is zero for every P < 9.
            if (price < 9) {
                assertEq(strategicLeg, 0, "below 9 wei Strategic rounds to nothing and Hard takes the remainder");
                assertEq(hardTarget, price - kingLeg, "Hard receives the whole retained remainder");
            }
        }
    }

    /// @dev The Reserve's floor is never worse than the nominal 8%: `hardFloor`
    ///      is `retained - floor(12%)`, and `retained` is `ceil(20%)`, so the
    ///      floor absorbs both flooring remainders.
    function testFuzz_HardFloorNeverFallsBelowTheNominalEightPercent(uint256 price) public view {
        price = bound(price, 0, 1e24);

        (uint256 kingLeg, uint256 hardTarget,) = math.route(price, 0, B0, S0);
        uint256 retained = price - kingLeg;
        uint256 hardFloor = retained - (price * 1_200) / 10_000;

        assertEq(hardTarget, hardFloor, "with Qraw = 0 the floor is the target");
        assertGe(hardFloor, (price * 800) / 10_000, "hardFloor >= the nominal floored 8%");
        assertGe(hardFloor + (price * 1_200) / 10_000, (price * 2_000) / 10_000, "floor + cap >= the full retained 20%");
    }

    /*----------  the universal properties, swept  --------------------------*/

    /// @dev Every property FR-4's acceptance list requires, asserted on every
    ///      randomized tuple regardless of which regime it lands in.
    function testFuzz_TheLawHoldsAcrossAllRegimes(uint256 price, uint256 qRaw, uint256 bPre, uint256 sPre)
        public
        view
    {
        // Bounds keep `qRaw x bPre` inside 256 bits so the independent oracle
        // stays valid; `qRaw`'s ceiling is the protocol's own cap, 3000 x 4 VUX/s.
        price = bound(price, 0, 1e24);
        qRaw = bound(qRaw, 0, 3_000 * 4e18);
        bPre = bound(bPre, 1, 1e30);
        sPre = bound(sPre, 1, 1e30);

        (uint256 kingLeg, uint256 hardTarget, uint256 strategicLeg) = math.route(price, qRaw, bPre, sPre);

        uint256 retained = price - (price * 8_000) / 10_000;
        uint256 strategicCap = (price * 1_200) / 10_000;
        uint256 hardFloor = retained - strategicCap;

        // 1. the exact formulas (independent oracle, native arithmetic)
        (uint256 expKing, uint256 expHard, uint256 expStrategic) = _expectedLegs(price, qRaw, bPre, sPre);
        assertEq(kingLeg, expKing, "king leg matches the frozen formula");
        assertEq(hardTarget, expHard, "hardTarget matches the frozen formula");
        assertEq(strategicLeg, expStrategic, "strategic residual matches the frozen formula");

        // 2. the legs exhaust P — no dust is stranded, no leg is invented
        assertEq(kingLeg + hardTarget + strategicLeg, price, "king + hardTarget + strategic == P");

        // 3. the bracket on Hard
        assertGe(hardTarget, hardFloor, "hardFloor <= hardTarget");
        assertLe(hardTarget, retained, "hardTarget <= retained");

        // 4. the cap on Strategic
        assertLe(strategicLeg, strategicCap, "strategic <= strategicCap");

        // 5. the King leg is fixed at exactly 80%, adaptivity never touches it
        assertEq(kingLeg, (price * 8_000) / 10_000, "king leg is not adaptive");
    }

    // The three regime sweeps below *construct* their regime by shaping `qRaw`
    // against the tuple, rather than generating freely and filtering with
    // `vm.assume`. Filtering here would discard the large majority of runs — the
    // regimes are narrow slices of the input space — and leave the suite
    // claiming a run count it never actually exercised (see `BaseTest.bound`).
    // The shaping identity used throughout: `D_need = ceil(qRaw × B/S) <= X`
    // exactly when `qRaw <= floor(X × S/B)`.

    /// @dev Regime 1 as a property: whenever `D_need <= hardFloor`, the adaptive
    ///      law must produce *exactly* the prior static split. A regression that
    ///      made Hard greedy would satisfy every bound in the sweep above and
    ///      still break this.
    function testFuzz_DegeneracyEqualsTheStaticSplitExactly(uint256 price, uint256 qSeed, uint256 bPre, uint256 sPre)
        public
        view
    {
        price = bound(price, 0, 1e24);
        bPre = bound(bPre, 1, 1e30);
        sPre = bound(sPre, 1, 1e30);

        uint256 retained = price - (price * 8_000) / 10_000;
        uint256 strategicCap = (price * 1_200) / 10_000;
        uint256 hardFloor = retained - strategicCap;

        uint256 qRaw = bound(qSeed, 0, _floorMulDiv(hardFloor, sPre, bPre));

        (, uint256 hardTarget, uint256 strategicLeg) = math.route(price, qRaw, bPre, sPre);
        assertEq(hardTarget, hardFloor, "degenerate regime: Hard receives exactly the nominal floor plus dust");
        assertEq(strategicLeg, strategicCap, "degenerate regime: Strategic receives exactly the floored 12% cap");
    }

    /// @dev Regime 2 as a property: inside the window `hardFloor < D_need <=
    ///      retained`, Hard receives *precisely* `D_need` — not the floor, not
    ///      everything — and Strategic keeps the remainder.
    function testFuzz_HardTracksDNeedExactlyInsideTheWindow(
        uint256 price,
        uint256 qSeed,
        uint256 bPre,
        uint256 sPre
    ) public view {
        price = bound(price, 0, 1e24);
        bPre = bound(bPre, 1, 1e30);
        sPre = bound(sPre, 1, 1e30);

        uint256 retained = price - (price * 8_000) / 10_000;
        uint256 hardFloor = retained - (price * 1_200) / 10_000;

        uint256 loQ = _floorMulDiv(hardFloor, sPre, bPre);
        uint256 hiQ = _floorMulDiv(retained, sPre, bPre);
        // For small payments the window can be empty (`strategicCap` rounds to
        // zero, collapsing floor onto retained). Nothing to assert then.
        if (hiQ <= loQ) return;

        uint256 qRaw = bound(qSeed, loQ + 1, hiQ);
        // `qRaw <= floor(retained × S/B)` bounds `qRaw × bPre` by `retained × sPre`,
        // so the native-arithmetic oracle below cannot overflow.
        uint256 dNeed = _ceilMulDiv(qRaw, bPre, sPre);

        (, uint256 hardTarget, uint256 strategicLeg) = math.route(price, qRaw, bPre, sPre);
        assertGt(dNeed, hardFloor, "the shaping did land above the floor");
        assertLe(dNeed, retained, "the shaping did land at or below retained");
        assertEq(hardTarget, dNeed, "windowed regime: Hard receives exactly D_need");
        assertEq(strategicLeg, retained - dNeed, "windowed regime: Strategic keeps the remainder");
    }

    /// @dev Regime 3 as a property: once `D_need` exceeds `retained`, Strategic
    ///      is zero and Hard has taken everything available.
    function testFuzz_StrategicIsZeroOnceHardNeedsEverything(
        uint256 price,
        uint256 qSeed,
        uint256 bPre,
        uint256 sPre
    ) public view {
        price = bound(price, 1, 1e24);
        bPre = bound(bPre, 1, 1e30);
        sPre = bound(sPre, 1, 1e30);

        uint256 retained = price - (price * 8_000) / 10_000;

        // Anything strictly above `floor(retained × S/B)` forces `D_need > retained`.
        uint256 minQ = _floorMulDiv(retained, sPre, bPre) + 1;
        uint256 qRaw = bound(qSeed, minQ, minQ + 1e18);

        (, uint256 hardTarget, uint256 strategicLeg) = math.route(price, qRaw, bPre, sPre);
        assertEq(hardTarget, retained, "Hard receives all retained capital");
        assertEq(strategicLeg, 0, "Strategic receives nothing, and nothing compensates it");
    }

    /// @dev Monotonicity in the one input that is supposed to steer the law: more
    ///      raw opportunity can only move capital toward Hard, never away.
    function testFuzz_MoreRawOpportunityNeverReducesTheHardLeg(uint256 price, uint256 qLow, uint256 qHigh)
        public
        view
    {
        price = bound(price, 0, 1e24);
        qLow = bound(qLow, 0, 3_000 * 4e18);
        qHigh = bound(qHigh, qLow, 3_000 * 4e18);

        (, uint256 hardLow, uint256 strategicLow) = math.route(price, qLow, B0, S0);
        (, uint256 hardHigh, uint256 strategicHigh) = math.route(price, qHigh, B0, S0);

        assertGe(hardHigh, hardLow, "Hard is non-decreasing in Qraw");
        assertLe(strategicHigh, strategicLow, "Strategic is non-increasing in Qraw");
    }
}
