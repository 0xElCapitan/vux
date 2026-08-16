# Sprint 6 — Review Remediation, pass 1

**Node:** `/implement sprint-6` (remediation) · **Branch:** `sprint-6` · **Baseline:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377` (unchanged, no commit)
**Terminal state:** **`SPRINT_6_REMEDIATION_INCOMPLETE`** — 3 of 5 findings remediated and verified; H-2 and M-2 not started.

## Starting identity (verified before mutation)

Re-derived the reviewed subject from git: 45 files, fingerprint
`20289436748666cab658c9a4e6777476e2f9aa854ec217dff39cca6b05029e4b` — **exact match** to
`evidence/subject-manifest.md`. `/review-sprint` had added only `engineer-feedback.md`.

## New implementation subject

**51 files** · fingerprint `d406952ae5b2cd94acdfca5152f192fab2f9ef3c531ce7e4193bbc9c081a5acb`
(`sha256(join("\n", sorted "<sha256>  <path>"))`, same scheme as the manifest).

| Finding | Files changed |
|---|---|
| H-1 | `indexer/src/index.ts`, `indexer/ponder.schema.ts`, `indexer/sql/schema.sql`, `indexer/test/handlers.test.mjs` (new), `indexer/test/ponder-virtual.mjs` (new), `indexer/test/ponder-virtual-stub.mjs` (new) |
| M-1 | `web/lib/units.js` (new), `web/app/redeem/page.jsx`, `web/tests/units.test.mjs` (new), `web/playwright.config.js`, `web/package.json` |
| M-3 | `indexer/src/api/index.ts`, `indexer/ponder.config.ts`, `indexer/scripts/verify-ponder-codegen.mjs` (new), `indexer/package.json`, `.gitignore` |

Sprint 2–5 implementation, `prd.md`/`sdd.md`/`sprint.md`, and all `docs/authority/**` are byte-unchanged
(`git status --porcelain` over each: empty). No dependency was added; the accepted pin census is untouched.

---

## H-1 — streaming event identity · **REMEDIATED**

Supply changes are now keyed by the log's own identity, `${txHash}:${logIndex}`, never by content.
`ponder.schema.ts` already documented that identity at its `id` column; the handler contradicted it.

Because the key is no longer a function of the amount, a cause handler can no longer recompute the key of
the row it refines, so pairing is explicit: `supplyChangePair` gives each change the next ordinal slot for
its `(tx, delta)`, and each cause event consumes the next unclaimed slot. The k-th change of a signed amount
pairs with the k-th cause event of that amount.

Both sides are idempotent **by log identity** — a slot records `consumedBy` (the cause log that claimed it),
not a boolean. That was not the first design: the initial version stored a bare `consumed` flag, and
`handlers.test.mjs` caught it — on replay the transfer re-appended a slot and the redemption re-attributed a
second burn. The test is in the suite as the permanent guard.

`indexer/sql/schema.sql` gained `log_index` and `UNIQUE (tx_hash, log_index)` so the database enforces
one-row-per-log rather than trusting the ingesting code. The surrogate `BIGSERIAL` key is retained, so the
accepted §3.3 shape is unchanged for consumers.

**Discriminating regression:** `indexer/test/handlers.test.mjs` drives the **shipped** `src/index.ts` — not a
copy — through a resolver that supplies the `ponder:registry` / `ponder:schema` virtual modules. The reviewer
PoC is asserted directly: two `VUX.burn(5e18)` logs in one transaction produce **two** rows with ids
`0xdeadbeef:0` and `0xdeadbeef:1` and a summed delta of `-2 x`. Under the old key both logs computed
`tx:burn:5000000000000000000` and the second was discarded, so the test fails against the previous
implementation by construction. Permissionless burns are untouched and idempotency is strengthened, not
weakened.

**11 tests, all passing.** Also covered: equal mints, identical burns in different transactions, redemption
and VYRF and settlement attribution, **two equal redemptions in one transaction both recorded and both
attributed**, F-5 zero-amount cause events, an orphan cause event, and whole-stream replay.

## M-1 — floating-point wei conversion · **REMEDIATED**

`BigInt(Math.trunc(Number(amount) * 1e18))` is gone. `web/lib/units.js` parses the decimal string directly
(split, pad, `BigInt`) with no binary floating-point intermediary anywhere on the path, and
`previewRedeemRaw` computes `floor(B x q / S)` on integers. Excess precision is **refused with a visible
message**, never truncated — truncating would quote an amount the user did not type. The rendered quote and
the raw quantity come from the same `parseUnits18` result.

`web/lib/units.js` is deliberately free of React and chain imports so it is testable under `node --test`;
the copy suite runs with no RPC, so the quote branch never executes there.

**Discriminating regression:** `web/tests/units.test.mjs`, **10 tests, all passing**, pins the exact case
review measured — `12345.6789` now yields `12345678900000000000000`, and the test asserts the old float path
overstated it by exactly `1622016`. Boundaries `1.005`, `1000.000000000000000001`, `0.000000000000000001`
and `999999999.999999999999999999` are asserted against a pure-string reference, and one test asserts that
at least three listed cases genuinely differ from the float path.

**Residual:** these tests exercise the arithmetic, not the rendered branch. Driving the DOM quote path needs
a build with `NEXT_PUBLIC_RPC_URL` set plus `page.route()` RPC mocking — see Remaining work.

## M-3 — the Ponder path · **REMEDIATED (build/codegen/handlers); runtime start not exercised**

Three distinct defects, all previously masked:

1. **`src/api/index.ts` imported `ponder:api`** — a virtual module the accepted pin `ponder@0.8.33` does not
   provide (it registers `ponder:registry`, `ponder:schema`, `ponder:internal`; `ponder:api` arrives in a
   later major). The unresolvable import aborted the whole build, so config, schema and codegen all died with
   it. Routes now register on `ponder.get(...)` with the per-request `c.db`, which is the pinned version's
   actual contract. Read-only surface unchanged: five GET routes, no writes, no auth, and the FR-14.4
   "backing" refusal retained.
2. **`ponder.config.ts` passed `{ kind: "http", url } as never`** as the transport. Ponder calls the
   transport; a plain object is not callable. The `as never` cast is what let a non-functional config ship.
   Now `http(rpc)` from viem.
3. **The failure was silent.** Ponder's shutdown exits **0** and, with the pretty logger, prints nothing —
   so a CI step running `ponder codegen` went green while generating nothing at all.

`indexer/scripts/verify-ponder-codegen.mjs` is the standing gate for (3). It **does not trust the exit
code**: it deletes prior output, runs codegen, and requires `ponder-env.d.ts` and `generated/schema.graphql`
to exist, be non-empty, and mention all five accepted tables. It is demonstrably discriminating — it
returned **FAIL/exit 1** against the broken tree and **PASS** after the fix. It also holds the child's stdin
open, because vite terminates the process on stdin EOF, which is what made codegen non-reproducible outside
an interactive terminal. Note the gate's own output: the CLI exits `3221226505` (a libuv shutdown crash on
Windows) while generating correct artifacts — the exit code is worthless here, which is the gate's whole
point.

**Handlers exercised, not merely type-shaped:** `handlers.test.mjs` executes the delivered indexing functions
against a store with ponder's insert/find/update semantics. That is what M-3 asked for and what H-1's
regression rides on.

**Not done:** starting `ponder dev`/`start` against a synced anvil chain, and routing the Task 6.5
reconstruction through the delivered indexing path. See Remaining work.

## H-2 — wallet flows · **NOT STARTED**

No `take`/`redeem` transaction flow was implemented. `wagmi` and `@tanstack/react-query` remain unused, and
`RESERVE_ABI`/`RIG_ABI` in `web/lib/protocol.js` remain dead exports. The finding stands exactly as review
recorded it.

## M-2 — harvest reconstruction leg · **NOT STARTED**

`script/TruthScenario.sol` still omits the harvest leg, so the integrated event-only scenario still covers
four of five burn causes. Review already established the path (the pool creation code is bytes read from
`out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json`; `extract-abis.mjs` already reads forge artifacts from
Node, so the driver can pass it as a `bytes` argument to a scenario deploy method — no cheatcode needed).
That work was not performed.

---

## Verification

| Gate | Result |
|---|---|
| `forge test` | **397 passed, 0 failed** (33 suites) — unchanged, no Solidity touched |
| indexer suites (`reconstruct` + `handlers`) | **22 passed** (11 pre-existing + 11 new) |
| `web` exact-arithmetic units | **10 passed** |
| `verify-ponder-codegen.mjs` | **PASS** — 5/5 accepted tables; FAILs on the pre-fix tree |
| `verify-accepted-pins.mjs` | **PASS** — census unchanged, integrity on every entry |
| `verify-static-export.mjs` | **PASS** — 6 pages, server bundle absent, 0 markers, 0 call sites |
| Playwright copy/degraded suite | **25 passed** |

Not re-run this pass: `verify-rsc-runtime.mjs` (no dependency changed), the live anvil reconstruction
(unchanged, and its harvest gap is M-2).

## Remaining work

1. **H-2** — implement `take` (with `maxPrice` guard) and `redeem` wallet flows on the pinned wagmi/viem stack.
2. **M-2** — add the harvest leg to `TruthScenario` and prove it event-only.
3. **M-3 residual** — start the delivered ponder app against anvil and route the Task 6.5 reconstruction
   through it.
4. **M-1 residual** — exercise the rendered quote branch via an RPC-mocked Playwright build.

No review, audit, commit, push, landing, or Sprint-7 work was performed. No `COMPLETED` marker written.
