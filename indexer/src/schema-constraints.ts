// Database invariants that ponder's schema builder cannot express (audit M-2).
//
// WHY THIS FILE EXISTS
//
// `sql/schema.sql` carried `legs_sum`, the cause domain and the never-'backing'
// rule as CHECK constraints, and two source comments described them as active
// defences. Nothing executed that file: ponder owns the DDL and builds it from
// `ponder.schema.ts`. Its CREATE TABLE convertor emits columns, NOT NULL,
// defaults and composite primary keys — and nothing else. There is no
// ADD CONSTRAINT convertor, and `check` is not among the drizzle helpers ponder
// re-exports. So the constraints existed only as text in an unrun file.
//
// Uniqueness IS expressible in the schema (`uniqueIndex`, which ponder emits as
// a real CREATE UNIQUE INDEX) and lives in `ponder.schema.ts` where it belongs.
// The CHECKs are applied here instead, once, at `setup` — before any row is
// indexed — using the Drizzle handle ponder already exposes as `db.sql`. No new
// dependency, no migration runner, no second database path.
//
// NOT APPLIED, deliberately: `supply_change.ref_epoch_id -> settlement(epoch_id)`.
// A foreign key would couple row-deletion ORDER during a reorg rollback, where
// ponder unwinds tables independently; a correct rollback could fail on a
// constraint that adds no truth the settlement row does not already carry. It
// stays a reference-shape declaration in sql/schema.sql, described as such.

import { sql } from "ponder";

// `db.sql.execute` returns positional rows (`[["public"]]`) under the embedded
// driver and object rows under node-postgres. Read both rather than pinning the
// shape: guessing wrong fails OPEN — the lookup returns undefined and the
// constraint is skipped — which is the exact class of bug M-2 is about.
const rowsOf = (res: any): any[] => res?.rows ?? res ?? [];
const cell = (r: any): any => (Array.isArray(r) ? r[0] : Object.values(r ?? {})[0]);
const firstCell = (res: any): any => {
  const r = rowsOf(res)[0];
  return r === undefined || r === null ? undefined : cell(r);
};

/**
 * Each check is built from the table's REAL column names, resolved from the
 * catalog. ponder emits snake_case while the drizzle column object still
 * reports the camelCase key, so neither the JS key nor a hand-written guess is
 * safe to paste into DDL.
 */
type Probe = Record<string, string>;
type Spec = {
  table: string;
  name: string;
  check: (c: (k: string) => string) => string;
  /** A row the constraint MUST reject, and one it must admit. */
  bad: Probe;
  good: Probe;
};

const SPECS: Spec[] = [
  {
    // FR-4.1: the three legs are a partition of the price. A decoder bug or an
    // ABI drift that broke this would otherwise be served as truth.
    table: "settlement",
    name: "legs_sum",
    check: (c) => `${c("kingLeg")} + ${c("strategicLeg")} + ${c("reserveLeg")} = ${c("price")}`,
    bad: { kingLeg: "1", strategicLeg: "1", reserveLeg: "1", price: "99" },
    good: { kingLeg: "1", strategicLeg: "1", reserveLeg: "1", price: "3" },
  },
  {
    table: "supply_change",
    name: "cause_domain",
    check: (c) =>
      `${c("cause")} IN ('genesis','settlement_mint','redemption_burn','vyrf_burn','other_authorized_burn')`,
    bad: { cause: "'not_a_cause'" },
    good: { cause: "'genesis'" },
  },
  {
    // FR-14.4: Strategic value is never labelled backing, at the storage layer
    // and not only at the surface that renders it.
    table: "strategic_flow",
    name: "class_is_never_backing",
    check: (c) => `lower(${c("class")}) NOT LIKE '%backing%'`,
    bad: { class: "'HardBacking'" },
    good: { class: "'ContributedPrincipal'" },
  },
  {
    table: "strategic_flow",
    name: "direction_domain",
    check: (c) => `${c("direction")} IN ('in','out')`,
    bad: { direction: "'sideways'" },
    good: { direction: "'in'" },
  },
];

/**
 * Apply every CHECK, idempotently, wherever ponder actually put the tables.
 *
 * The schema is resolved from the catalog rather than assumed: ponder builds
 * into an instance-specific schema, and a constraint applied to the wrong copy
 * would be a constraint that silently guards nothing.
 *
 * Throws if a constraint cannot be established. That is deliberate — an indexer
 * that believes it is constrained and is not is precisely the failure this file
 * was written to end.
 */
export async function applySchemaConstraints(db: any): Promise<string[]> {
  const applied: string[] = [];

  for (const spec of SPECS) {
    const schema = firstCell(
      await db.sql.execute(
        sql.raw(`
          SELECT n.nspname
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relname = '${spec.table}' AND c.relkind = 'r'
          ORDER BY (n.nspname = current_schema()) DESC, c.oid DESC
          LIMIT 1
        `),
      ),
    );
    if (!schema) {
      throw new Error(
        `schema-constraints: table ${spec.table} not found, so ${spec.name} cannot be applied`,
      );
    }

    const columns = rowsOf(
      await db.sql.execute(
        sql.raw(`
          SELECT column_name FROM information_schema.columns
          WHERE table_schema = '${schema}' AND table_name = '${spec.table}'
        `),
      ),
    ).map(cell) as string[];

    const flat = (s: string) => s.toLowerCase().replace(/_/g, "");
    const c = (key: string): string => {
      const real = columns.find((n) => flat(n) === flat(key));
      if (!real) {
        throw new Error(
          `schema-constraints: ${spec.table} has no column matching '${key}' `
            + `(saw: ${columns.join(", ")})`,
        );
      }
      return `"${real}"`;
    };

    const target = `"${schema}"."${spec.table}"`;
    // ADD CONSTRAINT has no IF NOT EXISTS in PostgreSQL 16; swallowing only
    // duplicate_object keeps a restart idempotent without hiding a real failure.
    await db.sql.execute(
      sql.raw(`
        DO $do$ BEGIN
          ALTER TABLE ${target} ADD CONSTRAINT "${spec.name}" CHECK (${spec.check(c)});
        EXCEPTION WHEN duplicate_object THEN NULL;
        END $do$;
      `),
    );

    const verify = await db.sql.execute(
      sql.raw(`
        SELECT 1 FROM pg_constraint con
        JOIN pg_class cl ON cl.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = cl.relnamespace
        WHERE con.conname = '${spec.name}' AND cl.relname = '${spec.table}'
          AND n.nspname = '${schema}' AND con.contype = 'c'
      `),
    );
    if (rowsOf(verify).length === 0) {
      throw new Error(`schema-constraints: ${spec.name} was not established on ${target}`);
    }

    await proveItBites(db, spec, target, c);
    applied.push(`${spec.table}.${spec.name}`);
  }

  return applied;
}

/**
 * Prove the constraint REJECTS a violating row and ADMITS a valid one.
 *
 * `pg_constraint` says a constraint is defined; it does not say the expression
 * discriminates. A CHECK that is present but vacuous reads identically in the
 * catalog and guards nothing — which is one step from the state M-2 found.
 *
 * The probe is a TEMP table cloned `INCLUDING CONSTRAINTS`, so real rows are
 * never touched and no transaction of the indexer's is put at risk. NOT NULL is
 * dropped on the clone so the only thing that can reject the bad row is the
 * CHECK itself, and that is asserted by SQLSTATE 23514 rather than by "it threw".
 */
async function proveItBites(db: any, spec: Spec, target: string, c: (k: string) => string) {
  const probe = `probe_${spec.name}`;
  const cols = (p: Probe) => Object.keys(p).map(c).join(", ");
  const vals = (p: Probe) => Object.values(p).join(", ");

  await db.sql.execute(sql.raw(`DROP TABLE IF EXISTS pg_temp."${probe}"`));
  await db.sql.execute(
    sql.raw(`CREATE TEMP TABLE "${probe}" (LIKE ${target} INCLUDING CONSTRAINTS)`),
  );
  // Isolate the CHECK: without this a NOT NULL rejection (23502) would look like
  // a passing test while the CHECK sat inert.
  for (const r of rowsOf(
    await db.sql.execute(
      sql.raw(`SELECT column_name FROM information_schema.columns
               WHERE table_name = '${probe}' AND is_nullable = 'NO'`),
    ),
  )) {
    await db.sql.execute(
      sql.raw(`ALTER TABLE pg_temp."${probe}" ALTER COLUMN "${cell(r)}" DROP NOT NULL`),
    );
  }

  let err: any = null;
  try {
    await db.sql.execute(
      sql.raw(`INSERT INTO pg_temp."${probe}" (${cols(spec.bad)}) VALUES (${vals(spec.bad)})`),
    );
  } catch (e: any) {
    err = e;
  }
  if (err === null) {
    throw new Error(`schema-constraints: ${spec.name} admitted a row it must reject — it is inert`);
  }
  // Drivers bury SQLSTATE differently (PGlite wraps, node-postgres exposes
  // `.code`), so look in every documented place AND fall back to the message.
  const code = err.code ?? err.cause?.code ?? err.originalError?.code ?? "";
  const text = `${err.message ?? ""} ${err.cause?.message ?? ""}`;
  const isCheckViolation = code === "23514" || /check constraint/i.test(text);
  if (!isCheckViolation) {
    throw new Error(
      `schema-constraints: ${spec.name} rejected the probe with code '${code}' / "${text.trim().slice(0, 200)}" — `
        + `not a check violation, so the probe did not test what it claims`,
    );
  }

  await db.sql.execute(
    sql.raw(`INSERT INTO pg_temp."${probe}" (${cols(spec.good)}) VALUES (${vals(spec.good)})`),
  );
  await db.sql.execute(sql.raw(`DROP TABLE pg_temp."${probe}"`));
}
