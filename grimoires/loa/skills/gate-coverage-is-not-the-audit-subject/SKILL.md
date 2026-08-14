---
name: gate-coverage-is-not-the-audit-subject
description: |
  A provenance/structural gate suite prints "All checks passed", and the auditor
  credits it as evidence for the sprint's security claim. But a gate that
  enumerates its subjects **by name** covers only the contracts it names — and
  a gate written in sprint N knows nothing about the contract sprint N+1 added,
  which is usually the entire audit subject. The failure is not a wrong gate; it
  is an auditor crediting a green run for coverage the run never claimed. Apply
  when any hand-maintained structural/provenance tool is offered as evidence for
  a claim about newly added code, and whenever a sprint's headline security
  claim ("no owner, no upgrade path, no arbitrary call") is backed by a tool run
  rather than by a check you performed on the new artifact. Provides the
  set-difference detection method and the independent-census fallback.
loa-agent: auditing-security
extracted-from: cycle-002 / sprint-3 `/audit-sprint` (Rig monetary core)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - audit-technique
  - ci-gates
  - provenance
  - evidence-integrity
  - structural-absence
  - solidity
  - foundry
---

## Problem

`tools/provenance/run-all.sh` ends with `All provenance gates and tests passed.`
The sprint's central security claim is that the new contract has *no owner, no
role, no pause, no upgrade path, no arbitrary call, and no hidden mutable
authority*. The obvious move is to cite the green run.

The green run does not contain that evidence. `inspect-runtime-surface.sh` was
written at sprint 2 and enumerates its subjects by name:

```
HardReserve external functions: 6      ok
VUX external functions: 20             ok
HardReserve mutability profile         ok
VUX burn surface                       ok
HardReserve runtime opcode census      ok  (no DELEGATECALL / SELFDESTRUCT / CREATE)
```

`Rig` — the whole of sprint 3, and the only contract that moves money — appears
nowhere. Its runtime bytecode was never examined by any gate.

The gate is not broken and is not lying. It is answering a sprint-2 question
with sprint-2 scope. The defect is in the *reader*: a suite whose pass message
names `HardReserve` and `VUX` was about to be cited for a claim about `Rig`.

---

## Trigger Conditions

### Symptoms

- A sprint adds a contract/module, and the audit cites a pre-existing gate suite
  as evidence about it.
- A gate's per-check output names specific subjects (`HardReserve …`, `VUX …`)
  rather than reporting a count derived from a discovered set.
- The tool's accepted lists are hand-maintained constants (`RESERVE_ABI=`,
  `VUX_ABI=`) rather than a glob, a manifest, or an artifact walk.
- The suite's summary line is subject-free ("All checks passed"), so the scope
  is visible only in the per-check lines above it.
- A sprint plan says a structural suite is "extended in later sprints" — which
  means it is *not* extended yet.

### Code shapes that trigger this

```bash
# Subject-enumerated: adding a contract requires editing the gate.
RESERVE_ABI=("redeem(uint256,address)" "backing()" ...)
VUX_ABI=("mint(address,uint256)" ...)

check_surface "HardReserve" "${RESERVE_ABI[@]}"
check_surface "VUX"         "${VUX_ABI[@]}"
# ...and nothing else. A third contract is simply not a subject.
```

### Context

Distinct from [[fail-closed-gate-scope-probe]], which covers the **location**
axis — a gate built from `find <fixed-dir>` misses a violating file placed
outside its scan roots, detected by planting a probe there. That probe finds
nothing here: `Rig.sol` sits *inside* every scanned directory. The gate skips it
because it has no stanza for it, not because it cannot see it. Location scoping
is probed; **subject enumeration is diffed**.

---

## Root Cause

Two different evidence sources are read as one:

1. **Discovered-set checks** scale with the repository. `verify-census.sh`
   classifies "89 files — 63 vendored, 26 VUX-owned" from a walk, so a new file
   is automatically a subject and default-deny catches it.
2. **Enumerated-subject checks** do not scale at all. Their coverage is a
   constant in the script.

Both print `ok` in the same suite, under one summary line. Nothing in the output
distinguishes "checked and clean" from "not a subject".

Worse, the enumerated form is often *deliberate*: this repo records that the
gate's ABI lists and the Solidity suites' lists are two hand-maintained copies
on purpose, because two independent implementations agreeing is the property.
That reasoning is sound and is exactly what does not extend itself to a new
contract.

---

## Solution

### Step 1: Extract the gate's enumerated subject set

Read the tool, not its output. Collect every subject it names.

```bash
grep -nE '^[A-Z_]+_ABI=|check_surface|for c in ' tools/provenance/inspect-runtime-surface.sh
```

### Step 2: Extract the sprint's subject set

From the sprint's own manifest — new/modified source files, not the tool.

```bash
git status --porcelain=v1 -- src/ ; git diff --stat HEAD -- src/
```

### Step 3: Take the set difference, and treat it as uncovered

`{sprint subjects} \ {gate subjects}` is the list of contracts for which the
green run is **not** evidence. Do not soften this to "probably fine because the
patterns are the same" — the gate exists precisely because that inference is
not accepted elsewhere.

### Step 4: Decompose "covered" by *what each source actually examines*

Coverage is per-property, not per-contract. In the originating audit, `Rig`'s
**ABI** was in fact covered by the Solidity suite
(`test_TheRigExternalSurfaceIsExactlyTheAcceptedOne`, a two-way exhaustive
comparison), while its **runtime opcodes** were covered by nothing. Only the
second gap was real, and only this decomposition found it.

### Step 5: Run an independent census for the uncovered property

Do not wait for the tool to be extended, and do not extend it during an audit.
Produce the missing evidence yourself, in the audit.

```bash
node -e '
const a=require("./out/Rig.sol/Rig.json");
const code=Buffer.from(a.deployedBytecode.object.slice(2),"hex");
const m=code.readUInt16BE(code.length-2);            // strip CBOR metadata tail
const body=(m+2<code.length)?code.slice(0,code.length-(m+2)):code;
const N={0xf0:"CREATE",0xf5:"CREATE2",0xf2:"CALLCODE",0xf4:"DELEGATECALL",0xff:"SELFDESTRUCT"};
const c={}; Object.values(N).forEach(k=>c[k]=0);
for(let i=0;i<body.length;i++){const op=body[i];
  if(N[op])c[N[op]]++;
  if(op>=0x60&&op<=0x7f)i+=op-0x5f;}                  // skip PUSH immediates
console.log(body.length,c);'
```

The PUSH-immediate skip is load-bearing: without it, bytes inside a `PUSH32`
operand are counted as opcodes and the census silently over-reports.

### Step 6: Report the gap separately from the finding

The census usually confirms the claim (it did here: `Rig` has 0 CREATE /
CREATE2 / CALLCODE / DELEGATECALL / SELFDESTRUCT). That makes the *coverage*
gap, not a vulnerability, the finding — record it as a carried obligation to
extend the tool, and state in the audit that the property was established by
independent census rather than by the gate.

---

## Verification

### Command

```bash
bash tools/provenance/run-all.sh 2>&1 | grep -oE '^ok +[A-Za-z]+' | sort -u
```

### Expected Output

A list of the subjects the suite actually names. Compare it against `src/`.
If a source file in `src/` never appears, the suite is not evidence about it.

### Checklist

- [ ] Every contract in the sprint's subject set appears in some gate's output,
      or is explicitly listed as independently censused.
- [ ] Coverage decomposed per property (ABI / opcodes / storage / bytecode
      identity), not asserted per contract.
- [ ] The independent census strips metadata and skips PUSH immediates.
- [ ] The census includes a known-present opcode as a positive control, so a
      broken walk cannot report a clean absence.
- [ ] The audit states which evidence came from the gate and which the auditor
      produced.

---

## Anti-Patterns

### Don't: cite the suite summary line

`All provenance gates and tests passed` names no subject. It is a true statement
about the gate's scope and an unsupported one about anything else.

### Don't: infer coverage from pattern similarity

"`Rig` is written in the same style as `HardReserve`, which passed" is exactly
the reasoning the structural gate was built to replace.

### Don't: extend the tool mid-audit

Editing the gate you are auditing destroys its independence and mutates the
subject. Produce the census as audit evidence; file the extension as a carried
obligation.

### Don't: treat the absence result as the finding

A clean census means the claim held. The finding is that it held *unverified* —
severity is on the coverage gap, and it is usually LOW/informational, not a
vulnerability.

---

## Related Memory

### NOTES.md References

- Learnings — "Provenance gate count is now 8 (`inspect-runtime-surface.sh`
  added at Sprint 2) … the accepted external-surface lists in that gate
  (`RESERVE_ABI`, `VUX_ABI`) … are two hand-maintained copies of the same fact
  **on purpose**". The deliberate redundancy is the same property that does not
  auto-extend to a new contract.

### Related Skills

- [[fail-closed-gate-scope-probe]] — the **location** axis of the same family
  (gates enforce only where they look). Sibling, not parent: that one is probed
  by planting an artifact outside the scan roots; this one is diffed against the
  sprint manifest, because the uncovered subject is already inside them.
- [[abi-surface-claims-scope]] — what an ABI-level claim does and does not cover,
  which is the per-property decomposition of Step 4.
- [[init-code-only-capability-proof]] — the positive/negative control discipline
  that Step 5's census inherits.

---

## Changelog

- 1.0.0 (2026-08-13) — extracted from `/audit-sprint sprint-3`, where a green
  8-gate provenance run was about to be cited as evidence for `Rig`'s
  structural-absence claim; `Rig` was not a subject of any gate.
