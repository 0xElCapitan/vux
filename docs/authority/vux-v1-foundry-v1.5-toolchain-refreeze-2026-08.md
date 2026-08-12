# VUX v1 Foundry v1.5.0 Toolchain Refreeze

**Date:** 2026-08-12
**Status:** `TOOLCHAIN_REFREEZE_CURRENT_ACCEPTED`
**Operator decision:** 2026-08-12 — EC, `OPERATOR_DECISION`
**Scope:** toolchain authority only
**Lifecycle disposition:** bounded toolchain-authority + CI-recovery node; no product implementation, no sprint advanced

## 1. Activation rule

For all VUX work after this refreeze, **Foundry `v1.5.0` @ `1c57854462289b2e71ee7654cd6666217ed86ffd` is authoritative wherever older accepted authority selected Foundry `v1.0.0`.**

Nothing else in the accepted authority set moves. This document supersedes exactly one selection — the Foundry orchestrator — and is deliberately narrow so that the OZ/v3-core provenance refreeze, the licence/pin freeze, the source registries, and the strategic-treasury supersession set all remain current, unedited, and byte-identical.

| precedence | authority | disposition |
|---:|---|---|
| 1 | this document (+ `vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.json`) | current Foundry-toolchain selection |
| 2 | `vux-v1-oz-v3-provenance-refreeze-2026-08.md` §6 | current for **everything except** its Foundry row; that row is superseded here |
| 3 | all other accepted authority | unchanged and current |

## 2. Authority transition

| | previous | new |
|---|---|---|
| repository | `foundry-rs/foundry` | `foundry-rs/foundry` |
| tag | `v1.0.0` | `v1.5.0` |
| commit | `8692e926198056d0228c1e166b1b6c34a5bed66c` | `1c57854462289b2e71ee7654cd6666217ed86ffd` |
| release published | 2025-01-31 | 2025-11-24 |
| tag object | lightweight | lightweight (tag ref resolves directly to a commit object) |

### 2.1 Independent verification of the new identity

The identity was resolved from primary upstream evidence, not from the dispatching prompt:

| evidence | result |
|---|---|
| `refs/tags/v1.5.0` on `foundry-rs/foundry` (GitHub git-ref API) | `object.sha = 1c57854462289b2e71ee7654cd6666217ed86ffd`, `object.type = commit` |
| release `v1.5.0` (GitHub releases API) | `draft: false`, `prerelease: false`, `published_at: 2025-11-24T06:14:42Z` |
| commit object `1c578544…` | exists on `foundry-rs/foundry`, committed 2025-11-16T19:29:16Z |
| installed binary, official `foundryup -i v1.5.0` | attestation-verified (`forge/cast/anvil/chisel verified ✓`), self-reports `1.5.0-v1.5.0`, `Commit SHA: 1c57854462289b2e71ee7654cd6666217ed86ffd` |

A tag that resolved to a different commit than the one the binary self-reports would have halted this node. It did not: the ref, the release, and the executing binary agree on one 40-character commit.

## 3. Operator context — why the toolchain moved

Sprint-2 implementation, review, audit, and local validation were performed under a local Foundry v1.5.0 while CI installed the frozen v1.0.0. That divergence is not cosmetic: it makes "the same repository" produce different evidence depending on which machine ran it, and it is precisely how a green local check and a red pipeline can both be honest. Post-merge CI run `31573121028` on `f997c077` is red for exactly this reason — see §7.

Going forward, implementation, review, audit, local validation, and CI use one authoritative Foundry identity.

## 4. Scope boundary — what this refreeze does NOT change

This is a toolchain selection and nothing else. Explicitly unchanged:

| unchanged | value |
|---|---|
| VUX compilation unit compiler | `solc =0.8.28` @ `7893614a31fbeacd1966994e310ed4f760772658` |
| vendored v3 compilation unit compiler | `solc =0.7.6` @ `7338295feebfb3f044e265d5cf05ef1841b258b1` |
| v3 build settings | optimizer enabled, `optimizer_runs = 800`, `evm_version = istanbul`, `bytecode_hash = none`, accepted CBOR behaviour |
| `POOL_INIT_CODE_HASH` | `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` |
| source-reuse authorisation | none granted, none withdrawn |
| dependency set | unchanged; nothing added, nothing removed; no `forge-std` |
| vendored upstream bytes | unchanged (28 OZ / 32 v3-core / 3 Miner = 63 identities) |
| licence posture | `GPL-3.0-or-later`, unchanged |
| protocol / economic parameters | unchanged |
| product Solidity (`src/VUX.sol`, `src/HardReserve.sol`, `src/interfaces/IVUX.sol`) | unchanged, byte-for-byte |

### 4.1 What this refreeze DOES change beyond the selection — the source-admission surface

The table above is a list of things that did not move. Exactly one thing beyond the orchestrator selection itself **did**, and it is recorded here explicitly rather than left to be inferred by joining §10 and §11:

| | v1.0.0 `8692e926…` | v1.5.0 `1c578544…` |
|---|---|---|
| explicitly imported Solidity source with an odd extension (`.txt`) | **rejected** — `Error: unexpected file extension`, `forge build` and `forge test` both exit 1; the file never reaches solc | **accepted** — reaches `metadata.sources`, compiles, and the deployed instance executes |
| explicitly imported Solidity source with **no** extension | **rejected**, same hard failure | **accepted**, same reachability |

Both rows were demonstrated directly, in an isolated project outside this repository, under each exact toolchain identity.

**Therefore the v1.5.0 migration changes the source-admission — and hence the provenance/security — surface, even though accepted product executable bytecode is semantically unchanged (§9.1).** These are independent axes: byte-identical opcodes for the sources that *are* compiled says nothing about which sources the orchestrator is willing to compile.

The consequences, stated rather than implied:

1. **M-1 is reachable under the new authoritative toolchain.** Under v1.0.0 the orchestrator's extension check was an accidental but real fence in front of M-1; v1.5.0 removes it. This refreeze does not merely inherit M-1's exposure — it creates the reachable form of it.
2. **M-1 remains a binding pre-Sprint-3 provenance-hardening condition** (§11, §12 obligation 1). That obligation is now *newly load-bearing* rather than inherited, and is not discharged, narrowed, or deferred by this document.
3. **The refreeze remains safe to land.** The current subject contains **no** unauthorized odd-extension source — the universe is 77 fully classified Solidity files with zero unauthorized entries — and Sprint-3 product Solidity remains blocked until M-1 closure. The exposure window is bounded by the same gate that closes it. M-1 also requires a deliberate `import` from inside an authorized root; it is not passive injection.

M-1 is **not** remediated here, deliberately, to keep this node bounded (§11).

## 5. Preserved predecessor evidence

The following accepted artifacts were **not edited** by this node and remain byte-identical. Their SHA-256 values are unchanged and are still the values pinned in `tools/provenance/census.sh`:

| artifact | SHA-256 | disposition |
|---|---|---|
| `docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md` | `27aa37ec82fffaea4deb63d5ccd87f66a7e71bad1afa9e7d95d814035e8e3203` | current, except its Foundry row (§6, and the toolchain row of its §"Toolchain pins") which this document supersedes |
| `docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json` | `db3144135251af34f6bef9da61300a2644c381c4763f2347753657de6afaf4f1` | current; its recorded `foundry` commit is historical from this date forward |
| `docs/authority/vux-v1-licence-provenance-source-pin-freeze-2026-08.md` | `50c3584a1483b40ffb6391260a2bf42df32220c64724fdcc672ca62c01ace3a2` | unchanged and current |
| `docs/authority/vux-v1-source-registry-2026-08.json` | `6fc9fa81d80eda1f1017c6cb79f297b9a608150538e76ad97d8de1c8b5d2fe04` | unchanged and current |
| `THIRD_PARTY_NOTICES.md` | `963e2cfb8fe8306ee6d2cfd6e14fa417a7a61fd7bfddc3fe5aedc2b577170873` | unchanged; Foundry is a build orchestrator, not distributed third-party source |

Historical Sprint-1 and Sprint-2 implementation, review, and audit reports continue to name Foundry `v1.0.0`. **That is correct and must not be rewritten** — those documents record what actually ran at the time. Old CI-run records likewise stand. Truth about the past is not repaired by editing it; it is superseded by dating the change, which is what this document does.

## 6. Superseded statements

Wherever the following older accepted text selects Foundry `v1.0.0` as the *current* toolchain, it is superseded by §2 of this document as of 2026-08-12:

| location | superseded statement | classification |
|---|---|---|
| `vux-v1-oz-v3-provenance-refreeze-2026-08.md` toolchain-pin table | `foundry-rs/foundry` `v1.0.0` → `8692e926…` | **SUPERSEDED** (document not edited) |
| `vux-v1-source-registry-oz-v3-refreeze-2026-08.json` toolchain entry | `commit_sha: 8692e926…` | **SUPERSEDED** (document not edited) |
| `grimoires/loa/sdd.md` §"Toolchain" row | Foundry stable `1.0.0` → `8692e926…` | **SUPERSEDED**; a pointer to this document was added in place, the historical pin left intact |

Not superseded and not related: `Uniswap/v3-core` tag `v1.0.0` @ `e3589b192d0be27e100cd0daaf6c97204fdb1899` and the vendored directory `vendor/uniswap-v3-core-v1.0.0/`. That `v1.0.0` belongs to a different upstream project and is untouched.

## 7. Active enforcement surfaces

The refreeze is only authority if the gates carry it. These files were changed by this node:

| file | change |
|---|---|
| `foundry.toml` | recorded toolchain pin comment → `foundry v1.5.0 … 1c578544…` (read by `verify-pins.sh` `check_pin`) |
| `tools/provenance/census.sh` | `FOUNDRY_TAG` / `FOUNDRY_COMMIT` → v1.5.0 identity; this document and its JSON companion registered as SHA-256-pinned authority |
| `tools/provenance/verify-pins.sh` | the running Foundry identity is now **asserted fail-closed**, not printed; this authority document is verified against its accepted hash |
| `.github/workflows/provenance.yml` | `FOUNDRY_VERSION: v1.5.0`, new `FOUNDRY_COMMIT` env, and the post-install assertion now requires the executing `forge` to self-report the exact 40-character authorised commit — the workflow input is no longer trusted on its own |
| `tools/provenance/README.md` | gate description updated to match the strengthened pins gate |

The `foundry-rs/foundry-toolchain` action itself remains pinned by immutable 40-character action commit (`82dee4ba654bd2146511f85f0d013af94670c4de`), per existing policy. Its `version:` input is the exact string `v1.5.0`. `stable`, `latest`, `nightly`, and branch names are never used.

## 8. Binding operational rule

> **Toolchain identity is part of the evidence chain.** Every substantive VUX implementation, review, audit, local validation, and CI node MUST verify the exact authoritative Foundry identity before relying on any Foundry-dependent evidence. The ambient `PATH` version is not evidence.

Mechanised in `tools/provenance/verify-pins.sh` (local and CI, fail-closed) and in the CI post-install assertion. It is stated once, here; the gate is the enforcement, not a repetition of this sentence across documents.

## 9. Parity evidence — v1.0.0 ↔ v1.5.0

A single bounded side-by-side validation was run on the exact current repository product, holding the accepted solc versions and build settings constant and varying only the Foundry orchestrator.

### 9.0 Digest convention — stated, because an unstated one is not evidence

Every bytecode digest in §9 and §9.1 is published under one convention, stated here in full:

> **SHA-256 over the artifact's `bytecode.object` / `deployedBytecode.object` field taken as its lowercase hex *string*** — the `0x` prefix removed, no trailing newline, hashing the ASCII hex characters and **not** the decoded bytes. §9.1's stripped-code digests use the same preimage after removing the trailing `n + 2` bytes (`2 × (n + 2)` hex characters), where `n` is the big-endian value of the object's final two bytes.

Reproduce any whole-artifact value below with nothing but `jq` and `sha256sum`:

```bash
jq -r '.bytecode.object' out/VUX.sol/VUX.json | sed 's/^0x//' | tr -d '\n' | sha256sum
```

The v1.0.0 column is reproduced by building the same tree with `forge` v1.0.0 `8692e926…` into a separate output directory (`FOUNDRY_OUT`), which is how it was produced here. Hashing the decoded bytes instead of the hex string is a valid convention but a *different* one, and yields different constants throughout — which is exactly why the convention is stated rather than assumed.

| compared identity | v1.0.0 | v1.5.0 | verdict |
|---|---|---|---|
| solc invoked, `=0.8.28` unit (all artifacts) | `0.8.28+commit.7893614a` | `0.8.28+commit.7893614a` | identical |
| solc invoked, `=0.7.6` unit (all artifacts) | `0.7.6+commit.7338295f` | `0.7.6+commit.7338295f` | identical |
| `VUX` ABI | — | — | identical |
| `HardReserve` ABI | — | — | identical |
| `VUX` method identifiers (20) | — | — | identical |
| `HardReserve` method identifiers (6) | — | — | identical |
| `UniswapV3Pool` creation / deployed bytecode | `888deca479325b2bdfed6c48f6ced356271fcba13e09d864a2f6986d8097fe43` / `ecd7503ff9ba5cface57946e85117c0c07796c0a5f2d7fe7ec20a54ec254510f` | same, both | **identical, whole artifact** |
| `VUX` creation / deployed bytecode | `52abdc247094420c952a782105df509ac1ea49b061af0d59eed2ceee40b1890e` / `05207c2747bddb2a2277192e61caea6502cb1922147ab838fed57a19c04eeb45` | `d39b3892c686f3c5cd77c7ee3865e28ad4c464c87e341094fe8c7be073a5a7c7` / `77c07c4ae72b6907e26d92098b4a09b08e546dc653c37f58be6c0bc4fc7285ba` | differ **only** in the trailing metadata CBOR |
| `HardReserve` creation / deployed bytecode | `1f977cbbe4a7f5ab7cf8d9cfb6e7736f6b90cce7c1522203be7ef0c2b152cd89` / `11b4ebd2928b4b6be16e7e48c16a9b6f4d1fc8cb6525fc739196d18a4a19d4ea` | `27655d138a377a902d8c60d4bdff1cfba7794ce24788e3ed47174afb04289eaf` / `d4cbe285488b96195e79e6ef4f79d4812b430e0c513303ecfb46639dcea45fd0` | differ **only** in the trailing metadata CBOR |

Artifact lengths are pairwise identical across the two toolchains — `VUX` 11,386 / 7,989 bytes, `HardReserve` 4,736 / 3,252 bytes, `UniswapV3Pool` 22,728 / 22,142 bytes — so no code was added or removed in either direction.

> **Restatement note.** An earlier draft of this section published a whole-artifact column under no stated convention, and those values did not reproduce under any of raw-bytes, hex-string, or `0x`-prefixed-hex SHA-256. Every constant in the table above was re-derived from clean-room builds under both toolchains and reproduced independently before publication. A reader comparing against that draft will see different constants; the constants here are the reproducible ones.

### 9.1 The difference is explained, not assumed

The four differing artifacts were compared again with the trailing CBOR metadata blob removed (length taken from the standard two-byte big-endian suffix). With metadata stripped, the **executable code is byte-identical in all four cases**, at identical length:

| artifact | code length (hex chars) | code SHA-256, both toolchains |
|---|---|---|
| `VUX` creation | 22,666 | `3f8ffe9ebacd3b5962fbef8aa19e3b8fb00916e356c9bca0773d405691a52fa6` |
| `VUX` deployed | 15,872 | `7377122c247ecc7da63099b3818c1db506c33f71eee2c6dfa8b9429275a32ed2` |
| `HardReserve` creation | 9,366 | `2184162f1cdecde87cbaecd09a0a80429cff48a33baf0fa2909712aca100e105` |
| `HardReserve` deployed | 6,398 | `065241a187cc91b53e174775c387cf6966e76e0d55b567ccd9e606074d804a07` |

The cause is named, not inferred. Diffing the two `metadata` objects yields exactly one difference in each contract:

```
-  "evmVersion": "cancun",
+  "evmVersion": "prague",
```

`metadata.sources` (file set and per-file keccak) is identical; `metadata.settings` is otherwise identical; the compiler identity is identical. A changed `evmVersion` string inside the metadata JSON changes the metadata hash, and therefore the CBOR tail, and therefore the artifact hash — while emitting the same opcodes, which is what the stripped comparison proves.

### 9.2 Toolchain-dependent build input — recorded, deliberately not "fixed" here

The root cause is that `foundry.toml [profile.default]` leaves `evm_version` **unset** by an explicit, documented Sprint-2 decision (it is a property of the deployment chain, to be frozen at Sprints 7–8 when the chain facts exist). An unset setting takes the Foundry default, and that default moved `cancun` → `prague` between v1.0.0 and v1.5.0. The VUX unit therefore inherits a build input from the orchestrator version.

The contrast is the proof: `[profile.v3core]` pins `evm_version = "istanbul"` explicitly, and its pool creation bytecode is identical across both toolchains, whole-artifact, metadata included.

Consequences, stated plainly:

- No semantic divergence exists today — the emitted code is byte-identical (§9.1).
- The recorded `evmVersion` in deployed VUX/HardReserve metadata is now `prague` rather than `cancun`.
- The deferred Sprints 7–8 deployment-bytecode freeze now has a second, sharper reason to pin `evm_version` explicitly: while it is unset, a future toolchain move can change a build input without any repository change. Pinning it is a product build-settings decision and was **not** authorised in this node; it is recorded here as a carry-forward obligation (§12).

## 10. Probe 12 / A-1 factual status under exact v1.5.0

`tools/provenance/demo-boundary-negative.sh` probe 12 is the positive control behind probes 8–11: it asserts that a mixed-case `.SOL` extension is genuinely build-reachable, read off solc's own `metadata.sources` plus an executed deployment rather than off a resolver diagnostic.

Re-run against the exact authorised toolchain, in an isolated project outside the repository:

| toolchain | result |
|---|---|
| v1.0.0 `8692e926…` | `forge build` and `forge test` both hard-fail: `Error: unexpected file extension`. The file never reaches solc. |
| v1.5.0 `1c578544…` | `metadata.sources` contains `src/CaseReach.SOL`; `forge test` reports `[PASS] test_MixedCaseExtensionIsBuildReachableAndExecutable`. Foundry prints `Unable to resolve imports` in the *same run* that compiled successfully. |

Findings:

1. **Probe 12 required no correction.** It is semantically accurate under the authoritative toolchain and its assertions were already written against compiler-authoritative evidence rather than a resolver diagnostic. It was preserved unchanged; the positive control was not deleted to obtain green CI.
2. **A-1 stands, under v1.5.0.** A mixed-case-extension Solidity file *is* compiled and executable when imported. Sprint-1 finding N-2 stays retracted.
3. **The Sprint-1 N-2 retraction is now doubly evidenced.** The `Unable to resolve imports` warning is emitted by Foundry's pre-resolution graph walker and coexists with a successful compile and a passing execution — a resolver diagnostic describes the discovery pass, never what compiled.
4. **CI run `31573121028` was red for a toolchain reason, not a defect.** Probe 12 was authored from v1.5.0 behaviour while CI installed v1.0.0, where the extension is refused outright. Probes 1–11 were green under both.

## 11. M-1 factual status under exact v1.5.0 — real, and carried forward

M-1 (the provenance filesystem universe is extension-keyed, while the compiler-reachable universe may not be) was re-established as fact, not re-argued. Bounded probe under exact v1.5.0, isolated project outside the repository:

| planted source | imported | in `metadata.sources` | executed |
|---|---|---|---|
| `src/Arbitrary.txt` | yes | yes | yes — `[PASS]` |
| `src/NoExtension` (no extension at all) | yes | yes | yes — `[PASS]` |

**M-1 is real under the authoritative toolchain.** An imported file becomes compiler input regardless of its filename extension, including having none; the compiler resolves the import string byte-for-byte through its own filesystem callback. An extension-keyed inventory therefore cannot enumerate the compiler-reachable source set.

M-1 was **not** remediated here and the compiler-metadata cross-check was **not** added — deliberately, to keep this node bounded. M-1 retains its carry-forward condition: **a bounded provenance-hardening node before Sprint-3 product implementation.**

**M-1's reachable form is created by this transition, not inherited by it** — under the superseded v1.0.0 orchestrator both probes above hard-fail with `unexpected file extension` and never reach solc. See §4.1, which records that widening as a change to the source-admission surface and states why the refreeze is nevertheless safe to land.

## 12. Obligations carried forward

1. **M-1 provenance hardening** — bounded node before Sprint-3 product implementation (§11). Unchanged in scope; now supported by direct v1.5.0 evidence. **This obligation is newly load-bearing rather than inherited:** the v1.0.0 → v1.5.0 transition removes the orchestrator's extension check and thereby creates M-1's reachable form (§4.1). Sprint-3 product Solidity is blocked until it closes.
2. **`evm_version` freeze for `[profile.default]`** — to be decided at the Sprints 7–8 deployment-bytecode freeze, with the §9.2 finding on the record.
3. **Red-CI recovery** — this node produces a forward fix commit through the normal lifecycle. `f997c077` and `89a92055` are not amended, reset, rebased, or force-pushed; run `31573121028` remains historical evidence of a real divergence.

## 13. Verification performed by this node

Full local regression under exact Foundry v1.5.0 `1c57854462289b2e71ee7654cd6666217ed86ffd`. Results are recorded in the node's evidence and in `grimoires/loa/NOTES.md`.
