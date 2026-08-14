// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FB-5 (50/80/100% Strategic loss, bit-identical core), FB-13, FB-15,
//          FB-16; INV-24, INV-35; FR-8 acceptance (prd.md:L444), FR-10.3
//          sprint.md Sprint 4 AC-8, Task 4.8

import {Artifact} from "../harness/Artifact.sol";
import {Vm} from "../harness/Vm.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {TreasuryFixture} from "./TreasuryFixture.sol";

/// @title TreasuryFailureBehaviorsTest — what a Strategic failure cannot do.
/// @notice FB-5 is the sprint's headline claim and it is stated as an equality,
///         not as a tendency: a 50%, 80%, or 100% Strategic loss leaves `B`,
///         redemption, VEM, and mint authority **bit-identical**. These tests
///         take the claim literally — every core value is captured before the
///         loss and compared after, and the settlement that follows is checked
///         to have read a `B_pre` the loss never touched.
contract TreasuryFailureBehaviorsTest is TreasuryFixture {
    uint8 internal constant NETTING = 0;

    uint256 internal constant CAP = 10_000 ether;
    uint256 internal constant DEPLOYED = 400 ether;

    /// @dev Where a lost position's assets go. Not the zero address: a burn
    ///      would be indistinguishable from a supply change on some tokens, and
    ///      the point is that the value left Strategic custody.
    address internal constant VOID = address(0xD3AD);

    bytes32 internal constant SETTLED_TOPIC = keccak256(
        "Settled(uint64,address,address,bool,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)"
    );

    MockStrategy internal strategy;

    function setUp() public {
        _deploySystem();
        strategy = _newStrategy();

        // Consume the bootstrap so the system is in an ordinary epoch with a
        // public King, a running clock, and a real VEM headroom to compare.
        _takeThrone(ALICE);

        _fundTreasury(address(weth), 2_000 ether);
        _admitMatured(address(strategy), address(weth), CAP, NETTING);
        treasury.deployToStrategy(address(strategy), address(weth), DEPLOYED);
    }

    function _takeThrone(address who) internal {
        uint256 price = rig.currentPrice();
        weth.mint(who, price);
        vm.prank(who);
        weth.approve(address(rig), price);
        vm.prank(who);
        rig.take(type(uint256).max);
    }

    /// @dev Destroy `lossBp` basis points of everything the strategy holds.
    function _loseStrategicCapital(uint256 lossBp) internal returns (uint256 lost) {
        uint256 held = weth.balanceOf(address(strategy));
        lost = (held * lossBp) / 10_000;
        if (lost == 0) return 0;
        vm.prank(address(strategy));
        weth.transfer(VOID, lost);
    }

    // =========================================================================
    // FB-5 — the core is bit-identical across any Strategic loss
    // =========================================================================

    function _assertLossLeavesTheCoreBitIdentical(uint256 lossBp, string memory label) internal {
        CoreState memory before = _snapshotCore();
        uint256 previewLarge = reserve.previewRedeem(1_000e18);
        uint256 outstandingBefore = treasury.outstandingPrincipal(address(strategy), address(weth));

        uint256 lost = _loseStrategicCapital(lossBp);

        _assertCoreUnchanged(before, label);
        assertEq(reserve.previewRedeem(1_000e18), previewLarge, string.concat(label, ": redemption quote"));

        // The loss is real and it is Strategic-only: the deployed principal is
        // still on the books as principal (it has not been reclassified into
        // revenue, a receivable, or a claim), and the assets are gone.
        assertEq(weth.balanceOf(VOID), lost, string.concat(label, ": the capital really left"));
        assertEq(
            treasury.outstandingPrincipal(address(strategy), address(weth)),
            outstandingBefore,
            string.concat(label, ": Strategic principal accounting is untouched by a market loss")
        );
        assertEq(treasury.realizedRevenue(address(weth)), 0, string.concat(label, ": a loss creates no revenue"));
    }

    function test_FB5_FiftyPercentStrategicLossLeavesTheCoreBitIdentical() public {
        _assertLossLeavesTheCoreBitIdentical(5_000, "50% Strategic loss");
    }

    function test_FB5_EightyPercentStrategicLossLeavesTheCoreBitIdentical() public {
        _assertLossLeavesTheCoreBitIdentical(8_000, "80% Strategic loss");
    }

    function test_FB5_TotalStrategicLossLeavesTheCoreBitIdentical() public {
        _assertLossLeavesTheCoreBitIdentical(10_000, "100% Strategic loss");
        assertEq(weth.balanceOf(address(strategy)), 0, "the position is worth nothing at all");
    }

    /// @dev The strongest form of the claim: after a total loss, the NEXT
    ///      settlement reads exactly the `B_pre` and `S_pre` it would have read
    ///      anyway, and mints on that basis. If a Strategic loss could reach VEM
    ///      at all, it would reach it here.
    function test_FB5_TheSettlementAfterATotalLossReadsAnUntouchedBackingAndSupply() public {
        _loseStrategicCapital(10_000);

        uint256 backingBefore = reserve.backing();
        uint256 supplyBefore = vux.totalSupply();

        vm.warp(vm.getBlockTimestamp() + 1_500);
        vm.recordLogs();
        _takeThrone(BOB_LIKE);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length != 4 || logs[i].topics[0] != SETTLED_TOPIC) continue;
            found++;
            (,,,,, uint256 bPre, uint256 sPre,,, uint256 qSafe, uint256 qMint,,) = abi.decode(
                logs[i].data,
                (
                    bool,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256
                )
            );
            assertEq(bPre, backingBefore, "the settlement read B, not B minus a Strategic loss");
            assertEq(sPre, supplyBefore, "and S, unaffected by the loss");
            assertLe(qMint, qSafe, "VEM still capped issuance on the untouched backing");
        }
        assertEq(found, 1, "exactly one settlement");
    }

    /// @dev And the negative: there is no rescue. After a total loss the
    ///      treasury cannot pull a single wei out of the Reserve to repair it,
    ///      because the Reserve exposes nothing to pull with.
    function test_FB5_NoRescuePathExistsAfterATotalLoss() public {
        _loseStrategicCapital(10_000);
        uint256 backing = reserve.backing();

        // Every shape a "rescue" could take, attempted with the treasury's own
        // identity. Each fails because the function does not exist.
        string[4] memory shapes = [
            "sweep(address,uint256)",
            "rescue(address,uint256)",
            "transfer(address,uint256)",
            "withdraw(uint256)"
        ];
        for (uint256 i = 0; i < shapes.length; i++) {
            vm.prank(address(treasury));
            (bool ok,) = address(reserve).call(abi.encodeWithSignature(shapes[i], address(weth), backing));
            assertFalse(ok, string.concat("no Reserve path named ", shapes[i]));
        }
        assertEq(reserve.backing(), backing, "B is exactly where it was");
    }

    // =========================================================================
    // FB-15 / FB-16 — no rescue, no recapitalization, from the new surface
    // =========================================================================

    /// @dev The treasury's identity buys it nothing. Even impersonating it, the
    ///      token's two immutable gates refuse: it is not the Rig and it is not
    ///      the Reserve, and no role, argument, or sequence can make it either.
    function test_FB16_TheTreasuryIdentityCannotMintOrBurnAnotherHolder() public {
        vm.prank(address(treasury));
        vm.expectRevert(bytes4(keccak256("NotRig()")));
        IVuxAuthority(address(vux)).mint(address(treasury), 1);

        vm.prank(address(treasury));
        vm.expectRevert(bytes4(keccak256("NotReserve()")));
        IVuxAuthority(address(vux)).burnForRedemption(ALICE, 1);
    }

    /// @dev FR-10.3 / FB-15 / FB-16, proven at the type level: the treasury's
    ///      compilation unit contains no declaration of any monetary-core
    ///      authority, so it cannot *name* `HardReserve.redeem`, `VUX.mint`, or
    ///      `VUX.burnForRedemption` — let alone call one. The compiler's own
    ///      record of what produced this artifact is the evidence.
    ///
    ///      This is the encoding-independent half of the claim and the stronger
    ///      one: "no call site in the bytecode" can be defeated by a call built
    ///      from a computed selector; "the declaration is not in the source set"
    ///      cannot.
    function test_FR10_3_TheTreasuryCannotEvenNameACoreAuthority() public view {
        string[] memory sources =
            vm.parseJsonKeys(vm.readFile("out/StrategicTreasury.sol/StrategicTreasury.json"), ".metadata.sources");

        string[5] memory forbidden = [
            "src/HardReserve.sol",
            "src/Rig.sol",
            "src/VUX.sol",
            "src/interfaces/IVUX.sol", // declares burnForRedemption
            "src/interfaces/IVUXMintable.sol" // declares mint
        ];
        for (uint256 i = 0; i < forbidden.length; i++) {
            assertFalse(
                Artifact.contains(sources, forbidden[i]),
                string.concat("the treasury must not compile against ", forbidden[i])
            );
        }

        // Positive controls: the narrow surfaces it DOES compile against.
        assertTrue(Artifact.contains(sources, "src/StrategicTreasury.sol"), "control: itself");
        assertTrue(Artifact.contains(sources, "src/interfaces/IVUXBurnable.sol"), "control: the self-burn only");
        assertTrue(Artifact.contains(sources, "src/interfaces/IStrategyAdapter.sol"), "control: the measurement surface");
    }

    /// @dev The bytecode half of the same claim: no call site embeds a
    ///      monetary-core selector.
    ///
    ///      Searching for the raw 4 bytes would be unsound here, and the positive
    ///      control is what shows why: under `via_ir` + optimizer the compiler
    ///      emits `PUSH4 (sel >> s); PUSH1 (0xe0 + s); SHL` for whichever small
    ///      `s` suits it — the F-46 self-burn's `0x42966c68` is stored as
    ///      `0x0852cd8d` with `s = 3`, and a naive substring search finds
    ///      nothing and calls it absence. So every legal shift is enumerated,
    ///      and the control proves the enumeration finds a call site that is
    ///      really there.
    function test_FR10_3_NoCoreAuthoritySelectorIsEmittedAsAnOutboundCall() public view {
        bytes memory runtime = vm.parseJsonBytes(
            vm.readFile("out/StrategicTreasury.sol/StrategicTreasury.json"), ".deployedBytecode.object"
        );

        assertFalse(_hasCallSite(runtime, bytes4(keccak256("redeem(uint256,address)"))), "no HardReserve.redeem");
        assertFalse(_hasCallSite(runtime, bytes4(keccak256("mint(address,uint256)"))), "no VUX.mint");
        assertFalse(
            _hasCallSite(runtime, bytes4(keccak256("burnForRedemption(address,uint256)"))), "no VUX.burnForRedemption"
        );

        assertTrue(_hasCallSite(runtime, bytes4(keccak256("burn(uint256)"))), "control: the F-46 self-burn IS called");
        assertTrue(
            _hasCallSite(runtime, bytes4(keccak256("principalUnits()"))), "control: the measurement read IS called"
        );
    }

    /// @dev True when `runtime` contains the `PUSH4 (sel >> s); PUSH1 (0xe0+s);
    ///      SHL` idiom for any shift `s` that `sel` can survive losslessly.
    function _hasCallSite(bytes memory runtime, bytes4 selector) private pure returns (bool) {
        uint32 sel = uint32(selector);
        for (uint256 s = 0; s < 8; s++) {
            uint32 shifted = sel >> s;
            if (shifted << s != sel) continue; // the compiler cannot use this shift
            bytes memory pattern =
                abi.encodePacked(bytes1(0x63), bytes4(shifted), bytes1(0x60), bytes1(uint8(0xe0 + s)), bytes1(0x1b));
            if (Artifact.containsBytes(runtime, pattern)) return true;
        }
        return false;
    }

    // =========================================================================
    // FB-13 — mass redemption while Strategic assets are illiquid
    // =========================================================================

    /// @dev Hard pays synchronously, pro rata, from `B` alone. The Strategic
    ///      position is not sold, not called, and does not supplement the payout
    ///      — its illiquidity is simply irrelevant to the exit right.
    function test_FB13_MassRedemptionIsPaidFromHardAloneWhileStrategicIsIlliquid() public {
        // Make the Strategic side maximally unhelpful: deployed and frozen.
        uint256 strategicHeld = weth.balanceOf(address(strategy));
        assertGt(strategicHeld, 0, "capital is out in an illiquid position");

        _consolidateFloatTo(ALICE);
        uint256 q = vux.balanceOf(ALICE);
        uint256 expected = reserve.previewRedeem(q);
        uint256 backingBefore = reserve.backing();

        vm.prank(ALICE);
        uint256 payout = reserve.redeem(q, ALICE);

        assertEq(payout, expected, "paid exactly floor(B x q / S) on pre-redemption values");
        assertEq(backingBefore - reserve.backing(), payout, "and paid it out of B, nothing else");
        assertEq(weth.balanceOf(address(strategy)), strategicHeld, "the Strategic position was never touched");
        assertEq(
            treasury.outstandingPrincipal(address(strategy), address(weth)),
            DEPLOYED,
            "nor its accounting"
        );
    }

    function _consolidateFloatTo(address holder) internal {
        uint256 balance = vux.balanceOf(address(this));
        if (balance > 0 && holder != address(this)) vux.transfer(holder, balance);
    }

    address internal constant BOB_LIKE = address(0xB0B);
}

interface IVuxAuthority {
    function mint(address to, uint256 amount) external;
    function burnForRedemption(address from, uint256 q) external;
}
