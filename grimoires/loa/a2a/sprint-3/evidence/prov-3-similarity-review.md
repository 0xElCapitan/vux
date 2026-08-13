# PROV-3 Similarity Review — `Rig.sol`

**Sprint:** cycle-002 / sprint-3 (global = local)
**Subject:** `src/Rig.sol`, `src/interfaces/IVUXMintable.sol`
**Classification:** mixed — Miner-derived skeleton (PROV-2) +
`VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` monetary surfaces (PROV-3, prd.md:L762;
sdd.md:L103)
**Date:** 2026-08-13

---

## 1. Required statement

> The adaptive routing law, Reserve-favouring dust arithmetic, `D_R`
> measurement, `D_R` consistency rejection, VEM math, and the VUX-specific
> monetary invariants were implemented from the accepted PRD/SDD equations
> alone. No prohibited or unenumerated source was consulted as an
> implementation source. The generic auction/throne skeleton was adapted only
> from the allowlisted Miner Manifold `contracts/Rig.sol` at the accepted pin.

## 2. The two provenance surfaces, separated per file section

`Rig.sol` is a mixed-provenance file, so PROV-3 requires the boundary to be
stated per section rather than for the file as a whole. The in-file
`@custom:provenance miner-manifold` and `@custom:modifications` blocks
(src/Rig.sol) carry the same split; this table is the reviewable index.

### 2a. Miner-derived (PROV-2 — allowlisted `contracts/Rig.sol`, blob `d362ef35…` @ `bcffbf1eb963810acb14a1fd1c73d03a53a085a8`)

| surface | upstream counterpart | nature of the derivation |
|---|---|---|
| Epoch state cells (`epochId`, `epochStart`, `epochOpening`, `epochUPS`, `king`) | `epochId`, `epochStartTime`, `epochInitPrice`, `epochUps`, `epochMiner` | Same concept, renamed; `king`/`epochOpening`/`epochStart` re-typed for packing |
| Linear Dutch decay | `getPrice()` | Same shape `opening − opening×t/T`; VUX adds the `DECAY_FLOOR` clip and the `t ≥ T` early return |
| Successor-opening ladder | `newInitPrice = price × PRICE_MULTIPLIER / PRECISION` with min/abs-max clamps | Same idea; VUX uses an integer multiplier and `max(MINIMUM_OPENING, 2P)`; the `uint192` clamp mirrors `ABS_MAX_INIT_PRICE` |
| Shift-based halving | `_getUpsFromTime`: `INITIAL_UPS >> halvings` | Same technique; VUX clamps the shift at 8 instead of flooring at a separate `TAIL_UPS` |
| Settlement shape | `mine()`: pull payment → distribute → mint to outgoing → rotate epoch | Same ordering skeleton |
| `nonReentrant` + `SafeERC20` posture | same | Same |

### 2b. VUX-original clean source (PROV-3 — written from PRD/SDD equations only)

| surface | site | upstream counterpart |
|---|---|---|
| Adaptive routing law (`retained`, `strategicCap`, `hardFloor`, `D_need`, `hardTarget`, Strategic residual) | `_route` | **None.** Upstream splits a *static* 80/15/2.5/2.5 four-way fee among fixed recipients |
| Reserve-favouring dust arithmetic | `_route` (`hardFloor = retained − strategicCap`) | **None.** Upstream assigns its remainder to the dev leg (`devAmount = price − …`) |
| Physical `D_R` measurement | `take` step 8b | **None.** Upstream never measures a recipient's balance |
| `D_R` consistency rejection (`InconsistentReserveDelta`) | `take` step 8b | **None** |
| VEM cap (`Qsafe`, `Qmint`) | `_vem` | **None.** Upstream mints `mineTime × epochUps` with no backing check whatsoever |
| Bootstrap branch (`king == reserve ⇒ Qraw = 0`, King leg to Hard, one-shot `scheduleStart`) | `take` | **None.** Upstream seats `team` as the genesis miner and starts its clock at deployment |
| `Settled` record | event + `_emitSettled` | **None.** Upstream emits five separate narrow events |
| Structural absences (no owner, no setters, no URI, no recipient parameter) | whole file | Inverse of upstream, which is `Ownable` with four setters |
| `IVUXMintable` | separate file | Declares `totalSupply`/`mint`; `IUnit` declares `mint`/`burn`/`setRig`/`rig` — only the ERC-20-conventional `mint` signature overlaps |

**The economically load-bearing half of this contract has no upstream
counterpart.** What was derived is the generic throne/auction/clock scaffolding;
what makes VUX a monetary system — measured-reality issuance and the adaptive
floor — is original.

## 3. Sources NOT consulted

The following were not opened, read, copied, adapted, or paraphrased at any
point during this sprint, in whole or in part, as an implementation source for
any part of `Rig.sol` or `IVUXMintable.sol`:

- `Strategy.sol` and `Hopper.sol` (non-allowlisted Miner Manifold files — and
  neither is present in the repository: only the 3 allowlisted files are
  vendored, mechanically enforced by `tools/provenance/verify-census.sh`)
- Liquid Signal Governance
- gumball6900
- give.fun
- Olympus (and any OHM-derived bonding, staking, or treasury implementation)
- Any other non-allowlisted Miner Manifold file
- Any other auction, KOTH, bonding-curve, reserve, or treasury implementation
  outside the accepted census

The repository additionally enforces this at the source level: naming any of
these in Solidity source trips the repository's own prohibited-source detector
(`tools/provenance/verify-census.sh`, the `prohibited_hits` gate), which is why
the list lives in this note rather than in a code comment — the same convention
Sprint 2 adopted for PROV-5.

## 4. What *was* consulted

- **prd.md FR-2** (L329–L344) — throne, Dutch pricing, successor ladder, floor
- **prd.md FR-3** (L346–L361) — UPS schedule, snapshot, 3,000-second cap, tail
- **prd.md FR-4** (L363–L378) — the adaptive routing law, verbatim equations
- **prd.md FR-5** (L380–L395) — VEM, `D_R`, `Qsafe`/`Qmint`, the no-carry rule
- **prd.md FR-6** (L397–L408) — bootstrap semantics and degeneracy
- **prd.md §10.3** (L604–L612) — INV-18…22
- **sdd.md §1.4 `Rig.sol`** (L101–L123) — storage layout, constants posture
- **sdd.md §1.5** (L196–L229) — the 13-step settlement order and arithmetic notes
- **sdd.md §3.2** — the `Settled` schema
- **sdd.md §5.2.2** — the exhaustive ABI
- **sdd.md §6.1** — typed errors (`PriceAboveMax`, `InconsistentReserveDelta`)
- **sdd.md Appendix F, F-1** — the adaptive-routing supersession record
- **vendor/miner-manifold-bcffbf1e/contracts/Rig.sol** — the allowlisted
  derivation reference, for §2a only

and from no other design or implementation.

## 5. Licence and notice compliance (PROV-8)

- `src/Rig.sol` declares `SPDX-License-Identifier: MIT AND GPL-3.0-or-later`
  and carries the mandatory `@custom:provenance miner-manifold` marker. The
  pairing is mechanically enforced in both directions by
  `tools/provenance/verify-spdx.sh` (a Miner-derived declaration without the
  marker fails, and vice versa).
- `src/interfaces/IVUXMintable.sol` declares `GPL-3.0-or-later` (VUX-original,
  no marker) — see §2b for why the `mint` signature overlap does not make it
  derived.
- Upstream MIT notice: already reproduced verbatim in `THIRD_PARTY_NOTICES.md`
  from Sprint 1; this sprint adds no new upstream source and therefore requires
  no notice change.
- The byte-identical upstream file remains at
  `vendor/miner-manifold-bcffbf1e/contracts/Rig.sol` as the derivation
  reference, unmodified.

## 6. No new dependency

Sprint 3 adds **zero** new source outside the accepted census. Every import in
`src/Rig.sol` resolves to already-vendored OpenZeppelin v5.2.0
(`IERC20`, `SafeERC20`, `Math`, `ReentrancyGuard`) or to VUX-original files.
`tools/provenance/run-all.sh` passes all gates on this tree, including the
census, byte-identity, excluded-source, SPDX, pin, and `POOL_INIT_CODE_HASH`
checks.

One build-configuration change was made and is called out here because it is
provenance-adjacent: `[profile.default]` now sets `via_ir = true` +
`optimizer = true` (a compilation necessity for the accepted 16-field `Settled`
event — see `foundry.toml` and the reviewer report). Because Foundry profiles
inherit from `default`, this initially propagated into `[profile.v3core]` and
would have changed the vendored unit's bytecode; `via_ir = false` is now pinned
explicitly there. `POOL_INIT_CODE_HASH` reproduces against the accepted constant
on the delivered tree.

## 7. Verdict

**No PROV-3 finding.** The derived surface is confined to the generic
throne/pricing/clock skeleton of the single allowlisted file; every monetary
surface the sprint exists to deliver is VUX-original and written from the
accepted equations. Licence declarations, notices, and the source census are
unchanged and green.
