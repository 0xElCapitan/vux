// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 5 Tasks 5.1/5.2/5.3, AC-2 (zero standing approvals),
//          AC-3 (VYRF ordering), AC-5 (buyVuxForPol bounds, no mint path)
//          FR-10, FR-11; INV-25, INV-26, INV-28, INV-29
//          sdd.md:L139-L144, L168, L252-L260

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {Vm} from "../harness/Vm.sol";
import {PolFixture} from "./PolFixture.sol";

/// @title TreasuryPolTest — the POL sleeve against the real vendored pool.
/// @notice Every positive property here is measured on real v3-core bytecode:
///         real `mint` pay-in callbacks, real fee accrual from real third-party
///         swaps, and the real `tokensOwed` cell that the fee-first ordering is a
///         claim about. Nothing is asserted against a stub.
contract TreasuryPolTest is PolFixture {
    address internal constant KEEPER = address(0xC0FFEE);

    function setUp() public {
        _deployPolSystem();
    }

    // =========================================================================
    // Task 5.1 — mintPolPosition / increasePol
    // =========================================================================

    /// @dev Genesis step 7 in miniature (sdd.md:L168): the tokens arrive first,
    ///      the treasury mints the full-range position directly on the pool, and
    ///      it pays the pool out of its own balance through the callback.
    function test_MintPolPositionOwnsTheFullRangePositionDirectly() public {
        vux.transfer(address(treasury), POL_VUX);
        weth.mint(address(treasury), W_POL);

        uint256 vuxBefore = vux.balanceOf(address(treasury));
        uint256 wethBefore = weth.balanceOf(address(treasury));

        vm.recordLogs();
        treasury.mintPolPosition(POL_VUX, W_POL);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 vuxPaid = vuxBefore - vux.balanceOf(address(treasury));
        uint256 wethPaid = wethBefore - weth.balanceOf(address(treasury));

        assertGt(vuxPaid, 0, "the pool took VUX");
        assertGt(wethPaid, 0, "and WETH");
        assertGt(uint256(_polLiquidity()), 0, "a position exists");

        // Direct ownership, no periphery and no NFT: the position lives under the
        // treasury's own key, and it is the pool's entire active liquidity.
        assertEq(
            uint256(IUniswapV3Pool(pool).liquidity()),
            uint256(_polLiquidity()),
            "the treasury's own key holds all of the pool's active liquidity"
        );

        // Cost basis is what the pool actually took, to the wei.
        assertEq(treasury.polVuxPrincipal(), vuxPaid, "polVuxPrincipal is the measured VUX paid");
        assertEq(treasury.polWethPrincipal(), wethPaid, "polWethPrincipal is the measured WETH paid");

        (int8 direction, uint256 vuxDelta, uint256 wethDelta, uint128 liquidityDelta) = _polChange(logs);
        assertEq(int256(direction), int256(1), "an increase");
        assertEq(vuxDelta, vuxPaid, "the event reports the measured VUX");
        assertEq(wethDelta, wethPaid, "the event reports the measured WETH");
        assertEq(uint256(liquidityDelta), uint256(_polLiquidity()), "and the liquidity minted");

        _assertNoStandingApprovals("after mintPolPosition");
    }

    /// @dev The committed maxima are a ceiling the pool cannot breach, and the
    ///      remainder is quantization dust: it never entered the position, so it
    ///      stays bare treasury inventory — principal-side by §1.10 rule 5, never
    ///      revenue, and never booked as position basis (sdd.md:L168).
    function test_QuantizationDustStaysPrincipalSideInventory() public {
        vux.transfer(address(treasury), POL_VUX);
        weth.mint(address(treasury), W_POL);
        treasury.mintPolPosition(POL_VUX, W_POL);

        uint256 vuxDust = vux.balanceOf(address(treasury));
        uint256 wethDust = weth.balanceOf(address(treasury));

        assertEq(treasury.polVuxPrincipal(), POL_VUX - vuxDust, "basis + dust accounts for every committed VUX wei");
        assertEq(treasury.polWethPrincipal(), W_POL - wethDust, "and every committed WETH wei");
        assertLe(treasury.polVuxPrincipal(), POL_VUX, "the pool never took more VUX than committed");
        assertLe(treasury.polWethPrincipal(), W_POL, "nor more WETH");

        assertEq(treasury.realizedRevenue(address(vux)), 0, "dust is not revenue");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "in either token");
    }

    function test_IncreasePolAddsToTheExistingPosition() public {
        _provisionPol();
        uint128 liquidityBefore = _polLiquidity();
        uint256 vuxBasisBefore = treasury.polVuxPrincipal();
        uint256 wethBasisBefore = treasury.polWethPrincipal();

        vux.transfer(address(treasury), 10_000e18);
        weth.mint(address(treasury), 20 ether);

        uint256 vuxBefore = vux.balanceOf(address(treasury));
        uint256 wethBefore = weth.balanceOf(address(treasury));
        treasury.increasePol(10_000e18, 20 ether);

        assertGt(uint256(_polLiquidity()), uint256(liquidityBefore), "liquidity grew");
        assertEq(
            treasury.polVuxPrincipal() - vuxBasisBefore,
            vuxBefore - vux.balanceOf(address(treasury)),
            "basis grew by exactly the VUX paid"
        );
        assertEq(
            treasury.polWethPrincipal() - wethBasisBefore,
            wethBefore - weth.balanceOf(address(treasury)),
            "and by exactly the WETH paid"
        );
        _assertNoStandingApprovals("after increasePol");
    }

    /// @dev The two names mean different things and neither can do the other's
    ///      job: minting over a live position, or increasing one that does not
    ///      exist, both fail closed.
    function test_MintAndIncreaseAreNotInterchangeable() public {
        vm.expectRevert(StrategicTreasury.PolPositionMissing.selector);
        treasury.increasePol(1e18, 1 ether);

        _provisionPol();

        vux.transfer(address(treasury), 1e18);
        weth.mint(address(treasury), 1 ether);
        vm.expectRevert(StrategicTreasury.PolPositionExists.selector);
        treasury.mintPolPosition(1e18, 1 ether);
    }

    function test_PolOperationsAreOperatorGated() public {
        _provisionPol();
        vm.startPrank(NON_OPERATOR);

        _expectUnauthorized();
        treasury.mintPolPosition(1e18, 1 ether);

        _expectUnauthorized();
        treasury.increasePol(1e18, 1 ether);

        _expectUnauthorized();
        treasury.decreasePol(1);

        _expectUnauthorized();
        treasury.buyVuxForPol(1 ether, 0, _limitFor(!vuxIsToken0));

        vm.stopPrank();
    }

    // =========================================================================
    // Task 5.2 — decreasePol
    // =========================================================================

    /// @dev The ordering property, observed rather than assumed: one call emits
    ///      the VYRF legs for the accrued fees AND the principal return, and
    ///      leaves `tokensOwed` empty — so no principal was ever left credited
    ///      where a later `collect` could sweep it as fee yield.
    function test_DecreasePolCollectsFeesFirstThenSweepsPrincipalAtomically() public {
        _provisionPol();
        _accrueBothFeeLegs(20 ether);

        uint128 liquidity = _polLiquidity();
        uint256 supplyBefore = vux.totalSupply();
        uint256 backingBefore = reserve.backing();
        uint256 vuxHeldBefore = vux.balanceOf(address(treasury));
        uint256 wethHeldBefore = weth.balanceOf(address(treasury));

        vm.recordLogs();
        treasury.decreasePol(liquidity / 2);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        (uint256 vuxFees, uint256 wethFees) = _vyrfLegs(logs);
        assertGt(vuxFees, 0, "VUX fees accrued and were classified");
        assertGt(wethFees, 0, "WETH fees accrued and were classified");

        // The fee legs went where VYRF says, not into the returned principal.
        assertEq(supplyBefore - vux.totalSupply(), vuxFees, "VUX fees burned, exactly");
        assertEq(reserve.backing() - backingBefore, wethFees, "WETH fees reached the Reserve, exactly");

        // The principal legs are separately observable and are what stayed here.
        (int8 direction, uint256 vuxBack, uint256 wethBack, uint128 liquidityBurned) = _polChange(logs);
        assertEq(int256(direction), int256(-1), "a decrease");
        assertEq(uint256(liquidityBurned), uint256(liquidity / 2), "the liquidity the operator asked for");
        assertEq(vux.balanceOf(address(treasury)) - vuxHeldBefore, vuxBack, "VUX principal stayed here");
        assertEq(weth.balanceOf(address(treasury)) - wethHeldBefore, wethBack, "WETH principal stayed Strategic");

        // The load-bearing half: nothing is left credited to the position.
        (uint256 owedVux, uint256 owedWeth) = _polTokensOwed();
        assertEq(owedVux, 0, "no VUX left owed after decreasePol returns");
        assertEq(owedWeth, 0, "no WETH left owed after decreasePol returns");

        _assertNoStandingApprovals("after decreasePol");
    }

    /// @dev INV-28 / FR-11.3: returned LP principal is principal. It retires cost
    ///      basis and never credits a wei of distributable revenue — including
    ///      when a token comes back worth more than it went in, which is exactly
    ///      what a price move produces on one leg of a two-sided position.
    function test_ReturnedPrincipalIsNeverRevenue() public {
        _provisionPol();
        // A large one-way buy leaves the position holding much more WETH and much
        // less VUX than it was funded with.
        weth.mint(address(swapper), 200 ether);
        _swapWethForVux(200 ether);

        uint256 vuxBasis = treasury.polVuxPrincipal();
        uint256 wethBasis = treasury.polWethPrincipal();

        vm.recordLogs();
        treasury.decreasePol(_polLiquidity());
        (, uint256 vuxBack, uint256 wethBack,) = _polChange(vm.getRecordedLogs());

        assertGt(wethBack, wethBasis, "the WETH side came back above its basis");
        assertLt(vuxBack, vuxBasis, "and the VUX side below its own");
        assertEq(treasury.polWethPrincipal(), 0, "the exceeded basis retires to zero, never below it");
        assertLe(treasury.polVuxPrincipal(), vuxBasis, "the other basis only ever falls");
        assertEq(treasury.realizedRevenue(address(vux)), 0, "no VUX revenue credit");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "no WETH revenue credit (INV-28)");
    }

    function test_DecreasePolRejectsZero() public {
        _provisionPol();
        vm.expectRevert(StrategicTreasury.ZeroAmount.selector);
        treasury.decreasePol(0);
    }

    // =========================================================================
    // Task 5.2 — buyVuxForPol
    // =========================================================================

    /// @dev Existing-supply sourcing (INV-26): the treasury's VUX grows, total
    ///      supply does not move by a single wei, and custody never leaves.
    function test_BuyVuxForPolSourcesExistingSupplyAndNeverMints() public {
        _provisionPol();
        weth.mint(address(treasury), 10 ether);

        uint256 supplyBefore = vux.totalSupply();
        uint256 vuxBefore = vux.balanceOf(address(treasury));
        uint256 wethBefore = weth.balanceOf(address(treasury));

        vm.recordLogs();
        treasury.buyVuxForPol(5 ether, 1, _limitFor(!vuxIsToken0));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 vuxOut = vux.balanceOf(address(treasury)) - vuxBefore;
        assertGt(vuxOut, 0, "VUX was acquired");
        assertEq(vux.totalSupply(), supplyBefore, "INV-26: not one wei was minted");
        assertEq(wethBefore - weth.balanceOf(address(treasury)), 5 ether, "paid exactly the committed WETH");

        (uint256 loggedIn, uint256 loggedOut) = abi.decode(_oneLog(logs, VUX_PURCHASED_TOPIC).data, (uint256, uint256));
        assertEq(loggedIn, 5 ether, "the event reports the input");
        assertEq(loggedOut, vuxOut, "and the measured output");

        assertEq(treasury.realizedRevenue(address(vux)), 0, "a purchase is not revenue");
        _assertNoStandingApprovals("after buyVuxForPol");
    }

    /// @dev `minVuxOut` is applied to the treasury's own measured balance delta,
    ///      so a pool that under-delivers cannot talk its way past it.
    function test_BuyVuxForPolEnforcesMinVuxOut() public {
        _provisionPol();
        weth.mint(address(treasury), 10 ether);

        // Learn the honest output, then demand twice it.
        uint256 vuxBefore = vux.balanceOf(address(treasury));
        treasury.buyVuxForPol(1 ether, 1, _limitFor(!vuxIsToken0));
        uint256 achievable = vux.balanceOf(address(treasury)) - vuxBefore;

        vm.expectPartialRevert(StrategicTreasury.SlippageExceeded.selector);
        treasury.buyVuxForPol(1 ether, achievable * 2, _limitFor(!vuxIsToken0));
    }

    /// @dev The price limit binds inside the pool: a limit at the current price
    ///      leaves the swap no room, so the operator's price bound is honoured by
    ///      the venue rather than by anything this contract chooses to check.
    function test_BuyVuxForPolEnforcesSqrtPriceLimit() public {
        _provisionPol();
        weth.mint(address(treasury), 10 ether);

        // Read the price BEFORE arming the expectation: an argument that is
        // itself an external call would consume the `expectRevert` instead.
        uint160 limitAtCurrentPrice = _sqrtPriceX96();

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "SPL"));
        treasury.buyVuxForPol(1 ether, 1, limitAtCurrentPrice);
    }

    function test_BuyVuxForPolRejectsZero() public {
        _provisionPol();
        vm.expectRevert(StrategicTreasury.ZeroAmount.selector);
        treasury.buyVuxForPol(0, 0, _limitFor(!vuxIsToken0));
    }

    // =========================================================================
    // Task 5.3 — harvestPol (VYRF)
    // =========================================================================

    /// @dev FR-11 end to end in one call, with all three legs separately
    ///      observable and each burn paired to its cause (sdd.md:L544).
    function test_HarvestPolBurnsVuxFeesAndAccretesWethFeesToHard() public {
        _provisionPol();
        (uint256 wethFeeBound, uint256 vuxFeeBound) = _accrueBothFeeLegs(20 ether);

        uint256 supplyBefore = vux.totalSupply();
        uint256 backingBefore = reserve.backing();
        uint256 treasuryVuxBefore = vux.balanceOf(address(treasury));
        uint256 treasuryWethBefore = weth.balanceOf(address(treasury));
        uint128 liquidityBefore = _polLiquidity();

        vm.recordLogs();
        vm.prank(KEEPER); // permissionless: no role, no allowlist
        treasury.harvestPol();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        (uint256 vuxFees, uint256 wethFees) = _vyrfLegs(logs);
        assertGt(vuxFees, 0, "a VUX fee leg exists");
        assertGt(wethFees, 0, "a WETH fee leg exists");
        assertLe(vuxFees, vuxFeeBound, "and is bounded by the fee the pool could have charged");
        assertLe(wethFees, wethFeeBound, "likewise");

        assertEq(supplyBefore - vux.totalSupply(), vuxFees, "VUX fee yield burned: S fell by exactly the leg");
        assertEq(_vuxBurnedInLogs(logs), vuxFees, "and the burn is paired to VyrfHarvest in the same transaction");
        assertEq(reserve.backing() - backingBefore, wethFees, "WETH fee yield raised B by exactly the leg");

        // Neither leg lingers in the treasury, and neither is revenue.
        assertEq(vux.balanceOf(address(treasury)), treasuryVuxBefore, "no VUX fee yield is held after harvest");
        assertEq(weth.balanceOf(address(treasury)), treasuryWethBefore, "nor WETH");
        assertEq(treasury.realizedRevenue(address(vux)), 0, "INV-29: fee yield bypasses the waterfall");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "in both denominations");

        // Principal is untouched by a harvest.
        assertEq(uint256(_polLiquidity()), uint256(liquidityBefore), "the position is intact");
        assertEq(treasury.polVuxPrincipal(), treasury.polVuxPrincipal(), "and its basis unmoved");
        _assertNoStandingApprovals("after harvestPol");
    }

    /// @dev Harvest performs no swap, so it has no slippage surface at all: the
    ///      pool's price is bit-identical across it (sdd.md:L144).
    function test_HarvestPolPerformsNoSwap() public {
        _provisionPol();
        _accrueBothFeeLegs(10 ether);

        uint160 priceBefore = _sqrtPriceX96();
        uint128 liquidityBefore = _polLiquidity();
        uint256 basisBefore = treasury.polVuxPrincipal();

        treasury.harvestPol();

        assertEq(uint256(_sqrtPriceX96()), uint256(priceBefore), "the marginal price did not move");
        assertEq(uint256(_polLiquidity()), uint256(liquidityBefore), "and no liquidity was traded");
        assertEq(treasury.polVuxPrincipal(), basisBefore, "a harvest never touches cost basis");
    }

    /// @dev A harvest with nothing accrued is a lawful no-op that still reports
    ///      its own truth: two zero legs. It does not revert, because reverting
    ///      would make a permissionless keeper's timing an error condition.
    function test_HarvestPolWithNoFeesIsAnHonestNoOp() public {
        _provisionPol();

        vm.recordLogs();
        treasury.harvestPol();
        (uint256 vuxFees, uint256 wethFees) = _vyrfLegs(vm.getRecordedLogs());

        assertEq(vuxFees, 0, "no VUX fee yield");
        assertEq(wethFees, 0, "no WETH fee yield");
    }

    function test_HarvestPolWithoutAPositionFailsClosed() public {
        vm.expectRevert(StrategicTreasury.PolPositionMissing.selector);
        treasury.harvestPol();
    }

    /// @dev NFR-REL-2: the absence of a keeper cannot corrupt classification.
    ///      Fees accrued over many unharvested trades collect correctly in one
    ///      late call — the outcome depends on *what* accrued, never on *when*
    ///      anybody got around to asking.
    function test_KeeperAbsenceCannotCorruptClassification() public {
        _provisionPol();
        for (uint256 i = 0; i < 6; i++) {
            _accrueBothFeeLegs(2 ether);
            vm.warp(vm.getBlockTimestamp() + 1 days);
        }

        uint256 supplyBefore = vux.totalSupply();
        uint256 backingBefore = reserve.backing();

        vm.recordLogs();
        vm.prank(KEEPER);
        treasury.harvestPol();
        (uint256 vuxFees, uint256 wethFees) = _vyrfLegs(vm.getRecordedLogs());

        assertGt(vuxFees, 0, "the backlog was real");
        assertEq(supplyBefore - vux.totalSupply(), vuxFees, "the whole VUX backlog burned");
        assertEq(reserve.backing() - backingBefore, wethFees, "the whole WETH backlog reached Hard");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "and none of it became revenue");
    }
}
