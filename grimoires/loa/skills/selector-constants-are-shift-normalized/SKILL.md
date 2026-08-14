---
name: selector-constants-are-shift-normalized
description: |
  A call-site's four-byte function selector is NOT reliably present as those four
  bytes in compiled EVM bytecode. Under `via_ir` + optimizer, solc normalizes the
  constant by shifting out its trailing zero bits and compensating in the `SHL`
  amount — `burn(uint256)`'s `0x42966c68` is emitted as `PUSH4 0x0852cd8d; PUSH1
  0xe3; SHL`, so a raw substring search for `42966c68` finds nothing. Because the
  usual claim being made is an ABSENCE ("this contract contains no call to
  `HardReserve.redeem`"), the failure is silent and confidence-inverting: the
  search returns empty and the test goes green while proving nothing. Apply when
  writing or reviewing any bytecode-level claim about outbound calls — structural
  absence suites, call-site accounting, capability audits — especially on a suite
  that had optimization enabled after it was written. Fix by enumerating every
  legal shift, and by keeping a positive control that fails when the enumeration
  is wrong.
loa-agent: implementing-tasks
extracted-from: cycle-002 / sprint-4 task 4.8 (FR-10.3 no-redeem-call-site proof)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - foundry
  - solidity
  - via-ir
  - optimizer
  - bytecode
  - structural-absence
  - positive-control
  - audit-technique
---

## Problem

A test asserting that a contract contains no call site for three monetary-core
authorities — and, as its positive control, that the one call it *does* make is
present — failed on the control:

```
AssertionFailed("control: the F-46 self-burn call site IS present: expected true")
```

The three absence assertions had passed. Had the control not been there, the
test would have been green, and it would have proven **nothing**: the search was
broken, and a broken search and a true absence are indistinguishable from their
result.

The contract demonstrably makes the call — a separate behavioural test observed
the burn reduce `totalSupply` by exactly the credited amount.

## Trigger Conditions

### Symptoms

- A selector known to be called does not appear in `deployedBytecode.object`.
- Some outbound selectors are found and others are not, in the *same* function.
- A bytecode absence suite goes green immediately after `via_ir`/`optimizer` is
  enabled, with no source change.

### The diagnostic that localizes it

Extract the operands of the selector-materialisation idiom instead of searching
for one selector, and compare the recovered set against the calls the source
makes:

```bash
node -e "
const d=require('./out/C.sol/C.json').deployedBytecode.object.toLowerCase().replace(/^0x/,'');
const seen=new Set(); let i=0;
while((i=d.indexOf('60e01b',i))!==-1){ const s=d.slice(i-8,i); if(/^[0-9a-f]{8}\$/.test(s)) seen.add(s); i+=6; }
console.log([...seen].sort().join(' '));
"
```

A selector that is called but absent from this set is the tell — and note the
scan itself is *also* wrong, for the same reason: it hard-codes `60e01b`.

### Context

| Context | Value |
|---|---|
| Technology | Solidity ≥ 0.8 with `via_ir = true` + `optimizer = true` |
| Applies to | Any claim about outbound calls read from bytecode |
| Also affects | Selector *presence* accounting (call-site census, capability audit) |

## Root Cause

To build calldata, the compiler needs the selector left-aligned in a word:
`selector << 224`. The IR optimizer treats that as ordinary constant arithmetic
and is free to re-associate it. If the selector has `s` trailing zero bits, then

```
selector << 224  ==  (selector >> s) << (224 + s)
```

and the right-hand side is what gets emitted, because the optimizer's constant
representation prefers the smaller operand. `burn(uint256)`:

```
0x42966c68 has 3 trailing zero bits
0x42966c68 >> 3 = 0x0852cd8d
emitted: 63 0852cd8d   60 e3   1b
         PUSH4         PUSH1   SHL
              ^ not 0x42966c68  ^ 0xe0 + 3
```

`principalUnits()` (`0x2031b3dd`, zero trailing zero bits) is emitted as
`PUSH4 0x2031b3dd; PUSH1 0xe0; SHL` and *is* found by a naive search — which is
exactly why the failure looks arbitrary: within one function, one selector is
findable and another is not, decided by the low bits of a hash.

The legacy pipeline does not do this, so a suite written before optimization was
enabled keeps passing and silently stops meaning anything.

## Solution

### Step 1: enumerate every legal shift

Only shifts the selector survives losslessly are candidates; check the byte
pattern for each.

```solidity
/// @dev True when `runtime` contains the `PUSH4 (sel >> s); PUSH1 (0xe0+s); SHL`
///      idiom for any shift `s` that `sel` can survive.
function _hasCallSite(bytes memory runtime, bytes4 selector) private pure returns (bool) {
    uint32 sel = uint32(selector);
    for (uint256 s = 0; s < 8; s++) {
        uint32 shifted = sel >> s;
        if (shifted << s != sel) continue;          // the compiler cannot use this shift
        bytes memory pattern = abi.encodePacked(
            bytes1(0x63), bytes4(shifted), bytes1(0x60), bytes1(uint8(0xe0 + s)), bytes1(0x1b)
        );
        if (_containsBytes(runtime, pattern)) return true;
    }
    return false;
}
```

`s < 8` covers every selector: a selector with 8+ trailing zero bits would be
emitted as `PUSH3` or shorter, so extend the loop and the opcode byte together if
a project ever needs it — or assert `s` never exceeded the loop, so the day it
does is a failure rather than a false absence.

### Step 2: keep a positive control, and make it a *hard* one

The control must exercise the same code path as the claim, on something known to
be present:

```solidity
assertFalse(_hasCallSite(runtime, bytes4(keccak256("redeem(uint256,address)"))), "no redeem");
assertTrue(_hasCallSite(runtime, bytes4(keccak256("burn(uint256)"))),            "control");
```

Pick a control that is *unlike* the subject: the burn is the one with the awkward
shift, which is precisely why it makes a good control.

### Step 3: prefer a claim that does not depend on codegen at all

The stronger statement is that the contract cannot even *name* the authority.
The compiler records its own source set in every artifact:

```solidity
string[] memory sources = vm.parseJsonKeys(vm.readFile(ARTIFACT), ".metadata.sources");
assertFalse(_contains(sources, "src/interfaces/IVUXMintable.sol"), "cannot name mint");
assertTrue(_contains(sources, "src/interfaces/IVUXBurnable.sol"),  "control: can name burn");
```

This survives every optimizer setting, and it defeats a computed-selector call as
well — a bytecode scan cannot. Use it as the primary proof and the shift-robust
scan as corroboration, not the other way round.

## Verification

```bash
forge test --match-test NoCoreAuthoritySelector -vv
```

Both the absence assertions and the two positive controls pass. Then mutate to
confirm the test can fail: temporarily search for the raw 4-byte selector and
watch the control go red — that is the exact failure this skill exists to make
loud.

### Checklist

- [ ] Every absence assertion has a positive control in the same test
- [ ] At least one control uses a selector with nonzero trailing zero bits
- [ ] The scan enumerates shifts rather than one encoding
- [ ] A source-set (`metadata.sources`) claim carries the primary argument
- [ ] The test was seen to fail once, deliberately

## Related

- `runtime-call-site-accounting` (approved) — call-site census that binds each
  `CALL` to a selector materialised nearby. Its method assumes the `s = 0`
  encoding; under `via_ir` the operand it looks for is shifted, so pair it with
  this skill before trusting a budget derived that way.
- `init-code-only-capability-proof` (pending) — carries the positive-control
  discipline as its core rule. This is the sharpest instance of *why*: the
  control was the only thing standing between a broken search and a false
  structural-absence claim in an audit-bound report.
- `optimizer-folds-context-reads-across-cheatcodes` (pending) — the same shape in
  a different medium: enabling optimization on an existing suite converts working
  assertions into vacuous ones with no source change and no warning.
