// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 4 AC-6 (LSG P0), Task 4.6; FR-13 acceptance
//          (prd.md:L522-L524); INV-32, INV-33, INV-34; FB-10; F-50
//          sdd.md:L146, L322-L344

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {Vm} from "../harness/Vm.sol";
import {MockLsgModule} from "../mocks/MockLsgModule.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {TreasuryFixture} from "./TreasuryFixture.sol";

/// @title TreasuryLsgBoundaryTest — an activation authority and a bounded read.
/// @notice What ships at P0 is a slot, an interface, and a consumption path. The
///         boundary claim is that this is *all* a signal can ever be: it names a
///         relative split over an operator-admitted menu, clamped by caps, and
///         reaches nothing else — not the Reserve, not minting, not routing, not
///         admission, not removal (INV-32/33; FR-13.3).
contract TreasuryLsgBoundaryTest is TreasuryFixture {
    uint8 internal constant NETTING = 0;
    uint8 internal constant UNITIZED = 2;

    uint256 internal constant CAP = 1_000 ether;

    MockStrategy internal alpha;
    MockStrategy internal beta;

    bytes32 internal constant SIGNAL_CONSUMED_TOPIC =
        keccak256("SignalConsumed(uint64,uint256,address[],uint256[])");

    function setUp() public {
        _deploySystem();
        alpha = _newStrategy();
        beta = _newStrategy();
        _fundTreasury(address(weth), 10_000 ether);
    }

    function _signal(MockLsgModule module, address a, uint256 wa, address b, uint256 wb) internal {
        address[] memory strategies = new address[](2);
        uint256[] memory weights = new uint256[](2);
        (strategies[0], weights[0]) = (a, wa);
        (strategies[1], weights[1]) = (b, wb);
        module.setSignal(strategies, weights);
    }

    // =========================================================================
    // Launch state and the activation authority (FR-13.4, INV-34)
    // =========================================================================

    function test_LaunchesInactiveWithTheAuthorityPresent() public view {
        assertEq(treasury.lsgModule(), address(0), "inactive at launch");
        // The authority's presence is asserted structurally in TreasurySurface;
        // here it is asserted behaviourally, by using it below.
    }

    /// @dev INV-34: activation is an affirmative operator action and nothing
    ///      else. No numeric readiness gate and no calendar date exists in the
    ///      code (F-50), so activation is available immediately, from the launch
    ///      state, with zero capital, zero revenue, and zero admitted strategies.
    function test_ActivationIsAffirmativeAndUngated() public {
        assertEq(treasury.realizedRevenue(address(weth)), 0, "no revenue");
        assertEq(uint256(treasury.allocationCount()), 0, "no history");

        MockLsgModule module = new MockLsgModule();
        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.LSGActivated(address(module));
        treasury.activateLSG(address(module));

        assertEq(treasury.lsgModule(), address(module), "activated by operator decision alone");
    }

    /// @dev The complement of INV-34: time alone never activates it. A year of
    ///      block time changes nothing, because no calendar exists to reach.
    function test_TimeAloneNeverActivatesLsg() public {
        vm.warp(vm.getBlockTimestamp() + 365 days);
        assertEq(treasury.lsgModule(), address(0), "still inactive after a year");

        vm.expectPartialRevert(StrategicTreasury.LSGInactive.selector);
        treasury.deployMarginalBySignal(1 ether);
    }

    function test_DeactivationIsInstantAndEvented() public {
        MockLsgModule module = _activateLsg();

        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.LSGDeactivated(address(module));
        treasury.deactivateLSG();

        assertEq(treasury.lsgModule(), address(0), "severed in the same transaction");
        vm.expectPartialRevert(StrategicTreasury.LSGInactive.selector);
        treasury.deployMarginalBySignal(1 ether);
    }

    /// @dev A module swap is deactivate + activate; there is no in-place
    ///      replacement, so a swap is always two evented operator acts.
    function test_ModuleSwapIsDeactivateThenActivate() public {
        MockLsgModule first = _activateLsg();
        MockLsgModule second = new MockLsgModule();

        treasury.deactivateLSG();
        treasury.activateLSG(address(second));

        assertEq(treasury.lsgModule(), address(second), "swapped");
        assertNotEq(treasury.lsgModule(), address(first), "the old module is severed");
    }

    function test_ActivationRejectsTheZeroAddressAndDoubleDeactivation() public {
        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        treasury.activateLSG(address(0));

        vm.expectRevert(StrategicTreasury.LSGInactive.selector);
        treasury.deactivateLSG();
    }

    /// @dev The signal surfaces fail closed before activation (AC-6).
    function test_SignalSurfacesFailClosedBeforeActivation() public {
        vm.expectRevert(StrategicTreasury.LSGInactive.selector);
        treasury.deployMarginalBySignal(1 ether);

        vm.expectRevert(StrategicTreasury.LSGInactive.selector);
        treasury.fundSignalerProgram(address(weth), 1, 0, 0);
    }

    function test_ActivationAuthorityRejectsAnUnauthorizedCaller() public {
        MockLsgModule module = new MockLsgModule();

        vm.startPrank(NON_OPERATOR);
        _expectUnauthorized();
        treasury.activateLSG(address(module));

        _expectUnauthorized();
        treasury.deactivateLSG();

        _expectUnauthorized();
        treasury.deployMarginalBySignal(1 ether);

        _expectUnauthorized();
        treasury.fundSignalerProgram(address(weth), 1, 0, 0);
        vm.stopPrank();
    }

    // =========================================================================
    // Consumption — a relative split, clamped (INV-32)
    // =========================================================================

    function test_MarginalDeploymentSplitsProRataByWeight() public {
        _admitMatured(address(alpha), address(weth), CAP, NETTING);
        _admitMatured(address(beta), address(weth), CAP, NETTING);
        MockLsgModule module = _activateLsg();
        _signal(module, address(alpha), 1, address(beta), 3);

        treasury.deployMarginalBySignal(100 ether);

        assertEq(treasury.outstandingPrincipal(address(alpha), address(weth)), 25 ether, "1/4");
        assertEq(treasury.outstandingPrincipal(address(beta), address(weth)), 75 ether, "3/4");
    }

    /// @dev Caps clamp the split, and the clamped remainder is simply not
    ///      deployed — rounding and clamping both favour NOT deploying.
    function test_CapsClampTheSplitAndTheRemainderStaysInCustody() public {
        _admitMatured(address(alpha), address(weth), 10 ether, NETTING);
        _admitMatured(address(beta), address(weth), CAP, NETTING);
        MockLsgModule module = _activateLsg();
        _signal(module, address(alpha), 1, address(beta), 1);

        uint256 held = weth.balanceOf(address(treasury));
        treasury.deployMarginalBySignal(100 ether);

        assertEq(treasury.outstandingPrincipal(address(alpha), address(weth)), 10 ether, "clamped at the cap");
        assertEq(treasury.outstandingPrincipal(address(beta), address(weth)), 50 ether, "its own share, unclamped");
        assertEq(held - weth.balanceOf(address(treasury)), 60 ether, "the other 40 never left custody");
    }

    /// @dev INV-32: the menu is the admitted set. A signal for an address that is
    ///      not admitted, not matured, or has been removed moves nothing — the
    ///      module cannot cause an admission or bypass the delay.
    function test_ASignalCannotReachAnUnadmittedUnmaturedOrRemovedTarget() public {
        _admitMatured(address(alpha), address(weth), CAP, NETTING);
        MockStrategy removed = _newStrategy();
        _admitMatured(address(removed), address(weth), CAP, NETTING);
        treasury.removeStrategy(address(removed), true);
        MockStrategy stranger = _newStrategy();
        // Admitted last, and deliberately not warped past: still pending.
        MockStrategy unmatured = _newStrategy();
        treasury.admitStrategy(address(unmatured), address(weth), CAP, NETTING);

        MockLsgModule module = _activateLsg();
        address[] memory strategies = new address[](4);
        uint256[] memory weights = new uint256[](4);
        (strategies[0], weights[0]) = (address(alpha), 1);
        (strategies[1], weights[1]) = (address(unmatured), 1);
        (strategies[2], weights[2]) = (address(removed), 1);
        (strategies[3], weights[3]) = (address(stranger), 1);
        module.setSignal(strategies, weights);

        treasury.deployMarginalBySignal(100 ether);

        assertEq(treasury.outstandingPrincipal(address(alpha), address(weth)), 100 ether, "the eligible one took it all");
        assertEq(treasury.outstandingPrincipal(address(unmatured), address(weth)), 0, "the delay is not bypassable");
        assertEq(treasury.outstandingPrincipal(address(removed), address(weth)), 0, "removal is not overridable");
        assertEq(treasury.outstandingPrincipal(address(stranger), address(weth)), 0, "admission is not signalable");
    }

    /// @dev INV-33: a module that signals the monetary core reaches nothing. The
    ///      core addresses are not admitted, so they are simply not on the menu —
    ///      and after the call every core value is bit-identical.
    function test_ASignalNamingTheMonetaryCoreReachesNothing() public {
        _admitMatured(address(alpha), address(weth), CAP, NETTING);
        MockLsgModule module = _activateLsg();

        address[] memory strategies = new address[](4);
        uint256[] memory weights = new uint256[](4);
        (strategies[0], weights[0]) = (address(reserve), 1_000);
        (strategies[1], weights[1]) = (address(rig), 1_000);
        (strategies[2], weights[2]) = (address(vux), 1_000);
        (strategies[3], weights[3]) = (address(alpha), 1);
        module.setSignal(strategies, weights);

        CoreState memory before = _snapshotCore();
        treasury.deployMarginalBySignal(100 ether);
        _assertCoreUnchanged(before, "a signal naming the core");

        assertEq(treasury.outstandingPrincipal(address(alpha), address(weth)), 100 ether, "only the admitted target");
    }

    /// @dev A duplicated entry clamps against live headroom rather than reverting
    ///      the allocation: a module cannot deny service by repeating a name.
    function test_ADuplicatedSignalEntryClampsRatherThanReverting() public {
        _admitMatured(address(alpha), address(weth), 30 ether, NETTING);
        MockLsgModule module = _activateLsg();
        _signal(module, address(alpha), 1, address(alpha), 1);

        treasury.deployMarginalBySignal(100 ether);
        assertEq(treasury.outstandingPrincipal(address(alpha), address(weth)), 30 ether, "clamped at the cap, no revert");
    }

    function test_AMalformedSignalIsRejected() public {
        _admitMatured(address(alpha), address(weth), CAP, NETTING);
        MockLsgModule module = _activateLsg();
        _signal(module, address(alpha), 1, address(beta), 1);
        module.setMismatchedLengths(true);

        vm.expectRevert(StrategicTreasury.MalformedSignal.selector);
        treasury.deployMarginalBySignal(1 ether);
    }

    /// @dev An all-ineligible or all-zero-weight signal deploys nothing and
    ///      reverts nothing: no eligible target is a valid, conservative outcome.
    function test_ASignalWithNoEligibleTargetsDeploysNothing() public {
        MockLsgModule module = _activateLsg();
        _signal(module, address(alpha), 1, address(beta), 1);

        uint256 held = weth.balanceOf(address(treasury));
        treasury.deployMarginalBySignal(100 ether);
        assertEq(weth.balanceOf(address(treasury)), held, "nothing deployed, nothing reverted");
        assertEq(uint256(treasury.allocationCount()), 1, "and the consumption is still recorded");
    }

    /// @dev The event snapshots exactly what was read, index-aligned with the
    ///      module's own answer — including the zeros (UC-9 observability).
    ///
    ///      It also pins the accepted **filter-then-split** semantics
    ///      (sdd.md:L337: "filters to admitted + matured + cap-headroom
    ///      strategies, splits `totalAmount` pro-rata by weight"): the weights of
    ///      ineligible entries are not part of the denominator, so `beta`'s share
    ///      does not become undeployed dust — the eligible set absorbs the whole
    ///      requested amount, still clamped by its own caps, with the operator
    ///      holding the size.
    function test_SignalConsumedSnapshotsWhatWasRead() public {
        _admitMatured(address(alpha), address(weth), CAP, NETTING);
        MockLsgModule module = _activateLsg();
        _signal(module, address(alpha), 3, address(beta), 1);

        vm.recordLogs();
        treasury.deployMarginalBySignal(100 ether);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(treasury) || logs[i].topics[0] != SIGNAL_CONSUMED_TOPIC) continue;
            found++;
            assertEq(uint256(logs[i].topics[1]), 1, "allocationId");
            (uint256 totalDeployed, address[] memory strategies, uint256[] memory amounts) =
                abi.decode(logs[i].data, (uint256, address[], uint256[]));
            assertEq(totalDeployed, 100 ether, "total actually deployed");
            assertEq(strategies.length, 2, "the full signal is snapshotted");
            assertEq(strategies[0], address(alpha), "index-aligned");
            assertEq(strategies[1], address(beta), "index-aligned");
            assertEq(amounts[0], 100 ether, "the only eligible weight is the whole denominator");
            assertEq(amounts[1], 0, "the ineligible entry is recorded as zero");
        }
        assertEq(found, 1, "exactly one SignalConsumed");
    }

    /// @dev Signal-driven deployment runs through the same principal ledger as a
    ///      manual one: it is not a second, weaker path (sdd.md:L337).
    function test_SignalDeploymentBooksPrincipalLikeAManualOne() public {
        _admitMatured(address(alpha), address(weth), CAP, UNITIZED);
        MockLsgModule module = _activateLsg();
        _signal(module, address(alpha), 1, address(beta), 0);

        treasury.deployMarginalBySignal(40 ether);

        assertEq(treasury.outstandingPrincipal(address(alpha), address(weth)), 40 ether, "principal booked");
        assertEq(treasury.unitsHeld(address(alpha)), 40 ether, "and UNITIZED units measured, exactly as manually");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "deployment creates no revenue");
    }

    // =========================================================================
    // Signaler programs — revenue-bounded, module-gated (FR-13.7)
    // =========================================================================

    function _earnAndEarmark(uint256 amount) internal {
        _admitMatured(address(alpha), address(weth), CAP, NETTING);
        _fund(ALICE, address(weth), amount);
        vm.prank(ALICE);
        weth.approve(address(treasury), amount);
        vm.prank(ALICE);
        treasury.returnFor(address(alpha), address(weth), amount);
        treasury.allocateRevenue(address(weth), 0, 0, 0, amount);
    }

    function test_FundingSpendsTheEarmarkAndRegistersOnTheModule() public {
        _earnAndEarmark(20 ether);
        MockLsgModule module = _activateLsg();

        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.SignalerProgramFunded(address(weth), 12 ether, 100, 200);
        treasury.fundSignalerProgram(address(weth), 12 ether, 100, 200);

        assertEq(treasury.signalerBudget(address(weth)), 8 ether, "earmark spent");
        assertEq(weth.balanceOf(address(module)), 12 ether, "the module received exactly the funded amount");
        assertEq(module.programCount(), 1, "and registered one PROTOCOL program");
    }

    /// @dev Signaler economics are revenue-bounded by construction: the earmark
    ///      can only be filled by `allocateRevenue`, which is itself bounded.
    function test_FundingCannotExceedTheEarmark() public {
        _earnAndEarmark(20 ether);
        _activateLsg();

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategicTreasury.RevenueExceedsRealized.selector, address(weth), 20 ether + 1, 20 ether
            )
        );
        treasury.fundSignalerProgram(address(weth), 20 ether + 1, 0, 0);
    }

    /// @dev FB-10: deactivation severs the funding path too. An absent, failed,
    ///      or captured module leaves the operator fully able to act, and the
    ///      earmarked value stays in custody.
    function test_DeactivationSeversFundingAndStrandsNothing() public {
        _earnAndEarmark(20 ether);
        _activateLsg();
        treasury.deactivateLSG();

        vm.expectRevert(StrategicTreasury.LSGInactive.selector);
        treasury.fundSignalerProgram(address(weth), 1 ether, 0, 0);

        assertEq(treasury.signalerBudget(address(weth)), 20 ether, "the earmark is intact");
        // And the operator's own controls are unaffected.
        treasury.removeStrategy(address(alpha), true);
        (bool active,,) = treasury.admissionOf(address(alpha));
        assertFalse(active, "operator authority survives a dead module");
    }

    /// @dev The module is granted nothing standing: the treasury pushes an exact
    ///      amount and then calls, so no allowance survives the transaction.
    function test_TheModuleHoldsNoAllowanceOverTheTreasury() public {
        _earnAndEarmark(20 ether);
        MockLsgModule module = _activateLsg();
        treasury.fundSignalerProgram(address(weth), 5 ether, 0, 0);

        assertEq(weth.allowance(address(treasury), address(module)), 0, "no standing approval");
        assertFalse(treasury.hasRole(treasury.OPERATOR_ROLE(), address(module)), "and no role");
    }
}
