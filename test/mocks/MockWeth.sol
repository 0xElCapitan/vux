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
contract MockWeth is ERC20 {
    bool public failTransfers;
    bool public silentlyDropTransfers;
    address public reentryTarget;

    constructor() ERC20("Wrapped Ether (test)", "WETH") {}

    /// @dev Test-only balance provisioning. Real WETH is minted by `deposit()`.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
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

    function transfer(address to, uint256 value) public override returns (bool) {
        if (failTransfers) return false;
        if (silentlyDropTransfers) return true;

        address target = reentryTarget;
        if (target != address(0)) {
            // One-shot: clear before re-entering so the probe cannot recurse
            // forever if the guard under test is missing.
            reentryTarget = address(0);
            IRedeemable(target).redeem(1, address(this));
        }

        return super.transfer(to, value);
    }
}
