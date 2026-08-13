---
name: init-code-only-capability-proof
description: |
  How to prove that a capability present in a contract's constructor does NOT
  survive into the deployed runtime — the claim behind "the sanitization/setup/
  temporary-authority code is init-code only". Reading the source and not finding
  a sweep function proves nothing: that is exactly what the bug looks like when
  the capability arrives via inheritance, a fallback, or a delegatecall. Instead,
  pick a 32-byte constant unique to the capability's code path (its event topic),
  assert it is PRESENT in `.bytecode.object` and ABSENT from
  `.deployedBytecode.object`, and add an opcode census of the runtime image.
  Two traps make a naive bytecode scan produce false results: solc's trailing
  metadata must be stripped, and PUSH immediates must be skipped. Every absence
  assertion needs a positive control, and the metadata stripper needs a guard of
  its own. Apply to constructor-only sanitization, one-shot setup, self-renouncing
  authority, or any audit criterion demanding "runtime bytecode inspection".
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-2 /implement (HardReserve constructor contamination sanitization, AC-5)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - solidity
  - evm
  - bytecode
  - foundry
  - structural-absence
  - audit-evidence
  - constructor
  - negative-testing
---

## Problem

A contract's constructor legitimately does something its runtime must never be
able to do — sweep a pre-existing token balance, hold a transient role, wire a
one-shot dependency. The safety argument is "constructor code is init code; it
is discarded at deployment, so the deployed contract has no such path."

That argument is correct and unprovable by reading. The reviewer needs evidence,
and the two obvious forms are both worthless:

- *"There is no sweep function in the source."* A reviewer can already see that,
  and it is exactly what the failure looks like if the capability arrives from a
  base contract, a fallback, or a `delegatecall` to something that has one.
- *"Assert the runtime bytecode contains no `CALL`."* False: the runtime almost
  certainly makes legitimate external calls, so the property does not hold and
  cannot be the discriminator.

You need a property that is **true iff the capability is absent**, and a scan
whose green cannot be produced by the scan being broken.

---

## Trigger Conditions

### Symptoms

- An acceptance criterion says "runtime bytecode inspection proves no X path
  survives deployment".
- A constructor performs a transfer, grant, or write that the runtime forbids.
- An audit asks you to prove absence of upgradeability, `selfdestruct`, or a
  successor-deployment path.
- You are about to write a comment asserting a structural absence with no
  mechanical check behind it.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity + Foundry; any toolchain emitting `bytecode` and `deployedBytecode` |
| Timing | Writing audit evidence for an immutable, ownerless contract |
| Prerequisites | The capability's code path emits an event, or can be made to |

---

## Root Cause

Init code and runtime code are different byte strings that live in the same
artifact. `bytecode.object` = constructor logic **+ the runtime image it
returns**; `deployedBytecode.object` = only what `CREATE` stored. So a constant
used solely by constructor logic appears in the first and not the second — that
difference is the evidence, and it is mechanically checkable.

Two properties of compiled output break a naive scan:

1. **solc appends CBOR metadata** after the runtime code, followed by a two-byte
   big-endian length of that CBOR section. Those bytes are data. Walking them as
   instructions invents opcodes at random — a `0xf4` inside a metadata hash reads
   as `DELEGATECALL` and fails a true claim.
2. **PUSH1..PUSH32 (`0x60`..`0x7f`) carry immediates.** A byte inside a pushed
   constant is not an instruction. Scanning byte-by-byte reports opcodes that
   never execute. (`PUSH0` = `0x5f` carries none.)

---

## Solution

### Step 1: Pick a marker unique to the capability

A non-anonymous event's topic0 is a 32-byte constant that solc emits as a
`PUSH32` wherever the emitting code lives. If the capability emits one, the
marker already exists.

```solidity
constructor(address weth_, address vux_) {
    uint256 contaminated = IERC20(weth_).balanceOf(address(this));
    if (contaminated != 0) {
        IERC20(weth_).safeTransfer(msg.sender, contaminated);
        emit PreGenesisWethSanitized(contaminated);   // <- the marker
    }
    if (IERC20(weth_).balanceOf(address(this)) != 0) revert NotBornEmpty(...);
}
```

If the path has no event, add one. An event on a constructor-only path is
observability you want anyway, and it buys the proof.

### Step 2: Assert present-in-creation, absent-in-runtime — with the positive control first

```solidity
bytes32 constant SANITIZED_TOPIC = keccak256("PreGenesisWethSanitized(uint256)");

function test_SanitizationMarkerIsInInitCodeAndNotInRuntimeCode() public view {
    bytes memory marker = abi.encodePacked(SANITIZED_TOPIC);

    // Positive control FIRST. Without it, a broken search "proves" the absence.
    assertTrue(Artifact.containsBytes(_creationBytecode(), marker),
        "positive control: the sanitization path IS present in the creation bytecode");
    assertFalse(Artifact.containsBytes(_runtimeBytecode(), marker),
        "the sanitization path is absent from the deployed runtime bytecode");
}
```

Search the **full** image (metadata included) for this claim: for "this constant
is nowhere in the deployed bytes", scanning every byte is the stronger statement.

### Step 3: Strip metadata before any opcode walk

Derive the length from the suffix, so it works whether `bytecode_hash` is `ipfs`
or `none` — the check must not silently depend on a build setting.

```solidity
function stripMetadata(bytes memory code) internal pure returns (bytes memory stripped) {
    if (code.length < 2) return code;
    uint256 metaLen = (uint256(uint8(code[code.length - 2])) << 8)
                    |  uint256(uint8(code[code.length - 1]));
    if (metaLen == 0 || metaLen + 2 > code.length) return code;

    uint256 n = code.length - metaLen - 2;
    stripped = new bytes(n);
    for (uint256 i = 0; i < n; i++) stripped[i] = code[i];
}
```

### Step 4: Walk opcodes, skipping PUSH immediates

```solidity
function countOpcode(bytes memory code, uint8 op) internal pure returns (uint256 n) {
    uint256 i = 0;
    while (i < code.length) {
        uint8 o = uint8(code[i]);
        if (o == op) n++;
        if (o >= 0x60 && o <= 0x7f) i += uint256(o) - 0x5f;  // PUSH1..PUSH32
        i++;
    }
}
```

Then assert the structural absences, again with positive controls:

```solidity
bytes memory runtime = Artifact.stripMetadata(_runtimeBytecode());

assertGt(Artifact.countOpcode(runtime, 0xf1), 0, "positive control: CALL found (the payout)");
assertGt(Artifact.countOpcode(runtime, 0xfa), 0, "positive control: STATICCALL found (balanceOf)");

assertFalse(Artifact.hasOpcode(runtime, 0xf4), "no DELEGATECALL: no proxy or upgrade path");
assertFalse(Artifact.hasOpcode(runtime, 0xf2), "no CALLCODE");
assertFalse(Artifact.hasOpcode(runtime, 0xff), "no SELFDESTRUCT");
assertFalse(Artifact.hasOpcode(runtime, 0xf0), "no CREATE: deploys no successor");
assertFalse(Artifact.hasOpcode(runtime, 0xf5), "no CREATE2: deploys no successor");
```

### Step 5: Guard the stripper — it is the new single point of failure

If `stripMetadata` ever removed the whole image, every opcode-absence assertion
would pass vacuously. Same shape as an over-broad prune list in a source-boundary
gate: green, exactly like the bug.

```solidity
function test_MetadataStrippingRemovesATailAndNotTheProgram() public view {
    bytes memory full = _runtimeBytecode();
    bytes memory stripped = Artifact.stripMetadata(full);

    assertLt(stripped.length, full.length, "a metadata tail was identified and removed");
    assertGt(stripped.length, (full.length * 9) / 10, "and only a tail: the program body survived");
}
```

### Step 6: Reproduce with an implementation that shares no code

Two implementations agreeing is the evidence. One being wrong in the same way as
the other is the failure mode this removes — and a reviewer can read a printed
report without running a test runner.

```bash
# tools/.../inspect-runtime-surface.sh — jq + awk, no Solidity, no forge test.
# hexval/byteat avoid gawk's strtonum so it behaves the same under mawk on CI.
printf '%s\n' "$deployed" | awk '
  function hexval(c,   p) { p = index("0123456789abcdef", tolower(c)); return p - 1 }
  function byteat(s, i) { return hexval(substr(s, i*2+1, 1)) * 16 + hexval(substr(s, i*2+2, 1)) }
  { code = $0; n = length(code)/2
    if (n >= 2) { metalen = byteat(code, n-2) * 256 + byteat(code, n-1)
                  if (metalen > 0 && metalen + 2 <= n) n = n - metalen - 2 }
    i = 0
    while (i < n) { op = byteat(code, i); count[op]++
                    if (op >= 96 && op <= 127) i += op - 95
                    i++ }
    printf "body=%d delegatecall=%d selfdestruct=%d call=%d staticcall=%d\n",
      n, count[244], count[255], count[241], count[250] }'
```

Recompute the event topic in the script too (`cast keccak '<signature>'`), so a
hardcoded constant cannot rot silently.

---

## Verification

### Command

```bash
forge build
forge test --match-path 'test/**/*Surface*'
bash tools/provenance/inspect-runtime-surface.sh
```

### Expected Output

```
ok    sanitization event topic recomputed from its signature
ok    sanitization marker present in the CREATION bytecode (positive control)
ok    sanitization marker absent from the DEPLOYED runtime bytecode — the capability did not survive deployment
      body=3199 create=0 callcode=0 delegatecall=0 create2=0 selfdestruct=0 call=2 staticcall=5
ok    opcode walk verified against known-present opcodes (CALL, STATICCALL)
ok    no DELEGATECALL (no proxy or upgrade path)
```

Record the census verbatim in the sprint/audit artifact. It is the number a
reviewer re-derives, and it changes if the compiler settings change.

### Checklist

- [ ] The marker is unique to the capability's path (not a shared selector)
- [ ] Present-in-creation asserted BEFORE absent-in-runtime
- [ ] Metadata stripped before any opcode walk
- [ ] PUSH immediates skipped in the walk
- [ ] The stripper has its own not-vacuous guard
- [ ] Positive controls for opcodes the runtime genuinely uses
- [ ] A second implementation, sharing no code, reproduces the result
- [ ] Try it dirty: add a `sweep()` and confirm the checks go red, then revert

---

## Anti-Patterns

### Don't: equate source reading with runtime proof

```solidity
// BAD — "no sweep function in the source" is exactly what the bug looks like
// when the capability is inherited, reached through a fallback, or delegatecalled.
/// @notice The deployed contract has no sweep path.
```

### Don't: scan bytes without skipping PUSH data

```solidity
// BAD — reports opcodes that never execute; a 0xff inside a pushed constant
// becomes a phantom SELFDESTRUCT.
for (uint256 i = 0; i < code.length; i++) if (uint8(code[i]) == op) n++;
```

### Don't: forget the metadata tail

Leaving ~53 bytes of CBOR in the walk makes structural-absence results
non-deterministic across source edits, because the metadata hash changes.

### Don't: pick a marker the runtime also uses

The `transfer(address,uint256)` selector is present in both images if the
runtime transfers anything. The marker must be *unique to the constructor path* —
which is why the event topic works and a generic selector does not.

### Don't: let the second implementation share the first one's code

Extracting a shared helper "to avoid duplication" removes the redundancy that
makes agreement evidence. The two hand-maintained copies are the point.

---

## Related Resources

- Solidity docs, "Contract Metadata" — CBOR encoding and the trailing two-byte length
- EVM opcode reference — `0x60`–`0x7f` PUSH1–PUSH32, `0xf0` CREATE, `0xf2` CALLCODE, `0xf4` DELEGATECALL, `0xf5` CREATE2, `0xff` SELFDESTRUCT

---

## Related Memory

### NOTES.md References

- `## Learnings`: "[Implementation technique — proving a capability is absent] … every absence claim needs a positive control in the same test"
- `## Decision Log`: 2026-08-11 `[implement sprint-2]` — recorded runtime census for the Hard Reserve
- `## Observations`: the two accepted-surface lists are hand-maintained duplicates **on purpose**

### Related Skills

- [`abi-surface-claims-scope`](../abi-surface-claims-scope/SKILL.md): the ABI-level companion — proves "no such function", where this proves "no such capability"
- [`default-deny-source-boundary`](../default-deny-source-boundary/SKILL.md): the same "green because it is looking at nothing" hazard, in repository file classification; its cross-check of authority rows is the direct analogue of Step 5

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction (absorbs the positive-control discipline generalized from `default-deny-source-boundary`) |

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
