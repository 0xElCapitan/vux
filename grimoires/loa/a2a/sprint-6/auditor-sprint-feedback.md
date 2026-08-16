# Sprint 6 — Truth Surfaces: Lens, Indexer & Truthful UX — Security Audit

**Verdict:** `CHANGES_REQUIRED`
**Auditor node:** `/audit-sprint sprint-6` — independent security audit only. No remediation, no commit, no acceptance.
**Branch:** `sprint-6` · **Baseline/HEAD:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377` (unchanged; no commit made)
**Date:** 2026-08-14

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 6 |
| Low | 5 |

No blocking *exploit* was found. Nothing in this tree can move funds, mint, burn, grant authority, or
degrade Hard Reserve integrity. `CHANGES_REQUIRED` rests on three concrete gaps against the sprint's own
stated deliverables — an unmet Success Metric, a Task 6.4 constraint that ships as a file but is never
applied, and a demonstrated (PoC) mis-attribution in the reconstruction library — plus two contradictions
of the provenance boundary this sprint exists to establish.

## Identity

Derived mechanically from git (`git status --porcelain --untracked-files=all`), partitioned per
`evidence/subject-manifest.md`, per-file `sha256`, aggregate
`sha256(join("\n", path-sorted "<sha256>  <path>"))`.

| Group | Files | Expected | Re-derived | Result |
|---|---|---|---|---|
| A — implementation subject | 58 | `0aa114b4a5d0f8b0…` | `0aa114b4a5d0f8b0e3e7a39f00560f58fa60eab0c6649c10a86aae9b3870f95e` | **MATCH** |
| B — activated authority | 2 | `1e6515cc1c79f553…` | `1e6515cc1c79f553c68d8172e16c78c183133ad0bc6057bf07cfb400ea267a2c` | **MATCH** |
| C — lifecycle evidence | 30 | — (self-mutating) | `04ed051b5027cb55…` | drift expected (L-3 of review) |

**The approved implementation bytes have not changed since review.** Group B reproducing the review-era
manifest fingerprint exactly is the independent corroboration: the activated authority is byte-identical,
so the subject was audited under the same authority it was reviewed under.

The aggregation is path-sorted, not line-sorted. I recovered that by reverse-engineering the two-file
Group B against its known fingerprint rather than assuming it, after a line-sorted first attempt produced
a count match with a fingerprint mismatch on both A and B — the double mismatch is what identified the
error as mine rather than the tree's.

## Independent verification — reproduced, not inherited

| Gate | Result |
|---|---|
| `forge test` | **397 passed / 0 failed** (33 suites) |
| `node --test indexer/test/{reconstruct,handlers}.test.mjs` | **22 passed / 0 failed** |
| `web` unit tests | **10 passed / 0 failed** |
| `tools/offchain/verify-accepted-pins.mjs` | **PASS** — indexer closure 391, web closure 371, all entries carry integrity |
| `web/scripts/verify-static-export.mjs` | **PASS** — static export, no server runtime, no Server Function endpoint |
| `web/scripts/verify-rsc-runtime.mjs` | **PASS** |
| `indexer/scripts/verify-ponder-codegen.mjs` | **PASS** — config, schema and API modules load; codegen produced the accepted tables |

`verify-ponder-runtime` was not reproduced (requires a live anvil). Playwright was not re-run in this node;
the review reproduced it and the copy-suite properties are additionally pinned by the unit tests above.

## Prior-sprint regression boundary — clean

`.gitignore` is the **only** tracked file modified outside the State Zone, at **+13/−0 with zero deletion
lines**. Every other subject entry is a new file. No prior-sprint Solidity, test, authority, or planning
artifact was touched, so VUX mint/burn authority, Hard Reserve ownerless/immutable constraints, Rig
settlement/VEM behaviour, Strategic Treasury separation, POL invariants, and the provenance default-deny
boundary are structurally unreachable from this diff. The full 397-test suite passing confirms it
behaviourally. Sprint-5 audit A-1 is untouched by this tree and remains an accepted prior residual.

---

## MEDIUM findings

### M-1 · Cause over-attribution in the standalone reconstruction fold — demonstrated

**Surface:** FR-14 independent reconstruction · `indexer/src/lib/reconstruct.mjs:216-224`

The burn-cause match is non-consuming:

```js
if (causes.vyrf.some((v) => v.vuxFeesBurned === value)) matched.push(CAUSE.VYRF_BURN);
...
if (matched.length > 1) { ambiguities.push({...}); }
```

`.some()` never marks a cause event as used, so **one cause event attributes every equal-valued burn in
the transaction**. `matched.length` stays 1, so the ambiguity detector cannot fire on this shape. The
detector is real and does fire for cross-*type* collisions (proven by the suite's own test at
`indexer/test/reconstruct.test.mjs:107-121`); the uncovered direction is N-burns-to-one-cause.

**Reachable:** `StrategicTreasury.harvestPol()` (`src/StrategicTreasury.sol:1010`) and `VUX.burn`
(`src/VUX.sol:115`) are both permissionless, so a composing contract can place both burns in one
transaction.

**PoC** (one `VyrfHarvest(vuxFeesBurned: 11)` + two `Transfer→0` of 11, log shape identical to the suite's):

```
supply delta          : -22n     ← correct
vyrf_burn             : 22n      ← should be 11n
other_authorized_burn : 0n       ← should be 11n
ambiguities           : []       ← detector silent
```

**Impact, bounded honestly.** `S`, `B`, and `B/S` are unaffected — `delta` derives from the transfer value
regardless of cause, and the PoC confirms supply is exact. The **shipped Ponder handler is correct**:
`refineCause` (`indexer/src/index.ts:94-112`) consumes one slot per cause log (`if (slot.consumedBy)
continue`), and `VUX:Transfer` defaults each burn to `other_authorized_burn` (`:136`), so the streaming
path attributes the second burn correctly. The defect is confined to the exported fold used by the
acceptance harness. The consequence is that the "burn causes … with zero ambiguity" criterion is proven by
the weaker of the two implementations, and any third party using `reconstruct()` for independent
verification gets wrong per-cause buckets on composed transactions.

**Remediation target:** port the consumption model from `index.ts` into the fold; add the mirror of the
existing detector test for the N-to-one direction; add a differential assertion that the fold and the
handler produce identical `(cause, delta)` multisets over the live scenario.

### M-2 · `legs_sum` and every other DDL constraint ship as a file that is never applied

**Surface:** Task 6.4 ("PostgreSQL schema (§3.3 tables incl. `legs_sum` constraint)") · `indexer/sql/schema.sql:38`

`grep` for `check(`/`unique(` in `indexer/ponder.schema.ts` returns **nothing** — ponder builds the live
tables from that file, with no constraints. `sql/schema.sql` is referenced in exactly two places, both
comments (`ponder.schema.ts:3`, `:116`), and there is no migration runner, no `psql`, and no
`DATABASE_URL` step in `package.json`, `ponder.config.ts`, or either workflow. So `legs_sum`, the
`UNIQUE (tx_hash, log_index)`, the `cause` domain, and the `class_is_never_backing` CHECK are all inert.

Two comments assert the protection as active — `ponder.schema.ts:116` says `NEVER 'backing' — enforced by
a CHECK in sql/schema.sql`, and `src/api/index.ts:76` calls its regex "Defence in depth behind the SQL
CHECK". The API guard at `:79` is in fact the *only* layer.

**Mitigating, and it matters:** replay idempotency does **not** depend on the dead `UNIQUE`. It rests on
ponder's positional primary key `${txHash}:${logIndex}` plus `onConflictDoNothing()`, which is live and
which the 22 passing indexer tests exercise. FR-14.4 is independently enforced at the API and in the
Playwright copy suite. This is a missing defence-in-depth layer plus two misleading comments, not an open
door.

**Remediation target:** enforce the leg identity in the handler (`src/index.ts:154`, before the insert) so
a violation halts loudly, and either apply `sql/schema.sql` in a startup/CI step or re-label it as a
consumer reference shape rather than "the authoritative DDL".

### M-3 · CI executes zero off-chain code — a stated Success Metric is unmet

**Surface:** Task 6.1 · `sprint-6-scope.md` Success Metrics: "**CI: lockfile-drift gate active**"

A case-insensitive grep of `.github/workflows/` for `npm|node |setup-node|playwright|indexer|web/|verify-accepted-pins`
returns **no matches**. `provenance.yml`'s gate step runs `tools/provenance/run-all.sh`, whose eight gates
are Solidity-side; `tools/provenance/verify-pins.sh` is solc/Foundry pin discipline, not the npm gate.
`verify-accepted-pins.mjs` is referenced only as a script *definition* in `indexer/package.json:14` and
`web/package.json:12`. `.github/` is not in the 58-file subject — the sprint did not modify CI at all.

The gate itself is well built and passes when run: fail-closed `process.exit(1)`, accumulating rather than
short-circuiting failures, and it checks declared ranges, manifest-vs-census, resolved lockfile versions,
and registry integrity. It simply never executes. The consequence is that the sprint's own named risk
mitigation ("Exact pins + lockfile integrity gate") is manual-only over the dependency path that signs
user transactions, and ~5,300 lines of new off-chain code have no automated verification.

**Remediation target:** add an off-chain job to `provenance.yml` — `npm ci --ignore-scripts` in both roots,
then the verifier, then `git diff --exit-code` on the lockfiles, then the indexer/web/Playwright suites.
`playwright.config.js` already branches on `process.env.CI`, so the wiring was anticipated.

### M-4 · `npx serve out` — unpinned dynamic package execution inside the provenance boundary

**Surface:** provenance boundary · `web/package.json:10`

```json
"start": "npx serve out",
```

`serve` appears in neither dependency block, neither lockfile, nor the integrity census. `npx` resolves it
from the registry at invocation and executes it, including its install scripts — in a repo whose `.npmrc`
opens with "exact pins only". The repository already contains the answer and states the reasoning itself
at `web/scripts/serve-static.mjs:4-6`: adding a server package to serve a static export would be an
unauthorized dependency under the accepted refreeze. One-line fix to
`"start": "node scripts/serve-static.mjs"`.

### M-5 · `ignore-scripts` is not set in either root

**Surface:** provenance boundary · `indexer/.npmrc`, `web/.npmrc`

Neither file sets `ignore-scripts=true`, so transitive packages carrying `hasInstallScript` execute
arbitrary code on every `npm ci`, on developer machines and in any future CI runner — including `keccak`
and `bufferutil`, which sit in the wallet/signing dependency path. Integrity digests do not mitigate this:
a digest proves the tarball is byte-identical to what the registry published, not that its postinstall is
benign. This is the highest-leverage supply-chain fix available and it is one line in two files.

Related nit: the comment `; Never silently accept a manifest/lockfile disagreement` in `indexer/.npmrc`
sits above `engine-strict=false`, which governs Node engine ranges and does not implement that control.

### M-6 · No chain verification before any signature

**Surface:** wallet transaction security (brief §7, "wallet/network mismatch handling") ·
`web/components/WalletFlows.jsx:119, 128, 183`

Three `writeContract` calls; none passes `chain`/`chainId`, and none is preceded by a network check.
`ready` gates on `isConnected` only (`:101`). `CHAIN_ID` exists in `web/lib/wagmi.js` solely to construct
the wagmi config and is never compared against the wallet's connected chain; `useAccount()` is
destructured for `{ address, isConnected }`, discarding the available `chainId`.

If the wallet sits on a chain absent from the config, viem's `assertCurrentChain` is skipped and the
configured addresses are used against whatever chain is connected — and the take flow's first action is
`approve(rig, maxPrice)` against `ADDRESSES.weth`. Bounded (the user must already be on the wrong network,
and most such addresses are empty and revert), but the failure mode is an approval to an unintended
address, which is the class worth eliminating outright.

**Remediation target:** `useChainId()`, gate `ready` on equality with `CHAIN_ID`, render an explicit
wrong-network state, and pass `chainId` to every `writeContract` so viem asserts before signing.

---

## LOW findings

- **L-1 · API input validation.** `limitOf` (`indexer/src/api/index.ts:33`) caps only the upper bound —
  `Math.min(Number(q) || 100, 500)` passes negatives through, so `?limit=-1` reaches Postgres and raises
  `22023`. `BigInt(c.req.param("epochId"))` (`:51`) is unguarded, so `/settlements/abc` throws before the
  route's own 404 branch. Both surface through ponder's framework handler, which returns the exception and
  an absolute host path. `?class=` (`:71`) is not allowlisted although `?cause=` is (`:59-62`), so a typo
  returns `200 []` rather than 400. Availability and error hygiene on a public, read-only, no-auth replica
  serving public data — not injection, and no secret is exposed.
- **L-2 · Shared `web/out/` (review residual, audited per brief §10).** Confirmed materially: `web/out/`
  **currently contains a test build** — `grep` finds `127.0.0.1:1/rpc` and the `0x…0f0001/0f0002`
  placeholders in `out/_next/static/chunks/`. `build-with-test-env.mjs:44` spreads `TEST_ENV` last, so it
  also overrides real production env. **Retained as LOW after examining the ship path**, not assumed:
  `out/` is gitignored with 0 tracked files and no workflow publishes it, so the only route is a manual
  upload after running the copy suite. The resulting artifact fails *loudly and honestly* rather than
  misleadingly — RPC `127.0.0.1:1` refuses instantly so every read renders "data unavailable", and the
  placeholder addresses hold no code, so wallet calls revert. No fund-loss path. **Bounded remediation:**
  emit a sentinel (e.g. `out/.TEST-BUILD`) from the test build and have `verify-static-export.mjs` fail on
  its presence, or build test output to a separate directory.
- **L-3 · `maxPrice` read→click window — M-4 NOT reopened.** The closed M-4 requirement is met: `submit`
  closes over the same render's `price` (`WalletFlows.jsx:112`), so the displayed maximum and the signed
  guard are the same expression from the same commit, a poll cannot move an in-flight guard, and a later
  take gets a fresh closure. A poll landing between the user *reading* and *clicking* updates display and
  guard atomically together, so the guard still equals what the DOM showed at click. The economics are
  fail-safe (a price rise reverts via `PriceAboveMax`; a Dutch decay pays less). Recorded as
  defence-in-depth hardening only — an explicit re-confirm on change — not as a defect, and explicitly not
  as grounds to reopen M-4.
- **L-4 · Codegen verdict wording (review L-1, per brief §10).** No security impact. The codegen gate's
  sentence claims more than that gate alone establishes, but the runtime gate supplies the missing proof
  and both are in the chain; no security decision rests on the sentence in isolation. No remediation
  required on wording precision alone.
- **L-5 · Prefix containment in `serve-static.mjs:27`.** `base.startsWith(OUT)` lacks a trailing-separator
  check, so a sibling directory such as `out-v3core/` prefixes cleanly. Unreachable today (request URLs are
  absolute, so `normalize()` collapses `..` before the strip) and test-tooling only — worth tightening
  because M-4's fix promotes this file to `npm start`. `:47` also binds all interfaces while logging
  `127.0.0.1`.

---

## Verified clean

- **Lens read-only authority surface.** `LensSurface.t.sol` proves absence of `SSTORE`/`CALL`/`CREATE`/`LOG*`
  in the *compiled runtime* **with positive controls from Rig's runtime on every assertion** — the correct
  way to write an absence proof, and it passes in my own `forge test` run. No Lens view can mutate state,
  move tokens, call `take`, mint, burn, create contracts, or create custody.
- **Lens estimate parity is independent, not tautological.** `LensFixture.sol:38-39` reads the estimate then
  executes a real `rig.take()` in the same block; `:52-55` compares against the decoded `Settled` log.
  `Rig._route` is `internal` and unreachable from `Lens`, so `Lens.sol:211-223` is a genuine reimplementation
  and drift on either side fails the assertions.
- **Round-UP is proven with an asserted remainder.** `LensViews.t.sol:169` asserts the chosen case actually
  has a remainder before checking the ceiling, so the test cannot silently decay into the useless
  exact-division case; flipping `Ceil`→`Floor` at `Lens.sol:192` fails it.
- **No-entitlement semantics** proven against six independent observables (supply, backing, contributed,
  king, epoch, caller balance).
- **SQL injection: none.** Every `sql` template interpolation in `/stats` (`api/index.ts:88, 91, 94`) is a
  drizzle Column object, never request data; all four request-derived values reach bound parameters via
  `eq(...)`. No write endpoints — `ponder.get` only — and no GraphQL surface.
- **Numeric precision on the transaction path.** BigInt end-to-end; no uint256 reaches a signed argument
  through a float. `parseUnits18` rejects excess precision rather than truncating.
- **Failure truthfulness.** Failing reads null the value rather than retaining it, a 30s staleness cutoff
  catches the silent-stop case, and `Unavailable`/`Truth` structurally cannot render a value alongside an
  unavailable state.
- **Static-export / no-server posture.** `verify-static-export.mjs` PASSes from the actual build: no server
  runtime, no Server Function endpoint, no route handlers, no server actions. Zero third-party origins in
  the shipped bundle.
- **Pin discipline.** Zero non-exact ranges in either manifest, including `viem` and `wagmi`; all 762
  lockfile entries carry integrity digests against a single registry; no lifecycle scripts in either
  manifest; no auth tokens or registry overrides. The `next` 15.1.4→15.1.12 delta is a documented
  CVE-2025-66478 upgrade, internally coherent across manifest, lockfile and registry — correct, not drift.

## Claims investigated and rejected

- **"The off-chain surface is untracked in git" (raised as CRITICAL by a parallel evidence agent).**
  Rejected. This is the expected pre-commit state of a sprint under audit — the brief states the
  implementation remains uncommitted, and `git check-ignore` confirms the lockfiles, `tools/offchain/`, and
  both authority documents are *not* ignored. Not a finding.
- **A "51-file subject".** Rejected — stale. The subject is 58 files, mechanically re-derived twice.
- **Path traversal in `serve-static.mjs`.** Hypothesised and disproved empirically; the prefix weakness is
  real but unreachable (recorded as L-5).
- **Integrity pinned for only 11 of 762 packages.** Accurate as a description of the verifier's *value*
  comparison, but this is the accepted design of the census, not a defect introduced by this sprint: the
  refreeze pins the decision surface and censuses the closure. Recorded here as an observation for the
  operator, not scored as a finding.

## Residual coverage debt — not escalated

The rendered payout number remains a known coverage debt. I found no implementation path where rendered
output diverges materially from the tested arithmetic — `previewRedeemRaw` is BigInt division and the
rendered form is an exact string slice of it. Not escalated, per the brief.

## Exit identity

Re-derived after all audit activity:

```
Group A — implementation subject
count:       58
fingerprint: 0aa114b4a5d0f8b0e3e7a39f00560f58fa60eab0c6649c10a86aae9b3870f95e   MATCH
```

**Audit mutated no implementation bytes.** All audit activity was read-only against the subject; the PoC
and derivation scripts were written to the session scratchpad, never under `indexer/`, `web/`, or `test/`
(placing them there would itself have moved the fingerprint). Lifecycle-only files written by this node:
this file, `grimoires/loa/a2a/sprint-6/auditor-sprint-feedback.md` (Group C).

No `COMPLETED` marker was created. Next step is remediation via `/implement sprint-6`, then re-audit.

<!-- LOA-VERDICT {"gate":"audit","verdict":"CHANGES_REQUIRED","counts":{"critical":0,"high":0,"medium":6,"low":5},"sprint_id":"sprint-6","ts":"2026-08-14T00:00:00Z"} -->
