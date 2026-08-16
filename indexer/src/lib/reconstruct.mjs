// Independent reconstruction of VUX economic truth from observable facts alone.
//
// THE CLAIM THIS IMPLEMENTS
//
//   "An independent indexer, using only observable facts, can reproduce `S`,
//    `B`, `B/S`, per-settlement legs, and burn causes with zero ambiguity."
//                                                          (prd.md:L538, FR-14)
//
// So this module reads LOGS and nothing else. It never calls a contract, never
// reads protocol state, and never consults a balance. A reconstruction that
// asked the chain for `totalSupply()` would prove nothing about observability —
// it would just be a slow way of reading state. The comparison against chain
// state happens in the test, on the other side of this boundary.
//
// It is a PURE FOLD over a log list. Two properties fall out of that rather than
// being bolted on: applying the same log twice cannot move the result
// (idempotency), and dropping a reorged block's logs and re-folding returns
// exactly the pre-reorg state (reorg handling). Both are asserted in the tests
// rather than asserted here (sdd.md:L836).

import { decodeEventLog } from 'viem';
import { RigAbi, HardReserveAbi, StrategicTreasuryAbi, VUXAbi } from '../../abis/vux-events.mjs';

const ZERO = '0x0000000000000000000000000000000000000000';
const RAY = 10n ** 27n;

/** `supply_change.cause` domain — sdd.md:L576-L577. */
export const CAUSE = {
  GENESIS: 'genesis',
  SETTLEMENT_MINT: 'settlement_mint',
  REDEMPTION_BURN: 'redemption_burn',
  VYRF_BURN: 'vyrf_burn',
  OTHER_AUTHORIZED_BURN: 'other_authorized_burn',
};

/** FR-9.1 classes. `backing` is deliberately absent and must never be added. */
export const STRATEGIC_CLASS = {
  1: 'ContributedPrincipal',
  2: 'ReturnedPrincipal',
  3: 'PolFeeYield',
  4: 'OtherRealizedRevenue',
};

const OUT_HARD_ACCRETION = 2;

const lower = (a) => (a ?? '').toLowerCase();

/** Stable identity of a log, for deduplication. */
const logKey = (l) => `${l.blockHash ?? l.blockNumber}:${l.transactionHash}:${l.logIndex}`;

function tryDecode(abi, log) {
  try {
    return decodeEventLog({ abi, data: log.data, topics: log.topics });
  } catch {
    return null;
  }
}

/**
 * Fold a log list into reconstructed economic truth.
 *
 * @param {Array} logs      raw logs (any order; deduplicated and sorted here)
 * @param {object} addresses {vux, weth, reserve, rig, treasury}
 */
export function reconstruct(logs, addresses) {
  const vux = lower(addresses.vux);
  const weth = lower(addresses.weth);
  const reserve = lower(addresses.reserve);
  const rig = lower(addresses.rig);
  const treasury = lower(addresses.treasury);

  // --- deduplicate, then order canonically -------------------------------
  // Idempotency is a property of the fold, so the fold must not double-count a
  // log delivered twice (a re-sync, an overlapping range query, a reorg replay).
  const seen = new Map();
  for (const l of logs) if (!seen.has(logKey(l))) seen.set(logKey(l), l);
  const ordered = [...seen.values()].sort((a, b) => {
    const bn = BigInt(a.blockNumber) - BigInt(b.blockNumber);
    if (bn !== 0n) return bn < 0n ? -1 : 1;
    return Number(a.logIndex) - Number(b.logIndex);
  });

  // --- pass 1: index the per-transaction cause events ---------------------
  // The accepted join is "Transfer(holder -> 0) paired with the cause event
  // emitted in the same transaction" (sdd.md:L544). So causes are collected
  // per-transaction first, and the supply changes are attributed against them.
  const txCauses = new Map(); // txHash -> {settled, redeemed[], vyrf[], revenueBurn[]}
  const causeSlot = (tx) => {
    if (!txCauses.has(tx)) txCauses.set(tx, { settled: null, redeemed: [], vyrf: [], revenueBurn: [] });
    return txCauses.get(tx);
  };

  const settlements = [];
  const redemptions = [];
  const strategicFlows = [];
  let firstVuxBlock = null;

  for (const log of ordered) {
    const addr = lower(log.address);
    const tx = log.transactionHash;

    if (addr === rig) {
      const d = tryDecode(RigAbi, log);
      if (d?.eventName === 'Settled') {
        const a = d.args;
        const rec = {
          epochId: BigInt(a.epochId),
          blockNumber: BigInt(log.blockNumber),
          txHash: tx,
          outgoingKing: lower(a.outgoingKing),
          newKing: lower(a.newKing),
          bootstrap: a.bootstrap,
          price: a.price,
          kingLeg: a.kingLeg,
          strategicLeg: a.strategicLeg,
          reserveLeg: a.reserveLeg,
          bPre: a.bPre,
          sPre: a.sPre,
          dR: a.dR,
          qRaw: a.qRaw,
          qSafe: a.qSafe,
          qMint: a.qMint,
          nextOpening: a.nextOpening,
          epochUps: a.epochUPS,
        };
        settlements.push(rec);
        causeSlot(tx).settled = rec;

        // F-1: ContributedPrincipal has no StrategicInflow emitter — the residual
        // arrives as a bare WETH transfer with no callback, so the treasury never
        // observes it. Its observable is Settled.strategicLeg, and the row is
        // absent when the leg is zero (sdd.md:L603, src/Rig.sol:345).
        if (rec.strategicLeg > 0n) {
          strategicFlows.push({
            blockNumber: rec.blockNumber, txHash: tx, direction: 'in',
            class: STRATEGIC_CLASS[1], asset: weth, amount: rec.strategicLeg, counterparty: rig,
          });
        }
      }
      continue;
    }

    if (addr === reserve) {
      const d = tryDecode(HardReserveAbi, log);
      if (d?.eventName === 'Redeemed') {
        const a = d.args;
        const rec = {
          blockNumber: BigInt(log.blockNumber), txHash: tx,
          redeemer: lower(a.redeemer), recipient: lower(a.to),
          q: a.q, payout: a.payout, bPre: a.bPre, sPre: a.sPre,
        };
        redemptions.push(rec);
        causeSlot(tx).redeemed.push(rec);
      }
      continue;
    }

    if (addr === treasury) {
      const d = tryDecode(StrategicTreasuryAbi, log);
      if (!d) continue;
      if (d.eventName === 'VyrfHarvest') {
        causeSlot(tx).vyrf.push({ vuxFeesBurned: d.args.vuxFeesBurned, wethFeesToHard: d.args.wethFeesToHard });
      } else if (d.eventName === 'VuxRevenueBurned') {
        causeSlot(tx).revenueBurn.push({ amount: d.args.amount });
      } else if (d.eventName === 'StrategicInflow') {
        const cls = STRATEGIC_CLASS[Number(d.args.class)];
        if (cls) {
          strategicFlows.push({
            blockNumber: BigInt(log.blockNumber), txHash: tx, direction: 'in',
            class: cls, asset: lower(d.args.asset), amount: d.args.amount, counterparty: treasury,
          });
        }
      } else if (d.eventName === 'StrategicOutflow') {
        strategicFlows.push({
          blockNumber: BigInt(log.blockNumber), txHash: tx, direction: 'out',
          class: `Outflow:${Number(d.args.kind)}`, asset: lower(d.args.asset),
          amount: d.args.amount, counterparty: lower(d.args.target),
          hardAccretion: Number(d.args.kind) === OUT_HARD_ACCRETION,
        });
      }
      continue;
    }
  }

  // --- pass 2: supply changes, each attributed to exactly one cause --------
  const supplyChanges = [];
  const ambiguities = [];
  let supply = 0n;

  // Cause evidence is CONSUMED, never reused: one cause event explains at most
  // one supply change. This is the same discipline the shipped handler enforces
  // with pairing slots (`src/index.ts:94-112`, `if (slot.consumedBy) continue`),
  // expressed as its inverse — there the cause claims a change, here the change
  // claims a cause. Membership-only matching let a single `VyrfHarvest(11)`
  // classify BOTH burns of a two-burn transaction as `vyrf_burn` (reporting 22)
  // while `matched.length` stayed 1 so no ambiguity was raised (audit M-1).
  // A WeakSet marks records by identity, so nothing is written onto the cause
  // objects that are also returned in `redemptions`/`settlements`.
  const consumedCause = new WeakSet();
  const firstUnconsumed = (list, amountOf, value) =>
    list.find((r) => !consumedCause.has(r) && amountOf(r) === value) ?? null;

  for (const log of ordered) {
    if (lower(log.address) !== vux) continue;
    const d = tryDecode(VUXAbi, log);
    if (d?.eventName !== 'Transfer') continue;

    const from = lower(d.args.from);
    const to = lower(d.args.to);
    const value = d.args.value;
    const isMint = from === ZERO;
    const isBurn = to === ZERO;
    if (isMint === isBurn) continue; // ordinary holder-to-holder transfer: not a supply change
    if (firstVuxBlock === null) firstVuxBlock = BigInt(log.blockNumber);

    const tx = log.transactionHash;
    const causes = txCauses.get(tx) ?? { settled: null, redeemed: [], vyrf: [], revenueBurn: [] };
    let cause = null;
    const matched = [];

    if (isMint) {
      // A mint pairs with `Settled` (settlement_mint), which can account for one
      // mint only. A mint with no unconsumed `Settled` in its transaction is the
      // token's own constructor emission — genesis.
      const s = causes.settled;
      if (s && !consumedCause.has(s) && s.qMint === value) {
        consumedCause.add(s);
        matched.push(CAUSE.SETTLEMENT_MINT);
      }
      cause = matched[0] ?? CAUSE.GENESIS;
    } else {
      // A burn pairs with exactly one of the three protocol cause events, by
      // amount, in the same transaction — and takes that evidence out of play.
      // Candidate order is fixed, so attribution is deterministic under a given
      // log order; the cause lists are built in log order in pass 1.
      const hits = [];
      for (const [candidate, list, amountOf] of [
        [CAUSE.REDEMPTION_BURN, causes.redeemed, (r) => r.q],
        [CAUSE.VYRF_BURN, causes.vyrf, (v) => v.vuxFeesBurned],
        [CAUSE.OTHER_AUTHORIZED_BURN, causes.revenueBurn, (v) => v.amount],
      ]) {
        const rec = firstUnconsumed(list, amountOf, value);
        if (rec) { hits.push({ candidate, rec }); matched.push(candidate); }
      }

      if (matched.length > 1) {
        // sdd.md:L544's zero-ambiguity claim failing in the field. Recorded, never
        // silently resolved by picking one.
        ambiguities.push({ txHash: tx, value, candidates: matched });
      }
      // F-2: a permissionless holder self-burn (`VUX.burn`) emits no protocol
      // cause event, because no protocol contract caused it. Zero *unconsumed*
      // cause events is a distinguishable signature that collides with none of
      // the four protocol causes, so it books as other_authorized_burn by
      // exclusion — and is never dropped, which would break the `S` identity.
      // This is also where a burn whose cause was already spent by an earlier
      // burn lands: classified on its own remaining evidence, never inheriting.
      if (hits.length > 0) {
        consumedCause.add(hits[0].rec);
        cause = hits[0].candidate;
      } else {
        cause = CAUSE.OTHER_AUTHORIZED_BURN;
      }
    }

    const delta = isMint ? value : -value;
    supply += delta;
    supplyChanges.push({
      blockNumber: BigInt(log.blockNumber),
      txHash: tx,
      cause,
      delta,
      refEpochId: cause === CAUSE.SETTLEMENT_MINT ? causes.settled.epochId : null,
      holder: isMint ? to : from,
    });
  }

  // --- pass 3: backing, from the WETH token's own transfer record ----------
  // `B` is authority-defined as the Reserve's physical WETH balance (INV-10), so
  // it reconstructs as WETH in minus WETH out on that address. This is general by
  // construction: it captures genesis funding, settlement legs, VYRF accretion,
  // revenue allocation, redemption payouts, and unsolicited donations alike,
  // without needing any of them to have a protocol event.
  let backing = 0n;
  const backingFlows = [];
  for (const log of ordered) {
    if (lower(log.address) !== weth) continue;
    const d = tryDecode(VUXAbi, log); // ERC-20 Transfer shape is identical
    if (d?.eventName !== 'Transfer') continue;
    const from = lower(d.args.from);
    const to = lower(d.args.to);
    const value = d.args.value;
    if (to === reserve && from !== reserve) {
      backing += value;
      backingFlows.push({ blockNumber: BigInt(log.blockNumber), txHash: log.transactionHash, delta: value });
    } else if (from === reserve && to !== reserve) {
      backing -= value;
      backingFlows.push({ blockNumber: BigInt(log.blockNumber), txHash: log.transactionHash, delta: -value });
    }
  }

  // --- derived aggregates -------------------------------------------------
  const burnsByCause = {};
  for (const c of Object.values(CAUSE)) burnsByCause[c] = 0n;
  for (const sc of supplyChanges) {
    if (sc.delta < 0n) burnsByCause[sc.cause] += -sc.delta;
  }
  const mintsByCause = { [CAUSE.GENESIS]: 0n, [CAUSE.SETTLEMENT_MINT]: 0n };
  for (const sc of supplyChanges) {
    if (sc.delta > 0n) mintsByCause[sc.cause] = (mintsByCause[sc.cause] ?? 0n) + sc.delta;
  }

  const strategicContributed = strategicFlows
    .filter((f) => f.class === STRATEGIC_CLASS[1])
    .reduce((a, f) => a + f.amount, 0n);

  return {
    supply,
    backing,
    // floor — understates backing per unit rather than overstating it (INV-16).
    backingPerVuxRay: supply === 0n ? null : (backing * RAY) / supply,
    settlements,
    redemptions,
    supplyChanges,
    burnsByCause,
    mintsByCause,
    strategicFlows,
    strategicContributed,
    backingFlows,
    ambiguities,
    logsConsidered: ordered.length,
    // `strategic_nav_disclosed` is deliberately absent: marks are not transfers
    // (INV-30), so NAV is disclosure, not reconstruction. Emitting a number here
    // would manufacture derived "backing" out of thin air (FR-14.4).
  };
}

/** Per-settlement leg checks that must hold on every record (FR-4.1). */
export function checkSettlementLegs(s) {
  const problems = [];
  if (s.kingLeg + s.strategicLeg + s.reserveLeg !== s.price) {
    problems.push(`legs_sum: ${s.kingLeg}+${s.strategicLeg}+${s.reserveLeg} != ${s.price}`);
  }
  if (s.qMint > s.qRaw) problems.push(`qMint ${s.qMint} > qRaw ${s.qRaw}`);
  if (s.qMint > s.qSafe) problems.push(`qMint ${s.qMint} > qSafe ${s.qSafe}`);
  // D_need is exactly derivable from the emitted fields (sdd.md:L488).
  if (s.sPre > 0n) {
    const dNeed = s.qRaw === 0n ? 0n : (s.qRaw * s.bPre + s.sPre - 1n) / s.sPre;
    if (s.qRaw > 0n && s.dR >= dNeed && s.qMint !== s.qRaw) {
      problems.push(`dR ${s.dR} >= D_need ${dNeed} but qMint ${s.qMint} != qRaw ${s.qRaw}`);
    }
  }
  return problems;
}
