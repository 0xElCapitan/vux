// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 4 AC-1 (no setPool/initializer), AC-4 (exactly four
//          legs; no toMarketInfra / marketInfraBudget), AC-5 (no stored ratio
//          constant), INV-30 (no mark/NAV cell), FR-12.4, FR-9.3
//          sdd.md:L140, L308-L318; Appendix F note F-2

import {Artifact} from "../harness/Artifact.sol";
import {BaseTest} from "../harness/BaseTest.sol";

/// @title TreasurySurfaceTest — what does not exist, proven against the artifact.
/// @notice Sprint 4's safety argument is mostly negative: principal cannot become
///         revenue *because there is no path*, the future waterfall cannot be
///         frozen *because there is no constant*, and the deleted
///         market-infrastructure leg is gone *because no symbol carries it*.
///         Those are claims about the compiled contract, and a reviewer reading
///         the source can already see the source — so they are asserted against
///         the method-identifier table and the deployed bytecode instead.
///
///         Every absence assertion is paired with a positive control, because a
///         search that finds nothing because it is broken looks identical to one
///         that finds nothing because nothing is there.
contract TreasurySurfaceTest is BaseTest {
    string internal constant ARTIFACT = "out/StrategicTreasury.sol/StrategicTreasury.json";

    function _surface() private view returns (string[] memory) {
        return vm.parseJsonKeys(vm.readFile(ARTIFACT), ".methodIdentifiers");
    }

    /// @dev The complete accepted external surface (sdd.md:L717-L764 minus the
    ///      Sprint-5 POL sleeve, plus the pinned OZ `AccessControl` members the
    ///      SDD explicitly keeps for Safe-held role rotation, sdd.md:L726-L727).
    function _acceptedSurface() private pure returns (string[] memory abi_) {
        abi_ = new string[](44);
        // AccessControl (pinned OZ v5.2.0)
        abi_[0] = "DEFAULT_ADMIN_ROLE()";
        abi_[1] = "getRoleAdmin(bytes32)";
        abi_[2] = "grantRole(bytes32,address)";
        abi_[3] = "hasRole(bytes32,address)";
        abi_[4] = "renounceRole(bytes32,address)";
        abi_[5] = "revokeRole(bytes32,address)";
        abi_[6] = "supportsInterface(bytes4)";
        // Constants and immutable identity
        abi_[7] = "ADMISSION_DELAY()";
        abi_[8] = "OPERATOR_ROLE()";
        abi_[9] = "weth()";
        abi_[10] = "vux()";
        abi_[11] = "hardReserve()";
        abi_[12] = "poolDeployer()";
        abi_[13] = "pool()";
        abi_[14] = "token0()";
        abi_[15] = "token1()";
        abi_[16] = "feeTier()";
        abi_[17] = "tickLower()";
        abi_[18] = "tickUpper()";
        // Accounting cells (sdd.md:L140 — the complete set)
        abi_[19] = "outstandingPrincipal(address,address)";
        abi_[20] = "unitsHeld(address)";
        abi_[21] = "realizedRevenue(address)";
        abi_[22] = "signalerBudget(address)";
        abi_[23] = "opsRecipient()";
        abi_[24] = "lsgModule()";
        abi_[25] = "allocationCount()";
        // Admission registry
        abi_[26] = "admitStrategy(address,address,uint256,uint8)";
        abi_[27] = "removeStrategy(address,bool)";
        abi_[28] = "deployToStrategy(address,address,uint256)";
        abi_[29] = "recallFromStrategy(address,address,uint256)";
        // Flow primitives
        abi_[30] = "returnFor(address,address,uint256)";
        abi_[31] = "harvestYield(address)";
        abi_[32] = "redeemUnits(address,uint256,uint256)";
        abi_[33] = "closeStrategy(address)";
        // Distribution surface
        abi_[34] = "allocateRevenue(address,uint256,uint256,uint256,uint256)";
        abi_[35] = "burnVuxRevenue()";
        abi_[36] = "setOpsRecipient(address)";
        // LSG P0 boundary
        abi_[37] = "activateLSG(address)";
        abi_[38] = "deactivateLSG()";
        abi_[39] = "deployMarginalBySignal(uint256)";
        abi_[40] = "fundSignalerProgram(address,uint256,uint64,uint64)";
        // Views
        abi_[41] = "admissionOf(address)";
        abi_[42] = "limitOf(address,address)";
        abi_[43] = "strategyAssets(address)";
    }

    /// @dev Closed-world: every accepted entry is present AND every present entry
    ///      is accepted. The second half is what makes this a structural claim —
    ///      a new privileged function cannot appear without failing here.
    function test_TheExternalSurfaceIsExactlyTheAcceptedOne() public view {
        string[] memory actual = _surface();
        string[] memory accepted = _acceptedSurface();

        for (uint256 i = 0; i < accepted.length; i++) {
            assertTrue(Artifact.contains(actual, accepted[i]), string.concat("missing: ", accepted[i]));
        }
        for (uint256 i = 0; i < actual.length; i++) {
            assertTrue(
                Artifact.contains(accepted, actual[i]), string.concat("unexpected external function: ", actual[i])
            );
        }
        assertEq(actual.length, accepted.length, "surface size");
    }

    /// @dev The prohibitions this sprint is defined by, one selector at a time.
    function test_TheProhibitedSurfacesDoNotExist() public view {
        string[] memory actual = _surface();

        string[] memory forbidden = new string[](18);
        // Wiring authority — AC-1: no setPool, no initializer, no upgrade.
        forbidden[0] = "setPool(address)";
        forbidden[1] = "initialize(address,address,address,address,address,uint24)";
        forbidden[2] = "initialize()";
        forbidden[3] = "upgradeTo(address)";
        forbidden[4] = "upgradeToAndCall(address,bytes)";
        // Declaration paths — classification is arithmetic (sdd.md:L289).
        forbidden[5] = "declareProfit(address,uint256)";
        forbidden[6] = "declareProfit(uint256)";
        forbidden[7] = "setRealizedRevenue(address,uint256)";
        forbidden[8] = "setNav(uint256)";
        forbidden[9] = "markToMarket(address,uint256)";
        // The deleted market-infrastructure leg (2026-08-12 remediation, F-2).
        forbidden[10] = "marketInfraBudget(address)";
        forbidden[11] = "allocateRevenue(address,uint256,uint256,uint256,uint256,uint256)";
        // Arbitrary reach out of the treasury.
        forbidden[12] = "execute(address,bytes)";
        forbidden[13] = "call(address,bytes)";
        forbidden[14] = "sweep(address,address,uint256)";
        forbidden[15] = "rescue(address,uint256)";
        // Monetary-core reach (FB-15/FB-16, INV-24).
        forbidden[16] = "redeem(uint256,address)";
        forbidden[17] = "mint(address,uint256)";

        for (uint256 i = 0; i < forbidden.length; i++) {
            assertFalse(
                Artifact.contains(actual, forbidden[i]), string.concat("surface must not exist: ", forbidden[i])
            );
        }

        // Positive control: the same membership test finds something that IS there.
        assertTrue(Artifact.contains(actual, "allocateRevenue(address,uint256,uint256,uint256,uint256)"), "control");
    }

    /// @dev AC-4's ABI assertion in its exact form: the five-leg shape is absent
    ///      and the four-leg shape is present. The superseded design differed
    ///      from the accepted one by exactly one `uint256`, so asserting on the
    ///      selector is the sharpest available statement.
    function test_AllocateRevenueHasExactlyFourLegs() public view {
        string[] memory actual = _surface();
        assertTrue(
            Artifact.contains(actual, "allocateRevenue(address,uint256,uint256,uint256,uint256)"),
            "four legs: compound / hard / ops / signalers"
        );
        assertFalse(
            Artifact.contains(actual, "allocateRevenue(address,uint256,uint256,uint256,uint256,uint256)"),
            "the superseded five-leg toMarketInfra shape must not exist"
        );

        uint256 legShaped;
        for (uint256 i = 0; i < actual.length; i++) {
            if (Artifact.containsString(actual[i], "allocateRevenue")) legShaped++;
        }
        assertEq(legShaped, 1, "exactly one allocateRevenue overload exists");
    }

    /// @dev The one earmark is `signalerBudget`; `marketInfraBudget` is deleted,
    ///      not merely unused — no getter, and the name appears nowhere in the
    ///      deployed image.
    function test_SignalerBudgetIsTheSoleEarmark() public view {
        string[] memory actual = _surface();
        assertTrue(Artifact.contains(actual, "signalerBudget(address)"), "the sole earmark");
        assertFalse(Artifact.contains(actual, "marketInfraBudget(address)"), "no market-infrastructure earmark");

        // Selector-level: `marketInfraBudget(address)` is not dispatched anywhere
        // in the runtime image, with the live earmark's selector as the control.
        bytes memory runtime = vm.parseJsonBytes(vm.readFile(ARTIFACT), ".deployedBytecode.object");
        assertFalse(
            Artifact.containsBytes(runtime, abi.encodePacked(bytes4(keccak256("marketInfraBudget(address)")))),
            "no marketInfraBudget selector in the runtime image"
        );
        assertTrue(
            Artifact.containsBytes(runtime, abi.encodePacked(bytes4(keccak256("signalerBudget(address)")))),
            "control: the signalerBudget selector IS in the runtime image"
        );
    }

    /// @dev AC-5 / INV-31 / R-9: the waterfall percentages are founder-accepted
    ///      *future doctrine*, never v1 contract constants. A stored ratio would
    ///      show up as a public getter; there is none, and the only constants the
    ///      surface exposes are the 24 h delay and the two role ids.
    function test_NoStoredPolicyRatioConstantIsExposed() public view {
        string[] memory actual = _surface();

        string[] memory ratioShaped = new string[](10);
        ratioShaped[0] = "COMPOUND_BP()";
        ratioShaped[1] = "HARD_BP()";
        ratioShaped[2] = "OPS_BP()";
        ratioShaped[3] = "SIGNALER_BP()";
        ratioShaped[4] = "MARKET_INFRA_BP()";
        ratioShaped[5] = "OPERATOR_RESERVE_BP()";
        ratioShaped[6] = "BP_DENOM()";
        ratioShaped[7] = "waterfall()";
        ratioShaped[8] = "setWaterfall(uint256,uint256,uint256,uint256)";
        ratioShaped[9] = "policyRatioBp()";

        for (uint256 i = 0; i < ratioShaped.length; i++) {
            assertFalse(
                Artifact.contains(actual, ratioShaped[i]), string.concat("policy ratio must not exist: ", ratioShaped[i])
            );
        }
    }

    /// @dev INV-30 is structural: appreciation that has not been realized as a
    ///      measured token flow is invisible to this surface *by construction*.
    ///      No mark or NAV cell exists to read or to write.
    function test_NoMarkOrNavCellExists() public view {
        string[] memory actual = _surface();

        string[] memory markShaped = new string[](6);
        markShaped[0] = "nav()";
        markShaped[1] = "navOf(address)";
        markShaped[2] = "marks(address)";
        markShaped[3] = "markOf(address,address)";
        markShaped[4] = "unrealizedGain(address)";
        markShaped[5] = "totalStrategicNav()";

        for (uint256 i = 0; i < markShaped.length; i++) {
            assertFalse(Artifact.contains(actual, markShaped[i]), string.concat("must not exist: ", markShaped[i]));
        }

        // Positive control: the cells that DO exist are the accepted ones.
        assertTrue(Artifact.contains(actual, "outstandingPrincipal(address,address)"), "principal cell exists");
        assertTrue(Artifact.contains(actual, "realizedRevenue(address)"), "realized-revenue cell exists");
    }

    /// @dev No LSG mechanism ships at P0: no stake, no epoch, no weighting, no
    ///      reward accrual, no threshold, and no calendar — only the activation
    ///      slot, the interface, and the consumption read (F-50; sprint.md's P1
    ///      tripwire).
    function test_NoLsgMechanismShipsAtP0() public view {
        string[] memory actual = _surface();

        string[] memory p1Shaped = new string[](9);
        p1Shaped[0] = "stake(uint256)";
        p1Shaped[1] = "unstake(uint256)";
        p1Shaped[2] = "setPreference(address[],uint16[])";
        p1Shaped[3] = "appliedWeightOf(address)";
        p1Shaped[4] = "totalStaked()";
        p1Shaped[5] = "epochLength()";
        p1Shaped[6] = "currentEpoch()";
        p1Shaped[7] = "activationThreshold()";
        p1Shaped[8] = "fundBribe(address,uint256,uint64,uint64,address)";

        for (uint256 i = 0; i < p1Shaped.length; i++) {
            assertFalse(Artifact.contains(actual, p1Shaped[i]), string.concat("P1 surface must not exist: ", p1Shaped[i]));
        }

        assertTrue(Artifact.contains(actual, "activateLSG(address)"), "the activation authority IS present");
        assertTrue(Artifact.contains(actual, "deactivateLSG()"), "and its inverse");
    }
}
