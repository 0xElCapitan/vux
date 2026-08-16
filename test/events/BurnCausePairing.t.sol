// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-14.1 (supply changes and their cause), FR-14 acceptance
//          (prd.md:L538 "burn causes with zero ambiguity"), sdd.md:L544,
//          sdd.md:L572-L580 (`supply_change.cause` domain)
//          sprint.md Sprint 6 Task 6.3

import {Vm} from "../harness/Vm.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {PolFixture} from "../treasury/PolFixture.sol";
import {VUX} from "../../src/VUX.sol";

/// @title BurnCausePairingTest — every supply change, joined to its cause.
/// @notice The accepted reconstruction claim is that "an independent indexer,
///         using only observable facts, can reproduce ... burn causes with zero
///         ambiguity" (prd.md:L538), by the join sdd.md:L544 specifies:
///         `Transfer(holder -> 0)` paired with the cause event emitted in the
///         same transaction.
///
///         This suite is that join, executed. It does not read protocol state to
///         decide what happened — it reads the logs, exactly as an indexer must,
///         and asserts that each supply-change `Transfer` has one and only one
///         determinable cause. A test that consulted `realizedRevenue` or
///         `totalSupply` to attribute a burn would prove nothing about what an
///         observer can see.
///
///         The `supply_change.cause` domain (sdd.md:L576-L577) is
///         `genesis | settlement_mint | redemption_burn | vyrf_burn |
///         other_authorized_burn`; every case below lands in exactly one of them.
contract BurnCausePairingTest is PolFixture {
    uint8 internal constant CLAIM = 1;
    uint256 internal constant CAP = type(uint128).max;

    MockStrategy internal strategy;

    bytes32 internal constant SETTLED_TOPIC = keccak256(
        "Settled(uint64,address,address,bool,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)"
    );
    bytes32 internal constant REDEEMED_TOPIC =
        keccak256("Redeemed(address,address,uint256,uint256,uint256,uint256)");
    bytes32 internal constant VUX_REVENUE_BURNED_TOPIC = keccak256("VuxRevenueBurned(uint256)");

    /// @dev How many cause events of each class one transaction's logs contain.
    struct Causes {
        uint256 settled;
        uint256 redeemed;
        uint256 vyrf;
        uint256 revenueBurn;
    }

    function setUp() public {
        _deployPolSystem();
        strategy = new MockStrategy();
    }

    // -----------------------------------------------------------------------
    // The indexer's view: cause events and supply-change transfers
    // -----------------------------------------------------------------------

    function _causes(Vm.Log[] memory logs) internal pure returns (Causes memory c) {
        c.settled = _countLogs(logs, SETTLED_TOPIC);
        c.redeemed = _countLogs(logs, REDEEMED_TOPIC);
        c.vyrf = _countLogs(logs, VYRF_HARVEST_TOPIC);
        c.revenueBurn = _countLogs(logs, VUX_REVENUE_BURNED_TOPIC);
    }

    /// @dev How many distinct *burn-cause* classes are present. More than one in
    ///      a single transaction is the ambiguity the accepted design rules out;
    ///      `Settled` is excluded because a settlement mints and never burns.
    function _distinctBurnCauseClasses(Causes memory c) internal pure returns (uint256 n) {
        if (c.redeemed != 0) n++;
        if (c.vyrf != 0) n++;
        if (c.revenueBurn != 0) n++;
    }

    /// @dev VUX minted in these logs, read from `Transfer(0x0, _, v)` on the
    ///      token — the mint-side twin of `_vuxBurnedInLogs`.
    function _vuxMintedInLogs(Vm.Log[] memory logs) internal view returns (uint256 minted) {
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.emitter != address(vux) || log.topics.length != 3 || log.topics[0] != TRANSFER_TOPIC) continue;
            if (address(uint160(uint256(log.topics[1]))) != address(0)) continue;
            minted += abi.decode(log.data, (uint256));
        }
    }

    // -----------------------------------------------------------------------
    // Scripted flows
    // -----------------------------------------------------------------------

    /// @dev `genesis`: the two constructor mints are the token's own deployment
    ///      transaction and carry no cause event, which is what identifies them —
    ///      no `Settled` exists yet, and none ever can for a mint that predates
    ///      the Rig's first settlement.
    function test_GenesisMintsAreIdentifiedByTheDeploymentTransaction() public {
        vm.recordLogs();
        VUX fresh = new VUX(address(rig), address(reserve));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 minted;
        uint256 transfers;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != address(fresh) || logs[i].topics[0] != TRANSFER_TOPIC) continue;
            if (address(uint160(uint256(logs[i].topics[1]))) != address(0)) continue;
            transfers++;
            minted += abi.decode(logs[i].data, (uint256));
        }

        assertEq(transfers, 2, "exactly two genesis mints");
        assertEq(minted, fresh.GENESIS_POL_SUPPLY() + fresh.GENESIS_RESERVE_SEED(), "and they are the genesis amounts");
        assertEq(minted, fresh.totalSupply(), "which is the whole of S at genesis");

        Causes memory c = _causes(logs);
        assertEq(c.settled, 0, "no settlement caused these");
        assertEq(c.redeemed + c.vyrf + c.revenueBurn, 0, "and no burn cause is present");
    }

    /// @dev `settlement_mint`: `Transfer(0x0 -> outgoingKing)` joined to `Settled`.
    ///      The minted amount must equal the record's `qMint` — not `qRaw`, and
    ///      not `qSafe`, which is the distinction FR-15 is built on.
    function test_SettlementMintPairsWithSettled() public {
        _takeThrone(ALICE); // bootstrap: mints nothing
        vm.warp(vm.getBlockTimestamp() + 600);

        vm.recordLogs();
        _takeThrone(NON_OPERATOR);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Causes memory c = _causes(logs);
        assertEq(c.settled, 1, "exactly one Settled");
        assertEq(c.redeemed + c.vyrf + c.revenueBurn, 0, "a settlement burns nothing");

        (,,,,,,,, uint256 qRaw, uint256 qSafe, uint256 qMint,,) = _decodeSettledTail(_oneLog(logs, SETTLED_TOPIC));
        uint256 minted = _vuxMintedInLogs(logs);

        assertGt(minted, 0, "the reign minted");
        assertEq(minted, qMint, "the mint equals the settled Qmint");
        assertEq(_vuxBurnedInLogs(logs), 0, "and nothing was burned");
        assertLe(qMint, qRaw, "Qmint never exceeds the raw clock limit");
        assertLe(qMint, qSafe, "nor the VEM cap");
    }

    /// @dev `redemption_burn`: `Transfer(holder -> 0x0)` joined to `Redeemed`.
    function test_RedemptionBurnPairsWithRedeemed() public {
        _takeThrone(ALICE);
        vm.warp(vm.getBlockTimestamp() + 900);
        _takeThrone(NON_OPERATOR); // ALICE's reign settles; ALICE is minted

        uint256 held = vux.balanceOf(ALICE);
        assertGt(held, 0, "ALICE has mined VUX to redeem");

        vm.recordLogs();
        vm.prank(ALICE);
        reserve.redeem(held / 2, ALICE);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Causes memory c = _causes(logs);
        assertEq(c.redeemed, 1, "exactly one Redeemed");
        assertEq(_distinctBurnCauseClasses(c), 1, "exactly one burn-cause class: no ambiguity");
        assertEq(c.settled, 0, "no settlement in this transaction");

        (uint256 q, uint256 payout,,) = abi.decode(
            _oneLog(logs, REDEEMED_TOPIC).data, (uint256, uint256, uint256, uint256)
        );
        Vm.Log memory redeemed = _oneLog(logs, REDEEMED_TOPIC);

        assertEq(_vuxBurnedInLogs(logs), q, "the burn equals the Redeemed q");
        assertEq(q, held / 2, "which is what the holder asked to burn");
        assertGt(payout, 0, "and it paid out");
        assertEq(address(uint160(uint256(redeemed.topics[1]))), ALICE, "attributed to the redeeming holder");
        assertEq(_vuxMintedInLogs(logs), 0, "a redemption mints nothing");
    }

    /// @dev `vyrf_burn`: `Transfer(treasury -> 0x0)` joined to `VyrfHarvest`,
    ///      whose `vuxFeesBurned` leg is separately observable from the WETH leg
    ///      (FR-11.1/11.2).
    function test_VyrfBurnPairsWithVyrfHarvest() public {
        _provisionPol();
        _accrueBothFeeLegs(20 ether);

        vm.recordLogs();
        treasury.harvestPol();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Causes memory c = _causes(logs);
        assertEq(c.vyrf, 1, "exactly one VyrfHarvest");
        assertEq(_distinctBurnCauseClasses(c), 1, "exactly one burn-cause class: no ambiguity");
        assertEq(c.settled + c.redeemed, 0, "neither a settlement nor a redemption");

        (uint256 vuxBurned, uint256 wethToHard) = _vyrfLegs(logs);
        assertGt(vuxBurned, 0, "the VUX fee leg was non-empty");
        assertEq(_vuxBurnedInLogs(logs), vuxBurned, "the burn equals the harvest's VUX leg");
        assertGt(wethToHard, 0, "and the WETH leg is a separate, non-burning number");
        assertEq(_vuxMintedInLogs(logs), 0, "a harvest mints nothing");
    }

    /// @dev `other_authorized_burn`: `Transfer(treasury -> 0x0)` joined to
    ///      `VuxRevenueBurned` — the F-46 path, and the only VUX-revenue
    ///      treatment that exists.
    function test_RevenueBurnPairsWithVuxRevenueBurned() public {
        _earnVuxRevenue(10 ether);

        vm.recordLogs();
        treasury.burnVuxRevenue();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Causes memory c = _causes(logs);
        assertEq(c.revenueBurn, 1, "exactly one VuxRevenueBurned");
        assertEq(_distinctBurnCauseClasses(c), 1, "exactly one burn-cause class: no ambiguity");

        uint256 amount = abi.decode(_oneLog(logs, VUX_REVENUE_BURNED_TOPIC).data, (uint256));
        assertEq(amount, 10 ether, "the credited revenue");
        assertEq(_vuxBurnedInLogs(logs), amount, "the burn equals the announced amount");
    }

    /// @dev A cause event is not itself proof that supply moved:
    ///      `burnVuxRevenue` with no credit emits `VuxRevenueBurned(0)`. An
    ///      indexer must key the supply change off the `Transfer`, and the
    ///      amount off the event — which is exactly what this asserts.
    function test_AZeroCauseEventPairsWithNoSupplyChange() public {
        vm.recordLogs();
        treasury.burnVuxRevenue();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(_causes(logs).revenueBurn, 1, "the cause event is still emitted");
        assertEq(abi.decode(_oneLog(logs, VUX_REVENUE_BURNED_TOPIC).data, (uint256)), 0, "announcing zero");
        assertEq(_vuxBurnedInLogs(logs), 0, "and no Transfer to 0x0 accompanies it");
    }

    /// @dev The residual class. `VUX.burn` is permissionless — any holder may
    ///      burn their own VUX — and such a burn emits no protocol cause event,
    ///      because no protocol contract caused it.
    ///
    ///      That is still unambiguous, and this test is what establishes it: the
    ///      transaction contains a supply-change `Transfer` and *zero* cause
    ///      events, which is a distinguishable signature and not a collision with
    ///      any of the four protocol causes. An indexer books it as
    ///      `other_authorized_burn` by exclusion.
    function test_HolderSelfBurnCarriesNoCauseEventAndCollidesWithNone() public {
        vux.transfer(ALICE, 5 ether);

        vm.recordLogs();
        vm.prank(ALICE);
        vux.burn(5 ether);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Causes memory c = _causes(logs);
        assertEq(_distinctBurnCauseClasses(c), 0, "no protocol cause event: the signature of a holder burn");
        assertEq(c.settled, 0, "and no settlement");
        assertEq(_vuxBurnedInLogs(logs), 5 ether, "the supply change is observable regardless");
    }

    // -----------------------------------------------------------------------
    // The ambiguity property, over a scripted multi-op scenario
    // -----------------------------------------------------------------------

    /// @dev The load-bearing claim (sdd.md:L544) is that no transaction ever
    ///      presents an indexer with two competing burn causes. Asserted across
    ///      a scenario that exercises every burn path the protocol has, plus a
    ///      settlement and a holder burn, one transaction at a time.
    function test_NoTransactionEverPresentsTwoCompetingBurnCauses() public {
        _provisionPol();
        _earnVuxRevenue(3 ether);
        _accrueBothFeeLegs(20 ether);

        _takeThrone(ALICE);
        vm.warp(vm.getBlockTimestamp() + 700);
        _takeThrone(NON_OPERATOR);
        vux.transfer(ALICE, 2 ether);

        // Each entry below is one transaction, recorded and attributed on its own.
        uint256 totalBurned;
        uint256 attributedBurns;

        // 1 — settlement (mints; burns nothing)
        vm.warp(vm.getBlockTimestamp() + 400);
        vm.recordLogs();
        _takeThrone(OPS_RECIPIENT);
        (uint256 burned1, uint256 classes1) = _auditOneTransaction(vm.getRecordedLogs());
        assertEq(classes1, 0, "settlement: no burn cause");
        assertEq(burned1, 0, "settlement: no burn");

        // 2 — VYRF harvest
        vm.recordLogs();
        treasury.harvestPol();
        (uint256 burned2, uint256 classes2) = _auditOneTransaction(vm.getRecordedLogs());
        assertEq(classes2, 1, "vyrf: exactly one burn cause");
        totalBurned += burned2;
        attributedBurns++;

        // 3 — revenue burn
        vm.recordLogs();
        treasury.burnVuxRevenue();
        (uint256 burned3, uint256 classes3) = _auditOneTransaction(vm.getRecordedLogs());
        assertEq(classes3, 1, "revenue: exactly one burn cause");
        totalBurned += burned3;
        attributedBurns++;

        // 4 — redemption
        uint256 held = vux.balanceOf(ALICE);
        vm.recordLogs();
        vm.prank(ALICE);
        reserve.redeem(held / 2, ALICE);
        (uint256 burned4, uint256 classes4) = _auditOneTransaction(vm.getRecordedLogs());
        assertEq(classes4, 1, "redemption: exactly one burn cause");
        totalBurned += burned4;
        attributedBurns++;

        // 5 — holder self-burn (the residual class)
        vm.recordLogs();
        vm.prank(ALICE);
        vux.burn(vux.balanceOf(ALICE));
        (uint256 burned5, uint256 classes5) = _auditOneTransaction(vm.getRecordedLogs());
        assertEq(classes5, 0, "holder burn: no protocol cause, by exclusion");
        totalBurned += burned5;

        assertEq(attributedBurns, 3, "all three protocol burn causes were exercised");
        assertGt(totalBurned, 0, "and supply actually fell");
    }

    /// @dev One transaction's logs, audited the way an indexer must: how much VUX
    ///      left supply, and how many distinct burn-cause classes claim it. The
    ///      "no ambiguity" property is `classes <= 1`, asserted here so every
    ///      caller inherits it without repeating it.
    function _auditOneTransaction(Vm.Log[] memory logs) internal view returns (uint256 burned, uint256 classes) {
        Causes memory c = _causes(logs);
        classes = _distinctBurnCauseClasses(c);
        burned = _vuxBurnedInLogs(logs);

        assertLe(classes, 1, "two competing burn causes in one transaction (sdd.md:L544 violated)");
        assertLe(c.settled, 1, "more than one Settled in one transaction");
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    function _takeThrone(address who) internal {
        uint256 price = rig.currentPrice();
        weth.mint(who, price);
        vm.startPrank(who);
        weth.approve(address(rig), price);
        rig.take(type(uint256).max);
        vm.stopPrank();
    }

    /// @dev Credit VUX-denominated realized revenue through a CLAIM strategy —
    ///      the only route by which `realizedRevenue[VUX]` becomes non-zero.
    function _earnVuxRevenue(uint256 amount) internal {
        _admitMatured(address(strategy), address(weth), CAP, CLAIM);
        strategy.lieUnits(1);

        address[] memory rewards = new address[](1);
        rewards[0] = address(vux);
        strategy.setRewardAssets(rewards);
        vux.transfer(address(strategy), amount);
        strategy.setHarvestAmount(address(vux), amount);

        treasury.harvestYield(address(strategy));
        assertEq(treasury.realizedRevenue(address(vux)), amount, "VUX revenue credited");
    }

    /// @dev The non-indexed tail of a `Settled` record.
    function _decodeSettledTail(Vm.Log memory log)
        internal
        pure
        returns (
            bool bootstrap,
            uint256 price,
            uint256 kingLeg,
            uint256 strategicLeg,
            uint256 reserveLeg,
            uint256 bPre,
            uint256 sPre,
            uint256 dR,
            uint256 qRaw,
            uint256 qSafe,
            uint256 qMint,
            uint256 nextOpening,
            uint256 epochUPS
        )
    {
        return abi.decode(
            log.data,
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
    }
}
