// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-4.2, FR-4.5, FR-4.6, FR-2.1, FR-2.6, INV-4, INV-20, INV-21
//          sprint.md Sprint 3 AC-6 (partial-failure injection, INV-21)

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {RigFixture} from "./RigFixture.sol";
import {Rig} from "../../src/Rig.sol";

/// @title RigSettlementTest — the 13-step outcome, and its all-or-nothing edge.
/// @notice Two things are being proven here. First, that an ordinary settlement
///         lands every leg exactly where the law says and leaves the successor
///         epoch in the specified state. Second — and this is the part that
///         matters most — that there is no way to reach a state where *some*
///         legs routed and others did not. The second is proven by failing each
///         leg in turn and asserting the entire world is unchanged, including
///         the last leg to run, where the most state has already been written.
contract RigSettlementTest is RigFixture {
    function setUp() public {
        _deploySystem();
    }

    /*----------  the ordinary outcome  ------------------------------------*/

    function test_OrdinarySettlementRoutesEveryLegExactly() public {
        _consumeBootstrap();
        vm.warp(rig.epochStart() + 1_200);

        uint256 bPre = reserve.backing();
        uint256 sPre = vux.totalSupply();
        uint256 treasuryPre = weth.balanceOf(TREASURY);
        uint256 kingPre = weth.balanceOf(ALICE);
        uint256 price = rig.currentPrice();
        uint256 qRaw = 1_200 * rig.epochUPS();

        (uint256 expKing, uint256 expHard, uint256 expStrategic) = _expectedLegs(price, qRaw, bPre, sPre);

        SettledRecord memory r = _takeRecorded(BOB);

        assertEq(r.price, price, "P is the Dutch price at settlement time");
        assertEq(r.kingLeg, expKing, "king leg");
        assertEq(r.reserveLeg, expHard, "Hard leg == hardTarget");
        assertEq(r.strategicLeg, expStrategic, "Strategic residual");
        assertEq(r.kingLeg + r.reserveLeg + r.strategicLeg, price, "the three legs exhaust P");

        assertEq(reserve.backing() - bPre, expHard, "Hard physically received hardTarget");
        assertEq(weth.balanceOf(TREASURY) - treasuryPre, expStrategic, "Strategic physically received the residual");
        assertEq(weth.balanceOf(ALICE) - kingPre, expKing, "the OUTGOING King received the recycle");
        assertEq(weth.balanceOf(address(rig)), 0, "the Rig kept nothing (INV-20)");
    }

    function test_TheMintGoesToTheOutgoingKingNotTheSuccessor() public {
        _consumeBootstrap();
        vm.warp(rig.epochStart() + 1_500);

        uint256 aliceBefore = vux.balanceOf(ALICE);
        uint256 bobBefore = vux.balanceOf(BOB);

        SettledRecord memory r = _takeRecorded(BOB);

        assertGt(r.qMint, 0, "this settlement must actually mint something");
        assertEq(r.outgoingKing, ALICE, "the record names the outgoing King");
        assertEq(vux.balanceOf(ALICE) - aliceBefore, r.qMint, "the outgoing King received exactly Qmint");
        assertEq(vux.balanceOf(BOB), bobBefore, "the incoming King received nothing");
    }

    function test_SuccessorEpochStateIsEstablished() public {
        _consumeBootstrap();
        uint256 epochIdBefore = rig.epochId();
        vm.warp(rig.epochStart() + 900);

        uint256 price = rig.currentPrice();
        uint256 expectedUps = rig.currentUPS();
        _take(BOB);

        assertEq(rig.king(), BOB, "the payer is the new King");
        assertEq(uint256(rig.epochStart()), block.timestamp, "the successor epoch opens now");
        assertEq(uint256(rig.epochOpening()), price * 2, "opening == max(MINIMUM_OPENING, 2P)");
        assertEq(rig.epochUPS(), expectedUps, "the successor snapshots the schedule rate");
        assertEq(uint256(rig.epochId()), epochIdBefore + 1, "the settlement counter advanced by one");
    }

    function test_StrategicAccountingAccumulatesAcrossSettlements() public {
        _consumeBootstrap();
        uint256 running = rig.totalStrategicContributed();

        for (uint256 i = 0; i < 3; i++) {
            vm.warp(rig.epochStart() + 400);
            SettledRecord memory r = _takeRecorded(BOB);
            running += r.strategicLeg;
            assertEq(rig.totalStrategicContributed(), running, "cumulative contributed principal tracks the legs");
        }
        assertEq(weth.balanceOf(TREASURY), running, "and equals what Strategic physically holds");
    }

    /// @dev A zero-valued Strategic leg is skipped rather than transferred, so no
    ///      misleading `Transfer` log implies a contribution that did not happen
    ///      (sdd.md:L215). Regime 3 produces the zero.
    function test_AZeroStrategicLegEmitsNoTransfer() public {
        _consumeBootstrap();

        // A full-length reign at full UPS against modest backing drives
        // `D_need` past `retained`, so the residual is zero.
        vm.warp(rig.epochStart() + EPOCH_PERIOD);
        uint256 treasuryPre = weth.balanceOf(TREASURY);
        // Nonzero: the bootstrap settlement routed its floored 12% cap.
        uint256 contributedPre = rig.totalStrategicContributed();

        SettledRecord memory r = _takeRecorded(BOB);

        assertEq(r.strategicLeg, 0, "this scenario must actually produce a zero residual");
        assertEq(weth.balanceOf(TREASURY), treasuryPre, "Strategic received nothing");
        assertEq(rig.totalStrategicContributed(), contributedPre, "and nothing was booked as contributed");
    }

    /*----------  slippage (FR-2, contender protection)  -------------------*/

    function test_MaxPriceRejectsAnythingAboveIt() public {
        _consumeBootstrap();
        uint256 price = rig.currentPrice();
        _fund(BOB, price);

        vm.expectRevert(abi.encodeWithSelector(Rig.PriceAboveMax.selector, price, price - 1));
        vm.prank(BOB);
        rig.take(price - 1);
    }

    function test_MaxPriceExactlyAtThePriceIsAccepted() public {
        _consumeBootstrap();
        uint256 price = rig.currentPrice();
        _fund(BOB, price);

        vm.prank(BOB);
        rig.take(price);
        assertEq(rig.king(), BOB, "paying exactly the limit succeeds");
    }

    /// @dev The realistic slippage risk is a *rise*: a competing takeover in the
    ///      same block re-opens the epoch at `2P`, so the next contender faces a
    ///      higher price than the one they quoted.
    function test_MaxPriceProtectsAgainstASameBlockLadderRise() public {
        _consumeBootstrap();
        vm.warp(rig.epochStart() + 1_000);

        uint256 quoted = rig.currentPrice();
        _fund(BOB, quoted * 4);
        _fund(CAROL, quoted * 4);

        // CAROL front-runs, doubling the opening in the same block.
        vm.prank(CAROL);
        rig.take(type(uint256).max);
        assertGt(rig.currentPrice(), quoted, "the ladder raised the price within the block");

        vm.expectPartialRevert(Rig.PriceAboveMax.selector);
        vm.prank(BOB);
        rig.take(quoted);
    }

    /*----------  payment collection (FR-2.1)  ------------------------------*/

    function test_SettlementFailsWhenThePayerCannotPay() public {
        _consumeBootstrap();
        uint256 price = rig.currentPrice();

        // Approved, but unfunded.
        vm.prank(ATTACKER);
        weth.approve(address(rig), type(uint256).max);

        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        vm.prank(ATTACKER);
        rig.take(type(uint256).max);

        assertEq(rig.king(), ALICE, "the throne did not change hands");
        assertNotEq(price, 0, "sanity: the price was nonzero");
    }

    function test_SettlementFailsWithoutAllowance() public {
        _consumeBootstrap();
        weth.mint(ATTACKER, 100 ether); // funded, but no approval

        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientAllowance.selector);
        vm.prank(ATTACKER);
        rig.take(type(uint256).max);

        assertEq(rig.king(), ALICE, "the throne did not change hands");
    }

    /*----------  partial-failure injection (FR-4 acceptance)  -------------*/

    /// @dev Each leg is failed in turn and the complete world state is compared
    ///      against a pre-image. The King leg is the important row: it runs
    ///      *after* the successor epoch has been written and after the mint, so
    ///      if any settlement could half-commit, that is where it would show.
    function test_FailingAnyOneLegUnwindsTheWholeSettlement() public {
        _consumeBootstrap();

        address[3] memory legTargets = [TREASURY, address(reserve), ALICE];
        string[3] memory legNames = ["Strategic leg", "Hard leg", "King leg"];

        for (uint256 i = 0; i < 3; i++) {
            uint256 snapshotKing = uint160(rig.king());
            uint256 snapshotEpoch = rig.epochId();
            uint256 snapshotBacking = reserve.backing();
            uint256 snapshotSupply = vux.totalSupply();
            uint256 snapshotTreasury = weth.balanceOf(TREASURY);
            uint256 snapshotContributed = rig.totalStrategicContributed();
            uint256 snapshotOutgoingVux = vux.balanceOf(ALICE);

            vm.warp(rig.epochStart() + 800);
            _fund(BOB, rig.currentPrice());

            weth.setFailTransfersTo(legTargets[i]);
            vm.expectRevert();
            vm.prank(BOB);
            rig.take(type(uint256).max);
            weth.setFailTransfersTo(address(0));

            assertEq(uint160(rig.king()), snapshotKing, string.concat(legNames[i], ": throne unchanged"));
            assertEq(uint256(rig.epochId()), snapshotEpoch, string.concat(legNames[i], ": epoch counter unchanged"));
            assertEq(reserve.backing(), snapshotBacking, string.concat(legNames[i], ": Hard backing unchanged"));
            assertEq(vux.totalSupply(), snapshotSupply, string.concat(legNames[i], ": nothing minted"));
            assertEq(weth.balanceOf(TREASURY), snapshotTreasury, string.concat(legNames[i], ": Strategic unchanged"));
            assertEq(
                rig.totalStrategicContributed(),
                snapshotContributed,
                string.concat(legNames[i], ": Strategic accounting unchanged")
            );
            assertEq(
                vux.balanceOf(ALICE), snapshotOutgoingVux, string.concat(legNames[i], ": outgoing King got no mint")
            );
        }
    }

    /// @dev A failing mint must take the settlement down too. The mint is gated
    ///      to the immutable `rig`, so the only way to make it fail is to point a
    ///      Rig at a token that will not accept it — which is exactly what a
    ///      mis-wired deployment would look like.
    function test_AFailingMintUnwindsTheSettlement() public {
        // This Rig is not the token's `rig`, so `VUX.mint` reverts `NotRig`.
        Rig strangerRig =
            new Rig(address(weth), address(reserve), address(vux), TREASURY, BOOTSTRAP_OPENING, MINIMUM_OPENING, DECAY_FLOOR);

        // Consume its bootstrap (mints zero, so it succeeds), then settle an
        // ordinary epoch, which must mint and therefore must fail.
        uint256 price = strangerRig.currentPrice();
        weth.mint(ALICE, price * 8);
        vm.prank(ALICE);
        weth.approve(address(strangerRig), type(uint256).max);
        vm.prank(ALICE);
        strangerRig.take(type(uint256).max);

        vm.warp(strangerRig.epochStart() + 1_000);
        uint256 backingBefore = reserve.backing();
        weth.mint(BOB, strangerRig.currentPrice() * 4);
        vm.prank(BOB);
        weth.approve(address(strangerRig), type(uint256).max);

        vm.expectRevert();
        vm.prank(BOB);
        strangerRig.take(type(uint256).max);

        assertEq(strangerRig.king(), ALICE, "the throne did not change hands");
        assertEq(reserve.backing(), backingBefore, "the Hard leg was unwound with everything else");
    }

    /*----------  reentrancy  -----------------------------------------------*/

    /// @dev Canonical WETH has no transfer hook (the YELLOW disclosure,
    ///      prd.md:L721), so this cannot happen today; the guard is defence
    ///      against an adverse upgrade (sdd.md:L227). The probe proves the guard
    ///      is actually applied to `take` rather than merely inherited.
    function test_ReentrantTakeIsRejected() public {
        _consumeBootstrap();
        vm.warp(rig.epochStart() + 600);
        _fund(BOB, rig.currentPrice() * 4);

        weth.setReentryCall(address(rig), abi.encodeCall(Rig.take, (type(uint256).max)));

        vm.expectPartialRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(BOB);
        rig.take(type(uint256).max);
    }

    /*----------  INV-21: the outgoing epoch cannot be rewritten  ----------*/

    /// @dev Successor state is written at step 12', before the mint and the King
    ///      leg. INV-21 requires that this cannot reach back and change who is
    ///      being settled. The proof: the record's `outgoingKing`/`epochId` name
    ///      the *previous* holder and epoch even though `king`/`epochId` have
    ///      already been overwritten by the time the event is emitted.
    function test_SuccessorStateCannotRewriteTheOutgoingEpoch() public {
        _consumeBootstrap();

        vm.warp(rig.epochStart() + 700);
        SettledRecord memory first = _takeRecorded(BOB);
        assertEq(first.outgoingKing, ALICE, "settled the reign that was actually open");
        assertEq(first.newKing, BOB, "and named the successor separately");
        assertEq(uint256(first.epochId), 1, "the record carries the OUTGOING epoch id");
        assertEq(uint256(rig.epochId()), 2, "while storage has already advanced");

        vm.warp(rig.epochStart() + 700);
        SettledRecord memory second = _takeRecorded(CAROL);
        assertEq(second.outgoingKing, BOB, "the next settlement settles BOB's reign");
        assertEq(uint256(second.epochId), 2, "epoch ids are consecutive and never reused");
    }

    /// @dev The mint recipient is fixed before any successor write, so a chain of
    ///      settlements credits each King exactly once, for their own reign.
    function test_EachReignIsMintedExactlyOnceToItsOwnKing() public {
        _consumeBootstrap();

        vm.warp(rig.epochStart() + 500);
        SettledRecord memory a = _takeRecorded(BOB);
        vm.warp(rig.epochStart() + 500);
        SettledRecord memory b = _takeRecorded(CAROL);
        vm.warp(rig.epochStart() + 500);
        SettledRecord memory c = _takeRecorded(ALICE);

        // ALICE was minted for her bootstrap-successor reign (record `a`) and has
        // not been credited again by the later settlements.
        assertEq(vux.balanceOf(ALICE), a.qMint, "ALICE credited once, for her own reign only");
        assertEq(vux.balanceOf(BOB), b.qMint, "BOB credited once, for his own reign only");
        assertEq(vux.balanceOf(CAROL), c.qMint, "CAROL credited once, for her own reign only");
    }

    /*----------  permissionless access (FR-2.6)  ---------------------------*/

    function test_AnyoneMayTakeTheThrone() public {
        _consumeBootstrap();

        address[3] memory strangers = [address(0x1111), address(0x2222), address(0x3333)];
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(rig.epochStart() + 300);
            _take(strangers[i]);
            assertEq(rig.king(), strangers[i], "no allowlist, identity gate, or privileged path");
        }
    }
}
