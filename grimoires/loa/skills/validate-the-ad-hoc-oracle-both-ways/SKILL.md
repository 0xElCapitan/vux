---
name: validate-the-ad-hoc-oracle-both-ways
description: |
  An auditor's throwaway shell/jq cross-check is unreviewed, untested code whose
  output goes straight into a verdict — and it fails in two opposite directions
  that both look like clean results. A wrong `jq` path or an empty glob yields
  an EMPTY set, and "no violations found" is indistinguishable from "nothing was
  examined" (vacuous pass). A CRLF, a locale mismatch, or an unsorted input to
  `comm`/`join` yields a FULL set, and "everything is unclassified" looks like a
  catastrophic finding (false positive). Both were hit in consecutive runs of one
  cross-check. Apply whenever building an ad-hoc comparison to test a claim
  during audit or review — set-difference over file lists, artifact metadata vs
  a manifest, ABI vs source, hash inventories — especially on Windows/MSYS. The
  rule: assert the inputs are NON-EMPTY and assert a known-good element MATCHES
  before reading the verdict; a result of "all" or "none" is a signal to debug
  the oracle, not a finding to report.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-2 exact-tree re-audit (compiler-metadata cross-check for M-1)
extraction-date: 2026-08-12
version: 1.0.0
tags:
  - security-audit
  - tooling
  - false-positives
  - windows-msys
  - evidence-integrity
---

## Problem

Mid-audit you need an answer the project's own gates do not provide, so you
write a five-line pipeline: extract a set, extract another set, diff them. That
pipeline is production code for the duration of the verdict, and nobody reviews
it.

It fails in two directions, and neither announces itself:

| Failure | Looks like | Reported as |
|---|---|---|
| One side extracts **nothing** (wrong `jq` path, empty glob, tool version drift) | `comm` emits no differences | "clean — no violations" ✗ vacuous |
| Sides are **incomparable** (CRLF, unsorted, locale, path separators) | every element differs | "catastrophic — nothing is classified" ✗ false positive |

Observed live, in consecutive runs of the same cross-check:

```
$ jq -r '(.input.sources // {}) | keys[]' build-info/*.json | sort -u > compiled.txt
compiled source count: 0
=== any compiled path NOT ending in .sol? ===
  (none — every compiled source is Solidity-named)      <-- VACUOUS. Nothing was read.
```

The `.input.sources` key did not exist in this Foundry version (`source_id_to_path`
did). The reassuring line was produced by an empty file.

Then, after fixing the extraction:

```
$ comm -23 compiled.txt universe.txt
  UNCLASSIFIED: src/VUX.sol
  UNCLASSIFIED: src/HardReserve.sol
  ... all 47 ...
```

`jq` on Windows emitted CRLF; `src/VUX.sol\r` never equals `src/VUX.sol`. Had
this appeared first, it reads as a total provenance failure.

---

## Trigger Conditions

### Symptoms

- You are writing a set comparison to substantiate or refute an audit claim.
- The result is **all** elements or **zero** elements — suspiciously total either way.
- Inputs come from `jq`, `find`, `git`, or a build tool's JSON, especially on
  Windows/MSYS/Git-Bash.
- `comm`, `join`, or `diff` is involved (all require identically-sorted inputs).
- A tool's JSON schema is version-dependent and you did not pin or inspect it.

### Error Messages

Often none. The tells are non-fatal warnings that are easy to scroll past:

```
tr: warning: an unescaped backslash at end of string is not portable
sed: -e expression #1, char 7: unterminated `s' command
```

### Context

| Context | Value |
|---------|-------|
| Phase | `/audit-sprint`, `/review-sprint` — any evidence-gathering step |
| Environment | Windows/MSYS especially; any cross-platform shell pipeline |
| Timing | Before the result enters the verdict |

---

## Root Cause

Two independent causes with the same signature:

1. **Empty-set semantics.** Unix set operations are total: `comm -23 ∅ X` is `∅`,
   and every "no violations" formulation is a statement about an empty set that
   is trivially true. Absence of output cannot distinguish "looked and found
   nothing" from "did not look".
2. **Silent incomparability.** `comm`/`join` assume identically-ordered inputs
   and compare bytes. A trailing `\r`, a `LC_ALL` difference, `./` prefixes, or
   `\` vs `/` makes every element unequal. These tools do not warn — mismatched
   sort order is not an error, it is a different answer.

Both are amplified by tool-version drift: build-tool JSON schemas change between
releases, so a key that worked in one version silently yields nothing in another.

---

## Solution

### Step 1: Assert both inputs are non-empty, before comparing

The single highest-value line. It converts a vacuous pass into a loud failure.

```bash
[[ -s compiled.txt && -s universe.txt ]] || { echo "ORACLE BROKEN: empty input"; exit 2; }
echo "sizes: compiled=$(wc -l < compiled.txt)  universe=$(wc -l < universe.txt)"
```

Always print the counts. A count is the cheapest possible sanity check and it
belongs in the audit artifact as evidence the oracle ran.

### Step 2: Normalize aggressively, then prove normalization happened

```bash
tr -d '\r' < raw.txt | sed 's|\\|/|g; s|^\./||' | LC_ALL=C sort -u > clean.txt
```

Verify rather than trust — inspect the bytes, not the rendering:

```bash
head -3 clean.txt | od -c | head -5     # no \r before \n
```

This is what exposed the CRLF: the two files rendered identically on screen.

### Step 3: Positive control — assert a known-good element matches

Pick an element you *know* is in both sets and assert it survives the join.
This catches incomparability directly, without depending on the final answer.

```bash
grep -qxF 'src/VUX.sol' clean.txt && grep -qxF 'src/VUX.sol' universe.txt \
  && comm -12 clean.txt universe.txt | grep -qxF 'src/VUX.sol' \
  || { echo "ORACLE BROKEN: known-good element does not join"; exit 2; }
```

### Step 4: Read "all" or "none" as a bug report, not a result

Adopt the reflex: a total result is a hypothesis about your pipeline first, and
a finding second. Confirm by an independent route before it enters the verdict —
here, the compiled-source set was re-derived from artifact `metadata.sources`
*and* from `build-info`, and the two agreed at 47 before either was trusted.

### Step 5: Prefer the schema-stable extraction path

Where a tool exposes the same fact twice, take the more stable surface and
cross-check with the other. `metadata.sources` has been stable across Foundry
versions; `build-info`'s top-level shape has not (`source_id_to_path` vs
`input.sources`). Pin the observation in the artifact:

```bash
jq -r 'keys' out/build-info/*.json | head    # inspect BEFORE relying on a key
```

---

## Verification

### Checklist

- [ ] Both input sets asserted non-empty, with counts printed
- [ ] Line endings/path separators normalized, verified by `od -c`
- [ ] A known-good element proven to join across both sets
- [ ] A total ("all"/"none") result was re-derived independently before reporting
- [ ] The extraction key was inspected against the actual JSON, not assumed
- [ ] Any non-fatal `tr`/`sed`/`jq` warning was read, not scrolled past

### Expected Output

```
sizes: compiled=47  universe=77
positive control: src/VUX.sol joins OK
compiled sources NOT in universe:  (empty)
breakdown: 33 vendored, 14 vux, 0 unauthorized
```

The breakdown line matters: it proves the comparison classified real elements
rather than comparing nothing.

---

## Anti-Patterns

**Reporting the first total result.** "All 47 unclassified" and "0 violations"
are both far more likely to be pipeline bugs than genuine findings.

**Trusting screen rendering over bytes.** CRLF, NBSP, and BOM are invisible in
terminal output and fatal to string equality. `od -c` costs one command.

**Assuming a JSON key exists because it did last version.** `jq` returns empty
for a missing path and exits 0. Silence is not confirmation.

**Using `comm`/`join` without asserting sort compatibility.** They compare
adjacent lines under an assumed order; a violated assumption is a wrong answer,
not an error.

**Writing the oracle only in the direction of the expected answer.** If you only
ever test the case you expect to pass, you have built a control that cannot fail —
the same defect as an unfalsified negative control (see
[[verify-the-mutant-not-the-verdict]]).

---

## Related Memory

- NOTES.md `## Learnings` — the CRLF false positive and the vacuous-pass near-miss
- [[verify-the-mutant-not-the-verdict]] — same shape, applied to mutation tests
- [[prove-which-fence-caught-it]] — the green-gate screen for reason matchers
- [[escalate-against-the-accepted-invariant]] — the consumer of this measurement
- [[init-code-only-capability-proof]] — positive-control discipline for absence claims
