---
name: authority-not-reachability-grades-a-caller-contract-gap
description: |
  When an implementation deliberately omits a precondition check INSIDE a gate and
  defends the omission with a call-site contract ("every caller builds/refreshes
  first"), do not accept or reject the defence on prose. Enumerate the COMPLETE
  caller set — including the ad-hoc direct invocation nobody lists — and for each
  one verify the structural facts that make the contract unbypassable, not the
  claim that it holds. Then grade the residual by AUTHORITY, not by reachability:
  a path a human can reach but that decides nothing (no merge gate, no acceptance,
  no landing) is a disclosed limitation, while the same gap on a verdict-bearing
  path is a blocker. Apply during code review or audit of build-artifact-consuming
  gates, cache-backed checks, or any "the pipeline guarantees it" argument. The
  non-obvious part: reachability alone inflates the finding, and the structural
  facts that actually secure the contract usually live outside the changed files
  (.gitignore, tracked-file state, CI profile inheritance) — one of them is
  typically a near-miss that would have broken CI silently.
loa-agent: reviewing-code
extracted-from: cycle-002 m1-l3-l4-provenance-hardening /review-sprint (freshness-control assessment, finding R-1)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - code-review
  - security-audit
  - ci-gates
  - severity-triage
  - build-artifacts
  - staleness
  - provenance
  - false-positive
  - foundry
---

## Problem

A gate starts consuming build artifacts as evidence (compiler metadata, a lock
file, a generated manifest, a cache). Artifacts can be stale, so the gate needs a
freshness guarantee. The implementation does not put one in the gate. Instead it
argues:

> The compiled half reflects the last build. Callers that must not miss a newly
> imported source build first — the orchestrator compiles both units before any
> gate, and both demonstrations compile at baseline.

This is a **caller contract**: the precondition is enforced at call sites rather
than by the callee. It is a legitimate design, and it is also exactly the shape
that hides a residual, because the caller set in the prose is the set the author
remembered.

Two review failure modes follow, and they pull in opposite directions:

- **Accept the prose.** The listed callers really do build first, the argument
  reads well, and the reviewer signs off — missing the unlisted path (a developer
  running one gate script directly) where the contract simply does not apply.
- **Reject on reachability.** The reviewer finds that unlisted path, observes a
  genuine false-green, and grades it a blocker — forcing a control the node was
  never scoped to build, on a path that gates nothing. This produces a perfection
  loop on a developer convenience.

Both are wrong, and the second is the more expensive because it looks rigorous.

## Trigger Conditions

Apply when reviewing or auditing any of these:

| Signal | Example |
|---|---|
| A gate reads generated state it does not itself generate | a check parsing `out/**/*.json`, `node_modules`, a lockfile, a coverage db |
| The implementation report has a "known limitations" entry naming staleness | "the X half is as fresh as the last build" |
| The defence is phrased as a property of callers | "run-all.sh builds first", "CI always does a clean checkout" |
| An internal check was CONSIDERED and rejected | "a finer staleness assertion was considered and rejected because …" |
| A gate newly depends on a directory produced by a build tool with profiles/targets | Foundry profiles, Gradle variants, Bazel configs, tsconfig projects |

The last row is the sharpest: a gate that reads `out/` is only correct if every
build configuration CI uses writes to `out/`.

## Root Cause

A precondition enforced by convention has no single place to inspect. The callee
is clean, so reading the callee proves nothing; the callers are scattered across
CI YAML, orchestrator scripts, and human habit. Reviewers therefore substitute
the author's list for the real caller set, because the real set requires a search
the diff does not suggest.

Compounding this: the facts that actually make the contract safe are usually
**not in the changed files**. Whether CI can inherit stale artifacts is decided by
`.gitignore` and the tracked-file state, not by the gate. Whether the gate reads
what CI writes is decided by build-profile inheritance, not by the gate. Neither
appears in the diff, so neither gets reviewed unless the reviewer goes looking.

## Solution

Three steps, in order. Do not grade before step 3.

### 1. Enumerate the complete caller set mechanically

Never from the report. Search for every invocation of the gate across CI
definitions, orchestrator scripts, docs, task runners, and git hooks — then add
the row the search cannot find:

```bash
grep -rn "verify-census\|run-all.sh" \
  --include="*.yml" --include="*.yaml" --include="*.md" \
  --include="Makefile" --include="*.toml" . | grep -v '^./grimoires/'
```

Always append **direct ad-hoc invocation** (`bash tools/<gate>.sh`) as a row. It
is never in the grep results and it is where the residual almost always lives.

### 2. Verify the structural facts, not the claim

For each caller, ask what would have to be true for the contract to hold, then
check that thing mechanically. For a build-artifact gate the two that matter:

```bash
# (a) Can CI inherit stale artifacts? Only if they are tracked.
git ls-files | grep -E '^(out|out-v3core)/'     # must be empty
grep -nE '^(out|out-v3core)/' .gitignore        # must be present

# (b) Does the gate read what CI writes? Check profile/target inheritance.
grep -nE '^\[profile|^\s*out\s*=' foundry.toml
```

Fact (a) is what makes the CI half airtight rather than merely conventional: a
fresh checkout has no artifacts at all, so an unbuilt CI job hits the gate's own
fail-closed emptiness check instead of silently reading stale state.

Fact (b) is the near-miss. If the CI build profile had declared its own output
directory, the gate would read an empty directory and fail every CI run — or
worse, read a stale one. Confirm it empirically, not from the config alone:

```bash
FOUNDRY_PROFILE=ci bash tools/provenance/run-all.sh   # observe "… in out/"
```

### 3. Grade by authority, not by reachability

Build the table and mark each path as verdict-bearing or not:

| path | builds first | false-green | authoritative |
|---|---|---|---|
| CI gate job to orchestrator | yes | no | **yes** |
| CI negative demos | yes | no | **yes** |
| local orchestrator | yes | no | no |
| direct single-gate invocation | **no** | **yes** | no |

Then apply the grading rule:

- False-green on an **authoritative** path (merge gate, acceptance evidence,
  release attestation) → **blocking**, regardless of how awkward the fix is.
- False-green only on a **non-authoritative** path → **non-blocking**, provided
  it is (i) not the documented entry point, (ii) not a regression, and (iii)
  disclosed. Record it, do not force it.

Test (ii) explicitly by asking what the same path did BEFORE the change. A
residual that is strictly narrower than the prior behaviour cannot be a reason to
reject the change that narrowed it.

### 4. Separate "this control is wrong" from "this control is not the only one"

When the implementation rejected an internal check, check whether the stated
reason covers **every** variant of that check or only the one considered. Here the
rejection was:

> a finer staleness assertion (artifacts newer than sources) was considered and
> rejected: it is tripped by any planted probe, which would fire the wrong fence
> in the demonstrations and destroy the attribution

That reasoning is valid for **mtime** freshness and does not transfer to
**content-hash** freshness: solc already records a `keccak256` per entry in
`metadata.sources`, and comparing it to the file's current bytes is not tripped by
planting an uncompiled file — only by a compiled source whose content moved, which
is exactly the stale-import case. Surface that as an alternative-not-considered,
recommend it as follow-up, and still approve. The distinction between "the
decision is wrong" and "the decision is right for a narrower reason than stated"
is the whole value of the finding.

## Verification

The review is complete when all of these hold:

- [ ] The caller table lists every invocation found by grep **plus** direct
      invocation, and each row is marked authoritative or not.
- [ ] For every authoritative row, the freshness guarantee was verified by a
      mechanical fact (untracked artifacts, `--force` build, clean checkout), not
      by reading the caller's source.
- [ ] Build-profile/target output directories were confirmed to match what the
      gate reads — empirically, under the CI profile.
- [ ] The gate's own fail-closed behaviour was exercised, not assumed:

```bash
mv out-v3core out-v3core.bak
bash tools/provenance/verify-census.sh; echo "EXIT=$?"   # expect 1 + intended message
mv out-v3core.bak out-v3core
bash tools/provenance/verify-census.sh >/dev/null; echo "EXIT=$?"  # expect 0
```

- [ ] The residual was graded against the pre-change behaviour on the same path.
- [ ] Any rejected internal control was re-examined for variants the stated
      objection does not cover.

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| Accepting "all security-relevant callers build first" as stated | "Security-relevant" is the author's classification of their own caller set; the review has to produce that classification independently |
| Grading the residual by whether a human can reach it | Every ad-hoc path is human-reachable; reachability is the precondition for a finding, authority is the severity |
| Blocking because a control is conceivable | The node was scoped by an operator acceptance; adding an unscoped control widens a deliberately bounded subject |
| Reading only the changed files | The facts securing a caller contract live in `.gitignore`, tracked-file state, and build-profile inheritance — none of which appear in the diff |
| Confirming profile output directories from config alone | Inheritance and overrides interact; run the CI profile and read the gate's own reported path |
| Treating a rejected control as settled | Check whether the objection covers all variants; "mtime is tripped by probes" says nothing about content hashes |
| Forgetting the pre-change baseline | A residual strictly narrower than the prior behaviour is progress, not a defect introduced by the change |

## Related Resources

- `grimoires/loa/skills/gate-gap-reachability-triage/SKILL.md` — the sibling
  method for a *detector blind spot*: classify by whether the protected consumer
  can reach the gap. This skill covers the different shape where the check is
  absent by design and delegated to callers.
- `grimoires/loa/skills/fail-closed-gate-scope-probe/SKILL.md` — location-axis
  probing of repository-wide gate claims.
- `grimoires/loa/skills-pending/ask-the-toolchain-not-the-filename/SKILL.md` —
  the implementation-side counterpart; this skill reviews the freshness contract
  that construction requires.
- `grimoires/loa/skills/assert-the-toolchain-that-produced-the-evidence/SKILL.md`
  — related: evidence is only evidence if the producing toolchain is asserted.

## Related Memory

- `grimoires/loa/NOTES.md` — Learnings: enforcement universe cannot be narrower
  than the toolchain (the M-1 closure this review assessed).
- `grimoires/loa/a2a/m1-l3-l4-provenance-hardening/engineer-feedback.md` §3 —
  the worked caller table and the authority-based grading of R-1.

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-08-13 | Extracted from the M-1/L-3/L-4 focused review — freshness-control assessment and R-1 grading |

## Metadata (Auto-Generated)

```yaml
applications: 1
success_rate: 1.0
last_applied: 2026-08-13
origin_node: m1-l3-l4-provenance-hardening
origin_gate: /review-sprint
```
