// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: FR-1 (canonical-pool infrastructure), sprint.md Task 4.1 acceptance,
//          sdd.md:L190-L194 (design), sdd.md:L829-L830 (error schema)

import {Vm} from "../harness/Vm.sol";
import {MockErc20} from "../mocks/MockErc20.sol";
import {IVuxPoolDeployer, PoolDeployerHarness} from "./PoolDeployerHarness.sol";

/// @title VuxPoolDeployerTest — the one-shot, commitment-gated, domain-checked
///        canonical-pool primitive.
/// @notice Everything here runs against the real `=0.7.6` artifact, deployed
///         from its compiled creation code. The pool it produces is the real
///         vendored `UniswapV3Pool`.
contract VuxPoolDeployerTest is PoolDeployerHarness {
    bytes32 internal constant SALT = keccak256("vux.pool-deployer.test.salt");
    uint24 internal constant FEE = 3_000;
    int24 internal constant TICK_SPACING = 60;

    address internal tokenA;
    address internal tokenB;
    address internal token0;
    address internal token1;

    address internal constant OUTSIDER = address(0xBADBAD);

    function setUp() public {
        tokenA = address(new MockErc20("A", "A"));
        tokenB = address(new MockErc20("B", "B"));
        (token0, token1) = _sorted(tokenA, tokenB);
    }

    function _deployerFor(address committedCaller) internal returns (IVuxPoolDeployer) {
        return _deployPoolDeployer(keccak256(abi.encode(committedCaller, SALT)));
    }

    /// @dev `require(cond, "msg")` in `=0.7.6` reverts `Error(string)` — custom
    ///      errors postdate that compiler (0.8.4), so the accepted error names
    ///      travel as strings (see `VuxPoolDeployer`'s header).
    function _expectRevertString(string memory reason) internal {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", reason));
    }

    // --- the happy path and its independent derivation -------------------------

    function test_DeploysAPoolAtTheIndependentlyRecomputedCreate2Address() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        address expected = _computePoolAddress(address(deployer), token0, token1, FEE);

        address pool = deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);

        assertEq(pool, expected, "pool address equals create2(deployer, keccak(token0,token1,fee), INIT_CODE_HASH)");
        assertEq(deployer.canonicalPool(), pool, "the deployer records the pool it created");
        assertNotEq(pool.code.length, 0, "the pool has code");
    }

    function test_TheDeployedPoolAnswersForItsOwnIdentity() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        address pool = deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);

        assertEq(IPoolView(pool).factory(), address(deployer), "the pool's factory is VuxPoolDeployer");
        assertEq(IPoolView(pool).token0(), token0, "token0");
        assertEq(IPoolView(pool).token1(), token1, "token1");
        assertEq(uint256(IPoolView(pool).fee()), uint256(FEE), "fee");
        assertEq(int256(IPoolView(pool).tickSpacing()), int256(TICK_SPACING), "tickSpacing");
    }

    /// @dev The protocol-fee switch is unreachable *forever*, not merely unused:
    ///      the vendored pool gates `setFeeProtocol`/`collectProtocol` on
    ///      `IUniswapV3Factory(factory).owner()`, and this factory's owner is a
    ///      compile-time constant zero (sdd.md:L192).
    function test_OwnerIsPermanentlyDead() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        assertEq(deployer.owner(), address(0), "owner() before deployment");

        address pool = deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);
        assertEq(deployer.owner(), address(0), "owner() after deployment");

        vm.expectRevert();
        IPoolOwnerActions(pool).setFeeProtocol(4, 4);
    }

    function test_EmitsCanonicalPoolDeployed() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));

        vm.recordLogs();
        address pool = deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 topic = keccak256("CanonicalPoolDeployed(address,address,address,uint24,int24)");
        uint256 found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length != 1 || logs[i].topics[0] != topic) continue;
            found++;
            (address p, address t0, address t1, uint24 f, int24 s) =
                abi.decode(logs[i].data, (address, address, address, uint24, int24));
            assertEq(p, pool, "event pool");
            assertEq(t0, token0, "event token0");
            assertEq(t1, token1, "event token1");
            assertEq(uint256(f), uint256(FEE), "event fee");
            assertEq(int256(s), int256(TICK_SPACING), "event tickSpacing");
        }
        assertEq(found, 1, "exactly one CanonicalPoolDeployed");
    }

    // --- the commitment gate ---------------------------------------------------

    function test_WrongSaltReverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        _expectRevertString("BadCommitment");
        deployer.deployCanonicalPool(keccak256("not the salt"), token0, token1, FEE, TICK_SPACING);
    }

    /// @dev The binding is to `msg.sender`, so the preimage alone is worthless:
    ///      an adversary who extracted the salt still cannot consume the one-shot
    ///      (sdd.md:L192-L193).
    function test_CorrectSaltFromTheWrongSenderReverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        vm.prank(OUTSIDER);
        _expectRevertString("BadCommitment");
        deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);
    }

    /// @dev And the complement: the committed caller is the only one who can,
    ///      which is what makes the gate a binding rather than a secret.
    function test_TheCommittedSenderIsTheOneWhoCan() public {
        IVuxPoolDeployer deployer = _deployerFor(OUTSIDER);

        _expectRevertString("BadCommitment");
        deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);

        vm.prank(OUTSIDER);
        address pool = deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);
        assertNotEq(pool, address(0), "the committed caller succeeds");
    }

    function test_ZeroCommitmentIsRejectedAtConstruction() public {
        // The revert happens inside init code, so `create` returns the zero
        // address and the harness's own guard fires.
        bytes memory creationCode = vm.parseJsonBytes(vm.readFile(DEPLOYER_ARTIFACT), ".bytecode.object");
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(bytes32(0)));
        address deployed;
        assembly ("memory-safe") {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        assertEq(deployed, address(0), "a zero commitment cannot be deployed");
    }

    // --- the one-shot ----------------------------------------------------------

    function test_SecondCallReverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);

        _expectRevertString("PoolAlreadyDeployed");
        deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);
    }

    /// @dev The latch is on the deployer, not on the parameter tuple: a second
    ///      call for a *different* pair is refused just as hard. "No fee-tier
    ///      registry, no permissionless `createPool`, no other function exists"
    ///      (sdd.md:L192).
    function test_SecondCallForADifferentPairAlsoReverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        deployer.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);

        address tokenC = address(new MockErc20("C", "C"));
        (address c0, address c1) = _sorted(token0, tokenC);
        _expectRevertString("PoolAlreadyDeployed");
        deployer.deployCanonicalPool(SALT, c0, c1, FEE, TICK_SPACING);
    }

    // --- Finding-4 parameter-domain checks -------------------------------------

    function test_UnsortedTokensRevert() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        _expectRevertString("InvalidPoolParams: tokenOrder");
        deployer.deployCanonicalPool(SALT, token1, token0, FEE, TICK_SPACING);
    }

    function test_IdenticalTokensRevert() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        _expectRevertString("InvalidPoolParams: tokenOrder");
        deployer.deployCanonicalPool(SALT, token0, token0, FEE, TICK_SPACING);
    }

    function test_ZeroToken0Reverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        _expectRevertString("InvalidPoolParams: zeroToken");
        deployer.deployCanonicalPool(SALT, address(0), token1, FEE, TICK_SPACING);
    }

    /// @dev `token1 == 0` cannot pass the sort check, so the zero-token domain is
    ///      closed from both sides rather than only where it is checked directly.
    function test_ZeroToken1Reverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        _expectRevertString("InvalidPoolParams: tokenOrder");
        deployer.deployCanonicalPool(SALT, token0, address(0), FEE, TICK_SPACING);
    }

    function test_FeeAtOrAboveOneHundredPercentReverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        _expectRevertString("InvalidPoolParams: fee");
        deployer.deployCanonicalPool(SALT, token0, token1, 1_000_000, TICK_SPACING);
    }

    function test_ZeroTickSpacingReverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        _expectRevertString("InvalidPoolParams: tickSpacing");
        deployer.deployCanonicalPool(SALT, token0, token1, FEE, 0);
    }

    function test_NegativeTickSpacingReverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        _expectRevertString("InvalidPoolParams: tickSpacing");
        deployer.deployCanonicalPool(SALT, token0, token1, FEE, -60);
    }

    function test_TickSpacingAtTheCanonicalCeilingReverts() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        _expectRevertString("InvalidPoolParams: tickSpacing");
        deployer.deployCanonicalPool(SALT, token0, token1, FEE, 16384);
    }

    /// @dev The boundaries are inclusive/exclusive exactly as the accepted domain
    ///      states: `fee < 1_000_000`, `0 < tickSpacing < 16384`. A check that
    ///      rejected the last legal value would be a different rule.
    function test_TheDomainEdgesThatAreLegalAreAccepted() public {
        IVuxPoolDeployer deployer = _deployerFor(address(this));
        address pool = deployer.deployCanonicalPool(SALT, token0, token1, 999_999, 16383);
        assertNotEq(pool, address(0), "fee 999_999 / tickSpacing 16383 is inside the domain");
    }

    // --- namespace exclusivity -------------------------------------------------

    /// @dev The pool lives in the deployer's exclusive CREATE2 namespace, so an
    ///      adversary who knows every address and every parameter still has
    ///      nothing to occupy (sdd.md:L193). Two deployers with identical
    ///      parameters produce different pools; only their own namespace is
    ///      theirs to fill.
    function test_EachDeployerHasItsOwnNamespace() public {
        IVuxPoolDeployer first = _deployerFor(address(this));
        IVuxPoolDeployer second = _deployerFor(address(this));

        address a = first.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);
        address b = second.deployCanonicalPool(SALT, token0, token1, FEE, TICK_SPACING);

        assertNotEq(a, b, "same parameters, different deployers, different pools");
        assertEq(a, _computePoolAddress(address(first), token0, token1, FEE), "first namespace");
        assertEq(b, _computePoolAddress(address(second), token0, token1, FEE), "second namespace");
    }
}

/// @notice The pool immutables the tests read, declared locally for the same
///         cross-unit reason as `IVuxPoolDeployer`.
interface IPoolView {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function tickSpacing() external view returns (int24);
}

interface IPoolOwnerActions {
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;
}
