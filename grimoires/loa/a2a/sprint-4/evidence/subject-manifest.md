# Sprint-4 implementation subject — manifest and fingerprint

**Node:** Sprint 4 implementation
**Purpose:** an exact-tree identity for `/review-sprint sprint-4` and the later audit, and a
clean separation between (A) what this node changed, (B) the lifecycle evidence it wrote, and
(C) pre-existing State Zone material it deliberately left alone.

---

## A. The implementation subject — 24 files

**Fingerprint:** `72896e9d80d16b229a78e19f8f51c4ed117f622423970bdb491b7d0575d3966b`

Reproduce exactly (msys/Git-Bash binary mode; the leading `*` in each row is `sha256sum`'s
binary marker and is part of the hashed bytes):

```bash
sha256sum foundry.toml src/StrategicTreasury.sol src/interfaces/ILSGModule.sol \
  src/interfaces/IStrategyAdapter.sol src/interfaces/IVUXBurnable.sol \
  src/v3core/VuxPoolDeployer.sol test/mocks/MockErc20.sol test/mocks/MockLsgModule.sol \
  test/mocks/MockPool.sol test/mocks/MockStrategy.sol test/mocks/MockWeth.sol \
  test/treasury/*.sol | LC_ALL=C sort -k2 | sha256sum
```

| sha256 | path | status |
|---|---|---|
| `5d74a91b1a2cf3fb8721f482e5e8d5358efd60107f3a7200fb83b83a25cb3fa3` | `foundry.toml` | **modified** |
| `ab83afeb53a8f34db10f2a13c834a6ecc7d7e11ada9b26e856325ef0e55b19bd` | `src/StrategicTreasury.sol` | new |
| `4966794efa7f063fc5aa1704498c44653ef78487eb560f033869fd132a66d0f2` | `src/interfaces/ILSGModule.sol` | new |
| `390010f5bfcb96f9237d7877d3a38ea3c9a464bb069e97dd86876a5279d1a25c` | `src/interfaces/IStrategyAdapter.sol` | new |
| `909607461e9e58af2b11df90c25461eefc2c79ef964de6528bb8077776b3a4d6` | `src/interfaces/IVUXBurnable.sol` | new |
| `09f3768347dead850e1b638f7136296d9adfdd12567edac658616af88f854e08` | `src/v3core/VuxPoolDeployer.sol` | new |
| `d8c8e78f4567fb029439b4380bb49606e2446cae0c598c4b876c4ac160b4d7e2` | `test/mocks/MockErc20.sol` | new |
| `ea8a925b2e3136063bccd5cb38be7b7a498c17a53936ad107f5d10c5831b4199` | `test/mocks/MockLsgModule.sol` | new |
| `7bf914c9e619907e506b72d0651c28760f8295739dc05fd33d31a53cd12e017f` | `test/mocks/MockPool.sol` | new |
| `fb17ada77cfb80f339f1bc73c9716f5d4cc688c0a6918c4069cf4f675949b372` | `test/mocks/MockStrategy.sol` | new |
| `355ea60f5180229d2fe8815f1ad5c17852f75f45b0742f26c0a0776430ce95ee` | `test/mocks/MockWeth.sol` | **modified** |
| `18c707d4032990d5b6c9b3c415ce6858e52fb337fcf1ae3df1eb52529ab923a1` | `test/treasury/PoolDeployerHarness.sol` | new |
| `3e691e918151f5444b30a5b4b8ab96edff4b8aa6c828440336bbdf5a8dd41cff` | `test/treasury/TreasuryAccountingProperties.t.sol` | new |
| `ed92735e6cec73ba45875b7582cea40055f89d2d7023b96c7441c861911c4543` | `test/treasury/TreasuryAdmission.t.sol` | new |
| `f5d09be17e274ea332633b89ff02e2068167e217f88f18fb07932ade98e702c8` | `test/treasury/TreasuryConstructor.t.sol` | new |
| `ce200e43b5de0a0c567cb31eb9ec720facae1f0774829a58049893eab029ac6e` | `test/treasury/TreasuryFailureBehaviors.t.sol` | new |
| `ed89cae19f484947e635ad6f6f797a6df5bd17bb359f11ee96741fce6542e1b4` | `test/treasury/TreasuryFixture.sol` | new |
| `3ce8acb3d78026b046cb240de51a7be9e7d6128064abb66603cc602dea07bceb` | `test/treasury/TreasuryFlows.t.sol` | new |
| `d272e507a7c99e47a10cc2aa0cceee7c7b0cc11d1e65b8665af3705100ef0e50` | `test/treasury/TreasuryInvariantHandler.sol` | new |
| `a4a1206b986d1448ac21333f73ae1644389c88402b46b1abf081e73567413c35` | `test/treasury/TreasuryInvariants.t.sol` | new |
| `fbdc4f2c07e6d6624c9b5bd9a85013f98d5d4c346cd2f0551cf63b75efd652ec` | `test/treasury/TreasuryLsgBoundary.t.sol` | new |
| `093c09375e5d663c8cc2feef147f1fa27c03b9939d0eea130d9583bbb82f7765` | `test/treasury/TreasuryRevenue.t.sol` | new |
| `0d6e94fb3d3bfaf0da7055277a3fcc7ba7c3477012b61ab33ab7cf64469c7b44` | `test/treasury/TreasurySurface.t.sol` | new |
| `c2c238eaba1f55dfdecbdeab345ec91f1f521ab09754fb10ad2cb3fc27bec6bb` | `test/treasury/VuxPoolDeployer.t.sol` | new |

### The two modifications, and why each was necessary

- **`foundry.toml`** — two lines plus their rationale comments. `[profile.default] skip =
  ["src/v3core/**"]` keeps the `=0.8.28` unit off the `=0.7.6` file; `[profile.v3core] script =
  "src/v3core"` gives that file a compile root inside the VUX source tree; `[profile.v3core]
  skip = []` cancels the inherited skip. No bytecode-affecting setting changed in either unit —
  `POOL_INIT_CODE_HASH` is reproduced byte-identical. See `reviewer.md` "Judgment Calls" (J-1).
- **`test/mocks/MockWeth.sol`** — one `transferFrom` override, inert unless the pre-existing
  `transferFeeBp` probe is set, so no earlier suite changes behaviour. It exists because
  `returnFor` pulls with `transferFrom` and books what it **measured**, a distinction that only
  exists when the pull can under-deliver.

---

## B. Lifecycle evidence written by this node (not part of the subject)

| path | role |
|---|---|
| `grimoires/loa/a2a/sprint-4/reviewer.md` | implementation report + AC verification |
| `grimoires/loa/a2a/sprint-4/sprint-4-scope.md` | byte-exact Sprint-4 slice of `sprint.md` L292–L350, `afde57a6fb480f061191aacf6a1d8d679404d36ddf7bf5204bc96afa9497aef9` |
| `grimoires/loa/a2a/sprint-4/evidence/*.md` | this file, plus the PROV-5 statement, the fraud-vs-theft argument, the R-1…R-14 sweep, and the FB-6/9/10/12 notes |
| `grimoires/loa/a2a/index.md` | sprint index row |
| `grimoires/loa/NOTES.md` | session continuity + decision log |
| `.beads/issues.jsonl` | Task 4.1–4.9 lifecycle (`br`) |
| `grimoires/loa/a2a/trajectory/*.jsonl` | skill trajectory logs |

## C. Pre-existing State Zone material — untouched

Present in the working tree at node start and deliberately not staged, cleaned, reset, or
included in the subject: `.beads/.br_history/`, `.run/`, `grimoires/loa/analytics/`,
`grimoires/loa/skills-pending/`, `grimoires/loa/ledger.json.bak`,
`grimoires/loa/ledger.json.lock`, `grimoires/loa/a2a/m1-l3-l4-provenance-hardening/`, and the
pre-existing `grimoires/loa/a2a/trajectory/*.jsonl` files.

---

## Baseline and authority identity

| item | value | verified |
|---|---|---|
| branch | `sprint-4`, created from the landed baseline | at node start |
| baseline commit | `84abced4f90b9b8d11d960ebb438125b84914272` (`master == origin/master`) | at node start |
| commits made | **none** — the tree is left uncommitted for exact-tree review | at node end |
| `grimoires/loa/prd.md` | `791c52f2ad05c794188b218e877957889bc97b6399b965b9c5fe003ef0e2406e` | unchanged |
| `grimoires/loa/sdd.md` | `b7270458e1417171dd812f34039263eca45cd676f8009dbfaf202d90aac6b175` | unchanged |
| `grimoires/loa/sprint.md` | `bcaebd18f8cc5b35c28ee23745cf7b07945c82bd66df589e1eccaf0eabaa5557` | unchanged |
| OZ/v3 refreeze (md) | `27aa37ec82fffaea4deb63d5ccd87f66a7e71bad1afa9e7d95d814035e8e3203` | unchanged |
| OZ/v3 registry delta (json) | `db3144135251af34f6bef9da61300a2644c381c4763f2347753657de6afaf4f1` | unchanged |
| base source registry (json) | `6fc9fa81d80eda1f1017c6cb79f297b9a608150538e76ad97d8de1c8b5d2fe04` | unchanged |
| Foundry v1.5 refreeze (md/json) | `439bdef308a79d1df20e4e43e2c3ec138af5bcd77dce3113a1a31befac20830a` / `f83853492bd6894457813ef96dc23745cb1b52f04b684397623cacbc185224aa` | unchanged |
| `THIRD_PARTY_NOTICES.md` | `963e2cfb8fe8306ee6d2cfd6e14fa417a7a61fd7bfddc3fe5aedc2b577170873` | unchanged |
| `POOL_INIT_CODE_HASH` | `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` | reproduced |
| `vendor/` | 63-file census, byte-identical | drift gate green |
