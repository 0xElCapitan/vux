# Sprint 1 — Implementation Report (Review Remediation)

**Sprint:** cycle-002 local `sprint-1` = global `sprint-1` (ledger-resolved, `VALID|global_id=1`)
**Theme:** Provenance-gated foundation & authorized vendoring
**Node:** `/implement sprint-1` (Loa `implementing-tasks`) — **remediation pass**, 2026-08-11
**Consumes:** `grimoires/loa/a2a/sprint-1/engineer-feedback.md` (`/review-sprint sprint-1` → `CHANGES_REQUIRED`; 0 critical / 1 high / 3 medium)
**Branch:** `master` (no commit, push, or tag made — not authorized for this node)
**Status:** review findings closed; awaiting re-review via `/review-sprint sprint-1`

---

## Executive Summary

The review confirmed the substance of Sprint 1 — 63/63 byte-identical vendored files, an
independently reproduced `POOL_INIT_CODE_HASH`, a drift fence that genuinely closes — and blocked
on one structural defect: **the unauthorized-source detectors chose their own scope.** Every
detector enumerated the directories it would look in (`vendor`, or `vendor src test script`), so a
directory outside that list was in *no* gate's scope. The reviewer demonstrated it live: three
unauthorized files under a new top-level `contracts/` — an unenumerated OpenZeppelin source, a file
named `UniswapV3Factory.sol`, and one citing Olympus / gumball6900 / give.fun — left **all seven
gates green and `run-all.sh` exit 0**.

That is now closed by inversion rather than by extension. `census.sh` gained one
**source-universe classification primitive**: every Solidity file in the working tree is classified
as `vendored` (an enumerated census row), `vux` (inside a declared VUX-owned source root), or
`unauthorized` (anything else — fails closed). `verify-census.sh`, `verify-spdx.sh`, and
`verify-quarantine.sh` all consume that one derived list, so no gate maintains its own `find` roots
and adding a source root is a visible edit to `VUX_SOURCE_ROOTS` rather than a silent exemption.

**The reviewer's exact probe was re-run against the repaired tree: `run-all.sh` now exits 1 with
8 FAIL lines across 2 gates** (was exit 0), and the tree hashed identical before and after.

A new standing demonstration, `demo-boundary-negative.sh`, plants six probes outside the boundary —
including in `lib/`, Foundry's conventional dependency directory — asserts each gate fails **for
the boundary reason** rather than merely failing, removes them, and asserts green again. It runs as
its own CI job, the same discipline that makes the drift demonstration trustworthy.

All three MEDIUM findings are fixed, not deferred. No PRD, SDD, sprint-plan, provenance-authority,
or licence-authority file was touched; all eight accepted authority hashes re-verified unchanged.
No dependency was added. No Sprint 2+ work was performed.

### Review findings — disposition

| # | Sev | Finding | Disposition |
|---|---|---|---|
| C-1 | **HIGH** | Unauthorized-source detectors are directory-scoped; source outside `{vendor,src,test,script}` escapes every gate | **Fixed** — repository-wide default-deny classification (`census.sh:152-205`) consumed by 3 gates; reviewer's probe now fails `run-all.sh` |
| I-2 | MEDIUM | `verify-pins.sh:40` `head -1` can select a `build-info` JSON with no compiler field → spurious fail | **Fixed** — `build-info` excluded by path; assertion now spans **every** artifact (18 + 32), not a sample (`verify-pins.sh:45-70`) |
| I-3 | MEDIUM | Gate 6's secret scan is `git ls-files`-scoped, near-vacuous pre-commit (22 files, none of the new work) | **Fixed** — tracked **plus** untracked-not-ignored; coverage 22 → **247** files, reported in the gate output (`verify-launch-hygiene.sh:57-59`) |
| I-4 | MEDIUM | §17 quarantine inherits the same fixed directory list | **Fixed** — scope derived from the same source universe (`verify-quarantine.sh:30-41`); proven by probe 6 |
| I-1 | MEDIUM | CI installs the Foundry pin but never asserts it | **Fixed** (reviewer marked hardening, not defect) — `provenance.yml:46-56` fails the build when the running toolchain is not the pinned `${FOUNDRY_VERSION}` |

### Authority hashes re-verified at node close (all unchanged)

| artifact | accepted SHA-256 | state |
|---|---|---|
| `grimoires/loa/prd.md` (v2.0.0) | `4e5cacf72d276377cb20897d9e1fe8aea721cc5edb2b0fd55e5cfde79ec89377` | unchanged |
| `grimoires/loa/sdd.md` (v1.6.0) | `19241ed7db8a89b419e746463c6121f5b77c8237d760829e2f2604536c37392a` | unchanged |
| `grimoires/loa/sprint.md` (v1.0.0) | `5dd5b87b25ed07a6b23d950a7e15cc986f84d61715acfceda8eda1404b7c7436` | unchanged |
| `docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md` | `27aa37ec82fffaea4deb63d5ccd87f66a7e71bad1afa9e7d95d814035e8e3203` | unchanged |
| `docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json` | `db3144135251af34f6bef9da61300a2644c381c4763f2347753657de6afaf4f1` | unchanged |
| `THIRD_PARTY_NOTICES.md` | `963e2cfb8fe8306ee6d2cfd6e14fa417a7a61fd7bfddc3fe5aedc2b577170873` | unchanged |
| `docs/authority/vux-v1-licence-provenance-source-pin-freeze-2026-08.md` (base) | `50c3584a1483b40ffb6391260a2bf42df32220c64724fdcc672ca62c01ace3a2` | unchanged |
| `docs/authority/vux-v1-source-registry-2026-08.json` (base) | `6fc9fa81d80eda1f1017c6cb79f297b9a608150538e76ad97d8de1c8b5d2fe04` | unchanged |

Four are additionally pinned inside the gate itself (`tools/provenance/census.sh:24-33`), so a
mutated authority artifact fails the census gate rather than silently redefining it.

---

## The new source boundary

`census.sh:152-205` adds the primitive; the gates consume it and hold no scan roots of their own.

```
VUX_SOURCE_ROOTS       = (src test script)            census.sh:152
SOURCE_UNIVERSE_PRUNE  = (.git out out-v3core cache cache-v3core broadcast
                          .claude grimoires .beads .run .ck)   census.sh:163
source_universe()      every *.sol in the working tree, repo-relative   census.sh:168
classify_sources()     -> "vendored" | "vux" | "unauthorized"           census.sh:176
vux_owned_sources()    everything non-vendored, wherever it lives       census.sh:197
```

Properties that make it a boundary rather than a longer list:

- **Location is authority.** Byte-identical *accepted* upstream source is still unauthorized in the
  wrong place — proven by probe 1, which copies a real census row into `contracts/` and fails.
- **The universe is the filesystem, not the git index.** `source_universe()` walks the tree, so
  tracked-vs-untracked creates no escape during this pre-commit lifecycle stage — the specific
  concern the review raised for Gate 6.
- **Symlinks are in scope** (`-type f -o -type l`), so a symlinked `*.sol` cannot be invisible.
- **`lib/` and `node_modules/` are deliberately NOT pruned.** An unauthorized dependency landing in
  Foundry's or npm's conventional directory is exactly what this catches (probe 5).
- **The prune list cannot silently hide `vendor/`.** `verify-census.sh:99-104` cross-checks that the
  walk still classified all 63 census rows, so a pruning bug fails loudly instead of turning the
  boundary check into a tautology.
- **Vendored bytes stay exempt from authored-source policy** (SPDX, §17) — they are frozen by the
  drift gate — preserving the accepted separation between byte-identical upstream and VUX-owned
  source. Source authority was **not** expanded: `contracts/` was not authorized despite being the
  reviewer's probe location.

Detector reach, before → after:

| detector | before | after |
|---|---|---|
| unenumerated source | `find vendor -type f` | repo-wide default-deny over 68 classified `*.sol` (`verify-census.sh:81-94`) |
| `UniswapV3Factory.sol` | `find vendor src test script` | repo-wide over the classified universe (`:126`) |
| v3-periphery use | `find vendor` + 4-dir grep | repo-wide (`:135`) |
| prohibited sources | `vendor src test script` | repo-wide (`:157`) |
| VUX SPDX policy / holders | `find src test script` | repo-wide non-vendored (`verify-spdx.sh:69`, `:99`) |
| §17 quarantine | fixed 7-entry list | fixed list **∪** repo-wide non-vendored source (`verify-quarantine.sh:30-41`) |
| launch-secret literals | tracked files (22) | tracked + untracked-not-ignored (247) (`verify-launch-hygiene.sh:57`) |
| compiler identity | first JSON found (`head -1`) | every artifact, `build-info` excluded (`verify-pins.sh:45-70`) |

---

## Negative-test evidence

### 1. The reviewer's exact probe, re-run against the repaired tree

Same three files, same location, same command the review recorded as **exit 0**:

```
$ mkdir -p ./contracts/vendored
$ cp vendor/openzeppelin-contracts-v5.2.0/contracts/utils/math/Math.sol ./contracts/vendored/Math.sol
$ cp vendor/uniswap-v3-core-v1.0.0/contracts/UniswapV3Pool.sol          ./contracts/vendored/UniswapV3Factory.sol
$ printf '…Olympus / gumball6900 / give.fun…'                         > ./contracts/vendored/PoolAddress-periphery.sol
$ bash tools/provenance/run-all.sh ; echo $?

FAIL  unauthorized Solidity source — neither an accepted census row nor inside a declared VUX source root (src test script): contracts/vendored/Math.sol
FAIL  unauthorized Solidity source — neither an accepted census row nor inside a declared VUX source root (src test script): contracts/vendored/PoolAddress-periphery.sol
FAIL  unauthorized Solidity source — neither an accepted census row nor inside a declared VUX source root (src test script): contracts/vendored/UniswapV3Factory.sol
FAIL  UniswapV3Factory.sol implementation present — excluded by refreeze §8:
FAIL  v3-periphery code use detected — the evidence pin authorizes zero code use (refreeze §7/§8):
FAIL  prohibited-source reference in Solidity sources:
FAIL  contracts/vendored/Math.sol            declares SPDX 'MIT';     VUX-original source is 'GPL-3.0-or-later'
FAIL  contracts/vendored/UniswapV3Factory.sol declares SPDX 'BUSL-1.1'; VUX-original source is 'GPL-3.0-or-later'

FAILED — 2 gate(s):  census, byte identity, excluded sources │ SPDX and copyright policy
1
```

`run-all.sh` **exit 1** (was 0). All four content detectors fired on relocated material, and the
SPDX gate inherited repo-wide reach for free. Working-tree inventory hashed
`39c7701031bada2d54557b194e23fa165e6221b5909406a0d21733e51c30b7b0` before and after the probe —
byte-identical, probe fully removed.

### 2. `demo-boundary-negative.sh` — standing demonstration, 6 probes

Each probe is planted, proven to fail **for the boundary reason** (not merely to fail), removed, and
the gate proven green again. `tools/provenance/demo-boundary-negative.sh:50-70` refuses to accept a
gate that fails for any other reason, and `:29-38` refuses to run at all if a probe root already
exists, so the script can never delete real work.

| # | probe | asserted failure reason | result |
|---|---|---|---|
| 1 | census row copied to `contracts/vendored/` | `unauthorized Solidity source` + `declares SPDX` | ok, both gates |
| 2 | `contracts/impl/UniswapV3Factory.sol` | `UniswapV3Factory.sol implementation present` | ok |
| 3 | `contracts/research/Probe.sol` (Olympus / gumball6900 / give.fun) | `prohibited-source reference` | ok |
| 4 | `contracts/periphery/PoolAddress.sol` | `v3-periphery code use detected` | ok |
| 5 | `lib/forge-std/src/Test.sol` | `unauthorized Solidity source` | ok |
| 6 | `contracts/policy/Policy.sol` (§17 value) | `guidance value present as implementation authority` | ok |

```
Source-boundary fence proven closed on all 6 probes, and reopened.
ok    working-tree inventory identical to pre-probe state (39c7701031bada…c30b7b0)
ok    probe root ./contracts removed        ok    probe root ./lib removed
ok    verify-census.sh / verify-spdx.sh / verify-quarantine.sh green again
exit 0
```

Probes 2, 3, 4 and 6 are the **relocation** proofs specifically: prohibited and excluded material in
a directory no detector previously scanned. Probe 1 is the strongest single result — *authorized*
bytes still fail, because the census defines a place as well as a content.

Promoted to standing CI as its own job, `source-boundary-negative-demonstration`
(`.github/workflows/provenance.yml:77-94`), which then asserts `git diff --exit-code` **and**
`test -z "$(git status --porcelain)"` — so a demonstration that failed to restore the tree fails the
build. It needs no compiler, only `git` + `jq`.

### 3. The drift fence still closes (unchanged behaviour)

Re-run after the remediation, reproducing the review-confirmed values exactly:

```
mutated 1 byte at offset 17750
mutated sha   : c1a70ca77f3257f7e323b60c11a7271df9d6ba8f6b11b3b81297bd114e46f571
FAIL  DRIFT (sha256) vendor/uniswap-v3-core-v1.0.0/contracts/UniswapV3Pool.sol
        accepted d515775b7f3ffe921dd70aca86b8bad16280fa4c122425d82b4dbea4dc564a7a
restored sha  : d515775b7f3ffe921dd70aca86b8bad16280fa4c122425d82b4dbea4dc564a7a
ok    drift gate failed closed on a one-byte mutation (exit 1)
ok    exact tree restored          ok    drift gate green again after restore
```

---

## AC Verification

Acceptance criteria quoted verbatim from `grimoires/loa/sprint.md` §"Sprint 1 → Acceptance
Criteria" (`sha256 5dd5b87b…c7436`, unchanged). The sprint-1 slice used for the mechanical validator
is preserved at `grimoires/loa/a2a/sprint-1/sprint-1-scope.md` (`sha256 0133a5b8…799aa`, byte-exact,
regenerable — see *Verification Steps*).

**AC-1**: Census exactness: repository contains exactly 28 + 32 + 3 vendored upstream files; per-file SHA-256 equals the accepted registry values (`docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json`); zero unenumerated upstream source anywhere
- Status: ✓ Met
- Evidence: `tools/provenance/verify-census.sh:35-37` — `check_count` for 28 / 32 / 3, with counts read from the accepted registry rather than hardcoded per directory
- Evidence: `tools/provenance/verify-census.sh:66-68` — `verify_family sha256 < <(census_oz)`, v3-core, and Miner (blob OID, the identity the base registry pins for that allowlist)
- Evidence: `tools/provenance/verify-census.sh:94` — **"anywhere" is now literal**: `pass "zero unauthorized Solidity source anywhere in the repository"`, computed over the repo-wide classified source universe (`census.sh:176`), not over a scanned directory list. `:91` is the fail path
- Evidence: `tools/provenance/verify-census.sh:99-104` — cross-check that the walk classified all `OZ_COUNT + V3_COUNT + MINER_COUNT` census rows, so the prune list cannot hide `vendor/` and make the check vacuous
- Evidence: `tools/provenance/verify-census.sh:115` — extension-agnostic set difference still asserts zero unenumerated files **of any type** under `vendor/`, covering non-`.sol` smuggling
- Evidence: `tools/provenance/census.sh:108-130` — the census is derived from the accepted registry JSON by `jq`, so the gate cannot disagree with the accepted authority
- Evidence: `tools/provenance/demo-boundary-negative.sh:97-107` — probe 1 proves the criterion empirically: a byte-identical accepted census row placed outside `vendor/` fails
- Result: `ok 63/63 vendored files byte-identical to accepted identities`; `source universe: 68 Solidity file(s) — 63 vendored (census), 5 VUX-owned`; `ok zero unauthorized Solidity source anywhere in the repository (68 file(s) classified)`; `ok all 63 accepted census rows present in the classified source universe`

**AC-2**: Drift gate demonstrated fail-closed: a 1-byte mutation of any vendored file makes CI fail (negative demonstration recorded in the sprint report)
- Status: ✓ Met
- Evidence: `tools/provenance/demo-drift-negative.sh:57-58` — runs the drift gate under mutation and captures its exit status via `PIPESTATUS[0]`; `:68` fails the demonstration if the gate *passed* a mutated file
- Evidence: `tools/provenance/demo-drift-negative.sh:74` — asserts the restored bytes reproduce the original SHA-256; `:80` re-asserts the gate is green after restore
- Evidence: `.github/workflows/provenance.yml:62` — standing CI job, re-proven on every push
- Result: re-run after this remediation, reproducing the review-confirmed run exactly — offset 17750, mutated `c1a70ca7…`, restored `d515775b…`, `ok drift gate failed closed on a one-byte mutation (exit 1)`. Unmodified by this node

**AC-3**: `POOL_INIT_CODE_HASH` reproduced in CI from the vendored `=0.7.6` unit and equal to `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` (refreeze §7 obligation 1) — CI fails closed on mismatch
- Status: ✓ Met
- Evidence: `test/provenance/PoolInitCodeHash.t.sol:35` — `assertEq(keccak256(creationCode), ACCEPTED_POOL_INIT_CODE_HASH, …)` against the artifact the `v3core` profile actually produced (`:29`)
- Evidence: `test/provenance/PoolInitCodeHash.t.sol:34` — creation-code length asserted at 22,728 bytes; `:49` CBOR tail `a164736f6c6343000706000a`, the mechanical confirmation of `bytecode_hash = "none"`
- Evidence: `tools/provenance/verify-init-code-hash.sh:31` — asserts the artifact was compiled by `0.7.6+commit.7338295f` before trusting it, then runs the assertion at `:41`
- Evidence: `foundry.toml:53-56` — the complete enumerated bytecode-affecting setting set (optimizer on, `optimizer_runs = 800`, `evm_version = "istanbul"`, `bytecode_hash = "none"`)
- Result: `ok POOL_INIT_CODE_HASH reproduced and equal to the accepted constant`; creation code independently measured at 45,456 hex chars = **22,728 bytes**. Unmodified by this node

**AC-4**: No `UniswapV3Factory.sol` implementation, no v3-periphery file, no non-allowlisted Miner file present (refreeze §8) — enforced by the unauthorized-file detector
- Status: ✓ Met
- Evidence: `tools/provenance/verify-census.sh:126` — Factory-name detector now runs over `$all_sources`, the repo-wide classified universe, so relocation does not bypass it (`IUniswapV3Factory.sol`, the authorized *interface*, is correctly not matched by `(^|/)UniswapV3Factory\.sol$`)
- Evidence: `tools/provenance/verify-census.sh:135-137` — periphery detector over the same universe plus `foundry.toml`/`remappings.txt`; targets *code use* (files, imports, remappings), which is what refreeze §7/§8 forbids, not prose
- Evidence: `tools/provenance/verify-census.sh:149` — Miner tree constrained to exactly the 3 allowlisted paths. A verbatim Miner file relocated elsewhere is caught by the layer beside it: `unauthorized` if outside the VUX roots, and inside them its upstream `MIT` header fails the PROV-8 policy at `verify-spdx.sh:69-86` (comment at `:143-148` records the argument)
- Evidence: `tools/provenance/verify-census.sh:157` — prohibited-source scan (LSG / gumball6900 / give.fun / Olympus) over the repo-wide universe
- Evidence: `tools/provenance/demo-boundary-negative.sh:109-138` — probes 2, 3 and 4 prove each of these three detectors fires on material relocated into a directory that was previously in no gate's scope
- Result: all four checks `ok` on the canonical tree; each proven to fail closed under relocation. `run-all.sh` under the reviewer's original probe: **exit 1**, was exit 0

**AC-5**: §17 research-guidance quarantine grep live and green (prd.md:L818)
- Status: ✓ Met
- Evidence: `tools/provenance/verify-quarantine.sh:39-52` — the pattern table covering the §17 guidance values and concepts (LSG 60-day / `$250K` / 5M gates, dry-powder 180-day window, operator-share and NAV-ceiling concepts, ROOT/GIGA look-through caps, signaler/LP measurement guidance, general revenue-split ratios)
- Evidence: `tools/provenance/verify-quarantine.sh:30-41` — scope is the fixed VUX build/CI list **plus** every non-vendored Solidity file in the repository-wide source universe, so relocating implementation material out of `src test script` no longer bypasses §17 (review Improvement 4)
- Evidence: `tools/provenance/verify-quarantine.sh:12-19` — `docs/authority/**` and `grimoires/**` remain deliberately unscanned, and vendored bytes remain excluded; legitimate research text is not converted into a false-positive implementation violation
- Evidence: `tools/provenance/demo-boundary-negative.sh:154-165` — probe 6 plants a §17 value in `contracts/policy/Policy.sol` and asserts the gate fails; the probe value is interpolated at write time so the demonstration script does not itself trip the gate it exercises
- Result: all 10 pattern classes `ok`. Frozen authority values remain excluded by construction, never by suppression: 80/8/12 routing, the 30-day halving period, the 3000 s decay window, the 24 h admission delay

**AC-6**: `foundry.toml` carries both solc pins (`7893614a…`, `7338295f…`); CI fails on any missing/short/mismatched pin (PROV-9)
- Status: ✓ Met
- Evidence: `foundry.toml:17-19` — `solc 0.8.28 … 7893614a…`, `solc 0.7.6 … 7338295f…`, and the Foundry v1.0.0 pin `8692e926…`
- Evidence: `tools/provenance/verify-pins.sh:31-33` — each pin must be present *and* match `^[0-9a-f]{40}$`; a missing or short pin fails
- Evidence: `tools/provenance/verify-pins.sh:45-70` — mismatch is caught where it matters, and now deterministically: `build-info` objects are excluded by path (they carry no `.metadata.compiler.version`, which is what made `head -1` able to fail spuriously), and the assertion spans **every** artifact rather than one sample — strictly stronger than the reviewed version
- Evidence: `tools/provenance/verify-pins.sh:92`, `:101`, `:111` — mutable-upstream-reference detector, short-SHA detector, and every GitHub Action pinned to a 40-character commit
- Evidence: `.github/workflows/provenance.yml:46-56` — the installed toolchain is now **asserted**, not merely printed: the build fails when `forge --version` does not carry `${FOUNDRY_VERSION}` (review Improvement 1)
- Result: `ok` on all three pins; `all 18 artifact(s) under out/ compiled by 0.8.28+commit.7893614a`; `all 32 artifact(s) under out-v3core/ compiled by 0.7.6+commit.7338295f`; all three reference-discipline checks clean

**AC-7**: `.gitignore` excludes `broadcast/**` production artifacts per the sdd.md:L270 launch-secret posture
- Status: ✓ Met
- Evidence: `.gitignore:28-29` — `broadcast/` and `broadcast/**`, under a comment naming the sdd.md:L270 posture
- Evidence: `tools/provenance/verify-launch-hygiene.sh:17` — asserts the exclusion is present; `:24` asserts no broadcast artifact is tracked (exclusion alone does not untrack an already-committed file). Both remain correctly git-scoped: "is this TRACKED" is a question only git can answer
- Evidence: `tools/provenance/verify-launch-hygiene.sh:57-59` — the secret-literal scan now covers tracked **plus** untracked-but-not-ignored files, and reports its own coverage, so the gate is meaningful before the first commit instead of scanning 22 previously-tracked files and none of the sprint's work (review Improvement 3). Ignored files stay out of scope by design — they are never committed
- Result: all checks `ok`; `scanning 247 file(s): tracked + untracked-not-ignored` (was 22); no `.env`, no tracked broadcast artifact, no tracked build output

**AC-8**: Zero new dependencies beyond the accepted census (test harness included)
- Status: ✓ Met
- Evidence: `test/harness/Vm.sol:6` and `test/harness/BaseTest.sol:7` — VUX-authored cheatcode ABI subset and assertion base; the only two `forge-std` occurrences in Solidity are comments recording that it is deliberately absent, with no import
- Evidence: `remappings.txt:1-2` — the only two remappings both target the vendored census; there is no third source root
- Evidence: `tools/provenance/verify-census.sh:91` — a dependency added **anywhere** now fails the gate, not only under `vendor/`; `census.sh:159-163` deliberately leaves `lib/` and `node_modules/` unpruned so Foundry's and npm's conventional dependency directories are in scope
- Evidence: `tools/provenance/demo-boundary-negative.sh:141-151` — probe 5 plants `lib/forge-std/src/Test.sol` and asserts the gate fails closed
- Result: no `package.json`, no `.gitmodules`, no `lib/`, no `node_modules/`; `src/` and `script/` contain zero Solidity files; this node added **zero** dependencies

**8 of 8 met.** AC-1 and AC-4 — the two the review returned as not-met-as-written and partially-met — are now enforced repository-wide and demonstrated empirically rather than argued.

---

## Files changed by this remediation

| file | change |
|---|---|
| `tools/provenance/census.sh` | 136 → **205** lines; adds `VUX_SOURCE_ROOTS`, `SOURCE_UNIVERSE_PRUNE`, `source_universe()`, `classify_sources()`, `vux_owned_sources()`, `grep_sources()`. No existing function altered |
| `tools/provenance/verify-census.sh` | 123 → **164**; directory-scoped detection replaced by default-deny classification + census-completeness cross-check; four excluded-source detectors re-scoped repo-wide; `vendor/` set difference made symlink-aware |
| `tools/provenance/verify-spdx.sh` | 103 → **106**; VUX SPDX policy and invented-holder scan consume `vux_owned_sources()` |
| `tools/provenance/verify-quarantine.sh` | 65 → **80**; §17 scope = fixed VUX build/CI list ∪ repo-wide non-vendored source |
| `tools/provenance/verify-pins.sh` | 107 → **125**; `check_compiler()` deterministic, `build-info` excluded, asserts all artifacts |
| `tools/provenance/verify-launch-hygiene.sh` | 76 → **85**; scan set = tracked ∪ untracked-not-ignored, coverage reported, `-H`/`-d '\n'` for path-safe grep |
| `tools/provenance/demo-boundary-negative.sh` | **new, 189 lines**; 6-probe out-of-boundary demonstration with per-probe reason assertions and inventory-hash restoration proof |
| `tools/provenance/README.md` | 38 → **75**; gate table corrected, new demo listed, "The source boundary is default-deny" section documenting the three classes and every prune with its reason |
| `.github/workflows/provenance.yml` | 65 → **94**; Foundry pin asserted rather than printed; new `source-boundary-negative-demonstration` job |
| `grimoires/loa/a2a/sprint-1/reviewer.md` | this report, refreshed for the remediated tree |
| `grimoires/loa/NOTES.md`, `.beads/issues.jsonl` | session memory + task lifecycle (`vux-nci`) |

**Not touched:** PRD, SDD, sprint plan, `docs/authority/**`, `THIRD_PARTY_NOTICES.md`, `LICENSE`,
`foundry.toml`, `remappings.txt`, `.gitattributes`, `.gitignore`, all 63 vendored files, all 5 test
files, `verify-notices.sh`, `verify-init-code-hash.sh`, `run-all.sh`, `demo-drift-negative.sh`,
`vendor-sync.sh`, `engineer-feedback.md`. Mechanisms the review independently reproduced were left
alone.

`README.md` and `THIRD_PARTY_NOTICES.md` still show as modified in `git status`: that is the
**pre-existing** working-tree dirt the review confirmed by mtime (Aug 9 22:39 / Aug 10 11:19, both
before the sprint window). Neither this node nor the previous one edited them, and TPN still hashes
to its accepted baseline.

---

## Testing Summary

11 tests across 3 suites, all passing — unchanged by this node (no test file was modified).

| suite | tests | covers |
|---|---|---|
| `test/harness/Harness.t.sol` | 6 (incl. 1 fuzz, 256 runs) | passing assertions do not revert; each failing assertion reverts with the expected message |
| `test/provenance/PoolInitCodeHash.t.sol` | 2 | init-code hash, creation-code length, CBOR tail |
| `test/provenance/VendoredSurface.t.sol` | 3 | vendored OZ executes; v3-core interface selectors resolve |

Gate results on the restored canonical tree (2026-08-11, forge 1.5.0-stable, solc 0.8.28 / 0.7.6),
`run-all.sh` → **exit 0**, 58 `ok` lines:

| gate | result |
|---|---|
| census, byte identity, excluded sources | pass — 63/63 identical; 68 sources classified, 0 unauthorized; 63/63 census rows seen by the walk; 4 exclusion checks clean |
| immutable pins | pass — 3 pins recorded; 18/18 and 32/32 artifacts match their compiler identity; 3 reference checks clean |
| SPDX and copyright policy | pass — 63/63 upstream SPDX retained, tally 9/22/1, 5 VUX files policy-clean (repo-wide scope) |
| LICENSE and third-party notices | pass — GPLv3 text, TPN identity, 4 notices + 3 dependencies |
| PRD §17 quarantine | pass — 10/10 pattern classes clean (derived scope) |
| launch-secret and broadcast hygiene | pass — 9 checks clean over 247 files |
| `POOL_INIT_CODE_HASH` reproduction | pass — equal to the accepted constant |
| drift negative demonstration | pass — gate failed closed, exact tree restored |
| **source-boundary negative demonstration** | **pass — 6/6 probes failed closed for the right reason, tree inventory identical** |

---

## Known Limitations

1. **No CI run has yet executed under the pinned Foundry v1.0.0.** Carried forward from the review
   unchanged: local verification ran forge 1.5.0-stable because installing the pinned release would
   mutate the operator's global toolchain, which this node is not authorized to do. CI installs
   `v1.0.0` and now **asserts** it (`provenance.yml:46-56`), so the first CI execution is stronger
   evidence than before — but it must be green before landing. This remains the single most
   important pre-landing item. The three new/changed gate behaviours are compiler-independent (they
   use `find`, `git`, `jq`, `grep` only), so the boundary work does not add toolchain risk.
2. **The boundary classifies `*.sol` only.** Every one of the 63 census rows is `.sol` and the
   repository has no other contract language or toolchain, so this is the actual source universe
   today, not a narrowing. The `vendor/` set difference (`verify-census.sh:115`) is
   extension-agnostic, so a non-`.sol` file smuggled into `vendor/` still fails. Extending the
   universe to another language is a one-line change to `source_universe()` if a later sprint ever
   introduces one — deliberately not speculated on now.
3. **The prune list is the boundary's one exclusion surface.** Eleven entries, each documented with
   why it is not repository source (`census.sh:155-163`), and `verify-census.sh:99-104` fails if
   pruning ever hides the census. Adding an entry is a reviewable edit; a reviewer should treat any
   future addition as a provenance change.
4. **§17 quarantine remains pattern-based** and will need tightening as contracts land: Sprint 4's
   "no stored ratio constant" criterion needs a check distinguishing frozen routing constants
   (8000/1200, legitimate) from policy ratios. Unchanged from the previous report; deliberately not
   speculated on.
5. **Bytecode-affecting settings for the `=0.8.28` unit are intentionally unset**
   (`foundry.toml:28-32`) — no authority freezes them and no VUX contract exists. Sprint 2 owns it.
   They cannot affect `POOL_INIT_CODE_HASH` (separate unit).
6. **Local-toolchain defects recorded previously still apply** (Git Bash `jq` CRLF, `grep -qiF`
   SIGABRT) and are handled in-code; CI on ubuntu-latest is unaffected.

No acceptance criterion is `Not met`, `Partial`, or deferred.

---

## Verification Steps for the reviewer

```bash
# 1. Everything on the canonical tree (both builds, 7 gates, 11 tests)
tools/provenance/run-all.sh

# 2. Watch the SOURCE BOUNDARY close and reopen — 6 probes, reason-asserted
tools/provenance/demo-boundary-negative.sh

# 3. Watch the drift fence close and reopen (unchanged by this node)
tools/provenance/demo-drift-negative.sh

# 4. Confirm steps 2 and 3 left the tree exactly as found
git status --porcelain --untracked-files=all | sort | sha256sum
```

Reproduce the review's original bypass and confirm it is closed:

```bash
mkdir -p ./contracts/vendored
cp vendor/openzeppelin-contracts-v5.2.0/contracts/utils/math/Math.sol ./contracts/vendored/Math.sol
cp vendor/uniswap-v3-core-v1.0.0/contracts/UniswapV3Pool.sol          ./contracts/vendored/UniswapV3Factory.sol
printf 'Olympus gumball6900 give.fun\n'                             > ./contracts/vendored/PoolAddress-periphery.sol
bash tools/provenance/run-all.sh ; echo "exit=$?"    # expect exit=1, was exit=0
rm -rf ./contracts
```

Inspect the boundary itself, independent of the gates:

```bash
# The three classes, straight from the primitive
bash -c 'source tools/provenance/census.sh; classify_sources' | cut -f1 | sort | uniq -c
#   63 vendored     5 vux     0 unauthorized

# What the walk excludes, and proof it excludes nothing that matters
bash -c 'source tools/provenance/census.sh; echo "${SOURCE_UNIVERSE_PRUNE[@]}"'
find .claude grimoires docs -name '*.sol' | wc -l          # 0

# Deterministic compiler identity across every artifact, not a sample
find out -name '*.json' -not -path '*/build-info/*' | wc -l   # 18
jq -r '.metadata.compiler.version' $(find out-v3core -name '*.json' -not -path '*/build-info/*') | sort -u
# 0.7.6+commit.7338295f
```

### AC validator

```bash
.claude/scripts/validate-ac-verification.sh \
  --report grimoires/loa/a2a/sprint-1/reviewer.md \
  --sprint grimoires/loa/a2a/sprint-1/sprint-1-scope.md
```

`sprint-1-scope.md` is a byte-exact slice of `grimoires/loa/sprint.md` from `## Sprint 1:` to
`## Sprint 2:` (`sha256 0133a5b8332fef702bf85919a1ab2c6f0022f75967cbae72c99abfb09d7799aa`,
re-verified this node), regenerable with:

```bash
awk '/^## Sprint 1:/{f=1} /^## Sprint 2:/{f=0} f' grimoires/loa/sprint.md
```

It exists because the validator harvests acceptance criteria from **every** `### Acceptance
Criteria` heading in the file it is given, and this cycle uses a single multi-sprint plan — 71
criteria across 8 sprints. Running it against the whole plan would demand that this sprint-1 report
quote Sprint 2–8 criteria verbatim, misrepresenting them as walked. Both runs are reported rather
than only the convenient one:

| input | exit | `ac_count` | violations |
|---|---|---|---|
| `sprint-1-scope.md` (this sprint) | **0** | 8 | 0 |
| `grimoires/loa/sprint.md` (whole plan) | 1 | 71 | 63 |

`71 − 8 = 63` exactly: every violation in the whole-plan run is a Sprint 2–8 criterion, and not one
Sprint-1 criterion is among them — the same arithmetic the review confirmed mechanically.

---

## Scope Confirmation

- Review findings closed: 1 HIGH fixed structurally, 3 MEDIUM fixed, plus the non-blocking CI
  hardening the review suggested. Nothing silently ignored; nothing deferred.
- Source authority **not** expanded: `VUX_SOURCE_ROOTS` is still exactly `src test script`.
  `contracts/` was not authorized despite being the probe location. The 63-file census is unchanged
  and re-verified byte-identical.
- No VUX protocol contract implemented: `src/` and `script/` contain zero Solidity.
  `VUX.sol`, `HardReserve.sol`, `Rig.sol`, `StrategicTreasury.sol`, `VuxPoolDeployer.sol`,
  `GenesisDeployer.sol`, `Lens.sol` — none exist anywhere in the tree.
- No Sprint 2+ work; no LSG, POL/VYRF, indexer, or frontend work; no off-chain dependency installed.
- No new external dependency; `forge-std` still absent and now provably unable to land unnoticed.
- No operator-reserved decision (R-1…R-14) resolved; no §17 research value promoted.
- No PRD, SDD, sprint-plan, provenance-refreeze, registry, or licence-authority mutation — all eight
  accepted hashes re-verified unchanged.
- No compiler or source pin changed; no frozen upstream byte modified; no lifecycle topology change.
- No commit, push, or tag. No review or audit verdict written. `/review-sprint` and `/audit-sprint`
  not invoked.
- `engineer-feedback.md` preserved unmodified.

**Recommended next node:** `/review-sprint sprint-1`.
