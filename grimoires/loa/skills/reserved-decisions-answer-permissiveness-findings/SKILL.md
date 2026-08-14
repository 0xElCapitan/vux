---
name: reserved-decisions-answer-permissiveness-findings
description: |
  A review finds that the implementation does not enforce some safety rule that
  obviously *should* hold ("credited revenue should be physically held", "the
  gate should refuse a stale artifact", "this cap should be checked on-chain"),
  and the tempting move is to grade the code against that stronger rule. Before
  writing the finding, ask the different question: is the missing rule ABSENT
  from the authority chain, or is it merely SOMEWHERE ELSE — assigned by name to
  a different authority (operator-reserved execution, a future/P1 design
  obligation, an off-chain policy)? If it lives elsewhere, implementing it would
  have RESOLVED a reserved decision, and the implementer's restraint was required
  rather than merely permitted — the finding inverts. Apply during any review or
  audit of a system with an explicit reserved-decision register, phased P0/P1
  scope, or accepted-doctrine-vs-contract-constant separation. Also gives the
  test for when this is a genuine contradiction (HITL) versus normal precedence.
loa-agent: reviewing-code
extracted-from: cycle-002 sprint-4 `/review-sprint` (J-3 — `realizedRevenue` accumulator vs. segregated balance)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - code-review
  - security-audit
  - requirements-traceability
  - authority-reconciliation
  - severity-triage
  - scope-discipline
  - reserved-decisions
  - hitl
  - solidity
---

## Problem

An implementation ships a bound that is weaker than the one a careful reviewer
would design. The concrete instance: a treasury enforced
`Σ distributions ≤ realizedRevenue[asset]`, where `realizedRevenue` is a
lifetime accumulator with no custody condition. So revenue can be genuinely
earned, the assets behind it redeployed as risk capital and lost, and a **later
principal inflow** can then satisfy the standing credit — principal funding a
revenue payout.

The stronger rule is obvious, cheap, and better accounting: refuse to deploy
assets covering an outstanding credit until the compounding leg has converted
them to principal. The reviewer reaches for `CHANGES_REQUIRED`.

That grading is wrong, and the reason it is wrong does not appear anywhere in
the diff, the tests, or the implementation report. It appears in the **authority
chain**, in a document the reviewer had no reason to open.

---

## Trigger Conditions

### Symptoms

- The implementation report escalates a "judgment call" of the form *"X is an
  accumulator / a soft check / not enforced here — recommend explicit review
  disposition"*.
- A reviewer can state a strictly stronger invariant in one sentence, and the
  implementer explicitly declined to impose it.
- A drafted test or invariant encoding the stronger rule was **removed**, with a
  note explaining why.
- The weaker behaviour is pinned as a *passing* test rather than hidden.
- The project has a phased scope (P0/P1), a reserved-decision register, or an
  "accepted doctrine, never a contract constant" separation.

### Context

| Context | Value |
|---------|-------|
| Artifact | Accepted PRD/SDD/sprint plan + founder/operator authority documents |
| Timing | Review or audit disposition of an escalated judgment call |
| Prerequisites | An authority chain with an explicit reservation register (e.g. PRD §16 R-1…R-14) |
| Anti-trigger | No reserved-decision register exists — then absence really is absence |

---

## Root Cause

Two different failure modes produce the *same* observable ("the contract does
not enforce X"), and they demand opposite verdicts:

1. **The rule is missing.** Nobody assigned it. → real finding.
2. **The rule is assigned elsewhere.** The authority chain names it and gives it
   to a *different* authority — an operator's reserved execution, a mandated P1
   design, an off-chain policy computation. → implementing it on-chain would
   **resolve a reserved decision**, which is normally forbidden outright.

Reviews default to mode 1 because the diff is the thing in front of you and the
reservation register is not. The register is also the *last* place a reviewer
looks, because it reads like governance boilerplate rather than a technical
constraint.

The deeper trap: mode 2 systems deliberately state safety bounds **without** the
condition you expect, and that omission is load-bearing. Reading the omission as
sloppiness inverts the verdict.

---

## Solution

### Step 1: Name the exact mechanism you are about to demand

Write it as a sentence with a searchable noun phrase, not as a feeling.

> "Realized losses must be deducted from distributable revenue before a draw" →
> search terms: `realized-loss`, `high-water`, `restoration`, `qualifying`.

### Step 2: Grep the authority chain for that mechanism — before writing the finding

```bash
grep -ni "high-water\|realized-loss\|restoration" \
  grimoires/loa/prd.md grimoires/loa/sdd.md docs/authority/*.md
```

If it appears **anywhere**, read every hit before grading. In the source case it
appeared in four places, and the decisive one was a table row:

> `R-9` | General revenue policy **execution** | … qualifying-revenue computation
> **incl. realized-loss/high-water restoration** | Principal/marks excluded …

That is the demanded mechanism, named, and **reserved to operator execution**.

### Step 3: Check the phase-scope clause

A reserved mechanism usually pairs with an explicit exclusion:

> "…are founder-accepted **future doctrine**: never stored v1 contract
> constants, and **not implemented by any P0 surface**."

Now implementing the stronger rule is doubly forbidden: it resolves a reserved
decision *and* it builds future doctrine at P0.

### Step 4: Look for the risk register confirming it

Sprint plans often name this exact hazard as a risk the sprint must avoid:

> | Accidentally freezing an operator-reserved execution parameter (R-9/R-10
> execution scope) | Medium | High | Call-time-arguments-only design … |

If present, the implementer's restraint is the *mitigation working*, not a gap.

### Step 5: Re-read the "weak" bound for deliberate omissions

Check whether the accepted text states the bound **without** the condition you
wanted, and whether it refuses that condition elsewhere. In the source case the
SDD twice refused to net losses against revenue — *"never negative revenue"*,
and a write-off *"can only reduce **principal** accounting"*. A credit surviving
a loss was chosen, not overlooked.

### Step 6: Test each high-level requirement as written, not as remembered

The requirements that *sound* violated usually describe a **classification act**,
while the surfaced behaviour involves **no act at all**:

| requirement | does the sequence breach it? |
|---|---|
| "returned principal is never revenue" | No — no principal is ever *credited*; the credit predates the inflow |
| "principal may not be relabeled to fund a preferred recipient" | No — **no relabeling operation exists in the contract** |
| "zero realized revenue provides no fallback to principal" | No — with a zero accumulator every leg reverts, mechanically |

Fungible tokens satisfying a correctly-recognised historical claim is not a
misclassification. Say so explicitly rather than letting the reader assume you
missed it.

### Step 7: Decide HITL by counting authorities, not by discomfort

- **Two rules binding two different authorities** (an on-chain bound *and* an
  operator-reserved computation) — **not** a contradiction. Normal precedence
  resolves it. Do **not** escalate.
- **One authority contradicting another** on the same actor — escalate.

The discomfort of "the contract permits something bad" is not evidence of
contradiction.

### Step 8: Convert the residual into a forward obligation

The correct disposition is not silence. Record that the corrective rule is
unenforced on-chain **by design**, and bind it to the phase that owns it:

> **L-1** — the mandated P1 waterfall design must carry the realized-loss /
> high-water restoration rule, since P0 deliberately omits it.

---

## Verification

### Command

```bash
grep -n "R-[0-9]" grimoires/loa/prd.md | grep -i "<your mechanism>"
```

### Expected Output

Either a reservation row naming your mechanism (→ the finding inverts), or no
hit at all (→ the finding stands).

### Checklist

- [ ] The demanded mechanism was written as a searchable noun phrase first.
- [ ] The reservation register and the phase-scope clauses were grepped **before**
      the finding was drafted.
- [ ] Each allegedly-violated high-level requirement was re-read as written and
      answered individually, in the artifact.
- [ ] The accepted text was checked for a *deliberate* omission of the condition.
- [ ] HITL was decided by counting authorities, not by severity of consequence.
- [ ] The residual is recorded as a forward obligation against the owning phase.

---

## Anti-Patterns

### Don't: grade the implementation against the better design

The review question is "does this faithfully satisfy accepted authority", not
"is this the best available accounting". A stronger design that removes operator
capability is a *change request against the authority chain*, not a code finding.

### Don't: treat an escalated judgment call as an admission

An implementer who surfaces the weaker behaviour, pins it as a passing test, and
documents the removal of the stronger invariant **in place** has done the
disclosure correctly. Grade the disposition, not the fact that one was needed.
The signal to check is the inverse: a stronger rule silently *added* beyond
accepted authority is the scope violation.

### Don't: let "no accepted authority states it" end the analysis

The implementation report may say exactly that, and be right, while missing that
some authority states the *opposite assignment* — which is far stronger evidence
than mere absence. Confirm the reservation yourself; it changes a "defensible
call" into "required restraint", and that difference belongs in the artifact.

### Don't: fold this into a severity discussion

This is a **verdict-direction** question, not a severity question. Resolve
absent-vs-elsewhere first; only then decide low/medium/high on whatever residual
survives.

---

## Related

- [[authority-not-reachability-grades-a-caller-contract-gap]] — the sibling
  question: once a gap is real, grade it by whether its path decides anything.
  This skill runs *first* and often prevents that skill from being needed.
- [[verify-reported-evidence-in-the-completeness-direction]] — the same review
  posture applied to reported evidence rather than to reported judgment calls.
