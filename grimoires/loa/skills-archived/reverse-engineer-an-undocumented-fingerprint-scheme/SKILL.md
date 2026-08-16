---
name: reverse-engineer-an-undocumented-fingerprint-scheme
description: |
  A review brief hands you a claimed hash/fingerprint of a file set (a "subject
  manifest") and asks you to independently reproduce it, without documenting the
  concatenation algorithm — only the target digest and the file list. Guessing
  wrong looks identical to guessing right until you check the target: any
  candidate that doesn't match is silently useless. Apply whenever asked to
  mechanically verify a claimed checksum/fingerprint over a known set of inputs
  with an unstated algorithm. Provides a systematic candidate-enumeration
  technique instead of ad hoc guessing, and the specific scheme this session
  reverse-engineered for reuse within the same review-artifact lineage.
loa-agent: reviewing-code
extracted-from: sprint-6 (VUX v1 Truth Surfaces), review subject-fingerprint verification
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - code-review
  - checksums
  - manifest-verification
  - hashing
---

## Problem

A review protocol required "reproduce the exact fingerprint from
`evidence/subject-manifest.md`" for a 45-file (later 51/56/58-file) implementation
subject. The manifest listed the claimed aggregate fingerprint and, per-file, a
truncated sha256 prefix — but nowhere stated HOW the per-file hashes combine into
the aggregate. Concatenation order, separator characters, trailing newlines, and
whether the path or the hash comes first are all invisible in a truncated
16-character preview, and a wrong guess produces a confidently different-looking
64-character hash with no diagnostic information about which part was wrong.

## Trigger Conditions

### Symptoms

- Told to "reproduce," "verify," or "re-derive" a fingerprint/checksum over a
  known file set, with the target value given but the algorithm undocumented
- Only truncated hash previews are shown (e.g., `20289436748666ca…`), so you
  cannot eyeball-compare a candidate against the full target
- The fingerprint recurs across multiple artifacts in the same lineage (an
  implementation report, its review, its remediation) — worth solving once

### Context

| Context | Value |
|---------|-------|
| Technology Stack | any — sha256 over file lists is common, but the technique generalizes to any hash-of-hashes scheme |
| Timing | pre-mutation identity verification in a review/audit workflow |
| Prerequisites | the full (untruncated) target fingerprint and the exact file list are both available |

## Root Cause

A hash-of-hashes has several independent degrees of freedom that are all
plausible defaults and all produce a valid-looking 64-hex-character output:
sort order of entries, per-line format (`hash path`, `path hash`, tab vs. two
spaces), presence/absence of a trailing newline on the final line, and whether
the aggregate hashes the hex-string representation or the raw hash bytes. There
is no way to infer the right combination from the truncated preview alone — it
has to be searched.

## Solution

### Step 1: Compute every per-file hash directly and confirm those match the manifest's truncated previews

This is unambiguous — sha256 of file bytes — and rules out the (unlikely but
possible) case that the individual hashes themselves use a different digest.

```js
const h = createHash('sha256').update(readFileSync(f)).digest('hex');
```

### Step 2: Enumerate candidate aggregate schemes systematically, not ad hoc

Vary each degree of freedom independently and generate all combinations worth
trying — do not stop at the first "reasonable-looking" guess:

```js
const cands = {};
cands['h+2sp+p+nl']        = sha(recs.map(r => `${r.h}  ${r.f}\n`).join(''));
cands['h+2sp+p+nl_noTrail'] = sha(recs.map(r => `${r.h}  ${r.f}`).join('\n'));
cands['p+2sp+h+nl']        = sha(recs.map(r => `${r.f}  ${r.h}\n`).join(''));
cands['h_only_cat']        = sha(recs.map(r => r.h).join(''));
cands['h_only_nl']         = sha(recs.map(r => r.h + '\n').join(''));
cands['bin_concat_hashbytes'] = createHash('sha256')
  .update(Buffer.concat(recs.map(r => Buffer.from(r.h, 'hex')))).digest('hex');
// ... json, tab-separated, hash-then-newline-no-trailing, etc.
```

### Step 3: Test against the SMALLEST available known-answer sample first

A 2-file group (if the manifest has one) narrows the search fast before applying
it to the full 45+ file set — fewer degrees of freedom to accidentally get right
by coincidence, and faster to iterate.

### Step 4: Match, then verify the SAME scheme reproduces every subsequent group

Once one candidate matches, confirm it also reproduces the manifest's other
listed groups (in this session: three separate fingerprinted groups in one
manifest). Agreement across independent groups rules out a coincidental match on
the first sample.

### Step 5: Record the discovered scheme for reuse across the review lineage

The scheme, once found, is stable across an entire review chain (initial review,
each remediation pass, each re-review) — reapply it directly rather than
re-deriving.

```
sha256( join("\n", sorted "<sha256-hex>  <relative-path>") )   — two spaces, no trailing newline
```

## Verification

### Command

```bash
node verify.mjs <claimed-fingerprint> <sorted file list>
```

### Expected Output

```
computed: 20289436748666cab658c9a4e6777476e2f9aa854ec217dff39cca6b05029e4b
claimed : 20289436748666cab658c9a4e6777476e2f9aa854ec217dff39cca6b05029e4b
*** FINGERPRINT MATCH ***
```

### Checklist

- [ ] Per-file hashes independently computed and checked against any truncated previews given
- [ ] Multiple aggregate-scheme candidates enumerated systematically (separator, order, field order, trailing newline)
- [ ] Tested against the smallest available known-answer group before the full set
- [ ] Matching scheme re-validated against every other independently fingerprinted group in the same document
- [ ] Scheme recorded/reused for subsequent artifacts in the same review lineage rather than re-derived each time

## Anti-Patterns

### Don't: guess once and move on if it "looks like" a hash

Any wrong candidate produces a full-length, plausible-looking hex string with no
partial-credit signal — there is no such thing as "close" for a hash mismatch.

### Don't: assume the scheme without testing multiple independent groups

A scheme that matches one 2-file group by coincidence (small search space) needs
confirmation against a larger, independently fingerprinted group before trusting
it for the file set that actually matters.

## Related Memory

### Related Skills

- `a-passing-regression-test-proves-nothing-alone` — same session, same
  discipline of not trusting a plausible-looking result without an independent
  confirming check

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-14 | Initial extraction |

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
  session: sprint-6 initial review, subject identity verification
```
