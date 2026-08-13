// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {BaseTest} from "../harness/BaseTest.sol";
import {Vm} from "../harness/Vm.sol";
import {MockWeth} from "../mocks/MockWeth.sol";
import {HardReserve} from "../../src/HardReserve.sol";
import {Rig} from "../../src/Rig.sol";
import {VUX} from "../../src/VUX.sol";

/// @title RigInvariantHandler — the bounded action space of the monetary core.
/// @notice The handler is the half of a stateful invariant suite that decides
///         *what can happen*; `RigInvariants.t.sol` decides what must remain
///         true. Splitting them this way is what makes the suite extensible:
///         Sprints 4 and 5 add treasury and POL actions here and their own
///         invariants there, without touching either existing half
///         (sprint.md "Cross-sprint invariant suite ownership").
///
///         Every action shapes its own inputs so that a legitimate call never
///         reverts, which is what lets the suite run with `fail_on_revert =
///         true`. Under `false`, a handler that reverted on most sequences would
///         still report a green run having exercised almost nothing.
///
/// @dev Two kinds of checking live here, and the distinction is deliberate:
///
///      * **Per-operation** assertions (in the actions below) capture facts that
///        are only observable *at* the operation — the legs of one settlement,
///        the epoch it settled, who received its mint. State-only invariants
///        cannot see these, because the next operation overwrites them.
///      * **Global** invariants (in the test contract) capture facts that must
///        hold between every pair of operations, forever.
contract RigInvariantHandler is BaseTest {
    MockWeth internal immutable weth;
    HardReserve internal immutable reserve;
    Rig internal immutable rig;
    VUX internal immutable vux;
    address internal immutable treasury;

    address[4] internal actors =
        [address(0xA11CE), address(0xB0B), address(0xCA401), address(0xDA71D)];

    // --- ghost accounting -----------------------------------------------------
    // Every VUX that has ever existed, and every one that has ever stopped
    // existing, attributed to the single cause that created or destroyed it.

    uint256 public ghostGenesisSupply;
    uint256 public ghostMintedBySettlement;
    uint256 public ghostBurnedByRedemption;
    uint256 public ghostStrategicContributed;
    uint256 public ghostQrawOffered;
    uint256 public ghostQmintTaken;
    uint256 public ghostDonated;

    uint256 public settlements;
    uint256 public redemptions;
    uint256 public bootstrapSettlements;

    /// @dev Counts calls that did real work, so a suite that quietly degenerated
    ///      into no-ops is visible rather than green.
    uint256 public effectiveCalls;

    bytes32 internal constant SETTLED_TOPIC = keccak256(
        "Settled(uint64,address,address,bool,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)"
    );

    constructor(MockWeth weth_, HardReserve reserve_, Rig rig_, VUX vux_, address treasury_) {
        weth = weth_;
        reserve = reserve_;
        rig = rig_;
        vux = vux_;
        treasury = treasury_;
        ghostGenesisSupply = vux_.totalSupply();
    }

    function actorAt(uint256 i) external view returns (address) {
        return actors[i % actors.length];
    }

    function actorCount() external pure returns (uint256) {
        return 4;
    }

    /*----------  actions  --------------------------------------------------*/

    /// @notice Take the throne after an arbitrary wait, which may cross a halving
    ///         boundary or exhaust the epoch entirely.
    function takeThrone(uint256 actorSeed, uint256 waitSeed) external {
        address actor = actors[actorSeed % actors.length];

        // The wait spans all three interesting regions: mid-ramp, exactly at the
        // cap, and long past it.
        vm.warp(block.timestamp + bound(waitSeed, 0, 2 * uint256(rig.EPOCH_PERIOD())));

        uint256 bPre = reserve.backing();
        uint256 sPre = vux.totalSupply();
        uint256 outgoingVuxPre = vux.balanceOf(rig.king());
        address outgoingKing = rig.king();
        uint256 epochIdPre = rig.epochId();

        uint256 price = rig.currentPrice();
        weth.mint(actor, price);
        vm.startPrank(actor);
        weth.approve(address(rig), price);
        vm.recordLogs();
        rig.take(price);
        vm.stopPrank();

        _checkSettlement(vm.getRecordedLogs(), bPre, sPre, outgoingKing, outgoingVuxPre, epochIdPre);
        settlements++;
        effectiveCalls++;
    }

    /// @notice Redeem a random slice of a random holder's balance.
    function redeemSome(uint256 actorSeed, uint256 qSeed) external {
        address actor = actors[actorSeed % actors.length];
        uint256 balance = vux.balanceOf(actor);
        if (balance == 0) return;

        uint256 headroom = vux.totalSupply() - reserve.S_MIN();
        uint256 q = bound(qSeed, 1, balance < headroom ? balance : headroom);
        if (q == 0) return;

        uint256 bPre = reserve.backing();
        uint256 sPre = vux.totalSupply();

        vm.prank(actor);
        uint256 payout = reserve.redeem(q, actor);

        // Reserve-favouring rounding (INV-16) and pre-redemption pricing (INV-15).
        assertLe(payout * sPre, bPre * q, "redemption payout floors in the Reserve's favour");

        ghostBurnedByRedemption += q;
        redemptions++;
        effectiveCalls++;
    }

    /// @notice Move time without settling — the FB-2 "no challenger" shape, and
    ///         the way halvings get crossed while a reign is open.
    function passTime(uint256 waitSeed) external {
        vm.warp(block.timestamp + bound(waitSeed, 1, 45 days));
        effectiveCalls++;
    }

    /// @notice An unsolicited WETH donation to the Reserve. The long-accepted
    ///         benign class (sdd.md §9.1): it raises `B` and therefore *lowers*
    ///         future `Qsafe`. It must never create a mint or an entitlement.
    function donateToReserve(uint256 amountSeed) external {
        uint256 amount = bound(amountSeed, 1, 10 ether);
        weth.mint(address(reserve), amount);
        ghostDonated += amount;
        effectiveCalls++;
    }

    /*----------  per-settlement checking  -----------------------------------*/

    function _checkSettlement(
        Vm.Log[] memory logs,
        uint256 bPre,
        uint256 sPre,
        address outgoingKing,
        uint256 outgoingVuxPre,
        uint256 epochIdPre
    ) private {
        (
            uint64 epochId,
            address recordOutgoing,
            bool bootstrap,
            uint256 price,
            uint256 kingLeg,
            uint256 strategicLeg,
            uint256 reserveLeg,
            uint256 recordBPre,
            uint256 recordSPre,
            uint256 dR,
            uint256 qRaw,
            uint256 qSafe,
            uint256 qMint
        ) = _readSettled(logs);

        // INV-21 — the record describes the reign that was actually open, even
        // though successor state has already been written.
        assertEq(uint256(epochId), epochIdPre, "INV-21: the record carries the OUTGOING epoch id");
        assertEq(recordOutgoing, outgoingKing, "INV-21: the record names the OUTGOING King");
        assertEq(uint256(rig.epochId()), epochIdPre + 1, "INV-21: the counter advanced by exactly one");

        // INV-18/19/20 — the adaptive law, on this settlement's own numbers.
        uint256 retained = price - (price * rig.SPLIT_KING_BP()) / rig.BP_DENOM();
        uint256 strategicCap = (price * rig.STRATEGIC_CAP_BP()) / rig.BP_DENOM();
        uint256 hardFloor = retained - strategicCap;

        assertEq(kingLeg, (price * 8_000) / 10_000, "INV-18: king leg is exactly floor(80%)");
        assertEq(kingLeg + reserveLeg + strategicLeg, price, "INV-20: the three legs exhaust P");
        assertGe(reserveLeg, hardFloor, "INV-19: Hard receives at least the floor plus dust");
        assertLe(reserveLeg, retained, "INV-19: Hard receives at most the full retained 20%");
        assertLe(strategicLeg, strategicCap, "INV-19: Strategic never exceeds the floored 12% cap");
        assertEq(weth.balanceOf(address(rig)), 0, "INV-20: no other primary recipient, and no residue");

        // INV-9 — the epoch's own snapshot, capped at 3,000 eligible seconds.
        assertLe(qRaw, uint256(rig.EPOCH_PERIOD()) * 4e18, "INV-9: Qraw within 3000s at the maximum rate");

        // INV-6/12 — issuance is bounded by both the clock and measured reality.
        assertEq(recordBPre, bPre, "INV-12: B_pre is the pre-settlement physical balance");
        assertEq(recordSPre, sPre, "S_pre is the pre-settlement complete supply");
        assertLe(qMint, qRaw, "INV-6: Qmint <= Qraw");
        assertLe(qMint, qSafe, "INV-6: Qmint <= Qsafe");
        assertEq(qSafe, _floorMulDiv(dR, sPre, bPre), "Qsafe == floor(D_R x S_pre / B_pre)");

        // INV-13 — the non-dilution inequality, in cross-multiplied form.
        assertLe(bPre * qMint, dR * sPre, "INV-13: authorized issuance cannot reduce B/S");

        // INV-4 — the mint went to the outgoing King and nobody else.
        assertEq(vux.balanceOf(outgoingKing) - outgoingVuxPre, qMint, "INV-4: only the outgoing King was credited");

        // INV-7/22 — bootstrap mints zero.
        if (bootstrap) {
            assertEq(qRaw, 0, "INV-7: the bootstrap clock is disabled");
            assertEq(qMint, 0, "INV-7: bootstrap mints zero");
            assertGe(dR * 10_000, price * 8_800, "INV-22: bootstrap sends >= 88% to Hard");
            bootstrapSettlements++;
        }

        ghostMintedBySettlement += qMint;
        ghostStrategicContributed += strategicLeg;
        ghostQrawOffered += qRaw;
        ghostQmintTaken += qMint;
    }

    /// @dev Split out because the settlement record has more fields than the
    ///      stack can hold alongside the checks that consume them.
    function _readSettled(Vm.Log[] memory logs)
        private
        pure
        returns (
            uint64 epochId,
            address outgoingKing,
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
            uint256 qMint
        )
    {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length != 4 || logs[i].topics[0] != SETTLED_TOPIC) continue;

            epochId = uint64(uint256(logs[i].topics[1]));
            outgoingKing = address(uint160(uint256(logs[i].topics[2])));
            (bootstrap, price, kingLeg, strategicLeg, reserveLeg, bPre, sPre, dR, qRaw, qSafe, qMint,,) = abi.decode(
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
            return (
                epochId,
                outgoingKing,
                bootstrap,
                price,
                kingLeg,
                strategicLeg,
                reserveLeg,
                bPre,
                sPre,
                dR,
                qRaw,
                qSafe,
                qMint
            );
        }
        fail("every take must emit exactly one Settled record");
    }

    function _floorMulDiv(uint256 a, uint256 b, uint256 d) private pure returns (uint256) {
        return (a * b) / d;
    }
}
