// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: INV-1, INV-10, INV-14, INV-15, INV-16, INV-17, FR-7.1, FR-7.4, FR-7.5
//          sprint.md Sprint 2 AC-3, AC-6

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Vm} from "../harness/Vm.sol";
import {ReserveFixture} from "./ReserveFixture.sol";
import {HardReserve} from "../../src/HardReserve.sol";

/// @dev External wrapper so the naive product can be attempted through a call
///      whose revert is observable. `b * q` in the test body would abort the
///      test itself rather than demonstrate anything.
contract NaiveMath {
    function product(uint256 a, uint256 b) external pure returns (uint256) {
        return a * b;
    }
}

/// @title HardReserveRedemptionTest — the redemption arithmetic, exactly.
/// @notice The payout formula is the protocol's exit right, so it is tested as a
///         property over randomized `(B, S, q)` rather than as a set of
///         hand-picked examples. Two fuzz domains are covered deliberately:
///         one where `B × q` fits in 256 bits — so the expected value can be
///         computed natively, independent of the `Math.mulDiv` under test — and
///         one where `B × q` provably does NOT fit, where the expectation is
///         computed by an algebraic decomposition that never forms the
///         overflowing product. Reusing `Math.mulDiv` as the oracle would only
///         prove the implementation equals itself.
contract HardReserveRedemptionTest is ReserveFixture {
    bytes32 internal constant REDEEMED_TOPIC =
        keccak256("Redeemed(address,address,uint256,uint256,uint256,uint256)");

    function setUp() public {
        _deploySystem();
    }

    // -----------------------------------------------------------------------
    // Backing is the physical balance (INV-10)
    // -----------------------------------------------------------------------

    function test_BackingIsThePhysicalWethBalanceWithNoDepositFunction() public {
        assertEq(reserve.backing(), 0, "the Reserve is born empty");

        // Accretion is a plain ERC-20 transfer in — there is no deposit
        // function to call, and none is needed.
        weth.mint(address(this), 5 ether);
        weth.transfer(address(reserve), 5 ether);

        assertEq(reserve.backing(), 5 ether, "backing tracks the raw WETH balance");
        assertEq(weth.balanceOf(address(reserve)), reserve.backing(), "backing() IS balanceOf, not a shadow cell");
    }

    // -----------------------------------------------------------------------
    // Pre-redemption state (INV-15) — the discriminating case
    // -----------------------------------------------------------------------

    /// @dev Burn happens before pay (CEI), so an implementation that computed
    ///      the payout from live state after the burn would read a smaller `S`
    ///      and overpay. Chosen so the two answers differ by 2×: `B=10, S=4,
    ///      q=2` gives `floor(10×2/4) = 5` on pre-state and `floor(10×2/2) = 10`
    ///      on post-burn state.
    function test_PayoutUsesPreRedemptionStateNotPostBurnState() public {
        _shrinkSupplyTo(4);
        weth.mint(address(reserve), 10);

        uint256 payout = reserve.redeem(2, address(this));

        assertEq(payout, 5, "floor(B x q / S) on PRE-redemption B and S");
        assertNotEq(payout, 10, "post-burn state would have paid double");
        assertEq(reserve.backing(), 5, "remainder stayed in the Reserve");
        assertEq(vux.totalSupply(), 2, "exactly q burned");
    }

    /// @dev The emitted record must let an indexer re-derive the payout without
    ///      replaying state (UC-6, sdd.md §3.2).
    function test_RedeemedEventCarriesThePreRedemptionInputs() public {
        _shrinkSupplyTo(4);
        weth.mint(address(reserve), 10);

        vm.recordLogs();
        reserve.redeem(2, HOLDER);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(reserve) || logs[i].topics[0] != REDEEMED_TOPIC) continue;
            found = true;

            assertEq(address(uint160(uint256(logs[i].topics[1]))), address(this), "indexed redeemer");
            assertEq(address(uint160(uint256(logs[i].topics[2]))), HOLDER, "indexed recipient");

            (uint256 q, uint256 payout, uint256 bPre, uint256 sPre) =
                abi.decode(logs[i].data, (uint256, uint256, uint256, uint256));
            assertEq(q, 2, "logged q");
            assertEq(bPre, 10, "logged pre-redemption B");
            assertEq(sPre, 4, "logged pre-redemption S");
            assertEq(payout, (bPre * q) / sPre, "payout re-derivable from the log alone");
        }
        assertTrue(found, "Redeemed event emitted");
    }

    // -----------------------------------------------------------------------
    // Payout property — native domain (exact, independent oracle)
    // -----------------------------------------------------------------------

    function testFuzz_PayoutIsFloorOfBTimesQOverS(uint256 bSeed, uint256 supplySeed, uint256 qSeed) public {
        // Bounds keep `b * q` inside 256 bits so the expectation below is an
        // INDEPENDENT computation, not a second call to the code under test.
        uint256 b = bound(bSeed, 0, 1e40);
        uint256 extra = bound(supplySeed, 0, 1e30);

        weth.mint(address(reserve), b);
        if (extra > 0) _mintVux(address(this), extra);
        _consolidateFloatTo(HOLDER);

        uint256 s = vux.totalSupply();
        uint256 q = bound(qSeed, 0, s - reserve.S_MIN());
        uint256 expected = (b * q) / s;

        uint256 wethTotalBefore = weth.totalSupply();
        uint256 holderVuxBefore = vux.balanceOf(HOLDER);

        vm.prank(HOLDER);
        uint256 payout = reserve.redeem(q, HOLDER);

        assertEq(payout, expected, "payout = floor(B x q / S)");

        // Zero fee: the Reserve's loss is exactly the recipient's gain, and no
        // third party received anything.
        assertEq(reserve.backing(), b - payout, "Reserve paid exactly the payout");
        assertEq(weth.balanceOf(HOLDER), payout, "recipient received exactly the payout");
        assertEq(weth.totalSupply(), wethTotalBefore, "no WETH created or destroyed");

        // Exact burn, complete supply.
        assertEq(vux.totalSupply(), s - q, "supply fell by exactly q");
        assertEq(vux.balanceOf(HOLDER), holderVuxBefore - q, "exactly q burned from the redeemer");

        // Reserve-favoring rounding: the payout never exceeds the true share,
        // and one more wei would.
        assertLe(payout * s, b * q, "payout never exceeds the exact pro-rata share");
        assertGt((payout + 1) * s, b * q, "payout is the greatest such value (floor, not a deeper truncation)");
    }

    // -----------------------------------------------------------------------
    // Payout property — the domain a naive `B * q` cannot reach
    // -----------------------------------------------------------------------

    /// @dev Writes `B = A·S + rem` with `rem < S`, so
    ///      `floor(B·q/S) = A·q + floor(rem·q/S)`. Neither `A·q` nor `rem·q`
    ///      overflows in the chosen ranges, while `B·q` provably does — which
    ///      the test asserts rather than assumes. This is the property a
    ///      512-bit `mulDiv` exists for; an implementation using a plain
    ///      `B * q` would revert here, denying the exit right precisely when
    ///      backing is largest.
    function testFuzz_PayoutIsExactWhenBTimesQOverflowsUint256(uint256 aSeed, uint256 remSeed, uint256 qSeed)
        public
    {
        _mintVux(address(this), 1e26);
        _consolidateFloatTo(HOLDER);

        uint256 s = vux.totalSupply();
        uint256 a = bound(aSeed, 1e28, 1e29);
        uint256 rem = bound(remSeed, 0, s - 1);
        uint256 b = a * s + rem;
        uint256 q = bound(qSeed, 1e25, s - reserve.S_MIN());

        assertTrue(b != 0 && q > type(uint256).max / b, "domain check: B x q genuinely overflows uint256");

        weth.mint(address(reserve), b);

        uint256 expected = a * q + (rem * q) / s;

        vm.prank(HOLDER);
        uint256 payout = reserve.redeem(q, HOLDER);

        assertEq(payout, expected, "payout = floor(B x q / S) with a 512-bit intermediate");
        assertEq(reserve.backing(), b - payout, "Reserve paid exactly the payout");
        assertEq(vux.totalSupply(), s - q, "supply fell by exactly q");
    }

    /// @dev Concrete companion to the property above: the same inputs that
    ///      `redeem` handles make a plain 256-bit product revert.
    function test_NaiveProductRevertsWhereRedeemSucceeds() public {
        _mintVux(address(this), 1e26);
        _consolidateFloatTo(HOLDER);

        uint256 s = vux.totalSupply();
        uint256 b = 1e28 * s;
        uint256 q = 1e26;
        weth.mint(address(reserve), b);

        NaiveMath naive = new NaiveMath();
        vm.expectRevert();
        naive.product(b, q);

        vm.prank(HOLDER);
        uint256 payout = reserve.redeem(q, HOLDER);
        assertEq(payout, 1e28 * q, "exact pro-rata payout at a scale a naive product cannot express");
    }

    // -----------------------------------------------------------------------
    // Rounding direction and the remainder (INV-16)
    // -----------------------------------------------------------------------

    function test_RoundingRemainderStaysInTheReserve() public {
        _shrinkSupplyTo(3);
        weth.mint(address(reserve), 10);

        uint256 payout = reserve.redeem(1, address(this));

        assertEq(payout, 3, "floor(10 x 1 / 3) = 3, not 4");
        assertEq(reserve.backing(), 7, "the truncated wei stayed with the Reserve, not the redeemer");
    }

    function testFuzz_PreviewMatchesTheActualPayout(uint256 bSeed, uint256 qSeed) public {
        uint256 b = bound(bSeed, 0, 1e40);
        weth.mint(address(reserve), b);
        _consolidateFloatTo(HOLDER);

        uint256 q = bound(qSeed, 0, vux.totalSupply() - reserve.S_MIN());
        uint256 quoted = reserve.previewRedeem(q);

        vm.prank(HOLDER);
        uint256 payout = reserve.redeem(q, HOLDER);

        assertEq(payout, quoted, "previewRedeem quotes the payout the same state would produce");
    }

    // -----------------------------------------------------------------------
    // S_MIN preservation and exhaustion (FR-7.5, INV-15)
    // -----------------------------------------------------------------------

    function test_RedeemingTheFinalUnitIsRejected() public {
        weth.mint(address(reserve), 100 ether);
        _consolidateFloatTo(HOLDER);
        uint256 s = vux.totalSupply();

        vm.prank(HOLDER);
        vm.expectRevert(abi.encodeWithSelector(HardReserve.SupplyFloor.selector, s, s - 1));
        reserve.redeem(s, HOLDER);

        assertEq(vux.totalSupply(), s, "rejected redemption changed nothing");
    }

    function testFuzz_FullExternalRedemptionLeavesTheSeedAndAPositiveRemainder(uint256 bSeed, uint256 supplySeed)
        public
    {
        uint256 b = bound(bSeed, 1, 1e40);
        uint256 extra = bound(supplySeed, 0, 1e30);

        weth.mint(address(reserve), b);
        if (extra > 0) _mintVux(address(this), extra);
        _consolidateFloatTo(HOLDER);

        uint256 s = vux.totalSupply();
        uint256 float_ = s - reserve.S_MIN();
        assertEq(vux.balanceOf(HOLDER), float_, "the holder holds the entire external float");

        vm.prank(HOLDER);
        reserve.redeem(float_, HOLDER);

        assertEq(vux.totalSupply(), reserve.S_MIN(), "exactly the permanent minimum supply remains");
        assertEq(vux.balanceOf(address(reserve)), reserve.S_MIN(), "and the Reserve still holds that seed");
        assertGt(reserve.backing(), 0, "a positive WETH remainder survives (prd.md:L253)");

        // The denominator is live, so the seed still has a computable claim.
        assertEq(reserve.previewRedeem(reserve.S_MIN()), reserve.backing(), "B/S remains well defined");
    }

    // -----------------------------------------------------------------------
    // Third-party burn impossibility (AC-6)
    // -----------------------------------------------------------------------

    /// @dev The strongest available statement of "the Reserve passes only
    ///      `msg.sender`": an attacker holding nothing cannot redeem, even
    ///      though the contract holds plenty of other people's VUX. If the burn
    ///      source were ever attacker-controlled, this call would succeed.
    function test_RedeemerWithNoBalanceCannotDrainAnotherHoldersVux() public {
        weth.mint(address(reserve), 100 ether);
        _consolidateFloatTo(VICTIM);
        uint256 victimBefore = vux.balanceOf(VICTIM);
        assertGt(victimBefore, 0, "the victim holds a redeemable balance");

        vm.prank(ATTACKER);
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        reserve.redeem(1000, ATTACKER);

        assertEq(vux.balanceOf(VICTIM), victimBefore, "victim balance untouched");
        assertEq(weth.balanceOf(ATTACKER), 0, "attacker received nothing");
    }

    function test_RedemptionBurnsOnlyTheCallersOwnVux() public {
        weth.mint(address(reserve), 100 ether);
        _mintVux(ATTACKER, 5e18);
        _consolidateFloatTo(VICTIM);

        uint256 victimBefore = vux.balanceOf(VICTIM);

        vm.prank(ATTACKER);
        reserve.redeem(5e18, ATTACKER);

        assertEq(vux.balanceOf(ATTACKER), 0, "the attacker's own VUX was burned");
        assertEq(vux.balanceOf(VICTIM), victimBefore, "and nobody else's");
    }

    function test_TheTokenGateRejectsADirectRedemptionBurn() public {
        _mintVux(VICTIM, 5e18);

        vm.prank(ATTACKER);
        (bool ok,) =
            address(vux).call(abi.encodeWithSignature("burnForRedemption(address,uint256)", VICTIM, 5e18));

        assertFalse(ok, "burnForRedemption is unreachable from a non-Reserve caller");
        assertEq(vux.balanceOf(VICTIM), 5e18, "victim balance untouched");
    }

    // -----------------------------------------------------------------------
    // Approval-free, atomic, non-reentrant (FR-7.4, sdd.md §6.1)
    // -----------------------------------------------------------------------

    function test_RedemptionNeedsNoApprovalAtAnyPoint() public {
        weth.mint(address(reserve), 10 ether);
        _consolidateFloatTo(HOLDER);

        assertEq(vux.allowance(HOLDER, address(reserve)), 0, "no allowance before");

        vm.prank(HOLDER);
        reserve.redeem(1e18, HOLDER);

        assertEq(vux.allowance(HOLDER, address(reserve)), 0, "and none was created or consumed");
    }

    function test_AFailedPayoutRevertsTheWholeRedemption() public {
        weth.mint(address(reserve), 10 ether);
        _consolidateFloatTo(HOLDER);

        uint256 sBefore = vux.totalSupply();
        uint256 holderBefore = vux.balanceOf(HOLDER);

        // A `false` return with no revert — the failure mode a bare
        // `.transfer(...)` would swallow, burning VUX and paying nothing.
        weth.setFailTransfers(true);

        vm.prank(HOLDER);
        vm.expectRevert();
        reserve.redeem(1e18, HOLDER);

        assertEq(vux.totalSupply(), sBefore, "no VUX was burned");
        assertEq(vux.balanceOf(HOLDER), holderBefore, "the redeemer kept its balance");
        assertEq(reserve.backing(), 10 ether, "backing is intact");
    }

    function test_ReentrantRedeemIsRejected() public {
        weth.mint(address(reserve), 10 ether);
        _consolidateFloatTo(HOLDER);

        weth.setReentryTarget(address(reserve));

        vm.prank(HOLDER);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        reserve.redeem(1e18, HOLDER);

        assertEq(vux.totalSupply(), S0, "nothing settled");
    }

    // -----------------------------------------------------------------------
    // Input handling
    // -----------------------------------------------------------------------

    function test_RedeemRejectsTheZeroRecipient() public {
        weth.mint(address(reserve), 10 ether);

        vm.expectRevert(HardReserve.ZeroAddress.selector);
        reserve.redeem(1e18, address(0));
    }

    function test_RedeemingZeroMovesNothing() public {
        weth.mint(address(reserve), 10 ether);
        _consolidateFloatTo(HOLDER);

        vm.prank(HOLDER);
        uint256 payout = reserve.redeem(0, HOLDER);

        assertEq(payout, 0, "zero in, zero out");
        assertEq(vux.totalSupply(), S0, "supply unchanged");
        assertEq(reserve.backing(), 10 ether, "backing unchanged");
    }

    /// @dev Donations raise `B` for every holder and are credited to nobody —
    ///      the accretion class the Reserve accepts by construction (INV-10).
    function test_DonatedWethRaisesEveryHoldersClaim() public {
        weth.mint(address(reserve), 10 ether);
        _consolidateFloatTo(HOLDER);
        uint256 before = reserve.previewRedeem(1e18);

        weth.mint(address(this), 90 ether);
        weth.transfer(address(reserve), 90 ether);

        assertGt(reserve.previewRedeem(1e18), before, "the same q now claims more WETH");
        assertEq(reserve.backing(), 100 ether, "donation entered B with no mint credit");
        assertEq(vux.totalSupply(), S0, "and created no VUX");
    }
}
