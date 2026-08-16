# Sprint 6 — audit remediation (pass 3)

**Node:** `/implement sprint-6` — bounded remediation of the security audit's six MEDIUM findings.
No review, no re-audit, no commit, no acceptance.
**Branch:** `sprint-6` · **Baseline/HEAD:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377` (unchanged)
**Date:** 2026-08-15

## Identity

| | Entry | Exit |
|---|---|---|
| Group A — implementation subject | 58 files, `0aa114b4a5d0f8b0…` (matched) | **61 files, `01921956f5d6fd243197dc605af0f7c84fbe276f94df347fa3a5a72b67ede489`** |
| Group B — activated authority | 2 files, `1e6515cc1c79f553…` | 2 files, `1e6515cc1c79f553…` — **unchanged** |

Entry identity reproduced exactly before any mutation. Authority is byte-identical at exit: no PRD, SDD,
sprint plan, `docs/authority/**`, or accepted pin was touched. Both lockfiles are byte-identical to the
review-era manifest (`indexer/package-lock.json` `7c305c97…`, `web/package-lock.json` `f2fcf22b…`), so
repeated `npm ci` rewrote nothing.

**Subject grew by 3** (58 → 61): two new files, plus `.github/workflows/provenance.yml`, which was tracked
and unmodified before and therefore only now enters the derived subject.

## Disposition

| Finding | Status | Files |
|---|---|---|
| M-1 cause over-attribution in the fold | **Remediated** | `indexer/src/lib/reconstruct.mjs`, `indexer/test/reconstruct.test.mjs`, `indexer/src/index.ts` (comment) |
| M-2 DDL constraints never applied | **Remediated** | `indexer/src/schema-constraints.ts` (new), `indexer/ponder.schema.ts`, `indexer/src/index.ts`, `indexer/sql/schema.sql`, `indexer/src/api/index.ts` |
| M-3 CI executes no off-chain code | **Remediated** | `.github/workflows/provenance.yml` |
| M-4 `npx serve` dynamic execution | **Remediated** | `web/package.json` |
| M-5 lifecycle scripts enabled | **Remediated** | `indexer/.npmrc`, `web/.npmrc` |
| M-6 no chain check before signing | **Remediated** | `web/components/WalletFlows.jsx`, `web/lib/wagmi.js`, `web/lib/truth-copy.js`, `web/tests/chain-guard.spec.js` (new) |

### M-1 — matching now consumes evidence

`reconstruct.mjs` matched causes with non-consuming `.some()`. Matching now takes the first *unconsumed*
cause record and marks it spent through a `WeakSet` (identity-marked, so nothing leaks into the returned
`redemptions`/`settlements` records). Applied to mints too: one `Settled` accounts for one mint. Candidate
order is fixed and the cause lists are built in log order, so attribution is deterministic. A burn whose
cause was already spent falls to the by-exclusion `other_authorized_burn` — the same path a bare holder
self-burn takes (F-2) — and never inherits the spent cause.

This is the discipline the shipped handler already enforced with pairing slots, so the two reconstructions
now agree on attribution as well as identity.

**Regression + discrimination.** The audit PoC is `test/reconstruct.test.mjs` — "audit M-1: one cause event
cannot classify two burns" — asserting the property the brief specified: the second burn must not consume
the spent cause and is classified on its own remaining evidence. A companion test covers the mint side.
Reverting the consumption check kills **exactly 1 of 13** tests in that file; the file restores
byte-identical (`f4a9bb66…` before and after).

### M-2 — invariants made real in the running database

Ponder's `PgCreateTableConvertor` emits columns, NOT NULL, defaults and composite PKs only; there is no
ADD CONSTRAINT convertor and `check` is not among the drizzle helpers ponder re-exports. So:

- **Occurrence uniqueness** is expressed natively — `uniqueIndex().on(txHash, logIndex)` in
  `ponder.schema.ts`, which ponder emits as a real `CREATE UNIQUE INDEX`.
- **`legs_sum`, `cause_domain`, `class_is_never_backing`, `direction_domain`** are applied by
  `src/schema-constraints.ts` at `setup` — once, before the first row is indexed — through the Drizzle
  handle ponder already exposes as `db.sql`. **No new dependency, no migration runner, no second database
  path.** The schema and the real column names are resolved from the catalog rather than assumed, because
  ponder builds into an instance-specific schema and emits snake_case while the drizzle column object
  still reports the camelCase key.
- **`ref_epoch_id` FK is deliberately NOT applied**: it would couple row-deletion order during a reorg
  rollback, where ponder unwinds tables independently. Recorded in-file and in `sql/schema.sql`.

**Proof, not assertion.** `pg_constraint` says a constraint is *defined*; it does not say the expression
*discriminates*. Each constraint is therefore proven to bite: a TEMP clone (`LIKE … INCLUDING CONSTRAINTS`)
with NOT NULL dropped, a violating insert that must fail as a **check violation** (SQLSTATE 23514 —
asserted specifically, so a NOT NULL rejection cannot masquerade as a pass), and a satisfying insert that
must succeed. Failure throws and the indexer refuses to start.

**Discrimination.** Making `legs_sum` vacuous (`1 = 1`) — which still appears in `pg_constraint` and would
satisfy any existence check — fails the runtime gate with
`legs_sum admitted a row it must reject — it is inert`. File restored byte-identical.

Two comments that claimed inactive defences are corrected (`ponder.schema.ts`, `src/api/index.ts`), and
`sql/schema.sql` now states plainly that it is a consumer reference shape that nothing executes.

### M-3 — CI now executes the off-chain surface

Two jobs added to `provenance.yml`, following the file's existing conventions (SHA-pinned checkout,
explicit assertions, a paired negative-demonstration job):

- **`offchain`** — asserts a usable Node from the runner image (**no `setup-node` action added**),
  `npm ci --ignore-scripts` in both roots, asserts no manifest/lockfile drift, then the accepted-pin gate,
  indexer unit suite, ponder codegen gate, web unit suite, a **production** static export, the
  static-export/no-server gate and the bundled-RSC gate.
- **`offchain-pin-negative-demonstration`** — mutates one accepted pin, asserts the gate FAILS, restores
  the exact bytes, asserts it passes again.

Every configured command was executed locally. The negative demonstration was run verbatim: `next`
`15.1.12 → 15.1.11` produces `VERDICT: FAIL — web: next@15.1.11 != accepted 15.1.12`, and restoring
returns `VERDICT: PASS`.

**Running the exact CI sequence caught a real defect** that the codegen gate alone did not: an
extensionless `./schema-constraints` import resolved under ponder's bundler but not under Node's loader in
`test/handlers.test.mjs`, silently dropping that file's 11 tests. Fixed with an explicit `.ts` extension;
both loaders now resolve it (24/24).

Playwright and the ponder runtime gate are deliberately **not** in CI: the first needs a browser download
and the second a live anvil, and neither is in the brief's required minimum. Both are run locally below.

### M-4 — dynamic execution removed

`web/package.json` `start` is now `node scripts/serve-static.mjs` — the dependency-free server the
repository already contains and whose header argues this exact point. Playwright already used it, so the
runtime behaviour is unchanged and already covered. A repository-wide search of the off-chain surface for
`npx|npm exec|curl|wget|bunx|pnpm dlx` returns **no remaining matches**.

### M-5 — install posture fails closed

`ignore-scripts=true` in both `.npmrc` roots, restated as `npm ci --ignore-scripts` in CI so CI can never
be softer than a developer machine. Verified by clean `rm -rf node_modules && npm ci` in both roots
(exit 0 each), then: pins gate PASS, ponder codegen PASS (this is the esbuild path), indexer 24/24, web
units 10/10, production build exit 0, static + RSC gates PASS, Playwright 46/46. **Nothing in the accepted
surface depended on a lifecycle script**, so no `HITL_REQUIRED` exception is needed. The stale
`engine-strict` comment in `indexer/.npmrc` — which described a control that setting does not implement —
is corrected in passing.

### M-6 — chain verified before any signature

Enforced twice, deliberately:

1. **UI gate.** `useAcceptedChain()` compares the wallet's reported `chainId` against `CHAIN_ID`. On a
   mismatch both flows render `<WrongNetwork/>`, which names the mismatch and offers a `useSwitchChain()`
   action, and the submit button is **not rendered at all** — the same "withdraw the transaction" posture
   the no-price case already used.
2. **Send-time assertion.** All three `writeContract` calls now pass `chain: acceptedChain`, so viem
   asserts the wallet's current chain before signing. This closes the window between the render that drew
   the button and the click that fires it.

A declined switch is not treated as success: readiness only advances when the wallet actually reports the
accepted chain.

**Regression.** `web/tests/chain-guard.spec.js` (5 tests, self-contained harness so the approved M-4
suite is not put at risk): wrong-chain take → zero sends; wrong-chain redeem → zero sends; declined switch
→ still blocked; correct chain → the canonical take still sends **with the M-4 guard intact** (`P1`);
`chainChanged` after render → readiness invalidated, zero sends.

**Discrimination.** Ignoring the wallet's chain (`onAcceptedChain: isConnected`) kills **4 of 5** — the
survivor is the correct-chain positive control, which is the right signature. File restored byte-identical.

## Verification — all reproduced locally

| Gate | Result |
|---|---|
| `forge test` | **397 passed / 0 failed** (33 suites) |
| indexer units (`npm test`) | **24 passed / 0 failed** (22 before, +2 M-1 regressions) |
| web units | **10 passed / 0 failed** |
| Playwright (full) | **46 passed / 0 failed** (41 before, +5 M-6) |
| accepted-pin gate | **PASS** (indexer closure 391, web closure 371) |
| pin gate negative demonstration | **FAILS closed** on a one-digit mutation, PASSES after restore |
| ponder codegen gate | **PASS** |
| **ponder runtime gate** (live anvil, constraints applied + proven) | **PASS** |
| constraint negative control | vacuous `legs_sum` → **gate FAILS** (`it is inert`) |
| **live independent reconstruction** | **PASS** — 75 logs → 5 settlements, 9 attributed supply changes, **0 ambiguities**, equal to chain state |
| static-export / no-server gate | **PASS** |
| bundled-RSC gate | **PASS** |
| clean `npm ci --ignore-scripts` both roots | **exit 0** |

Live reconstruction burn causes after the M-1 fix: `redemption_burn` 1200e18, `vyrf_burn` 25.209…e18,
`other_authorized_burn` 600e18 — all five accepted causes reconstruct, zero ambiguities.

## Carried LOW / residual findings — unchanged

Not remediated, faithfully carried:

- **L-1 API input validation** (negative `limit`, unguarded `BigInt(param)`, unallowlisted `?class=`).
- **L-3 read→click price window** — remains LOW hardening. M-6 did not change it, and the closed review
  M-4 property is intact (positively re-verified by the new correct-chain test, which asserts the guard is
  still `P1`).
- **L-4 codegen verdict wording** — no security impact; unchanged.
- **L-5 `serve-static.mjs` prefix check and `0.0.0.0` bind** — M-4 promotes this file to `npm start`, so it
  is now more exposed than when graded. **Deliberately not touched**: it is a LOW the audit scoped, and
  changing it here would widen this node past the six MEDIUMs. Flagged for the re-audit as the one LOW
  whose reachability this remediation increased.
- **Rendered payout coverage** — unchanged, non-blocking.

**L-2 shared `web/out/`** — partially retired by M-3, recorded rather than scope-crept: the CI job always
runs a **production** build immediately before the two gates that read `out/`, so CI can never inspect a
leftover test artifact. The local shared-directory behaviour is unchanged and remains LOW.

## Process observations — not product, not actioned

The audit-role Write restriction (C-PROC-001) and the stale `grimoires/loa/ledger.json.lock` were carried
as process observations and deliberately left alone.
