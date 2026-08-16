---
name: a-defined-constraint-may-be-inert
description: |
  A remediation claims "database invariant X is now enforced" and points at
  `pg_constraint`/catalog output showing the constraint defined, or at an
  application self-test that reports success. Neither proves the constraint
  DISCRIMINATES — a syntactically valid but vacuous expression (`CHECK (1=1)`,
  or a CHECK referencing the wrong column after a schema-name/casing mismatch)
  is equally "present" in the catalog and equally reported as applied by a
  self-test that only checks for the absence of an exception. Apply whenever
  auditing a claim that a database constraint, application-level guard, or
  runtime check is now "real"/"enforced"/"active" — especially when the
  claim's own evidence is the same code path that installed the constraint.
  Provides the out-of-band verification technique: open the live database
  directly, independent of the application process, and prove the constraint
  both REJECTS an invalid write (by the correct error code) and ADMITS a valid
  one.
loa-agent: auditing-security
extracted-from: sprint-6 (VUX v1 Truth Surfaces), audit-remediation re-audit — M-2 live database invariants
extraction-date: 2026-08-15
version: 1.0.0
tags:
  - database
  - postgresql
  - constraint-verification
  - security-audit
  - discrimination-testing
---

## Problem

A remediation for "DDL constraints exist in a file nobody executes" (the
original defect) added CHECK constraints applied programmatically at
application startup, plus the application's own runtime gate reporting
`VERDICT: PASS`. Trusting either alone is insufficient:

- **Catalog presence** (`SELECT ... FROM pg_constraint WHERE conname = 'x'`)
  proves a constraint named `x` exists and is syntactically valid. It does
  NOT prove the constraint's expression actually constrains anything — a
  constraint whose check expression was accidentally simplified to `1=1`
  passes this test identically to a correct one.
- **An application self-test that reports success** proves the code path that
  installs the constraint ran without throwing. If that self-test's own
  verification logic has the same blind spot (e.g. it checks "does
  `pg_constraint` contain a row with this name" rather than "does INSERTing a
  violating row actually fail"), the whole chain — install, self-check,
  runtime-gate PASS — can be green while the constraint guards nothing.

The audit needs a check that is adversarial to the CONSTRAINT, not merely
confirmatory of the INSTALLATION.

## Trigger Conditions

### Symptoms

- Remediation evidence for a database/schema-level security or correctness
  claim is: a `pg_constraint`/`information_schema` query result, OR an
  application log line / self-test asserting the constraint applied
  successfully, OR both — but no example of a REJECTED write
- The constraint is applied by application code at runtime (not by a
  reviewable, static migration file) — so "read the migration" is not
  available as an independent check
- A prior version of the same claim was found to be false (a constraint that
  existed in a file but was never executed) — raising the prior of "claims to
  exist" ≠ "does exist and works"

### Context

| Context | Value |
|---------|-------|
| Technology Stack | PostgreSQL (or any RDBMS) fronted by an embedded-database framework (ponder, Prisma, Drizzle-managed schemas) that owns DDL generation and may not expose the full constraint vocabulary (CHECK, in this case, unavailable through the framework's schema DSL) |
| Timing | any re-audit of a "we fixed the missing constraint" remediation |
| Prerequisites | ability to connect to the actual running/on-disk database instance the application uses — for an embedded engine (PGlite, SQLite), this means importing the SAME embedded-driver package the app uses and pointing it at the same data directory, out-of-process |

## Root Cause

Three independent failure surfaces can each individually make a "constraint is
now enforced" claim false while every visible signal says PASS:

1. **Vacuous expression** — the constraint exists and is well-formed SQL but
   does not encode the intended rule (e.g. a refactor that dropped operands,
   or a template-generation bug producing `col = col`).
2. **Wrong target** — the constraint was applied to the wrong table/schema
   (common when the framework builds into a non-`public`, instance-specific
   schema and the installer resolves the wrong one), so `pg_constraint`
   legitimately shows it installed — on a table nothing writes to.
3. **Self-test blind spot** — the "proof" the remediation ships is itself only
   checking for row presence in the catalog, which is exactly what (1) and
   (2) leave unchanged.

None of these are visible from source code review of the constraint's
declaration — the declaration LOOKS correct in all three cases. They are only
visible by attacking the constraint's actual runtime behavior.

## Solution

### Step 1: Open the database the application ACTUALLY uses, independently

Do not go through the application's own DB handle or ORM layer — that reuses
the exact code path under audit. For an embedded engine, import the same
driver package directly and point it at the same on-disk location:

```js
import { PGlite } from '<app>/node_modules/@electric-sql/pglite/dist/index.js';
const db = new PGlite('<app>/.ponder/pglite');   // same data dir the app writes to
await db.waitReady;
```

For a networked database, connect with a plain client library using the same
connection string, bypassing the ORM entirely.

### Step 2: Enumerate what is ACTUALLY in the catalog, with its full definition

```sql
SELECT n.nspname, c.relname, con.conname, pg_get_constraintdef(con.oid)
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE con.contype = 'c' AND n.nspname NOT IN ('pg_catalog','information_schema');
```

Read the returned `pg_get_constraintdef()` text yourself — this is where a
vacuous or wrong-column expression becomes visible, if it hasn't already been
caught by Step 3.

### Step 3: Attempt a violating write against the REAL table, and demand the SPECIFIC error

```js
await db.query('BEGIN');
try {
  await db.query(`INSERT INTO "${schema}".settlement (...) VALUES (...)`); // legs != price
} catch (e) {
  // Assert the SPECIFIC SQLSTATE for a check violation, not just "it threw" —
  // a NOT NULL or type-coercion failure on unrelated columns would also throw,
  // and would falsely read as "the constraint works".
  assert(e.code === '23514' || /check constraint/i.test(e.message));
}
await db.query('ROLLBACK');
```

Rolling back (rather than deleting afterward) guarantees the probe cannot
leave residue in the audited database regardless of driver error-handling
quirks.

### Step 4: Prove a VALID row is still admitted — the constraint is not overbroad either

```js
await db.query('BEGIN');
await db.query(`INSERT INTO "${schema}".settlement (...) VALUES (...)`); // legs == price
await db.query('ROLLBACK');   // no exception expected
```

Skipping this step misses the case where a constraint is too strict (e.g. an
off-by-one in the comparison) and would reject legitimate application traffic
— a different but equally real defect the "it throws on my bad input" test
alone cannot surface.

### Step 5: Cross-driver error-shape gotcha

Different Postgres client libraries surface `SQLSTATE` in different places —
`error.code` under `node-postgres`, `error.cause.code` under some wrapped
drivers (PGlite observed wrapping this way). Check every documented location
AND fall back to matching the human-readable message, rather than assuming one
driver's shape:

```js
const code = err.code ?? err.cause?.code ?? err.originalError?.code ?? '';
const isCheckViolation = code === '23514' || /check constraint/i.test(err.message ?? '');
```

Getting this wrong produces a false negative (the probe reports "not a check
violation" when it actually was), which is the same failure class the whole
technique exists to prevent — verify this detection logic itself against a
known-good and known-bad case before trusting its verdict.

## Verification

### Command

```bash
node audit-db-constraints.mjs
```

### Expected Output

```
=== CHECK constraints actually present in the live DB ===
  vux_runtime_check.settlement.legs_sum  CHECK (((king_leg + strategic_leg) + reserve_leg) = price)
  (total: 4)

=== direct writes against the REAL tables (each rolled back) ===
  PASS  legs_sum rejects legs != price     code=23514 ... violates check constraint "legs_sum"
  PASS  legs_sum admits legs == price      accepted
```

### Checklist

- [ ] Connected to the database the application ACTUALLY writes to, via the
      same embedded driver / connection string — not through the app's own
      handle
- [ ] Read the full constraint definition text from the catalog, not just its
      presence
- [ ] A violating write was attempted against the real table and rejected
      with the SPECIFIC constraint-violation error code, not merely "some
      exception"
- [ ] A valid write was also attempted and admitted, ruling out an overbroad
      constraint
- [ ] Negative control run: deliberately install a vacuous constraint
      (`CHECK (1=1)`) and confirm the audit's own probe methodology reports it
      as failing/inert — proves the probe discriminates, not just the target

## Anti-Patterns

### Don't: accept `pg_constraint` row presence as proof of enforcement

```sql
-- INSUFFICIENT — proves definition, not discrimination
SELECT 1 FROM pg_constraint WHERE conname = 'legs_sum';
```

### Don't: trust the application's own self-test as independent evidence

If the remediation's proof of "constraint applied" is generated by the exact
function that applies the constraint, a bug in that function's verification
logic is invisible to itself. Independent means a DIFFERENT code path,
ideally one you write yourself for the audit.

### Don't: catch-and-assume on the violating-write probe

```js
// INSUFFICIENT — any exception at all is treated as proof, including a NOT
// NULL failure on a column the probe forgot to populate
try { await db.query(badRow); } catch { pass(); }
```

## Related Memory

### Related Skills

- `a-passing-regression-test-proves-nothing-alone` — the general principle
  (green/success is not proof of discrimination) applied here specifically to
  live database constraints rather than application-code regression tests
- `capability-definition-is-not-use` — same family of error: a static/
  catalog-level signal (definition present) mistaken for the dynamic property
  that actually matters (behavior on real input)

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-15 | Initial extraction |

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: auditing-security
  phase: /audit-sprint (re-audit)
  session: sprint-6 audit-remediation re-audit, M-2 live database invariants
```
