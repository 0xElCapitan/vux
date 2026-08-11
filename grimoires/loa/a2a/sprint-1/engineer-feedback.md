# Sprint 1 Review Feedback

**Reviewer:** Senior Tech Lead Reviewer Agent
**Date:** 2026-08-10
**Sprint Reference:** `grimoires/loa/sprint.md` (sha256 `5dd5b87b25ed07a6b23d950a7e15cc986f84d61715acfceda8eda1404b7c7436`, unchanged)
**Implementation Report:** `grimoires/loa/a2a/sprint-1/reviewer.md`
**Cycle:** cycle-002, local `sprint-1` = global `sprint-1` (ledger-resolved, `VALID|global_id=1`)

---

## Overall Assessment

This is high-quality provenance engineering. Almost every load-bearing claim in the
implementation report was independently reproduced by this review, including the two that
usually turn out to be restated rather than real:

- **The 63-file census is exact and byte-identical.** Verified with a reviewer-authored
  script that reads the accepted registry directly and shares no code with
  `tools/provenance/` — 28 OZ sha256 + 32 v3-core sha256 + 3 Miner blob-OID, `checked=63
  failures=0`, and a set-difference in both directions returning empty.
- **`POOL_INIT_CODE_HASH` is genuinely reproduced, not restated.** After a forced clean
  recompile, the hash was computed with a reviewer-written pure-JS Keccak-256 (self-validated
  against three published vectors) — no Foundry, no solc, no `cast`, no project test involved.
  It yields `0xe34f199b…b8b54` exactly, at 22,728 bytes with CBOR tail
  `a164736f6c6343000706000a`, from an artifact whose own metadata reports
  `0.7.6+commit.7338295f`, `optimizer{enabled:true,runs:800}`, `evmVersion:istanbul`,
  `bytecodeHash:none`.
- **The drift fence really closes.** `demo-drift-negative.sh` reproduced the report's recorded
  run byte-for-byte (same offset 17750, same mutated sha `c1a70ca7…`), failed for the correct
  reason with both identities surfaced, and restored the tree exactly.
- **Working-tree attribution is clean.** All five accepted authority hashes re-verified
  unchanged; no PRD/SDD/sprint-plan/`docs/authority/`/TPN mutation. The report's claim that
  `README.md` and `THIRD_PARTY_NOTICES.md` carry *pre-existing* dirt is confirmed by mtime
  (Aug 9 22:39 and Aug 10 11:19, both before the 20:00 sprint window). Zero `.claude/` files
  were touched. Sprint-1 checkboxes correctly remain unticked.
- **The report is honest about its weak spot.** It discloses the forge 1.5.0-stable local run
  rather than implying pinned-toolchain evidence; I confirmed 1.5.0 is what is installed here.

One finding blocks approval. AC-1 requires "zero unenumerated upstream source **anywhere**"
and AC-4 says the exclusions are "**enforced by the unauthorized-file detector**". They are
enforced *under `vendor/`* (plus targeted `src test script` scans), not repository-wide. I
demonstrated this empirically rather than theoretically: three unauthorized files planted in a
new top-level `contracts/` directory — an unenumerated OpenZeppelin file, a file literally named
`UniswapV3Factory.sol`, and a file citing Olympus / gumball6900 / give.fun — left **all seven
gates green and `run-all.sh` exit 0**. The probe was removed and the tree proven identical to
its pre-review state.

This is the exact failure class the sprint exists to prevent, it contradicts two acceptance
criteria as written, and it is cheap to close. Everything else is non-blocking.

**Verdict:** CHANGES REQUIRED

---

## Critical Issues (Must Fix Before Approval)

### 1. Provenance — the unauthorized-source detectors are directory-scoped, so unenumerated upstream source is invisible outside `vendor/`

**File:** `tools/provenance/verify-census.sh:74-83` (primary), with the same scoping at
`:89`, `:97`, `:107`, `:115-116`; `tools/provenance/verify-spdx.sh:66`;
`tools/provenance/verify-quarantine.sh:24`

**Issue:** Every source-detection check enumerates the directories it will look in:

- `verify-census.sh:76` — `present="$(find vendor -type f …)"`; the unenumerated-file set
  difference therefore only ever sees `vendor/`. Its own pass string is honest about this:
  `"zero unenumerated files under vendor/"` (`:81`).
- `verify-census.sh:89` — `find vendor src test script -name 'UniswapV3Factory.sol'`.
- `verify-census.sh:97` — `periphery_files="$(find vendor -ipath '*periphery*')"` (`vendor/` only).
- `verify-census.sh:107` — non-allowlisted Miner detection is bounded to `$MINER_DIR`.
- `verify-census.sh:115-116` — prohibited-source grep bounded to `vendor src test script`.
- `verify-spdx.sh:66` — VUX-owned SPDX policy bounded to `src test script`.

A directory outside `{vendor, src, test, script}` is therefore in **no** gate's scope.

**Reproduction (run during this review, then reverted):**

```
mkdir -p ./contracts/vendored
cp vendor/openzeppelin-contracts-v5.2.0/contracts/utils/math/Math.sol ./contracts/vendored/Math.sol
cp vendor/uniswap-v3-core-v1.0.0/contracts/UniswapV3Pool.sol         ./contracts/vendored/UniswapV3Factory.sol
printf '…Olympus / gumball6900 / give.fun…' > ./contracts/vendored/PoolAddress-periphery.sol
```

Result — every gate passed:

```
ok    63/63 vendored files byte-identical to accepted identities
ok    zero unenumerated files under vendor/
ok    no UniswapV3Factory.sol implementation
ok    no v3-periphery source, import, or remapping
ok    Miner Manifold reuse limited to the 3 allowlisted files
ok    no prohibited-source (LSG / gumball6900 / give.fun / Olympus) reference in Solidity sources
CENSUS_EXIT=0     SPDX_EXIT=0     run-all.sh → "All provenance gates and tests passed."  (exit 0)
```

**Why This Matters:** AC-1 is worded "zero unenumerated upstream source **anywhere**" and AC-4
is worded "no `UniswapV3Factory.sol` implementation, no v3-periphery file, no non-allowlisted
Miner file present … **enforced by the unauthorized-file detector**". As implemented, both are
enforced only within a directory the fence itself chooses. `lib/` is Foundry's conventional
dependency directory and `contracts/` is the Hardhat convention — neither is exotic, and Sprint
4 already plans VUX-owned derivative source living *outside* `vendor/`, so "source outside
`vendor/`" is a routine future state rather than a hypothetical. The report cites
`verify-census.sh:81` as AC-1's evidence, but that line's own message is narrower than the
criterion it is offered for; this is the one place where a report claim is not matched by tree
behavior.

**Required Fix:** Invert the scan from allow-listed directories to default-deny, matching the
posture the sprint already applies to the census itself. Concretely, in `verify-census.sh`:
enumerate every `*.sol` in the repository (excluding `.git`, build output, and the Loa
`.claude`/`grimoires` zones), and fail on any path that is neither a registry-enumerated
census row nor inside an explicitly declared VUX-owned source root (`src`, `test`, `script`).
That single check subsumes the file-name, periphery, Miner-extra, and prohibited-source
detectors, all of which then inherit repo-wide reach for free. Re-scope
`verify-spdx.sh:66` and `verify-quarantine.sh:24` to the same derived list so a new source root
cannot silently opt out of SPDX and §17 enforcement.

**Suggested negative test:** extend `demo-drift-negative.sh` (or add a sibling) to plant one
unauthorized `.sol` outside `vendor/`, assert the census gate fails, remove it, and assert the
gate is green again — the same fence-closes-and-reopens discipline already used for byte drift,
which is what makes that gate trustworthy.

**Reference:** CWE-1053 (missing/incomplete verification of provenance); refreeze §8 exclusions;
sprint.md Sprint 1 acceptance criteria 1 and 4.

---

## Non-Critical Improvements (Recommended)

### 1. CI installs the Foundry pin but never asserts it

**File:** `.github/workflows/provenance.yml:39-44`, `:55-57`; `tools/provenance/verify-pins.sh:60-63`

**Suggestion:** CI does genuinely pin — `FOUNDRY_VERSION: v1.0.0` (`:25`) is consumed by
`foundry-rs/foundry-toolchain@82dee4ba…` (itself correctly pinned to a 40-char commit). But the
running version is only *printed* (`:44` `forge --version`) and only `info`-logged by the gate;
nothing fails if the installed toolchain is not v1.0.0. Add one assertion step, e.g.
`forge --version | grep -q '1\.0\.0' || exit 1`. This is a hardening suggestion, not a
correctness defect: refreeze §6's binding rule is literally "pinned via `foundry.toml` + CI at
Sprint 1", which is what was built, and the same §6 records the toolchain as "not imported
source". My own evidence supports the design judgment — forge **1.5.0** reproduced the accepted
hash exactly, confirming the determinism is carried by the strictly-enforced solc identity
(`verify-pins.sh:53-54`) and the explicit settings, not by the Foundry version.

**Benefit:** Converts the toolchain pin from an install step plus a human log-read into a
fail-closed check, closing the one path by which the pinned-environment evidence could silently
degrade.

### 2. `verify-pins.sh` artifact selection can pick a `build-info` file and fail spuriously

**File:** `tools/provenance/verify-pins.sh:40`

**Suggestion:** `artifact="$(find $artifact_glob -name '*.json' | head -1)"` takes the first
JSON in filesystem order. `out/build-info/*.json` matches that glob and has no
`.metadata.compiler.version` (confirmed: the key is `ABSENT`; its top-level keys are `id`,
`language`, `source_id_to_path`). It happens to sort after `out/BaseTest.sol/BaseTest.json`
here, but ordering is not guaranteed across filesystems or after a partial build. Exclude it:
`find $artifact_glob -name '*.json' -not -path '*/build-info/*'`.

**Benefit:** The failure direction is safe (spurious FAIL, never a false pass), so this is
flakiness rather than risk — but a gate that can red-flag on artifact ordering erodes trust in
the suite.

### 3. Gate 6's secret-literal scan is `git ls-files`-scoped and is near-vacuous pre-commit

**File:** `tools/provenance/verify-launch-hygiene.sh:50`

**Suggestion:** `scan_files="$(git ls-files … )"` restricts the launch-secret literal patterns
to *tracked* files. At this pre-commit lifecycle point every Sprint-1 deliverable is untracked,
so the scan currently covers 22 files and **none** of the new work (verified:
`foundry.toml`, `tools/`, `test/`, `vendor/`, `.github/workflows/provenance.yml` all report
UNTRACKED). The `broadcast/`/`.env` tracked-file checks are correctly git-scoped by design.
Consider scanning tracked files *plus* untracked-but-not-ignored files so the gate is
meaningful before the first commit.

**Benefit:** The locally-reported "9 checks clean" for this gate is weaker evidence than it
appears today; it becomes fully meaningful only once the work is committed and CI runs.

### 4. §17 quarantine inherits the same directory-list scoping

**File:** `tools/provenance/verify-quarantine.sh:24`

**Suggestion:** `SCOPE` is the fixed list `src test script tools .github foundry.toml
remappings.txt`. Folding this into the derived source list from Critical Issue 1 keeps §17
enforcement automatically aligned with wherever VUX source actually lives. Lower severity than
Issue 1 because §17 leakage into an unscanned directory has no build effect. The gate's design
is otherwise good — frozen authority values (80/8/12, 30-day, 3000 s, 24 h) are excluded by
construction rather than by suppression, which is the right call.

---

## Adversarial Analysis

### Concerns Identified

1. **Directory-scoped provenance enforcement** — `tools/provenance/verify-census.sh:76`. The
   fence's reach is defined by a hardcoded `find` root rather than by the census it is
   defending. Demonstrated bypass above. (Blocking; Critical Issue 1.)
2. **Toolchain pin asserted nowhere in the fail-closed path** — `tools/provenance/verify-pins.sh:60-63`
   emits `info`, not `pass`/`fail`. Non-blocking, and faithful to refreeze §6's wording.
3. **Artifact-ordering fragility in the compiler-identity check** — `tools/provenance/verify-pins.sh:40`
   `head -1` over an unfiltered glob that includes schema-incompatible `build-info` JSON.
4. **`demo-drift-negative.sh:57` pipes the gate through `head -6`** — a SIGPIPE could set
   `PIPESTATUS[0]` to 141 rather than the gate's own 1. The demonstration still passes for the
   right reason (any non-zero counts as fail-closed, and `:74-85` independently re-verify bytes
   and greenness), so this is an observation, not a defect. Worth noting that using
   `PIPESTATUS[0]` here rather than `$?` is *correct* and easy to get wrong — `$?` would have
   captured `grep`'s status and silently voided the whole demonstration.
5. **Gate 6 coverage overstated pre-commit** — `tools/provenance/verify-launch-hygiene.sh:50`.

### Assumptions Challenged

- **Assumption:** upstream source can only ever exist under `vendor/`, so bounding the
  unenumerated-file check to that directory is equivalent to bounding it to the repository.
  This assumption is load-bearing for AC-1 and AC-4 but is itself never enforced.
- **Risk if wrong:** the entire default-deny posture becomes advisory the moment any source
  lands outside the four scanned directories — demonstrated live, with all gates green.
- **Recommendation:** make the assumption explicit *and* enforced by deriving the scan set from
  the census plus a declared list of VUX source roots, so adding a new root is a visible,
  reviewable act rather than a silent exemption.

### Alternatives Not Considered

- **Alternative:** default-deny over the repository's `.sol` set (fail on anything that is
  neither an enumerated census row nor inside a declared VUX source root) instead of
  allow-listed scan directories with per-pattern detectors.
- **Tradeoff:** requires maintaining one small exclusion list (build output, `.git`, Loa zones)
  and would have flagged nothing in today's tree; in exchange it collapses five separate
  detectors into one check that cannot be sidestepped by choosing a different directory.
- **Verdict:** should reconsider — it is strictly closer to the sprint's own stated goal
  ("no later sprint can drift from the accepted census even by one byte") and to the
  registry-derived design already used everywhere else in `census.sh`.

---

## AC Verification Review

The report's `## AC Verification` section is present, complete, and walks all eight criteria
verbatim. Independently confirmed:

- `sprint-1-scope.md` is a **byte-exact** slice of `sprint.md` — regenerated with the report's
  own `awk` command; both hash to `0133a5b8332fef702bf85919a1ab2c6f0022f75967cbae72c99abfb09d7799aa`.
  The scoping rationale is sound, and reporting both runs rather than only the convenient one is
  the right call.
- Scoped validator: **exit 0**, 8 ACs, 0 violations.
- Whole-plan validator: **exit 1**, 63 violations — and I confirmed mechanically that **none**
  of the eight Sprint-1 criteria appears in that violation list (each returned `clean`). The
  `71 − 8 = 63` arithmetic holds.

| AC | Criterion | Report | Review disposition |
|---|---|---|---|
| AC-1 | Census exactness; zero unenumerated upstream source **anywhere** | ✓ Met | **Not met as written** — 63/63 identity and vendor-scoped exactness independently confirmed, but "anywhere" is not enforced (Critical Issue 1) |
| AC-2 | Drift gate demonstrated fail-closed | ✓ Met | **Met** — reproduced live; correct failure reason, both identities surfaced, exact restore, standing CI job |
| AC-3 | `POOL_INIT_CODE_HASH` reproduced, CI fails closed | ✓ Met | **Met** — independently reproduced with a non-Foundry hasher; length + CBOR tail + all four build settings confirmed from artifact metadata |
| AC-4 | No Factory impl / no periphery / no non-allowlisted Miner, **enforced by the detector** | ✓ Met | **Partially met** — true of today's tree; detector does not enforce it repo-wide (Critical Issue 1) |
| AC-5 | §17 quarantine live and green | ✓ Met | **Met** — 10/10 pattern classes clean; frozen authority values correctly excluded by construction (scope note in Improvement 4) |
| AC-6 | Both solc pins recorded; CI fails on missing/short/mismatched | ✓ Met | **Met** — both pins present and 40-char; compiler identity strictly enforced against artifacts actually produced |
| AC-7 | `.gitignore` excludes `broadcast/**` | ✓ Met | **Met** — `.gitignore:28-29` with sdd.md:L270 rationale; no tracked broadcast artifact |
| AC-8 | Zero new dependencies | ✓ Met | **Met** — no `package.json`, `.gitmodules`, `lib/`, `node_modules/`; `forge-std` absent, appearing only in comments and beads metadata |

**6 of 8 met; AC-1 and AC-4 blocked on the single scoping defect.**

---

## Karpathy Principles Check

| Principle | Assessment |
|-----------|------------|
| Think Before Coding | **Strong.** Known Limitations names the pinned-toolchain gap as "the single most important item to inspect" — and it was the right thing to point at. Assumptions are surfaced rather than buried. |
| Simplicity First | **Strong.** Plain bash + `jq` + `sha256sum`; no framework. `census.sh` derives every fact from the accepted registry instead of restating it, and pins the four authority hashes so a mutated registry fails rather than silently redefining "authorized". Lean already. |
| Surgical Changes | **Clean.** No PRD/SDD/sprint-plan/authority edits; pre-existing dirt correctly left alone and correctly identified as pre-existing. |
| Goal-Driven | **Strong.** `Harness.t.sol` asserts the *failure* paths with exact reason strings — an assertion library that cannot fail would green every later monetary suite, and this is the right instinct. |

---

## Documentation & Subagent Reports

- No `grimoires/loa/a2a/subagent-reports/` directory exists — `/validate` was not run (optional).
  No blocking verdicts outstanding.
- No `grimoires/loa/known-failures.md` (advisory input, absent → WARN only).
- Gate documentation lives in `tools/provenance/README.md`, correctly kept out of `vendor/` so
  the unenumerated-file detector stays meaningful.
- Framework integrity: 0 files under `.claude/` modified in the sprint window. `check-loa.sh`
  reports one pre-existing error (Aleph runtime bundle outside a trusted Git inventory) that
  predates this sprint and is not Sprint-1 attributable.
- Adversarial cross-model review: `flatline_protocol.code_review` is unset in `.loa.config.yaml`,
  so Phase 2.5 did not apply.

---

## Previous Feedback Status

Not applicable — this is the first review of Sprint 1; no prior `engineer-feedback.md` existed.

---

## Incomplete Tasks

None. All 8 sprint tasks were implemented, and the 8 beads tasks under epic `vux-1ro` are closed
with reasons. The blocking issue is a defect in delivered work, not an omission.

---

## Residual Risks to Verify Before Landing

Carried explicitly rather than treated as review failures:

1. **No CI run has executed under the pinned Foundry v1.0.0 environment.** Correct for this
   pre-commit lifecycle point and honestly disclosed. The first CI execution must be green before
   landing; it is the only evidence for the pinned-toolchain claim.
2. **Gate 6's secret-literal scan is not meaningfully exercised until the work is committed**
   (Improvement 3).
3. **`[profile.default]` bytecode-affecting settings are intentionally unset**
   (`foundry.toml:28-32`). Correct call — no authority freezes them and no VUX contract exists;
   inventing values would freeze something the authority deliberately left open. Sprint 2 owns it.
4. **§17 quarantine will need tightening as contracts land** — acknowledged in the report;
   correctly not speculated on now.

---

## Next Steps

1. Address Critical Issue 1 via `/implement sprint-1` — widen provenance enforcement to
   default-deny across the repository and add the out-of-`vendor/` negative test.
2. Optionally fold in Improvements 1–4 while in that file set.
3. Re-run `/review-sprint sprint-1`.
4. Do **not** proceed to `/audit-sprint sprint-1` until this review returns `All good`.

**Scope note:** this review made no implementation, vendored-source, test, CI, PRD, SDD,
provenance-authority, or sprint-plan modification. The only tree mutations were a reverted
bypass probe and the drift demo's own self-restoring mutation; `git status --porcelain` was
captured before and after and is byte-identical (`4ceda6f5f7d88341d926aea16c0c587bb4114d69dc96736b6e9ca6130d81ff7a`),
`run-all.sh` is green, and all 63 census files re-verified `checked=63 failures=0`. Sprint-1
acceptance checkmarks in `sprint.md` were deliberately **not** ticked, per the CHANGES_REQUIRED
outcome.

<!-- LOA-VERDICT {"gate":"review","verdict":"CHANGES_REQUIRED","counts":{"critical":0,"high":1,"medium":3,"low":0},"sprint_id":"sprint-1","ts":"2026-08-10T00:00:00Z"} -->
