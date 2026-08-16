// Stands in for BOTH `ponder:registry` and `ponder:schema` while the delivered
// handler module is under test. Tables are opaque handles to the handlers — they
// only ever pass them to the store — so a name tag is the whole of what a table
// needs to be here.

/** name -> indexing function, populated by `ponder.on(...)` at import time. */
export const handlers = new Map();

export const ponder = {
  on(name, fn) {
    handlers.set(name, fn);
  },
  // The API module registers routes on the same object; unused by these tests
  // but present so importing it would not throw.
  get() {},
  post() {},
  use() {},
};

export function resetRegistry() {
  handlers.clear();
}

const table = (name) => ({ __table: name });

export const settlement = table('settlement');
export const supplyChange = table('supplyChange');
export const supplyChangePair = table('supplyChangePair');
export const redemption = table('redemption');
export const strategicFlow = table('strategicFlow');

export default { settlement, supplyChange, supplyChangePair, redemption, strategicFlow };
