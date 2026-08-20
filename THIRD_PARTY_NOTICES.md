# Third-Party Notices

VUX is licensed `GPL-3.0-or-later` (see [`LICENSE`](LICENSE)). The project-level
GPL posture governs VUX-original code and the combined VUX work. It does **not**
erase any third-party file's licence, author credit, provenance, or copyright
notice.

**Controlling authority:** [`docs/authority/vux-v1-licence-provenance-source-pin-freeze-2026-08.md`](docs/authority/vux-v1-licence-provenance-source-pin-freeze-2026-08.md)
and its machine-readable companion
[`docs/authority/vux-v1-source-registry-2026-08.json`](docs/authority/vux-v1-source-registry-2026-08.json).
Where this file and the freeze disagree, the freeze governs.

**Current status:** no VUX source code exists in this repository yet. This file
records the frozen provenance obligations that attach *before* any code is
written, and is updated as authorized reuse and pinned dependencies actually
land.

**Default policy is deny.** A file not expressly allowlisted below may be
studied only under its assigned classification. It may not be copied, ported,
imported, or used to derive implementation.

---

## 1. Miner Manifold — authorized for v1 reuse (file-specific)

| field | value |
|---|---|
| Repository | https://github.com/Heesho/miner-manifold |
| Frozen source pin | `bcffbf1eb963810acb14a1fd1c73d03a53a085a8` |
| Commit date | `2026-01-09T12:06:46-08:00` |
| Classification | `V1_SOURCE_ANCESTOR` |
| Upstream licence state | Each allowlisted file declares `SPDX-License-Identifier: MIT`. At this pin the repository has **no** root `LICENSE`, `LICENCE`, `COPYING`, or `NOTICE` file; the README claims MIT but links to a file that does not exist. |
| Upstream author credit | `@author heesho` (as declared in the file headers) |
| Copyright holder | **None declared upstream.** No copyright line is present in these files at this pin, and this project does not invent one. |

### Directly reusable files — the complete allowlist

| upstream path | Git blob OID | upstream notices |
|---|---|---|
| `contracts/Rig.sol` | `d362ef354994df29f0859889a7189ec028868e07` | `MIT`; `@author heesho`; no copyright line |
| `contracts/Unit.sol` | `26d491eb650d5e0cc1609ee1b9791b9aee510d02` | `MIT`; `@author heesho`; no copyright line |
| `contracts/interfaces/IUnit.sol` | `7069422ce70c4d848145f8bfce42300a3f024bb5` | `MIT`; no author or copyright line |

**Approval is file-specific, not repository-wide.** Approving the repository
entry does not approve the repository as a whole. No other Miner Manifold file —
including `Strategy.sol`, `Hopper.sol`, `Router.sol`, `Multicall.sol`,
`interfaces/IRig.sol`, and the upstream tests — is authorized for v1 reuse. The
whole repository must not be cloned or vendored into VUX.

Reuse is authorized **only** from the frozen pin above. Mutable references
(`main`, `master`, `HEAD`, `latest`, or an unresolved tag) are never source
authority.

The permission basis is cumulative: the file-level MIT declarations for
Heesho-controlled material, plus an operator-recorded collaborator permission
from Heesho limited to rights Heesho controls, plus Euler's independent
`GPL-2.0-or-later` grant for the conservatively attributed auction lineage
(§2). The collaborator permission is preserved in private operational records
and is not published here. It does not relicense Euler, Solidly, Synthetix, or
any other third party's material.

---

## 2. Euler FeeFlow — transitive ancestry (no direct v1 copy)

| field | value |
|---|---|
| Repository | https://github.com/euler-xyz/fee-flow |
| Frozen source/licence evidence pin | `3bee858a1568d1313f37d615953f83391a897866` |
| Commit date | `2025-06-11T13:18:56+02:00` |
| Relevant source | `src/FeeFlowController.sol` |
| Licence | `GPL-2.0-or-later` (file SPDX); GPLv2 text present as the repository root `LICENSE` at this pin |
| Author credit | `@author Euler Labs` |
| Classification | `V1_SOURCE_ANCESTOR` (transitive, conservative) |

VUX conservatively treats the Miner Rig auction lineage as **descended from this
FeeFlow lineage**, and selects GPLv3 under the upstream `-or-later` grant.

The basis for the conservative treatment: the same Miner root commit contains
`Strategy.sol`, which expressly states that it is forked and modified from
Euler Finance's FeeFlow and is the same Git blob as the pinned Liquid Signal
Governance `Strategy.sol`; `Rig.sol` then repeats that lineage's distinctive
auction state-transition skeleton. `Rig.sol` itself discloses only `MIT` and
`@author heesho`, and a lone MIT header is not relied upon to erase an
inherited GPL grant.

**No claim is made that this exact Euler commit is the proven historical copy
source used by Heesho.** The precise historical revision is not established by
any commit record. `3bee858a1568d1313f37d615953f83391a897866` is the frozen,
immutable source and licence *evidence* pin for the FeeFlow lineage.

`GPL-2.0-or-later` is not `GPL-2.0-only`: the upstream expression lets a
recipient choose GPLv3, so this lineage does not conflict with the VUX
`GPL-3.0-or-later` posture. Euler credit, licence history, source pin,
modification notices and dates, and GPL corresponding-source obligations must
all be preserved.

Euler `src/FeeFlowController.sol` is **not** directly copied into v1. Its EVC
and Solmate imports do not accompany the Miner-derived Rig.

---

## 3. MIT permission and warranty text

The following MIT (Expat) permission and warranty terms apply to the reused
Miner Manifold material identified in §1. The customary MIT copyright line is
reproduced **without a holder** because no copyright line exists upstream at the
frozen pin; a verified holder may add its own notice later.

```text
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

MIT terms are compatible with GPLv3, and they do not disappear when the combined
VUX work is distributed under GPL terms.

---

## 4. Obligations on VUX modifications

VUX modifications **must preserve provenance**. For any file derived from or
ported from the §1 allowlist:

1. State the upstream repository URL, upstream path, and full 40-character SHA.
2. State the original licence expression(s), and retain the upstream author and
   source comments. Do not claim sole VUX authorship.
3. Carry a prominent, dated VUX modification notice.
4. Point to this file.

Per-file SPDX treatment:

| file condition | SPDX identifier |
|---|---|
| Wholly VUX-original, written from the canonical specification | `GPL-3.0-or-later` |
| Materially derived or ported from Miner `Rig.sol` | `MIT AND GPL-3.0-or-later`, plus Miner **and** Euler provenance and a dated modification comment |
| Materially derived or ported from Miner `Unit.sol` or `IUnit.sol` | `MIT AND GPL-3.0-or-later`, plus Miner provenance and a dated modification comment |
| Byte-for-byte unmodified allowlisted MIT file | retain `MIT`; the aggregate project remains GPL and this notice remains required |
| Third-party dependency kept in source form | retain its upstream SPDX and copyright headers verbatim |

`AND` is intentional: the recipient must comply with both sets of terms. Do not
use bare or deprecated `GPL-3.0`, do not change `-or-later` to `-only`, and do
not leave a lone `MIT` header on a materially GPL-derived VUX Rig.

Hard Reserve, VEM, revenue routing, and quoting/periphery are VUX-original work
written from the canonical specification. They carry `GPL-3.0-or-later` alone
and must not be started from any third-party source.

No document or header may invent a copyright holder — not `Copyright (c)
Heesho`, not a VUX company or entity, not the founders, and not any other party.

---

## 5. Reference and deferred sources — NOT AUTHORIZED FOR V1 CODE REUSE

These are recorded for provenance and traceability only. **No code, prose, or
structural port from any of them may enter VUX v1.** Each is frozen at a full
40-character SHA; no later pin is approved.

| source | repository | frozen full SHA | classification | boundary |
|---|---|---|---|---|
| Liquid Signal Governance (LSG) | https://github.com/Heesho/liquid-signal-governance | `14b5fbbbe1945f2e6501f84976e5f12b39fb227a` | `DEFERRED_NOT_V1` | No v1 copy, import, or derivation. `Voter.sol` and `Bribe.sol` are additionally `PROHIBITED_PENDING_CLEARANCE` — their named Solidly and Synthetix ancestry lacks an exact repository, commit, and path. |
| gumball6900 | https://github.com/Heesho/gumball6900 | `4d0883cc2954f773c1e2d84d6e54c3930b09341e` | `REFERENCE_ONLY` | Study only; no code or text copy. The pinned root `NOTICE` grants no repository licence and calls licensing a release blocker. `Fund.sol`, `LiquidityPosition.sol`, `Strategy.sol`, and `ResonanceRouter.sol` must not be copied, ported, or edited down. |
| give.fun | https://github.com/Heesho/givedotfun-monorepo | `ef6ee14a454432210d13e312d0ef825f670bd79d` | `REFERENCE_ONLY` (transitive evidence) | Study only; no v1 copy. Recorded because its `Auction.sol` independently declares Euler FeeFlow ancestry. |
| Olympus v3 | https://github.com/OlympusDAO/olympus-v3 | `a686d715bf572a60156a39f9c9af69d5208ca8be` | `REFERENCE_ONLY` | Policy-shape reference only; no code copy. Relevant files carry `AGPL-3.0` or `AGPL-3.0-only` expressions, which the GPL-only v1 surface does not silently absorb. |
| Olympus docs | https://github.com/OlympusDAO/olympus-docs | `4256dd3ffc20747426cbd9e89a1d93849ea968e2` | `REFERENCE_ONLY` | Reference only; no prose or source copying. Root licence at this pin is MIT, `Copyright (c) 2022 OlympusDAO`. |

Also not authorized for v1 reuse: Miner `Strategy.sol` (byte-identical to the
pinned LSG `Strategy.sol`), Miner `Hopper.sol`, `Router.sol`, `Multicall.sol`,
`interfaces/IRig.sol`, the upstream tests, and every upstream file not named in
the §1 allowlist.

---

## 6. Implementation dependencies

**Selected (accepted SDD v1.6.0) and authorized by the accepted refreeze
(operator acceptance 2026-08-10).**

**State of the tree as of Sprint 8 (2026-08-19)** — this section previously read
"None installed. Nothing imported or vendored yet.", which was true when it was
written and is no longer. What is actually here now:

| surface | state | census |
|---|---|---|
| OpenZeppelin v5.2.0 (§6.1) | **vendored**, byte-identical, 28 files | `tools/provenance/verify-census.sh` (CI, fail-closed) |
| Uniswap v3-core v1.0.0 (§6.2) | **vendored**, byte-identical, 32 files | same gate |
| Off-chain npm surface (§6.3) | **installed** in two roots with committed lockfiles | `grimoires/loa/a2a/sprint-8/offchain-licence-census.json` |
| Static-analysis toolchain (§6.4) | **installed** in CI only, hash-pinned | `grimoires/loa/a2a/sprint-8/static-analysis-licence-census.json` |

| dependency family | classification | licence family | status |
|---|---|---|---|
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) | `V1_DEPENDENCY` | MIT | **Exact release v5.2.0 selected and authorized; refreeze §6.1 accepted 2026-08-10.** Resolved to immutable commit `acd4ff74de833399287ed6b31b4debf6b2b35527`, with the complete closed 28-file imported-path census and the release's exact notice recorded **before** any code is written. |
| [Uniswap v3-core](https://github.com/Uniswap/v3-core) | `V1_DEPENDENCY_VENDORED_SOURCE` | per file: BUSL-1.1 (now governed by Change License `GPL-2.0-or-later`) / `GPL-2.0-or-later` / MIT | **Exact release v1.0.0 selected and authorized; refreeze §6.2 accepted 2026-08-10.** Resolved to immutable commit `e3589b192d0be27e100cd0daaf6c97204fdb1899`, with a closed 32-file census for byte-identical vendoring. |

Miner's lockfile resolving OpenZeppelin `4.9.6` describes the ancestor build
only; it is not a VUX dependency decision. A version range such as `^x.y.z` is
never the production authority.

The canonical POL venue is protocol-deployed from the pinned Uniswap v3-core
source (§6.2), and the toolchain pins (solc `=0.8.28` and `=0.7.6`, Foundry
**v1.5.0 @ `1c57854462289b2e71ee7654cd6666217ed86ffd`** — the 2026-08-12
toolchain refreeze superseded the Foundry 1.0.0 selection this line previously
named) are recorded in the refreeze authority. Canonical Robinhood Chain
WETH is an external deployed runtime contract, interacted with through a cleared
interface — it is not source copied or linked into VUX.

Each implementation dependency that is actually adopted must be added to this
file with its exact release or pin and its verbatim required copyright, licence,
and NOTICE material.

### 6.1 OpenZeppelin Contracts v5.2.0 — accepted refreeze (operator acceptance 2026-08-10)

| field | value |
|---|---|
| Repository | https://github.com/OpenZeppelin/openzeppelin-contracts |
| Release / frozen source pin | tag `v5.2.0` → commit `acd4ff74de833399287ed6b31b4debf6b2b35527` (independently verified 2026-08-10) |
| Commit date | `2025-01-09T09:04:47-06:00` |
| Classification | `V1_DEPENDENCY` — implementation dependency, exact files only |
| Licence | MIT — root `LICENSE` at the pin (git blob `b2fee8f211650092ffdcbd519ef3ffbc1c258b8f`, SHA-256 `8b3fddff3cff904ab9bd7c48a9288fb08ab4f47b179c07af6df7886b12cb04d6`); every authorized file declares `SPDX-License-Identifier: MIT` |
| Authorized surface | exactly the 28 files enumerated in the refreeze census (the 7 SDD-selected import paths plus their closed transitive OZ-internal closure) |
| Authority | [`docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md`](docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md) §3 + [`docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json`](docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json) |

Required notice, reproduced verbatim from the pinned `LICENSE`:

```text
The MIT License (MIT)

Copyright (c) 2016-2024 Zeppelin Group Ltd

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

Unmodified imported files retain their `MIT` SPDX headers. MIT terms are
GPLv3-compatible and survive conveyance of the combined GPL work. Importing any
OpenZeppelin path outside the recorded census requires a new operator-accepted
refreeze.

### 6.2 Uniswap v3-core v1.0.0 — accepted refreeze (operator acceptance 2026-08-10)

| field | value |
|---|---|
| Repository | https://github.com/Uniswap/v3-core |
| Release / frozen source pin | tag `v1.0.0` (annotated tag object `ef64f51d0f0dca5346c903484f3e6a771dd69d59`) → commit `e3589b192d0be27e100cd0daaf6c97204fdb1899` (independently verified 2026-08-10) |
| Commit date | `2021-05-04T11:46:59-05:00` |
| Classification | `V1_DEPENDENCY_VENDORED_SOURCE` — byte-identical vendoring, exact files only |
| Licence (root `LICENSE`, git blob `075a13ae390e521a9ccee36929e42725ed8ddf57`, SHA-256 `85c5cbc5be388d8bb38d8618de93c96e247ae5af20eb79dbafc1fb5b13b57b54`) | Business Source License 1.1 — Licensor **Uniswap Labs**; Licensed Work **Uniswap V3 Core** ("The Licensed Work is (c) 2021 Uniswap Labs"); Additional Use Grant "Any uses listed and defined at v3-core-license-grants.uniswap.eth" (not relied on); Change Date "The earlier of 2023-04-01 or a date specified at v3-core-license-date.uniswap.eth"; Change License **GNU General Public License v2.0 or later** |
| Licence state at consumption | the Change Date passed no later than 2023-04-01 (the ENS-published date could only accelerate it), so every `BUSL-1.1` file at this pin is governed by the Change License `GPL-2.0-or-later`; 22 files carry per-file `GPL-2.0-or-later` headers and `contracts/libraries/FullMath.sol` carries `MIT`; VUX selects GPL version 3 under the or-later option |
| Authorized surface | exactly the 32 files enumerated in the refreeze census (pool implementation + deployer + `NoDelegateCall`, all 16 libraries, 13 concrete interfaces) |
| Explicitly excluded | `contracts/UniswapV3Factory.sol` implementation; **all** of v3-periphery (evidence pin only); every other upstream path |
| Authority | [`docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md`](docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md) §4 + [`docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json`](docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json) |

Obligations on the vendored tree: files land byte-identical to the recorded
per-file blob OIDs/SHA-256s; upstream SPDX headers are retained verbatim —
including the historical `BUSL-1.1` headers (the Change-Date conversion is
recorded here and in the refreeze, never edited into upstream files); the
vendored pool implementation is never edited; Uniswap Labs credit is preserved.
`VuxPoolDeployer.sol` derives from the upstream deployer pattern and must carry
`GPL-3.0-or-later` plus a full upstream-provenance header (repository, path,
commit, blob, original `BUSL-1.1` licence, Change-Date basis, dated VUX
modification notice, pointer to this file) — it must never be presented as
wholly VUX-original. GPL corresponding-source obligations apply on conveyance.
Vendoring or importing any v3-core path outside the recorded census requires a
new operator-accepted refreeze.

### 6.3 Off-chain surface — accepted refreeze (operator acceptance 2026-08-14)

Authority: `docs/authority/vux-v1-offchain-provenance-refreeze-2026-08.md`
(`OFFCHAIN_PROVENANCE_REFREEZE_CURRENT_ACCEPTED`) + its JSON registry. The
acceptance authorizes exactly ten packages plus the disclosed exact transitive
`@tanstack/query-core@5.71.1`, in two package roots (`indexer/`, `web/`), each
with a committed lockfile enforced by `npm ci --ignore-scripts` and a CI
lockfile-drift gate.

| package | pin | root | licence |
|---|---|---|---|
| `ponder` | 0.8.33 | `indexer/` | MIT |
| `next` | 15.1.12 | `web/` | MIT |
| `react` / `react-dom` | 19.0.0 | `web/` | MIT |
| `viem` | 2.21.60 | both | MIT |
| `wagmi` | 2.14.16 | `web/` | MIT |
| `@playwright/test` | 1.49.1 | `web/` (dev/test) | Apache-2.0 |
| `@tanstack/react-query` | 5.71.1 | `web/` | MIT |
| `hono` | 4.6.19 | `indexer/` | MIT |
| PostgreSQL | 16.4 | service (deployment fact) | PostgreSQL Licence |

**Transitive licence census (closes disclosure D-3 of that refreeze, §6.1).**
Produced by `tools/offchain/licence-census.mjs`, recorded at
`grimoires/loa/a2a/sprint-8/offchain-licence-census.json`: **675 distinct
packages**, overwhelmingly MIT/ISC/Apache-2.0/BSD. Weak-copyleft members
(MPL-2.0 ×4, one `Apache-2.0 AND LGPL-3.0-or-later`) are all compatible with
`GPL-3.0-or-later`. 74 further lockfile entries are optional platform-gated
binaries npm records but does not install on any single host.

**Disclosed: three packages carry a proprietary, non-commercial licence and are
NOT distributed.** `@metamask/sdk@0.32.0`, `@metamask/sdk-communication-layer@0.32.0`,
and `@metamask/sdk-install-modal-web@0.32.0` arrive as non-optional production
dependencies of `@wagmi/connectors@5.7.12` (itself a dependency of the accepted
`wagmi` pin). They declare **no licence** on the npm registry, and the LICENSE
file inside the published tarball is a ConsenSys proprietary grant limited to
**Non-Commercial Use** — a field-of-use restriction incompatible with
`GPL-3.0-or-later` conveyance. `@metamask/eth-json-rpc-provider@1.0.1` likewise
declares no licence.

They are installed (they are in the accepted lockfile) but **no part of them is
conveyed**. VUX configures only wagmi's built-in `injected()` connector
(`web/lib/wagmi.js`), never `metaMask()`, so the bundler removes the SDK
entirely. Verified by exhaustive scan of all 38 files / 1,220,956 bytes of the
built static export `web/out/`: zero occurrences of `ConsenSys`, `MetaMaskSDK`,
`metamask.app.link`, `sdk-communication`, `eth-json-rpc-provider`, or
`Non-Commercial`. The single `metaMask` string that does appear is an entry in
wagmi's own MIT-licensed injected-wallet identifier table — a detection
predicate, not SDK code.

**Consequence, stated plainly:** the distributed artifact is clean. The
*development and CI environment* installs proprietary non-commercial code as a
transitive consequence of an accepted pin. That is a bounded, disclosed residual
carried to the operator, not a resolved one.

### 6.4 Static-analysis toolchain — accepted refreeze (operator acceptance 2026-08-19)

Authority: `docs/authority/vux-v1-static-analysis-provenance-refreeze-2026-08.md`
(`STATIC_ANALYSIS_PROVENANCE_REFREEZE_CURRENT_ACCEPTED`) + its JSON registry.
This is a **toolchain** entry, in the same class §6's preamble assigns to solc and
Foundry — not a conveyance entry.

| distribution | pin | upstream commit | licence |
|---|---|---|---|
| `slither-analyzer` | 0.10.4 | `crytic/slither` @ `aeeb2d368802844733671e35200b30b5f5bdcf5c` | AGPL-3.0 |
| `crytic-compile` | 0.3.7 | `crytic/crytic-compile` @ `20df04f37af723eaa7fa56dc2c80169776f3bc4d` | AGPL-3.0 |

The full transitive closure — **49 distributions**, every one pinned `==` with
`--hash=sha256:` in `tools/static-analysis/requirements.txt` — is censused at
`grimoires/loa/a2a/sprint-8/static-analysis-licence-census.json`: 0 undeclared
licences, 0 yanked artifacts, and three AGPL-3.0 members (the two above plus
`solc-select`, all Trail of Bits) alongside `certifi` MPL-2.0.

**No AGPL obligation reaches VUX**, for four independent reasons recorded in the
refreeze §4.2: no conveyance, no modification (so AGPL §13's network clause never
triggers), no linking or incorporation into any VUX artifact, and analyzer output
is not a derivative of the analyzer. The discriminating test is that the shipped
artifact is byte-identical whether or not slither is ever installed. Recorded but
not relied upon: `GPL-3.0-or-later` is in any case compatible with AGPL-3.0
(GPLv3 §13).

---

## 7. Changing any of this

A source or reference pin may change only through an explicit provenance delta
that names the old and proposed full SHAs and the reason, re-runs the file,
licence, notice, submodule, and dependency census at the proposed commit,
rechecks ancestry and compatibility, updates the Markdown authority and the JSON
registry atomically, and receives explicit operator approval before use. See §17
of the licence/provenance freeze.
