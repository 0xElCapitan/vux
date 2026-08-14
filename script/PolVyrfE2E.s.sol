// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 5 Task 5.6, AC-4 (end-to-end POL/VYRF scenario)
//          FR-11 acceptance (prd.md:L489-L490); sdd.md:L862 (fork/E2E row)

import {Vm} from "../test/harness/Vm.sol";
import {PolFixture} from "../test/treasury/PolFixture.sol";

/// @title PolVyrfE2E — the POL/VYRF lifecycle, end to end, against a live node.
/// @notice Run with:
///
///         ```
///         anvil --port 8545
///         forge script script/PolVyrfE2E.s.sol:PolVyrfE2E \
///             --fork-url http://127.0.0.1:8545 -vvv
///         ```
///
///         **What this is and is not.** The SDD's fork row targets "an RH-chain
///         fork" (sdd.md:L862). That target is not reachable in this sprint and
///         is not simulated away: no Robinhood Chain RPC endpoint is recorded
///         anywhere in the accepted artifacts, because the endpoint — like the
///         canonical WETH address, the fee tier, and the tick spacing — is an
///         R-14 deployment-time fact that Sprints 7–8 record. There is nothing to
///         fork yet. What runs here instead is the same scenario against a live
///         local anvil node over JSON-RPC, which exercises the fork toolchain and
///         the full lifecycle for real, and differs from the CI suite in exactly
///         one respect: the chain underneath is anvil's own rather than RH's.
///
///         The one thing an RH-chain fork would add that this cannot is the
///         behaviour of the *real* canonical WETH contract — which is precisely
///         the YELLOW external dependency (prd.md:L721) that Sprint 7's genesis
///         rehearsal and Sprint 8's E2E are scheduled to exercise. That gap is
///         stated here rather than papered over.
///
///         The scenario makes each of the six required observables separately
///         visible, and asserts every one of them.
contract PolVyrfE2E {
    /// @dev The scenario runs in its own deployed contract, not in this one.
    ///      Foundry rejects `address(this)` inside a script contract — script
    ///      addresses are ephemeral — and the production topology this fixture
    ///      reproduces is built on CREATE nonce prediction from the deployer's
    ///      own address (sdd.md:L157). Rather than weaken the fixture to a shape
    ///      genesis does not use, the deployer is a real contract.
    function run() external {
        new PolVyrfScenario().execute();
    }
}

contract PolVyrfScenario is PolFixture {
    /// @dev The evidence record. Visible in the script's trace at `-vvv`.
    event E2EObservable(string what, uint256 value);

    function execute() external {
        _deployPolSystem();

        // --- 0. Genesis-shaped POL: the whole 150,000 VUX + the POL WETH leg ---
        _provisionPol(POL_VUX, W_POL);
        emit E2EObservable("polLiquidity", uint256(_polLiquidity()));
        emit E2EObservable("polVuxPrincipal", treasury.polVuxPrincipal());
        emit E2EObservable("polWethPrincipal", treasury.polWethPrincipal());
        _require(_polLiquidity() > 0, "E2E: the position exists");

        uint256 supplyAtStart = vux.totalSupply();
        uint256 backingAtStart = reserve.backing();

        // --- 1. WETH fee accrual: a third party buys VUX ---
        weth.mint(address(swapper), 40 ether);
        uint256 wethFeeBound = _swapWethForVux(40 ether);
        emit E2EObservable("wethFeeChargedUpperBound", wethFeeBound);

        // --- 2. VUX fee accrual: the same party sells it back ---
        uint256 vuxFeeBound = _swapVuxForWeth(vux.balanceOf(address(swapper)));
        emit E2EObservable("vuxFeeChargedUpperBound", vuxFeeBound);

        // Nothing has been counted yet — FB-8, on the way past.
        _require(treasury.realizedRevenue(address(weth)) == 0, "E2E: no anticipated WETH revenue");
        _require(treasury.realizedRevenue(address(vux)) == 0, "E2E: no anticipated VUX revenue");
        _require(reserve.backing() == backingAtStart, "E2E: B unmoved while fees pend");

        // --- 3. harvestPol, called by an address with no role at all ---
        uint256 treasuryVuxBefore = vux.balanceOf(address(treasury));
        uint256 treasuryWethBefore = weth.balanceOf(address(treasury));

        vm.recordLogs();
        vm.prank(address(0xC0FFEE));
        treasury.harvestPol();
        Vm.Log[] memory harvestLogs = vm.getRecordedLogs();

        (uint256 vuxFees, uint256 wethFees) = _vyrfLegs(harvestLogs);
        emit E2EObservable("vyrfVuxFeesBurned", vuxFees);
        emit E2EObservable("vyrfWethFeesToHard", wethFees);
        _require(vuxFees > 0, "E2E: a VUX fee leg was harvested");
        _require(wethFees > 0, "E2E: a WETH fee leg was harvested");
        _require(vuxFees <= vuxFeeBound, "E2E: the VUX leg is bounded by fees charged");
        _require(wethFees <= wethFeeBound, "E2E: the WETH leg is bounded by fees charged");

        // --- 4. The VUX burn, with its cause pairing ---
        // The supply change and the ERC-20 burn record agree with the event, and
        // all three are in the same transaction — the join the indexer performs
        // (sdd.md:L544).
        uint256 burnedOnToken = _vuxBurnedInLogs(harvestLogs);
        emit E2EObservable("vuxBurnedOnTokenInSameTx", burnedOnToken);
        _require(burnedOnToken == vuxFees, "E2E: Transfer-to-zero pairs with VyrfHarvest");
        _require(supplyAtStart - vux.totalSupply() == vuxFees, "E2E: S fell by exactly the burned leg");
        _require(vux.balanceOf(address(treasury)) == treasuryVuxBefore, "E2E: no VUX fee yield was retained");

        // --- 5. The WETH leg physically in the Hard Reserve, raising B ---
        emit E2EObservable("backingDelta", reserve.backing() - backingAtStart);
        _require(reserve.backing() - backingAtStart == wethFees, "E2E: B rose by exactly the WETH leg");
        _require(
            weth.balanceOf(address(reserve)) == reserve.backing(), "E2E: B is the Reserve's physical WETH balance"
        );
        _require(weth.balanceOf(address(treasury)) == treasuryWethBefore, "E2E: no WETH fee yield was retained");

        // ...and it did not pass through the general waterfall to get there.
        _require(treasury.realizedRevenue(address(weth)) == 0, "E2E: fee yield never entered the accumulator");
        _require(treasury.realizedRevenue(address(vux)) == 0, "E2E: in either denomination");

        // --- 6. Returned LP principal stays Strategic principal ---
        uint256 vuxBasisBefore = treasury.polVuxPrincipal();
        uint256 wethBasisBefore = treasury.polWethPrincipal();
        uint256 backingBeforeDecrease = reserve.backing();

        vm.recordLogs();
        treasury.decreasePol(_polLiquidity() / 2);
        Vm.Log[] memory decreaseLogs = vm.getRecordedLogs();

        (, uint256 vuxBack, uint256 wethBack,) = _polChange(decreaseLogs);
        emit E2EObservable("principalVuxReturned", vuxBack);
        emit E2EObservable("principalWethReturned", wethBack);
        _require(vuxBack > 0 && wethBack > 0, "E2E: principal came back on both legs");

        // It landed in Strategic custody, retired cost basis, and became revenue
        // nowhere — and none of it reached the Reserve.
        _require(vux.balanceOf(address(treasury)) >= vuxBack, "E2E: returned VUX is in Strategic custody");
        _require(weth.balanceOf(address(treasury)) >= wethBack, "E2E: returned WETH is Strategic dry powder");
        _require(treasury.polVuxPrincipal() < vuxBasisBefore, "E2E: returned VUX retired cost basis");
        _require(treasury.polWethPrincipal() < wethBasisBefore, "E2E: returned WETH retired cost basis");
        _require(treasury.realizedRevenue(address(weth)) == 0, "E2E: returned principal is not revenue");

        // The only thing that raised B across the decrease is its own fee leg.
        (uint256 decreaseVuxFees, uint256 decreaseWethFees) = _vyrfLegs(decreaseLogs);
        _require(
            reserve.backing() - backingBeforeDecrease == decreaseWethFees,
            "E2E: only the fee leg of the decrease reached Hard"
        );
        emit E2EObservable("decreaseVuxFeeLeg", decreaseVuxFees);
        emit E2EObservable("decreaseWethFeeLeg", decreaseWethFees);

        // --- closing: the ordering property, observed after the fact ---
        (uint256 owedVux, uint256 owedWeth) = _polTokensOwed();
        _require(owedVux == 0 && owedWeth == 0, "E2E: decreasePol left no principal credited to the position");

        emit E2EObservable("finalPolLiquidity", uint256(_polLiquidity()));
        emit E2EObservable("finalBacking", reserve.backing());
        emit E2EObservable("finalSupply", vux.totalSupply());
    }

    /// @dev `BaseTest`'s assertions are the suite's; this is the script's, so a
    ///      failure aborts the run with a legible reason rather than a raw revert.
    function _require(bool condition, string memory what) private pure {
        if (!condition) fail(what);
    }
}
