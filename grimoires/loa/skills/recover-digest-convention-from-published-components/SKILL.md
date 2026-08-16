---
name: recover-digest-convention-from-published-components
description: |
  When a prior accepted artifact (audit report, release manifest, attestation)
  publishes an aggregate digest over a file set AND the per-file hashes behind it,
  and your node must change some of those files and publish a comparable digest —
  do not re-implement the aggregation from its prose description. Phrases like
  "SHA-256 over the sorted `sha256  path` manifest" underdetermine at least six
  encoding choices (separator width, `sha256sum`'s platform-dependent `*` binary
  marker, sort key, sort locale, line endings, trailing newline), each of which
  changes the digest completely. Instead, rebuild the manifest from the
  predecessor's OWN published per-file values and hash candidate encodings until
  one reproduces the published aggregate exactly; then compute the new digest with
  the recovered rule. Apply in any exact-tree / no-mutation node, re-audit,
  supply-chain attestation, or reproducible-build handoff where two digests must
  be comparable across nodes.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-2 /implement (A-1 remediation, audit-subject re-fingerprinting)
extraction-date: 2026-08-11
version: 1.1.0
tags:
  - integrity
  - fingerprinting
  - reproducibility
  - supply-chain
  - audit-handoff
  - shell
  - cross-platform
---

## Problem

An audit approves a tree and publishes an **audit-subject digest** — one hash
standing for "exactly this set of files at exactly these bytes". Your node changes
some of those files and must publish the successor digest so the next reviewer can
see precisely what moved.

If you compute the successor with a *different* encoding than the predecessor
used, the two numbers are unrelated noise. Worse, the failure is undetectable
downstream: the next auditor sees two 64-hex strings that do not match and cannot
tell whether the subject changed, the file set changed, or the method changed —
and re-deriving your intent requires guessing the same six choices you guessed.

The prose is never sufficient. "SHA-256 over the sorted `sha256  path` manifest"
leaves open:

| Choice | Plausible values |
|---|---|
| Separator | one space, two spaces, tab |
| Binary marker | `hash  path` vs `hash *path` — **platform-dependent** |
| Sort key | by path, or by hash (they differ) |
| Sort locale | `LC_ALL=C` vs locale-aware (differs on case and punctuation) |
| Line endings | LF vs CRLF |
| Trailing newline | present vs absent |

Two of these bit this session directly. `sha256sum` on the msys/Windows build
emits a `*` binary marker — `5686c4c7…  *src/VUX.sol` — so even "just use
`sha256sum`" does not pin the format. And the trailing-newline choice alone moved
the aggregate from `78c8881204…2ac45a` to `9e468deda1…f32c2de`: totally different,
with no signal that anything was wrong.

---

## Trigger Conditions

### Symptoms

- A prior artifact states an aggregate digest plus a per-file table, and your node
  must publish a successor digest over the same subject definition.
- The aggregation method is described in prose rather than as a runnable command.
- Your freshly computed digest does not match the predecessor's on the *unchanged*
  subject — before you have modified anything.
- `sha256sum` output contains `*` before paths on one machine and not another.

### Error Messages

None. A wrong encoding produces a well-formed, confident, wrong hash.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Any hashing/manifest toolchain; shown with `sha256sum` + `sort` |
| Environment | Especially cross-platform (Windows/msys ↔ Linux CI) |
| Timing | Before mutating any file the predecessor digest covers |
| Prerequisites | The predecessor must publish its per-item components, not only the aggregate |

---

## Root Cause

An aggregate digest is a hash of a *serialisation*, but it is habitually described
as a hash of a *set*. The serialisation carries the entropy: identical file
contents plus a different separator yields a completely different digest. Prose
descriptions describe the set and omit the serialisation, so every reimplementation
silently picks its own.

The recovery works because a well-formed predecessor artifact publishes both the
aggregate and its components — which makes the aggregation function **testable**
rather than assumed. The published table is, in effect, a test vector left behind
by the previous node.

---

## Solution

### Step 1: Do this BEFORE mutating anything

The predecessor's digest is only reproducible while the subject still matches it.
Recover the convention first; a mutation destroys your test vector.

### Step 2: Rebuild the manifest from the predecessor's OWN published values

Transcribe the published per-file table verbatim. Do **not** re-hash the files at
this stage — using the published values isolates the *encoding* question from the
*content* question, so a mismatch can only mean the encoding is wrong.

```bash
cat > /tmp/subject-manifest.txt <<'EOF'
85e2123216dc3993ffcad06a8ff1a8db654dbcf6cd46d2de528beb2a38c0a136  .github/workflows/provenance.yml
47b290cdc75e512796538bc20a1de71cc8a12c0e7bede7c0ac7506651377703e  foundry.toml
...
EOF
```

### Step 3: Hash candidate encodings until one reproduces the published aggregate

```bash
echo "LF, trailing NL : $(sha256sum < /tmp/subject-manifest.txt | cut -d' ' -f1)"
printf '%s' "$(cat /tmp/subject-manifest.txt)" | sha256sum | cut -d' ' -f1 \
  | sed 's/^/LF, no trail NL: /'
echo "TARGET          : 78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a"
```

```
LF, trailing NL : 78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a   <- match
LF, no trail NL : 9e468deda163dad0142149d0d802315bc190e251c74430579868a4551f32c2de
TARGET          : 78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a
```

The convention is now **recovered, not assumed**: `<sha256>` + two spaces +
`<path>`, `LC_ALL=C` sorted by path, LF, trailing newline. Record it in the report
— the next node should not have to repeat this.

### Step 3b: If the artifact publishes more than one independently fingerprinted group, use the smallest as the search and every other as cross-validation

A manifest that partitions its subject into several separately fingerprinted
groups (e.g. an implementation group and a much smaller authority/metadata
group) hands you a cheaper search and a free confirmation for the price of one
extra digest:

```bash
# solve the encoding against the SMALLEST group first — fewer entries means a
# wrong candidate is both faster to compute and less likely to coincidentally
# match by chance
echo "Group B candidate: $(sha256sum < /tmp/group-b-manifest.txt | cut -d' ' -f1)"
echo "Group B target   : 1e6515cc1c79f553c68d8172e16c78c183133ad0bc6057bf07cfb400ea267a2c"
```

Once a candidate matches the smallest group, re-apply the *same* rule to every
other published group before trusting it for the group that actually matters:

```bash
echo "Group A candidate: $(sha256sum < /tmp/group-a-manifest.txt | cut -d' ' -f1)"
echo "Group A target   : 20289436748666cab658c9a4e6777476e2f9aa854ec217dff39cca6b05029e4b"
```

Agreement across two independently fingerprinted groups rules out a
coincidental match on the first (small search spaces make coincidence
plausible) and confirms the recovered convention generalises rather than
having been curve-fit to one sample.

### Step 4: Reconstruct the subject set independently, then apply the recovered rule

Rebuild the file list from the stated subject *definition* rather than copying the
predecessor's path list — that independently re-verifies the set, and catches a
file added or removed since. Normalise `sha256sum`'s output rather than trusting
it (the `*` marker).

```bash
{ git status --porcelain --untracked-files=all | sed 's/^...//' ; } \
  | grep -vE '^(grimoires/|\.beads/|\.run/)' | LC_ALL=C sort -u > /tmp/subject-paths.txt

: > /tmp/subject-new.txt
while IFS= read -r p; do
  [[ -f "$p" ]] || continue
  printf '%s  %s\n' "$(sha256sum "$p" | cut -d' ' -f1)" "$p" >> /tmp/subject-new.txt
done < /tmp/subject-paths.txt
LC_ALL=C sort -k2 -o /tmp/subject-new.txt /tmp/subject-new.txt

echo "files:  $(wc -l < /tmp/subject-new.txt)"
echo "digest: $(sha256sum < /tmp/subject-new.txt | cut -d' ' -f1)"
```

`cut -d' ' -f1` then `printf '%s  %s\n'` reassembles the line in the recovered
encoding and discards the platform's `*` marker in the same move.

### Step 5: Diff the manifests, not just the digests

The recovered rule gives you a line-level diff for free — report *which* files
changed and their before/after hashes, not only that the aggregate moved.

```bash
diff /tmp/subject-manifest.txt /tmp/subject-new.txt
# 4 changed rows; the other 14 byte-identical to the audit's table
```

### Step 6: Re-verify at node close

State-zone edits (NOTES.md, reports, task tracking) must be excluded by the
subject definition. Recompute after those edits and confirm the digest is
unchanged — that proves the exclusion actually holds instead of assuming it.

---

## Verification

### Command

```bash
# predecessor's digest reproduced from its own published components
sha256sum < /tmp/subject-manifest.txt | cut -d' ' -f1
# successor computed with the same recovered rule, recomputed at node close
sha256sum < /tmp/subject-new.txt | cut -d' ' -f1
```

### Expected Output

```
78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a   # == published predecessor
a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf   # successor, stable at close
```

### Checklist

- [ ] Convention recovered **before** any subject file was mutated
- [ ] Predecessor aggregate reproduced exactly from its published per-file table
- [ ] At least one rejected encoding variant recorded (proves the test discriminates)
- [ ] Subject set rebuilt from the stated definition, and its size matches
- [ ] Unchanged files verified byte-identical to the published table, individually
- [ ] `sha256sum`'s platform `*` marker normalised, not trusted
- [ ] Successor digest recomputed after state-zone edits and unchanged
- [ ] If the artifact publishes multiple independently fingerprinted groups, the
      recovered rule was validated against more than one before being trusted
      for the group that matters

---

## Anti-Patterns

### Don't: re-implement the aggregation from the prose

```bash
# BAD - a confident, well-formed, incomparable number
find . -type f | sort | xargs sha256sum | sha256sum
```

Three independent divergences from the example above (sort key, `*` marker, and
`xargs` batching order on large sets), none of which announce themselves.

### Don't: re-hash the files during the recovery step

Use the *published* per-file values while solving for the encoding. Re-hashing
mixes two failure sources, so a mismatch no longer localises to the encoding.

### Don't: copy the predecessor's path list into your successor computation

That would make the set-membership claim circular — a file added or deleted since
would be invisible. Rebuild from the definition and let the count and the diff
confirm the set.

### Don't: publish a successor digest without saying which files moved

The digest proves *that* something changed. The per-file diff is what a reviewer
can act on, and you already have it.

---

## Related Resources

- `.gitattributes` / `core.autocrlf` — line-ending translation at checkout will
  change every file hash; a checkout-preserved-bytes assertion belongs in CI
  before any hashing step

---

## Related Memory

### NOTES.md References

- `## Session Continuity`: 2026-08-11 `/implement sprint-2` A-1 remediation entry —
  records the reproduction of `78c8881204…2ac45a` and the recovered convention

### Related Skills

- `audit-subject-fingerprint-under-agent-telemetry`: the complementary half — how
  to define *which files* the fingerprint covers so agent-harness telemetry does
  not read as subject mutation. This skill assumes that surface is settled and
  addresses how the covered files are *serialised* into one digest.
- `independent-constant-reproduction`: same discipline applied to a build constant
  rather than a file-set digest.
- `verify-the-mutant-not-the-verdict`: sibling rule from the same node — prove the
  premise of your check, not only its verdict.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.1.0 | 2026-08-16 | Merged in the smallest-group-first / multi-group cross-validation refinement (Step 3b) from the pending candidate `reverse-engineer-an-undocumented-fingerprint-scheme` (sprint-6 review, 2026-08-14), which independently rediscovered this skill's core technique against a manifest with three separately fingerprinted groups. Disposition: MERGE at `/skill-audit --pending` sprint-6 skill reconciliation (2026-08-16) — folded rather than promoted as a separate artifact; see `grimoires/loa/skills-archived/reverse-engineer-an-undocumented-fingerprint-scheme/` for the original. |
| 1.0.0 | 2026-08-11 | Initial extraction |

---

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true      # derived rather than assumed; a rejected variant (no trailing newline) proved the test discriminates. Honest note: the correct encoding was the first of two candidates tried, so effort was low — the value is in the technique and the expense of the avoided failure, not in a long investigation
  reusability: true          # applies to any re-audit, attestation, or reproducible-build handoff comparing digests across nodes
  trigger_clarity: true      # concrete trigger (predecessor publishes aggregate + components; successor must be comparable)
  verification: true         # verified in-session: predecessor digest reproduced exactly; successor recomputed and stable after state-zone edits
extraction_source:
  agent: implementing-tasks
  phase: /implement sprint-2 (A-1 provenance-boundary remediation)
  session: cycle-002 2026-08-11
```
