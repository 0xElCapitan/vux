# VUX v1 Strategic-Treasury Provenance & Source-Boundary Delta

**Date:** 2026-08-09  
**Status:** `PROVENANCE_DELTA_CURRENT_ACCEPTED`  
**Operator acceptance:** 2026-08-09 — `OPERATOR_ACCEPTANCE`  
**Base authority:** `vux-v1-licence-provenance-source-pin-freeze-2026-08.md`  
**Machine-readable companion:** `vux-v1-source-registry-strategic-treasury-delta-2026-08.json`

## 1. Purpose and activation

The corrected VUX product adds first-class Strategic routing/custody, POL-special VYRF behavior, and a core mature LSG product role. Those product decisions do **not** grant source-reuse permission.

Operator acceptance was recorded on 2026-08-09. This delta supplements the existing licence/provenance freeze and JSON registry. It changes no project licence, source pin, file allowlist, permission basis, dependency selection, notice obligation, or default-deny rule. The base files remain unchanged.

Recorded base hashes:

| base authority | SHA-256 |
|---|---|
| `vux-v1-licence-provenance-source-pin-freeze-2026-08.md` | `50c3584a1483b40ffb6391260a2bf42df32220c64724fdcc672ca62c01ace3a2` |
| `vux-v1-source-registry-2026-08.json` | `6fc9fa81d80eda1f1017c6cb79f297b9a608150538e76ad97d8de1c8b5d2fe04` |

## 2. Preserved source authority

The following remain unchanged:

- project licence: `GPL-3.0-or-later`;
- `LICENSE` and `THIRD_PARTY_NOTICES.md` posture;
- default deny: no copying/modification unless a file appears in the frozen file-reuse allowlist;
- direct allowlist limited to the three existing pinned Miner Manifold files;
- conservative Euler FeeFlow lineage treatment for Rig-derived portions;
- full-SHA-only pin policy and refreeze requirement for newer revisions;
- exact implementation dependency and AMM/library selection reserved to the SDD and a later licence census;
- canonical RH WETH treated as an external runtime interface, not vendored source;
- Liquid Signal Governance, gumball6900, Olympus v3, Olympus docs, and other research repositories provide no newly authorized implementation source.

No code, dependency, implementation library, or source file is authorized by this delta.

## 3. VUX-original clean-source surfaces

Unless a later provenance authority approves a specific source with exact pin, path, licence, lineage, and notice treatment, the following must be designed and implemented as VUX-original clean-source surfaces from the superseding authority documents:

| corrected product surface | source disposition |
|---|---|
| static `80/8/12` settlement and Reserve-favoring dust arithmetic | `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` except for separately allowlisted generic Rig lineage |
| separate Strategic receipt, custody boundary, and principal/revenue accounting | `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` |
| Hard-only `D_R` measurement under the corrected split | `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` under the existing VEM clean-source rule |
| POL principal versus fee-yield classification | `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` |
| VUX POL-fee burn and WETH POL-fee one-way Hard routing | `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` |
| general realized-revenue classification/policy surface | `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` |
| future LSG admission/signal/execution/emergency boundary | `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` |
| protocol-owned POL VUX non-voting treatment | `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` |

Conceptual similarity to prior art is not code ancestry. Future review must compare candidate implementation against prohibited/reference repositories closely enough to detect accidental structural or textual copying.

## 4. LSG classification clarification

The base registry classifies `Heesho/liquid-signal-governance@14b5fbbbe1945f2e6501f84976e5f12b39fb227a` as `DEFERRED_NOT_V1` with no copy/import authority.

After this supersession:

- the **VUX product capability** called LSG is a core mature surface, inactive until operator-threshold activation;
- the **pinned external repository** remains deferred/prohibited as implementation source.

Accordingly, `DEFERRED_NOT_V1` is preserved only as the base registry's source-reuse disposition. It must not be read as excluding the VUX-original LSG product role from the corrected canonical specification. The pin remains evidence/reference material, not an implementation input.

## 5. gumball and Olympus clarification

- gumball6900 Fund, LiquidityPosition, Strategy, revenue-routing, and VYRF-shaped code remain `REFERENCE_ONLY` or prohibited according to the base freeze. The corrected POL-special VYRF outcome does not authorize a port.
- Olympus treasury, POL, emission, and yield-repurchase code remains `REFERENCE_ONLY`. Policy precedent does not authorize code or prose copying.
- No ROOT/GIGA implementation source is admitted. Future public documentation or deployment facts require a separate evidence/provenance decision before integration code is selected.

## 6. Later SDD and implementation gates

Before implementation of any corrected surface, the SDD/provenance process must:

1. select exact dependencies and immutable versions/pins;
2. identify every imported/copied/modified source file;
3. keep the base file allowlist default-deny;
4. document VUX-original versus derived treatment per file;
5. preserve required copyright, licence, ancestry, and modification notices;
6. update `THIRD_PARTY_NOTICES.md` if and only if actual selected sources require it;
7. trigger a provenance refreeze before using any new external source, newer revision, LSG file, gumball file, Olympus code, ROOT/GIGA integration library, or unlisted dependency.

This delta does not choose contract architecture, custody, AMM integration, LSG mechanism, keeper design, or access-control primitives.

## 7. Authority disposition

The base Markdown freeze and JSON registry remain authoritative for all existing pins and reuse permissions. This delta is authoritative only for the corrected-surface clean-source classifications and the source-versus-product interpretation of LSG.

No base authority or predecessor file is rewritten. No source authority expands.

**STOP. The fresh Loa planning cycle is authorized next but has not been invoked.**
