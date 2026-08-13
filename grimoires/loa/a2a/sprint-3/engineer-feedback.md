All good

# Sprint 3 Review — Rig: Throne, Settlement, VEM & the Monetary Invariant Suite

Sprint 3 has been independently reviewed against the exact current tree and is
**APPROVED** to advance to security audit. All 8 acceptance criteria are met on
evidence I re-derived myself rather than accepted from the implementation report.
No critical or high finding exists. Nine low/informational observations are
recorded below and carried forward — none blocks the audit gate.

**Verdict:** `APPROVED` — 0 critical / 0 high / 0 medium / 6 low (+3 informational)
**Recommendation:** proceed to `/audit-sprint sprint-3`

---

## 1. Subject under review (tree identity)

| fact | value |
|---|---|
| branch | `sprint-3` |
| `git rev-parse HEAD` | `bc5dedc2025921221407cd85f5ec1e6d40ad7a7b` |
| implementation state | uncommitted working tree (per node mandate; landing is post-acceptance, sprint.md step 5) |
| `git diff --stat bc5dedc2 -- src test tools vendor foundry.toml` | 3 files, +134 / −9 (`foundry.toml`, `test/harness/Vm.sol`, `test/mocks/MockWeth.sol`) |
| untracked in scope | `src/Rig.sol`, `src/interfaces/IVUXMintable.sol`, `test/rig/` |

Every SHA-256 in `evidence/subject-manifest.md` §A re-computed and matched
**exactly** (16 of 16, including `foundry.toml` `74d5be36…` and
`src/Rig.sol` `f0377bf9…`). No Sprint-1 or Sprint-2 source file is modified; the
three modified files are strictly additive, which I confirmed by reading the full
diff rather than the summary — the two new `Vm` cheatcode declarations add no
behaviour, and every new `MockWeth` probe defaults to a value that preserves
Sprint-2 semantics (`transferFeeBp = 0`, `transferBonus = 0`,
`failTransfersTo = address(0)`, `reentryCallTarget = address(0)`).

**Authority chain re-hashed independently:**

| artifact | expected (sprint.md:L25-L26) | measured | |
|---|---|---|---|
| `grimoires/loa/prd.md` v2.1.1 | `791c52f2ad05…f0e2406e` | `791c52f2ad05c794188b218e877957889bc97b6399b965b9c5fe003ef0e2406e` | ✓ |
| `grimoires/loa/sdd.md` v1.7.1 | `b7270458e141…aac6b175` | `b7270458e1417171dd812f34039263eca45cd676f8009dbfaf202d90aac6b175` | ✓ |
| `grimoires/loa/sprint.md` v1.1.1 | — | `6db19ad09a2da42dbdf4847535b2a73890079efa0d91ebc691f1c7c32bfce514` | ✓ (see L-3) |

Both pre-Sprint-3 binding conditions (sprint.md:L121) confirmed discharged:
`git merge-base --is-ancestor 26ca4cd6c31ec30770c34891c23a4bb63ce2cada HEAD`
returns true (M-1/L-3/L-4 provenance hardening), and `bc5dedc2` is the landed
adaptive-routing reconciliation package.

---

## 2. Acceptance criteria — walked against the tree

`sprint-3-scope.md` verified a **byte-exact** slice of `sprint.md` L236–L290
(`diff <(sed -n '236,290p' grimoires/loa/sprint.md) …` → empty; SHA-256
`1584e2e1d948fb61e607d3bd9727c94fa973d9576c792b18b89d723fe8a815b6`, matching the
report). `validate-ac-verification.sh` against that scoped input exits **0**. The
`## AC Verification` section is present, complete, and quotes every AC verbatim;
no AC is `✗ Not met` and no `⏸ [ACCEPTED-DEFERRED]` row exists.

| AC | verdict | what I independently confirmed |
|---|---|---|
| AC-1 Dutch price + successor ladder | ✓ Met | `currentPrice()` ([src/Rig.sol:453](../../../../src/Rig.sol)) returns `DECAY_FLOOR` for `elapsed >= EPOCH_PERIOD` and `max(DECAY_FLOOR, opening − opening·t/3000)` below it — algebraically identical to the accepted form at t=0/3000/beyond, with the single division flooring the *subtrahend* so the price rounds up (Reserve-favouring, consistent with INV-16). `_successorOpening` ([:580](../../../../src/Rig.sol)) is `max(MINIMUM_OPENING, 2·P)` with a `uint192` clamp. 17 pricing tests green |
| AC-2 UPS schedule, snapshot, raw cap | ✓ Met | `currentUPS()` ([:466](../../../../src/Rig.sol)) = `INITIAL_UPS >> min((t−scheduleStart)/30d, 8)`; the tail is produced by clamping the shift, so no separate constant can drift. `test_UpsMatchesTheFrozenTableAtEveryHalvingBoundary` asserts all nine rows **at the exact halving second and one second before** — a shifted comparison cannot pass. `test_AHalvingDuringAnOpenReignDoesNotChangeItsSnapshot` proves the straddle case |
| AC-3 randomized adaptive-routing regimes | ✓ Met | `_route` ([:517](../../../../src/Rig.sol)) matches prd.md:L368 **term for term**, which I checked line-by-line against the PRD rather than against the report. All seven equations, leg exhaustion, the `hardFloor ≤ hardTarget ≤ retained` bracket, `0 ≤ strategic ≤ strategicCap`, dust-to-Hard, and exact static-split degeneracy are covered by 10 tests at 10,000 fuzz runs each. Regimes are reached by **input shaping**, not `vm.assume` filtering, and each shaped test asserts its shaping landed (`RigRouting.t.sol:208-209`) |
| AC-4 VEM property, `D_R` rejection, no carry cell | ✓ Met | `_vem` ([:566](../../../../src/Rig.sol)) is `min(Qraw, mulDiv(D_R, S_pre, B_pre))` — full-precision, floor. Rejection fires in **both** directions (`test_UnderDeliveredHardLegRejectsTheSettlement`, `test_OverDeliveredHardLegRejectsTheSettlement`). `test_NoStorageCellRecordsTheUnmintedRemainder` uses a raw `vm.load` scan of slots 0–9 — the only sound way to assert absence of state |
| AC-5 bootstrap (confirm-only) | ✓ Met | No bootstrap-specific economics exist in the source. The ≈88%+ result falls out of the *ordinary* law at `Qraw = 0` with the Reserve as outgoing King (step 8a, [:354](../../../../src/Rig.sol)). `hardContribution = P − floor(0.12P) ≥ 0.88P` for every `P`, which I verified algebraically as well as by the fuzzed `testFuzz_TheFirstTakeoverAlwaysSendsAtLeastEightyEightPercentToHard` |
| AC-6 partial-failure injection, INV-21 | ✓ Met | `test_FailingAnyOneLegUnwindsTheWholeSettlement` fails Strategic / Hard / King in turn against a seven-observable pre-image. The King row is the load-bearing one: it runs after the successor epoch write **and** after the mint. Plus failing-mint, failing-payment, failing-measurement, and a real reentrancy probe |
| AC-7 prohibited-signal inspection | ✓ Met | See §5 — I reproduced all four mechanical commands |
| AC-8 invariant suite over random sequences | ✓ Met | See §4 |

---

## 3. Test results and depth — re-run, not reported

```
forge test                     → 144 passed, 0 failed, 0 skipped (13 suites)
FOUNDRY_PROFILE=ci forge test  → 144 passed; fuzz runs: 10000 on every testFuzz_*
                                 9 invariants × runs: 256, calls: 16384, reverts: 0
bash tools/provenance/run-all.sh → all gates green, incl. POOL_INIT_CODE_HASH
```

Suite composition independently enumerated: 83 Sprint-3 tests
(10+11+12+16+17+8+9) and 61 pre-existing (18+19+13+2+3+6) = 144. Every
`testFuzz_*` in the CI run reported `runs: 10000`, clearing the ≥10,000 bar
(sprint.md Sprint 3 Success Metrics; sdd.md:L853). Invariant depth 16,384 calls
clears the ≥10,000 depth-configured bar.

**Non-vacuity** is established three independent ways and I checked each:
`fail_on_revert = true` is pinned in both invariant profiles (`foundry.toml`);
Foundry's own report shows **0 reverts and 0 discards** with calls distributed
evenly across all four handler actions (~250 each per invariant); and
`test_EveryHandlerActionDoesRealWork` ([test/rig/RigInvariants.t.sol:154](../../../../test/rig/RigInvariants.t.sol))
drives each action and asserts it moves the state it claims to. The decision to
make that a `test_` rather than an `invariant_` is correct and the reasoning at
`RigInvariants.t.sol:143-153` is right: the engine evaluates `invariant_`
functions at setup, before any call, where "work was done" is necessarily false.

`invariant_SettlementCountMatchesTheEpochCounter` is a further live guard against
a degenerate campaign: it ties `rig.epochId()` to the handler's own counter, so a
run in which `takeThrone` silently stopped settling would fail rather than pass.

---

## 4. INV-1…22 coverage

The coverage map in `reviewer.md` §AC-8 is accurate; I re-derived it from the
sources rather than accepting the table. All 22 are covered, split by what each
layer can physically observe:

- **Global state invariants (11):** INV-1, 5 (`invariant_SupplyIsCompletelyAttributed`);
  8 (`invariant_IssuanceNeverExceedsRawOpportunity`); 10
  (`invariant_BackingIsExactlyThePhysicalBalance`); 11, 17
  (`invariant_StrategicAndHardNeverMix`, `invariant_BackingOnlyReflectsRealWethMovements`);
  15 (`invariant_TheSupplyFloorHolds`); 20 (`invariant_TheRigHoldsNoValue`);
  7 also via `invariant_AtMostOneBootstrapSettlementEverOccurs`.
- **Per-settlement, inside the handler (10):** INV-4, 6, 7, 9, 12, 13, 16, 18, 19,
  21, 22 at `RigInvariantHandler.sol:156-226`.
- **Setup assertions (2):** INV-2, INV-3 at `RigInvariants.t.sol:36-40`.
- **INV-14** is a claim about ABI + runtime bytecode, correctly located in the
  Sprint-2 surface suite, which re-runs live on this tree (see §7).

The split is sound, not a weakening: per-settlement facts (which epoch settled,
who received the mint, this settlement's legs) are overwritten by the next call,
so a state-only invariant physically cannot see them. INV-18/INV-19 are asserted
in their **amended adaptive form** — `kingLeg == floor(80%)`,
`hardFloor ≤ reserveLeg ≤ retained`, `strategicLeg ≤ strategicCap` — not the
superseded static split.

---

## 5. Prohibited-signal absence — reproduced mechanically

I ran all four commands from `evidence/prohibited-signal-inspection.md` §7 and
confirmed each independently:

1. `_route` and `_vem` are both `internal pure` → **2**. This is the strongest
   available form of the FR-4.3 claim: `pure` is a compiler-enforced statement
   that the function reads no storage, no balance, no `block.*`, and makes no
   call, so the four parameters *provably* are the complete input set. It cannot
   be argued around.
2. The contract has **no mutable address cell**: only `address public king` is
   non-`immutable`, and no setter exists anywhere in the 26-entry surface.
3. The prohibited-signal vocabulary grep returns only Dutch-price vocabulary and
   the FR-4.3 prohibition text quoted in a doc comment — no external price
   source, oracle, pool, registry, or feed reference exists.
4. `test_TheRigExternalSurfaceIsExactlyTheAcceptedOne` passes.

The structural argument at §2 of the evidence note is the right one and I agree
with it: `Rig` holds exactly four external references, all `immutable`, and none
can yield a prohibited signal — `weth` (balance/transfer), `vux` (`totalSupply`/`mint`
via the deliberately narrow `IVUXMintable`), `reserve` and `treasury` (transfer
targets, never called). No prohibited signal is *reachable*, which is a stronger
claim than "no branch currently reads one" and survives later edits that add
branches. Only an added *reference* could invalidate it, and that is diff-visible.

The two `block.timestamp` reads are correctly classified as the independent
variable of two frozen formulas rather than as phase selectors. There is no
branch of the form "if period X, route differently". I checked this myself
against all 14 enumerated branches.

---

## 6. Rig external and mutating surface

Enumerated directly from the compiled artifact, independently of the test:

```
jq -r '.methodIdentifiers | keys | length' out/Rig.sol/Rig.json          → 26
jq -r '.abi[] | select(.type=="function")
       | select(.stateMutability!="view" and .stateMutability!="pure")
       | .name' out/Rig.sol/Rig.json                                     → take
```

**Exactly one state-changing external function.** No owner, no role, no pause, no
upgrade path, no setter, no second entry point. The 26 entries are `take` + 3
views + 7 storage getters + 4 immutable identities + 8 frozen constants + 3
converted USD targets — matching sdd.md §5.2.2 with the `epochState()` addition
the SDD itself declares (sdd.md:L689). `test_TheRigExternalSurfaceIsExactlyTheAcceptedOne`
compares in **both** directions and `test_FB16_…` pins the count at 26, so any
new authority appearing here fails a test rather than passing silently.

---

## 7. Provenance gates, census, and the frozen v3-core unit

`bash tools/provenance/run-all.sh` → **all gates green** on the exact delivered
tree, including census/byte-identity, pin lint, SPDX, quarantine, unauthorized-file
detection, the deployed-surface inspection, and `POOL_INIT_CODE_HASH`.

Zero new source enters the census: `remappings.txt` resolves only to
`vendor/openzeppelin-contracts-v5.2.0/` and `vendor/uniswap-v3-core-v1.0.0/`,
there is no `lib/`, and no `forge-std`. The Sprint-1 operator-accepted
VUX-original harness decision holds. `RigInvariantsTest.targetContracts()`
([test/rig/RigInvariants.t.sol:53](../../../../test/rig/RigInvariants.t.sol))
declares the invariant target directly rather than importing `StdInvariant` —
the correct resolution of that constraint, and it is what keeps
`fail_on_revert = true` viable.

**Frozen vendored unit — verified intact, two ways:**

```
FOUNDRY_PROFILE=v3core forge config
  → via_ir=false  optimizer=true  optimizer_runs=800
    evm_version="istanbul"  bytecode_hash="none"  solc="0.7.6"
```

matching refreeze §7 exactly. And a stronger check than settings equality: I
built the **accepted baseline tree** (`bc5dedc2`) in a throwaway git worktree and
compared the pool's creation bytecode directly.

| | `UniswapV3Pool` creation bytecode SHA-256 |
|---|---|
| baseline `bc5dedc2` | `0df5293be92beb9f46b97dd47f155208c7ab9a3380f88e5115080e0f77389314` |
| delivered tree | `0df5293be92beb9f46b97dd47f155208c7ab9a3380f88e5115080e0f77389314` |

**Byte-identical.** `verify-init-code-hash.sh` reproduces the accepted constant
`0xe34f199b…8b54` and the CBOR-tail test confirms `bytecode_hash = "none"`. The
frozen unit is untouched by the Sprint-3 compiler change.

---

## 8. Compiler-mode change (`via_ir`) — explicit disposition

This is the change the review mandate singles out, so it is dispositioned on its
own evidence rather than as a `Rig.sol` compilation detail.

### 8.1 Is `via_ir` a genuine necessity, or a preference?

**Necessity — independently proven, not accepted on assertion.** I rebuilt the
delivered tree under the baseline compiler settings and under the optimizer-only
variant:

| configuration | result |
|---|---|
| `via_ir=false`, `optimizer=false` (the exact baseline) | `Stack too deep` — `libyul/backends/evm/AsmCodeGen.cpp:68`, "Variable value0 is 1 slot(s) too deep" |
| `via_ir=false`, `optimizer=true` | `Stack too deep` — `libsolidity/codegen/LValue.cpp:50` |
| `via_ir=true`, `optimizer=true` (delivered) | compiles; 144/144 green |

The optimizer alone does **not** resolve it, so this is not an optimization
choice dressed as a necessity. The three source-level reductions were genuinely
applied first and are retained (memory `Settlement` struct at
[src/Rig.sol:206](../../../../src/Rig.sol), the `_emitSettled` frame at
[:425](../../../../src/Rig.sol), and the final field read from storage), and the
error is still short by exactly one slot. The alternatives — shrinking the
accepted 16-field `Settled` schema, or hand-rolling `log4` in assembly — would
have reopened accepted architecture (sdd.md:L480-L493) or breached the sprint's
no-assembly posture (sdd.md:L926) respectively. **Enabling `via_ir` was the
correct call, and correctly escalated rather than made silently.** It is
recorded in `foundry.toml` alongside the original Sprint-2 rationale rather than
replacing it, which is the right documentation shape.

The narrow amendment argument is sound: Sprint 2 declined bytecode-affecting
settings because *no requirement asked for them* and *nothing was load-bearing
for evidence*. Neither premise is disturbed — `evm_version` stays unset (still an
R-14 deployment fact), and the VUX unit still has no constant to reproduce.

### 8.2 Did it change previously accepted Sprint-2 artifacts?

**Yes, and materially — I measured it.** Baseline `[profile.default]` was
`via_ir = false, optimizer = false`; the delivered tree is
`via_ir = true, optimizer = true`.

| contract | baseline `bc5dedc2` runtime SHA-256 | delivered runtime SHA-256 |
|---|---|---|
| `VUX` | `550e3ef90c7b519bca9945e5e4d21312e11722a914b33b412f133bbf5273fa0f` | `69bddf95a05fc965b49be28c8380a74cbbe9da01b0d9e2efbf35292ea334a472` |
| `HardReserve` | `522468c3464944a6dd8581a46fdbda7fafaf3be5e4797a56da6c4886118826cd` | `c186e2099ad1b519a078b8fed6e9d793167ecc4e3114fe93e995f488f3bf22b7` |

The report does not state this consequence explicitly; the reviewer establishes
it here so the auditor inherits the fact rather than the inference.

### 8.3 Is the accumulated Sprint-2 evidence still sufficient?

**Yes — and this is the load-bearing answer.** The Sprint-2 runtime-bytecode
guarantees are **not** frozen artifacts that went stale; they are **live
assertions re-derived from `out/` on every run**, and both implementations pass
on this exact tree:

- `test/reserve/HardReserveSurface.t.sol` reads
  `out/HardReserve.sol/HardReserve.json` at test time (`:37`, `:57`, `:61`) and
  asserts (a) the `PreGenesisWethSanitized` marker is present in creation code
  and **absent** from runtime code, (b) no `DELEGATECALL` / `CALLCODE` /
  `SELFDESTRUCT` / `CREATE` / `CREATE2` opcode survives, and (c) the
  method-identifier table is exactly `redeem` + 5 views.
- `tools/provenance/inspect-runtime-surface.sh` reproduces the same findings with
  an independent jq+awk implementation and runs inside `run-all.sh` (`:31`). It
  carries **no pinned digest** — it re-derives from the fresh artifact.

Crucially, every absence assertion is paired with a **positive control**
(`assertGt(countOpcode(runtime, OP_CALL), 0)`,
`assertGt(countOpcode(runtime, OP_STATICCALL), 0)`,
`test_MetadataStrippingRemovesATailAndNotTheProgram`), so a codegen change that
broke the opcode walk would fail rather than pass vacuously. That is exactly the
property that makes the evidence portable across compiler pipelines, and it is
why nothing needs regenerating as a separate step.

I also confirmed there is **no static bytecode artifact** anywhere in
`grimoires/loa/a2a/sprint-2/evidence/` — the structural-absence checklist cites
the live test and the live tool, nothing frozen.

Finally, the behavioural half: all **61** Sprint-1/2 tests pass under the new
pipeline (inside the 144), and the same 61 pass at `bc5dedc2` under the legacy
pipeline. The Sprint-2 assertions themselves are byte-identical — the only test
files touched are strictly additive. **No Sprint-2 behavioural or authority
guarantee is regressed, and no runtime-bytecode evidence requires regeneration
before audit.**

### 8.4 The inheritance leak, and the guard deliberately not built

`via_ir = true` on `[profile.default]` propagated into `[profile.v3core]` by
Foundry profile inheritance and was caught by
`tools/provenance/verify-init-code-hash.sh` **failing closed** — refreeze §7
obligation 3 working as designed, on a live regression, in this sprint. That is
materially better evidence for the gate than any rehearsal.

The report flags (and does not build) a structural guard asserting the v3core
profile's *effective* settings match the refreeze set. I have applied the
mandate's test: **the present gates are sufficient today**, because they are
outcome-based rather than settings-based — they recompute `POOL_INIT_CODE_HASH`
from the built artifact and fail closed on any divergence, whatever its cause,
including a key nobody thought to override. Demanding the guard now would be
speculative hardening. It is recorded as I-1 below for the audit and for Sprint 8.

---

## 9. Architecture and authority fidelity

- **Storage layout** matches sdd.md:L109-L122 exactly, cell for cell and type for
  type. All routing/pricing constants are `constant`; the three converted USD
  targets are `immutable`. Nothing settable.
- **13-step settlement ordering** matches sdd.md:L196-L223 exactly, *including*
  the step-12' placement between VEM (9) and the mint (10), which is the
  effects-before-final-interactions requirement of sdd.md:L227. Steps 1–2 capture
  `outgoingKing`/`epochId`/`bootstrap` before any write, which is what makes
  INV-21 structural rather than tested-by-luck.
- **`Settled`** carries all 16 fields in the accepted order and types
  (sdd.md:L480-L493). `D_need` is re-derivable as `ceil(qRaw·bPre/sPre)` from
  emitted fields, satisfying the observability clause.
- **`currentPrice`/`currentUPS` as `public` rather than the SDD's `external`**
  (§6.3 of the report): judged on consequence, not syntax. The ABI entry, the
  4-byte selector, and the `view` mutability are **identical** — I confirmed both
  appear in `methodIdentifiers` and that the surface test's two-way comparison
  passes. No new authority, no semantic difference, no caller-visible change. It
  is *required*, because `take` calls both internally. **Harmless
  implementation-equivalent deviation; no SDD amendment needed.** The alternative
  (internal helpers plus external wrappers) would add two functions to a surface
  the sprint is trying to keep minimal.
- **Sprint-4 boundary respected.** The Strategic destination is a plain address
  with a plain `safeTransfer` — no callback, no interface, no return value
  consumed. `totalStrategicContributed` carries the P0 contributed-principal
  accounting exactly as sprint.md Sprint 3 Dependencies specifies. No treasury
  policy, no `StrategicTreasury`, no LSG, no POL, no VYRF, no revenue waterfall
  exists in this tree. I checked: no P1 mechanism leaked in.
- **Narrow-interface discipline.** `IVUXMintable` as a *second* narrow interface
  rather than widening `IVUX` is the right call and the reasoning in the file is
  correct — adding `mint` to the interface `HardReserve` imports would hand the
  Reserve a typed path to mint authority, which is precisely what INV-5 makes
  impossible. One extra file is the correct price.
- **Zero-transfer skip** for a zero Strategic leg (step 7) avoids a misleading
  ERC-20 `Transfer` implying a contribution that did not happen (sdd.md:L215) —
  and is tested for the *absence* of the accounting effect too
  (`test_AZeroStrategicLegEmitsNoTransfer`).

---

## 10. Adversarial Analysis

### Concerns identified

1. **Stale build claim inside the load-bearing file.**
   [src/Rig.sol:418-420](../../../../src/Rig.sol) states: "The alternative was
   enabling `via_ir` on the monetary core's build, which Sprint 2 deliberately
   left off (`foundry.toml`); one log statement is not a reason to change the
   compilation pipeline." That decision was reversed in this very sprint —
   `foundry.toml` now sets `via_ir = true`. The comment therefore asserts the
   opposite of the delivered configuration, on precisely the topic under
   heightened scrutiny. Its practical cost is that a future maintainer cannot
   tell whether the three stack reductions it justifies are still required under
   the IR pipeline (they are probably no longer necessary). Zero runtime effect;
   recorded as **L-1**.

2. **Constructor does not assert distinctness of its four addresses.**
   [src/Rig.sol:254-260](../../../../src/Rig.sol) rejects zero addresses and
   oversized openings and nothing else. If `treasury == reserve` were ever passed,
   every settlement with a nonzero Strategic leg would revert at the step-8b delta
   check (`D_R = strategicLeg + hardContribution ≠ hardContribution`), bricking
   the throne outside regime 3. This is **unreachable through the accepted genesis
   path** — sdd.md:L158-L166 fixes `reserve = actual₁` and `treasury = predict(4)`,
   structurally distinct, and `GenesisDeployer`'s closing self-verification
   (sdd.md:L187) checks `rig.king() == reserve`. So it is not a defect here; it is
   an **unstated assumption** that belongs on the Sprint-7 wiring-proof checklist.
   §6.4 of the report documents the deliberate minimalism but covers only the
   *economic ordering* of the three openings, not address distinctness. Recorded
   as **I-2**.

3. **`Settled.epochUPS` carries the successor's snapshot, not the settled epoch's.**
   [src/Rig.sol:442](../../../../src/Rig.sol) reads `epochUPS` from storage after
   step 12' has overwritten it. This is deliberate, is pinned by a test
   (`RigPricing.t.sol:233` asserts `r.epochUPS == INITIAL_UPS / 2` for an epoch
   that opened pre-halving), and is consistent with the schema grouping next to
   `nextOpening` (sdd.md:L492). It is also the only reading that makes the field
   useful, since the outgoing epoch's `qRaw` is emitted directly. But the SDD's
   §3.3 `epoch_ups NUMERIC(78,0)` column (sdd.md:L568) carries **no disambiguating
   comment**, so Sprint 6's indexer could reasonably read it the other way.
   Recorded as **I-3** so the ambiguity is closed at the SQL layer before the
   indexer is written, not after.

4. **`redeemSome` can no-op inside the invariant campaign.**
   [test/rig/RigInvariantHandler.sol:117](../../../../test/rig/RigInvariantHandler.sol)
   returns early when the chosen actor holds no VUX. Foundry counts that as a
   non-reverting call, so the ~250 `redeemSome` calls per invariant are an upper
   bound on actual redemptions, and no global assertion pins
   `handler.redemptions() > 0` across a campaign. In practice the settlement mint
   goes to the outgoing King — one of the same four actors — so balances build
   quickly and the path is genuinely exercised; `test_EveryHandlerActionDoesRealWork`
   covers the action itself. Non-blocking, but the cheap hardening for Sprint 4 is
   an `afterInvariant()` asserting each ghost counter advanced.

5. **One near-vacuous assertion.**
   [test/rig/RigFailureBehaviors.t.sol:72](../../../../test/rig/RigFailureBehaviors.t.sol),
   `assertLe(handlerFreeShortfall(sparse), theoreticalMax)`, is trivially true
   (`shortfall ≤ qRaw ≤ theoreticalMax` always). The two assertions above it carry
   FB-3 properly, so the row is not at risk. Recorded as **L-6**.

6. **`optimizer_runs` is now silently load-bearing-adjacent.**
   `forge config` resolves the delivered default profile to `optimizer_runs = 200`
   and `bytecode_hash = "ipfs"` — Foundry defaults, not pinned choices — because
   `optimizer = true` was set without them. That is consistent with the accepted
   plan (deployment bytecode is frozen in Sprints 7–8), but the *character* of
   that future decision has changed: the VUX unit no longer compiles at all under
   the legacy pipeline, so Sprints 7–8 can no longer freely choose it. Worth
   carrying into the Sprint-8 deployment-bytecode freeze as a constraint rather
   than an option. Recorded as **I-1**.

### Assumptions challenged

- **Assumption:** `B_pre > 0` and `S_pre ≥ S_MIN` always hold, so `_vem`'s
  division and `_route`'s `mulDiv` never divide by zero (documented as argued,
  not branched — report §7.2).
  **Risk if wrong:** the settlement reverts instead of minting — a denial of the
  mining right rather than a safety failure.
  **Assessment:** I checked the argument and it holds. `B_pre > 0` because
  genesis funds `B0 > 0` and `redeem` pays `floor(B·q/S)` with `q ≤ S − S_MIN`, so
  draining the whole balance would require `q ≥ S`; `invariant_TheSupplyFloorHolds`
  asserts `backing() > 0` across 16,384 calls. `S_pre ≥ 1` by the same floor. The
  `qRaw == 0` short-circuit in `_route` additionally protects the bootstrap path.
  **Recommendation:** leave as argued. Adding branches here would add unreachable
  code to the monetary core, which is the wrong trade. The assumption is
  documented at the function and is now also on the audit record.

- **Assumption (implicit, worth making explicit):** the `Settled` event's field
  count is fixed at 16 by accepted architecture, so the compilation pipeline must
  bend to it rather than the reverse. The report treats this as settled; I agree,
  but note it is the assumption that *forced* the `via_ir` change, and it is
  therefore the thing an auditor should re-test if they disagree with the outcome
  in §8.

### Alternatives not considered

- **Alternative:** split `Settled` into two events — e.g. a settlement record and
  a successor-epoch record — which would have fit the legacy pipeline with no
  compiler change at all.
  **Tradeoff:** it would have removed the `via_ir` question entirely and reduced
  per-settlement log cost, at the price of forcing every indexer to join two logs
  per settlement to reconstruct one atomic economic event, and of reopening the
  accepted §3.2 schema and the §3.3 SQL table that mirrors it 1:1.
  **Verdict:** the current approach is justified. The event schema is accepted
  architecture that Sprint 6's reconstruction test depends on, the node correctly
  declined to reopen it unilaterally, and the atomicity of one settlement = one
  record is itself a truth-surface property worth preserving. Recording it here so
  the choice is visible rather than absent.

- **Alternative:** keep `currentPrice`/`currentUPS` `external` per the SDD and add
  `_currentPrice()`/`_currentUPS()` internals for `take`.
  **Tradeoff:** literal SDD conformance at the cost of two more functions in the
  contract and a second place for the pricing formula to be edited.
  **Verdict:** current approach is better. The ABI is identical, so SDD
  conformance is preserved where it is observable.

---

## 11. Karpathy principles, complexity, and documentation

| principle | assessment |
|---|---|
| Think Before Coding | **Pass.** §6 of the report surfaces four judgment calls explicitly, including the one that reversed a Sprint-2 decision, and asks the reviewer a direct question rather than proceeding silently. §7 lists five known limitations. The leak in §6.2 is self-reported with the mechanism that caught it |
| Simplicity First | **Pass.** 556 lines for the whole monetary core; the adaptive law is 9 statements; no speculative abstraction. The one added file (`IVUXMintable`) is justified by a structural security argument, not by taste. The unreachable `uint192` clamp is a truncation guard, not speculation, and is disclosed |
| Surgical Changes | **Pass.** Three files modified, each strictly additive, each additively justified in-place. No adjacent code reformatted or "improved". No Sprint-1/2 source touched |
| Goal-Driven | **Pass.** Every AC maps to named tests; `_route`/`_vem` were deliberately kept as named `pure` functions specifically so the `∀`-quantified acceptance properties could be exercised over domains no live settlement can reach — that is goal-driven design, not test convenience |

**Complexity:** `take` is ~100 lines including comments (~45 statements) — above a
50-line guideline, but justified and I am not flagging it: the SDD specifies a
13-step *ordered* outcome, the ordering is the security property (INV-21,
effects-before-final-interactions), and splitting it across helpers for a line
count would obscure exactly what the audit must read. The comment at
`src/Rig.sol:201-205` makes the same argument and it is correct. Nesting never
exceeds 2. No duplication. No dead code. No circular dependencies. Naming is
consistent with the PRD's vocabulary throughout.

**Fast-gate parity:** N/A in the usual sense (no formatter/type-checker
configured for a Foundry project); the equivalent gates — `forge test`,
`forge build`, and `tools/provenance/run-all.sh` — were all re-run by me on the
exact tree, not taken on report.

**Documentation:** no CHANGELOG or CLAUDE.md obligation is triggered (no new
command or skill; the repo has no CHANGELOG under this cycle's conventions).
Security-relevant code is commented at the level the audit needs — the step-8b
double guard, the CEI placement, and the dust-favours-Hard argument are each
explained at their site. No SDD amendment is required (see §9 on `public`).
No documentation-coherence report exists and none is required; no
`subagent-reports/` directory exists, so no blocking subagent verdict is
outstanding. Adversarial cross-model review (Phase 2.5) is **not enabled** —
`.loa.config.yaml` declares no `flatline_protocol` block — consistent with the
Sprint-2 and M-1/L-3/L-4 nodes, neither of which produced an
`adversarial-review.json`.

---

## 12. Non-blocking observations carried to audit

Severity `low` = fix at next artifact touch; `info` = record only, no action this
sprint. **None blocks `/audit-sprint sprint-3`.**

| id | sev | where | observation |
|---|---|---|---|
| **L-1** | low | [src/Rig.sol:418-420](../../../../src/Rig.sol) | Comment states `via_ir` was left off; the delivered `foundry.toml` sets `via_ir = true`. Only stale build claim in `src/` (grep-confirmed). Suggest replacing with a note on whether the three stack reductions remain necessary under the IR pipeline |
| **L-2** | low | `reviewer.md` AC table; `evidence/prohibited-signal-inspection.md` §2/§3 | `src/Rig.sol` line anchors are stale — `_vem` cited at `:487` (actual `:566`, and `:487` lands inside `_route`'s docblock), `_successorOpening` at `:518` (actual `:580`), `_route` at `:500` (actual `:517`), immutables `L96-L131` (actual `L104-L134`), constructor `:255` (actual `:245`), `currentPrice` `:455` (actual `:453`), `currentUPS` `:471` (actual `:466`). Every symbol is named alongside its anchor so nothing is unverifiable, but the auditor's spot-checks will land on the wrong lines. Cross-artifact citations (`prd.md`, `sdd.md`, `HardReserve.sol:L55-L59`) spot-checked and **correct** |
| **L-3** | low | `reviewer.md:41`; `NOTES.md` 2026-08-13 entry | Abbreviated `sprint.md` hash written `6db19ad0…c1f32bfce514`; actual tail is `…c691f1c7c32bfce514`. The full value in `a2a/trajectory/implementing-tasks-2026-08-13.jsonl` is **correct and byte-exact**, so the verification itself was sound — this is a transcription slip in the human-readable abbreviation, repeated twice |
| **L-4** | low | `evidence/prohibited-signal-inspection.md` §7 cmd 2 | Stated expectation "expect only `address public king;`" does not match the command's actual output — the regex also matches the two `address public immutable` lines. The substantive claim (no *mutable* address cell) holds; the expectation text needs the `immutable` caveat or a `grep -v immutable` |
| **L-5** | low | [test/rig/RigRouting.t.sol:22-25](../../../../test/rig/RigRouting.t.sol) | Contract notice claims the universal sweep "reports which regimes it actually reached so a vacuous pass is visible". `testFuzz_TheLawHoldsAcrossAllRegimes` has no such reporting. Regime coverage *is* properly established — by the three dedicated shaped tests, each asserting its shaping landed — so the claim is misattributed rather than false |
| **L-6** | low | [test/rig/RigFailureBehaviors.t.sol:72](../../../../test/rig/RigFailureBehaviors.t.sol) | `assertLe(shortfall, theoreticalMax)` is trivially true; FB-3 is carried by the two assertions above it |
| **I-1** | info | `foundry.toml` `[profile.default]` | `optimizer_runs` (200) and `bytecode_hash` (ipfs) resolve to Foundry defaults, unpinned, and `evm_version` resolves to `prague`. Consistent with the accepted plan to freeze deployment bytecode in Sprints 7–8 — but the VUX unit **no longer compiles under the legacy pipeline**, so that freeze inherits `via_ir = true` as a constraint, not a choice. Also carries the profile-inheritance hazard of §8.4: the `POOL_INIT_CODE_HASH` gate is outcome-based and fails closed (proven live this sprint), so the structural settings-parity guard is correctly deferred — Sprint 8 is its natural home |
| **I-2** | info | [src/Rig.sol:254-260](../../../../src/Rig.sol) | Constructor asserts non-zero but not pairwise-distinct addresses. Unreachable via the accepted genesis order; belongs on the Sprint-7 `GenesisDeployer` wiring-proof checklist as an explicit row |
| **I-3** | info | sdd.md:L568 (`epoch_ups` column) | `Settled.epochUPS` is the **successor** epoch's snapshot (deliberate, tested at `RigPricing.t.sol:233`). The SQL column comment does not say so. Close the ambiguity at the schema before Sprint 6 writes the indexer |

---

## 13. Next steps

Sprint 3 is approved for security audit on the exact tree fingerprinted in §1.

```bash
/audit-sprint sprint-3
```

Audit attention is drawn to §8 (compiler-mode disposition, with the measured
Sprint-2 artifact deltas and the live-evidence argument), §5 (prohibited-signal
structural argument), and observations **L-1**, **I-1**, and **I-2**.

No implementation change is required to proceed.

### Sprint-plan bookkeeping applied — and the hash change it causes

Per the native review flow and the convention this repo records for Sprint 1
("`sprint.md`'s hash changed when the Sprint-1 checkboxes were ticked **on
approval**, criteria text unchanged" — `a2a/index.md`), the Sprint-3 checkboxes
in `grimoires/loa/sprint.md` are ticked at this gate: **4 deliverables + 8
acceptance criteria + 7 technical tasks = 19 boxes**, all within L236–L290.

The audit node re-hashes the authority chain, so the consequence is stated here
rather than left to be discovered:

| | SHA-256 |
|---|---|
| `sprint.md` before ticking (the value pinned in `reviewer.md` §1, `NOTES.md`, and the trajectory log) | `6db19ad09a2da42dbdf4847535b2a73890079efa0d91ebc691f1c7c32bfce514` |
| `sprint.md` after ticking (current) | `bcaebd18f8cc5b35c28ee23745cf7b07945c82bd66df589e1eccaf0eabaa5557` |

**The change is confined to checkbox characters.** `git diff --numstat` reports
`19 19` — a line-for-line replacement with no insertion or deletion — every one
of the 19 edits changed exactly one character (`[ ]` → `[x]`), and the first
remaining `- [ ]` in the file is at L301, inside Sprint 4. No criterion, task,
deliverable, or authority-chain row was altered. Sprint Plan version stays
**v1.1.1**.

Two downstream consequences the auditor should expect, both pre-existing
convention rather than defects:

1. `diff <(sed -n '236,290p' grimoires/loa/sprint.md) grimoires/loa/a2a/sprint-3/sprint-3-scope.md`
   — the byte-exactness check at `reviewer.md` §8.8 — **now differs on exactly
   those 19 checkbox characters**. I verified it was byte-exact **before**
   ticking (§2 above). `sprint-3-scope.md` is the pre-approval slice, the same
   status `a2a/index.md` already records for `sprint-1-scope.md` and
   `sprint-2-scope.md` (the latter holds 0 `[x]` / 16 `[ ]` against a fully
   ticked landed Sprint-2 section). Its own hash `1584e2e1…e8a815b6` is
   unchanged, and `validate-ac-verification.sh` still exits 0 against it.
2. Re-hashing `sprint.md` at the audit node yields `bcaebd18…` and not the value
   recorded in `reviewer.md` §1. That is this gate's bookkeeping, not drift.

---

*Reviewed by the Loa `/review-sprint sprint-3` node, cycle-002, 2026-08-13. Every*
*claim above was re-derived on the exact tree; nothing was accepted on report.*

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":6},"sprint_id":"sprint-3","ts":"2026-08-13T18:16:01Z"} -->
