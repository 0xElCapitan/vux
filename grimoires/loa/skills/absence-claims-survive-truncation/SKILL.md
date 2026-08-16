---
name: absence-claims-survive-truncation
description: |
  A search piped through `head`, `-m`, or a result cap answers "absent from the
  first N results", but gets recorded as "absent". When the claim being made IS
  an absence — this tag does not exist, this identifier appears nowhere, no such
  release was published — a truncating filter silently converts a lookup failure
  into a factual assertion. Apply whenever a negative finding is about to be
  written into a provenance record, authority artifact, audit, or report.
loa-agent: implementing-tasks
extracted-from: sprint-6-task-6.1 (VUX v1, off-chain provenance census)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - provenance
  - evidence-integrity
  - git
  - search-hygiene
---

## Problem

A provenance census recorded that a package version had **no resolvable upstream
tag**. The tag existed. The search had been piped through `head -6` over a
4,424-tag namespace, and the tag sorted below the cut.

The failure is not that a command returned the wrong answer — it returned exactly
what it was asked. The failure is that "not in the first 6 of 4,424" was written
down as "does not exist", in an artifact whose entire purpose is asserting exact
immutable identities.

## Trigger Conditions

### Symptoms

- A search pipeline contains `| head`, `| tail`, `-m N`, `--max-count`, `limit`,
  or any result cap, and its result is about to become a negative claim
- You are about to write "no X exists", "not resolvable", "not published",
  "absent from", "could not be found" into a durable artifact
- The namespace being searched is large (thousands of tags, versions, files)
- A similar probe *did* work for a different input, and you generalised from it

### The specific tell

The probe succeeded for one input and failed for another, and you concluded
something about the *input* rather than about the *probe*:

```bash
# worked for 5.101.4, so the scheme is "per-package tags"
git ls-remote --tags <repo> | grep "5\.101\.4" | head -6   # -> found
git ls-remote --tags <repo> | grep "5\.71\.1"  | head -6   # -> nothing. "no tag exists"
```

Both conclusions are wrong: the second version used an *older tag scheme*
(`v5.71.1` rather than `@scope/pkg@5.71.1`), and the cap hid it.

### Context

| Context | Value |
|---|---|
| Technology Stack | git, package registries, any large-namespace search |
| Timing | while assembling provenance / census / audit evidence |
| Prerequisites | the claim being recorded is negative |

## Root Cause

Two independent causes compound:

1. **Truncation is invisible in the result.** An empty result from a capped search
   and an empty result from an exhaustive one are byte-identical. Nothing in the
   output distinguishes "absent" from "absent so far".
2. **Naming schemes change across eras.** Monorepos migrate tag conventions
   (repo-wide `v<version>` → per-package `@scope/pkg@<version>`), so a probe
   validated against a recent release encodes an assumption that silently fails
   on an older one.

Either alone is survivable. Together they produce a confident false negative.

## Solution

### Step 1: Never cap a search whose result will be a negative claim

```bash
# WRONG — the cap decides the finding
git ls-remote --tags "$REPO" | grep "$VERSION" | head -6

# RIGHT — enumerate fully, count what you searched, then filter
ALL=$(git ls-remote --tags "$REPO")
echo "namespace size: $(echo "$ALL" | wc -l)"
echo "$ALL" | grep -- "$VERSION" || echo "(no match across the full namespace)"
```

Record the namespace size next to the finding. A negative claim over 4,424 tags is
a different claim from one over 6.

### Step 2: Query the exact ref both ways before concluding absence

```bash
for scheme in "v${VERSION}" "${PKG}@${VERSION}" "${VERSION}"; do
  git ls-remote "$REPO" "refs/tags/${scheme}" "refs/tags/${scheme}^{}"
done
```

Enumerate the *candidate schemes*, not just the one that worked last time.

### Step 3: Make the probe self-reporting

A probe that cannot distinguish "searched everything, found nothing" from
"stopped early" should say which it did:

```bash
found=$(echo "$ALL" | grep -c -- "$VERSION")
echo "searched $(echo "$ALL" | wc -l) refs, matched $found"
```

### Step 4: If a negative claim already shipped, retract it in place

Do not silently edit the artifact. Record the retraction, the cause, and the
corrected finding, then harden the stated method so the same truncation cannot
recur:

```markdown
### Correction to pass 1 — the tag IS resolvable

Pass 1 stated that tags for X were "not currently resolvable". That was wrong. The
search was truncated by a `head` filter over a 4,424-tag namespace, and the repo
changed tag schemes across eras. Enumerating the full namespace resolves it:
tag object `828249fd…` → peeled commit `6c105d6d…`.

The verification method now specifies full-namespace enumeration.
```

The retraction is the artifact's credibility, not a blemish on it.

## Verification

### Command

```bash
git ls-remote --tags "$REPO" | wc -l                       # namespace size
git ls-remote "$REPO" "refs/tags/${TAG}" "refs/tags/${TAG}^{}"   # exact, uncapped
```

### Expected Output

```
4424
828249fd05e76d1fe66d110f8c1a80691711d2d0	refs/tags/v5.71.1
6c105d6ddfc797ab5fe106d6020978f711e3af43	refs/tags/v5.71.1^{}
```

### Checklist

- [ ] No `head`/`tail`/`-m`/limit anywhere in a pipeline feeding a negative claim
- [ ] Namespace size recorded alongside the finding
- [ ] All plausible naming schemes tried, not just the one that worked before
- [ ] If the finding is still negative, the *method* is stated in the artifact so a
      reviewer can judge its exhaustiveness
- [ ] Any prior false negative retracted in place, with cause

## Related

- `[Implementation technique — proving a capability is absent]` (NOTES.md) — pairs
  every absence assertion with a positive control. That guards against a *broken*
  search; this guards against a *correct but truncated* one. Both are needed: a
  positive control passes happily while `head` still hides the tail.
- `absence-scans-need-a-negative-control` — the sibling hazard on the opposite
  axis. That skill guards a matcher's PRECISION (a predicate so loose it matches
  everything, producing false positives even though every positive control
  passes) via a negative control that is absent by construction. This skill
  guards a matcher's RECALL (a correct, precise predicate fed a truncated
  namespace, producing a false-negative absence claim) via full-namespace
  enumeration. Neither technique catches the other's failure mode; an absence
  claim that matters is unguarded unless both are considered.
