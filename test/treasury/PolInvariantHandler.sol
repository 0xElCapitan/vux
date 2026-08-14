// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {HardReserve} from "../../src/HardReserve.sol";
import {Rig} from "../../src/Rig.sol";
import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {VUX} from "../../src/VUX.sol";
import {Vm} from "../harness/Vm.sol";
import {MockErc20} from "../mocks/MockErc20.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {MockSwapper} from "../mocks/MockSwapper.sol";
import {MockWeth} from "../mocks/MockWeth.sol";
import {TreasuryInvariantHandler} from "./TreasuryInvariantHandler.sol";

/// @title PolInvariantHandler — Sprint 4's action space, plus POL and VYRF.
/// @notice This **extends** the Sprint-4 handler rather than standing beside it,
///         which is the whole point: every Sprint-4 action (settle, redeem,
///         donate, admit, deploy, lose, recall, harvest, redeem units, close,
///         allocate, burn) still fires in the same randomized sequences, now
///         interleaved with minting POL, decreasing it, buying VUX for it,
///         harvesting fee yield, and third parties trading against the position.
///         A POL-only harness would have proved that POL is self-consistent; this
///         one asks whether POL can break anything that was true without it.
///
/// @dev **Fee ghosts are an independent upper bound, never a measurement of the
///      thing they check.** `ghostFeesCharged*` is computed from the *inputs this
///      handler put into the pool* and the pinned fee tier — never from
///      `collect`'s return, never from `tokensOwed`. That is what lets it bound
///      what a harvest may legitimately classify: if principal ever leaked into a
///      fee classification, the classified total would exceed fees the pool could
///      possibly have charged, and the invariant fails.
///
///      Every action shapes its inputs so a legitimate call never reverts, so the
///      suite still runs under `fail_on_revert = true`.
contract PolInvariantHandler is TreasuryInvariantHandler {
    bytes32 internal constant VYRF_TOPIC = keccak256("VyrfHarvest(uint256,uint256)");
    bytes32 internal constant POL_CHANGED_TOPIC = keccak256("PolPositionChanged(int8,uint256,uint256,uint128)");

    /// @dev Below this the book is too thin for a bounded trade to be meaningful,
    ///      and a price move large enough to reach the pool's own domain limit
    ///      would start reverting legitimate calls. Skipping is shaping, not
    ///      hiding: the thin-book and full-unwind paths are covered by dedicated
    ///      unit tests instead (`TreasuryPol.t.sol`).
    uint128 internal constant THIN_BOOK = 1e15;

    IUniswapV3Pool internal immutable polPool;
    MockSwapper internal immutable swapper;
    bool internal immutable vuxIsToken0;
    uint24 internal immutable feeTier;
    int24 internal immutable polTickLower;
    int24 internal immutable polTickUpper;

    // --- POL/VYRF ghosts ------------------------------------------------------

    /// @dev VUX destroyed by the VYRF leg — a new, distinct cause of supply
    ///      reduction alongside redemption and the F-46 self-burn.
    uint256 public ghostVyrfVuxBurned;
    /// @dev WETH that reached the Reserve as POL fee yield. Also added to
    ///      `ghostHardIn`, because it is a genuine new cause of `B` (INV-29).
    uint256 public ghostVyrfWethToHard;

    uint256 public ghostFeesChargedVux;
    uint256 public ghostFeesChargedWeth;
    uint256 public ghostFeesCollectedVux;
    uint256 public ghostFeesCollectedWeth;

    uint256 public ghostPolVuxPaid;
    uint256 public ghostPolWethPaid;

    constructor(
        MockWeth weth_,
        MockErc20 rewardAsset_,
        HardReserve reserve_,
        Rig rig_,
        VUX vux_,
        StrategicTreasury treasury_,
        MockStrategy[3] memory strategies_,
        IUniswapV3Pool pool_,
        MockSwapper swapper_
    ) TreasuryInvariantHandler(weth_, rewardAsset_, reserve_, rig_, vux_, treasury_, strategies_) {
        polPool = pool_;
        swapper = swapper_;
        vuxIsToken0 = address(vux_) < address(weth_);
        feeTier = treasury_.feeTier();
        polTickLower = treasury_.tickLower();
        polTickUpper = treasury_.tickUpper();
    }

    // =========================================================================
    // POL actions
    // =========================================================================

    /// @dev Create the position, or add to it. The VUX side is drawn from this
    ///      handler's own float and bounded to a fraction of it, so the action
    ///      stays effective for the whole run instead of exhausting itself early
    ///      — VUX cannot be conjured, `mint` being `onlyRig`.
    function addPol(uint256 vuxAmt, uint256 wethAmt) external {
        uint256 float = vux.balanceOf(address(this));
        if (float < 1e18) return;

        uint256 vuxIn = bound(vuxAmt, 1e15, float / 50 + 1e15);
        uint256 wethIn = bound(wethAmt, 1e15, 20 ether);

        vux.transfer(address(treasury), vuxIn);
        weth.mint(address(treasury), wethIn);

        vm.recordLogs();
        if (_polLiquidity() == 0) {
            treasury.mintPolPosition(vuxIn, wethIn);
        } else {
            treasury.increasePol(vuxIn, wethIn);
        }
        _absorbPol(vm.getRecordedLogs());
        effectiveCalls++;
    }

    /// @dev Withdraw at most half the position, never all of it: a pool with zero
    ///      liquidity has no bounded swap behaviour left to exercise, and the full
    ///      unwind is a unit test rather than a random-sequence action.
    function decreasePolSome(uint256 seed) external {
        uint128 liquidity = _polLiquidity();
        if (liquidity <= THIN_BOOK) return;

        vm.recordLogs();
        treasury.decreasePol(uint128(bound(seed, 1, liquidity / 2)));
        _absorbPol(vm.getRecordedLogs());
        effectiveCalls++;
    }

    function harvestPolNow() external {
        if (_polLiquidity() == 0) return;

        vm.recordLogs();
        treasury.harvestPol();
        _absorbPol(vm.getRecordedLogs());
        effectiveCalls++;
    }

    /// @dev In-protocol, existing-supply VUX sourcing. `minVuxOut` is zero here
    ///      because the property under test is that the treasury never mints and
    ///      never books revenue, not that a particular price was achieved.
    function buyVuxForPolNow(uint256 amount) external {
        if (polPool.liquidity() <= THIN_BOOK) return;

        uint256 wethIn = bound(amount, 1e12, 1 ether);
        weth.mint(address(treasury), wethIn);
        treasury.buyVuxForPol(wethIn, 0, _limit(!vuxIsToken0));
        ghostFeesChargedWeth += _feeBound(wethIn);
        effectiveCalls++;
    }

    // =========================================================================
    // Third-party trading — the only thing that creates fee yield
    // =========================================================================

    function tradeWethForVux(uint256 amount) external {
        if (polPool.liquidity() <= THIN_BOOK) return;

        uint256 wethIn = bound(amount, 1e12, 2 ether);
        weth.mint(address(swapper), wethIn);
        swapper.swap(!vuxIsToken0, int256(wethIn), _limit(!vuxIsToken0));
        ghostFeesChargedWeth += _feeBound(wethIn);
        effectiveCalls++;
    }

    function tradeVuxForWeth(uint256 amount) external {
        if (polPool.liquidity() <= THIN_BOOK) return;
        uint256 held = vux.balanceOf(address(swapper));
        if (held < 1e12) return;

        uint256 vuxIn = bound(amount, 1e12, held);
        swapper.swap(vuxIsToken0, int256(vuxIn), _limit(vuxIsToken0));
        ghostFeesChargedVux += _feeBound(vuxIn);
        effectiveCalls++;
    }

    // =========================================================================
    // Views the invariants read
    // =========================================================================

    function polLiquidity() external view returns (uint128) {
        return _polLiquidity();
    }

    /// @dev `tokensOwed` in (VUX, WETH) terms — the cell the VYRF ordering
    ///      property is a statement about.
    function polTokensOwed() external view returns (uint256 vuxOwed, uint256 wethOwed) {
        (,,, uint128 owed0, uint128 owed1) = polPool.positions(_polKey());
        return vuxIsToken0 ? (owed0, owed1) : (owed1, owed0);
    }

    // =========================================================================
    // Internals
    // =========================================================================

    /// @dev Absorb whatever the operation reported. `VyrfHarvest` is the fee
    ///      classification (and, for the WETH leg, a new cause of `B`);
    ///      `PolPositionChanged` is the principal movement.
    function _absorbPol(Vm.Log[] memory logs) private {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length == 0) continue;

            if (logs[i].topics[0] == VYRF_TOPIC) {
                (uint256 vuxBurned, uint256 wethToHard) = abi.decode(logs[i].data, (uint256, uint256));
                ghostVyrfVuxBurned += vuxBurned;
                ghostVyrfWethToHard += wethToHard;
                ghostFeesCollectedVux += vuxBurned;
                ghostFeesCollectedWeth += wethToHard;
                ghostHardIn += wethToHard;
            } else if (logs[i].topics[0] == POL_CHANGED_TOPIC) {
                (int8 direction, uint256 vuxDelta, uint256 wethDelta,) =
                    abi.decode(logs[i].data, (int8, uint256, uint256, uint128));
                if (direction > 0) {
                    ghostPolVuxPaid += vuxDelta;
                    ghostPolWethPaid += wethDelta;
                }
            }
        }
    }

    function _polKey() private view returns (bytes32) {
        return keccak256(abi.encodePacked(address(treasury), polTickLower, polTickUpper));
    }

    function _polLiquidity() private view returns (uint128 liquidity) {
        (liquidity,,,,) = polPool.positions(_polKey());
    }

    /// @dev An upper bound on the fee an exact-input swap of `amountIn` charges,
    ///      derived from the pinned fee tier alone. Over-approximating by a wei is
    ///      deliberate: every use is on the large side of a `<=`.
    function _feeBound(uint256 amountIn) private view returns (uint256) {
        return Math.mulDiv(amountIn, feeTier, 1_000_000 - feeTier, Math.Rounding.Ceil) + 1;
    }

    function _limit(bool zeroForOne) private pure returns (uint160) {
        return zeroForOne ? 4295128740 : 1461446703485210103287273052203988822378723970341;
    }
}
