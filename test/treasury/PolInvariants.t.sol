// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 5 Task 5.5, AC-3 (VYRF ordering invariant), AC-7
//          INV-25 (POL WETH is Strategic; POL VUX stays in S), INV-26 (no
//          post-genesis POL VUX mint, no Reserve-funded POL), INV-28 (returned
//          principal is principal), INV-29 (VUX fee yield burns, WETH fee yield
//          enters Hard, both bypass the waterfall)
//          re-proves INV-23/24/30/33/35 under POL pressure
//          sdd.md:L141-L143, L260; prd.md:L623-L624

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {MockStrategy} from "../mocks/MockStrategy.sol";
import {PolFixture} from "./PolFixture.sol";
import {PolInvariantHandler} from "./PolInvariantHandler.sol";

/// @title PolInvariantsTest — the Sprint-4 identities, re-asked with POL running.
/// @notice Two claims are being made at once, and they need each other:
///
///         1. The Sprint-4 attribution identities still hold when a live POL
///            position, a keeper, and third-party traders are in the sequence —
///            with exactly one new attributed cause on each side (`B` gains the
///            VYRF WETH leg; `S` loses the VYRF burn). Anything else reaching
///            either is unattributed and fails the run.
///         2. The fee/principal boundary is real: what a harvest classifies as
///            fee yield is bounded by fees the pool could actually have charged,
///            computed from this suite's own swap inputs — so principal cannot be
///            classified as yield without breaking the sum.
contract PolInvariantsTest is PolFixture {
    PolInvariantHandler internal handler;
    MockStrategy[3] internal strategies;

    /// @dev Genesis `B0` predates the ghosts, so it is the constant offset every
    ///      attribution is measured from.
    uint256 internal backing0;

    /// @dev Likewise for the position `setUp` provisions before the handler
    ///      exists: it is genesis-shaped POL, not something the handler paid for,
    ///      so it belongs on the baseline side rather than in the ghost. The
    ///      invariant is still an attribution — it just starts from the state the
    ///      handler was handed, exactly as `backing0` does.
    uint256 internal polVuxBasis0;
    uint256 internal polWethBasis0;

    function setUp() public {
        _deployPolSystem();

        strategies[0] = _newStrategy();
        strategies[1] = _newStrategy();
        strategies[2] = _newStrategy();

        handler = new PolInvariantHandler(
            weth, otherAsset, reserve, rig, vux, treasury, strategies, IUniswapV3Pool(pool), swapper
        );

        treasury.grantRole(treasury.OPERATOR_ROLE(), address(handler));
        treasury.setOpsRecipient(OPS_RECIPIENT);

        // Split the genesis POL allocation three ways: into the position, into
        // the handler's float (so `addPol` stays effective), and into the
        // swapper (so somebody can sell VUX from the first call onward).
        _provisionPol(60_000e18, 120 ether);
        vux.transfer(address(handler), 60_000e18);
        vux.transfer(address(swapper), 30_000e18);

        backing0 = reserve.backing();
        polVuxBasis0 = treasury.polVuxPrincipal();
        polWethBasis0 = treasury.polWethPrincipal();
    }

    function targetContracts() public view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    // =========================================================================
    // INV-25 / INV-29 — what may reach B, and what may not
    // =========================================================================

    /// @dev `B` equals genesis plus its attributed causes minus redemptions, with
    ///      the VYRF WETH leg now among those causes and POL *principal* pointedly
    ///      not among them.
    ///
    ///      That asymmetry is INV-25 in state form: POL WETH is Strategic, so the
    ///      only POL-shaped wei that may ever enter `B` is incremental fee yield.
    ///      A `decreasePol` that misfiled returned principal as a fee, or any
    ///      other Strategic path finding its way to the Reserve, appears here
    ///      immediately as an unattributed delta.
    function invariant_BackingIsAttributedIncludingTheVyrfLeg() public view {
        assertEq(
            reserve.backing(),
            backing0 + handler.ghostHardIn() - handler.ghostHardOut(),
            "INV-25/INV-29: B moves only by settlement legs, donations, the WETH revenue leg, VYRF fees, and redemptions"
        );
    }

    /// @dev Every unit of `S` traces to exactly one cause, now including the VYRF
    ///      burn. There is still no mint path outside settlement (INV-26) and no
    ///      third-party burn.
    function invariant_SupplyIsAttributedIncludingTheVyrfBurn() public view {
        assertEq(
            vux.totalSupply(),
            handler.ghostGenesisSupply() + handler.ghostMintedBySettlement() - handler.ghostBurnedByRedemption()
                - handler.ghostBurnedByTreasury() - handler.ghostVyrfVuxBurned(),
            "INV-26/INV-29: S == genesis + settlement mints - redemption - F-46 burn - VYRF burn"
        );
    }

    /// @dev INV-26 stated on its own terms: no POL operation — not a mint, not an
    ///      increase, not a purchase, not a harvest — has ever raised supply.
    ///      Settlement remains the sole issuance authority.
    function invariant_NoPolPathEverIncreasesSupply() public view {
        assertLe(
            vux.totalSupply(),
            handler.ghostGenesisSupply() + handler.ghostMintedBySettlement(),
            "INV-26: no post-genesis VUX mint sources POL"
        );
    }

    // =========================================================================
    // The VYRF ordering property (sdd.md:L142) — the load-bearing invariant
    // =========================================================================

    /// @dev Outside a `decreasePol` execution, the position's `tokensOwed`
    ///      consists only of accrued fees.
    ///
    ///      Stated mechanically: what is owed can never exceed the fees the pool
    ///      could have charged on this suite's own swaps, less what has already
    ///      been collected. Principal is credited to the very same cell by
    ///      `burn`, and it is orders of magnitude larger than any fee — so a
    ///      `decreasePol` that failed to sweep it atomically, or any other path
    ///      that left principal owed, breaks this on the next observation.
    function invariant_TokensOwedIsFeesOnly() public view {
        (uint256 vuxOwed, uint256 wethOwed) = handler.polTokensOwed();
        assertLe(
            vuxOwed,
            handler.ghostFeesChargedVux() - handler.ghostFeesCollectedVux(),
            "VYRF ordering: VUX owed to the position is uncollected fees, never principal"
        );
        assertLe(
            wethOwed,
            handler.ghostFeesChargedWeth() - handler.ghostFeesCollectedWeth(),
            "VYRF ordering: WETH owed to the position is uncollected fees, never principal"
        );
    }

    /// @dev The same boundary from the other side: everything ever *classified*
    ///      as fee yield is bounded by fees that were actually charged. Together
    ///      with the invariant above this closes both directions — principal
    ///      cannot sit owed as if it were a fee, and cannot be paid out as one.
    function invariant_VyrfClassifiedAmountsNeverExceedFeesCharged() public view {
        assertLe(
            handler.ghostVyrfVuxBurned(),
            handler.ghostFeesChargedVux(),
            "INV-29: VUX burned as fee yield never exceeds VUX fees charged"
        );
        assertLe(
            handler.ghostVyrfWethToHard(),
            handler.ghostFeesChargedWeth(),
            "INV-29: WETH accreted as fee yield never exceeds WETH fees charged"
        );
    }

    // =========================================================================
    // INV-28 / INV-29 — principal is principal; fee yield is not revenue
    // =========================================================================

    /// @dev POL fee yield bypasses the general waterfall (INV-29) and returned LP
    ///      principal is not revenue (INV-28), in the one form a state invariant
    ///      can express both: the revenue accumulator is still bounded by what
    ///      *strategies* delivered. POL receipts are not in that sum, so a single
    ///      wei of fee yield or returned principal credited as revenue breaks it.
    function invariant_RevenueStillTracesOnlyToStrategyFlows() public view {
        address[2] memory assets = [address(weth), address(otherAsset)];
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 everCredited = treasury.realizedRevenue(assets[i]) + handler.ghostRevenueAllocated(assets[i]);
            assertLe(
                everCredited,
                handler.ghostReceivedFromStrategies(assets[i]),
                "INV-28/INV-29: POL principal and POL fee yield never credit realized revenue"
            );
        }
        assertEq(
            treasury.realizedRevenue(address(vux)), 0, "INV-29: VUX fee yield is burned, never credited as revenue"
        );
    }

    /// @dev Cost basis is created only by paying the pool. It can be retired by a
    ///      decrease, but never invented — and never exceeds what went in, which
    ///      is what stops a price move from being booked as a gain.
    function invariant_PolBasisNeverExceedsWhatWasPaidIn() public view {
        assertLe(
            treasury.polVuxPrincipal(),
            polVuxBasis0 + handler.ghostPolVuxPaid(),
            "INV-28: VUX basis traces to payments"
        );
        assertLe(
            treasury.polWethPrincipal(),
            polWethBasis0 + handler.ghostPolWethPaid(),
            "INV-28: WETH basis traces to payments"
        );
    }

    // =========================================================================
    // Structure that POL must not move
    // =========================================================================

    /// @dev The protocol's POL is one position, under the treasury's own key,
    ///      held directly on the pool. No periphery contract and no NFT holds it,
    ///      and nothing in the sprint's action space can make that stop being true.
    function invariant_ThePositionIsHeldDirectlyByTheTreasury() public view {
        assertEq(
            uint256(IUniswapV3Pool(pool).liquidity()),
            uint256(handler.polLiquidity()),
            "INV-25: the pool's active liquidity is exactly the treasury's own position"
        );
    }

    /// @dev Re-proven under POL pressure: the authority graph is immutable, and
    ///      the pool identity in particular can never be replaced.
    function invariant_TheAuthorityGraphNeverMoves() public view {
        assertEq(vux.rig(), address(rig), "the sole mint authority");
        assertEq(vux.reserve(), address(reserve), "the sole redemption-burn authority");
        assertEq(rig.treasury(), address(treasury), "the Strategic routing constant");
        assertEq(treasury.hardReserve(), address(reserve), "the accretion destination");
        assertEq(treasury.pool(), pool, "the verified pool, unreplaceable");
    }

    // =========================================================================
    // anti-degeneracy
    // =========================================================================

    /// @dev A plain test, not an invariant: an invariant is evaluated against the
    ///      post-`setUp` state too, where "the handler has done work" is false by
    ///      construction and the suite would fail to start.
    ///
    ///      Drives one of each POL action in an order that reaches every branch
    ///      and asserts each did real work, then re-checks the identities.
    function test_EveryPolHandlerActionDoesRealWork() public {
        handler.addPol(5_000e18, 10 ether);
        assertGt(handler.ghostPolVuxPaid(), 0, "addPol paid the pool");

        handler.tradeWethForVux(1 ether);
        assertGt(handler.ghostFeesChargedWeth(), 0, "a WETH-denominated fee was charged");

        handler.tradeVuxForWeth(500e18);
        assertGt(handler.ghostFeesChargedVux(), 0, "and a VUX-denominated one");

        handler.buyVuxForPolNow(0.5 ether);

        uint256 supplyBefore = vux.totalSupply();
        handler.harvestPolNow();
        assertGt(handler.ghostVyrfVuxBurned(), 0, "harvest burned VUX fee yield");
        assertGt(handler.ghostVyrfWethToHard(), 0, "and accreted WETH fee yield to Hard");
        assertEq(supplyBefore - vux.totalSupply(), handler.ghostVyrfVuxBurned(), "S fell by exactly the burn");

        uint128 liquidityBefore = handler.polLiquidity();
        handler.decreasePolSome(1);
        assertLt(uint256(handler.polLiquidity()), uint256(liquidityBefore), "decreasePol removed liquidity");

        // Sprint-4 actions still fire through the inherited handler.
        handler.fundTreasuryInventory(300 ether);
        handler.settle(0);
        handler.admit(0, 1_000 ether);
        handler.passTime(2 days);
        handler.deploy(0, 100 ether);
        handler.returnWithProfit(0, 150 ether);
        handler.allocate(0, treasury.realizedRevenue(address(weth)));
        handler.redeemSome(0);

        invariant_BackingIsAttributedIncludingTheVyrfLeg();
        invariant_SupplyIsAttributedIncludingTheVyrfBurn();
        invariant_TokensOwedIsFeesOnly();
        invariant_VyrfClassifiedAmountsNeverExceedFeesCharged();
        invariant_RevenueStillTracesOnlyToStrategyFlows();
        invariant_PolBasisNeverExceedsWhatWasPaidIn();
    }
}
