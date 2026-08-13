---
name: parity-proves-emission-not-admission
description: |
  A toolchain, compiler, bundler, or runtime migration that claims "changes
  nothing else" is normally defended with output parity — identical bytecode,
  identical artifacts, identical ABI. That evidence is real but it only covers
  what the tool EMITS. It says nothing about what the tool ACCEPTS. A version
  bump can leave every output byte-identical while widening the set of files the
  tool will admit as input, which silently converts a latent enforcement gap into
  a reachable one. Verified live: Foundry v1.0.0 refuses a non-`.sol` source with
  `Error: unexpected file extension`; v1.5.0 compiles and executes it — while
  producing byte-identical executable code for everything else. Apply when
  reviewing any dependency/toolchain migration that asserts scope neutrality,
  especially when a known latent gate weakness exists in the same area. The move
  is to re-run the known-weakness probe under BOTH the old and new versions and
  diff the ADMISSION result, not the output.
loa-agent: reviewing-code
extracted-from: cycle-002 Foundry v1.5.0 toolchain refreeze focused review (2026-08-12)
extraction-date: 2026-08-12
version: 1.0.0
tags:
  - code-review
  - toolchain
  - migration
  - provenance
  - supply-chain
  - scope-review
  - foundry
  - solidity
  - latent-defects
---

## Problem

A migration node moves a build toolchain to a new version and asserts the change
is scope-neutral. The evidence offered is output parity, and it is genuinely
strong:

- every solc pin unchanged and self-reported by the compilers that ran
- ABIs identical, method identifiers identical
- executable code byte-identical once metadata is stripped
- the one explicitly-pinned profile identical whole-artifact

All of that is true and all of it is verifiable. It is also **the wrong axis for
one specific class of risk**.

A build orchestrator does two separable things: it decides *what reaches the
compiler*, and it decides *how the compiler is invoked*. Output parity tests the
second. Nothing in a parity comparison tests the first, because a file the old
version refused to admit never appears in either build's output — so it cannot
show up as a difference.

The consequence is a scope change that reads as scope neutrality:

> A provenance gate enumerates source by filename extension. A file with the
> wrong extension is invisible to it. Under the **old** toolchain that gap was
> unreachable — the orchestrator refused the file outright. Under the **new**
> toolchain the same file compiles, lands in `metadata.sources`, and executes.
> The gate did not change. The weakness did not change. **The reachability
> changed**, and it changed because of the migration.

A review that only checks emitted bytes will approve this and record the
migration as provenance-neutral.

---

## Trigger Conditions

### Symptoms

- A migration/refreeze node claims "changes only X and nothing else"
- The scope-neutrality argument rests on output comparison (bytecode, artifact
  hashes, ABI, checksums, snapshot diffs)
- A known latent enforcement gap exists in the same subsystem — typically graded
  "real but unexploited", "latent in the tooling", or carried forward
- The migrated component sits *between* the inputs and the compiler/executor:
  build orchestrator, module resolver, bundler, loader, test runner, linter host
- The scope statement enumerates settings, versions, and dependencies — but says
  nothing about what the tool accepts as input

### When it does NOT apply

- The migrated component is a pure output-side tool (formatter, minifier,
  reporter) with no say over which inputs are admitted
- No latent enforcement gap exists in the area — there is nothing for widened
  admission to expose

---

## Root Cause

Enforcement gates and build orchestrators key on **different universes**, and
only the orchestrator's universe moves with a version bump.

| universe | defined by | moves on toolchain upgrade? |
|---|---|---|
| what the gate enumerates | filesystem predicate (`find -iname '*.sol'`) | no |
| what the compiler sees | the orchestrator's admission policy | **yes** |

Parity testing compares two builds' *outputs*. Both builds draw from the
orchestrator's universe. A file admitted by neither version is absent from both
outputs; a file admitted by only the new version appears in only the new
output — but a parity check on *existing* contracts will never surface it,
because nobody added that file to the repository. The exposure is created before
any file exists to detect.

So the risk is invisible to the strongest evidence the node produced, and it is
invisible precisely *because* that evidence is strong.

---

## Solution

Run the known-weakness probe under **both** versions and diff the admission
result.

### 1. Identify the latent gap already on record

Read the carried-forward findings. Anything of the form "the gate keys on X but
the real universe is Y" is a candidate — extension-keyed inventories, path-keyed
allowlists, glob-based scanners.

### 2. Build the minimal probe in a throwaway project

Never in the reviewed tree — the subject must stay byte-identical.

```bash
P="$SCRATCH/probe"; mkdir -p "$P/src" "$P/test"
# a source file the gate cannot see, explicitly imported from a file it can
cat > "$P/src/Arbitrary.txt" <<'EOF'
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;
contract FromTxt { function tag() external pure returns (string memory) { return "reached"; } }
EOF
# ... plus src/Main.sol importing it, and a test that deploys and calls it
```

### 3. Run it under the NEW version — establish reachability

```bash
forge build --force && forge test
```

Confirm from the compiler's own record, not from a diagnostic:

```bash
python -c "import json;print(sorted(json.load(open('out/Main.sol/Main.json'))['metadata']['sources']))"
# ['src/Arbitrary.txt', 'src/Main.sol', 'src/NoExtension']
```

### 4. Run the SAME project under the OLD version — this is the step nobody does

```bash
~/.foundry/versions/v1.0.0/forge.exe build --force
# Error: unexpected file extension
# EXIT=1
```

### 5. Confirm the gate is blind to it either way

```bash
find . \( -type f -o -type l \) -iname '*.sol' | sort
# src/Main.sol, test/M1.t.sol  — the odd-extension sources are ABSENT
```

### 6. Classify the delta

| old admits | new admits | classification |
|---|---|---|
| no | no | gap unreachable under both — inherited, unchanged by the migration |
| yes | yes | gap reachable under both — genuinely inherited, migration is neutral here |
| **no** | **yes** | **the migration CREATES the reachable form — scope change, must be disclosed** |
| yes | no | migration narrows exposure — note it, it may hide a regression elsewhere |

Only the third row is a finding against the migration's scope claim.

---

## Verification

The technique is confirmed when the two runs disagree on admission while the
parity evidence holds:

```
v1.5.0:  [PASS] test_OddExtensionSourcesExecute   metadata.sources = 3 files
v1.0.0:  Error: unexpected file extension          EXIT=1
```

and, in the same review:

```
VUX creation  code (CBOR-stripped)  14d19d5d…  identical across BOTH versions
VUX deployed  code (CBOR-stripped)  e1878fab…  identical across BOTH versions
```

Byte-identical emission, divergent admission. Both facts true simultaneously —
that is the whole point.

---

## Severity Guidance

The delta is a **disclosure** finding, not automatically a blocking one. Grade it
on whether the exposure is bounded:

- Does the current subject contain any file that exploits it? (enumerate — do not
  assume)
- Does exploitation require a deliberate act inside an authorized location
  (an explicit `import`), or is it passive?
- Is there a binding gate before the next node that could introduce one?
- What is the cost of *not* migrating? A live local-vs-CI evidence split is
  usually worse than a latent gap behind a binding gate.

In the source case all four favored landing: zero odd-extension sources present,
exploitation required an explicit import from an authorized root, the gap was
already a binding pre-next-sprint condition, and staying on the old version
preserved an active evidence divergence. The finding was MEDIUM, non-blocking,
and asked only that the widening be *stated* — not remediated in that node.

---

## Anti-Patterns

**Treating output parity as scope proof.** "Bytecode is byte-identical, so the
migration changed nothing" is a non-sequitur. It proves codegen equivalence for
the inputs both versions accepted.

**Reading the two facts separately.** The reviewed authority document contained
both halves — the old version's hard-fail in one section, the new version's
reachability in another — and drew no conclusion. Facts in adjacent sections are
not a finding until someone joins them.

**Assuming the gap is inherited.** "This weakness predates the migration" is the
default assumption and it was wrong here. Test it; do not infer it.

**Probing inside the reviewed tree.** Use a throwaway project outside the
repository and re-verify the subject fingerprint at exit.

**Trusting a resolver diagnostic over compiler evidence.** The new version prints
`Unable to resolve imports` in the *same run* that compiles and executes the
file. Read `metadata.sources` and an executed deployment — see the sibling skill
`resolver-diagnostic-is-not-reachability`.

---

## Related Memory

- `skills-pending/assert-the-toolchain-that-produced-the-evidence` — the
  implementer-side sibling: the same v1.0.0/v1.5.0 asymmetry, but concluding
  that toolchain identity must be *asserted fail-closed*. This skill starts from
  the same fact and draws the reviewer's conclusion instead: the asymmetry is a
  **scope change** that output-parity evidence structurally cannot detect.
- `skills-pending/resolver-diagnostic-is-not-reachability` — why admission must
  be read off `metadata.sources` and execution, never a resolver warning.
- `skills-pending/gate-gap-reachability-triage` — grading a gate gap once
  reachability is established.
- `skills-pending/separate-codegen-from-metadata-in-a-bytecode-diff` — how to
  establish the emission-parity half correctly.
- NOTES.md `## Learnings` — cycle-002 Foundry v1.5.0 refreeze review, finding T-2.
