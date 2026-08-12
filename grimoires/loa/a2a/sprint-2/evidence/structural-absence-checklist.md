# Structural-Absence Review Checklist — `HardReserve.sol` and `VUX.sol`

**Sprint:** cycle-002 / sprint-2
**Authority:** prd.md FR-7.2 / FR-7.3 (L416–L417), INV-14 (L599), INV-5 (L585),
sdd.md §1.4 (L90, L97, L133), §5.2.1, §5.2.3
**Date:** 2026-08-11

Structural absence is a claim that a capability *does not exist*, which cannot
be demonstrated by exercising it. Each row below therefore names the mechanical
artifact that would fail if the capability existed — not a reviewer's reading of
the source. Where a row can only be established by inspection, it says so.

Reproduce everything here with:

```bash
forge build && forge test && bash tools/provenance/inspect-runtime-surface.sh
```

---

## 1. `HardReserve.sol` — FR-7.2 prohibited authorities

The compiled external surface is exactly six functions, one of which is
state-changing:

```
redeem(uint256,address)    <- the only mutator
backing()                  view
previewRedeem(uint256)     view
weth()                     view
vux()                      view
S_MIN()                    view
```

| # | Must not exist | Mechanical proof |
|---|---|---|
| 1 | owner / ownership transfer | exact-ABI assertion + named negative — `HardReserveSurface.t.sol:231` (`test_ExternalSurfaceIsExactlyRedeemPlusViews`), `:250` (`test_NoProhibitedAuthoritySurfaceExists`); `inspect-runtime-surface.sh` surface check |
| 2 | roles / access control | same two assertions (`grantRole` in the forbidden list) |
| 3 | pause / unpause | same |
| 4 | upgrade path (proxy, `upgradeTo`, initializer) | same, **plus** no `DELEGATECALL` in the deployed runtime — `HardReserveSurface.t.sol:199` (`test_RuntimeContainsNoUpgradeDestructionOrDeploymentOpcode`); an upgrade path cannot exist without one |
| 5 | arbitrary call / `execute` | exact-ABI assertion; the runtime's only two `CALL` sites are the burn and the payout (opcode census: `call=2`) |
| 6 | ERC-20 approval of any token | exact-ABI assertion (`approve` in the forbidden list) — the Reserve grants no allowance to anyone, for any token, ever |
| 7 | sweep / rescue / withdraw | exact-ABI assertion (all three in the forbidden list) |
| 8 | successor / migration | exact-ABI assertion (`migrate`), **plus** no `CREATE`/`CREATE2` in the deployed runtime — it cannot deploy a successor |
| 9 | emergency principal withdrawal | no such function exists in the exact set; there is no privileged caller for one to be gated on |
| 10 | discretionary recovery | as above |
| 11 | payable runtime path | ABI `stateMutability` scan finds zero payable entries (`inspect-runtime-surface.sh`); behavioural test `HardReserveSurface.t.sol:277` (`test_NoEtherCanBeSentToTheReserve`) |
| 12 | `receive` hook | ABI type scan finds no `receive`; bare value transfer reverts (same test) |
| 13 | `fallback` | ABI type scan finds no `fallback`; unknown selector reverts (same test) |
| 14 | `selfdestruct` | no `SELFDESTRUCT` opcode in the deployed runtime (opcode census) |
| 15 | generic deposit function | exact-ABI assertion; accretion is a plain ERC-20 transfer in, verified by `HardReserveRedemption.t.sol:45` (`test_BackingIsThePhysicalWethBalanceWithNoDepositFunction`) |
| 16 | accounting shadow balance / NAV cell | **inspection**: the contract declares no mutable storage other than the inherited `ReentrancyGuard` status slot. `backing()` returns `weth.balanceOf(address(this))` directly (`src/HardReserve.sol:177`), so there is no cell to desynchronize from physical holdings (INV-10) |
| 17 | any path that moves the `S_MIN` seed | no token-moving entry point exists — `HardReserveSurface.t.sol:300` (`test_ReserveHoldsTheSeedAndHasNoWayToMoveIt`) |

### 1a. The constructor capability (FR-7.2 boundary case)

The constructor *does* transfer WETH out. That is the one deliberate exception,
and the claim is that it does not survive deployment.

| Claim | Mechanical proof |
|---|---|
| The sanitization path is in the init code | `PreGenesisWethSanitized` topic present in `.bytecode.object` — asserted as a **positive control**, so the absence result below cannot pass by the search being broken (`HardReserveSurface.t.sol:181`; `inspect-runtime-surface.sh`) |
| It is absent from the deployed runtime | same topic absent from `.deployedBytecode.object` — both implementations agree |
| The absence scan is not vacuous | `test_MetadataStrippingRemovesATailAndNotTheProgram` (`:219`) asserts the metadata stripper removed a tail and not the program; the opcode walk is validated against opcodes known to be present (`CALL`, `STATICCALL`) |
| It behaves correctly while it exists | `testFuzz_ConstructorSanitizesAnyPreExistingWeth` (fuzzed to `type(uint128).max`), `test_SanitizationEmitsTheExactAmount`, `test_CleanDeploymentEmitsNoSanitizationEvent`, `test_ConstructionAbortsIfTheReserveCannotBeBornEmpty`, `test_PrefundingCannotDistortTheGenesisBackingTarget` |

Recorded opcode census of the deployed runtime (3,252 bytes; 3,199 after
stripping the 53-byte metadata tail):

```
body=3199 create=0 callcode=0 delegatecall=0 create2=0 selfdestruct=0 call=2 staticcall=5
```

## 2. `VUX.sol` — INV-5 and the FR-7.4 burn boundary

| # | Must not exist | Mechanical proof |
|---|---|---|
| 1 | general `burnFrom` (allowance-gated burn) | `VuxToken.t.sol:248` (`test_NoBurnFromSignatureIsDispatchable`) over the dispatcher table, with a positive control; `:264` (`test_NoBurnFromEntryPointExistsAtRuntime`) proves the selector is not routed; `inspect-runtime-surface.sh` burn-family check |
| 2 | discretionary mint (treasury, governance, recovery, migration, recapitalization) | exact-ABI assertion `VuxToken.t.sol:278`: `mint` is the only mint entry, and `testFuzz_MintRevertsForEveryCallerExceptRig` gates it |
| 3 | `setRig` / `setReserve` or any authority repointing | `rig` and `reserve` are `immutable`; `test_NoOwnershipUpgradeOrAuthorityRepointingSurface` (`:296`) asserts no setter is dispatchable |
| 4 | owner / roles / pause / upgrade | same named-negative assertion |
| 5 | `ERC20Votes` / checkpoint / hook surface | exact-ABI assertion — the 20-signature set contains no `delegate`, `getVotes`, or `checkpoints` entry (sdd.md:L99) |
| 6 | genesis allocation to any third address | `test_GenesisCreditsNoAddressBeyondTheAcceptedTwo` (`:92`) enumerates the constructor's **complete** log set: exactly two mints, exactly two recipients, exactly the two accepted amounts |

## 3. Items settled by inspection rather than by test

Recorded explicitly so a reviewer knows what a green suite does *not* cover.

| Item | Why inspection | Where |
|---|---|---|
| No inline assembly in VUX-authored source | A test cannot observe the absence of a language construct; the source is 3 files and the property is directly readable (sdd.md:L274 gas posture) | `src/VUX.sol`, `src/HardReserve.sol`, `src/interfaces/IVUX.sol` — none contains an `assembly` block |
| The Reserve never passes any address but `msg.sender` to `burnForRedemption` | The mechanical tests establish the *consequence* (a caller with no balance cannot redeem; another holder's balance never moves), which is what protects holders. The literal argument is a one-line read | `src/HardReserve.sol:169` |
| No accounting cell exists | Absence of storage declarations; see row 16 above | `src/HardReserve.sol` |
| The token's event schema matches sdd.md §3.2 | §3.2 assigns no event to `VUX`; ERC-20 `Transfer` plus the causing contract's event carries supply attribution (UC-6). Verified by reading §3.2 against the contract | sdd.md:L474-L498 |

## 4. Result

No FR-7.2 prohibited authority is present on the deployed Hard Reserve; no
discretionary mint or generalized burn is present on the token; the single
transfer-out capability in the Reserve's constructor is proven absent from the
deployed runtime by two independent implementations. No row required a waiver.
