---
name: resolver-diagnostic-is-not-reachability
description: |
  A build tool's resolver warning ("Unable to resolve imports", "module not
  found", "could not locate") is a statement about the tool's own discovery
  pass, NOT proof that the code failed to compile. Foundry prints "Unable to
  resolve imports" from its pre-resolution source-graph walker and then compiles
  successfully anyway, because solc resolves the import itself through its own
  filesystem callback — the file lands in the compilation unit, its code is
  embedded in the importing contract's bytecode, and it deploys and RUNS. Any
  triage that reads the diagnostic and stops will refute a real, exploitable gap.
  Apply when classifying a detector blind spot by consumer reachability, when
  deciding whether an unscanned file is build-reachable, or whenever an audit
  conclusion rests on "the toolchain cannot see it either". The discriminator is
  never the log line: read the emitted artifact's `metadata.sources`
  (or the build-info compilation unit) and, decisively, EXECUTE the code.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-2 /audit-sprint (A-1 provenance boundary; corrects sprint-1 N-2)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - security-audit
  - severity-triage
  - reachability
  - foundry
  - solidity
  - build-systems
  - false-refutation
---

## Problem

An audit is triaging a detector blind spot: a gate's file walk uses a
case-sensitive glob (`find -name '*.sol'`), so `Evil.SOL` is never classified.
The natural triage question is whether the *protected consumer* — the compiler —
shares the blind spot. If it does, the gap is unexploitable and informational.

The consumer is tested by importing the file and building. The build prints:

```
Unable to resolve imports:
      "../Evil.SOL" in ".../src/Consumer.sol"
```

The obvious reading is: the toolchain cannot see it either, blind spots are
correlated, gap refuted, severity INFORMATIONAL.

**That reading is wrong, and it silently closes a real finding.** Three lines
later the same build says `Compiler run successful!`, the code is in the
compilation unit, and it executes.

## Trigger Conditions

### Symptoms

- Triage of a "the detector misses X" finding hinges on whether the build tool also misses X.
- A build emits a resolver/loader warning **and** reports success in the same run.
- No artifact is emitted for a file, and that absence is being read as "not compiled".
- A prior audit refuted a finding citing a resolver diagnostic as the evidence.

### Error Messages

```
Unable to resolve imports:
      "../Evil.SOL" in ".../src/Consumer.sol"
with remappings:
      ...
Compiling 2 files with Solc 0.8.28
Compiler run successful!
```

The co-occurrence of the warning and `Compiler run successful!` is the tell.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Foundry / solc; generalises to any two-stage resolve-then-compile toolchain (bundlers, TS project references, Bazel) |
| Environment | Any; independent of filesystem case sensitivity (see Root Cause) |
| Timing | Severity triage of a carried-forward or newly found detector gap |
| Prerequisites | Ability to build and run the code under test in a scratch project |

## Root Cause

Foundry performs **two independent resolutions**:

1. **Source-graph discovery** (Foundry's own) — globs the source roots for
   `*.sol` (case-sensitive) and walks imports to build a compilation set. A file
   it cannot place in that graph produces `Unable to resolve imports`. This pass
   also decides which **artifacts** get emitted, which is why no
   `out/Evil.SOL/Evil.json` appears.
2. **solc's import callback** — solc receives the source and resolves
   `import "../Evil.SOL"` itself, against the literal path. The import string
   matches the real filename exactly, so it resolves **on every platform** — this
   is not a Windows case-insensitivity artifact.

So the warning describes only pass 1. Pass 2 compiles the file, embeds its
creation code in the importing contract, and the code is deployable and
executable. The blind spots are therefore **asymmetric**: the detector truly
cannot see the file; the compiler can. That asymmetry is exactly what makes the
gap real.

The absent artifact is the trap that makes the wrong conclusion feel confirmed:
an artifact-scoped check finds nothing, which looks like corroboration but is
just pass 1 speaking twice.

## Solution

### Step 1: Never accept the log line as the verdict

Treat the resolver diagnostic as a hypothesis, not a result. Record whether the
same run also reported success.

### Step 2: Read the compilation unit, not the artifact list

The authoritative record of what solc actually compiled is the emitted
metadata's source list (or `out/build-info/*.json`).

```bash
python -c "
import json
d = json.load(open('out/Consumer.sol/Consumer.json'))
for s in d['metadata']['sources']: print(s)
"
# Evil.SOL        <-- present: solc DID compile it
# src/Consumer.sol
```

If the suspect file appears here, it is in the build regardless of any warning.

### Step 3: Execute it — the only unambiguous proof

Reachability means the code runs. Deploy the importing contract and call
through to the suspect code.

```solidity
// Evil.SOL  (never enumerated by the detector OR by Foundry's globber)
contract Evil { function pwn() external pure returns (uint256) { return 42; } }

// src/Consumer.sol  (inside a declared source root)
import {Evil} from "../Evil.SOL";
contract Consumer { function use() external returns (uint256) { return new Evil().pwn(); } }

// test/Reach.t.sol
function test_Reachable() public {
    if (new Consumer().use() != 42) revert("not reachable");
}
```

```
[PASS] test_UppercaseSolIsBuildReachableAndExecutable() (gas: 227841)
```

A passing execution ends the argument. No log line outranks it.

### Step 4: Re-open any prior refutation built on the diagnostic

If recorded knowledge (NOTES.md, a previous audit) refuted a finding on this
basis, correct it explicitly and cite the execution evidence. A wrong refutation
is more dangerous than an open finding: it is load-bearing for future triage.

## Verification

### Command

```bash
forge build 2>&1 | tee build.log
grep -q 'Compiler run successful' build.log && echo "COMPILED DESPITE WARNINGS"
forge test --match-test Reachable -vv
```

### Expected Output

```
COMPILED DESPITE WARNINGS
[PASS] test_Reachable()
```

### Checklist

- [ ] Checked whether the warning co-occurred with a success line
- [ ] Read `metadata.sources` / build-info for the actual compilation unit
- [ ] Executed the code path, not merely compiled it
- [ ] Confirmed the platform-independence of the resolution (literal path match)
- [ ] Corrected any prior refutation that relied on the diagnostic

## Anti-Patterns

### Don't: treat a missing artifact as proof of non-compilation

```
# BAD - both facts come from the same discovery pass
ls out/Evil.SOL/ || echo "not compiled"     # absent artifact != absent from build
```

Artifact emission and source-graph discovery are the same stage. Consulting it
to corroborate the resolver warning double-counts one piece of evidence.

### Don't: reason about filesystem case sensitivity first

The instinct is "this only works on Windows". It is irrelevant here: the import
string matches the filename byte-for-byte, so it resolves on Linux CI too. Test
the behaviour instead of predicting it from platform theory.

### Don't: stop at "the blind spots are correlated"

Correlation of blind spots is the *conclusion* of an experiment, never its
premise. Detector and consumer are built by different people with different
enumeration rules; assume asymmetry until execution proves otherwise.

## Related Memory

### NOTES.md References

- `## Learnings`: "[Audit technique — severity triage]" — this skill **corrects**
  the N-2 refutation recorded there (`Foo.SOL` was reported invisible to Foundry;
  it is not).
- `## Learnings`: "[Audit technique — resolver diagnostics]" (added 2026-08-11).

### Related Skills

- `gate-gap-reachability-triage`: the parent method (classify by consumer
  reachability). This skill supplies the missing rule for *how* to measure
  reachability, and is the counter-example that keeps that method honest.
- `matcher-asymmetry-in-default-deny-gates`: how the gap was found in the first place.
- `default-deny-source-boundary`: the gate design whose matcher the gap lives in.

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction; corrects sprint-1 N-2 refutation |

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: auditing-security
  phase: /audit-sprint sprint-2
  session: cycle-002-sprint-2-audit
```
