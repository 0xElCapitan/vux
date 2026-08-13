---
name: write-denied-long-artifact-authoring
description: |
  Authoring a long artifact (a review verdict, an audit report) from a skill
  whose frontmatter declares `disallowed-tools: [Write, Edit]` forces the write
  through Bash — and a single Bash invocation has a spawn-argument length limit
  that the whole heredoc body counts against. Over the limit the call fails in
  two ways, and the second one lies: it reports `unexpected EOF while looking
  for matching quote` and points at an apostrophe in your prose, when the real
  cause is that the command string was truncated before the heredoc terminator.
  Apply whenever a pure-review or pure-audit skill must persist a
  multi-hundred-line artifact, or whenever a quoted heredoc reports a quoting
  error it cannot possibly have.
loa-agent: reviewing-code
extracted-from: cycle-002 / sprint-2 / /review-sprint sprint-2
extraction-date: 2026-08-11
version: 1.1.0
tags:
  - loa-framework
  - bash
  - heredoc
  - pure-review-skills
  - tooling
---

## Problem

Loa's pure-review skills (`reviewing-code`, `auditing-security`) declare
`write_files: false` and `disallowed-tools: [Write, Edit, NotebookEdit]`. The
harness removes those tools while the skill is active, so the skill's own
required output — `engineer-feedback.md`, `auditor-sprint-feedback.md` — must be
written with Bash.

Those artifacts are long. A thorough monetary-core review verdict runs 600+
lines. Writing it as one `cat > file` heredoc fails, and the failure mode depends
on how far over the limit you are:

```
ENAMETOOLONG: name too long, uv_spawn
```

```
/usr/bin/bash: -c: line 97: unexpected EOF while looking for matching quote
```

The second message is the dangerous one. It names a line number inside your
content and blames a quote character, so the natural response is to hunt for an
unbalanced apostrophe — in prose that legitimately contains `constructor's`,
`caller's`, `Reserve's`. That hunt cannot succeed, because there is no quoting
bug.

---

## Trigger Conditions

### Symptoms

- A heredoc write fails while a materially shorter one to the same path succeeds.
- The error names a line number that is inside heredoc *content*, not shell code.
- Retrying the identical command reproduces the identical failure.
- Splitting the same content into two appends succeeds with no content edits.
- The target file is unchanged (zero bytes written) after the failure — the
  shell never ran the command, so there is no partial write to clean up.

### Context

| Context | Value |
|---------|-------|
| Framework | Loa pure-review / pure-audit skills (`disallowed-tools: [Write, Edit]`) |
| Tooling | Any agent harness that spawns the shell with the whole command as one argv |
| Timing | Phase 5 — writing the verdict artifact |
| Prerequisites | Artifact large enough to approach the argv limit (empirically a few hundred lines; fewer if lines are long) |

---

## Root Cause

The entire command — heredoc body included — is passed to the shell as **one
argv string**. It is not streamed. Two outcomes:

1. **Rejected at spawn.** The OS refuses the oversized argv and the harness
   surfaces `ENAMETOOLONG … uv_spawn`. An honest error.
2. **Truncated.** The command string is cut short, so the closing terminator
   never reaches the shell. Bash reads to end-of-input still inside the heredoc
   and reports `unexpected EOF`. The quote character it names is simply whatever
   the truncated tail happened to end near — an artifact of where the cut landed,
   not a real parse problem.

**The discriminator that ends the debugging immediately:** a *quoted* heredoc
delimiter performs no parameter expansion, no command substitution, and no quote
parsing on the body. Every byte is literal. Therefore a quoting error reported
against a quoted heredoc is **never** a content-quoting bug. If you see one, the
input was truncated. Stop looking at your prose.

Line count is a poor proxy for the limit — **bytes** are what count. A 90-line
chunk of wide markdown table rows can exceed a 130-line chunk of ordinary prose.

---

## Solution

### Step 1: Create the first section, then append the rest

Keep the approval contract intact: the first line of an approved review artifact
must be exactly `All good`, so it belongs in the creating chunk.

```bash
cat > grimoires/loa/a2a/sprint-N/engineer-feedback.md <<'EOF'
All good

# Sprint-N Review
...sections 1-2...
EOF
```

Then append each subsequent section with `>>` and its own quoted heredoc.

### Step 2: Confirm each chunk landed before writing the next

Never fire chunks blind — a silently failed middle chunk yields a
coherent-looking artifact with a hole in it.

```bash
echo "chunk ok: $(wc -l < grimoires/loa/a2a/sprint-N/engineer-feedback.md) lines"
```

A chunk that fails writes nothing, so the line count simply will not advance.
Re-check before continuing.

### Step 3: When a chunk still fails, cut bytes — not content

Wide markdown tables are the usual culprit. Converting one table into a bullet
list preserves every fact while removing the padding that pushed the chunk over
the limit. A seven-row table of long cells routinely halves in size this way.

### Step 4: Verify the artifact's contract, not just its size

Chunked writes can satisfy `wc -l` and still break the gate contract.

```bash
head -1 file   # must be exactly the approval token
tail -1 file   # must be the LOA-VERDICT trailer, nothing after it
grep -nE '^## (Changes Required|Findings|Issues)' file   # must match nothing on an approval
```

---

## Verification

### Command

```bash
.claude/scripts/verdict-derive.sh --file grimoires/loa/a2a/sprint-N/engineer-feedback.md --gate review
```

### Expected Output

```
CONSISTENT: gate=review verdict=APPROVED
```

### Checklist

- [ ] Every chunk's `wc -l` advanced as expected
- [ ] First line is the approval token (when approving)
- [ ] Last line is the `LOA-VERDICT` trailer with nothing after it
- [ ] No banned heading present on an approval
- [ ] `verdict-derive.sh` reports `CONSISTENT`

---

## Anti-Patterns

### Don't: switch to an unquoted heredoc to "fix the quoting"

This is the trap the misleading error steers you into, and it corrupts the
artifact instead of failing loudly. An unquoted delimiter expands `$...` and
backticks — and a review artifact is full of both: backticked `file:line`
references, shell snippets, and `${...}` inside quoted code. The write then
"succeeds" with silently eaten content, which is strictly worse than the error
you were trying to avoid.

Per `.claude/rules/shell-conventions.md` the delimiter stays quoted. Always.
The fix for a truncation error is fewer bytes, never weaker quoting.

### Don't: retry the identical monolithic command

The limit is deterministic. A second attempt fails identically and costs a
round-trip.

### Don't: build the file with per-line `echo`

Dozens of invocations, each its own failure point, and every line re-opens the
quoting hazard the heredoc was avoiding.

### Don't: assume a failed chunk left a partial file

It did not — the shell never executed. Truncating or rewriting "to clean up"
risks destroying the chunks that *did* land. Check `wc -l` first.

---

## Related Memory

### NOTES.md References

- `## Learnings`: "[Loa lifecycle — verdict without closure]" — establishes that
  pure-review skills cannot persist their own artifact. This skill is the next
  problem in that same workflow: once you know the write must go through Bash,
  this is how that write fails.

### Related Skills

- `gate-verdict-without-lifecycle-closure`: why the Write tool is absent in the
  first place, and how to run a gate's methodology without its closure effects.

### Related Rules

- `.claude/rules/shell-conventions.md`: the quoted-delimiter requirement and the
  expansion hazard the anti-pattern above would reintroduce.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction from `/review-sprint sprint-2` |
| 1.1.0 | 2026-08-11 | Recurrence data from `/review-sprint sprint-2` re-review: 2 more truncations in one artifact. Both failing chunks were dense markdown TABLES; every prose/bullet chunk of similar line count succeeded. Line count is a poor proxy — budget by bytes, and split table-heavy sections first. Successful chunk sizes this session: 45-130 lines of prose, ~40 lines when table-dense. |

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
  session: cycle-002/sprint-2
```
