// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 7 Task 7.1 / Deliverable "Q-6 evidence: fork-verified
//          canonical-WETH native-wrap (deposit()) semantics, recorded for R-14"
//          sdd.md:L155 (tx2 "carrying the genesis funding as native value which
//          the constructor wraps via canonical WETH.deposit()"), L161 (genesis
//          step 0), L235 (canonical RH WETH YELLOW row), L409 (the rejected
//          approval-funding alternative), §22 Q-6
//          docs/authority/vux-v1-canonical-specification-2026-08.md §21
//          Sprint-5 audit carry (recorded separately): the CURRENTLY DEPLOYED
//          canonical WETH transfer path invokes no recipient-controlled external
//          callback logic — the YELLOW fact quoted at sdd.md:L227 ("no …
//          transfer-hook") re-established against live code rather than inherited

import {BaseTest} from "../harness/BaseTest.sol";
import {Vm} from "../harness/Vm.sol";

/// @dev The external runtime interface of canonical RH WETH. Never vendored
///      (prd.md:L725) — declared here to the extent this gate calls it. The
///      `l1Address`/`l2Gateway` members are the aeWETH bridge surface and are
///      used as identity evidence, not as protocol dependencies.
interface IRhWeth {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function l1Address() external view returns (address);
    function l2Gateway() external view returns (address);
}

/// @title ConstructorWrapProbe — the discriminating Q-6 control.
/// @notice Q-6 is not "does a `deposit()` selector exist". The accepted topology
///         needs native value to be wrapped **inside a constructor**, and the
///         resulting WETH to be **spendable in that same constructor** (genesis
///         step 0 wraps `W_POL + B0`; step 7 transfers exactly `B0` onward).
///         This probe performs exactly that sequence in its own constructor and
///         `revert`s on any deviation, so a passing construction *is* the proof
///         and a non-conforming WETH cannot yield a deployed probe at all.
///
///         Every assertion is a measured delta, never an absolute balance — the
///         same discipline sdd.md:L156 requires of genesis itself.
contract ConstructorWrapProbe {
    uint256 public immutable wrappedDelta;
    uint256 public immutable supplyDelta;
    uint256 public immutable wethEthDelta;
    uint256 public immutable preSelfBalance;
    uint256 public immutable residual;

    error WrapDeltaMismatch(uint256 got, uint256 want);
    error SupplyDeltaMismatch(uint256 got, uint256 want);
    error EthDeltaMismatch(uint256 got, uint256 want);
    error TransferReturnedFalse();
    error ResidualNotZero(uint256 residual);

    /// @param polLeg   stands in for the POL WETH leg of genesis funding
    /// @param b0Leg    stands in for the exact `B0` leg
    /// @dev `msg.value` must equal `polLeg + b0Leg`; the residual check is what
    ///      makes that exact rather than approximate.
    constructor(IRhWeth weth, address polRecipient, uint256 polLeg, address b0Recipient, uint256 b0Leg) payable {
        uint256 preSelf = weth.balanceOf(address(this));
        uint256 preSupply = weth.totalSupply();
        uint256 preWethEth = address(weth).balance;
        preSelfBalance = preSelf;

        // The only funding input is this transaction's native value. No approval
        // is granted, and nothing was transferred to this address beforehand by
        // the caller — which is the whole point of the accepted topology
        // (sdd.md:L409: the approval flow "publishes a predicted address").
        weth.deposit{value: msg.value}();

        uint256 postSelf = weth.balanceOf(address(this));
        uint256 dBal = postSelf - preSelf;
        if (dBal != msg.value) revert WrapDeltaMismatch(dBal, msg.value);
        wrappedDelta = dBal;

        // Supply moving by exactly the same amount is what distinguishes genuine
        // mint-on-deposit wrapping from a transfer out of some pre-funded pool.
        uint256 dSupply = weth.totalSupply() - preSupply;
        if (dSupply != msg.value) revert SupplyDeltaMismatch(dSupply, msg.value);
        supplyDelta = dSupply;

        uint256 dEth = address(weth).balance - preWethEth;
        if (dEth != msg.value) revert EthDeltaMismatch(dEth, msg.value);
        wethEthDelta = dEth;

        // Spend it, in this constructor, in the two legs genesis actually uses.
        if (!weth.transfer(polRecipient, polLeg)) revert TransferReturnedFalse();
        if (!weth.transfer(b0Recipient, b0Leg)) revert TransferReturnedFalse();

        uint256 left = weth.balanceOf(address(this)) - preSelf;
        if (left != 0) revert ResidualNotZero(left);
        residual = left;
    }
}

/// @dev Discrimination control: a payable `deposit()` that takes the value and
///      credits nothing. Proves the probe's delta assertions are load-bearing —
///      selector existence and a successful call are both insufficient.
contract NoCreditWeth {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    function deposit() external payable {}

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
}

/// @dev Discrimination control: `deposit()` exists but is **not payable** — the
///      shape Q-6 would find if RH WETH were not the wrapped native asset. The
///      probe cannot even be constructed against it.
contract NonPayableDepositWeth {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    function deposit() external {}

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
}

/// @dev Sprint-5 carry control: a WETH whose `transfer` DOES hand control to the
///      recipient, and propagates the recipient's revert. Its only job is to
///      prove the two receivers below actually detect a callback — without it,
///      "`calls == 0`" would be an unfalsifiable claim.
contract HookingWeth {
    mapping(address => uint256) public balanceOf;

    error RecipientRejected();

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        (bool ok,) = to.call("");
        if (!ok) revert RecipientRejected();
        return true;
    }
}

/// @dev Reverts on ANY inbound call, with or without calldata (no `receive()`,
///      so empty-data calls land in `fallback` too). If a WETH transfer to this
///      address succeeds, the token made no call into the recipient.
contract RevertingReceiver {
    error CallbackInvoked(address caller, uint256 dataLength);

    fallback() external payable {
        revert CallbackInvoked(msg.sender, msg.data.length);
    }
}

/// @dev Records inbound calls instead of rejecting them, so the assertion can be
///      "exactly zero calls" rather than "the transfer happened to not revert".
contract RecordingReceiver {
    uint256 public calls;
    address public lastCaller;
    uint256 public lastDataLength;

    fallback() external payable {
        calls += 1;
        lastCaller = msg.sender;
        lastDataLength = msg.data.length;
    }

    function approveMax(IRhWeth weth, address spender) external {
        weth.approve(spender, type(uint256).max);
    }
}

/// @title RhWethForkTest — Q-6 evidence + the Sprint-5 WETH transfer-path carry.
/// @notice Runs only against a real Robinhood Chain fork. Off-fork the cases are
///         SKIPPED, never silently passed: this suite's verdict is only ever the
///         recorded fork run, and a green default run claims nothing about Q-6.
///
///         Required invocation (the exact recorded command, with its block, is
///         in grimoires/loa/a2a/sprint-7/evidence/q6-native-wrap.md):
///           VUX_RH_FORK_BLOCK=<n> VUX_RH_FORK_PARENT_HASH=<h> \
///           forge test --match-path test/fork/RhWethFork.t.sol \
///             --fork-url <RH mainnet RPC> --fork-block-number <n>
///
///         Reproduction caveat, measured here and recorded in the evidence: the
///         public RH RPC is NOT an archive node — it prunes historical state
///         after ~6,150 blocks (~10 minutes). Re-running at the originally
///         recorded block therefore requires an archive provider; re-running at
///         a fresh block (omitting the two env vars) works on the public RPC and
///         still proves every identity and behavioural claim, because the
///         identity anchors below are byte hashes rather than block heights.
contract RhWethForkTest is BaseTest {
    // --- recorded fork identity (Task 7.1 evidence) --------------------------
    uint256 internal constant RH_CHAIN_ID = 4663;

    /// @dev The exact-block binding is a RUNNER input, not a source constant.
    ///      Measured in Task 7.1: the public RH RPC prunes historical state after
    ///      roughly 6,150 blocks (~10 minutes), so a source-pinned block makes
    ///      this suite unreproducible within minutes of being written. The
    ///      evidence-capture run sets `VUX_RH_FORK_BLOCK` (+ optionally
    ///      `VUX_RH_FORK_PARENT_HASH`) and thereby proves the exact binding; a
    ///      later reviewer forking at their own block omits them and still gets
    ///      every block-independent identity and behavioural assertion below.
    string internal constant ENV_FORK_BLOCK = "VUX_RH_FORK_BLOCK";
    string internal constant ENV_FORK_PARENT_HASH = "VUX_RH_FORK_PARENT_HASH";

    /// @dev The accepted canonical address
    ///      (docs/authority/vux-v1-canonical-specification-2026-08.md §21).
    address internal constant WETH_ADDR = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    /// @dev Observed EIP-1967 implementation / admin behind the proxy. These are
    ///      *observations*, asserted so that a change in the upgradeable
    ///      infrastructure — precisely the YELLOW risk — turns into a red test
    ///      rather than a silent assumption. Block-independent: they hold at any
    ///      block until someone upgrades, which is exactly the event to catch.
    address internal constant WETH_IMPL = 0xC6B81b429797E0f555440b70cD99e032D7AE947e;
    address internal constant WETH_PROXY_ADMIN = 0xa3Acd31AFb851B4eB9DAD00F5204c01D924267dF;

    /// @dev Runtime-code hashes recorded at Task 7.1, cross-checked by two
    ///      independent paths (local keccak over `eth_getCode` bytes, and the
    ///      node's own `eth_getProof`-backed codehash). The strongest available
    ///      block-independent statement of "the deployed behaviour I tested is
    ///      the deployed behaviour you are testing".
    bytes32 internal constant WETH_PROXY_CODEHASH = 0x5706be52f64875fee65a2cec0d80e47a23d8793cbe85d214b48445e2d05f5353;
    bytes32 internal constant WETH_IMPL_CODEHASH = 0xbe1295f37be34ffe03ad779bda0ef278907e1856b51a3be2f35ee541d75d4650;
    bytes32 internal constant WETH_PROXY_ADMIN_CODEHASH =
        0xa4b2186ab82fa36fb4ae158582e5615ea519e757c26c13ba4a33daaaed8902a7;
    /// @dev aeWETH bridge surface: `l1Address()` is canonical Ethereum WETH9.
    address internal constant L1_WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant L2_WETH_GATEWAY = 0x1D187C3E2dA52D72BC9C41e3AbA0fdFa6a7bF055;

    bytes32 internal constant EIP1967_IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant EIP1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 internal constant EIP1967_BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    bytes32 internal constant TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)");

    IRhWeth internal weth = IRhWeth(WETH_ADDR);

    // Rehearsal legs. Not production conversion values (R-14 / operator-reserved);
    // any two distinct amounts exercise the same code path.
    uint256 internal constant POL_LEG = 3.5 ether;
    uint256 internal constant B0_LEG = 1.25 ether;
    uint256 internal constant FUNDING = POL_LEG + B0_LEG;

    address internal constant POL_RECIPIENT = address(0xB01);
    address internal constant B0_RECIPIENT = address(0xB02);

    /// @dev `true` when this run is not against the RH fork, having marked the
    ///      case skipped. Callers return immediately.
    function _skipOffFork() internal returns (bool) {
        if (block.chainid == RH_CHAIN_ID) return false;
        vm.skip(true);
        return true;
    }

    // ---------------------------------------------------------------- identity

    /// @notice The fork is the chain and the token the accepted trust surface
    ///         names — asserted before any behavioural claim is made on it.
    function test_ForkIdentity_MatchesAcceptedRhTrustSurface() public {
        if (_skipOffFork()) return;

        assertEq(block.chainid, RH_CHAIN_ID, "chainid");

        // Exact-block binding when the runner supplies one (evidence capture);
        // silent when it does not (reviewer on the pruning public RPC).
        uint256 wantBlock = vm.envOr(ENV_FORK_BLOCK, uint256(0));
        if (wantBlock != 0) {
            assertEq(block.number, wantBlock, "fork block number");
            bytes32 wantParent = vm.envOr(ENV_FORK_PARENT_HASH, bytes32(0));
            if (wantParent != bytes32(0)) {
                // Ties the run to one chain history, not merely to a height.
                assertEq(blockhash(block.number - 1), wantParent, "parent block hash");
            }
        }

        assertGt(WETH_ADDR.code.length, 0, "canonical WETH has code");
        assertEq(weth.name(), "WETH", "name");
        assertEq(weth.symbol(), "WETH", "symbol");
        assertEq(uint256(weth.decimals()), 18, "decimals");

        // aeWETH bridge identity — the accepted §21 evidence is "byte-verified
        // canonical Arbitrum aeWETH"; the L1 counterpart being WETH9 is the
        // strongest on-chain corroboration available from the token itself.
        assertEq(weth.l1Address(), L1_WETH9, "l1Address is canonical L1 WETH9");
        assertEq(weth.l2Gateway(), L2_WETH_GATEWAY, "l2Gateway");

        // Upgradeable infrastructure, exactly as the YELLOW row states.
        assertEq(address(uint160(uint256(vm.load(WETH_ADDR, EIP1967_IMPL_SLOT)))), WETH_IMPL, "EIP-1967 implementation");
        assertEq(
            address(uint160(uint256(vm.load(WETH_ADDR, EIP1967_ADMIN_SLOT)))), WETH_PROXY_ADMIN, "EIP-1967 proxy admin"
        );
        assertEq(vm.load(WETH_ADDR, EIP1967_BEACON_SLOT), bytes32(0), "not a beacon proxy");

        // Byte identity of all three deployed contracts. This is what makes the
        // recorded behavioural result transferable to a run at a different block.
        assertEq(WETH_ADDR.codehash, WETH_PROXY_CODEHASH, "proxy runtime codehash");
        assertEq(WETH_IMPL.codehash, WETH_IMPL_CODEHASH, "implementation runtime codehash");
        assertEq(WETH_PROXY_ADMIN.codehash, WETH_PROXY_ADMIN_CODEHASH, "proxy-admin runtime codehash");

        // A fully-backed 1:1 wrapper holds exactly its own supply in native ETH.
        // Asserted before this suite mints any test ETH into the system.
        assertEq(address(WETH_ADDR).balance, weth.totalSupply(), "native ETH held == WETH supply");
    }

    // ------------------------------------------------------------------- Q-6

    /// @notice Q-6, positively: native value wraps 1:1 **inside a constructor**
    ///         and the result is spendable in that same constructor.
    function test_Q6_ConstructorContextNativeWrapIsExactAndImmediatelySpendable() public {
        if (_skipOffFork()) return;

        vm.deal(address(this), FUNDING);

        uint256 preSupply = weth.totalSupply();
        uint256 preWethEth = address(WETH_ADDR).balance;

        // Construction itself is the assertion: the probe reverts on any
        // deviation, so reaching a deployed instance already proves the pattern.
        ConstructorWrapProbe probe =
            new ConstructorWrapProbe{value: FUNDING}(weth, POL_RECIPIENT, POL_LEG, B0_RECIPIENT, B0_LEG);

        assertEq(probe.preSelfBalance(), 0, "probe held no WETH before wrapping");
        assertEq(probe.wrappedDelta(), FUNDING, "wrapped credit == native value sent");
        assertEq(probe.supplyDelta(), FUNDING, "supply minted == native value sent");
        assertEq(probe.wethEthDelta(), FUNDING, "WETH-held ETH grew by the same amount");
        assertEq(probe.residual(), 0, "probe ended the constructor with zero residual");

        // The legs landed exactly, so the in-constructor spend was real.
        assertEq(weth.balanceOf(POL_RECIPIENT), POL_LEG, "POL leg delivered exactly");
        assertEq(weth.balanceOf(B0_RECIPIENT), B0_LEG, "B0 leg delivered exactly");
        assertEq(weth.balanceOf(address(probe)), 0, "probe holds nothing afterwards");

        assertEq(weth.totalSupply() - preSupply, FUNDING, "supply delta over the whole flow");
        assertEq(address(WETH_ADDR).balance - preWethEth, FUNDING, "ETH delta over the whole flow");
    }

    /// @notice The negative half of the accepted funding decision: no approval
    ///         and no pre-funding of any predicted address was required or used.
    function test_Q6_NoApprovalAndNoPrefundingWereUsed() public {
        if (_skipOffFork()) return;

        vm.deal(address(this), FUNDING);
        ConstructorWrapProbe probe =
            new ConstructorWrapProbe{value: FUNDING}(weth, POL_RECIPIENT, POL_LEG, B0_RECIPIENT, B0_LEG);

        // Nothing was pre-placed at the probe's address...
        assertEq(probe.preSelfBalance(), 0, "no pre-funding of the probe address");
        // ...and no allowance was granted in either direction by anyone here.
        assertEq(weth.allowance(address(probe), WETH_ADDR), 0, "probe granted WETH no allowance");
        assertEq(weth.allowance(address(probe), address(this)), 0, "probe granted the caller no allowance");
        assertEq(weth.allowance(address(this), WETH_ADDR), 0, "caller granted WETH no allowance");
        assertEq(weth.allowance(address(this), address(probe)), 0, "caller granted the probe no allowance");
    }

    /// @notice Discrimination: a `deposit()` that accepts value but credits
    ///         nothing fails the SAME probe. Selector presence is not the fact.
    function test_Q6_Control_ValueAcceptedButNotCreditedFails() public {
        if (_skipOffFork()) return;

        NoCreditWeth fake = new NoCreditWeth();
        vm.deal(address(this), FUNDING);
        vm.expectPartialRevert(ConstructorWrapProbe.WrapDeltaMismatch.selector);
        new ConstructorWrapProbe{value: FUNDING}(IRhWeth(address(fake)), POL_RECIPIENT, POL_LEG, B0_RECIPIENT, B0_LEG);
    }

    /// @notice Discrimination: a non-payable `deposit()` — the shape Q-6 would
    ///         find if RH WETH were not the wrapped native asset — cannot even
    ///         construct the probe. This is the fallback-transition trigger.
    function test_Q6_Control_NonPayableDepositFails() public {
        if (_skipOffFork()) return;

        NonPayableDepositWeth fake = new NonPayableDepositWeth();
        vm.deal(address(this), FUNDING);
        vm.expectRevert();
        new ConstructorWrapProbe{value: FUNDING}(IRhWeth(address(fake)), POL_RECIPIENT, POL_LEG, B0_RECIPIENT, B0_LEG);
    }

    // -------------------------------------------- Sprint-5 carry (recorded separately)

    /// @notice Sprint-5 carry: `transfer` hands no control to the recipient. A
    ///         recipient that rejects every inbound call still receives WETH.
    function test_Sprint5Carry_TransferInvokesNoRecipientCallback_RejectingReceiver() public {
        if (_skipOffFork()) return;

        RevertingReceiver hostile = new RevertingReceiver();
        vm.deal(address(this), 1 ether);
        weth.deposit{value: 1 ether}();

        assertTrue(weth.transfer(address(hostile), 1 ether), "transfer to a rejecting recipient succeeded");
        assertEq(weth.balanceOf(address(hostile)), 1 ether, "rejecting recipient credited exactly");
    }

    /// @notice Same fact, stated as an exact count rather than an absence of revert.
    function test_Sprint5Carry_TransferInvokesNoRecipientCallback_RecordingReceiver() public {
        if (_skipOffFork()) return;

        RecordingReceiver observer = new RecordingReceiver();
        vm.deal(address(this), 1 ether);
        weth.deposit{value: 1 ether}();

        assertTrue(weth.transfer(address(observer), 1 ether), "transfer succeeded");
        assertEq(observer.calls(), 0, "recipient was never called during transfer");
        assertEq(weth.balanceOf(address(observer)), 1 ether, "recipient credited exactly");
    }

    /// @notice `transferFrom` — the `Rig.take` payment-pull shape, where `from`
    ///         is attacker-chosen — calls neither side.
    function test_Sprint5Carry_TransferFromInvokesNoSenderOrRecipientCallback() public {
        if (_skipOffFork()) return;

        RecordingReceiver holder = new RecordingReceiver();
        RevertingReceiver hostile = new RevertingReceiver();

        vm.deal(address(this), 1 ether);
        weth.deposit{value: 1 ether}();
        assertTrue(weth.transfer(address(holder), 1 ether), "seed the holder");
        assertEq(holder.calls(), 0, "seeding did not call the holder");

        holder.approveMax(weth, address(this));

        assertTrue(weth.transferFrom(address(holder), address(hostile), 1 ether), "transferFrom succeeded");
        assertEq(holder.calls(), 0, "sender side was never called");
        assertEq(weth.balanceOf(address(hostile)), 1 ether, "recipient credited exactly");
    }

    /// @notice The complete log set of a transfer is exactly one `Transfer` from
    ///         the token itself — no hook, notification, or auxiliary event.
    function test_Sprint5Carry_TransferEmitsExactlyOneTransferEventAndNothingElse() public {
        if (_skipOffFork()) return;

        RecordingReceiver observer = new RecordingReceiver();
        vm.deal(address(this), 1 ether);
        weth.deposit{value: 1 ether}();

        vm.recordLogs();
        assertTrue(weth.transfer(address(observer), 1 ether), "transfer succeeded");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1, "exactly one log emitted by the whole transfer");
        assertEq(logs[0].emitter, WETH_ADDR, "the only emitter is the token");
        assertEq(logs[0].topics[0], TRANSFER_TOPIC, "the only event is ERC20 Transfer");
    }

    /// @notice Discrimination for the whole carry: against a WETH that DOES call
    ///         the recipient, both receivers detect it. Without this, the three
    ///         `calls == 0` assertions above would be unfalsifiable.
    function test_Sprint5Carry_Control_ReceiversDetectARealCallback() public {
        if (_skipOffFork()) return;

        HookingWeth hooking = new HookingWeth();
        vm.deal(address(this), 2 ether);
        hooking.deposit{value: 2 ether}();

        RecordingReceiver observer = new RecordingReceiver();
        hooking.transfer(address(observer), 1 ether);
        assertEq(observer.calls(), 1, "the recording receiver detects a real callback");

        RevertingReceiver hostile = new RevertingReceiver();
        vm.expectPartialRevert(HookingWeth.RecipientRejected.selector);
        hooking.transfer(address(hostile), 1 ether);
    }
}
