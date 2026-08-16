// Read-only REST — the JSON mirror of the §3.3 tables (sdd.md:L795).
//
// `GET /settlements`, `/settlements/:epochId`, `/supply-changes?cause=`,
// `/strategic-flows?class=`, `/stats`.
//
// No write endpoints, no auth, no server-side session state — the data is public
// and the surface is a mirror, not an authority (sprint.md:L448-L450). Every
// route below is a GET; there is deliberately no POST/PUT/PATCH/DELETE anywhere
// in this file, and `/` documents that absence rather than leaving it implied.

// API SURFACE. Routes register on the `ponder` registry, and the drizzle handle
// arrives per-request as `c.db`. The previous `import { db } from "ponder:api"`
// named a virtual module that does not exist in the accepted pin `ponder@0.8.33`
// (it registers `ponder:registry`, `ponder:schema` and `ponder:internal` only,
// and `ponder:api` arrives in a later major). That import failed to resolve, which
// aborted the whole build — config, schema and codegen with it — so no ponder
// command could run. `scripts/verify-ponder-codegen.mjs` is the standing gate
// that makes that class of failure loud.

import { ponder } from "ponder:registry";
import schema from "ponder:schema";
import { desc, eq, sql } from "ponder";

/** 256-bit values leave as strings — JSON numbers would silently lose precision. */
const j = (v: unknown): unknown =>
  typeof v === "bigint" ? v.toString()
    : Array.isArray(v) ? v.map(j)
    : v && typeof v === "object" ? Object.fromEntries(Object.entries(v).map(([k, x]) => [k, j(x)]))
    : v;

const LIMIT_MAX = 500;
const limitOf = (c: { req: { query: (k: string) => string | undefined } }) =>
  Math.min(Number(c.req.query("limit") ?? 100) || 100, LIMIT_MAX);

ponder.get("/", (c) =>
  c.json({
    service: "vux-indexer",
    role: "read-only mirror of chain events; on-chain events remain canonical (sdd.md:L930)",
    writes: "none — this API has no write endpoints and holds no keys or custody",
    routes: ["/settlements", "/settlements/:epochId", "/supply-changes?cause=", "/strategic-flows?class=", "/stats"],
    note: "strategic values are never labelled backing (FR-14.4); strategic_nav_disclosed is disclosure, not event-derived truth",
  })
);

ponder.get("/settlements", async (c) => {
  const rows = await c.db.select().from(schema.settlement).orderBy(desc(schema.settlement.epochId)).limit(limitOf(c));
  return c.json(j(rows));
});

ponder.get("/settlements/:epochId", async (c) => {
  const epochId = BigInt(c.req.param("epochId"));
  const [row] = await c.db.select().from(schema.settlement).where(eq(schema.settlement.epochId, epochId)).limit(1);
  if (!row) return c.json({ error: "no settlement with that epochId" }, 404);
  return c.json(j(row));
});

ponder.get("/supply-changes", async (c) => {
  const cause = c.req.query("cause");
  const CAUSES = ["genesis", "settlement_mint", "redemption_burn", "vyrf_burn", "other_authorized_burn"];
  if (cause && !CAUSES.includes(cause)) {
    return c.json({ error: `unknown cause; the domain is ${CAUSES.join(" | ")}` }, 400);
  }
  const q = c.db.select().from(schema.supplyChange);
  const rows = await (cause ? q.where(eq(schema.supplyChange.cause, cause)) : q)
    .orderBy(desc(schema.supplyChange.blockNumber))
    .limit(limitOf(c));
  return c.json(j(rows));
});

ponder.get("/strategic-flows", async (c) => {
  const cls = c.req.query("class");
  const q = c.db.select().from(schema.strategicFlow);
  const rows = await (cls ? q.where(eq(schema.strategicFlow.class, cls)) : q)
    .orderBy(desc(schema.strategicFlow.blockNumber))
    .limit(limitOf(c));
  // Defence in depth behind the `class_is_never_backing` CHECK that
  // `src/schema-constraints.ts` applies at startup: a class that says "backing"
  // must never reach a consumer, because FR-14.4 is a statement about what users
  // are told, not only about what the database stores. Both layers are real —
  // audit M-2 found this comment pointing at a constraint nothing applied.
  const offending = rows.filter((r) => /backing/i.test(String(r.class)));
  if (offending.length > 0) {
    return c.json({ error: "refusing to serve a strategic flow whose class says 'backing' (FR-14.4)" }, 500);
  }
  return c.json(j(rows));
});

ponder.get("/stats", async (c) => {
  const [supply] = await c.db
    .select({ total: sql<string>`coalesce(sum(${schema.supplyChange.delta}), 0)` })
    .from(schema.supplyChange);
  const [mints] = await c.db
    .select({ total: sql<string>`coalesce(sum(${schema.settlement.qMint}), 0)`, raw: sql<string>`coalesce(sum(${schema.settlement.qRaw}), 0)` })
    .from(schema.settlement);
  const [contributed] = await c.db
    .select({ total: sql<string>`coalesce(sum(${schema.strategicFlow.amount}), 0)` })
    .from(schema.strategicFlow)
    .where(eq(schema.strategicFlow.class, "ContributedPrincipal"));

  return c.json({
    currentSupply: String(supply?.total ?? "0"),
    completedMints: String(mints?.total ?? "0"),
    cumulativeRawOpportunity: String(mints?.raw ?? "0"),
    strategicContributedPrincipal: String(contributed?.total ?? "0"),
    // Not derivable from events: marks are not transfers (INV-30). `null` is the
    // truthful value for "not disclosed" and is never coerced to 0, which would
    // read as a measured absence of value.
    strategicNavDisclosed: null,
    disclaimer:
      "Hard backing B is the Reserve's raw canonical WETH balance and nothing else (INV-10). Strategic value is not backing (FR-14.4).",
  });
});

