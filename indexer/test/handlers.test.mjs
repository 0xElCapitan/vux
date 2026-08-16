// Regression suite for the DELIVERED ponder handlers (`src/index.ts`).
//
// The headline case is the one review demonstrated and the previous key could
// not survive: two identical burns in a single transaction. `VUX.burn(uint256)`
// is permissionless (src/VUX.sol:115), so any caller can deploy a contract whose
// body calls it twice with the same amount. Under the old content-derived key
// (`tx:direction:amount`) both logs produced the same id and the second insert
// was swallowed by `onConflictDoNothing`, silently understating `S`.
//
// Every test below drives the shipped module through the real registry surface —
// see `ponder-virtual.mjs`. None of it re-implements the handler logic.

import test from 'node:test';
import assert from 'node:assert/strict';

import { handlers, makeStore, evt } from './ponder-virtual.mjs';

// Registers the indexing functions by importing the delivered module.
await import('../src/index.ts');

const ZERO = '0x0000000000000000000000000000000000000000';
const ALICE = '0x00000000000000000000000000000000000000a1';
const TREASURY = '0x00000000000000000000000000000000000000c1';
const TX = '0xdeadbeef';

const call = (name, store, e) => handlers.get(name)({ ...e, context: { db: store.db } });
const burn = (store, { from = ALICE, value, logIndex, txHash = TX }) =>
  call('VUX:Transfer', store, evt({ txHash, logIndex, args: { from, to: ZERO, value } }));
const mint = (store, { to = ALICE, value, logIndex, txHash = TX }) =>
  call('VUX:Transfer', store, evt({ txHash, logIndex, args: { from: ZERO, to, value } }));

test('the delivered handler module registers every accepted event', () => {
  for (const name of [
    'VUX:Transfer',
    'Rig:Settled',
    'HardReserve:Redeemed',
    'StrategicTreasury:VyrfHarvest',
    'StrategicTreasury:VuxRevenueBurned',
    'StrategicTreasury:StrategicInflow',
    'StrategicTreasury:StrategicOutflow',
  ]) {
    assert.equal(typeof handlers.get(name), 'function', `missing handler: ${name}`);
  }
});

// ---------------------------------------------------------------------------
// H-1 — the reviewer's proof of concept
// ---------------------------------------------------------------------------

test('H-1: two identical self-burns in ONE transaction are both recorded', async () => {
  const store = makeStore();
  const x = 5_000_000_000_000_000_000n; // 5 VUX, burned twice by one contract call

  await burn(store, { value: x, logIndex: 0 });
  await burn(store, { value: x, logIndex: 1 });

  const rows = store.rows('supplyChange');
  assert.equal(rows.length, 2, 'BOTH burns must survive — the second must not be swallowed');
  assert.notEqual(rows[0].id, rows[1].id, 'the two logs must carry distinct identities');
  assert.deepEqual(
    rows.map((r) => r.id).sort(),
    [`${TX}:0`, `${TX}:1`],
    'identity is the log position, not the amount',
  );

  const S = rows.reduce((a, r) => a + r.delta, 0n);
  assert.equal(S, -2n * x, 'reconstructed supply delta must account for both burns');
  for (const r of rows) assert.equal(r.cause, 'other_authorized_burn', 'holder burn books by exclusion (F-2)');
});

test('H-1: the collision case is reachable for mints too, and is likewise safe', async () => {
  const store = makeStore();
  const x = 7n;
  await mint(store, { value: x, logIndex: 0 });
  await mint(store, { value: x, logIndex: 1 });
  assert.equal(store.rows('supplyChange').length, 2, 'two equal mints in one tx are two rows');
});

test('H-1: identical burns in DIFFERENT transactions remain distinct', async () => {
  const store = makeStore();
  await burn(store, { value: 3n, logIndex: 0, txHash: '0xaa' });
  await burn(store, { value: 3n, logIndex: 0, txHash: '0xbb' });
  assert.equal(store.rows('supplyChange').length, 2);
});

// ---------------------------------------------------------------------------
// Attribution still works — the fix must not buy uniqueness with lost causes
// ---------------------------------------------------------------------------

test('a redemption burn is attributed to Redeemed', async () => {
  const store = makeStore();
  const q = 4n;
  await burn(store, { value: q, logIndex: 0 });
  await call('HardReserve:Redeemed', store, evt({
    txHash: TX, logIndex: 1,
    args: { redeemer: ALICE, to: ALICE, q, payout: 9n, bPre: 100n, sPre: 50n },
  }));

  const [row] = store.rows('supplyChange');
  assert.equal(row.cause, 'redemption_burn');
  assert.equal(store.rows('redemption').length, 1);
});

test('TWO equal redemptions in one transaction are both recorded AND both attributed', async () => {
  const store = makeStore();
  const q = 4n;
  await burn(store, { value: q, logIndex: 0 });
  await call('HardReserve:Redeemed', store, evt({ txHash: TX, logIndex: 1, args: { redeemer: ALICE, to: ALICE, q, payout: 9n, bPre: 100n, sPre: 50n } }));
  await burn(store, { value: q, logIndex: 2 });
  await call('HardReserve:Redeemed', store, evt({ txHash: TX, logIndex: 3, args: { redeemer: ALICE, to: ALICE, q, payout: 9n, bPre: 96n, sPre: 46n } }));

  const rows = store.rows('supplyChange');
  assert.equal(rows.length, 2, 'both burns recorded');
  assert.deepEqual(rows.map((r) => r.cause), ['redemption_burn', 'redemption_burn'], 'both attributed — no slot reused');
  assert.equal(store.rows('redemption').length, 2);
});

test('a settlement mint is attributed to Settled and carries the epoch', async () => {
  const store = makeStore();
  const qMint = 11n;
  await mint(store, { value: qMint, logIndex: 0 });
  await call('Rig:Settled', store, evt({
    txHash: TX, logIndex: 1,
    args: {
      epochId: 3n, outgoingKing: ALICE, newKing: ALICE, bootstrap: false, price: 10n,
      kingLeg: 8n, strategicLeg: 0n, reserveLeg: 2n, bPre: 100n, sPre: 50n, dR: 2n,
      qRaw: 20n, qSafe: 11n, qMint, nextOpening: 20n, epochUPS: 1n,
    },
  }));
  const [row] = store.rows('supplyChange');
  assert.equal(row.cause, 'settlement_mint');
  assert.equal(row.refEpochId, 3n);
});

test('a VYRF burn is attributed to VyrfHarvest', async () => {
  const store = makeStore();
  const v = 6n;
  await burn(store, { from: TREASURY, value: v, logIndex: 0 });
  await call('StrategicTreasury:VyrfHarvest', store, evt({ txHash: TX, logIndex: 1, args: { vuxFeesBurned: v } }));
  assert.equal(store.rows('supplyChange')[0].cause, 'vyrf_burn');
});

test('F-5: a zero-amount cause event creates and refines nothing', async () => {
  const store = makeStore();
  await call('StrategicTreasury:VyrfHarvest', store, evt({ txHash: TX, logIndex: 0, args: { vuxFeesBurned: 0n } }));
  assert.equal(store.rows('supplyChange').length, 0);
});

test('a cause event with no matching transfer refines nothing and throws nothing', async () => {
  const store = makeStore();
  await call('HardReserve:Redeemed', store, evt({
    txHash: TX, logIndex: 0,
    args: { redeemer: ALICE, to: ALICE, q: 99n, payout: 1n, bPre: 1n, sPre: 1n },
  }));
  assert.equal(store.rows('supplyChange').length, 0, 'no change invented');
});

// ---------------------------------------------------------------------------
// Replay
// ---------------------------------------------------------------------------

test('replaying the whole log stream is idempotent', async () => {
  const drive = async (store) => {
    await burn(store, { value: 5n, logIndex: 0 });
    await burn(store, { value: 5n, logIndex: 1 });
    await call('HardReserve:Redeemed', store, evt({ txHash: TX, logIndex: 2, args: { redeemer: ALICE, to: ALICE, q: 5n, payout: 1n, bPre: 9n, sPre: 9n } }));
  };
  const once = makeStore();
  await drive(once);
  const twice = makeStore();
  await drive(twice);
  await drive(twice);

  const norm = (s) => JSON.stringify(s.rows('supplyChange').map((r) => [r.id, r.cause, String(r.delta)]).sort());
  assert.equal(norm(twice), norm(once), 'a replayed stream must not change the result');
  assert.equal(once.rows('supplyChange').length, 2);
});
