All good

# Sprint 1 Review Feedback — Re-Review After Remediation

**Reviewer:** Senior Tech Lead Reviewer Agent (`/review-sprint sprint-1`, second pass)
**Date:** 2026-08-10
**Sprint Reference:** `grimoires/loa/sprint.md` — pre-approval sha256 `5dd5b87b25ed07a6b23d950a7e15cc986f84d61715acfceda8eda1404b7c7436`
**Implementation Report:** `grimoires/loa/a2a/sprint-1/reviewer.md` (remediation pass)
**Prior verdict:** CHANGES_REQUIRED — 1 high (C-1), 3 medium (I-2, I-3, I-4), 1 medium hardening (I-1)
**Cycle:** cycle-002, local `sprint-1` = global `sprint-1` (ledger-resolved, `VALID|global_id=1`)

---

## Overall Assessment

**C-1 is structurally closed, and I proved it with probes the implementation never ran.**

The remediation replaced five directory-scoped detectors with one repository-wide classification
primitive (`tools/provenance/census.sh:168-192`). Rather than re-running the implementation's own
demonstrations, I planted unauthorized Solidity in five locations chosen by this review — an
arbitrary new top-level directory, a deeply nested directory under `docs/`, a hidden top-level
directory, a lookalike dependency directory *inside* `vendor/`, and the repository root. Every one
returned `exit=1` from `verify-census.sh` and named the exact probe path in the failure. Planted
simultaneously, all three still fired — no probe masks another. A sixth probe placed an upstream
`MIT` file inside the declared root `test/`: the SPDX gate rejected it, so the `vux` class is not a
free pass either. The tree hashed identical before and after every probe.

The prior review's own bypass is dead: `contracts/` now fails. That was already reported, so I did
not stop there.

All four MEDIUM findings are genuinely closed, each verified by execution rather than by reading
the diff:

- **I-1** — I ran the CI step's exact `case` logic against the locally installed toolchain
  (`forge Version: 1.5.0-stable`): it returns **FAIL**, as it must. Under v1.0.0 the first line is
  `forge Version: 1.0.0-stable`, which matches. The assertion is real, not decorative
  (`.github/workflows/provenance.yml:46-54`).
- **I-2** — `verify-pins.sh:45-70` is deterministic and *stronger* than what I asked for: it
  excludes `build-info` by path, sorts the enumeration, and compares the **set** of distinct
  reported compiler identities across every artifact. Measured: `out/` 18 artifacts / 18 reporting
  / 1 distinct value; `out-v3core/` 32 / 32 / 1. The "all N artifacts" message is literally true.
- **I-3** — scan set is now tracked ∪ untracked-not-ignored (`verify-launch-hygiene.sh:57-58`);
  observed coverage **248** files (report says 247 — a live count that drifts with untracked
  files, not a discrepancy). Every Sprint-1 deliverable is now inside the scan universe.
- **I-4** — §17 scope derives from the same source universe (`verify-quarantine.sh:30-41`), and
  `docs/authority/**` + `grimoires/**` remain unscanned so research prose is not converted into a
  false implementation violation. 10/10 pattern classes clean.

The standing demonstration cannot lie about what it proves. I attacked it directly: with an
unrelated gate already red it **aborts** (`exit=1`, "nothing could be demonstrated") instead of
reporting success; with a real `./contracts` present it **refuses to run** (`exit=2`) and the real
file survives. `expect_fail` (`demo-boundary-negative.sh:50-64`) requires both a non-zero exit *and*
the specific boundary reason, so a probe that failed to be created, or an incidental red, is
reported as a demonstration failure. That closes every falsification path I could construct.

**Three enumeration residues remain, all recorded below as N-1…N-3.** I proved each one empirically
rather than asserting it: source in a pruned Loa zone, and source with an uppercase `.SOL`
extension, are both invisible to the universe **and compilable into a VUX artifact** via an explicit
relative import. They are non-blocking, and the reason is a matter of consistency rather than
leniency: my own required fix in the prior review specified the exclusion list as "`.git`, build
output, and the Loa `.claude`/`grimoires` zones". The implementation built exactly that. Blocking
now on an exclusion this review prescribed would be moving the goalposts. The distinguishing test I
applied to C-1 also separates these cleanly: `contracts/` and `lib/` are *routine future states*
reached by ordinary toolchain convention with no import gymnastics, and Sprint 4 already plans
source outside `vendor/`. Nothing puts Solidity in `grimoires/`, names a file `.SOL`, or symlinks a
source root — each requires a deliberate, conspicuous cross-zone import line in a reviewed `src/`
file, and the residue is **provably empty today** (0 `.sol` across `.claude`, `grimoires`, `.beads`,
`.run`, `.ck`, `cache`, `cache-v3core`).

Regressions: none. The 63-file census re-verified with a reviewer-authored script sharing no code
with `tools/provenance/` — 28 OZ + 32 v3-core sha256 + 3 Miner blob-OID, `mismatch=0 missing=0`,
set-difference empty in both directions. `POOL_INIT_CODE_HASH` reproduced. All eight accepted
authority hashes unchanged. mtimes confirm the node touched exactly the nine files its report
claims and nothing else.

**Verdict: APPROVED** — 8 of 8 acceptance criteria met.

---

## Disposition of Prior Findings

| # | Sev | Finding | Disposition | Independent evidence |
|---|---|---|---|---|
| C-1 | HIGH | Unauthorized-source detectors directory-scoped | **Closed** | 5 reviewer-chosen probe locations, all `exit=1` naming the exact path; simultaneous plant → 3/3 fire; `census.sh:176-192` |
| I-1 | MED | CI installs the Foundry pin but never asserts it | **Closed** | CI `case` logic executed against local 1.5.0 → correctly FAILS (`provenance.yml:46-54`) |
| I-2 | MED | `head -1` can select a `build-info` JSON | **Closed** | 18/18 and 32/32 artifacts, 1 distinct identity each (`verify-pins.sh:45-70`) |
| I-3 | MED | Secret scan `git ls-files`-scoped, near-vacuous | **Closed** | 248 files scanned incl. all untracked Sprint-1 work (`verify-launch-hygiene.sh:57-58`) |
| I-4 | MED | §17 quarantine inherits a fixed directory list | **Closed** | scope derived from source universe; probe 6 fires on relocation (`verify-quarantine.sh:30-41`) |

---

## Independent Default-Deny Result (reviewer-controlled probes)

Locations deliberately different from the implementation's `contracts/` + `lib/`. Donor was a real
byte-identical census row. Tree inventory `f79b4cd3…a56b74` before **and** after.

| # | probe location | gate | exit | probe path named in failure |
|---|---|---|---|---|
| A | `zzz-newroot/Math.sol` — arbitrary new top-level dir | `verify-census.sh` | **1** | yes |
| B | `docs/vendored/deep/nest/Math.sol` — nested unexpected dir | `verify-census.sh` | **1** | yes |
| C | `.hidden-probe/Math.sol` — hidden top-level dir | `verify-census.sh` | **1** | yes |
| D | `vendor/openzeppelin-contracts-v5.2.1/contracts/Math.sol` — lookalike dependency dir inside `vendor/` | `verify-census.sh` | **1** | yes |
| E | `Evil.sol` — repository root | `verify-census.sh` | **1** | yes |
| F | `test/vendored/Math.sol` — inside a **declared VUX root**, upstream `MIT` header | `verify-spdx.sh` | **1** | yes |
| — | A + C + B planted **simultaneously**, full `run-all.sh` | all gates | **1** | 3/3 named, none masked |

Probe D matters most after A–C: byte-identical accepted OpenZeppelin source, in a directory whose
name differs from the census by one patch digit, inside `vendor/` itself — caught by both the
classification and the extension-agnostic `vendor/` set difference (`verify-census.sh:108-117`).

---

## `SOURCE_UNIVERSE_PRUNE` Assessment (primary new attack surface)

Eleven entries at `census.sh:163`. Each inspected against: why excluded, can it hold `.sol`, can
unauthorized Solidity there reach the build, is exclusion necessary, does it hide a source-bearing
subtree.

| entry | why | can hold `.sol` | reachable by build | verdict |
|---|---|---|---|---|
| `.git` | object store, not a working tree | blobs only | no | **safe** |
| `out`, `out-v3core` | Foundry artifacts; layout creates *directories* named `*.sol` | yes | **no** — `git check-ignore` confirms ignored; wiped by `--force`; empty on a fresh CI checkout | **safe** |
| `cache`, `cache-v3core` | Foundry cache | yes | no — gitignored, regenerated | **safe** |
| `broadcast` | launch artifacts, AC-7 posture | yes | no — `broadcast/run-latest.json` confirmed IGNORED | **safe** |
| `.claude` | Loa System Zone | `.claude/*` ignored, but `.claude/overrides/**` is **trackable** | yes, by explicit import | **residue N-1** |
| `grimoires`, `.beads`, `.run`, `.ck` | Loa State Zones | **git-trackable** (verified) | yes, by explicit import | **residue N-1** |

**The prune list does not recreate C-1.** Seven of eleven entries cannot carry source into a clone
or into CI at all — that is a filesystem-level guarantee, not a policy one. The anti-tautology
cross-check (`verify-census.sh:99-104`) fails loudly if pruning ever hides the census, so the list
cannot silently make the boundary vacuous — I regard that as the single best design decision in this
remediation. The list is documented per-entry in `tools/provenance/README.md:55-60` with the
tautology guard called out, and `reviewer.md` Known Limitation 3 flags future additions as
provenance changes. That satisfies "mechanically conspicuous and provenance-sensitive".

The four git-trackable Loa zones are the residue, recorded as N-1.

---

## Non-Blocking Findings (hardening; do not re-open this sprint)

### N-1 — the git-trackable pruned Loa zones are build-reachable

**File:** `tools/provenance/census.sh:163`

Proven, not theorised. `src/X.sol` containing `import "../grimoires/loa/zzprobe.sol";` **produced a
compiled artifact** (`out/ZZImportsPruned.sol/ZZImportsPruned.json`) while `verify-census.sh`
returned `exit=0`. `grimoires`, `.beads`, `.run`, `.ck` and `.claude/overrides/` are all
git-trackable (verified via `git check-ignore`), so such a file would reach a clone.

Currently empty: 0 `.sol` across all of them. Not accident-shaped — no toolchain convention,
dependency manager, or planned sprint puts Solidity there, and the escape needs a conspicuous
cross-zone import line in a file that is itself in scope.

**Suggested hardening, before Sprint 2 lands the first `src/` Solidity** (which is when an import
line becomes possible at all): drop `grimoires .beads .run .ck` from `SOURCE_UNIVERSE_PRUNE`. They
hold zero `.sol` today, so the gate stays green and the change is one line. Alternatively, reject
imports whose resolved target is outside the classified universe.

### N-2 — `find -name '*.sol'` is case-sensitive

**File:** `tools/provenance/census.sh:171`

`zzz-newroot/Math.SOL` escapes the universe entirely (`exit=0`, path never named). It is **not**
auto-discovered by `forge build` (verified: no artifact), but `import "./ZZUpper.SOL";` from a
`.sol` file **does** compile into an artifact, with the census gate still green. Fix is `-iname`.
CI runs on `ubuntu-latest`, so this is case-sensitive there in the exploitable direction.

### N-3 — `find` does not descend into symlinked directories

**File:** `tools/provenance/census.sh:171`

A native symlink `./zzlink -> <dir containing Math.sol>` left `verify-census.sh` at `exit=0`.
Largely degenerate: an absolute out-of-repo target dangles on a fresh CI clone, and an in-repo
target points at files already classified. Worth knowing before any sprint introduces a symlinked
source path. The comment at `census.sh:166-167` correctly claims symlinked *files* are covered
(`-type l`); symlinked *directories* are the uncovered case.

### N-4 — the launch-secret scan excludes `grimoires/`, at zero false-positive cost

**File:** `tools/provenance/verify-launch-hygiene.sh:58`

`grimoires/` is git-tracked (32 files) and the Loa state-zone rule warns specifically that secrets
there "ship in every clone". I measured the exclusion's cost: including `grimoires/` produces **0**
pattern hits today, so it is convenience, not false-positive avoidance. The `vendor/` and
`docs/authority/` exclusions are well-founded (frozen by the drift gate and by pinned hashes
respectively); this one is not.

### N-5 — CI asserts the Foundry tag string, not the pinned commit

**File:** `.github/workflows/provenance.yml:48-54`

The assertion matches `1.0.0` in `forge --version | head -1`. Refreeze §6's own rule is that tags
are never authority — only the 40-char commit is. `forge --version` prints `Commit SHA:` on line 2
(confirmed locally), so also asserting `8692e926198056d0228c1e166b1b6c34a5bed66c` costs one line
and makes the check agree with the pin discipline the rest of the suite enforces.

---

## Adversarial Analysis

### Concerns Identified

1. **Pruned Loa zones are build-reachable** — `tools/provenance/census.sh:163`. Empirically
   compiled into an artifact with the gate green (N-1). Non-blocking; consistency with this
   review's own prior required-fix wording is the reason.
2. **Extension-case escape** — `tools/provenance/census.sh:171`. `*.sol` is case-sensitive; a
   `.SOL` file is importable and compilable while invisible (N-2).
3. **Symlinked directories are not descended** — `tools/provenance/census.sh:171` (N-3).
4. **`source_universe()` suppresses `find` stderr** — `tools/provenance/census.sh:171`
   (`2>/dev/null`), and the consuming loop uses process substitution, so a partial walk would not
   propagate a failure. The census-completeness cross-check at `verify-census.sh:99-104` is what
   makes this survivable — a truncated walk drops `n_vendored` below 63 and fails loudly. Worth
   stating that the cross-check is load-bearing, not belt-and-braces.
5. **The prohibited-source scan now reads vendored bytes too** — `verify-census.sh:157` passes
   `$all_sources` (all 68 files, vendored included). Correct today, but it means a future
   authorized upstream file that merely *mentions* one of the prohibited names would fail a gate
   about VUX-authored provenance. Watch at the next refreeze.
6. **`run-all.sh` does not invoke either negative demonstration** — `tools/provenance/run-all.sh:24-33`
   runs 7 gates + 11 tests only. Both demos are standing CI jobs
   (`provenance.yml:59-94`), so coverage is real, but the report's 9-row "Testing Summary" table
   reads as though `run-all.sh` produced all nine rows. Presentation, not substance.

### Assumptions Challenged

- **Assumption:** anything inside a Loa framework/state zone is "never compiled", so excluding those
  zones from the source universe is equivalent to excluding non-source.
- **Risk if wrong:** it is wrong as stated — I compiled a VUX artifact from `grimoires/` in this
  review. What actually holds is the weaker claim that nothing *routinely* compiles from there.
- **Recommendation:** state the assumption as "not a compile root and not import-reachable without a
  visible cross-zone import", and close the gap in Sprint 2 when `src/` first contains Solidity.

### Alternatives Not Considered

- **Alternative:** classify by *reachability* — resolve every `import` in the classified universe and
  require each target to itself be classified — instead of classifying by location alone.
- **Tradeoff:** costs an import parse (a regex over `import` lines would cover the realistic cases),
  and in exchange it closes N-1, N-2 and N-3 simultaneously, because all three are escapes of
  *enumeration* that remain visible as *edges*. Location-based classification cannot see them by
  construction.
- **Verdict:** current approach is justified for Sprint 1 — there is no VUX Solidity yet, so there
  are no imports to resolve and the check would be vacuous today. Reconsider in Sprint 2, where it
  becomes both non-vacuous and cheap.

---

## AC Verification Review

`## AC Verification` present, complete, all eight criteria quoted verbatim.
`.claude/scripts/validate-ac-verification.sh` against `sprint-1-scope.md`: **exit 0**.
`sprint-1-scope.md` re-confirmed byte-exact — regenerated slice and on-disk file both hash
`0133a5b8332fef702bf85919a1ab2c6f0022f75967cbae72c99abfb09d7799aa`.

| AC | Criterion | Prior | Now | Independent basis |
|---|---|---|---|---|
| AC-1 | Census exactness; zero unenumerated upstream source **anywhere** | NOT MET | **MET** | Reviewer script (no shared code): 28+32+3, `mismatch=0 missing=0`, set-difference empty both ways. "Anywhere" now enforced repo-wide — probes A–E all `exit=1`. Residue N-1/N-2/N-3 recorded, currently empty, evasion-shaped |
| AC-2 | Drift gate demonstrated fail-closed | MET | **MET** | Re-run live: offset 17750, mutated `c1a70ca7…`, restored `d515775b…`, gate green again, `exit=0`. File unmodified by this node (mtime 20:58) |
| AC-3 | `POOL_INIT_CODE_HASH` reproduced, CI fails closed | MET | **MET** | `ok POOL_INIT_CODE_HASH reproduced and equal to the accepted constant`; 2/2 hash tests pass; compiler identity asserted before the artifact is trusted. Vendored bytes proven unchanged, so the prior review's non-Foundry recomputation still governs |
| AC-4 | No Factory impl / no periphery / no non-allowlisted Miner, **enforced by the detector** | PARTIAL | **MET** | All four detectors run over the classified universe (`verify-census.sh:126,135-137,149,157`); relocation probes 2/3/4 fire; my probe D adds the in-`vendor/` lookalike case |
| AC-5 | §17 quarantine live and green | MET | **MET** | 10/10 clean; scope now derived (`verify-quarantine.sh:30-41`); research prose in `docs/authority/**` + `grimoires/**` correctly unscanned; probe 6 proves relocation is caught |
| AC-6 | Both solc pins; CI fails on missing/short/mismatched | MET | **MET** | 3 pins at 40 chars; 18/18 and 32/32 artifacts, one distinct identity each — measured, not read |
| AC-7 | `.gitignore` excludes `broadcast/**` | MET | **MET** | `git check-ignore broadcast/run-latest.json` → IGNORED; no tracked broadcast artifact |
| AC-8 | Zero new dependencies | MET | **MET** | No `package.json`, `.gitmodules`, `lib/`, `node_modules/`; `forge-std` only in 2 comments, no import; `lib/` probe fails closed; classification is 63 vendored + 5 vux + 0 unauthorized |

**8 of 8 met.**

---

## Regression Results

- **63-file census:** `CENSUS_EXACT_63` — reviewer-authored verifier reading the accepted registry
  directly, sharing no code with `tools/provenance/`. 28 OZ sha256 + 32 v3-core sha256 + 3 Miner
  blob-OID; `mismatch=0 missing=0`; zero files present in `vendor/` but absent from the registry.
- **`POOL_INIT_CODE_HASH`:** reproduced and equal to
  `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`; artifacts self-report
  `0.7.6+commit.7338295f`; `foundry.toml:53-56` optimizer 800 / istanbul / `bytecode_hash = "none"`
  unchanged. `foundry.toml` not touched by this node.
- **Dependencies / prohibited source / scope:** zero new dependencies; `src/` and `script/` contain
  zero Solidity; the 5 VUX-owned files are all test harness/provenance tests; no Sprint-2+ product
  contract exists anywhere; no operator-reserved decision resolved; no §17 value promoted.
- **Authority:** all eight accepted hashes re-verified unchanged, including PRD
  `4e5cacf7…`, SDD `19241ed7…`, refreeze `27aa37ec…`, registry delta `db314413…`, TPN `963e2cfb…`.
- **Attribution:** mtimes show exactly the nine files the report claims were changed (22:19–22:26)
  and confirm `run-all.sh`, `verify-init-code-hash.sh`, `verify-notices.sh`,
  `demo-drift-negative.sh`, `vendor-sync.sh`, `foundry.toml`, `remappings.txt` and all 63 vendored
  files were not.
- **Suite:** `run-all.sh` → **exit 0**, 11/11 tests. Both standing demonstrations → **exit 0**.

---

## Karpathy Principles Check

| Principle | Assessment |
|-----------|------------|
| Think Before Coding | **Strong.** Known Limitation 3 names the prune list as the boundary's one exclusion surface and invites exactly the scrutiny this review applied. The limitation section is where the real risk was, and it pointed there. |
| Simplicity First | **Strong.** C-1 closed by *inversion*, not extension — five per-detector `find` roots collapsed into one primitive that three gates consume. `verify-spdx.sh` grew 3 lines to inherit repo-wide reach. Lean already. |
| Surgical Changes | **Clean.** mtime attribution matches the claimed file set exactly; mechanisms the prior review independently reproduced were left untouched. `README.md`/`THIRD_PARTY_NOTICES.md` dirt remains correctly identified as pre-existing, and TPN still hashes to its accepted baseline. |
| Goal-Driven | **Strong.** `demo-boundary-negative.sh` asserts the failure *reason*, not just a non-zero exit, and refuses to run rather than delete real work — both verified adversarially here. |

---

## Documentation & Subagent Reports

- No `grimoires/loa/a2a/subagent-reports/` — `/validate` not run (optional); no blocking verdicts.
- No `grimoires/loa/known-failures.md` (advisory input, absent → WARN only).
- Gate documentation at `tools/provenance/README.md:31-64` documents the three classes and every
  prune entry with its reason, plus the anti-tautology cross-check.
- Adversarial cross-model review: `flatline_protocol.code_review` unset in `.loa.config.yaml`, so
  Phase 2.5 does not apply.
- Framework integrity: no `.claude/` file modified by this node.

---

## Prior Feedback Status

| Item | Status |
|---|---|
| C-1 (HIGH) — repository-wide default-deny | **Resolved** — verified by reviewer-controlled probes, not by re-running the implementation's demos |
| I-1 — assert the Foundry pin in CI | **Resolved** — assertion logic executed and shown to fail on a divergent toolchain |
| I-2 — deterministic artifact selection | **Resolved** — and strengthened from sample to full set |
| I-3 — launch-secret scan coverage | **Resolved** — 248 files incl. all untracked Sprint-1 work; residual `grimoires/` exclusion recorded as N-4 |
| I-4 — §17 derived scope | **Resolved** — probe 6 confirms relocation is caught |

Nothing from the prior review is unaddressed or partially addressed.

---

## Evidence Ceiling — Foundry v1.0.0 (stated truthfully, as required)

**No CI run under the pinned Foundry v1.0.0 has occurred.** All local verification in this review
ran under `forge 1.5.0-stable` (`Commit SHA: 1c578544…`), the operator's installed toolchain. This
is disclosed, not inferred, and no green pinned-toolchain execution is claimed or implied anywhere
in this artifact.

Approval is granted with that ceiling because the three conditions hold:

1. CI genuinely pins (`FOUNDRY_VERSION: v1.0.0` → `foundry-rs/foundry-toolchain` at a 40-char
   commit) **and now asserts** — I executed the assertion logic and confirmed it fails on a
   non-pinned toolchain.
2. Bytecode-affecting semantics are enforced independently of the Foundry version: the solc build
   identity is asserted across every artifact (`verify-pins.sh:45-70`) and every setting that moves
   the pool's creation code is explicit in `foundry.toml:53-56`.
3. The deterministic pool hash is reproduced, and reproduced it was under a *different* Foundry
   version — which is itself the evidence that determinism is carried by solc identity plus explicit
   settings, not by the Foundry release.

All three new/changed gate behaviours are compiler-independent (`find`, `git`, `jq`, `grep` only),
so the boundary work adds no toolchain risk to that first pinned run.

---

## Remaining Non-Blocking Pre-Landing Requirements

1. **The first CI run under pinned Foundry v1.0.0 must be green before landing.** Unchanged and
   still the single most important pre-landing item.
2. N-1 — drop the four git-trackable Loa zones from `SOURCE_UNIVERSE_PRUNE`, or add import-target
   classification, **before Sprint 2 lands the first `src/` Solidity**.
3. N-2 — `-iname` in `source_universe()`.
4. N-4 — include `grimoires/` in the launch-secret scan (measured: 0 false positives today).
5. N-5 — assert the 40-char Foundry commit alongside the tag string.
6. `[profile.default]` bytecode-affecting settings remain intentionally unset
   (`foundry.toml:28-32`) — correct now, owned by Sprint 2.
7. §17 quarantine will need tightening as contracts land (Sprint 4's "no stored ratio constant").

Items 2–5 are one-line changes; none blocks this sprint and none should re-open it.

---

## Review Scope Note

This review made **no** implementation, provenance-script, vendored-source, dependency, PRD, SDD,
provenance-authority, or sprint-plan-content modification. All reviewer probe scripts were written
outside the repository. Every probe was reverted and proven reverted: the working-tree inventory
hashed `f79b4cd3ddc9820bd91cb6d5585ba4ebe2fc3192681ce2ae35aedbe3e1a56b74` before and after the
probe battery, the reachability tests, and both standing demonstrations. `run-all.sh` is green and
the census re-verified `63/63` afterwards.

On approval this node ticks the Sprint-1 checkboxes in `grimoires/loa/sprint.md` per the native
review contract. That changes `sprint.md`'s hash from the pre-approval
`5dd5b87b25ed07a6b23d950a7e15cc986f84d61715acfceda8eda1404b7c7436`; the criteria text is unchanged
and `sprint-1-scope.md` (`0133a5b8…799aa`) remains the pre-approval byte-exact slice the AC
validator consumes. Verified in advance that ticking does not alter the validator's result (exit 0,
8 criteria, 0 violations against a fully ticked slice). No commit, push, tag, audit, or `COMPLETED`
marker was made.

---

## Next Steps

1. `/audit-sprint sprint-1` — recommended next node.
2. Carry N-1…N-5 and the pinned-CI requirement into the audit as disclosed context, not as
   unresolved review findings.

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":1,"low":4},"sprint_id":"sprint-1","ts":"2026-08-10T00:00:00Z"} -->
