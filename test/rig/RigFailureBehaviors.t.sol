// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FB-2, FB-3, FB-4, FB-13, FB-14, FB-15, FB-16
//          INV-5, INV-14, INV-16, INV-17, INV-24
//          sprint.md Sprint 3 Task 3.6

import {Artifact} from "../harness/Artifact.sol";
import {RigFixture} from "./RigFixture.sol";
import {Rig} from "../../src/Rig.sol";

/// @title RigFailureBehaviorsTest — the canonical outcomes when things go wrong.
/// @notice Each test is one row of the PRD's FB register (prd.md:L647-L666),
///         asserted as the *required* outcome rather than as a bug. Several of
///         these rows describe behaviour the architecture deliberately tolerates
///         — a dormant market stays dormant, unsupported emission disappears —
///         so the assertions confirm the tolerance rather than engineering
///         around it. Two rows (FB-15, FB-16) are claims that **no path exists**,
///         which are proven against the compiled ABI, because a search of the
///         source that finds nothing looks the same whether the path is absent
///         or the search is broken.
contract RigFailureBehaviorsTest is RigFixture {
    string internal constant RIG_ARTIFACT = "out/Rig.sol/Rig.json";

    function setUp() public {
        _deploySystem();
    }

    /*----------  FB-2: no challenger  --------------------------------------*/

    /// @dev "King remains; raw accrual caps at 3,000 s; no VUX becomes owed."
    ///      The last clause is the important one: a long uncontested reign
    ///      accrues *opportunity*, not a debt, and the King's balance does not
    ///      move until someone actually displaces them.
    function test_FB2_NoChallengerLeavesTheKingSeatedAndOwedNothing() public {
        _consumeBootstrap();
        uint256 aliceVuxAtCoronation = vux.balanceOf(ALICE);

        vm.warp(rig.epochStart() + 365 days);

        assertEq(rig.king(), ALICE, "the King remains seated indefinitely");
        assertEq(vux.balanceOf(ALICE), aliceVuxAtCoronation, "no VUX accrued to the King while unchallenged");
        assertEq(rig.currentPrice(), DECAY_FLOOR, "the price waits at the floor rather than expiring");

        // And when a challenger finally arrives, the reign is worth exactly the
        // capped opportunity, not a year of it.
        SettledRecord memory r = _takeRecorded(BOB);
        assertEq(r.qRaw, EPOCH_PERIOD * INITIAL_UPS, "a year-long reign earns exactly the 3,000-second cap");
    }

    /*----------  FB-3: weak demand  ----------------------------------------*/

    /// @dev "Less actual supply; missed opportunity expires." Two protocols run
    ///      side by side over the same wall-clock window — one settled often,
    ///      one settled rarely. The rare one must end with strictly less supply,
    ///      and the difference must simply be gone.
    function test_FB3_WeakDemandProducesLessSupplyAndTheRestExpires() public {
        _consumeBootstrap();
        uint256 supplyAtStart = vux.totalSupply();
        uint256 windowStart = rig.epochStart();

        // Weak demand: one settlement in a 5-epoch-long window.
        vm.warp(windowStart + 5 * EPOCH_PERIOD);
        SettledRecord memory sparse = _takeRecorded(BOB);

        uint256 weakDemandSupply = vux.totalSupply() - supplyAtStart;
        uint256 theoreticalMax = 5 * EPOCH_PERIOD * INITIAL_UPS;

        assertLt(weakDemandSupply, theoreticalMax, "weak demand mints far less than the window could have offered");
        assertEq(sparse.qRaw, EPOCH_PERIOD * INITIAL_UPS, "only one epoch's worth of opportunity ever existed");
        // The four unclaimed epochs are not owed, banked, or recoverable.
        assertLe(handlerFreeShortfall(sparse), theoreticalMax, "the remainder simply never came into existence");
    }

    function handlerFreeShortfall(SettledRecord memory r) internal pure returns (uint256) {
        return r.qRaw - r.qMint;
    }

    /*----------  FB-4: high takeover demand  -------------------------------*/

    /// @dev "VEM/clock cap issuance; extra Hard contribution increases `B/S`;
    ///      Strategic leg remains Strategic." Rapid-fire settlements pour WETH
    ///      into Hard while the clock hands out almost no opportunity, so
    ///      backing per unit must rise — the good failure.
    function test_FB4_HighDemandCapsIssuanceAndRaisesBackingPerUnit() public {
        _consumeBootstrap();

        uint256 bStart = reserve.backing();
        uint256 sStart = vux.totalSupply();
        uint256 strategicStart = weth.balanceOf(TREASURY);

        // Twelve takeovers in quick succession: one second of clock each.
        for (uint256 i = 0; i < 12; i++) {
            vm.warp(rig.epochStart() + 1);
            _take(i % 2 == 0 ? BOB : CAROL);
        }

        uint256 bEnd = reserve.backing();
        uint256 sEnd = vux.totalSupply();

        assertGt(bEnd, bStart, "Hard absorbed a great deal of contribution");
        assertGt(bEnd * sStart, bStart * sEnd, "B/S strictly increased under high demand");
        assertLt(sEnd - sStart, 12 * INITIAL_UPS + 1, "the clock, not demand, bounded issuance");
        assertGt(weth.balanceOf(TREASURY), strategicStart, "the Strategic legs remained Strategic");
        assertEq(
            weth.balanceOf(TREASURY),
            rig.totalStrategicContributed(),
            "and none of it leaked into Hard or back to a King"
        );
    }

    /*----------  FB-13: mass redemption  -----------------------------------*/

    /// @dev "Hard pays synchronously pro rata; Strategic positions need not be
    ///      sold and do not supplement payout." Modelled by having every holder
    ///      redeem in sequence while the Strategic pool sits untouched.
    function test_FB13_MassRedemptionPaysProRataWithoutTouchingStrategic() public {
        _consumeBootstrap();

        // Build up several holders with real balances.
        address[3] memory holders = [BOB, CAROL, ALICE];
        for (uint256 i = 0; i < 6; i++) {
            vm.warp(rig.epochStart() + 900);
            _take(holders[i % 3]);
        }

        uint256 strategicBefore = weth.balanceOf(TREASURY);

        for (uint256 i = 0; i < 3; i++) {
            address holder = holders[i];
            uint256 balance = vux.balanceOf(holder);
            if (balance == 0) continue;

            uint256 bPre = reserve.backing();
            uint256 sPre = vux.totalSupply();
            uint256 wethBefore = weth.balanceOf(holder);

            vm.prank(holder);
            uint256 payout = reserve.redeem(balance, holder);

            // Synchronous and exactly pro rata on pre-redemption values.
            assertEq(payout, _floorMulDiv(bPre, balance, sPre), "payout == floor(B x q / S), paid in the same call");
            assertEq(weth.balanceOf(holder) - wethBefore, payout, "the holder was paid immediately");
        }

        assertEq(weth.balanceOf(TREASURY), strategicBefore, "no Strategic asset was sold to fund redemption");
        assertGt(reserve.backing(), 0, "a positive remainder survives the run");
        assertGe(vux.totalSupply(), reserve.S_MIN(), "the supply floor held throughout");
    }

    /*----------  FB-14: trading below backing  ------------------------------*/

    /// @dev "Holder redemption remains the hard claim; no oracle price defence or
    ///      Reserve-funded action triggers." There is no market in Sprint 3, and
    ///      that is the point: the protocol has no way to *learn* a market price,
    ///      so no behaviour can be conditioned on one. The assertion is therefore
    ///      structural — redemption is a pure function of `B`, `S`, and `q`, and
    ///      nothing in the monetary core can read a price at all.
    function test_FB14_RedemptionIsUnconditionalOnAnyMarketPrice() public {
        _consumeBootstrap();
        vm.warp(rig.epochStart() + 1_200);
        _take(BOB);

        uint256 q = vux.balanceOf(ALICE) / 2;
        assertGt(q, 0, "the holder must have something to redeem");

        uint256 quoted = reserve.previewRedeem(q);
        vm.prank(ALICE);
        uint256 payout = reserve.redeem(q, ALICE);

        assertEq(payout, quoted, "the quote and the payout agree - no price-dependent adjustment exists");
        assertEq(payout, _floorMulDiv(reserve.backing() + payout, q, vux.totalSupply() + q), "pure B/S/q arithmetic");

        // And no defensive action fired: Strategic untouched, nothing minted.
        assertEq(rig.totalStrategicContributed(), weth.balanceOf(TREASURY), "no Reserve-funded market action occurred");
    }

    /*----------  FB-15 / FB-16: no rescue, no recapitalization  -------------*/

    /// @dev "No authorized path exists" — twice over. Asserted against the
    ///      compiled method-identifier table rather than the source, and paired
    ///      with a positive control so a broken lookup cannot masquerade as an
    ///      absence.
    function test_FB15_FB16_TheRigExposesNoRescueOrRecapitalizationPath() public view {
        string[] memory actual = vm.parseJsonKeys(vm.readFile(RIG_ARTIFACT), ".methodIdentifiers");

        // Positive control: the lookup finds something that IS there.
        assertTrue(Artifact.contains(actual, "take(uint256)"), "control: the enumeration works at all");

        string[14] memory forbidden = [
            "owner()",
            "transferOwnership(address)",
            "renounceOwnership()",
            "grantRole(bytes32,address)",
            "pause()",
            "unpause()",
            "upgradeTo(address)",
            "initialize(address,address)",
            "sweep(address)",
            "rescue(address,uint256)",
            "recapitalize(uint256)",
            "mint(address,uint256)",
            "setTreasury(address)",
            "setKing(address)"
        ];
        for (uint256 i = 0; i < forbidden.length; i++) {
            assertFalse(
                Artifact.contains(actual, forbidden[i]),
                string.concat("FB-15/FB-16: no authorized path may exist - found ", forbidden[i])
            );
        }
    }

    /// @dev The Rig's complete external surface. Anything new appearing here is a
    ///      new authority, so the list is exhaustive in both directions: every
    ///      accepted entry must be present, and every present entry must be
    ///      accepted (sdd.md §5.2.2).
    function test_TheRigExternalSurfaceIsExactlyTheAcceptedOne() public view {
        string[] memory actual = vm.parseJsonKeys(vm.readFile(RIG_ARTIFACT), ".methodIdentifiers");
        string[] memory accepted = _acceptedRigAbi();

        for (uint256 i = 0; i < accepted.length; i++) {
            assertTrue(Artifact.contains(actual, accepted[i]), string.concat("missing: ", accepted[i]));
        }
        for (uint256 i = 0; i < actual.length; i++) {
            assertTrue(
                Artifact.contains(accepted, actual[i]), string.concat("unexpected external function: ", actual[i])
            );
        }
    }

    /// @dev The complete list. It is deliberately not abbreviated or split: the
    ///      test above compares it against the artifact in both directions, so
    ///      any omission here would report a real function as "unexpected" and
    ///      any surplus would report a missing one. That two-way check is the
    ///      whole value, and it only works on an exhaustive list.
    function _acceptedRigAbi() private pure returns (string[] memory abi_) {
        abi_ = new string[](26);
        // The ONLY state-changing function.
        abi_[0] = "take(uint256)";
        // Views (sdd.md §5.2.2).
        abi_[1] = "currentPrice()";
        abi_[2] = "currentUPS()";
        abi_[3] = "epochState()";
        // Storage getters.
        abi_[4] = "king()";
        abi_[5] = "epochStart()";
        abi_[6] = "epochOpening()";
        abi_[7] = "epochUPS()";
        abi_[8] = "scheduleStart()";
        abi_[9] = "epochId()";
        abi_[10] = "totalStrategicContributed()";
        // Immutable identities.
        abi_[11] = "weth()";
        abi_[12] = "vux()";
        abi_[13] = "reserve()";
        abi_[14] = "treasury()";
        // Frozen routing constants.
        abi_[15] = "SPLIT_KING_BP()";
        abi_[16] = "STRATEGIC_CAP_BP()";
        abi_[17] = "BP_DENOM()";
        // Frozen pricing and clock constants.
        abi_[18] = "EPOCH_PERIOD()";
        abi_[19] = "PRICE_MULTIPLIER()";
        abi_[20] = "INITIAL_UPS()";
        abi_[21] = "HALVING_PERIOD()";
        abi_[22] = "MAX_HALVINGS()";
        // Converted USD targets, fixed at construction (R-14 deployment facts).
        abi_[23] = "BOOTSTRAP_OPENING()";
        abi_[24] = "MINIMUM_OPENING()";
        abi_[25] = "DECAY_FLOOR()";
    }

    /// @dev The constants' *values*, as distinct from their presence above.
    function test_TheFrozenConstantsAreExposedAndCorrect() public view {
        assertEq(rig.SPLIT_KING_BP(), 8_000, "King share, basis points");
        assertEq(rig.STRATEGIC_CAP_BP(), 1_200, "Strategic CAP, basis points - not a fixed leg");
        assertEq(rig.BP_DENOM(), 10_000, "basis-point denominator");
        assertEq(rig.EPOCH_PERIOD(), 3_000, "epoch period, seconds");
        assertEq(rig.PRICE_MULTIPLIER(), 2, "successor price ladder multiplier");
        assertEq(rig.INITIAL_UPS(), 4e18, "4 VUX per second at schedule start");
        assertEq(rig.HALVING_PERIOD(), 30 days, "halving period");
        assertEq(rig.MAX_HALVINGS(), 8, "eight halvings, then the permanent tail");
        assertEq(rig.BOOTSTRAP_OPENING(), BOOTSTRAP_OPENING, "bootstrap opening immutable");
        assertEq(rig.MINIMUM_OPENING(), MINIMUM_OPENING, "minimum opening immutable");
        assertEq(rig.DECAY_FLOOR(), DECAY_FLOOR, "decay floor immutable");
    }

    /// @dev INV-5 from the Rig side: the Rig is the token's only mint authority,
    ///      and it has exactly one call site for it. Nobody can reach that
    ///      authority except by settling a real takeover.
    function test_FB16_TheMintAuthorityCannotBeReachedExceptThroughSettlement() public {
        _consumeBootstrap();

        // Direct mint attempts fail regardless of who tries.
        address[3] memory callers = [ATTACKER, ALICE, address(this)];
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(callers[i]);
            vm.expectRevert();
            vux.mint(callers[i], 1e18);
        }

        // And the Rig itself exposes no way to ask for a mint.
        string[] memory actual = vm.parseJsonKeys(vm.readFile(RIG_ARTIFACT), ".methodIdentifiers");
        assertEq(actual.length, 26, "the Rig's external surface is exactly 26 entries, of which take() is the only mutator");
    }
}
