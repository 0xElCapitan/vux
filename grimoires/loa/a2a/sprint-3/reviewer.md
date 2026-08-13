# Sprint 3 Implementation Report — Rig: Throne, Settlement, VEM & the Monetary Invariant Suite

**Sprint:** cycle-002 / sprint-3 (Sprint Ledger global 3 = local `sprint-3`)
**Branch:** `sprint-3` (tree left uncommitted — see §9)
**Baseline:** `bc5dedc2025921221407cd85f5ec1e6d40ad7a7b` (`master == origin/master` at node start)
**Date:** 2026-08-13
**Status:** implementation complete, ready for independent `/review-sprint sprint-3`
**`SPRINT_4_NOT_STARTED`**

---

## 1. Executive Summary

`src/Rig.sol` completes the VUX monetary core: one Dutch-priced KOTH throne, the
eight-halving mining clock, the 13-step atomic settlement carrying the **adaptive
8%-floor routing law**, measured-`D_R` VEM, and bootstrap semantics. The
cycle-wide stateful monetary invariant harness is introduced alongside it and is
built to be extended, not replaced, by Sprints 4–5.

The contract has **no owner, no role, no pause, no upgrade path, and exactly one
state-changing external function** (`take`). That is asserted against the
compiled artifact, not the source: its external surface is enumerated at 26
entries in both directions.

**Delivered:** 83 new tests across 7 suites, all green. Total suite 144/144.
At CI depth: **fuzz 10,000 runs** per property test, **invariant 16,384 calls with
0 reverts and 0 discards**. All provenance gates pass, including
`POOL_INIT_CODE_HASH` reproduction.

**Two judgment calls the reviewer should look at first** (details in §6):
`via_ir` was enabled on the VUX compilation unit as a compilation necessity for
the accepted 16-field `Settled` event, and that change initially leaked into the
vendored v3-core profile by Foundry profile inheritance before being pinned off.

### Authority verified at node start

| artifact | expected SHA-256 | verified |
|---|---|---|
| `grimoires/loa/prd.md` v2.1.1 | `791c52f2…f0e2406e` | ✓ exact |
| `grimoires/loa/sdd.md` v1.7.1 | `b7270458…aac6b175` | ✓ exact |
| `grimoires/loa/sprint.md` v1.1.1 | `6db19ad0…c1f32bfce514` | ✓ exact |

Both pre-Sprint-3 gating conditions confirmed satisfied on current master:
`26ca4cd6c31ec30770c34891c23a4bb63ce2cada` (M-1/L-3/L-4 provenance hardening) is
an ancestor of `HEAD`, and `bc5dedc2` is the landed adaptive-routing
reconciliation package. The Sprint Plan's conditional "blocked until" prose
(sprint.md:L12, L121; sdd.md Appendix F note F-5) is therefore discharged, as the
node mandate directed.

---

## AC Verification

Every acceptance criterion from `grimoires/loa/sprint.md` Sprint 3 (L250–L258),
quoted verbatim.

### Native validator result

**Exit 0 — 8/8 ACs walked verbatim, 0 violations.**

```bash
.claude/scripts/validate-ac-verification.sh \
  --report grimoires/loa/a2a/sprint-3/reviewer.md \
  --sprint grimoires/loa/a2a/sprint-3/sprint-3-scope.md
```

The validator takes no sprint argument, so it walks every AC in the file it is
given. `grimoires/loa/sprint.md` holds all 8 sprints of this cycle, so the
scoped input is `sprint-3-scope.md` — a **byte-exact** slice of sprint.md
L236–L290, following the convention Sprint 2 established with
`sprint-2-scope.md` (recorded in `a2a/index.md`). Verify the slice is not a
paraphrase:

```bash
diff <(sed -n '236,290p' grimoires/loa/sprint.md) grimoires/loa/a2a/sprint-3/sprint-3-scope.md
sha256sum grimoires/loa/a2a/sprint-3/sprint-3-scope.md
# 1584e2e1d948fb61e607d3bd9727c94fa973d9576c792b18b89d723fe8a815b6
```

Passing the unscoped multi-sprint file instead yields exit 1 with 63 violations,
all of which are *other* sprints' criteria — Sprints 1 and 2 behave identically
(63 and 64) against their own accepted reports. None of Sprint 3's own ACs
appears in that list.

### AC-1 — Dutch price and successor ladder

> "Price function matches `max(DECAY_FLOOR, opening × (1 − min(t,3000)/3000))` at boundary points t = 0 / 3000 / beyond, floor clip; successor opening `max(MINIMUM_OPENING, 2×P)` including the minimum branch (prd.md:L342-L344)"

**✓ Met.** Implementation [src/Rig.sol:455](../../../../src/Rig.sol) (`currentPrice`),
[src/Rig.sol:518](../../../../src/Rig.sol) (`_successorOpening`).

| boundary | test |
|---|---|
| t = 0 | `test_PriceAtEpochOpenIsTheOpening` ([RigPricing.t.sol:24](../../../../test/rig/RigPricing.t.sol)) |
| linear ramp (750/1500/2250) | `test_PriceDecaysLinearlyAcrossTheEpoch` ([:28](../../../../test/rig/RigPricing.t.sol)) |
| t = 3000 / 3001 / +10 y | `test_PriceAtAndBeyondExpiryIsTheFloorForever` ([:51](../../../../test/rig/RigPricing.t.sol)) |
| expiry join not one second early | `test_TheExpiryJoinDoesNotFireOneSecondEarly` ([:64](../../../../test/rig/RigPricing.t.sol)) |
| floor clip *before* expiry | `test_TheFloorClipsTheRampBeforeExpiry` ([:81](../../../../test/rig/RigPricing.t.sol)) |
| monotonic + floored (fuzz) | `testFuzz_PriceIsNonIncreasingAndFloored` ([:102](../../../../test/rig/RigPricing.t.sol)) |
| successor = 2×P branch | `test_SuccessorOpensAtTwiceThePaidPrice` ([:121](../../../../test/rig/RigPricing.t.sol)) |
| successor = MINIMUM branch | `test_SuccessorOpensAtTheMinimumWhenTwicePriceIsBelowIt` ([:132](../../../../test/rig/RigPricing.t.sol)) |

The expiry-join test uses a purpose-built probe instance: with the fixture's
rehearsal values the floor already clips the ramp by t = 2999, so the default
values provably cannot distinguish "the ramp ended" from "the floor clipped".

### AC-2 — UPS schedule, snapshot, and the raw cap

> "UPS at every schedule boundary equals 4 / 2 / 1 / 0.5 / 0.25 / 0.125 / 0.0625 / 0.03125 / 0.015625 VUX/s; an epoch straddling a halving settles at its opening snapshot; `Qraw` caps at exactly `3000 × epochUPS` (prd.md:L359-L361)"

**✓ Met.** Implementation [src/Rig.sol:471](../../../../src/Rig.sol) (`currentUPS`),
[src/Rig.sol:~370](../../../../src/Rig.sol) (step 4 of `take`).

- All nine table rows, at the exact halving second **and one second before it**:
  `test_UpsMatchesTheFrozenTableAtEveryHalvingBoundary`
  ([RigPricing.t.sol:155](../../../../test/rig/RigPricing.t.sol)).
- Permanent tail at day 240, +10 y, +100 y — no ninth halving:
  `test_TheTailIsPermanent` ([:186](../../../../test/rig/RigPricing.t.sol)).
- Straddling epoch settles at its snapshot while the schedule itself has halved:
  `test_AHalvingDuringAnOpenReignDoesNotChangeItsSnapshot`
  ([:213](../../../../test/rig/RigPricing.t.sol)).
- `Qraw` at exactly 3000 s, at 2999 s, and after 100× the cap:
  `test_QrawCapsAtExactlyThreeThousandSeconds`, `test_QrawOneSecondShortOfTheCapIsOneSecondShort`,
  `test_TimeBeyondTheCapCreatesNoCarry` ([:233](../../../../test/rig/RigPricing.t.sol)).
- Fuzzed identity `Qraw == min(elapsed, 3000) × snapshot`:
  `testFuzz_QrawIsElapsedCappedTimesTheSnapshot` ([:270](../../../../test/rig/RigPricing.t.sol)).

### AC-3 — Randomized adaptive-routing regime testing

> "Randomized `(P, Qraw, B_pre, S_pre)` regime testing (weak/cheap through strong/premium): `king = floor(P×8000/10000)`; `retained = P − king`; `strategicCap = floor(P×1200/10000)`; `hardFloor = retained − strategicCap`; `D_need = ceil(Qraw×B_pre/S_pre)`; `hardTarget = min(retained, max(hardFloor, D_need))`; `strategic = retained − hardTarget`; legs sum to `P`; `hardFloor ≤ hardTarget ≤ retained`; `0 ≤ strategic ≤ strategicCap`; dust lands in Hard; `D_need ≤ hardFloor ⇒` exact equality with the prior static split (prd.md:L376)"

**✓ Met.** Implementation [src/Rig.sol:500](../../../../src/Rig.sol) (`_route`, `internal pure`).

Every clause, in [test/rig/RigRouting.t.sol](../../../../test/rig/RigRouting.t.sol):

| clause | test |
|---|---|
| all seven formulas, exact, vs. an independent oracle | `testFuzz_TheLawHoldsAcrossAllRegimes` (assertions 1) |
| legs sum to `P` | same (assertion 2) |
| `hardFloor ≤ hardTarget ≤ retained` | same (assertion 3) |
| `0 ≤ strategic ≤ strategicCap` | same (assertion 4) |
| King leg fixed at 80%, never adaptive | same (assertion 5) |
| dust lands in Hard | `test_DustFavoursHardAtTinyPayments` (P = 0…20 wei), `testFuzz_HardFloorNeverFallsBelowTheNominalEightPercent` |
| `D_need ≤ hardFloor ⇒` exact static split | `testFuzz_DegeneracyEqualsTheStaticSplitExactly` + `test_RegimeOne_DegeneratesToTheStaticSplit` |
| regime 2 (`hardFloor < D_need ≤ retained`) | `testFuzz_HardTracksDNeedExactlyInsideTheWindow` + `test_RegimeTwo_HardTakesExactlyWhatIssuanceNeeds` |
| regime 3 (`D_need > retained`) → Strategic zero | `testFuzz_StrategicIsZeroOnceHardNeedsEverything` + `test_RegimeThree_HardTakesAllRetainedAndStrategicIsZero` |
| Strategic may reach zero | regime-3 tests above; `test_AZeroStrategicLegEmitsNoTransfer` (settlement level) |
| monotonicity in the steering input | `testFuzz_MoreRawOpportunityNeverReducesTheHardLeg` |

All three regimes are reached by **input shaping**, not `vm.assume` filtering —
the regimes are narrow slices of the input space, and filtering would have
discarded most runs while still reporting 10,000.

### AC-4 — VEM property, `D_R` rejection, no carry cell

> "Property test ∀ `(B_pre, S_pre, D_R, Qraw)`: minted amount = `min(Qraw, floor(D_R × S_pre / B_pre))` and preserves `(B_pre+D_R)/(S_pre+Qmint) ≥ B_pre/S_pre`; a measured `D_R` inconsistent with the routed `hardTarget` rejects atomically (`InconsistentReserveDelta`); no storage cell records unmet `Qraw − Qsafe` (prd.md:L393-L395); VEM measured-delta invariant unchanged (`D_actual ≡ D_R`)"

**✓ Met.** Implementation [src/Rig.sol:487](../../../../src/Rig.sol) (`_vem`),
[src/Rig.sol:~398](../../../../src/Rig.sol) (step 8b rejection).

| clause | test ([test/rig/RigVem.t.sol](../../../../test/rig/RigVem.t.sol)) |
|---|---|
| `Qmint = min(Qraw, floor(D_R×S_pre/B_pre))` ∀ tuples | `testFuzz_QmintIsMinOfQrawAndFlooredSafeIssuance` |
| non-dilution, cross-multiplied | `testFuzz_IssuanceCannotReduceBackingPerUnit`; live: `testFuzz_LiveSettlementNeverReducesBackingPerUnit` |
| survives an overflowing intermediate | `testFuzz_TheCapSurvivesAnOverflowingIntermediate` (product provably > 2²⁵⁶) |
| floor direction | `test_IssuanceRoundsDownTowardTheReserve` |
| which side binds | `test_WhenQsafeIsBindingOnlyQsafeIsMinted`, `test_WhenQrawIsBindingTheSurplusRaisesBackingPerUnit` |
| `D_R` under-delivered rejects | `test_UnderDeliveredHardLegRejectsTheSettlement` |
| `D_R` over-delivered rejects | `test_OverDeliveredHardLegRejectsTheSettlement` |
| rejection is atomic across every leg | `test_TheRejectionUnwindsEveryLeg` |
| no storage cell records the shortfall | `test_NoStorageCellRecordsTheUnmintedRemainder` — raw `vm.load` scan of slots 0–9 |
| `D_actual ≡ D_R` | `test_OrdinarySettlementRoutesEveryLegExactly` asserts `r.dR == hardTarget` and equals the physical balance delta |

The `∀` is real because `_vem` is exercised directly: a live settlement cannot
construct arbitrary `D_R` (it is determined by the routing law), so the pure
function is driven through `RigMathHarness`, a subclass wrapping the production
code with no arithmetic of its own.

### AC-5 — Bootstrap (confirm-only)

> "Bootstrap (confirm-only — behavior unchanged): Reserve is genesis King, clock disabled, `Qraw = 0` (so `hardTarget = hardFloor`, `strategic = strategicCap` by degeneracy), first takeover routes ≈88%+/12%/0-mint, payer's epoch opens at current schedule rate, no second bootstrap state reachable (prd.md:L407-L408)"

**✓ Met.** Implementation: constructor + the `king == reserve` test in `take`
([src/Rig.sol:255](../../../../src/Rig.sol), [:~345](../../../../src/Rig.sol)).

| clause | test ([test/rig/RigBootstrap.t.sol](../../../../test/rig/RigBootstrap.t.sol)) |
|---|---|
| Reserve is genesis King; clock disabled | `test_TheReserveIsTheGenesisKingAndTheClockIsOff`, `test_TheBootstrapStateIsVisibleThroughEpochState` |
| `Qraw = 0` ⇒ degeneracy to floor/cap | `test_TheFirstTakeoverRoutesEverythingButTheCapToHardAndMintsZero` (asserts `hardTarget == hardFloor`, `strategic == strategicCap`) |
| ≈88%+ Hard / ≤12% Strategic / 0 mint | same, plus fuzzed over the whole bootstrap epoch: `testFuzz_TheFirstTakeoverAlwaysSendsAtLeastEightyEightPercentToHard` |
| payer's epoch opens at current rate | `test_ThePayerBecomesTheFirstPublicKingAtTheCurrentScheduleRate` |
| no privileged party receives bootstrap value | `test_NoPrivilegedPartyReceivesBootstrapValue` |
| no second bootstrap reachable | `test_NoSecondBootstrapStateIsReachable` (5 rounds); `test_AFabricatedReserveInitiatedTakeStillCannotReseatTheReserve`; `invariant_AtMostOneBootstrapSettlementEverOccurs` over 16,384 calls |

No bootstrap-specific economics were written. The ≈88%+ result is the *ordinary*
law at `Qraw = 0` with the Reserve as outgoing King, which is why the King leg
terminates at Hard.

### AC-6 — Partial-failure injection and INV-21

> "Partial-failure injection: no state where some legs routed and others did not (prd.md:L378); settlement cannot rewrite a prior epoch or mint recipient (INV-21)"

**✓ Met.** In [test/rig/RigSettlement.t.sol](../../../../test/rig/RigSettlement.t.sol):

- **Per-leg matrix:** `test_FailingAnyOneLegUnwindsTheWholeSettlement` fails the
  Strategic, Hard, and King legs in turn and compares seven observables against a
  pre-image each time. The King leg is the load-bearing row: it runs *after* the
  successor epoch is written and after the mint, so a half-commit would surface
  there.
- **Failing mint:** `test_AFailingMintUnwindsTheSettlement`.
- **Failing payment:** `test_SettlementFailsWhenThePayerCannotPay`,
  `test_SettlementFailsWithoutAllowance`.
- **Failing measurement:** `test_TheRejectionUnwindsEveryLeg` (AC-4).
- **Reentrancy:** `test_ReentrantTakeIsRejected` proves `nonReentrant` is applied
  to `take`, not merely inherited.
- **INV-21:** `test_SuccessorStateCannotRewriteTheOutgoingEpoch` (the record names
  the outgoing King and outgoing epoch id while storage has already advanced);
  `test_EachReignIsMintedExactlyOnceToItsOwnKing`; and per-settlement inside the
  invariant handler over 16,384 calls.

### AC-7 — Prohibited-signal code inspection

> "Code-inspection checklist (narrowed prohibition): no branch of primary settlement reads time-phase, macro, NAV, ROOT/GIGA price, market price, oracle data, or operator preference — the adaptive computation consumes exactly `(P, Qraw, B_pre, S_pre)` plus own throne state (prd.md:L233, L377) — named checklist entry for review"

**✓ Met.** Named checklist:
[`evidence/prohibited-signal-inspection.md`](evidence/prohibited-signal-inspection.md).

It enumerates all 14 branches in the primary path, and makes the claim
structurally rather than by inspection on two axes: both adaptive formulas are
`pure` (so the compiler forbids reading anything beyond their four parameters),
and the contract's entire reference graph is four `immutable` addresses with no
mutable address cell and no setter — so no prohibited signal is *reachable* to
become an input. Includes four reproducible `grep`/`forge` commands.

### AC-8 — Invariant suite over random op sequences

> "Invariant suite green over random op sequences: `B/S` monotone under authorized issuance (INV-13), supply attribution complete, INV-1…22 with INV-18/INV-19 in their amended adaptive form (prd.md:L608-L609)"

**✓ Met.** [test/rig/RigInvariants.t.sol](../../../../test/rig/RigInvariants.t.sol)
+ [test/rig/RigInvariantHandler.sol](../../../../test/rig/RigInvariantHandler.sol).

9 global invariants × 16,384 calls at CI depth, **0 reverts, 0 discards**, with
calls distributed evenly across all four handler actions (`takeThrone`,
`redeemSome`, `passTime`, `donateToReserve`).

INV-1…22 coverage map — split by what each layer can physically observe:

| INV | where proven | note |
|---|---|---|
| 1, 5 | `invariant_SupplyIsCompletelyAttributed` | `S == genesis + settlement mints − redemption burns` |
| 2, 3 | `setUp` assertions | genesis exactness; zero to every user address |
| 4 | handler, per settlement | only the outgoing King is credited, by exactly `Qmint` |
| 6 | handler, per settlement | `Qmint ≤ Qraw` and `Qmint ≤ Qsafe` |
| 7 | handler, per settlement + `invariant_AtMostOneBootstrapSettlementEverOccurs` | bootstrap mints zero |
| 8 | `invariant_IssuanceNeverExceedsRawOpportunity` | cumulative `Qmint ≤ Qraw` — a banked shortfall would exceed |
| 9 | handler, per settlement | `Qraw ≤ 3000 × max UPS` |
| 10 | `invariant_BackingIsExactlyThePhysicalBalance` | `B ≡ WETH.balanceOf(reserve)` |
| 11 | `invariant_StrategicAndHardNeverMix`, `invariant_BackingOnlyReflectsRealWethMovements` | |
| 12 | handler, per settlement | `B_pre`/`S_pre` are the pre-settlement values |
| 13 | handler, per settlement (`B_pre × Qmint ≤ D_R × S_pre`) + `testFuzz_LiveSettlementNeverReducesBackingPerUnit` | |
| 14 | Sprint 2 `HardReserveSurface.t.sol` | a claim about ABI + runtime bytecode, not state |
| 15 | `invariant_TheSupplyFloorHolds` | `S ≥ S_MIN`; positive remainder always survives |
| 16 | handler `redeemSome` (`payout × S_pre ≤ B_pre × q`) | Reserve-favouring |
| 17 | `invariant_StrategicAndHardNeverMix` | Strategic holds exactly its contributed legs |
| 18, 19 | handler, per settlement — **amended adaptive form** | king = floor(80%); `hardFloor ≤ reserveLeg ≤ retained`; `strategic ≤ cap` |
| 20 | `invariant_TheRigHoldsNoValue` + handler leg-sum | no other primary recipient; no residue |
| 21 | handler, per settlement | outgoing epoch/King not rewritable; counter +1 exactly |
| 22 | handler, per bootstrap settlement | `D_R × 10000 ≥ price × 8800` |

Per-operation checks are not the weaker half: those facts are overwritten by the
next call, so a state-only invariant physically cannot see them. Both halves run
under the same randomized sequences.

Vacuity is ruled out three ways — `fail_on_revert = true`, Foundry's own
calls/reverts report, and `test_EveryHandlerActionDoesRealWork`, which drives
each action and asserts it moves the state it claims to. Deliberately *not* an
`invariant_` function: the engine evaluates those once at setup, before any call.

---

## 3. Tasks Completed

| task | deliverable | beads |
|---|---|---|
| 3.1 Rig pricing & schedule | `currentPrice`, `currentUPS`, storage layout per sdd.md:L109-L122, constants as `constant` | `vux-16n` closed |
| 3.2 `take(maxPrice)` 13-step settlement | adaptive legs, `D_R` measurement + rejection, `Math.mulDiv` VEM, CEI + `nonReentrant`, mint to outgoing King, `Settled` | `vux-2z4` closed |
| 3.3 Bootstrap branch | `king == reserve ⇒ Qraw = 0`, King leg to Hard, one-shot `scheduleStart` | `vux-1j8` closed |
| 3.4 Property/fuzz suites | 22 tests across routing + VEM | `vux-3rg` closed |
| 3.5 Stateful invariant harness | 9 global invariants + 10 per-settlement checks, INV-1…22 | `vux-uai` closed |
| 3.6 FB scenarios | FB-2, 3, 4, 13, 14, 15, 16 + Rig ABI enumeration | `vux-1v1` closed |
| 3.7 Review documentation | 3 evidence notes + subject manifest | `vux-3j5` closed |

### Files

**New:** `src/Rig.sol` (556 lines), `src/interfaces/IVUXMintable.sol`,
`test/rig/{RigFixture,RigMathHarness,RigInvariantHandler}.sol`,
`test/rig/{RigPricing,RigRouting,RigVem,RigSettlement,RigBootstrap,RigInvariants,RigFailureBehaviors}.t.sol`.

**Modified (three, each a strict addition):** `foundry.toml` (§6);
`test/harness/Vm.sol` (+`load`, +`getBlockTimestamp`);
`test/mocks/MockWeth.sol` (+4 probes).

**No Sprint-1 or Sprint-2 source was edited.** Exact hashes and the
Sprint-3 / lifecycle-evidence / pre-existing-material split:
[`evidence/subject-manifest.md`](evidence/subject-manifest.md).

---

## 4. Technical Highlights

**The adaptive law is a `pure` function.** `_route(price, qRaw, bPre, sPre)` and
`_vem(dR, sPre, bPre, qRaw)` are `internal pure`, which makes FR-4.3's
"consumes exactly `(P, Qraw, B_pre, S_pre)`" a compiler-enforced fact rather than
a reviewed claim, and makes the `∀`-quantified acceptance properties directly
testable over domains no live settlement can reach.

**Three structural properties of the law, not asserted but constructed.** The legs
exhaust `P` because `king + retained == P` and `hardTarget + strategic == retained`
by construction. All dust favours Hard because `retained` absorbs the King leg's
flooring remainder and `strategicCap` floors downward, so both losses land inside
`hardFloor`. `hardFloor` cannot underflow because `retained ≥ ceil(0.2P)` while
`strategicCap ≤ 0.12P`.

**Measured reality is enforced twice.** The `D_R != hardContribution` check is the
specified rejection; the `balanceOf(reserve) − B_pre` subtraction is a second
guard one layer below it, reverting on any settlement that *reduced* the Reserve's
balance. That is what refuses a fabricated Reserve-as-payer takeover
(`test_AFabricatedReserveInitiatedTakeStillCannotReseatTheReserve`).

**Narrow interfaces preserved.** `Rig` needs `mint`, which `IVUX` (imported by
`HardReserve`) deliberately does not declare. Adding it there would have given the
Reserve a typed path to the token's mint authority — precisely the structural
claim INV-5 makes impossible. Hence a second narrow interface,
`IVUXMintable`, at the cost of one file.

**Zero-transfer skip.** A zero Strategic leg is skipped rather than transferred, so
no misleading ERC-20 `Transfer` implies a contribution that did not happen.

**Sprint-4 boundary respected.** The Strategic destination is a plain address, the
Strategic leg is a plain WETH transfer with no callback and no interface, and
`Rig.totalStrategicContributed` carries the cumulative contributed-principal
accounting for Sprint 4 to consume. No treasury policy exists here.

---

## 5. Testing Summary

| suite | tests | carries |
|---|---:|---|
| `test/rig/RigPricing.t.sol` | 17 | FR-2, FR-3, INV-8, INV-9 |
| `test/rig/RigRouting.t.sol` | 10 | FR-4.1/4.2, INV-18, INV-19, INV-20 |
| `test/rig/RigVem.t.sol` | 12 | FR-5, INV-6, INV-12, INV-13, INV-16 |
| `test/rig/RigSettlement.t.sol` | 16 | FR-4.5/4.6, FR-2.1/2.6, INV-4, INV-21 |
| `test/rig/RigBootstrap.t.sol` | 8 | FR-6, INV-7, INV-22 |
| `test/rig/RigInvariants.t.sol` | 11 | INV-1…22 |
| `test/rig/RigFailureBehaviors.t.sol` | 9 | FB-2/3/4/13/14/15/16 |
| **Sprint 3 total** | **83** | |
| Pre-existing (Sprints 1–2) | 61 | unchanged, all still green |
| **Total** | **144** | 144 passed, 0 failed |

### Reproduce

```bash
export PATH="$HOME/.foundry/bin:$PATH"   # Foundry v1.5.0, commit 1c578544…
forge test                                # 144 passed
FOUNDRY_PROFILE=ci forge test             # fuzz 10,000; invariant 16,384 calls
bash tools/provenance/run-all.sh          # all provenance gates + POOL_INIT_CODE_HASH
```

### CI-depth results (`FOUNDRY_PROFILE=ci`)

- **Fuzz:** 10,000 runs on every `testFuzz_*` — meets the ≥10,000 bar
  (sprint.md Sprint 3 Success Metrics; sdd.md:L855).
- **Invariant:** `runs = 256, depth = 64` → **16,384 calls per invariant, 0
  reverts, 0 discards** — meets the ≥10,000 depth-configured bar.
- 144/144 pass. Rigour was not reduced to make CI faster; the whole CI run is
  8.7 s wall-clock.

---

## 6. Judgment Calls for Reviewer Attention

### 6.1 `via_ir` enabled on the VUX unit — a compilation necessity

The accepted event schema fixes `Rig.Settled` at **16 fields**, 13 of them
non-indexed (sdd.md §3.2). The legacy codegen pipeline cannot ABI-encode that
many values inside the EVM's 16-slot addressable stack window: it fails
`Stack too deep` **by exactly one slot**. Three reductions were applied first and
all three are retained in the delivered code — the record is threaded through a
memory struct, the emit was moved into its own frame, and its final field is read
from storage (written one step earlier) so it needs no stack slot to address.
Still one slot short.

The remaining options were to shrink the accepted event (reopening accepted
architecture) or hand-roll `log4` in assembly (excluded by the node mandate).
`via_ir` is the Solidity team's prescribed resolution for this error, is
semantics-preserving by specification, and changes no rounding or ordering
behaviour.

Sprint 2 deliberately left bytecode-affecting settings unset, so this **amends a
recorded decision** — and the amendment is narrow: Sprint 2's stated rationale was
declining optimization *for gas with no requirement asking for it*, which is not
this case. `evm_version` remains unset (still an R-14 deployment fact). Recorded
in `foundry.toml` next to the original rationale rather than silently replacing
it.

**Reviewer question:** is amending the Sprint-2 build decision acceptable, or
should the `Settled` schema be revisited instead? The latter would require
reopening accepted architecture, which this node declined to do unilaterally.

### 6.2 The leak that followed, and how it was caught

Foundry profiles inherit from `[profile.default]`, so `via_ir = true` silently
propagated into `[profile.v3core]` — the byte-identical vendored Uniswap unit
whose settings are frozen to reproduce `POOL_INIT_CODE_HASH`. That would have
changed the pool's creation bytecode and violated refreeze §7 obligation 3.

`tools/provenance/verify-init-code-hash.sh` **failed closed and caught it**,
exactly as designed. `via_ir = false` is now pinned explicitly in
`[profile.v3core]` with a comment stating that nothing may reach that unit by
inheritance. `POOL_INIT_CODE_HASH` reproduces against the accepted constant
`0xe34f199b…8b54` on the delivered tree, and all provenance gates pass.

Worth reviewer attention as a class of hazard rather than a residual defect: any
future `[profile.default]` addition inherits into the frozen vendored unit the
same way. A guard that asserts the v3core profile's effective settings match the
refreeze set exactly — rather than relying on each new key being overridden by
hand — would close it structurally. Flagged, not built: it is outside this
sprint's scope.

### 6.3 `currentPrice`/`currentUPS` are `public`, not `external`

sdd.md §5.2.2 declares both `external`. `take` calls them internally, which
requires `public`. The externally-observable signature is identical; the ABI
enumeration test asserts both are present. Recorded as a deviation for
completeness.

### 6.4 Constructor validation is deliberately minimal

The constructor rejects zero addresses and openings exceeding `uint192`, and
nothing else. It does **not** assert an ordering among
`BOOTSTRAP_OPENING`/`MINIMUM_OPENING`/`DECAY_FLOOR`: those are R-14
deployment-time founder facts verified by `GenesisDeployer`'s closing
self-verification in Sprint 7, and re-asserting a relationship here would freeze
an economic rule no accepted authority states.

### 6.5 A `via_ir` consequence for future test authors

With the optimizer on, repeated `block.timestamp` reads in one frame are folded —
correctly, since `TIMESTAMP` is invariant within a real transaction — which
silently breaks any test reading it both before *and after* a `vm.warp`. One test
hit this. `Vm.getBlockTimestamp()` was declared for that shape and the hazard is
documented at the declaration so it is not rediscovered.

---

## 7. Known Limitations

1. **`epochOpening` clamp is unreachable defensive code.** `_successorOpening`
   clamps `2×P` to `type(uint192).max`. sdd.md:L229 records `P ≤ 2^192` as
   impossible for WETH amounts, so the clamp exists solely to make the `uint192`
   cast incapable of silent truncation; it mirrors the derived skeleton's own
   `ABS_MAX_INIT_PRICE` treatment.
2. **`B_pre > 0` and `S_pre ≥ S_MIN` are argued, not branched.** Both hold
   structurally (documented at `_vem`). If either were ever false the division
   reverts — the correct failure — rather than being handled.
3. **The bootstrap flag follows the outgoing King.** If the Reserve could ever be
   seated as King, the next settlement would read as bootstrap. It cannot: the
   Reserve's surface is `redeem` + views, and §6.2's fabricated-caller test shows
   even an impossible caller is refused by the delta measurement. Recorded so the
   boundary is explicit rather than assumed.
4. **FB-14 is proven structurally.** There is no market in Sprint 3, which is the
   point — the protocol cannot read a price, so no behaviour can condition on one.
   The market-facing half arrives with POL in Sprint 5.
5. **`RigMathHarness` is a test-only subclass** of `Rig`. It adds no arithmetic;
   it exposes the production `pure` functions through `external pure` wrappers.

Nothing above blocks review. No `[ACCEPTED-DEFERRED]` AC rows exist.

---

## 8. Verification Steps for the Reviewer

1. **Baseline and authority.** `git rev-parse HEAD`; confirm `26ca4cd6` is an
   ancestor; re-hash the three authority documents against §1.
2. **Subject fingerprint.** Re-compute the hashes in
   [`evidence/subject-manifest.md`](evidence/subject-manifest.md) §D; confirm
   `git diff --stat bc5dedc2 -- src test tools vendor foundry.toml` shows only
   the 14 files listed there.
3. **Suites.** `forge test` (144), then `FOUNDRY_PROFILE=ci forge test` and
   confirm 10,000 fuzz runs and 16,384 invariant calls with 0 reverts.
4. **Provenance.** `bash tools/provenance/run-all.sh` — all gates, including
   `POOL_INIT_CODE_HASH`. Then confirm the leak of §6.2 is closed:
   `FOUNDRY_PROFILE=v3core forge config | grep via_ir` must print `false`.
5. **Prohibited signals.** Run the four commands in
   [`evidence/prohibited-signal-inspection.md`](evidence/prohibited-signal-inspection.md) §7.
6. **Surface.** `forge test --match-test test_TheRigExternalSurfaceIsExactlyTheAcceptedOne`
   — 26 entries, `take` the only mutator.
7. **The law against the PRD.** Read `_route` (src/Rig.sol:500) beside
   prd.md:L368 and confirm the seven equations line for line.
8. **AC validator.** Run it against `sprint-3-scope.md` (exit 0), and confirm the
   slice is byte-exact with the `diff` in the AC Verification preamble.
9. **Read the two evidence notes:**
   [PROV-3](evidence/prov-3-similarity-review.md),
   [FB-1](evidence/fb-1-mining-redemption-independence.md).

---

## 9. Transition State

Per the node mandate:

- Native Sprint-3 implementation/reviewer artifact produced (this file).
- The exact implementation tree is available for review on branch `sprint-3`,
  **uncommitted** — the mandate forbids committing, landing, and pushing, and the
  sprint plan places landing after operator acceptance (step 5). The manifest
  hashes in §D of the subject manifest are the fingerprint of record.
- `/review-sprint` **not** run. `/audit-sprint` **not** run. No operator
  acceptance granted. Nothing committed, landed, or pushed to `master`.
- Pre-existing State Zone material was neither reset, deleted, cleaned, nor
  staged (subject manifest §C).
- No `COMPLETED` marker written — that is `/audit-sprint`'s output on approval.

**Non-scope confirmed untouched.** No `StrategicTreasury.sol`, no
`VuxPoolDeployer`, no POL, no VYRF, no LSG or `LSGSignals`, no revenue waterfall,
no Operator Reserve, no Dry Powder, no lending or Morpho surface, no oracle, no
tournament/season mechanics, no new admin control, no frontend/Lens/indexer, no
genesis deployment machinery. The six deferred provenance LOW findings remain
deferred and were not folded in. Foundry remains v1.5.0 at the pinned commit; the
M-1/L-3/L-4 source-universe hardening is not regressed.

`SPRINT_4_NOT_STARTED`

---

*Generated by the Loa `/implement sprint-3` node, cycle-002, 2026-08-13.*
