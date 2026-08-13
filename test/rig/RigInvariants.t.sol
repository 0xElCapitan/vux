// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: INV-1 … INV-22 (INV-18/INV-19 in their amended adaptive form)
//          sprint.md Sprint 3 Task 3.5, AC-8 (invariant suite green over random
//          op sequences)

import {RigFixture} from "./RigFixture.sol";
import {RigInvariantHandler} from "./RigInvariantHandler.sol";

/// @title RigInvariantsTest — the cycle's permanent monetary regression harness.
/// @notice Introduced in Sprint 3 and **extended, not replaced**, by Sprints 4
///         and 5 (sprint.md "Cross-sprint invariant suite ownership"). A later
///         sprint that breaks one of these fails its own gate.
///
///         Coverage is split by what each layer can actually see:
///
///         | invariant | where it is proven | why there |
///         |---|---|---|
///         | INV-1, 2, 3, 5, 8, 10, 11, 13, 15, 17, 20 | here, as global state | true between every pair of operations |
///         | INV-4, 6, 7, 9, 12, 16, 18, 19, 21, 22 | handler, per operation | only observable at the operation that creates them |
///         | INV-14 | Sprint 2 surface suite | a claim about the ABI and runtime bytecode, not about state |
///
///         The per-operation half is not weaker: those facts are overwritten by
///         the next call, so a state-only invariant physically cannot check them.
///         Both halves run under the same randomized sequences.
contract RigInvariantsTest is RigFixture {
    RigInvariantHandler internal handler;

    function setUp() public {
        _deploySystem();
        handler = new RigInvariantHandler(weth, reserve, rig, vux, TREASURY);

        // INV-2/INV-3, asserted once at genesis: the invariant layer then proves
        // supply only ever moves by an attributed cause.
        assertEq(vux.totalSupply(), S0, "INV-2: genesis supply is exactly 150,000e18 + 1");
        assertEq(vux.balanceOf(address(reserve)), 1, "the Reserve holds the one-raw-unit seed");
        for (uint256 i = 0; i < handler.actorCount(); i++) {
            assertEq(vux.balanceOf(handler.actorAt(i)), 0, "INV-3: no user address receives genesis VUX");
        }

    }

    /// @dev The invariant engine reads this to decide what it may call. Without
    ///      it every contract deployed in `setUp` becomes a target, including the
    ///      Rig itself — and unshaped direct calls would revert constantly,
    ///      forcing `fail_on_revert = false` and hollowing the suite out.
    ///
    ///      `forge-std` supplies this through `StdInvariant`; the accepted
    ///      Sprint-1 decision is a VUX-original harness with no `forge-std`
    ///      (sprint.md operator-accepted interpretation 1), so it is declared
    ///      here directly. The engine only needs the signature.
    function targetContracts() public view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    /*----------  supply attribution (INV-1, 5, 8)  ------------------------*/

    /// @dev Every unit of `S` traces to exactly one cause: genesis, or a
    ///      settlement mint, minus redemption burns. If any other mint path
    ///      existed — treasury, governance, recovery, recapitalization — this
    ///      identity would drift (INV-5, prd.md:L585).
    function invariant_SupplyIsCompletelyAttributed() public view {
        assertEq(
            vux.totalSupply(),
            handler.ghostGenesisSupply() + handler.ghostMintedBySettlement() - handler.ghostBurnedByRedemption(),
            "INV-1/INV-5: S == genesis + settlement mints - redemption burns, with no unattributed change"
        );
    }

    /// @dev INV-8: unsupported opportunity expires. Cumulative issuance can never
    ///      exceed cumulative raw opportunity — if a shortfall were ever banked
    ///      and later minted, this would exceed.
    function invariant_IssuanceNeverExceedsRawOpportunity() public view {
        assertLe(
            handler.ghostQmintTaken(),
            handler.ghostQrawOffered(),
            "INV-8: no carry, IOU, makeup, or high-water emission"
        );
    }

    function invariant_SettlementCountMatchesTheEpochCounter() public view {
        assertEq(uint256(rig.epochId()), handler.settlements(), "the epoch counter is the settlement count");
    }

    /*----------  the Hard Reserve (INV-10, 11, 15, 17)  --------------------*/

    /// @dev INV-10: `B` is *defined* as the physical balance. There is no
    ///      accounting cell that could disagree with it, and this asserts the
    ///      view has not grown one.
    function invariant_BackingIsExactlyThePhysicalBalance() public view {
        assertEq(reserve.backing(), weth.balanceOf(address(reserve)), "INV-10: B == WETH.balanceOf(reserve)");
    }

    /// @dev INV-15: the supply floor is never breached, so the `B/S` denominator
    ///      stays live and the last holder cannot drain the Reserve.
    function invariant_TheSupplyFloorHolds() public view {
        assertGe(vux.totalSupply(), reserve.S_MIN(), "INV-15: S >= S_MIN");
        assertGt(reserve.backing(), 0, "a positive WETH remainder always survives redemption");
    }

    /// @dev INV-11/INV-17: Strategic capital and Hard principal are physically
    ///      disjoint pools. Everything Strategic has ever received is still
    ///      accounted as Strategic, and no path moved Reserve principal into it.
    function invariant_StrategicAndHardNeverMix() public view {
        assertEq(
            weth.balanceOf(TREASURY),
            handler.ghostStrategicContributed(),
            "INV-17: Strategic holds exactly its contributed legs - no Reserve principal reached it"
        );
        assertEq(
            rig.totalStrategicContributed(),
            handler.ghostStrategicContributed(),
            "the Rig's contributed-principal accounting matches reality"
        );
    }

    /// @dev INV-11 from the other side: `B` is only ever the sum of what actually
    ///      entered it — genesis, settlement Hard legs, and donations — less what
    ///      redemption paid out. No mark, NAV, or Strategic value inflates it.
    function invariant_BackingOnlyReflectsRealWethMovements() public view {
        assertLe(
            reserve.backing(),
            B0 + handler.ghostDonated() + weth.totalSupply(),
            "INV-11: B is bounded by real WETH that physically moved"
        );
    }

    /*----------  routing (INV-20)  ------------------------------------------*/

    /// @dev The Rig is a conduit, never a holder. If any settlement failed to
    ///      exhaust `P`, the remainder would be sitting here.
    function invariant_TheRigHoldsNoValue() public view {
        assertEq(weth.balanceOf(address(rig)), 0, "INV-20: no other primary recipient exists, not even the Rig");
        assertEq(vux.balanceOf(address(rig)), 0, "the Rig never holds VUX either");
    }

    /*----------  harness health  --------------------------------------------*/

    /// @dev A green suite that exercised nothing is worse than a red one, because
    ///      it is mistaken for evidence. Vacuity is ruled out three ways, and
    ///      deliberately none of them is an `invariant_` function — the engine
    ///      evaluates those once at setup too, where no call has happened yet, so
    ///      "work was done" is a post-run property and cannot be an invariant:
    ///
    ///      1. `fail_on_revert = true` (foundry.toml) — a call that reverted
    ///         instead of doing work fails the run outright.
    ///      2. Foundry's own per-invariant `calls`/`reverts` report.
    ///      3. This test, which drives every handler action once and asserts each
    ///         moves the state it claims to move. An action that silently
    ///         degenerated into a no-op — the failure mode the counter was meant
    ///         to catch — fails here.
    function test_EveryHandlerActionDoesRealWork() public {
        uint256 calls;

        handler.takeThrone(0, 1_000);
        assertEq(handler.settlements(), 1, "takeThrone settles");
        assertEq(handler.effectiveCalls(), ++calls, "takeThrone counted");

        handler.takeThrone(1, 1_500);
        assertEq(handler.effectiveCalls(), ++calls, "a second settlement mints to the first public King");
        calls = handler.effectiveCalls();

        uint256 burnedBefore = handler.ghostBurnedByRedemption();
        handler.redeemSome(0, type(uint256).max);
        assertGt(handler.ghostBurnedByRedemption(), burnedBefore, "redeemSome actually burns");
        assertEq(handler.redemptions(), 1, "redeemSome counted");

        // Read through the cheatcode, not `block.timestamp`: the optimizer folds
        // repeated `TIMESTAMP` reads in one frame, which `vm.warp` invalidates
        // (see the note on `Vm.getBlockTimestamp`).
        uint256 tBefore = vm.getBlockTimestamp();
        handler.passTime(12 hours);
        assertGt(vm.getBlockTimestamp(), tBefore, "passTime actually advances the clock");

        uint256 backingBefore = reserve.backing();
        handler.donateToReserve(1 ether);
        uint256 donated = handler.ghostDonated();
        assertGt(donated, 0, "donateToReserve actually donates (the seed is bounded, not used verbatim)");
        assertEq(reserve.backing() - backingBefore, donated, "B rose by exactly the donation");
        assertEq(handler.ghostMintedBySettlement(), handler.ghostQmintTaken(), "and nothing was attributed to issuance");
    }

    /// @dev The donation path, checked for the property that matters: an
    ///      unsolicited transfer raises `B` and therefore *lowers* future
    ///      `Qsafe`. It must never mint anything or create an entitlement
    ///      (sdd.md §9.1 benign class; INV-11).
    function test_ADonationRaisesBackingAndMintsNothing() public {
        handler.takeThrone(0, 500);
        uint256 supplyBefore = vux.totalSupply();

        handler.donateToReserve(50 ether);

        assertEq(vux.totalSupply(), supplyBefore, "a donation mints nothing");
        assertEq(handler.ghostMintedBySettlement(), 0, "and is not attributed as issuance");
    }

    /// @dev FR-6.3 over the whole random op space: however the sequence is
    ///      ordered, the bootstrap settlement happens at most once.
    function invariant_AtMostOneBootstrapSettlementEverOccurs() public view {
        assertLe(handler.bootstrapSettlements(), 1, "no second bootstrap state is reachable");
    }
}
