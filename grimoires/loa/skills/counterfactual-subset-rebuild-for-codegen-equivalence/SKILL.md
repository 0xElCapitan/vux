---
name: counterfactual-subset-rebuild-for-codegen-equivalence
description: |
  A change enables a codegen-affecting build setting (`via_ir`, an optimizer, a
  backend), and the tree can no longer compile under the old one — so the
  straight A/B build that would settle "did semantics change" is unavailable,
  and the disposition falls back to "hashes differ, but the tests still pass".
  That is an argument from absence. The available move is a **counterfactual
  subset rebuild**: the sources that are byte-unchanged from the accepted
  baseline still compile under the old pipeline, so build exactly those into a
  scratch output tree and diff **opcode classes, ABI, and storage layout** —
  never raw bytecode hashes, which always differ and prove nothing. Apply at the
  audit gate for any pipeline change, especially when a report says the change
  is "semantics-preserving by specification". Also relocates findings: an
  opcode present in *both* builds belongs to some other setting, not to the
  change under review.
loa-agent: auditing-security
extracted-from: cycle-002 / sprint-3 `/audit-sprint` (`via_ir` enablement on the VUX unit)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - audit-technique
  - build-configuration
  - reproducible-builds
  - codegen
  - evidence-integrity
  - foundry
  - solidity
  - via-ir
---

## Problem

Sprint 3 enables `via_ir` + `optimizer` because an accepted 16-field event will
not otherwise compile. Every artifact under the shared profile now has a
different runtime hash, including two contracts a previous sprint already
accepted. The delivered disposition is:

- the change is a genuine compilation necessity (true, and testable);
- prior guarantees were live checks, and all re-established green (true);
- `via_ir` is "semantics-preserving by specification" (a citation, not a
  measurement on this tree).

The gate question is narrower than any of those: **did the pipeline change what
this code can do?** The natural experiment — build the same sources both ways —
appears unavailable, because the whole point is that the tree no longer compiles
under the old pipeline. So the question gets answered by appeal to the compiler
team's documentation and a green suite.

It is answerable. The subset of sources that is *byte-unchanged from the
accepted baseline* is exactly the subset that used to compile, and still does.

---

## Trigger Conditions

### Symptoms

- A diff adds `via_ir`, `optimizer`, `optimizer_runs`, a compiler backend, or an
  equivalent codegen key to a shared build profile.
- The report states the old pipeline "fails to compile", so no baseline build is
  offered — only re-run tests.
- The justification cites a specification guarantee rather than a measurement.
- Previously accepted artifacts changed hash, and the accompanying argument is
  that their evidence was "live, not frozen".
- A later sprint will freeze deployment bytecode, inheriting this pipeline.

### Context

Complement, not duplicate, of two neighbours:

- [[live-evidence-survives-a-pipeline-change]] (review-side) asks *does the
  accumulated evidence still hold* — necessity test, live-vs-frozen
  classification, positive controls. It does not compare the two pipelines'
  **output semantics**, because its subject is the evidence, not the codegen.
- [[separate-codegen-from-metadata-in-a-bytecode-diff]] discriminates codegen
  change from metadata change **within one build**. This skill compares **across
  two pipelines**, which is only possible on the unchanged subset.

---

## Root Cause

A raw bytecode hash is the wrong comparator, and it is the only one usually
reached for. Under a pipeline change it differs unconditionally — from
instruction scheduling, stack layout, code size, and the metadata tail — so it
can neither confirm nor refute a semantic difference. Reporting "hashes changed"
therefore carries no information, and the vacuum gets filled by the
specification citation.

The informative comparators are the ones that map to *capability*:

| comparator | differs under a benign pipeline change? | answers |
|---|---|---|
| raw runtime hash | always | nothing |
| body length | always | nothing |
| **opcode-class set** | **no** | can the code do something new, or need chain support it did not? |
| **ABI hash** | **no** | did the external surface move? |
| **storage layout** | **no** | did state placement move? |

---

## Solution

### Step 1: Identify the byte-unchanged subset

Only sources identical to the accepted baseline are valid counterfactual
subjects — anything the sprint edited would confound codegen change with source
change.

```bash
git diff --stat HEAD -- src/          # empty for a file == unchanged, valid subject
```

### Step 2: Build that subset under the OLD pipeline, outside the repo

Env overrides only. Do not edit `foundry.toml`, and do not `git stash` — the
subject must stay byte-identical throughout.

```bash
SCRATCH=/path/to/scratchpad
FOUNDRY_VIA_IR=false \
FOUNDRY_OUT="$SCRATCH/out-legacy" \
FOUNDRY_CACHE_PATH="$SCRATCH/cache-legacy" \
forge build --skip 'test/**' --skip 'script/**' --skip '*NewContract*'
```

**`--skip` takes glob patterns, not directory names.** `--skip test` silently
matches nothing; the build then pulls in the test tree and dies on the very
`Stack too deep` you were routing around, which reads like the experiment is
impossible rather than mis-invoked. Use `'test/**'`.

Set `FOUNDRY_CACHE_PATH` as well as `FOUNDRY_OUT` — sharing the repo cache
across two pipelines produces stale or mixed artifacts.

### Step 3: Diff opcode classes, not bytes

Strip the CBOR metadata tail and walk the body skipping PUSH immediates, then
compare the *set* of classes present, and treat any class appearing in one build
and not the other as the finding.

```bash
node -e '
const fs=require("fs");
const NEW={0x5f:"PUSH0",0x5e:"MCOPY",0x5c:"TLOAD",0x5d:"TSTORE"};
const DANGER={0xf0:"CREATE",0xf5:"CREATE2",0xf2:"CALLCODE",0xf4:"DELEGATECALL",0xff:"SELFDESTRUCT"};
function prof(p){const a=JSON.parse(fs.readFileSync(p));
  const code=Buffer.from(a.deployedBytecode.object.slice(2),"hex");
  const m=code.readUInt16BE(code.length-2);
  const b=(m+2<code.length)?code.slice(0,code.length-(m+2)):code;
  const c={};
  for(let i=0;i<b.length;i++){const o=b[i];
    if(NEW[o]||DANGER[o])c[NEW[o]||DANGER[o]]=(c[NEW[o]||DANGER[o]]||0)+1;
    if(o>=0x60&&o<=0x7f)i+=o-0x5f;}
  return {len:b.length,c};}
console.log("via_ir",JSON.stringify(prof("out/VUX.sol/VUX.json")));
console.log("legacy",JSON.stringify(prof(process.argv[1]+"/out-legacy/VUX.sol/VUX.json")));' "$SCRATCH"
```

Observed in the originating audit:

| contract | pipeline | body | opcode classes |
|---|---|---|---|
| `VUX` | legacy | 4,266 B | PUSH0 ×109, **MCOPY ×1** |
| `VUX` | `via_ir` | 3,774 B | PUSH0 ×107, **MCOPY ×1** |
| `HardReserve` | legacy | 1,959 B | PUSH0 ×64 |
| `HardReserve` | `via_ir` | 1,710 B | PUSH0 ×35 |

Counts moving is expected and uninformative. **No class appearing or
disappearing** is the result.

### Step 4: Confirm ABI and storage layout are unmoved

```bash
node -e "console.log(JSON.stringify(require('./out/VUX.sol/VUX.json').abi))" | sha256sum
node -e "console.log(JSON.stringify(require('$SCRATCH/out-legacy/VUX.sol/VUX.json').abi))" | sha256sum
forge inspect src/VUX.sol:VUX storageLayout
```

### Step 5: Relocate any finding the counterfactual reattributes

This is the step that changes verdicts. An opcode present in **both** builds is
not caused by the change under review — it belongs to some other setting, and
the finding moves off the sprint's change surface.

Here, `MCOPY` (Cancun) and `PUSH0` (Shanghai) appear in the legacy build too, so
they trace to `evm_version` — left unset and therefore resolving to the pinned
toolchain's default (`forge config` → `prague`), a **pre-existing** condition,
not a sprint-3 regression. Without the counterfactual this is either missed
entirely or written up as a new finding against the wrong node.

### Step 6: Reproduce the necessity failure yourself

Cheap, and it converts a reported claim into a measured one. The mis-invoked
build in Step 2 already does it:

```
Error: Compiler error (…/LValue.cpp): Stack too deep.
Try compiling with `--via-ir` … 178 |  ) = _readSettled(logs);
```

---

## Verification

### What sufficiency looks like

A positive statement replaces an absence argument:

> Across the unchanged subset, `via_ir` introduces no new opcode class (MCOPY
> present in both, PUSH0 counts only decrease), ABIs are byte-identical, and
> storage layouts are unchanged. The Shanghai/Cancun opcodes trace to
> `evm_version`, not to the pipeline change.

### Checklist

- [ ] Every counterfactual subject is byte-unchanged vs the accepted baseline.
- [ ] Old-pipeline build used a scratch `FOUNDRY_OUT` **and** `FOUNDRY_CACHE_PATH`.
- [ ] `foundry.toml` untouched; no `git stash`; tree byte-identical after.
- [ ] Metadata tail stripped and PUSH immediates skipped in the walk.
- [ ] Opcode **classes** compared, not counts and not hashes.
- [ ] ABI hash and storage layout compared.
- [ ] Any shared-in-both opcode reattributed to its real cause.
- [ ] The frozen sibling unit (if one exists) confirmed unaffected via resolved
      config, not file text.

---

## Anti-Patterns

### Don't: report "runtime hashes changed" as the measurement

It differs unconditionally. It is the setup for the question, never the answer.

### Don't: accept "semantics-preserving by specification"

Probably true, and untested on this tree. The subset rebuild costs one build.

### Don't: conclude the experiment is impossible because the tree won't compile

The tree won't. The unchanged subset will — that is the whole technique.

### Don't: reuse the repository's `out/` or `cache/`

Two pipelines sharing a cache yield mixed artifacts, and the diff then measures
the cache rather than the codegen.

### Don't: clean the scratch tree with `rm -rf "$VAR/…"`

`block-destructive-bash.sh` `FR-2-AMBIGUOUS` blocks variable-path `rm -rf`.
Build into a fresh directory name instead of deleting — see
[[probe-cleanup-under-the-destructive-bash-fence]].

---

## Related Memory

### NOTES.md References

- Learnings — "[Review technique — accepted evidence under a changed compilation
  pipeline]": establishes necessity and live-vs-frozen evidence portability.
  This skill supplies the semantic-equivalence half that entry leaves open.
- Learnings — "[Implementation technique — is this bytecode diff semantic?]":
  the within-one-build form; names `evmVersion: cancun → prague` and the general
  class "an unset build setting is a silent dependency on the toolchain's
  default", which Step 5 here confirms from the other direction.

### Related Skills

- [[live-evidence-survives-a-pipeline-change]] — review-side complement
  (evidence portability); this is the audit-side (codegen equivalence).
- [[separate-codegen-from-metadata-in-a-bytecode-diff]] — within-build
  discrimination; supplies the CBOR-stripping mechanics reused in Step 3.
- [[inherited-build-flags-reach-frozen-units]] — the child-unit half: verify the
  frozen sibling against **resolved** config (`FOUNDRY_PROFILE=x forge config`).
- [[assert-the-toolchain-that-produced-the-evidence]] — the counterfactual is
  only meaningful against a pinned compiler.

---

## Changelog

- 1.0.0 (2026-08-13) — extracted from `/audit-sprint sprint-3`, where the
  `via_ir` disposition rested on a specification citation plus a green suite;
  the subset rebuild produced a positive equivalence result and reattributed the
  Shanghai/Cancun opcodes to a pre-existing unset `evm_version`.
