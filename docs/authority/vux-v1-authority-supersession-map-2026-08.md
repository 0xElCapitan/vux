# VUX v1 Strategic-Treasury Authority Supersession Map

**Date:** 2026-08-09  
**Status:** `SUPERSESSION_MAP_CURRENT_ACCEPTED`  
**Operator acceptance:** 2026-08-09 — `OPERATOR_ACCEPTANCE`  
**Lifecycle disposition:** bounded authority reconciliation; no downstream lifecycle invoked

## 1. Activation rule and current authority

Operator acceptance was recorded on 2026-08-09. The successor documents are current, the predecessor Founder Freeze and Canonical Specification are superseded in full, and authority is unambiguous:

| precedence | current authority | disposition |
|---:|---|---|
| 1 | `vux-founder-parameter-freeze-strategic-treasury-supersession-2026-08.md` | complete current Founder Parameter Freeze |
| 2 | `vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md` | complete current VUX v1 product specification |
| 3 | `vux-v1-strategic-treasury-provenance-boundary-delta-2026-08.md` and `vux-v1-source-registry-strategic-treasury-delta-2026-08.json` | narrow corrected-surface source delta |
| 4 | `vux-v1-licence-provenance-source-pin-freeze-2026-08.md` and `vux-v1-source-registry-2026-08.json` | preserved base licence/pin/reuse authority where not clarified by the delta |
| 5 | this map | authoritative old-to-new disposition and lifecycle record |
| 6 | prior research/closure artifacts | evidence/history only where not superseded above |

The old Founder Freeze and Canonical Specification remain preserved and are no longer current. No earlier research conclusion may override the successor set.

## 2. Preserved predecessor evidence

The following baseline files were not edited during this node:

| predecessor | baseline SHA-256 | disposition |
|---|---|---|
| `docs/authority/vux-founder-parameter-freeze-2026-08.md` | `70478a1de7504d744dfad5209bb1322f9001f2ea701600df281b107637110353` | superseded in full after acceptance; preserved history |
| `docs/authority/vux-v1-canonical-specification-2026-08.md` | `5df47db097ec90bc751a8f3fc555f671f66a22cdf1f391cfb1074b85d6401869` | superseded in full after acceptance; preserved history |
| `docs/authority/vux-v1-licence-provenance-source-pin-freeze-2026-08.md` | `50c3584a1483b40ffb6391260a2bf42df32220c64724fdcc672ca62c01ace3a2` | preserved base authority, supplemented only by delta |
| `docs/authority/vux-v1-source-registry-2026-08.json` | `6fc9fa81d80eda1f1017c6cb79f297b9a608150538e76ad97d8de1c8b5d2fe04` | preserved base machine registry, supplemented only by delta |
| `grimoires/loa/prd.md` | `bea5c8ab04ff2efbce8a5cd75f6f208d15dc5b35481b05f625124e8480c03945` | `SUPERSEDED_BEFORE_OPERATOR_ACCEPTANCE`; historical generation evidence; never current authority |

The stale PRD must not be patched, revived, or used as the basis for an SDD. A fresh `/plan-and-analyze` cycle against the accepted authority is now the authorized next node.

## 3. Major rule-level supersession

| old current-authority rule | replacement after acceptance | classification |
|---|---|---|
| ordinary payment `80% King / 20% Hard / 0% Strategic` | `king=floor(80%)`, `strategic=floor(12%)`, `reserve=remainder` (nominally at least 8% plus dust) | **SUPERSEDED** |
| Strategic Treasury receives no primary mining flow | Strategic receives exactly the floor-rounded 12% gross leg on every takeover, including activation | **SUPERSEDED** |
| bootstrap sends the complete payment to Hard | bootstrap sends outgoing-King 80% plus Hard leg/dust to Hard and 12% to Strategic; zero mint | **SUPERSEDED** |
| maximizing Hard Reserve is the effective sole product objective | VUX combines Hard exit rights with productive Strategic capital, holder-directed allocation, and market infrastructure under FAIR/SIMPLE/ELEGANT/SECURE | **SUPERSEDED** |
| Strategic Treasury is economically secondary/external | Strategic Treasury is a first-class core product surface and receives primary capitalization | **SUPERSEDED** |
| all incremental WETH protocol revenue enters Hard | POL WETH fee yield enters Hard specially; other realized Strategic WETH follows an adaptive disclosed general policy | **SUPERSEDED** |
| all incremental VUX revenue burns under one general rule | POL VUX fee yield always burns specially; non-POL VUX revenue normally burns unless later explicit authority establishes another treatment | **REFINED** |
| LSG is optional/deferred compatibility outside v1 | VUX-original LSG is a core mature product surface, inactive until operator-threshold activation | **SUPERSEDED** |
| LSG may direct only secondary/revenue flows | LSG may direct available marginal Strategic capital among admitted Strategies; never Hard or minting | **SUPERSEDED** |
| no primary Strategic capital receiver/product accounting | separate Strategic receipt, custody boundary, principal/revenue semantics, and observable accounting are required | **ADDED** |
| generic VUX/WETH revenue policy | POL principal and fee yield receive denomination-specific special treatment outside the general waterfall | **SUPERSEDED/REFINED** |
| exact research waterfall/caps could become assumed policy | exact general waterfall, operator share/caps, LSG gates, ROOT/GIGA caps, dry powder, and bribe hurdles are guidance only | **RESERVED, NOT FROZEN** |
| external LSG repository's `DEFERRED_NOT_V1` label might imply product exclusion | label remains source-reuse disposition only; VUX-original product role is core mature | **CLARIFIED** |

## 4. Founder Freeze section disposition

The predecessor Founder Freeze is superseded in full so that consumers never merge two documents ad hoc. The successor carries forward unaffected values as follows:

| predecessor location | disposition in successor |
|---|---|
| §1 Status and §9 Handoff | replaced by accepted-successor activation and fresh-PRD handoff |
| §2 Binding doctrine | FAIR and Hard doctrine preserved; `80/20/0` and economically closed identity superseded |
| §3 rows 1–7 | preserved: 150,000 POL VUX, exact total supply, zero users, genesis WETH targets, `P0/N0`, external genesis cap |
| §3 row 8 | preserved as Strategic/undeployed at genesis and expanded into first-class Strategic semantics |
| §3 rows 9–23 | preserved: epoch, multiplier, UPS, halvings, tail, bootstrap King/clock/price targets, redemption, graduation/tail points |
| §3 row 24 | shallow genesis POL preserved; later POL size/timing made explicitly adaptive; POL-special VYRF added |
| §3 row 25 | no active LSG at launch preserved; “v1.1 optional/deferred” superseded by core mature/operator-activation role; exact thresholds remain unfrozen |
| §3 row 26 | no founder/operator genesis or primary compensation preserved; legitimate realized-economics operations policy added without a fixed percentage |
| §4 Genesis accounting | exact VUX/WETH genesis values preserved; Strategic 12% activation receipt added |
| §5 Mining/TGE schedule | preserved without recalibrating 4 UPS or raw opportunity |
| §6 Bootstrap | full-payment-to-Hard conclusion superseded by approximately 88% or greater Hard / 12% Strategic / zero mint |
| §7 Not frozen | preserved and expanded with Strategic, POL, LSG, revenue, ROOT/GIGA, dry-powder, and bribe operator reservations |
| §8 Earlier supersessions | preserved; no historical 20M genesis, 17M public allocation, 85/15 genesis, 90-day halvings, `1/32` tail, or one-hour epoch is revived |

## 5. Canonical Specification section disposition

| predecessor location | disposition in successor |
|---|---|
| §§1–2 Status/one-page identity | replaced with the corrected dual-treasury identity and authority order |
| §3 Product doctrine | FAIR/SIMPLE/ELEGANT/SECURE preserved; mature Strategic purpose added without infecting mining UX |
| §4 Scope/exclusions | launch core preserved; Strategic receipt, POL VYRF, and explicit mature LSG added; architecture choices remain excluded |
| §5 System model | expanded with Strategic custody/accounting, fee policy, general revenue, risk/admission, LSG, and execution roles |
| §§6–8 Genesis, supply, Hard Reserve | preserved except additions for POL non-voting and POL-special burns; no Hard weakening |
| §9 KOTH | `80/20` replaced with exact `80/8/12` arithmetic |
| §§10–11 Pricing and mining clock | preserved |
| §12 VEM | preserved mathematically; `D` clarified as exact current-settlement Hard-only `D_R`; Strategic credit expressly zero |
| §13 Greed | “20% Reserve leg” wording replaced by capitalization through static Hard and Strategic legs; VEM behavior preserved |
| §14 Bootstrap | full Hard activation replaced by approximately 88% or greater Hard / 12% Strategic / zero mint |
| §15 Settlement truth | expanded to require Strategic receipt and three-leg observability while preserving atomicity and VEM ordering dependencies |
| §16 POL and Strategic capital | POL boundaries preserved and expanded; Strategic becomes first-class; adaptive deployment and failure independence made canonical |
| §17 Revenue policy | generic all-VUX-burn/all-WETH-Hard rule replaced by POL-special VYRF plus principle-based adaptive general revenue policy |
| §§18–19 UX and contestability | preserved |
| §20 LSG compatibility | replaced by core mature, operator-threshold-activated LSG role over admitted marginal Strategic capital |
| §21 RH WETH trust | preserved |
| §22 Invariants | all Hard/supply invariants preserved; routing, Strategic, POL VYRF, LSG, and failure-independence invariants updated/added |
| §23 Failure behavior | preserved and expanded; no Strategic failure reaches Hard |
| §24 Reserved values | expanded with portfolio, POL, LSG, revenue, ROOT/GIGA, dry-powder, and bribe decisions |
| §25 Licensing | replaced by reference to the completed preserved provenance freeze and narrow delta |
| §26 Future compatibility | LSG moved from optional future concept to phased mature capability; other unrelated concepts remain unresolved/excluded |
| §27 Loa handoff | old cycle and stale PRD superseded; fresh `/plan-and-analyze` is the authorized next node |

## 6. Provenance and source-registry disposition

No existing pin, allowlist entry, licence conclusion, collaborator-permission scope, or notice changes.

| base authority location | disposition |
|---|---|
| provenance freeze §§2, 4, 6, 9, 13–17 | preserved exactly |
| provenance freeze §7 Hard Reserve and §8 VEM | preserved; corrected routing/VEM implementation remains clean-source outside the explicit Miner allowlist |
| provenance freeze §§10 and 12 gumball/Olympus | preserved as reference/prohibited; no VYRF/POL port authorized |
| provenance freeze §11 LSG | no-copy/import disposition preserved; product deferral meaning superseded only by the narrow delta |
| provenance freeze §19 handoff | future fresh PRD consumes base freeze plus delta and successor authority |
| base JSON source registry | byte-preserved; all existing machine facts remain current |
| JSON Strategic-Treasury delta | adds only VUX-original classifications and source-versus-product clarification; no source pins or allowlist entries |

## 7. Preserved load-bearing rules

The supersession does not reopen:

- one throne, canonical RH WETH payment, 80% King recycle, 50-minute epoch, or 2× multiplier;
- 4 UPS, eight monthly halvings, `1/256` tail, and raw-opportunity framing;
- zero discretionary/user genesis VUX and no privileged post-genesis mint;
- ownerless immutable raw-WETH Hard Reserve and fee-free pro-rata redemption;
- all-inclusive `S = totalSupply()`, raw canonical RH WETH only in `B`, and `S_MIN`;
- exact current-settlement Hard-only VEM and monotonic Hard `B/S`;
- no carry, IOU, makeup, debt, Strategic-NAV mint, or recapitalization mint;
- truthful clock/estimate/final-mint UX;
- fair access without equal-outcome or anti-whale machinery;
- no post-genesis POL mint and no Reserve-funded/redeemed protocol POL;
- Strategic failure independence;
- canonical RH WETH YELLOW external trust disclosure;
- GPL-3.0-or-later, existing source pins/allowlist, and `THIRD_PARTY_NOTICES.md` posture.

## 8. Fresh-PRD acceptance answers

| question | unambiguous authority answer |
|---|---|
| What is VUX? | Permissionless KOTH/TGE + ownerless Hard Reserve + productive Strategic Treasury + protocol-owned market infrastructure + bounded mature LSG. |
| Why both treasuries? | Hard is the enforceable raw-WETH exit right; Strategic is separately risked productive capital and mature utility. |
| Ordinary payment destination? | Exact floor-rounded `80/8/12`, with dust to Hard and zero other primary recipient. |
| What funds issuance? | Exact realized current-settlement Hard WETH `D_R` only. |
| What never funds issuance? | Strategic WETH/NAV, POL, ROOT/GIGA, stable assets, prices, or expected yield. |
| What does 4 UPS promise? | Maximum raw time opportunity, not target supply, entitlement, debt, or guaranteed mint. |
| Bootstrap? | Ownerless Reserve outgoing King; zero clock/mint; approximately 88% or greater Hard and 12% Strategic. |
| Strategic principal? | Protocol-owned risk capital, including contributed/returned capital and POL principal; not Hard or distributable revenue. |
| Realized revenue? | Source-classified realized yield/fees/profit; never returned principal or unrealized marks. |
| POL VUX fee yield? | Burn. |
| POL WETH fee yield? | One-way Hard Reserve. |
| POL principal revenue? | No; returned principal remains Strategic. |
| Can protocol POL VUX redeem? | Not as treasury conduct. |
| Can protocol POL VUX vote in LSG? | No. |
| What may LSG control? | Relative marginal Strategic allocation among admitted opportunities only. |
| Who activates LSG? | Operators, affirmatively, after internal readiness thresholds. |
| Are numeric LSG gates frozen? | No. |
| Are general revenue percentages frozen? | No. |
| Strategic total loss? | Hard, redemption, KOTH, VEM, supply constraints, and no-recap-mint rule survive. |
| Can Reserve rescue Strategic? | No authorized path. |
| Can founders/operators receive primary mining flow? | No. Legitimate realized economics or disclosed external runway may fund operations. |
| Why own VUX after mining cools? | Hard exit right plus productive Strategic NAV, protocol-owned liquidity, bounded allocation influence, compounding, and verified ecosystem optionality. |

## 9. Lifecycle disposition

This node creates authority only. It does not edit the stale PRD, choose architecture, implement code, select dependencies, create a sprint, commit, push, or invoke Loa.

Authorized next node:

> fresh Loa `/plan-and-analyze`

**STOP. Wait for operator review.**
