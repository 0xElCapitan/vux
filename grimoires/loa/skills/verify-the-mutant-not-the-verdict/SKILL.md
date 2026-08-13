---
name: verify-the-mutant-not-the-verdict
description: |
  A negative control (probe, canary, regression test) written in the SAME change
  as the fix it guards is unfalsified by construction — it passes, but a control
  that can never fail passes identically. The standard remedy is to regress the
  fix and require the control to fail. That remedy has its own silent failure
  mode: the regression step itself can no-op (a `sed` whose pattern does not
  match, a patch applied to a copy, an edit whose anchor moved), after which the
  "falsification run" exercises the UNCHANGED code and its output is
  uninterpretable in either direction while looking completely normal. Apply when
  adding a negative control alongside its own fix, when validating a detector by
  breaking what it detects, or in any mutation/chaos test. The rule: prove the
  mutant landed — by asserting on the mutated content, not on the run's verdict —
  before reading any conclusion from the run, and restore by hash afterwards.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-2 /implement (A-1 provenance-boundary remediation)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - negative-testing
  - mutation-testing
  - ci-gates
  - regression-guard
  - shell
  - sed
  - verification
  - false-confidence
---

## Problem

You close a gate gap and, in the same change, add a probe that proves the gate
now catches the case. The probe passes. This is worth almost nothing: a probe
that asserts something already true, a probe wired to the wrong gate, and a probe
that can never fail all produce that identical green line.

The accepted remedy is falsification — temporarily regress the fix and require
the probe to *fail*. But the regression is usually applied by a scripted edit,
and a scripted edit can silently do nothing:

- a `sed` expression whose escaping collapsed and matched zero lines,
- a `patch`/`Edit` anchored on text that shifted,
- a mutation written to a *copy* of the file rather than the one under test,
- an in-memory or cached artifact that the run does not actually re-read.

`sed` in particular exits **0** when it matches nothing. Nothing warns you.

The run then executes the *unchanged* code, and its output is **uninterpretable
in either direction** — yet it looks exactly like a completed experiment:

- If the probe reports "caught it", you may conclude the probe cannot detect the
  regression and go weaken or redesign a probe that was already correct.
- If your expected direction happens to be the other way round, you read the same
  no-op as "control validated" and ship a control that has never once fired.

Both readings are drawn from a run that tested nothing.

### Observed instance

Remediating a case-sensitive `find … -name '*.sol'` in a default-deny provenance
gate, four new probes were added to the standing CI demonstration. To prove them
non-vacuous, the walk was regressed to the pre-fix predicate with:

```bash
sed -i "s|\\\\( -type f -o -type l \\\\) -iname '\\*\\.sol' -print|...|" census.sh
```

The bash-double-quoted escaping of `\( … \)` and `'*.sol'` collapsed; the pattern
matched **zero** lines; `sed` exited 0. The demonstration then ran against the
fixed code and reported every probe "failed closed for the right reason" — a
perfectly normal-looking green run that had falsified nothing. It was caught only
because the command echoed the target line back afterwards and the line still
read `-iname`.

---

## Trigger Conditions

### Symptoms

- A negative control and the fix it guards are introduced in the same change.
- A "prove the probe works" step regresses code with `sed -i`, `patch`, or a
  scripted editor, and reads the *suite's* verdict as the experiment's result.
- The falsification run's output is indistinguishable from an ordinary run.
- A mutation-test step reports a clean, plausible result on the first attempt
  with no evidence that the mutation was ever present.

### Error Messages

None — this failure mode is characterised by the **absence** of an error:

```
# sed matched nothing and is delighted about it
$ sed -i 's/pattern-that-does-not-match/x/' file.sh; echo $?
0
```

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Any. Shown here in bash/`sed` over a CI gate; identical in any language |
| Environment | Local or CI; especially where the mutation and the run are separate steps |
| Timing | When adding a regression guard, negative control, canary, or mutation test |
| Prerequisites | The artifact under mutation must be restorable to a known hash |

---

## Root Cause

Two independent assumptions are collapsed into one observation.

A falsification run asserts a conditional: *if the code is regressed, then the
control fails.* Reading only the run's verdict tests the consequent while taking
the antecedent on faith. The antecedent — "the code is regressed" — is a separate
empirical claim, and scripted edits fail it silently because "changed nothing"
and "changed what I meant" share an exit status.

The asymmetry is what makes it dangerous: a mutation that lands is loudly visible
(the suite goes red), while a mutation that does not land is perfectly quiet.
Silence therefore has two causes and the run cannot distinguish them.

---

## Solution

### Step 1: Prove the anchor is unique BEFORE mutating

Do not mutate on a pattern you have not counted. One line, or stop.

```bash
grep -n 'prune\[@\]' tools/provenance/census.sh
# 205:  find . \( "${prune[@]}" ... \) -iname '*.sol' -print ...
# exactly one hit -> safe to target; zero or many -> fix the anchor first
```

Prefer a short, structurally unique anchor over a long, heavily-escaped one.
`/prune\[@\]/` beat the full `find` expression precisely because it needed almost
no escaping. Note it is also case-discriminating here: `SOURCE_UNIVERSE_PRUNE[@]`
does not match lowercase `prune[@]`.

### Step 2: Assert on the mutated CONTENT, and abort if absent

The mutation is a claim. Make the script prove it, and refuse to continue
otherwise — this is the whole skill in six lines.

```bash
cp "$FILE" "$FILE.orig"                      # restore source of truth
sed -i '/prune\[@\]/ s/-iname/-name/' "$FILE"

sed -n '205p' "$FILE"                        # show the operator the mutant
if grep -q "prune\[@\].*-name '\*\.sol'" "$FILE" && ! grep -q "prune\[@\].*-iname" "$FILE"; then
  echo "REGRESSION APPLIED"
else
  echo "!!! regression NOT applied — aborting"; cp "$FILE.orig" "$FILE"; exit 1
fi
```

Assert both directions — the new form present **and** the old form gone. A
one-sided check passes when an edit duplicates rather than replaces.

### Step 3: Require the control to fail, per probe

Record which probes flip and which do not. A probe that does *not* flip is not
automatically broken — it may be guarded by a different mechanism, and knowing
which is itself a finding.

```
probe 8  → FAIL  gate PASSED with the probe present — the fence is open   ✓ detects
probe 9  → FAIL  gate PASSED with the probe present — the fence is open   ✓ detects
probe 10 → ok    gate failed closed for the right reason                  — guarded elsewhere
probe 11 → FAIL  gate PASSED with the probe present — the fence is open   ✓ detects
demo exit=1
```

Probe 10 not flipping was correct and expected: it was reached by a *different*
assertion that had always been case-insensitive — which was the original finding,
observed from the other side. Explain every non-flipping probe or treat it as
vacuous.

### Step 4: Restore by hash, not by hope

```bash
BEFORE="$(sha256sum "$FILE" | cut -d' ' -f1)"   # captured before Step 2
cp "$FILE.orig" "$FILE"; rm -f "$FILE.orig"
[[ "$BEFORE" == "$(sha256sum "$FILE" | cut -d' ' -f1)" ]] \
  && echo "RESTORED EXACTLY" || echo "!!! RESTORE MISMATCH"
```

`git checkout --` is not equivalent when the file was already dirty — which it is
whenever the fix is uncommitted, i.e. always in this workflow. Keep an explicit
copy. Do **not** reach for `git stash` here (see Anti-Patterns).

---

## Verification

### Command

```bash
# 1. control must FAIL against a verified mutant
bash prove-regression.sh          # Steps 1-4 above
# 2. control must PASS against the real code
bash tools/provenance/demo-boundary-negative.sh; echo "exit=$?"
# 3. the artifact must be byte-identical to its pre-experiment state
sha256sum tools/provenance/census.sh
```

### Expected Output

```
REGRESSION APPLIED (universe walk is case-sensitive again)
  FAIL  gate PASSED with the probe present — the fence is open [repository root, .SOL]
demo exit=1
RESTORED EXACTLY (63e8ec9d21fd40568db90bc3345a520b8aefe2dab1ae394395664c14bebf8533)
...
Source-boundary fence proven closed on all 11 probes and reopened.
exit=0
```

### Checklist

- [ ] Anchor proven to match exactly one line before mutating
- [ ] Mutated line echoed back and asserted on (both directions)
- [ ] Script aborts and self-restores when the mutation does not land
- [ ] Each probe's flip/no-flip outcome recorded, and every no-flip explained
- [ ] Artifact restored and re-verified by SHA-256, not by `git checkout`
- [ ] Post-restoration suite re-run green

---

## Anti-Patterns

### Don't: read the suite's verdict as proof the mutation happened

```bash
# BAD - two claims, one observation; sed's exit 0 means nothing
sed -i 's/-iname/-name/' census.sh
bash demo.sh && echo "probes are vacuous"   # ...or the sed no-op'd. Unknowable.
```

### Don't: mutate on a long, heavily-escaped pattern

```bash
# BAD - every backslash is a chance to silently match nothing
sed -i "s|\\\\( -type f -o -type l \\\\) -iname '\\*\\.sol' -print|...|" census.sh
```

Anchor on the shortest unique token instead. If the anchor genuinely needs heavy
escaping, mutate by line number derived from a verified `grep -n` in the same
run — not a line number remembered from earlier.

### Don't: use `git stash` to park the fix during the experiment

The repository's own `.claude/rules/stash-safety.md` blocks this class: overlapping
stashes shift indexes and `pop` can land on the wrong entry, and combining it with
output suppression turns data loss into a green log. An explicit `cp` + hash
comparison has none of that surface. A `git worktree` is the heavier alternative
when the experiment must not touch the working tree at all.

### Don't: accept a probe that never flips without explaining it

Either it is guarded by a different mechanism — say which, in a comment beside
the probe — or it is vacuous and must be redesigned. "It passed both ways" is not
a result.

---

## Related Resources

- `.claude/rules/stash-safety.md` — why `git stash` is the wrong parking mechanism here
- Mutation testing generally: a surviving mutant indicts the test suite; this skill
  is about the prior question of whether the mutant was ever created

---

## Related Memory

### NOTES.md References

- `## Learnings`: `[CLOSED 2026-08-11 at /implement sprint-2 A-1 remediation]` —
  records the instance and the rule ("verify the mutant, not just the verdict")
- `## Decision Log`: 2026-08-11 entries on probe-stem selection and the
  outside-the-repo build-reachability control

### Related Skills

- `fail-closed-gate-scope-probe`: the complementary phase — how to *find* a gate's
  scope gap by probing. This skill covers what to do afterwards: proving the probe
  you added to guard the fix can actually detect its reintroduction.
- `matcher-asymmetry-in-default-deny-gates`: the defect class that produced this
  session's fix; explains why probe 10 legitimately did not flip.
- `resolver-diagnostic-is-not-reachability`: sibling rule about reading a tool's
  diagnostic as evidence of something it does not assert.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction |

---

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true      # sed silently no-op'd; caught only on a second pass with an explicit content assertion
  reusability: true          # language- and project-agnostic; applies to any negative control or mutation test
  trigger_clarity: true      # concrete trigger (control added with its own fix; scripted regression step)
  verification: true         # verified in-session: probes 8/9/11 flipped to "fence is open", demo exit=1, census.sh restored byte-identical
extraction_source:
  agent: implementing-tasks
  phase: /implement sprint-2 (A-1 provenance-boundary remediation)
  session: cycle-002 2026-08-11
```
