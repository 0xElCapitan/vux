All good

Sprint 6 M-4 remediation reviewed and **APPROVED**. M-4 is closed, the five previously closed findings
remain closed, and no new load-bearing defect was found. Two non-blocking LOW residuals are recorded below.

**Node:** `/review-sprint sprint-6` — focused re-review. No fixes, no audit, no commit.
**Branch:** `sprint-6` · **Baseline/HEAD:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377` (unchanged)

## Identity

| | Claimed | Re-derived | Result |
|---|---|---|---|
| Implementation subject | 58 files, `0aa114b4a5d0f8b0…` | 58 files, `0aa114b4a5d0f8b0e3e7a39f00560f58fa60eab0c6649c10a86aae9b3870f95e` | **MATCH** |

All nine prior review/lifecycle artifacts sit outside the subject, in `grimoires/loa/a2a/sprint-6/`.

## M-4 — closed

The fix deletes the persistent `confirmed` state and uses the current render's `price`
(`web/components/WalletFlows.jsx:112`, `:150`). The only `useState` left in the file is the transaction
lifecycle in `useTx`.

The semantics hold, and they hold for a structural reason rather than by convention. `submit` is
re-created each render closing over that render's `maxPrice`, and `onClick={submit}` binds the closure
from the last commit — so:

- **First take.** The displayed maximum and the submitted guard are the *same expression from the same
  render*, so they cannot disagree. Reproduced: `25.000000` rendered, and the recorded `Rig.take`
  calldata carried exactly `P1`. The accompanying `approve` ceiling was `P1` too.
- **In-flight.** A poll landing after the click re-renders and creates a *new* `submit`, but the
  already-executing `run` keeps its own closure. The freeze is per submission, which is the correct
  property — not per component lifetime. No persistent state is needed to achieve it, and requiring one
  back would reintroduce the defect.
- **Price update.** The displayed maximum tracks the live poll; the previous transaction's guard is not
  retained anywhere and so cannot be presented as current.
- **Second take.** A fresh render yields a fresh closure. Reproduced: the second recorded guard was `P2`,
  asserted unequal to the first.

**Discrimination independently reproduced, not inherited.** I reintroduced the old
`confirmed ?? price` state, rebuilt the export, and re-ran `take-guard.spec.js`. It failed at exactly the
price-update phase:

```
Expected string: "18.000000"
Received string: "Maximum price you will pay: 25.000000 WETH"
```

The frozen display, precisely. The other two tests in the file still passed under the defect, which is the
right shape: the regression is targeted at the M-4 property rather than broadly coupled. I then restored
the file and confirmed it byte-identical (`572fc1ce40fa5db24829ed18d9a84badb548436d4cc5bb1f066948af20e5605c`).

## Test-environment build helper — boundary is clean

`web/scripts/build-with-test-env.mjs` spawns `next build` with `NEXT_PUBLIC_*` placeholders in the child's
env only. Reviewed against each concern raised:

- **Production untouched.** `npm run build` is still plain `next build`; the helper is reachable only via
  `build:test` / `test:copy`.
- **No new dependency or provenance surface.** Imports are `node:child_process`, `node:path`, `node:url`.
  The pin census is unchanged (web 6 deps + 1 dev, indexer 3) and `verify-accepted-pins.mjs` PASSes.
- **No leak into an ordinary build.** The env object is constructed at spawn time and never written to
  disk or to `process.env`; a plain `next build` cannot see it.
- **It exists for the right reason.** `NEXT_PUBLIC_*` is inlined at build time, so the price-available
  branch is unreachable without a compiled-in value. That is not a convenience — it is the only way to
  execute the code path M-4 lived in.

New test infrastructure is not objectionable per se, and this one earns its place. One operational note is
recorded as L-2 below.

## FB-17 degraded-state evidence — genuinely strengthened

The earlier suite had no RPC compiled in, so `client()` returned null and **no read was ever attempted**;
the degraded assertions passed against a path that never touched the network. That is now fixed rather than
papered over:

- A read is attempted — the transport is real and the host is `127.0.0.1:1`, which the browser refuses
  immediately, so failure is deterministic rather than a hang or a timeout race.
- The accepted FB-17 behaviour was not rewritten. `web/app/page.jsx:26-28` still requires *both* live reads
  unavailable **and** `reason !== 'loading'`, so loading is not misclassified as outage — the distinction
  the requirement cares about.
- `useTruth` still drops the previous value on error, so nothing stale survives the failure transition.
- `take-guard.spec.js`'s third test pins the H-2 safety property under the new build: with reads aborted,
  the submit button and the maximum-price line are *absent*, not merely disabled.

This is strictly more evidence than before, on the same accepted behaviour.

## Previously closed findings — still closed

Reproduced rather than inherited.

| | Evidence |
|---|---|
| **H-1** | 22 indexer tests pass; runtime gate shows duplicate-burn → **2 rows, 2 distinct ids**; `UNIQUE (tx_hash, log_index)` intact; `indexer/` sources untouched this pass |
| **H-2** | 41 Playwright tests; canonical `Rig.take` and `HardReserve.redeem` calldata recorded from a real wallet flow; transaction path withdrawn when price unavailable; no server bundle |
| **M-1** | 10 exact-arithmetic units pass; `12345.6789` → `12345678900000000000000` through the DOM; no `Number`/float on the quantity path |
| **M-2** | Integrated harvest reconstruction PASS — `S`, `B`, `B/S` equal chain state, `vyrf_burn` attributed, all five causes, replay ×3 and real reorg hold |
| **M-3** | Codegen gate 5/5 tables; runtime gate indexed a live chain with indexed `S` equal to chain `totalSupply` |

## Concerns (non-blocking)

### L-1 · carried · Ponder codegen gate wording

The gate prints "config, schema and API modules all load". I previously probed it with an empty required
address and it still passed, so it demonstrably proves schema compilation and API-module resolution but not
config validity.

**Graded: no remediation required.** No acceptance or security claim rests on that sentence. The gate's
load-bearing property — failing when generation is absent — is real and was observed failing on the pre-fix
tree. Config validity is independently established by the runtime gate, which starts the app with real
addresses and indexes a live chain. Wording precision alone does not justify touching a passing gate.

### L-2 · new · Test and production builds share `out/`

`output: 'export'` writes both builds to `web/out/`, so after `npm run test:copy` the export directory holds
the test artifact with placeholder addresses and an unroutable RPC.

**Graded: informational.** The failure mode is loud, not silent — every surface renders "data unavailable"
against `127.0.0.1:1`, and the addresses are visibly synthetic (`0x…0f0001`). No secret is involved and the
mitigation is ordering (`npm run build` last before any deploy). Worth a line in a deployment runbook rather
than a code change. Related: `verify-static-export.mjs` validates whichever artifact is present; the two are
structurally identical, so its no-server claim is unaffected.

### Rendered payout-number coverage — graded

`previewRedeemRaw` is exhaustively unit-covered (floor semantics, `S = 0`, zero and null inputs, exactness),
and the rendered raw-input path is asserted through the real DOM. The remaining untested step is
`formatUnits18(quote)` — a thin formatting layer over arithmetic that is already adequately tested.

**Graded: non-blocking coverage debt, not a requirement gap.** Every element AC-8 names is evidenced. I am
deliberately not manufacturing a blocker for a formatting call. Worth noting that the infrastructure to
close it now exists (this build plus `page.route`), so it is cheaper than it was.

## Adversarial analysis

**Concerns identified.** (1) `web/components/WalletFlows.jsx:101` — `submit` does not re-check `ready`;
correctness rests on the render branch swapping the button away when `price` becomes null, which is true but
implicit. (2) `web/scripts/build-with-test-env.mjs:27` — the RPC host is duplicated as a literal in
`web/tests/take-guard.spec.js:22`; a change to one silently breaks the other's interception, and only a
comment couples them. (3) `web/tests/take-guard.spec.js:156` — the price-update phase depends on a real 12s
poll, making the suite's runtime sensitive to `STALE_AFTER_MS`/`pollMs` changes elsewhere.

**Assumption challenged.** The fix assumes React's committed-handler closure is a sufficient per-submission
freeze. *Risk if wrong:* a concurrent-rendering mode could in principle invoke a handler from a
non-committed render, moving the guard. *Verdict:* sound here — the app is not in concurrent-features
territory, the displayed value and the guard derive from the same expression in the same render, so any such
skew would be visible rather than silent, and the empirical two-transaction test confirms the behaviour.

**Alternative not considered.** The guard could have been threaded explicitly through `run()` as an argument
rather than captured. *Tradeoff:* marginally more legible about intent, but it adds a parameter to express
what the closure already guarantees. *Verdict:* current approach is justified — it is the smaller diff and
removes state rather than adding plumbing.

## Regression sweep — reproduced

| Gate | Result |
|---|---|
| `forge test` | **397 passed, 0 failed** (33 suites) |
| indexer units (`reconstruct` + `handlers`) | **22 passed** |
| web exact-arithmetic units | **10 passed** |
| Playwright (copy + wallet + take-guard) | **41 passed** |
| M-4 take-guard regression | **3 passed; fails at the price-update phase against the reintroduced defect** |
| `verify-ponder-codegen.mjs` | **PASS** — 5/5 accepted tables |
| `verify-ponder-runtime.mjs` | **PASS** — 2 settlements, 5 causes, duplicate-burn 2 distinct rows, indexed `S` = chain `S` |
| reconstruction incl. harvest | **PASS** — 0 ambiguities; replay + real reorg hold |
| `verify-accepted-pins.mjs` | **PASS** — census unchanged |
| `verify-rsc-runtime.mjs` | **PASS** |
| `verify-static-export.mjs` | **PASS** — 6 pages, server bundle absent, 0 call sites |

## Preservation

This pass touched exactly four files, all under `web/`: `components/WalletFlows.jsx`, `package.json`,
`scripts/build-with-test-env.mjs` (new), `tests/take-guard.spec.js` (new). Verified by modification time
against `remediation-pass-2.md`: nothing under `src/`, `script/`, `test/`, `tools/` or `indexer/` sources was
written (the only `indexer/` hits are inside the gitignored `.ponder/` runtime database).

`src/Lens.sol` remains byte-identical to the originally reviewed version (`00030ebfd5dc9a88…`). Sprint 2–5
implementation, `docs/authority/**`, `prd.md`, `sdd.md`, `sprint.md`: `git status --porcelain` empty. No new
direct or peer dependency; census identical. No P1 mechanism, no operator-reserved value resolved.

Previously retired questions were not reopened: R-1, R-2, R-3, R-5 stand as decided; R-4 remains resolved by
H-1 and R-6 by M-2/M-3.

## Next step

`/audit-sprint sprint-6`. No `COMPLETED` marker is written by review.

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":2},"sprint_id":"sprint-6","ts":"2026-08-14T00:00:00Z"} -->
