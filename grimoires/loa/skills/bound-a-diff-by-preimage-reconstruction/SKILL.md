---
name: bound-a-diff-by-preimage-reconstruction
description: |
  When a node reports "I changed exactly these four files, and in each only
  this", and the baseline it changed FROM is not a commit — an uncommitted
  working tree, a prior audit subject, a vendored drop — `git diff` cannot check
  the claim. It shows the union of every node that touched those files, so a
  file the remediation never opened appears "modified" and an extra edit hides
  inside a legitimate-looking hunk. The predecessor artifact almost always
  published per-file hashes; that table is the missing baseline. Reconstruct the
  pre-image by reverting ONLY the claimed edits from the current file and hash
  the result: if it equals the recorded value, the claim is proven byte-exactly
  and nothing else changed. Apply in exact-tree review/re-audit, remediation
  verification, supply-chain drift checks, or any bounded-scope claim over an
  uncommitted subject. A reconstruction that FAILS is also a result — it bounds
  the report's precision, not the code's correctness, and should be graded as
  such.
loa-agent: reviewing-code
extracted-from: cycle-002 / sprint-2 / /review-sprint sprint-2 (A-1 re-review)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - review-technique
  - exact-tree
  - provenance
  - remediation-verification
  - hashing
  - git
---

## Problem

A bounded remediation node reports:

> Exactly 4 of the 18 audit-subject files changed. `.github/workflows/provenance.yml`
> changed only because probe 12 needs a compiler: the pinned toolchain step was
> added and the comment corrected. **No other job, permission, trigger or pin was
> touched.**

The reviewer must verify "no other … was touched". The obvious move is
`git diff .github/workflows/provenance.yml` — and it is misleading, because the
entire sprint is uncommitted. The diff is against `HEAD`, which predates the
sprint, so it shows **sprint-baseline changes and remediation changes fused
together**. In the observed instance it surfaced a hunk the report never
mentioned:

```
+  # [profile.ci] differs from the default only in fuzz depth ...
+  FOUNDRY_PROFILE: ci
```

A workflow-scope environment variable affecting all three jobs, absent from a
report that claimed nothing else was touched. Either the report understated its
diff — a real finding — or the entry predates the remediation and `git diff` is
simply the wrong instrument. **Nothing in git can tell you which.**

The mirror failure occurs in the other direction: `tools/provenance/run-all.sh`
showed as modified in `git diff`, which reads as a fifth changed file
contradicting the "exactly 4" claim. Its hash was byte-identical to the audit
entry. Both readings are wrong for the same reason.

---

## Trigger Conditions

### Symptoms

- The subject under review is uncommitted (`git status` shows the whole sprint as
  ` M` / `??`), so `HEAD` is not the baseline the claim is measured from.
- `git diff` shows more files, or more hunks, than a bounded-scope report claims.
- A report describes its own diff in prose ("only the comment was corrected")
  and there is no way to check the prose against bytes.
- A predecessor artifact (audit report, attestation, manifest) publishes a
  per-file hash table for the baseline state.
- You are about to write "the report appears to understate its changes" as a
  finding.

### Error Messages

None. The failure is a confident wrong conclusion in either direction — a false
finding against an accurate report, or an accepted claim that hid an edit.

### Context

| Context | Value |
|---------|-------|
| Timing | Re-review / re-audit of a remediation, before grading its scope claims |
| Prerequisites | Predecessor artifact publishes per-file hashes; current files readable |
| Fails when | No per-file baseline was published — then only the *functional* delta (below) is available |

---

## Root Cause

`git diff` answers "how does the working tree differ from a **commit**". A
bounded node's claim is "how does the working tree differ from the **subject the
previous gate accepted**". When the subject was never committed, those are
different baselines, and the second one exists only as the hash table the
previous gate published. Reaching for git here is a category error, not a
mistake of care.

---

## Solution

### Step 1: Get the per-file baseline from the predecessor artifact

Do not use its aggregate digest alone — you need the per-file rows.

```
| `85e2123216dc3993ffcad06a8ff1a8db654dbcf6cd46d2de528beb2a38c0a136` | `.github/workflows/provenance.yml` |
| `b4a373abd3e18afc05b65c416448ed4db5fd4747f65074d6c0c2252629a90045` | `tools/provenance/run-all.sh` |
```

Hash the current files against this table first. That alone settles *which*
files changed — and immediately dissolves the `run-all.sh` false alarm, without
reading a single diff hunk.

### Step 2: Reconstruct the pre-image by reverting ONLY the claimed edits

Work from the **current** file, applying the report's claimed changes in reverse.
Use line-index surgery with assertions rather than text substitution — em-dashes,
section signs and shell metacharacters in comments make literal replacement
fragile across encodings.

```python
L = open('tools/provenance/verify-census.sh', 'rb').read().decode('utf-8').split('\n')

# claimed edit 1: a header comment line was extended
i = next(k for k,l in enumerate(L) if 'not a scanned directory list,' in l)
assert 'independent of extension case' in L[i+1]      # the claim, asserted
L[i] = L[i].replace('directory list,', 'directory list;')
del L[i+1]

# claimed edit 2: 4 comment lines added and grep -E -> grep -iE
j = next(k for k,l in enumerate(L) if l.startswith('# Matched case-insensitively'))
assert 'grep -iE' in L[j+4]
L[j+4] = L[j+4].replace('grep -iE', 'grep -E')
del L[j:j+4]

print(hashlib.sha256('\n'.join(L).encode('utf-8')).hexdigest())
```

Every `assert` is a claim from the report converted into a check. A failing
assert means the report's description does not match the file, before you even
reach the hash.

### Step 3: Compare to the recorded baseline hash

```
reconstructed pre-image sha256: 39d721f95ed4a892d60f30290c4ee399381171e5a3cc57cedacad0d17c3b88a0
MATCH audit-entry 39d721f9...: True
```

An exact match is a **complete** proof of the bounded claim: the current file
minus exactly the claimed edits *is* the accepted baseline, so no unclaimed edit
exists. This is stronger than any diff review, because it needs no judgment about
whether a hunk is "related".

Applied to the observed instance, this settled the `FOUNDRY_PROFILE: ci`
question definitively: the reconstructed pre-image **retains** that line and
still hashes to `85e2123216dc3993…`, proving the entry predates the remediation
and the report was accurate. The candidate finding was withdrawn before it was
written.

### Step 4: When reconstruction fails, fall back to the FUNCTIONAL delta

One of three files did not reconstruct: the report described its comment changes
by line range (`census.sh:184-200`) rather than by content, so the pre-image is
underdetermined. This bounds the *report*, not the code. Answer the behavioural
question directly instead — strip comments and blanks from both versions and
diff:

```bash
git show HEAD:tools/provenance/census.sh | grep -vE '^\s*#|^\s*$' > /tmp/head.txt
grep -vE '^\s*#|^\s*$'   tools/provenance/census.sh              > /tmp/cur.txt
diff -u /tmp/head.txt /tmp/cur.txt
```

The executable delta across *both* the sprint and the remediation was three
hunks, of which the remediation's entire contribution was one token
(`-name` → `-iname`). That is a complete answer to "did anything else change
behaviourally", obtained without the pre-image.

Grade the reconstruction failure honestly — **informational**, affecting
auditability of the narrative, not of the behaviour. The remedy for the next node
is one line: record the pre-image hash **and** the exact diff text, not a line
range.

---

## Verification

### Command

```bash
python reconstruct-preimage.py && echo "claim proven byte-exactly"
```

### Expected Output

```
reconstructed pre-image sha256: 85e2123216dc3993ffcad06a8ff1a8db654dbcf6cd46d2de528beb2a38c0a136
audit-entry expected:           85e2123216dc3993ffcad06a8ff1a8db654dbcf6cd46d2de528beb2a38c0a136
FOUNDRY_PROFILE still present in pre-image: True
```

### Checklist

- [ ] Current files hashed against the predecessor's per-file table **before** reading any diff
- [ ] Files that hash equal are declared unchanged regardless of what `git diff` shows
- [ ] Each claimed edit reverted under an `assert` derived from the report's own words
- [ ] Reconstruction hashed and compared to the recorded baseline
- [ ] Any candidate "the report understates its diff" finding re-tested this way before being written
- [ ] Failed reconstructions answered with the comment-stripped functional delta and graded informational

---

## Anti-Patterns

### Don't: read `git diff` as the remediation's diff when the subject is uncommitted

It is the union of every node that touched the file. In the observed instance it
simultaneously suggested a fifth changed file (false) and an unreported hunk
(false). Both dissolve under hashing.

### Don't: reconstruct by text substitution on comment prose

Comments in this class of file carry em-dashes, `§`, backticks and shell
metacharacters; a literal `str.replace` silently no-ops across an encoding
boundary and you conclude "no change" from a replacement that never happened.
Use line indices with assertions — and note this is the same
prove-the-edit-landed discipline as [[verify-the-mutant-not-the-verdict]].

### Don't: mutate the working tree to reconstruct

Build the candidate in memory or in a scratchpad and hash it there. The subject
must remain byte-identical through the review; reconstruction is an
arithmetic exercise, not an edit.

### Don't: treat a failed reconstruction as a defect in the code

It bounds the report's precision. Say exactly that, grade it informational, and
answer the behavioural question by another route rather than blocking.

### Don't: skip the per-file table because the aggregate digest matched

The aggregate proves the set is what you think it is. Only the per-file rows tell
you *which* members moved — which is the whole question a bounded-scope claim
raises.

---

## Related Resources

- `grimoires/loa/a2a/sprint-2/auditor-sprint-feedback.md:74-93` — the per-file baseline table this technique consumes
- `grimoires/loa/a2a/sprint-2/engineer-feedback.md` §2.1, §2.2, I-1 — the review that produced this

---

## Related Memory

### NOTES.md References

- `## Learnings` — "[Review technique — bound a diff by pre-image reconstruction]"
- `## Learnings` — "[Attribution on uncommitted trees]" (the mtime-based predecessor this supersedes for content questions)

### Related Skills

- [[recover-digest-convention-from-published-components]] — the prerequisite when
  the baseline table's *aggregation* is what you need; this skill consumes the
  same table's rows rather than its total.
- [[audit-subject-fingerprint-under-agent-telemetry]] — defines the subject set
  whose per-file hashes this technique reverts into.
- [[verify-the-mutant-not-the-verdict]] — same discipline (assert the edit landed
  before trusting a result), applied to mutation rather than reconstruction.

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-08-11 | Extracted from `/review-sprint sprint-2` A-1 re-review |
