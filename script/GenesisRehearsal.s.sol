// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 7 Task 7.5 (two-transaction launch rehearsal script,
//          rehearsal values only) and launch-security obligation 12
//          sdd.md:L266 (launch = exactly two founder transactions), L268
//          (confidentiality vs. security), L270 (launch-secret hygiene)

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {GenesisDeployer, GenesisParams} from "../src/GenesisDeployer.sol";
import {Vm} from "../test/harness/Vm.sol";
import {GenesisFixture} from "../test/genesis/GenesisFixture.sol";

/// @title GenesisRehearsal — the launch, as two transactions, with fake values.
/// @notice Two entry points, because the two things worth rehearsing are
///         different:
///
///         `simulate()` — the choreography, runnable anywhere, no key and no
///         node. It performs tx1 and tx2 in-EVM and asserts the property the
///         whole nonce plan rests on: the commitment fixed in tx1 binds to an
///         address that does not exist yet, and tx2 must land on it exactly.
///
///         ```
///         forge script script/GenesisRehearsal.s.sol:GenesisRehearsal \
///             --sig "simulate()" -vvv
///         ```
///
///         `run()` — the real thing: two genuine transactions broadcast from a
///         rehearsal EOA, which is the only way to rehearse the founder's actual
///         nonce sequencing across a transaction boundary.
///
///         ```
///         anvil --port 8545
///         VUX_REHEARSAL_PK=<a throwaway anvil key> \
///         forge script script/GenesisRehearsal.s.sol:GenesisRehearsal \
///             --rpc-url http://127.0.0.1:8545 --broadcast -vvv
///         ```
///
/// @dev **Launch-secret hygiene (sdd.md:L270), stated as what this file does NOT
///      contain.** No production launch EOA or key; no production nonce plan; no
///      production commitment salt or preimage; no predicted production
///      addresses; no final genesis manifest; no founder conversion values; no
///      private-builder or routing configuration. The rehearsal key is read from
///      the environment and never written down. Every economic and pool constant
///      comes from `GenesisFixture`, which carries rehearsal figures only — the
///      real ones are R-14 founder deployment-time facts, and Q-3 (Safe signer
///      set and threshold) stays open as a Sprint-8 runbook input.
///      `broadcast/**` is gitignored and gate-checked, so running this against a
///      real node cannot leave an artifact in the repository.
///
/// @dev **Private routing is not modelled here, deliberately.** The production
///      posture requires a private same-block {fund-EOA -> tx2} bundle
///      (sdd.md:L268), but that is a *confidentiality* control layered on top of
///      a security property this rehearsal proves without it. Nothing below
///      depends on secrecy: the adversarial suite hands the attacker every
///      address and the salt itself and the launch is still exact.
contract GenesisRehearsal {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string private constant DEPLOYER_ARTIFACT = "out-v3core/VuxPoolDeployer.sol/VuxPoolDeployer.json";

    /// @notice In-EVM rehearsal of the two-transaction choreography.
    function simulate() external {
        new GenesisRehearsalScenario().execute();
    }

    /// @notice Broadcast rehearsal: two real transactions from a rehearsal EOA.
    function run() external {
        uint256 pk = vm.envUint("VUX_REHEARSAL_PK");
        address eoa = vm.addr(pk);

        Scenario memory s = _plan(eoa);

        // --- tx1: the inert, commitment-gated pool deployer -------------------
        // Publishes only its own address, its bytecode, and a 32-byte salted
        // commitment. Nothing about the protocol is derivable from it.
        bytes memory initCode = abi.encodePacked(
            vm.parseJsonBytes(vm.readFile(DEPLOYER_ARTIFACT), ".bytecode.object"), abi.encode(s.commitment)
        );
        vm.broadcast(pk);
        address poolDeployer = _create(initCode);

        // --- tx2: the launch transaction --------------------------------------
        // Its constructor IS genesis. The native value it carries is the whole
        // founder contribution, wrapped in-transaction (Q-6 verified on a real
        // Robinhood Chain fork: `test/fork/RhWethFork.t.sol`).
        GenesisParams memory p = _rehearsalParams(s, poolDeployer);
        vm.broadcast(pk);
        GenesisDeployer g = new GenesisDeployer{value: p.wPol + p.b0}(p);

        require(address(g) == s.predictedGenesis, "rehearsal: tx2 did not land on the committed address");
    }

    // -------------------------------------------------------------------------

    struct Scenario {
        address eoa;
        address predictedGenesis;
        bytes32 commitment;
        bytes32 salt;
    }

    /// @dev The founder's own nonce plan. tx1 consumes the current nonce, so the
    ///      `GenesisDeployer` lands on the next one — and the commitment has to
    ///      be computed against that address BEFORE tx1 is sent. Getting this
    ///      off by one produces a `BadCommitment` revert in tx2, which is the
    ///      same failure a real mis-sequenced launch would produce.
    function _plan(address eoa) private view returns (Scenario memory s) {
        s.eoa = eoa;
        s.salt = keccak256("vux.sprint-7.rehearsal.salt");
        uint256 n = uint256(vm.getNonce(eoa));
        s.predictedGenesis = vm.computeCreateAddress(eoa, n + 1);
        s.commitment = keccak256(abi.encode(s.predictedGenesis, s.salt));
    }

    /// @dev Rehearsal figures only. The WETH address is the one input a real
    ///      launch would not invent — here it is whatever the operator points
    ///      the rehearsal at, defaulting to zero so the omission fails loudly
    ///      rather than silently rehearsing against nothing.
    function _rehearsalParams(Scenario memory s, address poolDeployer) private view returns (GenesisParams memory p) {
        uint256 s0 = 150_000e18 + 1;
        uint256 b0 = 272_727_272_727_272_727_272;

        address weth = address(uint160(vm.envUint("VUX_REHEARSAL_WETH")));
        require(weth != address(0), "rehearsal: set VUX_REHEARSAL_WETH to a wrapped-native token");

        address predictedVux = vm.computeCreateAddress(s.predictedGenesis, 3);
        bool vuxIsToken0 = predictedVux < weth;

        p = GenesisParams({
            weth: weth,
            poolDeployer: poolDeployer,
            salt: s.salt,
            feeTier: 3_000,
            tickSpacing: 60,
            sqrtP0X96: _encodeSqrtP0X96(vuxIsToken0, b0, s0),
            b0: b0,
            wPol: 300 ether,
            bootstrapOpening: 25 ether,
            minimumOpening: 5 ether,
            decayFloor: 0.5 ether,
            operatorSafe: address(0x5AFE),
            p0Num: 11 * b0,
            p0Den: 10 * s0
        });
    }

    /// @dev The accepted encoder, floor at both steps (sdd.md:L185), over the
    ///      already-vendored OpenZeppelin primitives: `mulDiv` carries the
    ///      512-bit intermediate that `n << 192` needs, and `sqrt` is a floor
    ///      integer root. Hand-rolling either would be a second implementation
    ///      of arithmetic the census already authorises -- and the first draft of
    ///      this file did exactly that and overflowed on the checked `a * b`.
    function _encodeSqrtP0X96(bool vuxIsToken0, uint256 b0, uint256 s0) private pure returns (uint160) {
        (uint256 n, uint256 d) = vuxIsToken0 ? (11 * b0, 10 * s0) : (10 * s0, 11 * b0);
        return uint160(Math.sqrt(Math.mulDiv(n, 1 << 192, d)));
    }

    function _create(bytes memory initCode) private returns (address deployed) {
        assembly ("memory-safe") {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(deployed != address(0), "rehearsal: tx1 deployment reverted");
    }
}

/// @dev The in-EVM half. It reuses the genesis fixture rather than restating the
///      choreography, so the thing being rehearsed is the same thing the suites
///      prove — a second, subtly different copy would rehearse a fiction.
contract GenesisRehearsalScenario is GenesisFixture {
    event RehearsalObservable(string what, uint256 value);
    event RehearsalAddress(string what, address value);

    function execute() external {
        // --- tx1 ---------------------------------------------------------------
        _prepareLaunch();
        emit RehearsalAddress("tx1.poolDeployer", address(poolDeployer));
        emit RehearsalAddress("tx1.committedGenesisAddress", predictedGenesis);
        // Everything an observer can derive from tx1 alone. The point of the
        // list is that the protocol addresses below are NOT on it: they follow
        // from `predictedGenesis`, which the commitment hides behind a salt.
        emit RehearsalAddress("derivable.predictedVux", predictedVux);
        emit RehearsalAddress("derivable.predictedPool", predictedPool);

        // --- tx2 ---------------------------------------------------------------
        _launch();
        emit RehearsalAddress("tx2.genesisDeployer", address(genesis));
        emit RehearsalAddress("tx2.reserve", address(reserve));
        emit RehearsalAddress("tx2.rig", address(rig));
        emit RehearsalAddress("tx2.vux", address(vux));
        emit RehearsalAddress("tx2.pool", pool);
        emit RehearsalAddress("tx2.treasury", address(treasury));
        emit RehearsalAddress("tx2.lens", address(lens));

        // --- the assertions a rehearsal exists to make -------------------------
        require(address(genesis) == predictedGenesis, "rehearsal: tx2 missed the committed address");
        require(pool == predictedPool, "rehearsal: the canonical pool is not the predicted CREATE2 address");
        require(weth.balanceOf(address(reserve)) == B0, "rehearsal: B0 is not exact");
        require(vux.totalSupply() == S0, "rehearsal: S0 is not exact");
        require(_polLiquidity() > 0, "rehearsal: no canonical POL position");
        require(weth.balanceOf(address(genesis)) == 0, "rehearsal: deployer did not close at zero WETH");
        require(vux.balanceOf(address(genesis)) == 0, "rehearsal: deployer did not close at zero VUX");
        require(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), REHEARSAL_SAFE), "rehearsal: Safe has no admin");
        require(!treasury.hasRole(treasury.OPERATOR_ROLE(), address(genesis)), "rehearsal: deployer kept authority");
        require(poolDeployer.owner() == address(0), "rehearsal: pool deployer is not ownerless");
        require(poolDeployer.canonicalPool() == pool, "rehearsal: one-shot not consumed");

        emit RehearsalObservable("B0", weth.balanceOf(address(reserve)));
        emit RehearsalObservable("S0", vux.totalSupply());
        emit RehearsalObservable("sqrtP0X96", uint256(sqrtP0X96));
        emit RehearsalObservable("polLiquidity", uint256(_polLiquidity()));
        emit RehearsalObservable("contaminationSwept", genesis.contaminationSwept());
    }
}
