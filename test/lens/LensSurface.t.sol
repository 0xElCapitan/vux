// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sdd.md:L706 (Lens is read-only), sprint.md Sprint 6 Task 6.2
//          ("no authority, custody, approvals, writes, or monetary state")

import {BaseTest} from "../harness/BaseTest.sol";
import {Artifact} from "../harness/Artifact.sol";

/// @title LensSurfaceTest — "read-only" proven against bytes, not against prose.
/// @notice `Lens` claims to be a pure truth surface: no authority, no custody,
///         no approvals, no writes, no monetary state. Every one of those is an
///         absence, and an absence is exactly what a mistake also looks like
///         when the capability arrives through an inherited base, a fallback, or
///         a widened interface. So the claims are asserted against the compiled
///         artifact — the method-identifier table for the surface, and an
///         opcode-accurate walk of the runtime image for the capabilities.
///
///         Every absence assertion is paired with a positive control taken from
///         `Rig`'s runtime, which certainly does write storage, move value, and
///         emit logs. A detector that finds nothing because it is broken looks
///         identical to one that finds nothing because nothing is there; the
///         control tells the two apart.
contract LensSurfaceTest is BaseTest {
    string internal constant LENS_ARTIFACT = "out/Lens.sol/Lens.json";
    string internal constant RIG_ARTIFACT = "out/Rig.sol/Rig.json";

    // Opcodes. `STATICCALL` is the only outbound-call form a `view` may compile
    // to, and it is the positive control for the Lens's own image.
    uint8 internal constant SSTORE = 0x55;
    uint8 internal constant CALL = 0xF1;
    uint8 internal constant CALLCODE = 0xF2;
    uint8 internal constant DELEGATECALL = 0xF4;
    uint8 internal constant STATICCALL = 0xFA;
    uint8 internal constant CREATE = 0xF0;
    uint8 internal constant CREATE2 = 0xF5;
    uint8 internal constant SELFDESTRUCT = 0xFF;
    uint8 internal constant LOG0 = 0xA0;

    function _runtime(string memory artifact) private view returns (bytes memory) {
        return Artifact.stripMetadata(vm.parseJsonBytes(vm.readFile(artifact), ".deployedBytecode.object"));
    }

    /// @dev The complete accepted external surface (sdd.md:L708-L715) plus the
    ///      two public constants/immutables. Nothing else may exist.
    function _acceptedAbi() private pure returns (string[] memory abi_) {
        abi_ = new string[](7);
        abi_[0] = "rawClockLimit()";
        abi_[1] = "estimateIfDisplacedNow()";
        abi_[2] = "hardStats()";
        abi_[3] = "wethNeededForFullQraw()";
        abi_[4] = "strategicContributed()";
        abi_[5] = "RIG()";
        abi_[6] = "RAY()";
    }

    // -----------------------------------------------------------------------
    // The surface is exactly the five accepted views (plus two constants)
    // -----------------------------------------------------------------------

    function test_ExternalSurfaceIsExactlyTheAcceptedViews() public view {
        string[] memory actual = vm.parseJsonKeys(vm.readFile(LENS_ARTIFACT), ".methodIdentifiers");
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

    /// @dev Redundant with the exact-set assertion by construction, and kept
    ///      anyway: the audit checklist is a list of these names, and a reviewer
    ///      should be able to match it to assertions one-for-one.
    function test_NoAuthorityCustodyOrWriteSurfaceExists() public view {
        string[] memory actual = vm.parseJsonKeys(vm.readFile(LENS_ARTIFACT), ".methodIdentifiers");
        string[16] memory forbidden = [
            "owner()",
            "transferOwnership(address)",
            "grantRole(bytes32,address)",
            "pause()",
            "upgradeTo(address)",
            "initialize(address)",
            "sweep(address)",
            "withdraw(uint256)",
            "rescue(address,uint256)",
            "approve(address,uint256)",
            "transfer(address,uint256)",
            "transferFrom(address,address,uint256)",
            "execute(address,bytes)",
            "take(uint256)",
            "mint(address,uint256)",
            "redeem(uint256,address)"
        ];
        for (uint256 i = 0; i < forbidden.length; i++) {
            assertFalse(
                Artifact.contains(actual, forbidden[i]), string.concat("prohibited surface present: ", forbidden[i])
            );
        }
    }

    // -----------------------------------------------------------------------
    // The runtime image cannot write, move value, deploy, or log
    // -----------------------------------------------------------------------

    /// @dev `SSTORE` absent: the contract has no storage to write. Its single
    ///      state variable is `immutable`, which lives in code, not storage — so
    ///      "no monetary state" is a property of the image, not a convention.
    function test_RuntimeNeverWritesStorage() public view {
        assertFalse(Artifact.hasOpcode(_runtime(LENS_ARTIFACT), SSTORE), "Lens runtime contains SSTORE");
        assertTrue(Artifact.hasOpcode(_runtime(RIG_ARTIFACT), SSTORE), "positive control: Rig runtime does SSTORE");
    }

    /// @dev `CALL` absent, `STATICCALL` present: every outbound read is a
    ///      state-preserving call. A `CALL` is what a token transfer, an
    ///      approval, or any value movement would have to compile to, and there
    ///      is not one in the image.
    function test_RuntimeMakesOnlyStaticCalls() public view {
        bytes memory lens = _runtime(LENS_ARTIFACT);

        assertTrue(Artifact.hasOpcode(lens, STATICCALL), "Lens reads via STATICCALL (control: the walk finds opcodes)");
        assertFalse(Artifact.hasOpcode(lens, CALL), "Lens runtime contains CALL");
        assertFalse(Artifact.hasOpcode(lens, CALLCODE), "Lens runtime contains CALLCODE");
        assertFalse(Artifact.hasOpcode(lens, DELEGATECALL), "Lens runtime contains DELEGATECALL");

        assertTrue(Artifact.hasOpcode(_runtime(RIG_ARTIFACT), CALL), "positive control: Rig runtime does CALL");
    }

    function test_RuntimeCannotDeployOrSelfDestruct() public view {
        bytes memory lens = _runtime(LENS_ARTIFACT);
        assertFalse(Artifact.hasOpcode(lens, CREATE), "Lens runtime contains CREATE");
        assertFalse(Artifact.hasOpcode(lens, CREATE2), "Lens runtime contains CREATE2");
        assertFalse(Artifact.hasOpcode(lens, SELFDESTRUCT), "Lens runtime contains SELFDESTRUCT");
    }

    /// @dev No `LOG*`: `Lens` emits no events at all. An indexer must never be
    ///      able to mistake a lens reading for a protocol fact, and the cleanest
    ///      way to guarantee that is for the contract to have nothing to say.
    function test_RuntimeEmitsNoEvents() public view {
        bytes memory lens = _runtime(LENS_ARTIFACT);
        for (uint8 op = LOG0; op <= LOG0 + 4; op++) {
            assertFalse(Artifact.hasOpcode(lens, op), "Lens runtime contains a LOG opcode");
        }
        assertTrue(Artifact.hasOpcode(_runtime(RIG_ARTIFACT), LOG0 + 4), "positive control: Rig runtime does LOG4");
    }
}
