// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: INV-14, INV-17, FR-7.2, FR-7.3
//          sprint.md Sprint 2 AC-4, AC-5

import {BaseTest} from "../harness/BaseTest.sol";
import {Artifact} from "../harness/Artifact.sol";
import {Vm} from "../harness/Vm.sol";
import {MockWeth} from "../mocks/MockWeth.sol";
import {HardReserve} from "../../src/HardReserve.sol";
import {VUX} from "../../src/VUX.sol";

/// @title HardReserveSurfaceTest — structural absence, proven against bytes.
/// @notice Two claims are load-bearing for holder safety and neither can be
///         established by reading the source:
///
///         1. the deployed contract's entire state-changing external surface is
///            `redeem`, and
///         2. the constructor's WETH transfer-out capability does not survive
///            into the deployed runtime.
///
///         "There is no sweep function in the source" is something a reviewer
///         can see for themselves; it is also exactly what a mistake would look
///         like if the capability arrived through inheritance, a fallback, or a
///         `delegatecall`. So both claims are asserted against the compiled
///         artifact: the method-identifier table for the surface, and an
///         opcode-accurate walk of the runtime image for the capability. Every
///         absence assertion is paired with a positive control, because a
///         search that finds nothing because it is broken looks identical to one
///         that finds nothing because nothing is there.
///
///         `tools/provenance/inspect-runtime-surface.sh` reproduces the same
///         findings with an independent implementation (jq + awk, no Solidity,
///         no Foundry test runner) and prints them as an inspectable report.
contract HardReserveSurfaceTest is BaseTest {
    string internal constant ARTIFACT = "out/HardReserve.sol/HardReserve.json";

    /// @dev The 32-byte marker of the sanitization path. It is a PUSH32 constant
    ///      wherever the emitting code lives, so it is present in init code and
    ///      must be absent from runtime code.
    bytes32 internal constant SANITIZED_TOPIC = keccak256("PreGenesisWethSanitized(uint256)");

    address internal constant RIG = address(0xA11CE);

    function _acceptedAbi() private pure returns (string[] memory abi_) {
        abi_ = new string[](6);
        abi_[0] = "redeem(uint256,address)"; // the ONLY state-changing function
        abi_[1] = "backing()";
        abi_[2] = "previewRedeem(uint256)";
        abi_[3] = "weth()";
        abi_[4] = "vux()";
        abi_[5] = "S_MIN()";
    }

    function _runtimeBytecode() private view returns (bytes memory) {
        return vm.parseJsonBytes(vm.readFile(ARTIFACT), ".deployedBytecode.object");
    }

    function _creationBytecode() private view returns (bytes memory) {
        return vm.parseJsonBytes(vm.readFile(ARTIFACT), ".bytecode.object");
    }

    /// @dev Deploy a Reserve whose address is prefunded with `prefund` WETH
    ///      before its code exists — the adversarial case the sanitization
    ///      defends against (sdd.md:L177).
    function _deployPrefunded(uint256 prefund)
        private
        returns (HardReserve reserve, MockWeth weth, address predictedReserve)
    {
        weth = new MockWeth();

        uint256 nonce = uint256(vm.getNonce(address(this)));
        predictedReserve = vm.computeCreateAddress(address(this), nonce);
        address predictedVux = vm.computeCreateAddress(address(this), nonce + 1);

        if (prefund > 0) weth.mint(predictedReserve, prefund);

        reserve = new HardReserve(address(weth), predictedVux);
        assertEq(address(reserve), predictedReserve, "reserve landed at the prefunded address");
    }

    // -----------------------------------------------------------------------
    // Constructor-time contamination sanitization (AC-5)
    // -----------------------------------------------------------------------

    /// @dev Fuzzed across the whole plausible range including amounts far larger
    ///      than genesis capital: the accepted rehearsal requires the defence to
    ///      hold against "a very large amount (not dust)", so the property must
    ///      not be demonstrated on a convenient value.
    function testFuzz_ConstructorSanitizesAnyPreExistingWeth(uint256 prefund) public {
        prefund = bound(prefund, 1, type(uint128).max);

        (HardReserve reserve, MockWeth weth,) = _deployPrefunded(prefund);

        assertEq(weth.balanceOf(address(reserve)), 0, "the Reserve is born empty");
        assertEq(reserve.backing(), 0, "B starts at exactly zero, so genesis can land exactly B0");
        assertEq(weth.balanceOf(address(this)), prefund, "the full amount went to the creator, not a parameter");
    }

    function test_SanitizationEmitsTheExactAmount() public {
        uint256 prefund = 12_345 ether;

        vm.recordLogs();
        (HardReserve reserve,,) = _deployPrefunded(prefund);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 sanitizationEvents;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(reserve) || logs[i].topics[0] != SANITIZED_TOPIC) continue;
            sanitizationEvents++;
            assertEq(abi.decode(logs[i].data, (uint256)), prefund, "evented amount equals the sanitized amount");
        }
        assertEq(sanitizationEvents, 1, "exactly one PreGenesisWethSanitized");
    }

    /// @dev The event must distinguish attacker donations from founder capital,
    ///      so it must NOT fire on a clean deployment. Log-exhaustive: any
    ///      emission at all would be caught.
    function test_CleanDeploymentEmitsNoSanitizationEvent() public {
        vm.recordLogs();
        (HardReserve reserve,,) = _deployPrefunded(0);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(reserve) && logs[i].topics[0] == SANITIZED_TOPIC) {
                fail("a clean deployment emitted PreGenesisWethSanitized");
            }
        }
        assertEq(reserve.backing(), 0, "born empty either way");
    }

    /// @dev The born-empty `require` is not decoration: a token that reports a
    ///      successful transfer without moving the balance must abort the
    ///      deployment rather than silently redefine `B0`.
    function test_ConstructionAbortsIfTheReserveCannotBeBornEmpty() public {
        MockWeth weth = new MockWeth();

        uint256 nonce = uint256(vm.getNonce(address(this)));
        address predictedReserve = vm.computeCreateAddress(address(this), nonce);
        address predictedVux = vm.computeCreateAddress(address(this), nonce + 1);

        weth.mint(predictedReserve, 1 ether);
        weth.setSilentlyDropTransfers(true);

        vm.expectRevert(abi.encodeWithSelector(HardReserve.NotBornEmpty.selector, 1 ether));
        new HardReserve(address(weth), predictedVux);
    }

    function test_ConstructorRejectsZeroDependencies() public {
        vm.expectRevert(HardReserve.ZeroAddress.selector);
        new HardReserve(address(0), address(0xBEEF));
    }

    /// @dev End-to-end: prefunding cannot alter the physical genesis backing.
    ///      An attacker sends a very large amount to the predicted address;
    ///      genesis then deposits exactly `B0`; the Reserve must hold exactly
    ///      `B0` (sdd.md:L860 — "must end with WETH.balanceOf(reserve) == B0
    ///      exactly").
    function test_PrefundingCannotDistortTheGenesisBackingTarget() public {
        uint256 attackerDonation = 1_000_000 ether;
        uint256 b0 = 909 ether;

        (HardReserve reserve, MockWeth weth,) = _deployPrefunded(attackerDonation);

        // The creator (structurally GenesisDeployer) now holds the sanitized
        // WETH; it becomes unattributed Strategic inventory at the deployer's
        // closing sweep (Sprint 7), never Hard backing and never mint credit.
        assertEq(weth.balanceOf(address(this)), attackerDonation, "sanitized amount is held by the creator");

        weth.mint(address(this), b0);
        weth.transfer(address(reserve), b0);

        assertEq(reserve.backing(), b0, "genesis lands on exactly B0 despite the donation");
    }

    // -----------------------------------------------------------------------
    // Runtime bytecode: the sanitization capability does not survive (AC-5)
    // -----------------------------------------------------------------------

    function test_SanitizationMarkerIsInInitCodeAndNotInRuntimeCode() public view {
        bytes memory marker = abi.encodePacked(SANITIZED_TOPIC);

        assertTrue(
            Artifact.containsBytes(_creationBytecode(), marker),
            "positive control: the sanitization path IS present in the creation bytecode"
        );
        assertFalse(
            Artifact.containsBytes(_runtimeBytecode(), marker),
            "the sanitization path is absent from the deployed runtime bytecode"
        );
    }

    /// @dev Structural absences that a `delegatecall`, a proxy, a factory, or a
    ///      `selfdestruct` would each betray at the opcode level. Metadata is
    ///      stripped first so a stray byte inside the solc CBOR tail cannot be
    ///      mistaken for an instruction; the positive controls prove the walk is
    ///      seeing real opcodes rather than silently scanning nothing.
    function test_RuntimeContainsNoUpgradeDestructionOrDeploymentOpcode() public view {
        bytes memory runtime = Artifact.stripMetadata(_runtimeBytecode());

        assertGt(runtime.length, 0, "runtime bytecode is non-empty after metadata stripping");
        assertGt(Artifact.countOpcode(runtime, Artifact.OP_CALL), 0, "positive control: CALL is found (WETH payout)");
        assertGt(
            Artifact.countOpcode(runtime, Artifact.OP_STATICCALL), 0, "positive control: STATICCALL is found (balanceOf)"
        );

        assertFalse(Artifact.hasOpcode(runtime, Artifact.OP_DELEGATECALL), "no DELEGATECALL: no proxy or upgrade path");
        assertFalse(Artifact.hasOpcode(runtime, Artifact.OP_CALLCODE), "no CALLCODE");
        assertFalse(Artifact.hasOpcode(runtime, Artifact.OP_SELFDESTRUCT), "no SELFDESTRUCT");
        assertFalse(Artifact.hasOpcode(runtime, Artifact.OP_CREATE), "no CREATE: deploys no successor");
        assertFalse(Artifact.hasOpcode(runtime, Artifact.OP_CREATE2), "no CREATE2: deploys no successor");
    }

    /// @dev Guards the metadata stripper itself. If `stripMetadata` ever removed
    ///      the whole image (or nothing), the absence assertions above would
    ///      pass vacuously — the same "green because it is looking at nothing"
    ///      failure the source-boundary gate had to be guarded against.
    function test_MetadataStrippingRemovesATailAndNotTheProgram() public view {
        bytes memory full = _runtimeBytecode();
        bytes memory stripped = Artifact.stripMetadata(full);

        assertLt(stripped.length, full.length, "a metadata tail was identified and removed");
        assertGt(stripped.length, (full.length * 9) / 10, "and only a tail: the program body survived");
    }

    // -----------------------------------------------------------------------
    // External surface enumeration (AC-4)
    // -----------------------------------------------------------------------

    function test_ExternalSurfaceIsExactlyRedeemPlusViews() public view {
        string[] memory actual = vm.parseJsonKeys(vm.readFile(ARTIFACT), ".methodIdentifiers");
        string[] memory accepted = _acceptedAbi();

        assertEq(actual.length, accepted.length, "external function count");
        for (uint256 i = 0; i < accepted.length; i++) {
            assertTrue(Artifact.contains(actual, accepted[i]), string.concat("missing: ", accepted[i]));
        }
        for (uint256 i = 0; i < actual.length; i++) {
            assertTrue(
                Artifact.contains(accepted, actual[i]), string.concat("unexpected external function: ", actual[i])
            );
        }
    }

    /// @dev The FR-7.2 / INV-14 prohibition list, name by name. Redundant with
    ///      the exact-set assertion by construction — and kept anyway, because
    ///      the audit checklist is a list of these names and a reviewer should
    ///      be able to match it to assertions one-for-one.
    function test_NoProhibitedAuthoritySurfaceExists() public view {
        string[] memory actual = vm.parseJsonKeys(vm.readFile(ARTIFACT), ".methodIdentifiers");
        string[16] memory forbidden = [
            "owner()",
            "transferOwnership(address)",
            "renounceOwnership()",
            "grantRole(bytes32,address)",
            "pause()",
            "unpause()",
            "upgradeTo(address)",
            "upgradeToAndCall(address,bytes)",
            "initialize(address,address)",
            "sweep(address)",
            "withdraw(uint256)",
            "rescue(address,uint256)",
            "approve(address,uint256)",
            "transfer(address,uint256)",
            "execute(address,bytes)",
            "migrate(address)"
        ];
        for (uint256 i = 0; i < forbidden.length; i++) {
            assertFalse(
                Artifact.contains(actual, forbidden[i]), string.concat("surface must not exist: ", forbidden[i])
            );
        }
    }

    function test_NoEtherCanBeSentToTheReserve() public {
        (HardReserve reserve,,) = _deployPrefunded(0);
        vm.deal(address(this), 10 ether);

        // No receive hook.
        (bool plain,) = address(reserve).call{value: 1 ether}("");
        assertFalse(plain, "no receive(): a bare value transfer must revert");

        // No fallback.
        (bool unknown,) = address(reserve).call{value: 1 ether}(abi.encodeWithSignature("nope()"));
        assertFalse(unknown, "no fallback(): an unknown selector must revert");

        // And the one state-changing function is not payable.
        (bool payableRedeem,) =
            address(reserve).call{value: 1 ether}(abi.encodeWithSignature("redeem(uint256,address)", 0, address(this)));
        assertFalse(payableRedeem, "redeem is not payable");

        assertEq(address(reserve).balance, 0, "the Reserve holds no ether");
    }

    /// @dev The `S_MIN` seed is held by a contract with no function that can
    ///      move an ERC-20 it owns. The absence of `transfer`/`approve` from the
    ///      surface above IS that guarantee; this pins the balance it protects.
    function test_ReserveHoldsTheSeedAndHasNoWayToMoveIt() public {
        MockWeth w = new MockWeth();
        uint256 nonce = uint256(vm.getNonce(address(this)));
        HardReserve reserve = new HardReserve(address(w), vm.computeCreateAddress(address(this), nonce + 1));
        VUX token = new VUX(RIG, address(reserve));

        assertEq(token.balanceOf(address(reserve)), reserve.S_MIN(), "the Reserve holds exactly the seed");

        (bool moved,) = address(reserve).call(
            abi.encodeWithSignature("transfer(address,uint256)", address(this), reserve.S_MIN())
        );
        assertFalse(moved, "the Reserve exposes no token-moving entry point");
        assertEq(token.balanceOf(address(reserve)), reserve.S_MIN(), "seed intact");
    }
}
