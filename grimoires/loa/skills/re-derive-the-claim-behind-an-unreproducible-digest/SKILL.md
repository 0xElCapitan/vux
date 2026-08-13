---
name: re-derive-the-claim-behind-an-unreproducible-digest
description: |
  When a published constant in an authority document, attestation, or audit
  report fails to reproduce, the instinct is to escalate — an unverifiable
  number in binding authority looks like a critical integrity failure. Usually
  it is not. "The number does not reproduce" and "the claim is false" are
  different statements, and only the second is a blocking finding. Separate them
  by re-deriving the underlying claim through independent construction, then
  grade the unreproducible value on whether any conclusion actually rests on it.
  Requires a positive control: if OTHER published values in the same document DO
  reproduce under your search, the search apparatus is proven discriminating and
  the non-reproduction is real rather than a bug in your own tooling. Apply when
  reviewing any document publishing digests, hashes, checksums, or reproducible-
  build constants.
loa-agent: reviewing-code
extracted-from: cycle-002 Foundry v1.5.0 toolchain refreeze focused review (2026-08-12)
extraction-date: 2026-08-12
version: 1.0.0
tags:
  - code-review
  - verification
  - severity-calibration
  - reproducibility
  - attestation
  - supply-chain
  - audit-evidence
  - positive-control
---

## Problem

A binding authority document — SHA-256-pinned into the gate set, superseding
prior accepted authority — publishes a table of artifact digests as evidence for
a parity claim. You try to reproduce them and cannot.

This looks severe. The document is authority; a reader cannot check it; a future
node comparing against these constants will get a mismatch and be unable to tell
whether the subject drifted, the file set changed, or the method differed. The
pull toward CRITICAL or HIGH is strong.

But escalating there without one more step produces a **wrong finding**, in
either direction:

- **Over-grade**: block a correct migration because a redundant illustrative
  column used an unstated convention, while the conclusion it illustrated is
  independently verifiable and correct.
- **Under-grade**: wave it through as "cosmetic" when the unreproducible value
  is in fact the *only* evidence for a load-bearing claim.

Which error you are about to make is not visible from the non-reproduction
itself. It depends entirely on whether anything downstream rests on that number —
and that is a separate question requiring separate work.

---

## Trigger Conditions

### Symptoms

- A report, authority document, or attestation publishes hashes/digests/checksums
- Your recomputation disagrees with the published value
- The document is accepted, pinned, or otherwise binding
- The published value supports a claim you can, in principle, test another way

### Error Messages

There are none. This failure is silent — two 64-hex strings that differ. That is
precisely why it is dangerous: nothing tells you whether you are looking at
drift, a convention mismatch, or a real integrity failure.

---

## Root Cause

A digest published as *evidence* and a digest published as *illustration* look
identical on the page. Both are 64 hex characters in a table cell. The difference
is structural, not textual:

| role | what depends on it | non-reproduction means |
|---|---|---|
| **load-bearing** | the conclusion is only true if this value is | evidence failure — escalate |
| **illustrative** | the conclusion is provable without it | documentation defect — grade low |

Documents rarely label which is which. A parity section may publish *both*: a
whole-artifact column (illustrative — it shows the artifacts differ) and a
metadata-stripped column (load-bearing — it proves the executable code does
not). If only the illustrative column fails to reproduce, the conclusion stands
untouched.

Compounding this, published digests routinely use unstated conventions — raw
bytes vs. hex string, `0x`-prefixed or not, SHA-256 vs. Keccak-256, with or
without a trailing newline. Non-reproduction is therefore the *expected* outcome
of a naive check, not evidence of anything.

---

## Solution

### 1. Exhaust the convention space before concluding anything

Do not conclude "unreproducible" from one attempt. Search the cross-product:

```python
for algo in [sha256, keccak256]:
    for encoding in [raw_bytes, hex_lower, "0x"+hex_lower, hex_lower+"\n"]:
        for target in [bytecode_object, whole_artifact_file]:
            for source in [in_repo_out, clean_scratch_build]:
                ...
```

Include every toolchain version in play if the artifact is toolchain-dependent.

### 2. Demand a positive control — this is the step that makes the result trustworthy

If the same search reproduces **other** published values from the same document,
the apparatus is proven to work and the non-reproduction is a fact about the
document, not about your script.

In the source case the search recovered all four metadata-stripped constants
exactly:

```
VUX.creation         3f8ffe9ebacd3b59…  ✓ reproduced  (convention: strip n+2, sha256 over lowercase hex)
VUX.deployed         7377122c247ecc7d…  ✓ reproduced
HardReserve.creation 2184162f1cdecde8…  ✓ reproduced
HardReserve.deployed 065241a187cc91b5…  ✓ reproduced
```

while the nine whole-artifact digests in the adjacent section reproduced under
**no** combination. Same script, same run, same document. That asymmetry is the
finding — and without the positive control it would have been indistinguishable
from a broken hash pipeline.

Corroborate with any non-hash values the document states. Published *lengths*
(`22,666 / 15,872 / 9,366 / 6,398` hex chars) matched the extraction exactly,
independently confirming the artifacts under comparison were the right ones.

### 3. Re-derive the CLAIM by independent construction

Ignore the published numbers entirely and test the assertion directly. If the
claim is "these two builds emit identical executable code", build both and
compare:

```bash
forge build --force --out "$SCRATCH/out-new"
~/.foundry/versions/v1.0.0/forge.exe build --force --out "$SCRATCH/out-old"
# strip trailing CBOR (n+2 from the two-byte big-endian suffix), hash, compare
```

Now you know whether the claim is true regardless of whether its published
digests reproduce.

### 4. Grade on dependency, not on non-reproduction

| finding | grade |
|---|---|
| claim false | CRITICAL / HIGH — evidence failure |
| claim true, unreproducible value is the sole evidence | MEDIUM–HIGH — verifiability failure |
| claim true and independently re-derived, value is redundant | **MEDIUM** — documentation defect in binding authority |
| claim true, value redundant, document not binding | LOW |

Also check the **machine-readable** companion separately. In the source case the
JSON carried only the reproducible values, so the artifact that gates and tooling
actually parse was clean — which pulled the grade down and is worth stating
explicitly in the finding.

### 5. Recommend the cheap fix, and say when it is cheapest

Restate the column under the convention that does reproduce, or drop it and cite
the section that does. Note the timing: while the document is uncommitted this is
one coordinated edit (value + its registered SHA-256 pin). After it lands, the
same correction becomes an authority-supersession event.

---

## Verification

You have done this correctly when you can state all four:

1. the conventions searched, and that the search found *some* published values
   (positive control)
2. the claim, re-derived by construction without reference to the published values
3. exactly which published values do not reproduce, with your computed replacements
4. what breaks if the value stays wrong — and if the honest answer is "a future
   reviewer's time", say that rather than inflating it

---

## Anti-Patterns

**Escalating on non-reproduction alone.** The most likely cause is an unstated
encoding convention, not corruption. One failed attempt is not a finding.

**Concluding "unverifiable" and stopping.** The claim is usually testable by
construction even when its published evidence is not. Do that work — it is what
separates a MEDIUM from a HIGH.

**Omitting the positive control.** Without proving your search reproduces
*something* from the same document, "it does not reproduce" is a statement about
your script. Same failure shape as
`skills-pending/validate-the-ad-hoc-oracle-both-ways`.

**Grading every published number alike.** Load-bearing and illustrative digests
sit in adjacent table cells and look identical. Ask what breaks if each is wrong.

**Ignoring the machine-readable companion.** MD prose and JSON companion can
disagree; the JSON is what tooling parses, and its state changes the severity.

---

## Related Memory

- `skills-pending/independent-constant-reproduction` — the complement: when a
  constant *is* claimed reproduced, break the circularity with an outside
  implementation. This skill covers the opposite case, where reproduction fails.
- `skills-pending/recover-digest-convention-from-published-components` — how to
  recover an unstated convention from a predecessor's own published components;
  step 1 here is that technique used as a diagnostic rather than a producer.
- `skills-pending/validate-the-ad-hoc-oracle-both-ways` — the reviewer's own
  throwaway tooling fails in both directions; the positive-control rule.
- `skills-pending/escalate-against-the-accepted-invariant` — when a documentation
  defect in accepted authority *does* justify blocking.
- NOTES.md `## Learnings` — cycle-002 Foundry v1.5.0 refreeze review, finding T-1.
