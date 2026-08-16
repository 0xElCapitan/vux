---
name: streaming-attribution-by-exclusion-then-refine
description: |
  An indexer must join an effect (a token transfer, a state delta) to its cause
  event in the same transaction — but at every emission site the effect is logged
  BEFORE its cause, so a streaming handler seeing the effect cannot yet know the
  cause. Apply when building event-driven ETL that classifies changes by a
  co-emitted cause event. Provides the write-on-effect-with-default,
  refine-on-cause pattern and the residual class it makes correct.
loa-agent: implementing-tasks
extracted-from: sprint-6-task-6.4 (VUX v1, ponder indexer attribution)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - indexing
  - etl
  - event-sourcing
  - ponder
---

## Problem

The specification says each supply change is joined to "the cause event emitted in
the same transaction". Implementing that in a streaming handler fails, because at
**every** site the effect precedes its cause:

| Site | Order within the transaction |
|---|---|
| `HardReserve.redeem` | `_burn(...)` → `Transfer(holder→0)` … then `emit Redeemed` |
| treasury VYRF harvest | `vux.burn(fees)` → `Transfer(treasury→0)` … then `emit VyrfHarvest` |
| `Rig.take` | mint at step 10 → `Transfer(0→king)` … `emit Settled` at step 13 |

A handler on the transfer has no cause yet. A handler on the cause writes the row
but misses effects that have **no** cause event at all — a permissionless holder
self-burn emits only `Transfer(holder→0)`, because no protocol contract caused it.

Naive fixes each lose something: buffering breaks streaming; dropping causeless
effects breaks the supply identity; writing only from causes under-reports.

## Trigger Conditions

### Symptoms

- Cause events and their effects are in the same transaction, effect first
- Some effects legitimately have no cause event
- A cause event is sometimes emitted with a zero amount and **no** effect
- Handler ordering is per-log, and the framework offers no transaction-complete hook

### Context

| Context | Value |
|---|---|
| Technology Stack | ponder / subgraphs / any per-log streaming indexer |
| Timing | designing attribution for a derived store |
| Prerequisites | the classification domain includes a residual/"other" class |

## Root Cause

Emission order follows execution order: the state change happens, then the
contract announces why. Announcements are written after the fact, in code and on
chain alike. A streaming consumer therefore always learns the effect first.

## Solution

### Step 1: Write the row on the EFFECT, with the by-exclusion default

The default must be the classification that is *correct* for an effect with no
cause event — usually the residual class. This is not a placeholder; for the
causeless case it is the final, correct answer.

```typescript
ponder.on("Token:Transfer", async ({ event, context }) => {
  const { from, to, value } = event.args;
  const isMint = from === ZERO, isBurn = to === ZERO;
  if (isMint === isBurn) return;                  // ordinary transfer: not a supply change

  const delta = isMint ? value : -value;
  await context.db.insert(supplyChange).values({
    id: changeId(event.transaction.hash, delta),
    cause: isMint ? "genesis" : "other_authorized_burn",   // by exclusion
    delta, ...
  }).onConflictDoNothing();
});
```

### Step 2: REFINE on the cause event

```typescript
ponder.on("Reserve:Redeemed", async ({ event, context }) => {
  if (event.args.q === 0n) return;                 // a zero cause event has no effect
  await context.db
    .update(supplyChange, { id: changeId(event.transaction.hash, -event.args.q) })
    .set({ cause: "redemption_burn" })
    .catch(() => undefined);                       // no row = no effect; not an error
});
```

The terminal state is always the attributed one, and no change is ever dropped.

### Step 3: Derive the shared id from facts both handlers hold

The cause handler does not know the effect's log index, so the id must be
computable from what both sides see:

```typescript
const changeId = (tx: string, delta: bigint) =>
  `${tx}:${delta < 0n ? "burn" : "mint"}:${delta < 0n ? -delta : delta}`;
```

**Record the collision case explicitly**: two same-signed changes of identical
amount in one transaction would share an id. Then prove the domain cannot produce
it — here, the three burn sites are separate external functions on separate
contracts with no multicall surface, asserted per-transaction by a test — and cite
that proof next to the id.

### Step 4: Key the effect off the effect, never off the cause

A cause event may fire with a zero amount and no accompanying effect
(`VuxRevenueBurned(0)` when nothing was credited; a harvest whose fee leg is
zero). Creating a row from the cause event alone invents a change that never
happened.

```typescript
// F-5: the event is emitted even when the leg is zero. Key the supply change off
// the transfer; take the AMOUNT from the event.
if (vuxFeesBurned > 0n) { /* refine */ }
```

### Step 5: Never drop a causeless effect

The residual class exists so the aggregate identity holds. Dropping the
unattributable case makes `sum(changes) != actual` — a silent, compounding error.

## Verification

### Command

```bash
node --test test/reconstruct.test.mjs
node scripts/reconstruct.mjs        # against a live chain
```

### Expected Output

```
✔ F-2: a holder self-burn carries no cause event and books by exclusion
✔ F-5: a zero-amount cause event creates no supply change
VERDICT: PASS — indexer-only recompute matches chain state with zero ambiguity.
```

### Checklist

- [ ] Emission order confirmed by reading each site — do not assume cause-first
- [ ] Row written on the effect with the residual class as default
- [ ] Cause handlers refine, and tolerate a missing row
- [ ] Shared id computable by both handlers; collision case documented and proven unreachable
- [ ] Zero-amount cause events create no rows
- [ ] Causeless effects are retained, never dropped
- [ ] The aggregate identity (sum of changes == authoritative total) is asserted

## Related

- `reconstruct-from-the-asset-ledger` — the batch counterpart; a pure fold over the
  full log list can look ahead and so classifies directly, which makes it a useful
  oracle for the streaming path.
