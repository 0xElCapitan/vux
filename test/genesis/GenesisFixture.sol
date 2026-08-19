// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {GenesisDeployer, GenesisParams} from "../../src/GenesisDeployer.sol";
import {HardReserve} from "../../src/HardReserve.sol";
import {Lens} from "../../src/Lens.sol";
import {Rig} from "../../src/Rig.sol";
import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {VUX} from "../../src/VUX.sol";
import {MockWeth} from "../mocks/MockWeth.sol";
import {IVuxPoolDeployer, PoolDeployerHarness} from "../treasury/PoolDeployerHarness.sol";

/// @title GenesisFixture — the real two-transaction launch choreography.
/// @notice The fixture does not "set up a system"; it performs the launch, in
///         the order and with the dependencies production has, and every suite
///         built on it therefore tests the shipped path rather than a
///         reconstruction of it:
///
///           tx1  deploy the inert `VuxPoolDeployer(commitment)`
///           tx2  create `GenesisDeployer{value: W_POL + B0}` — its constructor
///                *is* genesis
///
///         The choreography is itself a proof obligation. The commitment fixed
///         in tx1 binds to the `GenesisDeployer` address, which does not exist
///         yet, so the fixture must predict it — from the launch sender's nonce
///         *after* tx1 has consumed one — exactly as the founder must. Getting
///         that wrong produces a `BadCommitment` revert in tx2, which is the
///         same failure a real mis-sequenced launch would produce.
///
/// @dev **Rehearsal values only.** Every economic and pool constant below is a
///      rehearsal figure with no production meaning: the four USD targets are
///      converted once, off-chain, by founders at deployment (prd.md:L321,
///      FR-1.4) and the `(fee, tickSpacing)` pair is an R-14 operator-reserved
///      deployment fact. Nothing here freezes any of them. The salt is a fixture
///      constant; the production salt is a launch secret until the launch block
///      (sdd.md:L270).
abstract contract GenesisFixture is PoolDeployerHarness {
    /// @dev Genesis supply: `150_000e18 + 1` raw (INV-2, prd.md:L582).
    uint256 internal constant S0 = 150_000e18 + 1;
    uint256 internal constant POL_VUX = 150_000e18;

    /// @dev Rehearsal pricing, carried over unchanged from the Sprint-4/5
    ///      fixtures so the genesis suites and the accumulated suites price the
    ///      same system.
    uint256 internal constant B0 = 272_727_272_727_272_727_272;
    uint256 internal constant W_POL = 300 ether;
    uint256 internal constant BOOTSTRAP_OPENING = 25 ether;
    uint256 internal constant MINIMUM_OPENING = 5 ether;
    uint256 internal constant DECAY_FLOOR = 0.5 ether;

    /// @dev `P0` as the exact rational the founder records: `P0 = 1.10 x B0/S0`
    ///      (FR-1.4), written so the identity is visible rather than asserted.
    uint256 internal constant P0_NUM = 11 * B0;
    uint256 internal constant P0_DEN = 10 * S0;

    uint24 internal constant FEE_TIER = 3_000;
    int24 internal constant TICK_SPACING = 60;

    /// @dev Fixture salt. No production meaning; see the contract note above.
    bytes32 internal constant REHEARSAL_SALT = keccak256("vux.sprint-7.rehearsal.salt");

    /// @dev The operator Safe. Q-3 (production signer set and threshold) stays
    ///      unresolved and is a Sprint-8 runbook input — this is a rehearsal
    ///      stand-in and freezes nothing.
    address internal constant REHEARSAL_SAFE = address(0x5AFE);

    MockWeth internal weth;
    IVuxPoolDeployer internal poolDeployer;
    GenesisDeployer internal genesis;

    HardReserve internal reserve;
    Rig internal rig;
    VUX internal vux;
    StrategicTreasury internal treasury;
    Lens internal lens;
    address internal pool;

    /// @dev The `GenesisDeployer` address, known before tx1 because the
    ///      commitment must bind to it. Everything an adversary could want is
    ///      derivable from this — and the suites in this directory hand it to
    ///      them on purpose.
    address internal predictedGenesis;
    address internal predictedReserve;
    address internal predictedRig;
    address internal predictedVux;
    address internal predictedTreasury;
    address internal predictedLens;
    address internal predictedPool;
    uint160 internal sqrtP0X96;
    bool internal vuxIsToken0;

    // --- launch ---------------------------------------------------------------

    /// @dev Everything up to but not including tx2, so an adversarial suite can
    ///      interpose between the two transactions — which is exactly the window
    ///      a real attacker gets.
    function _prepareLaunch() internal {
        weth = new MockWeth();

        // tx1 will consume the next nonce, so `GenesisDeployer` lands on the one
        // after it. This is the founder's own nonce plan, reproduced.
        uint256 n = uint256(vm.getNonce(address(this)));
        predictedGenesis = vm.computeCreateAddress(address(this), n + 1);

        // tx1 — inert. Publishes only its own address, its bytecode, and a
        // 32-byte salted commitment. Nothing about the protocol is derivable
        // from it (sdd.md:L159).
        poolDeployer = _deployPoolDeployer(keccak256(abi.encode(predictedGenesis, REHEARSAL_SALT)));

        // Derivable from `predictedGenesis` by anyone, which is the point: the
        // theorem must hold under total leakage (sdd.md:L156).
        predictedReserve = vm.computeCreateAddress(predictedGenesis, 1);
        predictedRig = vm.computeCreateAddress(predictedGenesis, 2);
        predictedVux = vm.computeCreateAddress(predictedGenesis, 3);
        predictedTreasury = vm.computeCreateAddress(predictedGenesis, 4);
        predictedLens = vm.computeCreateAddress(predictedGenesis, 5);
        vuxIsToken0 = predictedVux < address(weth);
        (address t0, address t1) = _sorted(predictedVux, address(weth));
        predictedPool = _computePoolAddress(address(poolDeployer), t0, t1, FEE_TIER);
        sqrtP0X96 = _encodeSqrtP0X96(vuxIsToken0);
    }

    /// @dev tx2 — the launch transaction. Its constructor performs all of genesis.
    function _launch() internal returns (GenesisDeployer) {
        vm.deal(address(this), address(this).balance + W_POL + B0);
        GenesisDeployer g = new GenesisDeployer{value: W_POL + B0}(_params());
        _bind(g);
        return g;
    }

    /// @dev The whole launch, for suites that do not need the gap between the
    ///      two transactions.
    function _runGenesis() internal {
        _prepareLaunch();
        _launch();
    }

    function _params() internal view returns (GenesisParams memory) {
        return GenesisParams({
            weth: address(weth),
            poolDeployer: address(poolDeployer),
            salt: REHEARSAL_SALT,
            feeTier: FEE_TIER,
            tickSpacing: TICK_SPACING,
            sqrtP0X96: sqrtP0X96,
            b0: B0,
            wPol: W_POL,
            bootstrapOpening: BOOTSTRAP_OPENING,
            minimumOpening: MINIMUM_OPENING,
            decayFloor: DECAY_FLOOR,
            operatorSafe: REHEARSAL_SAFE,
            p0Num: P0_NUM,
            p0Den: P0_DEN
        });
    }

    /// @dev Read the deployed system back out of the (now inert) deployer.
    function _bind(GenesisDeployer g) internal {
        genesis = g;
        reserve = HardReserve(g.reserve());
        rig = Rig(g.rig());
        vux = VUX(g.vux());
        treasury = StrategicTreasury(g.treasury());
        lens = Lens(g.lens());
        pool = g.pool();
    }

    /// @dev A fresh, unconsumed tx1 whose commitment binds to `who`, so a suite
    ///      can drive `deployCanonicalPool` directly and reach the parameter
    ///      domain checks without the commitment gate answering first.
    function _freshPoolDeployerBoundTo(address who) internal returns (IVuxPoolDeployer) {
        return _deployPoolDeployer(keccak256(abi.encode(who, REHEARSAL_SALT)));
    }

    /// @dev `VuxPoolDeployer` init code, for callers that must deploy it from an
    ///      account other than this one. The adversarial suite needs this: every
    ///      attacker `CREATE` has to come out of the attacker's own nonce, since
    ///      spending the launch account's nonce is a capability no real attacker
    ///      has and would break the commitment for reasons unrelated to security.
    function _poolDeployerInitCode(bytes32 commitment) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                vm.parseJsonBytes(vm.readFile(DEPLOYER_ARTIFACT), ".bytecode.object"), abi.encode(commitment)
            );
    }

    // --- the accepted off-chain price encoder --------------------------------

    /// @dev `sqrtP0X96 = isqrt((n << 192) / d)` with the frozen orientation
    ///      (token1-per-token0) and **floor at both steps** (sdd.md:L185).
    ///
    ///      Integer-only by construction: `Math.mulDiv` carries the 512-bit
    ///      intermediate exactly and `Math.sqrt` is a floor integer square root,
    ///      so no floating point enters the authoritative encoder anywhere. The
    ///      same rule is implemented independently in
    ///      `tools/offchain/encode-sqrt-p0.mjs` over BigInt, and
    ///      `GenesisPriceEncoding.t.sol` asserts the two agree.
    function _encodeSqrtP0X96(bool vuxFirst) internal pure returns (uint160) {
        (uint256 n, uint256 d) = vuxFirst ? (P0_NUM, P0_DEN) : (P0_DEN, P0_NUM);
        return uint160(Math.sqrt(Math.mulDiv(n, 1 << 192, d)));
    }

    // --- shared helpers -------------------------------------------------------

    /// @dev The canonical POL position's liquidity, read off the pool itself.
    function _polLiquidity() internal view returns (uint128 liquidity) {
        (liquidity,,,,) = _positionOf(address(treasury));
    }

    function _positionOf(address owner_)
        internal
        view
        returns (uint128 liquidity, uint256 fg0, uint256 fg1, uint128 owed0, uint128 owed1)
    {
        return IPoolPositions(pool)
            .positions(keccak256(abi.encodePacked(owner_, treasury.tickLower(), treasury.tickUpper())));
    }

    /// @dev Fund `who` with WETH the way an outsider does — by wrapping their own
    ///      ETH. Deliberately not `MockWeth.mint`: an attacker in these suites
    ///      must not have a capability the real chain would not give them.
    function _wrapFor(address who, uint256 amount) internal {
        vm.deal(who, who.balance + amount);
        vm.prank(who);
        weth.deposit{value: amount}();
    }

    /// @dev Attacker donation to an address, by the only route that exists.
    function _donateWeth(address to, uint256 amount) internal {
        address donor = address(0xD0A);
        _wrapFor(donor, amount);
        vm.prank(donor);
        weth.transfer(to, amount);
    }
}

/// @dev The one pool view this fixture needs, declared locally so the fixture
///      does not pull the full vendored interface into every genesis suite.
interface IPoolPositions {
    function positions(bytes32 key)
        external
        view
        returns (uint128 liquidity, uint256 fg0, uint256 fg1, uint128 owed0, uint128 owed1);
    function slot0()
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint16 i, uint16 j, uint16 k, uint8 f, bool unlocked);
    function initialize(uint160 sqrtPriceX96) external;
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function tickSpacing() external view returns (int24);
}
