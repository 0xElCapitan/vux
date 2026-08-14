// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 4 AC-3 (accounting properties for all flow sequences
//          and all modes), Task 4.7, Success Metric ">=10,000 fuzz runs per mode"
//          INV-23, INV-28, INV-30; FR-9, FR-12; sdd.md:L858

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {TreasuryFixture} from "./TreasuryFixture.sol";

/// @title TreasuryAccountingPropertiesTest — the §1.10 guards, quantified.
/// @notice `TreasuryFlows.t.sol` pins each guard at the boundary it defends with
///         hand-chosen values. This file asks the same questions over the input
///         space: for ALL deployment/return sequences, for ALL unit prices, for
///         ALL redemption splits, does the arithmetic still hold?
///
///         Inputs are **shaped** with `bound`, never filtered with `vm.assume`.
///         The modes are narrow slices of the input space and filtering would
///         discard most runs while the suite still reported 10,000 — the exact
///         failure `BaseTest.bound` warns about.
contract TreasuryAccountingPropertiesTest is TreasuryFixture {
    uint8 internal constant NETTING = 0;
    uint8 internal constant CLAIM = 1;
    uint8 internal constant UNITIZED = 2;

    /// @dev Wide enough that `cap` is never the binding constraint in a property
    ///      about classification, and small enough that `mulDiv` intermediates
    ///      stay far from overflow.
    uint256 internal constant CAP = type(uint128).max;

    MockStrategy internal strategy;

    function setUp() public {
        _deploySystem();
        strategy = _newStrategy();
    }

    function _return(address strategy_, address asset, uint256 amount) internal {
        _fund(ALICE, asset, amount);
        vm.prank(ALICE);
        IApproval(asset).approve(address(treasury), amount);
        vm.prank(ALICE);
        treasury.returnFor(strategy_, asset, amount);
    }

    // =========================================================================
    // NETTING — revenue only beyond full principal return
    // =========================================================================

    /// @dev For any deployment and any three-chunk return sequence:
    ///      `revenue == max(0, Σreturned − deployed)` exactly, and principal is
    ///      retired first. The three chunks matter: the property must hold across
    ///      a *sequence*, not just a single netting event.
    function testFuzz_NettingRecognisesOnlyTheExcessOverFullReturn(
        uint256 deployed,
        uint256 r1,
        uint256 r2,
        uint256 r3
    ) public {
        deployed = bound(deployed, 1, 1e24);
        r1 = bound(r1, 0, 1e24);
        r2 = bound(r2, 0, 1e24);
        r3 = bound(r3, 0, 1e24);

        _fundTreasury(address(weth), deployed);
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), deployed);

        if (r1 != 0) _return(address(strategy), address(weth), r1);
        if (r2 != 0) _return(address(strategy), address(weth), r2);
        if (r3 != 0) _return(address(strategy), address(weth), r3);

        uint256 returned = r1 + r2 + r3;
        uint256 expectedRevenue = returned > deployed ? returned - deployed : 0;
        uint256 expectedOutstanding = returned >= deployed ? 0 : deployed - returned;

        assertEq(treasury.realizedRevenue(address(weth)), expectedRevenue, "revenue is exactly the excess");
        assertEq(
            treasury.outstandingPrincipal(address(strategy), address(weth)),
            expectedOutstanding,
            "principal is retired first, and only by what arrived"
        );
    }

    /// @dev The distribution bound, over arbitrary NETTING flow sequences: one
    ///      wei beyond the credit always reverts, and exactly the credit always
    ///      clears. Compound-only, so the property is about the accumulator and
    ///      not about whether a transfer happened to have liquidity.
    function testFuzz_DistributionsNeverExceedRealizedCredits(uint256 deployed, uint256 returned) public {
        deployed = bound(deployed, 1, 1e24);
        returned = bound(returned, 0, 2e24);

        _fundTreasury(address(weth), deployed);
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), deployed);
        if (returned != 0) _return(address(strategy), address(weth), returned);

        uint256 credited = treasury.realizedRevenue(address(weth));

        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), credited + 1, 0, 0, 0);

        treasury.allocateRevenue(address(weth), credited, 0, 0, 0);
        assertEq(treasury.realizedRevenue(address(weth)), 0, "exactly the credit is spendable, never more");
    }

    // =========================================================================
    // CLAIM — measured deltas under intact units
    // =========================================================================

    /// @dev For any position size and any harvest: an intact (or grown) position
    ///      credits exactly the measured reward delta and leaves principal
    ///      untouched; a shrunk one reverts. Same inputs, opposite outcomes,
    ///      selected only by the units-intact guard.
    function testFuzz_ClaimCreditsMeasuredYieldOnlyWhileUnitsAreIntact(
        uint256 deployed,
        uint256 reward,
        bool shrink
    ) public {
        deployed = bound(deployed, 1, 1e24);
        reward = bound(reward, 1, 1e24);

        _fundTreasury(address(weth), deployed);
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        treasury.deployToStrategy(address(strategy), address(weth), deployed);
        strategy.lieUnits(deployed);

        address[] memory rewards = new address[](1);
        rewards[0] = address(otherAsset);
        strategy.setRewardAssets(rewards);
        otherAsset.mint(address(strategy), reward);
        strategy.setHarvestAmount(address(otherAsset), reward);
        strategy.setShrinkUnitsOnHarvest(shrink);

        if (shrink) {
            vm.expectRevert(
                abi.encodeWithSelector(StrategicTreasury.PrincipalUnitsDecreased.selector, address(strategy))
            );
            treasury.harvestYield(address(strategy));
            assertEq(treasury.realizedRevenue(address(otherAsset)), 0, "a shrinking harvest credits nothing");
        } else {
            treasury.harvestYield(address(strategy));
            assertEq(treasury.realizedRevenue(address(otherAsset)), reward, "exactly the measured delta");
        }

        assertEq(
            treasury.outstandingPrincipal(address(strategy), address(weth)), deployed, "principal never moves on harvest"
        );
    }

    // =========================================================================
    // UNITIZED — cost-basis release
    // =========================================================================

    /// @dev Basis conservation: over a full unwind in four uneven chunks, at any
    ///      unit price, `Σ basisReleased` equals the original basis to the wei —
    ///      so the outstanding basis lands on exactly zero, never on rounding
    ///      residue and never below.
    function testFuzz_UnitizedBasisConservesOverAnyFullUnwind(uint256 basis, uint256 unitRate, uint256 seed) public {
        basis = bound(basis, 4, 1e24);
        unitRate = bound(unitRate, 1e15, 1e21); // 0.001 .. 1000 units per asset

        _fundTreasury(address(weth), basis);
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        strategy.setUnitsPerAsset(unitRate);
        treasury.deployToStrategy(address(strategy), address(weth), basis);

        uint256 units = treasury.unitsHeld(address(strategy));
        if (units == 0) {
            // A unit price so coarse the deposit rounds to zero units: nothing to
            // unwind, and the basis stays exactly where it was booked.
            assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), basis, "basis intact");
            return;
        }

        for (uint256 i = 0; i < 3 && treasury.unitsHeld(address(strategy)) > 1; i++) {
            uint256 held = treasury.unitsHeld(address(strategy));
            uint256 chunk = bound(uint256(keccak256(abi.encode(seed, i))), 1, held - 1);
            treasury.redeemUnits(address(strategy), chunk, 0);
        }
        treasury.redeemUnits(address(strategy), treasury.unitsHeld(address(strategy)), 0);

        assertEq(treasury.unitsHeld(address(strategy)), 0, "fully unwound");
        assertEq(
            treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "and the basis closed out exactly"
        );
    }

    /// @dev Gain becomes revenue, shortfall becomes loss, and revenue is never
    ///      negative — at any payout against any basis, in one redemption.
    function testFuzz_UnitizedGainIsRevenueAndShortfallIsLossOnly(uint256 basis, uint256 payout) public {
        basis = bound(basis, 1, 1e24);
        payout = bound(payout, 0, 2e24);

        _fundTreasury(address(weth), basis);
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        treasury.deployToStrategy(address(strategy), address(weth), basis);

        // The strategy holds `basis` from the deployment; top it up if the payout
        // exceeds that, so the redemption can actually pay what it promises.
        if (payout > basis) weth.mint(address(strategy), payout - basis);
        strategy.setRedeemPayout(address(weth), payout);

        treasury.redeemUnits(address(strategy), treasury.unitsHeld(address(strategy)), 0);

        uint256 expectedRevenue = payout > basis ? payout - basis : 0;
        assertEq(treasury.realizedRevenue(address(weth)), expectedRevenue, "only the excess over basis is revenue");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "the basis is fully released");
    }

    // =========================================================================
    // Cross-mode invariants
    // =========================================================================

    /// @dev An arbitrary-asset "return" is rejected in every mode. The asset is
    ///      fuzzed over addresses that were never admitted for the strategy and
    ///      carry no outstanding principal, which is exactly the set rule 2
    ///      closes.
    function testFuzz_ArbitraryAssetReturnsAreRejectedInEveryMode(uint8 mode, uint256 assetSeed) public {
        mode = uint8(bound(mode, 0, 2));
        _admitMatured(address(strategy), address(weth), CAP, mode);

        // A fresh, never-admitted asset per run.
        address stranger = address(uint160(uint256(keccak256(abi.encode(assetSeed, "stranger")))));
        if (stranger == address(weth) || stranger == address(0)) return;

        vm.expectRevert(
            abi.encodeWithSelector(StrategicTreasury.UnknownReturnAsset.selector, address(strategy), stranger)
        );
        treasury.returnFor(address(strategy), stranger, 1);
    }

    /// @dev A write-off can only reduce principal accounting. Over any deployed
    ///      amount and any partial recovery, `closeStrategy` leaves the revenue
    ///      credit exactly where it was and drives principal to zero — it is not
    ///      a declaration escape hatch (§1.10 rule 3).
    function testFuzz_CloseStrategyOnlyEverReducesPrincipal(uint256 deployed, uint256 recovered, uint8 mode) public {
        mode = uint8(bound(mode, 0, 2));
        deployed = bound(deployed, 1, 1e24);
        recovered = bound(recovered, 0, deployed);

        _fundTreasury(address(weth), deployed);
        _admitMatured(address(strategy), address(weth), CAP, mode);
        treasury.deployToStrategy(address(strategy), address(weth), deployed);
        if (recovered != 0) treasury.recallFromStrategy(address(strategy), address(weth), recovered);

        uint256 revenueBefore = treasury.realizedRevenue(address(weth));
        uint256 principalBefore = treasury.outstandingPrincipal(address(strategy), address(weth));

        treasury.removeStrategy(address(strategy), true);
        treasury.closeStrategy(address(strategy));

        assertEq(treasury.realizedRevenue(address(weth)), revenueBefore, "a write-off creates no revenue");
        assertLe(treasury.outstandingPrincipal(address(strategy), address(weth)), principalBefore, "only reduces");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "and reduces to zero");
    }

    /// @dev Mode immutability for every ordered pair of distinct modes: while a
    ///      strategy is admitted, no re-admission can change its mode.
    function testFuzz_ModeIsImmutableWhileAdmitted(uint8 from, uint8 to) public {
        from = uint8(bound(from, 0, 2));
        to = uint8(bound(to, 0, 2));
        if (from == to) return;

        treasury.admitStrategy(address(strategy), address(weth), CAP, from);

        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.ModeImmutable.selector, address(strategy), from));
        treasury.admitStrategy(address(strategy), address(weth), CAP, to);

        (, uint8 mode,) = treasury.admissionOf(address(strategy));
        assertEq(uint256(mode), uint256(from), "mode unchanged");
    }

    /// @dev The global claim, in one property: across a mixed flow sequence in
    ///      any mode, the treasury never credits more revenue than value actually
    ///      arrived from outside. Value in is measured on the token, not on the
    ///      treasury's books, so a bookkeeping error cannot satisfy it.
    function testFuzz_RevenueCreditNeverExceedsValueDelivered(uint256 deployed, uint256 returned, uint8 mode)
        public
    {
        mode = uint8(bound(mode, 0, 2));
        deployed = bound(deployed, 1, 1e24);
        returned = bound(returned, 0, 2e24);

        _fundTreasury(address(weth), deployed);
        _admitMatured(address(strategy), address(weth), CAP, mode);
        treasury.deployToStrategy(address(strategy), address(weth), deployed);

        uint256 heldAfterDeploy = weth.balanceOf(address(treasury));
        if (returned != 0) _return(address(strategy), address(weth), returned);
        uint256 delivered = weth.balanceOf(address(treasury)) - heldAfterDeploy;

        assertLe(treasury.realizedRevenue(address(weth)), delivered, "revenue is bounded by what arrived");
    }
}

interface IApproval {
    function approve(address spender, uint256 amount) external returns (bool);
}
