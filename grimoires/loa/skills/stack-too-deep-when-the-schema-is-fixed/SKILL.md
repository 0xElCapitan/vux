---
name: stack-too-deep-when-the-schema-is-fixed
description: |
  Solidity's legacy codegen fails `Stack too deep` when a single expression needs
  more than the EVM's 16 addressable stack slots — most commonly a wide event
  emit or a function with many live locals. The usual advice ("remove local
  variables") assumes you are free to change the shape of the thing. When the
  shape is fixed by accepted authority — an event schema an indexer contract
  depends on, an ABI a downstream consumer is pinned to — that advice runs out,
  and the decision stops being a coding problem and becomes an architectural one:
  shrink the accepted artifact, hand-roll assembly, or change the compilation
  pipeline. Apply when hitting `Stack too deep` on a wide emit or a long
  function, especially in a repo where the schema is frozen. Provides an ordered
  reduction ladder, the diagnostic that tells you exactly how many slots you are
  short, and the decision framing for when the ladder is exhausted.
loa-agent: implementing-tasks
extracted-from: cycle-002 / sprint-3 (Rig 13-step settlement, 16-field `Settled`)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - solidity
  - stack-too-deep
  - via-ir
  - events
  - frozen-schema
---

## Problem

An accepted event schema fixed `Settled` at 16 fields, 13 of them non-indexed.
Emitting it inside a 13-step settlement function failed:

```
Error: Compiler error (LValue.cpp:50): Stack too deep. Try compiling with
`--via-ir` ... Otherwise, try removing local variables.
   --> src/Rig.sol:425:13
    |
425 |             s.nextOpening,
```

The event shape was not negotiable: it is the settlement record an indexer
reconstructs protocol state from, specified in the accepted architecture
document. "Remove local variables" was also nearly exhausted — the function's
locals were already the minimum the 13 specified steps need.

## Trigger Conditions

### Symptoms

- `Stack too deep` pointing at one of the **last** arguments of an `emit`.
- The same error moving to a *different* argument after each attempted fix.
- `Variable value0 is 1 slot(s) too deep inside the stack` from the ABI encoder's
  inline assembly — the same condition, reported one layer down.

### When to apply

- Wide events (≳12 fields) or functions with many simultaneously-live locals.
- Any repo where the event/ABI shape is fixed by an accepted spec, an indexer
  contract, or a published interface.

### When this does NOT apply

- You control the schema and can simply split the event or the function. Do that
  first; it is strictly simpler than everything below.

## Root Cause

The EVM can only reach 16 stack slots (`DUP16`/`SWAP16`). Legacy codegen
evaluates all of an emit's arguments onto the stack before encoding, so an
N-argument event needs N slots plus whatever the surrounding frame holds.

The specific trap with a memory struct: passing `Settlement memory s` puts the
**pointer at the bottom of the frame**, beneath every argument pushed on top of
it. Reading `s.field` for argument *k* therefore needs to reach depth *k+1*. The
last field of a 16-argument event needs `DUP17`. So the struct — the standard
advice for reducing stack pressure — helps the *function* while being the exact
thing that blocks the *emit*.

The tell that you are close: each fix moves the error to the **next** argument.
That is not the fix failing, it is the fix buying exactly one slot.

## Solution

### The ladder, in order — each rung buys about one slot

**1. Thread the values through a memory struct.** Collapses many live locals in
the enclosing function into one pointer. Necessary but, as above, not sufficient
for the emit itself.

**2. Move the emit into its own frame.** A `private` function taking the struct
starts with a clean stack.

```solidity
function _emitSettled(Settlement memory s) private {
    emit Settled(s.epochId, s.outgoingKing, /* … */);
}
```

**3. Take the deepest reads off the stack entirely.** Two sources cost no slot,
because they are addressed by a compile-time constant or an opcode rather than a
stack offset:

- **storage** — a state variable is `PUSH <slot>; SLOAD`.
- **context opcodes** — `msg.sender` is `CALLER`, `block.timestamp` is `TIMESTAMP`.

So make the **last** argument one of those. Here the final field was the
successor epoch's UPS, already written to storage one step earlier by the same
function, so it was dropped from the struct and read from storage in the emit:

```solidity
s.nextOpening,
epochUPS        // storage read — no stack slot needed to address it
```

Ordering matters: put the zero-cost reads **last**, where the struct pointer is
deepest.

### When the ladder runs out

If you are still one slot short after all three, no further local rearrangement
will help, and the remaining options are architectural — decide explicitly and
record which you chose and why:

| Option | Cost |
|---|---|
| Shrink the event / split into two | Reopens an accepted schema; breaks indexers |
| Hand-roll `log4` in assembly | Bypasses type checking on the protocol's own audit trail |
| Enable `via_ir` (+ optimizer) | Changes the compilation pipeline for that unit |

`via_ir` is the Solidity team's own prescribed resolution for this error and is
semantics-preserving by specification. It is nonetheless a **bytecode-affecting
build change**, so it needs the same treatment as any other: recorded rationale,
and a check on what else inherits it.

Keep every rung of the ladder in the delivered code even after enabling
`via_ir`. They are the evidence that the pipeline change was necessary rather
than reached for first, and they are what a reviewer checks.

## Verification

1. **Count your distance.** Apply one rung; if the error moves to an adjacent
   argument, you gained a slot and the diagnosis is right. If it moves to a
   completely different site, you changed something else.
2. **Confirm the pipeline change was necessary, not convenient** — the retained
   rungs plus a recorded "still one slot short" make this checkable.
3. **Re-run the full suite.** `via_ir` is semantics-preserving in specification;
   confirm it in practice. Here: all 61 pre-existing tests stayed green.
4. **Check what else inherits the setting** — see the related skill; enabling it
   on a shared profile is how it reaches units that must not change.

## Anti-Patterns

- **Reaching for `via_ir` first.** It works immediately, which is exactly why the
  cheaper reductions never get tried and the reviewer cannot tell whether it was
  needed.
- **Reverting the struct/frame/storage reductions after `via_ir` fixes the
  build.** They cost nothing and they are the justification.
- **Silently shrinking the event to make it compile.** The schema is a contract
  with the indexer; changing it to satisfy the compiler is an architecture change
  disguised as a build fix.
- **Assuming a memory struct always reduces stack pressure.** For a wide emit its
  pointer is the thing that runs out of reach.
- **Assembly `log4` as the first workaround.** It removes type checking from the
  protocol's audit trail to save a compiler flag.

## Related Resources

- `src/Rig.sol` — `Settlement` struct, `_emitSettled`, and the comment recording
  all three reductions and why they were still insufficient.
- `foundry.toml` — the `via_ir` rationale block.
- `grimoires/loa/a2a/sprint-3/reviewer.md` §6.1 — the decision as disclosed to
  review, including the reviewer question it raises.

## Related Memory

- [[inherited-build-flags-reach-frozen-units]] — the direct sequel: enabling
  `via_ir` here leaked into a frozen vendored profile by inheritance. If you take
  the third option above, read that one next.

## Changelog

- 1.0.0 (2026-08-13) — extracted from cycle-002 / sprint-3.

## Metadata (Auto-Generated)

- Applications: 1
- Success rate: 1/1
- Last applied: 2026-08-13
