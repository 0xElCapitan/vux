---
name: forge-gate-build-output-isolation
description: |
  A Foundry CI gate that rebuilds the project with different compiler settings
  (--build-info, coverage instrumentation, a different --skip pattern) into the
  SHARED out/ directory corrupts the compiled artifacts other suites read, so
  unrelated tests that call vm.readFile/vm.parseJsonBytes/vm.parseJsonKeys on
  out/<Contract>.sol/<Contract>.json start failing with no connection to the
  actual product. Apply this whenever adding a new forge-based gate (static
  analysis, coverage, a custom build-info consumer) to a repo whose test suite
  reads compiled artifacts back from disk. Solution: build the gate's own copy
  into a dedicated --out directory (or FOUNDRY_OUT env var), never the default.
loa-agent: implementing-tasks
extracted-from: sprint-8 (VUX v1, Task 8.1 / Task 8.3)
extraction-date: 2026-08-19
version: 1.0.0
tags:
  - foundry
  - forge
  - ci-gates
  - test-isolation
  - solidity
  - build-artifacts
---

## Problem

Adding a second forge-based CI gate — a static-analysis step that needs
`--build-info`, or a `forge coverage` run that disables the optimizer/viaIR for
accurate source mapping — silently breaks tests that were passing before the
gate existed. The failing tests have nothing to do with the feature the gate
checks: they fail because the gate's `forge build` overwrote `out/` with a
differently configured artifact set, and those tests read `out/` directly.

## Trigger Conditions

### Symptoms

- A newly added gate/CI step causes previously green tests to fail.
- The failures are in tests that use Foundry's `vm.readFile` +
  `vm.parseJsonBytes` / `vm.parseJsonKeys` cheatcodes against compiled
  artifacts (event-schema conformance checks, ABI/selector assertions,
  init-code-hash reproduction, deployed-bytecode inspection).
- Error shapes seen: `EvmError: MemoryOOG` at unusually high gas (roughly 10x
  normal) when a test re-parses a much larger `--build-info` JSON than it
  expects; or `vm.parseJsonKeys: key ".methodIdentifiers" must return exactly
  one JSON object` when the artifact's method-identifier structure changed
  shape under a different optimizer/viaIR configuration.
- The failure is order-dependent: it may pass on a fresh checkout (before any
  gate has built `out/`) and fail only after the new gate has run first in the
  same working tree. That is the worst kind of green, because CI ordering is
  not guaranteed and a lucky first run hides the bug.

### Error Messages

```
[FAIL: EvmError: MemoryOOG] test_TreasuryEmitsEveryAcceptedStrategicRecord() (gas: 1073720760)
```

```
[FAIL: vm.parseJsonKeys: key ".methodIdentifiers" must return exactly one JSON object]
```

### Context

| Context | Value |
|---|---|
| Technology Stack | Foundry (forge), any Solidity repo |
| Environment | Any -- reproduces locally and in CI identically |
| Timing | Whenever two forge-based gates run in the same working tree without output isolation |
| Prerequisites | The repo has at least one test that reads compiled artifacts from `out/` via cheatcodes, and a second gate that rebuilds with different flags |

## Root Cause

`forge build --build-info` and `forge coverage` both produce a different
artifact set than a plain `forge build`:

- `--build-info` writes large `out/build-info/*.json` companion files and can
  change which sources get compiled together, depending on `--skip` patterns.
- `forge coverage` disables the optimizer and viaIR for accurate source
  mapping (documented Foundry behavior), which changes bytecode, metadata, and
  can reshape `.methodIdentifiers` and related JSON structure in the emitted
  artifact.

Foundry's default `out/` is a single shared directory. Any two `forge build`
invocations with different settings racing for the same `out/` mean whichever
ran last determines what every subsequent `vm.readFile` sees, including reads
performed by a completely unrelated test suite that assumed a normal build.

## Solution

### Step 1: Give the gate its own output directory

```bash
# Static-analysis / build-info gate
forge build --out out-slither --build-info --skip "test/**" --skip "script/**"

# Coverage gate (forge's own flag support varies; FOUNDRY_OUT env works everywhere)
FOUNDRY_OUT=out-coverage forge coverage --ir-minimum --report lcov \
  --no-match-coverage "(test|script|vendor)"
```

Pass the matching directory to whatever consumes it (for example, slither's
`--foundry-out-directory out-slither`).

### Step 2: Gitignore the new output directory

```gitignore
out-slither/
out-coverage/
```

### Step 3: If the gate's job depends on a normal build existing, build one first

A fresh CI checkout has no `out/` at all, a case that never surfaces locally
where `out/` from a previous run is usually still sitting there. If any test
in the suite reads `out/<Contract>.sol/<Contract>.json` unconditionally, the
gate (or the job before it) must run a plain `forge build` before the
isolated/instrumented one, or those tests fail on a missing file the very
first time the pipeline runs clean.

```bash
forge build >/dev/null 2>&1 || { echo "normal build required for artifact-reading tests"; exit 1; }
FOUNDRY_OUT=out-coverage forge coverage --ir-minimum
```

## Verification

### Command

```bash
forge build                      # normal build, populates out/
# run the new gate with its own --out or FOUNDRY_OUT
forge test                       # must be unaffected by the gate having run
```

### Expected Output

`forge test` passes at the same count with or without the new gate having run
immediately before it, in either order.

### Checklist

- [ ] The new gate never writes to the default `out/` (or `out-v3core/` or
      other named default profiles already in use).
- [ ] The new gate's output directory is gitignored.
- [ ] Running the full test suite immediately after the new gate produces the
      same pass count as running it cold.
- [ ] If any test depends on a normal `out/` build existing, the gate (or a
      preceding step) creates one explicitly rather than assuming it.

## Anti-Patterns

### Do not assume a passing first run proves the gates are independent

```bash
# BAD: this "passed" only because out/ still held a normal build from
# a prior forge test invocation earlier in the session.
forge build --out out --build-info --skip "test/**"
forge test
```

Re-run with a clean `out/` (or on a fresh checkout) before trusting it.

### Do not reach for `--skip test` when the intent is `--skip "test/**"`

`--skip` takes globs. `--skip test` matches nothing, so the exclusion silently
does not apply and files that should have been excluded get compiled. Always
quote the glob and verify with a source-count check.

## Related Memory

### NOTES.md References

- `grimoires/loa/NOTES.md` Decision Log, 2026-08-19, `[implement sprint-8, task
  8.1 post-acceptance]` -- first occurrence (static-analysis gate versus
  `EventSchemaConformance.t.sol`).
- `grimoires/loa/NOTES.md` Decision Log, 2026-08-19, `[implement sprint-8, task
  8.3]` -- second occurrence (coverage gate versus 39 artifact-reading tests),
  including the lucky-first-run false green.

### Related Skills

- `bash-gate-set-e-inheritance` -- a different way a hastily added gate can
  produce a misleading result in the same class of CI-hardening work.

## Changelog

| Version | Date | Changes |
|---|---|---|
| 1.0.0 | 2026-08-19 | Initial extraction |

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: implementing-tasks
  phase: /implement sprint-8
  session: 84ce6375-f0f4-4712-b2e9-21c25ba3ec54
```
