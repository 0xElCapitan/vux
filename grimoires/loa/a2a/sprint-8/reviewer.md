# Sprint 8 — Implementation Report

**Sprint:** 8 (global = local) — Launch Readiness: Hardening, Traceability & E2E Goal Validation
**Branch:** `sprint-8` · **Baseline:** `6395cabb4deee5bae50ac79c8094053484261819`
**Node:** `/implement sprint-8` (single node, resumed across the Task-8.1 operator gate)
**Commits on the branch:** **0** — landing is a later operator-gated node

---

## Executive Summary

Sprint 8 closes cycle-002 at **launch readiness**. Nothing was deployed.

Task 8.1 stopped at its operator gate with a full provenance packet, was repaired on operator direction, and was then accepted; the refreeze is now `STATIC_ANALYSIS_PROVENANCE_REFREEZE_CURRENT_ACCEPTED` and **discharges the last open clause of the OZ/v3 refreeze §9** — no deferred provenance obligation remains anywhere in the cycle.

The static-analysis closure was derived, hash-pinned, and proven orphan-free; slither ran against the accepted build and produced **68 findings, 0 high-impact, every one dispositioned**. Traceability closed at **37/37 invariants and 18/18 failure behaviours**, with every named evidence path verified to exist **and every review-only citation verified to contain the row it is cited for** — the latter added in bounded remediation, after review found seven citations that resolved to files not about their row. Core line coverage is **98.19%** against a 90% floor. The accumulated suite is **454 passed, 0 failed**. All six PRD goals are validated end-to-end on the **assembled** system.

Six defects were found and repaired in this node — none in shipped protocol code, all in the verification and release surfaces where a silent failure is most expensive:

1. **An unconstrained resolve of the accepted pins selects a pre-release.** `eth-account==0.11.3` declares `eth-abi >=4.0.0-b.2`; that pre-release identifier makes pip admit eth-abi pre-releases generally, and it picks `6.0.0b1`. Constrained to stable; landed on 5.2.0, which also clears both eth-abi advisories. A pinned root does not imply a stable closure.
2. **The static-analysis gate broke the test suite.** Its `--build-info` artifacts in the shared `out/` made `EventSchemaConformance.t.sol` exhaust EVM memory (MemoryOOG at ~1.07e9 gas vs 1.8e8 normally), turning the full suite red with a failure that had nothing to do with the product. Isolated into `out-slither/` via `--foundry-out-directory`.
3. **The gate died silently mid-run.** `census.sh` sets `-e`, which every sourcing gate inherits; a non-zero `pip show` aborted the script after 250 bytes of output with no diagnostic. Now `set +e` after sourcing, so `fail()`/`finish()` report *which* check failed. Also: `command -v python3` succeeding proves nothing on Windows (Store stub), so interpreter selection is now by trial.
4. **`.gitignore`'s bare `coverage/` silently swallowed the coverage gate.** Unanchored patterns match at any depth, so `tools/coverage/verify-coverage.sh` — a file CI invokes by path — would have been written, tested, passed locally, never committed, and failed CI with "file not found". Anchored to `/coverage/`.
5. **The §17 quarantine gate caught a literal `60 days` in the new E2E test**, colliding with a superseded research value. The usage was `2 × HALVING_PERIOD` and unrelated — but weakening the gate for a coincidence is the wrong trade. Every boundary now derives from `rig.HALVING_PERIOD()` / `rig.MAX_HALVINGS()`, which is independently better.
6. **`THIRD_PARTY_NOTICES.md` §6 was factually false** — *"None installed. Nothing imported or vendored yet."* — while 63 files were vendored and two npm roots installed, and it named a superseded Foundry version. Repaired; §6.3/§6.4 added; two transitive licence censuses produced, one of which surfaced a **proprietary non-commercial dependency** (`@metamask/sdk`) in the production dependency tree, proven not distributed.

---

## AC Verification

> Every acceptance criterion from the Sprint-8 scope (`grimoires/loa/a2a/sprint-8/sprint-8-scope.md`, extracted verbatim from `grimoires/loa/sprint.md`), quoted verbatim, with status and file:line evidence.

**AC-1**: "Zero unexplained slither findings (triaged baseline documented); slither entered CI only after its pin acceptance"

- **Status: ✓ Met**
- 68 findings, **0 high-impact**, 100% dispositioned across 11 detector classes — `tools/static-analysis/triage-baseline.json:1` (totals at `triage-baseline.json` `totals.by_verdict`: 37 accepted-design, 16 false-positive, 15 informational).
- The gate fails on any finding absent from the baseline, any stale baseline entry, and unconditionally on any High — `tools/static-analysis/compare-baseline.py:67`.
- **Fail-closed demonstrated**, not assumed: dropping one disposition makes the gate reject the tree (`.github/workflows/provenance.yml` job `static-analysis-negative-demonstration`).
- **Order respected**: no slither install, execution, CI entry, manifest mutation, or baseline existed before acceptance — the pre-acceptance state is recorded at `docs/authority/vux-v1-source-registry-static-analysis-refreeze-2026-08.json:111` (`install_state_evidence_at_gate`), and CI entry landed only after `activation: ACTIVE`.

**AC-2**: "Traceability: 37/37 invariants and 18/18 FB rows have named evidence per their assigned method; review-only items (FB-1, FB-6, FB-8…FB-12, FB-17, FB-18; prohibited-signal inspection) have named checklist entries in the review artifacts (sdd.md:L867)"

- **Status: ✓ Met**
- 37/37 INV and 18/18 FB — `grimoires/loa/a2a/sprint-8/traceability-matrix.md:1`; machine form at `traceability.json` (`totals.uncovered: []`).
- Generated from the tree, not hand-maintained — `tools/traceability/build-matrix.mjs:1`.
- The gate verifies **every named evidence path exists on disk** (45 distinct artifacts) — `tools/traceability/verify-traceability.sh:56`. That check caught five dangling references during development. It is the **weaker** of the two false-coverage modes: a dangling path announces itself, while a path that resolves and does not carry the row reads as coverage.
- The gate additionally verifies, for every `review-checklist` and `documented-analysis` citation, that the named artifact **contains the row id at word boundaries** (10 citations) — `tools/traceability/verify-traceability.sh:73`. This closes the stronger mode. **It was added in remediation, after review findings H-1 and M-1 found seven such citations in this tree** — FB-11 with no artifact anywhere, and six pointing at whole-sprint feedback files that never mention the row. The pre-remediation tree fails this check; that was demonstrated by re-applying the FB-11 citation and re-running the gate.
- **What the gate does not prove.** Containment establishes that a citation points at a document *about* the row. It does not establish that the document argues the row successfully — that is a reviewer's judgement, and no gate replaces it. The generator says the same thing about itself (`build-matrix.mjs:109`: "declarations OF LOCATION, not of sufficiency"), and this line now matches it rather than overstating it.
- Review-only rows carry their assigned method, each cited to the artifact that actually contains it: FB-1 → `sprint-3/evidence/fb-1-mining-redemption-independence.md`; FB-6/9/10/12 → `sprint-4/evidence/fb-6-9-10-12-scenario-notes.md`; FB-8 → `sprint-5/engineer-feedback.md` (AC-7 sign-off); FB-11 → `grimoires/loa/a2a/sprint-8/fb-11-analysis.md:1`; FB-17/18 → `grimoires/loa/a2a/sprint-8/fb-17-18-analysis.md:1`; INV-36 → `web/components/ReserveDescription.jsx` + `trust-inventory.md`; INV-37 → the CI provenance gate set.

**AC-3**: "§20.1 sweep green: FR-1…FR-11 + FR-14…FR-16 acceptance criteria pass; LSG inactive with activation authority present; all 37 invariants demonstrated; all 18 FB behaviors demonstrated; genesis/conversion evidence *procedure* verified (production values at deployment); YELLOW disclosure present; PROV-1…9 clean; truthful-UX review passed (prd.md:L878-L886)"

- **Status: ✓ Met** — 8/8 rows resolved, `grimoires/loa/a2a/sprint-8/launch-criteria-sweep.md:1`.
- FR sweep: 143 checked / 24 unchecked in `sprint.md`, every unchecked box being Sprint 8's own (`sprint.md:538-580`).
- LSG inactive with authority present — `test/e2e/GoalValidation.t.sol:350` and `:354`.
- Conversion **procedure** verified, **production values reserved** — the split the plan requires; slots at `grimoires/loa/a2a/sprint-8/deployment-runbook.md:5.2`.
- PROV gates: 11/11 green (`tools/provenance/run-all.sh:24-34`).

**AC-4**: "Line coverage ≥90% on core contracts; full accumulated invariant suite green"

- **Status: ✓ Met**
- **98.19% total (598/609 lines)**; per file: GenesisDeployer 100%, HardReserve 100%, Lens 100%, VUX 100%, Rig 98.7%, StrategicTreasury 96.9%.
- Enforced with **two** floors — per-file AND total, because an aggregate alone lets a large well-covered contract carry a neglected one — `tools/coverage/verify-coverage.sh:77`.
- Core surface is **derived** from `git ls-files`, not hardcoded, so a new core contract is gated the day it lands — `tools/coverage/verify-coverage.sh:31`.
- Accumulated suite: **454 passed, 0 failed, 10 skipped** of 464.

**AC-5**: "Runbook complete with every operator-reserved input explicitly slotted (Q-3 Safe facts, fee tier/tickSpacing, conversion values, schedule start) and none resolved in-repo"

- **Status: ✓ Met**
- `grimoires/loa/a2a/sprint-8/deployment-runbook.md:1` — **52 unfilled slots**, mechanically counted and asserted by `tools/provenance/final-secret-sweep.sh:92`.
- Q-3 §5.1 · conversion §5.2 · fee/tickSpacing §5.4 · schedule start §5.5 · launch secrets §5.6 · Q-4 §5.7 · R-14 post-deployment §5.8 · chain-environment facts §5.9.
- Private same-block procedure documented with the **security/confidentiality distinction preserved verbatim** — required for confidentiality, non-load-bearing for security (`deployment-runbook.md:4`).

**AC-6**: "Release files exact: GPLv3 text unmodified; TPN §6/§6.1/§6.2 match vendored reality byte-for-byte with the accepted version"

- **Status: ✓ Met**
- `LICENSE` unmodified GPLv3 — `sha256:8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903`, 674 lines.
- §6.1/§6.2 census content **unchanged** and byte-verified against vendored reality by `tools/provenance/verify-census.sh` (63/63) and `verify-notices.sh`.
- §6's **preamble** was factually false and is repaired (see Known Limitations #1 for the reconciliation this creates).

**AC-7**: "E2E validation (Task 8.E2E) documents each goal G-1…G-6 with pass evidence; no goal marked "not achieved" without explicit justification"

- **Status: ✓ Met** — 6/6 achieved, none marked "not achieved".
- `grimoires/loa/a2a/sprint-8/e2e-goal-validation.md:1`; implementation at `test/e2e/GoalValidation.t.sol:1` (10 tests, 10 passing).
- G-1 `test/e2e/GoalValidation.t.sol:57,76,108,143,190,234` · G-2 `:270,309` · G-4 `:350,354` · G-3/G-5/G-6 off-chain, evidence named in the document.
- **G-1 modality.** The plan's G-1 action alone specifies a **"Fork scenario:"** (`sprint.md:571`). Sprint 8 executed the scenario body locally on the assembled system (`GenesisFixture` uses `MockWeth`) and executed **no new fork run**. The fork modality is discharged by reuse of accepted Sprint-7 evidence — `grimoires/loa/a2a/sprint-7/evidence/q6-fork-run.txt`, RH mainnet `chainid 4663`, block `39130641`, 10/10, `OPERATOR_ACCEPTANCE — SPRINT_7_Q6_NATIVE_WRAP_ACCEPTED` — which is the only dimension a fork discriminates for G-1 (canonical RH WETH behaviour; the routing law, VEM cap, halving schedule and redemption arithmetic are chain-independent). The reasoning, the reuse, and the reason the 10 fork tests self-skip in the 464-test run are recorded in the G-1 evidence artifact itself (`e2e-goal-validation.md` §"Modality"). Earlier drafts of that artifact omitted the phrase; the omission was review finding M-3 and is repaired.

**AC-8**: "No production secret, address, or broadcast artifact anywhere in repo/CI (final hygiene sweep)"

- **Status: ✓ Met**
- `tools/provenance/final-secret-sweep.sh:1` — **all 436 tracked files, no directory excluded** (the per-push gate excludes `vendor/`, `docs/authority/`, `grimoires/`; this sweep does not).
- Context-discriminating patterns, not raw entropy: a bare 64-hex scan matches every census digest and commit SHA in the repository and is useless. Clean on all 8 patterns plus credential-shaped files and broadcast artifacts.

**AC-9**: "Each goal validated with documented evidence; integration points verified end-to-end"

- **Status: ✓ Met**
- Integration is the point of the suite: it extends `GenesisFixture`, which performs the real two-transaction launch, so every assertion is against what genesis actually produces — `test/e2e/GoalValidation.t.sol:41`.
- Integration points verified: genesis → Rig throne (`:108`), Rig → Reserve/Treasury routing legs (`:143`), Rig → VUX mint + Reserve → holder redemption (`:234`), Treasury → core isolation under loss (`:270`), Treasury → LSG slot (`:354`), Lens → Rig (`:112` clock-disabled during bootstrap, `:159` `rawClockLimit` driving the routing expectation), events → indexer reconstruction (`indexer/test/reconstruct.test.mjs`).

**AC-10**: "No goal marked "not achieved" without explicit justification"

- **Status: ✓ Met** — zero goals marked "not achieved"; the justification clause is not exercised. `grimoires/loa/a2a/sprint-8/e2e-goal-validation.md` summary table, 6/6 ✅.

---

## Tasks Completed

### Task 8.1 — Static-analysis provenance gate → **[G-5]**

**Pre-acceptance.** Established the exact pin from primary sources only: PyPI packuments, the **full** upstream tag namespace (48 tags, not a filtered subset), GitHub releases, the GitHub Advisory Database, and the platform adapter read at its pinned commit. Nothing installed, executed, or downloaded.

| Accepted | Identity |
|---|---|
| `slither-analyzer==0.10.4` | `crytic/slither` @ `aeeb2d368802844733671e35200b30b5f5bdcf5c` · AGPL-3.0 · wheel `sha256:344745d8…4a14` · sdist `sha256:bb899455…3a32` |
| `crytic-compile==0.3.7` | `crytic/crytic-compile` @ `20df04f37af723eaa7fa56dc2c80169776f3bc4d` · AGPL-3.0 · wheel `sha256:bd8fc87f…634b` · sdist `sha256:c7713d92…0d4b` |

`crytic-compile` is pinned at 0.3.7 rather than the range top because 0.3.7 is the **only** member of slither 0.10.4's admitted range that existed at its release date — the version it was actually built against.

**Post-acceptance.** Closure derived and materialized at `tools/static-analysis/requirements.txt`: **49 distributions**, every one pinned `==` with all published non-yanked `--hash=sha256:` digests (1,735 hash lines), 0 yanked artifacts. **Reachability proven, not assumed**: 49/49 traceable to the two accepted roots, **0 orphans**, with a named parent chain per distribution. Installed environment verified **exactly equal** to the reviewed file (49 = 49, no extras, no omissions, no version drift).

Gate at `tools/provenance/verify-static-analysis.sh`, mechanizing the accepted dispositions rather than restating them: D-S4 distribution-name assertion, D-S2 no-RPC-environment control, isolated build-info, and `$PY -m slither` invocation so the identity assertion binds to the thing that actually runs.

### Task 8.2 — Traceability matrix → **[G-6, G-1, G-2]**

`tools/traceability/build-matrix.mjs` + `verify-traceability.sh`. Parses the repository's `// carries:` convention including range forms (`INV-1 … INV-22`), attributes inline references to their enclosing test function, and merges declared non-test evidence for rows whose accepted method is a CI gate, a Playwright assertion, or a documented analysis. **37/37 and 18/18, zero uncovered.**

### Task 8.3 — §20.1 sweep + coverage gate → **[G-1…G-5]**

`launch-criteria-sweep.md` (8/8 rows) + `tools/coverage/verify-coverage.sh` (98.19%, dual floors) + its own CI job.

### Task 8.4 / 8.E2E — Goal validation → **[all]**

`test/e2e/GoalValidation.t.sol` (10 tests) + `e2e-goal-validation.md`.

### Task 8.5 — Release compliance → **[G-5]**

LICENSE verified unmodified. TPN repaired against reality; §6.3 and §6.4 added. Two transitive licence censuses produced: off-chain **675 packages** (closing Sprint 6's D-3) and static-analysis **49 distributions** (closing D-S1's licence half).

### Task 8.6 — Deployment runbook → **[G-1, G-6]**

`deployment-runbook.md`, 52 operator-reserved slots, software-established facts separated from operator-reserved inputs throughout.

### Task 8.7 — Operator docs → **[G-3, G-6]**

`trust-inventory.md` (YELLOW register, trust inventory, no-trustless-claims review, 12-item residual register) + `fb-17-18-analysis.md`.

### Task 8.8 — Cycle closeout prep → **[G-6]**

`cycle-closeout-prep.md` — branch pruning list with a merged-into-master precondition, durable artifact inventory, `/ship`-time items. **Prepared, not executed.**

---

## Technical Highlights

**Static analysis reads the accepted build rather than making its own.** `crytic-compile`'s foundry platform, verified at the pinned commits of both 0.3.7 and 0.3.11, skips `forge build` entirely under `--ignore-compile` and parses `<out>/build-info`. Three consequences that are provenance properties, not conveniences: slither adds **no compiler**; the analyzed AST is provably the accepted Foundry-v1.5.0 / solc-0.8.28 build's AST, so analysis and compilation cannot silently diverge; and `solc-select` — a hard transitive dependency — is installed but never exercised and downloads nothing.

**Zero new CI surface.** No `actions/setup-python`, no `crytic/slither-action`, no container runtime, no compiler. The repository's accepted posture for interpreters (`provenance.yml`: *"Asserted rather than assumed"*) is mirrored exactly.

**The E2E suite proves its own coverage.** The adaptive-routing test asserts that all three regimes were actually reached, rather than asking the reader to trust that six reign lengths happened to span them.

**Findings that required judgment, not just triage.** The `reentrancy-no-eth` finding on `redeemUnits` is dispositioned against `nonReentrant` + `onlyRole` + the fact that the cross-function path needs an adapter holding `OPERATOR_ROLE`, *and* against the accepted threat-row-9 analysis that an adversarial adapter's fraud is bounded by theft it could already commit. The `unused-return` findings on `burn`/`swap` are dispositioned as *correct by design*: both sites deliberately measure the treasury's own balance delta instead of trusting the pool's return value.

---

## Testing Summary

| Suite | Result |
|---|---|
| Forge (accumulated, 38 suites) | **454 passed, 0 failed, 10 skipped** (464 total) |
| — of which new | `test/e2e/GoalValidation.t.sol` — **10 passed** |
| Core line coverage | **98.19% (598/609)**, floor 90%, every file ≥96.9% |
| Playwright copy suite | **46 passed** |
| Indexer | **24 passed** (incl. reconstruction equality) |
| Web unit | **10 passed** |
| Static export / RSC gates | **PASS / PASS** |
| `forge lint` (accepted Foundry v1.5.0, no new provenance surface) | **0 high** (gated, not baselined) · **4 medium**, all dispositioned in `triage-baseline.json` `forge_lint` |
| Provenance gates | **11/11 green** |
| Evidence-pack path integrity | **171/171** repo-relative paths referenced across the 10 Sprint-8 documents exist on disk (audited at this node; the same discipline `verify-traceability.sh` enforces on the matrix) |

**The 10 skipped tests are all `test/fork/RhWethFork.t.sol`** — the Q-6 fork-evidence suite, which self-skips off-fork by design (`test/fork/RhWethFork.t.sol:259`). Running it requires an archive-capable RH RPC, an operator input (residual R-Y10). This is the accepted behaviour, not an unrun obligation: the Q-6 fact was closed at Sprint 7 with that suite executed against the fork.

**How to reproduce:**

```bash
export PATH="$HOME/.foundry/bin:$PATH"
python3.11 -m venv .sa-venv
./.sa-venv/bin/python -m pip install --require-hashes --no-deps -r tools/static-analysis/requirements.txt
PYTHON=./.sa-venv/bin/python bash tools/provenance/run-all.sh     # 11 gates + 454 tests
bash tools/coverage/verify-coverage.sh                            # 98.19%
forge test --match-path 'test/e2e/*' -vv                          # the 10 goal tests
(cd indexer && npm test) && (cd web && npm run test:units && npm run test:copy)
```

---

## Known Limitations

1. **TPN hash reconciliation (documentation, carried to review).** Repairing `THIRD_PARTY_NOTICES.md` changed its SHA-256 from `963e2cfb…170873` to `40abb254…248f`. `sprint.md:33` (Authority Chain) and `vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md:98` both record the old value. `tools/provenance/census.sh:33` is updated so the gate tracks reality; **accepted authority was deliberately not edited**. Recorded as a reconciliation item, following the Sprint-6 precedent for `sdd.md:L449`. The repair was mandated by §6's own rule that every adopted dependency be recorded.

2. **Proprietary non-commercial dependency in the dev/CI tree (R-Y4).** `@metamask/sdk@0.32.0` and two siblings, via `@wagmi/connectors`. **Not distributed** — verified by exhaustive scan of all 38 files / 1,220,956 bytes of the built static export. The distributed artifact is clean; the development environment installs it. Bounded and disclosed, not resolved.

3. **`web3` CCIP-Read SSRF (D-S2, R-Y5)** — accepted residual; unreachable on the authorized invocation; enforced by the no-RPC control. **Lapses if static analysis is ever widened to a provider path.**

4. **slither 0.10.4 language boundary (D-S3, R-Y6)** — 0.10.4 parsed the accepted build-info successfully at this node. No in-family fallback exists; 0.11.x needs a new operator gate.

5. **Python range is tighter than the refreeze proposed (R-Y8).** `[3.10, 3.12)` rather than `>=3.10, !=3.12.0`, because the derived closure is wheel-complete only there. Both versions are in the ubuntu-latest tool cache.

6. **Coverage requires `--ir-minimum` and an isolated output directory.** `forge coverage` disables the optimizer and `viaIR`, and the `=0.8.28` unit does not compile that way. It also changes the artifact JSON, which broke 39 artifact-reading tests when it shared `out/` — the same class of defect as #2, found the same way. Both are documented in the gate; the instrumented build now goes to `out-coverage/`.

7. **Branch coverage is not gated.** The accepted requirement is line coverage (`sdd.md:L871`). Branch coverage is 74.31% overall, dominated by `GenesisDeployer` at 11.76% — its branches are one-shot constructor revert paths, most of which are unreachable without mutating the deployment. Recorded, not gamed.

8. **Q-3 and Q-4 remain open** — production-launch gates by design, slotted in the runbook, not Sprint-8 blockers.

---

## Bounded Remediation — response to `SPRINT_8_REVIEW_CHANGES_REQUIRED`

A second `/implement sprint-8` node addressed **only** the four blocking/remediation items enumerated by the reviewer (H-1, M-1, M-2, M-3). The rest of Sprint 8 was not reopened; the accepted LOW and informational findings (L-1…L-4, including the beads-graph drift the reviewer characterised as lifecycle bookkeeping) were deliberately left alone. **No protocol Solidity changed** — `git diff 6395cabb -- src/` is empty and `src/` has no working-tree modification. No accepted authority document was edited. `engineer-feedback.md` was not touched: it is the historical review record.

| Finding | Repair | Where |
|---|---|---|
| **H-1** — FB-11 cited an artifact that never mentions it; no FB-11 evidence existed anywhere | Authored the missing review-assigned scenario analysis and repointed the row at it | new `grimoires/loa/a2a/sprint-8/fb-11-analysis.md`; `build-matrix.mjs` |
| **M-1** — six further review-only citations named files that do not contain the row | Each repointed at the artifact that verifiably carries it (content-checked, not path-checked), classification preserved as `review-checklist` | `build-matrix.mjs`; restatements in `launch-criteria-sweep.md` Row 4 and AC-2 above |
| **M-2** — the gate proved path existence, not evidence truth, so H-1/M-1 passed mechanically | Added a word-boundary containment assertion over every `review-checklist` / `documented-analysis` citation; corrected AC-2's description of what the gate proves | `verify-traceability.sh:73`; AC-2 above |
| **M-3** — G-1 evidence elided the plan's "Fork scenario:" requirement instead of documenting how it was met | Restored the plan's G-1 action verbatim and added a *Modality* section naming the reused Sprint-7 fork evidence, what it discriminates, what Sprint 8 ran locally, and why the 10 fork tests self-skip | `e2e-goal-validation.md` §G-1 |

**FB-11's evidence is genuine, not restated requirement text.** `fb-11-analysis.md` discharges the row's two clauses against twelve named anchors — five `TreasuryLsgBoundary.t.sol` tests in which `MockLsgModule` *is* the captured-module case (admission not signalable, caps clamp with the overflow staying in custody, a signal naming the monetary core reaching nothing, the module holding no allowance or role, removal surviving a dead module), plus `removeStrategy`/`recallFromStrategy` being ungated by LSG state — and states the accepted residual (`sdd.md:953`: signal skew inside the admitted+capped menu) rather than claiming bribery is prevented. It also states plainly that the `LSGSignals` module is P1 and absent from `src/`, separating the P0 mechanical layer from the P1 design layer.

**The M-2 gate was proven discriminating, not merely added.** Three negative probes, each reverted byte-for-byte afterwards (`build-matrix.mjs`, `traceability.json`, `traceability-matrix.md` all restored to their pre-probe digests):

| Probe | Mutation | Result |
|---|---|---|
| A | FB-11 → `sprint-5/engineer-feedback.md` (the exact pre-remediation citation) | **gate fails** — reproduces H-1 mechanically |
| B | FB-6 → `sprint-3/evidence/fb-1-mining-redemption-independence.md` — a **valid, real evidence path** deliberately mapped to the wrong requirement | **existence check still passes** ("45 distinct evidence artifact(s) all present on disk"), **containment check fails** — the discriminating case |
| C | FB-1 → `fb-17-18-analysis.md`, which contains `FB-17`/`FB-18` but no `FB-1` | **gate fails**; a naive substring test matches 8 lines and would pass. The word boundaries are load-bearing, not cosmetic |

Post-remediation the gate is green: 37/37 INV, 18/18 FB, 45 evidence paths present, **10/10 review-only citations carry their row**.

---

## Verification Steps for the Reviewer

1. **Confirm the gate was respected.** `docs/authority/vux-v1-static-analysis-provenance-refreeze-2026-08.md` §1 and §10; the registry's `install_state_evidence_at_gate`; acceptance recorded at §10 with the re-verified pre-acceptance digests.
2. **Re-derive the closure.** Every distribution in `tools/static-analysis/requirements.txt` should trace to the two accepted roots. Install with the invariant and confirm the environment equals the file.
3. **Test the gates rather than reading them.** Drop one entry from `triage-baseline.json` and confirm the gate rejects the tree. Break one evidence path in `build-matrix.mjs` and confirm traceability fails. **Then test the stronger mode:** repoint a review-only row at a path that *exists* but carries a different row — e.g. `'FB-6'` → `sprint-3/evidence/fb-1-mining-redemption-independence.md` — and confirm the existence check still passes while the containment check fails. Restore the generator and re-run it afterwards; the gate rewrites `traceability.json` and `traceability-matrix.md` in place.
4. **Check the dispositions, not the count.** `triage-baseline.json` `class_dispositions` — especially `reentrancy-no-eth` and `unused-return`, the two that required judgment.
5. **Confirm nothing was resolved that should not be.** 52 unfilled runbook slots; the final sweep over all 436 tracked files.
6. **Confirm no commit exists.** `git rev-list --count 6395cabb..HEAD` → `0`.
