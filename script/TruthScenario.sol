// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {HardReserve} from "../src/HardReserve.sol";
import {Rig} from "../src/Rig.sol";
import {StrategicTreasury} from "../src/StrategicTreasury.sol";
import {VUX} from "../src/VUX.sol";
import {MockSwapper} from "../test/mocks/MockSwapper.sol";
import {MockWeth} from "../test/mocks/MockWeth.sol";

/// @notice The `VuxPoolDeployer` surface, redeclared for this `=0.8.28` unit.
/// @dev `src/v3core/VuxPoolDeployer.sol` compiles in the separate `=0.7.6` unit,
///      so no `=0.8.28` file can import its type. Bytecode has no version: the
///      driver reads the compiled artifact and hands the creation code in as
///      `bytes`, and this declaration calls the genuine contract. Nothing is
///      mocked — the same method `test/treasury/PoolDeployerHarness.sol` uses,
///      minus the cheatcode that merely READ the file.
interface IVuxPoolDeployer {
    function canonicalPool() external view returns (address);
    function deployCanonicalPool(bytes32 salt, address token0, address token1, uint24 fee, int24 tickSpacing)
        external
        returns (address pool);
}

/// @title Actor — a distinct on-chain identity the scenario can act through.
/// @dev The reconstruction has to distinguish `outgoingKing` from `newKing` and
///      attribute mints to the right address, so the scenario needs several real
///      addresses rather than one. On a live node there are no cheatcodes, so
///      `vm.prank` is unavailable and each identity is a real contract.
contract Actor {
    function exec(address target, bytes calldata data) external returns (bytes memory) {
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        return ret;
    }
}

/// @title TruthScenario — the scripted multi-op scenario, on a real chain.
/// @notice Deploys the monetary core and exposes each operation as its own
///         transaction, so the driver can advance the node's clock between them
///         and the resulting logs are genuine chain history — block numbers,
///         transaction hashes, log indices and all.
///
///         This is what the FR-14 acceptance criterion needs. The forge suite
///         proves the *pairing rules* against `vm.recordLogs`; it cannot prove
///         that an independent observer, given only `eth_getLogs`, arrives at the
///         same numbers the chain holds. That requires real logs, which requires
///         real transactions.
///
/// @dev **Scope, stated rather than implied.** This scenario deploys the
///      monetary core only — WETH, Reserve, Rig, VUX — with the Strategic leg
///      targeting a plain address, which is exactly Sprint 3's accepted boundary
///      (sdd.md:L138): the residual is a bare WETH transfer with no callback.
///      The Strategic Treasury is deliberately absent, because deploying the
///      canonical pool depends on `vm.getCode` against the separate `=0.7.6`
///      compilation unit, and cheatcodes do not exist on a live node.
///
///      Consequence: this scenario exercises four of the five `supply_change`
///      causes end to end — `genesis`, `settlement_mint`, `redemption_burn`, and
///      `other_authorized_burn` via a permissionless holder self-burn. The fifth,
///      `vyrf_burn`, and the treasury-side `other_authorized_burn` are proven in
///      `test/events/BurnCausePairing.t.sol`, which has the real pool fixture.
///      That split is a property of the toolchain, not a gap in the attribution
///      logic, and the reconstruction's handling of all five is exercised
///      directly in `indexer/test/reconstruct.test.mjs`.
contract TruthScenario {
    // Rehearsal pricing, carried over from `RigFixture`. R-14 deployment-time
    // founder facts (prd.md:L335) — fixture values with no production meaning.
    uint256 internal constant BOOTSTRAP_OPENING = 25 ether;
    uint256 internal constant MINIMUM_OPENING = 5 ether;
    uint256 internal constant DECAY_FLOOR = 0.5 ether;
    uint256 internal constant B0 = 272_727_272_727_272_727_272;

    /// @dev Sprint 3's accepted Strategic destination: a plain address.
    address public constant TREASURY = address(0x7EA5);

    MockWeth public immutable weth;
    HardReserve public immutable reserve;
    Rig public immutable rig;
    VUX public immutable vux;

    Actor public immutable alice;
    Actor public immutable bob;
    Actor public immutable carol;

    /// @notice One record carrying every address the reconstruction needs, so the
    ///         driver never hard-codes one.
    event ScenarioDeployed(
        address weth, address reserve, address rig, address vux, address treasury,
        address alice, address bob, address carol
    );

    error PredictionFailed(address expected, address actual);

    constructor() {
        // CREATE address prediction without cheatcodes. A contract's nonce starts
        // at 1, and for a nonce below 0x80 the RLP encoding of [sender, nonce] is
        // 0xd6 0x94 <20-byte sender> <1-byte nonce>. VUX is this contract's fourth
        // deployment, so nonce 4.
        address predictedVux = _computeCreateAddress(address(this), 4);

        weth = new MockWeth(); //                                   nonce 1
        reserve = new HardReserve(address(weth), predictedVux); //   nonce 2
        rig = new Rig( //                                            nonce 3
            address(weth), address(reserve), predictedVux, TREASURY,
            BOOTSTRAP_OPENING, MINIMUM_OPENING, DECAY_FLOOR
        );
        vux = new VUX(address(rig), address(reserve)); //             nonce 4
        if (address(vux) != predictedVux) revert PredictionFailed(predictedVux, address(vux));

        alice = new Actor();
        bob = new Actor();
        carol = new Actor();

        // Genesis funds the Reserve with exactly B0. The Reserve is born empty
        // (its constructor sanitizes), so this transfer is the whole of `B`.
        weth.mint(address(this), B0);
        weth.transfer(address(reserve), B0);

        emit ScenarioDeployed(
            address(weth), address(reserve), address(rig), address(vux), TREASURY,
            address(alice), address(bob), address(carol)
        );
    }

    /// @notice Take the throne as `who`, funding and approving exactly the price.
    function take(Actor who) external {
        uint256 price = rig.currentPrice();
        weth.mint(address(who), price);
        who.exec(address(weth), abi.encodeCall(IERC20.approve, (address(rig), price)));
        who.exec(address(rig), abi.encodeCall(Rig.take, (type(uint256).max)));
    }

    /// @notice Redeem `q` VUX held by `who`, paying out to `who`.
    function redeem(Actor who, uint256 q) external {
        who.exec(address(reserve), abi.encodeCall(HardReserve.redeem, (q, address(who))));
    }

    /// @notice A permissionless holder self-burn — the residual burn class that
    ///         carries no protocol cause event (event-completeness audit F-2).
    function selfBurn(Actor who, uint256 amount) external {
        who.exec(address(vux), abi.encodeCall(VUX.burn, (amount)));
    }

    /// @notice TWO identical self-burns in ONE transaction — the reachable
    ///         collision the review found. `VUX.burn` is permissionless, so any
    ///         caller can compose this; nothing in the protocol prevents it.
    ///         Both logs must survive indexing, or `S` is understated.
    function doubleSelfBurn(Actor who, uint256 amount) external {
        who.exec(address(vux), abi.encodeCall(VUX.burn, (amount)));
        who.exec(address(vux), abi.encodeCall(VUX.burn, (amount)));
    }

    /// @notice An unsolicited WETH donation straight into the Reserve. Lawful
    ///         accretion with no protocol event at all — it raises `B` and must
    ///         still reconstruct, which is why `B` is rebuilt from the WETH
    ///         token's own transfer record rather than from settlement legs.
    function donateToReserve(uint256 amount) external {
        weth.mint(address(this), amount);
        weth.transfer(address(reserve), amount);
    }

    function balanceOfVux(Actor who) external view returns (uint256) {
        return vux.balanceOf(address(who));
    }

    // ----------------------------------------------------------------------
    // The VYRF / POL sleeve — the harvest leg of the accepted Task 6.5 sequence
    // ----------------------------------------------------------------------
    //
    // The canonical pool is deployed from the compiled `=0.7.6` artifact, whose
    // creation code the driver reads from `out-v3core/` and passes in as bytes.
    // The earlier note on this file claimed the pool "depends on `vm.getCode`
    // ... and cheatcodes do not exist on a live node". That was wrong: the
    // cheatcode only ever read a JSON file, and the deployment itself is a plain
    // CREATE. Node reads the same artifact `scripts/extract-abis.mjs` already
    // reads, so the whole VYRF flow runs on a live chain with no cheatcode.
    //
    // The Rig's Strategic destination is deliberately left as the plain `TREASURY`
    // address it was accepted with (sdd.md:L138), so the four causes this
    // scenario already proved are byte-for-byte unaffected. The harvest is what
    // Task 6.5 names, and its observables — a VUX fee burn and a WETH fee
    // movement into the Hard Reserve — do not run through the settlement
    // residual at all.

    uint24 public constant POOL_FEE = 3_000;
    int24 public constant POOL_TICK_SPACING = 60;
    bytes32 public constant POOL_SALT = keccak256("vux.sprint-6.truth-scenario.salt");

    IVuxPoolDeployer public poolDeployer;
    IUniswapV3Pool public pool;
    StrategicTreasury public treasuryContract;
    MockSwapper public swapper;

    event StrategicStackDeployed(address poolDeployer, address pool, address treasury, address swapper);

    error DeployerDeploymentFailed();

    /// @notice Deploy the pool deployer, the canonical pool, the treasury and a
    ///         third-party swapper.
    ///
    /// @param deployerCreationCode the compiled `VuxPoolDeployer` artifact
    /// @param treasuryCreationCode the compiled `StrategicTreasury` artifact
    ///
    /// @dev Both are supplied by the driver rather than constructed with `new`.
    ///      `new StrategicTreasury(...)` would embed the treasury's creation code
    ///      in this contract and push it past the EIP-170 24,576-byte runtime
    ///      limit — it compiled, but could never be deployed to a live chain,
    ///      which is the only place this scenario is meant to run. Deploying both
    ///      from artifact bytes keeps this harness small and, incidentally, proves
    ///      the same point the pool does: nothing here is a mock.
    function deployStrategicStack(bytes calldata deployerCreationCode, bytes calldata treasuryCreationCode)
        external
    {
        bytes memory initCode =
            abi.encodePacked(deployerCreationCode, abi.encode(keccak256(abi.encode(address(this), POOL_SALT))));
        address deployed = _create(initCode);
        if (deployed == address(0)) revert DeployerDeploymentFailed();
        poolDeployer = IVuxPoolDeployer(deployed);

        (address token0, address token1) =
            address(vux) < address(weth) ? (address(vux), address(weth)) : (address(weth), address(vux));
        pool = IUniswapV3Pool(
            poolDeployer.deployCanonicalPool(POOL_SALT, token0, token1, POOL_FEE, POOL_TICK_SPACING)
        );

        address t = _create(
            abi.encodePacked(
                treasuryCreationCode,
                abi.encode(address(weth), address(vux), address(reserve), deployed, address(pool), POOL_FEE)
            )
        );
        if (t == address(0)) revert DeployerDeploymentFailed();
        treasuryContract = StrategicTreasury(payable(t));

        // `P0 = 1.10 x B/S` in the pool's token1-per-token0 Q64.96 sqrt encoding
        // (FR-1.4, sdd.md:L185). Read from live balances rather than a constant so
        // the price is consistent with whatever settlements have already happened.
        bool vuxIsToken0 = address(vux) < address(weth);
        uint256 b = weth.balanceOf(address(reserve));
        uint256 s = vux.totalSupply();
        (uint256 num, uint256 den) = vuxIsToken0 ? (11 * b, 10 * s) : (10 * s, 11 * b);
        pool.initialize(uint160(Math.sqrt(Math.mulDiv(num, 1 << 192, den))));

        swapper = new MockSwapper(pool);
        emit StrategicStackDeployed(deployed, address(pool), address(treasuryContract), address(swapper));
    }

    /// @notice Fund the treasury and mint the canonical POL position, the way
    ///         genesis step 7 does — tokens in first, the pool paid through the
    ///         treasury's own callback.
    function provisionPol(uint256 vuxAmt, uint256 wethAmt) external {
        vux.transfer(address(treasuryContract), vuxAmt);
        weth.mint(address(treasuryContract), wethAmt);
        treasuryContract.mintPolPosition(vuxAmt, wethAmt);
    }

    /// @notice Accrue BOTH fee legs from genuine third-party trading: buy VUX with
    ///         WETH (a WETH-denominated fee), then sell it back (a VUX-denominated
    ///         one). Fees cannot be conjured — only swaps produce them.
    function accrueFees(uint256 wethIn) external {
        weth.mint(address(swapper), wethIn);
        bool vuxIsToken0 = address(vux) < address(weth);
        // zeroForOne == true sells token0. Selling WETH means zeroForOne is true
        // exactly when WETH is token0, i.e. when VUX is not.
        swapper.swap(!vuxIsToken0, int256(wethIn), _limit(!vuxIsToken0));
        uint256 vuxBack = vux.balanceOf(address(swapper));
        swapper.swap(vuxIsToken0, int256(vuxBack), _limit(vuxIsToken0));
    }

    /// @notice The harvest itself: permissionless, burns the VUX fee leg and
    ///         moves the WETH fee leg into the Hard Reserve in-call (FR-10).
    function harvest() external {
        treasuryContract.harvestPol();
    }

    function _create(bytes memory initCode) private returns (address deployed) {
        assembly ("memory-safe") {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
    }

    /// @dev A price limit that never binds, on the correct side of the swap.
    function _limit(bool zeroForOne) private pure returns (uint160) {
        return zeroForOne ? 4_295_128_740 : 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;
    }

    function _computeCreateAddress(address deployer, uint8 nonce) private pure returns (address) {
        require(nonce > 0 && nonce < 0x80, "nonce out of the single-byte RLP range");
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(nonce)))))
        );
    }
}
