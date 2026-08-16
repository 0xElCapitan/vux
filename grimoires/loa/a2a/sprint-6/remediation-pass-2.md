# Sprint 6 — Review Remediation, pass 2

**Node:** `/implement sprint-6` · **Branch:** `sprint-6` · **Baseline:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377` (unchanged, no commit)
**Terminal state:** **`SPRINT_6_REMEDIATED_READY_FOR_REVIEW`**

Starting identity re-derived before mutation: 51 files, `d406952ae5b2cd94…` — **exact match**.

## Subject

**56 files** · fingerprint `1bf3974d2b94c4488d90ce806d752de576f394c91768ed0e26c91ab73a1fc14c`

| Finding | Files this pass |
|---|---|
| H-2 | `web/lib/wagmi.js` (new), `web/app/providers.jsx` (new), `web/components/WalletFlows.jsx` (new), `web/tests/wallet-flows.spec.js` (new), `web/app/layout.jsx`, `web/app/page.jsx`, `web/app/redeem/page.jsx`, `web/lib/protocol.js`, `web/lib/truth-copy.js` |
| M-2 | `script/TruthScenario.sol`, `indexer/scripts/reconstruct.mjs` |
| Ponder runtime | `indexer/scripts/verify-ponder-runtime.mjs` (new), `script/TruthScenario.sol` (`doubleSelfBurn`) |

Sprint 2–5 implementation, `src/Lens.sol`, `docs/authority/**`, `prd.md`/`sdd.md`/`sprint.md`: byte-unchanged. No dependency added — `wagmi` and `@tanstack/react-query` were already in the accepted census and are now actually used.

## H-2 — wallet flows · **REMEDIATED**

Real client-side flows on the accepted stack: `WagmiProvider` + `QueryClientProvider` (which is what the pinned `@tanstack/react-query` is for), `injected()` connector, viem wallet client. No server, no custody — the export is still fully static.

**`take`** reads the live price, approves exactly `maxPrice` of WETH, then calls `Rig.take(maxPrice)`. The guard is captured at the moment the user confirms (`setConfirmed(price)`) and sent verbatim — the price is deliberately *not* re-read at submit time, because re-reading would silently move the user's own protection. If the price has risen past it, `PriceAboveMax` reverts, and that revert is surfaced as the guard working.

**`redeem`** takes the exact `bigint` from `parseUnits18` — the same value the quote was computed from — and passes it to `HardReserve.redeem(q, to)` unchanged. No float anywhere on the path; no approval needed (the Reserve burns from `msg.sender`).

Both expose pending/success/revert honestly. The success message says the transaction is confirmed and points at settled history rather than implying a payout. When a required read is unavailable the flow is *withdrawn*, not defaulted: with no readable price the `take` submit button does not exist at all, so there is no way to send an unguarded transaction.

**13 Playwright tests.** Notably the redeem tests drive the real DOM input and assert the rendered raw amount: `12345.6789` → `12345678900000000000000`, with an explicit assertion that it is *not* the old float value `12345678900000001622016`.

## M-2 — integrated harvest reconstruction · **REMEDIATED**

The retired cheatcode assumption was the blocker, and it was wrong: `vm.readFile`/`vm.parseJsonBytes` only ever *read* a JSON file, and the deployment itself is an ordinary `CREATE`. The driver now reads `out-v3core/VuxPoolDeployer.sol/VuxPoolDeployer.json` and `out/StrategicTreasury.sol/StrategicTreasury.json` in Node and passes the creation code in as `bytes`.

`TruthScenario` gained `deployStrategicStack`, `provisionPol`, `accrueFees` and `harvest`. Both contracts are deployed from artifact bytes rather than with `new` — `new StrategicTreasury(...)` embedded its creation code and pushed the harness to 27,190 bytes, past EIP-170; it compiled but could never have been deployed to the live chain it exists to run on. It is now 7,137 bytes.

The scenario runs on a live anvil chain: real canonical pool, real POL position minted through the real pay-in callback, real third-party round-trip swaps accruing both fee legs, then `harvestPol()`. The Rig's Strategic destination is deliberately left as the plain address Sprint 3 accepted, so the four causes already proven are unaffected.

**Result — all reconstructed from `eth_getLogs` only, compared against `eth_call` only:**

```
S      logs=156276985319726174908984  chain=156276985319726174908984
B      logs=311381095757575757577     chain=311381095757575757577
B/S    logs=1992494896932667248827765 chain=1992494896932667248827765
burn   vyrf_burn  25208579516493501515
```

`B` includes the WETH fee leg the harvest moved into the Hard Reserve, and it is rebuilt from the WETH token's own transfer record — not from settlement legs — so it picks the movement up definitionally. All five burn causes now appear in the one integrated run. Replay ×3 identical, reversed delivery identical, prefix-stable, and a real `evm_snapshot`/`evm_revert` returns to the pre-fork state.

## Delivered Ponder runtime · **REMEDIATED**

`indexer/scripts/verify-ponder-runtime.mjs` deploys the scenario, starts the **delivered** `ponder start` against anvil, waits for its own API to serve rows, and asserts on those rows. A ponder that never ran cannot pass: every assertion is about rows the app must have written.

It found two real obstacles rather than papering over them — `ponder start` fail-closes without `--schema`, and ponder skips historical sync until the start block is finalized (anvil's `finalized` tag trails the head, so the gate mines past it).

```
settlements indexed     : 2
supply changes indexed  : 7
duplicate-burn rows     : 2 (distinct ids: 2)
causes present          : genesis, other_authorized_burn, redemption_burn, settlement_mint, vyrf_burn
indexed S vs chain      : 151174546775739578839844 / 151174546775739578839844
```

The third row is the important one. `TruthScenario.doubleSelfBurn` calls permissionless `VUX.burn(x)` twice in one transaction — the reviewer's proof of concept, on a real chain — and the **shipped handlers** produce two rows with distinct ids. H-1 is now proven end-to-end through the delivered indexing path, not only in unit form.

## Preserved

H-1, M-1 and M-3 were not redesigned. Log-identity keying, replay idempotency, deterministic cause pairing and the `UNIQUE (tx_hash, log_index)` constraint are intact; exact string→raw parsing is intact; the discriminating codegen gate and corrected config are intact. All their regressions still pass.

## Verification

| Gate | Result |
|---|---|
| `forge test` | **397 passed, 0 failed** (33 suites) |
| indexer units (`reconstruct` + `handlers`) | **22 passed** |
| web exact-arithmetic units | **10 passed** |
| Playwright (copy/degraded + wallet flows) | **38 passed** |
| `verify-ponder-codegen.mjs` | **PASS** — 5/5 accepted tables |
| `verify-ponder-runtime.mjs` | **PASS** — delivered app indexed live anvil |
| event-only reconstruction incl. harvest | **PASS** — 0 ambiguities; replay/reorg hold |
| `verify-accepted-pins.mjs` | **PASS** — census unchanged |
| `verify-rsc-runtime.mjs` | **PASS** |
| `verify-static-export.mjs` | **PASS** — 6 pages, server bundle absent, 0 call sites |

## Residuals (non-blocking)

1. **The rendered payout number** (`floor(B x q / S)`) is not exercised with mocked `B`/`S`. Everything the finding listed is covered — the `12345.6789` case, input↔submitted-quantity correspondence, excess-decimal rejection, data-unavailable behaviour, no optimistic or stale quote — but the numeric payout itself needs a build with `NEXT_PUBLIC_RPC_URL` set plus `page.route()` RPC fulfilment. `previewRedeemRaw` is covered at unit level.
2. **The wallet flows are not driven by an injected signer.** Connection, guard construction, exact-quantity wiring, disabled/withdrawn states and copy are asserted; a signature round trip would need a mock EIP-1193 provider.
3. The Ponder runtime gate mines ~96 blocks to clear anvil's finality window — a property of anvil, not of the app.

No review, audit, commit, push, landing, or Sprint-7 work. No `COMPLETED` marker.
