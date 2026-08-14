// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {HardReserve} from "../../src/HardReserve.sol";
import {Rig} from "../../src/Rig.sol";
import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {VUX} from "../../src/VUX.sol";
import {MockErc20} from "../mocks/MockErc20.sol";
import {MockLsgModule} from "../mocks/MockLsgModule.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";
import {MockWeth} from "../mocks/MockWeth.sol";
import {IVuxPoolDeployer, PoolDeployerHarness} from "./PoolDeployerHarness.sol";

/// @title TreasuryFixture — the production wiring topology, in a test.
/// @notice Two things are reproduced here rather than simplified away:
///
///         1. **The real pool.** `VuxPoolDeployer` is deployed from its genuine
///            `=0.7.6` artifact and deploys a genuine vendored pool by CREATE2,
///            so the treasury constructor's identity checks run against a pool
///            that answers for itself (sprint.md:L331 — "no mocks for identity
///            checks").
///         2. **The whole monetary core.** `VUX`, `HardReserve`, and `Rig` are
///            the real contracts, wired by CREATE prediction exactly as genesis
///            will wire them. Sprint 4's central claim is that no treasury
///            surface can reach any of them; asserting that against stubs would
///            assert nothing. It also means FB-5's bit-identity scenario runs
///            against real redemption and real VEM arithmetic.
///
///         The treasury address is predicted the same way, because the `Rig`'s
///         Strategic leg destination is immutable and the `Rig` is necessarily
///         constructed first. No fixture is allowed to need a wiring setter,
///         because production has none.
abstract contract TreasuryFixture is PoolDeployerHarness {
    address internal constant NON_OPERATOR = address(0xBADBAD);
    address internal constant OPS_RECIPIENT = address(0x09501);
    address internal constant ALICE = address(0xA11CE);

    /// @dev Genesis supply: `150_000e18 + 1` raw (INV-2, prd.md:L582).
    uint256 internal constant S0 = 150_000e18 + 1;

    // Rehearsal pricing, carried over from `RigFixture`. The USD targets behind
    // these are R-14 founder deployment-time facts (prd.md:L335); no accepted
    // authority fixes their wei values and this sprint must not freeze them.
    uint256 internal constant BOOTSTRAP_OPENING = 25 ether;
    uint256 internal constant MINIMUM_OPENING = 5 ether;
    uint256 internal constant DECAY_FLOOR = 0.5 ether;
    uint256 internal constant B0 = 272_727_272_727_272_727_272;

    // Pool parameters. Also R-14 operator-reserved deployment facts (PRD §16):
    // domain-checked by `VuxPoolDeployer`, never value-frozen by it, and used
    // here only because a pool cannot be created without *some* pair.
    uint24 internal constant FIXTURE_FEE = 3_000;
    int24 internal constant FIXTURE_TICK_SPACING = 60;

    /// @dev The commitment preimage's salt. In production this is a launch
    ///      secret until the launch block (sdd.md:L270); here it is a fixture
    ///      value with no production meaning.
    bytes32 internal constant FIXTURE_SALT = keccak256("vux.sprint-4.fixture.salt");

    MockWeth internal weth;
    MockErc20 internal otherAsset;
    HardReserve internal reserve;
    Rig internal rig;
    VUX internal vux;
    IVuxPoolDeployer internal poolDeployer;
    address internal pool;
    StrategicTreasury internal treasury;

    function _deploySystem() internal {
        uint256 n = uint256(vm.getNonce(address(this)));
        address predictedVux = vm.computeCreateAddress(address(this), n + 3);
        address predictedTreasury = vm.computeCreateAddress(address(this), n + 5);

        weth = new MockWeth(); //                                     nonce n
        reserve = new HardReserve(address(weth), predictedVux); //     nonce n+1
        rig = new Rig( //                                              nonce n+2
            address(weth),
            address(reserve),
            predictedVux,
            predictedTreasury,
            BOOTSTRAP_OPENING,
            MINIMUM_OPENING,
            DECAY_FLOOR
        );
        vux = new VUX(address(rig), address(reserve)); //              nonce n+3
        assertEq(address(vux), predictedVux, "CREATE prediction held for VUX");

        // nonce n+4. The pool itself is CREATE2 from `poolDeployer`, so it
        // consumes that contract's nonce and leaves this account's untouched.
        poolDeployer = _deployPoolDeployer(keccak256(abi.encode(address(this), FIXTURE_SALT)));
        (address token0, address token1) = _sorted(address(vux), address(weth));
        pool = poolDeployer.deployCanonicalPool(FIXTURE_SALT, token0, token1, FIXTURE_FEE, FIXTURE_TICK_SPACING);

        treasury = new StrategicTreasury( //                           nonce n+5
            address(weth), address(vux), address(reserve), address(poolDeployer), pool, FIXTURE_FEE
        );
        assertEq(address(treasury), predictedTreasury, "CREATE prediction held for the treasury");
        assertEq(rig.treasury(), address(treasury), "the Rig's Strategic leg targets the real treasury");

        otherAsset = new MockErc20("Other Asset (test)", "OTHER");

        // Genesis funds the Reserve; the Reserve is born empty, so this is `B`.
        weth.mint(address(this), B0);
        weth.transfer(address(reserve), B0);
        assertEq(reserve.backing(), B0, "genesis backing is exactly B0");
    }

    // --- treasury helpers -----------------------------------------------------

    function _newStrategy() internal returns (MockStrategy) {
        return new MockStrategy();
    }

    /// @dev Admit and fast-forward past the 24 h maturity, for the many tests
    ///      whose subject is what happens *after* the delay.
    function _admitMatured(address strategy, address asset, uint256 cap, uint8 mode) internal {
        treasury.admitStrategy(strategy, asset, cap, mode);
        vm.warp(vm.getBlockTimestamp() + treasury.ADMISSION_DELAY());
    }

    /// @dev Put `amount` of `asset` into the treasury as bare inventory — the
    ///      shape the 12% settlement leg arrives in (a plain transfer, no
    ///      callback), which books as principal-side inventory and never as
    ///      revenue (sdd.md:L303 rule 5).
    function _fundTreasury(address asset, uint256 amount) internal {
        if (asset == address(weth)) {
            weth.mint(address(treasury), amount);
        } else {
            MockErc20(asset).mint(address(treasury), amount);
        }
    }

    function _fund(address who, address asset, uint256 amount) internal {
        if (asset == address(weth)) {
            weth.mint(who, amount);
        } else {
            MockErc20(asset).mint(who, amount);
        }
    }

    /// @dev The next call must revert with OZ `AccessControl`'s unauthorized
    ///      error. Selector-only, because the error carries the account and role.
    function _expectUnauthorized() internal {
        vm.expectPartialRevert(bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")));
    }

    function _activateLsg() internal returns (MockLsgModule module) {
        module = new MockLsgModule();
        treasury.activateLSG(address(module));
    }

    // --- monetary-core snapshot (FB-5, INV-24) --------------------------------

    /// @dev Every core value a Strategic loss must leave untouched: `B` and `S`
    ///      (redemption's two inputs), the payout they produce, the four VEM
    ///      inputs the Rig holds, and the three immutable authority edges.
    struct CoreState {
        uint256 backing;
        uint256 supply;
        uint256 previewRedeem;
        address king;
        uint256 currentPrice;
        uint256 currentUps;
        uint256 epochUps;
        uint64 epochStart;
        uint64 epochId;
        address vuxRig;
        address vuxReserve;
        address rigTreasury;
    }

    function _snapshotCore() internal view returns (CoreState memory) {
        return CoreState({
            backing: reserve.backing(),
            supply: vux.totalSupply(),
            previewRedeem: reserve.previewRedeem(1e18),
            king: rig.king(),
            currentPrice: rig.currentPrice(),
            currentUps: rig.currentUPS(),
            epochUps: rig.epochUPS(),
            epochStart: rig.epochStart(),
            epochId: rig.epochId(),
            vuxRig: vux.rig(),
            vuxReserve: vux.reserve(),
            rigTreasury: rig.treasury()
        });
    }

    function _assertCoreUnchanged(CoreState memory before, string memory what) internal view {
        CoreState memory after_ = _snapshotCore();
        assertEq(after_.backing, before.backing, string.concat(what, ": B"));
        assertEq(after_.supply, before.supply, string.concat(what, ": S"));
        assertEq(after_.previewRedeem, before.previewRedeem, string.concat(what, ": redemption arithmetic"));
        assertEq(after_.king, before.king, string.concat(what, ": King"));
        assertEq(after_.currentPrice, before.currentPrice, string.concat(what, ": price"));
        assertEq(after_.currentUps, before.currentUps, string.concat(what, ": UPS"));
        assertEq(after_.epochUps, before.epochUps, string.concat(what, ": epoch UPS"));
        assertEq(uint256(after_.epochStart), uint256(before.epochStart), string.concat(what, ": epoch start"));
        assertEq(uint256(after_.epochId), uint256(before.epochId), string.concat(what, ": epoch id"));
        assertEq(after_.vuxRig, before.vuxRig, string.concat(what, ": mint authority"));
        assertEq(after_.vuxReserve, before.vuxReserve, string.concat(what, ": redemption-burn authority"));
        assertEq(after_.rigTreasury, before.rigTreasury, string.concat(what, ": routing constant"));
    }
}
