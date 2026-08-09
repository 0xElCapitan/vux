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

**None selected. None installed. None pinned.**

| dependency family | classification | licence family | status |
|---|---|---|---|
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) | `V1_DEPENDENCY` | MIT | **Family cleared; no VUX release selected.** The exact release is deliberately reserved for the Loa architecture phase and must be resolved to an immutable commit or package-integrity digest, with imported paths recorded and the release's exact notice preserved, **before** any code is written. |

Miner's lockfile resolving OpenZeppelin `4.9.6` describes the ancestor build
only; it is not a VUX dependency decision. A version range such as `^x.y.z` is
never the production authority.

The AMM/POL venue and the toolchain are unselected. Canonical Robinhood Chain
WETH is an external deployed runtime contract, interacted with through a cleared
interface — it is not source copied or linked into VUX.

Each implementation dependency that is actually adopted must be added to this
file with its exact release or pin and its verbatim required copyright, licence,
and NOTICE material.

---

## 7. Changing any of this

A source or reference pin may change only through an explicit provenance delta
that names the old and proposed full SHAs and the reason, re-runs the file,
licence, notice, submodule, and dependency census at the proposed commit,
rechecks ancestry and compatibility, updates the Markdown authority and the JSON
registry atomically, and receives explicit operator approval before use. See §17
of the licence/provenance freeze.
