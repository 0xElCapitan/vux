---
name: pip-pinned-root-pre-release-leak
description: |
  Pinning a package to an exact stable version (e.g. `some-tool==1.2.3`) does
  NOT guarantee its resolved transitive closure is all-stable: if any
  dependency in the tree declares a constraint containing a pre-release
  identifier (e.g. `some-lib >=4.0.0-b.2`), pip's resolver treats pre-releases
  as admissible for THAT package across the whole resolve, and can silently
  select a beta/rc build instead of the latest stable release satisfying the
  same range. Apply this whenever hash-pinning a Python dependency closure for
  provenance/security purposes and verifying "everything resolved is a stable
  release" is a stated requirement.
loa-agent: implementing-tasks
extracted-from: sprint-8 (VUX v1, Task 8.1, D-S1 discharge)
extraction-date: 2026-08-19
version: 1.0.0
tags:
  - python
  - pip
  - dependency-resolution
  - provenance
  - supply-chain
  - pre-release
---

## Problem

A provenance/security process pins exactly two "root" packages
(`toolA==X.Y.Z`, `toolB==A.B.C`) and derives the full transitive closure with
`pip install --dry-run --report`, intending every resolved distribution to be
a stable release under the accepted "verification method: stable releases
only" policy. The resolver silently selects a pre-release version for one
transitive dependency, violating that policy without any error, warning, or
non-zero exit -- the dry-run reports success.

## Trigger Conditions

### Symptoms

- A generated dependency-closure report (e.g. from `pip install --dry-run
  --report report.json`) contains a version string with a pre-release suffix
  (`b1`, `rc1`, `a2`, `.dev0`, etc.) for a package nobody explicitly pinned to
  a pre-release.
- The pinned ROOT packages are exact stable versions; the anomaly is several
  hops down the dependency graph.
- Re-running the resolve with an explicit stable-only constraint on just that
  one package (e.g. a constraints file entry `some-lib<X.0.0`, where X is the
  next major after the last stable release) changes the resolution back to a
  stable version and the rest of the closure is unaffected.

### Error Messages

None -- this is a silent, successful resolution. The only "signal" is
inspecting the resolved version strings for pre-release markers after the
fact.

### Context

| Context | Value |
|---|---|
| Technology Stack | Python, pip (any reasonably recent version with the new resolver) |
| Environment | Any -- reproduces deterministically given the same package universe at resolve time |
| Timing | At dependency-closure derivation / lockfile generation time |
| Prerequisites | At least one transitive dependency in the graph declares a version specifier containing an explicit pre-release identifier as its lower bound |

## Root Cause

PEP 440 / pip's resolver treats a specifier as "opting in" to pre-releases for
the constrained package if ANY clause in that specifier explicitly names a
pre-release version (for example `>=4.0.0-b.2`). This is standard, documented
pip/PEP 440 behavior, not a bug -- the package author who wrote that
constraint presumably needed the beta feature. But it means the pre-release
opt-in is attached to the CONSTRAINED package (here, some transitive library),
not to the package that declared the constraint, and it is not scoped to only
the caller that needed it: the resolver admits pre-releases for that library
globally across the whole resolve, so it becomes eligible to satisfy any
other, unrelated dependency edge that also needs that library -- including
edges whose own declared range would otherwise have been satisfied by a
perfectly good stable release.

## Solution

### Step 1: Enumerate the resolved closure and scan for pre-release markers

```bash
python3 -c "
import json
report = json.load(open('report.json'))
for d in report['install']:
    v = d['metadata']['version']
    if not v.replace('.', '').isdigit():   # crude: anything non-numeric-dotted
        print(d['metadata']['name'], v)
"
```

(A stricter check parses with `packaging.version.Version(v).is_prerelease`.)

### Step 2: Trace which parent's specifier caused the pre-release admission

```bash
python3 -c "
import json
report = json.load(open('report.json'))
target = 'some-lib'
for d in report['install']:
    reqs = d['metadata'].get('requires_dist') or []
    hits = [r for r in reqs if r.lower().startswith(target)]
    if hits:
        print(d['metadata']['name'], '->', hits)
"
```

### Step 3: Constrain the offending package to stable versions explicitly

```bash
echo "some-lib<X" > stable-only.txt   # X = next major/minor after the last stable release
pip install --dry-run --quiet --report report.json -c stable-only.txt toolA==X.Y.Z toolB==A.B.C
```

Re-verify: the resolved version for that package is now the latest STABLE
release satisfying every real constraint in the graph, and every other
resolved version is unaffected (the constraint only removes pre-release
candidates, it never widens or narrows anything else).

### Step 4: Verify the substitution did not break a security-advisory floor

If the earlier pre-release version happened to be at or above a
security-advisory fix version, confirm the new stable pin is ALSO at or above
that floor -- do not swap a policy violation for a real vulnerability without
checking.

## Verification

### Command

```bash
python3 -c "
import json
report = json.load(open('report-after.json'))
bad = [d['metadata']['name']+'=='+d['metadata']['version']
       for d in report['install']
       if not d['metadata']['version'].replace('.', '').isdigit()]
print('non-stable:', bad or 'NONE')
"
```

### Expected Output

```
non-stable: NONE
```

### Checklist

- [ ] Every distribution in the final resolved closure has a purely numeric
      dotted version string (no `a`/`b`/`rc`/`.dev` suffix), unless a
      pre-release was DELIBERATELY and explicitly accepted with a documented
      reason.
- [ ] The specific transitive edge that caused the pre-release admission was
      identified and traced, not just patched blindly.
- [ ] The stable substitute still satisfies any security-advisory version
      floor that applied to the original resolved version.
- [ ] Re-running the resolve is deterministic (same inputs, same output) after
      the constraint is added.

## Anti-Patterns

### Do not assume "I only pinned stable roots" implies a stable closure

```bash
# BAD: no verification step, trusts that pinning the two roots to exact
# stable versions is sufficient for the whole tree to be stable.
pip install --require-hashes --no-deps -r requirements.txt
```

Pinning the roots controls WHICH packages enter the graph; it does not control
which VERSION of a deeper transitive dependency the resolver picks when a
sibling's specifier opens the door to pre-releases.

### Do not manually pick a version by inspection alone

Eyeballing a dependency tree for the "right" version invites transcription
errors and does not scale past a handful of packages; regenerate the report
programmatically after adding the constraint and diff the version strings.

## Related Memory

### NOTES.md References

- `grimoires/loa/NOTES.md` Decision Log, 2026-08-19, `[implement sprint-8, task
  8.1 post-acceptance]` -- the concrete instance: `eth-account`'s
  `eth-abi >=4.0.0-b.2` specifier caused an unconstrained resolve to select
  `eth-abi==6.0.0b1` instead of the latest stable `5.2.0`, inside a
  provenance-gated static-analysis dependency closure.

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
