# VUX Founder Acceptance — Adaptive Retained-Capital Routing, LSG & Strategic-Revenue Doctrine, Holder-Liquidity Doctrine

**Date:** 2026-08-12
**Status:** `FOUNDER_ACCEPTANCE_COMPLETE`
**Founder decision:** 2026-08-12 — decisions arrived founder-approved in the acceptance-node dispatch; this record freezes them verbatim
**Authority:** Controlling founder decision record for pre-Sprint-3 economic/product doctrine; the authoritative input to the consolidated reconciliation node. Where this record conflicts with the current accepted Founder Freeze or Canonical Specification, this record states the founder's superseding decision; the reconciliation node renders it into successor authority documents. This node edits **no** existing authority, PRD, SDD, or sprint-plan file.
**Repository baseline:** `master == origin/master == 22e5e00f42da06b7c8ec666d3690e0287eb74aed`
**Current authority at acceptance (unedited):** `vux-founder-parameter-freeze-strategic-treasury-supersession-2026-08.md` (**FREEZE**), `vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md` (**SPEC**), per `vux-v1-authority-supersession-map-2026-08.md`

## 1. Controlling research evidence (read-only, outside the repository)

All in `C:\Users\0x007\Vux Research\`; SHA-256 pinned at acceptance. Where a delta-validation artifact amends its base research, the delta-validation conclusion controls.

| artifact | SHA-256 | role |
|---|---|---|
| `vux-minimum-hard-residual-strategic-routing-research-2026-08.md` | `122ba386ae13e9bd0840ce2132fbed93b5a1f94b6b3c5bc45cef5811c373b1ef` | Decision A basis — verdict "C — 8%-FLOOR ADAPTIVE WINS" |
| `vux-lsg-active-signaling-strategic-revenue-research-2026-08.md` | `a171e6b4636264e624b75a14c35fa508ef243ab1ad51743018cbbe9e91f035fc` | Decisions B–G basis — C-class verdict |
| `vux-lsg-founder-delta-validation-2026-08.md` | `5051cf986d4f7411a8ba74fd214719ef55db5d26a5631eec49d241d5774abc49` | Validated founder deltas: Operator Reserve semantics; 7/14 timing; activation exception; Dry Powder; Allocator Record |
| `vux-holder-liquidity-cooler-v2-research-2026-08.md` | `206301b20804ab80f2199ee4a4375a76cc84ca11a9557d43c93c983514d6be69` | Decisions H–I basis |
| `vux-holder-liquidity-founder-delta-validation-2026-08.md` | `b8c7af6e7011410a28c1484e67b0a2f261ea95f1a61ae4abd5b39d5ae8fdfc03` | Validated founder deltas: ≤1/3 mature LLTV posture; 40% demotion |

The VEM dead-zone research (`vux-vem-mining-dead-zone-research-2026-08.md`) is the referenced problem-statement baseline of the routing research; evidence only.

## 2. Scope and non-actions

This node: records the accepted decisions, their supersession relationships, and the reconciliation obligations. It does **not** implement anything, begin Sprint 3, mutate product code, or rewrite the PRD/SDD/Sprint Plan. Both delta-validation artifacts terminate `DELTA_VALIDATION_COMPLETE` with no blocker to founder acceptance; no contradiction was found (§8).

## 3. Accepted founder decisions

### A. Adaptive 8%-floor retained-capital routing — **v1 BINDING**

Supersedes the ordinary static `80% King / 8% Hard / 12% Strategic` routing (FREEZE §3 #7–#9; SPEC §12). For ordinary non-bootstrap settlement with exact payment `P` (basis-point denominator 10,000; `%`-form shown for readability):

```text
king         = floor(80% * P)          // floor(P × 8,000 / 10,000)
retained     = P - king
strategicCap = floor(12% * P)          // floor(P × 1,200 / 10,000)
hardFloor    = retained - strategicCap // nominal >=8%; receives all split dust
D_need       = ceil(Qraw * B_pre / S_pre)
hardTarget   = min(retained, max(hardFloor, D_need))
strategic    = retained - hardTarget
```

After actual transfers:

```text
D_actual = measured canonical WETH actually added to Hard
Qsafe    = floor(D_actual * S_pre / B_pre)
Qmint    = min(Qraw, Qsafe)
```

Binding clarifications:

1. **Symbols.** `D_actual` in this record is the current authority's `D_R` ("exact realized Hard Reserve WETH increase caused by this settlement"). `D_need` and `hardTarget` are new canonical symbols introduced by this decision.
2. **VEM preserved exactly.** FREEZE #14–#18 (Hard-only `D_R` measured-delta issuance, `Qsafe`/`Qmint`, monotone `B/S` invariant, no carry/IOU/makeup/entitlement, full-precision safe arithmetic) are unchanged. The existing fail-closed inconsistent-`D_R` rejection (SPEC §15 step 8) is preserved and now checks the measured delta against the adaptive `hardTarget`. VEM is never weakened to preserve Strategic revenue.
3. **Economic interpretation.** Outgoing King remains exactly 80%. Hard receives between the nominal 8%-plus-dust floor and the full retained 20%, as the settlement's issuance requirement dictates. Strategic receives the residual, capped at floor-rounded 12%. Weak/cheap settlement prioritizes Hard and mining support (all retained capital may become Hard, with VEM still capping the mint); strong/premium settlement permits more retained capital to flow Strategic (full 12% at high payment/backing ratios; near backing, Strategic can be zero for extended periods — an accepted product identity).
4. **Bootstrap unchanged.** With `Qraw = 0`, `D_need = 0`, so `hardTarget = hardFloor` and `strategic = strategicCap`: the adaptive rule degenerates to today's exact split with no special case. Bootstrap remains ~0% outgoing public King (the 80% King leg terminates at the Reserve-as-King), 88%+ Hard, 12% Strategic, zero VUX issuance (FREEZE #25–#28, SPEC §14 — **confirmed**).
5. **Determinism.** Settlement-local and deterministic: inputs are exactly `(P, Qraw, B_pre, S_pre)`. No oracle, no market price, no NAV, no Strategy return, no macro/calendar phase, no governance routing, no operator discretion, no carry/IOU/makeup issuance. The existing prohibition on dynamic primary routing is **narrowed, not deleted**: external/discretionary/oracle-mediated routing stays prohibited; this intrinsic monetary-closure branch is the sole sanctioned adaptivity.
6. **Dust.** All split dust continues to land in Hard (`hardFloor` carries it), preserving the Reserve-favoring rounding doctrine.

### B. Strategic realized-revenue waterfall and Operator Reserve — **ACCEPTED FUTURE DOCTRINE** (mature product; not v1 code)

For qualifying realized net non-POL Strategic revenue:

```text
50% -> Strategic compounding / dry powder floor
25% -> Operator Reserve
20% -> qualified active LSG pool
 5% -> Hard Reserve one-way
 0% -> speculative/gambling allocation
```

Qualifying revenue is computed after direct realization costs and realized-loss/high-water restoration as established by the research, and excludes returned principal, unrealized marks, POL principal, and POL fee yield (governed by VYRF). Unused/unqualified legs compound to Strategic (an inactive or unqualified LSG epoch's 20% compounds; it is never carried as an entitlement and never redirected to Hard — FREEZE #51 preserved). Rewards are paid only from realized cash assets, never newly emitted VUX.

**POL remains special (confirmed, unchanged):** VUX-denominated POL fees → burn; WETH-denominated POL fees → Hard one-way; LP principal → Strategic capital (FREEZE #39–#40).

**Operator Reserve** — the 25% leg is a protocol-owned reserve **contribution**, not a same-period operator entitlement:

- reserve remains protocol property; no person holds a claim before a permitted expense is approved and incurred;
- purpose-limited to actual approved protocol operating costs (infrastructure/hosting, security, audits, legal/accounting, contributor continuity);
- separately accounted within approved Strategic custody; no standalone operator-owned arbitrary-call treasury;
- target ≈ **18 months** of approved forward operating expenses, expressed in expected operating expense — **not** `% of Strategic NAV`;
- reforecast at least quarterly; reserve above the approved forward requirement sweeps to Strategic compounding;
- drawable during weak-revenue periods for approved actual operating/security/audit/legal/accounting/infrastructure/contributor costs;
- no automatic Hard or Strategic-principal fallback;
- transparent opening balance / credits / spending / sweeps / closing balance reporting every period;
- earmarked reserve assets are not LSG-deployable Strategic risk capital and are excluded from the allocator opportunity set.

The 18-month runway is an **operating-policy parameter**, not an immutable monetary constant. The prior research's `2.5% of average Strategic NAV` operator ceiling no longer controls the reserve target or period spending; it may persist only as an optional monitoring ratio. The frozen funding boundaries (FREEZE #41–#46: realized-cash-only, no principal relabeling, no Hard funding, non-POL VUX revenue normally burns) remain the floor beneath this waterfall.

### C. LSG active-signaling doctrine — **ACCEPTED FUTURE DOCTRINE**

The C-class verdict is retained: LSG is a strong **mature** VUX product pillar, not activated merely because the mechanism exists. No passive staking yield. Only external VUX that is (1) held in canonical LSG custody, (2) sufficiently aged, (3) freshly signaling in the current epoch, and (4) frozen through the epoch may earn the LSG revenue pool.

Zero LSG vote/signal weight and zero LSG rewards for: protocol-owned VUX, POL VUX, lending collateral, external LP VUX, inactive VUX, and liquid wallet VUX.

**One-status doctrine:** one raw VUX → one custody-defined economic status → at most one LSG reward claim. No receipt-derived or wrapper-derived duplicate LSG rights.

**Timing (normal operation)** — accepted future product design, changeable only by a new founder decision:

- minimum continuous stake age = **7 days** before epoch open (founder delta from the base research's 14 days; validated);
- epoch length = **14 days**;
- fresh complete signal in the **first 24 hours**; opening eligible weight fixed; eligible stake frozen through epoch close;
- no carry-forward signal; no auto-vote; no same-transaction stake/signal/reward/exit.

**First paid activation** — preferred: open staking at least 7 days before the first paid epoch and apply normal 7/14 rules from epoch one. Fallback **only** if that warm-up is operationally unavailable: a one-time prior-block eligibility snapshot before the first signal window, no same-block deposits, fresh first-epoch signal, full 14-day freeze, exception consumed permanently and never recreated after pause/migration/reactivation (full constraint set: LSG delta validation §3).

### D. LSG reward attribution — **ACCEPTED FUTURE DOCTRINE**

Global active-signal pool retained. Rejected: individual profitable-Strategy reward multipliers; subjective correctness rewards; reward-bearing delegation at first activation; retroactive winner bonuses. Signal quality may be observed (shadow analytics), not economically rewarded initially.

### E. Dry Powder — **ACCEPTED DOCTRINE (clarification)**

Dry Powder is a capital-allocation **state**: do not deploy marginal Strategic capital into discretionary risk Strategies now. It is conceptually distinct from USDG or any other custody asset; its physical assets may include approved WETH/USDG/cash-equivalent custody, but the allocation decision is the doctrine; USDG yield/risk exposure can itself be a Strategy; changing custody assets must not rewrite historical signals. No new Dry Powder token or contract is implied.

### F. Capital Allocator Record / future leaderboard — **FUTURE RESERVATION (non-economic)**

Reserve the factual historical data for a future non-economic Capital Allocator Leaderboard: epoch opportunity set; user allocation vector; eligible weight; actual executed allocation; Strategy principal movement; direct costs; realized profit/loss; drawdowns/analytics; Dry Powder calls; Strategy admission/cap/pause changes. Do not freeze a scoring formula. Leaderboard standing must never affect LSG rewards, voting/signal weight, access, delegation, Strategy admission, or retroactive payouts. Require substantial clean history before considering ranking — approximately **12 months** is the current research posture. This is a data-preservation and product-surface reservation only; the already-planned event/observability surfaces satisfy it, and it creates no new v1 contract requirement.

### G. LSG activation gate — **ACCEPTED FUTURE POSTURE (evidence-gated)**

Do not launch LSG until Strategic economics make active attention worthwhile. Inactive/unqualified LSG allocation compounds. The previously recommended activation evidence gates are preserved as the current recommended evidence posture — the LSG research §16 set (Strategic accounting separability; ≥2 meaningful admitted destinations + Dry Powder; trailing qualifying revenue supporting ≥ ~$25K annualized LSG pool at 20%; committed external VUX ≥ max(100K, 5% of non-protocol supply); ≥10 effective participants, no known controller >35%; reconciled non-voting protocol custody; independent audit; operator halt/recall capability) — replacing the older illustrative gate values in FREEZE §5 as guidance. These remain evidence-based operator-reserved recommendations, **not** founder-frozen numbers (FREEZE #50 and SPEC invariant #34 preserved). LSG is a mature product surface, not required for v1 launch.

### H. Future lending / holder liquidity — **ACCEPTED FUTURE DOCTRINE (net-new; nothing built now)**

Do **not** build custom VUX lending now. Preferred future shape: an externally funded isolated VUX/WETH lending market; Morpho-style integration is the current leading candidate, subject to future deployment diligence; raw VUX collateral; canonical RH WETH debt first; **exact Hard redemption value is the only VUX collateral valuation basis** — no Strategic NAV, no spot premium, no anticipated Hard inflows.

**Future LLTV posture** (future market-risk doctrine, not v1 constants): pilot effective floor LLTV ≤ **25%**; preferred mature candidate ≤ **1/3**, only after real production evidence; **no planned progression to 40%** — 40% survives only as a future research-reopening ceiling requiring a new founder decision (50% remains a rejected single-threshold setting; recovery red line in hypothetical two-threshold analysis only).

**Lending capital boundaries:** external voluntary lenders only. Hard Reserve must never lend, guarantee, subsidize, backstop, absorb bad debt, or provide special lender redemption. Strategic Treasury must not lend, guarantee, subsidize, provide first-loss capital, or absorb market bad debt. Protocol-owned POL/liquidity capital must not serve as lending capital or backstop.

**Looping:** economically possible; officially unsupported; no VUX loop UI/composite; no advertised leverage multiple; no protocol subsidy. **Stablecoin debt:** fully deferred; no WETH/USD oracle or stablecoin architecture reservation now.

**Lending / LSG status interaction:** collateralized VUX has no LSG vote, signal, delegation, or reward. External LP VUX has no LSG rights while physically committed to LP custody; LP receipts/NFTs do not inherit eligibility. Only raw VUX returned to canonical LSG custody and satisfying ordinary eligibility may later regain LSG status.

### I. No pre-Sprint-3 lending architecture change — **v1 BINDING**

No lending hook, registry, wrapper, oracle surface, collateral-status storage, transfer restriction, special redemption path, or other lending machinery is required before Sprint 3. The existing standard ERC-20 surface and Hard Reserve read surfaces (`VUX.totalSupply()`, `HardReserve.backing()`, `HardReserve.previewRedeem(q)`) preserve all future integration optionality.

### J. Product doctrine — **CONFIRMED**

FAIR · SIMPLE · ELEGANT · SECURE remain co-equal pillars. The accepted future product suite serves distinct external-holder use cases — liquid ownership/redemption; active LSG signaling; collateralized external borrowing; external LP provision — as **distinct economic statuses**, never simultaneous duplicated rights on one raw VUX unit.

## 4. Authority classification

### 4.1 v1-binding now (Sprint-3-relevant after reconciliation)

| decision | binding content |
|---|---|
| A | Adaptive ordinary routing law (formulas above), preserved VEM, preserved bootstrap, determinism constraints, dust-to-Hard |
| I | Zero lending machinery before Sprint 3; standard surfaces preserved |
| J | Product pillars; one-status principle as design doctrine |
| Confirmations | POL VYRF (#39–#40), revenue boundaries (#41–#46), LSG P0 boundary + operator activation authority (inactive at launch), non-voting protocol POL VUX |

### 4.2 Future reserved doctrine (binding doctrine; no v1 implementation)

B (waterfall + Operator Reserve), C (LSG eligibility/timing), D (attribution), E (Dry Powder), F (Allocator Record reservation), G (activation posture), H (lending doctrine). None of these creates a Sprint 3 (or cycle-002) implementation requirement.

### 4.3 Policy / evidence-gated parameters — explicitly NOT immutable constants

| parameter | class |
|---|---|
| 18-month Operator Reserve runway target | operating-policy parameter; quarterly reforecast |
| LLTV pilot ≤25%, mature ≤1/3, 40% reopening ceiling | future market-risk doctrine; evidence-gated; not v1 constants |
| LSG activation evidence gates (research §16 set) | evidence-based operator-reserved recommendations; no frozen numbers (FREEZE #50 preserved) |
| ~12-month Allocator Record history before ranking | research posture, not a frozen number |

Waterfall percentages (50/25/20/5/0) and LSG timing (7/14/24h) are founder-accepted doctrine: no longer operator-adjustable, changeable only by a new founder decision — but they are policy/design doctrine, not v1 contract constants.

## 5. Supersession disposition (current authority → this acceptance)

FREEZE = `vux-founder-parameter-freeze-strategic-treasury-supersession-2026-08.md`; SPEC = `vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md`. Nothing below is edited by this node; the reconciliation node renders these dispositions into successor documents.

### 5.1 Routing (decision A)

| current authority statement | disposition |
|---|---|
| FREEZE §3 #7 "Ordinary primary routing … `80 / 8 / 12` … nominally at least 8% Hard, 12% Strategic" | **SUPERSEDED** — 80% King fixed; Hard adaptive in [8%+dust, 20%]; Strategic residual in [0%, 12%] |
| FREEZE §3 #8 "Split arithmetic `king=floor(80%)`; `strategic=floor(12%)`; `reserve=P-king-strategic`" | **SUPERSEDED** by the §3.A formula block (dust posture preserved) |
| FREEZE §3 #9 "Monetary-routing posture: Static `80/8/12`. No macro/market-price/NAV/Strategy-return/ROOT-GIGA/calendar/oracle dynamic router" | **REFINED** — external/discretionary/oracle prohibition retained verbatim; settlement-local monetary closure on `(P, Qraw, B_pre, S_pre)` is the sole sanctioned adaptivity |
| SPEC §2 (static gross split; "Strategic Treasury receives 12% of every takeover"), §4.1 "static `80/8/12` settlement", §5 rows (Rig/Treasury legs), §12 (formulas + "This routing is static…"), §13 "through the static split", §15 step 6, §20.3, §24.3 #18–#19, §28 handoff "Every ordinary payment routes `80/8/12`" | **SUPERSEDED/REFINED** to match — Strategic "receives the residual up to 12%"; §12's prohibited-input list survives as the narrowed prohibition |
| SPEC §24.3 #20 "No other primary recipient exists" | **CONFIRMED** |
| Provenance delta §3 "static `80/8/12` settlement … `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED`" | **CONFIRMED, carried over** — the adaptive routing implementation remains VUX-original clean source under the same rule |

### 5.2 VEM and bootstrap

| current authority statement | disposition |
|---|---|
| FREEZE #14–#18 (Hard-only `D_R`, VEM rule, issuance invariant, no-carry, UPS≤VEM); SPEC §13 | **CONFIRMED** — measured-delta issuance unchanged; `D_actual ≡ D_R` |
| FREEZE §6 / SPEC §13 wording "`D_R` … is not an assumed 8% / not the nominal 8%" | **REFINED** (wording only) — becomes "not the routed target"; measured-delta principle unchanged |
| FREEZE #25–#28; SPEC §14 (bootstrap ~88%+/12%/0-mint, targets, cushion) | **CONFIRMED** — adaptive rule degenerates to the identical split at `Qraw = 0` |

### 5.3 Strategic revenue (decision B)

| current authority statement | disposition |
|---|---|
| FREEZE §4 "General realized-revenue waterfall — Operators/cofounders set and evolve exact percentages…"; "Operations budget and compensation — exact shares, caps, reserves … adapt" | **SUPERSEDED IN PART** — percentages are now founder-accepted `50/25/20/5/0`; budget approval/reforecast/draw execution remains operator-executed policy inside the accepted doctrine |
| FREEZE §5 guidance rows: `50/10/25/10/5` baseline; `25%` operator share; `2.5%` NAV ceiling | **SUPERSEDED as guidance** — replaced by the accepted four-leg waterfall and Operator Reserve; the 2.5%-NAV ceiling is demoted to an optional monitoring ratio |
| SPEC §2 "no exact general percentage is founder-frozen"; §18 "`50/10/25/10/5`, a 25% operator share, and a 2.5% NAV ceiling are research guidance"; §24.4 #31; §26 "guidance only" list (waterfall part); §28 "General revenue percentages are not frozen" | **SUPERSEDED IN PART** — for the general waterfall and operator leg only; ROOT/GIGA caps, dry-powder deployment rules, and bribe hurdles remain guidance/operator-reserved |
| FREEZE #41–#46 (qualifying-revenue boundaries; burn posture; runway concept #45) | **CONFIRMED** as the floor; #45's disclosed-runway concept **EXTENDED** by the Operator Reserve semantics; high-water/realized-loss restoration **ADDED** to the qualifying-revenue definition |
| FREEZE #39–#40 (POL VYRF; LP principal) | **CONFIRMED** unchanged |
| FREEZE #52 (bribe experiments) | **UNTOUCHED** — not addressed by this acceptance; reconciliation must harmonize the permitted-use list (#42 "market infrastructure") with the four-leg waterfall (no dedicated market-infrastructure leg; funding via Strategic capital deployment policy, never a new leg) |

### 5.4 LSG (decisions C–G)

| current authority statement | disposition |
|---|---|
| FREEZE #47–#51 (core mature surface; bounded authority; operator activation; pre-LSG flow) | **CONFIRMED**; doctrine **ADDED** on top (eligibility custody classes, one-status rule, 7/14/24h timing, global pool, attribution rejections, Dry Powder, Allocator Record) |
| SPEC §19 (role/authority boundary; "Exact days, supply, holders … thresholds are not frozen"); §24.4 #32–#34 | **CONFIRMED** — activation gates stay evidence-based and unfrozen |
| SPEC §4.2 "Its activation date and mechanism are not launch-frozen" | **REFINED** — activation date remains unfrozen; the mechanism's **economic design doctrine** is now founder-accepted (§3.C–D); implementation detail and activation remain reserved |
| FREEZE §5 LSG-gate row ("60 days, 5M distributed VUX, 50 holders … $250K" illustrative values) | **REPLACED as guidance** by the research §16 gate set (guidance → guidance; nothing frozen) |
| SPEC §26 (reserved: exact LSG voting/allocation/delegation/anti-capture mechanisms) | **REFINED** — still reserved, now bounded by the accepted doctrine |

### 5.5 Lending (decisions H–I)

| current authority statement | disposition |
|---|---|
| SPEC §4.3 "V1 does not authorize … Cooler-style lending …" | **CONFIRMED** — v1 still authorizes no lending |
| (no other lending/LLTV/collateral statement exists in current authority) | **ADDED** — decision H is net-new future reserved doctrine; decision I is a net-new binding pre-Sprint-3 non-requirement |

### 5.6 Standing operator posture

| statement | disposition |
|---|---|
| NOTES.md standing line (2026-08-10): "research-only values (waterfall splits, LSG gates, ROOT/GIGA caps, dry-powder, bribe hurdles) remain guidance only" | **SUPERSEDED IN PART** — waterfall splits and LSG timing are now founder-accepted doctrine; LSG activation gates remain evidence-based guidance; ROOT/GIGA caps, dry-powder deployment rules, and bribe hurdles remain guidance |

## 6. Consolidated reconciliation node — required updates

The reconciliation node (authorized next; not invoked here) must, before `/implement sprint-3`:

1. **Authority:** produce the successor Founder Freeze and successor Canonical Specification (or narrowly scoped supersession deltas per house precedent) rendering §5's dispositions, preserving predecessors as immutable history, and update `vux-v1-authority-supersession-map-2026-08.md`. SPEC §28 handoff bullets (routing, "percentages are not frozen") need matching edits.
2. **PRD** (`grimoires/loa/prd.md`): G-1 ("static `80/8/12`"); FR-4 in full (formulas, F-8/F-9 static posture → adaptive law + narrowed prohibition); FR-5.4 "the nominal 8%" wording; FR-6 confirm-only (bootstrap unchanged); FR-8.1 "exactly the floor-rounded 12% gross leg" → residual ≤12%; UC-1/UC-2 flows and ACs; INV-18/INV-19 rewrite (INV-20/INV-22 confirm); §14 Rig row ("deviate from static `80/8/12`"); §17 quarantine rows (old waterfall baseline, 25% share, 2.5% NAV, LSG-gates row) re-expressed against the accepted doctrine; R-9/R-10 restated (percentages founder-accepted; reserve policy operator-executed); §21 rows 2–3; Glossary "Split dust"; Appendix A "Ordinary routing" row (frozen-verbatim carry obligation).
3. **SDD** (`grimoires/loa/sdd.md`): §1.3 diagram legs; L122 routing-constant note and §5.2.2 ABI constants; 13-step step 6; `Settled` event leg semantics (variable Hard/Strategic legs; settlement observability for `D_need`/`hardTarget`); `Lens.wethNeededForFullQraw` parity with the adaptive rule; SQL leg-column comments; §7.1 fuzz/invariant gates; §7.3 quarantine-grep value list; §1.10 note that accepted waterfall percentages remain call-time policy application (no stored ratio constants — design preserved); **§1.11 P1 LSG sketch** (standing preference vectors, operator-paced cadence, streaming rewards, folded bribe engine) must be aligned with the accepted epochal 7/14 doctrine before any P1 build — the Sprint-4 P0 boundary (activation slot, `ILSGModule`, POL non-voting, INV-32…34) is unaffected; Appendix A carry. Use the SDD's established in-place supersession-note convention (Appendix E + dated "SUPERSEDED, see note" rows).
4. **Sprint Plan** (`grimoires/loa/sprint.md`): Sprint 3 goal ("static `80/8/12` legs") and AC (randomized-`P` floor-formula test) → adaptive formulas + regime tests; bootstrap AC confirm-only; Tasks 3.2/3.4/3.5; Sprint 4 "12% leg" attribution wording (`totalStrategicContributed` under a variable leg); Sprint 8 Task 8.E2E G-1 (frozen-parameter-table assert) and Appendix C/D rows.
5. **Mechanical coherence:** sprint.md pins the PRD/SDD by SHA-256 and the SDD cites `prd.md:L…` line numbers — re-pin hashes and re-verify line citations after edits; update the NOTES.md standing-status line per §5.6.
6. **Sequencing:** reconciliation is one of **two** independent binding pre-Sprint-3 conditions — the provenance-tooling hardening node (M-1/L-3/L-4, operator acceptance 2026-08-12) remains outstanding and is untouched by this record.

## 7. What must NOT be implemented in Sprint 3

- **No lending machinery of any kind:** no lending hook, approved-market registry, wrapper/receipt interface, oracle surface or price-oracle dependency, collateral-status storage in VUX, transfer restriction, special redemption path, or lender approval from Hard.
- **No LSG mechanism work:** Sprint 3 contains no LSG scope; the Sprint-4 P0 activation boundary ships as already planned (inactive, `address(0)` module); no `LSGSignals` P1 implementation, no staking/epoch/reward machinery, no snapshot infrastructure.
- **No waterfall constants in code:** the accepted 50/25/20/5/0 is policy doctrine; the SDD's call-time-argument `allocateRevenue` design stands; no stored ratio constants; no Operator Reserve contract or automation.
- **No Dry Powder token or contract.**
- **No leaderboard/scoring implementation:** the Allocator Record reservation is satisfied by the already-planned event/indexer surfaces; no new data machinery.
- **No stablecoin or WETH/USD oracle architecture reservation.**
- **No 40% LLTV artifact anywhere** — it exists only as a research-reopening ceiling in research records.
- The adaptive routing (decision A) is the **only** code-facing change accepted here, and it reaches Sprint 3 only through the reconciled PRD/SDD/Sprint Plan — never directly from this record.

## 8. Contradiction review

**No contradiction prevents acceptance.** Divergences examined and resolved:

1. **Stake age 14d vs 7d:** the base LSG research recommends 14 days throughout; the founder delta (7 days) is explicitly validated as preserving every load-bearing defense (`vux-lsg-founder-delta-validation` §2: "Accept 7-day age / 14-day epoch"). Delta-validation controls.
2. **Operator leg mechanics:** the base research's per-period cap `min(25% revenue, 2.5% NAV, approved budget)` with immediate compounding of unused amounts is amended by the validated Operator Reserve semantics (accrual to an 18-month runway, excess-only sweep); the 2.5%-NAV term is demoted to a monitoring ratio. Delta-validation controls.
3. **LLTV ladder:** the base holder-liquidity research presents 25% → 40% (evidence-gated); the founder posture (≤25% pilot, ≤1/3 mature candidate, 40% demoted to reopening ceiling) is a strict tightening inside the research's never-exceed envelope, explicitly validated. Delta-validation controls.
4. **Waterfall shape:** the accepted four-leg `50/25/20/5/0` replaces the older five-way `50/10/25/10/5` guidance baseline (guidance, never frozen). No frozen value is contradicted; §5.3 flags the market-infrastructure harmonization for reconciliation.
5. **"Static routing" prohibition:** the routing research confirms the accepted rule consumes no prohibited external input and itself states that current authority forbids dynamic primary routing "until explicit founder acceptance and supersession" — which this record is. The prohibition is narrowed deliberately (§5.1), not violated silently.
6. **Symbols:** `D_actual` ≡ current `D_R`; `D_need`/`hardTarget` are new. No arithmetic divergence exists between the accepted formulas and the routing research's exact integer arithmetic (verified formula-for-formula, including floor/ceil placement and `B_pre`/`S_pre` order).

## 9. Preserved history and boundaries

- Sprint 1 (landed `23263e18`) and Sprint 2 (landed `89a92055`, recorded `f997c077`) histories, reviews, audits, and operator acceptances are preserved unchanged, including the Sprint-2 carried conditions (M-1/L-3/L-4).
- All FREEZE parameters not named in §5 are preserved: genesis allocation and supply (#1–#6), epoch/multiplier/UPS/halvings/tail (#9–#23 of the predecessor lineage as carried), bootstrap price targets, redemption at 0%, POL rules, provenance/licence/pin authority (OZ/v3 refreeze, Foundry v1.5 toolchain refreeze), and the supersession map's §7 preserved load-bearing rules — except the ordinary-routing rows superseded in §5.1.
- Predecessor authority files remain immutable history; nothing is revived from any superseded artifact.

## 10. Handoff

This record is complete and self-contained. The authorized next node is the **consolidated reconciliation node** (§6), which alone may mutate the PRD, SDD, Sprint Plan, and authority successors. `/implement sprint-3` remains blocked until (a) reconciliation lands and (b) the provenance-tooling hardening condition (M-1/L-3/L-4) is closed.

**STOP. The consolidated reconciliation node is authorized next but has not been invoked.**
