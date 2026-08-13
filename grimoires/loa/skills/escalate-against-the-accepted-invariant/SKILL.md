---
name: escalate-against-the-accepted-invariant
description: |
  A reachable, proven gate gap is not automatically blocking. Once reachability
  is settled, the blocking decision turns on a question most audits skip: does
  the gap violate the invariant the OPERATOR ACCEPTED, or only the sentence the
  TOOL PRINTS? Gates routinely overstate — a walk keyed on `*.sol` prints "zero
  unauthorized source anywhere in the repository" — and it is tempting to
  escalate on the overstatement. Read the accepted authority document instead
  and find what it actually obligates; frequently the surface that authority
  governs is already covered on every axis by a different check, and the
  overstatement is a claim-precision defect rather than a breach. Then separate
  a LATENT gap from an EXPLOITED one by applying the proposed remedy ONCE as a
  measurement over the current subject. Apply during security audit severity
  triage, exact-tree re-audits, acceptance gating, or any "is this finding
  blocking?" decision where a reviewer already graded it. The non-obvious part:
  the gate's own output string is not the guarantee, and grading against it
  produces both false blockers and false reassurance.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-2 exact-tree re-audit (M-1 disposition, VUX provenance boundary)
extraction-date: 2026-08-12
version: 1.0.0
tags:
  - security-audit
  - severity-triage
  - provenance
  - acceptance-gating
  - default-deny
---

## Problem

A review hands you a reachable gap, already graded. You have proven it is real —
the code compiles, executes, reaches deployed bytecode. Now you must decide
whether it blocks operator acceptance.

Two failure modes are available, and both feel rigorous:

- **False blocker.** The gate prints an absolute claim ("zero unauthorized source
  *anywhere in the repository*"), the claim is demonstrably false, so you
  escalate. But the accepted authority never asked for that claim — the gate's
  prose was ambitious, and the surface the authority *does* govern is covered.
  You block a ready sprint over a documentation defect.
- **False reassurance.** You inherit the reviewer's "pre-existing, non-blocking"
  disposition because the reasoning sounds fine, without checking whether
  anything already came through the hole.

Both come from grading the finding against the **tool's self-description**
rather than against the **accepted invariant**, and from never distinguishing
"there is a hole" from "there is a hole and something is in it".

---

## Trigger Conditions

### Symptoms

- A reachable gate gap is confirmed, and the blocking decision is genuinely open.
- The gate's output or comments claim universality ("every", "anywhere",
  "repository-wide", "all sources") while its predicate is narrower.
- A prior review already assigned a severity/disposition you are told not to
  inherit.
- The finding is pre-existing rather than introduced by the change under audit.
- The remediation would reopen an otherwise-ready subject.

### Context

| Context | Value |
|---------|-------|
| Phase | `/audit-sprint`, exact-tree re-audit, acceptance gating |
| Prerequisites | Reachability already proven (see [[gate-gap-reachability-triage]], [[resolver-diagnostic-is-not-reachability]]) |
| Artifacts needed | The operator-accepted authority document(s), not just the gate source |
| Timing | After reproduction, before writing the verdict |

---

## Root Cause

A gate has three separate scopes that drift apart, and they are easy to conflate:

1. **The accepted invariant** — what the operator-signed authority actually
   obligates. Often narrower and differently-shaped than expected.
2. **The tool's claimed scope** — what its comments and PASS lines assert.
   Written aspirationally, and never re-audited when the predicate changes.
3. **The tool's actual scope** — what its predicate really matches.

Reviews naturally compare (3) against (2), because both live in the code under
review. That comparison finds a real defect, but it is a **claim-precision**
defect. Blocking requires (3) to fall short of (1) — and (1) lives in a
document nobody opened.

The second half of the root cause: a gap's severity depends on whether it is
*load-bearing right now*. "The universe walk can miss a file" and "the build
contains a file the walk missed" are different claims with the same shape, and
only the second one blocks.

---

## Solution

### Step 1: Read the accepted authority, not the gate

Find what the operator actually signed, and quote it into the verdict.

```bash
grep -rniE "default.deny|allowlist|every|all .*source" docs/authority/ | head -30
```

Worked example — the VUX provenance authority turned out to be a **source-reuse
authorization** rule, not a repository-scanning rule:

> "default deny: no copying/modification unless a file appears in the frozen
> file-reuse allowlist"

That governs *whether upstream third-party source may be copied in*. It says
nothing about how the repo enumerates its own files.

### Step 2: Find which check actually enforces the accepted invariant

The obligation from Step 1 is usually enforced somewhere other than where you
found the gap. Locate it and test its predicate on the same axis.

In the worked example the authority's surface is `vendor/`, and that check was
already **extension-agnostic**:

```
ok    zero unenumerated files of any type under vendor/
```

So the accepted default-deny was intact on every axis, while the extension gap
lived entirely in the *broader* claim the tool made on its own initiative.

### Step 3: Name the overstatement precisely, as its own finding

Do not let a correct claim-precision defect masquerade as a breach — and do not
suppress it either. State the exact strings that overreach and the exact axis
they overreach on.

Watch for a tell: an adjacent comment is often *precisely* scoped while the
header is not. That asymmetry shows the author knew the real boundary.

### Step 4: Separate LATENT from EXPLOITED — apply the remedy once, as a measurement

This is the step that decides the disposition. Run the proposed fix a single
time, by hand, over the current subject.

```bash
# Ask the compiler what it compiled, then check it against the gate's universe.
find out -name '*.json' -not -path 'out/build-info/*' \
  | while read -r a; do jq -r '(.metadata.sources // {}) | keys[]' "$a"; done \
  | tr -d '\r' | LC_ALL=C sort -u > /tmp/compiled.txt

comm -23 /tmp/compiled.txt /tmp/universe.txt   # must be empty
```

Result in the worked example: 47 compiled sources, **all** classified (33
vendored + 14 owned, 0 unauthorized). That converts the finding from *"the gate
can miss things"* to *"the gate can miss things, and nothing came through"* —
which is what makes a non-blocking disposition defensible rather than hopeful.

> Validate this ad-hoc oracle in both directions before trusting it — see
> [[validate-the-ad-hoc-oracle-both-ways]]. A cross-check that silently compares
> nothing reports a clean subject exactly like a real one does.

### Step 5: Decide, and rank the reasons honestly

Block if (3) falls short of (1), or if the measurement in Step 4 finds anything.
Otherwise: non-blocking **with a binding condition and a deadline tied to a real
downstream gate** (in the worked example, the Sprint 7–8 deployment-bytecode
freeze — nothing is deployed before then, so closing it later costs nothing).

Order the justification by strength and say which reasons are *not* load-bearing.
"Exploitation requires a visible edit" is a weak, contested argument — list it
last, explicitly, and make sure the disposition survives without it.

---

## Verification

### Checklist

- [ ] The accepted authority document was opened and quoted, not paraphrased
- [ ] The check that enforces the accepted invariant was located and tested on the same axis
- [ ] The overstatement is reported as its own finding with exact strings
- [ ] The remedy was applied once as a measurement over the current subject
- [ ] The measurement's oracle was validated in both directions
- [ ] Non-blocking dispositions carry a binding condition and a concrete deadline
- [ ] The weakest argument is listed last and flagged as non-load-bearing

### Expected Output

```
authority obligation : source-reuse authorization (allowlist), NOT repo enumeration
enforced by          : vendor/ exactness check — extension-agnostic (any type)
overstatement        : "anywhere in the repository" / "Every Solidity file"
measurement          : 47 compiled, 0 unclassified  => LATENT, not exploited
disposition          : MEDIUM, non-blocking; binding before bytecode freeze
```

---

## Anti-Patterns

**Grading against the gate's PASS line.** The string "zero unauthorized source
anywhere" is marketing, not a specification. It is evidence of what the author
*intended*, never of what the operator accepted.

**Inheriting the reviewer's disposition because the reasoning is plausible.**
Re-derive it. Converging on the same severity by an independent route is a
result worth reporting; assuming it is not.

**Escalating because the exploit is exotic.** "A weird filename compiles" is not
severity. Neither is "nobody would do that".

**Dismissing on visibility alone.** "The malicious import would show up in the
diff" is the weakest argument in the set — it assumes a reviewer who is looking,
knows what to look for, and is not fatigued. If the disposition needs it, the
disposition is not ready.

**Treating "pre-existing" as a disposition.** It is provenance. It bears on
*whose* sprint must fix it, not on whether it is safe to accept.

**Skipping Step 4 because the gap is "obviously" latent.** The measurement is
cheap and it is the only thing separating a defensible non-blocking call from an
assumption.

---

## Related Memory

- NOTES.md `## Learnings` — the M-1 disposition and the authority-vs-tool split
- [[gate-gap-reachability-triage]] — the prior step: is the gap reachable at all?
- [[matcher-asymmetry-in-default-deny-gates]] — how these predicate gaps arise
- [[resolver-diagnostic-is-not-reachability]] — proving reachability properly
- [[validate-the-ad-hoc-oracle-both-ways]] — trusting the Step 4 measurement
