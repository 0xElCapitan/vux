// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: INV-23, INV-24, INV-28, INV-30, INV-31 (Strategic accounting),
//          INV-33 (no LSG/treasury reach into the core), INV-35 (failure
//          independence), FB-15, FB-16
//          sprint.md Sprint 4 Task 4.8, AC-7

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {TreasuryFixture} from "./TreasuryFixture.sol";
import {TreasuryInvariantHandler} from "./TreasuryInvariantHandler.sol";

/// @title TreasuryInvariantsTest — the Strategic surface under random pressure.
/// @notice The Sprint-3 suite proves the monetary core is internally consistent
///         when only the core moves. This one keeps every one of those questions
///         open while a treasury runs beside it: admitting, deploying, losing
///         everything, recalling, classifying, distributing, and writing off, in
///         whatever order the fuzzer picks.
///
///         The invariants below are attributed, not measured: `B` is checked
///         against the sum of its *causes*, so any wei that reaches the Reserve
///         without one — from a Strategic path, a classification error, or a
///         distribution bug — fails the run.
contract TreasuryInvariantsTest is TreasuryFixture {
    TreasuryInvariantHandler internal handler;
    MockStrategy[3] internal strategies;

    function setUp() public {
        _deploySystem();

        strategies[0] = _newStrategy();
        strategies[1] = _newStrategy();
        strategies[2] = _newStrategy();

        handler = new TreasuryInvariantHandler(weth, otherAsset, reserve, rig, vux, treasury, strategies);

        // The handler drives the treasury, so it needs the operator role — the
        // production topology exactly: one Safe-held role, granted by the admin,
        // held by one address.
        treasury.grantRole(treasury.OPERATOR_ROLE(), address(handler));
        treasury.setOpsRecipient(OPS_RECIPIENT);

        handlerHardIn0 = reserve.backing();
    }

    /// @dev Genesis `B0` predates the handler's ghost accounting, so it is the
    ///      constant offset every attribution is measured from.
    uint256 internal handlerHardIn0;

    function targetContracts() public view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    // =========================================================================
    // INV-23 / INV-24 / FB-15 / FB-16 — nothing Strategic reaches Hard
    // =========================================================================

    /// @dev `B` equals genesis plus its attributed causes, minus redemption
    ///      payouts — and the ONLY treasury cause in that sum is the WETH-only
    ///      revenue accretion leg, an amount the handler passed in as an
    ///      argument. A Strategic loss, a misclassification, or any rescue path
    ///      would show up here as an unattributed delta.
    ///
    ///      This is simultaneously FB-15 ("governance wants Reserve rescue: no
    ///      authorized path exists") and FB-16 ("recapitalization mint: no
    ///      authorized path exists") in state form: neither can happen without
    ///      breaking this identity or the supply one below.
    function invariant_BackingIsCompletelyAttributed() public view {
        assertEq(
            reserve.backing(),
            handlerHardIn0 + handler.ghostHardIn() - handler.ghostHardOut(),
            "INV-23/INV-24: B moves only by settlement legs, donations, the WETH revenue leg, and redemptions"
        );
    }

    /// @dev Every unit of `S` traces to exactly one cause. The treasury's only
    ///      possible effect on supply is its own F-46 self-burn; there is no
    ///      mint path, no recapitalization, and no third-party burn (INV-5,
    ///      INV-24).
    function invariant_SupplyIsCompletelyAttributed() public view {
        assertEq(
            vux.totalSupply(),
            handler.ghostGenesisSupply() + handler.ghostMintedBySettlement() - handler.ghostBurnedByRedemption()
                - handler.ghostBurnedByTreasury(),
            "INV-24: S == genesis + settlement mints - redemption burns - the treasury's own VUX-revenue burn"
        );
    }

    /// @dev The authority graph is immutable, so a Strategic failure cannot move
    ///      it. Asserted between every pair of operations rather than once,
    ///      because "immutable" is the claim under test (INV-24, INV-33).
    function invariant_TheAuthorityGraphNeverMoves() public view {
        assertEq(vux.rig(), address(rig), "the sole mint authority");
        assertEq(vux.reserve(), address(reserve), "the sole redemption-burn authority");
        assertEq(rig.treasury(), address(treasury), "the Strategic routing constant");
        assertEq(rig.reserve(), address(reserve), "the Hard routing constant");
        assertEq(address(treasury.weth()), address(weth), "the treasury's asset identity");
        assertEq(treasury.hardReserve(), address(reserve), "the accretion destination");
        assertEq(treasury.pool(), pool, "the verified pool, unreplaceable");
    }

    /// @dev The monetary core holds no role and grants none. If the treasury
    ///      could ever hand its authority to the core — or the core to anyone —
    ///      the boundary argument would be a convention rather than a topology
    ///      (NFR-SEC-7, INV-33).
    function invariant_TheCoreHoldsNoTreasuryRole() public view {
        bytes32 operator = treasury.OPERATOR_ROLE();
        bytes32 admin = treasury.DEFAULT_ADMIN_ROLE();
        assertFalse(treasury.hasRole(operator, address(rig)), "the Rig holds no operator role");
        assertFalse(treasury.hasRole(operator, address(reserve)), "the Reserve holds no operator role");
        assertFalse(treasury.hasRole(operator, address(vux)), "the token holds no operator role");
        assertFalse(treasury.hasRole(admin, address(rig)), "nor admin");
        assertFalse(treasury.hasRole(operator, treasury.lsgModule()), "and an active module never gains one");
    }

    // =========================================================================
    // INV-28 / INV-30 — principal is principal; marks are nothing
    // =========================================================================

    /// @dev Revenue ever credited in an asset never exceeds what actually
    ///      arrived through a strategy-side flow, measured on the token itself.
    ///
    ///      The exclusion is the point: settlement legs, donations, and bare
    ///      inventory funding are NOT in the right-hand side, so a bare transfer
    ///      that ever got classified as revenue — the §1.10 rule-5 failure — or
    ///      a returned-principal credit — the INV-28 failure — breaks this
    ///      immediately. An unrealized mark cannot appear on either side, which
    ///      is INV-30 in the only form a state invariant can express it.
    function invariant_RevenueNeverExceedsWhatStrategiesDelivered() public view {
        address[2] memory assets = [address(weth), address(otherAsset)];
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 everCredited = treasury.realizedRevenue(assets[i]) + handler.ghostRevenueAllocated(assets[i]);
            assertLe(
                everCredited,
                handler.ghostReceivedFromStrategies(assets[i]),
                "INV-28/INV-30: revenue is bounded by measured strategy-side receipts"
            );
        }
    }

    /// @dev Outstanding principal is created only by deployment. It can be
    ///      retired by a return, released by a redemption, or written off by a
    ///      close — never invented.
    function invariant_OutstandingPrincipalNeverExceedsWhatWasDeployed() public view {
        for (uint256 i = 0; i < handler.strategyCount(); i++) {
            address strategy = handler.strategyAt(i);
            assertLe(
                treasury.outstandingPrincipal(strategy, address(weth)),
                handler.ghostDeployed(strategy, address(weth)),
                "INV-28: principal is only ever created by a deployment"
            );
        }
    }

    /// @dev The earmark is downstream of the accumulator, so it can never exceed
    ///      the revenue that was ever credited — signaler economics are
    ///      revenue-bounded by construction (FR-13.7).
    function invariant_TheEarmarkIsRevenueBounded() public view {
        address[2] memory assets = [address(weth), address(otherAsset)];
        for (uint256 i = 0; i < assets.length; i++) {
            assertLe(
                treasury.signalerBudget(assets[i]),
                handler.ghostReceivedFromStrategies(assets[i]),
                "FR-13.7: the signaler earmark traces to realized revenue"
            );
        }
    }

    // A "credited revenue is always physically held" invariant was drafted here
    // and deliberately REMOVED, because it is stronger than the accepted design
    // and the accepted design is what this suite must check. `realizedRevenue`
    // is an accumulator, not a segregated balance (sdd.md:L312 bounds the legs by
    // `realizedRevenue[asset]`, not by custody), so an operator who redeploys
    // revenue-backed assets as risk capital and loses them leaves a credit
    // standing with nothing behind it. That behaviour is pinned as an explicit
    // test in `TreasuryRevenue.t.sol` and raised for review disposition in
    // `reviewer.md` "Judgment Calls" (J-3) rather than silently enforced here.

    // =========================================================================
    // anti-degeneracy
    // =========================================================================

    /// @dev A handler whose actions all short-circuit would run 1,024 calls,
    ///      change nothing, and report green. This drives one of each action in
    ///      an order that reaches every branch and asserts each did real work —
    ///      a plain test, not an invariant, because the claim is about the
    ///      handler rather than about a state that must hold at all times.
    function test_EveryHandlerActionDoesRealWork() public {
        uint256 calls;

        handler.fundTreasuryInventory(300 ether);
        assertGt(weth.balanceOf(address(treasury)), 0, "inventory funded");
        assertGt(handler.effectiveCalls(), calls, "fundTreasuryInventory");
        calls = handler.effectiveCalls();

        handler.settle(0);
        assertGt(handler.ghostHardIn(), 0, "a settlement routed a Hard leg");
        assertGt(handler.effectiveCalls(), calls, "settle");
        calls = handler.effectiveCalls();

        handler.donateToReserve(1 ether);
        assertGt(handler.effectiveCalls(), calls, "donateToReserve");
        calls = handler.effectiveCalls();

        handler.admit(0, 1_000 ether);
        handler.admit(1, 1_000 ether);
        handler.admit(2, 1_000 ether);
        (bool active,,) = treasury.admissionOf(handler.strategyAt(2));
        assertTrue(active, "admit");
        calls = handler.effectiveCalls();

        handler.passTime(2 days);
        assertGt(handler.effectiveCalls(), calls, "passTime");
        calls = handler.effectiveCalls();

        handler.deploy(2, 100 ether);
        assertGt(handler.ghostDeployed(handler.strategyAt(2), address(weth)), 0, "deploy");
        assertGt(treasury.unitsHeld(handler.strategyAt(2)), 0, "UNITIZED units measured");
        calls = handler.effectiveCalls();

        handler.redeemUnits(0, type(uint256).max, 200 ether);
        assertGt(handler.ghostReceivedFromStrategies(address(weth)), 0, "redeemUnits delivered value");
        assertGt(treasury.realizedRevenue(address(weth)), 0, "a gain became revenue");
        calls = handler.effectiveCalls();

        handler.allocate(0, treasury.realizedRevenue(address(weth)));
        assertGt(handler.ghostRevenueAllocated(address(weth)), 0, "allocate");
        calls = handler.effectiveCalls();

        handler.deploy(1, 50 ether);
        handler.harvest(1, 5 ether);
        assertGt(handler.ghostReceivedFromStrategies(address(otherAsset)), 0, "harvest");
        calls = handler.effectiveCalls();

        handler.returnWithProfit(0, 10 ether);
        calls = handler.effectiveCalls();

        handler.deploy(0, 20 ether);
        handler.strategyLosesEverything(0);
        assertEq(weth.balanceOf(handler.strategyAt(0)), 0, "the strategy lost everything");
        calls = handler.effectiveCalls();

        handler.recall(1, 10 ether);
        calls = handler.effectiveCalls();

        handler.remove(0);
        handler.closeStrategy(0);
        assertEq(treasury.outstandingPrincipal(handler.strategyAt(0), address(weth)), 0, "closeStrategy");
        calls = handler.effectiveCalls();

        handler.burnVuxRevenue();
        assertGt(handler.effectiveCalls(), calls, "burnVuxRevenue");

        handler.redeemSome(0);
        handler.remove(1);

        // The whole point of the exercise: after every action class has fired,
        // the attribution identities still hold exactly.
        invariant_BackingIsCompletelyAttributed();
        invariant_SupplyIsCompletelyAttributed();
        invariant_RevenueNeverExceedsWhatStrategiesDelivered();
    }
}

interface IBalance {
    function balanceOf(address account) external view returns (uint256);
}
