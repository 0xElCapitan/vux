# Exact-Tree Security Audit — M-1 / L-3 / L-4 Provenance Hardening

**Node:** `m1-l3-l4-provenance-hardening` (cycle-002, post-Sprint-2, pre-Sprint-3)
**Gate:** `/audit-sprint` methodology (`auditing-security`), audit-only posture
**Audited:** 2026-08-13
**Beads:** `vux-21r`
**Base identity:** `HEAD == 22e5e00f42da06b7c8ec666d3690e0287eb74aed` on `master` — unchanged, nothing committed
**Review prerequisite:** `engineer-feedback.md` — `All good`, APPROVED 0C/0H/0M/4L

**Verdict: APPROVED - LET'S FUCKING GO**

**0 critical / 0 high / 0 medium / 6 low.** No blocking findings. M-1, L-3 and L-4 are
independently confirmed CLOSED under the accepted Foundry v1.5.0 toolchain, with default-deny
provenance strengthened rather than weakened.

---

## 1. Audited subject — re-derived, not accepted

Convention: `<sha256>` + two spaces + path, `LC_ALL=C` sorted by path, LF-terminated, then
SHA-256 of that manifest.

```
f75e4dbc57272551c73391ed04cbb32bf870f04fd3a714096bbffde17627fa9a
```

600 bytes, final byte `0x0a`. Matches the declared subject exactly.

```
c7033d5d1892bce0493acf8cdd46ea393c3876fc798b2e4cef517be14d4255cb  .github/workflows/provenance.yml
c94784d574eb208d993ceb43ea96750b4812e9d41d4c235ee608492f60d57ee7  tools/provenance/README.md
0763ffb219074dfb77757214e52b4467da28f5ab354a0439233c55a212ae0080  tools/provenance/census.sh
c59f9cd3e574ee8b4ca9b367cd6a49356485af92ca644ee43123f26d6fda94b8  tools/provenance/demo-boundary-negative.sh
e2542361806aaeadd001880a4e360591750252ec51219c9acc06f3433c3fb81f  tools/provenance/demo-drift-negative.sh
1b356b2357ddf114462d468074212afdc47622b7c57e786919aa3ae388a1f6a9  tools/provenance/verify-census.sh
```

Six files, no more. `git diff --stat -- src test script vendor foundry.toml` is empty.

## 2. Method

The implementation report and the review artifact were read for orientation and for the prior
findings' authoritative text; every conclusion below was then re-derived by measurement on this
tree. Where measurement disagreed with a prior characterisation, the measurement governs — see
R-3, which this audit re-characterises.

Executed independently at audit time:

| check | result |
|---|---|
| `demo-boundary-negative.sh`, full run | **exit 0** — 58 assertions ok, 0 bad, 15 negative probes, 4 compiler positive controls |
| working-tree inventory around that run | **identical** — `f27528b4…a710f5` before and after |
| subject fingerprint re-derived after the run | **identical** — `f75e4dbc…27fa9a` |
| `forge --version` | `1.5.0-v1.5.0`, commit `1c57854462289b2e71ee7654cd6666217ed86ffd` |
| census breakdown re-derived from `census.sh` | **oz=28 v3=32 miner=3 total=63** |
| vendored tree count | **63** `*.sol` under `vendor/` |
| 6 pinned authority artifacts re-hashed | all **match** their recorded SHA-256 |
| process-substitution status propagation | reproduced: assignment `rc=123`, process-substitution `rc=0` |
| `jq` batch-abort truncation | reproduced: malformed file drops every later file in the batch |

---

## 3. M-1 — extension-keyed source-universe bypass — **CLOSED**

### The effective universe is genuinely the union

`source_universe()` (`census.sh:286-288`) is `filesystem_sol_sources() ∪ compiled_sources()`,
deduplicated. Every provenance-sensitive consumer derives from it: `classify_sources()`
(`:313-329`) → default-deny in `verify-census.sh`, and `vux_owned_sources()` (`:336`) →
`verify-spdx.sh:69` and `verify-quarantine.sh:41`. There is no second, private universe.

`compiled_sources()` (`:233-241`) takes `.metadata.sources | keys[]` from every artifact
verbatim. The only filename predicate in it — `-name '*.json'` — selects *artifacts*, whose
naming is toolchain-controlled, not the *sources*, whose keys pass through unfiltered. The
normalisation that follows (`tr -d '\r'`, backslash→slash, `./` strip) is path canonicalisation,
not selection. **No extension filtering reaches the source paths.** Confirmed.

### The boundary was attacked, live, on all three named classes

Each probe asserts the compiler's own `metadata.sources` record *before* asserting the catch, so
the premise is proven rather than assumed, and each asserts the absence of the other reason so
the catch is attributed rather than inferred.

| class | probe | positive control (observed live) | caught as | isolation asserted |
|---|---|---|---|---|
| imported `.txt` Solidity | 14 | solc recorded `docs/boundary-probe-payload.txt` | `unauthorized compiler-admitted source` | `unauthorized Solidity source` **absent** |
| imported extensionless Solidity | 15 | solc recorded `docs/boundary-probe-payload-noext` | `unauthorized compiler-admitted source` | `unauthorized Solidity source` **absent** |
| prohibited content in compiler-admitted odd-name source | 16 | solc recorded `test/boundary-probe-prohibited.txt` | `prohibited-source reference` | `unauthorized compiler-admitted source` **absent** |

Probe 16 is the load-bearing one for closure completeness: the payload sits inside a declared VUX
root, so default-deny is structurally silent and the content scan is the only detector that can
fire. It reproduces the exact shape the Sprint-2 audit demonstrated at §8 — a `.txt` carrying all
three prohibited names passing every gate green — and it now fails closed. **The consumers of the
universe recovered, not merely the default-deny gate.**

### No alternate gate recreates an extension-keyed universe that permits a bypass

Two extension-keyed predicates remain in the tree, and neither reopens a real bypass:

- `filesystem_sol_sources()` (`:266-271`) is `-iname '*.sol'` **by design** — it is the
  complement half, and its blind spot is exactly what `compiled_sources()` covers. Union, not
  intersection: a file admitted by either half is classified.
- `loa_zone_solidity()` (`:304-310`) is `-iname '*.sol'` — this is R-4, disposed below.

The structural argument holds: the fix closes the whole naming axis at once by asking the
compiler what it compiled, rather than enumerating names the compiler might accept. Widening an
allowlist would only have moved the boundary to the next unenumerated name.

## 4. L-3 — unanchored negative-demo reason matching — **CLOSED**

`reason_matches()` (`demo-boundary-negative.sh:150`) is
`grep -E '^FAIL' | grep -qE "$2"` — the reason must appear **on a line that begins `FAIL`**.
Applied uniformly by `expect_fail` to all 15 probes, including the `not_reason` isolation
assertion.

Passing gate text cannot satisfy a negative expectation: a green gate emits no `^FAIL` line at
all, so the anchored matcher has nothing to match. The baseline control (`:287-302`) proves this
empirically by running all 8 matchers against the concatenated output of three **green** gates
and requiring zero hits — observed live, `ok`.

## 5. L-4 — missing isolated filename-detector probe — **CLOSED**

Probe 13 (`:534-548`) plants `test/UniswapV3Factory.SOL` — **inside a declared VUX source root**,
where default-deny cannot fire by construction, so the `UniswapV3Factory.sol implementation
present` detector is the only thing that can catch it. `expect_fail` is called with the
`not_reason` argument `unauthorized Solidity source`, so the absence of the default-deny reason is
**asserted, not assumed**. A future regression that silently drops `-iE` cannot hide behind
another gate's failure. Observed live, `ok`.

## 6. Standing probes are non-destructive and restore their subjects

Verified by measurement, not by reading the cleanup code:

- Working-tree inventory (`git status --porcelain --untracked-files=all`, sorted, hashed) was
  `f27528b43c6cb6495c9606f9baab6553578d33d81be25d4eb20e7d1d2ca710f5` **before** my run and
  **identical after**.
- Every probe root, zone probe, case probe, payload and importer explicitly asserted removed —
  observed `ok` on each.
- `out/BoundaryProbeImporter.sol` asserted removed. This is the correct and non-obvious part:
  a payload survives in the *compiled* half of the universe until its importer's artifact is
  gone, so artifact removal is restoration, not housekeeping. The demo treats it as such.
- Throwaway build project removed; all three gates green again afterwards.

---

## 7. Freshness control — the review's judgment is **CONFIRMED**

Every authoritative green path was traced to its build step:

| path | build discipline | stale-artifact false-green |
|---|---|---|
| CI `gates` job → `run-all.sh:21-22` | `forge build --force` ×2 | **no** |
| CI `drift-negative-demonstration` → `demo-drift-negative.sh:44` | builds both units | **no** |
| CI `source-boundary-negative-demonstration` → `demo-boundary-negative.sh:260-269` | builds both units at baseline, and rebuilds around every graph-changing probe (`:206`, `:502`) | **no** |
| local `run-all.sh` | `forge build --force` ×2 | **no** |
| local `demo-*.sh` | as above | **no** |

Four independent facts make this hold, each verified here rather than assumed:

1. **`--force`, not merely build-first.** `run-all.sh:21-22` forces full recompilation of both
   units before any gate. The security-relevant direction of staleness is a **narrower**
   universe — a source in the build that is missing from artifacts — and a forced full rebuild
   makes that unreachable. The opposite direction (an orphan artifact for a deleted source)
   widens the universe, which is fail-safe: it can only add a path to classify.
2. **CI cannot inherit artifacts at all.** `out/` and `out-v3core/` are gitignored
   (`.gitignore:19-20`) and carry **0 tracked files** (`git ls-files` empty for both), so a fresh
   checkout starts with no artifacts.
3. **`[profile.ci]` does not redirect the out-dir.** `foundry.toml:59-66` declares only
   `fuzz.runs`, inheriting `out = "out"` from `[profile.default]`. `BUILD_OUT_DIRS=(out
   out-v3core)` is therefore correct on the CI path as well as the local one. Had `ci` redirected
   output, the new evidence check would have failed CI outright.
4. **`run-all.sh` aggregates failures.** `verify-census.sh` runs first (`:24`), carries the
   zero-artifact evidence check, and any gate failure is collected and forced to `exit 1`
   (`:36-41`). One gate's silence cannot be rescued by another's.

**Direct single-gate invocation is confirmed NOT an authoritative acceptance path.** `README.md`
documents exactly one entry point — `tools/provenance/run-all.sh`, "exactly what
`.github/workflows/provenance.yml` runs". The per-gate table describes what each gate enforces;
it is not an instruction to invoke them individually as acceptance. The only other direct
invocations in the repository are inside the two demonstrations, both of which build first. The
review's judgment stands.

**Timestamp freshness is correctly rejected.** Asserting artifacts-newer-than-sources would fire
on every probe that plants an uncompiled file, displacing the fence under test. It is not
required, and requiring it as theoretical hardening would make the demonstrations weaker, not
stronger.

**`metadata.sources[*].keccak256` is non-blocking.** Its absence creates no reachable security
failure now: on every authoritative path the artifacts are produced by a forced rebuild moments
earlier, so content-freshness has no window in which to diverge. Recorded as future hardening,
correctly.

---

## 8. Preservation evidence

| item | expected | verified |
|---|---|---|
| subject fingerprint | `f75e4dbc…27fa9a` | ✓ re-derived before and after all work |
| six-file manifest | exactly 6 paths | ✓ byte-identical manifest, 600 bytes |
| Foundry identity | `1.5.0`, `1c57854462289b2e71ee7654cd6666217ed86ffd` | ✓ self-reported by the running binary |
| solc pins | `0.8.28` / `7893614a31fbeacd1966994e310ed4f760772658`; `0.7.6` / `7338295feebfb3f044e265d5cf05ef1841b258b1` | ✓ `census.sh:62-65`, full 40 chars |
| authorized census | 28 OZ + 32 v3 + 3 Miner = 63 | ✓ re-derived from the authority registry |
| vendored byte identity | 63/63 | ✓ `verify-census.sh` green at demo baseline and after restore; 63 files present |
| `POOL_INIT_CODE_HASH` | `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` | ✓ `census.sh:72` == `foundry.toml:81` |
| authority hashes | 4 pinned artifacts + TPN + 2 toolchain refreeze | ✓ all 6 re-hashed, all match |
| planning chain | prd `791c52f2…`, sdd `b7270458…`, sprint `6db19ad0…` | ✓ unchanged before and after |
| product source | unchanged | ✓ `git diff --stat -- src test script vendor foundry.toml` empty |
| dependencies | none added | ✓ no `.gitmodules`, no `lib/`, no `node_modules/`, no package manifest; manifest diffs empty |
| source authorization | none added | ✓ `VUX_SOURCE_ROOTS` unchanged; no new census row |
| Sprint 3 | unstarted | ✓ ledger `cycles.1.sprints.2` (`global_id 3`, `sprint-3`) = `planned` |
| default-deny | not weakened | ✓ universe strictly widened; 15/15 probes fail closed |

---

## 9. Findings — 6 LOW, none blocking

None of the six makes M-1 / L-3 / L-4 closure false. Per the operator's promotion test, all are
preserved as deferred hardening.

### Review findings, independently evaluated

| id | disposition | basis |
|---|---|---|
| **R-1** — direct single-gate stale-artifact possibility | **CONFIRMED LOW, carried** | Reachable only off the documented acceptance path. Every authoritative path force-builds; CI additionally starts artifact-free. Strictly narrower than pre-node behaviour, where even `run-all.sh` false-greened on an imported non-`.sol` source. |
| **R-2** — L-3 control does not assert its own non-vacuity | **CONFIRMED LOW, sharpened** | `unanchored_hits` (`:289`, `:301`) is computed and printed but never asserted `> 0`. It has already eroded to 1 while the code comment at `:283-286` still explains the fix in terms of a larger matcher set — the erosion is in progress, not theoretical. The **anchoring itself** is real and protects all 15 probes; only the demonstration of its necessity can decay. Not a security defect. |
| **R-3** — malformed artifact may terminate silently under `set -e` | **RE-CHARACTERISED, LOW, carried** | See below — the review's "fail-closed but opaque" is correct for `verify-census.sh` and **incorrect** for the quarantine/SPDX path. |
| **R-4** — pruned-zone dormant-file check remains extension-keyed | **CONFIRMED LOW, carried** | `loa_zone_solidity()` (`:304-310`) is `-iname '*.sol'`. A dormant, oddly-named Solidity file in a pruned zone is seen by neither half — but dormant means uncompiled, undeployed, executing nothing. The instant anything imports it, it enters `metadata.sources` and `compiled_sources()` catches it. The build-reachability fence holds. |

### R-3, re-characterised

The review recorded this as fail-closed but undiagnosable. Measurement shows the propagation is
**asymmetric**, and one side is fail-*open* in shape:

- **Assignment form** — `verify-census.sh:87` `compiled_default="$(compiled_sources out)"`.
  Status propagates; under `set -euo pipefail` the gate aborts. Fail-closed, as the review said.
- **Process-substitution form** — `classify_sources()` `done < <(source_universe)`
  (`census.sh:328`). The shell never inspects a process substitution's exit status. Reproduced
  directly: identical failing producer yields `rc=123` through assignment and `rc=0` through
  process substitution. `set -e` and `pipefail` do not help.

Consequence: `verify-spdx.sh:69` and `verify-quarantine.sh:41` consume `vux_owned_sources()` →
`classify_sources()`, so a truncated universe reaches them as **green**. The truncation mechanism
is real — `xargs -0 -r jq` batches many artifacts into one `jq`, which aborts at the first
malformed file and silently drops every later file in that batch (reproduced: `rc=5`, one of two
valid sources lost), with the error suppressed by `2>/dev/null`.

**Why it stays LOW:** on `run-all.sh` and in CI, `verify-census.sh` runs first, catches the same
condition through its assignment-form check, and `run-all.sh` forces `exit 1`. A malformed
artifact cannot produce an overall green. Reaching it at all requires either write access to
`out/` between build and gate — which presupposes code execution in CI — or a corrupt orphan
artifact surviving a forced rebuild locally, which CI's artifact-free checkout excludes.
`verify-census.sh` is fail-closed here **incidentally** (line 87 precedes line 110) rather than by
design, and that is what makes the deferred fix worth doing.

### New audit findings

| id | severity | location | finding |
|---|---|---|---|
| **A-1** | LOW | `verify-spdx.sh:69`, `verify-quarantine.sh:41` vs `verify-census.sh:87-99` | The "cannot silently degrade to empty" guarantee exists in **1 of 3** gates that consume the compiled half. `compiled_sources()` returns empty with **exit 0** when an out-dir is absent (`census.sh:237`), and neither SPDX nor quarantine carries the evidence check. Run directly on an unbuilt tree, both revert to the M-1-vulnerable filename universe and report green. `README.md:64-66` states the property under `verify-census.sh`'s name but draws a conclusion about "the extension-independent half" generally — broader than the one gate supports. Not reachable via CI or `run-all.sh` (both build first; `verify-census.sh` runs first and the runner aggregates). |
| **A-2** | LOW | `census.sh:196-199` | `BUILD_OUT_DIRS=(out out-v3core)` is hand-maintained and never asserted against `foundry.toml`'s `out` declarations (`:30`, `:75`). Correct today and confirmed correct for `[profile.ci]`. A future third compilation unit would silently fall back to the filename predicate for that unit — M-1 restored, locally, with every gate green: the evidence check iterates the same hardcoded list, so it would still pass on the two known units. Cheap fix: derive the list from `forge config`, or assert equality. |

---

## 10. Scope discipline and mutation

- **No mutation of the implementation.** Subject fingerprint `f75e4dbc…27fa9a` re-derived
  identically after every command this audit ran; the six per-file digests are byte-identical;
  the manifest files diff clean.
- **No mutation of the tree.** Working-tree inventory `f27528b4…a710f5` identical before and
  after, including across a full 15-probe demonstration that plants and removes files in
  `contracts/`, `lib/`, `docs/`, `test/`, `grimoires/` and the repository root.
- **No commit, push, tag, branch, PR, or merge.** `HEAD == 22e5e00f…` on `master`.
- **No `COMPLETED` marker**, per the focused-node convention established by
  `a2a/foundry-v1.5-refreeze/`. Sprint closure remains operator-gated.
- **Sprint 3 not started.** Ledger `sprint-3` = `planned`; no `src/` file created or modified.
- **No unrelated LOW reopened.** Sprint-2 L-1/L-2/L-5, refreeze L-1/L-2, R-2/T-5/T-6 untouched.
- **The only writes this audit performed** are this file and scratch files outside the repository.

### Operational note — not a finding

The working tree carries a separate, pre-existing uncommitted stream (adaptive-routing economic
supersession: `prd.md`, `sdd.md`, `sprint.md`, the authority supersession map, and three untracked
authority documents). It is properly disclosed at `reviewer.md:111-131`, and I verified this node
did not touch it — the six-file subject excludes all of it, and the planning-chain hashes are
unchanged. Note that the supersession map is **not** one of the six hash-pinned authority
artifacts, so the provenance gates are silent on its content by design; that is the pre-existing
authority model, not a regression from this node. **At landing, stage exactly the six subject
files rather than the working tree.**

---

## 11. Verdict

**APPROVED - LET'S FUCKING GO**

**0 critical / 0 high / 0 medium / 6 low.** No blocking findings.

Audited-tree fingerprint: `f75e4dbc57272551c73391ed04cbb32bf870f04fd3a714096bbffde17627fa9a`

This exact six-file tree securely closes M-1, L-3 and L-4 under the accepted Foundry v1.5.0
toolchain. The M-1 fix is structurally correct rather than incrementally patched: it closes the
entire naming axis by asking the compiler what it compiled instead of enumerating extensions,
keeps the filesystem walk as a genuine complement rather than a replacement, and routes both
halves through one definition that every consumer shares — so the consumers can no longer
disagree about what counts as source. Default-deny is strictly widened; no product, authority,
planning or economic state is altered; no dependency or source authorization is added; Sprint 3
remains unstarted.

The Sprint-2 binding carry-forward conditions are discharged. Sprint 3 is unblocked on this axis,
subject to operator acceptance.

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":6},"sprint_id":"m1-l3-l4-provenance-hardening","ts":"2026-08-13T00:00:00Z"} -->
