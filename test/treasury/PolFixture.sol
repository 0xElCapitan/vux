// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {Vm} from "../harness/Vm.sol";
import {MockSwapper} from "../mocks/MockSwapper.sol";
import {TreasuryFixture} from "./TreasuryFixture.sol";

/// @title PolFixture — the Sprint-5 POL sleeve against a live vendored pool.
/// @notice Extends the Sprint-4 topology rather than replacing it, for the reason
///         that fixture already gives: the identity checks and the accounting
///         boundary are only worth something against the real contracts. Sprint 5
///         adds the one thing Sprint 4 had no need of — an **initialized** pool
///         with a real position in it and real third parties trading against it.
///
///         Everything the POL/VYRF evidence rests on therefore happens on pinned
///         v3-core bytecode: real `mint` with a real pay-in callback, real fee
///         accrual out of real swaps, real `burn`/`collect` semantics, and the
///         real `tokensOwed` cell the fee-first ordering is a claim about. No
///         mock stands in for any of it.
///
///         The Sprint-4 files are left untouched, exactly as Sprint 4 left
///         Sprint 3's: their green run is part of that sprint's evidence.
abstract contract PolFixture is TreasuryFixture {
    /// @dev The genesis POL VUX (FR-1.1) — the whole `GENESIS_POL_SUPPLY`, which
    ///      `VUX`'s constructor mints to its creator and which therefore starts
    ///      out held by this test contract, exactly as genesis holds it
    ///      transiently in `GenesisDeployer` (sdd.md:L164, L168).
    uint256 internal constant POL_VUX = 150_000e18;

    /// @dev The POL WETH leg. An R-14 founder deployment-time fact in production;
    ///      here it is simply the amount that balances `POL_VUX` at `P0`, so the
    ///      mint consumes both sides and neither is trivially the binding one.
    uint256 internal constant W_POL = 300 ether;

    MockSwapper internal swapper;

    /// @dev Whether the canonical sort put VUX first. Every amount in this suite
    ///      is expressed in (VUX, WETH) terms and mapped through this, because
    ///      the ordering is an address-dependent accident that no assertion
    ///      should silently depend on.
    bool internal vuxIsToken0;

    // --- setup ---------------------------------------------------------------

    /// @dev The Sprint-4 system, plus an initialized pool at the genesis price.
    ///      Initialization is separate from `_deploySystem` on purpose: Sprint-4
    ///      suites are built against an uninitialized pool and must keep running
    ///      against exactly the state they were accepted on.
    function _deployPolSystem() internal {
        _deploySystem();
        vuxIsToken0 = address(vux) < address(weth);
        IUniswapV3Pool(pool).initialize(_genesisSqrtPriceX96());
        swapper = new MockSwapper(IUniswapV3Pool(pool));
    }

    /// @dev `P0 = 1.10 x N0 = 1.10 x B0/S0` (FR-1.4), encoded as the pool's
    ///      token1-per-token0 Q64.96 sqrt price. Exact wei rational in, floor at
    ///      both steps, matching the encoding rule at sdd.md:L185.
    function _genesisSqrtPriceX96() internal view returns (uint160) {
        (uint256 numerator, uint256 denominator) = vuxIsToken0 ? (11 * B0, 10 * S0) : (10 * S0, 11 * B0);
        return uint160(Math.sqrt(Math.mulDiv(numerator, 1 << 192, denominator)));
    }

    // --- POL helpers ---------------------------------------------------------

    /// @dev Fund the treasury and mint the canonical position, the way genesis
    ///      step 7 does: the tokens are transferred in first, and the treasury
    ///      pays the pool out of its own balance through the callback.
    function _provisionPol(uint256 vuxAmt, uint256 wethAmt) internal {
        vux.transfer(address(treasury), vuxAmt);
        weth.mint(address(treasury), wethAmt);
        treasury.mintPolPosition(vuxAmt, wethAmt);
    }

    /// @dev The working position for suites that also need a VUX float. VUX
    ///      cannot be conjured — `mint` is `onlyRig` — so the genesis allocation
    ///      is the only VUX in existence at fixture time, and a suite that
    ///      provisioned all of it would have none left to trade with. Four fifths
    ///      in, one fifth held, balanced at `P0` on both legs.
    function _provisionPol() internal {
        _provisionPol(120_000e18, 240 ether);
    }

    /// @dev Accrue **both** fee legs the honest way: a trader buys VUX with WETH
    ///      (charging a WETH-denominated fee) and sells the VUX back (charging a
    ///      VUX-denominated one). Returns an upper bound on each.
    ///
    ///      A round trip rather than two independent swaps because the trader has
    ///      to obtain VUX before it can sell any — the same constraint every real
    ///      counterparty has, and the reason no test here can hand itself VUX.
    function _accrueBothFeeLegs(uint256 wethIn) internal returns (uint256 wethFeeBound, uint256 vuxFeeBound) {
        weth.mint(address(swapper), wethIn);
        wethFeeBound = _swapWethForVux(wethIn);
        vuxFeeBound = _swapVuxForWeth(vux.balanceOf(address(swapper)));
    }

    function _polPositionKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked(address(treasury), treasury.tickLower(), treasury.tickUpper()));
    }

    function _polLiquidity() internal view returns (uint128 liquidity) {
        (liquidity,,,,) = IUniswapV3Pool(pool).positions(_polPositionKey());
    }

    /// @dev `tokensOwed` in (VUX, WETH) terms — the cell the VYRF ordering
    ///      property is a statement about.
    function _polTokensOwed() internal view returns (uint256 vuxOwed, uint256 wethOwed) {
        (,,, uint128 owed0, uint128 owed1) = IUniswapV3Pool(pool).positions(_polPositionKey());
        return vuxIsToken0 ? (owed0, owed1) : (owed1, owed0);
    }

    function _sqrtPriceX96() internal view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
    }

    // --- third-party trading (the only source of fees) ------------------------

    /// @dev Fund the swapper so it can pay for what it takes.
    function _fundSwapper(uint256 vuxAmt, uint256 wethAmt) internal {
        if (vuxAmt != 0) vux.transfer(address(swapper), vuxAmt);
        if (wethAmt != 0) weth.mint(address(swapper), wethAmt);
    }

    /// @dev Buy VUX with `wethIn`, accruing a WETH-denominated fee to the
    ///      position. Returns the fee the pool charged, computed independently of
    ///      the pool from the pinned fee tier.
    function _swapWethForVux(uint256 wethIn) internal returns (uint256 feeCharged) {
        swapper.swap(!vuxIsToken0, int256(wethIn), _limitFor(!vuxIsToken0));
        return _feeOn(wethIn);
    }

    /// @dev Sell `vuxIn`, accruing a VUX-denominated fee.
    function _swapVuxForWeth(uint256 vuxIn) internal returns (uint256 feeCharged) {
        swapper.swap(vuxIsToken0, int256(vuxIn), _limitFor(vuxIsToken0));
        return _feeOn(vuxIn);
    }

    /// @dev An upper bound on the fee a `amountIn` exact-input swap charges.
    ///      v3 takes `ceil(amountIn x fee / (1e6 - fee))` on the consumed portion;
    ///      bounding it above by one wei of slack is deliberate — every use is on
    ///      the large side of a `<=`, where over-approximating is the safe
    ///      direction and under-approximating would make the assertion vacuous.
    function _feeOn(uint256 amountIn) internal view returns (uint256) {
        return Math.mulDiv(amountIn, FIXTURE_FEE, 1_000_000 - FIXTURE_FEE, Math.Rounding.Ceil) + 1;
    }

    /// @dev A price limit that never binds, so a swap is bounded by its input
    ///      rather than by the limit. `MIN_SQRT_RATIO + 1` / `MAX_SQRT_RATIO - 1`
    ///      are the pool's own admissible extremes.
    function _limitFor(bool zeroForOne) internal pure returns (uint160) {
        return zeroForOne ? 4295128740 : 1461446703485210103287273052203988822378723970341;
    }

    // --- zero-standing-approval assertion -------------------------------------

    /// @dev Sprint-5 AC: "Zero standing approvals after every pool operation".
    ///      Checked against every counterparty the treasury ever transfers to, so
    ///      it is a statement about the contract rather than about the pool
    ///      relationship alone.
    function _assertNoStandingApprovals(string memory what) internal view {
        address[4] memory spenders = [pool, hardReserveAddr(), address(rig), address(swapper)];
        for (uint256 i = 0; i < spenders.length; i++) {
            assertEq(vux.allowance(address(treasury), spenders[i]), 0, string.concat(what, ": VUX allowance"));
            assertEq(weth.allowance(address(treasury), spenders[i]), 0, string.concat(what, ": WETH allowance"));
        }
    }

    function hardReserveAddr() internal view returns (address) {
        return address(reserve);
    }

    // --- log inspection -------------------------------------------------------

    // The accepted schema (sdd.md §3.2). None of the three POL events indexes a
    // field, so every assertion about them is an assertion about `data`.
    bytes32 internal constant POL_POSITION_CHANGED_TOPIC =
        keccak256("PolPositionChanged(int8,uint256,uint256,uint128)");
    bytes32 internal constant VYRF_HARVEST_TOPIC = keccak256("VyrfHarvest(uint256,uint256)");
    bytes32 internal constant VUX_PURCHASED_TOPIC = keccak256("VuxPurchasedForPol(uint256,uint256)");
    bytes32 internal constant STRATEGIC_INFLOW_TOPIC = keccak256("StrategicInflow(uint8,address,uint256)");
    bytes32 internal constant TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)");

    function _countLogs(Vm.Log[] memory logs, bytes32 topic0) internal pure returns (uint256 n) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == topic0) n++;
        }
    }

    /// @dev The single log with `topic0`; fails if there is not exactly one, so a
    ///      duplicate emission cannot be silently read past.
    function _oneLog(Vm.Log[] memory logs, bytes32 topic0) internal pure returns (Vm.Log memory found) {
        uint256 seen;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length == 0 || logs[i].topics[0] != topic0) continue;
            found = logs[i];
            seen++;
        }
        if (seen != 1) fail(string.concat("expected exactly one matching log, saw ", vm.toString(seen)));
    }

    /// @dev The `VyrfHarvest` legs, in (VUX burned, WETH to Hard) order.
    function _vyrfLegs(Vm.Log[] memory logs) internal pure returns (uint256 vuxBurned, uint256 wethToHard) {
        return abi.decode(_oneLog(logs, VYRF_HARVEST_TOPIC).data, (uint256, uint256));
    }

    /// @dev The `PolPositionChanged` record, decoded.
    function _polChange(Vm.Log[] memory logs)
        internal
        pure
        returns (int8 direction, uint256 vuxDelta, uint256 wethDelta, uint128 liquidityDelta)
    {
        return abi.decode(_oneLog(logs, POL_POSITION_CHANGED_TOPIC).data, (int8, uint256, uint256, uint128));
    }

    /// @dev Total VUX burned in `logs`, read from ERC-20 `Transfer(_, 0x0, v)`
    ///      events on the token itself — the supply-change record the accepted
    ///      burn-cause pairing joins against (sdd.md:L544).
    function _vuxBurnedInLogs(Vm.Log[] memory logs) internal view returns (uint256 burned) {
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.emitter != address(vux) || log.topics.length != 3 || log.topics[0] != TRANSFER_TOPIC) continue;
            if (address(uint160(uint256(log.topics[2]))) != address(0)) continue;
            burned += abi.decode(log.data, (uint256));
        }
    }
}
