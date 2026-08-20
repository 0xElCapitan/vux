All good

# Sprint 8 — Focused Re-Review: Hosted-CI Control Remediation

**Verdict:** `APPROVED`
**Node:** `/review-sprint sprint-8` — focused re-review of the CI-control remediation only. No
remediation, no audit, no commit.
**Branch:** `sprint-8` · **Tip:** `e9d04003d9067cc67cfa139c6df70538a48adbcc`
**Scope:** the three changed Group-A files and their integration. The rest of Sprint 8 is not
reopened; the prior two passes stand.

The remediation is correct, bounded, and better than the tree it replaces. Both hosted-CI
defects are genuinely fixed — I reproduced each from a real empty build state rather than
reading the claim. The negative demonstration, which was previously satisfiable by a broken
analyzer, is now a controlled experiment. Nothing was weakened: every threshold, pin, isolation
boundary and fail-closed path is intact, and no protocol, authority, dependency or test surface
moved.

---

## 1. Identity — independently derived

| | Reported | Re-derived | Result |
|---|---|---|---|
| Group A (16 files) | `dfeb8f58e175e62a39c4b8f50ddf6dc477d6b3ba27d38620ecb65302cef07038` | identical | **MATCH** |
| Group B (2 files) | `1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437` | identical | **MATCH — unchanged** |

**Group B was checked first, as the stated stop condition.** It is byte-identical to the value
carried through both prior passes. No accepted authority moved; the review proceeded.

**History is the expected linear fast-forward**, each commit with exactly one parent:

```
6395cabb ← 67769a75 (land Sprint 8) ← f14f3c18 (diagnostics) ← e9d04003 (fresh-checkout prereqs)
```

`master` and `origin/master` both remain at `6395cabb`; one worktree; Group A working tree clean.

**Exactly three Group-A files moved**, and they are the three named:

| File | Before → after |
|---|---|
| `.github/workflows/provenance.yml` | `d9867749…` → `04c2c3f2…` |
| `tools/coverage/verify-coverage.sh` | `1e0a6f43…` → `2a375c83…` |
| `tools/provenance/verify-static-analysis.sh` | `13e06766…` → `7439e9a4…` |

The other thirteen re-hash byte-identical to the review-approved values. Cumulative diffstat is
**3 files changed, 150 insertions(+), 7 deletions(-)** — exactly as reported.

**Scope preservation — verified, not assumed.** `git diff 67769a75 e9d04003` over `src/`,
`test/`, `docs/authority/`, `grimoires/loa/prd.md`, `grimoires/loa/sdd.md`,
`grimoires/loa/sprint.md`, `foundry.toml`, `vendor/`, `lib/`, `tools/static-analysis/` and the
package/lock files is **empty**. `grimoires/loa/a2a/` is likewise empty — every historical
review, audit and acceptance artifact is untouched, including both prior review passes
(`engineer-feedback.md` still `6630a959…`).

---

## 2. Coverage gate · **CORRECT**

The defect was real and the diagnosis is right: `[profile.v3core]` is a second compilation unit
under a different profile, three test files hardcode `out-v3core/...` paths through
`vm.readFile`, and one of them — `test/treasury/PoolDeployerHarness.sol` — is a *shared
harness*, which is why a missing directory took out ~52 tests rather than three. Locally the
directory always existed because `run-all.sh` builds both units; the coverage job never runs
`run-all.sh`, so a fresh hosted checkout had nothing to read.

**The fix is the right shape.** The gate now builds the second unit explicitly, by profile
name, with its own fail-closed check and diagnostic. It does not vendor settings, does not
touch `foundry.toml`, and does not reach into the other unit.

| Requirement | Finding |
|---|---|
| Floor remains ≥ 90% | `THRESHOLD=90`, unchanged; the diff contains no threshold, floor or lcov-parsing line |
| Core surface unchanged | Still derived from `git ls-files 'src/*.sol'` minus `interfaces/` and `v3core/` — 6 contracts, same list, hosted and local |
| No file dropped | A core file with no lcov record still **fails** ("it was not instrumented"), so silent removal cannot pass |
| No tests skipped for green | No `--skip`, `--match-path` or `--no-match-test` added; hosted `gates` job still reports **454 passed, 0 failed, 10 skipped (464)** — the same figures I verified independently in the first pass, with the 10 being the designed off-fork suite |
| `--ir-minimum` intact | Preserved verbatim, together with `--report lcov --no-match-coverage '(test\|script\|vendor)'` |
| v3-core built under its own accepted profile | `env FOUNDRY_PROFILE=v3core forge build` — the profile carries the complete frozen set (solc 0.7.6, `optimizer_runs = 800`, `evm_version = istanbul`, `bytecode_hash = none`, `via_ir = false`) that reproduces `POOL_INIT_CODE_HASH` |
| Cannot contaminate the `=0.8.28` unit | `[profile.v3core]` declares `out = "out-v3core"` and `cache_path = "cache-v3core"`; the invocation names the profile only, so both outputs and caches are disjoint from `out/`/`cache/` by configuration, not by convention |
| Output isolation correct | Three disjoint trees: `out/` (normal), `out-v3core/` (=0.7.6), `out-coverage/` (instrumented, via `FOUNDRY_OUT`) — all gitignored, so the CI post-step `git diff --exit-code` still holds |
| Works from a fresh checkout | **Reproduced.** See below |

**Fresh-checkout reproduction.** I deleted `out/`, `out-v3core/`, `out-slither/`, `cache/`,
`cache-v3core/` and `lcov.info` (each confirmed gitignored first; no tracked file touched) and
ran the gate from that state:

```
ok    normal build present in out/ for the artifact-reading suites
ok    =0.7.6 vendored unit present in out-v3core/ for the artifact-reading suites
ok    forge coverage completed (instrumented build isolated in out-coverage/)
ok    src/GenesisDeployer.sol   100.0% (134/134)   ok  src/Rig.sol                98.7% (76/77)
ok    src/HardReserve.sol       100.0% (24/24)     ok  src/StrategicTreasury.sol  96.9% (316/326)
ok    src/Lens.sol              100.0% (34/34)     ok  src/VUX.sol               100.0% (14/14)
ok    core total 98.1%  (598/609 lines) — floor is 90%
All checks passed.                                                          [exit 0]
```

That is the reported hosted result — **598/609, 98.1%, every named file above the floor** —
reproduced locally from the exact state that broke CI. The hosted log for run `32387964906`
carries the identical figures under `FOUNDRY_PROFILE=ci`.

**No hidden execution-order dependency was created; one was removed.** The order
(normal build → v3-core build → coverage) is real, but it is now *declared and enforced*: each
step is checked and `finish`es on failure. The hidden dependency was the previous state, where
the second unit was satisfied only by artifacts a prior `run-all.sh` happened to leave behind —
which is precisely why it passed locally and failed hosted.

---

## 3. Static-analysis gate · **CORRECT**

The diagnosis is exact and the fix is minimal. Slither writes its report with a plain
`open(path, "w")`, which cannot create a missing parent; the parent is `out/`, which this gate
deliberately never builds into. On a fresh checkout the analysis completed and was discarded at
the final write.

| Requirement | Finding |
|---|---|
| Accepted pins | `slither-analyzer==0.10.4` and `crytic-compile==0.3.7` — both asserted live by the D-S4 block, hosted and local |
| Authority + Python closure | `docs/authority/**` and `tools/static-analysis/requirements.txt` byte-unchanged; the gate's `require_authority` check is untouched and green |
| `--ignore-compile` | Preserved verbatim — slither still adds no compiler |
| Build-info isolation | `--out "$SA_OUT"` and `--foundry-out-directory "$SA_OUT"` both still `out-slither/`; unchanged by the diff |
| Report at the authority-recorded path | `REPORT="out/slither-report.json"`, matching the refreeze §-recorded invocation (`--json out/slither-report.json`) in both the markdown and the registry |
| `mkdir -p` does not reintroduce shared-build contamination | **Verified empirically — see below** |
| Stale-report protection | `rm -f "$REPORT"` still runs *after* the `mkdir`, so a leftover report cannot satisfy the gate |
| Exit-status semantics | Still deliberately not consulted (`\|\| true`), with the original reasoning intact: slither returns non-zero whenever findings exist, and the dispositions are the gate |
| 68 / 68 / 0 high | Reproduced locally from a state with `out/` and `out-slither/` both absent, and present in the hosted log |

**Fresh-checkout reproduction**, with `out/` and `out-slither/` deleted first:

```
ok  distribution 'slither-analyzer' == 0.10.4 (the accepted pin)
ok  distribution 'crytic-compile'   == 0.3.7  (the accepted pin)
ok  unrelated PyPI distribution 'slither' absent
ok  no RPC/provider endpoint configured — D-S2's bounded-invocation condition holds
ok  forge emitted 1 build-info artifact(s) into out-slither/ under the accepted Foundry/solc pins
    slither findings : 68        baseline entries : 68
ok  every finding carries a triaged disposition; 0 high-impact
ok  static-analysis baseline clean
ok  forge lint: 0 high-severity finding(s) · 4 medium-severity, matching the recorded dispositions
All checks passed.
```

**Contamination check, done properly.** After the run I inspected what actually landed where.
`out-slither/build-info` holds the analyzer's artifact at **4,963,733 bytes**; `out/` holds a
`build-info` of **3,391 bytes**. I isolated the cause rather than assuming it: deleting `out/`
and running `forge lint src/` alone recreates it, so the small artifact is `forge lint`'s, not
slither's, and the lint block is **untouched by this remediation** — pre-existing behaviour.
The hazard the prior review recorded was the ~5 MB analyzer build-info in shared `out/` driving
`EventSchemaConformance.t.sol` to MemoryOOG at ~1.07e9 gas. I ran that exact canary against the
current state: **9 passed, 0 failed**, peak `gas: 179,985,681` — the normal ~1.8e8 budget, three
orders of magnitude from the failure. The 5 MB artifact stays isolated; creating the report's
parent does not reintroduce the defect.

**D-S2 preserved exactly.** The block is untouched, the no-RPC control is live and green in both
the hosted log and my local run, the registry's accepted characterization is unchanged
("the vulnerable package is **PRESENT** … but the vulnerable path is structurally unreachable on
the authorized VUX invocation"), and none of the three changed files uses any of the prohibited
restatements (`fixed`, `absent`, `non-vulnerable`) for it.

**A-3 not reopened.** The remediation changes nothing about config loading — the diff contains
no `--config-file` or `slither.config.json` line, and the invocation's explicit flags are
unchanged.

---

## 4. Positive / negative controls · **CORRECT — this is the strongest part of the change**

The reasoning in the workflow comment is right and it is the reasoning I would have written:
*"the gate failed" is also satisfied by a gate that could not RUN at all.* Before this change the
negative demonstration proved nothing about the disposition machinery, and the 2026-08-20 failure
is the proof — the mutation under test was never reached.

**Positive control** (`- name: Positive control — slither runs and the accepted tree is clean`)
runs the unmodified gate before any mutation. On hosted run `32387964906` it is **step 6,
success**, and its log carries the full chain: D-S4 both pins asserted, D-S2 no-RPC control,
build-info isolated in `out-slither/`, **`slither findings : 68` / `baseline entries : 68` /
`0 high-impact` / `static-analysis baseline clean`**. Slither demonstrably executed against the
accepted build-info on a fresh hosted checkout and produced the exact triaged count.

**Negative control** (step 7, success) is genuinely discriminating, and the discrimination is
mechanical rather than rhetorical:

```bash
if bash tools/provenance/verify-static-analysis.sh > /tmp/out 2>&1; then
  echo "::error::gate PASSED with an undispositioned finding — it is not fail-closed"; exit 1
fi
grep -q "no disposition in the baseline" /tmp/out || {
  cat /tmp/out; echo "::error::gate failed, but not for the expected reason"; exit 1; }
```

A broken analyzer fails with `slither produced no report at out/slither-report.json`, which does
**not** contain `no disposition in the baseline` — so the grep fails and the step errors out.
**A broken analyzer cannot satisfy this demonstration.** The hosted log confirms the intended
path was taken: it prints `gate correctly rejected the undispositioned finding`, which is only
reachable past *both* the non-zero exit and the specific-reason grep. Step 8 then restores the
baseline and asserts `git diff --exit-code` plus an empty `git status --porcelain`.

With both halves in one job on one checkout, the only difference between step 6 passing and step
7 failing is the single removed disposition. That is a controlled experiment.

**The gate is also self-sufficient**, so the pairing introduces no ordering dependency of its
own: `mkdir -p "$(dirname "$REPORT")"` runs unconditionally inside the gate, so step 7 would work
without step 7's predecessor having created `out/`.

---

## 5. Diagnostics · **CORRECT, and probed**

`run_logged` captures stdout+stderr to a temp log and preserves status
(`DIAG_STATUS=$?; return "$DIAG_STATUS"`); `diag` prints, to stderr, the exit status and the last
`DIAG_TAIL=200` lines with a header naming `shown of total`. Both gates run under
`set -uo pipefail` + `set +e`, so a captured failure accumulates and reports rather than aborting
— consistent with the accumulate-and-report posture established earlier in this sprint.

| Requirement | Finding |
|---|---|
| Concise green output | A successful step still prints one `ok` line; my fresh runs above are the evidence |
| Load-bearing diagnostics on failure | **Probed — see below** |
| Non-zero exit preserved | `run_logged` returns the real status; the gate closed with `2 check(s) failed` |
| Failures not swallowed | Every `diag` call sits on a `fail` path; `diag` writes to stderr and never alters status |
| Bounded output | Tail capped at 200 lines, with `shown`/`total` printed so truncation is visible rather than silent |
| Killed / empty-output legible | `total=0` prints `exit N, last 0 of 0 output line(s)` — the header alone distinguishes "died without output" from "failed with output", which is exactly the case the comment says it is for |
| Cleanup safe | `trap 'rm -rf "${DIAG_DIR:?}"' EXIT` — the `:?` guard against an empty `mktemp` result is the right instinct |

**Probe (non-mutating; PATH altered for one invocation only).** I ran the static-analysis gate
with `forge` unavailable. The old gate would have printed `slither produced no report` and
nothing else. The new one printed the actual cause:

```
| crytic_compile.platform.exceptions.InvalidCompilation: Compilation failed. Can you run build command?
| out-slither\build-info is not a directory.
---- end slither ----
2 check(s) failed.
```

That is precisely the class of root cause the old suppression hid, surfaced without a
reproduction step, with non-zero status preserved and nothing mutated (`git status` clean over
`tools/`, `.github/`, `src/`, `test/`, `docs/`). This is not a generalized logging framework —
two small helpers, used on the load-bearing calls only — which is the right size.

---

## 6. Hosted evidence · **exact-SHA correspondence confirmed**

Retrieved directly from the GitHub API, not from the report:

| | |
|---|---|
| Run | `32387964906` (`repos/0xElCapitan/vux`) |
| `head_sha` | **`e9d04003d9067cc67cfa139c6df70538a48adbcc`** — the exact remediation tip |
| `head_branch` / event | `sprint-8` / `push` |
| Status / conclusion | `completed` / **`success`** |
| Created | 2026-08-20T15:44:49Z |

**All seven branch jobs green**, and the seven are the seven the workflow defines: provenance
gates · core line coverage ≥ 90% · static-analysis gate fails closed on an undispositioned
finding · drift gate fails closed on a 1-byte mutation · source boundary fails closed on
out-of-root, mis-cased and non-Solidity-named source · off-chain gates (indexer + web) ·
accepted-pin gate fails closed on a mutated pin.

Job logs were read, not inferred: the coverage job's `598/609 · 98.1%` with the new
`=0.7.6 vendored unit present in out-v3core/` line; the negative-demonstration job's positive
control at 68/68/0-high followed by `gate correctly rejected the undispositioned finding`; and
the gates job's `454 tests passed, 0 failed, 10 skipped (464)`.

---

## 7. Findings

**0 critical · 0 high · 0 medium · 0 low.** No defect in the reviewed change.

Two bounded observations, both **informational**, both pre-existing and outside the changed
surface — recorded because the new diagnostics are what made the first one visible, not as a
reason to withhold approval:

**N-1 — `forge lint --severity high` reports a result it did not observe.** `lint_high` counts
matching lines from `forge lint`'s output; when `forge` cannot run, the count is `0` and the gate
prints `ok forge lint: 0 high-severity finding(s)`. The lint block is untouched by this
remediation and this cannot produce a false green: the earlier `forge build --build-info` step
already fails loudly in that scenario, so the gate exits non-zero regardless (my probe closed
with `2 check(s) failed`). The medium half is genuinely fail-closed — `expected_med` reads `4`
from the baseline, so a non-running lint yields `0 != 4` and fails. Worth a future one-line
liveness assertion; not a Sprint-8 blocker and explicitly not in this review's scope.

**N-2 — `forge lint` incidentally writes `out/build-info`.** 3,391 bytes, versus the analyzer's
4,963,733 bytes isolated in `out-slither/`. Pre-existing, and demonstrated harmless above by the
`EventSchemaConformance` canary (9/9, gas 1.8e8). Recorded only so a future reader who greps for
`out/build-info` does not mistake it for a regression of the isolation fix.

**Prior Sprint-8 findings are unchanged and not re-graded.** The four LOWs recorded in
`engineer-feedback-2.md` (L-1 stale "74 VUX-owned"; L-2 presence-only slot assertion;
L-3 traceability gate regenerates in place; L-4 beads epic/task inconsistency) remain open and
bounded there. None is touched by this remediation and none is reopened here.

---

## 8. Review-node hygiene

**Files written by this review:** exactly one —
`grimoires/loa/a2a/sprint-8/engineer-feedback-3.md` (this file).

**No implementation or authority mutation occurred.** Group A re-derives
`dfeb8f58e175e62a39c4b8f50ddf6dc477d6b3ba27d38620ecb65302cef07038` and Group B
`1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437` after all probing —
identical to entry. `HEAD` is still `e9d04003…`, `master`/`origin/master` still `6395cabb`, one
worktree. The only tracked files modified during this session are the two hook-appended
trajectory logs (`karpathy-2026-08-20.jsonl`, `zone-guard-2026-08-20.jsonl`), which are
Loa-appended on every tool call and are outside every subject group. Both prior review artifacts
are byte-intact.

**Temporary state during review:** gitignored build artifacts only — `out/`, `out-v3core/`,
`out-slither/`, `out-coverage/`, `cache/`, `cache-v3core/`, `lcov.info` were deleted and
rebuilt to reproduce the fresh-checkout condition. Each was confirmed gitignored before removal;
no tracked file was touched. The one PATH-scoped probe mutated nothing.

**Nothing was committed, pushed, tagged, landed, deployed, or marked complete. No audit was
begun.**

---

## 9. Recommendation

**`SPRINT_8_CI_REMEDIATION_REVIEW_APPROVED`.**

Both defects were real, both diagnoses are correct, and both fixes are the minimum that actually
holds — a profile-named build for the unit the job never built, and a `mkdir -p` for a parent the
writer cannot create. Neither reaches for a threshold, a pin, or a skip. The commit split is also
right: diagnostics first, then the prerequisites those diagnostics exposed, which is the order in
which the information actually arrived.

The part I would single out is the positive control. The honest reading of the 2026-08-20 failure
is that the negative demonstration had been passing for reasons nobody had checked, and the
response was to make the pair a controlled experiment rather than to fix the symptom and move on.
The `grep -q "no disposition in the baseline"` assertion is what turns "the gate failed" into
"the gate failed *for the reason under test*", and it is the difference between a demonstration
and a ritual.

**Recommended next node:** `/audit-sprint sprint-8`, against tip `e9d04003…` with the Group A
fingerprint recorded in §1.

---

*Focused re-review by the Loa `/review-sprint sprint-8` node, 2026-08-20, third pass. Every*
*claim above was re-derived on the exact tip: both group fingerprints, the full cumulative diff,*
*a fresh-checkout reproduction of the coverage gate from a genuinely emptied build state*
*(598/609, exit 0), a fresh-checkout reproduction of the static-analysis gate with `out/` and*
*`out-slither/` both absent (68/68, 0 high), an isolation experiment identifying `forge lint` as*
*the source of `out/build-info` plus the `EventSchemaConformance` canary showing the MemoryOOG*
*hazard does not recur, a PATH-scoped probe exercising the diagnostics failure path, and direct*
*GitHub API retrieval of run 32387964906 with its job and step conclusions and log contents.*
*Nothing was accepted on report. No implementation source, authority document, evidence*
*artifact, or prior review artifact was modified — both group fingerprints are identical before*
*and after. Nothing was committed, pushed, or marked complete, and no audit was begun.*

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":0},"sprint_id":"sprint-8","ts":"2026-08-20T00:00:00Z"} -->
