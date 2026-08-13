# VUX v1 Strategic-Treasury Authority Supersession Map

**Date:** 2026-08-09  
**Status:** `SUPERSESSION_MAP_CURRENT_ACCEPTED`  
**Operator acceptance:** 2026-08-09 — `OPERATOR_ACCEPTANCE`  
**Lifecycle disposition:** bounded authority reconciliation; no downstream lifecycle invoked  
**Updated:** 2026-08-12 — §1 and §10 amended by the authorized consolidated reconciliation node (adaptive-routing supersession, controlling record `vux-founder-acceptance-adaptive-routing-lsg-holder-liquidity-2026-08.md`); §§2–9 preserved unedited as accepted history and read subject to §10.

## 1. Activation rule and current authority

Operator acceptance of the strategic-treasury supersession was recorded on 2026-08-09; the founder adaptive-routing acceptance was recorded 2026-08-12 and rendered into supersession deltas by the consolidated reconciliation node (§10). Current authority is unambiguous:

| precedence | current authority | disposition |
|---:|---|---|
| 1 | `vux-founder-parameter-freeze-strategic-treasury-supersession-2026-08.md` **as amended by** `vux-founder-parameter-freeze-adaptive-routing-supersession-2026-08.md` | current Founder Parameter Freeze (base + 2026-08-12 delta; delta wins on its named rows) |
| 2 | `vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md` **as amended by** `vux-v1-canonical-specification-adaptive-routing-supersession-2026-08.md` | current VUX v1 product specification (base + 2026-08-12 delta) |
| 3 | `vux-founder-acceptance-adaptive-routing-lsg-holder-liquidity-2026-08.md` | controlling founder decision record for the 2026-08-12 supersession; governs interpretation of the two deltas |
| 4 | `vux-v1-strategic-treasury-provenance-boundary-delta-2026-08.md` and `vux-v1-source-registry-strategic-treasury-delta-2026-08.json` | narrow corrected-surface source delta |
| 5 | `vux-v1-licence-provenance-source-pin-freeze-2026-08.md` and `vux-v1-source-registry-2026-08.json`, supplemented by the self-describing OZ/v3-core refreeze (`vux-v1-oz-v3-provenance-refreeze-2026-08.md` + JSON) and Foundry v1.5 toolchain refreeze (`vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md` + JSON) | preserved licence/pin/reuse authority chain |
| 6 | this map | authoritative old-to-new disposition and lifecycle record |
| 7 | prior research/closure artifacts | evidence/history only where not superseded above |

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

## 9. Lifecycle disposition (2026-08-09 — historical; completed)

This node creates authority only. It does not edit the stale PRD, choose architecture, implement code, select dependencies, create a sprint, commit, push, or invoke Loa.

Authorized next node:

> fresh Loa `/plan-and-analyze`

*(2026-08-12 note: that cycle ran and completed — PRD v2.0.0, SDD v1.6.0, Sprint Plan v1.0.0 all operator-accepted; Sprints 1–2 landed. The current lifecycle state is recorded in §10.)*

## 10. Adaptive-routing supersession (2026-08-12)

### 10.1 Event and artifacts

The founder accepted the adaptive 8%-floor retained-capital routing law, the Strategic realized-revenue waterfall / Operator Reserve doctrine, the LSG epochal doctrine, and the future holder-liquidity (lending) doctrine on 2026-08-12. The authorized consolidated reconciliation node rendered that acceptance into successor authority deltas and reconciled the planning chain. Pinned artifacts:

| artifact | SHA-256 | role |
|---|---|---|
| `vux-founder-acceptance-adaptive-routing-lsg-holder-liquidity-2026-08.md` | `a0d5d38bf9b631a12d6f22cbe66007f9c64cdb0f43a2d9de080b5f48c8f4dac3` | controlling founder decision record (`FOUNDER_ACCEPTANCE_COMPLETE`) |
| `vux-founder-parameter-freeze-adaptive-routing-supersession-2026-08.md` | `89687ecc9b5ff849b2341d4684ee8e089675a776c7a5a69fc92d7dddc8892b51` | Founder Freeze supersession delta (current, with base) |
| `vux-v1-canonical-specification-adaptive-routing-supersession-2026-08.md` | `04512412b416cad395e99bdb16e00b9082e3436e24369ef5b875b4f8e368c1aa` | Canonical Specification supersession delta (current, with base) |

### 10.2 Preserved predecessor evidence (unedited by the 2026-08-12 node)

| predecessor | SHA-256 at supersession | disposition |
|---|---|---|
| `vux-founder-parameter-freeze-strategic-treasury-supersession-2026-08.md` | `b9b6a81db8c318e91601b3349283cab1654964c05d1d8e360b4971b7b1828723` | remains current base, amended by the freeze delta; byte-preserved |
| `vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md` | `d2b2d1a344b75b2e45790af60039ea4ad420626281e0c80191638cd88d8a950a` | remains current base, amended by the spec delta; byte-preserved |
| this map (pre-update) | `a6554f795dedd27d6551b4a19e195c4134e8b2de0b9db427837fa61fd442dbbe` | §§2–9 preserved; §1 and this §10 amended/added |

### 10.3 Rule-level supersession summary

Full dispositions are in the controlling record §5 and the two deltas; the load-bearing rows:

| old current-authority rule | replacement | classification |
|---|---|---|
| Ordinary routing: static gross `80/8/12` (FREEZE #7–#8; SPEC §12) | Adaptive 8%-floor law: `king = floor(80%)`; `hardTarget = min(retained, max(hardFloor, D_need))`; `strategic = retained − hardTarget` (Hard ∈ [8%+dust, 20%]; Strategic ∈ [0%, 12%]; dust to Hard) | **SUPERSEDED** |
| "Static `80/8/12`; no dynamic router" (FREEZE #9; SPEC §12 prohibition) | External/discretionary/oracle prohibition retained verbatim; the settlement-local monetary-closure branch on `(P, Qraw, B_pre, S_pre)` is the sole sanctioned adaptivity | **REFINED (narrowed)** |
| VEM measured-delta issuance; monotone `B/S`; no carry (FREEZE #14–#18; SPEC §13) | Unchanged; `D_actual ≡ D_R`; "not an assumed 8%" reworded "not the routed target" | **CONFIRMED** |
| Bootstrap ≈88%+/12%/0-mint (FREEZE #25–#28; SPEC §14) | Unchanged — the adaptive law degenerates to the identical split at `Qraw = 0` | **CONFIRMED** |
| General waterfall percentages operator-reserved (FREEZE §4; SPEC §18, §24.4 #31) | Percentages founder-accepted `50/25/20/5/0` + Operator Reserve semantics (≈18-month operating-policy runway target); execution remains operator-reserved; never v1 contract constants | **SUPERSEDED IN PART** |
| `50/10/25/10/5` baseline, 25% share, 2.5% NAV ceiling as guidance (FREEZE §5) | Five-way baseline superseded as guidance; 25% is now the Operator Reserve leg (doctrine); 2.5% demoted to optional monitoring ratio | **SUPERSEDED as guidance** |
| LSG illustrative gate values (FREEZE §5 row) | Replaced as guidance by the LSG research §16 evidence-gate set; nothing frozen (FREEZE #50 / SPEC #34 preserved) | **REPLACED as guidance** |
| LSG mechanism unreserved beyond role boundary (SPEC §4.2, §19, §26) | Economic design doctrine founder-accepted (custody eligibility, one-status, 7d/14d/24h timing, global pool, attribution rejections, evidence-gated activation); implementation and activation remain reserved, now bounded | **CONFIRMED + doctrine ADDED** |
| (no lending statement beyond SPEC §4.3 exclusion) | Future lending doctrine added (isolated external market; exact-Hard-redemption valuation; LLTV ≤25% pilot / ≤1/3 mature / 40% reopening-ceiling only; Hard/Strategic/POL never lend or backstop); zero pre-Sprint-3 lending machinery (v1-binding) | **ADDED** |

No genesis, supply, Hard Reserve, redemption, pricing, mining-clock, POL/VYRF, provenance, or licence rule is reopened; §7's preserved load-bearing rules stand except the ordinary-routing rows named above.

### 10.4 Planning-chain disposition

The reconciled planning chain (PRD v2.1.1, SDD v1.7.1, Sprint Plan v1.1.1 — revised 2026-08-12 by the focused reconciliation remediation, which corrected the P0 revenue-distribution surface to four legs, redefined `toOps` as actual-approved-expense payment only, deleted the dedicated market-infrastructure revenue leg/earmark, and marked the future Operator Reserve credit/accumulation/sweep/allocator-exclusion mechanics as a P1/future design obligation; hashes pinned in `grimoires/loa/sprint.md` and `grimoires/loa/NOTES.md`; version references to v2.1.0/v1.7.0/v1.1.0 in the two supersession deltas read on these revised documents) renders these decisions; Sprint 1 (landed `23263e18`) and Sprint 2 (landed `89a92055`) history is preserved unchanged. `/implement sprint-3` remains blocked until **both** (a) the consolidated reconciliation is accepted and (b) the independent M-1/L-3/L-4 provenance-tooling hardening condition (operator acceptance 2026-08-12, Sprint-2 carry) is closed.

**STOP. Wait for operator review of the reconciliation package.**
