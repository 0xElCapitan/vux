# VUX v1 Canonical Specification — Adaptive-Routing Supersession Delta

**Date:** 2026-08-12
**Status:** `CANONICAL_AUTHORITY_CURRENT_ACCEPTED`
**Form:** narrowly scoped supersession delta (house precedent). This document **amends** the base specification; it does not replace it.
**Base (amended, preserved unedited):** `vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md` — SHA-256 `d2b2d1a344b75b2e45790af60039ea4ad420626281e0c80191638cd88d8a950a`
**Controlling decision record:** `vux-founder-acceptance-adaptive-routing-lsg-holder-liquidity-2026-08.md` (`FOUNDER_ACCEPTANCE_COMPLETE`, 2026-08-12) — SHA-256 `a0d5d38bf9b631a12d6f22cbe66007f9c64cdb0f43a2d9de080b5f48c8f4dac3`
**Companion:** `vux-founder-parameter-freeze-adaptive-routing-supersession-2026-08.md` (the amended Founder Freeze outranks this document on overlap, exactly as the base freeze outranks the base specification).

## 1. Status and precedence

The current VUX v1 canonical specification is the base document **as amended by this delta**. Sections named below are superseded, refined, or added exactly as stated; every base statement not named is preserved. The base and all predecessors remain immutable history. This is product/monetary/authority specification only — it is not a PRD, SDD, or implementation plan and invokes no lifecycle.

## 2. Ordinary payment routing — base §12 REPLACED

For exact takeover payment `P`, with basis-point denominator 10,000 and the outgoing epoch's raw opportunity `Qraw` (base §11) and pre-settlement state `B_pre`, `S_pre` (base §13):

```text
king         = floor(P × 8,000 / 10,000)
retained     = P − king
strategicCap = floor(P × 1,200 / 10,000)
hardFloor    = retained − strategicCap      // nominal ≥8%; carries all split dust
D_need       = ceil(Qraw × B_pre / S_pre)
hardTarget   = min(retained, max(hardFloor, D_need))
strategic    = retained − hardTarget
```

Therefore:

- the outgoing King receives at most exactly 80% (`king`) — unchanged;
- the Hard Reserve receives `hardTarget`: nominally at least 8% plus all split dust (`hardFloor`), and up to the full retained 20% (`retained`) when required for safe issuance;
- the Strategic Treasury receives the residual `strategic`, capped at the floor-rounded 12% (`strategicCap`) and possibly zero — near backing, Strategic can be zero for extended periods (accepted product identity);
- all three legs sum to `P`; founders, operators, developers, signalers, and every other primary recipient receive zero (base §24.3 #20 **CONFIRMED**).

**Narrowed prohibition (replaces the base "This routing is static…" paragraph):** KOTH settlement may not branch on time phase, macro view, VUX/ROOT/GIGA price, market price relative to backing, Strategic NAV, returns, dry powder, oracle data, or operator preference. The sole sanctioned adaptivity is this settlement-local, deterministic monetary-closure computation, whose complete input set is `(P, Qraw, B_pre, S_pre)`. No oracle, market price, NAV, Strategy return, calendar phase, governance routing input, or operator discretion exists anywhere in primary settlement. Adaptive *portfolio* decisions still begin only after the Strategic leg is received and classified as Strategic principal.

**Economic interpretation:** weak/cheap settlement prioritizes Hard and mining support (all retained capital may become Hard, with VEM still capping the mint); strong/premium settlement permits more retained capital to flow Strategic (full 12% at high payment/backing ratios).

## 3. VEM — base §13 CONFIRMED, wording refined

The base §13 mathematics are unchanged and `D_actual ≡ D_R`:

```text
Qsafe = floor(D_R × S_pre / B_pre)
Qmint = min(Qraw, Qsafe)
(B_pre + D_R)/(S_pre + Qmint) ≥ B_pre/S_pre
```

Wording refinement: `D_R` "is not the nominal 8%" becomes "**is not the routed target**" — it remains the exact realized WETH increase in the Hard Reserve caused by this settlement, measured only after the Hard leg reaches the Reserve; never a quote, later deposit, market value, Strategic value, or oracle mark. The measured-delta principle, no-carry rule, and full-precision arithmetic are unchanged. The base's closing sentence becomes: greed capitalizes both Hard and Strategic surfaces **through the adaptive split** without extra issuance; the Strategic transfer receives zero issuance credit. VEM is never weakened to preserve Strategic revenue.

## 4. Settlement truth — base §15 step 6 (and step 8) REFINED

Step 6 of the base 13-step outcome becomes: "calculate `king`, `retained`, `strategicCap`, `hardFloor`, `D_need`, `hardTarget`, and `strategic` using §2 of this delta" (note: `Qraw` is already fixed at step 4, before the legs are computed). Step 8's fail-closed rejection is preserved and now rejects a measured `D_R` inconsistent with the routed adaptive `hardTarget` (plus the outgoing-King leg when the Reserve is outgoing King at bootstrap). All other steps, atomicity, and ordering dependencies are unchanged.

**Observability addition:** product observability must let users/indexers distinguish, per settlement, the adaptive quantities — `hardTarget` (the routed Hard leg) and `D_need` — in addition to the base list (`P`, all three routed amounts, `B_pre`, `S_pre`, exact `D_R`, `Qraw`, `Qsafe`, `Qmint`, bootstrap flag, Strategic principal received). `D_need` may be exposed directly or be exactly derivable from observed `Qraw`, `B_pre`, `S_pre`.

## 5. Bootstrap — base §14 CONFIRMED

With `Qraw = 0`, `D_need = 0`, so `hardTarget = hardFloor` and `strategic = strategicCap`: the adaptive law **degenerates to the base's exact split with no special case**. The first public paid takeover still routes the 80% outgoing-King leg, the nominal Hard leg, and all split dust to the Hard Reserve (Reserve is outgoing King), routes the floor-rounded 12% to Strategic custody, mints zero, and seats the first public King. The approximately-88%-or-greater Hard / 12% Strategic / zero-mint result, price targets, and cushion procedure are unchanged (base §24.3 #22 **CONFIRMED**).

## 6. Consequential base wording — SUPERSEDED to match §2

| base location | disposition |
|---|---|
| §2 one-page split block ("80% / 8% / 12% / 0%") and "The Strategic Treasury receives 12% of every takeover from the first activation onward" | Split block → the §2 adaptive law; Strategic "receives the Strategic residual (up to the floor-rounded 12%) of every takeover; at bootstrap exactly the 12% cap". "Static monetary routing does not force deployment" → "Ordinary monetary routing does not force deployment." |
| §4.1 "static `80/8/12` settlement" | → "adaptive 8%-floor settlement (delta §2)" |
| §5 KOTH/Rig row "static `80/8/12`; cannot mint outside VEM" | → "the frozen adaptive routing law (delta §2); cannot mint outside VEM" |
| §5 Strategic Treasury row "receive/account for the 12% leg" | → "receive/account for the Strategic residual leg (≤12%)" |
| §13 "through the static split" | → "through the adaptive split" (§3 above) |
| §20.3 "Static `80/8/12` routing never forces immediate deployment" | → "Ordinary routing never forces immediate deployment" (rest of §20.3 unchanged) |
| §24.3 #18 | → "Ordinary payment uses the exact adaptive arithmetic of delta §2 (`king = floor(80%)`; `strategic = retained − hardTarget`; `reserve = hardTarget = min(retained, max(hardFloor, D_need))`), with full-precision safe arithmetic." |
| §24.3 #19 | → "The Reserve receives at least the nominal 8% plus all split dust (`hardFloor`), and up to the full retained 20% when required for safe issuance; Strategic receives the residual, capped at the floor-rounded 12%." |
| §24.3 #20, #21, #22 | **CONFIRMED** unchanged (no other primary recipient; atomicity; bootstrap result). |
| §28 handoff bullet "Every ordinary payment routes `80/8/12`; no primary founder/operator share exists." | → "Every ordinary payment routes by the adaptive 8%-floor law (80% King fixed; Hard in [8%+dust, 20%]; Strategic the residual in [0%, 12%]); no primary founder/operator share exists." |

The provenance disposition is **CONFIRMED and carried over**: the adaptive routing implementation remains `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` under the same rule that governed the static split (strategic-treasury provenance delta §3); no source-reuse authority changes.

## 7. General realized revenue — base §18 SUPERSEDED IN PART

The frozen principles of base §18 (returned principal is not revenue; unrealized marks are not distributable; Hard Reserve principal funds nothing; no primary skim; no casual relabeling; F-46 burn posture; disclosed external runway) are **CONFIRMED as the floor**. Superseded in part:

- "Operators/cofounders set and may evolve exact general-waterfall percentages…" → the general waterfall percentages are now **founder-accepted future doctrine**: `50%` Strategic compounding / Dry Powder floor, `25%` Operator Reserve, `20%` qualified active LSG pool, `5%` Hard Reserve one-way, `0%` speculative — per Freeze delta §5.1, including the qualifying-revenue definition (direct realization costs and realized-loss/high-water restoration deducted) and the market-infrastructure harmonization (funded via Strategic capital deployment policy, never a dedicated leg).
- "`50/10/25/10/5`, a 25% operator share, and a 2.5% NAV ceiling are research guidance" → the five-way baseline is superseded history; the operator leg is the founder-accepted Operator Reserve (Freeze delta §5.2 semantics: protocol-owned, purpose-limited, ≈18-month operating-policy runway target, quarterly reforecast, excess sweep, no same-period entitlement, no automatic Hard or Strategic-principal fallback); the 2.5%-NAV value is demoted to an optional monitoring ratio.
- Base §24.4 #31 ("General revenue percentages and operations caps are operator-reserved…") → **SUPERSEDED IN PART**: the waterfall percentages and Operator Reserve semantics are founder doctrine; operator-reserved remains the *execution* — qualifying-revenue computation, budget approval, reforecast, draws — within the frozen funding boundaries. ROOT/GIGA caps, dry-powder deployment rules, and bribe hurdles remain guidance/operator-reserved.
- Base §26 "exact general revenue percentages" in the reserved list → now reads "general-revenue policy execution within the founder-accepted waterfall doctrine".
- §28 handoff bullet "General revenue percentages are not frozen." → "The general waterfall (`50/25/20/5/0`) and Operator Reserve semantics are founder-accepted future doctrine — policy, not v1 contract constants; LSG activation gates, ROOT/GIGA caps, dry-powder rules, and bribe hurdles remain unfrozen guidance."

These percentages remain **policy doctrine, never v1 contract constants**: no v1 contract stores waterfall ratios; the accepted call-time-argument revenue-distribution design stands.

## 8. LSG — base §19 CONFIRMED, doctrine ADDED; base §4.2 REFINED

Base §19's role and authority boundary (holders direct relative marginal Strategic allocation among admitted opportunities; operators retain admission/execution/emergency; the Hard Reserve and minting are never LSG-controlled; activation is an affirmative, unfrozen operator decision) is **CONFIRMED** — no numeric readiness gate is frozen (base §24.4 #32–#34 confirmed). Added on top, as founder-accepted future doctrine (Freeze delta §5.3–§5.7): custody-class eligibility with zero weight/rewards for protocol-owned, POL, lending-collateral, external-LP, inactive, and liquid wallet VUX; the one-status rule; 7-day minimum stake age / 14-day epochs / first-24-hours fresh signal / fixed opening eligible weight frozen through close / no carry-forward or auto-vote or same-transaction compound actions; the global active-signal reward pool with the §5.4 attribution rejections; the Dry Powder clarification; the non-economic Capital Allocator Record reservation; the evidence-gated activation posture (research §16 gate set replacing the old illustrative values as guidance).

Base §4.2's "Its activation date and mechanism are not launch-frozen" is **REFINED**: the activation date remains unfrozen and operator-decided; the mechanism's **economic design doctrine** is now founder-accepted as above; implementation detail and activation remain reserved. Base §26's reserved list ("exact LSG voting, allocation, delegation, anti-capture mechanisms…") remains reserved, now **bounded by the accepted doctrine**. LSG remains a mature product surface, not required for v1 launch; before activation the Strategic residual leg remains Strategic.

## 9. Future lending / holder liquidity — ADDED (net-new); base §4.3 CONFIRMED

Base §4.3's "V1 does not authorize … Cooler-style lending" is **CONFIRMED** — v1 still authorizes no lending. Added as founder-accepted future doctrine, verbatim in force from Freeze delta §5.8: the externally funded isolated VUX/WETH market shape (Morpho-style leading candidate, not a dependency); exact-Hard-redemption-value-only collateral valuation; the LLTV posture (≤25% pilot; ≤1/3 preferred mature candidate only after evidence; 40% only a future research-reopening ceiling, never an active planned value); the capital boundaries (Hard/Strategic/POL never lend, guarantee, subsidize, backstop, or absorb bad debt); looping unsupported; stablecoin debt fully deferred; and the lending/LSG status interaction.

**v1-binding non-requirement (Freeze delta §6 A-2):** no lending hook, registry, wrapper/receipt interface, oracle surface, collateral-status storage, transfer restriction, special redemption path, or other lending machinery may be introduced before Sprint 3; the standard ERC-20 and Hard Reserve read surfaces preserve all future integration optionality. The one-status principle (A-3) is design doctrine, not authorization for v1 status machinery.

## 10. What this delta does NOT change

Genesis and supply (base §§7–8); the Hard Reserve and redemption (base §9); KOTH pricing and the mining clock (base §§10–11); Strategic Treasury semantics (base §16); POL and POL-special VYRF (base §17); UX truth and contestability (base §§21–22); the canonical WETH trust disclosure (base §23); all invariants of base §24 except the three rows amended in §6 above; failure behavior (base §25); operator-reserved deployment values (base §26, as refined in §7–§8); licence and source boundary (base §27). The 13-step settlement remains atomic; bootstrap remains a one-time state; the fresh-PRD answers of base §28 stand as amended by §6 and §7.

## 11. Handoff

The current canonical specification is the base as amended by this delta, subordinate to the amended Founder Freeze, alongside the preserved provenance chain and the updated supersession map (§10 there records this supersession). The reconciled PRD (v2.1.0), SDD (v1.7.0), and Sprint Plan (v1.1.0) render these decisions into planning. `/implement sprint-3` remains blocked until both the consolidated reconciliation is accepted and the independent M-1/L-3/L-4 provenance-tooling hardening condition is closed. This document invokes nothing.
