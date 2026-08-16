// Event handlers — the streaming half of the replica.
//
// ATTRIBUTION IN A STREAM
//
// The canonical burn-cause join is "Transfer(holder -> 0) paired with the cause
// event emitted in the same transaction" (sdd.md:L544). In a streaming indexer
// that join has an ordering problem: the burn `Transfer` is emitted BEFORE its
// cause event at every site (`HardReserve.redeem` burns then emits `Redeemed`;
// `_pokeCollectAndClassifyFees` burns then emits `VyrfHarvest`; `Rig.take` mints
// at step 10 and emits `Settled` at step 13). A handler seeing the transfer
// cannot yet know the cause.
//
// So the row is written on the transfer with the BY-EXCLUSION default — which is
// exactly what the event-completeness audit concluded is correct for a change
// with no protocol cause event (F-2) — and the cause handler then REFINES it.
// The terminal state is always the attributed one, and a change is never
// dropped, which would break the `S` identity.
//
// EVENT IDENTITY
//
// A supply change is identified by the LOG that carried it — `${txHash}:${logIndex}`
// — never by its contents. The previous content-derived key
// (`tx:direction:amount`) was not unique: `VUX.burn(uint256)` is permissionless
// (src/VUX.sol:115), so any caller can compose two identical burns into one
// transaction, and the second insert collided and was silently discarded. The
// log position is unique by construction, so no reachable event sequence can
// lose a row.
//
// Because the key is no longer a function of the amount, a cause handler cannot
// recompute the key of the row it refines. It finds it through an explicit
// pairing slot instead — see `supplyChangePair` in ponder.schema.ts. The k-th
// change of a given signed amount in a transaction pairs with the k-th cause
// event of that amount, which is exactly the join the audit describes and is
// stable under replay.
//
// `indexer/src/lib/reconstruct.mjs` keys logs the same way (block hash, tx hash,
// log index), so the streaming path and the standalone fold agree on event
// identity rather than merely claiming to. They now also agree on ATTRIBUTION:
// the fold consumes a cause event once, as `refineCause` does here. Audit M-1
// found it matching by membership instead, so a single `VyrfHarvest` classified
// every equal-valued burn in its transaction while this path — the shipped one —
// attributed them correctly. Two reconstructions that disagree are one oracle
// and one bug, and there was no test that would have said which.

import { ponder } from "ponder:registry";
import { settlement, supplyChange, supplyChangePair, redemption, strategicFlow } from "ponder:schema";
// Explicit extension: ponder's bundler and Node's own loader must BOTH resolve
// this. `test/handlers.test.mjs` imports this module directly to exercise the
// delivered handlers, and Node's ESM resolver does not guess extensions.
import { applySchemaConstraints } from "./schema-constraints.ts";

const ZERO = "0x0000000000000000000000000000000000000000";

/**
 * Establish the database invariants ponder's schema builder cannot express,
 * before the first row is indexed (audit M-2).
 *
 * `setup` runs once, after the tables exist and ahead of every event handler. A
 * failure here is fatal by design: an indexer that believes it is constrained
 * and is not is worse than one that refuses to start.
 */
ponder.on("Rig:setup", async ({ context }) => {
  const applied = await applySchemaConstraints(context.db);
  console.log(`schema constraints active: ${applied.join(", ")}`);
});

/** FR-9.1 classes. `backing` is deliberately absent (FR-14.4). */
const STRATEGIC_CLASS: Record<number, string> = {
  1: "ContributedPrincipal",
  2: "ReturnedPrincipal",
  3: "PolFeeYield",
  4: "OtherRealizedRevenue",
};

const rowId = (tx: string, logIndex: number) => `${tx}:${logIndex}`;

/** Pairing-slot key: signed amount, so a mint never pairs with a burn. */
const slotId = (tx: string, delta: bigint, ordinal: number) => `${tx}:${delta}:${ordinal}`;

/**
 * Bound on slots probed for one `(tx, delta)`. Each step is a primary-key read;
 * the realistic count is one. It exists so a pathological transaction degrades
 * into an unattributed-but-recorded row rather than an unbounded loop — the
 * change itself is already durably stored before pairing is attempted.
 */
const MAX_SLOTS = 64;

/**
 * Append this change to the next free pairing slot for its `(tx, delta)`.
 *
 * Idempotent: a replayed transfer finds the slot it already owns and stops. A
 * blind append would hand the same change a second slot on every replay, which
 * shifts every later pairing by one — the failure `handlers.test.mjs` exercises.
 */
async function claimSlot(db: any, tx: string, delta: bigint, changeId: string) {
  for (let k = 0; k < MAX_SLOTS; k++) {
    const id = slotId(tx, delta, k);
    const existing = await db.find(supplyChangePair, { id });
    if (existing) {
      if (existing.changeId === changeId) return; // already claimed on an earlier pass
      continue;
    }
    await db.insert(supplyChangePair).values({ id, changeId, consumedBy: null }).onConflictDoNothing();
    return;
  }
}

/**
 * Attribute the next unconsumed change of `delta` in this transaction.
 *
 * Returns silently when no slot is open. That is the correct behaviour for a
 * cause event with no accompanying transfer — `VyrfHarvest` with a zero VUX leg,
 * `VuxRevenueBurned(0)` (audit F-5) — and it can never *drop* a change, because
 * the change row is written by the transfer handler independently of pairing.
 */
async function refineCause(
  db: any,
  tx: string,
  causeLogIndex: number,
  delta: bigint,
  patch: { cause: string; refEpochId?: bigint },
) {
  const causeKey = rowId(tx, causeLogIndex);
  for (let k = 0; k < MAX_SLOTS; k++) {
    const id = slotId(tx, delta, k);
    const slot = await db.find(supplyChangePair, { id });
    if (!slot) return;
    if (slot.consumedBy === causeKey) return; // this exact cause log already applied
    if (slot.consumedBy) continue; // claimed by a different cause log
    await db.update(supplyChangePair, { id }).set({ consumedBy: causeKey });
    await db.update(supplyChange, { id: slot.changeId }).set(patch);
    return;
  }
}

// ---------------------------------------------------------------------------
// Supply changes — written on the transfer, refined by the cause
// ---------------------------------------------------------------------------

ponder.on("VUX:Transfer", async ({ event, context }) => {
  const { from, to, value } = event.args;
  const isMint = from === ZERO;
  const isBurn = to === ZERO;
  if (isMint === isBurn) return; // ordinary holder-to-holder move: not a supply change

  const delta = isMint ? value : -value;
  const id = rowId(event.transaction.hash, event.log.logIndex);
  await context.db
    .insert(supplyChange)
    .values({
      id,
      blockNumber: event.block.number,
      txHash: event.transaction.hash,
      logIndex: event.log.logIndex,
      // By exclusion until a cause event refines it. A mint with no `Settled` is
      // the token's constructor emission; a burn with no protocol cause event is
      // a permissionless holder self-burn (audit F-2).
      cause: isMint ? "genesis" : "other_authorized_burn",
      delta,
      refEpochId: null,
      holder: isMint ? to : from,
    })
    .onConflictDoNothing();

  // The row is durable before pairing is attempted, so a change is recorded even
  // if nothing ever claims it.
  await claimSlot(context.db, event.transaction.hash, delta, id);
});

// ---------------------------------------------------------------------------
// Rig
// ---------------------------------------------------------------------------

ponder.on("Rig:Settled", async ({ event, context }) => {
  const a = event.args;

  await context.db.insert(settlement).values({
    epochId: a.epochId,
    blockNumber: event.block.number,
    txHash: event.transaction.hash,
    ts: event.block.timestamp,
    outgoingKing: a.outgoingKing,
    newKing: a.newKing,
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
  }).onConflictDoNothing();

  // Refine the mint this settlement caused. Skipped at zero, which is every
  // bootstrap and every VEM-starved settlement — there is no transfer to refine.
  if (a.qMint > 0n) {
    await refineCause(context.db, event.transaction.hash, event.log.logIndex, a.qMint, {
      cause: "settlement_mint",
      refEpochId: a.epochId,
    });
  }

  // F-1: ContributedPrincipal has no `StrategicInflow` emitter — the residual is
  // a bare WETH transfer with no callback, so the treasury never observes it. Its
  // observable is `Settled.strategicLeg`, absent when zero (sdd.md:L603).
  if (a.strategicLeg > 0n) {
    await context.db.insert(strategicFlow).values({
      id: rowId(event.transaction.hash, event.log.logIndex),
      blockNumber: event.block.number,
      txHash: event.transaction.hash,
      ts: event.block.timestamp,
      direction: "in",
      class: STRATEGIC_CLASS[1]!,
      asset: ZERO, // WETH; the token identity is an R-14 deployment fact
      amount: a.strategicLeg,
      counterparty: event.log.address,
    }).onConflictDoNothing();
  }
});

// ---------------------------------------------------------------------------
// HardReserve
// ---------------------------------------------------------------------------

ponder.on("HardReserve:Redeemed", async ({ event, context }) => {
  const a = event.args;

  await context.db.insert(redemption).values({
    id: rowId(event.transaction.hash, event.log.logIndex),
    blockNumber: event.block.number,
    txHash: event.transaction.hash,
    ts: event.block.timestamp,
    redeemer: a.redeemer,
    recipient: a.to,
    q: a.q,
    payout: a.payout,
    bPre: a.bPre,
    sPre: a.sPre,
  }).onConflictDoNothing();

  if (a.q > 0n) {
    await refineCause(context.db, event.transaction.hash, event.log.logIndex, -a.q, { cause: "redemption_burn" });
  }
});

// ---------------------------------------------------------------------------
// StrategicTreasury
// ---------------------------------------------------------------------------

ponder.on("StrategicTreasury:VyrfHarvest", async ({ event, context }) => {
  // F-5: the event is emitted even when the VUX leg is zero (only WETH fees
  // accrued). A supply change must key off the transfer, never off the event.
  const { vuxFeesBurned } = event.args;
  if (vuxFeesBurned > 0n) {
    await refineCause(context.db, event.transaction.hash, event.log.logIndex, -vuxFeesBurned, { cause: "vyrf_burn" });
  }
});

ponder.on("StrategicTreasury:VuxRevenueBurned", async ({ event }) => {
  // Already `other_authorized_burn` by exclusion, and `VuxRevenueBurned(0)` is
  // emitted with no accompanying transfer (F-5). Nothing to refine or create.
  void event;
});

ponder.on("StrategicTreasury:StrategicInflow", async ({ event, context }) => {
  const cls = STRATEGIC_CLASS[Number(event.args.class)];
  if (!cls) return;
  await context.db.insert(strategicFlow).values({
    id: rowId(event.transaction.hash, event.log.logIndex),
    blockNumber: event.block.number,
    txHash: event.transaction.hash,
    ts: event.block.timestamp,
    direction: "in",
    class: cls,
    asset: event.args.asset,
    amount: event.args.amount,
    counterparty: event.log.address,
  }).onConflictDoNothing();
});

ponder.on("StrategicTreasury:StrategicOutflow", async ({ event, context }) => {
  await context.db.insert(strategicFlow).values({
    id: rowId(event.transaction.hash, event.log.logIndex),
    blockNumber: event.block.number,
    txHash: event.transaction.hash,
    ts: event.block.timestamp,
    direction: "out",
    class: `Outflow:${Number(event.args.kind)}`,
    asset: event.args.asset,
    amount: event.args.amount,
    counterparty: event.args.target,
  }).onConflictDoNothing();
});
