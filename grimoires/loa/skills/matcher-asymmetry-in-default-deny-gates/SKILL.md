---
name: matcher-asymmetry-in-default-deny-gates
description: |
  A default-deny gate is only as wide as its enumeration PREDICATE. When such a
  gate also prunes zones and covers them with a compensating "this zone is empty
  of X" assertion, compare the two predicates directly: if the exemption's
  matcher is BROADER than the primary universe's matcher, the primary universe
  has a hole the exemption does not. Seen concretely as `find -name '*.sol'`
  (case-sensitive) for the universe versus `find -iname '*.sol'` (case-
  insensitive) for the prune-zone assertion — so `Evil.SOL` is caught inside the
  pruned zone but invisible everywhere else in the repository, including the
  declared source roots. Apply when auditing any "no unauthorized X anywhere"
  gate: provenance/source boundaries, licence-header checks, secret scanning,
  dependency policy. Corollary: the gate's own negative-control test, written
  alongside it, inherits the same blind spot and cannot detect the regression.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-2 /audit-sprint (finding A-1, VUX provenance boundary)
extraction-date: 2026-08-11
version: 1.1.0
tags:
  - security-audit
  - ci-gates
  - provenance
  - supply-chain
  - default-deny
  - fail-closed
  - negative-testing
  - shell
---

## Problem

A repository enforces "zero unauthorized source anywhere" with a default-deny
boundary: enumerate the whole file universe, classify each file against an
authority (census/allowlist) plus declared owned roots, fail on anything in
neither class. Build output is pruned for walk cost; git-trackable framework
zones are pruned *and* covered by a compensating assertion that they contain no
such files, so the exemption is conditional rather than a hole.

The design is sound and the gate is green. It is nevertheless bypassable — not
through the prune list everyone audits, but through the **matcher** nobody does.
A file whose extension differs only in case is invisible to the primary
universe, passes the gate, and is fully build-reachable.

## Trigger Conditions

### Symptoms

- A gate enumerates with `find … -name`, `grep --include=`, a glob, or a regex, then classifies.
- The gate has a prune/exclusion list with a compensating "zone is clean" assertion.
- Review findings mention prune lists (the usual suspect) but never matchers.
- A negative-control script exists and is green — written by the same author, in the same sprint.

### Error Messages

None. This class is silent by construction: the gate exits 0 and reports a
plausible file count. Absence of a failure is the symptom.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Shell gates (`find`/`grep`/`awk`), CI provenance and compliance checks |
| Environment | Any; the asymmetry is in the predicate, not the platform |
| Timing | Security audit of a fail-closed gate; triage of carried-forward gate findings |
| Prerequisites | Ability to plant probe files and run the gate |

## Root Cause

Two enumerations are written at different times for different reasons:

- The **primary universe** is written first, for the common case, with the
  natural lowercase glob.
- The **prune-zone assertion** is added later, in response to an earlier finding,
  by an author who reasons "the only correct answer here is zero, so breadth is
  free" and reaches for `-iname`.

The result inverts the intended containment: the *conditional exemption* is
strictly broader than the *primary default-deny it is compensating for*. Anything
matched by the exemption's predicate but not the universe's predicate is
unclassifiable **everywhere except inside the pruned zones** — including the
declared source roots the gate most needs to police.

Downstream scans that consume the same universe (prohibited-source greps,
licence checks) inherit the hole silently, because they take the file list as an
input rather than re-enumerating.

## Solution

### Step 1: Extract every enumeration predicate in the gate

Read them side by side; do not infer them from the surrounding prose.

```bash
grep -nE "find |[-]i?name|--include|grep -r" tools/provenance/*.sh
```

```
census.sh:184   find . ( … ) -prune -o ( -type f -o -type l ) -name  '*.sol' -print   # universe
census.sh:204   find "${present[@]}"        ( -type f -o -type l ) -iname '*.sol' -print   # exemption
```

### Step 2: Diff the predicates and predict the gap

`-iname ⊃ -name`. Anything in the difference — `.SOL`, `.SoL` — is:

- **caught** inside a pruned zone (exemption is broad), and
- **missed** everywhere else (universe is narrow).

Write the prediction down before testing, so the probe result is a test rather
than a rationalisation.

### Step 3: Probe both sides of the asymmetry

The two-sided matrix is what distinguishes a matcher bug from a scope bug.

```bash
plant docs/Probe.SoL   ; run_gate   # predicted MISS  -> confirms universe hole
plant .ck/Probe.SOL    ; run_gate   # predicted CATCH -> confirms exemption breadth
plant docs/Probe.sol   ; run_gate   # predicted CATCH -> control: gate works normally
```

Observed exactly as predicted. The third probe is essential: without it a MISS
could mean the gate is broken generally rather than in the case dimension.

### Step 4: Check whether the negative control shares the blind spot

```bash
grep -n '\.sol' tools/provenance/demo-boundary-negative.sh
# contracts/impl/UniswapV3Factory.sol, contracts/research/Probe.sol, lib/forge-std/src/Test.sol
```

All lowercase. The regression test cannot fail on this class — so the gap is not
merely present, it is **unguarded against reintroduction**. Report this
separately; it is a distinct defect from the matcher itself.

### Step 5: Confirm consumer reachability before assigning severity

A matcher gap matters only if the protected consumer can reach the file. Do not
infer this from a resolver warning — see `resolver-diagnostic-is-not-reachability`.

### Step 6: Remediate by widening the universe, never by narrowing the exemption

```bash
# census.sh:184 — align the universe with the exemption's existing posture
find . \( "${prune[@]}" -false \) -prune -o \( -type f -o -type l \) -iname '*.sol' -print
```

Then add a case-variant probe to the negative control so the regression is
guarded.

## Verification

### Command

```bash
printf 'contract X{}' > docs/Probe.SoL && tools/provenance/verify-census.sh; echo "exit=$?"
rm -f docs/Probe.SoL
```

### Expected Output

Before the fix — the bug:

```
ok    zero unauthorized Solidity source anywhere in the repository
exit=0
```

After the fix:

```
FAIL  unauthorized Solidity source … : docs/Probe.SoL
exit=1
```

### Checklist

- [ ] Every enumeration predicate in the gate extracted and compared
- [ ] Predicted the gap before probing
- [ ] Probed the missed side, the caught side, and a working control
- [ ] Checked the negative control for the same blind spot
- [ ] Verified consumer reachability before assigning severity
- [ ] Confirmed probes removed and the tree restored byte-identically

## Anti-Patterns

### Don't: audit the prune list and call the exclusion surface done

```bash
# BAD - the usual review reflex, and it stops one layer too early
BUILD_ARTIFACT_PRUNE=(.git out cache)   # <- everyone checks this
find . -name '*.sol'                    # <- nobody checks this
```

The prune list is the *documented* exclusion; the matcher is the *undocumented*
one. Both are exclusions.

### Don't: assume broader-is-safer applies uniformly

`-iname` on the exemption is genuinely correct ("the only right answer is zero").
The defect is not that the exemption is broad — it is that the universe is
narrower **than its own exemption**. Compare predicates relative to each other,
not against an absolute ideal.

### Don't: let a green negative control stand in for coverage

A negative control proves the gate fails closed on the cases its author
imagined. It is evidence about the author's imagination, not about the gate.

## Related Memory

### NOTES.md References

- `## Learnings`: "[Audit technique — gate matcher asymmetry]" (added 2026-08-11).
- `## Technical Debt`: A-1 — `census.sh` universe walk is case-sensitive.

### Corollary added at re-review (v1.1.0) — when there is no sibling predicate to diff

This skill's discovery method is to compare two predicates that are supposed to
agree. It has a blind spot of its own: a predicate can be narrower than the real
semantic domain **with no sibling to compare it against**. Diffing finds nothing,
because there is nothing to diff.

The second oracle is the **consumer's acceptance domain**. Ask what the thing
downstream of the gate actually accepts, and compare the predicate to that
instead of to a peer matcher. Applied to the A-1 fix at `/review-sprint sprint-2`
re-review: with the case axis closed, the predicate is still `-iname '*.sol'`,
so the question becomes "what filenames does solc accept?" — and the answer is
any of them, because an import resolves on the import string byte-for-byte.
Verified in one probe, by the same compiler-evidence method used to retract N-2:

```
docs/ReviewerExtensionProbe.txt  (Solidity, containing prohibited-source markers)
  -> verify-census.sh PASSES — the universe does not see it
[PASS] test_X()   metadata.sources: src/ExtReach.txt
```

Same unclassifiable-yet-build-reachable shape as A-1 and as N-1, on a third
axis. Raised as **M-1 (MEDIUM)** and disclosed rather than blocked, because it
pre-dates the remediation and sits outside the bounded node's scope.

**Rule:** after closing one axis of an under-specified predicate, enumerate the
predicate's remaining axes (case, extension, symlink, encoding, path form) and
benchmark each against the consumer, not against a peer gate. A fix on one axis
is evidence the predicate is under-specified, not evidence it is now complete.

**Design escape hatch worth naming in the finding:** derive the universe — or a
cross-check on it — from the consumer's own record (solc's `metadata.sources`)
rather than from a filesystem name predicate. That closes every naming axis at
once, but only over what the build reaches, so it is a complement to the walk,
never a replacement.

### Related Skills

- `resolver-diagnostic-is-not-reachability`: required before assigning severity to a gap found this way — and it supplies the compiler-evidence method the corollary above depends on.
- `fail-closed-gate-scope-probe`: the same discipline on the **location** axis; this skill is the **naming** axis.
- `default-deny-source-boundary`: the implementation counterpart — warns the prune list creates a hole; this skill shows the matcher is a second, quieter one.
- `gate-gap-reachability-triage`: severity classification once the gap is confirmed.

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction from finding A-1 |
| 1.1.0 | 2026-08-11 | Added the no-sibling-predicate corollary: benchmark the predicate against the CONSUMER's acceptance domain. Found at `/review-sprint sprint-2` re-review (finding M-1, extension axis) |

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: auditing-security
  phase: /audit-sprint sprint-2
  session: cycle-002-sprint-2-audit
```
