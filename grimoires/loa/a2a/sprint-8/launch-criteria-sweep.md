# PRD §20.1 — Launch-Criteria Sweep

**Node:** `/implement sprint-8`, Task 8.3
**Scope:** the eight launch criteria at `prd.md:L877-L886`, each resolved to named evidence or explicitly identified as an operator-reserved production input.

> **The rule this sweep follows:** a criterion is satisfied by *evidence*, or it is identified as an *operator-reserved production input where accepted authority says it is not an implementation blocker*. Nothing is silently converted from the second class into the first. Where a criterion has both an implementable half and a production half — row 5 is the clear case — both halves are stated separately.

**Result: 8/8 rows resolved.** Six satisfied outright by software-established evidence; one (row 5) satisfied as to *procedure* with its *production values* correctly reserved; one (row 8) satisfied by the mechanical copy suite plus the manual review recorded here.

---

## Row 1 — FR-1…FR-11 and FR-14…FR-16 acceptance criteria pass

**Status: ✅ satisfied.**

The FR acceptance criteria were closed per sprint and checked off at each sprint's review. Mechanical confirmation at this node: `grimoires/loa/sprint.md` carries **143 checked** acceptance boxes and **24 unchecked**, and every unchecked box is Sprint 8's own (lines 538–580) — no Sprint 1–7 criterion remains open.

| FR | Where it is carried | Assembled-system confirmation |
|---|---|---|
| FR-1 genesis state & supply | `test/genesis/GenesisWiring.t.sol`, `GenesisPriceEncoding.t.sol` | `test_G1_GenesisStateIsExact` |
| FR-2 throne & Dutch pricing | `test/rig/RigPricing.t.sol` | `test_G1_FrozenParametersMatchTheDeployedConstantsVerbatim` |
| FR-3 clock, UPS schedule, tail | `test/rig/RigPricing.t.sol` | `test_G1_TakeoversContinueCorrectlyAcrossAHalvingBoundary` |
| FR-4 adaptive 8%-floor routing | `test/rig/RigRouting.t.sol` (3 regimes + 3 fuzz properties) | `test_G1_EveryAdaptiveRoutingRegimeIsObservedOnTheAssembledSystem` |
| FR-5 VEM issuance cap | `test/rig/RigVem.t.sol` | covered by the invariant suite |
| FR-6 bootstrap settlement | `test/rig/RigBootstrap.t.sol` | `test_G1_BootstrapTakeoverMintsZeroAndAccruesEightyEightPercentToHard` |
| FR-7 Hard Reserve & redemption | `test/reserve/HardReserveRedemption.t.sol` | `test_G1_RedemptionPaysProRataOnTheMinedSystem` |
| FR-8 Strategic receipt & custody separation | `test/treasury/TreasuryFlows.t.sol` | `test_G2_StrategicLossAtEveryDepthLeavesTheCoreBitIdentical` |
| FR-9 principal/revenue classification | `test/treasury/TreasuryRevenue.t.sol`, `TreasuryAccountingProperties.t.sol` | — |
| FR-10 POL conduct | `test/treasury/PolConduct.t.sol`, `TreasuryPol.t.sol` | — |
| FR-11 POL-special VYRF | `test/treasury/PolInvariants.t.sol` | — |
| FR-14 observability | `test/events/EventSchemaConformance.t.sol`, `BurnCausePairing.t.sol` | indexer reconstruction |
| FR-15 truthful UX | `web/tests/truth-copy.spec.js` | row 8 |
| FR-16 boundaries | `test/treasury/TreasuryLsgBoundary.t.sol` | `test_G4_*` |

---

## Row 2 — LSG inactive, activation authority present, POL non-voting rule preserved

**Status: ✅ satisfied.**

- **Inactive at launch:** `treasury.lsgModule() == address(0)` on the assembled genesis output — `test/e2e/GoalValidation.t.sol::test_G4_LsgShipsInactiveAndItsActivationLifecycleWorks`.
- **Authority present and affirmative:** `activateLSG` / `deactivateLSG` exist, are operator-gated, and **time alone never activates** — `test_G4_ActivationDeactivationLifecycleAndNegativeBoundaries`, plus the 21-test boundary suite at `test/treasury/TreasuryLsgBoundary.t.sol`.
- **Boundaries unreachable (INV-32…34):** a signal naming the monetary core reaches nothing; the module holds no allowance over the treasury; signal surfaces fail closed before activation — `TreasuryLsgBoundary.t.sol:117,208,371`.
- **POL non-voting rule:** preserved treasury-side; no LSG path can reach the POL position.

---

## Row 3 — All 37 invariants demonstrated by test or review, each traced to its carrying FR

**Status: ✅ satisfied — 37/37.**

`grimoires/loa/a2a/sprint-8/traceability-matrix.md`, generated from the tree by `tools/traceability/build-matrix.mjs` and enforced by `tools/traceability/verify-traceability.sh` (in `run-all.sh`, therefore in CI).

The gate checks two things a hand-maintained table cannot: that no row is evidence-free, **and that every named evidence path exists on disk** — the failure mode that makes a matrix worse than none, because a dangling reference reads as coverage. 44 distinct evidence artifacts, all present.

INV-36 (YELLOW coupling) and INV-37 (no source-authority expansion) carry non-test evidence by accepted assignment (`sprint.md` §D): the single-component coupling plus the Playwright copy suite, and the CI provenance gate set, respectively. That is the assigned method, not a gap.

---

## Row 4 — All 18 failure behaviours demonstrated per their assigned method

**Status: ✅ satisfied — 18/18.**

Method assignment is `prd.md:L669`, restated at `sdd.md:L869`:

| Class | Rows | Method | Evidence |
|---|---|---|---|
| Automated | FB-2…FB-5, FB-7, FB-13…FB-16 | forge tests | `RigFailureBehaviors.t.sol`, `TreasuryFailureBehaviors.t.sol`, `PolFailureBehaviors.t.sol` |
| Review + scenario docs | FB-1, FB-6, FB-8…FB-12 | named review-checklist entries | **per row — see the table below** |
| Documented disclosure/analysis | FB-17, FB-18 | documented analysis | `grimoires/loa/a2a/sprint-8/fb-17-18-analysis.md` |

**Review-only rows, cited individually.** This sweep originally cited the class as "sprint-3/4/5 `engineer-feedback.md`" — a citation by sprint number rather than by artifact. Review finding M-1 established that six of those seven files never mention the row they were cited for, and H-1 that FB-11 had no artifact at all. Each row now names the document that actually carries it, and `tools/traceability/verify-traceability.sh` asserts the containment mechanically:

| Row | Artifact that carries it | Lines mentioning the row |
|---|---|---:|
| FB-1 | `grimoires/loa/a2a/sprint-3/evidence/fb-1-mining-redemption-independence.md` | 9 |
| FB-6 | `grimoires/loa/a2a/sprint-4/evidence/fb-6-9-10-12-scenario-notes.md` §FB-6 | 3 |
| FB-8 | `grimoires/loa/a2a/sprint-5/engineer-feedback.md` (AC-7 sign-off, naming both FB-8 tests) | 2 |
| FB-9 | `grimoires/loa/a2a/sprint-4/evidence/fb-6-9-10-12-scenario-notes.md` §FB-9 | 3 |
| FB-10 | `grimoires/loa/a2a/sprint-4/evidence/fb-6-9-10-12-scenario-notes.md` §FB-10 | 2 |
| FB-11 | `grimoires/loa/a2a/sprint-8/fb-11-analysis.md` | 13 |
| FB-12 | `grimoires/loa/a2a/sprint-4/evidence/fb-6-9-10-12-scenario-notes.md` §FB-12 | 3 |

FB-8…FB-12 additionally carry named forge tests, discovered from the tree rather than declared (`PolFailureBehaviors.t.sol`, `TreasuryRevenue.t.sol`, `TreasuryLsgBoundary.t.sol`); the review-checklist citation above is the row's *assigned* method, not its only evidence.

FB-5 additionally re-proven on the assembled system at three loss depths (50/80/100%) — `test_G2_StrategicLossAtEveryDepthLeavesTheCoreBitIdentical`.

**Not forced into uniformity.** Manufacturing a synthetic test for FB-17 ("chain unavailable") would assert VUX's behaviour against a condition VUX cannot create, and would launder a documented-analysis assignment into a false green. The analysis states the stronger fact instead: *no mechanism exists that could reclassify a balance in response to time or liveness.*

---

## Row 5 — Genesis/WETH conversion evidence recorded; `P0/N0 = 1.10`; cushion inequality holds

**Status: ✅ procedure verified — 🔲 production values operator-reserved.**

This row has two halves and the accepted plan splits them explicitly (`sprint.md:L548`: "genesis/conversion evidence *procedure* verified (production values at deployment)").

**Software-established (✅):**

- The conversion **procedure** is specified and rehearsed: `GenesisFixture` performs the real two-transaction choreography with rehearsal values, and `test/genesis/GenesisPriceEncoding.t.sol` proves the off-chain deterministic `sqrtP0X96` encoding.
- `P0 = 1.10 × B0/S0` is carried as an exact rational (`P0_NUM = 11 × B0`, `P0_DEN = 10 × S0`) so the identity is visible rather than asserted.
- The cushion inequality `BOOTSTRAP_OPENING ≤ P0×S0 − B0` is checked in-transaction by the genesis self-verification; violation reverts the whole launch and the contract never exists.
- The recording **template** exists at `grimoires/loa/a2a/sprint-8/deployment-runbook.md` §5.2/§5.3.

**Operator-reserved (🔲), per FR-1.4 and R-14:** the WETH/USD reference price, its source, its timestamp, the rounding rule, and the four converted wei amounts. These are converted **once**, immediately before deployment, by the founder. No runtime USD oracle exists or may be added.

**Resolving these in-repo would be a defect, not completeness.** The runbook slots are verified unfilled by `tools/provenance/final-secret-sweep.sh` (52 slots, all empty).

---

## Row 6 — YELLOW disclosure present wherever required (§13)

**Status: ✅ satisfied.**

- **Verbatim text**, character-for-character from `prd.md:L722-L723`, carried once at `web/lib/truth-copy.js:105-106`.
- **Structural coupling (INV-36):** `web/components/ReserveDescription.jsx` is the only component that describes the Reserve as ownerless/immutable, and it always renders the disclosure with it. There is no code path that emits the first claim without the second — a guarantee, not a policy.
- **Mechanical assertion:** `web/tests/truth-copy.spec.js` asserts the rendered output on every page.
- **Inventory:** `grimoires/loa/a2a/sprint-8/trust-inventory.md` — one YELLOW entry exists (canonical RH WETH) and it is the only one.

---

## Row 7 — Provenance gates PROV-1…PROV-9 clean; licence/notice files per NFR-COMP

**Status: ✅ satisfied.**

`bash tools/provenance/run-all.sh` — 11 gates, all green:

| Gate | Result |
|---|---|
| census, byte identity, excluded sources | 63/63 vendored files byte-identical |
| immutable pins | no short SHA, no mutable ref as authority, every Action SHA-pinned |
| SPDX and copyright policy | 63/63 vendored SPDX retained; 74 VUX-owned files match PROV-8; no invented copyright holder |
| LICENSE and third-party notices | GPLv3 unmodified (`sha256:8ceb4b9e…`, 674 lines); all required notices present |
| PRD §17 quarantine | clean |
| launch-secret and broadcast hygiene | clean |
| `POOL_INIT_CODE_HASH` reproduction | matches `0xe34f199b…b54` |
| deployed surface and runtime capability | clean |
| **static analysis (slither, triaged baseline)** | **NEW** — 68 findings, 0 high, all dispositioned |
| **requirement traceability (INV/FB)** | **NEW** — 37/37 + 18/18, 44 evidence paths verified present |
| **final secret sweep (whole namespace)** | **NEW** — all 436 tracked files, no exclusions |

**NFR-COMP release compliance** (Task 8.5) additionally closed two real drifts: `THIRD_PARTY_NOTICES.md` §6 asserted "None installed. Nothing imported or vendored yet." while 63 files were vendored and two npm roots installed, and it named a superseded Foundry version. Both repaired; §6.3 (off-chain, 675-package census) and §6.4 (static-analysis toolchain, 49-distribution census) added.

---

## Row 8 — Truthful-UX review passes on every mining-state surface (FR-15)

**Status: ✅ satisfied.**

**Mechanical.** `web/tests/truth-copy.spec.js` (Playwright 1.49.1) asserts, on the rendered pages rather than the source: the three tiers stay distinct, the YELLOW text is verbatim, and zero prohibited phrases appear. `web/tests/units.test.mjs` (10 tests) and the indexer suite (24 tests) carry the numeric half; `indexer/test/reconstruct.test.mjs` proves reconstruction equality.

**The distinction the suite protects**, and why it is the whole point of FR-15:

| Tier | Meaning | Never conflated with |
|---|---|---|
| raw clock opportunity | what the schedule has made available | an entitlement |
| estimate if displaced now | what a displacement *at this instant* would settle | a promise |
| actual settled / minted VUX | what has irrevocably happened | either of the above |

**Manual review at this node** (`trust-inventory.md` §4): every VUX-authored trust-claiming surface read and checked — `truth-copy.js`, `ReserveDescription.jsx`, `/trust`, the four app pages, `README.md`, TPN §6.3, and Solidity NatSpec across `src/**`. **Zero trustless claims; zero uncoupled ownerless/immutable descriptions.**

---

## Summary

| # | Criterion | Status |
|---|---|---|
| 1 | FR-1…11, FR-14…16 acceptance | ✅ satisfied |
| 2 | LSG inactive + authority present | ✅ satisfied |
| 3 | 37 invariants traced | ✅ 37/37 |
| 4 | 18 failure behaviours per method | ✅ 18/18 |
| 5 | Genesis/conversion evidence | ✅ procedure • 🔲 production values reserved (FR-1.4, R-14) |
| 6 | YELLOW disclosure | ✅ satisfied |
| 7 | PROV-1…9 + NFR-COMP | ✅ 11/11 gates green |
| 8 | Truthful-UX review | ✅ satisfied |

**No criterion is unresolved. No production-launch input has been converted into a repository constant.**
