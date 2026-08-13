---
name: gate-verdict-without-lifecycle-closure
description: |
  When an operator needs a quality gate's VERDICT but not the lifecycle
  transition its command performs (COMPLETED marker, ledger status, index
  closure, task closure), read the command wrapper and the underlying skill
  frontmatter separately before concluding the two are inseparable. Loa's
  pure-review skills declare `write_files: false` with
  `disallowed-tools: [Write, Edit]`, which means the skill never persists its own
  artifact — the wrapper does. Artifact persistence is therefore architecturally
  the CALLER's job, so a bounded caller can execute the native methodology and
  verdict contract while suppressing every closure side effect, with no loss of
  verdict fidelity. Apply when a lifecycle demands operator acceptance between
  audit and completion, or whenever a gate must run without advancing state.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-1 /audit-sprint (VUX lifecycle: audit precedes operator acceptance)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - loa-lifecycle
  - audit
  - skill-frontmatter
  - disallowed-tools
  - process-compliance
  - verdict-contract
---

## Problem

A project's lifecycle inserts a step the framework command does not model. Loa's
`/audit-sprint` treats approval as terminal — it creates a `COMPLETED` marker,
flips the Sprint Ledger to `completed`, and closes the A2A index. A lifecycle
that requires **explicit operator acceptance** after audit and before commit
needs the audit *verdict* without any of that.

The two apparent options are both bad:

1. Run the stock command and accept a false `COMPLETED` state, which corrupts
   lifecycle evidence and claims an acceptance the operator never gave.
2. Hand-roll a bespoke audit, abandoning the native methodology, the verdict
   contract, and the framework's mechanical verdict validation — and produce an
   artifact downstream tooling cannot consume.

Neither is necessary. The separation already exists in the framework; it is just
not visible from the command file.

---

## Trigger Conditions

### Symptoms

- The operator explicitly forbids `COMPLETED`, ledger completion, index closure,
  or task closure, but still requires a durable native verdict.
- The command's `outputs:` block lists lifecycle artifacts alongside the report.
- A prompt says "use the live skill as authority — do not recreate its
  methodology" while also constraining what may be mutated.
- Uncertainty about whether invoking the skill will strip the tools needed to
  persist the result.

### Context

| Context | Value |
|---------|-------|
| Node | `/audit-sprint`, `/review-sprint`, any gate whose approval advances state |
| Technology Stack | Loa framework, Claude Code skill frontmatter |
| Timing | when the project lifecycle inserts a step the command does not model |
| Prerequisites | read access to `.claude/commands/*.md` and `.claude/skills/*/SKILL.md` |

---

## Root Cause

The command wrapper and the skill are **two different artifacts with two
different permission surfaces**, and only the wrapper carries the closure logic.

`.claude/commands/audit-sprint.md`:

```yaml
outputs:
  - path: "grimoires/loa/a2a/$RESOLVED_SPRINT_ID/auditor-sprint-feedback.md"
  - path: "grimoires/loa/a2a/$RESOLVED_SPRINT_ID/COMPLETED"      # <- closure
  - path: "grimoires/loa/a2a/index.md"                            # <- closure
  - path: "grimoires/loa/ledger.json"                             # <- closure
```

`.claude/skills/auditing-security/SKILL.md`:

```yaml
capabilities:
  write_files: false          # the skill writes NOTHING
disallowed-tools:
  - Write
  - Edit
  - NotebookEdit              # harness-level, per .claude/rules/skill-invariants.md
```

The skill *cannot* write its own report — cycle-114 FR-4 removes the write tools
while it is active, mechanically enforcing C-PROC-001. So persisting
`auditor-sprint-feedback.md` was never the skill's job; the caller does it. Once
that is seen, "verdict without closure" is not a workaround — it is the wrapper's
report output minus its lifecycle outputs, which are independent.

The corollary matters just as much: **formally invoking the pure-review skill can
remove the very tool needed to persist the verdict**, converting a completable
audit into a forced `HITL_REQUIRED`. The skill's authority is its methodology and
verdict contract, both of which load by reading it.

---

## Solution

### Step 1: Diff the wrapper's outputs against the skill's capabilities

```bash
sed -n '/^outputs:/,/^mode:/p' .claude/commands/audit-sprint.md
sed -n '/^capabilities:/,/^cost-profile:/p' .claude/skills/auditing-security/SKILL.md
grep -A4 '^disallowed-tools:' .claude/skills/auditing-security/SKILL.md
```

If the skill is `write_files: false`, every output in the wrapper is
caller-performed and independently suppressible.

### Step 2: Execute the native contract, persist at the caller layer

Follow the skill's workflow verbatim — its phases, its severity tally, its
one-way rule (`critical + high > 0 ⇒ CHANGES_REQUIRED`; zero counts never force
approval), and its exact verdict prose and trailer:

```
APPROVED - LET'S FUCKING GO

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{...},"sprint_id":"sprint-N","ts":"..."} -->
```

Write **only** the report path. Do not create `COMPLETED`, touch the ledger,
update the index, or close beads.

### Step 3: Run the framework's own verdict validation

This is what preserves the verdict *interface* and distinguishes a bounded
invocation from a hand-rolled one:

```bash
bash .claude/scripts/verdict-derive.sh \
  --file grimoires/loa/a2a/sprint-1/auditor-sprint-feedback.md --gate audit
```

It enforces trailer presence and last-line position, prose↔trailer agreement, and
the one-way severity rule.

### Step 4: Prove the suppression mechanically

Assert the absence of each closure effect rather than asserting it in prose:

```bash
[ -f grimoires/loa/a2a/sprint-1/COMPLETED ] && echo 'LEAK' || echo 'ABSENT (correct)'
jq -r '.cycles[]|select(.id=="cycle-002").sprints[]
       |select(.local_label=="sprint-1")|.status,.completed' grimoires/loa/ledger.json
git rev-parse HEAD          # unchanged
```

### Step 5: Say in the artifact what the verdict does and does not mean

State plainly that audit approval establishes eligibility for operator acceptance
and is not acceptance, and enumerate exactly what the node mutated. A verdict
whose scope is ambiguous invites the closure it was designed to avoid.

---

## Verification

### Command

```bash
bash .claude/scripts/verdict-derive.sh --file <artifact> --gate audit
```

### Expected Output

```
CONSISTENT: gate=audit verdict=APPROVED
```

### Checklist

- [ ] Wrapper `outputs:` inspected; closure outputs enumerated
- [ ] Skill `capabilities.write_files` / `disallowed-tools` inspected
- [ ] Native phases, severity tally, one-way rule, exact prose and trailer used
- [ ] `verdict-derive.sh` returns `CONSISTENT`
- [ ] `COMPLETED` absent; ledger `in_progress`/`completed: null`; index unchanged
- [ ] Beads untouched; no commit, push, or tag
- [ ] Artifact states that approval ≠ acceptance and lists every mutation

---

## Anti-Patterns

### Don't: assume the command and the skill are one unit

The command file is the lifecycle; the skill is the methodology. Conflating them
forces a false choice between corrupting lifecycle state and abandoning the
native contract.

### Don't: invoke a pure-review skill when you must persist its output

```
# BAD - disallowed-tools removes Write while active; the verdict cannot be saved,
# and an otherwise-completable audit degrades to HITL_REQUIRED.
Skill(auditing-security)   # then try to Write the artifact
```

Reading the SKILL.md loads the same authority without removing the tool the caller
needs. Reserve formal invocation for callers that do not persist the result.

### Don't: drop the LOA-VERDICT trailer because the run is "custom"

The trailer is the machine interface every downstream consumer reads. A bounded
invocation that omits it is a hand-rolled audit wearing the native name.

### Don't: write a partial closure as a compromise

Updating the index to `AUDIT_APPROVED` while withholding `COMPLETED` still
advances lifecycle state the operator withheld. Suppress all of it, or return
`HITL_REQUIRED`.

---

## Related Memory

### NOTES.md References

- `## Decision Log`: lifecycle requires explicit operator acceptance between
  audit approval and commit; audit approval confers eligibility only.

### Related Skills

- `gate-gap-reachability-triage`: the classification work performed *inside* this
  bounded invocation.
- `audit-subject-fingerprint-under-agent-telemetry`: proves the bounded node
  mutated nothing beyond its authorized artifact.

### Framework References

- `.claude/rules/skill-invariants.md` — `disallowed-tools` as a harness-level
  barrier; the pure-review vs report-authoring skill classes.
- `.claude/scripts/verdict-derive.sh` — the verdict contract validator.

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
