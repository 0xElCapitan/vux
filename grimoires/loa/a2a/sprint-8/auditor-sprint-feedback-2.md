# Sprint 8 — Focused Security Audit: hosted-CI control remediation

**Verdict:** `APPROVED - LET'S FUCKING GO`
**Node:** `/audit-sprint sprint-8` — focused audit of the three changed control files only. No
remediation, no renewed operator acceptance, no landing, no deployment, no retrospective.
**Branch:** `sprint-8` · **Tip:** `e9d04003d9067cc67cfa139c6df70538a48adbcc`
**Counts:** **0 critical · 0 high · 0 medium · 0 low · 3 informational.**

The remediation is correct and is the smallest change that could fix what broke. Both hosted
failures were genuine fresh-checkout artifact-precondition defects, and I confirmed that from the
hosted logs rather than from the claim. Nine functional lines close both. No threshold, pin,
isolation boundary, authority, dependency, or protocol semantic moved — I checked each one
individually rather than inferring it from the diffstat.

Two things I want on the record. First, the strongest evidence for the new positive control is not
the passing run: it is that the control **failed closed on the real defect on its first hosted
outing** (`f14f3c18`, step 6 failed, step 7 skipped). Second, and going the other way, the stated
motivation for that control slightly overstates the prior risk — the old negative demonstration was
already not falsifiable by analyzer failure, and I have the hosted evidence and a local reproduction
to show it. That is R-I2 below. It does not change the verdict; it changes what a later reader
should believe about the tree they inherited.

---

## 1. Identity — derived before auditing

| Group | Reported | Independently derived (entry) | Re-derived (exit, post-probe) | Result |
|---|---|---|---|---|
| A — implementation (16) | `dfeb8f58e175e62a39c4b8f50ddf6dc477d6b3ba27d38620ecb65302cef07038` | identical | identical | **MATCH** |
| B — activated authority (2) | `1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437` | identical | identical | **MATCH — exact, unchanged** |

**Group B is byte-identical to the value carried through implementation, both reviews and the
original audit.** The authority tree is the same one. This audit was cleared to proceed.

**History is exactly the declared chain**, verified with `git rev-list --reverse 6395cabb..HEAD`:

```
6395cabb  build: land Sprint 7 …                    (baseline; master and origin/master)
67769a75  build: land Sprint 8 — Launch Readiness…  (failed landing candidate)
f14f3c18  ci: make the …gates report why they failed (diagnostics)
e9d04003  ci: give both gates the fresh-checkout prerequisites they assumed (tip)
```

`master` = `origin/master` = `6395cabb…` — **untouched**. One registered worktree. `origin/sprint-8`
is at `e9d04003…`, the same commit as local HEAD.

---

## 2. The audit surface — exactly three files, and nothing else

`git diff --name-only 67769a75 e9d04003` returns **exactly**:

```
.github/workflows/provenance.yml
tools/coverage/verify-coverage.sh
tools/provenance/verify-static-analysis.sh
```

`3 files changed, 150 insertions(+), 7 deletions(-)` — reproduces the reported delta exactly.

**The other thirteen Group-A members are byte-identical to the digests I recorded at the original
audit** — I compared each individually, not the group hash: `.gitignore` `0e7530cd…`,
`THIRD_PARTY_NOTICES.md` `40abb254…`, `test/e2e/GoalValidation.t.sol` `72e6cdfa…`,
`licence-census.mjs` `1f52b35c…`, `census.sh` `9bdd517e…`, `final-secret-sweep.sh` `c58b4b72…`,
`run-all.sh` `ccaa00ea…`, `compare-baseline.py` `83ddd3ef…`, `requirements.txt` `ff44ce18…`,
`slither.config.json` `2b45af0e…`, `triage-baseline.json` `d5ad0067…`, `build-matrix.mjs`
`94e58d5d…`, `verify-traceability.sh` `b0e4a2e3…`. The three that moved start from exactly their
previously-audited values (`d9867749…`, `1e0a6f43…`, `13e06766…`).

**Nothing else moved.** `git diff --quiet 67769a75 e9d04003` is clean over every path the brief
enumerates: `src/`, `test/`, `script/`, `docs/authority/`, `vendor/`, `lib/`, `indexer/`, `web/`,
`foundry.toml`, `remappings.txt`, `requirements.txt`, `triage-baseline.json`, `slither.config.json`,
`compare-baseline.py`, `census.sh`.

**Split by commit** — the functional fix is nine lines:

| Commit | Files | Delta | Content |
|---|---|---|---|
| `f14f3c18` | 3 | +118 / −7 | `run_logged`/`diag` wrappers in both gates; the 17-line workflow positive control |
| `e9d04003` | 2 | **+32 / −0** | the v3core prebuild block (7 lines) and `mkdir -p "$(dirname "$REPORT")"` (1 line) |

---

## 3. Hidden-artifact-ordering — **eliminated**, probed from an empty workspace

This was the root-cause class, so I attacked it directly rather than reasoning about it.

**Probe C1 — fresh-checkout simulation.** I removed `out/`, `out-v3core/`, `out-coverage/`,
`out-slither/`, `cache/`, `cache-v3core/` and `lcov.info` (every one gitignored; `git status
--porcelain --untracked-files=no` confirmed no tracked file was disturbed), then ran **only**
`tools/coverage/verify-coverage.sh` with nothing else:

```
      FOUNDRY_PROFILE=default
ok    normal build present in out/ for the artifact-reading suites
ok    =0.7.6 vendored unit present in out-v3core/ for the artifact-reading suites
ok    forge coverage completed (instrumented build isolated in out-coverage/)
ok    core total 98.1%  (598/609 lines) — floor is 90%
All checks passed.                                                       GATE EXIT: 0
```

**The gate builds every artifact it depends on.** It no longer inherits anything.

**Probe C2 — is the prebuild load-bearing or incidental?** I deleted `out-v3core/` and ran the
suites that read it *without* the prebuild. Every one failed:

```
[FAIL: vm.readFile: failed to open file "…\out-v3core\VuxPoolDeployer.sol\VuxPoolDeployer.json":
       The system cannot find the path specified. (os error 3)] test_EmitsCanonicalPoolDeployed()
```

— the original defect, reproduced locally. **Absent artifacts fail; they do not silently pass.**
Re-running the remediated gate from that same state rebuilt `out-v3core/` and returned
`core total 98.1% (598/609)`, exit 0. The prebuild is load-bearing and the gate self-heals.

**No profile leakage — measured from the artifacts, not argued.** `env FOUNDRY_PROFILE=v3core`
scopes to that one process:

| output dir | solc | evm_version | via_ir | optimizer runs |
|---|---|---|---|---|
| `out/` | 0.8.28 + `7893614a` | prague | **true** | 200 |
| `out-v3core/` | **0.7.6 + `7338295f`** | **istanbul** | **unset** | **800** |

Those are exactly the frozen `[profile.v3core]` settings the refreeze §7 requires to reproduce
`POOL_INIT_CODE_HASH`. The default unit is untouched. `out/` carries only the `>=0.5.0` v3-core
*interfaces* the `=0.8.28` unit legitimately imports — no `UniswapV3Pool` or `VuxPoolDeployer`
implementation artifact. **No contamination in either direction**, and `out-coverage/` is a third,
separate tree. All three are gitignored.

**Hosted evidence is stronger than my local probe and agrees with it.** No job in this workflow uses
`actions/cache`, `upload-artifact`, `download-artifact`, `needs:` or `outputs:` — every job is an
independent fresh checkout. Seven such jobs, all green. A gate cannot become green because another
job prepared the workspace, because no job can see another's workspace.

---

## 4. Coverage disposition — **accepted property preserved exactly**

Nothing was lowered, removed, skipped or weakened. Checked individually:

| Property | State |
|---|---|
| Aggregate floor | `THRESHOLD=90`, **unchanged** |
| Per-file floor | same `THRESHOLD`, applied per file **and** to the total — both retained |
| Core surface | `git ls-files 'src/*.sol'` minus `interfaces/` minus `v3core/` — **unchanged derivation**; 6 contracts, none removed |
| `--ir-minimum` | retained verbatim |
| `--no-match-coverage '(test\|script\|vendor)'` | retained verbatim |
| Instrumented-build isolation | `FOUNDRY_OUT=out-coverage` retained (now via `env`, semantically identical) |
| `=0.8.28` build | unchanged — `foundry.toml` is byte-identical |
| Measurement arithmetic | `pct10`/`tpct10` integer math untouched |
| No test skipped | the suites run in full; the v3-core readers now have their inputs instead of failing |

**The accepted measurement reproduces independently.** Hosted, under `FOUNDRY_PROFILE=ci`:
GenesisDeployer 100.0% (134/134), HardReserve 100.0% (24/24), Lens 100.0% (34/34), Rig 98.7%
(76/77), StrategicTreasury 96.9% (316/326), VUX 100.0% (14/14), **total 98.1% (598/609)**. The
arithmetic closes: 134+24+34+76+316+14 = 598; 134+24+34+77+326+14 = 609. My local run under
`FOUNDRY_PROFILE=default` produced the **identical** 598/609 — so the accepted figure is stable
across the fuzz/invariant-depth difference between the two profiles, which is worth knowing and was
not previously established. I imposed no new threshold.

**Stale artifacts cannot produce a false green.** A failing `forge coverage` calls `finish` and exits
*before* `[[ -s "$LCOV" ]]` is reached, so a stale `lcov.info` is never measured after a failure; and
a fresh CI checkout has none, since it is gitignored and uncommitted.

---

## 5. Static-analysis positive path — **established, item by item**

From the hosted log of run `32387964906`, job `96486980060`, step 6 (the new positive control),
which runs the unmodified tree:

| # | Required | Hosted evidence |
|---|---|---|
| 1 | Correct Python | `ok python 3.11.16 (/opt/hostedtoolcache/Python/3.11.16/x64/bin/python3) is inside the closure's wheel-complete range [3.10, 3.12)` |
| 2 | 49/49 closure | 49 pinned distributions; `pywin32==312 ; platform_system == "Windows"` is the **only** marker-gated entry, so 48 install on Linux — I counted both. Not drift: correct platform resolution |
| 3 | Pins exact | `ok distribution 'slither-analyzer' == 0.10.4` · `ok distribution 'crytic-compile' == 0.3.7` · `ok unrelated PyPI distribution 'slither' absent` |
| 4 | No pre-release | none in `requirements.txt`; the `eth-abi<6` constraint still holds; `Successfully installed …` lists only stable versions |
| 5 | No RPC path | `ok no RPC/provider endpoint configured — D-S2's bounded-invocation condition holds` |
| 6 | Build-info under `out-slither/` | `ok forge emitted 1 build-info artifact(s) into out-slither/ under the accepted Foundry/solc pins` |
| 7 | Report parent prepared | `mkdir -p "$(dirname "$REPORT")"`, immediately followed by the pre-existing `rm -f "$REPORT"` — so the parent exists and no stale report survives |
| 8–9 | Slither 0.10.4 executes and writes | report written; `[[ -s "$REPORT" ]]` satisfied |
| 10 | 68 findings parsed | `slither findings : 68` |
| 11 | 68 baseline entries | `baseline entries : 68` |
| 12–13 | All dispositioned, 0 high | `ok every finding carries a triaged disposition; 0 high-impact` |
| 14 | Gate green | `ok static-analysis baseline clean`; step conclusion `success` |

**I did not accept report existence as proof of analyzer semantics.** The parsed counts, the
disposition closure and the zero-high assertion all come from `compare-baseline.py`, which cannot
reach any of them without a successfully parsed report whose `success` field is truthy.

**Malformed / partial / empty behaviour, traced rather than assumed:** empty report →
`[[ -s "$REPORT" ]]` fails → `fail` + `diag`; malformed JSON → `json.load` raises → non-zero with a
visible traceback; `success: false` → `compare-baseline.py:45-47` returns 1; missing
`results.detectors` → `KeyError` → non-zero. **Every one fails closed.**

**The invocation is byte-for-byte the audited one.** The only difference from the previously audited
version is the removal of `>/dev/null 2>&1` and indentation. No flag added, none removed, no
`--config-file`, no address target, no RPC. `REPORT="out/slither-report.json"` and
`SA_OUT="out-slither"` are unchanged, so both the accepted report path and the build-info topology
are preserved.

---

## 6. Static-analysis negative control — **cannot be satisfied by analyzer failure**

This is the assertion that matters most, so I attacked it three ways.

**(a) Structural.** The assertion is two-part and always has been:

```bash
if bash tools/provenance/verify-static-analysis.sh > /tmp/out 2>&1; then … exit 1; fi
grep -q "no disposition in the baseline" /tmp/out || { cat /tmp/out; …; exit 1; }
```

The string has **exactly one** emission site in the repository — `compare-baseline.py:73` — and
reaching it requires a non-empty report, successful JSON parse, truthy `success`, an iterable
`results.detectors`, and a non-empty `new` set. Every masquerade mode the brief lists exits on a
different message: import failure → `slither not importable`; missing build-info → `no
out-slither/build-info/*.json produced`; missing parent or crash → `slither produced no report`;
malformed report → traceback; `success:false` → `slither reported an analysis error`; wrong pin →
`slither-analyzer is X, accepted pin is 0.10.4`; RPC set → `RPC/provider endpoint configured`.

**(b) Reproduced locally.** slither is absent on my host, so the gate fails for exactly the wrong
reason. Part (a) of the assertion is satisfied; **part (b) rejects it**:

```
gate FAILED (exit non-zero)              -> part (a) satisfied
grep did NOT match                       -> part (b) REJECTS
actual reason: FAIL slither-analyzer is 'not installed', accepted pin is 0.10.4
               FAIL slither not importable
```

The workflow would emit `::error::gate failed, but not for the expected reason` and exit 1.

**(c) Demonstrated in production, twice, in opposite directions.**

- In run `32342077255` (`67769a75`, before the positive control existed) the negative step failed
  with `##[error]gate failed, but not for the expected reason` — the reason-grep caught the broken
  analyzer. **No false green occurred.**
- In run `32387155823` (`f14f3c18`, positive control landed, prerequisite fix not yet) step 6
  **failed** and step 7 was **skipped**. The new control caught the real defect on its first outing
  and stopped the negative demonstration from running at all.

**Ordering is explicit and load-bearing**, and cannot be softened: the workflow contains **no**
`continue-on-error`, no `if:`, no `always()`, no `success()`/`failure()` anywhere. Every step is
sequential and a failure fails the job. All four `uses:` references are SHA-pinned with a version
comment. `permissions: contents: read`; no `secrets.` reference anywhere.

**Mutation restoration and stale-report reuse** are both handled: `cp /tmp/baseline.orig` then
`git diff --exit-code` and `git status --porcelain --untracked-files=no`; and the script's `rm -f
"$REPORT"` before each run means the second slither invocation cannot consume the first's report.
The two runs share an identical build-info by design — which is precisely what makes the pair a
controlled experiment, since the popped disposition is then the only variable.

---

## 7. Diagnostics — **fail-closed semantics preserved**

`run_logged` and `diag` are identical in both gates. Checked against every requirement:

| Requirement | Finding |
|---|---|
| Exit code preserved | `"$@" >"$DIAG_LOG" 2>&1; DIAG_STATUS=$?; return "$DIAG_STATUS"`. No `local x=$(cmd)` status-masking pattern. A redirection failure (e.g. `mktemp` failed → `DIAG_LOG="/…"`) also returns non-zero — **fail-closed** |
| Capture cannot convert failure to success | `diag` is called only in `else` branches, **after** `fail()` has incremented `FAILURES`, and `finish` then exits 1. `diag` runs only `wc`, `printf`, `tail`, `sed` — it cannot decrement anything |
| 200-line truncation cannot suppress the decision | the decision is `fail()`/`finish()`, independent of the tail; and the header prints `exit %d, last %d of %d output line(s)`, so truncation is **disclosed**, not silent |
| Successful runs stay concise | success prints one `pass` line; `diag` is unreachable on the success path |
| Killed process distinguishable | `diag` always prints the exit status, so an empty tail at exit 137 is legible as a kill rather than as a quiet success — and success never reaches `diag` at all |
| Temp logs are not trusted input | `DIAG_LOG` lives under `mktemp -d`, outside the repository, is read only by `diag`, and is removed by an EXIT trap. No later check consumes it. `$LCOV` and `$REPORT` are unchanged |
| Quoting / paths | `"$@"`, `>"$DIAG_LOG"`, `wc -l < "$DIAG_LOG"`, `tail -n "$DIAG_TAIL" "$DIAG_LOG"` all quoted |
| No new secret exposure | `diag` prints a human label, the status, line counts and captured output — **never** `"$@"` and never the environment. The workflow references no secret and holds `contents: read` |
| Trap collision | `census.sh` sets no trap; these are the only EXIT traps in either gate's execution path. `${DIAG_DIR:?}` guards the recursive delete against an empty variable |

**The diagnostics did their job in production before I audited them.** Run `32387155823` is the
proof — and it is also my independent corroboration of both root causes:

```
FAIL  forge coverage failed
      | [FAIL: vm.readFile: failed to open ".../out-v3core/VuxPoolDeployer.sol/VuxPoolDeployer.json":
      |        No such file or directory (os error 2)] setUp()

FAIL  slither produced no report at out/slither-report.json
      ---- slither: exit 1, last 200 of 201 output line(s) ----
      | . analyzed (53 contracts with 93 detectors), 68 result(s) found
      | FileNotFoundError: [Errno 2] No such file or directory: 'out/slither-report.json'
```

Both root-cause claims are **exactly** what the hosted logs say. And note the second one carries an
audit-relevant fact: slither found **68 results — the same triaged count as the passing run — in the
failing run too.** The fix changed nothing about what the analyzer found; it only let the report be
written. That is what makes this a precondition repair rather than a semantic change.

---

## 8. Authority preservation — **nothing changed**

Verified individually, not inferred: Slither version (`0.10.4`), crytic-compile (`0.3.7`), the Python
dependency closure and every hash (`requirements.txt` byte-identical), the no-RPC rule (untouched and
asserted green in the hosted log), the report path (`out/slither-report.json`), build-info topology
(`out-slither`), the detector baseline (`triage-baseline.json` byte-identical), the static-analysis
refreeze (**Group B exact**), the Foundry pin (`v1.5.0 @ 1c578544`, `foundry.toml` byte-identical),
both Solidity pins (`0.8.28 @ 7893614a`, `0.7.6 @ 7338295f` — I read them out of the built artifacts,
not just the config), and the v3-core authority (`vendor/` byte-identical). **Nothing was silently
changed. No new dependency into the protocol tree was created**: the v3core prebuild compiles the
same frozen unit `run-all.sh` already built, under the same frozen settings.

---

## 9. D-S2 — **carried, invocation not broadened**

`web3==6.20.4` is present and unpatched — confirmed directly in the hosted install line
(`… web3-6.20.4 websockets-13.1 yarl-1.24.5`). The accepted safety argument is structural
unreachability under the authorized local/no-RPC invocation, and the remediation does not touch it:
the slither command line is byte-identical apart from output capture; the nine-variable environment
check is unchanged and reported `ok` on the hosted runner; no new environment variable is exported by
the workflow beyond `PYTHON`; and capturing stdout to a temp file has no network implication. **The
invocation is neither widened nor narrowed. Residual carried. Not upgraded in this node.**

---

## 10. A-3 — unchanged, characterization not made worse

`git diff 67769a75 e9d04003 -- tools/provenance/verify-static-analysis.sh` contains **no** change to
`CONFIG="$SA_DIR/slither.config.json"` (`:38`), to the existence check (`:92`), or to the invocation
flags. `--config-file` is still passed nowhere and `slither.config.json` still does not exist at the
CWD, so it is still never loaded — exactly as the original audit found. The new comment block
concerns only the report parent and is accurate ("The report path stays exactly the one the accepted
refreeze records, and the build output stays isolated"). **A-3 remains true, remains LOW, and was
not made worse or more misleading. Not reopened as a blocker.**

---

## 11. N-1 and N-2

**N-1 — `forge lint --severity high` reports zero when Forge cannot execute. Informational,
confirmed, with a second barrier the review did not name.**

The review's dependency claim holds: `run_logged forge-build-info forge build …` is at `:188`,
`forge lint` at `:258-260`. A Forge that cannot execute fails the build-info step first, and
`FAILURES ≥ 1` makes `finish` exit 1 regardless of what the lint section reports.

But there is a **second, independent barrier** that closes the narrower case where `forge build`
works and `forge lint` specifically does not: the gate compares `lint_med` against
`triage-baseline.json`'s `forge_lint.medium_findings`, which is **4**. If `forge lint` cannot produce
parseable output, `lint_med` is `0`, `0 ≠ 4`, and the gate fails. So the medium-count *equality*
functions as a positive control for `forge lint` itself. The only residual shape is
`--severity high` breaking while `--severity med` still emits exactly four parseable findings, which
is not a realistic failure mode. **N-1 is correctly informational.**

**N-2 — `forge lint` incidentally writes `out/build-info`. Informational, confirmed, and quantified.**

I measured both trees after running the gate locally:

| tree | artifacts | size |
|---|---|---|
| `out-slither/build-info` (slither's declared input) | 1 | **4,963,733 B** |
| `out/build-info` (incidental, from `forge lint`) | 2 | 5,926 B + 3,391 B = **9,317 B** |

Three orders of magnitude apart, in different directories. The decisive evidence is hosted, though,
not local: in run `32387155823` slither analyzed **53 contracts with 93 detectors, 68 results** in a
job where **`out/` did not exist at all** — which is precisely why the report write threw
`FileNotFoundError`. Slither's input was `out-slither/build-info` with `out/` entirely absent, so
`--foundry-out-directory` is honoured and there is no fallback to `out/`. **No source/build-info
confusion and no stale-input substitution path.** I do not grade the incidental artifact.

---

## 12. Findings — all informational

**R-I1 — The negative-control step records its conclusion but not its evidence.**
`.github/workflows/provenance.yml:188-195`. The gate's output on the negative path goes to
`/tmp/out` and is `cat`-ed only on the two failure branches; on success the step prints just
`gate correctly rejected the undispositioned finding`. The hosted log for the passing run therefore
carries no record of the second slither run's `slither findings : 68 / baseline entries : 67`, nor
of the comparator's actual `FAIL … no disposition in the baseline` line — the very line the
assertion greps for. **This cannot produce a false green**: the final `echo` is unreachable unless
`grep -q` matched. It is an observability gap in exactly the dimension `f14f3c18` set out to close,
and it is why an auditor must reconstruct the negative proof structurally instead of reading it.
*Bounded remediation:* after the successful match, emit the evidence —
`grep -E "^(slither findings|baseline entries|FAIL)" /tmp/out`. One line, workflow only.

**R-I2 — The stated positive-control weakness overstates the prior risk.**
The rationale at `.github/workflows/provenance.yml:159-171` says the prior negative demonstration
"is not evidence" because *"the gate failed" is also satisfied by a gate that could not RUN at all*,
and that an uncontrolled negative test "proves nothing about the disposition machinery". That is true
of **part (a)** of the assertion in isolation, but the assertion has always had **part (b)** — the
reason-specific grep, whose string only `compare-baseline.py` emits and only after a successful
analysis. The hosted record bears this out: in run `32342077255`, before the positive control
existed, the negative step **failed** with `gate failed, but not for the expected reason`. I
reproduced the same rejection locally. So the pre-remediation control was already not falsifiable by
analyzer failure. **The positive control is still a real improvement** — it fails earlier, attributes
the failure to the right control, and turns the pair into a controlled experiment — but a later
reader taking the comment at face value would believe the tree they inherited had a false-green hole
that it did not have. *Bounded remediation:* soften the comment to what the evidence supports
(earlier and better-attributed failure; a controlled experiment), or cite run `32342077255` as the
counterexample. Comment only; no behavioural change.

**R-I3 — The coverage gate creates its v3-core precondition but does not assert the artifacts
exist.** `tools/coverage/verify-coverage.sh:117-127` trusts `forge build`'s exit status, whereas the
sibling static-analysis gate additionally asserts `bi_count > 0` on the artifacts it needs
(`verify-static-analysis.sh:190-197`). A `forge build` exiting 0 without emitting
`out-v3core/VuxPoolDeployer.sol/…` would be caught only downstream, when the suites fail in
`vm.readFile` — which is fail-closed, and is exactly how the original defect surfaced, so **there is
no false-green path**. Recorded as an asymmetry between two sibling gates, not a defect. The brief's
security property — *each gate creates or verifies every artifact prerequisite it depends on* — is
satisfied by creation.

### Carried, not reopened

| ID | Disposition |
|---|---|
| **D-S2** | Carried. `web3==6.20.4` present, unpatched, structurally unreachable; invocation not broadened |
| **A-3** | Carried, LOW, unchanged. Config still not loaded; characterization not made worse |
| **N-1** | Informational, confirmed, with a second barrier identified (§11) |
| **N-2** | Informational, confirmed and quantified (§11) |
| **A-1, A-2, A-4, A-5** | Outside this remediation. The three changed files create no dependency into their factual basis: `src/`, `test/`, `docs/authority/`, `foundry.toml`, the traceability generator and the secret sweep are all byte-identical |
| Original monetary-core, Hard/Strategic, genesis, G-1…G-4, secret-hygiene, licensing conclusions | Unchanged and not re-run. The protocol tree did not move |

---

## 13. Approval threshold

| # | Criterion | Result |
|---|---|---|
| 1 | Fresh checkout independent of hidden prior artifacts | ✅ §3 — probed from an empty workspace; no cross-job state exists |
| 2 | Coverage measures the exact accepted property | ✅ §4 — every threshold and flag preserved; 598/609 reproduced under a second profile |
| 3 | Slither actually executes under the accepted pin | ✅ §5 — 0.10.4 / 0.3.7 asserted, 68 findings parsed |
| 4 | Positive analyzer success independently established | ✅ §5 — the new step 6, green on the tip |
| 5 | Negative proof not satisfiable by analyzer failure | ✅ §6 — structural, reproduced locally, and demonstrated twice in production |
| 6 | Diagnostics preserve fail-closed behaviour | ✅ §7 |
| 7 | Workflow ordering explicit and robust | ✅ §6 — no `continue-on-error`/`if:`/`always()`; SHA-pinned actions |
| 8 | No authority/dependency/protocol semantics changed | ✅ §8 |
| 9 | Group B exact | ✅ §1 |
| 10 | No Critical/High/Medium control defect | ✅ 0 / 0 / 0 |

---

## 14. Audit-node hygiene

**Files written by this node:** exactly one —
`grimoires/loa/a2a/sprint-8/auditor-sprint-feedback-2.md` (this file).

**`grimoires/loa/a2a/sprint-8/COMPLETED` was deliberately NOT rewritten.** It records the
pre-remediation identity (Group A `407d0bab…`) and the original audit's attestation, which was true
when written. Overwriting it under cover of a fingerprint update is the exact hazard the subject
manifest warns about, and renewing acceptance is not this node's call. **Flagged for the operator:
the marker's Group-A value is now historical, and re-acceptance should record `dfeb8f58…`.** The
prior `auditor-sprint-feedback.md` (`c609c492…`), `engineer-feedback.md` (`6630a959…`),
`engineer-feedback-2.md` and `engineer-feedback-3.md` (`96e9209e…`) are all unmodified.

**Temporary probes, all restored.** No file was mutated: the probes removed and rebuilt only
gitignored build artifacts (`out/`, `out-v3core/`, `out-coverage/`, `out-slither/`, `cache/`,
`cache-v3core/`, `lcov.info`). The three remediation files report `UNCHANGED` under `git diff`, and
both group fingerprints re-derive to their entry values after every probe:

```
Group A (16)  dfeb8f58e175e62a39c4b8f50ddf6dc477d6b3ba27d38620ecb65302cef07038
Group B ( 2)  1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437
```

`git status --porcelain --untracked-files=no` shows only the two Loa hook trajectory logs, which are
appended on every tool call.

**Git state unchanged.** HEAD `e9d04003…`; **`master` and `origin/master` both at `6395cabb…`,
untouched**; one registered worktree. Nothing was committed, pushed, tagged, merged, landed, or
deployed. No operator acceptance was renewed. No retrospective was run.

---

## 15. Recommendation

**`SPRINT_8_CI_REMEDIATION_AUDIT_APPROVED`.**

Nine functional lines, no deletions, both hosted defects closed, and every accepted property intact.
The remediation is the right size and the right shape: it fixed the *precondition* rather than the
requirement, and the evidence that it works is a hosted run on the exact tip with all seven jobs
green — corroborated here by a fresh-workspace reproduction that returns the same 598/609 under a
different profile.

The three informational notes cost a line each and none of them blocks anything. R-I1 is the one I
would fold in first: the negative demonstration is now a genuinely good control, and the only reason
I had to reconstruct its proof structurally is that it does not print what it proved.

**Recommended next lifecycle node:** operator re-acceptance against the tree identified in §1,
recording the new Group-A value, then resume landing. Not automatic — neither re-acceptance nor
landing is this node's to give.

---

*Focused security audit by the Loa `/audit-sprint sprint-8` node, 2026-08-20. Identity derived from*
*git before any remediation artifact was read and re-derived at exit. Every claim was established on*
*this tree or from the hosted record: both group fingerprints, thirteen per-file digests, the*
*three-file delta and its commit split, two fresh-workspace probes, one local reproduction of the*
*negative-control rejection, compiler settings read out of the built artifacts, build-info sizes*
*measured, and four hosted runs inspected via the GitHub API — the passing tip run and the three*
*that preceded it. Nothing was accepted on report. No implementation, authority, evidence, review or*
*prior-audit artifact was modified. Nothing was committed, pushed, landed, or deployed, and operator*
*acceptance was not renewed.*

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":0},"sprint_id":"sprint-8","ts":"2026-08-20T00:00:00Z"} -->
