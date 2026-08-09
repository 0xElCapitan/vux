# VUX v1 Licence, Provenance & Source-Pin Freeze

**Date:** 2026-08-09  
**Authority:** Final founder/source authority before the Loa lifecycle  
**Companion registry:** `vux-v1-source-registry-2026-08.json`  
**Legal posture:** Source-provenance and licence-compliance engineering review; not legal advice.

## 1. Status and executive verdict

`LICENCE_PROVENANCE_FREEZE_COMPLETE`

**VUX v1 may proceed into Loa `/plan-and-analyze` after this authority is accepted/imported.** This node does not invoke Loa, create a PRD/SDD/sprint plan, or authorize implementation.

The launch-critical source-rights path is clear:

- project posture: `GPL-3.0-or-later`;
- direct v1 reuse: only Miner Manifold `Rig.sol`, `Unit.sol`, and optional direct-import companion `IUnit.sol`, all at one immutable full SHA;
- conservative transitive treatment: the distinctive auction skeleton in Miner `Rig.sol` is treated as carrying Euler FeeFlow `GPL-2.0-or-later` ancestry even though `Rig.sol` itself discloses only `MIT` and `@author heesho`;
- clean-source v1 work: Hard Reserve, VEM arithmetic/policy, revenue routing, and quoting/periphery are VUX-original implementations written from the canonical specification;
- excluded from v1 code: Miner/LSG Strategy, LSG, gumball6900 code, give.fun code, Olympus code, Miner Hopper/Router/Multicall, and all unlisted upstream files.

`GPL-2.0-or-later` is not `GPL-2.0-only`. The upstream expression lets a recipient choose GPLv3; therefore the conservative FeeFlow lineage does not conflict with VUX `GPL-3.0-or-later`. No launch-critical source has a known incompatible licence.

The default rule is **deny**: if a file is not expressly allowlisted in §5, Loa may study it only under its assigned classification and may not copy, port, import, or derive implementation from it.

## 2. Project-level licence decision

The final project-level posture is:

```text
SPDX project licence: GPL-3.0-or-later
Canonical future root file: LICENSE containing the unmodified GNU GPL version 3 text
VUX-original Solidity: // SPDX-License-Identifier: GPL-3.0-or-later
```

Evidence and consequence:

1. The binding canonical specification fixes the intended project licence as `GPL-3.0-or-later`; this node does not reopen that founder decision.
2. SPDX distinguishes [`GPL-3.0-or-later`](https://spdx.org/licenses/GPL-3.0-or-later.html) from `GPL-3.0-only`, and distinguishes [`GPL-2.0-or-later`](https://spdx.org/licenses/GPL-2.0-or-later.html) from [`GPL-2.0-only`](https://spdx.org/licenses/GPL-2.0-only.html).
3. The FSF's [GPL compatibility guidance](https://www.gnu.org/licenses/gpl-faq.en.html#v2v3Compatibility) states that GPLv2-only and GPLv3 are incompatible, but code released under GPL version 2 **or later** can be used under GPLv3.
4. Miner allowlist files state `MIT`. The [MIT grant](https://opensource.org/license/mit) permits copying, modification, distribution, and sublicensing, subject to preservation of its copyright and permission notice. MIT terms are compatible with GPLv3; they do not disappear when the combined VUX work is distributed under GPL terms.

The root GPL posture governs VUX-original code and the combined VUX work. It is not permission to erase a third-party file's licence, author credit, provenance, or copyright notice. Per-file SPDX treatment is fixed in §15.

## 3. V1 source topology

```text
VUX v1 — GPL-3.0-or-later
|
+-- V1_SOURCE_ANCESTOR: Miner Manifold
|   source pin: bcffbf1eb963810acb14a1fd1c73d03a53a085a8
|   +-- contracts/Rig.sol — fork/modify or selective port
|   |   +-- conservative transitive auction lineage:
|   |       Euler FeeFlowController.sol
|   |       source-evidence pin: 3bee858a1568d1313f37d615953f83391a897866
|   |       GPL-2.0-or-later; GPLv3 selected for VUX
|   +-- contracts/Unit.sol — fork/modify or selective port
|   +-- contracts/interfaces/IUnit.sol — optional imported companion
|   +-- OpenZeppelin imports — dependency family; exact VUX release selected later by SDD
|
+-- VUX-original from canonical specification
|   +-- WETH-only Hard Reserve and redemption
|   +-- VEM cap/arithmetic and bootstrap policy
|   +-- revenue classification/routing
|   +-- read-only quoting/periphery
|
+-- DEFERRED_NOT_V1
|   +-- Liquid Signal Governance @ 14b5fbbbe1945f2e6501f84976e5f12b39fb227a
|   +-- Miner/LSG Strategy auction files
|
+-- REFERENCE_ONLY
    +-- gumball6900 @ 4d0883cc2954f773c1e2d84d6e54c3930b09341e
    +-- give.fun @ ef6ee14a454432210d13e312d0ef825f670bd79d
    |   (transitive gumball evidence)
    +-- Olympus v3 @ a686d715bf572a60156a39f9c9af69d5208ca8be
    +-- Olympus docs @ 4256dd3ffc20747426cbd9e89a1d93849ea968e2
```

The red-team result changes the earlier expected picture in one narrow way: Euler FeeFlow is not only a future Strategy reference. The auction state-transition skeleton in Miner `Rig.sol` is sufficiently similar to the explicitly FeeFlow-derived sibling `Strategy.sol` that VUX must conservatively treat Euler as transitive v1 ancestry. This adds GPL attribution and modification-notice duties but does not change the product architecture or block the licence posture.

## 4. Canonical source-pin registry

Every source/reference pin below is a full 40-character Git SHA. Commit dates are committer dates recorded by Git. Branches, tags, and current repository heads are non-authoritative.

| repository | classification | frozen full SHA | commit date | relevant paths | exact-pin licence/notice state | VUX permission |
|---|---|---|---|---|---|---|
| [Heesho/miner-manifold](https://github.com/Heesho/miner-manifold) | `V1_SOURCE_ANCESTOR` | [`bcffbf1eb963810acb14a1fd1c73d03a53a085a8`](https://github.com/Heesho/miner-manifold/tree/bcffbf1eb963810acb14a1fd1c73d03a53a085a8) | `2026-01-09T12:06:46-08:00` | `contracts/Rig.sol`; `contracts/Unit.sol`; `contracts/interfaces/IUnit.sol` | no root `LICENSE`/`COPYING`/`NOTICE`; README claims MIT but links to missing `LICENSE`; allowlisted files say `MIT` | copy/modify allowlist only; conservative Euler GPL treatment for Rig |
| [euler-xyz/fee-flow](https://github.com/euler-xyz/fee-flow) | `V1_SOURCE_ANCESTOR` (transitive, conservative) | [`3bee858a1568d1313f37d615953f83391a897866`](https://github.com/euler-xyz/fee-flow/tree/3bee858a1568d1313f37d615953f83391a897866) | `2025-06-11T13:18:56+02:00` | `src/FeeFlowController.sol`; `LICENSE` | file `GPL-2.0-or-later`; root GPLv2 text | no direct copy for v1; satisfy lineage through Miner-derived Rig under GPLv3 |
| [Heesho/liquid-signal-governance](https://github.com/Heesho/liquid-signal-governance) | `DEFERRED_NOT_V1` | [`14b5fbbbe1945f2e6501f84976e5f12b39fb227a`](https://github.com/Heesho/liquid-signal-governance/tree/14b5fbbbe1945f2e6501f84976e5f12b39fb227a) | `2026-02-10T01:12:21-08:00` | `Strategy.sol`; `RevenueRouter.sol`; `Voter.sol`; `Bribe.sol` | no root licence/notice; MIT file headers; Strategy declares Euler ancestry; Voter/Bribe have unpinned ancestry | no v1 copy/import/derivation |
| [Heesho/gumball6900](https://github.com/Heesho/gumball6900) | `REFERENCE_ONLY` | [`4d0883cc2954f773c1e2d84d6e54c3930b09341e`](https://github.com/Heesho/gumball6900/tree/4d0883cc2954f773c1e2d84d6e54c3930b09341e) | `2026-08-09T00:42:06+02:00` | `NOTICE`; `Fund.sol`; `LiquidityPosition.sol`; `Strategy.sol`; `ResonanceRouter.sol` | no root licence; NOTICE grants no repo licence, calls licensing a release blocker, and conflicts with current MIT file headers by referring to BUSL-1.1 headers pending counsel | study only; no code/text copy |
| [Heesho/givedotfun-monorepo](https://github.com/Heesho/givedotfun-monorepo) | `REFERENCE_ONLY` (transitive evidence) | [`ef6ee14a454432210d13e312d0ef825f670bd79d`](https://github.com/Heesho/givedotfun-monorepo/tree/ef6ee14a454432210d13e312d0ef825f670bd79d) | `2026-03-30T01:11:26-07:00` | `Auction.sol`; `Fundraiser.sol`; `Coin.sol`; `Core.sol` | no root licence/notice; file MIT headers; `Auction.sol` declares Euler FeeFlow ancestry | study only; no v1 copy |
| [OlympusDAO/olympus-v3](https://github.com/OlympusDAO/olympus-v3) | `REFERENCE_ONLY` | [`a686d715bf572a60156a39f9c9af69d5208ca8be`](https://github.com/OlympusDAO/olympus-v3/tree/a686d715bf572a60156a39f9c9af69d5208ca8be) | `2026-07-30T11:08:48+04:00` | `EmissionManager.sol`; `YieldRepurchaseFacility.sol`; `OlympusTreasury.sol`; `Heart.sol` | no root licence; relevant files use legacy `AGPL-3.0` or `AGPL-3.0-only` expressions | policy-shape reference only; no code copy |
| [OlympusDAO/olympus-docs](https://github.com/OlympusDAO/olympus-docs) | `REFERENCE_ONLY` | [`4256dd3ffc20747426cbd9e89a1d93849ea968e2`](https://github.com/OlympusDAO/olympus-docs/tree/4256dd3ffc20747426cbd9e89a1d93849ea968e2) | `2026-07-31T10:23:28+04:00` | root `LICENSE`; treasury/POL/emissions/YRF overview docs | root MIT, `Copyright (c) 2022 OlympusDAO` | reference only; no prose/source copying |

No later pin is approved. The known gumball commit `395a0dfbf56e3d478233736ef7a110e584a676e7` is not authority and is not proposed as a replacement: its changed Fund/LiquidityPosition behavior does not make code reuse necessary or clear the repository-wide licence ambiguity.

## 5. File-level provenance registry

### V1 copy/modify allowlist

| upstream file | classification | Git blob OID | upstream SPDX/notices | imports/ancestry | planned VUX treatment | mandatory treatment |
|---|---|---|---|---|---|---|
| `miner-manifold/contracts/Rig.sol` | `V1_SOURCE_ANCESTOR` | `d362ef354994df29f0859889a7189ec028868e07` | `MIT`; `@author heesho`; no copyright line | local `IUnit`; OZ `IERC20`, `SafeERC20`, `Ownable`, `ReentrancyGuard`; conservative Euler FeeFlow lineage | fork/modify or selective port; never call it VUX-original | derived-file SPDX `MIT AND GPL-3.0-or-later`; retain Heesho credit; credit Euler Labs/`GPL-2.0-or-later`; source URLs/SHAs; prominent VUX modification notice/date |
| `miner-manifold/contracts/Unit.sol` | `V1_SOURCE_ANCESTOR` | `26d491eb650d5e0cc1609ee1b9791b9aee510d02` | `MIT`; `@author heesho`; no copyright line | OZ `ERC20`, `ERC20Permit`, `ERC20Votes`; no other declared ancestor | fork/modify or selective port; exact feature selection belongs to SDD | if materially modified/ported: `MIT AND GPL-3.0-or-later`, source URL/SHA, Heesho credit, modification notice/date; if copied byte-for-byte, retain `MIT` |
| `miner-manifold/contracts/interfaces/IUnit.sol` | `V1_SOURCE_ANCESTOR` | `7069422ce70c4d848145f8bfce42300a3f024bb5` | `MIT`; no author/copyright line | no imports; direct Rig companion | optional copy/rename/modify, or replace with independently written `IVUX` | same MIT preservation and derived-file policy; do not treat its availability as permission for other interfaces |

Only these three Miner files are authorized. Approval of the repository entry does not approve the repository as a whole.

### Relevant files not authorized for v1 reuse

| file/group | classification | reason and boundary |
|---|---|---|
| `miner-manifold/contracts/Strategy.sol` | `DEFERRED_NOT_V1` | byte-identical to pinned LSG `Strategy.sol`; declares Euler ancestry; not required by launch core |
| `miner-manifold/contracts/Hopper.sol` | `REFERENCE_ONLY` | Hard Reserve replaces the launch role; no redemption/accounting and no reason to copy it |
| `miner-manifold/contracts/Router.sol`, `Multicall.sol`, `interfaces/IRig.sol`, tests | `REFERENCE_ONLY` | old interfaces/fee paths and settlement behavior do not match canonical v1; write periphery/tests from VUX authorities |
| Miner/LSG `Voter.sol`, `Bribe.sol` and connected factories/interfaces | `PROHIBITED_PENDING_CLEARANCE` | named Solidly/Synthetix ancestry lacks exact repository/commit/path and is not launch-critical |
| LSG `RevenueRouter.sol` and other LSG files | `DEFERRED_NOT_V1` | LSG inactive at genesis; no v1 import |
| Euler `src/FeeFlowController.sol` | `V1_SOURCE_ANCESTOR` (transitive only) | licence/provenance basis for Rig auction lineage; do not directly copy the whole file or its EVC/Solmate imports |
| gumball `Fund.sol`, `LiquidityPosition.sol`, `Strategy.sol`, `ResonanceRouter.sol`, all core/interfaces | `REFERENCE_ONLY` | unresolved repository licence/release state; v1 behavior can be implemented independently from the canonical specification |
| give.fun listed contracts | `REFERENCE_ONLY` | transitive gumball/auction provenance only; no v1 use |
| Olympus v3 code and Olympus docs prose | `REFERENCE_ONLY` | policy shapes only; no literal or close port required |

## 6. Miner Manifold clearance

### Exact-pin census

At [`bcffbf1eb963810acb14a1fd1c73d03a53a085a8`](https://github.com/Heesho/miner-manifold/commit/bcffbf1eb963810acb14a1fd1c73d03a53a085a8):

- there is no tracked root `LICENSE`, `LICENSE.*`, `LICENCE`, `COPYING`, or `NOTICE`;
- [`README.md`](https://raw.githubusercontent.com/Heesho/miner-manifold/bcffbf1eb963810acb14a1fd1c73d03a53a085a8/README.md) says “MIT License” but points to a non-existent root file;
- [`Rig.sol`](https://raw.githubusercontent.com/Heesho/miner-manifold/bcffbf1eb963810acb14a1fd1c73d03a53a085a8/contracts/Rig.sol), [`Unit.sol`](https://raw.githubusercontent.com/Heesho/miner-manifold/bcffbf1eb963810acb14a1fd1c73d03a53a085a8/contracts/Unit.sol), and [`IUnit.sol`](https://raw.githubusercontent.com/Heesho/miner-manifold/bcffbf1eb963810acb14a1fd1c73d03a53a085a8/contracts/interfaces/IUnit.sol) each carry `SPDX-License-Identifier: MIT`;
- the three files have only the pinned initial commit in their file history; blame attributes their lines to Heesho;
- the initial commit metadata also says `Co-Authored-By: Claude Opus 4.5`; this is recorded as source-generation provenance, not treated as evidence of a separate human copyright holder;
- there are no Git submodules or vendored source trees;
- `package.json` requests `@openzeppelin/contracts ^4.8.0`; `yarn.lock` resolves package `4.9.6`. That resolution describes the ancestor build only.

### Rig ancestry correction

Earlier research said `Rig.sol` declared no third-party ancestry. That statement is literally true about its comments but insufficient about its code lineage.

The same root commit contains `Strategy.sol`, which expressly says it is “forked and modified from Euler Finance's FeeFlow.” That Miner file is the exact same Git blob (`c86b6f6550851f9f2504a25290021d4beaa92f39`) as the earlier LSG `Strategy.sol`. `Rig.sol` then repeats the distinctive state-transition skeleton visible in the LSG/Euler chain:

- deadline and epoch-ID guards;
- slippage maximum;
- `type(uint192).max` price bound;
- settlement-price × multiplier next-opening calculation;
- upper/lower clamps;
- unchecked epoch increment;
- epoch timestamp reset; and
- the same linear `initPrice - initPrice * timePassed / epochPeriod` decay form.

No commit history proves the exact copy operation or exact historical Euler revision used. The similarity and sibling-file evidence are strong enough that the safe engineering posture is to **treat the Rig auction portions as GPL-descended**, not to rely on the Rig MIT header as proof of clean authorship. The matching frozen Euler evidence source is `FeeFlowController.sol@3bee858a1568d1313f37d615953f83391a897866`.

### Permission basis and scope

The clearance basis is cumulative:

1. file-level MIT SPDX declarations for Heesho-controlled material;
2. operator-supplied `COLLABORATOR_PERMISSION` from Heesho — “go for it!” — for Miner Manifold core changes/additions, limited to rights Heesho controls; and
3. Euler's `GPL-2.0-or-later` grant for the conservatively attributed auction lineage, with GPLv3 selected for VUX.

The direct permission does not relicense Euler, Solidly, Synthetix, or any other third-party material. It need not: Euler's existing `-or-later` GPL grant supplies a GPLv3-compatible path. Preserve the original permission message/screenshot in private operational records; a new Heesho grant is not a launch gate for this allowlist.

### Loa boundary

Loa may start from the three allowlisted files only. It must not clone/copy the whole Miner repository into VUX, import old tests as v1 tests, or bring Hopper/governance/Strategy code into the build. The final Rig will be materially different and must be labelled as a derivative with preserved lineage, not as solely VUX-authored code.

## 7. Hard Reserve clean-source posture

The v1 Hard Reserve is **VUX-original implementation from the canonical specification**.

Its source authority is the frozen behavior:

```text
B = canonical WETH balance at Reserve
S = VUX totalSupply before redemption
payout = floor(B * q / S)
S_MIN = 1 raw VUX unit
```

No gumball source file is needed to implement those equations and invariants. Loa must not copy, selectively port, or edit-down:

- `gumball6900/.../Fund.sol`;
- `IFund.sol`;
- `GBX.sol` redemption helpers;
- basket-selection, transient-storage duplicate detection, successor, or migration code; or
- a later gumball Fund revision.

The mathematical idea of pre-burn supply and floor-rounded pro-rata redemption is reference context, not code permission. The VUX implementation must be written directly from the canonical specification, use VUX-selected cleared dependencies, and contain none of Fund's multi-asset/migration structure. If implementation review later finds material line/structure similarity to Fund, the file must be reclassified as derived and re-cleared before merge.

## 8. VEM clean-source posture

VEM is **VUX-original mathematical/policy implementation from the accepted VUX authorities**:

```text
Qsafe = floor(D * S_pre / B_pre)
Qmint = min(Qraw, Qsafe)
B_pre * Qmint <= D * S_pre
```

VEM is not attributed to Olympus and does not require an Olympus Emission Manager source file. It also does not require Miner/LSG/Euler `Strategy.sol`; the only FeeFlow lineage retained in v1 is the existing Dutch-auction skeleton carried through Miner Rig.

Full-precision multiplication/division is a dependency capability, not permission to copy arithmetic from Olympus or gumball. The SDD must select and pin the exact cleared library release before coding. Any VEM file written from the equations and settlement order in the canonical specification uses `GPL-3.0-or-later` alone unless it is physically incorporated into the Miner-derived Rig file, in which case the Rig derived-file SPDX policy applies.

## 9. Strategy / Euler FeeFlow lineage

The evidence chain is:

```text
Euler FeeFlow
  euler-xyz/fee-flow@3bee858a1568d1313f37d615953f83391a897866
  src/FeeFlowController.sol
  SPDX: GPL-2.0-or-later
        |
        +-- explicit fork statement
            LSG contracts/Strategy.sol@14b5fbbbe1945f2e6501f84976e5f12b39fb227a
            file says MIT, but MIT cannot erase inherited Euler GPL terms
                    |
                    +-- exact same Git blob in Miner Manifold Strategy.sol
                            |
                            +-- distinctive auction skeleton repeated in Miner Rig.sol
                                (material lineage inferred; exact copy event/revision not proven)

  separate explicit branch:
  give.fun Auction.sol@ef6ee14a454432210d13e312d0ef825f670bd79d
  says forked and modified from Euler Fee Flow
```

Primary evidence: [`FeeFlowController.sol`](https://raw.githubusercontent.com/euler-xyz/fee-flow/3bee858a1568d1313f37d615953f83391a897866/src/FeeFlowController.sol) states `GPL-2.0-or-later` and `@author Euler Labs`; the exact-pin [GPLv2 licence text](https://raw.githubusercontent.com/euler-xyz/fee-flow/3bee858a1568d1313f37d615953f83391a897866/LICENSE) is present; pinned [LSG Strategy](https://raw.githubusercontent.com/Heesho/liquid-signal-governance/14b5fbbbe1945f2e6501f84976e5f12b39fb227a/contracts/Strategy.sol) names FeeFlow; and gumball's pinned [`NOTICE`](https://raw.githubusercontent.com/Heesho/gumball6900/4d0883cc2954f773c1e2d84d6e54c3930b09341e/NOTICE) identifies the same full Euler pin and GPL expression.

Disposition:

- Euler is a conservative transitive `V1_SOURCE_ANCESTOR` for the Rig auction portions.
- Direct `Strategy.sol` use is `DEFERRED_NOT_V1`; it is not in the launch build.
- `GPL-2.0-or-later` allows the GPLv3 selection required by VUX. Preserve Euler credit, licence history, source pin, modification notices/dates, and corresponding-source obligations.
- A future Strategy can have a clean compatible path by starting from the pinned Euler GPL source or properly treating the Heesho adaptations as GPL-descended, but it still requires a new v1.1 provenance delta and dependency review. No future Strategy approval is granted here.

## 10. gumball6900 disposition

`Heesho/gumball6900@4d0883cc2954f773c1e2d84d6e54c3930b09341e` is `REFERENCE_ONLY`.

Exact-pin findings:

- no root `LICENSE`, `LICENCE`, or `COPYING`;
- root `NOTICE` expressly says it does not select or grant a repository licence and that the rebuild is not release-authorized;
- core Solidity files display `MIT` SPDX lines while the same NOTICE says original GBX adaptations retain BUSL-1.1 headers pending counsel — an internal provenance/licence inconsistency that this node does not resolve;
- NOTICE identifies give.fun, LSG, Euler FeeFlow, and unresolved Solidly/Synthetix ancestry;
- no git submodules; a vendored `forge-std` tree contains Apache-2.0 and MIT licence files, but it is not relevant to VUX because no gumball source is imported.

Copy boundaries:

- `Fund.sol`: no copy, port, edit-down, or derivative; WETH-only Reserve is original.
- `LiquidityPosition.sol`: no fee-routing copy; v1 routing is specified and implemented independently.
- `Strategy.sol`, `ResonanceRouter.sol`, SDK/ABI/generated docs, tests, scripts, and interfaces: no copy/import.
- Concepts may be named in research/provenance; code and prose may not enter VUX without a separate re-clearance.

## 11. LSG disposition

`Heesho/liquid-signal-governance@14b5fbbbe1945f2e6501f84976e5f12b39fb227a` is `DEFERRED_NOT_V1`.

The exact pin has no root licence/notice and its README points to a missing `LICENSE`. Solidity files carry MIT SPDX lines, but:

- `Strategy.sol` declares Euler FeeFlow ancestry and must be treated under the inherited GPL path;
- `Voter.sol` declares Solidly ancestry without an exact repository/commit/path;
- `Bribe.sol` declares Synthetix StakingRewards ancestry without an exact repository/commit/path;
- there are no submodules.

LSG is inactive at genesis and not imported by v1. `RevenueRouter.sol` and other apparently simple files remain deferred because no launch requirement justifies expanding the source surface. `Voter.sol` and `Bribe.sol` are additionally `PROHIBITED_PENDING_CLEARANCE` until their named ancestors are pinned and cleared. A future LSG review must be independent of this launch freeze.

## 12. Olympus disposition

Olympus is `REFERENCE_ONLY`.

- `OlympusDAO/olympus-v3@a686d715bf572a60156a39f9c9af69d5208ca8be` has no root licence file at the pin. Relevant policy/module files use legacy `AGPL-3.0` text or `AGPL-3.0-only`. The tracked `.gitmodules` file is empty and no gitlinks exist.
- `OlympusDAO/olympus-docs@4256dd3ffc20747426cbd9e89a1d93849ea968e2` has a root MIT licence naming `Copyright (c) 2022 OlympusDAO`.
- VUX borrowed policy shapes and research language: support expansion economically, spend realized income not principal, burn repurchased protocol token, and isolate policy failure. No Olympus source implementation is needed.

Loa must not copy Olympus Emission Manager, Yield Repurchase Facility, Heart, Kernel, Treasury, POL policy, tests, interfaces, or documentation prose. If a future implementation proposes Olympus code, AGPL and file-level notice consequences require a new review; this root GPL-only posture does not silently absorb AGPL code.

## 13. Dependency-family licence census

### Approved family, implementation pin still open

| dependency family | classification | licence family | current authority | SDD gate |
|---|---|---|---|---|
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) | `V1_DEPENDENCY` | MIT (for example, both exact upstream [v4.9.6](https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.6/LICENSE) and [v5.6.1](https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.6.1/LICENSE) carry MIT licence files) | family cleared; **no VUX version selected here** | SDD must choose an exact release, resolve it to an immutable commit or package-integrity digest, record imported paths, confirm compiler/API compatibility, and preserve the selected release's exact notice before coding |

Miner's lockfile resolving OpenZeppelin 4.9.6 is ancestor-build evidence, not a VUX dependency decision. Earlier research mentioning 5.6.1 for `Math.mul512` is also not a decision. Loa may select either or another suitable cleared release during architecture, but may not use a range such as `^x.y.z` as the production authority.

Canonical RH WETH is an external deployed runtime contract, not source copied or linked into VUX. Interact through a cleared interface; do not vendor its implementation. The AMM/POL venue and toolchain are unselected. If the SDD chooses Uniswap or any other periphery/library import, it must perform and record an exact version/file licence census before implementation; gumball's dependency manifest is not authority for VUX.

### Compatibility rules for future SDD selection

| expression/family | consequence for a `GPL-3.0-or-later` VUX work |
|---|---|
| `MIT`, `BSD-2-Clause`, `BSD-3-Clause` | compatible; preserve copyright, permission, warranty, and non-endorsement notices as applicable |
| `Apache-2.0` | compatible with GPLv3, not a reason to omit Apache patent/NOTICE/modified-file duties; preserve any upstream NOTICE |
| `LGPL-2.1-*`, `LGPL-3.0-*` | potentially compatible but library/linking/relinking/source duties are component-specific; requires SDD file-level review, not automatic approval |
| `GPL-2.0-only` | incompatible with the intended GPLv3 combined-work posture; exclude or obtain a separate compatible grant |
| `GPL-2.0-or-later` | compatible by choosing GPLv3; retain original expression/provenance and comply with GPLv3 for the combined work |
| `GPL-3.0-only` | compatible only at GPLv3, but would prevent an unqualified whole-work “or later” grant for that component; requires explicit mixed-version treatment or exclusion |
| `GPL-3.0-or-later` | directly compatible |
| `AGPL-3.0-*` | GPLv3 section 13 permits a combination but AGPL network-source requirements apply to the combination; not approved for the clean GPL-only v1 surface |
| `UNLICENSED`, no grant, ambiguous custom notice, BUSL/source-available | public visibility is not permission; prohibit pending exact review/permission |

Official reference points: [SPDX licence identifiers and expressions](https://spdx.dev/learn/handling-license-info/), [FSF licence list/compatibility commentary](https://www.gnu.org/licenses/license-list.en.html), [Apache-2.0 text](https://www.apache.org/licenses/LICENSE-2.0), and [BSD-3-Clause](https://spdx.org/licenses/BSD-3-Clause.html).

## 14. Required copyright / attribution / notices

When the authority is later imported into `C:\Users\0x007\vux`, Loa must require all of the following before release:

1. **Root `LICENSE`:** unmodified GNU GPL version 3 text. README/package metadata must state `GPL-3.0-or-later`, not merely “GPL” or “GPL-3.0”.
2. **Root `THIRD_PARTY_NOTICES.md`:** include:
   - Miner repository URL, full SHA, exact allowlisted paths, upstream `MIT`, and preserved `@author heesho` credit;
   - Euler repository URL, full SHA, `src/FeeFlowController.sol`, `GPL-2.0-or-later`, and `@author Euler Labs`, plus the statement that VUX selects GPLv3 under the later-version option;
   - the complete MIT permission/warranty text applicable to the reused Miner material, without inventing a missing upstream copyright holder;
   - each actual implementation dependency's exact release/pin and verbatim required copyright/licence/NOTICE material.
3. **Derived source headers:** state the upstream repository/path/full SHA, original licence expression(s), VUX modification date, and pointer to `THIRD_PARTY_NOTICES.md`. Preserve author/source comments; do not claim sole VUX authorship.
4. **GPL source duties:** when conveying source or object/bytecode copies, keep licence/no-warranty notices and provide the corresponding preferred source plus build/deployment scripts needed to reproduce the conveyed code in the manner GPLv3 requires. The precise legal treatment of a chain deployment can be jurisdiction/fact dependent; the project should publish complete source regardless.
5. **Permission evidence:** preserve the original Heesho “go for it!” message/screenshot privately as `COLLABORATOR_PERMISSION`, scoped only to grantor-controlled rights. It need not be published in the public repository.

No document or header may invent `Copyright (c) Heesho`, a VUX company/entity, the founders, or any other holder. A verified holder may add its own notice later.

## 15. SPDX policy

Apply these rules exactly during the later authority-import/bootstrap and implementation lifecycle:

| file condition | SPDX treatment |
|---|---|
| wholly VUX-original Solidity written from the canonical specification | `// SPDX-License-Identifier: GPL-3.0-or-later` |
| materially derived/ported from Miner `Rig.sol` | `// SPDX-License-Identifier: MIT AND GPL-3.0-or-later` plus the Miner/Euler provenance and dated modification comment |
| materially derived/ported from Miner `Unit.sol` or `IUnit.sol` | `// SPDX-License-Identifier: MIT AND GPL-3.0-or-later` plus Miner provenance and dated modification comment |
| byte-for-byte unmodified allowed MIT file | retain `// SPDX-License-Identifier: MIT`; the aggregate/project remains GPL, and the third-party notice remains required |
| third-party dependency file kept in source form | retain its upstream SPDX/copyright headers verbatim; do not bulk-rewrite to GPL |

`AND` is intentional: SPDX defines it to mean the recipient must comply with both applicable terms. For the Rig lineage, the original Euler expression remains recorded as `GPL-2.0-or-later`; VUX selects GPLv3 for the derived combined file and preserves the MIT obligations for Heesho material. Do not use bare/deprecated `GPL-3.0`, do not change `-or-later` to `-only`, and do not leave a lone `MIT` header on a materially GPL-derived VUX Rig.

If Loa independently implements a component from the canonical specification without copying/porting protected expression, use the VUX-original rule and record the reference repositories only in this freeze, not in that file's ancestry header. Superficial renaming or line shuffling is not independent implementation.

## 16. Prohibited source actions

Loa and later implementation agents must not:

1. fetch or copy `main`, `master`, `HEAD`, `latest`, a tag without resolved commit, or a newer upstream revision as source authority;
2. copy/modify any Miner file outside the three-file allowlist;
3. copy Miner or LSG `Strategy.sol` into v1;
4. copy Miner `Hopper.sol`, `Router.sol`, `Multicall.sol`, `IRig.sol`, or upstream tests into the v1 build/test source;
5. copy/derive/import any LSG voting, bribe, strategy, router, or governance file into v1;
6. copy, edit-down, translate, or structurally port gumball `Fund.sol`, `LiquidityPosition.sol`, `Strategy.sol`, fee routing, interfaces, tests, SDK, or generated ABI code;
7. copy Olympus code or documentation prose;
8. copy give.fun code or use it as a substitute source pin;
9. vendor an entire upstream repository or its unused dependency tree;
10. treat an SPDX line as proof that its committer owned third-party material, or treat collaborator permission as waiving Euler/Solidly/Synthetix rights;
11. import source with no valid grant, ambiguous BUSL/custom state, `GPL-2.0-only`, or AGPL into v1 without a new clearance;
12. select an OpenZeppelin/AMM/toolchain version implicitly during implementation; the SDD must pin first;
13. erase notices, claim sole authorship, obfuscate derivation, or perform superficial rewrites to avoid copyleft; or
14. change either frozen registry artifact without an explicit provenance delta.

## 17. Source-update policy

A source/reference pin may change only through an explicit provenance delta that:

1. names the old and proposed full 40-character SHAs and why the change is needed;
2. diffs every authorized/relevant file and import graph;
3. repeats the root/file licence, copyright, NOTICE, vendored-code, submodule, and dependency-manifest census at the proposed commit;
4. rechecks material ancestry and licence compatibility;
5. records changed notices/SPDX/permission scope;
6. updates both this Markdown authority and the JSON registry atomically;
7. receives explicit operator approval before Loa uses the new source; and
8. forbids the old/new pin mixture in one implementation unless separately reviewed.

Implementation dependencies are a separate pin class. The SDD may select OpenZeppelin or another library version without changing these source/reference pins, but it must record an immutable release commit/package integrity, exact imports, licence/notice state, and compiler compatibility **before** code is written. A later routine dependency update still requires its own dependency provenance delta.

## 18. Red-team results

| challenge | result |
|---|---|
| Does `Rig.sol` contain copied code not disclosed in its comments/SPDX? | **Likely/materially yes for the auction skeleton.** Sibling `Strategy.sol` expressly descends from Euler, is byte-identical to earlier LSG Strategy, and Rig repeats the distinctive guards/reset/clamp/decay sequence. Exact copy event/revision is not proven; GPL lineage is applied conservatively. |
| Does `Unit.sol` contain third-party ancestry? | No specific ancestor found beyond explicit OpenZeppelin inheritance/imports. File history is one Heesho commit, file says MIT, and no embedded fork/adapted-from comment exists. This is not proof of exclusive authorship; permission is limited accordingly. |
| Do Miner imports change posture? | Rig/Unit require MIT OpenZeppelin family code and optional local `IUnit`. They do not import Miner Strategy, Hopper, LSG, Solmate, or EVC. Exact VUX OpenZeppelin release remains an SDD gate. |
| Is `Strategy.sol` avoidable in v1? | Yes. Canonical v1 has no auctioned revenue conversion/active LSG. No v1 file may import it. |
| Are useful KOTH functions trapped in another unresolved file? | No launch-critical behavior requires Hopper/Router/Multicall/Strategy. The useful auction skeleton is already in allowlisted Rig; its discovered GPL lineage is compatible and recorded. |
| Is Reserve effectively a `Fund.sol` derivative? | No VUX code exists yet. The clean-source rule makes it original from the canonical single-asset equations and explicitly forbids Fund structure/code. Similarity must be rechecked during review. |
| Is VYRF/POL fee-routing code copied from gumball? | No. Canonical revenue classification is sufficient; gumball routing is prohibited. |
| Do Heesho MIT files contain GPL-derived material? | Yes in Strategy explicitly, and likely in Rig's auction skeleton. A lone MIT header is not relied upon to erase the Euler grant. |
| Does any required lineage use `GPL-2.0-only`? | No. Required Euler evidence says `GPL-2.0-or-later`. |
| Does any required source have no grant? | The Miner repo lacks a root licence, but each allowlisted file has MIT SPDX evidence, supplemented by collaborator permission; Rig's third-party lineage has an independent GPL grant. Repos with unresolved/no repo grants are excluded from copying. |
| Vendored dependencies/submodules? | Miner, LSG, gumball, Olympus docs: no gitlinks. Gumball vendors forge-std but VUX imports none. Olympus `.gitmodules` is empty. FeeFlow has EVC/forge-std/Solmate gitlinks, but direct FeeFlow copying is prohibited and those imports do not accompany Miner Rig. |
| Would copying a whole repo drag unnecessary terms? | Yes. Default deny and file allowlist prohibit it. |
| Could Loa accidentally fetch HEAD? | Prevented by full-SHA registry, default deny, and refreeze rule; Loa must encode these checks in planning/SDD. |
| Is the root GPL claim too broad for every file header? | Yes if interpreted as a bulk header rewrite. VUX-original files use GPL; derived files use the §15 layered expression; unmodified permissive dependencies retain their own SPDX. |
| Are notices preserved under combined GPL distribution? | Mandatory under §§14–15. GPL project status does not cancel MIT/Apache/BSD or upstream attribution duties. |

Residual epistemic limits, none launch-blocking under the conservative treatment:

- The precise historical Euler commit from which Heesho derived Strategy/Rig is not proven. `3bee858a1568d1313f37d615953f83391a897866` is the immutable matching source/licence evidence pin identified by gumball NOTICE, not a fabricated claim about the historical copy event.
- The original Heesho permission message is not stored in this workspace; its summary was supplied by the operator. Preserve the original privately.
- Miner was introduced as one root commit and records Claude Opus 4.5 as co-author, so Git history cannot expose earlier drafting steps. No additional public exact-match source was identified by the limited search; absence of a match is not proof of absence.

These limits do not block v1 because the implementation adopts the stricter known upstream GPL path, limits Heesho permission to grantor-controlled rights, and excludes unresolved Solidly/Synthetix/gumball/AGPL surfaces.

## 19. Loa authority handoff

When Loa later starts `/plan-and-analyze`, its PRD/SDD/sprint/implementation rules are:

1. Treat this file, the JSON registry, the canonical v1 specification, and founder parameter freeze as binding source authorities.
2. Copy/modify only the three Miner files in §5 and only from `bcffbf1eb963810acb14a1fd1c73d03a53a085a8`.
3. Treat the Rig auction skeleton as conservatively Euler-derived `GPL-2.0-or-later`, choose GPLv3 for VUX, and preserve all §14–15 notices.
4. Implement Hard Reserve, VEM, revenue routing, and periphery independently from the canonical VUX specification; do not start from gumball/Olympus/LSG code.
5. Keep Strategy/LSG/Crown/future treasury integrations outside the v1 build and dependency graph.
6. In the SDD, select and pin exact implementation dependency releases before coding; do not inherit Miner/gumball manifests by convenience.
7. Make the build fail or review fail if an upstream URL is mutable, a SHA is not 40 characters, a non-allowlisted upstream file appears, a required notice is absent, or a dependency lacks an immutable pin.
8. Carry file-level provenance into code headers, `THIRD_PARTY_NOTICES.md`, review checklists, and release artifacts; do not defer attribution to the end.
9. Any new source ancestor, literal code reference, generated/vendored source, or pin change stops implementation until a provenance delta is approved.

This is a source authority, not a contract decomposition. It does not choose the exact OpenZeppelin release, AMM venue, toolchain, contract count, or implementation architecture reserved to the SDD.

## 20. Founder/operator decisions

**NONE.**

The newly discovered Rig/FeeFlow ancestry creates no founder licence choice because the frozen project posture is already GPL-3.0-or-later and the upstream grant is GPL-2.0-or-later. No product/economic/architecture decision is reopened.

Administrative action only: preserve the original Heesho permission message/screenshot in private operational records.

**Transition:** VUX may proceed to Loa `/plan-and-analyze` after this freeze is accepted/imported. Do not import it into `C:\Users\0x007\vux`, create the root licence/notices, or start Loa in this node.
