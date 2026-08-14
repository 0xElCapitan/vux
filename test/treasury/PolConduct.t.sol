// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 5 Task 5.6, AC-4 (the general waterfall provably
//          cannot receive POL fee yield), AC-6 (no HardReserve.redeem path)
//          FR-10.3, FR-11.2; INV-26 (no post-genesis POL VUX mint), INV-27
//          (protocol POL VUX is non-redeeming and non-voting)
//          sdd.md:L148, L318; prd.md:L490, L623-L624

import {Artifact} from "../harness/Artifact.sol";
import {Vm} from "../harness/Vm.sol";
import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {PolFixture} from "./PolFixture.sol";

/// @title PolConductTest — the POL conduct boundary, proven structurally.
/// @notice Three claims that are all of the form "the protocol *cannot*", and
///         are therefore proven against the compiled artifact and by behaviour,
///         not by reading the source:
///
///         * the general realized-revenue waterfall cannot receive POL fee yield;
///         * no code path calls `HardReserve.redeem` (FR-10.3), so protocol POL
///           VUX is non-redeeming as treasury conduct;
///         * no post-genesis mint can source POL inventory (INV-26).
contract PolConductTest is PolFixture {
    string internal constant ARTIFACT = "out/StrategicTreasury.sol/StrategicTreasury.json";

    function setUp() public {
        _deployPolSystem();
        _provisionPol();
    }

    // =========================================================================
    // The general waterfall cannot receive POL fee yield (FR-11 acceptance)
    // =========================================================================

    /// @dev The proof is arithmetic, not procedural. `allocateRevenue` can spend
    ///      only `realizedRevenue[asset]`, and no POL path ever writes that cell —
    ///      so after a harvest that demonstrably moved real value into burn and
    ///      into `B`, the distribution surface still has exactly nothing to
    ///      allocate, and asking for a single wei fails closed.
    function test_TheWaterfallCannotReceivePolFeeYield() public {
        _accrueBothFeeLegs(20 ether);

        uint256 backingBefore = reserve.backing();
        uint256 supplyBefore = vux.totalSupply();
        treasury.harvestPol();

        assertGt(reserve.backing() - backingBefore, 0, "the harvest moved real WETH value");
        assertGt(supplyBefore - vux.totalSupply(), 0, "and real VUX value");

        // ...and the waterfall still sees nothing.
        assertEq(treasury.realizedRevenue(address(weth)), 0, "no WETH revenue credit exists to allocate");
        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), 0, 1, 0, 0);

        vm.expectPartialRevert(StrategicTreasury.RevenueExceedsRealized.selector);
        treasury.allocateRevenue(address(weth), 1, 0, 0, 0);

        // The VUX leg cannot even be addressed to the waterfall: it is rejected
        // outright, because burning is the only VUX treatment that exists (F-46).
        vm.expectRevert(StrategicTreasury.VuxRevenueMustBurn.selector);
        treasury.allocateRevenue(address(vux), 0, 0, 0, 1);
    }

    /// @dev The same boundary from the treasury's own VUX side: `burnVuxRevenue`
    ///      burns the *credited revenue*, which POL fee yield never becomes. A
    ///      treasury holding POL inventory therefore cannot be made to burn that
    ///      inventory through the revenue surface.
    function test_TheRevenueBurnCannotReachPolInventory() public {
        vux.transfer(address(treasury), 1_000e18);
        uint256 inventory = vux.balanceOf(address(treasury));
        assertGt(inventory, 0, "the treasury holds POL-shaped VUX inventory");

        uint256 supplyBefore = vux.totalSupply();
        treasury.burnVuxRevenue();

        assertEq(vux.balanceOf(address(treasury)), inventory, "inventory untouched");
        assertEq(vux.totalSupply(), supplyBefore, "and nothing was burned");
    }

    // =========================================================================
    // FR-10.3 / INV-27 — no redeem path exists
    // =========================================================================

    /// @dev The type-level half, re-run against the Sprint-5 artifact: the
    ///      treasury's compilation unit still contains no declaration of any
    ///      monetary-core authority, so it cannot *name* `HardReserve.redeem`.
    ///      Adding the POL sleeve did not add a source that could.
    function test_FR10_3_ThePolSleeveAddedNoCoreAuthorityToTheSourceSet() public view {
        string[] memory sources = vm.parseJsonKeys(vm.readFile(ARTIFACT), ".metadata.sources");

        string[5] memory forbidden = [
            "src/HardReserve.sol",
            "src/Rig.sol",
            "src/VUX.sol",
            "src/interfaces/IVUX.sol",
            "src/interfaces/IVUXMintable.sol"
        ];
        for (uint256 i = 0; i < forbidden.length; i++) {
            assertFalse(
                Artifact.contains(sources, forbidden[i]),
                string.concat("the treasury must not compile against ", forbidden[i])
            );
        }

        assertTrue(Artifact.contains(sources, "src/interfaces/IVUXBurnable.sol"), "control: the self-burn only");
        assertTrue(
            Artifact.contains(sources, "vendor/uniswap-v3-core-v1.0.0/contracts/interfaces/IUniswapV3Pool.sol"),
            "control: the pool interface IS what the POL sleeve compiles against"
        );
    }

    /// @dev The bytecode half, with **both** controls.
    ///
    ///      A positive control alone is not enough here. It shows the search can
    ///      find what is there; it cannot detect the opposite failure — a search
    ///      so permissive that it finds everything, which passes every positive
    ///      control it is given and then reports fabricated call sites. So this
    ///      also carries a NEGATIVE control: a selector whose four bytes are
    ///      demonstrably present in the image (as a dispatcher entry for the
    ///      contract's own function) but which is *not* an outbound call site.
    ///      The method must find the bytes and still answer "no call site" — which
    ///      is exactly the discrimination an absence claim depends on.
    function test_FR10_3_NoCoreAuthoritySelectorIsEmittedAsAnOutboundCall() public view {
        bytes memory runtime = vm.parseJsonBytes(vm.readFile(ARTIFACT), ".deployedBytecode.object");

        // --- the claims ---
        assertFalse(_hasCallSite(runtime, bytes4(keccak256("redeem(uint256,address)"))), "no HardReserve.redeem");
        assertFalse(_hasCallSite(runtime, bytes4(keccak256("mint(address,uint256)"))), "no VUX.mint");
        assertFalse(
            _hasCallSite(runtime, bytes4(keccak256("burnForRedemption(address,uint256)"))), "no VUX.burnForRedemption"
        );
        // Zero standing approvals, stated structurally rather than by balance:
        // there is no `approve` call site anywhere, so no allowance can exist.
        assertFalse(_hasCallSite(runtime, bytes4(keccak256("approve(address,uint256)"))), "no approve call site");

        // --- positive controls: calls the POL sleeve really does make ---
        assertTrue(_hasCallSite(runtime, bytes4(keccak256("burn(uint256)"))), "control: the F-46 self-burn IS called");
        assertTrue(
            _hasCallSite(runtime, bytes4(keccak256("mint(address,int24,int24,uint128,bytes)"))),
            "control: pool.mint IS called"
        );
        assertTrue(
            _hasCallSite(runtime, bytes4(keccak256("burn(int24,int24,uint128)"))), "control: pool.burn IS called"
        );
        assertTrue(
            _hasCallSite(runtime, bytes4(keccak256("collect(address,int24,int24,uint128,uint128)"))),
            "control: pool.collect IS called"
        );
        assertTrue(
            _hasCallSite(runtime, bytes4(keccak256("swap(address,bool,int256,uint160,bytes)"))),
            "control: pool.swap IS called"
        );
        assertTrue(_hasCallSite(runtime, bytes4(keccak256("positions(bytes32)"))), "control: pool.positions IS read");

        // --- negative control: present in the image, but not as a call site ---
        bytes4 ownSelector = bytes4(keccak256("harvestPol()"));
        assertTrue(
            Artifact.containsBytes(runtime, abi.encodePacked(ownSelector)),
            "the negative control's bytes ARE in the image"
        );
        assertFalse(
            _hasCallSite(runtime, ownSelector),
            "negative control: the treasury's own entry point is not an outbound call site"
        );
    }

    /// @dev True when `runtime` contains the `PUSH4 (sel >> s); PUSH1 (0xe0+s);
    ///      SHL` idiom for any shift `s` that `sel` can survive losslessly.
    ///
    ///      Three constraints keep this from degenerating into "finds anything",
    ///      and all three are load-bearing: the search is **anchored** on the full
    ///      three-instruction idiom rather than on the bare constant; the shift is
    ///      bounded to the eight the compiler can actually emit for a four-byte
    ///      value; and a shift that would lose a set bit is skipped, because the
    ///      compiler cannot use it.
    function _hasCallSite(bytes memory runtime, bytes4 selector) private pure returns (bool) {
        uint32 sel = uint32(selector);
        for (uint256 s = 0; s < 8; s++) {
            uint32 shifted = sel >> uint32(s);
            if (shifted << uint32(s) != sel) continue; // lossy: the compiler cannot use this shift
            bytes memory pattern =
                abi.encodePacked(bytes1(0x63), bytes4(shifted), bytes1(0x60), bytes1(uint8(0xe0 + s)), bytes1(0x1b));
            if (Artifact.containsBytes(runtime, pattern)) return true;
        }
        return false;
    }

    /// @dev INV-27, behaviourally: every POL operation is exercised while the
    ///      treasury holds VUX, and across all of them the Reserve records **no
    ///      redemption at all**. `B` only ever rises, and only by the VYRF fee
    ///      leg — there is no conduct by which protocol POL VUX becomes a
    ///      redemption claim.
    function test_INV27_ProtocolPolVuxNeverRedeems() public {
        uint256 backingBefore = reserve.backing();
        vux.transfer(address(treasury), 1_000e18);
        weth.mint(address(treasury), 60 ether);

        vm.recordLogs();
        treasury.buyVuxForPol(5 ether, 0, _limitFor(!vuxIsToken0));
        treasury.increasePol(500e18, 10 ether);
        treasury.harvestPol();
        treasury.decreasePol(_polLiquidity() / 4);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(_countLogs(logs, keccak256("Redeemed(address,address,uint256,uint256,uint256,uint256)")), 0, "no redemption occurred anywhere in the POL lifecycle");
        assertGe(reserve.backing(), backingBefore, "B never fell");
        assertGt(vux.balanceOf(address(treasury)), 0, "and the treasury still holds protocol POL VUX");
    }

    /// @dev INV-27's other half: the treasury has no staking surface at all, so
    ///      protocol POL VUX carries zero LSG weight under any module (F-38).
    function test_INV27_ProtocolPolVuxIsNonVoting() public view {
        string[] memory surface = vm.parseJsonKeys(vm.readFile(ARTIFACT), ".methodIdentifiers");

        assertFalse(Artifact.contains(surface, "stake(uint256)"), "the treasury cannot stake");
        assertFalse(Artifact.contains(surface, "setPreference(address[],uint16[])"), "nor express a preference");
        assertFalse(Artifact.contains(surface, "claim(uint64[])"), "nor claim signaler rewards");
        assertTrue(Artifact.contains(surface, "activateLSG(address)"), "control: the activation authority IS present");
    }

    // =========================================================================
    // INV-26 — no post-genesis mint can source POL inventory
    // =========================================================================

    /// @dev The authority is immutable and caller-scoped: even the treasury, the
    ///      protocol's only privileged contract, is refused by the token.
    function test_INV26_TheTreasuryCannotMintVuxForPol() public {
        vm.prank(address(treasury));
        vm.expectRevert(bytes4(keccak256("NotRig()")));
        IVuxMintAuthority(address(vux)).mint(address(treasury), 1);
    }

    /// @dev And the whole POL sleeve, exercised end to end, adds not one wei of
    ///      supply: every unit of VUX that reaches the position was already in
    ///      circulation before the operation started.
    function test_INV26_NoPolOperationEverIncreasesSupply() public {
        uint256 supply0 = vux.totalSupply();

        weth.mint(address(treasury), 50 ether);
        treasury.buyVuxForPol(10 ether, 0, _limitFor(!vuxIsToken0));
        assertEq(vux.totalSupply(), supply0, "buyVuxForPol minted nothing");

        treasury.increasePol(vux.balanceOf(address(treasury)), 20 ether);
        assertEq(vux.totalSupply(), supply0, "increasePol minted nothing");

        _accrueBothFeeLegs(10 ether);
        treasury.decreasePol(_polLiquidity() / 2);
        assertLt(vux.totalSupply(), supply0, "the only supply move was the VYRF burn, which is downward");
    }
}

interface IVuxMintAuthority {
    function mint(address to, uint256 amount) external;
}
