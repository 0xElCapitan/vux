---
name: live-evidence-survives-a-pipeline-change
description: |
  When a change enables a codegen-affecting build setting (`via_ir`, an
  optimizer, a different backend), everything compiled under the shared profile
  recompiles differently — including artifacts a previous, already-accepted
  sprint produced evidence about. The reviewer's question is not "did the
  bytecode change" (it did) but "does the accumulated evidence still hold, and
  what must be regenerated before the next gate". That answer turns on one
  property no report states: whether each prior evidence item is **derived at
  run time from the build output** or **recorded as a value** when it was
  produced. Only recorded evidence goes stale. Apply when reviewing any diff
  that adds a bytecode- or output-affecting key to a shared build profile in a
  repo whose earlier gates accepted claims about compiled artifacts — and when a
  report defends the change as a "compilation necessity", which is a testable
  claim, not a framing. Provides the necessity test (including the rebuttal
  configuration everyone forgets), the non-mutating way to obtain baseline
  artifacts, the live-vs-frozen classification, and the reason positive controls
  are what make live evidence portable across pipelines.
loa-agent: reviewing-code
extracted-from: cycle-002 / sprint-3 review (`via_ir` enablement on the VUX unit)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - review-technique
  - build-configuration
  - reproducible-builds
  - evidence-integrity
  - foundry
  - solidity
  - via-ir
---

## Problem

A sprint enables `via_ir` + `optimizer` on `[profile.default]` because an
accepted 16-field event will not compile otherwise. The report discloses the
change honestly and shows every gate green.

Two questions are left unanswered, and both are the reviewer's:

1. Was it actually *necessary*, or is "compilation necessity" a framing over a
   preference? The report asserts it; nothing in the tree tests it.
2. Everything under that profile now compiles differently — including
   `VUX.sol` and `HardReserve.sol`, whose structural-absence guarantees a
   **previous accepted sprint** established. Does that evidence still hold, and
   does any of it have to be regenerated before the audit gate?

The failure mode is not approving a bad change. It is approving a good change
on the wrong basis — "the suite is green, so nothing regressed" — which is true
of a suite whose absence assertions have silently gone vacuous under new
codegen, and equally true of one that is genuinely portable. Green does not
distinguish them.

---

## Trigger Conditions

### Symptoms

- A diff adds a bytecode- or output-affecting key to a **shared parent** build
  profile (`via_ir`, `optimizer`, `optimizer_runs`, `evm_version`,
  `bytecode_hash`; equivalently a tsconfig `target`, a Gradle toolchain, a
  compiler backend flag).
- The change is justified as a compilation necessity rather than a preference.
- An earlier, already-accepted sprint or PR produced evidence **about compiled
  artifacts** — runtime-bytecode inspection, opcode absence, ABI/dispatcher
  enumeration, a reproduced init-code hash.
- The report says the earlier suites "still pass" without saying what they read.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Any compiled language with a shared build-profile config; observed on Foundry + Solidity |
| Environment | Multi-sprint / multi-PR lifecycle where earlier gates accepted artifact-level claims |
| Timing | Review gate, before audit — while regeneration is still cheap |
| Prerequisites | The accepted baseline is reachable as a commit |

---

## Root Cause

Evidence about a compiled artifact exists in two forms that a report describes
identically:

| form | how it is obtained | survives a pipeline change? |
|---|---|---|
| **Live** | re-derived from the build output every run — a test that reads `out/**.json`, a tool that walks the freshly built image | **Yes**, if it has positive controls |
| **Frozen** | a value recorded when it was produced — a pinned hash, a checked-in dump, a quoted opcode offset in a prose artifact | **No** — stale the moment codegen moves |

Both read as "verified by runtime-bytecode inspection" in a report. The
distinction lives in the test and tool *source*, not in the prose, so it cannot
be settled by reading the report at all.

The second half of the root cause is why live evidence is not automatically
safe. An absence assertion (`no DELEGATECALL survives`) and a **broken search**
produce the same result, and new codegen is exactly the kind of change that
breaks a search — a different instruction layout, a different metadata tail, a
different image length. A live absence assertion with no positive control
becomes vacuous silently, under a green suite. The control is what converts
"the search found nothing" into "the thing is not there".

---

## Solution

### Step 1 — Test the necessity claim, including the rebuttal configuration

Reproduce the failure under the **exact** prior settings, then again under the
one variation a skeptic will raise. Both runs, or neither is evidence:

```bash
# The exact baseline settings
FOUNDRY_VIA_IR=false FOUNDRY_OPTIMIZER=false forge build --out "$SCRATCH/a"
#   → Stack too deep — libyul/backends/evm/AsmCodeGen.cpp:68

# The obvious rebuttal: "surely the optimizer alone fixes this"
FOUNDRY_VIA_IR=false FOUNDRY_OPTIMIZER=true  forge build --out "$SCRATCH/b"
#   → Stack too deep — libsolidity/codegen/LValue.cpp:50
```

The second run is the load-bearing one. Without it, "they enabled the optimizer
too, and *that* is a gas choice" is an unanswered objection. Note the error
moves to a different compiler stage between the two — that is confirmation you
changed the pipeline and not just the flag.

Build to a scratch `--out` so the working tree's artifacts are untouched.

### Step 2 — Measure the delta against a build of the accepted baseline

The baseline must be *built*, not inferred. Use a throwaway worktree — never
`git stash`, which shifts index state under any hook that stashes internally:

```bash
git worktree add "$SCRATCH/base" <accepted-baseline-commit>
( cd "$SCRATCH/base" && forge build )

for c in VUX HardReserve; do
  jq -r '.deployedBytecode.object' "$SCRATCH/base/out/$c.sol/$c.json" | sha256sum
  jq -r '.deployedBytecode.object' "out/$c.sol/$c.json"               | sha256sum
done

git worktree remove --force "$SCRATCH/base" && git worktree prune
```

State the measured pair in the review artifact. "The artifacts presumably
changed" is an inference the audit gate should not have to redo.

If the hashes differ but the **lengths** match, stop and read
[[separate-codegen-from-metadata-in-a-bytecode-diff]] first — that is the
metadata-tail signature, and it is a different (much smaller) finding.

### Step 3 — Classify each prior evidence item: live or frozen

Do this from the sources, not the report. Two greps settle most of it:

```bash
# Live evidence: assertions that read the build output at run time
grep -rn "readFile\|parseJson\|getDeployedCode\|out/" test/

# Frozen evidence: a recorded value that will not move on its own
grep -rniE "bytecode|deployedBytecode|0x60[0-9a-f]{20,}" <prior-evidence-dir>/
grep -nE "sha256|EXPECTED|0x[0-9a-f]{16,}" <verification-tooling>
```

Then check the *prose* evidence artifacts too: a prior audit that quoted opcode
offsets (`PUSH4 0xdb6b1b4f at 0x4cb`) recorded frozen evidence in a document
nobody will think to re-run.

Anything frozen goes in the verdict as "must be regenerated for the current
exact tree". Anything live proceeds to Step 4.

### Step 4 — For live evidence, verify the positive controls exist

Live evidence is portable **only** if each absence assertion is paired with a
control proving the search still works on this pipeline's output:

```solidity
// The controls that make the absence claims below mean something
assertGt(Artifact.countOpcode(runtime, Artifact.OP_CALL), 0,       "control: CALL found");
assertGt(Artifact.countOpcode(runtime, Artifact.OP_STATICCALL), 0, "control: STATICCALL found");

assertFalse(Artifact.hasOpcode(runtime, Artifact.OP_DELEGATECALL), "no proxy path");
assertFalse(Artifact.hasOpcode(runtime, Artifact.OP_SELFDESTRUCT), "no self-destruct");
```

Also check the *helpers* the search depends on — a metadata stripper that
removed the whole image would make every opcode-absence claim pass vacuously,
so it needs its own guard (`stripped < full`, and `stripped > 0.9 × full`).

An uncontrolled live absence assertion is **not** portable evidence. Report it
as a finding: it did not fail, and that is precisely the problem.

### Step 5 — Use the frozen unit as a free control group

If the repo also compiles a byte-frozen vendored unit under a *sibling*
profile, it is a control that costs nothing: build it in both trees and compare
directly, rather than only re-running its hash gate.

```bash
# Effective settings, not the config file
FOUNDRY_PROFILE=v3core forge config | grep -E "via_ir|optimizer|evm_version|bytecode_hash|solc"

# And the outcome the settings are supposed to produce
jq -r '.bytecode.object' "$SCRATCH/base/out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json" | sha256sum
jq -r '.bytecode.object'              "out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json"  | sha256sum
```

Byte-identical across trees converts "the frozen unit was pinned off correctly"
from a settings comparison into an outcome proof. See
[[inherited-build-flags-reach-frozen-units]] for how the leak happens.

---

## Verification

### Commands

```bash
forge test                                   # same assertions, new pipeline
FOUNDRY_PROFILE=ci forge test                # at declared depth
bash tools/provenance/run-all.sh             # frozen-artifact gates
```

### What sufficiency looks like

- Necessity reproduced under **both** legacy configurations.
- The prior-sprint artifact deltas are stated as measured hashes, not inferred.
- Every prior artifact-level claim classified live or frozen, from source.
- Every live absence assertion has a positive control, and its helpers have
  guards.
- The prior sprint's tests pass in **both** trees, with byte-identical
  assertions (confirm the test files themselves are unchanged, or the
  comparison proves nothing).
- The frozen sibling unit is byte-identical across trees.

### Checklist

- [ ] Old settings reproduce the failure; old settings + optimizer also do
- [ ] Baseline built in a worktree, not stashed, and removed afterwards
- [ ] Artifact deltas recorded as before/after hashes in the review artifact
- [ ] Prior evidence classified live vs frozen from test/tool source
- [ ] No frozen artifact-level value left un-regenerated
- [ ] Positive controls confirmed present for every live absence assertion
- [ ] Prior-sprint suite green in both trees; test files byte-unchanged

---

## Anti-Patterns

### Don't: accept "semantics-preserving by specification" as the answer

True, and it answers a different question. Specification-level equivalence says
the *program* means the same thing; it says nothing about whether an
*assertion about the compiled image* still measures what it measured. The
evidence question survives the semantics answer intact.

### Don't: read "144/144 green" as "nothing regressed"

A green suite is consistent with portable evidence and with evidence that went
vacuous. The suite cannot tell you which, because a vacuous absence assertion
passes. Only the positive controls separate them.

### Don't: infer the baseline artifacts instead of building them

```bash
# BAD — the accepted baseline's artifacts are not in this tree, and
#       "it must have been different" is not a measurement
echo "the bytecode presumably changed under via_ir"
```

Build the baseline commit. The pair of hashes is one command and it is what the
audit gate would otherwise have to derive itself.

### Don't: reach for `git stash` to get a clean tree

Pre-commit hooks stash internally and the indexes collide; a worktree has no
such window. See the project's stash-safety rule.

### Don't: stop at the settings comparison for the frozen unit

`forge config` proving `via_ir = false` shows the key was overridden. It does
not show the output is unchanged — a *different* inherited key could still have
moved it. Compare the built artifact.

---

## Related Memory

### NOTES.md References

- `## Learnings` — "[Review technique — accepted evidence under a changed
  compilation pipeline]"
- `## Decision Log` — the sprint-3 `via_ir` disposition

### Related Skills

- `inherited-build-flags-reach-frozen-units` — the *child* side: how a parent
  profile key silently reaches the unit you froze. This skill is the *parent*
  side: what the same key does to the artifacts already accepted under it.
- `stack-too-deep-when-the-schema-is-fixed` — the implementer's decision
  framing that leads to this change; this skill is how a reviewer verifies it.
- `separate-codegen-from-metadata-in-a-bytecode-diff` — run first when hashes
  differ: identical length means metadata, not codegen, and a much smaller
  finding.
- `assert-the-toolchain-that-produced-the-evidence` — the toolchain-version
  analogue of the same principle (evidence is conditional on how it was built).
- `parity-proves-emission-not-admission` — the other blind spot of output
  comparison: parity cannot see what the toolchain now *accepts*.
- `init-code-only-capability-proof` — where the positive-control discipline this
  skill depends on is defined.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-13 | Initial extraction from the cycle-002 sprint-3 review |
