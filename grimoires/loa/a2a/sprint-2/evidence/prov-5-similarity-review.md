# PROV-5 Similarity Review — `HardReserve.sol`

**Sprint:** cycle-002 / sprint-2 (global = local)
**Subject:** `src/HardReserve.sol`
**Classification:** `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` (PROV-5, prd.md:L764; sdd.md:L127)
**Date:** 2026-08-11

---

## 1. Required statement

> The Hard Reserve was implemented from the canonical VUX equations and the
> accepted architecture. Prohibited source was not consulted as an
> implementation source.

Concretely: `src/HardReserve.sol` was written from

- **prd.md FR-7** (L410–L426) — the monetary definition of `B`, the redemption
  formula `payout = floor(B × q / S)` on pre-redemption state, zero fee,
  Reserve-favoring rounding, `S_MIN = 1` raw unit, and the FR-7.2 list of
  authorities that must not exist;
- **prd.md §10.2** — INV-10, INV-14, INV-15, INV-16, INV-17;
- **sdd.md §1.4 `HardReserve.sol`** (L125–L133) — the CEI ordering, the
  `nonReentrant` posture, the `burnForRedemption(msg.sender, q)` call shape, the
  constructor-time contamination sanitization, and the structural-absence list;
- **sdd.md §5.2.3** — the exhaustive ABI;
- **sdd.md §3.2** — the `Redeemed` and `PreGenesisWethSanitized` event schema;
- **sdd.md §6.1** — the typed-error strategy (`SupplyFloor`).

and from no other design or implementation.

## 2. Sources NOT consulted

The following were not opened, read, copied, adapted, or paraphrased at any
point during this sprint, in whole or in part, as an implementation source for
`HardReserve.sol`:

| Source | Status |
|---|---|
| gumball6900 | prohibited (PRD §15 / refreeze §8) — not consulted |
| Liquid Signal Governance repository | prohibited — not consulted |
| Olympus (and OHM-family bonding/treasury/staking code) | prohibited — not consulted |
| give.fun | prohibited — not consulted |
| Any other redemption, bonding-curve, reserve, vault, or treasury implementation | not enumerated by the accepted census — not consulted |

The Miner Manifold allowlist (PROV-2) authorizes three files, all of which are
token/auction surfaces. None was used here: `HardReserve.sol` imports nothing
from `vendor/miner-manifold-bcffbf1e/`, and its SPDX is plain
`GPL-3.0-or-later`, not the Miner-derived `MIT AND GPL-3.0-or-later`, which the
SPDX gate enforces as mutually implied with an `@custom:provenance
miner-manifold` marker (`tools/provenance/verify-spdx.sh:79-87`).

## 3. Post-hoc similarity assessment

PROV-5 asks for a *similarity review*, not merely a declaration of intent. The
review below is structural, and its conclusion is that convergence with any
pro-rata redemption implementation is confined to arithmetic that has only one
correct form.

| Element | Assessment |
|---|---|
| `payout = floor(B × q / S)` | Convergent by necessity. Pro-rata division has one expression; the PRD fixes the rounding direction. Any implementation computing the same quantity looks the same at this line. Not evidence of derivation. |
| Full-precision `mulDiv` | Convergent. The OpenZeppelin `Math.mulDiv` used here is a vendored, censused dependency (refreeze §3), reached by the SDD's own selection — not lifted from a redemption implementation. |
| CEI ordering (snapshot → compute → burn → pay) | Prescribed verbatim by sdd.md:L130. |
| Approval-free burn via a token-side `onlyReserve` gate | **Divergent from the common pattern.** The prevalent shape is `transferFrom`/`burnFrom` with an allowance; this architecture deletes the allowance path entirely and inverts the trust direction (sdd.md:L97). A derived implementation would carry the allowance shape. |
| `B` as a physical balance with no accounting cell | **Divergent.** Reserve/treasury implementations in this space characteristically maintain a tracked reserve balance, a debt/supply ratio cell, or an NAV term. There is none here, by design (INV-10). |
| Constructor-time contamination sanitization | **No known counterpart.** It exists to satisfy a VUX-specific genesis-exactness requirement (`balanceOf(reserve) == B0` exactly, sdd.md:L132) and has no analogue in general redemption code. |
| Ownerless, roleless, non-upgradeable, no sweep, no recovery | **Divergent.** The prohibited-source families are characterized by owner/governance/treasury-management surfaces. Their absence here is the design (FR-7.2). |
| `S_MIN` permanent seed held by the redeeming contract itself | **Divergent.** A denominator floor held by the redemption contract, unreachable by any code path, is specific to this specification. |

**Conclusion.** The only convergence is in arithmetic whose form is determined by
the specification itself. Every element where implementations have design freedom
diverges from the prohibited families, and diverges in the direction the accepted
architecture prescribes. The file is VUX-original clean source.

## 4. Mechanical corroboration

Not a substitute for the review above, but independently checkable:

- `tools/provenance/verify-census.sh` fails the build on any reference to the
  prohibited sources anywhere in the repository's Solidity universe
  (default-deny classification, `census.sh:176-192`). It is green.
- `src/HardReserve.sol` imports exactly four vendored OpenZeppelin files
  (`IERC20`, `SafeERC20`, `Math`, `ReentrancyGuard`) and one VUX-original
  interface (`IVUX`). Every one is either an accepted census row or VUX-owned.
- The prohibited-source names are deliberately kept out of the Solidity source
  and confined to this document, because naming them in a `.sol` file would trip
  the repository's own detector. That is a reporting constraint, not an evasion:
  the statement is recorded here, in the sprint's review artifacts, which is
  where prd.md:L764 places it.
