---
name: mutation-probes-corrupt-the-baseline
description: |
  Restoring a mutated source file byte-for-byte does NOT restore the build. An
  incremental toolchain prunes artifacts for the file it recompiled, and a narrow
  re-run (`--match-path`, `-k`, `--filter`) regenerates only what that subset
  needed. Suites that read build artifacts from disk — ABI-surface enumerations,
  bytecode-census tests, codegen checks — then fail on missing-file errors that
  name the artifact, never the mutation that removed it. In an audit this is
  acute: the failures appear in suites unrelated to the probe, look exactly like
  tree defects, and arrive at the moment you are forming a verdict. The rule:
  source-hash restoration proves the SUBJECT is intact, never that the BASELINE
  is. Force a full rebuild before reading any post-probe suite result, and if a
  bad count was observed, report it and its cause rather than silently dropping
  it. Apply after any mutation/chaos probe, bisect, or stash-based experiment.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-7 /audit-sprint (adversarial mutation probes M-A/M-B)
extraction-date: 2026-08-18
version: 1.0.0
tags:
  - mutation-testing
  - foundry
  - forge
  - build-cache
  - false-positive
  - audit-evidence
  - incremental-build
  - verification
---

## Problem

An audit runs an adversarial mutation to prove a guard is load-bearing: mutate a
source file, run a targeted suite, observe the expected failure, restore the file,
verify by hash. The subject fingerprint re-derives byte-identical — the tree is
provably untouched.

The next full-suite run then reports a large block of failures:

```
Encountered 7 failing tests in test/treasury/TreasurySurface.t.sol
[FAIL: vm.readFile: failed to open file ".../out/StrategicTreasury.sol/StrategicTreasury.json":
 The system cannot find the path specified. (os error 3)]
...
Encountered a total of 37 failing tests, 407 tests succeeded
```

Nothing in that output mentions the mutation. The failures are in suites the probe never
touched, the restored file hashes correctly, and the reviewer's report claims a clean run.
The available readings — "the reviewer's baseline was wrong", "the tree is broken", "the
suite is flaky" — are all false, and each would be a serious audit finding if reported.

---

## Trigger Conditions

### Symptoms

- Test failures citing missing build artifacts (`out/**/*.json`) rather than assertion failures
- Failures concentrated in surface/ABI/bytecode-inspection suites that read artifacts from disk
- Failure count contradicts a recently reported green baseline, with no source difference
- Source files verify byte-identical by hash, yet the suite is red
- The session recently ran a mutation, bisect, stash, or checkout experiment

### Error Messages

```
vm.readFile: failed to open file ".../out/<Contract>.sol/<Contract>.json"
ENOENT: no such file or directory, open 'out/...'
```

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Foundry/forge (any incremental build: cargo, tsc, bazel, gradle) |
| Environment | Audit or review node running adversarial mutation probes |
| Timing | Immediately after a mutate → targeted-run → restore cycle |
| Prerequisites | A test suite that reads compiled artifacts from disk |

---

## Root Cause

Two mechanisms compose:

1. **Mutating a source invalidates and prunes its artifact.** The build system removes the
   stale output for the changed unit.
2. **A narrow re-run rebuilds only its own dependency closure.** `forge test --match-path
   'test/genesis/*'` compiles what those tests need. Artifacts for contracts outside that
   closure are never regenerated.

Restoring the source afterwards restores *the source*. The build system sees a file whose
content now matches an earlier state but whose artifact is gone, and no subsequent narrow
run has a reason to rebuild it.

The error surfaces only in suites that read artifacts **from disk** — ABI enumeration,
`methodIdentifiers` checks, bytecode census — because ordinary tests link against compiled
code and never notice.

**The general form:** hash-restoring the subject is not the same as restoring the
environment that produces evidence about the subject.

---

## Solution

### Step 1: Recognise the signature before diagnosing anything else

Missing-artifact errors + unrelated suites + a hash-clean subject = environment damage,
not a tree defect. Do not open an investigation into the tree.

### Step 2: Confirm which artifacts are actually gone

```bash
for n in VUX HardReserve Rig Lens StrategicTreasury; do
  [ -f "out/$n.sol/$n.json" ] && echo "ok $n" || echo "MISSING $n"
done
```

### Step 3: Force a full rebuild, then re-run

```bash
forge build --force && forge test
```

Or run the project's own aggregate gate, which usually rebuilds everything as a side
effect and re-establishes the canonical baseline in one step:

```bash
tools/provenance/run-all.sh   # → 444 passed / 0 failed / 10 skipped
```

### Step 4: Make full rebuild part of the probe, not a recovery step

```bash
cp "$SCRATCH/backup/Target.sol" src/Target.sol
sha256sum src/Target.sol            # subject restored
forge build --force                 # BASELINE restored — do not skip
forge test                          # only now is this number meaningful
```

### Step 5: Report the bad count and its cause

An intermediate red run is part of the audit's own record. Stating "37 failures appeared;
all were missing-artifact reads caused by my probe; a clean rebuild reproduced 444/0/10"
is stronger evidence of a controlled process than a report where the number never appears.
Silently discarding an inconvenient observation is the habit this rule exists to prevent.

---

## Verification

### Command

```bash
forge build --force && forge test 2>&1 | tail -3
```

### Expected Output

The pre-probe baseline, exactly.

```
Ran 37 test suites: 444 tests passed, 0 failed, 10 skipped (454 total tests)
```

### Checklist

- [ ] Subject files restored and hash-verified
- [ ] Artifact directory checked for missing entries
- [ ] Full rebuild forced before reading any suite count
- [ ] Post-restore count matches the pre-probe baseline exactly
- [ ] Any intermediate bad count reported with its cause, not dropped
- [ ] Subject fingerprint re-derived after the rebuild

---

## Anti-Patterns

### Don't: treat the post-probe count as a finding

```
// BAD — reports your own environment damage as a defect in the audited tree
"Full suite shows 37 failures; the reviewer's 444/0/10 could not be reproduced."
```

### Don't: conclude the tree is clean from the source hash alone

The hash proves the subject. It says nothing about the artifacts the evidence is read from.

### Don't: re-run only the narrow suite to "confirm" recovery

The narrow suite is precisely the closure that still builds. It will pass while the
baseline stays broken.

### Don't: `forge clean` reflexively

It also removes separately-profiled output trees (`out-v3core/`) that a narrow rebuild will
not regenerate, converting a small problem into a larger one. Prefer `--force`.

---

## Related Memory

- `grimoires/loa/skills/verify-the-mutant-not-the-verdict` — the **companion**: prove the
  mutation landed before reading the run, and restore by hash. This skill covers the step
  after that one: the restore leaves the build cache inconsistent.
- `grimoires/loa/skills-pending/mutate-the-source-for-constructor-only-guards` — why
  constructor-only guards need source mutation to test at all.
- `grimoires/loa/skills/live-evidence-survives-a-pipeline-change` — evidence must be
  re-derived after the pipeline moves.
- NOTES.md `## Learnings` — Sprint-7 audit, §2 environment note.
