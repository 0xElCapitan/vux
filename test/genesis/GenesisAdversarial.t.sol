// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 7 Task 7.4 (full-knowledge adversarial rehearsal)
//          and launch-security obligations 1, 2, 4, 5, 9, 11 of the twelve
//          sdd.md:L156 (the two-halved non-griefability theorem), L172-L184
//          (per-address prefunding defense table), L193 (nothing to create,
//          initialize, occupy, consume, or poison), L250 (lookalike pools are
//          irrelevant), L252-L258 (callback authentication), §9.2 threat row 23

import {GenesisDeployer} from "../../src/GenesisDeployer.sol";
import {Vm} from "../harness/Vm.sol";
import {IVuxPoolDeployer} from "../treasury/PoolDeployerHarness.sol";
import {GenesisFixture, IPoolPositions} from "./GenesisFixture.sol";

/// @dev Pushes ETH to an address that cannot refuse it. `selfdestruct` is the
///      only way to force native value into a contract with no payable entry
///      point, which is exactly the case sdd.md:L184 disposes of.
contract EthForcer {
    constructor(address payable target) payable {
        selfdestruct(target);
    }
}

/// @dev Every attacker `CREATE` happens here rather than in the test contract.
///      In production the launch EOA's nonce is the founder's own; letting the
///      adversary's deployments advance the *launch* account's nonce would model
///      a capability no attacker has, and would break the tx1 commitment for
///      reasons that have nothing to do with security.
contract Adversary {
    function forceEth(address payable target) external payable {
        new EthForcer{value: msg.value}(target);
    }

    function deployFrom(bytes memory initCode) external returns (address deployed) {
        assembly ("memory-safe") {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(deployed != address(0), "adversary deployment failed");
    }

    /// @dev A contract the attacker controls, calling the gate. Proves the
    ///      commitment resists a *contract* caller as much as an EOA.
    function callGate(address deployer, bytes32 salt, address t0, address t1, uint24 fee, int24 spacing)
        external
        returns (address)
    {
        return IVuxPoolDeployer(deployer).deployCanonicalPool(salt, t0, t1, fee, spacing);
    }
}

/// @title GenesisAdversarialTest — the launch under total information leakage.
/// @notice The adversary here is not partial. Before the launch transaction
///         runs they know every future protocol address, the canonical pool
///         address, the token ordering, the fee tier and tick spacing, the
///         init-code hash, and the commitment salt itself. They act on all of it.
///
///         The theorem is deliberately stronger than "the launch does not
///         revert": genesis must complete **at the intended addresses with the
///         intended economics, to the wei**, and no attacker-controlled balance
///         may receive VEM mint credit, founder-capital classification,
///         realized-revenue classification, or protocol authority (sdd.md:L156).
contract GenesisAdversarialTest is GenesisFixture {
    address internal constant ATTACKER = address(0xA77ACC);

    /// @dev Deliberately enormous. The accepted rehearsal requires a *very
    ///      large* future-Reserve prefund, not one wei: `B` is defined as a raw
    ///      balance, so size is the whole attack.
    uint256 internal constant HUGE_RESERVE_PREFUND = 1_000_000 ether;
    uint256 internal constant PREFUND = 5_000 ether;
    uint256 internal constant FORCED_ETH = 13 ether;

    /// @dev Every fee tier a public v3 deployment enables, so the lookalike
    ///      sweep is exhaustive rather than illustrative.
    uint24[4] internal FEE_TIERS = [uint24(100), 500, 3_000, 10_000];
    int24[4] internal TICK_SPACINGS = [int24(1), 10, 60, 200];

    Adversary internal adversary;
    address[] internal hostilePools;

    function setUp() public {
        adversary = new Adversary();
    }

    // -------------------------------------------------------------------------

    /// @notice The whole rehearsal: every attack class fires between tx1 and
    ///         tx2, then the legitimate launch runs and every fact is exact.
    function test_FullKnowledgeAdversaryCannotAlterOneWeiOfGenesis() public {
        _prepareLaunch();

        // --- the adversary acts, knowing everything ---------------------------
        _assertNamespacesAreUnoccupied();
        _prefundEveryPredictedAddress();
        _forceEthEverywhere();
        _createHostileLookalikePoolsAtEveryFeeTier();
        _attemptToConsumeTheOneShot();
        _spamAroundTheLaunch();

        // --- the legitimate launch, unchanged ---------------------------------
        vm.recordLogs();
        GenesisDeployer g = _launch();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // 1. It landed exactly where tx1's commitment bound it.
        assertEq(address(g), predictedGenesis, "genesis landed at the predicted address");
        assertEq(address(reserve), predictedReserve, "Reserve at its predicted address");
        assertEq(address(rig), predictedRig, "Rig at its predicted address");
        assertEq(address(vux), predictedVux, "VUX at its predicted address");
        assertEq(address(treasury), predictedTreasury, "treasury at its predicted address");
        assertEq(address(lens), predictedLens, "Lens at its predicted address");
        assertEq(pool, predictedPool, "the canonical pool is the predicted CREATE2 address");

        // 2. The exact economics. Not approximately, and not weakened to `>=`.
        assertEq(weth.balanceOf(address(reserve)), B0, "physical B0 exactly, after a 1,000,000 ETH prefund");
        assertEq(vux.totalSupply(), S0, "S0 exactly");
        assertEq(vux.balanceOf(address(reserve)), 1, "the permanent seed, exactly");
        assertGt(uint256(_polLiquidity()), 0, "the canonical POL position exists");
        (uint160 stored,,,,,,) = IPoolPositions(pool).slot0();
        assertEq(uint256(stored), uint256(sqrtP0X96), "and opened at exactly the intended price");

        // 3. Physical N0 and P0/N0, computed from live state rather than records.
        assertEq(P0_NUM * vux.totalSupply() * 10, P0_DEN * weth.balanceOf(address(reserve)) * 11, "P0/N0 == 1.10");
        (uint256 bPre,,) = lens.hardStats();
        assertEq(bPre, B0, "first-settlement B_pre is exactly B0");

        // 4. The attacker's donations were classified, never credited.
        _assertAttackerReceivedNothing();
        _assertContaminationClassifiedAsStrategicInventory(logs);

        // 5. Every hostile pool is still irrelevant.
        _assertHostilePoolsAreReferencedNowhere();

        // 6. No authority anywhere but the Safe.
        _assertAuthorityTopologyIntact();
    }

    // ------------------------------------------------ class: arbitrary prefunding

    /// @notice Obligation 4 — WETH at every predicted address cannot alter genesis.
    function test_PrefundingEveryPredictedAddressLeavesGenesisExact() public {
        _prepareLaunch();
        _prefundEveryPredictedAddress();
        _launch();

        assertEq(weth.balanceOf(address(reserve)), B0, "Reserve holds exactly B0");
        assertEq(vux.totalSupply(), S0, "supply untouched by donations");
        assertEq(weth.balanceOf(address(genesis)), 0, "the deployer closed at zero");
        assertEq(vux.balanceOf(address(genesis)), 0, "and holds no VUX");

        // The accepted defense table's "provably stuck" row: no code path in
        // these contracts reads, moves, or asserts their own WETH balance, so
        // the donation is permanently inert. Still being there IS the property.
        assertEq(weth.balanceOf(address(vux)), PREFUND, "VUX donation is inert and untouched");
        assertEq(weth.balanceOf(address(rig)), PREFUND, "Rig donation is inert and untouched");
        assertEq(weth.balanceOf(address(lens)), PREFUND, "Lens donation is inert and untouched");
        assertEq(weth.balanceOf(address(poolDeployer)), PREFUND, "pool-deployer donation is inert");

        assertEq(treasury.realizedRevenue(address(weth)), 0, "no donation became realized revenue");
    }

    /// @notice Obligation 5 — a very large future-Reserve prefund is sanitized in
    ///         the constructor and ends as unattributed Strategic inventory.
    function test_VeryLargeReservePrefundIsSanitizedAndReclassified() public {
        _prepareLaunch();
        _donateWeth(predictedReserve, HUGE_RESERVE_PREFUND);
        assertEq(weth.balanceOf(predictedReserve), HUGE_RESERVE_PREFUND, "the attacker's WETH is sitting there");

        vm.recordLogs();
        _launch();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Born empty, then funded with exactly B0 — the frozen invariant.
        assertEq(weth.balanceOf(address(reserve)), B0, "the Reserve ends at exactly B0, not B0 + prefund");
        assertEq(genesis.wethSanitizedFromReserve(), HUGE_RESERVE_PREFUND, "the full amount was sanitized out");
        assertEq(genesis.contaminationSwept(), HUGE_RESERVE_PREFUND, "and swept as contamination");

        // The evidence trail sdd.md:L177 requires.
        assertTrue(
            _sawEvent(logs, keccak256("PreGenesisWethSanitized(uint256)"), address(reserve)),
            "PreGenesisWethSanitized emitted by the Reserve"
        );
        assertTrue(
            _sawEvent(logs, keccak256("PreGenesisContaminationSwept(uint256,uint256,uint256)"), address(genesis)),
            "the deployer evented the sweep distinctly from founder capital"
        );

        // Unattributed Strategic inventory: present as a balance, absent from
        // every revenue and mint-credit cell.
        assertGe(weth.balanceOf(address(treasury)), HUGE_RESERVE_PREFUND, "the treasury holds it as inventory");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "zero revenue classification");
        assertEq(vux.totalSupply(), S0, "zero VEM mint credit: supply is untouched");
        _assertPolPrincipalIsFounderCapitalOnly();

        (uint256 b,,) = lens.hardStats();
        assertEq(b, B0, "first-settlement B_pre is exactly B0");
    }

    /// @notice The sanitization capability does not survive into runtime.
    function test_NoSanitizationOrRecoveryAuthoritySurvivesIntoRuntime() public {
        _prepareLaunch();
        _donateWeth(predictedReserve, HUGE_RESERVE_PREFUND);
        _launch();

        // A post-genesis donation stays put: nothing can sweep it out again.
        // (Runtime donations are the separate, long-accepted benign class — they
        // only raise `B` and lower future `Qsafe`, sdd.md:L177.)
        _donateWeth(address(reserve), 7 ether);
        assertEq(weth.balanceOf(address(reserve)), B0 + 7 ether, "post-genesis donations simply raise B");

        for (uint256 i = 0; i < 4; i++) {
            (bool ok,) = address(reserve).call(_recoveryAttempt(i));
            assertFalse(ok, "no sweep, recovery, or admin path exists on the Reserve runtime");
        }
        assertEq(weth.balanceOf(address(reserve)), B0 + 7 ether, "and nothing moved");
    }

    /// @notice Forced ETH is economically irrelevant: nothing reads ETH balances.
    function test_ForcedNativeEthIsIrrelevantToEveryGenesisQuantity() public {
        _prepareLaunch();
        _forceEthEverywhere();
        assertEq(predictedGenesis.balance, FORCED_ETH, "ETH was really forced onto the deployer address");

        _launch();

        assertEq(weth.balanceOf(address(reserve)), B0, "B0 exact");
        assertEq(vux.totalSupply(), S0, "S0 exact");
        // Only `msg.value` is wrapped, so the forced ETH sits there untouched
        // and uncounted — the accepted disposition (sdd.md:L184).
        assertEq(address(genesis).balance, FORCED_ETH, "forced ETH was neither wrapped nor read");
        assertEq(weth.balanceOf(address(genesis)), 0, "and the WETH close is still exactly zero");
        assertEq(weth.balanceOf(address(reserve)), B0, "the Reserve's ETH balance changed nothing");
    }

    // ------------------------------------------- class: hostile lookalike pools

    /// @notice Obligations 1 and 2 — hostile lookalike pools at every fee tier,
    ///         hostile initialization, and total irrelevance.
    function test_HostileLookalikePoolsAtEveryFeeTierAreIrrelevant() public {
        _prepareLaunch();
        _createHostileLookalikePoolsAtEveryFeeTier();
        assertEq(hostilePools.length, FEE_TIERS.length, "a hostile pool exists at every tier");

        _launch();

        _assertHostilePoolsAreReferencedNowhere();
        assertEq(weth.balanceOf(address(reserve)), B0, "genesis economics unaffected");
        assertEq(vux.totalSupply(), S0, "supply unaffected");
        assertGt(uint256(_polLiquidity()), 0, "the canonical position minted normally");
    }

    /// @notice A hostile pool cannot pass itself off as the canonical one.
    function test_CallbackForgeryFromAHostilePoolIsRejected() public {
        _prepareLaunch();
        _createHostileLookalikePoolsAtEveryFeeTier();
        _launch();

        for (uint256 i = 0; i < hostilePools.length; i++) {
            vm.prank(hostilePools[i]);
            vm.expectPartialRevert(bytes4(keccak256("CallbackUnauthorizedCaller(address)")));
            treasury.uniswapV3MintCallback(1, 1, "");
        }

        // Even the REAL pool cannot: outside an armed operation the context is
        // NONE, so being the canonical caller is not sufficient (sdd.md:L255).
        vm.prank(pool);
        vm.expectPartialRevert(bytes4(keccak256("CallbackContextMismatch(uint8,uint8)")));
        treasury.uniswapV3MintCallback(1, 1, "");

        vm.prank(ATTACKER);
        vm.expectPartialRevert(bytes4(keccak256("CallbackUnauthorizedCaller(address)")));
        treasury.uniswapV3MintCallback(1, 1, "");
    }

    /// @notice Obligation 11 — the genesis mint callback really fired, and left
    ///         no standing approval behind.
    function test_GenesisPolCallbackWasExercisedAndLeftNoApproval() public {
        _prepareLaunch();
        _launch();

        // v3 verifies payment as a within-operation balance delta, so a position
        // with liquidity is itself proof the callback ran and paid.
        assertGt(uint256(_polLiquidity()), 0, "the genesis mint callback paid the pool");

        assertEq(weth.allowance(address(treasury), pool), 0, "no standing WETH approval survives");
        assertEq(vux.allowance(address(treasury), pool), 0, "no standing VUX approval survives");
        assertEq(weth.allowance(address(genesis), pool), 0, "the deployer granted no approval either");
        assertEq(weth.allowance(address(genesis), address(treasury)), 0, "nor to the treasury");
        assertEq(vux.allowance(address(genesis), address(treasury)), 0, "nor for VUX");
    }

    // ------------------------------------------------ class: commitment attacks

    /// @notice Obligation 9 — salt extraction, guessed salts, and contract
    ///         callers all fail; the one-shot is consumed by genesis alone.
    function test_SaltExtractionAndWrongSenderCannotConsumeTheOneShot() public {
        _prepareLaunch();
        _attemptToConsumeTheOneShot();

        // Nothing above consumed it, so the real launch still works.
        _launch();
        assertEq(poolDeployer.canonicalPool(), pool, "the one-shot was consumed by genesis, not by the attacker");
        assertEq(poolDeployer.owner(), address(0), "and the deployer is permanently ownerless");

        // Consumed means consumed, for everyone, forever.
        (address t0, address t1) = _sorted(address(vux), address(weth));
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("PoolAlreadyDeployed"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIER, TICK_SPACING);

        vm.prank(address(genesis));
        vm.expectRevert(bytes("PoolAlreadyDeployed"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIER, TICK_SPACING);
    }

    /// @notice Protocol-fee authority is unreachable forever, so no external
    ///         party can ever dilute VYRF yield on the canonical pool.
    function test_ProtocolFeeAuthorityIsPermanentlyUnreachable() public {
        _prepareLaunch();
        _launch();

        assertEq(poolDeployer.owner(), address(0), "factory owner is dead");

        vm.prank(ATTACKER);
        (bool ok,) = pool.call(abi.encodeWithSignature("setFeeProtocol(uint8,uint8)", uint8(4), uint8(4)));
        assertFalse(ok, "setFeeProtocol is unreachable");

        // Unreachable for the operator Safe too, which is the actual property:
        // it is dead, not merely withheld from attackers.
        vm.prank(REHEARSAL_SAFE);
        (bool safeOk,) = pool.call(abi.encodeWithSignature("setFeeProtocol(uint8,uint8)", uint8(4), uint8(4)));
        assertFalse(safeOk, "and unreachable for the operator Safe");
    }

    // --------------------------------------------- class: namespace occupation

    /// @notice Computing an address is not occupying it. An attacker with the
    ///         identical salt and identical init code lands somewhere else,
    ///         because CREATE2 binds to the deploying account.
    function test_Create2NamespaceIsExclusiveToTheProtocolDeployer() public {
        _prepareLaunch();

        (address t0, address t1) = _sorted(predictedVux, address(weth));
        IVuxPoolDeployer rogue = _adversaryPoolDeployer();
        address roguePool = rogue.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIER, TICK_SPACING);

        assertNotEq(roguePool, predictedPool, "same salt, same init code, different deployer, different address");
        assertEq(predictedPool.code.length, 0, "the canonical namespace slot is still empty");

        _launch();
        assertEq(pool, predictedPool, "genesis occupied its own namespace");
        assertNotEq(pool, roguePool, "the rogue pool is a different contract entirely");
    }

    /// @notice Pre-funding the computable pool address does not block CREATE2.
    /// @dev EIP-684 collision requires code or a nonce at the target, neither of
    ///      which a third party can place there (sdd.md:L181).
    function test_PrefundingTheCanonicalPoolAddressDoesNotBlockCreate2() public {
        _prepareLaunch();
        _donateWeth(predictedPool, PREFUND);
        _forceEthTo(predictedPool);

        _launch();

        assertEq(pool, predictedPool, "the pool deployed into the pre-funded address");
        assertGt(uint256(_polLiquidity()), 0, "and the canonical position minted normally");
        (uint160 stored,,,,,,) = IPoolPositions(pool).slot0();
        assertEq(uint256(stored), uint256(sqrtP0X96), "at exactly the intended price");

        // The donation is unattributed excess owned by no position: our cost
        // basis tracks only what we actually deposited.
        _assertPolPrincipalIsFounderCapitalOnly();
    }

    // ---------------------------------------------------- attacker action set

    function _prefundEveryPredictedAddress() private {
        _donateWeth(predictedGenesis, PREFUND);
        _donateWeth(predictedReserve, HUGE_RESERVE_PREFUND);
        _donateWeth(predictedRig, PREFUND);
        _donateWeth(predictedVux, PREFUND);
        _donateWeth(predictedTreasury, PREFUND);
        _donateWeth(predictedLens, PREFUND);
        _donateWeth(predictedPool, PREFUND);
        _donateWeth(address(poolDeployer), PREFUND);
        _donateWeth(REHEARSAL_SAFE, PREFUND);
    }

    function _forceEthEverywhere() private {
        _forceEthTo(predictedGenesis);
        _forceEthTo(predictedReserve);
        _forceEthTo(predictedRig);
        _forceEthTo(predictedVux);
        _forceEthTo(predictedTreasury);
        _forceEthTo(predictedLens);
        _forceEthTo(predictedPool);
    }

    function _forceEthTo(address target) private {
        vm.deal(address(adversary), address(adversary).balance + FORCED_ETH);
        adversary.forceEth{value: FORCED_ETH}(payable(target));
    }

    /// @dev Real pools, from real pinned bytecode, at every tier, initialized at
    ///      a hostile price. The attacker owns their own factories-of-one, which
    ///      is strictly MORE capability than a shared public factory would give
    ///      them — and it still buys nothing.
    function _createHostileLookalikePoolsAtEveryFeeTier() private {
        delete hostilePools;
        (address t0, address t1) = _sorted(predictedVux, address(weth));
        for (uint256 i = 0; i < FEE_TIERS.length; i++) {
            IVuxPoolDeployer rogue = _adversaryPoolDeployer();
            address p = rogue.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIERS[i], TICK_SPACINGS[i]);
            // Hostile initialization at a price of the attacker's choosing.
            IPoolPositions(p).initialize(sqrtP0X96 / 4 + 1);
            hostilePools.push(p);
        }
    }

    /// @dev A rogue deployer, created from the attacker's own nonce, whose
    ///      commitment binds to this test contract so the attacker can drive it.
    function _adversaryPoolDeployer() private returns (IVuxPoolDeployer) {
        bytes memory initCode = _poolDeployerInitCode(keccak256(abi.encode(address(this), REHEARSAL_SALT)));
        return IVuxPoolDeployer(adversary.deployFrom(initCode));
    }

    /// @dev Every consumption attempt actually available to an attacker who has
    ///      extracted the salt from the pending launch transaction. Impersonating
    ///      `predictedGenesis` is deliberately NOT attempted: no key and no code
    ///      exist at that address, so `msg.sender` cannot be it — that is the
    ///      property the gate rests on, and forging it with a cheatcode would
    ///      test the cheatcode rather than the gate.
    function _attemptToConsumeTheOneShot() private {
        (address t0, address t1) = _sorted(predictedVux, address(weth));

        // From an EOA, with the real salt.
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("BadCommitment"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, FEE_TIER, TICK_SPACING);

        // From an EOA, with a guessed salt.
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("BadCommitment"));
        poolDeployer.deployCanonicalPool(keccak256("guess"), t0, t1, FEE_TIER, TICK_SPACING);

        // From a contract the attacker controls, with the real salt — a
        // different `msg.sender` shape, same answer.
        vm.expectRevert(bytes("BadCommitment"));
        adversary.callGate(address(poolDeployer), REHEARSAL_SALT, t0, t1, FEE_TIER, TICK_SPACING);

        // And with different pool parameters, in case the gate keyed on those.
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("BadCommitment"));
        poolDeployer.deployCanonicalPool(REHEARSAL_SALT, t0, t1, 500, 10);
    }

    function _assertNamespacesAreUnoccupied() private view {
        // There is no EVM operation that places code at an address derived from
        // another account, so the observable claim is that they are all still
        // empty when the launch begins.
        assertEq(predictedGenesis.code.length, 0, "no code at the future deployer");
        assertEq(predictedReserve.code.length, 0, "no code at the future Reserve");
        assertEq(predictedRig.code.length, 0, "no code at the future Rig");
        assertEq(predictedVux.code.length, 0, "no code at the future VUX");
        assertEq(predictedTreasury.code.length, 0, "no code at the future treasury");
        assertEq(predictedLens.code.length, 0, "no code at the future Lens");
        assertEq(predictedPool.code.length, 0, "no code at the canonical pool address");
    }

    function _spamAroundTheLaunch() private {
        // Mempool noise between tx1 and tx2: wraps, transfers, and repeated
        // failed gate attempts. None of it touches shared state genesis reads.
        for (uint256 i = 0; i < 5; i++) {
            _wrapFor(ATTACKER, 1 ether);
            vm.prank(ATTACKER);
            weth.transfer(predictedTreasury, 1 ether);
        }
    }

    function _recoveryAttempt(uint256 i) private view returns (bytes memory) {
        if (i == 0) return abi.encodeWithSignature("sweep(address)", ATTACKER);
        if (i == 1) return abi.encodeWithSignature("recover(address,uint256)", address(weth), uint256(1));
        if (i == 2) return abi.encodeWithSignature("rescueTokens(address,address)", address(weth), ATTACKER);
        return abi.encodeWithSignature("transferOwnership(address)", ATTACKER);
    }

    // ------------------------------------------------------------- assertions

    function _assertAttackerReceivedNothing() private view {
        assertEq(vux.balanceOf(ATTACKER), 0, "the attacker minted no VUX");
        assertEq(vux.balanceOf(address(adversary)), 0, "nor did their contract");
        (uint128 attackerPos,,,,) = _positionOf(ATTACKER);
        assertEq(uint256(attackerPos), 0, "the attacker owns no POL position");

        assertFalse(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), ATTACKER), "no admin role");
        assertFalse(treasury.hasRole(treasury.OPERATOR_ROLE(), ATTACKER), "no operator role");
        assertFalse(treasury.hasRole(treasury.OPERATOR_ROLE(), address(adversary)), "none for their contract");
    }

    function _assertContaminationClassifiedAsStrategicInventory(Vm.Log[] memory logs) private view {
        // Founder capital is exactly `W_POL + B0` and arrived only through the
        // in-transaction wrap; donations are a separate, evented quantity.
        assertEq(genesis.wethPreSelf(), PREFUND, "the deployer donation was recorded, not absorbed");
        assertEq(genesis.wethSanitizedFromReserve(), HUGE_RESERVE_PREFUND, "the Reserve donation was sanitized");
        assertEq(
            genesis.contaminationSwept(), PREFUND + HUGE_RESERVE_PREFUND, "and the total was swept as contamination"
        );

        assertEq(treasury.realizedRevenue(address(weth)), 0, "zero revenue classification for donations");
        _assertPolPrincipalIsFounderCapitalOnly();
        assertEq(vux.totalSupply(), S0, "zero VEM mint credit");
        assertTrue(
            _sawEvent(logs, keccak256("PreGenesisContaminationSwept(uint256,uint256,uint256)"), address(genesis)),
            "the sweep is evented distinctly from founder capital"
        );
    }

    function _assertHostilePoolsAreReferencedNowhere() private view {
        for (uint256 i = 0; i < hostilePools.length; i++) {
            assertNotEq(hostilePools[i], pool, "a hostile pool is not the canonical pool");
            assertNotEq(hostilePools[i], treasury.pool(), "and is not what the treasury points at");
            assertNotEq(IPoolPositions(hostilePools[i]).factory(), address(poolDeployer), "different factory");
            (uint128 liq,,,,) = IPoolPositions(hostilePools[i])
                .positions(keccak256(abi.encodePacked(address(treasury), treasury.tickLower(), treasury.tickUpper())));
            assertEq(uint256(liq), 0, "the protocol owns no liquidity in a hostile pool");
        }
        assertEq(treasury.pool(), pool, "the treasury's pool identity is the canonical one");
    }

    function _assertAuthorityTopologyIntact() private view {
        bytes32 admin = treasury.DEFAULT_ADMIN_ROLE();
        bytes32 operator = treasury.OPERATOR_ROLE();
        assertTrue(treasury.hasRole(admin, REHEARSAL_SAFE), "the Safe holds admin");
        assertTrue(treasury.hasRole(operator, REHEARSAL_SAFE), "the Safe holds operator");
        assertFalse(treasury.hasRole(admin, address(genesis)), "the deployer holds nothing");
        assertFalse(treasury.hasRole(operator, address(genesis)), "the deployer holds nothing");
        assertFalse(treasury.hasRole(admin, address(this)), "the launch sender holds nothing");
        assertFalse(treasury.hasRole(operator, address(this)), "the launch sender holds nothing");
        assertFalse(treasury.hasRole(admin, ATTACKER), "the attacker holds nothing");
        assertEq(poolDeployer.owner(), address(0), "no pool-deployer authority survives");
    }

    /// @dev POL principal is bounded by the founder legs. The pool takes
    ///      slightly less than what is offered because v3 quantizes liquidity
    ///      into whole units, and the remainder stays as treasury-held POL
    ///      inventory (sdd.md:L168) -- so the exact figure is a few hundred wei
    ///      below the leg. The load-bearing claim is the BOUND: a donation
    ///      booked as principal is precisely what exceeding the leg would look
    ///      like, and that cannot happen.
    function _assertPolPrincipalIsFounderCapitalOnly() private view {
        assertLe(treasury.polWethPrincipal(), W_POL, "POL WETH principal never exceeds the founder leg");
        assertLt(W_POL - treasury.polWethPrincipal(), 1e12, "the shortfall is v3 quantization dust");
        assertLe(treasury.polVuxPrincipal(), POL_VUX, "POL VUX principal never exceeds the founder allocation");
        assertLt(POL_VUX - treasury.polVuxPrincipal(), 1e18, "likewise on the VUX leg");
    }

    function _sawEvent(Vm.Log[] memory logs, bytes32 topic0, address emitter) private pure returns (bool) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == emitter && logs[i].topics.length > 0 && logs[i].topics[0] == topic0) return true;
        }
        return false;
    }
}
