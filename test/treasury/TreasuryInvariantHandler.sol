// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {HardReserve} from "../../src/HardReserve.sol";
import {Rig} from "../../src/Rig.sol";
import {VUX} from "../../src/VUX.sol";
import {BaseTest} from "../harness/BaseTest.sol";
import {Vm} from "../harness/Vm.sol";
import {MockErc20} from "../mocks/MockErc20.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {MockWeth} from "../mocks/MockWeth.sol";

/// @title TreasuryInvariantHandler — the bounded action space of Sprint 4.
/// @notice The Sprint-3 harness (`test/rig/`) drives the monetary core alone.
///         This one drives the core **and** the treasury in the same randomized
///         sequences, which is the only way to ask INV-23/INV-24's actual
///         question: does anything a Strategic surface can do — deploy, lose,
///         recall, classify, distribute, write off — reach `B`, `S`, redemption,
///         or mint authority?
///
///         The Sprint-3 files are deliberately untouched. Their suite still runs
///         and still guards INV-1…22; this adds a second, wider one rather than
///         editing a landed harness whose green run is part of Sprint 3's
///         evidence.
///
/// @dev **Ghosts are attributed by cause, never measured from the thing they
///      check.** `ghostHardIn` accumulates the `Settled` event's `reserveLeg`,
///      the donation amounts this handler sent, and the `toHard` argument it
///      passed — never `reserve.backing()`. An invariant fed by a measurement of
///      its own subject is a tautology; this one fails the moment any
///      unattributed wei reaches the Reserve.
///
///      Every action shapes its inputs so a legitimate call never reverts, which
///      is what lets the suite run with `fail_on_revert = true`.
contract TreasuryInvariantHandler is BaseTest {
    uint8 internal constant NETTING = 0;
    uint8 internal constant CLAIM = 1;
    uint8 internal constant UNITIZED = 2;

    MockWeth internal immutable weth;
    MockErc20 internal immutable rewardAsset;
    HardReserve internal immutable reserve;
    Rig internal immutable rig;
    VUX internal immutable vux;
    StrategicTreasury internal immutable treasury;

    address[3] internal actors = [address(0xA11CE), address(0xB0B), address(0xCA401)];
    MockStrategy[3] internal strategies;
    /// @dev One strategy per mode, fixed, so every run exercises all three.
    uint8[3] internal modes = [NETTING, CLAIM, UNITIZED];

    // --- ghost accounting -----------------------------------------------------

    uint256 public ghostHardIn;
    uint256 public ghostHardOut;
    uint256 public ghostGenesisSupply;
    uint256 public ghostMintedBySettlement;
    uint256 public ghostBurnedByRedemption;
    uint256 public ghostBurnedByTreasury;

    /// @dev Value that actually arrived from a strategy-side flow, measured on
    ///      the token. Bare transfers (the settlement leg, donations, funding)
    ///      are deliberately excluded: they are principal-side inventory and must
    ///      never be able to explain a revenue credit (§1.10 rule 5).
    mapping(address asset => uint256) public ghostReceivedFromStrategies;
    /// @dev Revenue that has left the `realizedRevenue` accumulator.
    mapping(address asset => uint256) public ghostRevenueAllocated;
    mapping(address strategy => mapping(address asset => uint256)) public ghostDeployed;

    uint256 public effectiveCalls;

    bytes32 internal constant SETTLED_TOPIC = keccak256(
        "Settled(uint64,address,address,bool,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)"
    );
    bytes32 internal constant REDEEMED_TOPIC = keccak256("Redeemed(address,address,uint256,uint256,uint256,uint256)");

    constructor(
        MockWeth weth_,
        MockErc20 rewardAsset_,
        HardReserve reserve_,
        Rig rig_,
        VUX vux_,
        StrategicTreasury treasury_,
        MockStrategy[3] memory strategies_
    ) {
        weth = weth_;
        rewardAsset = rewardAsset_;
        reserve = reserve_;
        rig = rig_;
        vux = vux_;
        treasury = treasury_;
        strategies = strategies_;
        ghostGenesisSupply = vux_.totalSupply();
    }

    function actorAt(uint256 i) external view returns (address) {
        return actors[i % actors.length];
    }

    function actorCount() external pure returns (uint256) {
        return 3;
    }

    function strategyAt(uint256 i) external view returns (address) {
        return address(strategies[i % strategies.length]);
    }

    function strategyCount() external pure returns (uint256) {
        return 3;
    }

    // =========================================================================
    // Monetary-core actions (the perturbation INV-23/24 must survive)
    // =========================================================================

    /// @dev Take the throne. The Strategic residual leg lands in the REAL
    ///      treasury here, which is what makes the treasury's inventory grow
    ///      from the same source production will use.
    function settle(uint256 seed) external {
        address actor = actors[seed % actors.length];
        uint256 price = rig.currentPrice();
        weth.mint(actor, price);
        vm.prank(actor);
        weth.approve(address(rig), price);

        vm.recordLogs();
        vm.prank(actor);
        rig.take(type(uint256).max);
        _absorbSettlement(vm.getRecordedLogs());
        effectiveCalls++;
    }

    function _absorbSettlement(Vm.Log[] memory logs) private {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length != 4 || logs[i].topics[0] != SETTLED_TOPIC) continue;
            // Accepted schema (sdd.md §3.2): 3 indexed topics + 13 data fields —
            // bootstrap, price, kingLeg, strategicLeg, reserveLeg, bPre, sPre,
            // dR, qRaw, qSafe, qMint, nextOpening, epochUPS.
            // The bootstrap settlement's King IS the Reserve (FR-6.1), so its 80%
            // king leg lands in `B` as well — the "approximately 88% or greater
            // Hard" of INV-22. Attributing only `reserveLeg` would leave that
            // wei unexplained and break the identity for a reason that has
            // nothing to do with the treasury.
            address outgoingKing = address(uint160(uint256(logs[i].topics[2])));
            (,, uint256 kingLeg, /*strategicLeg*/, uint256 reserveLeg,,,,,, uint256 qMint,,) = abi.decode(
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
            ghostHardIn += reserveLeg;
            if (outgoingKing == address(reserve)) ghostHardIn += kingLeg;
            ghostMintedBySettlement += qMint;
        }
    }

    function redeemSome(uint256 seed) external {
        address actor = actors[seed % actors.length];
        uint256 balance = vux.balanceOf(actor);
        if (balance == 0) return;
        uint256 supply = vux.totalSupply();
        uint256 maxRedeemable = supply - reserve.S_MIN();
        uint256 q = bound(seed, 1, balance < maxRedeemable ? balance : maxRedeemable);
        if (q == 0) return;

        vm.recordLogs();
        vm.prank(actor);
        reserve.redeem(q, actor);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length != 3 || logs[i].topics[0] != REDEEMED_TOPIC) continue;
            (, uint256 payout,,) = abi.decode(logs[i].data, (uint256, uint256, uint256, uint256));
            ghostHardOut += payout;
        }
        ghostBurnedByRedemption += q;
        effectiveCalls++;
    }

    function donateToReserve(uint256 amount) external {
        amount = bound(amount, 1, 100 ether);
        weth.mint(address(this), amount);
        weth.transfer(address(reserve), amount);
        ghostHardIn += amount;
        effectiveCalls++;
    }

    function passTime(uint256 seconds_) external {
        vm.warp(vm.getBlockTimestamp() + bound(seconds_, 1, 3 days));
        effectiveCalls++;
    }

    // =========================================================================
    // Treasury actions
    // =========================================================================

    /// @dev Bare inventory, the shape the 12% settlement leg arrives in.
    function fundTreasuryInventory(uint256 amount) external {
        amount = bound(amount, 1 ether, 500 ether);
        weth.mint(address(treasury), amount);
        effectiveCalls++;
    }

    function admit(uint256 seed, uint256 cap) external {
        uint256 i = seed % strategies.length;
        (bool active,,) = treasury.admissionOf(address(strategies[i]));
        // Mode is immutable while admitted, and this handler keeps one fixed
        // mode per strategy, so re-admission is only ever a cap change.
        if (!active && treasury.unitsHeld(address(strategies[i])) != 0) return;

        treasury.admitStrategy(address(strategies[i]), address(weth), bound(cap, 1 ether, 1e24), modes[i]);
        effectiveCalls++;
    }

    function remove(uint256 seed) external {
        uint256 i = seed % strategies.length;
        (bool active,,) = treasury.admissionOf(address(strategies[i]));
        if (!active) return;
        treasury.removeStrategy(address(strategies[i]), seed % 2 == 0);
        effectiveCalls++;
    }

    function deploy(uint256 seed, uint256 amount) external {
        uint256 i = seed % strategies.length;
        address strategy = address(strategies[i]);

        (bool active,,) = treasury.admissionOf(strategy);
        if (!active) return;
        (uint256 cap, uint64 maturesAt) = treasury.limitOf(strategy, address(weth));
        if (maturesAt == 0 || vm.getBlockTimestamp() < maturesAt) return;

        uint256 outstanding = treasury.outstandingPrincipal(strategy, address(weth));
        if (outstanding >= cap) return;
        uint256 headroom = cap - outstanding;
        uint256 available = weth.balanceOf(address(treasury));
        if (available == 0) return;
        uint256 max = headroom < available ? headroom : available;
        uint256 size = bound(amount, 1, max);

        treasury.deployToStrategy(strategy, address(weth), size);
        ghostDeployed[strategy][address(weth)] += size;
        effectiveCalls++;
    }

    function recall(uint256 seed, uint256 amount) external {
        uint256 i = seed % strategies.length;
        address strategy = address(strategies[i]);
        uint256 held = weth.balanceOf(strategy);
        if (held == 0) return;
        uint256 size = bound(amount, 1, held);

        uint256 before = weth.balanceOf(address(treasury));
        treasury.recallFromStrategy(strategy, address(weth), size);
        ghostReceivedFromStrategies[address(weth)] += weth.balanceOf(address(treasury)) - before;
        effectiveCalls++;
    }

    /// @dev A strategy pays back MORE than it holds of the treasury's capital —
    ///      genuine profit, delivered. This is the only way revenue in WETH can
    ///      legitimately appear, so it must be exercised or the revenue-bound
    ///      invariant proves nothing.
    function returnWithProfit(uint256 seed, uint256 amount) external {
        uint256 i = seed % strategies.length;
        address strategy = address(strategies[i]);
        (, uint64 maturesAt) = treasury.limitOf(strategy, address(weth));
        if (maturesAt == 0) return; // never admitted for WETH: rule 2 would reject

        address actor = actors[seed % actors.length];
        uint256 size = bound(amount, 1, 200 ether);
        weth.mint(actor, size);
        vm.prank(actor);
        weth.approve(address(treasury), size);

        uint256 before = weth.balanceOf(address(treasury));
        vm.prank(actor);
        treasury.returnFor(strategy, address(weth), size);
        ghostReceivedFromStrategies[address(weth)] += weth.balanceOf(address(treasury)) - before;
        effectiveCalls++;
    }

    function harvest(uint256 seed, uint256 reward) external {
        uint256 i = seed % strategies.length;
        address strategy = address(strategies[i]);
        // The treasury's OWN stored mode is the gate, not this handler's plan: a
        // strategy that has never been admitted still reads as `NETTING` there.
        (, uint8 storedMode,) = treasury.admissionOf(strategy);
        if (storedMode == NETTING) return;

        uint256 size = bound(reward, 0, 50 ether);
        address[] memory assets = new address[](1);
        assets[0] = address(rewardAsset);
        strategies[i].setRewardAssets(assets);
        if (size != 0) {
            rewardAsset.mint(strategy, size);
            strategies[i].setHarvestAmount(address(rewardAsset), size);
        }

        uint256 before = rewardAsset.balanceOf(address(treasury));
        treasury.harvestYield(strategy);
        ghostReceivedFromStrategies[address(rewardAsset)] += rewardAsset.balanceOf(address(treasury)) - before;
        effectiveCalls++;
    }

    function redeemUnits(uint256 seed, uint256 units, uint256 payout) external {
        uint256 i = 2; // the UNITIZED strategy
        address strategy = address(strategies[i]);
        uint256 held = treasury.unitsHeld(strategy);
        if (held == 0) return;

        uint256 size = bound(units, 1, held);
        uint256 pay = bound(payout, 0, 300 ether);
        uint256 strategyBalance = weth.balanceOf(strategy);
        if (pay > strategyBalance) weth.mint(strategy, pay - strategyBalance);
        strategies[i].setRedeemPayout(address(weth), pay);

        uint256 before = weth.balanceOf(address(treasury));
        treasury.redeemUnits(strategy, size, 0);
        ghostReceivedFromStrategies[address(weth)] += weth.balanceOf(address(treasury)) - before;
        effectiveCalls++;
    }

    function closeStrategy(uint256 seed) external {
        uint256 i = seed % strategies.length;
        address strategy = address(strategies[i]);
        (bool active,,) = treasury.admissionOf(strategy);
        if (active) return;
        treasury.closeStrategy(strategy);
        effectiveCalls++;
    }

    /// @dev Total loss of everything a strategy holds — the FB-5 driver, run
    ///      inside the same randomized sequences as everything else.
    function strategyLosesEverything(uint256 seed) external {
        uint256 i = seed % strategies.length;
        address strategy = address(strategies[i]);
        uint256 held = weth.balanceOf(strategy);
        if (held == 0) return;
        vm.prank(strategy);
        weth.transfer(address(0xDEAD), held);
        effectiveCalls++;
    }

    function allocate(uint256 seed, uint256 amount) external {
        address asset = seed % 2 == 0 ? address(weth) : address(rewardAsset);
        uint256 credit = treasury.realizedRevenue(asset);
        if (credit == 0) return;
        uint256 size = bound(amount, 1, credit);

        // Split across the legs the asset is allowed to use. The Hard leg is
        // WETH-only, so a non-WETH allocation earmarks instead.
        //
        // The Hard leg physically transfers, so it is additionally capped by what
        // the treasury actually holds: a realized-revenue CREDIT is an
        // accumulator, not a segregated balance, and the operator may have
        // redeployed the assets behind it (see
        // `TreasuryRevenue.t.sol::test_ARedeployedAndLostRevenueCreditRemainsOutstanding`,
        // which pins that behaviour). Shaping it here keeps a legitimate call
        // from reverting, which is what lets the suite run `fail_on_revert`.
        uint256 toHard = asset == address(weth) ? size / 2 : 0;
        uint256 held = weth.balanceOf(address(treasury));
        if (toHard > held) toHard = held;
        uint256 toSignalers = size - toHard;

        treasury.allocateRevenue(asset, 0, toHard, 0, toSignalers);
        ghostRevenueAllocated[asset] += size;
        ghostHardIn += toHard;
        effectiveCalls++;
    }

    function burnVuxRevenue() external {
        uint256 credit = treasury.realizedRevenue(address(vux));
        treasury.burnVuxRevenue();
        ghostBurnedByTreasury += credit;
        effectiveCalls++;
    }
}
