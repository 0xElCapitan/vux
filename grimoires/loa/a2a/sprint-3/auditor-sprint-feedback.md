# Security Audit — Sprint 3 (cycle-002): Rig, the accumulated VUX monetary core

**Gate:** `/audit-sprint sprint-3` (Paranoid Cypherpunk Auditor)
**Date:** 2026-08-13
**Posture:** audit-only. No implementation, test, planning, or authority mutation.
**Verdict:** **APPROVED - LET'S FUCKING GO**

---

## 1. Exact audited subject identity

The audit consumed the working tree, not the committed baseline. Sprint-3
implementation is uncommitted; these hashes fix what was actually read.

**Repository:** canonical VUX repo · **branch** `sprint-3`
**HEAD baseline:** `bc5dedc2025921221407cd85f5ec1e6d40ad7a7b`
**Toolchain (verified running):** `forge 1.5.0` @ `1c57854462289b2e71ee7654cd6666217ed86ffd`; solc `0.8.28+commit.7893614a` / `0.7.6+commit.7338295f`

| file | SHA-256 (16) | git state |
|---|---|---|
| `src/Rig.sol` | `f0377bf95432a388` | new (untracked) |
| `src/interfaces/IVUXMintable.sol` | `b19f15a50e5f75b4` | new (untracked) |
| `src/VUX.sol` | `5686c4c7c3537119` | **unchanged vs HEAD** |
| `src/HardReserve.sol` | `74b8319ab155225b` | **unchanged vs HEAD** |
| `src/interfaces/IVUX.sol` | `3910bf9d440a1755` | **unchanged vs HEAD** |
| `foundry.toml` | `74d5be36d3935e47` | modified |
| `test/harness/Vm.sol` | `ade0f71b56d6dcf8` | modified (additive) |
| `test/mocks/MockWeth.sol` | `ed5a32c5b7607244` | modified (additive) |
| `test/rig/RigBootstrap.t.sol` | `14ace3d5c2c05b99` | new |
| `test/rig/RigFailureBehaviors.t.sol` | `74810348c1648593` | new |
| `test/rig/RigFixture.sol` | `f0e550774db4f5d9` | new |
| `test/rig/RigInvariantHandler.sol` | `4650f1583872f645` | new |
| `test/rig/RigInvariants.t.sol` | `9a2bef47a77040aa` | new |
| `test/rig/RigMathHarness.sol` | `154d63b807afaa08` | new |
| `test/rig/RigPricing.t.sol` | `bf7fc492eecdbde3` | new |
| `test/rig/RigRouting.t.sol` | `3aae98d23b2fcd98` | new |
| `test/rig/RigSettlement.t.sol` | `bdd0e2f6638be1f1` | new |
| `test/rig/RigVem.t.sol` | `abc54e23df0847d6` | new |

**Inbound artifact chain (hashes confirmed against the operator's stated values):**

| artifact | SHA-256 (16) | status |
|---|---|---|
| `grimoires/loa/a2a/sprint-3/engineer-feedback.md` | `656e430f36e5171f` | matches stated `656e430f…` ✓ |
| `grimoires/loa/sprint.md` | `bcaebd18f8cc5b35` | matches stated `bcaebd18…` ✓ |
| `grimoires/loa/a2a/sprint-3/reviewer.md` | `fd32d39a0b111469` | implementation artifact |
| `grimoires/loa/a2a/sprint-3/sprint-3-scope.md` | `1584e2e1d948fb61` | scope record |

Review verdict trailer read from the artifact: `{"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":6}}`.
`sprint.md`'s diff against HEAD is **19 `[ ]`→`[x]` checkbox flips and nothing else** — confirmed
review-state mutation, not implementation drift. No `COMPLETED` marker exists.

---

## 2. Findings by severity

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 8 |

**No exploitable defect, monetary-integrity defect, authority escalation, or
provenance violation was found.** All eight LOW findings are documentation,
deployment-parameter, or cosmetic class; five confirm the review's non-blocking
observations, three are new. None requires a Sprint-3 change.

### LOW-1 — stale `via_ir` claim in `_emitSettled` NatSpec *(confirms review)*

`src/Rig.sol:418-420` states the alternative "was enabling `via_ir` on the
monetary core's build, which Sprint 2 deliberately left off (`foundry.toml`);
one log statement is not a reason to change the compilation pipeline." The
delivered unit **does** enable `via_ir` (`foundry.toml:69`). The comment
describes a decision the same commit reverses.

*Security consequence:* none. Documentation only. Correct at the next
documentation touch; do not mutate during audit.

### LOW-2 — stale line anchors in Sprint-3 evidence *(confirms review)*

`evidence/prohibited-signal-inspection.md` §3 cites `_route` at L500-L516 and
`_vem` at L487-L493; actual positions are **L517-L530** and **L566-L573**.

*Security consequence:* none. Every claim in that artifact was re-derived
independently against the exact tree (§5 below) and holds.

### LOW-3 — the Sprint-7/8 freeze inherits `evm_version` as well as `via_ir` *(confirms and sharpens review)*

The review noted the future bytecode freeze inherits `via_ir = true`. Audit
adds the more consequential half: `evm_version` is **unset** in
`[profile.default]` and therefore resolves to the pinned toolchain's default —
`forge config` reports **`evm_version = "prague"`**. The compiled VUX-unit
runtime already contains post-Istanbul opcodes:

| contract | runtime opcodes |
|---|---|
| `Rig` | PUSH0 ×63 (Shanghai) |
| `VUX` | PUSH0 ×107, **MCOPY ×1** (Cancun) |
| `HardReserve` | PUSH0 ×35 |
| `UniswapV3Pool` (v3core) | SAR ×3 only — Istanbul-clean ✓ |

This is **pre-existing, not Sprint-3-introduced** — see §6, where the legacy
build of the same unchanged sources is shown to contain the same MCOPY. The
`foundry.toml` rationale is sound (`evm_version` is an R-14 deployment fact).
The observation is that *"unset" is not "neutral"*: it silently tracks the
toolchain default, and the artifacts already assume Shanghai+Cancun opcode
support.

*Security consequence:* none in Sprint 3. *Carried obligation:* the Sprints 7–8
freeze must pin `evm_version` explicitly against verified Robinhood-Chain opcode
support, not leave it to inheritance. Deploying Cancun bytecode to a pre-Cancun
chain fails at deploy time (fail-closed), so this is a launch-readiness item,
not a latent runtime hazard.

### LOW-4 — `Settled.epochUPS` is the successor snapshot *(confirms review)*

`_emitSettled` reads `epochUPS` from storage *after* the step-12' write, so the
field carries the **incoming** epoch's rate, not the settled reign's. This is
correct per the accepted schema (SDD §3.2 groups it with `nextOpening`) and is
documented at `src/Rig.sol:422-424`, but the field name alone is ambiguous.

*Security consequence:* none. Indexer-semantics risk only. Make explicit before
Sprint 6.

### LOW-5 — `currentPrice`/`currentUPS` are `public view`, SDD says `external view` *(confirms review)*

`sdd.md:687-688` declares both `external`. Audit confirms the ABI entry,
selector, and `stateMutability` are identical, and adds that **`public` is
required by the implementation as written**: `take` calls both internally
(`src/Rig.sol:317, 388`), which `external` would force into a `this.` self-call.

*Security consequence:* none. Implementation-equivalent. The SDD text is the
party that should move, not the code.

### LOW-6 — `decayFloor_` is the one constructor parameter with no bound *(new)*

`src/Rig.sol:259-260` bounds `bootstrapOpening_` and `minimumOpening_` against
`type(uint192).max`; `decayFloor_` is bounded at neither end.

Audit verified this **cannot** cause silent truncation: `_successorOpening`
clamps to `type(uint192).max` before the cast at `src/Rig.sol:387`, and
`MINIMUM_OPENING` is constructor-bounded, so `epochOpening` is always in range
regardless of `DECAY_FLOOR`. Monetary integrity also holds: a `DECAY_FLOOR = 0`
deployment yields `P = 0` settlements that route three zero legs, measure
`D_R = 0`, and mint zero — fail-safe, no value leak.

Two degenerate configurations are nonetheless reachable by deployment parameters
alone:

- `DECAY_FLOOR = 0` — the throne becomes free 3,000 s into every epoch.
- `DECAY_FLOOR > MINIMUM_OPENING` — the "floor" exceeds the successor opening,
  so `currentPrice` returns `DECAY_FLOOR` for the whole epoch and the Dutch ramp
  is inverted.

Both are R-14 deployment-time facts the constructor deliberately declines to
police (`src/Rig.sol:233-240`), with the economic ordering assigned to
`GenesisDeployer`'s closing self-verification (SDD §1.4, Sprint 7). That
deferral is a legitimate accepted design position, and the audit does not
reopen it.

*Recommendation (Sprint 7, not Sprint 3):* have the deployer assert
`0 < DECAY_FLOOR ≤ MINIMUM_OPENING ≤ BOOTSTRAP_OPENING` alongside the existing
`P0/N0` and cushion checks.

### LOW-7 — `treasury == reserve` is not rejected at construction *(new)*

The constructor rejects zero addresses but not aliasing between the four
dependency addresses. If genesis were misconfigured with `treasury == reserve`,
the step-7 Strategic transfer would inflate the measured Hard delta and every
settlement carrying a non-zero Strategic leg would revert on
`InconsistentReserveDelta`.

*Security consequence:* none — the failure mode is a **fail-closed brick**, not
a value leak or an accounting corruption, and the `D_R` rejection is precisely
the control that catches it. Same R-14 / Sprint-7 deployer-assertion class as
LOW-6.

### LOW-8 — zero-transfer skip is applied to the Strategic leg but not the Hard leg *(new)*

Step 7 skips a zero Strategic transfer to avoid emitting a misleading ERC-20
`Transfer` (`src/Rig.sol:344-345`); step 8a applies no such skip to the Hard leg
(`src/Rig.sol:355`).

Audit verified the asymmetry is **unreachable for every `P ≥ 1`**: `hardFloor =
ceil(0.2P) − floor(0.12P) ≥ 1` for all `P ≥ 1`, so a zero Hard transfer requires
`P = 0`, which requires the `DECAY_FLOOR = 0` configuration of LOW-6.

*Security consequence:* none. Cosmetic.

---

## 3. Monetary core — accumulated `Rig + VUX + HardReserve`

### 3.1 Adaptive routing law — exact match to accepted authority

The frozen law was compared character-by-character against the controlling
delta (`vux-v1-canonical-specification-adaptive-routing-supersession-2026-08.md`
L19-L25, restated at `prd.md:L368` FR-4.1 and `INV-18`):

| authority | `src/Rig.sol` `_route` (L517-L530) | |
|---|---|---|
| `king = floor(P × 8,000 / 10,000)` | `(price * SPLIT_KING_BP) / BP_DENOM` | ✓ |
| `retained = P − king` | `price - kingLeg` | ✓ |
| `strategicCap = floor(P × 1,200 / 10,000)` | `(price * STRATEGIC_CAP_BP) / BP_DENOM` | ✓ |
| `hardFloor = retained − strategicCap` | `retained - (…)` | ✓ |
| `D_need = ceil(Qraw × B_pre / S_pre)` | `Math.mulDiv(qRaw, bPre, sPre, Rounding.Ceil)` | ✓ |
| `hardTarget = min(retained, max(hardFloor, D_need))` | `Math.min(retained, Math.max(hardFloor, dNeed))` | ✓ |
| `strategic = retained − hardTarget` | `retained - hardTarget` | ✓ |

Structural properties verified by derivation, not assertion:

- **Exhaustion.** `king + hardTarget + strategic == price` identically, since
  `hardTarget + strategic ≡ retained` by construction. No dust can strand in the
  Rig — confirmed empirically by `invariant_TheRigHoldsNoValue` (16,384 calls).
- **Dust favours Hard (INV-19).** `retained = ceil(0.2P)` absorbs the King leg's
  flooring remainder while `strategicCap` floors downward, so both rounding
  losses accrue inside `hardFloor`.
- **`hardFloor` cannot underflow.** `retained ≥ 0.2P > 0.12P ≥ strategicCap` for
  every `P`, including `P = 0` (all three are 0).
- **The ceil/floor pairing is exact, not merely conservative.** With
  `hardTarget = D_need = ceil(Qraw·B/S)`, it follows that
  `Qsafe = floor(D_need·S/B) ≥ Qraw`, so the middle regime always delivers the
  **full** raw opportunity. Rounding `D_need` down would silently under-deliver
  it. This is the load-bearing reason the rounding directions are opposed.

### 3.2 VEM frontier and the equality case

`_vem` (L566-L573) implements `Qsafe = floor(D_R × S_pre / B_pre)`,
`Qmint = min(Qraw, Qsafe)` with `Math.mulDiv`'s 512-bit intermediate.

Non-dilution (INV-13) verified algebraically:
`Qmint ≤ floor(D_R·S_pre/B_pre) ⟹ B_pre·Qmint ≤ D_R·S_pre ⟺ (B_pre+D_R)/(S_pre+Qmint) ≥ B_pre/S_pre`.

**The equality case is correct and intended.** `FR-5.3` states the frontier as
`≥` and adds verbatim: *"Equality permits full `Qraw`."* An implementation
enforcing strict increase would deny lawful issuance. Asserted on every
settlement by the handler (`assertLe(bPre * qMint, dR * sPre)`), and swept by
`testFuzz_IssuanceCannotReduceBackingPerUnit` and
`testFuzz_LiveSettlementNeverReducesBackingPerUnit`.

Overflow safety: `Math.mulDiv` is used precisely because reverting on the
intermediate would **deny** the mining right rather than cap it — the correct
reasoning, and exercised by `testFuzz_TheCapSurvivesAnOverflowingIntermediate`.

Division-by-zero posture is fail-closed and correct: `B_pre = 0` reverts rather
than minting against unmeasurable backing. Audit confirmed `B` cannot reach zero
from positive — redemption pays `floor(B·q/S)` with `q ≤ S − S_MIN`, leaving
`B' ≥ ceil(B/S) ≥ 1`.

### 3.3 Cross-contract interactions and manipulation attempts

| attempted manipulation | outcome |
|---|---|
| Donate WETH to the Reserve before a `take` to suppress a rival's mint | Raises `B_pre` → raises `D_need` (more capital to Hard) and lowers `Qsafe`. Costs the attacker real WETH that permanently raises backing for all holders. Economically self-defeating; tested by `test_ADonationRaisesBackingAndMintsNothing` + the `donateToReserve` handler action. |
| Redeem immediately before a `take` to shrink `B_pre` and inflate `Qsafe` | Redemption's floor rounding makes `S'/B' ≤ S/B`, so `Qsafe` can only *decrease*. Verified at the extreme (`q = S − S_MIN`): `S' /B' = 1/ceil(B/S) ≤ S/B`. Non-inflatable. |
| Inflate `S_pre` to inflate `Qsafe` | `S` grows only through the VEM-capped mint itself and the one-shot genesis. No path. |
| Donate WETH to the Rig | Rig never reads its own balance; funds are inert. No accounting effect. |
| Re-enter `take` from inside a WETH transfer | `nonReentrant` reverts. Tested for real with a generalised re-entry probe (`MockWeth.setReentryCall` → `Rig.take`), asserting the guard's own selector. |
| Under-deliver the Hard leg (fee-on-transfer WETH) | `D_R != hardContribution` → `InconsistentReserveDelta`, whole settlement unwinds. Tested. |
| Over-deliver the Hard leg (balance inflation) | Same rejection fires in the opposite direction — the check is equality, not `≥`. Tested. |
| Reduce the Reserve balance during settlement | `weth.balanceOf(reserve) - s.bPre` underflows and reverts before the equality check. |
| Reseat the Reserve as King to re-bootstrap (resetting `scheduleStart` and the halving schedule) | Structurally impossible. `HardReserve`'s entire mutating surface is `redeem`; its runtime contains exactly 2 CALLs (WETH transfer, `burnForRedemption`), no approve, no arbitrary call. Confirmed at bytecode level, plus `test_NoSecondBootstrapStateIsReachable`, `test_AFabricatedReserveInitiatedTakeStillCannotReseatTheReserve`, and `invariant_AtMostOneBootstrapSettlementEverOccurs` (16,384 calls). |
| Front-run a contender to raise their price | Bounded by `max(DECAY_FLOOR, opening)` with `opening ≤ 2×P_prev`; `maxPrice` is the complete slippage statement. The deliberate omission of `deadline`/`epochId` guards is correct — an epoch-id guard would let a griefer invalidate honest transactions by taking first. Tested by `test_MaxPriceProtectsAgainstASameBlockLadderRise`. |
| Self-take repeatedly to farm mint | Bounded by VEM (non-dilution holds every settlement) and by the 2× successor ladder. This is the intended "greed capitalizes the Reserve" dynamic; `test_FB4_HighDemandCapsIssuanceAndRaisesBackingPerUnit` asserts `B/S` strictly rises. |

### 3.4 Clock, pricing, and boundary arithmetic

- `currentPrice` is written as `opening − opening·t/3000`, flooring the
  *subtrahend* and therefore rounding the **price up** — the Reserve-favouring
  direction, consistent with INV-16. Monotone non-increasing across the
  `elapsed == EPOCH_PERIOD` join (no upward jump), with the boundary tested from
  both sides (`test_TheExpiryJoinDoesNotFireOneSecondEarly`).
- `opening * elapsed` cannot overflow: the `elapsed >= EPOCH_PERIOD` early
  return bounds `elapsed < 3000` and `opening ≤ 2^192`.
- `Qraw = min(elapsed, 3000) × epochUPS` — caps exactly, no carry
  (`test_TimeBeyondTheCapCreatesNoCarry`, `test_QrawOneSecondShortOfTheCapIsOneSecondShort`).
- Halving: `INITIAL_UPS >> min((t − scheduleStart)/30 days, 8)`. Tail is produced
  by clamping the shift, so no separate constant can drift.
  `4/256 = 0.015625` ✓. All nine boundary values asserted against the frozen
  table (`test_UpsMatchesTheFrozenTableAtEveryHalvingBoundary`).
- **Bootstrap/zero-clock degeneracy.** `epochUPS = 0` at genesis *and* the
  `king == reserve` test independently forces `Qraw = 0` — two independent
  guarantees. At the bootstrap settlement `currentUPS()` is evaluated **before**
  `scheduleStart` is written, so the first public epoch snapshots `INITIAL_UPS`;
  audit confirms the result is identical either way, so the ordering is not
  fragile.
- **No prohibited signal is readable.** `_route` and `_vem` are `pure` —
  compiler-enforced proof that their parameters are the complete input set.
  Independently reproduced: exactly 2 `pure` matches; the only non-immutable
  address cell is `king`; every prohibited-vocabulary grep hit is in NatSpec
  describing an *absence*, never in code.

### 3.5 Settlement ordering and atomicity (INV-21)

The 13-step order was compared against `sdd.md:L196-L229` step by step and
matches exactly, including the two load-bearing placements: the outgoing
identity (`outgoingKing`, `epochId`, `bootstrap`) is captured at steps 1-2
before any write, and step 12' commits successor state before the mint and the
outgoing King transfer. No `try`/`catch`, no partial-success path.

Verified empirically: `test_SuccessorStateCannotRewriteTheOutgoingEpoch`,
`test_EachReignIsMintedExactlyOnceToItsOwnKing`,
`test_FailingAnyOneLegUnwindsTheWholeSettlement` (each leg failed
independently), `test_AFailingMintUnwindsTheSettlement`,
`test_TheRejectionUnwindsEveryLeg`, plus the per-settlement handler assertions
`epochId == epochIdPre` and `recordOutgoing == outgoingKing` on all 16,384 calls.

**No carry, debt, IOU, or high-water cell exists (FR-5.5).** Confirmed three
ways: the compiled storage layout has exactly seven declared cells plus the
inherited guard slot (§4), `test_NoStorageCellRecordsTheUnmintedRemainder` scans
raw slots 0-9 via `vm.load` for both the shortfall and `Qraw`, and the next
epoch's opportunity is asserted to inherit nothing.

---

## 4. Authority surface — structural absence

`Rig`'s complete external ABI is **26 entries, of which `take(uint256)` is the
only state-changing function**. No `receive`, no `fallback`, no payable
function. Independently enumerated from `out/Rig.sol/Rig.json` and matched
two-way against the accepted list in
`test_TheRigExternalSurfaceIsExactlyTheAcceptedOne`.

Independent runtime-bytecode opcode census (metadata stripped), performed by
audit because `tools/provenance/inspect-runtime-surface.sh` covers only
`HardReserve` and `VUX`:

| contract | CREATE | CREATE2 | CALLCODE | DELEGATECALL | SELFDESTRUCT |
|---|---|---|---|---|---|
| `Rig` (4,466 B body) | 0 | 0 | 0 | **0** | **0** |
| `HardReserve` (1,710 B body) | 0 | 0 | 0 | **0** | **0** |

No owner, role, pause, upgrade, proxy, initializer, sweep, rescue,
recapitalization, arbitrary-call, or hidden mutable-authority path exists in
either contract. Asserted against the compiled method-identifier table with a
positive control so a broken lookup cannot masquerade as an absence
(`test_FB15_FB16_TheRigExposesNoRescueOrRecapitalizationPath`).

Compiled storage layout matches the accepted layout at `sdd.md:L109-L122`
exactly — `king`+`epochStart` packed in slot 1, `epochOpening` slot 2,
`epochUPS` slot 3, `scheduleStart`+`epochId` packed in slot 4,
`totalStrategicContributed` slot 5, with OZ `ReentrancyGuard._status` at slot 0.
`HardReserve` declares **no storage of its own** beyond the guard slot — INV-10
("`B` is the physical balance") is structural, not asserted.

---

## 5. Test and invariant evidence — re-run, not read

All results below were produced by this audit against the exact tree.

| run | result |
|---|---|
| `forge build` | clean (lints/notes only) |
| `forge test` (default profile) | **144 passed, 0 failed, 0 skipped** — 13 suites |
| `FOUNDRY_PROFILE=ci forge test` | **144 passed, 0 failed, 0 skipped** |
| CI fuzz depth | **10,000 runs** confirmed on the redemption property suites |
| CI invariant depth | **9 invariants × 256 runs × 16,384 calls, 0 reverts** |
| `tools/provenance/run-all.sh` | **All provenance gates and tests passed** |

**Anti-vacuity is real, not claimed.** `fail_on_revert = true` with **0 reverts
across 16,384 calls per invariant** means the handler genuinely shaped every
input rather than degenerating into no-ops; `effectiveCalls` plus
`test_EveryHandlerActionDoesRealWork` make the degeneration visible if it ever
starts. The routing suite **constructs** each of the three adaptive regimes by
shaping `qRaw` against the tuple rather than filtering with `vm.assume`, and
checks each against an independent native-arithmetic oracle — so a claimed run
count is an exercised run count.

The handler asserts INV-4, 6, 7, 9, 12, 13, 18, 19, 20, 21 and 22 on **every
individual settlement**, which is materially stronger than state-only
invariants: leg exhaustion, the `hardFloor ≤ hardTarget ≤ retained` bracket, the
Strategic cap, mint-recipient correctness, and the outgoing-epoch identity are
all facts only observable at the operation.

Negative coverage is genuinely adversarial: `MockWeth` gained fee-on-transfer
(under-delivery), a minted `transferBonus` (over-delivery), per-address failure
(one leg at a time), and a generalised re-entry probe that bubbles the inner
revert so a missing guard cannot look like a pass.

---

## 6. `via_ir` compiler-mode transition — independent disposition

The operator directed the audit not to reopen the runtime-hash change, but to
determine whether the `via_ir`-compiled accumulated core has any
**security-relevant semantic difference not caught by the review evidence**.
Audit performed a test the review did not: it recompiled the *unchanged*
Sprint-1/2 sources under the **legacy** pipeline into a scratch directory
(no repository mutation) and diffed the result.

| contract | pipeline | body size | opcode classes present |
|---|---|---|---|
| `VUX` | legacy | 4,266 B | PUSH0 ×109, **MCOPY ×1** |
| `VUX` | `via_ir` | 3,774 B | PUSH0 ×107, **MCOPY ×1** |
| `HardReserve` | legacy | 1,959 B | PUSH0 ×64 |
| `HardReserve` | `via_ir` | 1,710 B | PUSH0 ×35 |

**Conclusions, on exact-tree evidence:**

1. **`via_ir` introduces no new opcode class.** MCOPY is present in *both*
   builds; PUSH0 counts only decrease. No CREATE/CREATE2/CALLCODE/DELEGATECALL/
   SELFDESTRUCT appears in either. The Shanghai/Cancun opcodes are a function of
   `evm_version`, **not** of the pipeline change — which relocates that concern
   to LOW-3 (pre-existing) and removes it from the Sprint-3 change surface.
2. **ABIs are byte-identical** across pipelines for both contracts.
3. **Storage layouts are unchanged** (§4).
4. **All Sprint-2 structural-absence guarantees re-establish on the current
   `via_ir` artifacts** — `inspect-runtime-surface.sh` confirms the exact
   accepted external sets (HardReserve 6, VUX 20), `burnFrom` absent from the
   dispatcher, and the sanitization marker present in creation bytecode but
   **absent from deployed runtime**.
5. **The legacy pipeline genuinely cannot build this tree** — audit reproduced
   the failure independently (`Stack too deep … Try compiling with --via-ir`),
   corroborating the necessity claim rather than accepting it on report.

The size reduction and instruction rescheduling are the expected and only
observable effects. `via_ir = true` is accepted as part of the current VUX-unit
build identity.

---

## 7. Provenance, frozen-unit boundary, and default-deny

| check | result |
|---|---|
| Sprint-1/2 protected source unchanged | ✓ `git diff HEAD` empty for `src/VUX.sol`, `src/HardReserve.sol`, `src/interfaces/IVUX.sol`, and all of `vendor/` |
| Vendored census byte-identity | ✓ 63/63 files byte-identical to accepted registry |
| Repository source boundary (default-deny) | ✓ 89 files classified, **0 unauthorized**; 0 reachable only through the compiler |
| Excluded-source detection | ✓ no v3-periphery, no `UniswapV3Factory` implementation, Miner Manifold reuse limited to the 3 allowlisted files, no prohibited-source reference |
| Toolchain pins | ✓ Foundry v1.5.0 @ 40-char commit; all artifacts compiled by the pinned solc builds; no mutable refs or short SHAs |
| Quarantine | ✓ all 8 reserved-value classes clean |
| **`POOL_INIT_CODE_HASH`** | ✓ **reproduced and equal** to `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`; CBOR tail confirms `bytecode_hash = none` |

**v3-core compiler-mode containment — independently confirmed empirically.**
Resolved profile settings, not just the file text:

| setting | `[profile.default]` | `[profile.v3core]` |
|---|---|---|
| `via_ir` | `true` | **`false`** |
| `solc` | 0.8.28 | 0.7.6 |
| `evm_version` | `prague` (default) | **`istanbul`** |
| `optimizer_runs` | 200 | **800** |
| `bytecode_hash` | `ipfs` | **`none`** |

The frozen unit's complete bytecode-affecting set is pinned explicitly and
nothing reaches it by inheritance. The opcode census corroborates this from the
other direction: the pool runtime is Istanbul-clean (SAR only), containing none
of the PUSH0/MCOPY that the VUX unit carries.

The `via_ir = false` line in `[profile.v3core]` is genuinely load-bearing, and
the sequence that produced it — inheritance leak introduced, caught by
`verify-init-code-hash.sh` failing closed, contained explicitly — is refreeze §7
obligation 3 working as designed. **The proposed structural guard against
inherited profile settings remains out of Sprint-3 scope:** the current tree
demonstrably does *not* fail closed-source or frozen-bytecode guarantees without
it, which is the condition the operator set for pulling it in.

---

## 8. Doctrine check — FAIR · SIMPLE · ELEGANT · SECURE

- **FAIR** — `take` is permissionless with no allowlist, identity gate, or
  privileged path; no deployer, founder, or operator receives bootstrap WETH,
  VUX, a free clock, or a free reign (`test_NoPrivilegedPartyReceivesBootstrapValue`).
  Unsupported opportunity expires for everyone identically.
- **SIMPLE** — one mutating entry point; two `pure` formulas carrying the entire
  monetary law; no owner, no config, no second path. `HardReserve` holds no
  storage at all.
- **ELEGANT** — the adaptive law degenerates to the prior static split at
  `Qraw = 0` with **no special case** in the code, which is exactly what the
  accepted delta specifies; the tail is produced by clamping a shift so it
  cannot drift from its constant; bootstrap is detected as `king == reserve`
  rather than by a flag.
- **SECURE** — issuance is bounded by physically measured reality and rejects
  any disagreement with intent; rounding favours the Reserve at every step;
  atomicity is the transaction boundary; the authority surface is empty by
  construction and verified against compiled bytes.

---

## 9. Accepted residual risk

- **Canonical WETH is trusted for balance accounting.** `B` is *defined* as
  `WETH.balanceOf(reserve)`, so a hostile WETH that lied about balances could
  forge `D_R`. This is outside the accepted trust model and is the disclosed
  YELLOW dependency (INV-36, PRD §13). The `nonReentrant` + measured-delta +
  equality-rejection posture is the correct defence against everything *inside*
  the model (hooks, fee-on-transfer, over-crediting), and all three are tested.
- **Deployment-parameter correctness is an R-14 / Sprint-7 obligation** (LOW-6,
  LOW-7). The Sprint-3 contract deliberately validates only what is structurally
  load-bearing for itself.
- **`StrategicTreasury` is a plain address in Sprint 3.** Per `sdd.md:L138` and
  the Sprint-3 Dependencies, the Strategic leg is a plain WETH transfer with no
  callback and no authority in either direction; `Rig.totalStrategicContributed`
  carries the accounting until Sprint 4.

---

## 10. Verdict

Zero critical, zero high, zero medium. Eight LOW findings, none with a security
consequence and none requiring a Sprint-3 change. The adaptive routing law and
VEM match accepted authority character-for-character; settlement ordering and
atomicity match the accepted 13-step outcome exactly; the authority surface is
empty as verified against compiled bytes; the frozen v3-core unit is
byte-reproducible and provably insulated from the compiler-mode change; and the
`via_ir` transition is shown — by direct legacy-vs-IR comparison of the
unchanged sources — to introduce no new opcode class, no ABI change, and no
storage-layout change.

**APPROVED - LET'S FUCKING GO**

### Recommended next node

Operator acceptance / Sprint-3 landing preparation.

This audit deliberately did **not**: create the `COMPLETED` marker, update the
Sprint Ledger status, commit, push, merge, or begin Sprint 4. Sprint closure is
an operator-gated lifecycle step and is left to the operator.

### Carried to later sprints (no Sprint-3 action)

| item | owner |
|---|---|
| Pin `evm_version` explicitly against verified RH-chain opcode support (LOW-3) | Sprints 7–8 bytecode freeze |
| Deployer assertion `0 < DECAY_FLOOR ≤ MINIMUM_OPENING ≤ BOOTSTRAP_OPENING`, and dependency-address distinctness (LOW-6, LOW-7) | Sprint 7 `GenesisDeployer` |
| Make `Settled.epochUPS`'s successor semantics explicit (LOW-4) | before Sprint 6 indexer work |
| Correct the stale `_emitSettled` `via_ir` comment (LOW-1) and evidence line anchors (LOW-2); reconcile SDD `external`→`public` for the two views (LOW-5) | next documentation touch |

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":8},"sprint_id":"sprint-3","ts":"2026-08-13T19:16:00Z"} -->
