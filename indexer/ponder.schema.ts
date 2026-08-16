// The accepted off-chain schema, sdd.md §3.3, as ponder onchain tables.
//
// THIS FILE IS THE LIVE SCHEMA. ponder builds the running tables from it, so
// every invariant that must actually hold has to be expressible here — or be
// applied at startup by `src/schema-constraints.ts`. `sql/schema.sql` is a
// consumer-facing reference shape for anyone rebuilding this replica in their
// own warehouse; it is NOT executed by this application and nothing in it
// enforces anything here (audit M-2).
//
// Where PostgreSQL gives NUMERIC(78,0), ponder gives bigint — both hold a
// 256-bit unsigned value without loss, which is the property that matters.
//
// The store is DERIVED, disposable and rebuildable from genesis (sdd.md:L474).

import { onchainTable, index, uniqueIndex } from "ponder";

export const settlement = onchainTable(
  "settlement",
  (t) => ({
    epochId: t.bigint().primaryKey(),
    blockNumber: t.bigint().notNull(),
    txHash: t.hex().notNull(),
    ts: t.bigint().notNull(),
    outgoingKing: t.hex().notNull(),
    newKing: t.hex().notNull(),
    bootstrap: t.boolean().notNull(),
    price: t.bigint().notNull(),
    kingLeg: t.bigint().notNull(),
    strategicLeg: t.bigint().notNull(),
    reserveLeg: t.bigint().notNull(),
    bPre: t.bigint().notNull(),
    sPre: t.bigint().notNull(),
    dR: t.bigint().notNull(),
    qRaw: t.bigint().notNull(),
    qSafe: t.bigint().notNull(),
    qMint: t.bigint().notNull(),
    nextOpening: t.bigint().notNull(),
    epochUps: t.bigint().notNull(),
  }),
  (table) => ({
    blockIdx: index().on(table.blockNumber),
  })
);

export const supplyChange = onchainTable(
  "supply_change",
  (t) => ({
    // `${txHash}:${logIndex}` — the LOG's own identity, not a function of its
    // contents. A content-derived key (tx + direction + amount) is not unique:
    // `VUX.burn` is permissionless, so one transaction can carry two identical
    // burns, and the second would collide and be discarded. The log position is
    // unique by construction, so no reachable event sequence can lose a row.
    id: t.text().primaryKey(),
    blockNumber: t.bigint().notNull(),
    txHash: t.hex().notNull(),
    // Kept as a column, not only inside `id`, so pairing can order numerically —
    // lexicographic ordering of the composite id puts log 10 before log 2.
    logIndex: t.integer().notNull(),
    // Domain: genesis | settlement_mint | redemption_burn | vyrf_burn | other_authorized_burn
    cause: t.text().notNull(),
    delta: t.bigint().notNull(), // signed
    refEpochId: t.bigint(),
    holder: t.hex().notNull(),
  }),
  (table) => ({
    causeIdx: index().on(table.cause),
    blockIdx: index().on(table.blockNumber),
    txIdx: index().on(table.txHash),
    // Event-occurrence uniqueness, enforced by the DATABASE rather than asserted
    // in a comment. The `id` primary key already implies it — `id` is exactly
    // `${txHash}:${logIndex}` — but that made the guarantee a property of a
    // string-formatting convention. Stated over the real columns, a handler
    // change that altered `id` can no longer silently widen what counts as a
    // distinct occurrence. ponder emits this as a real CREATE UNIQUE INDEX.
    occurrenceIdx: uniqueIndex().on(table.txHash, table.logIndex),
  })
);

/**
 * Pairing slots joining a supply-change log to the cause event that follows it.
 *
 * At every burn site the `Transfer` is emitted BEFORE its cause event, so the
 * transfer handler cannot yet know the cause and the cause handler must find the
 * row it belongs to. It cannot recompute the row's key, because the key is now
 * the log position rather than the amount — which is the whole point.
 *
 * So each supply-change log claims the next free ordinal slot for its
 * `(tx, delta)`, and each cause event consumes the next unconsumed slot. The
 * k-th change of a given signed amount in a transaction pairs with the k-th
 * cause event of that amount: deterministic, order-stable under replay, and
 * unable to drop a row because slots are appended rather than overwritten.
 *
 * Written through the same indexing store as every other table, so a slot
 * written earlier in the transaction is visible to the cause handler that reads
 * it, and reorg rollback reverts slots with the rows they point at.
 */
export const supplyChangePair = onchainTable("supply_change_pair", (t) => ({
  id: t.text().primaryKey(), // `${txHash}:${delta}:${ordinal}`
  changeId: t.text().notNull(), // -> supply_change.id
  // The cause LOG that claimed this slot (`${txHash}:${logIndex}`), or null while
  // unclaimed. Storing which log consumed the slot — rather than a bare boolean —
  // is what makes replay idempotent: a cause event replayed over an already-paired
  // stream recognises its own mark and stops, instead of consuming the next slot
  // and re-attributing a second change.
  consumedBy: t.text(),
}));

export const redemption = onchainTable("redemption", (t) => ({
  id: t.text().primaryKey(),
  blockNumber: t.bigint().notNull(),
  txHash: t.hex().notNull(),
  ts: t.bigint().notNull(),
  redeemer: t.hex().notNull(),
  recipient: t.hex().notNull(),
  q: t.bigint().notNull(),
  payout: t.bigint().notNull(),
  bPre: t.bigint().notNull(),
  sPre: t.bigint().notNull(),
}));

export const strategicFlow = onchainTable(
  "strategic_flow",
  (t) => ({
    id: t.text().primaryKey(),
    blockNumber: t.bigint().notNull(),
    txHash: t.hex().notNull(),
    ts: t.bigint().notNull(),
    direction: t.text().notNull(), // 'in' | 'out'
    // FR-9.1 classes. NEVER 'backing' (FR-14.4) — enforced by a real CHECK
    // constraint applied at startup by `src/schema-constraints.ts`, and again by
    // `api/index.ts` refusing to serve a row whose class says otherwise. Before
    // audit M-2 this comment pointed at sql/schema.sql, which nothing executes.
    class: t.text().notNull(),
    asset: t.hex().notNull(),
    amount: t.bigint().notNull(),
    counterparty: t.hex().notNull(),
  }),
  (table) => ({
    classIdx: index().on(table.class),
  })
);
