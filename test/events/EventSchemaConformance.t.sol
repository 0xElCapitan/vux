// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-14.1-14.4 (observability), sdd.md:L478-L542 (accepted event schema)
//          sprint.md Sprint 6 Task 6.3 ("every FR-14.1-14.4 observable mapped to
//          an emit site")

import {BaseTest} from "../harness/BaseTest.sol";
import {Artifact} from "../harness/Artifact.sol";

/// @title EventSchemaConformanceTest — the accepted schema, checked against the
///        compiled images.
/// @notice Task 6.3's audit maps every FR-14.1-14.4 observable to an emit site.
///         The written mapping lives at
///         `grimoires/loa/a2a/sprint-6/evidence/event-completeness-audit.md`;
///         this file is the mechanical half, so the mapping cannot silently rot
///         when a later sprint edits a contract.
///
///         Each accepted event signature from sdd.md:L478-L542 is hashed to its
///         `topic0` and located as a 32-byte constant inside the compiled image.
///         A non-anonymous `emit` must push its `topic0`, so presence of the
///         constant is presence of an emit site; absence means the event was
///         renamed, retyped, dropped, or never wired.
///
///         The check is deliberately signature-exact. A field widened from
///         `uint64` to `uint256`, or two fields transposed, changes the hash and
///         fails here — which is the failure an indexer would otherwise discover
///         in production, as a decode that silently yields wrong numbers.
contract EventSchemaConformanceTest is BaseTest {
    string internal constant RIG = "out/Rig.sol/Rig.json";
    string internal constant RESERVE = "out/HardReserve.sol/HardReserve.json";
    string internal constant TREASURY = "out/StrategicTreasury.sol/StrategicTreasury.json";
    string internal constant POOL_DEPLOYER = "out-v3core/VuxPoolDeployer.sol/VuxPoolDeployer.json";
    string internal constant TOKEN = "out/VUX.sol/VUX.json";

    function _image(string memory artifact, bool runtime) private view returns (bytes memory) {
        string memory key = runtime ? ".deployedBytecode.object" : ".bytecode.object";
        return vm.parseJsonBytes(vm.readFile(artifact), key);
    }

    function _hasTopic(string memory artifact, bool runtime, string memory sig) private view returns (bool) {
        return Artifact.containsBytes(_image(artifact, runtime), abi.encodePacked(keccak256(bytes(sig))));
    }

    /// @dev An accepted event must have an emit site in the deployed runtime.
    function _assertEmitted(string memory artifact, string memory sig) private view {
        assertTrue(_hasTopic(artifact, true, sig), string.concat("no emit site for: ", sig));
    }

    // -----------------------------------------------------------------------
    // FR-14.1 — the settlement record
    // -----------------------------------------------------------------------

    function test_RigEmitsTheAcceptedSettlementRecord() public view {
        _assertEmitted(
            RIG,
            "Settled(uint64,address,address,bool,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)"
        );
    }

    /// @dev Negative control. A near-miss signature — the same name, a truncated
    ///      field list — must NOT be found, or the search is matching something
    ///      other than what it claims to.
    function test_ANearMissSettlementSignatureIsAbsent() public view {
        assertFalse(_hasTopic(RIG, true, "Settled(uint64,address,address)"), "near-miss signature matched");
        assertFalse(
            _hasTopic(
                RIG,
                true,
                "Settled(uint256,address,address,bool,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)"
            ),
            "a widened epochId matched: the check is not signature-exact"
        );
    }

    // -----------------------------------------------------------------------
    // FR-14.1 — Reserve records
    // -----------------------------------------------------------------------

    function test_ReserveEmitsTheAcceptedRedemptionRecord() public view {
        _assertEmitted(RESERVE, "Redeemed(address,address,uint256,uint256,uint256,uint256)");
    }

    /// @dev `PreGenesisWethSanitized` is constructor-only by design (sdd.md:L498),
    ///      so its emit site lives in the creation image and must be absent from
    ///      the runtime — the same claim `HardReserveSurface.t.sol` makes about
    ///      the sanitization path's capability, here about its record.
    function test_SanitizationRecordExistsOnlyInTheCreationImage() public view {
        string memory sig = "PreGenesisWethSanitized(uint256)";
        assertTrue(_hasTopic(RESERVE, false, sig), "no emit site in the creation image");
        assertFalse(_hasTopic(RESERVE, true, sig), "the constructor-only record survived into runtime");
    }

    // -----------------------------------------------------------------------
    // FR-14.2 — Strategic / POL accounting at product-semantic level
    // -----------------------------------------------------------------------

    function test_TreasuryEmitsEveryAcceptedStrategicRecord() public view {
        string[14] memory accepted = [
            "StrategicInflow(uint8,address,uint256)",
            "StrategicOutflow(uint8,address,address,uint256)",
            "PolPositionChanged(int8,uint256,uint256,uint128)",
            "VyrfHarvest(uint256,uint256)",
            "ReturnedFromStrategy(address,address,uint256,uint256)",
            "YieldHarvested(address,address,uint256,uint256)",
            "UnitsRedeemed(address,uint256,uint256,uint256,uint256,uint256)",
            "StrategyLossRealized(address,address,uint256)",
            "RevenueAllocated(address,uint256,uint256,uint256,uint256)",
            "SignalerProgramFunded(address,uint256,uint64,uint64)",
            "VuxRevenueBurned(uint256)",
            "VuxPurchasedForPol(uint256,uint256)",
            "OpsRecipientSet(address)",
            "StrategyRemoved(address,bool)"
        ];
        for (uint256 i = 0; i < accepted.length; i++) {
            _assertEmitted(TREASURY, accepted[i]);
        }
    }

    // -----------------------------------------------------------------------
    // FR-14.3 — LSG activation state, admitted identity, bounded signal
    // -----------------------------------------------------------------------

    function test_TreasuryEmitsEveryAcceptedLsgRecord() public view {
        _assertEmitted(TREASURY, "LSGActivated(address)");
        _assertEmitted(TREASURY, "LSGDeactivated(address)");
        _assertEmitted(TREASURY, "StrategyAdmitted(address,address,uint256,uint8,uint64)");
        _assertEmitted(TREASURY, "SignalConsumed(uint64,uint256,address[],uint256[])");
    }

    /// @dev "Responsible authority" (FR-14.3) is observable through the pinned
    ///      OpenZeppelin `AccessControl` role records, which is why the treasury
    ///      inherits them rather than declaring a VUX-original substitute.
    function test_TreasuryEmitsTheInheritedRoleRecords() public view {
        _assertEmitted(TREASURY, "RoleGranted(bytes32,address,address)");
        _assertEmitted(TREASURY, "RoleRevoked(bytes32,address,address)");
    }

    // -----------------------------------------------------------------------
    // Genesis infrastructure
    // -----------------------------------------------------------------------

    function test_PoolDeployerEmitsTheCanonicalPoolRecord() public view {
        _assertEmitted(POOL_DEPLOYER, "CanonicalPoolDeployed(address,address,address,uint24,int24)");
    }

    // -----------------------------------------------------------------------
    // The token declares no event of its own (sdd.md:L37-L42 of VUX.sol)
    // -----------------------------------------------------------------------

    /// @dev Supply changes ride on ERC-20 `Transfer` to/from the zero address,
    ///      and their cause rides on the co-emitted event of the contract that
    ///      caused them. The token adding a `Minted`/`Burned` record of its own
    ///      would give an indexer a second, competing source for the same fact —
    ///      exactly the ambiguity FR-14 rules out. Both the presence of the
    ///      ERC-20 record and the absence of the dropped upstream ones are
    ///      asserted, so this is not a vacuous check.
    function test_TokenCarriesSupplyChangesOnTransferAndDeclaresNothingElse() public view {
        _assertEmitted(TOKEN, "Transfer(address,address,uint256)");

        assertFalse(_hasTopic(TOKEN, true, "Unit__Minted(address,uint256)"), "an upstream mint record survived");
        assertFalse(_hasTopic(TOKEN, true, "Unit__Burned(address,uint256)"), "an upstream burn record survived");
        assertFalse(_hasTopic(TOKEN, true, "Minted(address,uint256)"), "a token-declared mint record exists");
        assertFalse(_hasTopic(TOKEN, true, "Burned(address,uint256)"), "a token-declared burn record exists");
    }
}
