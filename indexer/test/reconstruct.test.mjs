// Unit coverage for the reconstruction fold, over synthetic-but-real-shaped logs.
//
// The live scenario (`scripts/reconstruct.mjs`) proves the fold against a real
// chain, but it deploys the monetary core only — the canonical pool needs a
// cheatcode that does not exist on a live node. So the two treasury-side burn
// causes, and the adversarial cases a happy-path scenario cannot produce, are
// exercised here against logs encoded with the same ABIs the indexer decodes.
//
// Run: node --test test/

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { encodeEventTopics, encodeAbiParameters, parseAbiParameters } from 'viem';
import { reconstruct, CAUSE, STRATEGIC_CLASS } from '../src/lib/reconstruct.mjs';
import { RigAbi, HardReserveAbi, StrategicTreasuryAbi, VUXAbi } from '../abis/vux-events.mjs';

const ADDR = {
  vux: '0x00000000000000000000000000000000000000v1'.replace('v1', '01'),
  weth: '0x0000000000000000000000000000000000000002',
  reserve: '0x0000000000000000000000000000000000000003',
  rig: '0x0000000000000000000000000000000000000004',
  treasury: '0x0000000000000000000000000000000000000005',
};
const ZERO = '0x0000000000000000000000000000000000000000';
const HOLDER = '0x00000000000000000000000000000000000000aa';

let n = 0;
/** Build a log with the shape viem produces from eth_getLogs. */
function log(address, abi, eventName, args, { block = 1 } = {}) {
  const item = abi.find((e) => e.name === eventName);
  const topics = encodeEventTopics({ abi, eventName, args: pickIndexed(item, args) });
  const nonIndexed = item.inputs.filter((i) => !i.indexed);
  const data = nonIndexed.length
    ? encodeAbiParameters(nonIndexed, nonIndexed.map((i) => args[i.name]))
    : '0x';
  n += 1;
  return {
    address, topics, data,
    blockNumber: BigInt(block), blockHash: `0x${'b'.repeat(63)}${block}`,
    transactionHash: args.__tx ?? `0x${'t'.repeat(63)}${block}`, logIndex: n,
  };
}
function pickIndexed(item, args) {
  const out = {};
  for (const i of item.inputs) if (i.indexed) out[i.name] = args[i.name];
  return out;
}
const transfer = (token, from, to, value, opts) =>
  log(token, VUXAbi, 'Transfer', { from, to, value, ...opts }, opts);

const settled = (over = {}, opts) =>
  log(ADDR.rig, RigAbi, 'Settled', {
    epochId: 1n, outgoingKing: HOLDER, newKing: HOLDER, bootstrap: false,
    price: 100n, kingLeg: 80n, strategicLeg: 12n, reserveLeg: 8n,
    bPre: 1000n, sPre: 1000n, dR: 8n, qRaw: 5n, qSafe: 8n, qMint: 5n,
    nextOpening: 200n, epochUPS: 4n, ...over, ...opts,
  }, opts);

test('vyrf_burn: a treasury burn pairs with VyrfHarvest by amount', () => {
  const tx = `0x${'1'.repeat(64)}`;
  const logs = [
    log(ADDR.treasury, StrategicTreasuryAbi, 'VyrfHarvest', { vuxFeesBurned: 70n, wethFeesToHard: 30n, __tx: tx }, { __tx: tx }),
    transfer(ADDR.vux, ADDR.treasury, ZERO, 70n, { __tx: tx }),
  ];
  const r = reconstruct(logs, ADDR);
  assert.equal(r.burnsByCause[CAUSE.VYRF_BURN], 70n);
  assert.equal(r.burnsByCause[CAUSE.OTHER_AUTHORIZED_BURN], 0n);
  assert.equal(r.supply, -70n); // burns only, in isolation
  assert.deepEqual(r.ambiguities, []);
});

test('other_authorized_burn: a treasury burn pairs with VuxRevenueBurned', () => {
  const tx = `0x${'2'.repeat(64)}`;
  const logs = [
    log(ADDR.treasury, StrategicTreasuryAbi, 'VuxRevenueBurned', { amount: 40n, __tx: tx }, { __tx: tx }),
    transfer(ADDR.vux, ADDR.treasury, ZERO, 40n, { __tx: tx }),
  ];
  const r = reconstruct(logs, ADDR);
  assert.equal(r.burnsByCause[CAUSE.OTHER_AUTHORIZED_BURN], 40n);
  assert.equal(r.burnsByCause[CAUSE.VYRF_BURN], 0n);
});

test('F-5: a zero-amount cause event creates no supply change', () => {
  // `burnVuxRevenue()` emits VuxRevenueBurned(0) when there is no credit, and
  // VyrfHarvest carries a zero VUX leg whenever only WETH fees accrued. Neither
  // may manufacture a supply_change row.
  const tx = `0x${'3'.repeat(64)}`;
  const logs = [
    log(ADDR.treasury, StrategicTreasuryAbi, 'VuxRevenueBurned', { amount: 0n, __tx: tx }, { __tx: tx }),
    log(ADDR.treasury, StrategicTreasuryAbi, 'VyrfHarvest', { vuxFeesBurned: 0n, wethFeesToHard: 5n, __tx: tx }, { __tx: tx }),
  ];
  const r = reconstruct(logs, ADDR);
  assert.equal(r.supplyChanges.length, 0);
  assert.equal(r.supply, 0n);
});

test('F-2: a holder self-burn carries no cause event and books by exclusion', () => {
  const tx = `0x${'4'.repeat(64)}`;
  const logs = [transfer(ADDR.vux, HOLDER, ZERO, 9n, { __tx: tx })];
  const r = reconstruct(logs, ADDR);
  assert.equal(r.supplyChanges.length, 1, 'the change is never dropped — that would break the S identity');
  assert.equal(r.supplyChanges[0].cause, CAUSE.OTHER_AUTHORIZED_BURN);
  assert.equal(r.burnsByCause[CAUSE.OTHER_AUTHORIZED_BURN], 9n);
  assert.deepEqual(r.ambiguities, []);
});

test('two competing cause events in one transaction are reported, never silently resolved', () => {
  // The sdd.md:L544 no-ambiguity claim failing in the field. The protocol has no
  // path that produces this (the three burn sites are separate external functions
  // with no multicall surface), which is exactly why the detector needs its own
  // test — a detector that never fires is indistinguishable from a broken one.
  const tx = `0x${'5'.repeat(64)}`;
  const logs = [
    log(ADDR.treasury, StrategicTreasuryAbi, 'VyrfHarvest', { vuxFeesBurned: 11n, wethFeesToHard: 0n, __tx: tx }, { __tx: tx }),
    log(ADDR.treasury, StrategicTreasuryAbi, 'VuxRevenueBurned', { amount: 11n, __tx: tx }, { __tx: tx }),
    transfer(ADDR.vux, ADDR.treasury, ZERO, 11n, { __tx: tx }),
  ];
  const r = reconstruct(logs, ADDR);
  assert.equal(r.ambiguities.length, 1);
  assert.deepEqual(r.ambiguities[0].candidates.sort(), [CAUSE.OTHER_AUTHORIZED_BURN, CAUSE.VYRF_BURN].sort());
});

test('audit M-1: one cause event cannot classify two burns', () => {
  // The audit PoC. `harvestPol()` and `VUX.burn` are both permissionless, so a
  // composing contract puts two equal burns and ONE VyrfHarvest in one tx.
  // Membership-only matching booked both as vyrf_burn (reporting 22) and left
  // `ambiguities` empty, because `matched.length` never exceeded 1.
  //
  // The property under test is consumption, not a bucket name: the second burn
  // must not reuse the cause the first burn already spent, and must be
  // classified only on its own remaining evidence.
  const tx = `0x${'a'.repeat(64)}`;
  const logs = [
    log(ADDR.treasury, StrategicTreasuryAbi, 'VyrfHarvest', { vuxFeesBurned: 11n, wethFeesToHard: 0n, __tx: tx }, { __tx: tx }),
    transfer(ADDR.vux, ADDR.treasury, ZERO, 11n, { __tx: tx }),
    transfer(ADDR.vux, ADDR.treasury, ZERO, 11n, { __tx: tx }),
  ];
  const r = reconstruct(logs, ADDR);

  // Both burns are recorded and S is exact either way — the defect was never in
  // the supply identity, which is why nothing else caught it.
  assert.equal(r.supplyChanges.length, 2, 'neither burn may be dropped');
  assert.equal(r.supply, -22n);

  // The single cause accounts for exactly its own amount, once.
  assert.equal(r.burnsByCause[CAUSE.VYRF_BURN], 11n, 'one VyrfHarvest(11) explains 11, not 22');
  // The uncaused burn falls to the by-exclusion cause, exactly as a bare holder
  // self-burn does (F-2) — it did not inherit the spent VYRF cause.
  assert.equal(r.burnsByCause[CAUSE.OTHER_AUTHORIZED_BURN], 11n);
  assert.notEqual(r.supplyChanges[0].cause, r.supplyChanges[1].cause, 'the two burns are distinguishable');

  // Consumption is not ambiguity: there is exactly one candidate per burn here.
  assert.deepEqual(r.ambiguities, []);
});

test('audit M-1: a settlement mint cannot be claimed twice either', () => {
  // Same discipline on the mint side: one `Settled` accounts for one mint. The
  // second equal mint has no unconsumed cause and books as genesis by exclusion.
  const tx = `0x${'b'.repeat(64)}`;
  const logs = [
    settled({ qMint: 5n }, { __tx: tx }),
    transfer(ADDR.vux, ZERO, HOLDER, 5n, { __tx: tx }),
    transfer(ADDR.vux, ZERO, HOLDER, 5n, { __tx: tx }),
  ];
  const r = reconstruct(logs, ADDR);
  assert.equal(r.supply, 10n);
  assert.equal(r.mintsByCause[CAUSE.SETTLEMENT_MINT], 5n, 'one Settled(qMint=5) explains 5, not 10');
  assert.equal(r.mintsByCause[CAUSE.GENESIS], 5n);
});

test('settlement mint pairs with Settled; a mint without one is genesis', () => {
  const tx = `0x${'6'.repeat(64)}`;
  const logs = [
    transfer(ADDR.vux, ZERO, HOLDER, 150n, { block: 1, __tx: `0x${'0'.repeat(64)}` }), // constructor mint
    settled({ qMint: 5n, epochId: 7n, __tx: tx }, { block: 2, __tx: tx }),
    transfer(ADDR.vux, ZERO, HOLDER, 5n, { block: 2, __tx: tx }),
  ];
  const r = reconstruct(logs, ADDR);
  assert.equal(r.mintsByCause[CAUSE.GENESIS], 150n);
  assert.equal(r.mintsByCause[CAUSE.SETTLEMENT_MINT], 5n);
  assert.equal(r.supply, 155n);
  const mint = r.supplyChanges.find((s) => s.cause === CAUSE.SETTLEMENT_MINT);
  assert.equal(mint.refEpochId, 7n, 'the settlement mint is joined to its epoch');
});

test('F-1: ContributedPrincipal is derived from Settled.strategicLeg, and absent at zero', () => {
  const withLeg = reconstruct([settled({ strategicLeg: 12n, kingLeg: 80n, reserveLeg: 8n })], ADDR);
  assert.equal(withLeg.strategicContributed, 12n);
  assert.equal(withLeg.strategicFlows[0].class, STRATEGIC_CLASS[1]);

  const zeroLeg = reconstruct([settled({ strategicLeg: 0n, kingLeg: 80n, reserveLeg: 20n })], ADDR);
  assert.equal(zeroLeg.strategicContributed, 0n);
  assert.equal(zeroLeg.strategicFlows.length, 0, 'no row when the leg is zero (sdd.md:L603)');
});

test('no strategic class may ever contain the word "backing" (FR-14.4)', () => {
  const logs = [
    settled({ strategicLeg: 12n }),
    log(ADDR.treasury, StrategicTreasuryAbi, 'StrategicInflow', { class: 3, asset: ADDR.weth, amount: 4n }),
    log(ADDR.treasury, StrategicTreasuryAbi, 'StrategicOutflow', { kind: 2, target: ADDR.reserve, asset: ADDR.weth, amount: 4n }),
  ];
  const r = reconstruct(logs, ADDR);
  assert.ok(r.strategicFlows.length > 0);
  for (const f of r.strategicFlows) assert.ok(!/backing/i.test(f.class), `class "${f.class}" says backing`);
});

test('B is rebuilt from the WETH transfer record, including eventless donations', () => {
  const logs = [
    transfer(ADDR.weth, HOLDER, ADDR.reserve, 1000n),   // genesis funding — no protocol event
    transfer(ADDR.weth, HOLDER, ADDR.reserve, 30n),     // unsolicited donation — no protocol event
    transfer(ADDR.weth, ADDR.reserve, HOLDER, 200n),    // redemption payout
  ];
  const r = reconstruct(logs, ADDR);
  assert.equal(r.backing, 830n, 'B = WETH in - WETH out on the Reserve address (INV-10)');
});

test('B/S floors, and is null rather than 0 when S is zero', () => {
  const RAY = 10n ** 27n;
  const logs = [
    transfer(ADDR.weth, HOLDER, ADDR.reserve, 7n),
    transfer(ADDR.vux, ZERO, HOLDER, 3n),
  ];
  const r = reconstruct(logs, ADDR);
  assert.equal(r.backingPerVuxRay, (7n * RAY) / 3n);
  assert.ok(r.backingPerVuxRay * 3n <= 7n * RAY, 'never overstates backing per VUX (INV-16)');

  const noSupply = reconstruct([transfer(ADDR.weth, HOLDER, ADDR.reserve, 7n)], ADDR);
  assert.equal(noSupply.backingPerVuxRay, null, 'undefined is reported as null, never as a measured 0');
});

test('the fold is idempotent, order-independent and prefix-stable', () => {
  const base = [
    transfer(ADDR.weth, HOLDER, ADDR.reserve, 1000n, { block: 1 }),
    transfer(ADDR.vux, ZERO, HOLDER, 100n, { block: 1 }),
    transfer(ADDR.vux, HOLDER, ZERO, 10n, { block: 5 }),
  ];
  const once = reconstruct(base, ADDR);
  const thrice = reconstruct([...base, ...base, ...base], ADDR);
  assert.equal(thrice.supply, once.supply);
  assert.equal(thrice.supplyChanges.length, once.supplyChanges.length);

  const reversed = reconstruct([...base].reverse(), ADDR);
  assert.equal(reversed.supply, once.supply);
  assert.equal(reversed.backing, once.backing);

  const prefix = reconstruct(base.filter((l) => l.blockNumber <= 1n), ADDR);
  assert.equal(prefix.supply, 100n, 'dropping a reorged block returns the earlier state exactly');
});
