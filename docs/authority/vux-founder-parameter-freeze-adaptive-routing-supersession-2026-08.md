# VUX Founder Parameter Freeze — Adaptive-Routing Supersession Delta

**Date:** 2026-08-12
**Status:** `FOUNDER_AUTHORITY_CURRENT_ACCEPTED`
**Form:** narrowly scoped supersession delta (house precedent: provenance boundary delta, toolchain refreeze). This document **amends** the base freeze; it does not replace it.
**Base (amended, preserved unedited):** `vux-founder-parameter-freeze-strategic-treasury-supersession-2026-08.md` — SHA-256 `b9b6a81db8c318e91601b3349283cab1654964c05d1d8e360b4971b7b1828723`
**Controlling decision record:** `vux-founder-acceptance-adaptive-routing-lsg-holder-liquidity-2026-08.md` (`FOUNDER_ACCEPTANCE_COMPLETE`, 2026-08-12) — SHA-256 `a0d5d38bf9b631a12d6f22cbe66007f9c64cdb0f43a2d9de080b5f48c8f4dac3`
**Acceptance basis:** the decisions rendered here arrived founder-approved in the acceptance-node dispatch and are frozen verbatim in the controlling record; this delta is their faithful rendering by the authorized consolidated reconciliation node. Where this delta and the controlling record could be read differently, the controlling record governs.

## 1. Activation and precedence

The current Founder Parameter Freeze is the base document **as amended by this delta**. Rows and sections named below are superseded, refined, or added exactly as stated; every base parameter not named here is preserved unchanged. The base document and all earlier predecessors remain immutable historical authority evidence.

This delta authorizes no implementation, no lifecycle invocation, and no source-provenance expansion. The old-to-new disposition is recorded in `vux-v1-authority-supersession-map-2026-08.md` §10.

## 2. Authority classification (extended)

The base's three classes (**FROZEN** / **OPERATOR-RESERVED, ADAPTIVE** / **RESEARCH GUIDANCE, NOT AUTHORITY**) are retained and one class is added:

- **FOUNDER-ACCEPTED FUTURE DOCTRINE** — binding product doctrine for a future (post-v1-launch or mature-phase) surface. Not operator-adjustable; changeable only by a new founder decision. It creates **no v1 implementation requirement** and its numeric values are policy/design doctrine, **never v1 contract constants**.

Silence still never converts guidance into a frozen value; no reserved or doctrinal decision may violate a frozen boundary.

## 3. Superseded and refined FROZEN rows (ordinary routing)

### 3.1 Base §3 #7 and #8 — SUPERSEDED

Ordinary primary routing and split arithmetic are now the **adaptive 8%-floor retained-capital routing law**. For ordinary non-bootstrap settlement with exact payment `P` (basis-point denominator 10,000):

```text
king         = floor(P × 8,000 / 10,000)
retained     = P − king
strategicCap = floor(P × 1,200 / 10,000)
hardFloor    = retained − strategicCap      // nominal ≥8%; carries all split dust
D_need       = ceil(Qraw × B_pre / S_pre)
hardTarget   = min(retained, max(hardFloor, D_need))
strategic    = retained − hardTarget
```

After actual transfers:

```text
D_actual = exact measured canonical WETH increase in the Hard Reserve caused by this settlement
Qsafe    = floor(D_actual × S_pre / B_pre)
Qmint    = min(Qraw, Qsafe)
```

Binding clarifications (verbatim force from the controlling record §3.A):

1. **Symbols.** `D_actual` **is** the base authority's `D_R` (`D_actual ≡ D_R`). `D_need` and `hardTarget` are new canonical symbols.
2. **Economic bounds.** Outgoing King remains exactly the floor-rounded 80%. Hard receives between the nominal 8%-plus-dust floor (`hardFloor`) and the full retained 20% (`retained`), as the settlement's issuance requirement dictates. Strategic receives the residual, capped at the floor-rounded 12% (`strategicCap`). Near backing, Strategic can be zero for extended periods — an accepted product identity.
3. **Dust.** All split dust continues to land in Hard (`hardFloor` carries it); the Reserve-favoring rounding doctrine is preserved.
4. **Fail-closed measurement.** The fail-closed inconsistent-delta rejection is preserved and now checks the measured `D_actual`/`D_R` against the routed adaptive `hardTarget`. Full-precision safe arithmetic throughout; issuance rounds down, required-contribution rounds up.
5. **No carry.** No carry, IOU, makeup, debt, entitlement, high-water emission, or recapitalization claim exists — unchanged.

### 3.2 Base §3 #9 — REFINED (narrowed, not deleted)

The monetary-routing prohibition survives with its external scope intact: **no macro, market-price, NAV, Strategy-return, ROOT/GIGA-price, calendar-phase, oracle-mediated, or operator-discretion dynamic KOTH router.** The sole sanctioned adaptivity is the settlement-local, deterministic monetary-closure branch above, whose complete input set is `(P, Qraw, B_pre, S_pre)`. External, discretionary, and oracle-mediated routing remain prohibited exactly as before.

### 3.3 Base §6 (canonical ordinary settlement and VEM) — REPLACED formula block

The base §6 split block (`king/strategic/reserve` static floors) is replaced by the §3.1 formula block above. The VEM paragraph is preserved with one wording refinement: `D_R` "is not an assumed 8%" becomes "**is not the routed target**" — the measured-delta principle is unchanged; the Strategic transfer still receives zero issuance credit; settlement remains atomic with full-precision arithmetic.

### 3.4 Confirmed unchanged (explicit)

- **VEM (base #14–#18):** Hard-only measured-delta issuance, `Qsafe`/`Qmint`, the monotone `B/S` issuance invariant, no-carry, and UPS≤VEM limits — **CONFIRMED**, with `D_actual ≡ D_R`. VEM is never weakened to preserve Strategic revenue.
- **Bootstrap (base #25–#28):** with `Qraw = 0`, `D_need = 0`, so `hardTarget = hardFloor` and `strategic = strategicCap` — the adaptive law **degenerates to the identical prior split with no special case**. Bootstrap remains ~0% outgoing public King (the 80% leg terminates at the Reserve-as-King), 88%-or-greater Hard, 12% Strategic, zero VUX issuance, unchanged price targets — **CONFIRMED**.
- **Hard/Strategic separation, Reserve properties, redemption (base #10–#13), POL VYRF (#39–#40), revenue boundaries (#41–#46), LSG boundary (#47–#51), bribe posture (#52), and every other base row not named in this delta** — preserved.

## 4. Amended OPERATOR-RESERVED rows (base §4)

| base row | disposition |
|---|---|
| "General realized-revenue waterfall — Operators/cofounders set and evolve exact percentages…" | **SUPERSEDED IN PART** — the percentages are now founder-accepted doctrine (§5.1 below). Operator-reserved remains: qualifying-revenue computation under the accepted definition, budget approval, at-least-quarterly reforecast, and draw execution **inside** the accepted waterfall and Operator Reserve semantics. |
| "Operations budget and compensation — exact shares, caps, reserves … adapt" | **SUPERSEDED IN PART** — the operator leg is now the Operator Reserve contribution (§5.2 below). Budget approval and spending execution remain operator-executed policy inside those semantics; the frozen floors (#41–#46) still apply beneath. |

All other base §4 reservations (portfolio weights, POL sizing, deployment timing, dry powder, Strategy admission, LSG activation timing and internal readiness thresholds, ROOT/GIGA exposure, bribe sizing, market-infrastructure tactics, deployment facts) are preserved.

## 5. FOUNDER-ACCEPTED FUTURE DOCTRINE (new rows; no v1 implementation)

None of the following creates a Sprint 3 or cycle-002 implementation requirement, contract constant, or acceptance criterion. Waterfall percentages and LSG timing below are founder doctrine — no longer operator-adjustable, changeable only by a new founder decision — but they are policy/design doctrine, not v1 contract constants.

### 5.1 Strategic realized-revenue waterfall

For qualifying realized net non-POL Strategic revenue:

```text
50% -> Strategic compounding / Dry Powder floor
25% -> Operator Reserve
20% -> qualified active LSG pool
 5% -> Hard Reserve one-way
 0% -> speculative/gambling allocation
```

Qualifying revenue is computed after direct realization costs and realized-loss/high-water restoration, and excludes returned principal, unrealized marks, POL principal, and POL fee yield (POL VYRF #39–#40 unchanged). Unused or unqualified legs compound to Strategic; an inactive or unqualified LSG epoch's 20% compounds and is never carried as an entitlement and never redirected to Hard (#51 preserved). Rewards are paid only from realized cash assets, never newly emitted VUX. **Harmonization of #42:** "market infrastructure" remains a permitted use, funded via Strategic capital deployment policy (from compounded Strategic capital) — it is **not** a dedicated waterfall leg.

### 5.2 Operator Reserve

The 25% leg is a protocol-owned reserve **contribution**, not a same-period operator entitlement: protocol property with no personal claim before a permitted expense is approved and incurred; purpose-limited to actual approved protocol operating costs (infrastructure/hosting, security, audits, legal/accounting, contributor continuity); separately accounted within approved Strategic custody with no standalone operator-owned arbitrary-call treasury; target ≈ **18 months** of approved forward operating expenses (an **operating-policy parameter**, not an immutable monetary constant — reforecast at least quarterly; excess sweeps to Strategic compounding); drawable during weak-revenue periods for approved actual costs; **no automatic Hard or Strategic-principal fallback**; transparent per-period opening/credits/spending/sweeps/closing reporting; earmarked reserve assets are not LSG-deployable Strategic risk capital and are excluded from the allocator opportunity set. The prior research `2.5% of average Strategic NAV` ceiling no longer controls the reserve target or period spending; it may persist only as an optional monitoring ratio.

### 5.3 LSG active-signaling doctrine

C-class verdict retained: LSG is a strong **mature** product pillar, not activated merely because the mechanism exists; no passive staking yield. Only external VUX that is (1) held in canonical LSG custody, (2) sufficiently aged, (3) freshly signaling in the current epoch, and (4) frozen through the epoch may earn the LSG revenue pool. Zero LSG vote/signal weight and zero LSG rewards for protocol-owned VUX, POL VUX, lending collateral, external LP VUX, inactive VUX, and liquid wallet VUX. **One-status doctrine:** one raw VUX → one custody-defined economic status → at most one LSG reward claim; no receipt- or wrapper-derived duplicate rights.

**Timing (normal operation):** minimum continuous stake age **7 days** before epoch open; epoch length **14 days**; fresh complete signal in the **first 24 hours**; opening eligible weight fixed and eligible stake frozen through epoch close; no carry-forward signal, no auto-vote, no same-transaction stake/signal/reward/exit. **First paid activation:** preferred — open staking ≥7 days before the first paid epoch and apply normal 7/14 rules from epoch one; fallback **only** if that warm-up is operationally unavailable — a one-time prior-block eligibility snapshot before the first signal window, no same-block deposits, fresh first-epoch signal, full 14-day freeze, exception consumed permanently and never recreated after pause/migration/reactivation.

### 5.4 LSG reward attribution

Global active-signal pool. Rejected: individual profitable-Strategy reward multipliers; subjective correctness rewards; reward-bearing delegation at first activation; retroactive winner bonuses. Signal quality may be observed (shadow analytics), never economically rewarded initially.

### 5.5 Dry Powder

A capital-allocation **state** (do not deploy marginal Strategic capital into discretionary risk Strategies now), conceptually distinct from USDG or any custody asset; physical assets may include approved WETH/USDG/cash-equivalent custody; USDG yield/risk exposure can itself be a Strategy; changing custody assets must not rewrite historical signals. No new Dry Powder token or contract is implied.

### 5.6 Capital Allocator Record (non-economic reservation)

Preserve the factual historical data for a future non-economic Capital Allocator Leaderboard (epoch opportunity set; allocation vectors; eligible weight; executed allocation; principal movement; direct costs; realized P/L; drawdowns/analytics; Dry Powder calls; admission/cap/pause changes). No frozen scoring formula. Leaderboard standing must never affect LSG rewards, voting/signal weight, access, delegation, Strategy admission, or retroactive payouts. Approximately **12 months** of clean history before considering ranking is the current research posture, not a frozen number. The already-planned event/observability surfaces satisfy this reservation; it creates no new v1 contract requirement.

### 5.7 LSG activation gate posture

Do not launch LSG until Strategic economics make active attention worthwhile; inactive/unqualified allocation compounds. The LSG research §16 evidence-gate set (Strategic accounting separability; ≥2 meaningful admitted destinations + Dry Powder; trailing qualifying revenue supporting ≥ ~$25K annualized LSG pool at 20%; committed external VUX ≥ max(100K, 5% of non-protocol supply); ≥10 effective participants with no known controller >35%; reconciled non-voting protocol custody; independent audit; operator halt/recall capability) **replaces the base §5 illustrative LSG-gate row as the current recommended evidence posture** — guidance replacing guidance; these remain evidence-based operator-reserved recommendations, **not** founder-frozen numbers (#50 preserved).

### 5.8 Future lending / holder liquidity

Do **not** build custom VUX lending now. Preferred future shape: an externally funded isolated VUX/WETH lending market; Morpho-style integration is the current leading candidate (a candidate, not a dependency), subject to future deployment diligence; raw VUX collateral; canonical RH WETH debt first; **exact Hard redemption value is the only VUX collateral valuation basis** — no Strategic NAV, no spot premium, no anticipated Hard inflows. **LLTV posture (future market-risk doctrine, evidence-gated, not v1 constants):** pilot effective floor LLTV ≤ **25%**; preferred mature candidate ≤ **1/3**, only after real production evidence; **no planned progression to 40%** — 40% survives only as a future research-reopening ceiling requiring a new founder decision (50% remains rejected). **Capital boundaries:** external voluntary lenders only; the Hard Reserve must never lend, guarantee, subsidize, backstop, absorb bad debt, or provide special lender redemption; the Strategic Treasury must not lend, guarantee, subsidize, provide first-loss capital, or absorb market bad debt; protocol-owned POL/liquidity capital must not serve as lending capital or backstop. **Looping:** economically possible, officially unsupported — no loop UI/composite, no advertised leverage multiple, no protocol subsidy. **Stablecoin debt:** fully deferred; no WETH/USD oracle or stablecoin architecture reservation now. **Status interaction:** collateralized VUX has no LSG vote, signal, delegation, or reward; external LP VUX has no LSG rights while committed to LP custody; LP receipts/NFTs do not inherit eligibility; only raw VUX returned to canonical LSG custody satisfying ordinary eligibility may later regain LSG status.

## 6. New v1-BINDING rows

| # | parameter or boundary | binding value / outcome |
|---:|---|---|
| A-1 | Ordinary adaptive routing law | The §3.1 formula block, with clarifications §3.1(1)–(5) and the §3.2 narrowed prohibition. |
| A-2 | No pre-Sprint-3 lending machinery | No lending hook, approved-market registry, wrapper/receipt interface, oracle surface or price-oracle dependency, collateral-status storage in VUX, transfer restriction, special redemption path, or lender approval from Hard is required or permitted before Sprint 3. The existing standard ERC-20 surface and Hard Reserve read surfaces (`VUX.totalSupply()`, `HardReserve.backing()`, `HardReserve.previewRedeem(q)`) preserve all future integration optionality. |
| A-3 | One-status product doctrine | FAIR · SIMPLE · ELEGANT · SECURE remain co-equal. The future product suite serves distinct external-holder use cases (liquid ownership/redemption; active LSG signaling; collateralized external borrowing; external LP provision) as **distinct economic statuses**, never simultaneous duplicated rights on one raw VUX unit. This is design doctrine — it authorizes **no** v1 status machinery. |

## 7. Amended RESEARCH GUIDANCE rows (base §5)

| base §5 row | disposition |
|---|---|
| `50% / 10% / 25% / 10% / 5%` five-way waterfall baseline | **SUPERSEDED as guidance** — replaced by the founder-accepted four-leg `50/25/20/5/0` doctrine (§5.1). The five-way values are historical only and must appear nowhere as active values. |
| `25%` operator share | **SUPERSEDED as guidance** — the 25% is now the founder-accepted Operator Reserve leg (§5.2), doctrine rather than guidance. |
| `2.5%` average Strategic NAV operator ceiling | **DEMOTED** — optional monitoring ratio only; controls nothing. |
| LSG gates `60 days / 5M distributed / 50 holders / 10 participants / 35% ceiling / $250K` | **REPLACED as guidance** by the research §16 evidence-gate set (§5.7) — guidance → guidance; nothing frozen. |
| ROOT/GIGA caps, dry-powder rows, bribe-measurement rows | Preserved as research guidance, unchanged. |

## 8. Handoff

The current Founder Parameter Freeze is the base document as amended by this delta, consumed together with the amended Canonical Specification (`vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md` as amended by `vux-v1-canonical-specification-adaptive-routing-supersession-2026-08.md`), the preserved provenance authority chain, and the updated supersession map. The reconciled PRD/SDD/Sprint Plan carry these decisions into planning. `/implement sprint-3` remains blocked until **both** (a) the consolidated reconciliation is accepted and (b) the independent M-1/L-3/L-4 provenance-tooling hardening condition is closed. This document invokes nothing.
