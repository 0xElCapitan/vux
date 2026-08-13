---
name: audit-subject-fingerprint-under-agent-telemetry
description: |
  When a node must prove it did not mutate its subject, a single aggregate hash
  over "all tracked + untracked files" WILL change on its own — agent-framework
  hooks append telemetry (.run/*.jsonl, trajectory logs, perf caches) on every
  tool call. Define the fingerprint as the audited SURFACE and exclude
  framework-written telemetry, and record PER-SUBTREE hashes alongside the
  aggregate so a change can be localized instead of reading as a mutation alarm.
  Also: `find -mmin`/`-newermt` windows routinely catch files written just BEFORE
  the node began, so mtime alone attributes nothing. Apply in any audit, review,
  or verification node operating under a no-mutation boundary inside an agentic
  harness.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-1 /audit-sprint (exact-tree / mutation-boundary rule)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - security-audit
  - integrity
  - fingerprinting
  - attribution
  - loa-hooks
  - telemetry
  - false-positive
---

## Problem

An audit operating under an exact-tree rule must establish a reproducible
fingerprint before work begins and re-verify it after, so implementation mutation
during the node is detectable. The natural construction:

```bash
{ git ls-files; git ls-files --others --exclude-standard; } | sort -u \
  | xargs sha256sum | sha256sum
```

This **fails as an integrity signal**, and it fails in the most expensive
direction: it reports a change when nothing in the audited subject changed.

Observed in the originating session: the digest moved from `d1f8eb31…` to
`5430091f…` with the file count constant at 357. Read naively that is "content
changed but no files added or removed" — indistinguishable from tampering, and
grounds for aborting the audit.

The follow-up made it worse before it made it better. A `find -mmin -40` sweep
returned, among other paths:

```
./vendor/uniswap-v3-core-v1.0.0/contracts/UniswapV3Pool.sol
./grimoires/loa/a2a/sprint-1/engineer-feedback.md
./grimoires/loa/sprint.md
```

A recently-touched **vendored** file is exactly the alarm a provenance audit
exists to raise, and two of the others were review artifacts the node was
forbidden to modify.

Both signals were false. Nothing in the subject had changed.

---

## Trigger Conditions

### Symptoms

- A pre/post fingerprint differs while the file **count** is identical.
- `find -mmin` / `-newermt` implicates files the node demonstrably never opened.
- Untracked, non-gitignored state paths appear in the subject list (`.run/`,
  `.ck/`, trajectory JSONL, perf caches).
- About to report "tree changed" or abort a node on this evidence.

### Context

| Context | Value |
|---------|-------|
| Node | any audit/review/verification node under a no-mutation boundary |
| Technology Stack | Loa framework (or any harness with PreToolUse/PostToolUse hooks) |
| Timing | pre-audit fingerprint capture and post-audit re-verification |
| Prerequisites | `.run/` and trajectory dirs not covered by `.gitignore` |

---

## Root Cause

Two independent causes, and they compound.

**1. The harness writes to the working tree on every tool call.** Loa safety and
telemetry hooks append to `.run/audit.jsonl`, `.run/karpathy-task-state.jsonl`,
`.run/perf-cache/*`, and `grimoires/loa/a2a/trajectory/*.jsonl` continuously. None
is gitignored, so `git ls-files --others --exclude-standard` includes them and
their bytes land inside the aggregate. The digest is therefore guaranteed to move
in any session of non-trivial length — it measures the *session*, not the subject.

**2. `-mmin`/`-newermt` windows are wider than the node.** A window chosen to
cover "this node" (`-mmin -40`) also covers whatever the *previous* node wrote in
its final minutes. The vendored file and the review artifacts carried mtimes of
`23:40`–`23:48`; the audit began at `~23:57`. They were the implementation and
review nodes' own writes, correctly untouched since.

Neither cause is visible from the aggregate. An aggregate hash answers "did
anything change?" but never "what?", so it cannot distinguish a telemetry append
from a vendored-source edit.

---

## Solution

### Step 1: Define the subject as the audited surface, not the working tree

Enumerate what is actually under audit and exclude framework telemetry by
construction:

```bash
{ find tools test vendor docs src script .github/workflows -type f;
  printf '%s\n' foundry.toml remappings.txt .gitattributes .gitignore \
    THIRD_PARTY_NOTICES.md LICENSE \
    grimoires/loa/prd.md grimoires/loa/sdd.md grimoires/loa/sprint.md \
    grimoires/loa/a2a/sprint-1/reviewer.md \
    grimoires/loa/a2a/sprint-1/engineer-feedback.md; } \
  | LC_ALL=C sort -u > /tmp/subject.txt

while IFS= read -r f; do sha256sum "$f"; done < /tmp/subject.txt \
  | LC_ALL=C sort | sha256sum | cut -d' ' -f1     # AUDIT_SUBJECT_DIGEST
```

Publish the subject **definition** next to the digest. A digest whose scope is
unstated is unauditable.

### Step 2: Record per-subtree hashes at the same moment

This is the step that converts a future alarm into a two-minute lookup:

```bash
for d in tools test vendor docs/authority .github/workflows; do
  printf '%-22s %s\n' "$d" \
    "$(find "$d" -type f | LC_ALL=C sort | while IFS= read -r f; do sha256sum "$f"; done \
       | sha256sum | cut -d' ' -f1)"
done
```

When the aggregate moves, re-run this: every subtree reporting `UNCHANGED`
localizes the delta to what the subject excludes.

### Step 3: Re-verify domain identity independently, not just by hash equality

For a provenance audit, re-derive the authority's own per-file identities at the
end rather than trusting the subtree hash alone — it catches a compensating edit
and confirms the specific security property:

```bash
# 63/63 re-verified against the accepted registry, 0 drift
```

### Step 4: Date the mtime window against the node's actual start

Before implicating any file, compare its mtime to when the node began:

```bash
stat -c '%y' <suspect-file>; date '+%Y-%m-%d %H:%M:%S'
```

A file older than the node's first tool call was written by a previous node. Then
confirm content, which is decisive where mtime never is:

```bash
sha256sum vendor/.../UniswapV3Pool.sol
jq -r '...|.sha256' docs/authority/<registry>.json    # equal -> untouched
```

### Step 5: Report the three categories separately

Do not fold them together — the distinction is the whole claim:

| Category | Example | Claim |
|---|---|---|
| Authorized node output | `auditor-sprint-feedback.md` | created by this node, by authorization |
| Regenerated derived output | `out-v3core/`, `cache-v3core/` | gitignored, outside the subject, byte-identical |
| Harness telemetry | `.run/*.jsonl`, `trajectory/*.jsonl` | appended by hooks on every tool call, in any session |

State explicitly that the digest excludes the artifact's own bytes, so audit
bookkeeping is never claimed as part of the pre-audit subject.

---

## Verification

### Command

```bash
DIG=$(while IFS= read -r f; do sha256sum "$f"; done < /tmp/subject.txt \
      | LC_ALL=C sort | sha256sum | cut -d' ' -f1)
[ "$DIG" = "$AUDIT_SUBJECT_DIGEST" ] && echo UNCHANGED || echo CHANGED
```

### Expected Output

```
UNCHANGED
```

### Checklist

- [ ] Subject definition published alongside the digest
- [ ] Telemetry paths excluded by construction, not by after-the-fact reasoning
- [ ] Per-subtree hashes captured pre-node
- [ ] Post-node aggregate re-verified; any delta localized by subtree
- [ ] Domain identities (registry/census) independently re-derived at the end
- [ ] Every mtime-implicated file dated against the node's start and content-checked
- [ ] Mutations reported in the three categories above

---

## Anti-Patterns

### Don't: fingerprint the whole working tree in an agentic harness

```bash
# BAD - includes .run/*.jsonl and trajectory logs the harness appends to on
# every tool call. Guaranteed to differ; measures the session, not the subject.
git ls-files --others --exclude-standard | xargs sha256sum | sha256sum
```

### Don't: keep only the aggregate

An aggregate detects change and localizes nothing. Without per-subtree hashes the
only recovery is re-deriving everything under time pressure, which is exactly when
a wrong call gets made.

### Don't: treat mtime as attribution

`find -mmin -N` answers "modified within N minutes", never "modified by this
node". Anchor to the node's first tool call, then decide on content.

### Don't: abort on a fingerprint delta before localizing it

The correct sequence is localize → date → content-check → conclude. Reporting
"tree changed" from the aggregate alone is a false alarm that costs the node its
credibility.

---

## Related Memory

### NOTES.md References

- `## Learnings`: "[Attribution on uncommitted trees]" — mtime windows as the
  only mechanical attribution signal on untracked trees. This skill adds the
  failure mode of that technique (windows overlap the previous node) and the
  aggregate-vs-per-subtree localization that resolves it.

### Related Skills

- `gate-verdict-without-lifecycle-closure`: the bounded node whose no-mutation
  claim this fingerprint substantiates.
- `independent-constant-reproduction`: same discipline — verify against the
  authority's value, not a local copy.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction |

---

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: auditing-security
  phase: /audit-sprint
  session: cycle-002-sprint-1-audit
```
