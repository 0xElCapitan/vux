# Sprint 6 — Remediation Re-Review

**Verdict:** `CHANGES_REQUIRED`
**Node:** `/review-sprint sprint-6` — independent re-review only. No remediation, no audit, no commit.
**Branch:** `sprint-6` · **Baseline/HEAD:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377` (unchanged)

## Identity

Derived mechanically from git, partitioned against the State-Zone/authority material.

| | Claimed | Re-derived | Result |
|---|---|---|---|
| Implementation subject | 56 files, `1bf3974d2b94c448…` | 56 files, `1bf3974d2b94c4488d90ce806d752de576f394c91768ed0e26c91ab73a1fc14c` | **MATCH** |

## Prior findings — all five close

**H-1 · CLOSED.** Identity is now `${txHash}:${logIndex}` (`indexer/src/index.ts:53,125`), matching what
`ponder.schema.ts` always documented and the old handler contradicted. `indexer/sql/schema.sql:52,57` adds
`log_index` and `UNIQUE (tx_hash, log_index)`, so the database enforces one row per log rather than trusting
the ingester. Pairing is explicit and idempotent by *log identity* — `consumedBy` records the claiming cause
log, not a boolean.

The regression was not accepted on its passing status. I built a mutant outside the repo restoring **only**
the old content-derived key and ran the same assertions against the shipped handlers:

```
rows recorded : 1   (remediated expects 2)
ids           : 0xdeadbeef:burn:5000000000000000000
summed delta  : -5000000000000000000   (remediated expects -10000000000000000000)
>>> MUTANT KILLED
```

The test genuinely detects the original defect. Reproduced end-to-end too: the runtime gate's on-chain
`doubleSelfBurn` produces **2 rows with distinct ids** through the delivered handlers. Both paths now key on
log occurrence — `src/lib/reconstruct.mjs:49` uses `blockHash:txHash:logIndex`, and the streaming path uses
`txHash:logIndex`; the earlier claim that they "agree" is now true rather than aspirational. **R-4 resolved.**

**H-2 · CLOSED with one defect (M-4 below).** Real flows exist: `WagmiProvider` + `QueryClientProvider` +
`injected()`, viem wallet client, canonical `Rig.take(maxPrice)` and `HardReserve.redeem(q, to)`. Client-side
only — the export is still 6 static pages with no server bundle. `take` withdraws entirely when the price is
unreadable (`WalletFlows.jsx:130-133`): the submit button is not rendered at all, so an unguarded transaction
cannot be sent. `redeem` threads the exact `parseUnits18` bigint through unchanged.

**M-1 · CLOSED.** No float remains on the quantity path — the only `Number(`/`* 1e18` occurrence in
`units.js`, `redeem/page.jsx` or `WalletFlows.jsx` is inside a comment describing the removed defect.
`12345.6789` → `12345678900000000000000` reproduced both at unit level and through the real DOM input
(`wallet-flows.spec.js:63`), with an explicit assertion that it is *not* the old `12345678900000001622016`.
Excess precision fails visibly and yields no quantity. Quote and transaction consume the same `q`.

**M-2 · CLOSED.** Reproduced against live anvil. The scenario runs the real canonical v3 pool (deployed from
`out-v3core/…/VuxPoolDeployer.json` creation code), a real POL mint through the real pay-in callback, real
third-party round-trip swaps, and real `harvestPol()`. Reconstruction consumes `eth_getLogs` only; chain reads
appear solely as the final oracle. Independence holds — the treasury address is discovered from an emitted
event, not a state read, and `B` is rebuilt from the WETH token's own transfer record, which is why the
harvest's WETH leg is captured definitionally rather than by special-casing.

```
S      logs=156274506709590509937272  chain=156274506709590509937272
B      logs=311368363636363636363     chain=311368363636363636363
B/S    logs=1992445026334260522983132 chain=1992445026334260522983132
vyrf_burn 25209210848415306803
```

All five causes present in the one integrated run. Replay ×3 identical; real `evm_snapshot`/`evm_revert`
returns to the pre-fork state. **R-6 resolved.**

**M-3 · CLOSED.** Codegen produces `ponder-env.d.ts` + `generated/schema.graphql` with 5/5 accepted tables.
The runtime gate starts the delivered app against anvil and asserts on rows it wrote: 2 settlements, 7 supply
changes, all five causes, duplicate-burn → 2 distinct rows, and indexed `S` equal to chain `totalSupply`. A
process that merely exits cannot pass — every assertion is about written rows.

The reported process oddities are correctly handled and none is cosmetic-only: `--schema` fail-close is
ponder refusing to share an unnamed schema; the mined blocks clear anvil's trailing `finalized` tag; and the
CLI's `3221226505` exit (a libuv shutdown crash on Windows) is precisely why the gate refuses to read exit
codes. Not requiring CLI cleanliness — the artifacts and rows are proven independently.

**EIP-170 correction · sound.** `TruthScenario` runtime is 7,381 bytes, and it is not merely under the limit —
it actually deployed and ran on anvil in both integration gates, which is the environment it models. The
workaround changes no protocol behaviour: the treasury is deployed from the same
`out/StrategicTreasury.sol/StrategicTreasury.json` bytecode `new` would have embedded, with identically
ABI-encoded constructor args and the same `msg.sender`, so role grants and identity checks are unchanged.

---

## Findings

### M-4 · MEDIUM · The `take` guard freezes after the first submission and is then displayed as current

**File:** `web/components/WalletFlows.jsx:100,105,142`
**Violated requirement:** AC-7 — "never stale-as-live" (`sprint.md:430`, `sdd.md:L836`); and H-2's
"carries the user's confirmed `maxPrice`".

```js
const [confirmed, setConfirmed] = useState(null);   // :100
const maxPrice = confirmed ?? price;                // :105
onClick={() => { setConfirmed(price); submit(); }}  // :142
```

`confirmed` is set on the first click and **never cleared**. Three consequences:

1. **`setConfirmed` does nothing for the transaction it accompanies.** `submit()` closes over `maxPrice` from
   the current render, where `confirmed` is still its previous value. The first transaction is correctly
   guarded only because the closure already captured `price` — the state variable contributes nothing.
2. **The displayed guard goes stale.** `:137` renders `formatUnits18(maxPrice)` under "Maximum price you will
   pay" while `useTruth` keeps polling a moving price every 12s. After one submission that number is frozen
   forever — a stale value presented as current, in the surface Sprint 6 exists to make truthful.
3. **A second `take` reuses the first transaction's guard**, which the user never confirmed for it. After a
   successful take the opening resets to `2 x P`, so the frozen lower guard makes attempt 2 revert with
   `PriceAboveMax` — fail-safe on price, but systematically broken, and if the price later decays below the
   frozen value it executes against a guard the user never agreed to for that transaction.

**Why no test caught it:** every wallet test runs in the degraded no-RPC state, so `price === null` and the
entire `take-maxprice` branch never renders. No test exercises the price-available branch at all.

**Bounded remediation target:** delete `confirmed` and use `price` directly — the closure already captures the
confirmed value — or reset it when the flow returns to idle. Add one test that renders `TakeFlow` with a price
present and asserts the displayed maximum tracks the live price across a re-render.

### L-1 · LOW · The codegen gate's verdict text claims more than the gate proves

`indexer/scripts/verify-ponder-codegen.mjs` prints "config, schema and API modules all load". I probed it with
`VUX_RIG_ADDRESS=''`, which `ponder.config.ts:19` should reject — the gate still returned **PASS**. Ponder's
`codegen` gates only on `schemaResult`, so a config fault need not prevent artifact generation.

This is an evidence-precision issue, not a coverage hole: the gate demonstrably fails when generation is
absent (observed exit 1 on the pre-fix tree), and the **runtime** gate independently proves the config by
starting the app with real addresses and indexing. Recommend narrowing the verdict wording to what the
mechanism establishes.

---

## Residuals graded (not blocking)

**Mock EIP-1193 signer — not required.** Grading the requirement rather than the technique: Task 6.6 asks for
wallet flows, and their existence, canonical call construction, exact-quantity threading, withdrawal under
unavailable data, and copy compliance are all evidenced. A signature round trip would raise confidence but is
not what the requirement asks for. The real gap is narrower and is folded into M-4: **no test renders the
price-available branch**, which is what let M-4 through. Fixing M-4's test closes it; a mock signer is not
needed for that.

**Rendered payout number with mocked `B`/`S` — non-blocking coverage gap.** The untested branch is
mechanically constrained by adequately tested pure logic: `previewRedeemRaw` is exhaustively unit-covered
(floor semantics, `S = 0`, zero/null inputs, exactness), the input→raw path is DOM-covered, and the render is a
thin `formatUnits18(quote)` call. No remediation manufactured for this.

## Regression sweep — reproduced, not inherited

| Gate | Result |
|---|---|
| `forge test` | **397 passed, 0 failed** (33 suites) |
| indexer units (`reconstruct` + `handlers`) | **22 passed** |
| web exact-arithmetic units | **10 passed** |
| Playwright (copy/degraded + wallet flows) | **38 passed** |
| H-1 duplicate-burn regression | **passes; mutant against old key KILLED** |
| `verify-ponder-codegen.mjs` | **PASS** — 5/5 tables (see L-1) |
| `verify-ponder-runtime.mjs` | **PASS** — delivered app indexed live anvil |
| reconstruction incl. harvest | **PASS** — 0 ambiguities; replay + real reorg hold |
| `verify-accepted-pins.mjs` | **PASS** — census unchanged (web 3+7, indexer 3+391) |
| `verify-rsc-runtime.mjs` | **PASS** |
| `verify-static-export.mjs` | **PASS** — 6 pages, server bundle absent, 0 call sites |

## Preservation

`src/Lens.sol` is byte-identical to the originally reviewed version (`00030ebfd5dc9a88…`). Sprint 2–5
implementation, `docs/authority/**`, `prd.md`, `sdd.md`, `sprint.md`: `git status --porcelain` empty. No
dependency added — web `{@tanstack/react-query, next, react, react-dom, viem, wagmi}` + `@playwright/test`,
indexer `{hono, ponder, viem}`, exactly the accepted census; `wagmi` and `@tanstack/react-query` are now used
rather than dormant. No P1 mechanism, no operator-reserved value resolved.

Previously retired questions were not reopened: **R-1**, **R-2**, **R-3**, **R-5** stand as decided.

## Next steps

1. Address M-4 (two-line fix plus one test); L-1 is optional wording.
2. Route through `/implement sprint-6` — review does not fix.
3. Re-submit for `/review-sprint sprint-6`. `/audit-sprint` remains gated behind approval.

<!-- LOA-VERDICT {"gate":"review","verdict":"CHANGES_REQUIRED","counts":{"critical":0,"high":0,"medium":1,"low":1},"sprint_id":"sprint-6","ts":"2026-08-14T00:00:00Z"} -->
