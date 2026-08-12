# Sprint 2 Implementation Report — VUX Token & Hard Reserve (Exit-Right Primitives)

**Cycle:** cycle-002 "VUX v1 Strategic Treasury"
**Sprint:** local `sprint-2` = global `sprint-2`
**Node:** `/implement sprint-2` (operator-dispatched)
**Date:** 2026-08-11
**Starting repository identity:** `master == origin/master == 79c966f6c55899489fdb9db176773ef69e6ecf62`
**Branch:** `master` (working tree; no commit, push, or tag — not authorized by this node)

> **Remediation pass appended 2026-08-11.** After this report was written, Sprint 2 was
> reviewed **APPROVED** and audited **APPROVED** with one MEDIUM finding (**A-1**, provenance
> tooling) and three LOW. A narrowly bounded `/implement sprint-2` node then closed A-1. See
> **[Remediation pass — Security Audit Feedback Addressed (A-1, MEDIUM)](#remediation-pass--security-audit-feedback-addressed-a-1-medium)**
> at the end of this document. Everything above is the original node's report and is unchanged;
> no product code or test was touched by the remediation.

**Scope input:** `grimoires/loa/a2a/sprint-2/sprint-2-scope.md` — a byte-exact
`sed -n '174,225p'` slice of `grimoires/loa/sprint.md`
(SHA-256 `c5060bff3fc9bbc7a2776b1e9b15ffe4ff276139798bf87588d543b084c8d508`).

---

## Executive Summary

Sprint 2 lands the two narrow-authority monetary primitives complete: `VUX.sol`
(ERC20 + ERC20Permit, `mint` gated to an immutable `rig`, `burnForRedemption`
gated to an immutable `reserve`, no general `burnFrom`, exact genesis mint) and
`HardReserve.sol` (ownerless, one-transaction approval-free
`floor(B × q / S)` redemption with full-precision arithmetic, `S_MIN`
preservation, and constructor-time contamination sanitization that provably does
not survive deployment). Both were built against the accepted authority only:
the token from the allowlisted Miner Manifold surface plus vendored
OpenZeppelin, the Reserve as VUX-original clean source from the canonical
equations.

All **7 Sprint-2 acceptance criteria are met**. The scoped AC validator exits 0.
The complete accumulated provenance suite (now 8 gates) is green, `forge test`
is **61/61** (11 carried from Sprint 1, 50 new), and the property suites pass at
the SDD's CI fuzz depth of **10,000 runs** each.

Two things are worth the reviewer's attention up front:

1. **The Sprint-1 audit residue N-1 is closed first**, before the first line of
   product Solidity, as the node required. The default-deny source boundary now
   makes its prune of the git-trackable Loa zones *conditional* on those zones
   containing no Solidity at all, and the fence is negative-demonstrated by a
   seventh probe in the existing CI demonstration.
2. **Structural absence is asserted against compiled output, not source text**,
   by two independent implementations that agree — a Solidity opcode/ABI walk
   inside `forge test`, and a jq+awk gate that shares no code with it. "There is
   no sweep function in the source" is something a reviewer can already see; it
   is also exactly what a capability arriving via inheritance, a fallback, or a
   `delegatecall` would look like.

No new dependency was added; `forge-std` is not present. No Sprint-3+ mechanism
was implemented. No accepted authority artifact was modified — all five
authority hashes re-verified byte-identical at node close.

---

## AC Verification

Every acceptance criterion from the Sprint-2 section of `grimoires/loa/sprint.md`,
quoted verbatim.

### AC-1

> - [ ] INV-1…5 unit-tested: complete-supply truth; exact genesis constructor amounts; mint gated to the immutable `rig` address; no discretionary mint/burn path (prd.md:L581-L587)

**Status:** ✓ Met

**Evidence:** test/token/VuxToken.t.sol:121 — `test_TotalSupplyIsCompleteWithNoProtocolExclusion` asserts `totalSupply()` equals the sum of every balance *including the Reserve's seed* (INV-1, no protocol-balance exclusion).

Supporting per-invariant evidence:

| INV | Claim | Where |
|---|---|---|
| 1 | complete-supply truth | `test/token/VuxToken.t.sol:121` |
| 2 | genesis supply is exactly `150_000e18 + 1` | `test/token/VuxToken.t.sol:82`; constants at `src/VUX.sol:75` and `src/VUX.sol:79` |
| 2 | exact constructor amounts | `test/token/VuxToken.t.sol:75`; mints at `src/VUX.sol:95` |
| 3 | zero to every other address | `test/token/VuxToken.t.sol:92` — enumerates the constructor's **complete** log set: exactly 2 mints, exactly 2 recipients, exactly the 2 accepted amounts. A third credited address would require a third `Transfer` from the zero address, so this is a universal claim rather than a spot check |
| 4 | mint gated to the immutable `rig` | `src/VUX.sol:108`; positive `test/token/VuxToken.t.sol:152`; fuzzed negative over all callers `test/token/VuxToken.t.sol:162` |
| 4 | `rig` is immutable | `src/VUX.sol:82`; `test/token/VuxToken.t.sol:170` |
| 5 | no discretionary mint/burn path | `test/token/VuxToken.t.sol:278` asserts the compiled external surface is **exactly** the 20-signature accepted set, so an unlisted authority cannot hide behind an unguessed name; `test/token/VuxToken.t.sol:296` names the classes explicitly |

### AC-2

> - [ ] `burnForRedemption` reverts for every caller except the immutable `reserve`; no `burnFrom` symbol exists in the ABI (sdd.md:L678; FR-7.4 "no approval gate", prd.md:L251)

**Status:** ✓ Met

**Evidence:** test/token/VuxToken.t.sol:190 — `testFuzz_BurnForRedemptionRevertsForEveryCallerExceptReserve` fuzzes the caller across the address space, asserting `NotReserve()` and an untouched victim balance; the gate itself is `src/VUX.sol:123`.

- No `burnFrom` in the compiled dispatcher table: `test/token/VuxToken.t.sol:248` (with a positive control proving the scan can find a burn signature that *is* present), and independently `tools/provenance/inspect-runtime-surface.sh:118` (burn-family check).
- Not dispatchable at runtime either: `test/token/VuxToken.t.sol:264`.
- An allowance cannot substitute for the gate: `test/token/VuxToken.t.sol:204`.
- Approval-free end-to-end: `test/reserve/HardReserveRedemption.t.sol:325` asserts the allowance is zero before the redemption and still zero afterwards.

**Method note (reviewer-relevant).** A whole-artifact text search for `burnFrom`
was implemented first and **rejected**: forge stores `rawMetadata`, which embeds
solc's `devdoc`, so the NatSpec sentence in `VUX.sol` that documents the
deletion put the string into the artifact. A test a comment can flip is not a
surface test. The claim is now scoped to `.methodIdentifiers`, which is exactly
the set of signatures the contract dispatches.

### AC-3

> - [ ] Property test ∀ tested `(B, S, q)`: `payout = floor(B×q/S)`, zero fee, Reserve-favoring rounding, pre-redemption values (prd.md:L425-L426); exhaustive-redemption test preserves `S_MIN = 1` raw and a positive WETH remainder (prd.md:L253)

**Status:** ✓ Met

**Evidence:** test/reserve/HardReserveRedemption.t.sol:110 — `testFuzz_PayoutIsFloorOfBTimesQOverS` asserts `payout == (b * q) / s` computed natively, i.e. by an oracle independent of the `Math.mulDiv` under test, plus zero fee (Reserve delta == recipient delta, WETH total supply unchanged), exact `q` burned, and both rounding bounds `payout·s <= b·q < (payout+1)·s`.

| Property | Where |
|---|---|
| exact floor, native domain (independent oracle) | `test/reserve/HardReserveRedemption.t.sol:110` |
| exact floor where `B × q` overflows uint256 | `test/reserve/HardReserveRedemption.t.sol:159` — writes `B = A·S + rem` so the expectation is `A·q + floor(rem·q/S)`, computable without ever forming the overflowing product; the test **asserts** it is in the overflow domain (`q > type(uint256).max / b`) rather than assuming it |
| a naive `B * q` would revert on inputs `redeem` handles | `test/reserve/HardReserveRedemption.t.sol:187` |
| zero fee / conservation | `test/reserve/HardReserveRedemption.t.sol:110` (WETH `totalSupply` unchanged; recipient gain == Reserve loss) |
| Reserve-favoring rounding, concretely | `test/reserve/HardReserveRedemption.t.sol:209` — `floor(10×1/3) = 3`, remainder 7 stays |
| pre-redemption values | `test/reserve/HardReserveRedemption.t.sol:66` — `B=10, S=4, q=2` pays **5**; a post-burn computation would pay 10. This is the discriminating case, not a coincidence-tolerant one |
| the log lets an indexer re-derive the payout | `test/reserve/HardReserveRedemption.t.sol:80` |
| `S_MIN` rejection at the boundary | `test/reserve/HardReserveRedemption.t.sol:237` — `redeem(S)` reverts `SupplyFloor(S, S-1)`; enforcement at `src/HardReserve.sol:165` |
| exhaustive redemption leaves `S_MIN` and a positive remainder | `test/reserve/HardReserveRedemption.t.sol:249` — fuzzed; ends at `totalSupply() == 1`, the seed still held by the Reserve, `backing() > 0`, and `B/S` still well defined |
| `previewRedeem` agrees with the payout | `test/reserve/HardReserveRedemption.t.sol:219` |

Implementation: `src/HardReserve.sol:167` (`Math.mulDiv`, 512-bit intermediate).
CI fuzz depth is 10,000 runs per property (`foundry.toml` `[profile.ci]`);
recorded run below.

### AC-4

> - [ ] Reserve external surface is exactly `redeem` + views: no owner, roles, pause, upgrade, arbitrary call, approval, sweep, receive-hook, selfdestruct, payable path (FR-7.2, INV-14) — verified by ABI enumeration + review checklist

**Status:** ✓ Met

**Evidence:** test/reserve/HardReserveSurface.t.sol:231 — `test_ExternalSurfaceIsExactlyRedeemPlusViews` asserts the compiled `.methodIdentifiers` set is exactly `{redeem(uint256,address), backing(), previewRedeem(uint256), weth(), vux(), S_MIN()}`, both directions (nothing missing, nothing extra).

- Named prohibited-authority negatives: `test/reserve/HardReserveSurface.t.sol:250` (16 signatures).
- Exactly one state-changing function, from ABI `stateMutability`: `tools/provenance/inspect-runtime-surface.sh:99`.
- No payable entry, no `receive`, no `fallback` in the ABI: `tools/provenance/inspect-runtime-surface.sh:106` and `:110`; behaviourally `test/reserve/HardReserveSurface.t.sol:277` (bare value transfer, unknown selector, and value-bearing `redeem` all revert; the Reserve's ether balance stays 0).
- No `SELFDESTRUCT`, `DELEGATECALL`, `CALLCODE`, `CREATE`, `CREATE2` in the deployed runtime: `test/reserve/HardReserveSurface.t.sol:199`.
- The seed is unreachable: `test/reserve/HardReserveSurface.t.sol:300`.
- Review checklist: `grimoires/loa/a2a/sprint-2/evidence/structural-absence-checklist.md:35` (17 rows for the Reserve, 6 for the token, plus 4 items explicitly recorded as settled by inspection rather than by test).

### AC-5

> - [ ] Constructor sanitization proven: prefunded predicted address → constructor transfers full amount to creator, emits `PreGenesisWethSanitized`, requires born-empty; **runtime bytecode inspection proves no transfer-out/sweep path survives deployment** (sdd.md:L132)

**Status:** ✓ Met

**Evidence:** test/reserve/HardReserveSurface.t.sol:181 — `test_SanitizationMarkerIsInInitCodeAndNotInRuntimeCode` asserts the 32-byte `PreGenesisWethSanitized(uint256)` topic **is** present in `.bytecode.object` (positive control) and **is not** present in `.deployedBytecode.object`.

| Claim | Where |
|---|---|
| full amount to the creator, Reserve born empty | `test/reserve/HardReserveSurface.t.sol:91` — fuzzed to `type(uint128).max`, per the accepted rehearsal's "very large amount (not dust)" requirement; implementation `src/HardReserve.sol:114` |
| emits `PreGenesisWethSanitized` with the exact amount | `test/reserve/HardReserveSurface.t.sol:101`; emission `src/HardReserve.sol:115` |
| does **not** emit on a clean deployment (so the event distinguishes donations from founder capital) | `test/reserve/HardReserveSurface.t.sol:120` — log-exhaustive |
| born-empty `require` is live, not dead code | `test/reserve/HardReserveSurface.t.sol:136` — a token reporting success without moving the balance aborts construction with `NotBornEmpty(1 ether)`; check at `src/HardReserve.sol:122` |
| prefunding cannot distort the genesis target | `test/reserve/HardReserveSurface.t.sol:160` — 1,000,000 ether donation, then `B0` deposited, Reserve holds exactly `B0` |
| no upgrade/destruction/deployment opcode survives | `test/reserve/HardReserveSurface.t.sol:199` |
| the absence scan is not vacuous | `test/reserve/HardReserveSurface.t.sol:219` — asserts the metadata stripper removed a tail and not the program; the opcode walk is validated against `CALL` and `STATICCALL`, which must be present |
| independent second implementation | `tools/provenance/inspect-runtime-surface.sh:1` — jq + awk, no Solidity, no test runner; recomputes the event topic with `cast keccak` and reproduces the same findings |

Recorded runtime census (creation 4,736 bytes; runtime 3,252 bytes; 3,199 after
stripping the 53-byte metadata tail):

```
body=3199 create=0 callcode=0 delegatecall=0 create2=0 selfdestruct=0 call=2 staticcall=5
```

The two `CALL` sites are the redemption burn and the WETH payout; the five
`STATICCALL`s are `balanceOf`/`totalSupply` reads.

### AC-6

> - [ ] Reserve code passes only `msg.sender` to `burnForRedemption` — negative test proves it cannot burn a third party (sdd.md:L130)

**Status:** ✓ Met

**Evidence:** test/reserve/HardReserveRedemption.t.sol:282 — `test_RedeemerWithNoBalanceCannotDrainAnotherHoldersVux`: an attacker holding zero VUX calls `redeem(1000, attacker)` while the contract system holds a large victim balance, and the call reverts with `ERC20InsufficientBalance`. If the burn source were ever attacker-influenceable, this call would succeed.

- The literal call site: `src/HardReserve.sol:169` — `vux.burnForRedemption(msg.sender, q)`; `msg.sender` is not a parameter and is not derived from one.
- A successful redemption burns only the caller's own VUX: `test/reserve/HardReserveRedemption.t.sol:296`.
- The independent token-side barrier rejects a direct call: `test/reserve/HardReserveRedemption.t.sol:310` and the fuzzed `test/token/VuxToken.t.sol:190`.

### AC-7

> - [ ] PROV-5 similarity statement recorded: Hard Reserve implemented from the canonical equations; no prohibited source consulted (prd.md:L764)

**Status:** ✓ Met

**Evidence:** grimoires/loa/a2a/sprint-2/evidence/prov-5-similarity-review.md:9 — the required statement, the enumerated list of sources not consulted, and a post-hoc structural similarity assessment concluding that the only convergence with any pro-rata redemption implementation is arithmetic whose form the specification itself determines, while every element with design freedom diverges.

Corroborating: `src/HardReserve.sol:33` records the same classification in the
contract header (deliberately without naming the prohibited projects, since
naming them in Solidity would trip the repository's own prohibited-source
detector at `tools/provenance/verify-census.sh:157`, which is green).

---

## Precondition — Sprint-1 audit residue N-1, closed before any product Solidity

**Finding (carried from `auditor-sprint-feedback.md:123`, LOW / deferred):**
`SOURCE_UNIVERSE_PRUNE` excluded `.claude grimoires .beads .run .ck` from the
default-deny source walk. Those zones are git-trackable, and the audit's own
reachability probe established that an out-of-root `.sol` **is** compiled and
emitted when a file inside a declared VUX root imports it explicitly. Sprint 1
was allowed to defer it because no product Solidity existed. Sprint 2 is where
it does.

**Fix — smallest structural change that removes the class, not the instance.**
The prune stays (walk cost), but it is split by *why*, and the Loa half becomes
**conditional**:

- `tools/provenance/census.sh:154` — `BUILD_ARTIFACT_PRUNE` (`.git out out-v3core cache cache-v3core broadcast`): generated or non-working-tree, nothing git-trackable, excluded unconditionally.
- `tools/provenance/census.sh:176` — `LOA_ZONE_PRUNE` (`.claude grimoires .beads .run .ck`): git-trackable, so excluded *only while provably Solidity-free*.
- `tools/provenance/census.sh:185` — `loa_zone_solidity()` enumerates any Solidity-shaped file in those zones. Matching is case-**in**sensitive here while the universe walk stays case-sensitive: this is a "nothing Solidity-shaped lives here" claim, and breadth is free when the only correct answer is zero.
- `tools/provenance/verify-census.sh:106` — consumes it and fails closed with the reason spelled out.

**What was deliberately NOT done.** VUX source authority was not expanded:
`VUX_SOURCE_ROOTS` remains exactly `src test script`, the 63-file census is
unchanged, and `grimoires/`, `.claude/` and friends did not become authorized
implementation roots. The zones were also not un-pruned — that would have been
the larger change, and it would have traded a closed hole for a slower walk
without improving the guarantee.

**Negative evidence (fence proven closed, then reopened).**
`tools/provenance/demo-boundary-negative.sh:171` adds probe 7. It cannot use a
probe *root* — the target directory holds real work — so it plants a single
file by exact path, refuses to run if that path already exists, and removes it
by exact path under the existing trap:

```
── probe 7 — unauthorized source inside a pruned Loa/state zone (audit N-1)
  planted: grimoires/loa/boundary-probe-zone.sol  (inside a pruned zone — invisible to the source walk)
  ok    verify-census.sh failed closed for the right reason [unclassifiable .sol in a pruned trackable zone] (exit 1)
          FAIL  Solidity inside a pruned Loa/state zone — unclassifiable by the source boundary yet build-reachable …
  ok    verify-census.sh green again after probe removal

── restoration
  ok    working-tree inventory identical to pre-probe state (43fee96a30393890253ff3af8617a333b7e1c8478c15386c7b815ade5fdda559)
  ok    probe root ./contracts removed
  ok    probe root ./lib removed
  ok    grimoires/loa/boundary-probe-zone.sol removed

Source-boundary fence proven closed on all 7 probes, and reopened.
```

*(Operational note for whoever runs this next: the inventory check compares
`git status --porcelain --untracked-files=all` before and after, so it reports a
mismatch if anything else writes to the tree while it runs. One intermediate run
during this node tripped exactly that — an editor writing `NOTES.md` in
parallel — with all three probe artifacts still correctly removed. The recorded
result above is from a quiescent re-run. This is the check behaving correctly,
but it is worth knowing before reading a red line as leftover dirt.)*

The demonstration runs as a CI job on every push
(`.github/workflows/provenance.yml:77`), so the fence is re-proven rather than
recorded once. Probe count 6 → 7.

**Scope discipline.** N-3 (symlink directories), N-4 (launch-secret coverage) and
N-5 (exact Foundry-commit assertion) were **not** touched — none is required for
Sprint-2 correctness, and the node scoped this precondition narrowly.

---

## Tasks Completed

### Task 2.1 — `VUX.sol`

`src/VUX.sol` (127 lines). ERC20 + ERC20Permit from the vendored OZ v5.2.0
census; **no** ERC20Votes, no upgrade surface, no roles.

- **Provenance.** SPDX `MIT AND GPL-3.0-or-later` with the mandatory
  `@custom:provenance miner-manifold` marker (`src/VUX.sol:43`), naming the
  allowlisted `contracts/Unit.sol` / `contracts/interfaces/IUnit.sol` at
  `bcffbf1eb963810acb14a1fd1c73d03a53a085a8`, and a dated
  `@custom:modifications 2026-08-11` block (`src/VUX.sol:56`) enumerating the six
  substantive departures from the ancestor. No holder statement is asserted;
  the upstream MIT notice lives in `THIRD_PARTY_NOTICES.md`.
- **Immutable authority.** `rig` (`:82`) and `reserve` (`:85`) are `immutable`;
  `setRig` and the ancestor's mutable slot are deleted, so no setter exists to
  repoint either. `Unit__InvalidRig` becomes a constructor `ZeroAddress` check,
  which is the only point at which validation can still happen.
- **Genesis.** `constructor(rig_, reserve_)` (`:95`) mints `150_000e18` to
  `msg.sender` and `1` raw unit to `reserve_`. The POL recipient is
  `msg.sender`, not a parameter — the same structural choice the Reserve makes
  for its sanitization receiver, so no argument exists to misdirect the genesis
  allocation.
- **Burns.** `burn(uint256)` self-only (`:115`); `burnForRedemption(address,uint256)`
  gated to `reserve` (`:123`). No `burnFrom` — and none to delete: the vendored
  census contains no `ERC20Burnable`, so the ancestor's allowance-gated burn
  simply has no path into this tree.
- **Events.** None declared. sdd.md §3.2 assigns no event to `VUX`; ERC-20
  `Transfer` from/to the zero address carries every supply change, and its
  *cause* is carried by the co-emitted event of the contract that caused it
  (`Redeemed`, `VyrfHarvest`, `Settled`) — which is what UC-6 attribution
  requires (prd.md:L267). The ancestor's `Unit__Minted`/`Unit__Burned` were
  dropped as redundant; adding events the accepted schema does not list would
  have been a unilateral schema change.

### Task 2.2 — Token authority suite

`test/token/VuxToken.t.sol` (18 tests, 2 fuzzed). Covered in AC-1 and AC-2 above.

### Task 2.3 — `HardReserve.sol`

`src/HardReserve.sol` (185 lines), VUX-original clean source.

- `redeem(uint256 q, address to)` (`:150`): `nonReentrant`; snapshot `B`/`S`;
  `SupplyFloor` check against `S − S_MIN` (`:165`); `Math.mulDiv` (`:167`);
  `burnForRedemption(msg.sender, q)` (`:169`); `safeTransfer` (`:170`);
  `Redeemed` (`:172`). CEI throughout.
- `backing()` (`:176`) returns `weth.balanceOf(address(this))` directly — there
  is no accounting cell, so nothing can desynchronize from physical holdings.
- `previewRedeem(uint256)` (`:182`) — a quotation, explicitly not an entitlement.
- Constructor (`:107`): sanitize → event → born-empty `require`.
- `src/interfaces/IVUX.sol` — a two-member VUX-original interface
  (`totalSupply`, `burnForRedemption`). Deliberately not a mirror of the token
  ABI: a wider interface would let a future consumer reach token authority
  through this file instead of through the token's own gates. It reproduces no
  declaration from `IUnit.sol` (none of that interface's four members appears),
  so it carries the VUX-original SPDX.

### Task 2.4 — Redemption property/fuzz suite

`test/reserve/HardReserveRedemption.t.sol` (19 tests, 4 fuzzed) +
`test/reserve/ReserveFixture.sol`. Covered in AC-3 and AC-6.

The fixture reproduces the **production wiring topology** — deploy the Reserve
against a CREATE-predicted VUX address, deploy VUX, assert the prediction held
(`test/reserve/ReserveFixture.sol:35`) — rather than adding a wiring setter to
make testing convenient. A wiring setter would be the single most damaging
thing this sprint could introduce, so no fixture is allowed to need one.

### Task 2.5 — Constructor sanitization + runtime-bytecode inspection

`test/reserve/HardReserveSurface.t.sol` (13 tests, 1 fuzzed),
`test/harness/Artifact.sol`, `tools/provenance/inspect-runtime-surface.sh`.
Covered in AC-4 and AC-5.

### Task 2.6 — Structural-absence checklist + PROV-5 note

`grimoires/loa/a2a/sprint-2/evidence/structural-absence-checklist.md`,
`grimoires/loa/a2a/sprint-2/evidence/prov-5-similarity-review.md`.

---

## Exact files added / modified

**Added (13)**

| Path | Purpose |
|---|---|
| `src/VUX.sol` | the token |
| `src/HardReserve.sol` | the Hard Reserve |
| `src/interfaces/IVUX.sol` | the two-member token surface the Reserve depends on |
| `test/token/VuxToken.t.sol` | token authority + genesis + ABI suite |
| `test/reserve/ReserveFixture.sol` | production-topology deployment fixture |
| `test/reserve/HardReserveRedemption.t.sol` | redemption semantics + property/fuzz |
| `test/reserve/HardReserveSurface.t.sol` | structural absence + runtime bytecode |
| `test/harness/Artifact.sol` | metadata stripping, opcode walk, byte/string search |
| `test/mocks/MockWeth.sol` | TEST-ONLY canonical-WETH stand-in |
| `tools/provenance/inspect-runtime-surface.sh` | gate 8 — independent surface/runtime inspection |
| `grimoires/loa/a2a/sprint-2/sprint-2-scope.md` | byte-exact Sprint-2 slice |
| `grimoires/loa/a2a/sprint-2/evidence/prov-5-similarity-review.md` | PROV-5 |
| `grimoires/loa/a2a/sprint-2/evidence/structural-absence-checklist.md` | FR-7.2/7.3 checklist |

**Modified (8)**

| Path | Change |
|---|---|
| `tools/provenance/census.sh` | N-1: prune split into build-artifact vs Loa-zone; `loa_zone_solidity()` added |
| `tools/provenance/verify-census.sh` | N-1: conditional-prune assertion |
| `tools/provenance/demo-boundary-negative.sh` | N-1: probe 7 (single-file probe, exact-path cleanup) |
| `tools/provenance/run-all.sh` | registers gate 8 |
| `.github/workflows/provenance.yml` | `FOUNDRY_PROFILE: ci` (fuzz depth) |
| `foundry.toml` | `./out` read permission; `[profile.ci]`; records the bytecode-settings decision |
| `test/harness/Vm.sol` | `parseJsonKeys`, `recordLogs`/`getRecordedLogs` + `Log`, `getNonce`, `computeCreateAddress` |
| `test/harness/BaseTest.sol` | `bound()` for fuzz input shaping |

**Native lifecycle state (not implementation):** `grimoires/loa/NOTES.md`
(Status, Sub-Goals, Session Continuity, Decision Log, Learnings, Technical
Debt), `grimoires/loa/a2a/index.md` (sprint-2 row + artifacts; sprint-1's stale
`REVIEW_APPROVED` row corrected to `LANDED_VERIFIED` against
`auditor-sprint-feedback.md:589` and commit `23263e18`),
`grimoires/loa/ledger.json` (sprint-1 → `completed`, sprint-2 → `in_progress`;
`validate_ledger` OK), `.beads/issues.jsonl` (6 Sprint-2 tasks closed, epic
`vux-31v` left `in_progress` since review/audit remain),
`grimoires/loa/a2a/trajectory/implementing-tasks-2026-08-11.jsonl`.

**Not modified:** `grimoires/loa/prd.md`, `grimoires/loa/sdd.md`,
`grimoires/loa/sprint.md`, anything under `docs/authority/`,
`THIRD_PARTY_NOTICES.md`, anything under `vendor/`. Confirmed by an empty
`git diff --stat` over exactly those paths.

---

## Technical Highlights

### Structural absence proven against bytes, by two independent implementations

The Reserve's safety claims are claims about the deployed artifact. The
Solidity side (`test/harness/Artifact.sol`) strips the solc metadata tail using
its trailing two-byte length — so a stray `0xf4` inside a metadata hash cannot
read as a `DELEGATECALL` — then walks the image opcode-by-opcode, skipping
`PUSH1..PUSH32` immediates so a byte inside a pushed constant is not mistaken
for an instruction. The shell side (`tools/provenance/inspect-runtime-surface.sh`)
does the same in awk, written without gawk's `strtonum` so it behaves
identically under mawk on CI runners, and reads the ABI's `stateMutability` with
jq to establish "exactly one state-changing function" — a fact the Solidity side
cannot see from `.methodIdentifiers` alone. They agree.

Every absence assertion is paired with a positive control, because a search that
finds nothing *because it is broken* is indistinguishable from one that finds
nothing because nothing is there — the same "green because it is looking at
nothing" failure mode the Sprint-1 source-boundary remediation had to guard
against.

### The overflow domain is tested, not assumed away

The operator's requirement not to use a raw `B * q` is verified in three ways:
a property over inputs where the product provably exceeds `uint256` (with the
overflow condition asserted, not assumed), an algebraic oracle for that domain
that never forms the product, and a concrete test where a plain 256-bit
multiplication reverts on the exact inputs `redeem` handles correctly. Reverting
there would be a denial of the exit right precisely when backing is largest —
which is a safety failure, not a safety property.

### The genesis wiring 2-cycle is reproduced, not worked around

`VUX` and `HardReserve` reference each other immutably. The test fixture uses
CREATE prediction and asserts the prediction held, exactly as `GenesisDeployer`
will in Sprint 7. The alternative — a setter to break the cycle for testing —
is the initializer authority this architecture forbids, and the temptation to
add one is strongest in test code.

---

## Testing Summary

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge build                                        # both units
forge test                                         # 61/61
FOUNDRY_PROFILE=ci forge test --match-path 'test/reserve/*'   # property suites at 10,000 runs
bash tools/provenance/run-all.sh                   # 8 gates + full suite
bash tools/provenance/demo-boundary-negative.sh    # 7 probes, fence closes and reopens
bash tools/provenance/demo-drift-negative.sh       # 1-byte drift, fence closes and reopens
```

**`forge test` — 61 passed, 0 failed, 0 skipped** (6 suites):

| Suite | Tests | Sprint |
|---|---|---|
| `test/token/VuxToken.t.sol` | 18 (2 fuzzed) | 2 |
| `test/reserve/HardReserveRedemption.t.sol` | 19 (4 fuzzed) | 2 |
| `test/reserve/HardReserveSurface.t.sol` | 13 (1 fuzzed) | 2 |
| `test/harness/Harness.t.sol` | 6 | 1 |
| `test/provenance/VendoredSurface.t.sol` | 3 | 1 |
| `test/provenance/PoolInitCodeHash.t.sol` | 2 | 1 |

**Property suites at CI depth** (`FOUNDRY_PROFILE=ci`, 10,000 runs each, all
pass): `testFuzz_PayoutIsFloorOfBTimesQOverS`,
`testFuzz_PayoutIsExactWhenBTimesQOverflowsUint256`,
`testFuzz_PreviewMatchesTheActualPayout`,
`testFuzz_FullExternalRedemptionLeavesTheSeedAndAPositiveRemainder`,
`testFuzz_ConstructorSanitizesAnyPreExistingWeth`.

**Accumulated provenance suite — `run-all.sh` exit 0**, all 8 gates green:
census/byte-identity/excluded-sources, immutable pins, SPDX + copyright policy,
LICENSE + third-party notices, PRD §17 quarantine, launch-secret/broadcast
hygiene, `POOL_INIT_CODE_HASH` reproduction, **deployed surface and runtime
capability (new)**.

Preserved Sprint-1 facts, re-verified this node:

| Fact | Result |
|---|---|
| OZ v5.2.0 census | exactly 28 files, per-file SHA-256 match |
| Uniswap v3-core v1.0.0 census | exactly 32 files, per-file SHA-256 match |
| Miner Manifold allowlist | exactly 3 files, git blob OID match |
| Total vendored identity regression | **63/63 byte-identical**, zero drift |
| Zero unenumerated files under `vendor/` | pass |
| `POOL_INIT_CODE_HASH` | reproduced `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`, creation code 22,728 bytes, CBOR tail `a164736f6c6343000706000a` |
| Default-deny source boundary | pass — now including the conditional Loa-zone prune |
| §17 research-guidance quarantine | pass (10 pattern classes) |
| SPDX / no invented holders | pass — `VUX.sol` accepted as Miner-derived, `HardReserve.sol` and `IVUX.sol` as VUX-original |
| Launch-secret hygiene | pass |

**Source universe after this sprint:** 68 → 77 Solidity files — 63 vendored
census rows (unchanged) + 14 VUX-owned (5 Sprint-1 harness/provenance, 9 new),
as reported by the boundary gate itself:

```
source universe: 77 Solidity file(s) — 63 vendored (census), 14 VUX-owned (roots: src test script)
ok    zero unauthorized Solidity source anywhere in the repository (77 file(s) classified)
ok    zero Solidity in the pruned Loa/state zones (.claude grimoires .beads .run .ck) — the prune stays safe
```

**`forge lint src/`** reports zero warnings and zero errors; the only output is
4 × `note[screaming-snake-case-immutable]`. Lowercase address immutables are
deliberate — they match the accepted architecture's own naming (`immutables:
vux, weth, reserve, treasury`, sdd.md:L120) and the Miner ancestor's `rig`.
Renaming them would make `VUX.sol` diverge from both. The test tree also carries
`erc20-unchecked-transfer` notes on direct `MockWeth.transfer` calls in
fixtures; `src/` uses `SafeERC20` exclusively and produces none.

---

## Known Limitations

1. **Local verification ran forge 1.5.0-stable, not the pinned v1.0.0.** Carried
   from Sprint 1 and unchanged in character: CI installs and asserts the pin
   (`.github/workflows/provenance.yml:46`), and the bytecode-relevant pins (both
   solc build commits) are enforced strictly by comparing the compiler identity
   the artifacts actually report. The first green CI run under the pinned
   toolchain remains a pre-landing requirement.
2. **The `=0.8.28` unit's bytecode-affecting settings remain unset** — now as a
   recorded decision rather than an omission (`foundry.toml`): no accepted
   authority freezes them, the SDD's gas posture is correctness-first, and
   `evm_version` is a deployment-chain fact (R-14 adjacent). They are decided
   in Sprints 7–8 when the chain facts exist. Consequence to hold in mind: the
   recorded runtime-bytecode sizes above will change when they are set; the
   structural-absence *claims* will not, because the gate recomputes them.
3. **`MockWeth` is a stand-in, not canonical WETH.** It models only
   `balanceOf`/`transfer` — the surface the Reserve touches — plus three probe
   switches. `deposit()`/`withdraw()` are deliberately absent because nothing in
   Sprint 2 wraps native value; that is the Sprint-7 genesis path, and modelling
   it now would be fiction with no assertion behind it.
4. **Fixture supply shrinking uses `burn`.** Several readable examples need a
   small `S`, obtained by self-burning the creator's genesis inventory
   (`ReserveFixture.sol:56`). This uses no authority a holder does not have, but
   it does mean those examples run at a supply the production system will never
   see. The property suites run at realistic supply.
5. **`bound()` introduces mild modulo bias** toward the low end of a range. The
   boundary values that matter (`0`, `1`, `S_MIN`, `S − S_MIN`) are covered by
   dedicated unit tests rather than left to the fuzzer, so the bias costs
   nothing here — recorded because it would matter for a future property whose
   interesting region is at the top of its range.
6. **`src/.gitkeep` survives** in a now-populated directory. Harmless; removing
   it was outside what this sprint's request implies.

---

## Verification Steps for the reviewer

1. **Identity.** `git rev-parse HEAD` → `79c966f6c55899489fdb9db176773ef69e6ecf62`; `git status --porcelain` shows the 21 implementation paths plus the native lifecycle state listed above, and no authority file.
2. **Authority unchanged.** `sha256sum grimoires/loa/prd.md grimoires/loa/sdd.md docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json THIRD_PARTY_NOTICES.md` → the five accepted values.
3. **Build + test.** `forge build && forge test` → 61/61.
4. **Gates.** `bash tools/provenance/run-all.sh` → exit 0, 8 gates.
5. **Read the runtime evidence, do not just run it.** `bash tools/provenance/inspect-runtime-surface.sh` prints the surface sets, the mutability profile, the marker presence/absence, and the opcode census. Compare its numbers against `test/reserve/HardReserveSurface.t.sol`; they are independent implementations and should agree.
6. **Break it on purpose.** Add a `function sweep(address to) external { weth.safeTransfer(to, weth.balanceOf(address(this))); }` to `HardReserve.sol` and re-run: the exact-ABI assertion, the named-negative assertion, and gate 8's surface check should all fail. Revert.
7. **N-1 fence.** `bash tools/provenance/demo-boundary-negative.sh` → 7 probes, working-tree inventory identical before and after.
8. **Fuzz depth.** `FOUNDRY_PROFILE=ci forge test --match-path 'test/reserve/*'` → 10,000 runs per property.
9. **AC table.** `.claude/scripts/validate-ac-verification.sh --report grimoires/loa/a2a/sprint-2/reviewer.md --sprint grimoires/loa/a2a/sprint-2/sprint-2-scope.md` → exit 0.

### Where the reviewer should look hardest

- **`src/HardReserve.sol:150-173`** — the whole exit right is 23 lines. Ordering, the `S_MIN` subtraction, and the burn argument are each load-bearing, and a plausible-looking change to any of them is a monetary defect.
- **The `to == address(0)` check at `src/HardReserve.sol:155`.** This is an addition beyond the SDD's literal ABI text. Reasoning: canonical WETH would credit the zero address happily, destroying the payout *after* the burn committed. It is static, applies only to the caller's own argument, and blocks no redemption that could otherwise pay out — so it is malformed-input rejection, not the "approval gate, pause, allowlist, or discretionary block" FR-7 forbids. If the reviewer reads it as an invented gate, it is a one-line deletion.
- **`redeem(0, to)` is permitted** and emits a `Redeemed` event with zeros. Adding a revert would be an unrequested gate; the alternative is indexer noise. Flagged as a judgment call, not an oversight.
- **`test/harness/Artifact.sol:29` `stripMetadata`.** If this is wrong, several absence claims weaken. It is guarded by `test_MetadataStrippingRemovesATailAndNotTheProgram`, but the guard's 10% bound is a heuristic.
- **`tools/provenance/census.sh:176` `LOA_ZONE_PRUNE`.** This list is now the only place a source-boundary bypass could hide, and it is one line. Adding an entry to it is a provenance change.
- **`src/VUX.sol` carries no events.** If the reviewer disagrees that sdd.md §3.2 is exhaustive for the token, this is the place to say so — it is cheap to add now and expensive after Sprint 3 depends on the schema.

---

# Remediation pass — Security Audit Feedback Addressed (A-1, MEDIUM)

**Node:** `/implement sprint-2` — A-1 provenance-boundary remediation (operator-dispatched, narrowly bounded)
**Date:** 2026-08-11
**Starting audit-subject digest:** `78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a` (18 files)
**Resulting prospective-subject digest:** `a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf` (18 files, 4 changed)

The Sprint-2 audit returned **APPROVED** with 0 critical / 0 high / **1 medium (A-1)** / 3 low.
This pass closes A-1 and nothing else. The three LOW findings are deliberately untouched
(§"LOW findings" below). Product source, monetary behaviour, token authorities, redemption
math, vendor files, authority documents and dependencies are unchanged.

### Subject-digest method, independently recovered

The audit records the method only as "SHA-256 over the sorted `sha256  path` manifest". Before
changing anything, the manifest was reconstructed from the audit's own per-file table and
hashed until it reproduced `78c8881204…2ac45a` **exactly** — establishing the convention as
`<sha256>` + two spaces + `<path>`, `LC_ALL=C` sorted by path, LF line endings, trailing
newline. The resulting digest below is therefore computed by the same rule the auditor used,
not by a rule invented here.

### 1. Root cause

> From `auditor-sprint-feedback.md` (FINDING A-1): "`source_universe()` enumerates with
> `find … -name '*.sol'` — **case-sensitive** — while the Loa-zone assertion
> `loa_zone_solidity()` (`census.sh:204`) deliberately uses `-iname`. The primary default-deny
> universe is therefore *narrower* than the conditional exemption it guards, which is the
> inverse of the intended relationship."

One walk defines the whole boundary. `classify_sources()` (`census.sh:232`) consumes
`source_universe()`, and everything downstream consumes `classify_sources()` —
`all_sources` (`verify-census.sh:82`, feeding the §8 excluded-source and prohibited-source
detectors) and `vux_owned_sources()` (`census.sh:253`, feeding `verify-spdx.sh:69` and
`verify-quarantine.sh:41`). A file the walk cannot see is therefore invisible to **every**
gate at once, while remaining real compiled source the moment a declared root imports it.
The design property asserted at `census.sh:148-151` — "relocating source cannot move it out of
any gate's reach" — held on the location axis and failed on the naming axis.

### 2. Exact source-universe fix

| File | Change |
|---|---|
| `tools/provenance/census.sh:205` | `-name '*.sol'` → **`-iname '*.sol'`** in `source_universe()` — one case-insensitive universe definition, inherited by every consumer |
| `tools/provenance/census.sh:149-151` | the falsified design claim amended: "neither relocating source **nor re-casing its extension** can move it out of any gate's reach" |
| `tools/provenance/census.sh:184-200` | rationale recorded: solc resolves through its own filesystem callback, so `Foo.SOL` is real compiled source; N-2 explicitly retracted in-code |
| `tools/provenance/census.sh:216-220` | `loa_zone_solidity()`'s comment corrected — it no longer claims the walk is case-sensitive by design |
| `tools/provenance/verify-census.sh:146` | `grep -E` → **`grep -iE`** on the `UniswapV3Factory.sol` detector |

**Why the factory detector too.** It is the only §8 detector keying on a *filename* rather than
on content (`periphery` already used `grep -i` at `:155`; prohibited-source already used
`-HniE` at `:177`). Fixing only the walk would leave `src/UniswapV3Factory.SOL` classified
`vux` — legitimately, it is inside a declared root — and therefore past the sole remaining
check for it. That is the same class this node was dispatched to close, so it is closed. This
makes the case rules uniform rather than introducing a new posture; recorded in the NOTES.md
Decision Log as a scope judgment for the reviewer to confirm or reject.

`demo-boundary-negative.sh:117`'s vendored-donor selector keeps `-name` deliberately: it picks a
known-authorized census row, it is not a universe definition.

### 3. Exact files changed

Exactly **4** of the 18 audit-subject files. The other 14 are byte-identical to the audit's
table — verified hash-by-hash, not asserted.

| Path | Audit-entry SHA-256 | Post-remediation SHA-256 |
|---|---|---|
| `tools/provenance/census.sh` | `8b9996456ff3b5ed…e9c09d7e` | `63e8ec9d21fd4056…bebf8533` |
| `tools/provenance/verify-census.sh` | `39d721f95ed4a892…d0d17c3b88a0` | `2530dcd9f2b61856…cf82dee5` |
| `tools/provenance/demo-boundary-negative.sh` | `d629d7ff34b238e6…181e1f975a` | `fc37fcc28e7f9601…c4efa033` |
| `.github/workflows/provenance.yml` | `85e2123216dc3993…a38c0a136` | `1768f4d56fe56e9b…cb7edbf72` |

`.github/workflows/provenance.yml` changed only because probe 12 needs a compiler: the
`source-boundary-negative-demonstration` job carried the comment *"Needs only git + jq: the
source-boundary gates never invoke the compiler"*, which the control makes false. The pinned
`foundry-rs/foundry-toolchain@82dee4ba…` step (same 40-char pin as the other two jobs, same
`FOUNDRY_VERSION`) was added and the comment corrected. No other job, permission, trigger or
pin was touched.

**Unchanged, and verified so:** `tools/provenance/run-all.sh`
(`b4a373ab…`), `tools/provenance/inspect-runtime-surface.sh` (`c653a62a…`), `foundry.toml`
(`47b290cd…`), all 5 `src/**` + `test/**` product and harness files.

### 4. Authorization roots did not expand

`docs/`, the repository root, and the Loa/state zones now **fail closed** — they were not
exempted, whitelisted, or turned into source roots.

```
153:VUX_SOURCE_ROOTS=(src test script)
175:BUILD_ARTIFACT_PRUNE=(.git out out-v3core cache cache-v3core broadcast)
176:LOA_ZONE_PRUNE=(.claude grimoires .beads .run .ck)
```

All three lists are byte-identical to the audited versions. No new remapping, no `lib/`, no
`node_modules/`, no dependency. The classified universe is still **77 files — 63 vendored
(census) + 14 VUX-owned** — i.e. the fix widened the *predicate*, not the *authorization*: a
wider net over the same tree catches the same 77 files, because none of them was mis-cased.

### 5. Mixed-case negative probes (probes 8-11)

Added to the standing CI demonstration, each planted → proven to fail **for the boundary
reason** → removed → gate proven green again. Probe names are chosen independently of the
audit's (`AuditProbeEvil.*`), and use **distinct stems** rather than case variants of one stem —
on a case-insensitive filesystem `x.sol` and `x.SOL` are the same file, and Windows is exactly
where the audit's proof-of-concept ran.

| # | Probe | Location class | Casing | Gate + expected reason | Result |
|---|---|---|---|---|---|
| 8 | `ProvenanceCaseProbeRoot.SOL` | repository root | `.SOL` | `verify-census.sh` / `unauthorized Solidity source` | **failed closed** |
| 9 | `docs/provenance-case-probe-docs.SoL` | ordinary trackable non-source dir | `.SoL` | `verify-census.sh` / `unauthorized Solidity source` | **failed closed** |
| 10 | `grimoires/loa/boundary-probe-zone-case.sOl` | pruned Loa/state zone | `.sOl` | `verify-census.sh` / `pruned Loa/state zone` | **failed closed** |
| 11 | `contracts/research/CaseProbe.SOL` | prohibited-source reach | `.SOL` | `verify-census.sh` / `prohibited-source reference` | **failed closed** |

Cleanup is exact: refuse-if-present at start, `rm -f` by exact path, unconditional `trap`, and
the pre-existing working-tree inventory comparison. Final run:

```
ok    working-tree inventory identical to pre-probe state (f7db6903e8f3e8dc8ccc723b7d704bd452313ffbf93873df85c10ac95cbde3d9)
ok    ProvenanceCaseProbeRoot.SOL removed
ok    docs/provenance-case-probe-docs.SoL removed
ok    grimoires/loa/boundary-probe-zone-case.sOl removed
ok    throwaway build project removed
Source-boundary fence proven closed on all 11 probes and reopened; mixed-case build-reachability proven from compiler evidence.
```

**The probes were proven non-vacuous.** A negative control written in the same pass as its fix
is unfalsified by construction, so `source_universe()` was temporarily regressed to `-name` and
the new probes were *required* to fail:

```
── probe 8  → FAIL  verify-census.sh PASSED with the probe present — the fence is open [repository root, .SOL]
── probe 9  → FAIL  verify-census.sh PASSED with the probe present — the fence is open [docs/, .SoL]
── probe 10 → ok    verify-census.sh failed closed for the right reason [pruned Loa zone, .sOl]
── probe 11 → FAIL  verify-census.sh PASSED with the probe present — the fence is open [prohibited sources, .SOL extension]
demo exit=1
```

Probe 10 passing against the regressed walk is **correct and expected** — it is reached by
`loa_zone_solidity()`, which was already `-iname`; that asymmetry *is* finding A-1, observed
from the other side. `census.sh` was then restored and re-verified byte-identical
(`63e8ec9d…bebf8533`).

### 6. Positive build-reachability control (probe 12)

The negative probes only matter if a mixed-case extension really is build-reachable — and the
**sprint-1 audit concluded the opposite (N-2), from a resolver diagnostic**. This control
therefore reads no resolver output as evidence. It builds a throwaway Foundry project in
`mktemp -d`, **outside the repository** (importing a `.SOL` from `src/` would both mutate
Sprint-2 product source and perturb the inventory hash the demonstration depends on), and takes
its verdict from two compiler-authoritative facts:

```
ok    solc recorded src/CaseReach.SOL in the importing artifact's metadata.sources — it IS compiled source
ok    a deployed instance of the .SOL contract EXECUTED — reachability is proven, not inferred
      [PASS] test_MixedCaseExtensionIsBuildReachableAndExecutable() (gas: 68184)
      note: Foundry printed "Unable to resolve imports" in the same run that passed —
            a resolver diagnostic describes the discovery pass, never what compiled
            (this is the sprint-1 N-2 error; the entry is retracted in NOTES.md)
```

The control deliberately **prints** the N-2 diagnostic beside a passing execution: that
juxtaposition is the retraction's evidence. The test contract uses no `forge-std` and no
harness — `require` is the whole assertion, so a pass can only mean the imported mixed-case
source compiled, deployed and ran.

### 7. Prohibited-source scan result

Clean tree: `ok    no prohibited-source (LSG / gumball6900 / give.fun / Olympus) reference in
Solidity sources`. Reach is now proven rather than claimed — probe 11 shows the detector fires
on `Olympus`/`gumball6900`/`give.fun` hidden behind a `.SOL` extension, and fails to fire
against the regressed walk. This closes the audit's caveat that A-1 *"slightly overstates the
reach claimed in the PROV-5 evidence §4"*.

### 8. N-1 / default-deny regression

Unaffected and re-proven. Probe 7 (lowercase `.sol` in a pruned zone, the original N-1 closure)
still fails closed, probes 1-6 still fail closed for their original reasons, and the clean-tree
assertions are unchanged:

```
      source universe: 77 Solidity file(s) — 63 vendored (census), 14 VUX-owned (roots: src test script)
ok    zero unauthorized Solidity source anywhere in the repository (77 file(s) classified)
ok    all 63 accepted census rows present in the classified source universe
ok    zero Solidity in the pruned Loa/state zones (.claude grimoires .beads .run .ck) — the prune stays safe
```

### 9-11. Complete provenance + test regression

`bash tools/provenance/run-all.sh` → **exit 0**, captured both before any edit (baseline) and
after: both compilation units build, all 8 gates green, `forge test` **61 passed / 0 failed**
across 6 suites. Specifically re-confirmed:

- **63/63 vendored files byte-identical** to the accepted registry (28 OZ sha256 + 32 v3-core sha256 + 3 Miner blob-OID); counts exactly 28 / 32 / 3
- **`POOL_INIT_CODE_HASH` reproduced** and equal to the accepted constant `0xe34f199b…b8b54`; pool compiled by `0.7.6+commit.7338295f`
- 4 accepted authority artifacts match their recorded SHA-256
- runtime-surface gate unchanged: exactly one state-changing function (`redeem`), no payable, no `receive`/`fallback`, no `burnFrom`, `create=0 create2=0 callcode=0 delegatecall=0 selfdestruct=0`, sanitization marker in creation code and absent from runtime
- **no new dependency; no `forge-std`** (`lib/` does not exist; `remappings.txt` unchanged at 2 entries)

### 12. Product-source hashes unchanged

```
5686c4c7c353711998eccb3693bda44d9ab0352ed79d69a1b853447dc5197349  src/VUX.sol
74b8319ab155225b4533790b88d3adc71c8da117ff74d4124e180f3bd39f2c17  src/HardReserve.sol
3910bf9d440a1755cd6bad3e0e7975ad0a1adb9a0f5a4b0e91ee9391ed83eb24  src/interfaces/IVUX.sol
```

Identical to the audit-subject table. All `test/**` files likewise byte-identical. No Solidity
was written, edited, or deleted by this node.

### 13. LOW findings untouched — verified still present

Not "not fixed" as an omission; verified unchanged so the reviewer can confirm no silent
perfection loop occurred.

| Finding | Check | Observed |
|---|---|---|
| **L-1** stale source-comment pointers | `grep -n ReserveSurface.t.sol src/HardReserve.sol` | still 2 hits, `:31` and `:100` — unchanged |
| **L-2** `forge fmt --check` residue | `forge fmt --check` | same 4 files still differ (`src/HardReserve.sol`, `test/harness/Harness.t.sol`, `test/reserve/HardReserveRedemption.t.sol`, `test/reserve/HardReserveSurface.t.sol`) |
| **R-1** `BUILD_ARTIFACT_PRUNE` not assertion-covered | `census.sh:175` | byte-identical; audit disposition was "No remediation required" |

R-2 (read-only reentrancy) and R-3…R-6 (informational) likewise untouched.

### 14. AC status

Unaffected. This pass changed no product code and no test, so the 7/7 Sprint-2 acceptance
criteria verified in `## AC Verification` above stand exactly as recorded, with the same
`file:line` evidence and the same 61/61 suite behind them. The audit's own AC reconciliation is
similarly undisturbed.

### 15. Reusable learning beyond the already-captured audit lesson

Yes — one, and it is about the *remediation*, not the defect. The audit's lesson ("a resolver
diagnostic is never build-reachability proof") was already captured. What this node added:
**a mutation test must prove the mutation landed before it proves anything about the
detector.** The first regression attempt used a `sed` expression that silently failed to match;
the demonstration then ran against the *fixed* code and reported every probe green, which reads
identically to a successful falsification. It was caught only by echoing the mutated line back
and asserting on it before trusting the run. Recorded in NOTES.md `## Learnings`; a
`skills-pending` entry is left to the operator-run `/retrospective` step rather than authored
here.

---

## Node boundary

- No commit, push, tag, branch, or landing.
- No review or audit verdict written; `/review-sprint sprint-2` and `/audit-sprint sprint-2` not invoked.
- No new dependency; `forge-std` absent.
- No Sprint-3+ mechanism: no `Rig.sol`, pricing, VEM, routing, treasury, POL, VYRF, Lens, or `GenesisDeployer`. The token exposes the immutable `rig` mint boundary the accepted architecture requires, and nothing behind it.
- No operator-reserved decision resolved (R-1…R-14 untouched); no PRD §17 research value promoted.
- Beads: epic `vux-31v` and tasks `vux-fs8`, `vux-3ot`, `vux-3gq`, `vux-33a`, `vux-2gu`, `vux-3ha` managed natively.

**Remediation-pass boundary (2026-08-11).** Same constraints, re-asserted for the A-1 node: no
commit, push, tag, branch, or landing; `/review-sprint` and `/audit-sprint` **not** invoked; no
Sprint-3 work begun; no operator acceptance taken. No product contract change was required, so
`HITL_REQUIRED` was not raised. Authorized mutation was confined to the provenance/default-deny
tooling, its coupled negative demonstration, the CI job that runs that demonstration, and native
implementation evidence/state (`NOTES.md`, this report, `a2a/index.md`, beads). Beads task
`vux-96d` tracks the remediation under epic `vux-31v`. The remediated subject must go through
`/review-sprint sprint-2` and then an exact-tree audit before operator acceptance.
