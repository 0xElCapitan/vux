// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import {BaseTest} from "../harness/BaseTest.sol";
import {MockWeth} from "../mocks/MockWeth.sol";
import {HardReserve} from "../../src/HardReserve.sol";
import {VUX} from "../../src/VUX.sol";

/// @title ReserveFixture — the production wiring topology, in a test.
/// @notice `VUX` and `HardReserve` reference each other immutably, which is a
///         2-cycle: one edge must be built against a *predicted* address
///         (sdd.md:L157). The fixture reproduces exactly that — deploy the
///         Reserve against the predicted VUX address, deploy VUX, then assert
///         the prediction held — rather than adding a setter to make testing
///         convenient. A wiring setter would be the single most damaging thing
///         this sprint could introduce, so no fixture is allowed to need one.
abstract contract ReserveFixture is BaseTest {
    address internal constant RIG = address(0xA11CE);
    address internal constant HOLDER = address(0xC0FFEE);
    address internal constant ATTACKER = address(0xBADBAD);
    address internal constant VICTIM = address(0xDEAD1);

    MockWeth internal weth;
    HardReserve internal reserve;
    VUX internal vux;

    /// @dev Genesis supply, before any test-driven mint or burn.
    uint256 internal constant S0 = 150_000e18 + 1;

    function _deploySystem() internal {
        weth = new MockWeth();

        // The Reserve is created at the current nonce; VUX at the next one.
        address predictedVux = vm.computeCreateAddress(address(this), uint256(vm.getNonce(address(this))) + 1);
        reserve = new HardReserve(address(weth), predictedVux);
        vux = new VUX(RIG, address(reserve));

        assertEq(address(vux), predictedVux, "CREATE prediction held (the genesis wiring method)");
        assertEq(address(reserve.vux()), address(vux), "reserve points at the real token");
        assertEq(vux.reserve(), address(reserve), "token points at the real reserve");
    }

    /// @dev Move every externally-held VUX to one account, so a single `redeem`
    ///      can address the whole redeemable float.
    function _consolidateFloatTo(address holder) internal {
        uint256 balance = vux.balanceOf(address(this));
        if (balance > 0 && holder != address(this)) vux.transfer(holder, balance);
    }

    function _mintVux(address to, uint256 amount) internal {
        vm.prank(RIG);
        vux.mint(to, amount);
    }

    /// @dev Shrink supply to `target` by self-burning the creator's genesis
    ///      inventory. Used where a readable small-number example is clearer
    ///      than a realistic one — `S0` is too large for hand-checkable
    ///      arithmetic. `burn` is the ordinary self-burn path, so this uses no
    ///      authority a holder does not have.
    function _shrinkSupplyTo(uint256 target) internal {
        uint256 current = vux.totalSupply();
        assertGe(current, target, "cannot shrink supply upward");
        vux.burn(current - target);
        assertEq(vux.totalSupply(), target, "supply shrunk to the example value");
    }
}
