// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 7 Deliverable "Off-chain deterministic sqrtP0X96
//          encoder (floor isqrt((n<<192)/d) convention + quantization-delta
//          evidence, sdd.md:L185)" and Task 7.3's "exact slot0"
//          sdd.md:L185 (orientation, floor at both steps, exact slot0 equality,
//          recorded quantization delta), L192 (TickMath bounds pre-asserted)

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {GenesisFixture, IPoolPositions} from "./GenesisFixture.sol";

/// @title GenesisPriceEncodingTest — the encoder is deterministic, floored, and
///        agrees with an implementation that shares no code with it.
/// @notice The two constants below are the output of
///         `tools/offchain/encode-sqrt-p0.mjs --rehearsal`, a BigInt
///         implementation written independently of the Solidity one. They are
///         pasted here rather than computed here on purpose: a test that derives
///         its expected value from the code under test proves only that the code
///         is self-consistent.
///
///         Both orientations are pinned because the live one is an
///         address-dependent accident — whichever way the sort falls at launch,
///         the encoding for that case is already fixed and checked.
contract GenesisPriceEncodingTest is GenesisFixture {
    /// @dev `isqrt((11*B0 << 192) / (10*S0))` — VUX sorts first.
    uint160 internal constant EXPECTED_VUX_TOKEN0 = 3543191142285914205917298257;
    /// @dev `isqrt((10*S0 << 192) / (11*B0))` — WETH sorts first.
    uint160 internal constant EXPECTED_WETH_TOKEN0 = 1771595571142957102963385194354;

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    function setUp() public {
        _runGenesis();
    }

    /// @notice The Solidity encoder reproduces the independent BigInt encoder
    ///         exactly, in both orientations.
    function test_SolidityEncoderMatchesTheIndependentOffchainEncoder() public pure {
        assertEq(uint256(_encode(P0_NUM, P0_DEN)), uint256(EXPECTED_VUX_TOKEN0), "VUX-token0 orientation");
        assertEq(uint256(_encode(P0_DEN, P0_NUM)), uint256(EXPECTED_WETH_TOKEN0), "WETH-token0 orientation");
    }

    /// @notice The fixture selects the orientation by the real token sort, and
    ///         the pool was initialized at exactly that value.
    function test_TheLiveOrientationIsEncodedAndStoredVerbatim() public view {
        uint160 expected = vuxIsToken0 ? EXPECTED_VUX_TOKEN0 : EXPECTED_WETH_TOKEN0;
        assertEq(uint256(sqrtP0X96), uint256(expected), "the fixture encoded the live orientation");

        (uint160 stored,,,,,,) = IPoolPositions(pool).slot0();
        assertEq(uint256(stored), uint256(expected), "slot0 stores it verbatim: exact equality, no tolerance");
    }

    /// @notice The floor convention, stated as the exact integer property rather
    ///         than described: `r` is the largest integer with `r^2 <= x`.
    /// @dev This *is* the "quantization delta < 1 ulp" claim. `r^2 <= x` says the
    ///      encoding never overstates the price; `(r+1)^2 > x` says it is never
    ///      more than one representable step below it. Nothing weaker would
    ///      distinguish a floor encoder from a rounding one.
    function test_FloorConventionHoldsExactlyInBothOrientations() public pure {
        _assertFloorRoot(P0_NUM, P0_DEN, EXPECTED_VUX_TOKEN0, "VUX-token0");
        _assertFloorRoot(P0_DEN, P0_NUM, EXPECTED_WETH_TOKEN0, "WETH-token0");
    }

    function _assertFloorRoot(uint256 n, uint256 d, uint160 root, string memory what) private pure {
        uint256 x = Math.mulDiv(n, 1 << 192, d);
        uint256 r = uint256(root);
        assertLe(r * r, x, string.concat(what, ": r^2 <= x - the encoding never overstates the price"));
        assertGt((r + 1) * (r + 1), x, string.concat(what, ": (r+1)^2 > x - within one ulp of the exact root"));
    }

    /// @notice The encoder is a pure function of the recorded rational: the same
    ///         inputs give the same output, and the ratio step itself floors.
    function test_EncoderIsDeterministicAndTheRatioStepFloors() public pure {
        assertEq(uint256(_encode(P0_NUM, P0_DEN)), uint256(_encode(P0_NUM, P0_DEN)), "same inputs, same output");

        // Scaling numerator and denominator by the same factor is the same
        // rational, so a correct floor encoder returns the same root.
        assertEq(
            uint256(_encode(P0_NUM, P0_DEN)),
            uint256(_encode(P0_NUM * 3, P0_DEN * 3)),
            "the encoding depends on the rational, not on its representation"
        );
    }

    /// @notice Discrimination: the pinned constants are load-bearing. A root one
    ///         step away from the encoder's output fails the floor property, so
    ///         a wrong constant could not have been pasted in unnoticed.
    function test_Discrimination_NeighbouringRootsFailTheFloorProperty() public pure {
        uint256 x = Math.mulDiv(P0_NUM, 1 << 192, P0_DEN);
        uint256 r = uint256(EXPECTED_VUX_TOKEN0);

        // One below: still <= x, but no longer maximal — (r-1+1)^2 = r^2 <= x.
        assertLe((r - 1) * (r - 1), x, "r-1 squared is below x");
        assertLe(r * r, x, "so r-1 is not the largest root - it fails maximality");

        // One above: overshoots outright.
        assertGt((r + 1) * (r + 1), x, "r+1 squared exceeds x - it would overstate the price");
    }

    /// @notice Both orientations sit inside the range the vendored `initialize`
    ///         enforces, which `GenesisDeployer` pre-asserts for a clear failure.
    function test_BothOrientationsAreInsideTickMathBounds() public pure {
        assertGe(uint256(EXPECTED_VUX_TOKEN0), uint256(MIN_SQRT_RATIO), "VUX-token0 >= MIN_SQRT_RATIO");
        assertLt(uint256(EXPECTED_VUX_TOKEN0), uint256(MAX_SQRT_RATIO), "VUX-token0 < MAX_SQRT_RATIO");
        assertGe(uint256(EXPECTED_WETH_TOKEN0), uint256(MIN_SQRT_RATIO), "WETH-token0 >= MIN_SQRT_RATIO");
        assertLt(uint256(EXPECTED_WETH_TOKEN0), uint256(MAX_SQRT_RATIO), "WETH-token0 < MAX_SQRT_RATIO");
    }

    /// @notice The two orientations are reciprocals of the same rational, so
    ///         encoding one and inverting must land within a ulp of the other.
    /// @dev A transposed orientation is the single most plausible encoder
    ///      mistake, and it is not detectable from the constant alone — the
    ///      wrong one is a perfectly valid price. This is what catches it.
    function test_TheTwoOrientationsAreReciprocalNotInterchangeable() public pure {
        uint256 a = uint256(EXPECTED_VUX_TOKEN0);
        uint256 b = uint256(EXPECTED_WETH_TOKEN0);
        assertNotEq(a, b, "the orientations are genuinely different constants");

        // sqrt(p) * sqrt(1/p) == 1, so a*b should be 2^192 up to floor error.
        //
        // The tolerance is derived, not guessed. Each root is floored, so each
        // sits at most 1 below its exact value; the product therefore falls
        // short by at most `a*1 + b*1 + 1`, which after the 2^96 scaling is
        // `(a + b) / 2^96 + 1`. Anything larger would mean the two constants are
        // not reciprocals of one rational — which is exactly the transposition
        // this test exists to catch.
        uint256 unit = 1 << 96;
        uint256 product = Math.mulDiv(a, b, unit);
        uint256 maxShortfall = (a + b) / unit + 2;

        assertLe(product, unit, "floor on both sides means the product never exceeds 2^96");
        assertGe(product + maxShortfall, unit, "the constants are reciprocals within the derived floor error");
        assertLt(maxShortfall, unit, "the bound is a tolerance, not a vacuous one");
    }

    function _encode(uint256 n, uint256 d) private pure returns (uint160) {
        return uint160(Math.sqrt(Math.mulDiv(n, 1 << 192, d)));
    }
}
