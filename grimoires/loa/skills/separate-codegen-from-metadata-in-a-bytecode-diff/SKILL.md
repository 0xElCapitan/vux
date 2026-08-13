---
name: separate-codegen-from-metadata-in-a-bytecode-diff
description: |
  When a compiler or build-tool change makes contract bytecode hashes differ,
  "the code changed" and "only the metadata hash changed" are indistinguishable
  from the hashes alone — and the difference decides whether you ship or halt.
  Check LENGTH first: identical length with a different hash is the signature of
  a metadata-tail-only change. Prove it by stripping the trailing CBOR blob
  (last two bytes are its big-endian length) and re-hashing the remainder, then
  NAME the cause by diffing the two artifacts' `.metadata` objects — a
  one-line `evmVersion: cancun -> prague` is a finding, "probably metadata" is
  not. A sibling compilation unit that pins the setting explicitly is a free
  control group that turns the inference into proof. The underlying class: any
  build setting left unset is a silent dependency on the toolchain's default.
  Apply on compiler/toolchain upgrades, reproducible-build mismatches,
  deployment-bytecode freezes, and any "is this diff semantic?" question.
loa-agent: implementing-tasks
extracted-from: cycle-002 Foundry v1.5.0 toolchain refreeze — v1.0.0/v1.5.0 parity validation (2026-08-12)
extraction-date: 2026-08-12
version: 1.0.0
tags:
  - solidity
  - solc
  - foundry
  - bytecode
  - metadata
  - cbor
  - reproducible-builds
  - toolchain
  - diff-triage
---

## Problem

A bounded parity check held the repository, both solc pins, and every declared
build setting constant, and varied only the Foundry version. ABIs matched. All
26 method identifiers matched. The vendored Uniswap pool's creation bytecode
matched byte-for-byte. But the two product contracts did not:

```
VUX.creation.sha256          b401e8e1...  ->  fc426937...
VUX.deployed.sha256          26e3fb15...  ->  a0e919c7...
HardReserve.creation.sha256  7c82de05...  ->  d7e27406...
HardReserve.deployed.sha256  1ffda37f...  ->  83dc1a3d...
```

The governing rule was explicit: an unexplained semantic bytecode difference
halts the node. So the question was not "did something change" — obviously — but
"did any *opcode* change". Four different hashes cannot answer that, and neither
can the reflex answer, "it's just metadata."

The failure mode on each side is real. Shrug it off and you ship a silent
codegen change into a monetary contract. Halt on it and you escalate a
cosmetic hash difference to an operator as a possible compiler bug.

---

## Trigger Conditions

### Symptoms

- Contract bytecode hash changed after a toolchain, compiler, or build-tool
  version bump, with no source change.
- Reproducible-build check fails between two environments.
- A deployment-bytecode or init-code-hash freeze fails to reproduce.
- Two builds of the same commit yield different artifacts on different machines.
- The diff is confined to the **tail** of the hex string.
- One compilation unit in the repo moved and a sibling unit did not.

### The discriminating observation

```
VUX.creation.len    22775   (both toolchains)
VUX.deployed.len    15981   (both toolchains)
```

**Identical length, different hash.** Codegen changes almost always move
lengths; the appended metadata hash is fixed-width. This is the cheapest signal
available and it comes free from any snapshot that records lengths — so record
lengths in the snapshot, not just hashes.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity / solc; Foundry `out/**/*.json` artifacts (`.bytecode.object`, `.deployedBytecode.object`, `.metadata`) |
| Environment | Any two builds being compared — versions, machines, CI vs local |
| Timing | Toolchain upgrades, deployment-bytecode freezes, provenance/parity validation |
| Prerequisites | `bytecode_hash` NOT set to `none` (with `none` there is no CBOR tail and this class of difference cannot arise) |

---

## Root Cause

solc appends a CBOR-encoded metadata blob after the program, followed by a
two-byte big-endian length of that blob. The blob contains a hash of the
metadata **JSON**, and that JSON records the compilation settings — including
`evmVersion`.

So any change to a recorded setting changes the metadata hash, therefore the
CBOR tail, therefore the artifact hash — while emitting identical opcodes.

The setting changed here without anyone editing it:

```
-  "evmVersion": "cancun",
+  "evmVersion": "prague",
```

`foundry.toml [profile.default]` deliberately left `evm_version` unset (a
documented decision: it is a property of the deployment chain, to be frozen
later). An unset setting takes the orchestrator's default, and Foundry's default
moved between v1.0.0 and v1.5.0.

**The general class: an unset build setting is a silent dependency on the
toolchain's default version.** It is invisible in the repository, invisible in
review, and surfaces only as an unexplained artifact hash.

---

## Solution

### Step 1: Compare lengths before hashes

If lengths differ, stop — this is a codegen change and the rest of this skill
does not apply. If lengths match, continue.

```bash
jq -r '.bytecode.object' "$ART" | tr -d '\n' | wc -c
```

### Step 2: Strip the CBOR tail and re-hash

The last four hex characters are the big-endian byte length `L` of the CBOR
blob. Remove `(L + 2)` bytes — the blob plus its own length field:

```bash
strip_meta() {
  local h="${1#0x}"
  local n=${#h}
  local L=$((16#${h:n-4:4}))     # last 2 bytes = CBOR length, big-endian
  local strip=$(( (L + 2) * 2 )) # bytes -> hex chars, +2 for the length field
  printf '%s' "${h:0:n-strip}"
}

for C in VUX HardReserve; do
  for K in bytecode deployedBytecode; do
    a=$(strip_meta "$(jq -r ".$K.object" "old/$C.json")")
    b=$(strip_meta "$(jq -r ".$K.object" "new/$C.json")")
    [[ "$a" == "$b" ]] && echo "$C.$K CODE IDENTICAL" || echo "$C.$K CODE DIFFERS"
  done
done
```

Guard the stripper: if `L + 2` exceeds the image length, or the remainder is
empty, you mis-parsed — fail loudly rather than "proving" identity by deleting
everything. When comparing raw strings, print the first differing offset so a
genuine divergence is localized rather than merely reported.

### Step 3: NAME the cause — diff the metadata objects

Code-identical is only half the answer. "It's metadata" without a named cause is
a guess that happens to be right. Diff the metadata itself:

```bash
diff <(jq -S '.metadata.settings' old/VUX.json) \
     <(jq -S '.metadata.settings' new/VUX.json)
```

Then check `.metadata.sources` **separately**. A changed source set or a changed
per-file keccak is a real difference wearing a metadata costume — different file
set, different remapping, different content:

```bash
diff <(jq -S '.metadata.sources' old/VUX.json) \
     <(jq -S '.metadata.sources' new/VUX.json)
```

### Step 4: Use the pinned sibling as a control group

The strongest evidence was already in the repository. Two compilation units were
built by both toolchains:

| unit | `evm_version` | result |
|---|---|---|
| `[profile.v3core]` (vendored Uniswap) | `istanbul`, pinned explicitly | **identical whole-artifact**, metadata included |
| `[profile.default]` (product) | unset | metadata tail moved |

One unit pins the setting and does not move; the other does not pin it and does.
That contrast converts "we believe the cause is the inherited default" into a
demonstrated one, at zero extra cost. Look for such a control before building
one.

### Step 5: Record the finding; do not silently "fix" it

The repair — pinning `evm_version` — is a bytecode-affecting product decision,
usually outside the scope of the node that discovered it. Record:

- there is no semantic divergence today (code byte-identical);
- the *recorded* `evmVersion` in deployed metadata has changed;
- while the setting stays unset, a future toolchain move can change a build
  input with no repository change — which is the actual latent risk, and the
  reason to pin it at the deployment-bytecode freeze.

---

## Verification

### Command

```bash
# per artifact, per bytecode kind
echo "$C.$K CODE IDENTICAL (metadata stripped) len=${#ca} sha256=$ha"
diff <(jq -S 'del(.metadata.sources) | .metadata' old.json) \
     <(jq -S 'del(.metadata.sources) | .metadata' new.json)
```

### Expected Output

```
VUX.bytecode          CODE IDENTICAL (metadata stripped)  len=22666 hex  sha256=3f8ffe9e...
VUX.deployedBytecode  CODE IDENTICAL (metadata stripped)  len=15872 hex  sha256=73771 22c...
HardReserve.bytecode          CODE IDENTICAL (metadata stripped)  len=9366 hex
HardReserve.deployedBytecode  CODE IDENTICAL (metadata stripped)  len=6398 hex

738c738
-     "evmVersion": "cancun",
+     "evmVersion": "prague",
```

Exactly one metadata line differs, `metadata.sources` is identical, and the
stripped code hashes match. That is a closed explanation.

### Checklist

- [ ] Lengths compared before hashes
- [ ] CBOR tail stripped with a guarded length parse
- [ ] Stripped code hashes compared for creation **and** deployed images
- [ ] `.metadata.settings` diffed and the delta named
- [ ] `.metadata.sources` diffed separately (file set + per-file keccak)
- [ ] Compiler identity (`.metadata.compiler.version`) confirmed unchanged
- [ ] ABI and method identifiers confirmed unchanged
- [ ] A pinned sibling unit checked as a control, if one exists
- [ ] Finding recorded with its carry-forward obligation

---

## Anti-Patterns

### Don't: conclude "metadata only" from equal lengths

```bash
# BAD — necessary, nowhere near sufficient
[[ ${#a} -eq ${#b} ]] && echo "just metadata"
```

Equal length is a *hint* that tells you which hypothesis to test first. A
same-length codegen change is entirely possible (a swapped constant, a reordered
comparison). Strip and compare.

### Don't: assume the newer toolchain is right

"It's the new version, so this is the correct output" skips the question. The
direction of a change says nothing about its cause. Identify whether the delta
comes from a changed compiler identity, changed settings, changed sources, or
build orchestration — then judge.

### Don't: diff only `settings` and skip `sources`

`.metadata.sources` is where a genuinely different compilation hides: an extra
file pulled in by a changed resolver, a remapping that now points elsewhere.
Both live under `.metadata`; only one is about configuration.

### Don't: walk stripped bytecode as opcodes without also skipping PUSH immediates

If the reason you are stripping is an opcode census rather than a hash
comparison, stripping metadata is only the first of two traps — PUSH immediate
data reads as instructions too. See `init-code-only-capability-proof`.

### Don't: leave the discovery as a passing check

The check passed; the *cause* is the deliverable. "Bytecode differs, code
identical" is a green light. "Bytecode differs because an unset setting inherits
the toolchain default, and here is the sibling unit that proves it" is a finding
with an owner and a deadline.

---

## Related Resources

- [Solidity — contract metadata & CBOR encoding](https://docs.soliditylang.org/en/latest/metadata.html)
- [Foundry — `evm_version` configuration](https://book.getfoundry.sh/reference/config/solidity-compiler)

---

## Related Memory

### NOTES.md References

- `## Session Continuity`: 2026-08-12 Foundry v1.5.0 toolchain refreeze — the
  v1.0.0/v1.5.0 parity validation and the four stripped-code hashes.
- `## Decision Log`: 2026-08-12 — `evm_version` deliberately not pinned in this
  node; deferred to the deployment-bytecode freeze with evidence recorded.

### Related Skills

- `assert-the-toolchain-that-produced-the-evidence`: the sibling failure mode.
  This skill covers the orchestrator leaking into *what the compiler is told*;
  that one covers it deciding *what reaches the compiler at all*.
- `init-code-only-capability-proof`: shares the CBOR-stripping mechanics for a
  different purpose (proving a capability is absent from runtime bytecode), and
  documents the PUSH-immediate trap for opcode walks.
- `independent-constant-reproduction`: recording compiler identity, settings, and
  the CBOR tail alongside a reproduced constant — the inputs this skill diffs.
- `bound-a-diff-by-preimage-reconstruction`: bounding *which files* changed;
  this skill bounds *what within a compiled artifact* changed.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-12 | Initial extraction |

---

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: implementing-tasks
  phase: /retrospective --scope implementing-tasks
  session: cycle-002 foundry-v1.5-toolchain-refreeze 2026-08-12
```
