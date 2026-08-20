---
name: bash-gate-set-e-inheritance
description: |
  A bash CI-gate script that sources a shared library declaring `set -e`
  inherits abort-on-first-nonzero, which silently defeats a fail()/finish()
  style gate whose whole design is to run every check and report all failures
  at once. The gate dies mid-run on the first probe that returns nonzero (a
  `pip show` on an absent package, a grep with no match, etc.) with no
  diagnostic at all -- the worst possible behavior for something meant to be a
  fence. Apply this whenever writing or debugging a shell-based CI gate that
  sources another script and uses accumulate-then-report error handling.
loa-agent: implementing-tasks
extracted-from: sprint-8 (VUX v1, Task 8.1)
extraction-date: 2026-08-19
version: 1.0.0
tags:
  - bash
  - shell
  - ci-gates
  - error-handling
  - set-e
  - fail-closed
---

## Problem

A new gate script sources a shared library (for example, one providing
`pass()`/`fail()`/`finish()` helpers and some common variables) and then runs a
series of independent checks, expecting each check's failure to be recorded
and reported together at the end. Instead, the script exits abruptly partway
through with almost no output and no indication of which check failed or why.

## Trigger Conditions

### Symptoms

- A gate script that clearly has multiple `echo`/`pass`/`fail` sections
  produces only the first one or two lines of output, then stops.
- The script's exit code is nonzero, but no `FAIL` line was ever printed --
  the accumulate-and-report machinery never got a chance to run.
- The behavior only appears for CERTAIN inputs: a probe command that is
  expected to sometimes fail (checking whether a package is installed,
  greping for a pattern that may be absent, testing a precondition) is exactly
  the kind of command that triggers it.
- Removing the `source` of the shared library "fixes" it, which is the
  giveaway that the library's own shell options are the cause, not the probe
  itself.

### Error Messages

No specific error text -- the symptom IS the absence of expected output. If
run with `bash -x`, the trace simply stops after the offending command with no
further lines executed.

### Context

| Context | Value |
|---|---|
| Technology Stack | Bash / POSIX sh, any CI gate or lint script |
| Environment | Any |
| Timing | Immediately on first invocation with an input that makes one probe return nonzero |
| Prerequisites | The gate script sources a library that sets `set -e` (directly or via `set -euo pipefail`) and the gate's own logic is not written to tolerate that |

## Root Cause

`source lib.sh` runs the library's contents in the CURRENT shell, including
any `set -e` (or `set -euo pipefail`) directive at its top. Bash's `-e` option
persists in the sourcing script's shell for the remainder of execution unless
explicitly reset. A gate written around "run every check, accumulate
pass/fail, report all of them" assumes non-fatal command failures; `set -e`
converts the very first nonzero-returning command anywhere in the script
(including inside `$(...)`  command substitutions in some bash versions) into
an immediate script exit, before the gate's own `fail()` function is ever
reached for that check, and before any of the checks after it run at all.

## Solution

### Step 1: Reset shell options immediately after sourcing

```bash
source "$(dirname "${BASH_SOURCE[0]}")/shared-lib.sh"
# shared-lib.sh sets -e for ITS OWN internal safety; this gate needs to keep
# running after any individual probe fails, so opt back out here.
set +e
```

### Step 2: Keep the accumulate/report pattern doing the actual gating

```bash
FAILURES=0
fail() { printf "FAIL  %s\n" "$*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { printf "ok    %s\n" "$*"; }

pip show some-package >/dev/null 2>&1 && pass "some-package present" || fail "some-package missing"
grep -q "expected-pattern" some-file.txt && pass "pattern found" || fail "pattern missing"

(( FAILURES > 0 )) && exit 1
```

`set +e` is safe here specifically BECAUSE the gate's own error handling
(`fail()`/`FAILURES` counter/final `exit 1`) is what actually enforces
fail-closed behavior -- the script does not need bash's `-e` to be correct, it
needs every check to run and the aggregate result to be checked at the end.

### Step 3: Document why, so a later reader does not "fix" it back

Leave a one-line comment at the `set +e` explaining that the sourced library
sets `-e` for itself and this script's checks are deliberately non-fatal
probes.

## Verification

### Command

```bash
# Force one probe to fail and confirm the script still runs every remaining check.
bash gate-script.sh
```

### Expected Output

Every `pass`/`fail` line for every check appears, even when an earlier check
failed, followed by a summary and a nonzero exit only if at least one check
failed.

### Checklist

- [ ] `set +e` (or equivalent) appears immediately after any `source` of a
      library that sets `-e`, if the script's own checks are meant to be
      non-fatal probes.
- [ ] A deliberately-failing probe still allows every later check to run and
      be reported.
- [ ] The script's own accumulate/report logic (not bash's `-e`) is what
      determines the final exit code.

## Anti-Patterns

### Do not assume `source`d files are side-effect-free with respect to shell options

```bash
# BAD: silently inherits -e from lib.sh with no comment explaining why the
# very first probe that can legitimately fail kills the whole script.
source ./lib.sh
some_probe_that_can_fail
echo "this line may never run"
```

### Do not "fix" a silently-dying gate by wrapping every command in `|| true`

That suppresses the failure signal entirely rather than restoring the
intended accumulate-and-report behavior. Reset `-e` once at the top instead,
and let the gate's own `fail()`/counter logic do the actual gating.

## Related Memory

### NOTES.md References

- `grimoires/loa/NOTES.md` Decision Log, 2026-08-19, `[implement sprint-8, task
  8.1 post-acceptance]` -- the concrete instance: `census.sh` sets `-e`, a
  static-analysis gate sourcing it died on the first `pip show` of a missing
  package, with 250 bytes of output and no diagnostic.

### Related Skills

- `forge-gate-build-output-isolation` -- a different way a hastily added CI
  gate misbehaves in the same class of hardening work.
- `windows-python-stub-false-positive` -- another discovery from the same
  gate-authoring session, about trusting `command -v` too readily.

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
