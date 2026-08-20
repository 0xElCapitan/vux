# Task 8.E2E — End-to-End Goal Validation (G-1…G-6)

**Node:** `/implement sprint-8`, Task 8.4 / Task 8.E2E
**Subject:** the **assembled** VUX system — launched through the real two-transaction genesis choreography, not a per-surface reconstruction of it.

**Result: 6/6 goals validated. No goal is marked "not achieved".**

---

## Why an assembled-system suite exists at all

Every other suite in this repository tests a surface. Integration is where the frozen parameters, the routing law, the VEM cap, and the treasury boundary have to agree **with each other** rather than each merely be correct in isolation — and a per-contract suite structurally cannot observe a disagreement between two individually-correct contracts.

`test/e2e/GoalValidation.t.sol` therefore extends `GenesisFixture`, which performs the actual launch (tx1 inert `VuxPoolDeployer` with a salted commitment; tx2 `GenesisDeployer` whose constructor *is* genesis), and drives the full monetary lifecycle across whatever that produces.

**10 tests, 10 passing.**

| Goal | Solidity-observable? | Where its evidence lives |
|---|---|---|
| G-1 faithful monetary core | yes | `test/e2e/GoalValidation.t.sol` (6 tests), **plus** the plan's "Fork scenario:" modality discharged by accepted Sprint-7 fork evidence — see *Modality* under G-1 |
| G-2 dual-treasury separation | yes | `test/e2e/GoalValidation.t.sol` (2 tests) |
| G-3 truthful UX | **no** — off-chain | Playwright + indexer reconstruction |
| G-4 LSG-ready boundary | yes | `test/e2e/GoalValidation.t.sol` (2 tests) |
| G-5 provenance discipline | **no** — CI gate set | `tools/provenance/run-all.sh` |
| G-6 operator reviewability | **no** — artifacts | this evidence pack |

G-3, G-5 and G-6 are not Solidity-observable. Writing Solidity that pretended to check them would be theatre; their evidence is named below in the form it actually takes.

---

## G-1 — Faithful monetary core

> **Validation action (plan, `sprint.md:571`, verbatim):** **Fork scenario:** rehearsal genesis → bootstrap takeover → ordinary takeovers across a halving **and across adaptive regimes (`D_need ≤ hardFloor` through `D_need > retained`)** → redemptions; assert frozen-parameter table (PRD Appendix A, incl. the adaptive routing law) against deployed constants and observed leg behavior verbatim
> **Expected:** INV-1…22 hold (INV-18/19 amended form); constants match verbatim; adaptive floor/cap/dust properties observed; bootstrap ≈88%+/12%/0-mint.

**✅ ACHIEVED** — locally on the assembled system for the scenario body, and **through accepted Sprint-7 fork evidence for the fork modality**. The two halves are separated in *Modality* immediately below rather than merged, because only one of them was executed by this node.

### Modality — the plan's "Fork scenario:" requirement, and how Sprint 8 discharges it

G-1 is the only goal whose validation action names a **fork**. The plan assigns modality per goal deliberately — G-2 says "on the assembled system", G-3 "on the assembled stack", G-1 alone says "Fork scenario:" — so the phrase is a requirement, not decoration, and this section states plainly which part of it Sprint 8 executed.

**What Sprint 8 executed: local, not forked.** Everything in the sections below ran against `test/e2e/GoalValidation.t.sol`, which extends `GenesisFixture` and therefore uses `MockWeth`, not canonical Robinhood Chain WETH. **No new fork execution occurred in Sprint 8**, and nothing here should be read as claiming one.

**What a fork actually discriminates for G-1 — and what it does not.** The scenario body is chain-independent by construction: the adaptive routing law, the VEM cap, the halving schedule, the frozen-constant table, and redemption arithmetic are pure functions of contract state and the frozen constants. Running them against a forked chain would exercise identical code paths and identical arithmetic. The *only* G-1 fact that a fork can discriminate is the behaviour of the **canonical RH WETH dependency** — that the Reserve's backing asset wraps native value exactly in constructor context, is immediately spendable without approval or prefunding, and that its `transfer`/`transferFrom` invoke no recipient callback and emit exactly one event. A mock cannot establish those; only the real deployed token can.

**Where that fact was established, named exactly.** It was closed at Sprint 7 against a real fork and is reused here rather than re-run:

| | |
|---|---|
| Evidence artifact | `grimoires/loa/a2a/sprint-7/evidence/q6-fork-run.txt` (verbatim capture) |
| Suite | `test/fork/RhWethFork.t.sol` |
| Chain | Robinhood Chain mainnet, `eth_chainId = 4663` |
| Fork block | `39130641` — block hash `0x662b5a64…da304`, parent `0xb1f43f47…7bee3`, state root `0x8121aa96…3375` |
| Result | **10 passed / 0 failed / 0 skipped** |
| Operator disposition | `OPERATOR_ACCEPTANCE — SPRINT_7_Q6_NATIVE_WRAP_ACCEPTED`, recorded at `grimoires/loa/a2a/sprint-7/evidence/q6-native-wrap.md:5` |

Its five Q-6 cases carry **discriminating controls**, which is why the evidence proves a property rather than merely reporting a green run: `test_Q6_Control_ValueAcceptedButNotCreditedFails` and `test_Q6_Control_NonPayableDepositFails` are constructed to fail against a token that accepted value without crediting it, and `test_Sprint5Carry_Control_ReceiversDetectARealCallback` fails against a token that *did* invoke a recipient hook. A suite whose controls can fail is measuring something.

**Why the reuse remains applicable, not stale.** The reused fact is a property of an external deployed contract at a pinned block, and nothing in Sprint 8 touched the surface that consumes it — `src/HardReserve.sol` and the genesis choreography are byte-unchanged since Sprint 7 (Sprint 8's implementation subject is CI gates, static-analysis tooling, traceability tooling and evidence; no `src/` change). The Sprint-7 capture additionally records that it was **itself re-established after Tasks 7.2–7.6** rather than inherited from Sprint 5, precisely because its harness had changed — so the evidence chain has already been walked once under exactly this scrutiny. Re-running the same suite against the same pinned block in Sprint 8 would reproduce the same ten results and add no discriminating information; it is not performed for ceremony.

**Why the 10 fork tests appear as skips in the Sprint-8 run.** The accumulated Sprint-8 result is **454 passed / 0 failed / 10 skipped** of 464. All ten skips are `test/fork/RhWethFork.t.sol`, which self-skips off-fork by design: `_skipOffFork()` (`test/fork/RhWethFork.t.sol:259`) calls `vm.skip(true)` unless `block.chainid == RH_CHAIN_ID`. Executing them requires an archive-capable RH RPC, which is an operator input (residual R-Y10). The skips are therefore the suite's designed off-fork behaviour and a pointer to the Sprint-7 evidence above — **not an unrun obligation**.

**Net position on the modality requirement.** The plan's "Fork scenario:" is satisfied in the only dimension a fork discriminates, by named, operator-accepted Sprint-7 evidence, with the chain-independent remainder executed locally on the assembled system and reported below. Sprint 8 claims no new fork execution.

### Frozen parameters vs. deployed constants

`test_G1_FrozenParametersMatchTheDeployedConstantsVerbatim` reads the constants off the **live instance**, so a constant edited in source fails here even if someone updates the comment beside it:

| Parameter | Frozen value | Observed |
|---|---|---|
| `SPLIT_KING_BP` | 8,000 | ✅ |
| `STRATEGIC_CAP_BP` | 1,200 | ✅ |
| `BP_DENOM` | 10,000 | ✅ |
| `EPOCH_PERIOD` | 3,000 | ✅ |
| `PRICE_MULTIPLIER` | 2 | ✅ |
| `INITIAL_UPS` | 4e18 | ✅ |
| `HALVING_PERIOD` | 30 days | ✅ |
| `MAX_HALVINGS` | 8 | ✅ |
| adaptive floor (derived) | `retained − strategicCap` = **800 bp** | ✅ derived, not restated |

### Genesis state

`test_G1_GenesisStateIsExact` — `S0 = 150,000e18 + 1`; Reserve holds exactly 1 raw unit and `B0` WETH; zero at the deployer, the Rig, the operator Safe, and the launcher.

It asserts the POL allocation in the accepted form — `pool + quantization dust == POL_VUX`, `dust < 1e18` — because a v3 full-range mint places only what the liquidity math can consume and the remainder stays with the treasury as protocol-owned inventory. A naive `pool == 150,000e18` assertion is asserting a rounding behaviour Uniswap v3 does not have; it failed on first run at 19 raw units, which is exactly the dust. **Additionally asserted: `pool + dust + reserve == S0`** — full conservation, which makes the zero-balance checks exhaustive rather than a list of addresses someone remembered.

### Bootstrap

`test_G1_BootstrapTakeoverMintsZeroAndAccruesEightyEightPercentToHard`:

- genesis King **is** the Reserve; `lens.rawClockLimit() == 0` (clock disabled);
- the takeover mints **zero** (INV-20);
- Hard receives `kingLeg + floor`, Strategic receives exactly 12% — asserted as an exact wei equality, and additionally `hard/price ≥ 88%`;
- the system leaves bootstrap and `scheduleStart` is set.

### Every adaptive regime, on the assembled system

`test_G1_EveryAdaptiveRoutingRegimeIsObservedOnTheAssembledSystem` drives six reigns of 1 / 30 / 200 / 900 / 2,000 / 3,000 seconds. Because `dNeed = ceil(qRaw × B / S)` and `qRaw = min(elapsed, EPOCH_PERIOD) × UPS`, reign length sweeps `dNeed` across the whole law. At each step it recomputes the expected split independently and asserts the observed Strategic leg to the wei, plus the amended INV-18/19 bounds.

**The test asserts that all three regimes were actually reached** — a coverage claim the test proves about itself rather than one the reader has to take on trust:

| Regime | Condition | Observed |
|---|---|---|
| 1 | `dNeed ≤ hardFloor` → floor binds, Strategic = 12% | ✅ |
| 2 | `hardFloor < dNeed < retained` → Hard tracks need exactly | ✅ |
| 3 | `dNeed ≥ retained` → Hard takes all retained, Strategic = 0 | ✅ |

### Halving and tail

`test_G1_TakeoversContinueCorrectlyAcrossAHalvingBoundary` — UPS is `INITIAL_UPS` in epoch 0, halves at the first boundary, halves again at the second, and **stops** at `MAX_HALVINGS` (probed just past the cap and again 32 halving-periods beyond it, so the tail is proven *flat* rather than merely reached). Supply and backing are monotone across each boundary (INV-1, INV-13).

Every boundary is derived from `rig.HALVING_PERIOD()` and `rig.MAX_HALVINGS()` rather than written as literal day counts, so a change to either constant moves the boundary this test checks instead of silently leaving it asserting the wrong instant. The frozen values stay pinned in exactly one place — the constants assertion above. (Literal durations in implementation artifacts are also what the PRD §17 quarantine grep is correctly suspicious of; it flagged an earlier `60 days` here, and deriving from the contract was the right resolution rather than relaxing the gate.)

### Redemption

`test_G1_RedemptionPaysProRataOnTheMinedSystem`, on a system that has actually been mined through three takeovers: payout is exactly `floor(q × B / S)`; the burn is exactly `q` (INV-3); backing is the physical balance afterwards (INV-10); and **backing-per-unit does not fall**, because floor division favours the Reserve.

### Supporting invariant evidence

INV-1…22 are additionally carried by the stateful invariant harness (`test/rig/RigInvariants.t.sol`, 9 invariants over random op sequences) and the property suites accumulated since Sprint 3. The E2E suite adds the assembled-system path those harnesses do not exercise.

---

## G-2 — Dual-treasury separation and failure independence

> **Validation action:** Strategic loss 50/80/100% + POL failure scenarios on the assembled system.
> **Expected:** INV-23…31, INV-35 hold; core state bit-identical (FB-5); FB-7.

**✅ ACHIEVED.**

`test_G2_StrategicLossAtEveryDepthLeavesTheCoreBitIdentical` destroys Strategic value **outright** at 50%, then 80%, then 100% of what remains — value transferred to `0xDEAD`, with no adapter cooperating in the accounting, which is the strongest form of the failure. After each depth it asserts backing, supply, throne and epoch are **unchanged**, then performs another takeover to prove the core keeps functioning while reading an untouched Reserve.

`test_G2_NoRescuePathFromStrategicDistressToTheReserve` drains Strategic to zero and then asserts the thing a holder actually cares about: **the hard claim still pays, unchanged**. A "no rescue path" claim is only meaningful if the thing it protects still works, so the test redeems and checks the payout equals `floor(held × B / S)` computed against pre-drain backing. It also asserts no VUX-side allowance exists in either direction between Reserve and treasury.

**POL failure scenarios** are carried by `test/treasury/PolFailureBehaviors.t.sol` and the POL invariant suite (`PolInvariants.t.sol`), which prove INV-25/26/27/29 including the VYRF ordering property and that the pool's active liquidity is exactly the treasury's own position.

---

## G-3 — Truthful UX

> **Validation action:** Playwright suite + reconstruction test on the assembled stack.
> **Expected:** three tiers distinct; zero prohibited phrases; indexer equality.

**✅ ACHIEVED** — off-chain, as the goal requires.

| Surface | Evidence | Result |
|---|---|---|
| Lens | `test/lens/LensSurface.t.sol`, `LensViews.t.sol`, `LensEstimateParity.t.sol` | green in the 464-test run |
| Event/indexer path | `indexer/test/handlers.test.mjs` | **24/24 pass** |
| Reconstruction | `indexer/test/reconstruct.test.mjs` | **pass** — `B` rebuilt from the WETH transfer record incl. eventless donations; `B/S` floors and is *null* rather than 0 when `S` is zero; the fold is idempotent, order-independent and prefix-stable |
| API/frontend | `web/tests/units.test.mjs` | **10/10 pass** |
| Static export integrity | `npm run verify:static` | **PASS** — no server runtime, no Server Function endpoint |
| Bundled RSC | `npm run verify:rsc` | **PASS** |
| **Playwright copy suite** | `web/tests/truth-copy.spec.js`, `chain-guard.spec.js`, `take-guard.spec.js`, `wallet-flows.spec.js` | **46/46 pass** |

**The three tiers stay distinct**, which is the goal's actual content:

| Tier | What it is | Must never become |
|---|---|---|
| raw clock opportunity | what the schedule has made available | an entitlement |
| estimate if displaced now | what a displacement at this instant would settle | a promise |
| actual settled / minted VUX | what has irrevocably happened | either of the above |

Named Playwright evidence for the harder cases: *"unreadable values render as explicitly unavailable, never as 0 or a stale number"*; *"the chain-outage banner appears when live reads cannot be made (FB-17)"*; *"the guard tracks the live price and is never reused from an earlier take"*; *"wallet copy predicates no entitlement on unsettled VUX"*; *"every page reaches the Trust page, so the disclosure is always one click away"*.

Zero prohibited phrases, asserted on rendered output rather than source.

---

## G-4 — LSG-ready but inactive

> **Validation action:** activation-slot lifecycle (activate mock module → deactivate) + INV-32…34 negatives.
> **Expected:** inactive at launch; authority present; boundaries structurally unreachable.

**✅ ACHIEVED, and strictly bounded to the P0 activation boundary.**

`test_G4_LsgShipsInactiveAndItsActivationLifecycleWorks` — `lsgModule() == address(0)` on the assembled genesis output (INV-32).

`test_G4_ActivationDeactivationLifecycleAndNegativeBoundaries`:

- **365 days pass and LSG stays inactive** — activation is affirmative, never calendar-driven (R-6);
- an unauthorized caller is rejected;
- the operator authority activates, and **deactivation is instant** — the emergency direction is never delayed;
- INV-33/34: the module holds no VUX, no WETH, and **no allowance over the treasury**.

Plus the full 21-test boundary suite at `test/treasury/TreasuryLsgBoundary.t.sol`, including *"a signal naming the monetary core reaches nothing"*, *"signal surfaces fail closed before activation"*, *"a signal cannot reach an unadmitted, unmatured or removed target"*, and *"deactivation severs funding and strands nothing"*.

**P1 remains excluded**, as required: no `LSGSignals` implementation, no reward machinery, no ROOT/GIGA adapters, no mature bribe machinery. The mock module exists only to exercise the P0 slot.

---

## G-5 — Provenance discipline

> **Validation action:** full CI gate run — census drift, pins, SPDX, quarantine grep, `POOL_INIT_CODE_HASH`, lockfile gates.
> **Expected:** zero unauthorized source; all gates green.

**✅ ACHIEVED — 11/11 gates green** (`bash tools/provenance/run-all.sh`).

| Gate | Result |
|---|---|
| census, byte identity, excluded sources | 63/63 vendored files byte-identical; Miner reuse limited to 3 allowlisted files; no prohibited-source reference |
| immutable pins | no short SHA; no mutable ref as authority; every GitHub Action pinned to a 40-char commit |
| SPDX and copyright policy | 63/63 vendored SPDX retained verbatim; 74 VUX-owned files match PROV-8; no invented copyright holder |
| LICENSE and third-party notices | GPLv3 unmodified; all required notices present |
| PRD §17 quarantine | clean |
| launch-secret and broadcast hygiene | clean |
| `POOL_INIT_CODE_HASH` | reproduces `0xe34f199b…b54` |
| deployed surface and runtime capability | clean |
| static analysis (slither) | 68 findings, **0 high**, all dispositioned against the baseline |
| requirement traceability | 37/37 INV, 18/18 FB, 44 evidence paths verified present |
| final secret sweep | all 436 tracked files, no directory excluded |

**Off-chain**: lockfile-drift gate and accepted-pin gate green (`offchain` CI job).

**New tooling matches the accepted Sprint-8 provenance set exactly.** `slither-analyzer==0.10.4` and `crytic-compile==0.3.7`, at the accepted commits and digests, plus the 49-distribution closure every member of which is a proven transitive consequence of those two pins (0 orphans). Enforced by `--require-hashes --no-deps` against a committed file, and asserted at gate time by distribution name and version.

**Zero unauthorized dependency or source entered.** No v3-periphery, no `UniswapV3Factory.sol`, no unauthorized third-party Solidity, no P1 Signal/LSG implementation.

---

## G-6 — Operator reviewability

> **Validation action:** evidence pack + traceability matrix review; every §21 question answerable from artifacts.
> **Expected:** 20/20 answerable; matrix complete.

**✅ ACHIEVED — 20/20 answerable from artifacts, without conversational memory.**

| §21 # | Question | Answerable from |
|---:|---|---|
| 1 | What does the user do? | PRD §8; `web/app/*` + `wallet-flows.spec.js` |
| 2 | What does the King receive? | `src/Rig.sol` `_route`/`_vem`; `RigSettlement.t.sol`; E2E G-1 |
| 3 | Where does each payment leg go? | `Rig._route`; `RigRouting.t.sol`; E2E adaptive-regime test |
| 4 | What safely funds issuance? | `Rig._vem` (`D_R` measured delta); `RigVem.t.sol` |
| 5 | What can never fund issuance? | `InconsistentReserveDelta` equality; `RigFailureBehaviors.t.sol` |
| 6 | What does the Hard Reserve guarantee? | `src/HardReserve.sol`; `HardReserveRedemption.t.sol`; E2E redemption |
| 7 | What is NOT guaranteed by Strategic NAV? | `TreasuryFailureBehaviors.t.sol`; E2E G-2; `trust-inventory.md` |
| 8 | What does 4 UPS mean? | `Rig.INITIAL_UPS`; `RigPricing.t.sol`; Lens three-tier copy |
| 9 | Unsupported raw opportunity? | `Rig._vem`; `RigVem.t.sol` |
| 10 | What happens at bootstrap? | `RigBootstrap.t.sol`; E2E bootstrap test |
| 11 | What is Strategic principal? | `StrategicTreasury` accounting; `TreasuryAccountingProperties.t.sol` |
| 12 | What is realized revenue? | `TreasuryRevenue.t.sol` |
| 13 | How does POL-special VYRF work? | `PolInvariants.t.sol`; `TreasuryPol.t.sol` |
| 14 | What does LSG control? | `TreasuryLsgBoundary.t.sol`; E2E G-4 |
| 15 | What does LSG not control? | same, negative boundaries (INV-32…34) |
| 16 | Who decides when LSG activates? | `activateLSG`; *"time alone never activates"* test |
| 17 | Which decisions remain adaptive? | `deployment-runbook.md` §5 (R-1…R-14 slots) |
| 18 | If Strategic goes to zero? | E2E G-2 total-loss test; `fb-17-18-analysis.md` |
| 19 | Why is VUX useful post-TGE? | PRD §3.3/§7.3; `trust-inventory.md` |
| 20 | Launch-critical vs mature? | `launch-criteria-sweep.md`; P0/P1 boundary in `sprint.md` |

### The evidence pack

| Artifact | What it answers |
|---|---|
| `traceability-matrix.md` + `traceability.json` | INV-1…37, FB-1…18 → named evidence |
| `launch-criteria-sweep.md` | PRD §20.1, all eight rows |
| `e2e-goal-validation.md` (this file) | G-1…G-6 |
| `trust-inventory.md` | what must be trusted, and what happens if that trust fails |
| `fb-17-18-analysis.md` | the two documented-analysis failure rows |
| `deployment-runbook.md` | how to launch; what only the operator can supply |
| `offchain-licence-census.json` | 675-package transitive licence reality |
| `static-analysis-licence-census.json` | 49-distribution toolchain licence reality |
| `tools/static-analysis/triage-baseline.json` | every static-analysis finding and its disposition |
| `cycle-closeout-prep.md` | what `/ship` will need |
| `subject-manifest.md` | the exact 33-file subject and its fingerprints |

---

## Summary

| Goal | Verdict | Primary evidence |
|---|---|---|
| G-1 Faithful monetary core | ✅ achieved | `test/e2e/GoalValidation.t.sol` (6 tests) + accumulated suites |
| G-2 Dual-treasury separation | ✅ achieved | `test/e2e/GoalValidation.t.sol` (2 tests) + `*FailureBehaviors.t.sol` |
| G-3 Truthful UX | ✅ achieved | 46 Playwright + 24 indexer + 10 web unit + reconstruction |
| G-4 LSG-ready boundary | ✅ achieved | `test/e2e/GoalValidation.t.sol` (2 tests) + 21-test boundary suite |
| G-5 Provenance discipline | ✅ achieved | 11/11 gates green |
| G-6 Operator reviewability | ✅ achieved | 20/20 §21 answerable; matrix complete |

**Accumulated suite at this node: 464 tests, 454 passed, 0 failed, 10 skipped.**
**Core line coverage: 98.19% (598/609), floor 90%, every file ≥ 96.9%.**
