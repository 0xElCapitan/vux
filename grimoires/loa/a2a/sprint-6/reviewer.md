# Sprint 6 — Truth Surfaces: Lens, Indexer & Truthful UX — Implementation Report

**Status:** **`SPRINT_6_IMPLEMENTED_READY_FOR_REVIEW`**
**Branch:** `sprint-6` · **Baseline:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377` (= `master` = `origin/master`, unchanged — no commit made)
**Date:** 2026-08-14 (pass 1 implementation · pass 2 HITL reconciliation · pass 3 acceptance + Tasks 6.4–6.8)
**Node:** `/implement sprint-6` — implementation only. No review, audit, operator acceptance of the sprint, landing, commit, push, or Sprint-7 work performed.

**Subject fingerprints** (derived from git, `evidence/subject-manifest.md`):

| Group | Files | Fingerprint |
|---|---|---|
| A — implementation subject | 45 | `20289436748666ca…` |
| B — activated authority | 2 | `1e6515cc1c79f553…` |
| C — lifecycle evidence | 8 | `53f221702be5c571…` |

---

## Executive Summary

Sprint 6 is implemented. All eight tasks are complete; all eight acceptance criteria are met.

The sprint ran in three passes because Task 6.1 is a fail-closed intra-sprint operator gate. Pass 1
did the work the gate does not govern (Tasks 6.2, 6.3) and produced the pin census. Pass 2 consumed
the operator's D-1/D-2 disposition and completed the census. Pass 3 recorded acceptance, activated the
refreeze, discharged the deferred RSC verification, and implemented Tasks 6.4–6.8.

**Seven gates, all green:**

| Gate | Result |
|---|---|
| `forge test` | **397 passed, 0 failed** |
| indexer unit tests (`node --test`) | **11 passed** |
| **independent reconstruction, live chain** | **PASS** — S, B, B/S, legs and all burn causes match chain state, 0 ambiguities |
| accepted-pins standing gate | **PASS** — both roots equal the accepted census; 0 unmet required peers |
| bundled RSC runtime verification | **PASS** — vendored transports postdate the fix floor by ~7 weeks |
| static-export / no-server posture | **PASS** — no server bundle, 0 Server Function call sites |
| Playwright copy suite | **25 passed** |

**The reconstruction claim is proven end to end, not asserted.** A scripted eight-operation scenario
runs on a live anvil chain; the reconstruction side calls `eth_getLogs` and nothing else, the truth
side calls `eth_call` and nothing else, and neither can borrow the other's answer. They agree exactly
on `S`, `B`, `B/S`, every settlement's legs, and every burn cause. Idempotency (3× replay),
order-independence, prefix-stability, and a **real anvil snapshot/revert reorg** all hold.

**Two things found by building rather than by reading**, both recorded rather than smoothed:

- The static-export gate **failed on first run**, flagging `createServerReference` in a client chunk.
  Triage showed the RSC client runtime is bundled by Next unconditionally and the hit was its
  *definition*, with zero server-reference markers — defining the capability is not using it. The
  detector was sharpened to count call sites separately from definitions, not relaxed.
- The Playwright suite **failed on first run** with four failures. Three were an over-broad test of
  mine — FR-15.2 bans the affirmative predication, not the words, and tier-2's own mandated label
  contains "not claimable" while the verbatim contestability claim contains "user-owned VUX". The
  fourth was a **real defect**: the `strategic_nav_disclosed` naming sat behind the data-availability
  gate, so FR-14.4's naming requirement silently vanished whenever the indexer was unreachable —
  precisely the state where a reader is most likely to guess. Labels now render independently of data.

No previously accepted implementation was modified. `Lens.sol` and the event audit are byte-identical
to pass 1.

---

## AC Verification

Sprint 6 acceptance criteria, verbatim from `grimoires/loa/sprint.md:424-431`. **8 of 8 met.**

> **Gate first:** zero off-chain package installed/used before the operator-accepted pin set exists (fail-closed; refreeze §9) — evidence: pins + integrity hashes recorded, acceptance logged, lockfiles match pins

**✓ Met.** The gate held for two full passes: no `package.json`, lockfile, `node_modules` or `.npmrc`
existed anywhere in the tree until operator acceptance was recorded. Pins + integrity hashes:
`docs/authority/vux-v1-offchain-provenance-refreeze-2026-08.md` §3.1–§3.3 (10 packages, 40-char
commits, sha512 for each). Acceptance logged: same document §9 and
`…-source-registry-…json:operator_acceptance`, with both pre-acceptance candidate digests re-verified
immediately before the mutation and an entry-by-entry equivalence check (11/11, no broadening).
Lockfiles match pins: `tools/offchain/verify-accepted-pins.mjs` PASS — every accepted pin's lockfile
`version` **and** `integrity` equals the accepted census, in both roots.

> Independent-reconstruction test: an indexer-only recompute of `S`, `B`, `B/S`, per-settlement legs, and burn causes over a scripted multi-op scenario **matches chain state with zero ambiguity** (FR-14 acceptance, prd.md:L538); reorg/idempotency handling per sdd.md:L836

**✓ Met.** `indexer/scripts/reconstruct.mjs` — PASS. Eight-operation scenario on a live chain
(`script/TruthScenario.sol`): bootstrap → two settlements → redemption → eventless WETH donation →
holder self-burn → VEM-limited settlement → ordinary settlement. Reconstruction reads `eth_getLogs`
only (`indexer/src/lib/reconstruct.mjs`); truth reads `eth_call` only. Equal on `S`, `B`, `B/S` and
Strategic contributed; 5 settlements with `legs_sum` verified on each; 8 supply changes each
attributed to exactly one cause; **0 ambiguities**. Reorg/idempotency: 3× replay identical, reversed
delivery identical, prefix-truncation stable, and a **real anvil `evm_snapshot`/`evm_revert`** round
trip returns to the pre-fork state and re-agrees with chain `totalSupply`.

> Three-tier truth on every mining surface: tier labels distinct, prohibited framings absent ("earned", "owed", "claimable", "guaranteed" for tiers 1–2), estimate labeled variable + non-claimable; canonical explanation available verbatim (prd.md:L546-L553)

**✓ Met.** `web/components/ThreeTierPanel.jsx` renders three separate blocks with distinct labels
from `web/lib/truth-copy.js`; tier 3 comes from settled indexer history and never falls back to a live
estimate. Playwright: labels distinct (3 unique), tier-2 label asserted to contain both "may rise or
fall" and "not claimable", canonical explanation asserted character-for-character, and the six
prohibited words asserted to appear inside the tier-1/tier-2 blocks **only under negation**, plus a
12-pattern affirmative-framing grep across all five pages.

> YELLOW disclosure renders verbatim wherever the Reserve is described as ownerless/immutable — single-component coupling (INV-36; prd.md:L722-L723)

**✓ Met.** `web/components/ReserveDescription.jsx` is the only component that describes the Reserve
and always renders the disclosure with it — the coupling is structural, not a rule to remember.
Playwright asserts the text verbatim on `/redeem`, `/accounting`, `/trust`, and asserts
`count(disclosures) === count(descriptions)` on **every** page, so a description without one fails.

> Contestability claim appears only in its exact bounded form; no broad-distribution/anti-whale/equal-outcome claim anywhere (prd.md:L549)

**✓ Met.** Rendered once, verbatim, on `/trust` only, with an explicit bound stating it does *not*
claim equal outcomes, broad distribution, anti-whale design, or absence of capital advantage.
Playwright asserts the exact string, asserts a distinctive fragment appears on no other page, and
greps 12 prohibited claim families (`fair launch`, `anti-whale`, `trustless`, …) across all pages,
allowing them only under negation.

> NAV column named `strategic_nav_disclosed`; the word "backing" never labels Strategic values (FR-14.4)

**✓ Met.** Column named `strategic_nav_disclosed` in `indexer/sql/schema.sql` (analytics view) and
surfaced under that name on `/accounting` and `/treasury`. `NULL` is the value for "not disclosed" and
is never coerced to 0. Enforced at three layers: a SQL `CHECK` forbidding any `strategic_flow.class`
matching `%backing%`; the REST API refusing (HTTP 500) to serve such a row; and a Playwright test that
takes every sentence containing both "Strategic" and "backing" and requires it to *separate* them.
Labels render independently of data availability — the defect the suite caught.

> Failure truthfulness: RPC failure → explicit "data unavailable" (never stale-as-live); chain outage messaging per FB-17; FB-18 documented disclosure present on `/trust` (sdd.md:L836)

**✓ Met.** `useTruth` **drops** the previous value on error rather than retaining it, and ages out a
value that stops refreshing (`STALE_AFTER_MS`), so a stale number cannot be shown as current. The
`<Truth>` gate makes a value unreachable without its availability. The Playwright run executes with no
RPC configured — every live read is in its failure path — and asserts the unavailable state renders,
that the tiers show no number (and specifically not `0`), that the FB-17 outage banner appears, and
that `/trust` carries the FB-18 policy statement. On-chain contribution: `Lens.hardStats()` reverts
rather than returning `0` when `S` is zero.

> `previewRedeem`/estimates create no entitlement — copy + no-optimistic-display tests (prd.md:L539)

**✓ Met.** Contract side: `test/lens/LensEstimateParity.t.sol:123,140,170,189` — the estimate falls as
price decays, reading every view changes no protocol state, the reader receives nothing, and shortfalls
are not carried. Copy side: the quote is labelled a quotation with an explicit non-reservation
qualifier. Display side: with no amount entered the page shows `—`, and the quote element is asserted
absent — no optimistic zero, no placeholder that reads like a payout.

**No `COMPLETED` marker is written.** All eight criteria are met, but the marker is written by
`/audit-sprint` on approval, not by `/implement` — and operator acceptance of the sprint is a separate
stop this node is not authorized to perform.

---

## Tasks Completed

### Task 6.2 — `Lens.sol` + tests ⇐ none · **complete**

| File | Lines | What |
|---|---|---|
| `src/Lens.sol` | 224 | the five accepted views |
| `src/interfaces/ILensViews.sol` | 75 | the exact read-only surface Lens may reach |
| `test/lens/LensFixture.sol` | 57 | Lens over the real `RigFixture` topology |
| `test/lens/LensViews.t.sol` | 259 | tier-1 semantics, `B`/`S`/`B/S`, F-16 round-UP, Strategic separation |
| `test/lens/LensEstimateParity.t.sol` | 205 | tier-2 parity vs. real settlements; no-entitlement |
| `test/lens/LensSurface.t.sol` | 150 | read-only proven against the compiled artifact |

All five accepted views implemented to `sdd.md:L708-L715`: `rawClockLimit`,
`estimateIfDisplacedNow`, `hardStats`, `wethNeededForFullQraw` (rounds UP), `strategicContributed`.

**Approach.** Three properties drove the design:

1. **No authority path may exist.** `Lens` imports no contract type carrying a mutator — see Decision
   Log 2026-08-14. Asserted against bytes: the runtime contains `STATICCALL` and no `CALL`, `SSTORE`,
   `LOG*`, `CREATE*`, `CALLCODE`, `DELEGATECALL`, or `SELFDESTRUCT`, each absence paired with a
   positive control from `Rig`'s runtime (`test/lens/LensSurface.t.sol:113-149`).
2. **No mis-wiring may be possible.** The constructor takes only the Rig; the Reserve and token are
   derived from it at call time (`src/Lens.sol:55-68`), so a Lens reporting one contract's price
   against another's backing is not a deployment mistake that can be made.
3. **The estimate must be the number a settlement would actually produce.** `Lens` reimplements the
   routing law (widening `Rig` was available and declined), so parity is established by fuzzing the
   estimate against real settlements rather than by inspection.

**Tests: 31, all passing.** Notable coverage: bootstrap parity (`test_ParityAtBootstrap`), both VEM
regimes (`test_ParityWhenTheClockBindsAndWhenVemBinds`), parity after a redemption moves `B` and `S`,
parity across a settlement sequence, `D_need` as a two-sided mint threshold
(`testFuzz_WethNeededIsTheFullMintThreshold` — both branches exhibited, not assumed), and the INV-8
no-carry property.

### Task 6.3 — Event completeness audit ⇐ none · **complete**

| File | Lines | What |
|---|---|---|
| `grimoires/loa/a2a/sprint-6/evidence/event-completeness-audit.md` | 208 | FR-14.1–14.4 → emit-site mapping, 6 findings |
| `test/events/BurnCausePairing.t.sol` | 403 | the burn-cause join, executed on scripted flows |
| `test/events/EventSchemaConformance.t.sol` | 166 | accepted signatures vs. compiled images |

Every FR-14.1–14.4 observable maps to a declared event with a live emit site, or to an explicitly
recorded derivation (F-1) or non-derivation (F-3). **No event was added, renamed, or retyped** — this
task is a read of the Sprint 2–5 tree plus mechanical assertions over it.

The pairing tests read **logs only**, never protocol state, because that is what an indexer can see; a
test that consulted `realizedRevenue` to attribute a burn would prove nothing about observability.

**Tests: 17, all passing.**

### Task 6.1 — Off-chain provenance gate ⇐ none · **complete; refreeze ACCEPTED and ACTIVE**

| File | What |
|---|---|
| `docs/authority/vux-v1-offchain-provenance-refreeze-2026-08.md` | candidate refreeze, pass 2 (sha256 `f39dcf424abdc319…`) |
| `docs/authority/vux-v1-source-registry-offchain-refreeze-2026-08.json` | machine-readable registry, pass 2 (sha256 `8449ebb367b5650c…`) |

**Pass 2 (HITL reconciliation)** consumed the operator's disposition: **D-1 resolved** (`next = 15.1.12`,
React pins preserved), **D-2 candidate expansion authorized** and independently verified, **D-3/D-4**
recorded as disclosures. The census is now a complete ten-package final set with every peer edge
checked (9/9 satisfied) and no unresolved decision.

The D-1 security verification the operator required — *"do not infer it from the Next version number
alone"* — produced the substantive finding of this pass. CVE-2025-66478 is a **CVSS 10.0 RCE
originating upstream in React itself** (CVE-2025-55182), and the vulnerable packages are the three
`react-server-dom-*` RSC transport packages, **not** `react`/`react-dom`. Three consequences:

1. A complete manifest diff of `next@15.1.4` vs `15.1.12` shows **no `react-server-dom-*` edge at
   either version** — so there is no dependency path through which a vulnerable copy could be
   reintroduced. That is a statement about the manifest, not the version number.
2. Next.js **vendors** its RSC runtime inside its own tarball, so that copy cannot be pinned or
   verified independently of `next`. Recorded honestly as a residual with a post-acceptance,
   pre-import obligation rather than claimed as verified.
3. `react@19.0.0` is **not** a vulnerable package and is not deprecated anywhere in the 19.0.x line,
   so the operator's instruction to preserve `19.0.0` stands on evidence rather than on default.

Two further findings worth the reviewer's attention: the advisory names `15.1.9` as the 15.1.x fix,
but the registry still marks `15.1.9` **and** `15.1.10` deprecated — so the operator's `15.1.12` is
strictly more conservative than the vendor's own stated remedy. And the accepted architecture
(static-exportable, no server-side custody — sdd.md:L449/L453, sprint.md:L450) places VUX outside the
vulnerability's scope condition entirely, which is now a **binding Task 6.6 obligation** to assert
mechanically rather than an assumption.

**Correction to pass 1.** Pass 1 reported that `@tanstack/react-query@5.71.1` had no resolvable
upstream tag. That was wrong — a `head`-truncated search over a 4,424-tag namespace, compounded by
TanStack changing tag schemes across eras. The tag exists: `v5.71.1` → peeled commit
`6c105d6ddfc797ab5fe106d6020978f711e3af43`. The verification method now mandates full-namespace
enumeration so the truncation cannot recur.

Status `CANDIDATE`, activation `INACTIVE_UNTIL_OPERATOR_ACCEPTANCE`. Follows the OZ/v3-core refreeze
precedent exactly (candidate in `docs/authority/` with acceptance pending).

### Task 6.4 — ponder indexer + PostgreSQL schema + read-only REST ⇐ 6.1, 6.3 · **complete**

| File | What |
|---|---|
| `indexer/sql/schema.sql` | the accepted §3.3 DDL — 4 tables incl. the `legs_sum` CHECK, 3 indexes, the `accounting_truth` view |
| `indexer/ponder.schema.ts` | the same schema as ponder onchain tables |
| `indexer/ponder.config.ts` | networks/contracts; every address from env, fail-closed on absence |
| `indexer/src/index.ts` | event handlers with by-exclusion-then-refine attribution |
| `indexer/src/api/index.ts` | the five read-only REST routes (sdd.md:L795) |
| `indexer/scripts/extract-abis.mjs` | ABIs generated from forge artifacts, every topic0 verified against the accepted signature |

Three findings from Task 6.3 became implemented rules rather than notes: `ContributedPrincipal` is
derived from `Settled.strategicLeg` (F-1), a holder self-burn books by exclusion and is never dropped
(F-2), and a supply change is keyed off the transfer rather than the cause event so a zero-amount
cause event creates no row (F-5).

**Two implementation judgments recorded for review.** (1) The streaming attribution writes the row on
the transfer with the by-exclusion default and *refines* it when the cause event arrives, because at
every burn site the transfer is emitted *before* its cause event — a handler seeing the transfer
cannot yet know the cause. The shared id is `${txHash}:${direction}:${amount}`; its one collision case
is two same-signed changes of identical amount in one transaction, which the protocol cannot produce
and which `BurnCausePairing.t.sol` asserts per transaction. (2) `strategic_nav_disclosed` is `NULL`,
never `0` — the truthful value for "not disclosed" (F-3, INV-30).

### Task 6.5 — Independent-reconstruction test ⇐ 6.4 · **complete**

| File | What |
|---|---|
| `script/TruthScenario.sol` | the scripted scenario, deployable on a live node (no cheatcodes) |
| `indexer/src/lib/reconstruct.mjs` | the pure fold — logs in, economic truth out |
| `indexer/scripts/reconstruct.mjs` | the live acceptance run |
| `indexer/test/reconstruct.test.mjs` | 11 unit tests over synthetic-but-real-shaped logs |

`B` is rebuilt from the **WETH token's own transfer record** on the Reserve address rather than from
settlement legs. That is the definitional reading (INV-10) and it is general by construction: the
scenario includes an unsolicited eventless WETH donation, which a legs-based reconstruction would miss
entirely and which this one picks up exactly.

**Scope, stated rather than implied.** The live scenario deploys the monetary core only — the
canonical pool needs `vm.getCode` against the separate `=0.7.6` unit, and cheatcodes do not exist on a
live node. It therefore exercises four of the five causes end to end; `vyrf_burn` and the treasury
revenue burn are covered by `test/events/BurnCausePairing.t.sol` (real pool fixture) and by the unit
tests here. That split is a toolchain property, not a gap in the attribution logic.

### Task 6.6 — Frontend ⇐ 6.1 · **complete**

Five pages per sdd.md:L633-L643 (`/`, `/redeem`, `/accounting`, `/treasury`, `/trust`), a single
`truth-copy` module, `<ReserveDescription/>` with structural YELLOW coupling, and a read layer whose
API makes a value unreachable without its availability.

**Recorded deviation:** sprint.md names `truth-copy.ts`; the module is `truth-copy.js`. The accepted
refreeze does not authorize the `typescript` package (§8 excludes it explicitly; it is an *optional*
peer everywhere it appears), and Next.js requires that package to compile `.ts`/`.tsx`. Authoring in
TypeScript would have been unauthorized dependency expansion. The newer, more specific authority
governs. Flagged rather than silently renamed.

### Task 6.7 — Playwright copy suite ⇐ 6.6 · **complete**

`web/tests/truth-copy.spec.js` — **25 tests, all passing**, run against the **built static export**
rather than the dev server, because the requirement is about what a user is actually served.

The suite runs with **no RPC configured**, deliberately: that puts every live read into its failure
path, so the copy requirements are asserted in the degraded state as well. A surface that only tells
the truth when the chain is reachable is not a truth surface.

### Task 6.8 — Failure-truthfulness states ⇐ 6.6 · **complete**

`<Unavailable>`, `<Truth>` and `<OutageBanner>` in `web/components/Unavailable.jsx`, plus the
value-dropping and staleness-ageing behaviour in `useTruth`. There is no `value` prop on the
unavailable component — it structurally cannot render a number. FB-18's documented disclosure is on
`/trust`.

---

## Technical Highlights

**The reconstruction is a pure fold, and two required properties fall out of that** rather than being
bolted on: replaying a log cannot move the result (idempotency), and dropping a reorged block's logs
returns exactly the earlier state (reorg handling). Both are asserted — including against a real chain
reorg, not only a simulated truncation.

**Independence is enforced by construction, not by discipline.** The reconstruction module imports no
contract-call helper and never reads state; the acceptance script keeps the two sides on separate RPC
methods. A reconstruction that could ask for `totalSupply()` would prove nothing about observability.

**ABIs are generated, and their identity is checked.** `extract-abis.mjs` reads the compiled forge
artifacts and asserts each event's `topic0` equals the accepted sdd.md §3.2 signature, so the indexer
cannot silently decode a drifted shape. 13/13 verified.

**FR-14.4 is enforced at three independent layers** — a SQL `CHECK` on the class vocabulary, an API
refusal, and a rendered-sentence assertion — because "never call Strategic value backing" is a claim
about what users are told, not only about what the database stores.

**Provenance.** No new smart-contract source beyond Sprint 6's own `Lens.sol`/`ILensViews.sol` and the
scenario harness. `GPL-3.0-or-later` posture unchanged; the audited on-chain surface acquired no
dependency from the off-chain refreeze.

---

## Testing Summary

```bash
export PATH="$HOME/.foundry/bin:$PATH" && forge test          # 397 passed
cd indexer && node --test test/reconstruct.test.mjs           # 11 passed
node tools/offchain/verify-accepted-pins.mjs                  # PASS
cd web && node scripts/verify-rsc-runtime.mjs                 # PASS
cd web && npm run build && node scripts/verify-static-export.mjs   # PASS
cd web && npx playwright test                                 # 25 passed
anvil --port 8545 &  cd indexer && node scripts/reconstruct.mjs    # PASS
```

| Suite | Count | Result |
|---|---|---|
| forge (Solidity) | 397 | pass |
| indexer reconstruction units | 11 | pass |
| Playwright copy suite | 25 | pass |
| live reconstruction acceptance | 1 scenario, 20+ assertions | pass |
| standing gates (pins / RSC / static-export) | 3 | pass |

Test counts are not offered as proof. The load-bearing assertions are the ones that could fail for a
real reason: an events-only recompute equalling chain state across five settlements and eight supply
changes; a real reorg round trip; opcode-level absence with positive controls; per-transaction
burn-cause uniqueness; verbatim disclosure equality; and the six prohibited words permitted inside the
tier blocks only under negation.

---

## Known Limitations

1. **The vendored RSC build stamp cannot be byte-compared.** `8eb60861-20260126` is an internal
   Vercel/React build identifier, not a published npm artifact (confirmed by enumerating the
   packument). The PASS rests on build-date ordering, the targeted-rebuild asymmetry, the shadowing
   check, and the static-export scope condition — four independent legs, but not an equality proof.
2. **The live reconstruction scenario covers four of five burn causes**; `vyrf_burn` and the treasury
   revenue burn need the canonical pool, which needs a cheatcode unavailable on a live node. Covered
   at unit and forge level instead.
3. **`truth-copy.js`, not `.ts`** — a consequence of the accepted dependency boundary (Task 6.6 above).
4. **PostgreSQL 16.4 is not installed in this environment.** The accepted DDL is delivered and ponder
   embeds PGlite (real PostgreSQL), so the schema semantics apply; a run against a standalone
   PostgreSQL 16.4 server is a deployment-time exercise.
5. **The ponder app has not been run against a synced chain.** Its schema, handlers and REST routes are
   delivered and reviewable; the *reconstruction claim* — which is what the AC asserts — is proven by
   the standalone harness against a live chain.
6. **`estimateIfDisplacedNow`'s bootstrap branch** remains the pass-1 interpretation of sdd.md:L711
   against Task 6.2's parity criterion, carried forward for review as instructed.
7. **`sdd.md:L449` still names Next.js `15.1.4`.** The accepted pin is `15.1.12`. The SDD was not
   edited by this node; the divergence is recorded in the refreeze §10 as a documentation-reconciliation
   item for review.

---

## Verification Steps for the Reviewer

1. **Baseline and branch**
   ```bash
   git rev-parse master origin/master && git branch --show-current
   ```
   Expect `92f8762111cd89c4cbdd4bcb11d06bf368f29377` for both, on branch `sprint-6`, no commit made.

2. **The accepted surface equals the installed surface**
   ```bash
   node tools/offchain/verify-accepted-pins.mjs
   ```

3. **The installed Next artifact is not an unpatched RSC runtime**
   ```bash
   cd web && node scripts/verify-rsc-runtime.mjs
   ```

4. **The build is a static export with no server**
   ```bash
   cd web && npm run build && node scripts/verify-static-export.mjs
   ```

5. **Independent reconstruction against a live chain**
   ```bash
   anvil --port 8545
   ```
   ```bash
   cd indexer && node scripts/reconstruct.mjs
   ```

6. **The copy requirements, on the shipped artifact**
   ```bash
   cd web && npx playwright test
   ```

7. **Accepted artifacts unchanged**
   ```bash
   git status --porcelain -- grimoires/loa/prd.md grimoires/loa/sdd.md grimoires/loa/sprint.md src/Rig.sol src/VUX.sol src/HardReserve.sol src/StrategicTreasury.sol
   ```
   Expect empty.

---

## Residual Findings and Review Questions

| # | Item | Kind |
|---|---|---|
| R-1 | `estimateIfDisplacedNow` bootstrap branch — sdd.md:L711's literal formula vs. Task 6.2's parity criterion | carried judgment, pass 1 |
| R-2 | `truth-copy.js` vs. sprint.md's `truth-copy.ts` | deviation forced by the accepted dependency boundary |
| R-3 | `sdd.md:L449` names Next.js 15.1.4; accepted pin is 15.1.12 | documentation reconciliation, not performed by this node |
| R-4 | Streaming attribution's `${txHash}:${direction}:${amount}` id | implementation judgment; collision case unreachable in protocol |
| R-5 | Bundled RSC stamp not byte-comparable | stated limit of the verification |
| R-6 | ponder app not run against a synced chain | delivered but unexercised at runtime |

None is a defect I am aware of and concealing; each is a judgment or a stated limit that review should
rule on.

---

## Terminal State

**`SPRINT_6_IMPLEMENTED_READY_FOR_REVIEW`**

All eight tasks complete, all eight acceptance criteria met, seven gates green. No `COMPLETED` marker
written (that is `/audit-sprint`'s). `/review-sprint`, `/audit-sprint`, operator acceptance of the
sprint, commit, push, landing, and Sprint 7 were not invoked and are not authorized by this node.
