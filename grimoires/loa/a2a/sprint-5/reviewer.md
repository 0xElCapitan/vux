# Sprint 5 — Strategic Treasury II: POL, Callback Authentication & VYRF

**Node:** `/implement sprint-5`
**Worktree / branch:** `C:\Users\0x007\vux-sprint-5`, `sprint-5`
**Baseline:** `cf0108109e428da0483b8470726f9e48ee740777` (`master == origin/master == sprint-5`,
clean tree, zero commits ahead at node entry)
**Subject fingerprint:** `37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a` (12 files)
**Manifest:** [`evidence/subject-manifest.md`](evidence/subject-manifest.md) — derived from git,
proven exhaustive in both directions (`A ∪ B == R`, `A ∩ B == ∅`, 12/12 present on disk)
**Scope slice:** [`sprint-5-scope.md`](sprint-5-scope.md) (`829f3437…834a7e`)

---

## Executive summary

The Strategic Treasury's POL sleeve is complete against the already-vendored canonical v3 pool.
The treasury now owns a full-range position **directly on the pool** — no periphery, no position
NFT, and no standing approval of any token at any time — mints and increases it against committed
callback maxima, decreases it fee-first, buys VUX for it from existing supply on the canonical
venue, and realizes the frozen VYRF outcome permissionlessly: VUX fee yield burns, WETH fee yield
goes one-way to the Hard Reserve, returned LP principal stays Strategic principal.

The two things this sprint had to make *mechanically true* rather than merely intended are both
tested as facts:

- **Fee/principal separation is ordering, not accounting.** Pinned v3 `collect` cannot tell fees
  from principal once both sit in `tokensOwed`, so `decreasePol` collects fees *before* burning
  liquidity and sweeps the resulting principal atomically in the same call. The invariant
  `tokensOwed ≤ (fees charged − fees collected)` is checked after every action of a 16,384-call
  randomized sequence, against a fee bound computed from the suite's own swap inputs and the
  pinned fee tier — never from anything the pool reported.
- **Being the canonical pool is not authorization.** A callback is authorized only when the
  caller is the exact immutable pool *and* a matching one-shot context is active, consumed before
  payment. All nine accepted rejection classes are proven, and the two that a well-behaved pool
  cannot produce — a duplicate second callback and an unconsumed authorization — are exercised for
  real from the treasury's own `pool` address, as an exact differential against the same operation
  succeeding with one callback.

Everything is additive: no Sprint-4 function body changed, no accepted finding reopened, no
authority or P1 boundary crossed, and `foundry.toml` is untouched — so the frozen `=0.7.6` unit
never had a new opportunity to drift, and `POOL_INIT_CODE_HASH` reproduces byte-identical.

**Result:** 349 tests pass (baseline 298 → +51), 0 failures, under both the default and the
`[profile.ci]` (10,000 fuzz runs / 256×64 invariant) profiles. All provenance gates pass. The
end-to-end POL/VYRF scenario runs green against a live anvil node over JSON-RPC; the one thing an
RH-chain fork would add is named explicitly below rather than simulated away.

---

## AC Verification

Every criterion is quoted verbatim from [`sprint-5-scope.md`](sprint-5-scope.md).

### AC-1

> Callback negative suite green (sdd.md:L858): forged caller; canonical pool with no active context; wrong callback type; wrong token direction; amount above committed maximum; nested/reentrant attempt; nonempty data; **duplicate second callback under one armed operation reverts even from the canonical pool** (mock double-callback test); outer op with unconsumed authorization reverts (`CallbackNotConsumed`)

**✓ Met.** All nine classes, one test each, in
[`test/treasury/TreasuryCallbackAuth.t.sol`](../../../../test/treasury/TreasuryCallbackAuth.t.sol):

| # | class | test | rejection |
|---|---|---|---|
| 1 | forged caller | `test_1_…:79` | `CallbackUnauthorizedCaller` ([`src/StrategicTreasury.sol:321`](../../../../src/StrategicTreasury.sol)) |
| 2 | canonical pool, no active context | `test_2_…:97` | `CallbackContextMismatch` (:322) |
| 3 | wrong callback type | `test_3_…:114` | `CallbackContextMismatch` |
| 4 | wrong token direction | `test_4_…:134` | `CallbackDirectionMismatch` (:323) |
| 5 | amount above committed maximum | `test_5_…:151` | `CallbackAmountExceedsCommitment` (:324) |
| 6 | nested / reentrant attempt | `test_6_…:173` | `ReentrancyGuardReentrantCall` |
| 7 | nonempty data | `test_7_…:186` | `CallbackDataNotEmpty` (:325) |
| 8 | duplicate second callback, from the canonical pool | `test_8_…:207` | `CallbackContextMismatch` |
| 9 | unconsumed authorization | `test_9_…:241` | `CallbackNotConsumed` (:326) |

Class 2 is exercised from the **real** vendored pool address via `vm.prank(pool)`. Classes 3–9
need a pool that misbehaves on cue, so they run against
[`test/mocks/MockCallbackPool.sol`](../../../../test/mocks/MockCallbackPool.sol), whose address
*is* that treasury's immutable `pool` — so "the caller was the canonical pool" holds in every one
of them. Class 8 is an exact differential: the same operation with the same amounts is shown to
**succeed** with one callback (`:212-215`), and the only change before it reverts is the second
identical callback (`:219`). A control (`test_Control_…:63`) proves the rig can produce a callback
the treasury accepts, so no "reverts" assertion is passing for the wrong reason.

Validation order matches sdd.md:L256 exactly — caller, context type, direction, amount, data,
then consume, then pay ([`src/StrategicTreasury.sol:1031-1059`](../../../../src/StrategicTreasury.sol)
and `:1061-1078`).

### AC-2

> Zero standing approvals after every pool operation (asserted per-op)

**✓ Met**, on two independent legs.

- **Per-operation, on balances:** `_assertNoStandingApprovals`
  ([`test/treasury/PolFixture.sol`](../../../../test/treasury/PolFixture.sol) `_assertNoStandingApprovals`)
  checks both tokens against four spenders (pool, Reserve, Rig, swapper) and is called after
  `mintPolPosition`, `increasePol`, `decreasePol`, `buyVuxForPol`, and `harvestPol` — see
  `TreasuryCallbackAuth.t.sol:259` for the all-operations sweep and the five call sites in
  `TreasuryPol.t.sol`.
- **Structurally, on the artifact:** `PolConduct.t.sol:135` asserts the deployed runtime contains
  **no `approve(address,uint256)` call site at all**, so no allowance can exist to check. Payment
  is `safeTransfer` in both callbacks ([`src/StrategicTreasury.sol:1057-1058`, `:1077`](../../../../src/StrategicTreasury.sol)).

### AC-3

> VYRF ordering invariant: position `tokensOwed` outside a `decreasePol` execution consists of fees only (sdd.md:L142); principal sweeps atomically inside `decreasePol` against cost-basis cells

**✓ Met.** `invariant_TokensOwedIsFeesOnly`
([`test/treasury/PolInvariants.t.sol:134`](../../../../test/treasury/PolInvariants.t.sol)) asserts
`tokensOwed ≤ ghostFeesCharged − ghostFeesCollected` on both tokens after every action of the
randomized sequence. The bound is attributed, not measured: `ghostFeesCharged` comes from the
handler's own swap inputs and the pinned fee tier
([`PolInvariantHandler.sol` `_feeBound`](../../../../test/treasury/PolInvariantHandler.sol)),
never from `collect`. Principal is credited to the same cell by `burn` and is orders of magnitude
larger than any fee, so an unsweept principal credit breaks it on the next observation.

The atomic sweep is the implementation at
[`src/StrategicTreasury.sol:945-972`](../../../../src/StrategicTreasury.sol) — poke + collect +
classify fees, *then* `burn(liquidity)`, *then* `collect` the principal, *then* book against
`polVuxPrincipal`/`polWethPrincipal` (`:253`, `:255`) — and is observed directly by
`test_DecreasePolCollectsFeesFirstThenSweepsPrincipalAtomically`
([`TreasuryPol.t.sol:163`](../../../../test/treasury/TreasuryPol.t.sol)), which asserts
`tokensOwed == 0` on both tokens once the call returns (`:196-198`).

### AC-4

> End-to-end scenario: fee accrual → `harvestPol` → VUX fee burn observed with cause pairing, WETH fees land in `B`, returned principal books as principal (FR-11 acceptance, prd.md:L489-L490); the general-waterfall surface provably cannot receive POL fee yield

**✓ Met.** [`script/PolVyrfE2E.s.sol`](../../../../script/PolVyrfE2E.s.sol) runs the whole
lifecycle against a live anvil node and asserts all six required observables separately.
Recorded run (`forge script … --fork-url http://127.0.0.1:8545`, exit 0):

| observable | value |
|---|---|
| POL liquidity minted | `6708203932499369089234` |
| `polVuxPrincipal` / `polWethPrincipal` | `149999999999999999999981` / `299999999999999999636` |
| WETH fee charged (independent upper bound) | `120361083249749249` |
| VUX fee charged (independent upper bound) | `52959868188772507943` |
| `VyrfHarvest.vuxFeesBurned` | `52800988584206190418` |
| `VyrfHarvest.wethFeesToHard` | `120000000000000000` |
| VUX burned on the token, same tx (`Transfer→0x0`) | `52800988584206190418` — **equals the event leg** |
| `B` delta | `120000000000000000` — **equals the WETH leg** |
| principal returned (VUX / WETH) | `74973599505707896904780` / `150052819581424978293` |
| `tokensOwed` after the decrease | `0 / 0` |

The waterfall exclusion is proven arithmetically rather than procedurally, at
[`PolConduct.t.sol:41`](../../../../test/treasury/PolConduct.t.sol): after a harvest that
demonstrably moved real value into burn and into `B`, `realizedRevenue` is still zero and
`allocateRevenue(weth, …, 1, …)` reverts `RevenueExceedsRealized`. `harvestPol` writes that
accumulator nowhere ([`src/StrategicTreasury.sol:1219-1238`](../../../../src/StrategicTreasury.sol)),
which is what makes POL fee yield arithmetically unreachable from the distribution surface rather
than merely un-routed to it. The VUX leg cannot even be addressed to it (`VuxRevenueMustBurn`).

**Fork qualification (stated, not simulated away):** the SDD's fork row targets "an RH-chain
fork" (sdd.md:L862). No Robinhood Chain RPC endpoint exists in any accepted artifact — the
endpoint, like the canonical WETH address and the fee tier, is an R-14 deployment-time fact that
Sprints 7–8 record — so there is nothing to fork yet. The scenario therefore runs against a live
local anvil node (v1.5.0) over JSON-RPC. The single thing an RH-chain fork would add is the
behaviour of the **real** canonical WETH contract, which is exactly the YELLOW external dependency
(prd.md:L721) that Sprint 7's genesis rehearsal and Sprint 8's E2E are scheduled to exercise. That
is the precise residual gap.

### AC-5

> `buyVuxForPol`: `minVuxOut` + `sqrtPriceLimitX96` enforced; purchased VUX books as POL inventory principal; no path mints VUX for POL (INV-26 negative)

**✓ Met**, with one interpretation recorded as **J-1** below.

- `minVuxOut` is applied to the treasury's **own measured balance delta**, not to a pool return
  value ([`src/StrategicTreasury.sol:988-989`](../../../../src/StrategicTreasury.sol)); enforced
  in `test_BuyVuxForPolEnforcesMinVuxOut` ([`TreasuryPol.t.sol:265`](../../../../test/treasury/TreasuryPol.t.sol)).
- `sqrtPriceLimitX96` is passed through to the pool, which enforces it; a limit at the current
  price reverts `SPL` (`TreasuryPol.t.sol:281`).
- Purchased VUX is POL inventory, principal-classified and never revenue: `VuxPurchasedForPol`
  (`src/StrategicTreasury.sol:360`, emitted at `:991`), zero `realizedRevenue` credit
  (`TreasuryPol.t.sol:259`), and it enters `polVuxPrincipal` when `increasePol` actually pays it
  to the pool. See **J-1**.
- INV-26 negative: `test_INV26_TheTreasuryCannotMintVuxForPol`
  ([`PolConduct.t.sol:228`](../../../../test/treasury/PolConduct.t.sol)) — even the treasury is
  refused by `VUX.mint` with `NotRig()`; `test_INV26_NoPolOperationEverIncreasesSupply` (`:237`)
  drives buy → increase → decrease and shows supply only ever falls; and
  `invariant_NoPolPathEverIncreasesSupply` ([`PolInvariants.t.sol:113`](../../../../test/treasury/PolInvariants.t.sol))
  holds it over 16,384 randomized calls.

### AC-6

> No code path calls `HardReserve.redeem` from the treasury (FR-10.3 conduct, negative test + review)

**✓ Met**, on three legs, re-derived against the **Sprint-5** artifact:

1. **Type level** — the treasury's `metadata.sources` still contains no monetary-core declaration,
   so it cannot name `redeem` ([`PolConduct.t.sol:89`](../../../../test/treasury/PolConduct.t.sol));
   the POL sleeve added only the vendored `IUniswapV3Pool` interface, asserted as a control.
2. **Bytecode level, with both controls** (`:124`). The scan is anchored on the full emitted
   `PUSH4 (sel >> s); PUSH1 (0xe0+s); SHL` idiom with the shift bounded to the eight the compiler
   can emit and lossy shifts skipped. Six **positive** controls (the F-46 self-burn plus the five
   pool calls the sleeve really makes) are all found. A **negative** control is carried alongside:
   `harvestPol()`'s four bytes are asserted *present* in the image (as a dispatcher entry) while
   the method still answers "no call site" (`:181-190`) — which is exactly the discrimination an
   absence claim depends on, and which a scan permissive enough to find everything would fail.
   `redeem(uint256,address)`, `mint(address,uint256)`, `burnForRedemption(address,uint256)` and
   `approve(address,uint256)` are all absent.
3. **Behavioural** — `test_INV27_ProtocolPolVuxNeverRedeems` (`:194`) drives buy → increase →
   harvest → decrease while the treasury holds VUX and asserts the Reserve recorded **zero**
   `Redeemed` events across the whole lifecycle.

### AC-7

> INV-25/26/27 (treasury-side)/28/29 handlers added to the invariant harness; FB-7 (POL failure leaves Hard arithmetic unchanged) and FB-8 (unharvested fees counted nowhere) scenarios green

**✓ Met.**

| invariant | where |
|---|---|
| INV-25 (POL WETH is Strategic; POL VUX stays in `S`) | `invariant_BackingIsAttributedIncludingTheVyrfLeg` ([`PolInvariants.t.sol:90`](../../../../test/treasury/PolInvariants.t.sol)); `invariant_ThePositionIsHeldDirectlyByTheTreasury` (`:212`) |
| INV-26 (no post-genesis POL VUX mint) | `invariant_SupplyIsAttributedIncludingTheVyrfBurn` (`:101`); `invariant_NoPolPathEverIncreasesSupply` (`:113`) |
| INV-27 treasury-side (non-redeeming, non-voting) | `PolConduct.t.sol:194` and `:213` (structural — no redeem call site, no staking surface) |
| INV-28 (returned principal is principal) | `invariant_RevenueStillTracesOnlyToStrategyFlows` (`:174`); `invariant_PolBasisNeverExceedsWhatWasPaidIn` (`:192`); `test_ReturnedPrincipalIsNeverRevenue` ([`TreasuryPol.t.sol:204`](../../../../test/treasury/TreasuryPol.t.sol)) |
| INV-29 (VUX burns, WETH → Hard, both bypass the waterfall) | `invariant_VyrfClassifiedAmountsNeverExceedFeesCharged` (`:152`); `:90`; `:101`; `PolConduct.t.sol:41` |

The harness is an **extension**, not a parallel approximation:
[`PolInvariantHandler`](../../../../test/treasury/PolInvariantHandler.sol) *inherits*
`TreasuryInvariantHandler`, so all twelve Sprint-4 actions still fire in the same randomized
sequences alongside the six new POL ones — 22 selectors, 0 reverts, at
`fail_on_revert = true`. The prior Sprint-3 and Sprint-4 suites are untouched and still green.

FB-7: `test_FB7_APolPriceCollapseLeavesHardArithmeticBitIdentical`
([`PolFailureBehaviors.t.sol:33`](../../../../test/treasury/PolFailureBehaviors.t.sol)) moves the
marginal price by orders of magnitude with a 5,000-WETH rout and asserts the twelve-field core
snapshot is bit-identical; `:49` unwinds the position entirely and shows the Reserve untouched.
FB-8: `:75` accrues fees, leaves them, and asserts nothing anywhere moved — then harvests to prove
the value was real; `:107` shows harvest timing changes *when*, never *where*.

Wash trading (§9.2 row 12) is carried as a **tested** interpretation rather than a prose note:
`test_WashTradingDonatesFeesAndBuysNoPrivilege` (`:150`) has an attacker churn 100 WETH, then
asserts the fees landed in burn and in `B` while the attacker gained no mint credit, no revenue
classification, no role, and no principal claim.

### AC-8

> `harvestPol` is permissionless, parameter-free, and performs no swap (sdd.md:L144) — keeper absence cannot corrupt classification (NFR-REL-2)

**✓ Met.** `harvestPol()` takes no arguments and no role
([`src/StrategicTreasury.sol:1010`](../../../../src/StrategicTreasury.sol)) — `nonReentrant` is
its only modifier. Called from an unrelated address in
`test_HarvestPolBurnsVuxFeesAndAccretesWethFeesToHard`
([`TreasuryPol.t.sol:305`](../../../../test/treasury/TreasuryPol.t.sol)).
`test_HarvestPolPerformsNoSwap` (`:344`) asserts the pool's `sqrtPriceX96` and the position's
liquidity are bit-identical across it. `test_KeeperAbsenceCannotCorruptClassification` (`:382`)
lets six days of trades accumulate unharvested and shows the whole backlog classifies correctly in
one late call. `test_HarvestPolWithNoFeesIsAnHonestNoOp` (`:362`) pins that an early keeper is a
lawful no-op reporting two zero legs rather than an error.

---

## Tasks completed

| task | beads | delivered |
|---|---|---|
| 5.1 POL position ops | `vux-221` | `mintPolPosition` / `increasePol` (`src/StrategicTreasury.sol:913`, `:921`) sharing `_addLiquidity` (`:1156`); committed-maxima arming; direct-on-pool position; quantization-dust treatment |
| 5.2 decrease + POL VUX purchase | `vux-24x` | `decreasePol` (`:945`) with the accepted five-step ordering; `buyVuxForPol` (`:974`) with measured-output verification |
| 5.3 permissionless VYRF | `vux-1uw` | `harvestPol` (`:1010`) over `_pokeCollectAndClassifyFees` (`:1219`); `VyrfHarvest` (`:359`) |
| 5.4 callback authentication | `vux-7tj` | both callbacks (`:1031`, `:1061`); one-shot `OpContext` (`:271`, `_arm` `:1240`, `_requireConsumed` `:1247`); 9-class negative suite + control |
| 5.5 invariants & failure behaviour | `vux-7z7` | `PolInvariantHandler` (extends Sprint 4) + 9 invariants + anti-vacuity test; FB-7 / FB-8 / wash-trading scenarios |
| 5.6 fork E2E + conduct proof | `vux-kgg` | `script/PolVyrfE2E.s.sol`; FR-10.3 three-leg re-proof with positive **and** negative controls; INV-26/27; waterfall exclusion |

---

## Technical highlights

### The liquidity inversion, and why it needs no `TickMath`

`increasePol(vuxAmt, wethAmt)` is the accepted signature (sdd.md §5.2.5) and the accepted genesis
behaviour is that quantization dust remains inventory (sdd.md:L168) — so the treasury must convert
committed *amounts* into a liquidity *unit*. Inverting v3's charge formulas needs
`sqrtRatioAtTick`, which this compilation unit cannot have: the vendored `TickMath` lives in the
`=0.7.6` unit on wrapping arithmetic that is deliberately never ported, and porting or re-deriving
it would be exactly the copied third-party helper the provenance boundary forbids.

It does not need it. Substituting the *domain* endpoints for the position's own bounds moves both
estimates in the safe direction — `x/(x−p)` decreases in `x`, and `1/(p−a)` decreases as `a`
falls — so each side under-estimates the true affordable liquidity, hence so does their minimum,
hence the pool can never demand more than the committed maxima. The same conclusion holds if the
price were ever outside the full range, where the true charge is one-sided and smaller still.
Implementation and the direction proof: [`src/StrategicTreasury.sol:1195-1217`](../../../../src/StrategicTreasury.sol).

The precision cost is bounded by `sqrtA/sqrtP + sqrtP/sqrtB`. Measured on the genesis-shaped
position in the E2E run: **19 wei of VUX and 364 wei of WETH** out of 150,000 VUX and 300 WETH —
"a few wei of either token", as sdd.md:L168 anticipated. That dust never entered the position, so
it stays bare treasury inventory (principal-side by §1.10 rule 5, never revenue) and is
deliberately **not** booked as position basis.

### Ordinary storage for the context, not transient

The one-shot context (`:271`) is plain storage. Transient storage would be the obvious choice and
is deliberately declined: it would make the contract require a Cancun-or-later chain, and
`evm_version` is left unset as an R-14 deployment-time fact. Nothing is lost — the context is
armed and consumed inside one call and the outer operation reverts if it survives, so it can never
persist across transactions.

### Callbacks are not `nonReentrant`, and that is load-bearing

They arrive while the outer operation still holds the guard, so taking it would deadlock every
legitimate mint. The authentication is the context. Class 6 of the negative suite shows the other
half of that argument: a callback that tries to start a nested treasury operation meets the guard
the outer operation is still holding.

---

## Judgment calls

**J-1 — `buyVuxForPol` does not increment `polVuxPrincipal`.**
AC-5 says purchased VUX "books as POL inventory principal", and sdd.md:L143 says the cells are the
cost basis that `decreasePol` books returned principal *against*. Both readings cannot be
satisfied by incrementing on purchase: the same VUX would be counted again when `increasePol` pays
it to the pool, and sdd.md:L140 fixes the accounting-cell set as "exactly these" — there is no
third cell available to hold an undeployed-inventory basis. The implementation therefore treats
the two cells as the **position's** basis, and satisfies "books as POL inventory principal" as the
classification statement it is: purchased VUX is POL inventory, is principal (no purchase path
credits `realizedRevenue`), is evented by `VuxPurchasedForPol`, and enters `polVuxPrincipal` at the
moment it actually enters the position. Rationale in-code at
[`src/StrategicTreasury.sol:229-252`](../../../../src/StrategicTreasury.sol). Raised for reviewer
disposition rather than decided silently.

**J-2 — `mintPolPosition` and `increasePol` differ only by a precondition.**
The accepted API names both. Implemented as one shared `_addLiquidity` with `mintPolPosition`
requiring the position not to exist and `increasePol` requiring that it does, so each name means
what it says and neither can do the other's job by accident (`:913`, `:921`, tested at
`TreasuryPol.t.sol:124`). The alternative — two identical functions — seemed the worse answer.

**J-3 — `TreasurySurface.t.sol` was modified.** It is a closed-world assertion designed to fail
when the external surface changes; the array grew from 44 to 53 by exactly the SDD §5.2.5 POL
surface. Updating it is how a new surface gets accepted, not a way around the gate.

---

## Testing summary

| suite | tests | notes |
|---|---|---|
| `TreasuryPol.t.sol` | 17 | POL ops, decrease ordering, purchase bounds, VYRF |
| `TreasuryCallbackAuth.t.sol` | 11 | 9 rejection classes + control + zero-approval sweep |
| `PolInvariants.t.sol` | 9 invariants + 1 anti-vacuity | 22 handler selectors, 0 reverts |
| `PolFailureBehaviors.t.sol` | 5 | FB-7 ×2, FB-8 ×2, wash trading |
| `PolConduct.t.sol` | 8 | waterfall exclusion, FR-10.3 ×2, INV-26 ×2, INV-27 ×2 |
| **new total** | **51** | baseline 298 → **349** |

```bash
FOUNDRY_PROFILE=v3core forge build          # frozen =0.7.6 unit
forge build && forge test                   # 349 passed, 0 failed
FOUNDRY_PROFILE=ci forge test               # 349 passed — 10,000 fuzz runs, 256x64 invariants
bash tools/provenance/run-all.sh            # All provenance gates and tests passed
```

Invariant depth under `[profile.ci]`: every one of the nine POL invariants reports
`runs: 256, calls: 16384, reverts: 0` — clearing the sprint's ≥10,000 bar. No prior fuzz or
invariant budget was reduced; `[profile.default.invariant]` and `[profile.ci.invariant]` are
unchanged.

E2E:

```bash
anvil --port 8545
forge script script/PolVyrfE2E.s.sol:PolVyrfE2E --fork-url http://127.0.0.1:8545 -vvvv
```

---

## Known limitations

1. **RH-chain fork unavailable** (AC-4 above). No accepted artifact records an RPC endpoint; the
   scenario runs against live anvil instead. Residual: the real canonical WETH's behaviour is not
   exercised — the YELLOW dependency Sprints 7–8 are scheduled to cover.
2. **The invariant handler never fully unwinds the position or trades a thin book.** Both are
   shaped out (`THIN_BOOK`) so a legitimate call cannot revert under `fail_on_revert = true`; both
   paths are covered by dedicated unit tests instead (`PolFailureBehaviors.t.sol:49`,
   `TreasuryPol.t.sol:204`). Stated rather than left implicit.
3. **Partial-decrease basis release is `min(returned, basis)`, not proportional.** Simplest rule
   that cannot create revenue in either direction, which is what INV-28 requires; a proportional
   release would add machinery no acceptance criterion asks for and could only create revenue.
4. **`_feeOn` / `_feeBound` over-approximate by one wei per swap.** Deliberate: every use is on
   the large side of a `≤`, where over-approximating is the safe direction.

---

## Boundaries observed

- **Sprint-4 carry-forward:** J-3/R-9 lifetime-accumulator semantics untouched; `returnFor` still
  permissionless; `recallFromStrategy`/`UnknownReturnAsset` LOW left as accepted; `activateLSG`
  doc/behaviour mismatch not opportunistically remediated. No Sprint-4 function body changed.
- **P0/P1 tripwire:** no `LSGSignals`, no LSG timing, no ROOT/GIGA or production adapters, no
  waterfall activation, no `50/25/20/5/0` constant, no Operator Reserve machinery, no market-infra
  leg, no POL expansion tooling, no range-management policy, no oracle, no lending, no LLTV, no
  governance expansion. `TreasurySurface.t.sol`'s prohibited-surface and no-ratio-constant tests
  still pass against the Sprint-5 artifact.
- **Provenance:** no new dependency; `vendor/`, `remappings.txt`, `foundry.toml` all unchanged.
  The `HITL_REQUIRED — NEW_DEPENDENCY_PROVENANCE_GATE` stop was never reached.
- **Lifecycle:** no commit, no push, no `COMPLETED` marker, no ledger mutation, no `sprint.md`
  checkbox ticked, no authority file touched. `/review-sprint` not invoked.

---

## Verification steps for the reviewer

```bash
cd C:/Users/0x007/vux-sprint-5
git rev-parse HEAD                    # cf0108109e428da0483b8470726f9e48ee740777
git log --oneline master..sprint-5    # empty — zero commits ahead

# 1. Re-derive the subject from git and re-prove exhaustiveness (both directions)
BASE=cf0108109e428da0483b8470726f9e48ee740777
{ git diff --name-only "$BASE" -- . ; git ls-files --others --exclude-standard ; } | LC_ALL=C sort -u > R.txt
grep -E '^(src/|test/|script/|foundry\.toml$|remappings\.txt$)' R.txt | LC_ALL=C sort > A.txt
grep -E '^(grimoires/|\.beads/|\.run/)'                          R.txt | LC_ALL=C sort > B.txt
cat A.txt B.txt | LC_ALL=C sort -u | diff - R.txt && echo "A u B == R"
comm -12 A.txt B.txt | wc -l          # 0
xargs -a A.txt sha256sum | LC_ALL=C sort -k2 | sha256sum
#   -> 37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a

# 2. Frozen unit identity — ask the toolchain, not the file
FOUNDRY_PROFILE=v3core forge config | grep -E 'via_ir|optimizer|evm_version|bytecode_hash|solc'
bash tools/provenance/verify-init-code-hash.sh

# 3. Full evidence
FOUNDRY_PROFILE=v3core forge build && forge build
forge test && FOUNDRY_PROFILE=ci forge test
bash tools/provenance/run-all.sh
```

---

## Continuous learning — recommendation

One candidate lesson is genuinely reusable and was discovered by investigation rather than known
in advance: **a conservative closed-form inversion can replace a library you are not allowed to
import, when the substitution's error direction is provable.** The POL liquidity computation
needed `sqrtRatioAtTick`; substituting the price domain's endpoints for the position's own bounds
is provably an under-estimate on both sides, which converts "I cannot import this" into "I do not
need it" — at a measured cost of 19 wei on a 150,000-unit position. The reusable part is the
method: identify the monotonicity of the formula in the unknown, substitute the domain bound that
moves it the safe way, then *measure* the resulting slack rather than reasoning about it.

A second, smaller candidate: Foundry evaluates a call's **arguments before** `vm.expectRevert`
takes effect, so an argument that is itself an external call silently consumes the expectation and
the test reports "did not revert as expected" against the wrong call.

Recommend running `/retrospective` for this node **before** `/review-sprint`, so the learning
capture does not contaminate the implementation subject. Not run here.

---

**Terminal state: `SPRINT_5_IMPLEMENTED_READY_FOR_REVIEW`**
