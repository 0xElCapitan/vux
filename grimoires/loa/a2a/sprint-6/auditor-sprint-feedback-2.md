# Sprint 6 — Audit-Remediation Re-Audit

**Verdict:** `APPROVED`
**Auditor node:** `/audit-sprint sprint-6` — focused independent re-audit of the remediated tree. No
remediation, no review, no commit, no operator acceptance.
**Branch:** `sprint-6` · **Baseline/HEAD:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377` (unchanged)
**Date:** 2026-08-15

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 6 (5 carried + 1 re-graded with corrected reachability) |

All six prior audit MEDIUMs (M-1…M-6) are **closed**, verified independently rather than inherited from
`remediation-pass-3.md`. No new blocking defect was introduced. The remaining residuals are LOW and all
sit in development/test tooling or in observational surfaces with bounded impact.

## Identity

| Group | Entry | Exit | Result |
|---|---|---|---|
| A — implementation subject | 61 files, `01921956f5d6fd24…` | 61 files, `01921956f5d6fd243197dc605af0f7c84fbe276f94df347fa3a5a72b67ede489` | **MATCH** |
| B — activated authority | 2 files, `1e6515cc1c79f553…` | `1e6515cc1c79f553c68d8172e16c78c183133ad0bc6057bf07cfb400ea267a2c` | **byte-identical** |

Derived mechanically from `git status --porcelain --untracked-files=all`, partitioned per
`evidence/subject-manifest.md`, per-file `sha256`, aggregate `sha256(join("\n", path-sorted "<sha256>  <path>"))`.

**Audit mutated no implementation bytes.** One PoC required a canary file outside `out/`
(`web/outaudit-canary.txt`); it was created, used, deleted, and Group A re-derived to the exact entry
fingerprint. Two temporary source mutations (M-1 discrimination) were restored and hash-verified
byte-identical. All other audit tooling lives in the session scratchpad.

Independent supply-chain corroboration: both lockfiles are byte-identical to the **review-era** manifest
(`indexer/package-lock.json` `7c305c97…`, `web/package-lock.json` `f2fcf22b…`), so nothing in the
remediation — including repeated `npm ci` — moved a dependency. Census unchanged: indexer 3 direct, web 6
direct + 1 dev, all exact pins.

## M-1 — cause attribution · CLOSED

Attacked beyond the original PoC with 12 adversarial probes, **all passing**:

| Probe | Result |
|---|---|
| 3 burns / 1 `VyrfHarvest(7)` | `vyrf=7`, `other=14`, `S=-21` — consumption is not a one-off special case |
| 2 same-type causes / 2 burns | `vyrf=10`, no by-exclusion leakage — each cause consumed exactly once |
| cause event with no burn | no supply change fabricated |
| cross-type (redemption + vyrf, same amount, 2 burns) | `redemption=4`, `vyrf=4`, **and ambiguity still raised** |
| reordered ingestion | identical cause buckets — deterministic |
| 1 `Settled(qMint=5)` / 2 equal mints | `settlement_mint=5`, `genesis=5` by exclusion |

The original PoC no longer reproduces (`vyrf=11`, `other=11`, `S=-22`). **Discrimination reproduced
independently**: reverting to membership-only matching fails exactly 1 of 13 tests in
`reconstruct.test.mjs`; file restored byte-identical (`f4a9bb66…`).

Fold-vs-handler consistency: the fold now consumes evidence, mirroring `refineCause`'s
`if (slot.consumedBy) continue`. Both paths pass their suites over the same live scenario. There is still
no *single* differential test asserting the two produce identical `(cause, delta)` multisets — noted as
coverage debt (L-6), not a defect.

Live reconstruction: **PASS — 75 logs → 5 settlements, 9 attributed supply changes, 0 ambiguities**,
equal to chain state, all five causes present.

## M-2 — live database invariants · CLOSED

Verified **against the database the delivered application actually wrote**, opened independently after the
runtime gate rather than trusting the app's own self-test or source.

Present in the live schema `vux_runtime_check`:

```
settlement.legs_sum                    CHECK (((king_leg + strategic_leg) + reserve_leg) = price)
supply_change.cause_domain             CHECK (cause = ANY (ARRAY['genesis','settlement_mint',…]))
strategic_flow.class_is_never_backing  CHECK (lower(class) !~~ '%backing%')
strategic_flow.direction_domain        CHECK (direction = ANY (ARRAY['in','out']))
supply_change_tx_hash_log_index_index  CREATE UNIQUE INDEX … (tx_hash, log_index)
```

Direct violating writes against the **real** tables (each rolled back), rejected **by the intended
constraint by name** — so no NOT NULL / FK / unrelated-index failure is masquerading as proof:

| Probe | Result |
|---|---|
| legs ≠ price | `23514 … violates check constraint "legs_sum"` |
| legs = price (control) | **accepted** — the constraint is not vacuous |
| unknown cause | `23514 … "cause_domain"` |
| duplicate `(tx_hash, log_index)` | `23505 … "supply_change_tx_hash_log_index_index"` |
| class `'HardBacking'` | `23514 … "class_is_never_backing"` |
| direction `'sideways'` | `23514 … "direction_domain"` |

Valid indexed traffic still succeeds (2 settlements indexed; runtime gate PASS). Ponder codegen PASS.

**The omitted `ref_epoch_id` FK is the correct call, and for a stronger reason than stated.** CHECK
constraints and unique indexes fire on INSERT/UPDATE only — they cannot block a DELETE, so they are
inherently reorg-rollback-safe. A FOREIGN KEY is the one constraint class that *does* constrain deletes,
which is exactly the ordering coupling cited. The relationship is also observational: `ref_epoch_id` is a
convenience join, the settlement row is independently reconstructible from events, and ponder unwinds a
reorg transactionally, so a dangling reference is not reachable in normal operation. No persistent
corruption path was found. I do not require the FK.

## M-3 — off-chain CI · CLOSED

Workflow inspected for bypasses, not just for presence:

- **No new GitHub Action.** Only the already-pinned `actions/checkout@34e11487…`. Node comes from the
  runner image and its major version is **asserted** (`>= 20`), failing closed on a runner rollback.
- **No bypass surface**: no `continue-on-error`, no `|| true`, no `if:` conditions, no `paths:`/
  `paths-ignore:` filters, no `2>/dev/null`, no `set +e`. Triggers are `push: ['**']` + `pull_request` +
  `workflow_dispatch`, so neither PR nor push can skip it.
- **Exact installs** — `npm ci --ignore-scripts` in both roots, with `working-directory` correct on all
  eight scoped steps; the repo-root pin gate correctly has none.
- **Drift assertion** — `git diff --exit-code` over both manifests and both lockfiles.
- Indexer units, ponder codegen, web units, a **production** build, static-export/no-server and
  bundled-RSC gates all execute.
- **Discrimination**: `offchain-pin-negative-demonstration` mutates one pin, requires the gate to FAIL,
  restores, and requires PASS. Reproduced verbatim locally — `next 15.1.12 → 15.1.11` yields
  `VERDICT: FAIL — web: next@15.1.11 != accepted 15.1.12`; restoring yields `VERDICT: PASS`.

The claimed extensionless-import repair is real: `src/index.ts` imports `./schema-constraints.ts` with an
explicit extension, and **both** loaders now resolve it — Node's ESM loader (`npm test` → 24/24, which
previously collapsed to 13/14 when `handlers.test.mjs` failed to load) and ponder's bundler (codegen PASS).

Hosted CI is correctly **not** claimed green — nothing is committed or pushed. The wiring is correct and
the exact command sequence succeeds locally.

## M-4 — dynamic execution · CLOSED

Repository-wide search of the off-chain surface for `npx`, `npm exec`, `curl`, `wget`, `bunx`, `pnpm dlx`:
**no matches**. The only `child_process` uses are three `spawn` calls in gate/build scripts, each invoking
`process.execPath` with a path into local `node_modules` (`ponder/dist/bin/ponder.js`,
`next/dist/bin/next`) — not fetch-capable. `web/package.json` `start` is now
`node scripts/serve-static.mjs`. No dependency entered the census.

## M-5 — lifecycle scripts fail closed · CLOSED

`ignore-scripts=true` in both `.npmrc` roots; `npm config get ignore-scripts` returns `true` in both.
Repository-wide search for `ignore-scripts=false`, `--foreground-scripts`, `npm rebuild`, or manual
`node-gyp` invocation: **no overrides**. CI restates `--ignore-scripts` explicitly, so it cannot be softer
than a developer machine. Clean installs succeed in both roots and every downstream gate passes —
including ponder codegen, which is the esbuild path most likely to need an install script. Nothing in the
accepted surface depends on a lifecycle script; no authority exception is needed.

## M-6 — chain verified before signature · CLOSED

Both layers verified **independently**, per the brief's instruction not to accept the UI gate alone.

*Layer 1 (UI).* `useAcceptedChain()` compares the wallet's reported `chainId` to `CHAIN_ID`; on mismatch
both flows render `<WrongNetwork/>` and the submit control is **not rendered**. 5 Playwright regressions
pass: wrong-chain take → zero sends; wrong-chain redeem → zero sends; declined switch → still blocked;
`chainChanged` after render → readiness invalidated; correct chain → canonical take still sent.

*Layer 2 (send-time).* All three `writeContract` calls carry `chain: acceptedChain`. Tested directly
against the **pinned viem** with a recording transport, independent of the app:

| Wallet chain | `eth_sendTransaction` | Outcome |
|---|---|---|
| `0x1` (wrong) | **NOT SENT** | `The current chain of the wallet (id: 1) does not match the target chain` |
| `0x7a69` (accepted) | SENT | no error |

So the guard refuses **before** any RPC send and is not a blanket block. The render→click race is closed
by this layer even if the UI were bypassed.

**Prior review M-4 preserved**: the correct-chain regression asserts the take still carries `P1`, the
price of the render clicked in — per-submission freeze intact.

## Regression of previously approved properties — none found

`forge test` **397/397** · indexer **24/24** · web units **10/10** · Playwright **46/46** · live
reconstruction **PASS (0 ambiguities)** · ponder runtime **PASS** · pins / codegen / static-export /
bundled-RSC gates **PASS**. Lens read-only and estimate parity are covered by the passing Solidity suite;
exact redemption arithmetic by the web units; event identity by the indexer suite; static-export/no-server
posture by its gate. **No tracked Solidity was modified**, so Sprints 2–5 are structurally untouched.

---

## LOW residuals

### L-5 · static server — re-graded, with a correction to my own prior audit

**The prior audit called this unreachable. That was wrong**, and I am correcting it: the reachability
claim held only for *origin-form* request targets. Origin-form always begins with `/`, so `normalize()`
collapses `..` against the root and the leading-separator strip finishes the job — all 14 origin-form,
encoded, double-encoded, backslash and mixed-separator probes return 404. But an **absolute-form** request
(`GET http://a/../../../x HTTP/1.1`, which Node passes through verbatim) yields a `clean` beginning with
`..`, and `base.startsWith(OUT)` is a prefix test with no trailing-separator check.

**PoC (confirmed, not theorised).** With a canary at `web/outaudit-canary.txt` — outside the export root —
`GET http://a/../../../outaudit-canary.txt` returned **HTTP 200 with the file contents**. Canary removed;
subject re-derived to the exact entry fingerprint.

**Why it stays LOW.** The escape region is exactly `C:\…\web\out*` — siblings of the export root whose
name begins with `out`. It cannot reach `app/`, `lib/`, `.npmrc`, `node_modules`, `.env`, or anything at
the repository root (all such probes 404, confirmed). Today no such sibling exists, so nothing is
disclosable; and by naming convention anything that ever appears there is build output, which is public.
This is dev/test tooling — no project script or document uses `npm start` as a production hosting path;
the static export ships to a static host.

Separately confirmed: the server binds **`0.0.0.0` and `[::]`** while logging
`static export served on http://127.0.0.1:4321` — the log is misleading, and the LAN exposure is real.
Combined risk is what matters here: a confirmed containment escape that is LAN-reachable rather than
loopback-only. Impact remains bounded by the escape region.

**Bounded remediation** (not required for acceptance): `if (base !== OUT && !base.startsWith(OUT + sep)) return null;`,
`.listen(PORT, '127.0.0.1', …)`, and correct the log line. Two lines and a string.

### L-2 · shared `web/out/` — partially retired, remainder LOW

The CI claim is **verified from workflow order**: `npm run build` (production) runs immediately before
`verify:static` and `verify:rsc`, so CI can never inspect a leftover test artifact.

The local path is unchanged and currently live: `web/out/` **right now contains a test build**
(`127.0.0.1:1/rpc` present), and `npm start` serves `out/` without building. So
`test:copy` → manual upload of `out/` remains possible. Impact is bounded and loud rather than silent —
the placeholder RPC refuses instantly so every read renders "data unavailable", and the placeholder
addresses hold no code so wallet calls revert. No secret is embedded; this is synthetic test data, not
leakage. Remains **LOW / process**. A build marker asserted by `verify-static-export.mjs` would close it.

### Other carried LOWs — unchanged

- **L-1 API input validation** — negative `limit`, unguarded `BigInt(param)`, unallowlisted `?class=`.
  Still present; still availability/error-hygiene on a public read-only replica, not injection.
- **L-3 read→click price window** — unchanged; the closed review-M-4 property is intact and positively
  re-verified by the new correct-chain test.
- **L-4 codegen verdict wording** — no security impact; the gate chain remains unambiguous.
- **Rendered payout coverage** — unchanged, non-blocking; no divergence path found.

### L-6 · new, introduced by the remediation (informational)

`applySchemaConstraints` self-proves on **every** startup, which requires `CREATE TEMP TABLE` privilege on
the indexer's database role. That is a new operational precondition: a role without TEMP rights makes the
indexer refuse to start. Correct-by-design (fail closed) but worth recording in the deployment runbook.
Related minor coupling: the constraints are applied from the `Rig:setup` handler, so removing `Rig` from
`ponder.config.ts` would silently remove the invariants. Neither is a security defect. The generated DDL
interpolates only internal constants and catalog-derived column names — no user input reaches it, so
there is no injection path.

---

## Why APPROVED

All six prior MEDIUMs are closed on independent evidence, not on the remediation's own claims: M-1 by 12
adversarial probes plus a reproduced mutation, M-2 by opening the live database and rejecting real writes
by constraint name, M-3 by inspecting the workflow for bypasses and replaying its exact commands, M-4 by
exhaustive search, M-5 by effective-config and override search, M-6 by driving the pinned viem directly.
The remediation introduced no new blocking defect, moved no dependency, and touched no prior-sprint code.

The one residual that materially changed is **L-5**, where I disproved my own earlier reachability claim.
It stays LOW because the escape region contains only build output and the component is dev tooling — but
it should be fixed, and the fix is trivial.

**APPROVED - LET'S FUCKING GO**

This is the audit gate's verdict only. It is not operator acceptance: Sprint 6 remains unaccepted,
uncommitted, unlanded, and the six LOW residuals above are carried forward faithfully.

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":6},"sprint_id":"sprint-6","ts":"2026-08-15T00:00:00Z"} -->
