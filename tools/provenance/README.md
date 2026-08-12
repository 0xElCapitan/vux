# Provenance gates

Fail-closed enforcement of the operator-accepted source and licence authority.
Every gate reads its facts from `docs/authority/` — no fact is restated here, so
the gates cannot drift from the accepted registry.

```bash
tools/provenance/run-all.sh
```

Runs both builds, all seven gates, and the test suite. Non-zero exit on any
violation; every gate runs to completion so one failure does not hide another.
This is exactly what `.github/workflows/provenance.yml` runs.

| script | enforces |
|---|---|
| `verify-census.sh` | accepted-authority integrity; exact 28 + 32 + 3 census; per-file byte identity (the drift gate); **zero unauthorized Solidity source anywhere in the repository** (default-deny); zero unenumerated files of any type under `vendor/`; excluded surfaces absent repository-wide (refreeze §8) |
| `verify-pins.sh` | both solc pins recorded at full 40 characters *and* self-reported by the compilers that actually ran; the toolchain refreeze authority byte-identical; the Foundry pin recorded *and* self-reported by the `forge` that is actually running (fail-closed — ambient `PATH` version is not evidence); no mutable upstream reference; no short SHA; every GitHub Action pinned by commit |
| `verify-spdx.sh` | upstream SPDX retained verbatim on all 63 vendored files; v3-core licence tally 9/22/1; VUX-owned SPDX policy (PROV-8); no invented copyright holder |
| `verify-notices.sh` | `LICENSE` is GPLv3; `THIRD_PARTY_NOTICES.md` matches its accepted baseline hash and carries the required upstream notices |
| `verify-quarantine.sh` | PRD §17 research-guidance values never appear as implementation authority |
| `verify-launch-hygiene.sh` | `broadcast/**` excluded and untracked; no `.env`, key, mnemonic, or salt literal in tracked files (sdd.md:L270) |
| `verify-init-code-hash.sh` | the vendored `=0.7.6` unit reproduces the accepted `POOL_INIT_CODE_HASH` (refreeze §7 obligation 1) |
| `demo-drift-negative.sh` | proves the drift gate closes: mutates one byte, asserts failure, restores the exact bytes, asserts green again |
| `demo-boundary-negative.sh` | proves the source boundary closes: plants 6 probes outside the census and the declared VUX roots (`contracts/`, `lib/`), asserts each gate fails *for the boundary reason*, removes them, asserts green again |
| `vendor-sync.sh` | re-vendors the census from the pinned upstream commits, refusing to write anything whose upstream identity does not match |

`census.sh` is the shared library: accepted pins, accepted artifact hashes, and
the registry-derived file lists.

## The source boundary is default-deny

`census.sh` classifies **every** Solidity file in the working tree into exactly
one of three classes, and the gates consume that one list rather than each
maintaining its own `find` roots:

| class | meaning |
|---|---|
| `vendored` | a path enumerated by the accepted registry — the 63-file census |
| `vux` | inside a declared VUX-owned source root (`VUX_SOURCE_ROOTS`: `src test script`) |
| `unauthorized` | anything else — fails closed |

Consequences worth knowing before adding source:

- **Location is authority.** Byte-identical accepted upstream source is still
  unauthorized in the wrong place; `vendor/` is the only home for the census.
- **Declaring a new source root is a visible edit** to `VUX_SOURCE_ROOTS`, not a
  silent exemption — which is the point. Sprint 4's VUX-owned derivative source
  lives in `src/`, already declared.
- **The universe is the filesystem, not the index.** Uncommitted and gitignored
  files are in scope, so nothing escapes by being untracked.
- **`lib/` and `node_modules/` are deliberately in scope.** An unauthorized
  dependency landing in Foundry's or npm's conventional directory is exactly
  what this boundary exists to catch (AC-8).
- **Pruned as not-repository-source:** `.git`, Foundry build output (`out`,
  `out-v3core`, `cache`, `cache-v3core` — note its artifact layout creates
  *directories* named `*.sol`), `broadcast/`, and the Loa zones (`.claude`,
  `grimoires`, `.beads`, `.run`, `.ck`). `verify-census.sh` cross-checks that the
  walk still sees all 63 census rows, so a pruning bug cannot quietly turn the
  boundary check into a tautology.

`verify-spdx.sh` (PROV-8 policy, invented-holder scan) and `verify-quarantine.sh`
(§17) consume the same derived list, so a new source root cannot opt out of them
either. Vendored bytes stay excluded from both — they are frozen by the drift
gate, and authored-source policy does not apply to byte-identical upstream.

## Rules a script cannot express

- **Vendored files are never edited.** A required change to upstream behaviour
  is VUX-owned source in a separate file, never a patch to `vendor/`.
- **A red gate is never fixed by editing the accepted constant.** Refreeze §7
  obligation 3: a compiler or bytecode-affecting settings change invalidates
  `POOL_INIT_CODE_HASH` and requires a new operator-accepted refreeze.
- **Adding any source outside the accepted census is an operator gate**, not an
  implementation decision — including test-only dependencies.
