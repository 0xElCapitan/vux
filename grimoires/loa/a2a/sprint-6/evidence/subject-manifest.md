# Sprint 6 — subject manifest

**Branch:** `sprint-6` · **Baseline:** `92f8762111cd89c4cbdd4bcb11d06bf368f29377`
**Derived from git** (`git add -An --dry-run`), not from expectation, and partitioned by path prefix so the three groups are exhaustive and disjoint by construction.

Excluded as pre-existing State-Zone churn not authored by this node: `.beads/`, `.run/`, `grimoires/loa/analytics/`, `ledger.json.bak`, `ledger.json.lock`.

Dependencies are NOT in any group: they are reproduced from the committed lockfiles under the accepted refreeze and are gitignored.

## Group A — implementation subject (45 files)

fingerprint: 20289436748666cab658c9a4e6777476e2f9aa854ec217dff39cca6b05029e4b

c75df2c86f8c811b…  .gitignore
309117216c15b92c…  indexer/.npmrc
1a38077c7a9c4bc8…  indexer/abis/vux-events.mjs
7c305c97731c2963…  indexer/package-lock.json
f345af9c8821636b…  indexer/package.json
cf7b980ecfc54fa5…  indexer/ponder.config.ts
5394e6e3cc20334a…  indexer/ponder.schema.ts
07dd89c755821dad…  indexer/scripts/extract-abis.mjs
04a20ac3edaacbf9…  indexer/scripts/reconstruct.mjs
9c337273dcbd096e…  indexer/sql/schema.sql
4eb43fe8d742700c…  indexer/src/api/index.ts
3782c12c37bc11ad…  indexer/src/index.ts
68b5180965db36bd…  indexer/src/lib/reconstruct.mjs
5ac32b2528811427…  indexer/test/reconstruct.test.mjs
0d8faf611d03f788…  script/TruthScenario.sol
00030ebfd5dc9a88…  src/Lens.sol
66abfbadd6090d71…  src/interfaces/ILensViews.sol
90137aa3a264b0f3…  test/events/BurnCausePairing.t.sol
3dc8f7096284e0d7…  test/events/EventSchemaConformance.t.sol
b1358304b364f2c1…  test/lens/LensEstimateParity.t.sol
318913a0c7043ff5…  test/lens/LensFixture.sol
1782b0905a87748c…  test/lens/LensSurface.t.sol
640550688f27fb43…  test/lens/LensViews.t.sol
43858a5b22895653…  tools/offchain/verify-accepted-pins.mjs
34babf9123cf08f5…  web/.npmrc
4a9af11327115193…  web/app/accounting/page.jsx
b11c4bf5b6a2f5fb…  web/app/globals.css
a177627d0abea54a…  web/app/layout.jsx
4fd4413dbe8f6214…  web/app/page.jsx
08fcfd36069b91e2…  web/app/redeem/page.jsx
c682b103f50c4e77…  web/app/treasury/page.jsx
2c0fb3bebc965894…  web/app/trust/page.jsx
7c9e3c49f3983181…  web/components/ReserveDescription.jsx
10d84b30939071a0…  web/components/ThreeTierPanel.jsx
2e65f2429f5672a0…  web/components/Unavailable.jsx
3c2238fe51a73743…  web/lib/protocol.js
124c94577cbd53e0…  web/lib/truth-copy.js
2df130c6e00d13ea…  web/next.config.mjs
f2fcf22b704fd14d…  web/package-lock.json
8bc21477bee8aeda…  web/package.json
711eaad0d649e30d…  web/playwright.config.js
7f9a7b08c78e56d3…  web/scripts/serve-static.mjs
109b60fdab90f0fd…  web/scripts/verify-rsc-runtime.mjs
d9fe1405dbf41784…  web/scripts/verify-static-export.mjs
762e15483a5a5337…  web/tests/truth-copy.spec.js

## Group B — activated authority (2 files)

fingerprint: 1e6515cc1c79f553c68d8172e16c78c183133ad0bc6057bf07cfb400ea267a2c

a37ab91f29c2fe25…  docs/authority/vux-v1-offchain-provenance-refreeze-2026-08.md
52c626131c3c222f…  docs/authority/vux-v1-source-registry-offchain-refreeze-2026-08.json

## Group C — lifecycle evidence (8 files)

fingerprint: 53f221702be5c571397a18b032b2880f50df1654562b4d2504600539b2988405

4e4756ca0552e49a…  grimoires/loa/NOTES.md
31a28f79cc526e5c…  grimoires/loa/a2a/index.md
2d1558559d4f2e8d…  grimoires/loa/a2a/sprint-6/evidence/event-completeness-audit.md
aaeafa4219d6764f…  grimoires/loa/a2a/sprint-6/evidence/next-rsc-bundled-verification.md
8124dfda708c33a6…  grimoires/loa/a2a/sprint-6/reviewer.md
80f484be7299246e…  grimoires/loa/a2a/trajectory/karpathy-2026-08-14.jsonl
d503b5bc6fd2bdc4…  grimoires/loa/a2a/trajectory/zone-guard-2026-08-14.jsonl
9ea08511d5e03e5c…  grimoires/loa/ledger.json
