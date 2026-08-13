---
name: prove-which-fence-caught-it
description: |
  A layered fail-closed gate runs many checks and exits non-zero if ANY of them
  fires. So "I planted a probe and the gate failed" proves the gate failed — it
  does not prove the check you are reviewing is the one that caught it. Two
  independent mechanisms silently break the attribution: (1) probe PLACEMENT — a
  probe planted where an outer default-deny check also fires can never
  distinguish the outer check from the inner detector you meant to test; and (2)
  assertion ANCHORING — a reason-matched assertion like
  `grep -q 'unauthorized source'` also matches the gate's own SUCCESS line
  (`pass "zero unauthorized source anywhere"`), so the "failed for the right
  reason" check degenerates into "failed for some reason". Apply when reviewing
  or writing negative controls for provenance boundaries, secret scanning,
  licence gates, policy engines — any gate whose output is a sequence of
  pass/fail lines. The rule: place the probe so exactly one layer CAN fire, and
  anchor the assertion on the failure prefix so exactly one layer's message CAN
  match.
loa-agent: reviewing-code
extracted-from: cycle-002 / sprint-2 / /review-sprint sprint-2 (A-1 re-review)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - review-technique
  - negative-controls
  - fail-closed-gates
  - test-design
  - default-deny
  - provenance
---

## Problem

A remediation changed one detector inside a multi-check gate. To decide whether
that change was necessary, the reviewer must answer: **with the change reverted,
does the probe still get caught — and by what?**

A gate like `verify-census.sh` runs ~15 checks and prints one line per check:

```
ok    zero unauthorized Solidity source anywhere in the repository (77 file(s) classified)
...
FAIL  UniswapV3Factory.sol implementation present — excluded by refreeze §8:
```

then exits 1 if any check failed. Two things follow, and both are easy to miss:

- **Exit code carries no attribution.** Every probe that lands anywhere
  unauthorized trips the outer default-deny check, so *every* such probe makes
  the gate exit 1 regardless of whether the inner detector under review works at
  all. A probe placed in an unauthorized directory cannot falsify a claim about
  a filename detector, a content scanner, or a policy rule.
- **The pass and fail messages of the same check share vocabulary**, because
  they are written by the same author about the same subject. `pass "zero
  unauthorized Solidity source anywhere…"` contains the exact substring
  `unauthorized Solidity source` that the failure message contains. A reason
  regex built from the failure text therefore matches a **green** gate.

Combined, they produce a verdict that looks rigorous and means nothing.

### Observed instance

Reviewing an A-1 remediation, the reviewer wrote a probe harness to test whether
a `grep -E` → `grep -iE` change on a filename detector was necessary. Two probes
were planted inside a declared source root (so default-deny could not fire) and
the harness reported:

```
  FAIL  [script/.SOL prohibited] default-deny fired — probe does not isolate the detector
  FAIL  [factory .SOL] default-deny fired — probe does not isolate the filename detector
```

This reads as a real finding about the implementation — "the probe placement is
wrong, default-deny is catching everything". It was **false**. Default-deny had
not fired at all. The harness had asked `grep -qE 'unauthorized Solidity
source'` and matched the gate's own `pass` line. Re-running with the assertion
anchored on the `FAIL` prefix gave the true result:

```
--- P5 UniswapV3Factory.SOL inside authorized root script/  (exit 1) ---
    FAIL  UniswapV3Factory.sol implementation present — excluded by refreeze §8:
          source universe: 78 Solidity file(s) — 63 vendored, 15 VUX-owned
```

The `15 VUX-owned` count (up from 14) is the independent confirmation that the
probe was classified **authorized** — so default-deny structurally could not
fire, and the filename detector fired alone. Only at that point was the
`-iE` change provably necessary rather than merely plausible.

The same defect was then found in the subject's own negative control: its
`expect_fail` helper used the reason regexes `'unauthorized Solidity source'`
and `'pruned Loa/state zone'`, both of which are substrings of the corresponding
`pass` lines. It was filed as a LOW finding.

---

## Trigger Conditions

### Symptoms

- A negative probe produces a verdict you cannot explain from the code you just
  read.
- A "failed for the right reason" assertion passes against a gate you believe is
  green, or would pass if you deleted the check under test.
- A probe is planted in an unauthorized/out-of-scope location to test an
  **inner** rule (content scan, filename rule, policy value).
- A review must decide whether a specific one-line detector change was
  necessary, and the only evidence is a whole-gate exit code.
- A mutation test reports "still fails closed" and you cannot say which check
  held.

### Error Messages

There is no error. That is the hazard — both mechanisms produce well-formed,
confident, wrong verdicts. The only surfaced signal is a verdict that contradicts
your reading of the source.

### Context

| Context | Value |
|---------|-------|
| Gate shape | Multi-check script printing `ok`/`pass` and `FAIL` lines, exiting non-zero if any check failed |
| Timing | Review of a remediation that changed one detector; or authoring a negative control |
| Prerequisites | The gate has at least one outer default-deny/catch-all check plus inner specific detectors |
| Cross-domain | Identical in secret scanners, licence-header gates, SAST policy engines, lint rule suites |

---

## Root Cause

**Placement.** Default-deny gates are layered on purpose: an outer check catches
anything unclassified, inner checks catch specific prohibited things in
*classified* locations. The outer check is strictly broader, so a probe in an
unauthorized location is caught by it and never reaches the question the inner
check answers. The inner detector exists precisely for the case the outer one
cannot see — an authorized location — which is the only place it can be tested.

**Anchoring.** A check's pass and fail messages are two renderings of one
predicate. Authors naturally write `pass "zero X anywhere"` and `fail "X found:
…"`, so the distinguishing token is the quantifier (`zero`), not the subject
(`X`). A regex built from the subject matches both. `grep -q` over the whole
output makes this maximally likely, because the output contains every check's
line, not just the failing one.

---

## Solution

### Step 1: Place the probe where exactly one layer can fire

Ask which checks are *structurally capable* of firing at the probe's location,
before running anything.

```bash
# WRONG for testing an inner detector: contracts/ is unauthorized,
# so default-deny fires and the detector's contribution is invisible.
plant contracts/research/CaseProbe.SOL   # prohibited content

# RIGHT: script/ is a DECLARED source root, so the file is classified
# authorized; default-deny structurally cannot fire and only the
# prohibited-source detector remains.
plant script/ReviewProbeEcho.SOL         # prohibited content
```

### Step 2: Confirm the classification, don't assume it

Read the gate's own accounting line back. If the probe was classified as
intended, the authorized count moves:

```
source universe: 78 Solidity file(s) — 63 vendored (census), 15 VUX-owned
                                                          ^^ 14 -> 15
```

A probe you *believe* is authorized but which the gate classified otherwise is
the placement bug, restated.

### Step 3: Anchor the assertion on the failure prefix

Never match the bare reason. Match the reason **as a failure**:

```bash
# WRONG — also matches:  pass "zero unauthorized Solidity source anywhere..."
grep -qE 'unauthorized Solidity source'

# RIGHT — can only match a FAIL line
grep -qE '^FAIL  unauthorized Solidity source'
```

If the gate's fail lines are indented or coloured, strip ANSI first and anchor on
the literal prefix the script emits (`fail()` in the gate is the authority for
that string). Where the gate has no distinguishing prefix, that is itself a
finding: report it and assert on line position instead.

### Step 4: Assert the NEGATIVE too

Isolation is a two-sided claim. Assert both that the intended check fired **and**
that the outer check did not:

```bash
out="$(bash "$GATE" 2>&1)"; rc=$?
if   (( rc == 0 ));                                          then bad "gate passed — detector blind"
elif grep -qE '^FAIL  unauthorized Solidity source' <<<"$out"; then bad "default-deny fired — probe does not isolate the detector"
elif grep -qE '^FAIL  UniswapV3Factory\.sol'        <<<"$out"; then ok  "ONLY the filename detector fired"
else                                                               bad "failed for an unrelated reason"; fi
```

The three-way split is the point: `ok` is reachable only when exactly one named
check fired.

### Step 5: Pair it with a false-positive control

A detector widened to catch more (e.g. `-E` → `-iE`) needs proof it did not also
start catching authorized things. Plant the nearest *legitimate* neighbour and
require green:

```
P6 — script/IUniswapV3Factory.SOL (the AUTHORIZED interface name) -> gate green
```

---

## Verification

### Command

```bash
# isolation probe + false-positive control, each asserted three-ways
bash reviewer-probes.sh
```

### Expected Output

```
--- P4 prohibited-source .SOL inside authorized root script/  (exit 1) ---
    FAIL  prohibited-source reference in Solidity sources:
          source universe: 78 Solidity file(s) — 63 vendored, 15 VUX-owned
--- P5 UniswapV3Factory.SOL inside authorized root script/  (exit 1) ---
    FAIL  UniswapV3Factory.sol implementation present — excluded by refreeze §8:
          source universe: 78 Solidity file(s) — 63 vendored, 15 VUX-owned
--- P6 authorized interface name, .SOL (false-positive control)  (exit 0) ---
```

Exactly one `FAIL` line per probe, and it is the intended one. The count line
confirms the placement. P6 green confirms no over-match.

### Checklist

- [ ] Every probe's location was chosen so exactly one check can fire
- [ ] The gate's own classification/accounting line confirms the placement
- [ ] Every reason regex is anchored on the failure prefix, not the bare subject
- [ ] Each probe asserts the outer check did **not** fire, not only that the inner one did
- [ ] A widened matcher has a false-positive control on its nearest legitimate neighbour
- [ ] Regexes were sanity-checked against a **green** run — a reason regex that matches a clean gate is broken

---

## Anti-Patterns

### Don't: treat a non-zero exit as attribution

`rc != 0` means the gate failed. In a 15-check gate it says nothing about which
check, and therefore nothing about the line you are reviewing.

### Don't: build the reason regex from the failure message alone

Copy the failure string, then **run it against a clean gate**. If it matches, it
is matching the pass line. This one-line check would have caught the observed
instance immediately.

### Don't: file "the probe placement is wrong" without re-checking your own harness

The false verdict in the observed instance was a plausible, well-formed finding
*about the subject*. The harness was wrong. When a probe result contradicts your
reading of the source, suspect the harness first — it is younger and less
reviewed than the code.

### Don't: accept a probe that is caught by the outer layer as evidence for an inner one

Report it as a test-strength finding instead. The subject's probe 11 planted
prohibited content in an unauthorized directory; it proves the gate catches the
file, not that the prohibited-source scanner recovered its reach.

### Don't: widen a matcher without a false-positive control

`-E` → `-iE` on `(^|/)UniswapV3Factory\.sol$` is safe only because the `(^|/)`
anchor still excludes `IUniswapV3Factory.sol`. That is a claim, and it costs one
probe to make it a fact.

---

## Related Resources

- `tools/provenance/verify-census.sh` — the layered gate; `fail()`/`pass()` are the authority for the prefix strings
- `tools/provenance/demo-boundary-negative.sh:96-103` — `expect_fail`, the observed instance of the anchoring defect
- `grimoires/loa/a2a/sprint-2/engineer-feedback.md` §4, §5, L-3, I-2 — the review that produced this

---

## Related Memory

### NOTES.md References

- `## Learnings` — "[Review technique — which fence caught it]"

### Related Skills

- [[verify-the-mutant-not-the-verdict]] — the sibling rule. That one proves the
  **mutant existed**; this one proves **which detector responded**. A mutation
  test needs both: an unproven mutant makes the run uninterpretable, an
  unattributed verdict makes it unattributable.
- [[fail-closed-gate-scope-probe]] — the complementary direction: plant where the
  gate does **not** look, to expose a scope hole. This skill plants where it
  **does** look, in a position only one layer covers.
- [[matcher-asymmetry-in-default-deny-gates]] — how the inner/outer predicate
  disagreement that makes isolation necessary arises in the first place.
- [[default-deny-source-boundary]] — the implementation-side counterpart.

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-08-11 | Extracted from `/review-sprint sprint-2` A-1 re-review |
