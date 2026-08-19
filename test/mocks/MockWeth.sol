// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Minimal callback surface used by the reentrancy probe below.
interface IRedeemable {
    function redeem(uint256 q, address to) external returns (uint256);
}

/// @title MockWeth — TEST ONLY. Never deployed, never imported by `src/`.
/// @notice Canonical RH WETH is an external, non-vendored dependency
///         (prd.md:L725); this stands in for it in unit and property tests. Only
///         the surface the Hard Reserve actually touches is modelled —
///         `balanceOf` and `transfer`. `deposit()`/`withdraw()` are deliberately
///         absent: nothing in Sprint 2 wraps native value (that is the Sprint-7
///         genesis path), so modelling them would be fiction with no assertion
///         behind it.
/// @dev The two probe switches exist to test failure modes that cannot be
///      reached otherwise, and each is off unless a test turns it on:
///
///      • `failTransfers` makes `transfer` return `false` WITHOUT reverting —
///        the case a bare `.transfer(...)` would swallow. It proves `SafeERC20`
///        is doing real work and that a failed payout reverts the whole
///        redemption rather than burning VUX for nothing.
///      • `reentryTarget` makes `transfer` call back into `redeem` exactly once,
///        which is the only way to observe whether `nonReentrant` actually
///        engages on the payout leg.
///      • `silentlyDropTransfers` makes `transfer` report success while moving
///        nothing — the fee-on-transfer / rebasing shape. It is the only way to
///        reach the Reserve constructor's born-empty `require`, which would
///        otherwise be untestable and indistinguishable from dead code.
///      • `transferFeeBp` withholds a fraction of every `transfer`, so the
///        recipient's measured delta is *less* than the amount sent. Added in
///        Sprint 3: the Rig's step-8b rejection compares the physically measured
///        Hard delta against the routed intent, and under-delivery is the
///        realistic way reality and intent diverge (FR-5.1, prd.md:L394).
///      • `transferBonus` credits the recipient *more* than was sent. The same
///        rejection must fire in that direction too — an over-measured delta
///        would otherwise inflate `Qsafe` — and no honest asset produces it, so
///        a probe is the only way to reach the branch.
///      • `failTransfersTo` fails transfers to exactly one address. Settlement
///        routes three legs in sequence, and FR-4's partial-failure injection
///        asks whether any single leg can fail while the others stand; failing
///        them one at a time is the only way to ask that question per leg.
///      • `setReentryCall` re-enters an arbitrary function once, from inside a
///        transfer. `reentryTarget` above is redemption-specific (Sprint 2) and
///        is left exactly as it was; this is its general form, needed because
///        the call to re-enter here is `Rig.take`, not `redeem`.
contract MockWeth is ERC20 {
    bool public failTransfers;
    bool public silentlyDropTransfers;
    address public reentryTarget;
    uint256 public transferFeeBp;
    uint256 public transferBonus;
    address public failTransfersTo;
    address public reentryCallTarget;
    bytes public reentryCallData;

    constructor() ERC20("Wrapped Ether (test)", "WETH") {}

    /// @dev Test-only balance provisioning. Real WETH is minted by `deposit()`.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @dev The native wrap, mirroring the semantics Q-6 measured against the
    ///      real canonical RH WETH on a Robinhood Chain fork: credit the caller
    ///      exactly `msg.value`, minting supply against the ETH actually received
    ///      (`test/fork/RhWethFork.t.sol`). Genesis funds itself through this
    ///      call inside `GenesisDeployer`'s constructor (sdd.md:L161), so the
    ///      mock has to have it — and having it match the *measured* behaviour,
    ///      rather than a guess at it, is what keeps the genesis suites honest.
    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function setFailTransfers(bool value) external {
        failTransfers = value;
    }

    function setReentryTarget(address target) external {
        reentryTarget = target;
    }

    function setSilentlyDropTransfers(bool value) external {
        silentlyDropTransfers = value;
    }

    function setTransferFeeBp(uint256 bp) external {
        transferFeeBp = bp;
    }

    function setTransferBonus(uint256 bonus) external {
        transferBonus = bonus;
    }

    function setFailTransfersTo(address to) external {
        failTransfersTo = to;
    }

    function setReentryCall(address target, bytes calldata data) external {
        reentryCallTarget = target;
        reentryCallData = data;
    }

    /// @dev Sprint 4: `transferFeeBp` applied to the PULL direction too. The
    ///      treasury's `returnFor` pulls with `transferFrom` and books what it
    ///      measured, not what it asked for — a distinction that only exists
    ///      when the pull can under-deliver. Inert unless `transferFeeBp` is set,
    ///      so no earlier suite changes behaviour.
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (transferFeeBp == 0) return super.transferFrom(from, to, value);
        _spendAllowance(from, _msgSender(), value);
        _transfer(from, to, value - (value * transferFeeBp) / 10_000);
        return true;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (failTransfers) return false;
        if (failTransfersTo != address(0) && to == failTransfersTo) return false;
        if (silentlyDropTransfers) return true;

        if (reentryCallTarget != address(0)) {
            // One-shot: cleared before re-entering, so a missing guard produces a
            // single observable re-entry rather than unbounded recursion.
            (address callTarget, bytes memory callData) = (reentryCallTarget, reentryCallData);
            reentryCallTarget = address(0);
            (bool ok, bytes memory err) = callTarget.call(callData);
            // Bubble the inner revert so the test sees *why* re-entry failed —
            // a swallowed revert would let a missing guard look like a pass.
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(err, 0x20), mload(err))
                }
            }
        }

        address target = reentryTarget;
        if (target != address(0)) {
            // One-shot: clear before re-entering so the probe cannot recurse
            // forever if the guard under test is missing.
            reentryTarget = address(0);
            IRedeemable(target).redeem(1, address(this));
        }

        uint256 fee = (value * transferFeeBp) / 10_000;
        bool ok = super.transfer(to, value - fee);
        // Minted rather than moved, so the recipient's delta exceeds the sent
        // amount without any other account's balance explaining it.
        if (transferBonus != 0) _mint(to, transferBonus);
        return ok;
    }
}
