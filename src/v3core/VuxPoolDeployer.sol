// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.6;

import {UniswapV3PoolDeployer} from "@uniswap/v3-core/contracts/UniswapV3PoolDeployer.sol";

/// @title VuxPoolDeployer — one-shot canonical-pool infrastructure ("factory-of-one").
/// @notice Deploys the canonical VUX/WETH pool inside the genesis transaction,
///         in a CREATE2 namespace only the protocol controls. It replaces any
///         use of a shared permissionless factory for the canonical venue
///         (sdd.md:L190-L194).
///
///         Everything an adversary could want is public in advance — every
///         predicted address, the token pair, the fee tier, the init code hash —
///         and none of it helps: the pool lives in *this* contract's exclusive
///         CREATE2 namespace, which no other account can deploy into, and the
///         single function that occupies it requires an unpublished commitment
///         preimage *and* the matching `msg.sender` (sdd.md:L193).
///
/// @dev **Provenance — VUX-owned derivative source, not vendored census.**
///      This file derives from the pinned upstream `UniswapV3PoolDeployer`
///      (`vendor/uniswap-v3-core-v1.0.0/contracts/UniswapV3PoolDeployer.sol`,
///      commit `e3589b192d0be27e100cd0daaf6c97204fdb1899`) by *inheritance* —
///      not by copying it — so upstream's `deploy()` CREATE2 semantics and the
///      argument-free `parameters()` init-code pattern are preserved byte-for-byte
///      and `POOL_INIT_CODE_HASH` is unaffected. It shares the `=0.7.6`
///      compilation unit with that census but is deliberately NOT part of it:
///      it lives under `src/`, the declared VUX source root, so every provenance
///      gate classifies it as VUX-owned rather than upstream
///      (sprint.md:L19 — "'Vendored unit' in this plan does not authorize
///      modifying upstream files or placing VUX-owned derivative source inside
///      the immutable upstream census"). The four additions below — commitment
///      gate, one-shot latch, Finding-4 domain checks, permanently dead
///      `owner()` — are VUX-original (sdd.md:L194).
///
/// @dev **No custom errors.** Solidity `=0.7.6` predates them (0.8.4). The
///      accepted error schema's names (`BadCommitment`, `PoolAlreadyDeployed`,
///      `InvalidPoolParams`, sdd.md:L829-L830) are therefore carried as revert
///      strings, one per distinguishable domain violation.
contract VuxPoolDeployer is UniswapV3PoolDeployer {
    /// @notice `keccak256(abi.encode(genesisDeployer, salt))` — the salted,
    ///         `msg.sender`-binding commitment fixed at construction.
    /// @dev Binding to `msg.sender` rather than `tx.origin` makes the gate immune
    ///      to phishing: possession of the preimage is not enough, the caller
    ///      must *be* the committed address. Publishing the commitment publishes
    ///      neither the salt nor the address (sdd.md:L192).
    bytes32 public immutable COMMITMENT;

    /// @notice The canonical pool, once deployed. Zero until then, and its
    ///         non-zero value is the one-shot latch.
    address public canonicalPool;

    /// @notice Permanently `address(0)`.
    /// @dev The vendored pool gates `setFeeProtocol`/`collectProtocol` on
    ///      `IUniswapV3Factory(factory).owner()`. `factory` is this contract, so
    ///      a dead owner makes the protocol-fee switch unreachable forever —
    ///      not merely unused (sdd.md:L192). `constant` is what makes that a
    ///      property of the bytecode rather than of an unset storage slot.
    address public constant owner = address(0);

    /// @notice Accepted schema (sdd.md §3.2).
    event CanonicalPoolDeployed(address pool, address token0, address token1, uint24 fee, int24 tickSpacing);

    /// @param commitment `keccak256(abi.encode(genesisDeployer, salt))`. A zero
    ///        commitment is rejected: no preimage could ever satisfy it, so it
    ///        would deploy a permanently unusable genesis primitive.
    constructor(bytes32 commitment) {
        require(commitment != bytes32(0), "BadCommitment");
        COMMITMENT = commitment;
    }

    /// @notice Deploy the canonical pool. Callable exactly once, and only by the
    ///         committed caller presenting the committed salt.
    ///
    /// @dev The pool address is `create2(address(this), keccak256(abi.encode(
    ///      token0, token1, fee)), POOL_INIT_CODE_HASH)` — upstream's salt and
    ///      argument-free init code, unchanged, which is why the accepted
    ///      `POOL_INIT_CODE_HASH` build constant still derives the address
    ///      (sdd.md:L192).
    ///
    ///      **Parameter-domain checks (Finding 4)** re-impose the safety the
    ///      deleted shared factory used to provide, without freezing any
    ///      economic value: the concrete `(fee, tickSpacing)` pair stays an R-14
    ///      founder deployment-time fact — domain-checked, never value-frozen.
    ///      `sqrtPriceX96` bounds are enforced downstream by the vendored
    ///      `initialize` itself and pre-asserted by `GenesisDeployer` (Sprint 7).
    ///
    ///      **One-shot ordering.** `canonicalPool` is written after `deploy`
    ///      returns rather than before, because the address is not known until
    ///      then. That is safe rather than merely convenient: the only external
    ///      code this call executes is the byte-frozen vendored pool
    ///      constructor, whose entire interaction with its deployer is the
    ///      `parameters()` view — there is no path back into this function to
    ///      race the latch.
    ///
    /// @param salt        The commitment preimage's salt.
    /// @param token0      Lower-sorted pool token.
    /// @param token1      Higher-sorted pool token.
    /// @param fee         Fee in hundredths of a bip.
    /// @param tickSpacing Tick spacing for the pool.
    /// @return pool The deployed canonical pool.
    function deployCanonicalPool(bytes32 salt, address token0, address token1, uint24 fee, int24 tickSpacing)
        external
        returns (address pool)
    {
        require(canonicalPool == address(0), "PoolAlreadyDeployed");
        require(keccak256(abi.encode(msg.sender, salt)) == COMMITMENT, "BadCommitment");

        require(token0 != address(0), "InvalidPoolParams: zeroToken");
        require(token0 < token1, "InvalidPoolParams: tokenOrder");
        require(fee < 1_000_000, "InvalidPoolParams: fee");
        require(tickSpacing > 0 && tickSpacing < 16384, "InvalidPoolParams: tickSpacing");

        pool = deploy(address(this), token0, token1, fee, tickSpacing);
        canonicalPool = pool;

        emit CanonicalPoolDeployed(pool, token0, token1, fee, tickSpacing);
    }
}
