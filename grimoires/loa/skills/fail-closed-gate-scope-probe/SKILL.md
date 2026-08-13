---
name: fail-closed-gate-scope-probe
description: |
  When reviewing a fail-closed CI gate that enforces a repository-wide claim
  ("no unauthorized source anywhere", "no secrets anywhere", "every file has a
  licence header"), test it on the LOCATION axis, not only the CONTENT axis.
  Gates built from `find <fixed-dir>` or `grep -r <fixed-dirs>` enforce their
  claim only where they happen to look, so a violating file placed in an
  unlisted directory passes every check. Apply during code review, security
  audit, or any provenance/compliance gate assessment. The probe is: plant a
  violating artifact outside the gate's scan roots, run the suite, observe
  green, then revert and prove the tree is byte-identical.
loa-agent: reviewing-code
extracted-from: cycle-002 sprint-1 /review-sprint (VUX provenance foundation)
extraction-date: 2026-08-11
version: 1.1.0
tags:
  - code-review
  - ci-gates
  - provenance
  - supply-chain
  - fail-closed
  - negative-testing
  - shell
---

## Problem

A gate suite reports all-green and its acceptance criterion is marked met, but
the criterion says "anywhere in the repository" while the gate only inspects a
fixed set of directories. The gate is not wrong about what it checks — it is
silently narrower than the claim it is offered as evidence for.

The failure is invisible to every normal signal: the suite passes, the report
cites a real passing line, and a well-built content-mutation negative test
(flip a byte, watch the gate fail) also passes. None of those exercise the
location axis.

Observed symptom in the originating session: an acceptance criterion reading
"zero unenumerated upstream source **anywhere**" was satisfied by a check whose
own success message read `zero unenumerated files under vendor/`.

---

## Trigger Conditions

### Symptoms

- An acceptance criterion or policy says "anywhere", "any file", "the whole
  repository", or "no X exists" — but the implementing check names directories.
- A gate's pass message is narrower than the requirement it is cited for.
- Several sibling detectors each repeat their own directory list.
- A negative test exists, but it only mutates the *content* of an already-known
  file (byte flip, corrupted hash, bad signature).
- New source roots are expected to appear in later work (a planned directory
  that does not exist yet).

### Code shapes that trigger this

```bash
find vendor -type f                                   # scan root hardcoded
find vendor src test script -name 'Forbidden.sol'     # enumerated list
grep -rniE 'badpattern' --include='*.sol' vendor src  # enumerated list
SCOPE=(src test script tools .github)                 # array of roots
vux_sol="$(find src test script -name '*.sol')"       # policy check, fixed roots
```

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Any: shell/CI gates, licence scanners, SPDX linters, secret scanners, dependency allowlists, provenance/census checks |
| Environment | Code review, security audit, supply-chain assessment |
| Timing | Reviewing a gate whose claim is repo-wide; before approving an AC that says "anywhere" |
| Prerequisites | Ability to run the gate suite locally and revert the working tree |

---

## Root Cause

Gates are usually written from the inside out: the author knows where the
sensitive files live today, so the scan root is written as the directory that
currently holds them. That encodes today's layout as an assumption. The
assumption is load-bearing for the requirement but is itself never enforced —
nothing fails when a file appears outside the assumed root.

This is the inverse of the default-deny posture such gates are meant to
implement. A default-deny gate enumerates what is *allowed* and rejects
everything else; a directory-scoped gate enumerates where it will *look* and
ignores everything else.

---

## Solution

### Step 1: Read every detector for its scan root

Before running anything, list each check and record the root it scans. The gap
is usually visible in the source alone.

```bash
grep -nE "find |grep -r|SCOPE=" tools/provenance/*.sh
```

Write down the union of roots. Anything outside that union is unenforced.

### Step 2: Plant a violating artifact outside the union

Use a plausible directory, not an absurd one — `contracts/` (Hardhat
convention), `lib/` (Foundry dependency convention), `third_party/`, `deps/`.
Plant one artifact per claim the gate makes.

```bash
git status --porcelain > /tmp/pre-probe.txt      # snapshot FIRST

mkdir -p ./contracts/vendored
cp vendor/<pkg>/SomeUpstream.sol ./contracts/vendored/SomeUpstream.sol   # unenumerated source
cp vendor/<pkg>/Pool.sol ./contracts/vendored/ForbiddenName.sol          # excluded filename
printf '// references a prohibited source\n' > ./contracts/vendored/Prohibited.sol
```

### Step 3: Run the full suite and record the exit code

```bash
bash tools/provenance/run-all.sh; echo "EXIT=$?"
```

A green suite with the artifacts present is the finding. Capture the actual
`ok` lines — they are the strongest possible evidence, because they are the
gate asserting its own claim while the violation sits in the tree.

### Step 4: Revert and prove the tree is byte-identical

Non-negotiable. A review that leaves residue is worse than no review.

```bash
rm -rf ./contracts/
git status --porcelain > /tmp/post-probe.txt
diff /tmp/pre-probe.txt /tmp/post-probe.txt && echo "TREE RESTORED EXACTLY"
bash tools/provenance/run-all.sh   # re-confirm green on the pristine tree
```

### Step 5: Recommend inversion, not more detectors

The fix is not "add `contracts/` to the list" — that reproduces the bug at the
next unlisted directory. Recommend deriving the scan set from the authority:

> Enumerate every candidate file repo-wide (excluding build output and tooling
> zones) and fail on any path that is neither an authority-enumerated row nor
> inside an explicitly declared source root.

One inverted check typically subsumes several directory-scoped detectors, and
each then inherits repo-wide reach for free.

### Step 6: Ask for the missing negative test

If the project already has a content-axis negative test, the location-axis one
belongs beside it — same fence-closes-and-reopens discipline:

> plant one violating file outside the census → assert the gate fails →
> remove it → assert the gate is green again.

---

## Verification

### Command

```bash
bash tools/provenance/run-all.sh; echo "EXIT=$?"
```

### Expected Output

Before the fix, with the probe planted — the finding:

```
ok    zero unenumerated files under vendor/
ok    no ForbiddenName.sol implementation
ok    no prohibited-source reference in sources
All provenance gates and tests passed.
EXIT=0
```

After the fix, with the probe planted — the gate closes:

```
FAIL  unauthorized source outside the accepted census: contracts/vendored/SomeUpstream.sol
1 check(s) failed.
EXIT=1
```

### Checklist

- [ ] Every detector's scan root recorded; union computed
- [ ] Violating artifact planted in a *plausible* unlisted directory
- [ ] Full suite run; exit code captured verbatim
- [ ] Probe removed; `git status --porcelain` diffed pre/post and identical
- [ ] Suite re-run green on the pristine tree
- [ ] Finding cites `file:line` of each narrow scan root, not just the symptom
- [ ] The probe run was **quiescent** — nothing else wrote to the tree (see below)

### The inventory check needs a quiescent tree (added 2026-08-11, cycle-002 sprint-2)

The pre/post `git status --porcelain --untracked-files=all` hash is what makes
"the probe left nothing behind" a fact rather than a hope. It also compares the
*whole* working tree, so **anything** writing during the run trips it:

```
FAIL  working-tree inventory changed: e23c5f46… -> 43fee96a…
  ok    probe root ./contracts removed
  ok    probe root ./lib removed
  ok    grimoires/loa/boundary-probe-zone.sol removed
```

Observed live while the demonstration ran in the background and an editor was
concurrently writing `NOTES.md`. Every probe artifact was correctly removed; the
inventory line was reporting the editor's write.

The check is behaving correctly, and the resolution rule matters more than the
cause, because the two readings are asymmetric:

- Reading a real leftover as "just concurrency" leaves dirt in the tree and a
  false claim in the report.
- Reading concurrency as a real leftover costs one re-run.

So: **never dismiss an inventory mismatch by explanation — resolve it by a
controlled re-run** with nothing else touching the tree, and record the hash from
*that* run. If the second run also mismatches, it is real. When the run is long
(a whole-tree walk per gate ×N probes), start it and then stop editing; a fence
demonstration is not something to multitask against.

Optional hardening if this recurs: scope the inventory to the probe roots plus
the gates' own inputs rather than the whole tree. Not done here on purpose — a
whole-tree comparison is the only version that catches a probe writing somewhere
nobody predicted, which is precisely the class this technique exists to find.

---

## Anti-Patterns

### Don't: conclude from reading alone

```
// WEAK - reviewer asserts a bypass without running it
"verify-census.sh only scans vendor/, so unauthorized source elsewhere
 would presumably not be caught."
```

An engineer can reasonably answer "presumably" with "but the SPDX gate covers
it" or "but CI diff review would catch it". A captured green run with the
violation in the tree ends the argument. Demonstrate; do not speculate.

### Don't: leave the probe in the tree

Never rely on "I'll clean it up after". Snapshot `git status` before, revert,
and diff. If the probe cannot be proven reverted, the review has mutated the
artifact under review.

### Don't: use an implausible location

Planting in `/tmp` or a bizarre path invites "nobody would do that" and the
finding gets downgraded. Use the conventional directory for the ecosystem —
`lib/` and `contracts/` are the ones reviewers reach for in Solidity repos.

### Don't: accept "add the directory to the list" as the fix

```bash
# BAD - same bug, one directory later
find vendor contracts -type f
```

---

## Related Resources

- CWE-1053: Missing/Incomplete Verification of Provenance
- SLSA provenance requirements — source integrity is a repo-wide property

---

## Related Memory

### NOTES.md References

- `## Decision Log`: 2026-08-11 [review sprint-1] "Blocking finding is a
  **scoping** defect, not a byte defect" — the project-specific instance
- `## Technical Debt`: "Provenance-gate scoping (raised by /review-sprint
  sprint-1, 2026-08-11, open)" — the open remediation item

### Related Skills

- `independent-constant-reproduction`: the sibling review technique — verify a
  claimed reproduction with tooling independent of the project's own, rather
  than re-running the project's test

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction from cycle-002 sprint-1 review |
| 1.1.0 | 2026-08-11 | Added the quiescent-tree requirement for the pre/post inventory check (cycle-002 sprint-2: a concurrent editor write tripped it while every probe artifact was correctly removed) |

---

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: reviewing-code
  phase: /review-sprint
  session: cycle-002-sprint-1-review
```
