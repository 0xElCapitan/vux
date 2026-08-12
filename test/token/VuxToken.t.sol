// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: INV-1, INV-2, INV-3, INV-4, INV-5, FR-1.1, FR-7.4
//          sprint.md Sprint 2 AC-1, AC-2

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {BaseTest} from "../harness/BaseTest.sol";
import {Artifact} from "../harness/Artifact.sol";
import {Vm} from "../harness/Vm.sol";
import {VUX} from "../../src/VUX.sol";

/// @title VuxTokenTest — genesis exactness and the two immutable authorities.
/// @notice Every claim this sprint makes about the token is either a claim about
///         *state after construction* or a claim about *who may call what*. Both
///         are tested here against the deployed contract, and the "nothing else
///         exists" half is tested against the compiled ABI rather than the
///         source text — a reviewer can already grep the source, so grepping the
///         source in a test would add nothing they do not have.
contract VuxTokenTest is BaseTest {
    string internal constant ARTIFACT = "out/VUX.sol/VUX.json";

    bytes32 internal constant TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)");

    address internal constant RIG = address(0xA11CE);
    address internal constant RESERVE = address(0xB0B);
    address internal constant HOLDER = address(0xC0FFEE);
    address internal constant VICTIM = address(0xDEAD1);

    VUX internal vux;

    function setUp() public {
        vux = new VUX(RIG, RESERVE);
    }

    /// @dev The complete external signature set of `VUX`: the three
    ///      protocol-specific functions of sdd.md §5.2.1, the immutable
    ///      authority identities and genesis constants, and the inherited
    ///      ERC20 / ERC20Permit surface enumerated in sdd.md §5.1 — nothing
    ///      else. An added mutator, an accidentally public helper, or a
    ///      resurrected `burnFrom` all fail against this list.
    function _acceptedAbi() private pure returns (string[] memory abi_) {
        abi_ = new string[](20);
        // protocol-specific (sdd.md §5.2.1)
        abi_[0] = "mint(address,uint256)";
        abi_[1] = "burn(uint256)";
        abi_[2] = "burnForRedemption(address,uint256)";
        // immutable authority identities + genesis constants (views)
        abi_[3] = "rig()";
        abi_[4] = "reserve()";
        abi_[5] = "GENESIS_POL_SUPPLY()";
        abi_[6] = "GENESIS_RESERVE_SEED()";
        // inherited ERC20 (pinned OZ v5.2.0)
        abi_[7] = "name()";
        abi_[8] = "symbol()";
        abi_[9] = "decimals()";
        abi_[10] = "totalSupply()";
        abi_[11] = "balanceOf(address)";
        abi_[12] = "transfer(address,uint256)";
        abi_[13] = "allowance(address,address)";
        abi_[14] = "approve(address,uint256)";
        abi_[15] = "transferFrom(address,address,uint256)";
        // inherited ERC20Permit / EIP712
        abi_[16] = "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)";
        abi_[17] = "nonces(address)";
        abi_[18] = "DOMAIN_SEPARATOR()";
        abi_[19] = "eip712Domain()";
    }

    // -----------------------------------------------------------------------
    // Genesis (INV-2, INV-3, FR-1.1)
    // -----------------------------------------------------------------------

    function test_GenesisMintsExactlyTheAcceptedAmounts() public view {
        assertEq(vux.GENESIS_POL_SUPPLY(), 150_000e18, "accepted POL inventory constant");
        assertEq(vux.GENESIS_RESERVE_SEED(), 1, "accepted reserve seed constant");
        assertEq(vux.balanceOf(address(this)), 150_000e18, "creator holds the transient POL inventory");
        assertEq(vux.balanceOf(RESERVE), 1, "reserve holds exactly the one raw S_MIN unit");
    }

    function test_GenesisTotalSupplyIsExactlyTheFrozenValue() public view {
        assertEq(vux.totalSupply(), 150_000e18 + 1, "S0 = 150_000e18 + 1 (INV-2, prd.md:L582)");
    }

    /// @dev INV-3 is a universal claim — "zero to every other address" — so
    ///      spot-checking a handful of addresses cannot establish it. Capturing
    ///      the constructor's COMPLETE log set and proving it contains exactly
    ///      two mints, to exactly two recipients, for exactly the two accepted
    ///      amounts, does: any third credited address would need a third
    ///      `Transfer` from the zero address.
    function test_GenesisCreditsNoAddressBeyondTheAcceptedTwo() public {
        vm.recordLogs();
        VUX fresh = new VUX(RIG, RESERVE);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 mints;
        uint256 toCreator;
        uint256 toReserve;
        for (uint256 i = 0; i < logs.length; i++) {
            assertEq(logs[i].emitter, address(fresh), "genesis emitted a log from another contract");
            assertEq(logs[i].topics[0], TRANSFER_TOPIC, "genesis emitted a non-Transfer event");
            assertEq(address(uint160(uint256(logs[i].topics[1]))), address(0), "genesis Transfer is not a mint");

            mints++;
            address to = address(uint160(uint256(logs[i].topics[2])));
            uint256 amount = abi.decode(logs[i].data, (uint256));
            if (to == address(this)) toCreator += amount;
            else if (to == RESERVE) toReserve += amount;
            else fail("genesis credited an address other than the creator and the reserve");
        }

        assertEq(mints, 2, "genesis performed exactly two mints");
        assertEq(toCreator, 150_000e18, "creator credited exactly the POL inventory");
        assertEq(toReserve, 1, "reserve credited exactly one raw unit");
        assertEq(fresh.totalSupply(), toCreator + toReserve, "supply equals the sum of the two mints");
    }

    /// @dev INV-1: `S` is the complete supply with no protocol-balance
    ///      exclusion — in particular, the Reserve's own seed counts.
    function test_TotalSupplyIsCompleteWithNoProtocolExclusion() public {
        vm.prank(RIG);
        vux.mint(HOLDER, 7e18);

        assertEq(
            vux.totalSupply(),
            vux.balanceOf(address(this)) + vux.balanceOf(RESERVE) + vux.balanceOf(HOLDER),
            "totalSupply equals the sum of every balance, reserve seed included"
        );
    }

    function test_ConstructorRejectsZeroRig() public {
        vm.expectRevert(VUX.ZeroAddress.selector);
        new VUX(address(0), RESERVE);
    }

    function test_ConstructorRejectsZeroReserve() public {
        vm.expectRevert(VUX.ZeroAddress.selector);
        new VUX(RIG, address(0));
    }

    function test_IdentityIsVux() public view {
        assertEq(vux.name(), "VUX", "name");
        assertEq(vux.symbol(), "VUX", "symbol");
        assertEq(uint256(vux.decimals()), 18, "decimals");
    }

    // -----------------------------------------------------------------------
    // Mint authority (INV-4, INV-5)
    // -----------------------------------------------------------------------

    function test_RigCanMint() public {
        vm.prank(RIG);
        vux.mint(HOLDER, 5e18);

        assertEq(vux.balanceOf(HOLDER), 5e18, "rig mint credited the recipient");
        assertEq(vux.totalSupply(), 150_000e18 + 1 + 5e18, "supply grew by exactly the minted amount");
    }

    /// @dev The gate is universal, so the negative is fuzzed over callers rather
    ///      than asserted for one hand-picked address.
    function testFuzz_MintRevertsForEveryCallerExceptRig(address caller) public {
        vm.assume(caller != RIG);

        vm.prank(caller);
        vm.expectRevert(VUX.NotRig.selector);
        vux.mint(caller, 1);
    }

    function test_AuthoritiesAreTheConstructorValues() public view {
        assertEq(vux.rig(), RIG, "rig is the constructor value");
        assertEq(vux.reserve(), RESERVE, "reserve is the constructor value");
    }

    // -----------------------------------------------------------------------
    // Burn authority (FR-7.4; the redemption-burn gate)
    // -----------------------------------------------------------------------

    function test_ReserveCanBurnForRedemption() public {
        vm.prank(RIG);
        vux.mint(HOLDER, 10e18);

        vm.prank(RESERVE);
        vux.burnForRedemption(HOLDER, 4e18);

        assertEq(vux.balanceOf(HOLDER), 6e18, "exactly q burned from the named holder");
        assertEq(vux.totalSupply(), 150_000e18 + 1 + 6e18, "supply fell by exactly q");
    }

    function testFuzz_BurnForRedemptionRevertsForEveryCallerExceptReserve(address caller) public {
        vm.assume(caller != RESERVE);
        vm.prank(RIG);
        vux.mint(VICTIM, 10e18);

        vm.prank(caller);
        vm.expectRevert(VUX.NotReserve.selector);
        vux.burnForRedemption(VICTIM, 1e18);

        assertEq(vux.balanceOf(VICTIM), 10e18, "victim balance untouched by the rejected call");
    }

    /// @dev No allowance can substitute for the gate — this is what makes the
    ///      redemption path approval-free *and* unforgeable at the same time.
    function test_AllowanceDoesNotUnlockBurnForRedemption() public {
        vm.prank(RIG);
        vux.mint(VICTIM, 10e18);

        vm.prank(VICTIM);
        vux.approve(HOLDER, type(uint256).max);

        vm.prank(HOLDER);
        vm.expectRevert(VUX.NotReserve.selector);
        vux.burnForRedemption(VICTIM, 1e18);
    }

    /// @dev `burn` is self-only by construction (`_burn(msg.sender, ...)`), so
    ///      the observable claim is that a caller can never reduce anyone else's
    ///      balance through it, and cannot burn beyond its own.
    function test_BurnIsSelfOnly() public {
        vm.prank(RIG);
        vux.mint(HOLDER, 3e18);
        vm.prank(RIG);
        vux.mint(VICTIM, 9e18);

        vm.prank(HOLDER);
        vux.burn(3e18);

        assertEq(vux.balanceOf(HOLDER), 0, "caller burned its own balance");
        assertEq(vux.balanceOf(VICTIM), 9e18, "no other balance moved");

        vm.prank(HOLDER);
        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        vux.burn(1);
    }

    // -----------------------------------------------------------------------
    // Absence of a general `burnFrom` (AC-2) and of any unexpected authority
    // -----------------------------------------------------------------------

    /// @dev Compiled-artifact proof, not a source grep — but scoped to the
    ///      dispatcher table rather than the file. A whole-artifact text search
    ///      was tried first and is wrong: forge stores `rawMetadata`, which
    ///      embeds solc's `devdoc`, so the NatSpec sentence in `VUX.sol` that
    ///      *documents the deletion* of `burnFrom` is itself in the artifact.
    ///      A search that a comment can flip is not a surface test.
    ///      `.methodIdentifiers` is exactly the set of signatures the contract
    ///      dispatches, which is the domain the claim is actually about.
    function test_NoBurnFromSignatureIsDispatchable() public view {
        string[] memory signatures = vm.parseJsonKeys(vm.readFile(ARTIFACT), ".methodIdentifiers");

        bool sawPositiveControl;
        for (uint256 i = 0; i < signatures.length; i++) {
            if (Artifact.containsString(signatures[i], "burnForRedemption")) sawPositiveControl = true;
            assertFalse(
                Artifact.containsString(signatures[i], "burnFrom"),
                string.concat("a burnFrom-like signature is dispatchable: ", signatures[i])
            );
        }
        assertTrue(sawPositiveControl, "positive control: the scan does find a burn signature that IS present");
    }

    /// @dev And no dispatcher entry for it either — an ABI could in principle
    ///      omit a function the bytecode still routes.
    function test_NoBurnFromEntryPointExistsAtRuntime() public {
        vm.prank(RIG);
        vux.mint(VICTIM, 10e18);

        (bool ok,) = address(vux).call(abi.encodeWithSignature("burnFrom(address,uint256)", VICTIM, 1e18));

        assertFalse(ok, "burnFrom(address,uint256) must not be dispatchable");
        assertEq(vux.balanceOf(VICTIM), 10e18, "victim balance untouched");
    }

    /// @dev The exhaustive form of "no discretionary mint or burn path exists"
    ///      (INV-5): the compiled external surface is exactly the accepted set,
    ///      so an unlisted authority cannot hide behind a name nobody thought
    ///      to check for.
    function test_ExternalSurfaceIsExactlyTheAcceptedSet() public view {
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

    /// @dev Named negatives for the authority classes an auditor scans for. The
    ///      exact-set assertion above already covers these; spelling them out
    ///      makes the review checklist mechanical instead of a reading exercise.
    function test_NoOwnershipUpgradeOrAuthorityRepointingSurface() public view {
        string[] memory actual = vm.parseJsonKeys(vm.readFile(ARTIFACT), ".methodIdentifiers");
        string[10] memory forbidden = [
            "setRig(address)",
            "setReserve(address)",
            "owner()",
            "transferOwnership(address)",
            "pause()",
            "unpause()",
            "upgradeTo(address)",
            "initialize(address,address)",
            "grantRole(bytes32,address)",
            "burnFrom(address,uint256)"
        ];
        for (uint256 i = 0; i < forbidden.length; i++) {
            assertFalse(
                Artifact.contains(actual, forbidden[i]), string.concat("surface must not exist: ", forbidden[i])
            );
        }
    }
}
