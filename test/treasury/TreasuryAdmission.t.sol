// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 4 AC-2 (mode immutability, maturity gate, instant
//          removal/recall), AC-7 (unauthorized-caller negatives), Task 4.3
//          sdd.md:L147 (admission registry), §1.12 (ADMISSION_DELAY)

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {Vm} from "../harness/Vm.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {TreasuryFixture} from "./TreasuryFixture.sol";

/// @title TreasuryAdmissionTest — the asymmetric guard.
/// @notice "Slow to add risk, instant to remove it" (sdd.md:L147) is one
///         sentence with two halves, and both halves are load-bearing. The delay
///         only matters if nothing can shortcut it; the instant removal only
///         matters if nothing — no signal, no module, no pending state — can
///         block or delay it.
contract TreasuryAdmissionTest is TreasuryFixture {
    uint8 internal constant NETTING = 0;
    uint8 internal constant CLAIM = 1;
    uint8 internal constant UNITIZED = 2;

    uint256 internal constant CAP = 100 ether;

    MockStrategy internal strategy;

    function setUp() public {
        _deploySystem();
        strategy = _newStrategy();
        _fundTreasury(address(weth), 1_000 ether);
    }

    // --- admission records ----------------------------------------------------

    function test_AdmissionRecordsModeCapAndMaturity() public {
        uint64 expectedMaturity = uint64(vm.getBlockTimestamp()) + treasury.ADMISSION_DELAY();

        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.StrategyAdmitted(address(strategy), address(weth), CAP, CLAIM, expectedMaturity);
        treasury.admitStrategy(address(strategy), address(weth), CAP, CLAIM);

        (bool active, uint8 mode, address unitAsset) = treasury.admissionOf(address(strategy));
        assertTrue(active, "active");
        assertEq(uint256(mode), uint256(CLAIM), "mode recorded");
        assertEq(unitAsset, address(0), "no unit asset outside UNITIZED");

        (uint256 cap, uint64 maturesAt) = treasury.limitOf(address(strategy), address(weth));
        assertEq(cap, CAP, "cap recorded");
        assertEq(uint256(maturesAt), uint256(expectedMaturity), "maturity is now + 24h");
    }

    function test_UnitizedAdmissionFixesTheUnitAsset() public {
        treasury.admitStrategy(address(strategy), address(weth), CAP, UNITIZED);
        (,, address unitAsset) = treasury.admissionOf(address(strategy));
        assertEq(unitAsset, address(weth), "the unit ledger is denominated in the admitted asset");
    }

    function test_AdmittedAssetsAreEnumerableForCloseout() public {
        treasury.admitStrategy(address(strategy), address(weth), CAP, NETTING);
        treasury.admitStrategy(address(strategy), address(otherAsset), CAP, NETTING);

        address[] memory assets = treasury.strategyAssets(address(strategy));
        assertEq(assets.length, 2, "both assets listed once");
        assertEq(assets[0], address(weth), "in admission order");
        assertEq(assets[1], address(otherAsset), "in admission order");

        // Re-admission of the same asset must not duplicate the entry.
        treasury.admitStrategy(address(strategy), address(weth), CAP * 2, NETTING);
        assertEq(treasury.strategyAssets(address(strategy)).length, 2, "no duplicate entry");
    }

    // --- the maturity gate ----------------------------------------------------

    function test_DeploymentIsBlockedUntilMaturity() public {
        treasury.admitStrategy(address(strategy), address(weth), CAP, NETTING);
        (, uint64 maturesAt) = treasury.limitOf(address(strategy), address(weth));

        vm.expectRevert(
            abi.encodeWithSelector(StrategicTreasury.AdmissionNotMatured.selector, address(strategy), maturesAt)
        );
        treasury.deployToStrategy(address(strategy), address(weth), 1 ether);
    }

    /// @dev One second before maturity is still blocked; the maturity second
    ///      itself is open. An off-by-one here is a 24-hour guard that is really
    ///      a 24-hour-and-one-second guard, or worse, a 0-second one.
    function test_TheMaturityBoundaryIsExact() public {
        treasury.admitStrategy(address(strategy), address(weth), CAP, NETTING);
        (, uint64 maturesAt) = treasury.limitOf(address(strategy), address(weth));

        vm.warp(uint256(maturesAt) - 1);
        vm.expectPartialRevert(StrategicTreasury.AdmissionNotMatured.selector);
        treasury.deployToStrategy(address(strategy), address(weth), 1 ether);

        vm.warp(uint256(maturesAt));
        treasury.deployToStrategy(address(strategy), address(weth), 1 ether);
        assertEq(
            treasury.outstandingPrincipal(address(strategy), address(weth)), 1 ether, "deployable at exactly maturesAt"
        );
    }

    /// @dev Raising a cap re-runs the delay. Adding the first unit of risk and
    ///      adding the next one are the same act as far as the guard is concerned.
    function test_ReAdmissionRestartsTheDelay() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 1 ether);

        treasury.admitStrategy(address(strategy), address(weth), CAP * 2, NETTING);
        vm.expectPartialRevert(StrategicTreasury.AdmissionNotMatured.selector);
        treasury.deployToStrategy(address(strategy), address(weth), 1 ether);

        vm.warp(vm.getBlockTimestamp() + treasury.ADMISSION_DELAY());
        treasury.deployToStrategy(address(strategy), address(weth), 1 ether);
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 2 ether, "deployable after re-delay");
    }

    // --- mode immutability ----------------------------------------------------

    function test_ModeCannotChangeWhileAdmitted() public {
        treasury.admitStrategy(address(strategy), address(weth), CAP, CLAIM);

        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.ModeImmutable.selector, address(strategy), CLAIM));
        treasury.admitStrategy(address(strategy), address(weth), CAP, NETTING);

        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.ModeImmutable.selector, address(strategy), CLAIM));
        treasury.admitStrategy(address(strategy), address(otherAsset), CAP, UNITIZED);
    }

    /// @dev The accepted escape is remove + re-admit, which re-runs the delay —
    ///      never an in-place change (sdd.md:L147).
    function test_ModeChangesOnlyViaRemoveAndReAdmitWithANewDelay() public {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        treasury.removeStrategy(address(strategy), false);

        treasury.admitStrategy(address(strategy), address(weth), CAP, UNITIZED);
        (bool active, uint8 mode,) = treasury.admissionOf(address(strategy));
        assertTrue(active, "re-admitted");
        assertEq(uint256(mode), uint256(UNITIZED), "mode changed by remove + re-admit");

        vm.expectPartialRevert(StrategicTreasury.AdmissionNotMatured.selector);
        treasury.deployToStrategy(address(strategy), address(weth), 1 ether);
    }

    /// @dev A stale unit balance cannot be carried into a mode that has no way to
    ///      redeem it — that would strand it outside every guard.
    function test_ModeChangeIsRefusedWhileUnitsAreHeld() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        treasury.deployToStrategy(address(strategy), address(weth), 10 ether);
        assertGt(treasury.unitsHeld(address(strategy)), 0, "units recorded");

        treasury.removeStrategy(address(strategy), false);
        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.ModeImmutable.selector, address(strategy), UNITIZED));
        treasury.admitStrategy(address(strategy), address(weth), CAP, NETTING);
    }

    function test_AnUndefinedModeIsRejected() public {
        vm.expectPartialRevert(StrategicTreasury.ModeImmutable.selector);
        treasury.admitStrategy(address(strategy), address(weth), CAP, 3);
    }

    // --- caps -----------------------------------------------------------------

    function test_TheCapIsTheExactCeiling() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);

        treasury.deployToStrategy(address(strategy), address(weth), CAP);
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), CAP, "exactly the cap is allowed");

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategicTreasury.CapExceeded.selector, address(strategy), address(weth), CAP + 1, CAP
            )
        );
        treasury.deployToStrategy(address(strategy), address(weth), 1);
    }

    /// @dev Caps bound *outstanding* exposure, not lifetime turnover: returning
    ///      principal restores headroom, which is what makes a capped strategy
    ///      usable rather than single-use.
    function test_ReturningPrincipalRestoresCapHeadroom() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), CAP);

        treasury.recallFromStrategy(address(strategy), address(weth), CAP / 2);
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), CAP / 2, "half returned");

        treasury.deployToStrategy(address(strategy), address(weth), CAP / 2);
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), CAP, "headroom restored");
    }

    function test_DeploymentToAnUnadmittedAssetReverts() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        _fundTreasury(address(otherAsset), 10 ether);

        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.StrategyNotAdmitted.selector, address(strategy)));
        treasury.deployToStrategy(address(strategy), address(otherAsset), 1 ether);
    }

    function test_DeploymentToANeverAdmittedStrategyReverts() public {
        MockStrategy stranger = _newStrategy();
        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.StrategyNotAdmitted.selector, address(stranger)));
        treasury.deployToStrategy(address(stranger), address(weth), 1 ether);
    }

    /// @dev A `UNITIZED` strategy may be admitted for a second asset, but nothing
    ///      can be deployed in it: the unit ledger has one denomination, and
    ///      basis released against it must mean one thing.
    function test_UnitizedDeploymentIsConfinedToTheUnitAsset() public {
        _admitMatured(address(strategy), address(weth), CAP, UNITIZED);
        treasury.admitStrategy(address(strategy), address(otherAsset), CAP, UNITIZED);
        vm.warp(vm.getBlockTimestamp() + treasury.ADMISSION_DELAY());
        _fundTreasury(address(otherAsset), 10 ether);

        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.ModeForbidsFlow.selector, address(strategy), UNITIZED));
        treasury.deployToStrategy(address(strategy), address(otherAsset), 1 ether);
    }

    // --- instant, unblockable removal and recall ------------------------------

    function test_RemovalIsInstantAndBlocksFurtherDeployment() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 10 ether);

        vm.expectEmit(true, true, true, true);
        emit StrategicTreasury.StrategyRemoved(address(strategy), true);
        treasury.removeStrategy(address(strategy), true);

        (bool active,,) = treasury.admissionOf(address(strategy));
        assertFalse(active, "inactive in the same transaction: no pending state, no delay");

        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.StrategyNotAdmitted.selector, address(strategy)));
        treasury.deployToStrategy(address(strategy), address(weth), 1 ether);
    }

    /// @dev Recall is deliberately not gated on admission: the whole point of
    ///      instant removal is that the capital can still come home afterwards.
    function test_RecallStillWorksAfterRemoval() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 10 ether);
        treasury.removeStrategy(address(strategy), true);

        uint256 before = weth.balanceOf(address(treasury));
        treasury.recallFromStrategy(address(strategy), address(weth), 10 ether);

        assertEq(weth.balanceOf(address(treasury)) - before, 10 ether, "capital returned after removal");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "booked as principal, not revenue");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "recall of principal credits no revenue");
    }

    /// @dev An active LSG module cannot gate removal or recall. The signal
    ///      surface has no veto because it has no call (UC-10; INV-33).
    function test_AnActiveLsgModuleCannotBlockRemovalOrRecall() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), 10 ether);
        _activateLsg();

        treasury.removeStrategy(address(strategy), true);
        treasury.recallFromStrategy(address(strategy), address(weth), 10 ether);

        (bool active,,) = treasury.admissionOf(address(strategy));
        assertFalse(active, "removed while a module was active");
        assertEq(treasury.outstandingPrincipal(address(strategy), address(weth)), 0, "recalled while a module was active");
    }

    function test_RemovingAnUnadmittedStrategyReverts() public {
        vm.expectRevert(abi.encodeWithSelector(StrategicTreasury.StrategyNotAdmitted.selector, address(strategy)));
        treasury.removeStrategy(address(strategy), false);
    }

    function test_AdmissionRejectsZeroAddresses() public {
        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        treasury.admitStrategy(address(0), address(weth), CAP, NETTING);

        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        treasury.admitStrategy(address(strategy), address(0), CAP, NETTING);
    }

    // --- unauthorized callers (AC-7) ------------------------------------------

    function test_EveryAdmissionMutatorRejectsAnUnauthorizedCaller() public {
        _admitMatured(address(strategy), address(weth), CAP, NETTING);

        vm.startPrank(NON_OPERATOR);

        _expectUnauthorized();
        treasury.admitStrategy(address(strategy), address(weth), CAP, NETTING);

        _expectUnauthorized();
        treasury.removeStrategy(address(strategy), false);

        _expectUnauthorized();
        treasury.deployToStrategy(address(strategy), address(weth), 1 ether);

        _expectUnauthorized();
        treasury.recallFromStrategy(address(strategy), address(weth), 1 ether);

        vm.stopPrank();
    }
}
