# Event-Completeness Audit — FR-14.1–14.4 → emit sites

**Sprint:** 6 (Truth Surfaces) · **Task:** 6.3
**Subject tree:** branch `sprint-6`, baseline `92f8762111cd89c4cbdd4bcb11d06bf368f29377`
**Method:** every FR-14 observable traced to a declared event and a live emit site; signature
conformance and burn-cause pairing asserted mechanically, not by reading source.

**Mechanical companions**

| Claim | Test |
|---|---|
| Every accepted signature has an emit site in the compiled image | `test/events/EventSchemaConformance.t.sol` |
| Every supply change joins to exactly one cause | `test/events/BurnCausePairing.t.sol` |

Signatures below are the canonical forms extracted from the compiled artifacts
(`forge inspect <contract> events`), not transcribed by hand.

---

## 1. FR-14.1 — per-settlement observability

> "Per settlement, observably distinguish: outgoing epoch/King and incoming King; exact paid price
> and all three routed amounts; `B_pre`, `S_pre`, exact `D_R`, `Qraw`, `Qsafe`, actual `Qmint`;
> bootstrap-vs-ordinary; Strategic contributed principal received; VUX supply changes and their
> cause" (prd.md:L531)

One event carries the whole record: `Settled(uint64,address,address,bool,uint256×12)`
— declared `src/Rig.sol:182`, emitted `src/Rig.sol:426` (sole emit site).

| Observable | Field | Status |
|---|---|---|
| outgoing epoch | `epochId` (indexed) | ✓ |
| outgoing King | `outgoingKing` (indexed) | ✓ |
| incoming King | `newKing` (indexed) | ✓ |
| exact paid price | `price` | ✓ |
| King leg | `kingLeg` | ✓ |
| Strategic leg | `strategicLeg` | ✓ |
| Hard leg | `reserveLeg` | ✓ |
| `B_pre` / `S_pre` | `bPre`, `sPre` | ✓ |
| exact `D_R` (measured) | `dR` | ✓ |
| `Qraw` / `Qsafe` / `Qmint` | `qRaw`, `qSafe`, `qMint` | ✓ |
| bootstrap vs ordinary | `bootstrap` | ✓ |
| Strategic contributed principal received | `strategicLeg` — see finding **F-1** | ✓ (derived) |
| supply change | ERC-20 `Transfer(0x0 → outgoingKing, qMint)` | ✓ |
| its cause | join to `Settled` in the same tx | ✓ (`BurnCausePairing.t.sol`) |

`D_need = ceil(qRaw × bPre / sPre)` is exactly derivable from emitted fields, so the adaptive
routing decision is reconstructable without contract calls (sdd.md:L488).

**Redemption** — `Redeemed(address,address,uint256,uint256,uint256,uint256)`, declared
`src/HardReserve.sol:70`, emitted `src/HardReserve.sol:172`. Carries `bPre`/`sPre`, so `payout`
is re-derivable from the log alone.

**Constructor-only** — `PreGenesisWethSanitized(uint256)` (`src/HardReserve.sol:115`) distinguishes
attacker donations from founder capital. Its topic is present in the creation image and **absent**
from runtime — asserted, not assumed.

---

## 2. FR-14.2 — Strategic / POL accounting at product-semantic level

All declared `src/StrategicTreasury.sol:332-364` under the comment "accepted schema, reproduced
exactly" (`src/StrategicTreasury.sol:329`).

| Observable (prd.md:L532) | Event | Emit sites |
|---|---|---|
| contributed principal | *see* **F-1** | — |
| returned principal | `StrategicInflow(class=2,…)` | `:676`, `:961`, `:962`, `:1147` |
| realized fee/revenue by denomination | `StrategicInflow(class=3\|4,…)` | `:621`, `:677`, `:1148`, `:1226`, `:1230` |
| VUX burned | `VuxRevenueBurned`, `VyrfHarvest.vuxFeesBurned` | `:783`, `:1235` |
| WETH sent to Hard | `StrategicOutflow(kind=2,…)`, `VyrfHarvest.wethFeesToHard` | `:758`, `:1232`, `:1235` |
| general-waterfall amounts | `RevenueAllocated` (four legs) | `:768` |

Supporting records with live emit sites: `PolPositionChanged` (`:960`, `:1168`),
`VuxPurchasedForPol` (`:990`), `ReturnedFromStrategy` (`:1146`), `YieldHarvested` (`:622`),
`UnitsRedeemed` (`:674`), `StrategyLossRealized` (`:678`, `:698`), `SignalerProgramFunded` (`:892`),
`OpsRecipientSet` (`:790`), `StrategyRemoved` (`:510`).

---

## 3. FR-14.3 — LSG observability

| Observable (prd.md:L533) | Event | Emit site |
|---|---|---|
| activation state | `LSGActivated` / `LSGDeactivated` | `:802`, `:811` |
| admitted Strategy identity | `StrategyAdmitted(strategy, asset, cap, mode, maturesAt)` | `:497` |
| bounded allocation signal/result | `SignalConsumed(allocationId, totalDeployed, strategies, amounts)` | `:868` |
| responsible authority | inherited `RoleGranted` / `RoleRevoked` — **F-4** | OZ AccessControl |

---

## 4. FR-14.4 — analytics report list

> Ten items, "and Strategic NAV shall not be labeled backing" (prd.md:L534)

| Report item | Reconstruction source |
|---|---|
| genesis POL inventory | genesis `Transfer(0x0 → creator, GENESIS_POL_SUPPLY)` |
| current total supply `S` | Σ signed `Transfer` to/from `0x0` |
| cumulative raw opportunity | Σ `Settled.qRaw` |
| completed mints | Σ `Settled.qMint` |
| VUX burns by cause | burn-cause join (§5) |
| redemption burns | `Redeemed.q` |
| Hard WETH `B` and `B/S` | Σ `Settled.dR` + `VyrfHarvest.wethFeesToHard` + `StrategicOutflow(kind=2)` − `Redeemed.payout`; `B/S` from `B` and `S` |
| Strategic contributed principal | Σ `Settled.strategicLeg` (**F-1**) |
| realized revenue | `StrategicInflow(class=3\|4)` / `RevenueAllocated` |
| disclosed Strategic NAV | **not event-derivable — F-3** |

---

## 5. Burn-cause pairing (sdd.md:L544)

`supply_change.cause` domain: `genesis | settlement_mint | redemption_burn | vyrf_burn |
other_authorized_burn` (sdd.md:L576-L577).

| Cause | Supply-change record | Joined cause event | Test |
|---|---|---|---|
| `genesis` | `Transfer(0x0 → _)` in the token's deployment tx | *none, and none possible* | `test_GenesisMintsAreIdentifiedByTheDeploymentTransaction` |
| `settlement_mint` | `Transfer(0x0 → outgoingKing)` | `Settled.qMint` | `test_SettlementMintPairsWithSettled` |
| `redemption_burn` | `Transfer(holder → 0x0)` | `Redeemed.q` | `test_RedemptionBurnPairsWithRedeemed` |
| `vyrf_burn` | `Transfer(treasury → 0x0)` | `VyrfHarvest.vuxFeesBurned` | `test_VyrfBurnPairsWithVyrfHarvest` |
| `other_authorized_burn` (revenue) | `Transfer(treasury → 0x0)` | `VuxRevenueBurned.amount` | `test_RevenueBurnPairsWithVuxRevenueBurned` |
| `other_authorized_burn` (holder) | `Transfer(holder → 0x0)` | *none* — **F-2** | `test_HolderSelfBurnCarriesNoCauseEventAndCollidesWithNone` |

**The no-ambiguity property** — that no transaction ever presents two competing burn causes — is
asserted per-transaction across a scripted scenario exercising all three protocol burn paths plus a
settlement and a holder burn (`test_NoTransactionEverPresentsTwoCompetingBurnCauses`). The three
protocol burn paths are separate external functions on separate contracts with no multicall surface,
so no single transaction can emit two of them.

---

## 6. Findings

### F-1 — `ContributedPrincipal` has no `StrategicInflow` emission (by design; **no gap**)

`StrategicInflow.class` documents `1 = ContributedPrincipal`, but the constant is not declared and
the class is never emitted (`src/StrategicTreasury.sol:122-124` — the enumeration starts at 2). This
is correct: the settlement residual arrives as a bare WETH transfer with no callback, so "the
treasury is never invoked and cannot observe it. Its attribution lives in `Rig.Settled` +
`Rig.totalStrategicContributed`" (`src/StrategicTreasury.sol:115-117`, sdd.md:L138). The accepted ER
diagram derives the `strategic_flow` ContributedPrincipal row from the settlement, "absent when
zero" (sdd.md:L603), matching the Rig's skip-at-zero (`src/Rig.sol:345`).

**Indexer rule (Task 6.4):** write the `ContributedPrincipal` `strategic_flow` row from
`Settled.strategicLeg`, not from a `StrategicInflow` log; emit no row when the leg is zero.

### F-2 — the permissionless holder burn carries no cause event (**resolvable; rule required**)

`VUX.burn(uint256)` is permissionless (`src/VUX.sol:115`) — any holder may burn their own VUX. Such
a burn emits only `Transfer(holder → 0x0)`, with no protocol cause event, because no protocol
contract caused it. sdd.md:L544's phrasing ("each burn site emits exactly one cause event in the
same transaction") is exact for the three *protocol* burn paths and does not describe this one.

This is **not ambiguity**: zero cause events is a distinguishable signature that collides with none
of the four protocol causes, so attribution by exclusion is deterministic. Asserted in
`test_HolderSelfBurnCarriesNoCauseEventAndCollidesWithNone`.

**Indexer rule (Task 6.4):** a `Transfer → 0x0` with no cause event in its transaction books as
`other_authorized_burn`. It must not be silently dropped — dropping it would break the `S`
reconstruction identity.

### F-3 — `strategic_nav_disclosed` is not reconstructable from events (**by design; UI obligation**)

Class 5 (`UnrealizedMark`) "is never an event at all, because a mark is not a transfer and has no
cell here (INV-30)" (`src/StrategicTreasury.sol:119-121`). Disclosed Strategic NAV therefore cannot
be derived from chain events; it requires external valuation inputs.

**Consequence for Tasks 6.4/6.6:** the NAV column is named `strategic_nav_disclosed` (FR-14.4,
sdd.md:L609) and must be presented as *disclosed*, never as derived protocol truth and never labeled
backing. Where its valuation inputs are stale or unavailable, the truthful surface is the explicit
data-unavailable state (Task 6.8), not a carried-forward number.

### F-4 — role records are inherited, not declared (**no gap**)

FR-14.3's "responsible authority" is carried by pinned OpenZeppelin `AccessControl`
`RoleGranted`/`RoleRevoked`/`RoleAdminChanged`, which sdd.md §3.2 does not restate because they are
not VUX-declared. Emit sites confirmed present in the treasury runtime
(`test_TreasuryEmitsTheInheritedRoleRecords`). Per-action authority is additionally observable as
the transaction sender.

### F-5 — a cause event does not imply a supply change (**rule required**)

`burnVuxRevenue()` emits `VuxRevenueBurned(0)` when no revenue is credited
(`src/StrategicTreasury.sol:777-783` — the emit sits outside the `if`), and `VyrfHarvest` is emitted
with a zero VUX leg whenever only WETH fees accrued (`src/StrategicTreasury.sol:1225-1235`).

**Indexer rule (Task 6.4):** key the existence of a supply change off the `Transfer`, and its amount
off the paired cause event. Do not create a `supply_change` row from a cause event alone. Asserted in
`test_AZeroCauseEventPairsWithNoSupplyChange`.

### F-6 — `SignalConsumed` placement differs from the SDD's section heading (**cosmetic**)

sdd.md lists `SignalConsumed` under "LSGSignals module (P1 implementation)" (sdd.md:L531-L536), but
it is declared and emitted on `StrategicTreasury` (`:364`, `:868`). This is correct — the treasury
is what consumes a signal, in `deployMarginalBySignal` — and the signature is unchanged. Recorded so
a reviewer comparing the SDD's section layout to the tree does not read it as a missing event.

---

## 7. Verdict

Every FR-14.1–14.4 observable maps to a declared event with a live emit site, or to an explicitly
recorded derivation (F-1) or non-derivation (F-3). No event was added, renamed, or retyped by this
task; the audit is a read of the Sprint 2–5 tree plus mechanical assertions over it.

Two indexer rules (F-2, F-5) and one derivation rule (F-1) are obligations that Task 6.4 must
implement, and one presentation obligation (F-3) carries to Tasks 6.6/6.8.
