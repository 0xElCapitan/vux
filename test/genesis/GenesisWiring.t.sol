// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 7 Task 7.3 (genesis wiring proof suite) and the
//          "Plus" row of the Sprint-7 acceptance criteria — commitment
//          negatives, domain negatives, exact slot0, recorded-wei ratio/cushion,
//          contamination arithmetic, closing-sweep completeness, deployer zero
//          balances, POL liquidity > 0 owned by the treasury, rig.king() ==
//          reserve, exact S0, one-shot consumption, gas/initcode headroom
//          sdd.md:L158-L171 (deployment order), L185 (price encoding), L187
//          (closing self-verification), L192 (VuxPoolDeployer domain checks)
//
// The mutated-extra-CREATE nonce negative is a SOURCE mutation and therefore
// lives in `tools/genesis/demo-nonce-negative.sh`, which mutates
// `src/GenesisDeployer.sol`, proves the launch reverts on
// `PredictedAddressMismatch`, restores the file, and re-verifies it
// byte-identical. A test double could only show that a double breaks; the guard
// under test is in the shipped constructor, so the mutation has to be too.

import {GenesisDeployer, GenesisParams} from "../../src/GenesisDeployer.sol";
import {GenesisFixture, IPoolPositions} from "./GenesisFixture.sol";

contract GenesisWiringTest is GenesisFixture {
    function setUp() public {
        _runGenesis();
    }

    // ---------------------------------------------------- CREATE prediction

    /// @notice Every predicted address equals the address actually deployed.
    /// @dev Recomputed with `vm.computeCreateAddress` — a different
    ///      implementation from the contract's own RLP encoder — so agreement is
    ///      evidence rather than a tautology.
    function test_PredictedAddressesEqualActualForEveryDeployment() public view {
        assertEq(address(genesis), predictedGenesis, "GenesisDeployer landed where tx1's commitment bound it");

        address g = address(genesis);
        assertEq(address(reserve), vm.computeCreateAddress(g, 1), "HardReserve at nonce 1");
        assertEq(address(rig), vm.computeCreateAddress(g, 2), "Rig at nonce 2");
        assertEq(address(vux), vm.computeCreateAddress(g, 3), "VUX at nonce 3");
        assertEq(address(treasury), vm.computeCreateAddress(g, 4), "StrategicTreasury at nonce 4");
        assertEq(address(lens), vm.computeCreateAddress(g, 5), "Lens at nonce 5");

        // The forward references the 2-cycles forced: each was built against a
        // prediction and each prediction held.
        assertEq(address(reserve.vux()), address(vux), "HardReserve's predicted VUX edge resolved correctly");
        assertEq(address(rig.vux()), address(vux), "the Rig's predicted VUX edge resolved correctly");
        assertEq(rig.treasury(), address(treasury), "the Rig's predicted treasury edge resolved correctly");
        assertEq(vux.rig(), address(rig), "VUX points back at the real Rig");
        assertEq(vux.reserve(), address(reserve), "VUX points back at the real Reserve");
        assertEq(rig.reserve(), address(reserve), "the Rig points at the real Reserve");
        assertEq(treasury.hardReserve(), address(reserve), "the treasury points at the real Reserve");
    }

    /// @notice The pool CREATE2 consumes the POOL DEPLOYER's nonce, not the
    ///         GenesisDeployer's — which is why `predict(4)` still holds.
    /// @dev Stated as an address fact rather than a nonce reading: had the pool
    ///      consumed a GenesisDeployer nonce, the treasury would have landed at
    ///      nonce 5 and the Lens at 6. Pinning both ends pins the sequence, and
    ///      pinning nonce 6 as empty proves exactly five CREATEs happened
    ///      (sdd.md:L157, L166).
    function test_PoolCreate2DoesNotConsumeAGenesisDeployerNonce() public view {
        assertEq(address(treasury), vm.computeCreateAddress(address(genesis), 4), "treasury still at nonce 4");
        assertEq(address(lens), vm.computeCreateAddress(address(genesis), 5), "Lens still at nonce 5");
        assertNotEq(pool, vm.computeCreateAddress(address(genesis), 4), "the pool is not a GenesisDeployer CREATE");
        assertNotEq(pool, vm.computeCreateAddress(address(genesis), 5), "the pool is not a GenesisDeployer CREATE");
        assertEq(vm.computeCreateAddress(address(genesis), 6).code.length, 0, "no sixth deployment exists");
    }

    // ------------------------------------------------- canonical pool identity

    /// @notice Independent CREATE2 recomputation equals the deployed pool and
    ///         equals `treasury.POOL()`.
    /// @dev `_computePoolAddress` derives from the compiled pool artifact's own
    ///      init-code hash; `GenesisDeployer` uses the accepted constant. Two
    ///      independent derivations meeting at one address is the evidence
    ///      (sdd.md:L192, L859).
    function test_CanonicalPoolCreate2IdentityIsExactEndToEnd() public view {
        (address t0, address t1) = _sorted(address(vux), address(weth));
        address recomputed = _computePoolAddress(address(poolDeployer), t0, t1, FEE_TIER);

        assertEq(recomputed, pool, "independent CREATE2 recomputation equals the deployed pool");
        assertEq(treasury.pool(), pool, "treasury.POOL() is that same pool");
        assertEq(recomputed, predictedPool, "and it is the address predicted before tx2 ran");

        assertEq(IPoolPositions(pool).factory(), address(poolDeployer), "pool.factory() is the protocol deployer");
        assertEq(IPoolPositions(pool).token0(), t0, "token0 sorted");
        assertEq(IPoolPositions(pool).token1(), t1, "token1 sorted");
        assertEq(uint256(IPoolPositions(pool).fee()), uint256(FEE_TIER), "fee tier");
        assertEq(int256(IPoolPositions(pool).tickSpacing()), int256(TICK_SPACING), "tick spacing");
        assertEq(poolDeployer.owner(), address(0), "pool-deployer owner is permanently dead");
    }

    /// @notice The shipped `POOL_INIT_CODE_HASH` is the compiled pool's actual
    ///         init-code hash — the wiring uses exactly the accepted constant
    ///         (refreeze §7 obligation 2).
    function test_PoolInitCodeHashConstantMatchesTheCompiledArtifact() public view {
        assertEq(genesis.POOL_INIT_CODE_HASH(), _poolInitCodeHash(), "shipped constant == compiled pool init code");
    }

    // ------------------------------------------------------- commitment gate

    /// @notice Wrong salt cannot consume the one-shot, so the launch dies.
    function test_CommitmentNegative_WrongSaltRevertsTheLaunch() public {
        _prepareLaunch();
        vm.deal(address(this), address(this).balance + W_POL + B0);
        vm.expectRevert(bytes("BadCommitment"));
        _launchWithSalt(keccak256("not.the.committed.salt"));
    }

    /// @notice Control: the same fresh tx1, with the RIGHT salt, launches.
    function test_Control_TheSameFreshTx1LaunchesWithTheRightSalt() public {
        _prepareLaunch();
        vm.deal(address(this), address(this).balance + W_POL + B0);
        address deployed = _launchWithSalt(REHEARSAL_SALT);
        assertEq(deployed, predictedGenesis, "the committed salt launches at the committed address");
    }

    /// @notice Wrong sender cannot consume the one-shot even WITH the real salt.
    /// @dev The mempool-observer case: the salt is treated as fully extracted.
    ///      The gate binds `msg.sender`, so possessing the preimage is not
    ///      enough — the caller must *be* the committed address (sdd.md:L192).
    function test_CommitmentNegative_RightSaltWrongSenderFails() public {
        _prepareLaunch();
        (address t0, address t1) = _sorted(predictedVux, address(weth));

        address attacker = address(0xA77ACC);
        vm.prank(attacker);
        vm.expectRevert(bytes("BadCommitment"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIER, TICK_SPACING);

        // And the launch that follows is unaffected — the failed attempt
        // consumed nothing.
        vm.deal(address(this), address(this).balance + W_POL + B0);
        assertEq(_launchWithSalt(REHEARSAL_SALT), predictedGenesis, "the real launch still succeeds afterwards");
    }

    /// @notice The one-shot is consumed: a second deployment reverts forever,
    ///         for the committed caller as much as for anyone else.
    function test_OneShotIsConsumedAfterGenesis() public {
        assertEq(poolDeployer.canonicalPool(), pool, "the latch holds the canonical pool");

        (address t0, address t1) = _sorted(address(vux), address(weth));
        vm.prank(address(genesis));
        vm.expectRevert(bytes("PoolAlreadyDeployed"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIER, TICK_SPACING);
    }

    // -------------------------------------------------- parameter-domain gate

    /// @notice The Finding-4 domain checks reject each violation distinctly.
    /// @dev Run against a fresh deployer whose commitment binds to THIS test
    ///      contract, so every rejection is the domain check firing rather than
    ///      the commitment gate. A reverted attempt consumes nothing, so all six
    ///      cases share one deployer — and the last one is a positive control
    ///      proving the gate is not simply closed.
    function test_DomainNegatives_EachViolationIsRejectedAndValidInputIsAccepted() public {
        poolDeployer = _freshPoolDeployerBoundTo(address(this));
        (address t0, address t1) = _sorted(address(vux), address(weth));

        vm.expectRevert(bytes("InvalidPoolParams: zeroToken"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, address(0), t1, FEE_TIER, TICK_SPACING);

        vm.expectRevert(bytes("InvalidPoolParams: tokenOrder"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t1, t0, FEE_TIER, TICK_SPACING);

        vm.expectRevert(bytes("InvalidPoolParams: fee"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, 1_000_000, TICK_SPACING);

        vm.expectRevert(bytes("InvalidPoolParams: tickSpacing"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIER, 0);

        vm.expectRevert(bytes("InvalidPoolParams: tickSpacing"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIER, 16384);

        address deployed = poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIER, TICK_SPACING);
        assertGt(deployed.code.length, 0, "the valid domain deploys a real pool");
    }

    // ------------------------------------------------------ genesis economics

    /// @notice Exact initial pool price: `slot0.sqrtPriceX96 == sqrtP0X96`.
    function test_PoolInitializedAtExactlySqrtP0X96() public view {
        (uint160 actual,,,,,,) = IPoolPositions(pool).slot0();
        assertEq(uint256(actual), uint256(sqrtP0X96), "slot0 stores the supplied encoding verbatim");
        assertNotEq(uint256(sqrtP0X96), 0, "and the encoding is not the degenerate zero");
    }

    /// @notice `P0/N0 = 1.10` and `BOOTSTRAP_OPENING <= P0*S0 - B0`, in exact wei
    ///         arithmetic on the recorded conversion values.
    function test_RecordedWeiRatioAndCushionHold() public pure {
        // Cross-multiplied, so no division rounds the identity into agreement.
        assertEq(P0_NUM * 10 * S0, P0_DEN * 11 * B0, "P0/N0 == 1.10 exactly on the recorded values");

        uint256 p0TimesS0 = (P0_NUM * S0) / P0_DEN;
        assertGt(p0TimesS0, B0, "P0*S0 exceeds B0, so a cushion exists at all");
        assertLe(BOOTSTRAP_OPENING, p0TimesS0 - B0, "the bootstrap opening fits inside the premium cushion");
    }

    /// @notice A ratio that is not exactly 1.10 reverts the launch.
    /// @dev Discrimination for the check above: `_verifyBootstrapEconomics` must
    ///      be the reason a bad conversion record cannot launch.
    function test_EconomicsNegative_OffRatioP0RevertsTheLaunch() public {
        _prepareLaunch();
        vm.deal(address(this), address(this).balance + W_POL + B0);
        vm.expectPartialRevert(GenesisDeployer.PremiumRatioViolated.selector);
        _launchWithP0(P0_NUM + 1, P0_DEN);
    }

    /// @notice A bootstrap opening larger than the cushion reverts the launch.
    function test_EconomicsNegative_OpeningBeyondTheCushionRevertsTheLaunch() public {
        _prepareLaunch();
        uint256 cushion = (P0_NUM * S0) / P0_DEN - B0;
        vm.deal(address(this), address(this).balance + W_POL + B0);
        vm.expectPartialRevert(GenesisDeployer.CushionViolated.selector);
        _launchWithOpening(cushion + 1);
    }

    /// @notice Control for both economics negatives: the boundary value itself
    ///         is accepted, so the checks are `<=` and not merely "always fail".
    function test_Control_TheExactCushionBoundaryLaunches() public {
        _prepareLaunch();
        uint256 cushion = (P0_NUM * S0) / P0_DEN - B0;
        vm.deal(address(this), address(this).balance + W_POL + B0);
        assertEq(_launchWithOpening(cushion), predictedGenesis, "opening == cushion is inside the law");
    }

    /// @notice Exact genesis supply and the permanent one-raw-unit Reserve seed.
    function test_ExactGenesisSupplyAndReserveSeed() public view {
        assertEq(vux.totalSupply(), S0, "S0 == 150_000e18 + 1");
        assertEq(vux.balanceOf(address(reserve)), 1, "the Reserve holds exactly the permanent seed");
        assertEq(vux.GENESIS_POL_SUPPLY(), POL_VUX, "the POL allocation constant is unchanged");
    }

    /// @notice Physical `B0`, and the `N0` / `P0/N0` facts that rest on it.
    /// @dev "Physical" is the claim being tested: `B` is a real WETH balance and
    ///      `S` a real supply, so the ratio law is a fact about state rather than
    ///      about a bookkeeping cell (sdd.md:L187).
    function test_PhysicalB0AndTheDerivedBackingFacts() public view {
        assertEq(weth.balanceOf(address(reserve)), B0, "WETH.balanceOf(reserve) == B0 exactly");
        assertEq(reserve.backing(), B0, "and the Reserve reports it as B");
        assertEq(vux.totalSupply(), S0, "S is the real supply");

        // P0 / (B/S) == 11/10, computed from the LIVE balance and supply rather
        // than from the recorded constants: P0_NUM * S * 10 == P0_DEN * B * 11.
        uint256 liveB = weth.balanceOf(address(reserve));
        uint256 liveS = vux.totalSupply();
        assertEq(P0_NUM * liveS * 10, P0_DEN * liveB * 11, "P0/N0 == 1.10 against physical state");
    }

    /// @notice The first settlement will see `B_pre == B0` exactly.
    /// @dev Read through the Lens rather than asserted about the balance again,
    ///      so this is the value the settlement path itself would observe.
    function test_FirstSettlementBPreIsExactlyB0() public view {
        (uint256 b, uint256 s,) = lens.hardStats();
        assertEq(b, B0, "B_pre for the first settlement is exactly B0");
        assertEq(s, S0, "S_pre for the first settlement is exactly S0");
    }

    /// @notice Zero discretionary VUX exists: every unit is POL or the seed.
    function test_NoDiscretionaryFounderOrTeamVuxExists() public view {
        uint256 inPolSystem = vux.balanceOf(address(treasury)) + vux.balanceOf(pool);
        assertEq(inPolSystem + vux.balanceOf(address(reserve)), S0, "all supply is POL-side plus the Reserve seed");
        assertEq(vux.balanceOf(address(genesis)), 0, "the launch deployer holds no VUX");
        assertEq(vux.balanceOf(address(this)), 0, "the launch sender holds no VUX");
        assertEq(vux.balanceOf(REHEARSAL_SAFE), 0, "the operator Safe holds no VUX");
        assertEq(vux.balanceOf(address(rig)), 0, "the Rig holds no VUX");
        assertEq(vux.balanceOf(address(lens)), 0, "the Lens holds no VUX");
    }

    /// @notice The canonical POL position exists, is non-empty, and is the
    ///         treasury's.
    function test_PolPositionIsRealAndOwnedByTheTreasury() public view {
        assertGt(uint256(_polLiquidity()), 0, "the canonical position has liquidity");

        (uint128 deployerPos,,,,) = _positionOf(address(genesis));
        assertEq(uint256(deployerPos), 0, "the deployer owns no position");
        (uint128 senderPos,,,,) = _positionOf(address(this));
        assertEq(uint256(senderPos), 0, "the launch sender owns no position");
        (uint128 safePos,,,,) = _positionOf(REHEARSAL_SAFE);
        assertEq(uint256(safePos), 0, "the operator Safe owns no position");
    }

    /// @notice The POL legs landed where FR-1 requires: 150,000 VUX into
    ///         protocol-owned liquidity, with only quantization dust retained.
    function test_PolProvisioningConsumedTheGenesisAllocation() public view {
        uint256 dust = vux.balanceOf(address(treasury));
        assertEq(vux.balanceOf(pool) + dust, POL_VUX, "every POL VUX is in the pool or is retained dust");
        assertLt(dust, 1e18, "retained VUX is quantization dust, not an unplaced allocation");
        assertGt(treasury.polVuxPrincipal(), 0, "the VUX principal cost basis was booked");
        assertGt(treasury.polWethPrincipal(), 0, "the WETH principal cost basis was booked");
    }

    /// @notice Bootstrap throne state: the Reserve is King and mints nothing.
    function test_BootstrapKingIsTheReserve() public view {
        assertEq(rig.king(), address(reserve), "rig.king() == reserve");
        assertEq(rig.epochUPS(), 0, "the bootstrap epoch's snapshot is zero");
    }

    // ------------------------------------------------- contamination and sweep

    /// @notice With no contamination present, the sweep is a no-op and both
    ///         deployer balances close at exactly zero.
    function test_CleanLaunchClosesWithZeroResidual() public view {
        assertEq(genesis.wethPreSelf(), 0, "nothing was pre-placed at the deployer");
        assertEq(genesis.wethSanitizedFromReserve(), 0, "nothing was sanitized out of the Reserve");
        assertEq(genesis.contaminationSwept(), 0, "so nothing was swept");
        assertEq(weth.balanceOf(address(genesis)), 0, "deployer WETH is exactly zero");
        assertEq(vux.balanceOf(address(genesis)), 0, "deployer VUX is exactly zero");
        assertEq(address(genesis).balance, 0, "deployer ETH is exactly zero");
    }

    /// @notice Funding must be exact: `msg.value == W_POL + B0`, both directions.
    function test_FundingNegative_UnderAndOverFundingBothRevert() public {
        _prepareLaunch();
        vm.deal(address(this), address(this).balance + 2 * (W_POL + B0));

        vm.expectPartialRevert(GenesisDeployer.FundingMismatch.selector);
        new GenesisDeployer{value: W_POL + B0 - 1}(_params());

        vm.expectPartialRevert(GenesisDeployer.FundingMismatch.selector);
        new GenesisDeployer{value: W_POL + B0 + 1}(_params());
    }

    // -------------------------------------------------------- authority teardown

    /// @notice Exactly the Safe holds treasury authority; nothing else does.
    function test_FinalRoleTopologyIsSafeOnly() public view {
        bytes32 admin = treasury.DEFAULT_ADMIN_ROLE();
        bytes32 operator = treasury.OPERATOR_ROLE();

        assertTrue(treasury.hasRole(admin, REHEARSAL_SAFE), "Safe holds DEFAULT_ADMIN_ROLE");
        assertTrue(treasury.hasRole(operator, REHEARSAL_SAFE), "Safe holds OPERATOR_ROLE");

        assertFalse(treasury.hasRole(admin, address(genesis)), "the deployer renounced admin");
        assertFalse(treasury.hasRole(operator, address(genesis)), "the deployer renounced operator");
        assertFalse(treasury.hasRole(admin, address(this)), "the launch sender never held admin");
        assertFalse(treasury.hasRole(operator, address(this)), "the launch sender never held operator");
        assertFalse(treasury.hasRole(admin, address(0)), "the zero address holds nothing");
    }

    /// @notice The renounce is real, not cosmetic: the deployer cannot use the
    ///         authority it used to hold.
    function test_TheDeployerCannotExerciseTreasuryAuthorityAfterwards() public {
        vm.prank(address(genesis));
        vm.expectPartialRevert(bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")));
        treasury.setOpsRecipient(address(0xBEEF));

        // Control: the Safe can, so the surface exists and is merely out of the
        // deployer's reach.
        vm.prank(REHEARSAL_SAFE);
        treasury.setOpsRecipient(address(0xBEEF));
        assertEq(treasury.opsRecipient(), address(0xBEEF), "the Safe holds real authority");
    }

    /// @notice The immutable core has no role surface at all — nothing to
    ///         renounce, because nothing was ever grantable.
    function test_ImmutableCoreHasNoRoleSurface() public view {
        address[4] memory core = [address(vux), address(rig), address(reserve), address(lens)];
        for (uint256 i = 0; i < core.length; i++) {
            (bool hasRoleOk,) =
                core[i].staticcall(abi.encodeWithSignature("hasRole(bytes32,address)", bytes32(0), address(this)));
            assertFalse(hasRoleOk, "no hasRole on the immutable core");
            (bool ownerOk,) = core[i].staticcall(abi.encodeWithSignature("owner()"));
            assertFalse(ownerOk, "no owner() on the immutable core");
        }
        // The pool deployer's `owner()` exists deliberately and is permanently
        // dead — that is the property, not its absence.
        assertEq(poolDeployer.owner(), address(0), "VuxPoolDeployer.owner() is dead, not missing");
    }

    /// @notice `GenesisDeployer` is inert afterwards: its complete ABI is
    ///         read-only getters, so no callable `genesis()` surface exists.
    function test_GenesisDeployerExposesOnlyReadOnlyGetters() public view {
        string[] memory fns =
            vm.parseJsonKeys(vm.readFile("out/GenesisDeployer.sol/GenesisDeployer.json"), ".methodIdentifiers");
        assertGt(fns.length, 0, "the ABI was actually read");
        for (uint256 i = 0; i < fns.length; i++) {
            assertTrue(_isReadOnlyGetter(fns[i]), string.concat("unexpected callable surface: ", fns[i]));
        }
    }

    function _isReadOnlyGetter(string memory sig) private pure returns (bool) {
        bytes32 h = keccak256(bytes(sig));
        return h == keccak256("POOL_INIT_CODE_HASH()") || h == keccak256("weth()") || h == keccak256("poolDeployer()")
            || h == keccak256("reserve()") || h == keccak256("rig()") || h == keccak256("vux()")
            || h == keccak256("pool()") || h == keccak256("treasury()") || h == keccak256("lens()")
            || h == keccak256("operatorSafe()") || h == keccak256("wethPreSelf()")
            || h == keccak256("wethSanitizedFromReserve()") || h == keccak256("contaminationSwept()");
    }

    // ------------------------------------------------ gas and initcode headroom

    /// @notice EIP-3860 / EIP-170 headroom, measured rather than assumed.
    /// @dev Genesis embeds five creation codes inside one initcode, so the
    ///      launch transaction's size is a real launch-blocking risk
    ///      (sdd.md:L859, Sprint-7 risk row). Bounded here so future growth in
    ///      the embedded contracts fails in CI rather than at launch.
    ///
    ///      The figure that faces EIP-3860 is the **launch transaction's** init
    ///      code, which is the creation code PLUS the ABI-encoded constructor
    ///      arguments — `GenesisParams` is a fourteen-field static tuple, so 448
    ///      bytes that the artifact alone does not show. Measuring only the
    ///      artifact would overstate the headroom by exactly that much; the
    ///      broadcast rehearsal's recorded 48,057-byte payload is this sum.
    function test_InitcodeAndRuntimeHeadroom() public view {
        string memory artifact = vm.readFile("out/GenesisDeployer.sol/GenesisDeployer.json");
        bytes memory creationCode = vm.parseJsonBytes(artifact, ".bytecode.object");
        bytes memory runtime = vm.parseJsonBytes(artifact, ".deployedBytecode.object");

        uint256 constructorArgs = abi.encode(_params()).length;
        assertEq(constructorArgs, 14 * 32, "GenesisParams encodes as a static 14-word tuple");

        uint256 launchInitcode = creationCode.length + constructorArgs;

        assertGt(creationCode.length, 40_000, "the measurement is reading the real artifact, not an empty one");
        assertLt(launchInitcode, 49_152, "the launch transaction's init code fits EIP-3860");
        assertLt(runtime.length, 24_576, "GenesisDeployer runtime fits EIP-170");
    }

    // --- launch variants used by the negatives --------------------------------

    function _launchWithSalt(bytes32 salt) private returns (address) {
        GenesisParams memory p = _params();
        p.salt = salt;
        return address(new GenesisDeployer{value: W_POL + B0}(p));
    }

    function _launchWithP0(uint256 num, uint256 den) private returns (address) {
        GenesisParams memory p = _params();
        p.p0Num = num;
        p.p0Den = den;
        return address(new GenesisDeployer{value: W_POL + B0}(p));
    }

    function _launchWithOpening(uint256 opening) private returns (address) {
        GenesisParams memory p = _params();
        p.bootstrapOpening = opening;
        return address(new GenesisDeployer{value: W_POL + B0}(p));
    }
}
