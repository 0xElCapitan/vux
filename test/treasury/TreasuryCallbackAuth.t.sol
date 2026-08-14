// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 5 Task 5.4, AC-1 (nine rejection classes), AC-2
//          (zero standing approvals after every pool operation)
//          sdd.md:L252-L258 (one-shot context authentication), L858 (the
//          required negative suite), §9.2 threat rows 10 and 23

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {MockCallbackPool} from "../mocks/MockCallbackPool.sol";
import {PolFixture} from "./PolFixture.sol";

/// @title TreasuryCallbackAuthTest — the nine ways a callback is refused.
/// @notice The callbacks are the one place an external contract calls into the
///         treasury mid-operation, so "the pool is allowed to call this" is not
///         the authorization — the one-shot context is (sdd.md:L257). This suite
///         is the negative half of that claim, and it is deliberately built so
///         that **being the canonical pool is never sufficient**: most cases
///         below are attempted from the exact address the treasury holds as its
///         immutable `pool`, and they still fail.
///
///         Two of the classes cannot be produced by a well-behaved pool at all —
///         a duplicate second callback, and an operation whose authorization is
///         never consumed. Asserting those from storage would only show that the
///         context word *reads* `NONE`; it would not show that a real second call
///         *fails*. So `MockCallbackPool` makes both attempts for real.
contract TreasuryCallbackAuthTest is PolFixture {
    bytes4 internal constant REENTRANCY_GUARD = bytes4(keccak256("ReentrancyGuardReentrantCall()"));

    MockCallbackPool internal rogue;
    StrategicTreasury internal rigged;

    uint256 internal constant COMMIT_VUX = 1_000e18;
    uint256 internal constant COMMIT_WETH = 2 ether;

    function setUp() public {
        _deployPolSystem();
        _provisionPol();

        // A second treasury whose immutable `pool` is a contract that misbehaves
        // on cue. It passes every constructor identity check by answering for
        // itself, exactly as `MockPool` does for the Sprint-4 negatives — the
        // technique is only ever used to reach a rejection a real pool cannot
        // produce, never to establish a property that holds.
        (address t0, address t1) = _sorted(address(vux), address(weth));
        rogue = new MockCallbackPool(t0, t1, FIXTURE_FEE, FIXTURE_TICK_SPACING, _genesisSqrtPriceX96());
        rigged = new StrategicTreasury(
            address(weth), address(vux), address(reserve), address(rogue), address(rogue), FIXTURE_FEE
        );

        // Enough of both tokens that a payment would succeed if it were allowed
        // to — so every revert below is the authentication, not an empty purse.
        vux.transfer(address(rigged), COMMIT_VUX * 4);
        weth.mint(address(rigged), COMMIT_WETH * 4);
    }

    // =========================================================================
    // The control — the rig CAN produce a callback the treasury accepts
    // =========================================================================

    /// @dev Without this, every "reverts" assertion below could be green because
    ///      the rig never produces a usable callback at all.
    function test_Control_AWellFormedCallbackFromTheRigIsAccepted() public {
        rogue.setOwed(_asToken0(COMMIT_VUX / 2, COMMIT_WETH / 2), _asToken1(COMMIT_VUX / 2, COMMIT_WETH / 2));

        uint256 vuxBefore = vux.balanceOf(address(rigged));
        rigged.mintPolPosition(COMMIT_VUX, COMMIT_WETH);

        assertEq(vuxBefore - vux.balanceOf(address(rigged)), COMMIT_VUX / 2, "the payment went through");
        assertEq(rigged.polVuxPrincipal(), COMMIT_VUX / 2, "and booked as basis");
        _assertNoRiggedApprovals("after an accepted callback");
    }

    // =========================================================================
    // 1 — forged caller
    // =========================================================================

    /// @dev Anyone may call the callback; nobody but the pool gets past line one.
    function test_1_ForgedCallerIsRejected() public {
        vm.expectPartialRevert(StrategicTreasury.CallbackUnauthorizedCaller.selector);
        treasury.uniswapV3MintCallback(1, 1, "");

        vm.expectPartialRevert(StrategicTreasury.CallbackUnauthorizedCaller.selector);
        treasury.uniswapV3SwapCallback(1, -1, "");

        vm.prank(NON_OPERATOR);
        vm.expectPartialRevert(StrategicTreasury.CallbackUnauthorizedCaller.selector);
        treasury.uniswapV3MintCallback(1, 1, "");
    }

    // =========================================================================
    // 2 — the canonical pool, outside any operation
    // =========================================================================

    /// @dev The heart of the doctrine: the real, constructor-verified canonical
    ///      pool calls, and is refused, because no operation armed anything.
    function test_2_TheCanonicalPoolWithNoArmedContextIsRejected() public {
        vm.prank(pool);
        vm.expectPartialRevert(StrategicTreasury.CallbackContextMismatch.selector);
        treasury.uniswapV3MintCallback(1, 1, "");

        vm.prank(pool);
        vm.expectPartialRevert(StrategicTreasury.CallbackContextMismatch.selector);
        treasury.uniswapV3SwapCallback(1, -1, "");
    }

    // =========================================================================
    // 3 — wrong callback type
    // =========================================================================

    /// @dev A mint operation answered with the swap callback, and a swap
    ///      operation answered with the mint callback. The context type is armed
    ///      correctly in both; only the callback is wrong.
    function test_3_WrongCallbackTypeIsRejected() public {
        rogue.setMode(MockCallbackPool.Mode.WRONG_TYPE);
        rogue.setDeltas(_asInt0(-1e18, 1 ether), _asInt1(-1e18, 1 ether));

        vm.expectPartialRevert(StrategicTreasury.CallbackContextMismatch.selector);
        rigged.mintPolPosition(COMMIT_VUX, COMMIT_WETH);

        rogue.setOwed(_asToken0(1e18, 1 ether), _asToken1(1e18, 1 ether));
        vm.expectPartialRevert(StrategicTreasury.CallbackContextMismatch.selector);
        rigged.buyVuxForPol(COMMIT_WETH, 0, _limitFor(!vuxIsToken0));
    }

    // =========================================================================
    // 4 — wrong token direction
    // =========================================================================

    /// @dev For a purchase, exactly one delta may be positive and it must be the
    ///      WETH side. Both-positive (the pool asking to be paid twice) and a
    ///      positive VUX side (being charged for what is being bought) are the
    ///      two ways to get this wrong, and both are refused.
    function test_4_WrongTokenDirectionIsRejected() public {
        rogue.setDeltas(int256(1 ether), int256(1e18)); // both sides owed
        vm.expectPartialRevert(StrategicTreasury.CallbackDirectionMismatch.selector);
        rigged.buyVuxForPol(COMMIT_WETH, 0, _limitFor(!vuxIsToken0));

        // VUX owed, WETH received — the exact inverse of the armed operation.
        rogue.setDeltas(_asInt0(1e18, -1 ether), _asInt1(1e18, -1 ether));
        vm.expectPartialRevert(StrategicTreasury.CallbackDirectionMismatch.selector);
        rigged.buyVuxForPol(COMMIT_WETH, 0, _limitFor(!vuxIsToken0));
    }

    // =========================================================================
    // 5 — amount above the committed maximum
    // =========================================================================

    /// @dev The excess-delta case, on each token of each callback. One wei over
    ///      the commitment is over the commitment.
    function test_5_AmountAboveTheCommittedMaximumIsRejected() public {
        rogue.setOwed(_asToken0(COMMIT_VUX + 1, 1), _asToken1(COMMIT_VUX + 1, 1));
        vm.expectPartialRevert(StrategicTreasury.CallbackAmountExceedsCommitment.selector);
        rigged.mintPolPosition(COMMIT_VUX, COMMIT_WETH);

        rogue.setOwed(_asToken0(1, COMMIT_WETH + 1), _asToken1(1, COMMIT_WETH + 1));
        vm.expectPartialRevert(StrategicTreasury.CallbackAmountExceedsCommitment.selector);
        rigged.mintPolPosition(COMMIT_VUX, COMMIT_WETH);

        rogue.setDeltas(_asInt0(-1e18, int256(COMMIT_WETH + 1)), _asInt1(-1e18, int256(COMMIT_WETH + 1)));
        vm.expectPartialRevert(StrategicTreasury.CallbackAmountExceedsCommitment.selector);
        rigged.buyVuxForPol(COMMIT_WETH, 0, _limitFor(!vuxIsToken0));
    }

    // =========================================================================
    // 6 — nested / reentrant attempt
    // =========================================================================

    /// @dev A callback that tries to start a second treasury operation meets the
    ///      outer `nonReentrant` guard, which the callback itself deliberately
    ///      does not take (sdd.md:L257). This is why not taking it is safe: the
    ///      guard is still held by the operation that armed the context.
    function test_6_ReentrantCallbackIsRejected() public {
        rogue.setMode(MockCallbackPool.Mode.REENTRANT);
        rogue.setOwed(_asToken0(1e18, 1 ether), _asToken1(1e18, 1 ether));

        vm.expectRevert(REENTRANCY_GUARD);
        rigged.mintPolPosition(COMMIT_VUX, COMMIT_WETH);
    }

    // =========================================================================
    // 7 — nonempty callback data
    // =========================================================================

    /// @dev This contract passes no data, so any is malformed by definition.
    function test_7_NonemptyCallbackDataIsRejected() public {
        rogue.setMode(MockCallbackPool.Mode.NONEMPTY_DATA);
        rogue.setOwed(_asToken0(1e18, 1 ether), _asToken1(1e18, 1 ether));

        vm.expectPartialRevert(StrategicTreasury.CallbackDataNotEmpty.selector);
        rigged.mintPolPosition(COMMIT_VUX, COMMIT_WETH);

        rogue.setDeltas(_asInt0(-1e18, 1 ether), _asInt1(-1e18, 1 ether));
        vm.expectPartialRevert(StrategicTreasury.CallbackDataNotEmpty.selector);
        rigged.buyVuxForPol(COMMIT_WETH, 0, _limitFor(!vuxIsToken0));
    }

    // =========================================================================
    // 8 — authorization reuse: a real second callback, from the canonical pool
    // =========================================================================

    /// @dev The one-shot claim, exercised rather than inferred. The pool address
    ///      is this treasury's own immutable `pool`, the first callback is
    ///      well-formed and accepted, and the *second* — identical, same
    ///      operation, same caller — finds `CTX_NONE` and reverts, taking the
    ///      whole operation with it.
    function test_8_ADuplicateSecondCallbackRevertsEvenFromTheCanonicalPool() public {
        rogue.setOwed(_asToken0(1e18, 1 ether), _asToken1(1e18, 1 ether));
        rogue.setDeltas(_asInt0(-1e18, 1 ether), _asInt1(-1e18, 1 ether));

        // Establish the differential: with ONE callback, this exact operation
        // with these exact amounts succeeds.
        rigged.mintPolPosition(COMMIT_VUX, COMMIT_WETH);
        rigged.buyVuxForPol(COMMIT_WETH, 0, _limitFor(!vuxIsToken0));
        uint256 vuxAfterAcceptedOps = vux.balanceOf(address(rigged));
        uint256 wethAfterAcceptedOps = weth.balanceOf(address(rigged));

        // Change exactly one thing: the pool now calls back a second time, with
        // identical arguments, inside the same operation, from the same address.
        rogue.setMode(MockCallbackPool.Mode.DOUBLE_CALLBACK);

        vm.expectPartialRevert(StrategicTreasury.CallbackContextMismatch.selector);
        rigged.mintPolPosition(COMMIT_VUX, COMMIT_WETH);

        vm.expectPartialRevert(StrategicTreasury.CallbackContextMismatch.selector);
        rigged.buyVuxForPol(COMMIT_WETH, 0, _limitFor(!vuxIsToken0));

        // The first callback of each reverted operation paid — and that payment
        // did not survive, because the second callback took the whole call down.
        assertEq(vux.balanceOf(address(rigged)), vuxAfterAcceptedOps, "no further VUX left the treasury");
        assertEq(weth.balanceOf(address(rigged)), wethAfterAcceptedOps, "and no further WETH");
    }

    // =========================================================================
    // 9 — an authorization that goes unconsumed
    // =========================================================================

    /// @dev A pool that takes the call and never calls back leaves a live
    ///      authorization behind. The outer operation refuses to return on it,
    ///      so no armed context can outlive the operation that armed it.
    function test_9_AnUnconsumedAuthorizationRevertsTheOuterOperation() public {
        rogue.setMode(MockCallbackPool.Mode.NO_CALLBACK);

        vm.expectRevert(StrategicTreasury.CallbackNotConsumed.selector);
        rigged.mintPolPosition(COMMIT_VUX, COMMIT_WETH);

        vm.expectRevert(StrategicTreasury.CallbackNotConsumed.selector);
        rigged.buyVuxForPol(COMMIT_WETH, 0, _limitFor(!vuxIsToken0));
    }

    // =========================================================================
    // Zero standing approvals — after every pool operation
    // =========================================================================

    /// @dev AC-2. Payment is by direct `transfer` in both callbacks, so there is
    ///      never an allowance for a later caller to spend. Asserted after each
    ///      of the four operations that touch the pool, on both tokens, against
    ///      the pool and every other counterparty the treasury ever transfers to.
    function test_ZeroStandingApprovalsAfterEveryPoolOperation() public {
        _assertNoStandingApprovals("at rest");

        _accrueBothFeeLegs(5 ether);
        _assertNoStandingApprovals("after third-party trading");

        treasury.harvestPol();
        _assertNoStandingApprovals("after harvestPol");

        vux.transfer(address(treasury), 1_000e18);
        weth.mint(address(treasury), 5 ether);

        treasury.increasePol(1_000e18, 2 ether);
        _assertNoStandingApprovals("after increasePol");

        treasury.buyVuxForPol(1 ether, 0, _limitFor(!vuxIsToken0));
        _assertNoStandingApprovals("after buyVuxForPol");

        treasury.decreasePol(_polLiquidity() / 4);
        _assertNoStandingApprovals("after decreasePol");
    }

    // --- helpers --------------------------------------------------------------

    /// @dev Map a (VUX, WETH) pair onto the pool's token0/token1 slots. Written
    ///      out rather than reused from the fixture so the negative suite states
    ///      the ordering itself instead of inheriting the contract's view of it.
    function _asToken0(uint256 vuxAmount, uint256 wethAmount) private view returns (uint256) {
        return vuxIsToken0 ? vuxAmount : wethAmount;
    }

    function _asToken1(uint256 vuxAmount, uint256 wethAmount) private view returns (uint256) {
        return vuxIsToken0 ? wethAmount : vuxAmount;
    }

    function _asInt0(int256 vuxDelta, int256 wethDelta) private view returns (int256) {
        return vuxIsToken0 ? vuxDelta : wethDelta;
    }

    function _asInt1(int256 vuxDelta, int256 wethDelta) private view returns (int256) {
        return vuxIsToken0 ? wethDelta : vuxDelta;
    }

    function _assertNoRiggedApprovals(string memory what) private view {
        assertEq(vux.allowance(address(rigged), address(rogue)), 0, string.concat(what, ": VUX allowance"));
        assertEq(weth.allowance(address(rigged), address(rogue)), 0, string.concat(what, ": WETH allowance"));
    }
}
