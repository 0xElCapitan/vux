// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

// carries: sprint.md Sprint 4 AC-1 (constructor re-verification, creator-granted
//          roles, no setPool/initializer), AC-7 (role topology), NFR-SEC-7,
//          sdd.md:L140, L718-L725

import {StrategicTreasury} from "../../src/StrategicTreasury.sol";
import {MockErc20} from "../mocks/MockErc20.sol";
import {MockPool} from "../mocks/MockPool.sol";
import {IVuxPoolDeployer} from "./PoolDeployerHarness.sol";
import {TreasuryFixture} from "./TreasuryFixture.sol";

/// @title TreasuryConstructorTest — identity fixed once, against the pool itself.
/// @notice The treasury is the protocol's only privileged surface, and the
///         moment it is most dangerous is the one moment its wiring is writable:
///         construction. After that there is no `setPool`, no initializer, and
///         no upgrade, so everything asserted here is asserted forever.
contract TreasuryConstructorTest is TreasuryFixture {
    function setUp() public {
        _deploySystem();
    }

    // --- the verified identity (real pool, no mocks) --------------------------

    function test_ImmutablesBindTheRealVerifiedTopology() public view {
        assertEq(address(treasury.weth()), address(weth), "weth");
        assertEq(address(treasury.vux()), address(vux), "vux");
        assertEq(treasury.hardReserve(), address(reserve), "hard reserve");
        assertEq(treasury.poolDeployer(), address(poolDeployer), "pool deployer");
        assertEq(treasury.pool(), pool, "pool");
        assertEq(uint256(treasury.feeTier()), uint256(FIXTURE_FEE), "fee tier");

        (address t0, address t1) = _sorted(address(vux), address(weth));
        assertEq(treasury.token0(), t0, "token0 is the canonical sort");
        assertEq(treasury.token1(), t1, "token1 is the canonical sort");
    }

    /// @dev The pool the treasury bound to is the one the CREATE2 derivation
    ///      predicts — checked independently of `VuxPoolDeployer`'s own record.
    function test_TheBoundPoolIsTheIndependentlyDerivedCanonicalAddress() public view {
        (address t0, address t1) = _sorted(address(vux), address(weth));
        assertEq(
            treasury.pool(),
            _computePoolAddress(address(poolDeployer), t0, t1, FIXTURE_FEE),
            "treasury.POOL() == create2(deployer, keccak(token0,token1,fee), INIT_CODE_HASH)"
        );
    }

    /// @dev Bounds are *derived* from the verified pool's own `tickSpacing()`,
    ///      not passed in — so no argument exists that could place the protocol's
    ///      future position on bounds the pool would reject.
    function test_TickBoundsAreDerivedFromThePoolAndAligned() public view {
        int24 spacing = FIXTURE_TICK_SPACING;
        assertEq(int256(treasury.tickLower()), int256((-887272 / spacing) * spacing), "tickLower");
        assertEq(int256(treasury.tickUpper()), int256((887272 / spacing) * spacing), "tickUpper");

        assertEq(int256(treasury.tickLower() % spacing), int256(0), "tickLower is spacing-aligned");
        assertEq(int256(treasury.tickUpper() % spacing), int256(0), "tickUpper is spacing-aligned");
        assertTrue(treasury.tickLower() >= -887272, "tickLower inside the tick domain");
        assertTrue(treasury.tickUpper() <= 887272, "tickUpper inside the tick domain");
    }

    /// @dev Derived, not hard-coded: a different spacing yields different bounds.
    function test_TickBoundsFollowADifferentSpacing() public {
        (address t0, address t1) = _sorted(address(vux), address(weth));
        bytes32 salt = keccak256("alternate.spacing");
        IVuxPoolDeployer deployer = _deployPoolDeployer(keccak256(abi.encode(address(this), salt)));
        address altPool = deployer.deployCanonicalPool(salt, t0, t1, 500, 10);

        StrategicTreasury alt = new StrategicTreasury(
            address(weth), address(vux), address(reserve), address(deployer), altPool, 500
        );

        assertEq(int256(alt.tickLower()), int256((-887272 / int24(10)) * 10), "tickLower follows spacing 10");
        assertEq(int256(alt.tickUpper()), int256((887272 / int24(10)) * 10), "tickUpper follows spacing 10");
        assertNotEq(uint256(uint24(alt.tickLower())), uint256(uint24(treasury.tickLower())), "bounds actually differ");
    }

    // --- roles (AC-1, AC-7) ---------------------------------------------------

    /// @dev Both roles go to `msg.sender` — the creator, structurally
    ///      `GenesisDeployer`. There is no `genesisOperator` argument, so the
    ///      external genesis caller can never receive authority (sdd.md:L140).
    function test_BothRolesAreGrantedToTheCreatorAndNobodyElse() public view {
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), address(this)), "creator holds admin");
        assertTrue(treasury.hasRole(treasury.OPERATOR_ROLE(), address(this)), "creator holds operator");

        assertFalse(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), NON_OPERATOR), "outsider holds no admin");
        assertFalse(treasury.hasRole(treasury.OPERATOR_ROLE(), NON_OPERATOR), "outsider holds no operator");
        assertFalse(treasury.hasRole(treasury.OPERATOR_ROLE(), address(rig)), "the Rig holds no role");
        assertFalse(treasury.hasRole(treasury.OPERATOR_ROLE(), address(reserve)), "the Reserve holds no role");
        assertFalse(treasury.hasRole(treasury.OPERATOR_ROLE(), address(vux)), "the token holds no role");
        assertFalse(treasury.hasRole(treasury.OPERATOR_ROLE(), address(0)), "the zero address holds no role");
    }

    /// @dev Role rotation is the Safe-held path the SDD keeps (`grantRole` /
    ///      `revokeRole` under `DEFAULT_ADMIN_ROLE`, sdd.md:L726-L727) — present,
    ///      admin-gated, and reaching nothing else.
    function test_RoleRotationIsAdminGated() public {
        // Read the role id first: `prank` applies to the next call, and an
        // argument that is itself an external call would consume it.
        bytes32 operator = treasury.OPERATOR_ROLE();

        vm.prank(NON_OPERATOR);
        vm.expectPartialRevert(bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")));
        treasury.grantRole(operator, NON_OPERATOR);

        treasury.grantRole(operator, ALICE);
        assertTrue(treasury.hasRole(operator, ALICE), "admin can rotate the operator role");

        treasury.revokeRole(operator, ALICE);
        assertFalse(treasury.hasRole(operator, ALICE), "and can revoke it");
    }

    /// @dev NFR-SEC-7 / INV-33: operator roles exist on the treasury ONLY. The
    ///      monetary core has no role registry at all — a claim about the other
    ///      three contracts, asserted from the treasury's own test because that
    ///      is where the authority lives.
    function test_NoRoleSurfaceExistsOnTheMonetaryCore() public view {
        address[3] memory core = [address(vux), address(reserve), address(rig)];
        for (uint256 i = 0; i < core.length; i++) {
            (bool ok,) = core[i].staticcall(
                abi.encodeWithSignature("hasRole(bytes32,address)", treasury.OPERATOR_ROLE(), address(this))
            );
            assertFalse(ok, "no core contract answers hasRole");
        }
    }

    // --- rejections ------------------------------------------------------------

    function test_RejectsAPoolDeployedByADifferentDeployer() public {
        (address t0, address t1) = _sorted(address(vux), address(weth));
        bytes32 salt = keccak256("other.deployer");
        IVuxPoolDeployer other = _deployPoolDeployer(keccak256(abi.encode(address(this), salt)));
        address otherPool = other.deployCanonicalPool(salt, t0, t1, FIXTURE_FEE, FIXTURE_TICK_SPACING);

        vm.expectPartialRevert(StrategicTreasury.PoolFactoryMismatch.selector);
        new StrategicTreasury(
            address(weth), address(vux), address(reserve), address(poolDeployer), otherPool, FIXTURE_FEE
        );
    }

    function test_RejectsAPoolOfTheWrongPair() public {
        MockErc20 stranger = new MockErc20("Stranger", "STR");
        (address t0, address t1) = _sorted(address(stranger), address(weth));
        bytes32 salt = keccak256("wrong.pair");
        IVuxPoolDeployer deployer = _deployPoolDeployer(keccak256(abi.encode(address(this), salt)));
        address wrongPool = deployer.deployCanonicalPool(salt, t0, t1, FIXTURE_FEE, FIXTURE_TICK_SPACING);

        vm.expectPartialRevert(StrategicTreasury.PoolTokensMismatch.selector);
        new StrategicTreasury(
            address(weth), address(vux), address(reserve), address(deployer), wrongPool, FIXTURE_FEE
        );
    }

    function test_RejectsAFeeTierThePoolDoesNotHave() public {
        vm.expectPartialRevert(StrategicTreasury.PoolFeeMismatch.selector);
        new StrategicTreasury(
            address(weth), address(vux), address(reserve), address(poolDeployer), pool, FIXTURE_FEE + 1
        );
    }

    /// @dev Unreachable with a real `VuxPoolDeployer` (its `owner` is a constant
    ///      zero), which is precisely why the guard is exercised against a mock:
    ///      an unreachable guard and a broken one look the same.
    function test_RejectsALivingProtocolFeeAuthority() public {
        (address t0, address t1) = _sorted(address(vux), address(weth));
        MockPool fake = new MockPool(address(0), t0, t1, FIXTURE_FEE, FIXTURE_TICK_SPACING);
        fake.setOwner(ALICE);
        // The mock plays both roles, so `pool.factory()` can match the deployer
        // under test while that deployer still reports a living owner.
        MockPool self = new MockPool(address(0), t0, t1, FIXTURE_FEE, FIXTURE_TICK_SPACING);
        self.setOwner(ALICE);
        MockPool poolOf = new MockPool(address(self), t0, t1, FIXTURE_FEE, FIXTURE_TICK_SPACING);

        vm.expectPartialRevert(StrategicTreasury.PoolOwnerNotDead.selector);
        new StrategicTreasury(
            address(weth), address(vux), address(reserve), address(self), address(poolOf), FIXTURE_FEE
        );
    }

    /// @dev Also unreachable with a real pool — `deployCanonicalPool` rejects an
    ///      out-of-domain spacing before a pool exists.
    function test_RejectsAnOutOfDomainTickSpacing() public {
        (address t0, address t1) = _sorted(address(vux), address(weth));
        MockPool deployerMock = new MockPool(address(0), t0, t1, FIXTURE_FEE, 0);
        MockPool poolMock = new MockPool(address(deployerMock), t0, t1, FIXTURE_FEE, 0);

        vm.expectPartialRevert(StrategicTreasury.PoolTickSpacingInvalid.selector);
        new StrategicTreasury(
            address(weth), address(vux), address(reserve), address(deployerMock), address(poolMock), FIXTURE_FEE
        );
    }

    function test_RejectsZeroAddresses() public {
        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        new StrategicTreasury(address(0), address(vux), address(reserve), address(poolDeployer), pool, FIXTURE_FEE);

        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        new StrategicTreasury(address(weth), address(0), address(reserve), address(poolDeployer), pool, FIXTURE_FEE);

        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        new StrategicTreasury(address(weth), address(vux), address(0), address(poolDeployer), pool, FIXTURE_FEE);

        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        new StrategicTreasury(address(weth), address(vux), address(reserve), address(0), pool, FIXTURE_FEE);

        vm.expectRevert(StrategicTreasury.ZeroAddress.selector);
        new StrategicTreasury(
            address(weth), address(vux), address(reserve), address(poolDeployer), address(0), FIXTURE_FEE
        );
    }

    // --- launch state ----------------------------------------------------------

    /// @dev Everything the treasury owns starts empty. Nothing is admitted,
    ///      nothing is credited, no recipient is set, and LSG is inactive.
    function test_LaunchStateIsEmpty() public view {
        assertEq(treasury.lsgModule(), address(0), "LSG inactive at launch (FR-13)");
        assertEq(treasury.opsRecipient(), address(0), "no ops recipient at launch");
        assertEq(treasury.realizedRevenue(address(weth)), 0, "no revenue credited at launch");
        assertEq(treasury.signalerBudget(address(weth)), 0, "no earmark at launch");
        assertEq(uint256(treasury.allocationCount()), 0, "no allocations at launch");
        assertEq(uint256(treasury.ADMISSION_DELAY()), 24 hours, "ADMISSION_DELAY = 24 hours");
    }
}
