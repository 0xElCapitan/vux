// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {BaseTest} from "../harness/BaseTest.sol";
import {Vm} from "../harness/Vm.sol";
import {MockWeth} from "../mocks/MockWeth.sol";
import {HardReserve} from "../../src/HardReserve.sol";
import {Rig} from "../../src/Rig.sol";
import {VUX} from "../../src/VUX.sol";

/// @title RigFixture — the production wiring topology, in a test.
/// @notice Sprint 2's `ReserveFixture` reproduced the `VUX ↔ HardReserve`
///         2-cycle with CREATE prediction rather than inventing a setter. The
///         Rig closes a second cycle (`VUX ↔ Rig`), so this fixture reproduces
///         the real genesis order and the real prediction: Reserve at nonce n,
///         Rig at n+1, VUX at n+2, each constructed against the predicted token
///         address and asserted afterwards. No fixture is allowed to need a
///         wiring setter, because production has none (sdd.md:L157-L166).
///
///         The Strategic destination is a **plain address**. Sprint 3's accepted
///         boundary is exactly that — the residual leg is a plain WETH transfer
///         with no callback and no interface, and `StrategicTreasury` is Sprint 4
///         (sdd.md:L138; sprint.md Sprint 3 Dependencies). Using an address here
///         is the specified design, not a mock standing in for one.
abstract contract RigFixture is BaseTest {
    /// @dev Strategic residual destination for Sprint 3.
    address internal constant TREASURY = address(0x7EA5);
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    address internal constant CAROL = address(0xCA401);
    address internal constant ATTACKER = address(0xBADBAD);

    /// @dev Genesis supply: `150_000e18 + 1` raw (INV-2, prd.md:L582).
    uint256 internal constant S0 = 150_000e18 + 1;

    // --- rehearsal pricing values -------------------------------------------
    //
    // The three USD targets (≈$50 / ≈$10 / ≈$1) are converted once, off-chain,
    // pre-deployment, and are R-14 deployment-time founder facts (prd.md:L335) —
    // no accepted authority fixes their wei values, and Sprint 3 must not freeze
    // them. These are a self-consistent *rehearsal* set that preserves the frozen
    // 50 : 10 : 1 ratio and satisfies the FR-1.4 cushion inequality
    // `BOOTSTRAP_OPENING <= P0×S0 − B0` (25 <= 300 − 272.72… = 27.27…), so the
    // fixture starts from a state genesis could actually produce.
    uint256 internal constant BOOTSTRAP_OPENING = 25 ether;
    uint256 internal constant MINIMUM_OPENING = 5 ether;
    uint256 internal constant DECAY_FLOOR = 0.5 ether;

    /// @dev `B0 = P0 × S0 / 1.10` at a genesis marginal price of 0.002 WETH/VUX,
    ///      i.e. `floor(300e18 × 10 / 11)`.
    uint256 internal constant B0 = 272_727_272_727_272_727_272;

    uint256 internal constant EPOCH_PERIOD = 3_000;
    uint256 internal constant INITIAL_UPS = 4e18;
    uint256 internal constant HALVING_PERIOD = 30 days;

    MockWeth internal weth;
    HardReserve internal reserve;
    Rig internal rig;
    VUX internal vux;

    /// @dev Deploys the system in its genesis state and funds the Reserve with
    ///      exactly `B0`, which is what `GenesisDeployer` will do in Sprint 7.
    function _deploySystem() internal {
        weth = new MockWeth();

        // Reserve = nonce n, Rig = n+1, VUX = n+2.
        address predictedVux = vm.computeCreateAddress(address(this), uint256(vm.getNonce(address(this))) + 2);

        reserve = new HardReserve(address(weth), predictedVux);
        rig = new Rig(
            address(weth), address(reserve), predictedVux, TREASURY, BOOTSTRAP_OPENING, MINIMUM_OPENING, DECAY_FLOOR
        );
        vux = new VUX(address(rig), address(reserve));

        assertEq(address(vux), predictedVux, "CREATE prediction held (the genesis wiring method)");
        assertEq(vux.rig(), address(rig), "token points at the real rig");
        assertEq(address(rig.vux()), address(vux), "rig points at the real token");
        assertEq(rig.reserve(), address(reserve), "rig points at the real reserve");

        // Genesis funds the Reserve. The Reserve is born empty (its constructor
        // sanitizes), so this transfer is the whole of `B`.
        weth.mint(address(this), B0);
        weth.transfer(address(reserve), B0);
        assertEq(reserve.backing(), B0, "genesis backing is exactly B0");
        assertEq(rig.king(), address(reserve), "Reserve is the genesis King (FR-6.1)");
    }

    /// @dev Fund `who` with WETH and pre-approve the Rig, so `take` is a single
    ///      call in the test body.
    function _fund(address who, uint256 amount) internal {
        weth.mint(who, amount);
        vm.prank(who);
        weth.approve(address(rig), type(uint256).max);
    }

    /// @dev Take the throne as `who` at the current price with no slippage bound.
    function _take(address who) internal returns (uint256 price) {
        price = rig.currentPrice();
        _fund(who, price);
        vm.prank(who);
        rig.take(type(uint256).max);
    }

    // --- the settlement record -----------------------------------------------

    /// @dev The decoded `Settled` log. Assertions read the emitted record rather
    ///      than re-reading contract state, because the event is what an indexer
    ///      and every downstream truth surface actually consume (FR-14.1).
    struct SettledRecord {
        uint64 epochId;
        address outgoingKing;
        address newKing;
        bool bootstrap;
        uint256 price;
        uint256 kingLeg;
        uint256 strategicLeg;
        uint256 reserveLeg;
        uint256 bPre;
        uint256 sPre;
        uint256 dR;
        uint256 qRaw;
        uint256 qSafe;
        uint256 qMint;
        uint256 nextOpening;
        uint256 epochUPS;
    }

    bytes32 internal constant SETTLED_TOPIC = keccak256(
        "Settled(uint64,address,address,bool,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)"
    );

    /// @dev Take the throne and return the decoded settlement record.
    function _takeRecorded(address who) internal returns (SettledRecord memory r) {
        vm.recordLogs();
        _take(who);
        return _decodeSettled(vm.getRecordedLogs());
    }

    function _decodeSettled(Vm.Log[] memory logs) internal pure returns (SettledRecord memory r) {
        bool found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length != 4 || logs[i].topics[0] != SETTLED_TOPIC) continue;
            if (found) fail("more than one Settled event in one settlement");
            found = true;

            r.epochId = uint64(uint256(logs[i].topics[1]));
            r.outgoingKing = address(uint160(uint256(logs[i].topics[2])));
            r.newKing = address(uint160(uint256(logs[i].topics[3])));
            (
                r.bootstrap,
                r.price,
                r.kingLeg,
                r.strategicLeg,
                r.reserveLeg,
                r.bPre,
                r.sPre,
                r.dR,
                r.qRaw,
                r.qSafe,
                r.qMint,
                r.nextOpening,
                r.epochUPS
            ) = abi.decode(
                logs[i].data,
                (bool, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
            );
        }
        if (!found) fail("no Settled event emitted");
    }

    /// @dev Consume the bootstrap state, leaving `ALICE` as the first public King
    ///      and the public clock started. Most tests want an ordinary epoch, and
    ///      the bootstrap path is exercised on its own in `RigBootstrap.t.sol`.
    function _consumeBootstrap() internal {
        _take(ALICE);
        assertEq(rig.king(), ALICE, "bootstrap consumed; first public King seated");
        assertNotEq(uint256(rig.scheduleStart()), 0, "public clock started");
    }

    // --- expectation oracles -------------------------------------------------
    //
    // Independent re-derivations of the frozen formulas from the PRD text. They
    // deliberately do NOT call into `Rig`: an oracle that reuses the
    // implementation only proves the implementation equals itself.

    /// @dev `king = floor(P×8000/10000)`; `retained = P − king`;
    ///      `strategicCap = floor(P×1200/10000)`; `hardFloor = retained − cap`;
    ///      `D_need = ceil(Qraw×B_pre/S_pre)`;
    ///      `hardTarget = min(retained, max(hardFloor, D_need))`;
    ///      `strategic = retained − hardTarget` (FR-4.1, prd.md:L368).
    function _expectedLegs(uint256 price, uint256 qRaw, uint256 bPre, uint256 sPre)
        internal
        pure
        returns (uint256 kingLeg, uint256 hardTarget, uint256 strategicLeg)
    {
        kingLeg = (price * 8_000) / 10_000;
        uint256 retained = price - kingLeg;
        uint256 hardFloor = retained - (price * 1_200) / 10_000;
        uint256 dNeed = _ceilMulDiv(qRaw, bPre, sPre);

        uint256 floored = dNeed > hardFloor ? dNeed : hardFloor;
        hardTarget = floored < retained ? floored : retained;
        strategicLeg = retained - hardTarget;
    }

    // The two oracles below use **native** 256-bit arithmetic on purpose. They
    // exist to check `Math.mulDiv`, so re-using `Math.mulDiv` to predict its own
    // output would prove only that it equals itself. Solidity's checked
    // arithmetic makes the precondition self-enforcing: a caller that strays
    // outside the domain where `a×b` fits gets a revert — a failed test — rather
    // than a silently wrong expectation. Tests that deliberately explore the
    // overflow domain assert structural properties instead of an exact value.

    /// @dev `ceil(a×b/d)`.
    function _ceilMulDiv(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        uint256 p = a * b;
        return p / d + (p % d == 0 ? 0 : 1);
    }

    /// @dev `floor(a×b/d)`.
    function _floorMulDiv(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        return (a * b) / d;
    }

    /// @dev `INITIAL_UPS >> min((t − scheduleStart)/30 days, 8)` (FR-3.3).
    function _expectedUps(uint256 elapsedSinceScheduleStart) internal pure returns (uint256) {
        uint256 halvings = elapsedSinceScheduleStart / HALVING_PERIOD;
        if (halvings > 8) halvings = 8;
        return INITIAL_UPS >> halvings;
    }
}
