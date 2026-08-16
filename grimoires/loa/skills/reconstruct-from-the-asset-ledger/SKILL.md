---
name: reconstruct-from-the-asset-ledger
description: |
  Rebuilding a balance by summing domain events (settlement legs, harvest legs,
  payout legs) both double-counts movements that two events describe and misses
  movements no event describes. Rebuild it from the asset's own transfer record
  instead — the definitional source. Apply when reconstructing balances or
  supply from logs, and when designing the test that proves the reconstruction.
  Also provides the independence-by-construction test design.
loa-agent: implementing-tasks
extracted-from: sprint-6-task-6.5 (VUX v1, independent-reconstruction acceptance)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - indexing
  - reconstruction
  - accounting
  - test-design
---

## Problem

A reserve balance `B` must be reconstructable from logs. The obvious approach sums
the domain events that describe money moving into and out of it:

```javascript
B = Σ Settled.dR
  + Σ VyrfHarvest.wethFeesToHard
  + Σ StrategicOutflow(kind=HardAccretion).amount
  - Σ Redeemed.payout;
```

This is wrong twice over:

1. **Double count.** The VYRF fee movement is emitted by *two* events for the same
   transfer — `VyrfHarvest.wethFeesToHard` **and** `StrategicOutflow(kind=2)`.
   Adding both counts it twice.
2. **Missed movement.** Genesis funding and unsolicited donations are plain ERC-20
   transfers with **no** protocol event. A legs-based sum misses them entirely and
   still looks internally consistent.

Both errors are silent. The reconstruction reports a number, it is plausible, and
it is wrong.

## Trigger Conditions

### Symptoms

- A balance is reconstructed by summing domain/business events
- One physical movement is described by more than one event
- The account can be credited or debited by paths with no domain event
- Reconstructed totals drift from actual state under specific scenarios
- The specification *defines* the quantity as a raw balance

### The tell

The specification says something like *"backing is the contract's physical token
balance"*. That sentence names the reconstruction source: the token's ledger, not
the business events.

### Context

| Context | Value |
|---|---|
| Technology Stack | any event-sourced replica over token/asset movements |
| Timing | designing reconstruction, and its acceptance test |
| Prerequisites | the asset emits standard transfer events |

## Root Cause

Domain events describe *intent and classification*; the asset ledger records
*movement*. They are different layers, and the mapping between them is neither
injective (two events, one movement) nor surjective (movements with no event).
Reconstructing a balance — a movement fact — from the classification layer inherits
both mismatches.

## Solution

### Step 1: Rebuild the balance from the asset's own transfer record

```javascript
let backing = 0n;
for (const log of ordered) {
  if (lower(log.address) !== weth) continue;         // the ASSET contract
  const d = decodeTransfer(log);
  if (!d) continue;
  const { from, to, value } = d.args;
  if (to === reserve && from !== reserve)      backing += value;
  else if (from === reserve && to !== reserve) backing -= value;
}
```

General by construction: it captures genesis funding, every routed leg, fee
accretion, payouts, and donations, without any of them needing a domain event.

### Step 2: Keep domain events for CLASSIFICATION, not for totals

Use them for cause attribution, per-settlement legs, and flow classes — the things
only they can express. Never sum them to obtain a balance.

### Step 3: Put an eventless movement in the acceptance scenario deliberately

This is the assertion that catches the whole class:

```javascript
await send('donateToReserve', [3n * 10n ** 18n]);   // no protocol event at all
```

A legs-based reconstruction passes every other step and fails here. Without it,
the bug ships.

### Step 4: Enforce independence by construction in the test

The reconstruction and the truth it is compared against must not be able to borrow
from each other:

```javascript
// reconstruction side: eth_getLogs and nothing else
const R = reconstruct(await pub.getLogs({ fromBlock: genesis, toBlock: 'latest' }), addresses);

// truth side: eth_call and nothing else
const chainSupply  = await pub.readContract({ ...vux,  functionName: 'totalSupply' });
const chainBacking = await pub.readContract({ ...weth, functionName: 'balanceOf', args: [reserve] });
```

Enforce it in the module boundary too: the reconstruction module imports no
contract-call helper. A reconstruction that *could* call `totalSupply()` proves
nothing about observability.

### Step 5: Make the reconstruction a pure fold, then two properties come free

Deduplicate by log identity and sort canonically inside the fold. Then:

- **idempotency** — replaying logs cannot move the result;
- **reorg handling** — dropping a block's logs and re-folding returns the earlier
  state exactly.

Assert both, plus order-independence, plus a **real** reorg:

```javascript
const snap = await pub.request({ method: 'evm_snapshot', params: [] });
/* diverge */
await pub.request({ method: 'evm_revert', params: [snap] });
// re-fetch, re-fold, must equal the pre-fork state AND agree with chain state again
```

A simulated truncation tests your filter. A snapshot/revert tests the chain doing
it to you.

## Verification

### Command

```bash
anvil --port 8545 &
node scripts/reconstruct.mjs
```

### Expected Output

```
    S      logs=156299715920438925244075  chain=156299715920438925244075
    B      logs=311308363636363636364     chain=311308363636363636364
    real reorg: branch added epoch 6, reverted -> back to 5 settlements
VERDICT: PASS — indexer-only recompute matches chain state with zero ambiguity.
```

### Checklist

- [ ] Balance rebuilt from the asset's transfer record, not from domain legs
- [ ] Every physical movement described by two events identified; only one counted
- [ ] An eventless credit is in the scenario, deliberately
- [ ] Reconstruction side and truth side use disjoint RPC methods
- [ ] The reconstruction module imports no state-reading helper
- [ ] Fold deduplicates and sorts; idempotency, order-independence, prefix-stability asserted
- [ ] A real snapshot/revert reorg round-trip is asserted

## Related

- `streaming-attribution-by-exclusion-then-refine` — the incremental counterpart;
  this batch fold makes a good oracle for it.
