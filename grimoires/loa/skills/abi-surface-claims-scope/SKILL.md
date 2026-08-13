---
name: abi-surface-claims-scope
description: |
  A test asserting that a symbol does NOT exist on a compiled contract must scan
  the dispatcher table, not the artifact file. Forge/Hardhat artifacts embed
  `rawMetadata`, which contains solc's `devdoc`/`userdoc` — so the NatSpec comment
  that *documents the deletion* of a function puts that function's name back into
  the artifact text, and a whole-file search fails while the ABI is genuinely
  clean. Apply whenever proving absence of an authority surface (`burnFrom`,
  `owner`, `pause`, `upgradeTo`, `sweep`) against compiled output, or when an
  absence test fails and grep confirms the function is not declared. The fix is
  to scope the claim to `.methodIdentifiers` (or `.abi` with `stateMutability`),
  and to pair it with a runtime dispatch negative.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-2 /implement (VUX token, AC-2 "no burnFrom symbol exists in the ABI")
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - solidity
  - foundry
  - abi
  - structural-absence
  - negative-testing
  - build-artifacts
  - test-design
---

## Problem

You need a mechanical test for "function `X` does not exist on this contract" —
the kind of claim an audit acceptance criterion makes about an authority surface.
The obvious implementation reads the build artifact and asserts the name is
absent from it. This reads as *stronger* than checking the ABI array, because it
covers the ABI, the method-identifier table and the metadata all at once.

It is not stronger. It is wrong, and it fails in the direction that wastes time:
**the test goes red while the contract is correct**.

Worse is the case where it stays green for the wrong reason. Rename the function
you are excluding, or drop the documenting comment, and the same test passes
without asserting anything about the surface.

---

## Trigger Conditions

### Symptoms

- An absence assertion over a build artifact fails, but `grep` of the source
  confirms the function is not declared anywhere.
- The failing symbol appears in the artifact only inside prose.
- An absence test's result changes when a comment is edited.
- You are about to write "assert the artifact JSON does not contain `<name>`".

### Error Messages

```
[FAIL: AssertionFailed("no burnFrom symbol anywhere in the artifact: expected false")]
```

Then, locating it:

```bash
grep -o '.\{80\}burnFrom.\{60\}' out/VUX.sol/VUX.json
# ... **No general `burnFrom`.** The allowance-gated burn of an ancestor is deliber ...
```

That is the contract's own `@dev` NatSpec, round-tripped through solc metadata.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity + Foundry (`out/<File>.sol/<Contract>.json`); the same applies to Hardhat artifacts |
| Timing | Writing structural-absence tests against compiled output |
| Prerequisites | Contract carries NatSpec that mentions the excluded symbol — i.e. good documentation |

---

## Root Cause

A forge artifact is not the ABI. It is a bundle:

| Field | Contains | Is it the surface? |
|---|---|---|
| `.abi` | function/event/error entries with `stateMutability` | yes |
| `.methodIdentifiers` | `{"signature": "selector"}` for every dispatchable function | yes — this IS the dispatcher table |
| `.bytecode` / `.deployedBytecode` | compiled code | indirectly |
| `.rawMetadata` / `.metadata` | solc metadata JSON, **including `output.devdoc` and `output.userdoc`** | no — this is documentation |

Because NatSpec is compiled into `devdoc`, documenting a deliberate omission is
enough to reintroduce the string. The better the comment, the more certain the
failure. Any absence claim whose scope includes documentation is a claim about
prose, and prose is exactly what a reviewer can already read for themselves —
the test adds nothing and costs a false negative.

---

## Solution

### Step 1: Scope the claim to the dispatcher table

`.methodIdentifiers` keys are precisely the signatures the contract routes.
Nothing else belongs in an absence claim about the surface.

```solidity
// test/harness/Vm.sol — declare the cheatcode once
function parseJsonKeys(string calldata json, string calldata key)
    external pure returns (string[] memory keys);
```

```solidity
function test_NoBurnFromSignatureIsDispatchable() public view {
    string[] memory signatures =
        vm.parseJsonKeys(vm.readFile("out/VUX.sol/VUX.json"), ".methodIdentifiers");

    bool sawPositiveControl;
    for (uint256 i = 0; i < signatures.length; i++) {
        if (_contains(signatures[i], "burnForRedemption")) sawPositiveControl = true;
        assertFalse(_contains(signatures[i], "burnFrom"),
            string.concat("a burnFrom-like signature is dispatchable: ", signatures[i]));
    }
    // A scan that silently found nothing would "prove" the absence claim.
    assertTrue(sawPositiveControl, "positive control: the scan does find a burn signature that IS present");
}
```

### Step 2: Prefer the exact-set assertion over name blacklists

A blacklist only excludes names you thought of. Asserting the *complete* set in
both directions excludes everything you did not.

```solidity
string[] memory actual   = vm.parseJsonKeys(vm.readFile(ARTIFACT), ".methodIdentifiers");
string[] memory accepted = _acceptedAbi();

assertEq(actual.length, accepted.length, "external function count");
for (uint256 i = 0; i < accepted.length; i++)
    assertTrue(_in(actual, accepted[i]),  string.concat("missing: ", accepted[i]));
for (uint256 i = 0; i < actual.length; i++)
    assertTrue(_in(accepted, actual[i]),  string.concat("unexpected: ", actual[i]));
```

Keep a named-negative test too, even though it is redundant: an audit checklist
is a list of names, and a reviewer should be able to match it to assertions
one-for-one.

### Step 3: Add the runtime dispatch negative

An ABI can in principle omit a function the bytecode still routes.

```solidity
(bool ok,) = address(token).call(
    abi.encodeWithSignature("burnFrom(address,uint256)", victim, 1e18));
assertFalse(ok, "burnFrom must not be dispatchable");
assertEq(token.balanceOf(victim), before, "victim balance untouched");
```

### Step 4: Use `.abi` when the claim needs mutability

`.methodIdentifiers` cannot tell you which functions are state-changing.
"Exactly one mutator, and it is `redeem`" needs `stateMutability`, which is easiest
outside Solidity:

```bash
jq -r '[.abi[] | select(.type=="function"
        and .stateMutability!="view" and .stateMutability!="pure") | .name] | join(" ")' \
   out/HardReserve.sol/HardReserve.json
# redeem

jq -r '[.abi[] | select(.type=="receive" or .type=="fallback") | .type] | join(" ")' \
   out/HardReserve.sol/HardReserve.json
# (empty)
```

---

## Verification

### Command

```bash
forge build && forge test --match-test NoBurnFrom
grep -c 'burnFrom' out/VUX.sol/VUX.json     # non-zero is FINE — it is the NatSpec
jq -r '.methodIdentifiers | keys[]' out/VUX.sol/VUX.json | grep -c 'burnFrom'   # must be 0
```

### Expected Output

```
[PASS] test_NoBurnFromSignatureIsDispatchable()
[PASS] test_NoBurnFromEntryPointExistsAtRuntime()
[PASS] test_ExternalSurfaceIsExactlyTheAcceptedSet()
```

### Checklist

- [ ] The absence claim reads `.methodIdentifiers` or `.abi`, never the whole file
- [ ] A positive control asserts the scan finds a related symbol that IS present
- [ ] An exact-set assertion runs in both directions
- [ ] A runtime low-level call confirms the selector is not routed
- [ ] Editing a comment does not change any test result

---

## Anti-Patterns

### Don't: search the artifact file

```solidity
// BAD — rawMetadata embeds devdoc, so the NatSpec documenting the deletion
// puts the symbol back. Red while the contract is correct; and green for the
// wrong reason once the comment changes.
assertFalse(_contains(vm.readFile(ARTIFACT), "burnFrom"), "no burnFrom");
```

### Don't: search the source text

```bash
# BAD — a reviewer can already do this, so it adds no evidence, and it misses
# a function arriving through inheritance, which is the case that matters.
! grep -q 'function burnFrom' src/VUX.sol
```

### Don't: assert an absence without a positive control

A broken scan and a true absence produce the same green. Whatever the medium —
ABI keys, bytecode, a file list — assert that the search finds something you
know is there before trusting that it did not find something you hope is not.

### Don't: rely on a name blacklist alone

`sweep`, `rescue`, `withdraw`, `drain`, `emergencyExit`, `adminCall` … the list
is unbounded. Assert the complete accepted set; keep the blacklist only as
reviewer-facing documentation.

---

## Related Resources

- Foundry artifact schema — `out/<File>.sol/<Contract>.json`
- Solidity docs, "Contract Metadata": `output.devdoc` / `output.userdoc` are part of the metadata JSON

---

## Related Memory

### NOTES.md References

- `## Learnings`: "[Implementation technique — artifact-scoped surface tests] A whole-artifact text search is NOT a surface test."
- `## Decision Log`: 2026-08-11 `[implement sprint-2]` — token external surface asserted as an exact 20-signature set

### Related Skills

- [`init-code-only-capability-proof`](../init-code-only-capability-proof/SKILL.md): the bytecode-level companion — same positive-control discipline, applied to opcodes rather than signatures
- [`default-deny-source-boundary`](../default-deny-source-boundary/SKILL.md): the "green because it is looking at nothing" failure in a third medium (repository file classification)

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction |

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
  phase: /implement sprint-2
  session: cycle-002-sprint-2
```
