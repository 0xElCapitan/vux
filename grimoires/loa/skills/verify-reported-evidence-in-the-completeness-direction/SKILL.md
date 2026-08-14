---
name: verify-reported-evidence-in-the-completeness-direction
description: |
  Re-deriving a report's numbers proves the report is HONEST about what it
  listed; it proves nothing about what it did not list. Every reported artifact
  — a subject manifest, a hash fingerprint, an ABI enumeration, a mutator count,
  a test total, a bit-identity assertion — has a correctness direction (do the
  listed items check out?) and a completeness direction (is the list the whole
  set, and does each assertion discriminate?). Reports are written to invite the
  first and are silent about the second, so a reviewer who only re-runs the
  numbers can return APPROVED on a subject that was never fully seen. Apply at
  any exact-tree review or audit node, and to any claim of the form "N items,
  all verified". Provides the paired second-direction check for each common
  evidence type.
loa-agent: reviewing-code
extracted-from: cycle-002 sprint-4 `/review-sprint` (24-file subject fingerprint; 44-entry closed-world ABI; FB-5 bit-identity)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - code-review
  - security-audit
  - evidence-integrity
  - exact-tree-review
  - non-vacuity
  - test-quality
  - provenance
  - solidity
  - foundry
---

## Problem

An implementation node reports a subject fingerprint over 24 files. The reviewer
recomputes it, gets a byte-identical match, and records "subject identity
verified".

It is not verified. The hash proves those 24 files are what the manifest says
they are. It says nothing about a **25th file** that was changed and never
listed — the one failure mode a manifest actually needs to defend against, and
the one a matching hash cannot detect, because omission and integrity are
orthogonal properties.

The same gap recurs across every evidence type a report offers:

| reported | what re-running proves | what it silently does not |
|---|---|---|
| subject fingerprint | listed files are unaltered | no unlisted file changed |
| "44 external functions" | 44 entries exist | each is *accounted for* / none is unexpected |
| "13 mutators, all role-gated" | those 13 are gated | 13 is the whole mutator set |
| "298 tests pass" | they pass | any of them would fail if the code broke |
| "core state bit-identical after loss" | the values match | the loss actually happened |
| "fuzz 10,000 runs" | depth is configured | the properties assert something falsifiable |

Every row's right-hand column is where a real defect would hide.

---

## Trigger Conditions

### Symptoms

- A report supplies a manifest, fingerprint, or `N/N` count as evidence.
- A claim reads "all X verified", "closed-world", "exhaustive", or "bit-identical".
- The review mandate says *"do not rely on the report as proof; recompute
  independently"* — recomputation alone under-delivers on that instruction.
- A structural-absence claim ("no such function exists") is offered.

### Context

| Context | Value |
|---------|-------|
| Timing | Exact-tree review / audit, before writing the verdict |
| Prerequisites | Working tree available; VCS status; compiled artifacts |
| Anti-trigger | The claim is about a single named file you read in full |

---

## Root Cause

Re-derivation is *confirmatory*: it takes the report's frame — this list, this
count, this assertion — and tests inside it. A report is itself the product of
the node under review, so its **frame** is exactly as unverified as its numbers,
and frames fail silently. A missing row produces no error; a tautological
assertion produces a green test; an unlisted file produces a matching hash.

The reviewer's independence is therefore not established by recomputing. It is
established by deriving the frame from a source the reported artifact does not
control — version control, the compiler, the working tree.

---

## Solution

For each evidence type, run the *paired* check whose source is outside the report.

### Step 1: Manifests and fingerprints — diff against VCS, not against the manifest

```bash
# correctness (what the report invites)
sha256sum <manifest files> | LC_ALL=C sort -k2 | sha256sum

# completeness (the check that matters) — ground truth is git, not the report
git status --porcelain=v1 -- src test foundry.toml script tools vendor .github docs
```

The second command must return **exactly** the manifest's file set. Scope it to
the App Zone and build config so State-Zone lifecycle files do not mask the
signal. Pair it with `git diff --stat <baseline>` to bound *modified* tracked
files, which untracked-file listings do not show.

### Step 2: Enumerations — account for every entry, not just count them

A "closed-world" claim is only closed if you can bucket **all** of it:

```bash
node -e "const j=require('./out/X.sol/X.json');
  const k=Object.keys(j.methodIdentifiers); console.log(k.length); console.log(k.sort().join('\n'))"
```

Then partition the list — immutables, views, inherited framework surface,
role-gated mutators, deliberately permissionless entries — and require the
buckets to sum to the total. An entry you cannot assign a reason to is the
finding. This also surfaces the *intended-but-unmentioned* surface (inherited
`AccessControl` role management), which a count alone hides.

### Step 3: Counts — re-derive the denominator independently

```bash
grep -c "onlyRole(OPERATOR_ROLE)" src/X.sol     # 13 — matches the report
```

Then confirm the *excluded* items are excluded by design, not by oversight: the
two permissionless mutators must be traceable to accepted design text, or "13/13"
is really "13 of 15".

### Step 4: Bit-identity assertions — prove the perturbation occurred

A comparison that passes because **nothing happened** is the classic vacuous
green. Require the test to assert its own premise:

```solidity
assertEq(weth.balanceOf(VOID), lost, "the capital really left");   // premise
_assertCoreUnchanged(before, label);                                // conclusion
```

Without the first line the second proves nothing.

### Step 5: Properties — read one, and check it computes its expectation independently

A property that re-measures its subject is a tautology. A sound one derives the
expected value in the test and asserts equality, and tests **both** directions of
a bound:

```solidity
vm.expectPartialRevert(...);  treasury.allocateRevenue(asset, credited + 1, ...);  // +1 reverts
treasury.allocateRevenue(asset, credited, ...);                                     // exactly clears
assertEq(treasury.realizedRevenue(asset), 0, "exactly the credit is spendable");
```

### Step 6: Absence claims — demand a positive control

Any "X is not present" check must be shown capable of finding an X that *is*
present, in the same run, by the same method. A search that silently matches
nothing is indistinguishable from a clean result. Prefer a structural source
(the compiler's own `metadata.sources`) over a textual scan, and keep the
control regardless.

### Step 7: Depth claims — verify the depth *and* the breadth

```bash
FOUNDRY_PROFILE=ci forge test 2>&1 | grep -c "runs: 10000"
FOUNDRY_PROFILE=ci forge test 2>&1 | grep "runs: 256" | grep -v "reverts: 0"   # must be empty
```

Counting the suites that actually ran at depth catches a property that quietly
sits outside the profile.

---

## Verification

### Command

```bash
git status --porcelain=v1 -- src test foundry.toml script tools vendor .github docs
```

### Expected Output

Exactly the reported subject's files — no more, no fewer.

```
 M foundry.toml
 M test/mocks/MockWeth.sol
?? src/StrategicTreasury.sol
…
```

### Checklist

- [ ] Manifest completeness derived from VCS, not from the manifest.
- [ ] Modified tracked files bounded by `git diff --stat <baseline>`, not only by
      untracked-file listings.
- [ ] Every enumerated ABI entry assigned to a bucket; buckets sum to the total.
- [ ] Reported counts' *exclusions* traced to accepted design text.
- [ ] At least one bit-identity test read for its premise assertion.
- [ ] At least one property read for independent expectation + both bound directions.
- [ ] Every absence claim carries a positive control, ideally structural.
- [ ] Subject fingerprint recomputed at **exit** and shown equal to entry.

---

## Anti-Patterns

### Don't: treat a matching hash as subject verification

It is integrity evidence about a list. Completeness is a separate claim needing a
separate source. Say which one you established.

### Don't: quote the report's totals back as your own findings

"298/298, 8/8 gates, 44/44 ABI" reproduced verbatim reads like independent
verification and is not. State the *second-direction* result next to each number,
or the reader cannot tell which you did.

### Don't: skip this because the report is unusually thorough

A thorough report raises the cost of the frame being wrong, not the odds. The
source case's report was excellent — it still could not prove its own manifest
was exhaustive, because no artifact can vouch for what it omits.

### Don't: run the completeness check across the whole repo

Unscoped `git status` drowns the signal in State-Zone lifecycle churn (trajectory
logs, notes, ledger locks) and trains you to skim it. Scope to App Zone + build
config, and check State Zone separately when the mandate constrains mutation.

---

## Related

- [[gate-coverage-is-not-the-audit-subject]] — the audit-side sibling: a green
  gate is evidence only about the subjects it *names*. Same principle applied to
  tooling rather than to a report's manifest.
- [[post-run-properties-are-not-invariants]] — non-vacuity for invariant
  campaigns specifically; Step 5 here is its review-side entry point.
- [[reserved-decisions-answer-permissiveness-findings]] — the same posture
  applied to reported judgment calls rather than reported evidence.
