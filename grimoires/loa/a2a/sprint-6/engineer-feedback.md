# Sprint 6 — Truth Surfaces: Lens, Indexer & Truthful UX — Review Feedback

**Verdict:** `CHANGES_REQUIRED`
**Reviewer node:** `/review-sprint sprint-6` — independent implementation review only. No remediation, no audit, no commit, no acceptance.
**Branch:** `sprint-6` · **Baseline:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377` (`HEAD` unchanged; no commit made)
**Date:** 2026-08-14

## Subject fingerprint (re-derived mechanically, not inherited)

Derived from `git status --porcelain --untracked-files=all`, partitioned per `evidence/subject-manifest.md`,
per-file `sha256`, aggregate `sha256(join("\n", sorted "<sha256>  <path>"))`.

| Group | Files | Claimed | Re-derived | Result |
|---|---|---|---|---|
| A — implementation subject | 45 | `20289436748666ca…` | `20289436748666cab658c9a4e6777476e2f9aa854ec217dff39cca6b05029e4b` | **MATCH** |
| B — activated authority | 2 | `1e6515cc1c79f553…` | `1e6515cc1c79f553c68d8172e16c78c183133ad0bc6057bf07cfb400ea267a2c` | **MATCH** |
| C — lifecycle evidence | 8 | `53f221702be5c571…` | `3df083f3ab1d9c61…` | differs — see L-3 (not a defect) |

**The claimed 45-file subject is confirmed exactly.** All 45 paths present, all 45 per-file digests equal
the manifest, aggregate equal. This is the subject preserved throughout the review and re-derived at exit.

## Evidence independently reproduced

Every gate was re-run from the working tree. None was accepted on report.

| Gate | Reported | Reproduced |
|---|---|---|
| `forge test` | 397 pass / 0 fail | **397 passed, 0 failed** (33 suites) |
| `node --test indexer/test/reconstruct.test.mjs` | 11 pass | **11 passed** |
| `tools/offchain/verify-accepted-pins.mjs` | PASS | **PASS** — indexer direct=3/closure=391, web direct=7/closure=371, all entries carry integrity |
| `web/scripts/verify-rsc-runtime.mjs` | PASS | **PASS** — next 15.1.12 = accepted pin; both vendored transports build-stamp `20260126` ≥ floor `20251211`; no shadowing |
| `web/scripts/verify-static-export.mjs` | PASS | **PASS** — 6 pages, server bundle absent, 0 markers, 0 call sites |
| `npx playwright test` | 25 pass | **25 passed** |

Prior-sprint preservation independently confirmed: `git status --porcelain` over `src/ test/ script/ docs/
lib/ foundry.toml remappings.txt prd.md sdd.md sprint.md` is **empty**. Tracked diff is 8 files —
`.gitignore` (purely additive, +12/−0) plus State-Zone lifecycle files. No deletions. No P1 mechanism.
No prior authority file touched; the two new authority files are additive.

---

## Findings

### H-1 · HIGH · The Ponder supply-change id collides on caller-composed transactions, and the row is silently dropped

**Violated requirement:** AC-2 — "an indexer-only recompute of `S`, `B`, `B/S`, per-settlement legs, and
burn causes … **matches chain state with zero ambiguity**" (`sprint.md:425`). Disposes **R-4**.

`indexer/src/index.ts:39-40` keys every supply change as `` `${tx}:${delta<0?"burn":"mint"}:${|delta|}` ``
and `indexer/src/index.ts:69` inserts it with `.onConflictDoNothing()`.

`reviewer.md:261` justifies the id as safe because "its one collision case is two same-signed changes of
identical amount in one transaction, which the protocol cannot produce … the three burn sites are separate
external functions on separate contracts with no multicall surface."

**The multicall surface is the caller, not the protocol.** `src/VUX.sol:115` is
`function burn(uint256 amount) external { _burn(msg.sender, amount); }` — fully permissionless. Any EOA can
deploy a contract whose function body calls `vux.burn(x)` twice. That single transaction emits two
`Transfer(holder → 0, x)` logs with the same `txHash` and the same `amount`, so both map to the **identical**
`changeId`. The first insert lands; the second is **silently discarded**. The `supplyChange` table then
under-reports burns by `x`, and `S` recomputed from its deltas diverges from chain `totalSupply`.

Reachable variants: `HardReserve.redeem(q,to)` twice in one transaction (`src/HardReserve.sol:150` —
`nonReentrant` blocks reentrancy, not two sequential top-level calls), or `redeem(q)` and `burn(q)` mixed.

**Why no test caught it.** `test/events/BurnCausePairing.t.sol:262`
(`test_NoTransactionEverPresentsTwoCompetingBurnCauses`) asserts distinct *cause classes* per transaction —
a different property — and its own comment records that "Each entry below is one transaction", every step a
single protocol call. It never composes two same-amount burns into one transaction, because doing so needs
an attacker contract the fixture does not build. `test_HolderSelfBurnCarriesNoCauseEventAndCollidesWithNone`
(`:240`) burns once.

**Why the passing harness is silent.** The standalone reconstruction is immune: `indexer/src/lib/reconstruct.mjs:49`
keys per log — `` `${blockHash}:${txHash}:${logIndex}` ``. So the AC's proof path and the delivered app's
streaming path use *different* identity schemes, and only the un-run one is defective. `index.ts:19` states
the id is "computed identically on both sides"; it is not.

**Bounded remediation target:** key `supplyChange` on `(txHash, logIndex)` — the `rowId` helper already at
`indexer/src/index.ts:42` — and refine causes by matching candidate rows within the transaction rather than
by an amount-derived primary key. Add a Forge case that composes two equal self-burns in one transaction.

### H-2 · HIGH · Task 6.6 wallet flows are entirely absent, and the report presents Task 6.6 as complete

**Violated requirement:** `sprint.md` Task 6.6 — "Frontend — five pages per sdd.md:L633-L643, `truth-copy.ts`
lint-guarded constants, `<ReserveDescription/>`, **wallet flows (`take` with maxPrice guard, `redeem`)**,
no-optimistic-entitlement states". Corroborated by `sdd.md:L633` (Throne page: "`take` flow with `maxPrice`
guard", key data "Lens + wallet"), `sdd.md` §4.4 "Key Flow: take the throne" (Connect wallet → approve WETH →
take), and `sdd.md:L444` justifying wagmi as "wallet interactions for `take`/`redeem`".

No wallet functionality exists:

- `wagmi@2.14.16` and `@tanstack/react-query@5.71.1` are declared in `web/package.json` and **imported
  nowhere** — verified by ripgrep across `web/` excluding `node_modules`.
- `RESERVE_ABI` (`web/lib/protocol.js:44`, carrying `redeem`) and `RIG_ABI` (`web/lib/protocol.js:49`,
  carrying `take(maxPrice)`) are exported and **never imported**. Only `LENS_ABI` is consumed.
- No `writeContract`, `sendTransaction`, `useAccount`, connector, or approval path anywhere.
- `web/app/page.jsx:50` renders prose — "Set a maximum price" — which is copy about a flow, not the flow.

`reviewer.md:284-294` reports Task 6.6 "**complete**" and enumerates pages, copy module, `<ReserveDescription/>`
and the read layer, silently dropping the wallet-flows clause. It is absent from Known Limitations
(`reviewer.md:367-387`) and from R-1…R-6 (`reviewer.md:437-444`). The one recorded Task 6.6 deviation is the
`.ts`/`.js` filename.

This is a requirement gap **and** a report-truthfulness failure: an unbuilt named deliverable reported complete
without disclosure. Two direct dependencies were also carried through the fail-closed provenance gate for a
capability that was never built.

**Bounded remediation target:** implement the `take`/`redeem` wallet flows against the already-pinned wagmi/viem
surface and the already-declared ABIs, preserving the no-optimistic-entitlement copy rules — **or** record an
explicit, operator-visible scope split of the wallet-flow clause of Task 6.6 to a follow-up sprint task and
justify retaining the two unused direct dependencies. Do not resolve it silently.

### M-1 · MEDIUM · The redeem quote is computed through IEEE-754 and is not `floor(B×q/S)` of the amount typed

**Violated requirement:** `sdd.md:L634` — Redeem page shows "exact `floor(B×q/S)` quote (deterministic, zero
fee)"; AC-8 no-optimistic-display (`sprint.md:431`).

`web/app/redeem/page.jsx:24`: `const q = BigInt(Math.trunc(Number(amount) * 1e18));`

`Number(amount) * 1e18` exceeds 2^53 for any realistic amount, so `q` is the nearest representable double, not
the value typed. Measured on this tree:

| typed | `q` as implemented | exact | delta |
|---|---|---|---|
| `12345.6789` | `12345678900000001622016` | `12345678900000000000000` | **+1,622,016** |
| `1.005` | `1004999999999999872` | `1005000000000000000` | −128 |
| `1000.000000000000000001` | `1000000000000000000000` | `1000000000000000000001` | −1 (wei dropped) |

The first row **overstates** `q`, so the displayed payout exceeds what burning that amount returns — an
optimistic display, directly beneath `REDEEM_COPY.deterministic` (`web/lib/truth-copy.js:137`) rendered at
`web/app/redeem/page.jsx:47`, which promises "fee-free and deterministic: floor(B × q / S)". The magnitude is
dust-level, but the surface asserts exactness it does not deliver.

**No test exercises this branch at all.** The Playwright suite runs with no RPC configured (deliberately, per
`reviewer.md:300-303`), so `hard.unavailable` is always `true` and `quote` is always `null`. Test 21 ("with no
amount entered, no optimistic value is displayed") passes on the empty path. The quote arithmetic — the only
non-trivial numeric logic in the frontend, and a money path — has zero coverage, contrary to the project's
Karpathy §4 floor ("Non-trivial logic … MUST leave at least one runnable check that fails if the logic breaks").

**Bounded remediation target:** parse the decimal string to wei directly (`viem`'s `parseUnits` is already a
pinned dependency), and add a test that exercises the quote branch with a stubbed `hardStats` read.

### M-2 · MEDIUM · Task 6.5's live scenario omits the harvest leg, on a justification that does not hold

**Violated requirement:** `sprint.md` Task 6.5 — "scripted anvil scenario (**genesis-fixture → takeovers →
redemptions → harvest**) recomputed from events only". Disposes part of **R-6**.

The delivered scenario (`script/TruthScenario.sol`, driven by `indexer/scripts/reconstruct.mjs`) covers
bootstrap → settlements → redemption → eventless donation → self-burn → VEM-limited settlement → ordinary
settlement. **No harvest.** `vyrf_burn` is covered only in Forge and unit tests (`reviewer.md:278-282`,
Known Limitation 2).

The stated justification — `script/TruthScenario.sol:45`, "canonical pool depends on `vm.getCode` against the
separate `=0.7.6` unit", and `reviewer.md:280` "cheatcodes do not exist on a live node" — is not binding.
`test/treasury/PoolDeployerHarness.sol:39` obtains the creation code with
`vm.parseJsonBytes(vm.readFile("out-v3core/…/UniswapV3Pool.json"), ".bytecode.object")` and deploys it with a
plain assembly `create` (`:44`). The cheatcode only **reads a file**; the deployment is ordinary CREATE.
`indexer/scripts/extract-abis.mjs:11,26` already reads forge artifacts from Node with `readFileSync`, and
`out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json` is present on disk. The driver could pass the init code to a
`TruthScenario` deploy method as `bytes`. No cheatcode, no new authority, no external secret.

Grading rather than accepting the substitution: the accepted scenario names harvest in the integrated
event-only proof, and separate Forge coverage is not that proof.

**Bounded remediation target:** extend `TruthScenario` with a pool-deploy entry point taking the creation code
as `bytes`, have `reconstruct.mjs` supply it from the compiled artifact, and add the harvest operation so all
five burn causes are exercised in the one event-only run.

### M-3 · MEDIUM · The delivered Ponder application is unexercised and does not complete codegen

**Violated requirement:** `sprint.md` Task 6.4 — "ponder indexer + PostgreSQL schema … + read-only REST
endpoints". Disposes the remainder of **R-6**.

`reviewer.md:381` records that "The ponder app has not been run against a synced chain." Reproduced
independently: `npx ponder codegen` in `indexer/` prints `Failed to find Response internal state key`,
**creates no `generated/` directory**, and **exits 0**. Installed Node is v25.2.1, inside ponder's declared
`engines: { "node": ">=18.14" }`, so this is not an out-of-range environment.

The standalone harness proves the *reconstruction claim*, and that distinction is fairly stated in the report.
But H-1 is the concrete cost of the substitution: a reachable correctness defect survived into the delivered
Task 6.4 artifact precisely because its only proof was by argument, while the passing harness uses a different
identity scheme. A no-op codegen that exits 0 is additionally fail-open — a CI step invoking it would pass
while doing nothing.

**Bounded remediation target:** make `ponder codegen` succeed (or fail non-zero) in the pinned environment, and
run the delivered app against the anvil scenario end-to-end so the streaming handlers are exercised, not only
the fold.

### L-1 · LOW · `verify-static-export.mjs:106` prints "server bundle : absent" unconditionally

The literal is emitted regardless of outcome. The gate itself is sound — the real checks at
`web/scripts/verify-static-export.mjs:46-54` push to `failures` and drive the verdict and exit code — but a
FAIL run would still print "absent". Cosmetic; move the line under the check result.

### L-2 · LOW · `subject-manifest.md`'s exhaustiveness claim is inaccurate

`evidence/subject-manifest.md:4` states the three groups are "exhaustive and disjoint by construction", and
`:6` lists the exclusions. Two changed paths fall in no group and no exclusion:
`grimoires/loa/a2a/sprint-6/sprint-6-scope.md` and
`grimoires/loa/a2a/trajectory/continuous-learning-2026-08-14.jsonl`. Group A is unaffected and verified exactly;
this is an evidence-hygiene note.

### L-3 · LOW · Group C's fingerprint is self-referentially unverifiable

Group C re-derives to `3df083f3ab1d9c61…` against the claimed `53f221702be5c571…`. Five of eight members
(`NOTES.md`, `a2a/index.md`, `reviewer.md`, and both trajectory logs) are written by the node *after* the
manifest records their digests — `reviewer.md` records a hash of itself. Not a defect and not evidence of
tampering; Groups A and B are stable and both match. Note it as a limit of the scheme, or exclude
self-mutating lifecycle files from fingerprinting.

---

## Residual findings dispositioned

| # | Item | Disposition |
|---|---|---|
| **R-1** | `estimateIfDisplacedNow` bootstrap branch | **Correct implementation.** Ruled below. |
| **R-2** | `truth-copy.js` vs `truth-copy.ts` | **Accepted.** No requirement mismatch. Ruled below. |
| **R-3** | `sdd.md:L449` names 15.1.4; pin is 15.1.12 | **No normative contradiction.** Not HITL. Ruled below. |
| **R-4** | Streaming attribution id | **Rejected — reachable.** See H-1. |
| **R-5** | Bundled RSC stamp not byte-comparable | **Accepted.** PASS stands. Ruled below. |
| **R-6** | Ponder app unexercised | **Graded.** See M-2, M-3. |

### R-1 — correct implementation, and the test discriminates

Not pre-decided; reconciled against actual `Rig.take` behaviour. `src/Rig.sol:354` sets
`hardContribution = bootstrap ? reserveLeg + kingLeg : reserveLeg`; `:369-370` measures `dR` and reverts unless
it equals that; `:571` computes `qSafe = mulDiv(dR, sPre, bPre)`. `src/Lens.sol:222` returns
`bootstrap ? hardTarget + kingLeg : hardTarget` and `:126` applies `mulDiv(·, s, b)` — an exact reproduction.
`Lens._hardToReserve` (`:216-221`) matches `Rig._route` (`src/Rig.sol:522-528`) term for term and reads the
basis-point constants from the Rig rather than redeclaring them.

`sdd.md:L711`'s literal `D = hardTarget` would exclude the King leg at bootstrap and thereby **understate** the
`qSafe` a bootstrap settlement actually emits; the same line makes parity the stated requirement
("(parity, 2026-08-12)"), and Task 6.2's criterion is "estimate parity against actual settlement outcomes".
Parity governs, the implementation follows it, and the divergence is confined to the auxiliary `qSafeEst` —
`estimateQmint` is `0` under either reading because tier 1 is zero during bootstrap.

Discrimination verified rather than assumed: `test/lens/LensFixture.sol:54` asserts `estQSafe == r.qSafe`, and
`test_ParityAtBootstrap` (`test/lens/LensEstimateParity.t.sol:39`) reads the estimate and settles in the same
block. Dropping the bootstrap branch would shift `qSafeEst` by `mulDiv(kingLeg, s, b)` with
`kingLeg = 80% of price ≠ 0`, so the assertion fails. Not permissible underspecification — a correct branch
with a genuinely failing-sensitive test.

### R-2 — `truth-copy.js` is not a requirement mismatch

The requirement is a single lint-guarded canonical copy source ("Copy strings live in a single `truth-copy.ts`
module with lint-guarded string constants **so review and Playwright tests target one location**",
`sdd.md:L631`). `web/lib/truth-copy.js` supplies exactly that: every truth string is exported from one module,
the pages import from it, and `web/tests/truth-copy.spec.js:10` imports the same module so the assertions and
the rendered copy cannot diverge. Semantics are fully preserved; the filename was descriptive of the language,
not normative to the property.

The simpler authorized realization is correct here: `.tsx` compilation requires the `typescript` package, which
the accepted refreeze §8 excludes explicitly, so authoring in TypeScript would be unauthorized dependency
expansion under the same gate AC-1 enforces. Recorded openly at `web/lib/truth-copy.js:11-17` and
`reviewer.md:290-294`. No TypeScript was added during review. **Accepted as-is.**

### R-3 — the authorities reconcile; not `HITL_REQUIRED`

`sdd.md:L449` names Next.js 15.1.4. The operator-accepted off-chain provenance refreeze (accepted 2026-08-14)
records at §D-1: "**RESOLVED — select `next = 15.1.12`; do not use `15.1.4`**". The operator has already
adjudicated this exact question, knowingly and by name, so there is nothing left for review to escalate.

Three independent reasons the newer instrument governs the exact implementation dependency:

1. **The SDD delegates the pin.** `sdd.md:L452` — "All off-chain dependencies pass the same pin-recording gate
   before use (PROV-6)". The refreeze is that gate's operator-accepted output; the table entry is the family
   selection, the refreeze is the exact version.
2. **Specificity and recency agree.** The refreeze is both the more specific instrument (exact versions,
   integrity digests, licences, peer closure) and the later accepted one.
3. **The architectural property the SDD's justification rests on is preserved and strengthened.** 15.1.12 is
   inside the 15.1.x family; "static-exportable read-only UI, no server-side custody" is now mechanically
   enforced by `web/scripts/verify-static-export.mjs` rather than asserted.

`sdd.md:L449` is therefore a **stale descriptive reference, not a normative contradiction**. The SDD was
correctly not edited by the implementation node, and is correctly not edited by review. Recommend a
documentation-reconciliation edit in a later authorized node; the refreeze §10 already carries the item.

### R-5 — the deferred RSC PASS is adequately established

The build stamp alone was not treated as proof. The determination rests on four legs, of which the decisive one
is independent of the stamp: **the app has no RSC server surface at all.** That is verified mechanically from
build output, not prose — `web/scripts/verify-static-export.mjs` walks `out/`, confirms no server artifacts
(`:46-54`), and finds 0 `react.server.reference` markers and 0 non-definition `createServerReference` call
sites. Reproduced: 6 pages, server bundle absent, 0 markers, 0 call sites. The advisory's own scope condition
is "if your app's React code does not use a server, your app is not affected", so even were the build-stamp
reasoning wrong, the vulnerable surface is not reachable.

The refined detector was examined for the false-negative path specifically requested. `uses = total −
definitions` (`:92-94`) with `definitionRe = /createServerReference\s*[:=]\s*function/`: a real call site in
the same chunk as the definition yields `uses ≥ 1` and fails; a definition emitted in an unrecognised form
(e.g. an arrow function) yields `uses ≥ 1` and also fails. Both error directions are toward FAIL, so narrowing
did not open a false-negative path. Capability definition is correctly not counted as use. The
`react.server.reference` marker check is retained as the independent second signal. **Sound; PASS accepted**,
with the stated limit honestly recorded.

---

## Verified as met

These were re-derived, not inherited.

- **AC-1 (gate first).** `verify-accepted-pins.mjs` PASS on both roots; every accepted pin's lockfile `version`
  **and** `integrity` equals the census; 0 unmet required peers; closure 391/371 with integrity on every entry;
  `lockfileVersion: 3`. Acceptance-state mutation did not alter substantive candidate pin evidence — refreeze
  §D-1 records the disposition and §5 the security evidence, both intact. No unauthorized direct/peer expansion
  found. (Two authorized-but-unused direct deps are noted under H-2, which is a scope issue, not a gate breach.)
- **AC-3 (three-tier truth).** Three distinct labels from `web/lib/truth-copy.js:27-56`; canonical explanation
  verbatim at `:61-62`; tier-2's mandated "may rise or fall, not claimable" at `:41`. Playwright tests 1, 2, 10 pass.
- **AC-4 (YELLOW).** `web/components/ReserveDescription.jsx` is the sole Reserve describer and always renders
  the disclosure — structural coupling. Tests 11-14 pass, including `count(disclosures) === count(descriptions)`
  on every page.
- **AC-5 (contestability).** Exact bounded form at `web/lib/truth-copy.js:69-70`, rendered on `/trust` only;
  tests 15-17 pass; 12 prohibited claim families greped, permitted only under negation.
- **AC-6 (`strategic_nav_disclosed`).** Named at `web/lib/truth-copy.js:122` and in `indexer/sql/schema.sql`;
  three enforcement layers (SQL `CHECK`, API refusal, rendered-sentence assertion); tests 17-19 pass. `NULL`,
  never `0`, for "not disclosed".
- **AC-7 (failure truthfulness).** Reproduced in the degraded state, not only the happy path: the whole suite
  runs with no RPC, so every live read is in its failure path. `useTruth` **drops** the prior value on error
  (`web/lib/protocol.js:82`) and ages out non-refreshing values (`:101-103`); `<Truth>` makes a value
  unreachable without its availability. Tests 22-24 pass — unavailable renders, tiers show no number and
  specifically not `0`, FB-17 banner appears, FB-18 disclosure on `/trust`.
- **Compliance detector correctness.** Confirmed it tests **predication, not vocabulary**
  (`web/tests/truth-copy.spec.js:64-100`): 12 affirmative-construction regexes globally, plus the strict
  word-level rule scoped to the tier-1/tier-2 blocks requiring negation (`:106-122`). The correction was right —
  a flat word ban would forbid tier 2's own mandated "not claimable" (`truth-copy.js:41`) and the verbatim
  contestability claim's "user-owned VUX" (`:70`). This reading matches FR-15.2's "described as", which is a
  rule about predication.
- **Lens read-only boundary.** `src/Lens.sol` holds one immutable, no payable/`receive`/`fallback`, no token
  handle, no role. `test/lens/LensSurface.t.sol:113-149` asserts opcode-level absence against the compiled
  artifact **with positive controls from `Rig`'s runtime** — the pairing is what makes the absence meaningful.
  Constructor takes only the Rig; Reserve and token derived at call time (`src/Lens.sol:185-188`), so the
  mis-wiring class is structurally unavailable. `wethNeededForFullQraw` rounds UP via
  `Math.Rounding.Ceil` (`:192`) and short-circuits at zero without dividing. `hardStats` reverts rather than
  returning `0` at `S == 0` — correct: `0` would present absence as measurement.
- **Reconstruction accounting independence.** Genuine, and enforced by construction rather than discipline:
  `indexer/src/lib/reconstruct.mjs` imports no contract-call helper and never reads state; the acceptance run
  keeps reconstruction on `eth_getLogs` and truth on `eth_call`. `B` is rebuilt from the WETH token's own
  transfer record on the Reserve address (`:262-265`), not from settlement legs — the definitional reading, and
  the scenario's eventless donation is the case that proves it (a legs-based rebuild would miss it entirely).
  `B/S` floors and is `null` rather than `0` when `S` is zero. The fold's purity gives idempotency,
  order-independence and prefix-stability as properties rather than bolt-ons, all asserted (11/11 unit tests).
- **Event completeness.** FR-14.1–14.4 observables map to declared events with live emit sites, or to recorded
  derivation (F-1) / non-derivation (F-3). No event added, renamed or retyped — confirmed by the empty tracked
  diff over `src/`. Pairing tests read logs only, never protocol state, which is the right discipline for an
  observability claim. `extract-abis.mjs` asserts each `topic0` against the accepted signature, 13/13.
  Burn-cause uniqueness holds **for protocol-composed transactions**; the caller-composed case is H-1.
- **Scope and prior-sprint preservation.** Byte-unchanged, verified above. Off-chain surfaces are read-only:
  `indexer/src/api/index.ts` exposes the five accepted read routes with no write endpoint, and the frontend
  holds no key and no custody. All accumulated monetary/POL invariants green in the 397-test run.

---

## Adversarial Analysis

### Concerns identified

1. **The proof path and the shipped path diverge** — `indexer/src/lib/reconstruct.mjs:49` keys per log while
   `indexer/src/index.ts:39` keys by amount. `index.ts:19` claims they are "computed identically on both sides".
   A green acceptance run says nothing about the handler that will actually run in production (H-1).
2. **Dependencies were pinned for a capability that was never built** — `web/package.json` carries
   `wagmi@2.14.16` and `@tanstack/react-query@5.71.1` with zero importers, and `web/lib/protocol.js:44,49`
   carries two dead ABIs. Unused direct dependencies are supply-chain surface with no consumer (H-2).
3. **The only money arithmetic in the frontend is both wrong and untested** — `web/app/redeem/page.jsx:24`
   routes wei through a double, under a rendered promise of determinism at `:47` (M-1).
4. **Testing in the degraded state hid the happy path.** Running Playwright with no RPC was the right call and
   caught the real `strategic_nav_disclosed` defect — but it also means `hard.unavailable` is permanently
   `true`, so every value-rendering branch on `/redeem` is dark. The choice that found one defect concealed
   another.
5. **`ponder codegen` exits 0 while producing nothing**, so a CI step invoking it would report success (M-3).

### Assumption challenged

- **Assumption:** "the protocol cannot produce two same-signed supply changes of identical amount in one
  transaction" (`reviewer.md:261`, `indexer/src/index.ts:20-24`).
- **Risk if wrong:** supply changes are silently dropped and the indexer's `S` diverges from chain — the exact
  failure AC-2 exists to exclude.
- **It is wrong.** The premise reasons about what the *protocol* composes; identity collisions are determined by
  what a *transaction* contains, and `src/VUX.sol:115` lets any caller compose freely. Make the invariant
  explicit and enforce it in the key, rather than relying on a property of the callee.

### Alternative not considered

- **Alternative:** key `supplyChange` on `(txHash, logIndex)` — already present as `rowId`
  (`indexer/src/index.ts:42`) and already the scheme the reconstruction uses — and let the cause handler refine
  by selecting candidate rows within the transaction.
- **Tradeoff:** the cause handler must resolve amount → row rather than compute the key directly, which is
  marginally more code in one handler.
- **Verdict:** should be adopted. It removes an entire defect class instead of arguing it unreachable, needs no
  new concept (the codebase already contains both helpers), and makes the two halves of the indexer agree on
  identity — which the comment already claims they do.

---

## Complexity / Karpathy

- **Simplicity:** good overall — the fold is genuinely minimal and the copy module is one file. Two
  `SIMPLICITY[delete]` items: `RESERVE_ABI` and `RIG_ABI` (`web/lib/protocol.js:44-52`, ~8 lines) are dead until
  H-2 is resolved. Resolve H-2 first; the correct fix may be to use them rather than delete them.
- **Surgical changes:** exemplary. Zero modifications to any prior-sprint file; `.gitignore` purely additive.
- **Think before coding:** strong. Assumptions are surfaced in `reviewer.md` and in-code. The one that was not
  surfaced is the collision premise, and it is the one that is false.
- **Goal-driven:** mostly met — the parity test compares against real emitted `Settled` records rather than
  inspection, which is the right shape. Two gaps: the redeem quote (M-1) and the streaming handlers (M-3) carry
  no runnable check that fails when they break.
- `net: −8 lines possible` after H-2 is dispositioned. Otherwise lean.

---

## Next Steps

1. Address H-1 and H-2 (both block approval), then M-1, M-2, M-3.
2. Route remediation through a separate `/implement sprint-6` node — review does not fix.
3. Re-run all seven gates plus a new test for each of H-1 and M-1.
4. Re-submit for `/review-sprint sprint-6`. `/audit-sprint` remains gated behind review approval.

**Not performed by this node:** no implementation, test, manifest, lockfile, authority, provenance, frontend or
indexer file was mutated; no audit, commit, push, landing, sprint acceptance, or Sprint-7 work. No
`COMPLETED` marker written. The eight `grimoires/loa/skills-pending/` candidates were treated as pending
learning candidates only — neither promoted nor treated as authority.

<!-- LOA-VERDICT {"gate":"review","verdict":"CHANGES_REQUIRED","counts":{"critical":0,"high":2,"medium":3,"low":3},"sprint_id":"sprint-6","ts":"2026-08-14T00:00:00Z"} -->
