---
name: windows-python-stub-false-positive
description: |
  On Windows, `command -v python3` (and `python`) can report SUCCESS while
  pointing at the Microsoft Store App Execution Alias stub rather than a real
  interpreter -- so a shell script that trusts "the command exists" as proof of
  "a working interpreter is available" can pass its own existence check and
  then fail (or silently misbehave) the moment it actually invokes the
  interpreter. Apply this whenever writing a bash/CI script that needs to
  locate a working Python (or similar optional-runtime) interpreter on a
  machine that might be Windows, especially one that then asserts a version
  range for a dependency closure.
loa-agent: implementing-tasks
extracted-from: sprint-8 (VUX v1, Task 8.1)
extraction-date: 2026-08-19
version: 1.0.0
tags:
  - windows
  - bash
  - python
  - interpreter-detection
  - ci-gates
  - cross-platform
---

## Problem

A gate script does `command -v python3 >/dev/null 2>&1 && PY=python3` (or
similar) to find an interpreter, then proceeds to use `$PY` for real work
later in the script. On Windows, this existence check can succeed even though
`python3` is not a working interpreter at all -- it resolves to a stub binary
Windows installs by default that, when invoked, prints an install prompt and
exits nonzero instead of running any code.

## Trigger Conditions

### Symptoms

- A script's "python found" check passes, but a later step that actually runs
  `"$PY" -c "..."` fails or produces no output, with an error message about
  installing from the Microsoft Store rather than a Python traceback.
- The failure only reproduces on Windows machines/runners; the identical
  script works on Linux/macOS CI.
- `command -v python3`, `which python3`, or `type python3` all report a path
  under something like `...\WindowsApps\python3.exe`, which is the App
  Execution Alias, not a real install.

### Error Messages

```
Python was not found; run without arguments to install from the Microsoft
Store, or disable this shortcut from Settings > Apps > Advanced app settings >
App execution aliases.
```

(Exit code is nonzero, commonly reported as 49 by some shells.)

### Context

| Context | Value |
|---|---|
| Technology Stack | Bash/POSIX sh scripts run on Windows (Git Bash, WSL interop edge cases, MSYS) |
| Environment | Windows 10/11 with the default App Execution Alias for `python`/`python3` still enabled and no real Python on PATH ahead of it, or a real Python installed under a version-suffixed command (`python3.11`) that the script never tries |
| Timing | Any time the script's interpreter-detection step runs before the real Python is confirmed executable |
| Prerequisites | None -- this is a stock Windows default, not a misconfiguration |

## Root Cause

Windows ships "App Execution Alias" stub launchers for `python.exe` and
`python3.exe` under `WindowsApps` on `PATH` by default, intended to prompt an
unconfigured user to install Python from the Microsoft Store. These stubs are
real, executable files that a `PATH` lookup finds successfully -- so
`command -v` and equivalents report success, because their job is only to
check "does something executable exist at this name", not "does invoking it
actually run Python code". The stub only reveals itself as non-functional the
moment something tries to execute it for real.

## Solution

### Step 1: Never trust existence alone -- confirm by executing a real check

```bash
py_ok=""
for cand in python3.11 python3.10 python3 python; do
  command -v "$cand" >/dev/null 2>&1 || continue
  # The check that matters: does it actually run and report a usable version?
  if "$cand" -c "import sys; sys.exit(0 if (3,10) <= sys.version_info[:2] < (3,12) else 1)" >/dev/null 2>&1; then
    py_ok="$cand"
    break
  fi
done
if [[ -z "$py_ok" ]]; then
  echo "no working interpreter in range found" >&2
  exit 1
fi
PY="$py_ok"
```

The stub fails this check (nonzero exit, no valid `sys.version_info`), so the
loop correctly skips past it to the next candidate, or reports failure
cleanly if nothing real is on PATH.

### Step 2: Prefer version-suffixed names over the bare command when practical

`python3.11`, `python3.10`, etc. are far less likely to collide with the stub,
since the stub is specifically registered under the bare `python`/`python3`
names. Trying suffixed names first (falling back to the bare names) reduces
how often the loop even has to skip the stub.

### Step 3: Allow an explicit override for environments where detection is wrong

```bash
PY="${PYTHON:-}"
if [[ -z "$PY" ]]; then
  # ... run the detection loop from Step 1 ...
fi
```

Lets a user or CI job pin an exact interpreter path without fighting the
auto-detection.

## Verification

### Command

```bash
# On a machine where the stub is present and no real python3/python is
# installed under those bare names:
bash -c 'command -v python3 && python3 --version'
```

### Expected Output

`command -v python3` prints a path (proving the naive check would have
"succeeded"), while `python3 --version` fails with the Microsoft Store install
message -- demonstrating the gap this skill closes.

### Checklist

- [ ] Interpreter detection executes a real command against each candidate
      (not just `command -v`) before accepting it.
- [ ] The script tries version-suffixed names before bare `python3`/`python`.
- [ ] An explicit `PYTHON=` (or equivalent) override is honored ahead of
      auto-detection.
- [ ] The failure path (`no working interpreter found`) is a clear, actionable
      message rather than a downstream cryptic error from the stub.

## Anti-Patterns

### Do not gate on `command -v` alone when the result feeds real execution

```bash
# BAD: passes on Windows even when python3 is the non-functional stub.
if command -v python3 >/dev/null 2>&1; then
  PY=python3
fi
```

### Do not assume a Linux/macOS-tested script needs no Windows-specific check

The stub is a Windows-only default, so this exact failure mode is invisible
in CI running on Linux runners and only appears for contributors or
self-hosted runners on Windows -- worth testing explicitly rather than
inferring from other platforms passing.

## Related Memory

### NOTES.md References

- `grimoires/loa/NOTES.md` Decision Log, 2026-08-19, `[implement sprint-8, task
  8.1 post-acceptance]` -- the concrete instance inside a static-analysis
  gate's interpreter-selection step.

### Related Skills

- `bash-gate-set-e-inheritance` -- another discovery from the same
  gate-authoring session.

### Related project memory (this repository, not portable)

- `python-absent-use-node.md` -- a related but distinct fact: from this
  agent's own Bash tool in this environment, `python3`/`python` fail outright
  (exit 49) rather than appearing to succeed. That memory is about the
  agent's own tool invocations; this skill is about writing ROBUST detection
  logic inside a shell script that might run on someone else's Windows
  machine, where the stub can look like success rather than an outright
  failure.

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
