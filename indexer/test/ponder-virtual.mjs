// A test substrate for the DELIVERED ponder handlers.
//
// `src/index.ts` imports the virtual modules `ponder:registry` and
// `ponder:schema`, which only exist inside ponder's own vite build. That is why
// the shipped handlers had no test of their own and a reachable identity defect
// survived review: the only executable proof was the standalone fold in
// `src/lib/reconstruct.mjs`, which is a different implementation.
//
// So the virtual specifiers are resolved here, and the real handler module is
// imported and driven directly. What runs in these tests is the shipped file,
// not a copy of its logic.
//
// The store mirrors ponder's indexing-store semantics that the handlers rely on:
// `insert().values().onConflictDoNothing()`, `find(table, key)` and
// `update(table, key).set(patch)`, all keyed by primary key, all read-your-writes
// within the run.

import { registerHooks } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const STUB = pathToFileURL(join(HERE, 'ponder-virtual-stub.mjs')).href;

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === 'ponder:registry' || specifier === 'ponder:schema') {
      return { url: STUB, shortCircuit: true };
    }
    return nextResolve(specifier, context);
  },
});

export { handlers, resetRegistry } from './ponder-virtual-stub.mjs';

/** An in-memory stand-in for ponder's indexing store. */
export function makeStore() {
  /** @type {Map<string, Map<string, any>>} */
  const tables = new Map();
  const tableOf = (t) => {
    const name = t?.__table ?? String(t);
    if (!tables.has(name)) tables.set(name, new Map());
    return tables.get(name);
  };
  const keyOf = (table, key) => String(key[Object.keys(key)[0]]);

  const db = {
    insert(table) {
      return {
        values(v) {
          const rows = tableOf(table);
          const id = String(v.id ?? v.epochId);
          let settled = false;
          const apply = (onConflict) => {
            if (settled) return;
            settled = true;
            if (rows.has(id)) {
              if (onConflict) rows.set(id, { ...rows.get(id), ...onConflict(rows.get(id)) });
              return;
            }
            rows.set(id, { ...v });
          };
          return {
            onConflictDoNothing: async () => apply(null),
            onConflictDoUpdate: async (f) => apply(f),
            then: (res, rej) => Promise.resolve().then(() => apply(null)).then(res, rej),
          };
        },
      };
    },
    async find(table, key) {
      return tableOf(table).get(keyOf(table, key));
    },
    update(table, key) {
      return {
        set: async (patch) => {
          const rows = tableOf(table);
          const id = keyOf(table, key);
          const cur = rows.get(id);
          if (!cur) throw new Error(`update of a missing row: ${id}`);
          rows.set(id, { ...cur, ...patch });
        },
      };
    },
  };

  return { db, rows: (name) => [...(tables.get(name)?.values() ?? [])], tables };
}

/** Build the `{ event, context }` shape a ponder indexing function receives. */
export function evt({ txHash, logIndex, args, address = '0x00000000000000000000000000000000000000aa', blockNumber = 1n, timestamp = 1000n }) {
  return {
    event: {
      args,
      log: { logIndex, address },
      block: { number: blockNumber, timestamp },
      transaction: { hash: txHash },
    },
  };
}
