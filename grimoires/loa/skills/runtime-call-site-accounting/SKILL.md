---
name: runtime-call-site-accounting
description: |
  To prove "no alternate runtime path can do X" for a deployed contract, do NOT
  reach for control-flow reachability: solc compiles internal function returns
  as dynamic JUMPs, so any sound (over-approximating) CFG concludes that every
  dispatcher entry reaches every site, which is true, useless, and looks like a
  finished analysis. The technique that works is saturation accounting —
  enumerate every external-interaction opcode in the runtime, bind each site to a
  specific source-level operation using the selector constants materialised
  nearby, and show the count is exactly consumed with none spare. Then invert it:
  enumerate the capability selectors that are ABSENT (`approve`, `transferFrom`),
  because a capability whose selector appears nowhere in the runtime cannot be
  invoked by any path, reachable or not. Apply to sweep/recovery/upgrade absence
  claims, ownerless-vault audits, and any criterion demanding runtime inspection
  rather than source review.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-2 /audit-sprint (HardReserve structural-absence proof)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - security-audit
  - evm
  - bytecode
  - structural-absence
  - static-analysis
  - solidity
  - audit-evidence
---

## Problem

An audit criterion reads: *"runtime bytecode inspection proves no transfer-out /
sweep path survives deployment"*, and explicitly demands attacking **reachable
control flow**, not merely opcode existence.

Opcode census answers a weaker question. `DELEGATECALL: 0`, `SELFDESTRUCT: 0`
proves those capabilities are absent — but the contract legitimately contains
`CALL`, because it pays out during redemption. The real claim is that the
`CALL`s present cannot be driven to move principal along some other path.

The obvious next step — build a CFG, walk forward from each dispatcher entry,
see which entries reach the `CALL` sites — produces this:

```
S_MIN()          entry=0x011e reaches CALL: ['0x508','0x893']  [over-approx: dynamic jump]
backing()        entry=0x0100 reaches CALL: ['0x508','0x893']  [over-approx: dynamic jump]
redeem(...)      entry=0x00b2 reaches CALL: ['0x508','0x893']  [over-approx: dynamic jump]
```

Every view function "reaches" every `CALL`. The analysis is sound and carries
zero information.

## Trigger Conditions

### Symptoms

- An acceptance criterion demands proof about the **deployed runtime**, not the source.
- A capability must be shown unreachable while related opcodes are legitimately present.
- A reachability walk marks every entry point as reaching every site.
- The audit brief says "attack reachable control flow, not merely opcode existence".

### Error Messages

None — the failure mode is a *degenerate result*, not an error:

```
[over-approx: dynamic jump]
```

Every entry reaching every site is the signal that the method has collapsed.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | EVM runtime bytecode; solc output; Foundry artifacts |
| Environment | Audit of an immutable/ownerless contract with structural-absence claims |
| Timing | After opcode census establishes which capabilities exist at all |
| Prerequisites | Build artifacts with `deployedBytecode`, `bytecode`, `methodIdentifiers` |

## Root Cause

solc implements internal function calls by pushing a return address and using a
**dynamic `JUMP`** to come back. A statically sound CFG cannot know the runtime
stack, so it must treat a dynamic `JUMP` as potentially targeting **every**
`JUMPDEST`. Because solc heavily shares helper code (ABI decoding, memory
allocation, `SafeERC20`), every entry point funnels through shared blocks that
end in dynamic jumps — so the over-approximation immediately saturates.

Over-approximation is the right choice for soundness (an "unreachable" verdict
from it would be trustworthy), but on solc output it never produces one.

The insight: **you do not need reachability if the budget is exhausted.** If the
contract's specified behaviour requires exactly N external calls and the runtime
contains exactly N call opcodes, there is no spare site for an alternate path to
use — regardless of which entry points can reach what.

## Solution

### Step 1: Census the external-interaction opcodes over the stripped program body

Strip solc's CBOR metadata first (validate the strip: assert it removed a tail
and not the program), and skip PUSH immediates so data is never walked as code.

```
CALL: 2   CALLCODE: 0   DELEGATECALL: 0   STATICCALL: 5
CREATE: 0   CREATE2: 0   SELFDESTRUCT: 0
```

### Step 2: Predict the budget from the specification

Read the source and count the external interactions the contract is *supposed*
to make:

| Operation | Opcode | Expected |
|---|---|---|
| `vux.burnForRedemption(...)` | CALL | 1 |
| `weth.transfer(...)` via SafeERC20 | CALL | 1 |
| `weth.balanceOf` ×3 (`backing`, `previewRedeem`, `redeem`) | STATICCALL | 3 |
| `vux.totalSupply` ×2 (`previewRedeem`, `redeem`) | STATICCALL | 2 |

Predicted: 2 CALL, 5 STATICCALL. Predict **before** counting.

### Step 3: Bind each site to its operation via nearby selector constants

Locate every `PUSH4` in the runtime and disassemble a window around each call site.

```
0x4cb  PUSH4 0xdb6b1b4f          -> IVUX.burnForRedemption(address,uint256)
0x4fa  EXTCODESIZE ... ISZERO    -> high-level call's code-existence check
0x507  GAS
0x508  CALL                       <== bound to burnForRedemption
0x7ee  PUSH4 0xa9059cbb          -> IERC20.transfer(address,uint256)
0x893  CALL                       <== bound to SafeERC20 _callOptionalReturn
```

Also read the **value** operand: `PUSH0` immediately in the stack build-up means
0 wei, confirming no ether movement.

Budget consumed: 2 of 2 CALL, 5 of 5 STATICCALL. **Zero spare sites.**

### Step 4: Invert — enumerate the ABSENT capability selectors

This is the strongest part and requires no reachability at all. An external call
must materialise its target selector somewhere in the runtime.

```
present : 18160ddd totalSupply | 70a08231 balanceOf | a9059cbb transfer | db6b1b4f burnForRedemption
absent  : 095ea7b3 approve     | 23b872dd transferFrom
```

`approve` absent ⇒ the contract can never delegate spending authority over its
principal. `transferFrom` absent ⇒ it can never pull. No control-flow argument is
needed: the capability is not expressible in this bytecode.

### Step 5: Close with the dispatcher and the hooks

Recover the selector table **from the bytecode** (not the ABI JSON) and
cross-check it against the ABI; confirm exactly one non-view entry; confirm no
`receive`/`fallback` by calling an unknown selector and empty calldata against a
live deployment.

### Step 6: Corroborate dynamically

Fund a deployed instance and attempt every plausible capability shape
(`sweep`, `rescue`, `recover`, `withdraw`, `emergencyWithdraw`,
`transferOwnership`). All must revert with the balance unmoved.

## Verification

### Command

```bash
python evm_audit.py            # census + dispatcher recovery + site binding
forge test --match-test NoRuntimeSweep -vv
```

### Expected Output

```
opcode census: {'CALL': 2, 'STATICCALL': 5, 'DELEGATECALL': 0, 'SELFDESTRUCT': 0}
dispatcher selectors recovered from BYTECODE: 6
  bytecode-vs-ABI  extra=none  missing=none
CALL sites at: ['0x508', '0x893']   (both bound, none spare)
absent capability selectors: approve, transferFrom
[PASS] test_NoRuntimeSweepEntryPoint()
```

### Checklist

- [ ] Metadata stripped, and the strip itself guarded (removed a tail, not the program)
- [ ] PUSH immediates skipped
- [ ] Positive controls: the walk finds opcodes known to be present
- [ ] Budget predicted from source **before** counting
- [ ] Every call site bound to a named operation via its selector
- [ ] Value operand checked at each site
- [ ] Absent capability selectors enumerated explicitly
- [ ] Dispatcher recovered from bytecode and cross-checked against the ABI
- [ ] Dynamic corroboration against a live deployment

## Anti-Patterns

### Don't: report an over-approximated reachability result as analysis

```
# BAD - sound, saturated, and says nothing
redeem()  reaches CALL: [0x508, 0x893]
backing() reaches CALL: [0x508, 0x893]
```

If every entry reaches every site, the method has failed. Say so and switch
techniques rather than presenting it as coverage.

### Don't: conclude from opcode counts alone

`CALL: 2` is not by itself reassuring — two calls could be one legitimate payout
and one sweep. The count means something only once each site is **bound** to a
specific source operation and the budget is shown exhausted.

### Don't: trust the ABI JSON for the dispatcher

Recover selectors from the bytecode and use the ABI only as a cross-check.
Agreement between two independently derived tables is the evidence; either one
alone is an assumption.

## Related Memory

### NOTES.md References

- `## Learnings`: "[Audit technique — runtime capability accounting]" (added 2026-08-11).

### Related Skills

- `init-code-only-capability-proof`: proves a capability is *absent* from the runtime (topic marker + opcode census). This skill handles the harder case — the opcode is legitimately *present* and must be shown bounded.
- `abi-surface-claims-scope`: scope absence claims to `.methodIdentifiers`, not artifact text.

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction |

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
