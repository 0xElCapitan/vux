// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

/// @notice The two callbacks under test, declared locally so the mock can invoke
///         them without importing the treasury.
interface ITreasuryCallbacks {
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external;
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
    function harvestPol() external;
}

/// @title MockCallbackPool — TEST ONLY. A canonical pool that misbehaves on cue.
/// @notice The callback negative suite has an awkward requirement: several of its
///         rejection classes are only reachable from **the canonical pool
///         itself**. A real pool calls back exactly once, with well-formed
///         amounts, empty data, and never re-enters — so "a duplicate second
///         callback reverts even from the canonical pool" and "an outer operation
///         whose authorization goes unconsumed reverts" cannot be produced by
///         asking a real pool nicely.
///
///         The alternative — asserting those two properties from storage reads —
///         would be inference, not a proof: it would show that the context word
///         *is* `NONE` after the first callback, not that a real second call
///         *fails*. So this contract exists to make the attempt for real, from
///         the exact address the treasury holds as its immutable `pool`.
///
///         It answers every constructor check (`factory`, `owner`, token
///         ordering, `fee`, `tickSpacing`) so a treasury can be built against it
///         with the mock passed as both `pool` and `poolDeployer` — the same
///         technique, and the same justification, as `MockPool` in Sprint 4.
///         Positive-path behaviour is verified against the real vendored pool
///         everywhere else in the suite; nothing here is ever the evidence for a
///         property that holds.
contract MockCallbackPool {
    enum Mode {
        /// @dev One well-formed callback — the control, so the rig is known to
        ///      produce a callback the treasury ACCEPTS. Without it, every
        ///      "reverts" assertion below could be passing for the wrong reason.
        NORMAL,
        /// @dev Two callbacks in one operation, both from this address.
        DOUBLE_CALLBACK,
        /// @dev The pool call returns without ever calling back.
        NO_CALLBACK,
        /// @dev One callback carrying nonempty `data`.
        NONEMPTY_DATA,
        /// @dev A mint operation is answered with the *swap* callback (and a swap
        ///      operation with the *mint* callback).
        WRONG_TYPE,
        /// @dev The callback re-enters a guarded treasury entry point.
        REENTRANT
    }

    Mode public mode;

    address public factory;
    address public token0;
    address public token1;
    uint24 public fee;
    int24 public tickSpacing;
    address public owner;

    uint160 public sqrtPriceX96;
    uint128 public positionLiquidity;

    uint256 public owed0;
    uint256 public owed1;
    int256 public delta0;
    int256 public delta1;

    constructor(address token0_, address token1_, uint24 fee_, int24 tickSpacing_, uint160 sqrtPriceX96_) {
        factory = address(this);
        token0 = token0_;
        token1 = token1_;
        fee = fee_;
        tickSpacing = tickSpacing_;
        sqrtPriceX96 = sqrtPriceX96_;
    }

    function setMode(Mode mode_) external {
        mode = mode_;
    }

    function setOwed(uint256 owed0_, uint256 owed1_) external {
        owed0 = owed0_;
        owed1 = owed1_;
    }

    function setDeltas(int256 delta0_, int256 delta1_) external {
        delta0 = delta0_;
        delta1 = delta1_;
    }

    function setPositionLiquidity(uint128 liquidity) external {
        positionLiquidity = liquidity;
    }

    // --- the pool surface the treasury reads ---------------------------------

    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool) {
        return (sqrtPriceX96, 0, 0, 1, 1, 0, true);
    }

    function positions(bytes32) external view returns (uint128, uint256, uint256, uint128, uint128) {
        return (positionLiquidity, 0, 0, 0, 0);
    }

    // --- the pool surface the treasury calls ---------------------------------

    function mint(address, int24, int24, uint128, bytes calldata) external returns (uint256, uint256) {
        _fire(true);
        return (owed0, owed1);
    }

    function swap(address, bool, int256, uint160, bytes calldata) external returns (int256, int256) {
        _fire(false);
        return (delta0, delta1);
    }

    function burn(int24, int24, uint128) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function collect(address, int24, int24, uint128, uint128) external pure returns (uint128, uint128) {
        return (0, 0);
    }

    /// @dev `isMint` selects which callback the *operation* legitimately expects;
    ///      `WRONG_TYPE` deliberately answers with the other one.
    function _fire(bool isMint) private {
        if (mode == Mode.NO_CALLBACK) return;

        bytes memory data = mode == Mode.NONEMPTY_DATA ? bytes(hex"deadbeef") : bytes("");
        bool sendMint = mode == Mode.WRONG_TYPE ? !isMint : isMint;

        _one(sendMint, data);
        if (mode == Mode.DOUBLE_CALLBACK) _one(sendMint, data);
        if (mode == Mode.REENTRANT) ITreasuryCallbacks(msg.sender).harvestPol();
    }

    function _one(bool sendMint, bytes memory data) private {
        if (sendMint) {
            ITreasuryCallbacks(msg.sender).uniswapV3MintCallback(owed0, owed1, data);
        } else {
            ITreasuryCallbacks(msg.sender).uniswapV3SwapCallback(delta0, delta1, data);
        }
    }
}
