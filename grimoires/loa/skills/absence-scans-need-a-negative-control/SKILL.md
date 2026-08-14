---
name: absence-scans-need-a-negative-control
description: |
  A positive control proves an absence scan CAN find what is there. It cannot
  detect the opposite failure — a scan so permissive it finds everything — because
  a method that matches indiscriminately passes every positive control it is given.
  The inverse failure is the dangerous one at an audit node: a false NEGATIVE
  produces a silently vacuous green test, while a false POSITIVE produces a
  fabricated CRITICAL finding against code that is actually correct. This bites
  hardest when an auditor REIMPLEMENTS an absence check independently — which audit
  mandates structurally require ("do not merely rerun the implementation's
  commands") — because the obvious generalization of "enumerate every legal shift"
  drops the losslessness, operand-width, and opcode-anchor constraints all at once.
  Apply to any absence/non-reachability claim read out of bytecode, logs, ASTs, or
  greps, and to every independently rebuilt version of someone else's structural
  check. Fix by anchoring on the full emitted idiom, bounding the search space by
  what the producer can actually emit, and carrying a NEGATIVE control alongside
  the positive one.
loa-agent: auditing-security
extracted-from: cycle-002 / sprint-4 /audit-sprint (FR-10.3 core-isolation re-derivation)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - audit-technique
  - structural-absence
  - positive-control
  - negative-control
  - bytecode
  - via-ir
  - evidence-integrity
  - false-positive
---

## Problem

An audit mandate required independently re-deriving the claim "the Strategic
Treasury contains no call site for any monetary-core authority" rather than
re-running the implementation's own test. The independent scan enumerated all 32
shifts of each selector and substring-searched the bytecode. It reported:

```
=== POSITIVE CONTROLS (must ALL be FOUND) ===
FOUND   0x42966c68  IVUXBurnable.burn            s=3
FOUND   0xa9059cbb  IERC20.transfer              s=0
... 10/10 FOUND

=== DANGEROUS SELECTORS (must ALL be absent) ===
PRESENT 0x40c10f19  VUX.mint                     s=27
PRESENT 0xdb6b1b4f  VUX.burnForRedemption        s=29
PRESENT 0x7bde82f2  HardReserve.redeem           s=30
... 9/9 PRESENT

METHOD INTEGRITY: OK — every control detected
DANGEROUS PRESENT: 9
```

**Every positive control passed and the method printed `OK`, while producing nine
false positives.** Taken at face value this is a fabricated CRITICAL finding — a
report that the treasury can mint VUX and drain the Hard Reserve — against a
contract that provably cannot name those functions at all.

The impact is asymmetric and worth stating plainly:

| direction | effect at an audit node |
|---|---|
| false **negative** (scan misses a real call) | vacuous green; a real defect ships |
| false **positive** (scan matches noise) | fabricated CRITICAL; correct code blocked, auditor credibility spent |

## Trigger Conditions

### Symptoms

- An absence scan reports that **everything** in the forbidden set is present.
- The forbidden set and the control set both come back 100 % positive.
- A match is reported only at a large shift/offset (`s ≥ 24`) while the controls
  all match at small ones (`s = 0..3`).
- You just rewrote someone else's structural check "independently" and got a
  dramatically worse result than they did.

### The five-second disproof

If a scan claims a selector is present, ask what byte string it matched. At
`s ≥ 24` a 32-bit selector has been shifted down to one significant byte:

```
0x40c10f19 >>> 27  ==  0x8        ->  padded to 8 hex chars: "00000008"
```

`00000008` occurs in essentially every contract's bytecode. The scan is matching
noise, not a call site.

### Context

| Context | Value |
|---|---|
| Applies to | Any absence claim: bytecode scans, log greps, AST queries, ABI diffs |
| Sharpest at | Audit/review nodes that mandate independent re-derivation |
| Also affects | Any rebuild of a check whose original had constraints you did not port |

## Root Cause

The sound method has **three** simultaneous constraints. The naive
generalization keeps one and silently drops the other two.

Solidity under `via_ir` emits `selector << 224` as
`(selector >> s) << (224 + s)` for some small `s`, materialised as the idiom
`PUSH4 (sel >> s); PUSH1 (0xe0 + s); SHL`. A correct scan therefore requires:

1. **Losslessness** — `(sel >> s) << s == sel`. Only shifts the selector survives
   are candidates; the compiler cannot use any other, because the low bits would
   be unrecoverable.
2. **Operand width** — `(sel >> s) >= 0x01000000`. Once the shifted value no
   longer needs four bytes, solc emits `PUSH3` or shorter, so a `PUSH4` pattern
   is not what would appear.
3. **Opcode anchoring** — match `63 <4 bytes> 60 <0xe0+s> 1b`, not the bare hex
   of the operand.

Drop (1) and (2) and the search space explodes to 32 candidates per selector,
most of them one- or two-byte values. Drop (3) and each candidate is matched
against raw hex with no structural context. The product of those three omissions
is a scan that matches almost anything.

**Why the positive control cannot save you here.** A control asserts *"the method
finds X, which is present."* An over-permissive method finds X. It also finds
everything else. Positive controls are monotone in permissiveness: loosening the
method can only make them pass harder. They constrain the method from exactly one
side, and this failure arrives from the other.

## Solution

### Step 1: anchor on the full emitted idiom and bound the search space

```javascript
function found(hex) {
  const v = parseInt(hex, 16); const hits = [];
  for (let s = 0; s < 32; s++) {
    const sh = v >>> s;
    if (sh < 0x01000000) break;              // (2) solc would not PUSH4 this
    if ((sh << s) >>> 0 !== v) continue;     // (1) compiler cannot use this shift
    const h = sh.toString(16).padStart(8, '0');
    const idiom = '63' + h + '60' + (0xe0 + s).toString(16).padStart(2, '0') + '1b';
    if (code.includes(idiom)) hits.push(`SHL-idiom s=${s}`);   // (3) anchored
  }
  return hits.length ? hits.join(',') : null;
}
```

### Step 2: carry a NEGATIVE control

The negative control must be absent **by construction**, not merely believed
absent — otherwise a failure is ambiguous. A synthetic signature nobody would
ever call is the right choice, and it costs one line:

```javascript
// Negative control: cannot exist in any real contract.
assert(found(sel('__loa_audit_negative_control_zzz()')) === null,
       'method is over-permissive — it matches a selector that cannot be present');
```

Run it in the **same** pass as the subject. Positive control ⇒ "the method can
see." Negative control ⇒ "the method is not hallucinating." An absence claim
needs both, and only both together bound the method from each side.

### Step 3: prefer the producer-independent proof, and treat the scan as corroboration

The strongest form of the claim does not depend on codegen at all. Read the
compiler's own record of what it compiled:

```bash
jq -r '.metadata.sources | keys[]' out/C.sol/C.json
```

Then close the residual the source-set argument leaves open — a call built from a
*computed* selector — by showing the producer has no mechanism to build one:

```bash
grep -nE '\b(assembly|delegatecall|staticcall|\.call\(|create2?)\b' src/C.sol
```

With no assembly and no low-level call, every selector the contract can emit was
encoded by the compiler from a typed interface member, and `metadata.sources`
enumerates those exhaustively. That makes absence **structural** rather than
encoding-dependent, and demotes the bytecode scan to what it should be: a
cross-check, not the argument.

## Verification

The corrected scan on the same artifact, in one pass:

```
=== POSITIVE CONTROLS (must ALL be FOUND) ===
FOUND   0x42966c68  IVUXBurnable.burn            SHL-idiom s=3
FOUND   0x1f035c7a  Adapter.recall               SHL-idiom s=1
... 10/10 FOUND

=== DANGEROUS SELECTORS (must ALL be absent) ===
absent  0x40c10f19  VUX.mint
absent  0x8206a4d1  Pool.setFeeProtocol
... 0/9 PRESENT

METHOD INTEGRITY: OK — all 10 controls detected
```

Two independent signals then agreed: this scan, and the shipped
`_hasCallSite` (which had the constraints all along). Agreement between two
methods built from different starting points is the real verification —
`setFeeProtocol` is *nameable* in the compilation unit yet not emitted, a fact
neither the source-set proof nor a naive scan would have surfaced alone.

### Checklist

- [ ] Every absence assertion has a positive control **and** a negative control
- [ ] The negative control is absent by construction, not by belief
- [ ] The search space is bounded by what the producer can actually emit
- [ ] Matches are anchored on structure (opcodes/fields), not bare substrings
- [ ] A producer-independent proof carries the primary claim
- [ ] Any reported "present" was traced to the exact bytes it matched

## Anti-Patterns

### Don't: enumerate a search space larger than the producer's output space

```javascript
// BAD — 32 candidates per selector; at s>=24 the operand is one byte and
// matches noise in every contract. Reports 9/9 forbidden selectors "PRESENT".
for (let s = 0; s < 32; s++)
  if (code.includes((v >>> s).toString(16).padStart(8, '0'))) return true;
```

### Don't: treat a green control panel as method validation

`METHOD INTEGRITY: OK — every control detected` was printed by the broken run.
The banner was true and meaningless: it validated only the direction that was
already working. Name the property being controlled for, not "integrity."

### Don't: report a scan hit as a finding without tracing the matched bytes

A "present" result at an implausible shift/offset is a method bug until proven
otherwise. Escalating it as CRITICAL costs more than the check would have.

## Related Memory

### NOTES.md References

- `## Learnings`: absence scans need controls in both directions (this skill)

### Related Skills

- `selector-constants-are-shift-normalized` (pending) — **the direct inverse, and
  required reading with this one.** It documents the false-NEGATIVE failure of the
  same scan and prescribes positive controls as the remedy. This skill is the
  other half: that remedy is necessary but not sufficient, and its own guidance to
  "enumerate every legal shift" is what an independent reimplementer over-reads
  into a false-positive machine. Neither skill is complete without the other.
- `verify-reported-evidence-in-the-completeness-direction` (pending) — same
  discipline one level up: re-deriving reported numbers proves honesty about what
  was listed, never about what was omitted. This is its bytecode-level instance.
- `gate-coverage-is-not-the-audit-subject` (pending) — the third member of the
  family: a green tool run is evidence only for the subject the tool actually
  covered.

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-13 | Initial extraction |

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: auditing-security
  phase: /audit-sprint sprint-4
  session: 8d563f9a-91a2-4cf9-bc1f-7e027d2a952b
```
