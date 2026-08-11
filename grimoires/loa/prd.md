# Product Requirements Document: VUX v1

**Version:** 2.0.0 (fresh derivation — planning cycle-002 "VUX v1 Strategic Treasury")
**Date:** 2026-08-09
**Author:** PRD Architect Agent (Loa `/plan-and-analyze`, unattended operator-dispatched node)
**Status:** `PRD_ACCEPTED` — requirements baseline for `/architect`
**Operator acceptance:** 2026-08-10 — `OPERATOR_ACCEPTANCE`

---

## 1. Document Control, Authority Basis & Cycle Identity

> **Sources**: vux-v1-authority-supersession-map-2026-08.md §§1–2, §9; vux-founder-parameter-freeze-strategic-treasury-supersession-2026-08.md §1; vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md §1, §28; grimoires/loa/ledger.json (cycle-002)

### 1.1 Planning-cycle identity

| field | value |
|---|---|
| Loa cycle | `cycle-002` — "VUX v1 Strategic Treasury" (fresh cycle; **not** a continuation of cycle-001) |
| Git baseline | `master @ 9920b034042af733baca91a5325c465247373080` (authority documents present as working-tree files) |
| Predecessor PRD | cycle-001 PRD dispositioned `SUPERSEDED_BEFORE_OPERATOR_ACCEPTANCE`; preserved byte-for-byte (SHA-256 `bea5c8ab04ff2efbce8a5cd75f6f208d15dc5b35481b05f625124e8480c03945`) at `grimoires/loa/archive/2026-08-09-vux-v1-superseded-before-acceptance/prd.md`; it is historical generation evidence only and contributed **zero** requirements to this document |

### 1.2 Accepted authority consumed (precedence order)

| # | authority (all `CURRENT_ACCEPTED`, operator acceptance 2026-08-09) | SHA-256 | cited as |
|---:|---|---|---|
| 1 | `docs/authority/vux-founder-parameter-freeze-strategic-treasury-supersession-2026-08.md` | `b9b6a81db8c318e91601b3349283cab1654964c05d1d8e360b4971b7b1828723` | FREEZE (frozen rows: F-1…F-57) |
| 2 | `docs/authority/vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md` | `d2b2d1a344b75b2e45790af60039ea4ad420626281e0c80191638cd88d8a950a` | SPEC (invariants: INV-1…INV-37) |
| 3 | `docs/authority/vux-v1-strategic-treasury-provenance-boundary-delta-2026-08.md` | `5e1790276e290a08c58c1fe0accd40fc5d94b5a2ddc94dbb2c91aa90fce12ec3` | DELTA |
| 4 | `docs/authority/vux-v1-source-registry-strategic-treasury-delta-2026-08.json` | `79e2df97606027e020c2ec3100647dc60f4e7b53fcb3ab1f00128ba91df4b97f` | REG-DELTA |
| 5 | `docs/authority/vux-v1-licence-provenance-source-pin-freeze-2026-08.md` (preserved base) | `50c3584a1483b40ffb6391260a2bf42df32220c64724fdcc672ca62c01ace3a2` | LIC |
| 5 | `docs/authority/vux-v1-source-registry-2026-08.json` (preserved base) | `6fc9fa81d80eda1f1017c6cb79f297b9a608150538e76ad97d8de1c8b5d2fe04` | REG |
| 6 | `docs/authority/vux-v1-authority-supersession-map-2026-08.md` | `a6554f795dedd27d6551b4a19e195c4134e8b2de0b9db427837fa61fd442dbbe` | MAP |

Newer and more specific accepted authority governs overlap. The predecessor FREEZE/SPEC (`vux-founder-parameter-freeze-2026-08.md`, `vux-v1-canonical-specification-2026-08.md`) are superseded **in full** and were not merged into this PRD (MAP §1). No superseded parameter (notably `80/20/0` routing) is restored here.

### 1.3 What this document is

This PRD defines **WHAT** VUX v1 must do and the product, economic, and security outcomes it must guarantee, in testable form, so that `/architect` can later design the system without reopening founder/product decisions. It deliberately does **not** decide contract decomposition, storage, custody primitives, AMM/pool implementation, LSG algorithms, keeper design, access-control implementation, event schemas, dependencies, deployment topology, or gas strategy (§19).

---

## 2. Executive Summary

> **Sources**: SPEC §2, §3; FREEZE §1, F-33; MAP §8

VUX v1 is a Robinhood-Chain (RH) protocol combining six co-designed surfaces: (1) a permissionless WETH-paid King-of-the-Hill (KOTH) mining game that **is** the public TGE and the only post-genesis issuance path; (2) an enforceable, ownerless, immutable raw-WETH **Hard Reserve** giving every VUX unit a fee-free pro-rata exit right; (3) a separately custodied, productive **Strategic Treasury** capitalized by a static 12% leg of every takeover payment; (4) bounded holder-directed Strategic allocation through **LSG** — a core *mature* capability, inactive until operators affirmatively activate it; (5) protocol-owned VUX/WETH market infrastructure (**POL**) with a frozen special fee policy (**VYRF**: VUX fees burn; WETH fees strengthen the Hard Reserve); and (6) realized economic activity that may compound Strategic capital, accrete Hard backing, fund legitimate operations, and reward useful allocation — never from Hard Reserve principal.

The corrected product identity is:

> The throne gets people in.
> The Strategic Treasury gives them a reason to stay.
> The Hard Reserve gives them a right to leave.

Mature shorthand: **ROOT for the people.** VUX is *not* merely a WETH-backed token, and the Hard Reserve and Strategic Treasury are never collapsed into one NAV concept: the Hard Reserve is the enforceable exit right; the Strategic Treasury is separately risked productive capital. Issuance is bounded by **VEM** so that only exact, realized, current-settlement Hard Reserve WETH ever supports minting; Strategic value never does. Genesis mints exactly 150,000 VUX to canonical protocol-owned POL plus 1 raw VUX unit to seed the Hard Reserve — and zero to any person.

This PRD freezes those outcomes as requirements, preserves every operator-reserved decision as reserved (§16), quarantines research guidance from canonical status (§17), and provides the acceptance criteria and reviewability map (§§20–21) an operator needs to verify faithfulness before `/architect` is invoked.

---

## 3. Problem Statement & Product Vision

> **Sources**: SPEC §2, §3, §21; FREEZE §1, F-1, F-54; MAP §3, §8

### 3.1 The problem

Token launches routinely fail their holders in four repeating ways:

1. **Unfair genesis** — insiders, funds, and teams receive allocations users cannot get; "fair launch" claims hide discretionary mints.
2. **Unbacked or dishonestly backed supply** — emission schedules promise supply regardless of capital actually received; "backing" claims blend hard assets with marks, IOUs, and treasury risk.
3. **No enforceable exit** — treasuries are discretionary; holders have price, not a right.
4. **Dead-end utility** — after the launch game cools, nothing gives holding a continuing reason; or, in the opposite failure, governance hands token voters the keys to security-critical machinery.

### 3.2 The VUX answer

VUX makes the launch game itself the distribution mechanism (one throne, one price ladder, one clock), makes the exit right physical and ownerless (raw canonical RH WETH, pro-rata, fee-free, immutable), caps every mint by the exact WETH the settlement physically added to the Hard Reserve (VEM), and gives holders a durable reason to stay: a first-class, separately risked Strategic Treasury that receives 12% of every takeover, may compound productively under bounded operator/risk authority, and — at maturity — accepts bounded holder allocation signal (LSG) without ever touching the Reserve, minting, or security controls.

### 3.3 Desired state (verifiable)

- Every user-owned VUX was mined under public rules or bought on the open market — provably, from genesis facts (SPEC §22).
- Hard `B/S` (WETH backing per VUX) never decreases through authorized issuance (INV-13).
- Strategic losses — including total loss — are economically incapable of reaching the Hard Reserve (F-34; INV-24, INV-35).
- Mining UX never presents raw clock opportunity as earned VUX (F-55; SPEC §21).
- After TGE graduation, holding VUX still means: a hard exit right + exposure to productive protocol-owned capital + bounded allocation influence (SPEC §21).

### 3.4 Why now, why this shape

The founder reconciliation (accepted 2026-08-09) rejected the prior "WETH-backed token with an economically secondary treasury" identity and established the dual-treasury product above (MAP §3). This PRD is the first planning artifact derived from that corrected identity.

---

## 4. Product Doctrine & Holder Promise

> **Sources**: SPEC §3 (§3.1–§3.5), §21; FREEZE §1, F-54, F-55

### 4.1 Four co-equal pillars

| pillar | operational meaning (requirement, not slogan) |
|---|---|
| **FAIR** | Permissionless mining is the TGE; genesis allocates only protocol POL inventory + 1-raw-unit Reserve seed; zero founder/operator/apDAO/partner/investor/user/airdrop/sale/discretionary genesis; no primary-flow share for founders/operators/developers/signalers; users may mine or buy openly. Fair **access** does not promise equal outcomes, broad distribution, or anti-whale machinery (F-54). |
| **SIMPLE** | The launch loop stays: *take the throne → hold → mine while King → when displaced, receive recycled WETH + safely settled VUX*. Strategic accounting and LSG sit behind this loop and must not turn an ordinary takeover into portfolio management (SPEC §3.2). |
| **ELEGANT** | One successor payment simultaneously compensates the outgoing King, strengthens the immutable Hard Reserve, capitalizes the productive Strategic Treasury, and settles the outgoing epoch's VUX within VEM (SPEC §3.3). |
| **SECURE** | Hard Reserve integrity outranks mining continuity, Strategic performance, POL, revenue routing, governance, LSG, and recovery convenience. Failures outside the Reserve create no claim on its principal (SPEC §3.4). |

### 4.2 Exact holder promise

VUX holders receive exactly:

1. a fee-free pro-rata raw-WETH redemption right against the ownerless Hard Reserve, with non-decreasing Hard `B/S` through authorized issuance; and
2. fungible exposure to protocol-owned Strategic capital plus bounded holder-directed marginal allocation under disclosed policy — **without** any redemption guarantee against Strategic NAV.

VUX must never promise that ROOT, GIGA, POL, stable assets, expected yield, or Strategic marks are Hard backing (SPEC §3.5). Public/legal characterization of Strategic and governance rights requires later jurisdiction-specific review and cannot weaken the accounting truth above.

---

## 5. Goals & Success Metrics

> **Sources**: SPEC §§3–4, §15, §22, §24; FREEZE §§2–3; MAP §8. Metrics are verification-shaped because the authority freezes outcomes, not market targets; no market-performance KPI exists in authority and none is invented here.

### 5.1 Primary goals

| ID | Goal | Measurement | Validation method |
|----|------|-------------|-------------------|
| G-1 | Faithful monetary core: genesis, KOTH, static `80/8/12` routing, VEM, redemption behave exactly as frozen | INV-1…INV-22 hold under test; frozen parameter table (§24 / Appendix A) matches implementation constants verbatim | Acceptance tests per FR-1…FR-7; `/review-sprint` + `/audit-sprint` traceability to this PRD |
| G-2 | Dual-treasury separation: Strategic capital physically and accountingly distinct; failure-independent | INV-23…INV-31, INV-35 hold; failure rows FB-5…FB-8, FB-13 demonstrably true | Scenario tests per §11; audit review |
| G-3 | Truthful UX: raw clock vs. live estimate vs. settled mint never conflated | FR-15 acceptance criteria pass on every user-facing surface | UX review against SPEC §21 canonical wording |
| G-4 | LSG-ready boundary: activation authority exists, inactive at launch, bounded role enforced | FR-13 acceptance criteria; INV-32…INV-34 | Design review + tests when built; boundary text review now |
| G-5 | Provenance discipline: default-deny source posture carried through planning and later phases | §15 requirements PROV-1…PROV-9 satisfied; zero unauthorized source in any later artifact | Provenance checks at SDD/implementation gates |
| G-6 | Operator reviewability: the 20 acceptance questions answerable directly from this PRD | §21 table complete with section pointers | Operator review of this PRD |

### 5.2 Constraints on goals

- No goal may be "achieved" by weakening a frozen boundary (FREEZE §2: silence never converts guidance into frozen values; reserved decisions never violate frozen boundaries).
- Distribution/price/participation outcomes are explicitly **not** goals: VEM protects monetary integrity, not competition (SPEC §22).

---

## 6. Users, Personas & Stakeholders

> **Sources**: SPEC §2, §5, §§9–11, §19, §21, §22; FREEZE F-5, F-43, F-47; LIC §6 (collaborator), SPEC §23 (external trust)

### 6.1 Personas

| persona | goals | key interactions | notable truths |
|---|---|---|---|
| **Contender (miner)** | Take the throne at an acceptable Dutch price; mine | Pays canonical RH WETH; becomes King; epoch starts | Pays the same public price ladder as everyone; no allowlist or identity gate |
| **Sitting King** | Hold as long as possible; get displaced profitably | Accrues raw clock opportunity (≤3,000 s eligible); on displacement receives 80% recycle + `Qmint` VUX | Clock is *opportunity*, not earnings; settlement is bounded by VEM |
| **Holder / redeemer** | Hold exposure; exit at will | May burn `q` VUX for `floor(B×q/S)` canonical WETH, fee-free, anytime the chain functions | Exit right is against Hard `B` only, never Strategic NAV |
| **Market participant** | Buy/sell existing VUX openly | AMM/POL and any venue | Buying confers the same fungible redemption claim (SPEC §9) |
| **Operator / cofounder / risk authority** | Steward Strategic capital within frozen boundaries | Receives nothing personally from primary flow; admits/removes Strategies; sets disclosed policies; decides LSG activation | Bounded: cannot raid Reserve, mint, reclassify principal, or create undisclosed founder economics (FREEZE §4 tail) |
| **Signaler (mature, post-LSG-activation)** | Express relative allocation preference among admitted Strategies | Votes/signals with eligible VUX; may earn disclosed rewards from permitted realized economics | Never controls Hard Reserve, minting, recipients, security parameters (F-48) |
| **Indexer / analyst / integrator** | Reconstruct accounting truth | Reads observable settlement, treasury, POL, burn, LSG facts | Must be able to distinguish every routed leg and every supply change cause (SPEC §15) |

### 6.2 Stakeholders (non-user)

| stakeholder | relationship | boundary |
|---|---|---|
| Founders / project / apDAO | Zero genesis VUX; zero primary flow; remaining project/apDAO capital is Strategic and undeployed at genesis unless separately authorized (F-32) | Compensation only via §14-permitted realized economics or disclosed external runway (F-43, F-45) |
| Heesho (Miner Manifold author) | Collaborator permission for the three allowlisted files (LIC §6) | Scope limited to grantor-controlled rights; no relicensing of third-party lineage |
| Robinhood Chain / canonical WETH authority | External trust dependency (YELLOW) | VUX cannot constrain it; disclosure mandatory (§13) |
| Future auditors / reviewers | Consume the invariant register and acceptance criteria | This PRD is their requirements baseline |

---

## 7. Lifecycle Phases & Capability Scope

> **Sources**: SPEC §4 (§4.1–§4.3), §11, §14; FREEZE F-22…F-27, F-50

### 7.1 Protocol lifecycle phases

| phase | trigger | monetary state | notes |
|---|---|---|---|
| **Genesis** | Deployment | `S0 = 150,000 × 10^18 + 1` raw units; POL seeded; Reserve seeded with 1 raw VUX + `B0` WETH | One-shot founder-approved USD→WETH conversions recorded (FR-1) |
| **Bootstrap** | Deployment → first public takeover | Ownerless Hard Reserve is sole genesis King; clock disabled; `Qraw = 0` | First takeover mints zero; ≈88%+ Hard / 12% Strategic (FR-6) |
| **Launch war** | First public takeover → day 30 | 4 VUX/s epoch-open UPS | Public clock begins at first public King's epoch |
| **Primary distribution / halvings** | Days 30–240 | Eight 30-day halvings (days 30,60,90,120,150,180,210,240) | Snapshotted UPS per epoch; open epochs unaffected by a halving |
| **Public TGE graduation** | ≈ day 180 | 0.125 VUX/s epoch band | Framing only; no state change is triggered by the date itself |
| **Wind-down** | Days 180–240 | 0.0625 → 0.03125 VUX/s | Cumulative pre-tail raw opportunity ≈ 20,655,000 VUX |
| **Tail (permanent)** | Day 240 onward | `4/256 = 0.015625` VUX/s pilot light; ≤ 492,750 raw VUX/year | Still clock- and VEM-limited |
| **Mature operations** | Continuous, operator-paced | Strategic deployment, POL growth, revenue policy, LSG activation | No calendar gate; operator judgment within frozen boundaries |

### 7.2 Minimum launch capability (P0)

Exact genesis supply and low-float VUX/WETH POL; one canonical RH WETH throne; static `80/8/12` settlement; ownerless Hard Reserve + fee-free redemption; Hard-only VEM; truthful mining UX; physically and accountingly separate Strategic receipt; bootstrap zero-mint; POL principal-vs-fee-yield classification and the POL-special VYRF outcome; product-level accounting sufficient to observe Hard, Strategic, settlement, fee, and burn facts; **inactive LSG with an explicit operator-controlled activation authority and the preserved non-voting-POL rule** (SPEC §4.1).

Launch does **not** require complex active Strategies, ROOT/GIGA exposure, or active token voting. Before LSG activation, operators may retain raw Strategic WETH or use a narrow authorized bootstrap policy (F-51).

### 7.3 Mature capability (P1 — core product, not optional)

Expanded POL when economically attractive; admitted productive Strategies and ecosystem assets; **active LSG allocation signaling when internally ready**; realized-revenue funding of compounding/backing/operations/signalers/market infrastructure under disclosed policy; verified ROOT/GIGA or other RH-native opportunities when admitted; adaptive portfolio construction and dry powder within frozen boundaries (SPEC §4.2). LSG is a core mature product surface — losing it, or demoting it to "optional compatibility," is a load-bearing failure.

### 7.4 Excluded or unresolved (non-goals, v1)

Crown Share, hVUX, Cooler-style lending, tournaments, multiple thrones, new emission seasons, an oracle-mediated monetary router, Reserve-backed Strategy rescue, privileged token allocation (SPEC §4.3). See §18 for the complete non-goal register.

---

## 8. User Flows & Use Cases

> **Sources**: SPEC §2, §§9–15, §17, §19, §21; FREEZE F-6, F-13, F-25…F-27, F-38, F-39, F-47…F-51

Flow steps are product-observable outcomes; internal ordering/decomposition is `/architect` territory (SPEC §15).

### UC-1: First public takeover (bootstrap exit)

**Actor:** Contender. **Preconditions:** Deployment complete; Hard Reserve is genesis King; clock disabled.
**Flow:**
1. Contender pays the bootstrap Dutch price (opening ≈$50 WETH-equivalent, decaying; floor ≈$1) in canonical RH WETH.
2. Canonical split applies: 80% outgoing-King leg + nominal 8% leg + all split dust → Hard Reserve (because the Reserve is outgoing King); 12% → Strategic custody.
3. Zero VUX mints (`Qraw = 0`).
4. Payer becomes first public King; the public epoch clock starts at the current schedule rate.

**Postconditions:** ≈88%+ of `P` in Hard; 12% in Strategic; supply unchanged.
**Acceptance criteria:**
- [ ] Settlement observably routes ≥88% of `P` to Hard and exactly `floor(P×1,200/10,000)` to Strategic.
- [ ] `Qmint = 0` and no address received bootstrap VUX, WETH, a free clock, or a free reign.
- [ ] The payer's epoch opens at the schedule's current UPS.

### UC-2: Ordinary takeover

**Actor:** Contender. **Preconditions:** A public King sits; current Dutch price `P` known.
**Flow:**
1. Contender pays `P` canonical WETH.
2. Split: `king = floor(P×8,000/10,000)` → outgoing King; `strategic = floor(P×1,200/10,000)` → Strategic; `reserve = P − king − strategic` → Hard.
3. Outgoing epoch settles: `Qraw = min(elapsed, 3,000 s) × epochUPS`; `Qsafe = floor(D_R × S_pre / B_pre)`; `Qmint = min(Qraw, Qsafe)` mints to the outgoing King.
4. Contender becomes King; successor epoch opens at `max(MINIMUM_OPENING, 2 × P)` and decays linearly over 3,000 s to the floor.

**Postconditions:** All three legs sum to `P`; Hard `B/S` non-decreasing; supply increased by exactly `Qmint`.
**Acceptance criteria:**
- [ ] The three routed amounts are exact per the frozen arithmetic and observably distinguishable.
- [ ] `D_R` is measured after the Hard contribution physically arrives; an inconsistent measurement rejects the settlement.
- [ ] Settlement is atomic: all authorized throne/payment/accounting/backing/issuance effects commit, or none.
- [ ] No branch of primary settlement reads time-phase, macro, NAV, ROOT/GIGA price, market price, oracle data, or operator preference.

### UC-3: Reign and displacement (King's lifecycle)

**Actor:** Sitting King. **Preconditions:** Epoch open with snapshotted UPS.
**Flow:** King holds; raw opportunity accrues at `epochUPS` up to 3,000 eligible seconds; on displacement, UC-2 settles the epoch.
**Postconditions:** King received exact recycle + `Qmint`; unused/unsupported opportunity expired.
**Acceptance criteria:**
- [ ] Raw accrual caps at exactly 3,000 s; later halvings do not alter the open epoch's snapshot.
- [ ] If `Qraw > Qsafe`, the difference never exists afterward: no carry, IOU, debt, makeup, entitlement, or high-water record.
- [ ] With no challenger, no VUX becomes owed (FB-2).

### UC-4: Redemption (exit right)

**Actor:** Holder. **Preconditions:** Holder owns `q` VUX; chain and backing asset functional.
**Flow:** Holder burns `q`; receives `payout = floor(B × q / S)` canonical WETH atomically, fee-free, using pre-redemption `B` and `S`.
**Postconditions:** `S` decreased by `q`; `B` decreased by `payout`; rounding favored the Reserve; `S ≥ S_MIN = 1` raw VUX.
**Acceptance criteria:**
- [ ] Zero fee; no approval gate, pause, allowlist, or discretionary block exists on the redemption path.
- [ ] Strategic values and market price are irrelevant to payout.
- [ ] Full redemption of all externally held VUX leaves the 1-raw-unit denominator and a positive WETH remainder.
- [ ] Protocol-owned POL VUX is never redeemed as treasury conduct; a market buyer of existing VUX retains the full fungible claim.

### UC-5: Open-market acquisition

**Actor:** Market participant. **Flow:** Buys existing VUX (POL or any venue); acquires identical fungible rights (redemption claim, future LSG eligibility per its rules).
**Acceptance criteria:**
- [ ] No transfer tax, wallet cap, identity gate, or anti-whale mechanism exists (F-54; SPEC §22).

### UC-6: Observe accounting truth

**Actor:** Indexer/analyst. **Flow:** Reads observable protocol facts.
**Acceptance criteria (product-level observability):**
- [ ] Per settlement: outgoing epoch/King, incoming King, exact `P`, all three routed amounts, `B_pre`, `S_pre`, exact `D_R`, `Qraw`, `Qsafe`, `Qmint`, bootstrap-vs-ordinary flag, Strategic principal received.
- [ ] Supply: every `S` change attributable to its cause (mint, redemption burn, VYRF burn, other authorized burn).
- [ ] Analytics can separately report: genesis POL inventory, current `S`, cumulative raw opportunity, completed mints, burns by cause, `B` and `B/S`, Strategic contributed principal, realized revenue, disclosed Strategic NAV — with NAV never labeled "backing" (SPEC §21).

### UC-7: Strategic receipt and adaptive deployment (operator)

**Actor:** Operator/risk authority. **Preconditions:** Strategic custody holds the accumulated 12% legs.
**Flow:** Operator stages deployment (or deliberately does not) among admitted Strategies/POL/dry powder; classification by source and substance is preserved at every step.
**Acceptance criteria:**
- [ ] Static receipt forces no deployment; capital may remain raw WETH indefinitely (F-107 analog: FREEZE §4 "Strategic deployment timing"; SPEC §20.3).
- [ ] No deployment, loss, or rebalancing changes `B`, redemption, VEM, or mint authority.
- [ ] Every inflow/return is classified as exactly one of: Hard accretion; Strategic contributed/returned principal; POL fee yield by denomination; other realized revenue by denomination; unrealized mark (SPEC §6) — and classification is never changed merely to fund a preferred recipient.

### UC-8: POL fee harvest (VYRF outcome)

**Actor:** Operator/automation (mechanism unspecified). **Preconditions:** Canonical POL position accrued incremental fee yield.
**Flow:** Fee yield is separated from principal and classified by denomination; VUX-denominated fee yield is burned; WETH-denominated fee yield enters the Hard Reserve one-way; returned LP principal (if any) returns to Strategic principal.
**Acceptance criteria:**
- [ ] VUX fee yield is never held, re-LP'd, redeemed, recycled into mining, or counted as Strategic NAV after collection — it burns.
- [ ] WETH fee yield increases `B` and never routes through the general waterfall.
- [ ] Principal withdrawal is never counted as fee yield or revenue.
- [ ] Accounting exposes each leg (burned VUX, WETH→Hard, returned principal) distinctly (SPEC §15).

### UC-9: LSG activation and signaling (mature)

**Actor:** Operator (activation); Signaler (use). **Preconditions:** Internal readiness thresholds met in operator judgment; affirmative operator activation.
**Flow:** Operator activates LSG; eligible holders express relative preferences for **marginal Strategic allocation among admitted opportunities**; bounded execution follows within admission caps; operators retain emergency remove/recall.
**Acceptance criteria:**
- [ ] Before activation, the 12% Strategic leg remains Strategic (never redirected to Hard) (F-51).
- [ ] Activation state, admitted Strategy identity, bounded allocation signal/result, and responsible authority are observable (SPEC §15).
- [ ] Protocol-owned POL VUX has zero LSG voting power at all times (F-38).
- [ ] No LSG pathway can touch the Hard Reserve, minting, arbitrary recipients, low-level security parameters, exploit response, or ordinary upgrades (F-48).
- [ ] No fixed calendar date or frozen numeric threshold auto-activates LSG (F-50).

### UC-10: Emergency Strategy removal (mature)

**Actor:** Operator/risk authority. **Flow:** Operator removes/recalls an admitted Strategy under bounded emergency policy; positions unwind per that policy.
**Acceptance criteria:**
- [ ] Removal authority exists independent of LSG votes and cannot be blocked by signalers.
- [ ] Losses realized in removal remain Strategic; no Hard claim arises (FB-5/FB-6).

---

## 9. Functional Requirements

> **Sources**: FREEZE §3 (F-1…F-57), §§6–9; SPEC §§6–21; DELTA §3; MAP §§3–5, §7. Each requirement cites its authority; priorities: P0 = launch-critical, P1 = mature-core (required product, activation operator-paced).

### FR-1: Genesis State & Supply (P0)

**Description:** The protocol must instantiate the exact frozen genesis.

Requirements:
1. Genesis VUX mint shall be exactly: 150,000 VUX (× 10^18 raw) to canonical protocol-owned VUX/WETH POL; 1 raw VUX unit to the ownerless Hard Reserve; 0 to every other address — founders, operators, developers, apDAO, partners, investors, users, airdrops/community, public sale, Strategic Treasury, and all discretionary recipients (F-2…F-5; SPEC §7.1).
2. `S0` shall equal exactly `150,000 × 10^18 + 1` raw units (F-4).
3. WETH genesis shall satisfy: POL WETH side ≈ $1,000 USD-equivalent; `B0 = P0 × S0 / 1.10` derived from actual initialized `P0` and `S0` (≈ $909.09 under the intended comparator); total external genesis deployment ≈ $1,909.09 USD-equivalent and nothing else (F-29…F-31; SPEC §7.2).
4. Immediately before deployment, the four USD-equivalent launch targets (POL WETH side, bootstrap opening, minimum opening, decay floor) shall be converted **once** using a founder-approved WETH/USD reference price, source, and timestamp; validation shall record rounding, token ordering, decimals, ticks, actual marginal price, `P0/N0 = 1.10`, and the bootstrap-cushion condition `BOOTSTRAP_OPENING ≤ P0×S0 − B0`. No runtime USD oracle or refresh mechanism shall exist (FREEZE §7; SPEC §7.2).
5. The 150,000 POL VUX shall be treated as protocol liquidity inventory — not a user or voting allocation (F-2; SPEC §7.1).

**Acceptance criteria:**
- [ ] Post-deployment state equals the genesis table exactly; any nonzero discretionary genesis balance is a critical failure.
- [ ] The recorded conversion evidence (price, source, timestamp, rounding) exists and matches deployed constants.
- [ ] `P0/N0 = 1.10` and the cushion inequality verifiably held at initialization.

### FR-2: KOTH Throne & Dutch Pricing (P0)

**Description:** One canonical throne, paid only in canonical RH WETH, priced by a frozen Dutch mechanism.

Requirements:
1. Exactly one throne shall exist; payment shall be exclusively canonical RH WETH (F-1; SPEC §10).
2. Frozen pricing parameters: `EPOCH_PERIOD = 3,000 s`; `PRICE_MULTIPLIER = 2×`; `BOOTSTRAP_OPENING ≈ $50`; `MINIMUM_OPENING ≈ $10`; `DECAY_FLOOR ≈ $1` (each USD target converted once pre-deployment) (F-20, F-21, F-28; SPEC §10).
3. An ordinary successor epoch shall open at `max(MINIMUM_OPENING, 2 × paid takeover price)`; the reference price shall decay linearly over 3,000 s: `price(t) = max(DECAY_FLOOR, opening × (1 − min(t, 3,000)/3,000))`, then remain at the floor until displacement (SPEC §10).
4. The `2×` multiplier is a price-ladder multiplier only — it shall have no mining/issuance effect (F-21).
5. The decay floor is a paid-handoff/dust-restart rule — never an issuance, oracle, backing, or quote guarantee (SPEC §10).
6. Anyone may pay; no allowlist, identity gate, or privileged path shall exist (F-1; SPEC §3.1).

**Acceptance criteria:**
- [ ] Price function matches the formula exactly at boundary points (t = 0, 3,000, beyond; floor clip).
- [ ] Successor opening applies `max(MINIMUM_OPENING, 2 × P)` including the minimum-opening branch.
- [ ] Non-canonical payment assets are impossible.

### FR-3: Mining Clock, UPS Schedule & Tail (P0)

**Description:** Time defines raw opportunity under an immutable halving schedule; nothing more.

Requirements:
1. `INITIAL_UPS = 4 VUX/second`, snapshotted at epoch opening, always VEM-limited (F-18).
2. Eligible raw accrual per reign: `elapsedEligible = min(elapsed, 3,000 s)`; `Qraw = elapsedEligible × epochUPS` (F-20; SPEC §11).
3. Eight immutable 30-day halvings at days 30, 60, 90, 120, 150, 180, 210, 240 from schedule start; permanent tail `INITIAL_UPS/256 = 0.015625 VUX/s` thereafter (≤ 492,750 raw VUX/year) (F-22, F-23; SPEC §11).
4. A halving shall not alter an already-open epoch's snapshot (SPEC §11).
5. The cumulative ≈ 20,655,000 pre-tail VUX is raw opportunity — never target supply, promise, entitlement, or debt; unsettled time and unsupported opportunity expire (F-19, F-24; SPEC §8, §11).
6. TGE framing: ≈ day 180 public graduation; days 180–240 wind-down; day 240 formal tail — framing only, no schedule-driven state change beyond the UPS halvings themselves (F-24).

**Acceptance criteria:**
- [ ] UPS at every schedule boundary matches SPEC §11's table (4 / 2 / 1 / 0.5 / 0.25 / 0.125 / 0.0625 / 0.03125 / 0.015625).
- [ ] An epoch straddling a halving settles at its opening snapshot.
- [ ] `Qraw` caps at exactly `3,000 × epochUPS`.

### FR-4: Ordinary Settlement & Static Routing (P0)

**Description:** Every ordinary takeover payment is exhausted by the frozen three-leg split.

Requirements:
1. For exact payment `P` (basis-point denominator 10,000): `king = floor(P × 8,000 / 10,000)`; `strategic = floor(P × 1,200 / 10,000)`; `reserve = P − king − strategic` (F-8; FREEZE §6; SPEC §12).
2. Therefore: outgoing King receives at most exactly 80%; Strategic receives at most exactly 12% under floor rounding; Hard receives nominally at least 8% **plus all split dust**; the three legs sum to `P`; every other primary recipient receives exactly 0 (F-7; SPEC §12).
3. Routing shall be static: no macro, market-price, NAV, Strategy-return, ROOT/GIGA-price, calendar-phase, oracle-mediated, or operator-discretion branch shall exist anywhere in primary settlement (F-9; SPEC §12).
4. Adaptive decisions begin only **after** the Strategic leg is received and classified as Strategic principal (SPEC §12).
5. Settlement shall be atomic and use full-precision arithmetic; the Strategic transfer receives zero issuance credit (FREEZE §6; SPEC §15).
6. The complete economic settlement result shall follow SPEC §15's 13-step outcome (identify epoch/King; fix `P`; establish `B_pre`/`S_pre`; compute `Qraw`; collect payment; compute legs; deliver/classify Strategic and realize Hard contribution; measure exact `D_R` and reject inconsistency; compute `Qsafe`/`Qmint`; mint to outgoing King; deliver recycle; establish successor epoch/price; commit all or nothing) — exact call graph reserved to `/architect`.

**Acceptance criteria:**
- [ ] Randomized `P` values: legs match the floor formulas exactly and sum to `P`; dust lands in Hard.
- [ ] Code inspection: no conditional on any prohibited signal in the primary path.
- [ ] Partial-failure injection: no state where some legs routed and others did not.

### FR-5: VEM Issuance Cap (P0)

**Description:** Only the exact, measured, current-settlement Hard Reserve WETH delta supports issuance.

Requirements:
1. `B_pre` = Hard Reserve WETH before this settlement's contribution; `S_pre` = `VUX.totalSupply()` before this settlement's issuance; `D_R` = exact realized WETH increase in the Hard Reserve caused by this settlement, measured only after the Hard leg physically arrives (F-14; SPEC §13).
2. `Qsafe = floor(D_R × S_pre / B_pre)`; `Qmint = min(Qraw, Qsafe)`; mathematically equivalent full-precision, overflow-safe arithmetic required (F-15; SPEC §13).
3. Issuance invariant: `(B_pre + D_R)/(S_pre + Qmint) ≥ B_pre/S_pre` — equivalently `B_pre × Qmint ≤ D_R × S_pre`. Equality permits full `Qraw`. Issuance rounds down; any required-contribution calculation rounds up (F-16; SPEC §13).
4. Zero issuance credit for: Strategic WETH/NAV, POL, ROOT, GIGA, stable assets, market prices, expected yield, oracle marks, quotes, later deposits, or the nominal 8% (F-14; SPEC §13).
5. If `Qraw > Qsafe`: mint only `Qsafe`; the remainder never exists — no carry, IOU, debt, makeup emission, entitlement, high-water emission, Strategic-NAV mint, oracle-backed mint, or recapitalization mint, ever (F-17; SPEC §13).
6. If `Qsafe > Qraw`: mint only `Qraw`; excess Hard contribution raises `B/S` (SPEC §13).

**Acceptance criteria:**
- [ ] Property test: for all tested `(B_pre, S_pre, D_R, Qraw)`, minted amount preserves the invariant and equals `min(Qraw, floor(D_R × S_pre / B_pre))`.
- [ ] A settlement whose measured `D_R` is inconsistent with the routed Hard leg rejects atomically.
- [ ] No storage or accounting cell anywhere records unmet `Qraw − Qsafe` for later use.

### FR-6: Bootstrap Settlement (P0)

**Description:** A distinct one-time state with the ownerless Hard Reserve as genesis King.

Requirements:
1. At deployment: outgoing King = ownerless Hard Reserve; bootstrap clock disabled; bootstrap `Qraw = 0` (F-25, F-26; SPEC §14).
2. The first public paid takeover shall: be permissionless at the bootstrap Dutch price; apply the canonical split arithmetic; route the 80% outgoing-King leg + nominal Hard leg + all dust to the Hard Reserve (Reserve is outgoing King); route the 12% leg to Strategic custody; mint zero VUX; make the payer the first public King and start that epoch at the current schedule rate (F-27; SPEC §14).
3. Economic result: approximately 88% or greater Hard / 12% Strategic / zero minted VUX. No deployer, founder, operator, partner, or any person receives bootstrap WETH, VUX, a free clock, or a free reign (F-27; SPEC §14).

**Acceptance criteria:**
- [ ] Bootstrap settlement test shows the exact leg routing and `Qmint = 0`.
- [ ] No second bootstrap state is reachable.

### FR-7: Hard Reserve & Redemption (P0)

**Description:** The enforceable exit right — raw canonical RH WETH only, ownerless, immutable.

Requirements:
1. `S = VUX.totalSupply()` (complete — POL-held, Strategic-held, Reserve seed, mined, user-held, protocol-held; "circulating supply" is analytics only); `B` = raw canonical RH WETH physically held by the Hard Reserve — excluding Strategic WETH, POL WETH, LP value, stable assets, ROOT, GIGA, receivables, unreceived fees, unrealized marks, oracles, expected yield; `N = B/S` conceptual only (F-11; SPEC §6).
2. The VUX-controlled Reserve surface shall be: ownerless; immutable/non-upgradeable; non-pausable; with no arbitrary call, token approval, sweep, successor, migration, or discretionary principal-movement authority (F-12; SPEC §9).
3. The Reserve is not a treasury, Strategy, POL manager, operational wallet, governance executor, migration staging area, or emergency fund (SPEC §9).
4. Redemption: for `q` VUX, using state immediately before redemption, `payout = floor(B × q / S)`, `fee = 0`; exact `q` burns and payout pays atomically; rounding favors the Reserve (F-13; SPEC §9).
5. `S_MIN = 1` raw VUX permanently held by the Reserve; redemption may not reduce supply below it; full external redemption leaves a live denominator and positive WETH remainder (F-13; SPEC §9).
6. Reserve principal shall never fund payroll, bribes, Strategies, POL, operating costs, or Strategic-loss rescue — and never becomes Strategic principal or revenue working capital (F-44; INV-17).
7. Strategic NAV shall never enter `B` (F-10; INV-11).

**Acceptance criteria:**
- [ ] No authority — operator, governance, LSG, or emergency — can pause, upgrade, sweep, approve, or discretionarily move Reserve principal (test + review).
- [ ] Redemption pays exactly `floor(B×q/S)` for property-tested `(B, S, q)`; zero fee; Reserve-favoring rounding.
- [ ] `S_MIN` preserved under exhaustive-redemption test.

### FR-8: Strategic Treasury Receipt & Custody Separation (P0)

**Description:** First-class protocol-owned risk capital, physically and accountingly distinct from the Hard Reserve.

Requirements:
1. The Strategic Treasury shall receive exactly the floor-rounded 12% gross leg of every takeover from the first activation onward (F-7, F-33; MAP §3).
2. Hard and Strategic principal shall be physically and accountingly distinct; Strategic assets never enter `B` (F-10).
3. Permitted Strategic composition (economic purposes, not an implementation list): raw Strategic WETH/dry powder; WETH/stable productive Strategies; protocol-owned VUX/WETH liquidity; verified/admitted ROOT, GIGA, Stock Token, or other RH-native opportunities; other admitted productive assets or market infrastructure (SPEC §16).
4. Strategic principal includes: primary 12% contributions, externally authorized project capital, returned deployed principal, and returned LP principal. It is never Hard backing and never revenue merely because custody changes or a position exits (SPEC §16).
5. Strategic failure independence: Strategic loss — including total loss — shall be incapable of reducing/withdrawing `B`, altering redemption, supporting VEM/minting, authorizing recapitalization emission, creating a Hard Reserve rescue entitlement, or permitting principal to be relabeled as revenue (F-34; SPEC §16).
6. Strategic-zero survival: if Strategic NAV reaches zero, supply accounting, Hard redemption, KOTH, VEM, and FAIR issuance constraints remain functional subject to their own dependencies (F-35; SPEC §16).
7. Static receipt forces no deployment; operators may stage, pause, or resume within risk boundaries; no fixed dry powder or cadence is canonical (SPEC §16, §20.3).
8. `T_nav` (disclosed realizable Strategic NAV) is analytics/portfolio only; it never changes redemption or VEM (SPEC §6).

**Acceptance criteria:**
- [ ] No code path exists from any Strategic surface to Reserve principal, redemption math, or mint authority (review + tests).
- [ ] Simulated 50%/80%/100% Strategic loss leaves `B`, redemption, VEM, and mint authority bit-identical (FB-5).
- [ ] The 12% leg lands in Strategic custody in the same atomic settlement as the other legs.

### FR-9: Strategic Principal / Revenue Classification (P0 accounting; P1 policy use)

**Description:** Classification-by-substance is the accounting law of the Strategic surface.

Requirements:
1. Every inflow/return shall be classified by source and economic substance as exactly one of: Hard Reserve principal/accretion; Strategic contributed or returned principal; incremental POL fee yield by denomination; other realized Strategic revenue by denomination; unrealized Strategic mark (SPEC §6).
2. Returned principal is not revenue; unrealized gains/marks are not distributable revenue; noncash rewards remain Strategic inventory until realized or explicitly classified (F-41; SPEC §16).
3. Classification shall never be changed merely to fund a preferred recipient (SPEC §6).
4. Strategic principal may not be casually relabeled as revenue; a disclosed external startup/incubation runway may fund pre-scale work (F-45).

**Acceptance criteria:**
- [ ] Accounting surfaces expose the five classes distinctly and completely (UC-6).
- [ ] A returned-principal event observably books as principal, not revenue.

### FR-10: POL — Protocol-Owned Liquidity (P0 classification/conduct; sizing P1-adaptive)

**Description:** VUX/WETH POL is a Strategic Treasury sleeve with frozen boundaries.

Requirements:
1. Canonical POL begins with 150,000 VUX + ≈ $1,000 WETH-equivalent; initially shallow, intended for price discovery (SPEC §17.1).
2. Frozen boundaries: POL WETH never enters `B`; POL VUX always remains in `S`; Reserve principal never funds POL; no post-genesis VUX mint may fund POL; later POL VUX must be existing or purchased VUX; returned LP principal remains Strategic principal (F-36, F-37; SPEC §17.1).
3. Conduct rules: protocol-owned POL VUX shall not be redeemed against the Hard Reserve as a treasury operation and shall be non-voting for LSG (F-38).
4. Operators may choose a large or dominant protocol share of economically active VUX/WETH liquidity when attractive; no percentage is frozen; exact venue, pool type, fee tier, token order, ranges, custody, fee collection, and later deployment are reserved (SPEC §17.1; §16 herein).

**Acceptance criteria:**
- [ ] `B` accounting demonstrably excludes POL WETH at all times.
- [ ] No mint path can be invoked for POL sourcing post-genesis.
- [ ] Protocol POL VUX voting weight is provably zero under any future LSG mechanism (boundary requirement now; test at LSG build).

### FR-11: POL-Special VYRF Fee Routing (P0 outcome)

**Description:** Frozen economic policy for incremental POL fee yield — bypassing the general waterfall.

Requirements:
1. Incremental VUX-denominated POL fee yield → **burn**. It shall never be held, automatically re-LP'd, redeemed, recycled into mining, or counted as Strategic NAV after collection (F-39; SPEC §17.2).
2. Incremental WETH-denominated POL fee yield → **Hard Reserve, one-way** (increases `B`); it shall never route through the general waterfall (F-39; SPEC §17.2).
3. Returned LP principal → **Strategic principal** — it is not POL fee yield and not distributable revenue (F-40; SPEC §17.2).
4. The policy applies to incremental fee yield only, not principal; burning reduces `S`; WETH routing increases `B`; neither authorizes principal redemption, a new mint, or an automated implementation decomposition (FREEZE §8; SPEC §17.2).
5. Accounting truth: each VYRF leg (VUX burned, WETH→Hard, principal returned) shall be separately observable (SPEC §15).
6. No particular router, harvesting contract, cadence, or execution architecture is required — the requirement is the economic outcome and its accounting truth (SPEC §17.2).

**Acceptance criteria:**
- [ ] End-to-end scenario: fee accrual → classification → VUX burn observed with cause; WETH lands in `B`; principal legs stay Strategic.
- [ ] The general-waterfall surface provably cannot receive POL fee yield.

### FR-12: General Realized Strategic Revenue Policy Surface (P1 policy; P0 boundary)

**Description:** Principles frozen; exact percentages operator-reserved.

Requirements:
1. The general waterfall applies only to qualifying non-POL realized economics (SPEC §18).
2. Frozen principles: returned principal is not revenue; unrealized marks are not distributable; realized cash yield/fees/profit may fund — under disclosed operator policy — Strategic compounding, Hard Reserve accretion, legitimate operations/contributors, LSG/signaler incentives, and market infrastructure; Hard Reserve principal may fund none of these; founders/operators receive no primary KOTH skim or privileged VUX allocation (F-41…F-43; SPEC §18).
3. VUX-denominated non-POL revenue is normally burned unless later explicit founder authority establishes another justified treatment (F-46).
4. Exact general-waterfall percentages, operating shares/caps/reserves, and performance terms are operator-reserved and may evolve; the PRD shall provide the capability (a disclosed, classifiable, observable allocation policy surface) without fixing values (§16 herein; SPEC §18).
5. Sustainability posture: VUX must be capable of sustainably paying legitimate builders/operators from realized protocol economics if successful; if realized revenue is zero and external runway is exhausted, costs contract or receive separately disclosed funding — Reserve or mislabeled principal is never a fallback (SPEC §18).

**Acceptance criteria:**
- [ ] The policy surface can express and disclose allocations across the five permitted uses without code changes to frozen boundaries (capability test at build).
- [ ] Negative test: no configuration of the policy surface can reach Reserve principal or mint.

### FR-13: LSG — Core Mature Capability (P1 core; P0 boundary + activation authority)

**Description:** Bounded holder-directed allocation: real, core, and strictly fenced.

Requirements:
1. Canonical role: *eligible VUX holders express relative preference for marginal Strategic allocation among admitted opportunities* — nothing more (F-47; SPEC §19).
2. Authority separation (frozen): operators/risk authorities retain Strategy admission, due diligence, risk limits/caps, bounded execution, and emergency removal/recall; protocol upgrades and low-level security are separate authorities; the Hard Reserve and minting are never LSG-controlled (F-48, F-49; SPEC §19).
3. LSG shall be incapable of: choosing arbitrary recipients, withdrawing/encumbering Reserve principal, modifying KOTH routing, minting VUX, altering redemption, changing VEM, setting exploit response, or controlling ordinary upgrades (SPEC §19).
4. Activation: inactive at launch; internally threshold-gated; requires an affirmative operator decision; operators may activate earlier or later based on actual distribution, Strategic capital, meaningful Strategy choice, implementation safety, and concentration; **no numeric readiness gate or calendar date is frozen** (F-50; SPEC §19).
5. Pre-activation: the 12% Strategic leg remains Strategic — absence of active LSG never redirects it to Hard (F-51).
6. Protocol-owned POL VUX is always excluded from LSG voting power (F-38; SPEC §19).
7. Signalers may be rewarded only from permitted realized protocol economics under disclosed policy; external or Strategy-funded incentives must be observable and cannot convert the admission/security boundary into token-vote control (SPEC §19).
8. The exact voting, weighting, epoch, delegation, anti-capture, precision, keeper, and execution mechanism belongs to later requirements/design work and must satisfy this boundary (SPEC §19; §19 herein).

**Acceptance criteria:**
- [ ] Launch ships with LSG inactive **and** an explicit operator-controlled activation authority present (SPEC §4.1).
- [ ] Boundary review: every LSG-prohibited authority in item 3 is structurally unreachable from the LSG surface.
- [ ] Activation and allocation actions are observable per UC-9.

### FR-14: Settlement & Treasury Observability — Accounting Truth (P0)

**Description:** Users and indexers must be able to reconstruct the protocol's economic truth.

Requirements:
1. Per settlement, observably distinguish: outgoing epoch/King and incoming King; exact paid price and all three routed amounts; `B_pre`, `S_pre`, exact `D_R`, `Qraw`, `Qsafe`, actual `Qmint`; bootstrap-vs-ordinary; Strategic contributed principal received; VUX supply changes and their cause (SPEC §15).
2. Strategic/POL accounting shall separately expose, at product-semantic level: contributed/returned principal, realized fee/revenue by denomination, VUX burned, WETH sent to Hard, and general-waterfall amounts (SPEC §15).
3. LSG (when active) shall expose: activation state, admitted Strategy identity, bounded allocation signal/result, responsible authority (SPEC §15).
4. Analytics shall be able to separately report: genesis POL inventory, current total supply, cumulative raw opportunity, completed mints, VUX burns by cause, redemption burns, Hard WETH and `B/S`, Strategic contributed principal, realized revenue, disclosed Strategic NAV — and Strategic NAV shall not be labeled backing (SPEC §21).
5. Exact event names, indexing choices, and schema layout remain SDD decisions (SPEC §15).

**Acceptance criteria:**
- [ ] An independent indexer, using only observable facts, can reproduce `S`, `B`, `B/S`, per-settlement legs, and burn causes with zero ambiguity.
- [ ] Read-only estimates create no entitlement (SPEC §5).

### FR-15: Truthful Mining UX (P0)

**Description:** The three-tier truth is a product requirement wherever mining state is shown.

Requirements:
1. Every user-facing surface and analytics feed shall distinguish: (1) **raw clock limit / maximum from time** — time-only opportunity, never earned or owed; (2) **VUX if displaced now** — a live estimate under current price, supply, Hard contribution, and VEM; may rise or fall; not claimable; (3) **VUX mined/earned** — actual VUX minted by completed settlement only (F-55; SPEC §21).
2. Raw opportunity shall never be described as already earned, owned, claimable, owed, guaranteed, or debt (SPEC §11).
3. Canonical explanation (verbatim availability required): "You mine while you hold the throne. The clock sets the maximum reward. Your exact VUX is settled when the next King pays, and only the amount safely backed by that payment is minted." (SPEC §21).
4. Contestability truth: VUX may claim *"No user received VUX at genesis. Every user-owned VUX was mined under the same public KOTH/VEM rules or purchased from existing supply in the open market."* — and may **not** claim broad distribution, anti-whale design, or equal outcomes without live evidence (SPEC §22).

**Acceptance criteria:**
- [ ] UX copy review: the three tiers are visually and verbally distinct; no "earned while clock runs" phrasing anywhere.
- [ ] The live estimate is labeled non-claimable and variable.

### FR-16: Operator, Risk & Emergency Authority Boundaries (P0 boundary)

**Description:** Bounded human authority — real responsibility, structurally fenced.

Requirements:
1. Operators/risk authorities hold: Strategy admission/diligence/caps, bounded execution, emergency removal/recall, security responsibility, LSG activation, disclosed policy setting (F-49, F-50; SPEC §5, §19).
2. Operator discretion is not authority to: raid the Reserve, mint VUX, reclassify principal, create undisclosed founder economics, or make unverified ROOT/GIGA claims (FREEZE §4 tail).
3. No founder/operator/developer/signaler receives genesis allocation or primary KOTH flow (F-5, F-43).
4. Bribes: default posture is **own the liquidity**; protocol-funded VUX/WETH bribes are measured tactical experiments funded from realized protocol economics by default, never Hard Reserve principal; failed rental must not become the primary liquidity strategy; exact sizes/hurdles unfrozen (F-52; SPEC §20.1).
5. ROOT/GIGA: Strategic hypotheses/opportunities until canonical facts exist — never `B`, never VEM support, never a redemption promise, no required allocation percentage; founder/partner expectations (professional/private management; material GIGA support; 7.5% of GIGA supply at TGE; heavy bidding intent) shall be represented only with correct evidence labeling and never promoted to public technical facts before verification of canonical contracts, documentation, token rights, allocation/vesting, custody, liquidity, valuation, and security evidence (F-53; SPEC §20.2).
6. "Operator," "risk authority," and "execution" are product responsibilities; exact identities, keys, modules, governance primitives, and upgrade arrangements belong to future planning/architecture within this specification (SPEC §5).

**Acceptance criteria:**
- [ ] Authority-boundary review maps every privileged action to a §16-reserved decision or a frozen prohibition; no action reaches Reserve/mint/classification.
- [ ] All public ROOT/GIGA statements in any protocol surface carry evidence labels.

---

## 10. Monetary & Accounting Invariant Register

> **Sources**: SPEC §24 (INV-1…INV-37, restated here in substance-preserving form); FREEZE §3. This register is the traceability spine for `/architect`, `/review-sprint`, and `/audit-sprint`: every invariant must remain demonstrably true in every later artifact.

### 10.1 Supply and FAIR issuance

| INV | invariant | carried by |
|---:|---|---|
| 1 | `S` is always complete `VUX.totalSupply()` with no protocol-balance exclusion | FR-7 |
| 2 | Genesis supply is exactly `150,000 × 10^18 + 1` raw VUX units | FR-1 |
| 3 | Every user/discretionary address receives zero genesis VUX | FR-1 |
| 4 | Only KOTH/VEM may mint after genesis, only to the outgoing public King during successful settlement | FR-4, FR-5 |
| 5 | No treasury, POL, governance, recovery, migration, recapitalization, or discretionary mint exists | FR-5, FR-10 |
| 6 | `Qmint ≤ Qraw` and `Qmint ≤ Qsafe` with full-precision safe arithmetic | FR-5 |
| 7 | Bootstrap mints zero | FR-6 |
| 8 | Unsupported opportunity expires without carry, IOU, debt, or entitlement | FR-5 |
| 9 | Each epoch uses its snapshotted UPS for at most 3,000 eligible seconds | FR-3 |

### 10.2 Hard Reserve and VEM

| INV | invariant | carried by |
|---:|---|---|
| 10 | `B` is only raw canonical RH WETH held by the Hard Reserve | FR-7 |
| 11 | Strategic assets, NAV, POL, ROOT/GIGA, stable assets, prices, and yield never enter `B` or support minting | FR-5, FR-7, FR-8 |
| 12 | Issuance uses the exact realized current-settlement `D_R` after it enters Hard | FR-5 |
| 13 | Authorized issuance cannot reduce `B/S` | FR-5 |
| 14 | Hard Reserve principal has no discretionary call, approval, sweep, pause, migration, successor, owner, or upgrade path | FR-7 |
| 15 | Redemption uses pre-redemption `B`/`S`, burns exact `q`, pays `floor(B×q/S)` with zero fee, and preserves `S_MIN` | FR-7 |
| 16 | Rounding favors the Reserve | FR-5, FR-7 |
| 17 | Reserve principal never becomes Strategic principal or revenue working capital | FR-7 |

### 10.3 Settlement and primary routing

| INV | invariant | carried by |
|---:|---|---|
| 18 | Ordinary payment uses exact static `king=floor(80%)`, `strategic=floor(12%)`, `reserve=remainder` arithmetic | FR-4 |
| 19 | Reserve receives nominally at least 8% and all split dust | FR-4 |
| 20 | No other primary recipient exists | FR-4 |
| 21 | Settlement is atomic and successor state cannot rewrite the outgoing epoch or mint recipient | FR-4 |
| 22 | First activation sends approximately 88% or greater Hard, 12% Strategic, and mints zero | FR-6 |

### 10.4 Strategic, POL, revenue, and LSG

| INV | invariant | carried by |
|---:|---|---|
| 23 | Strategic principal is separately accounted and cannot create claims on Hard | FR-8 |
| 24 | Strategic total loss cannot change redemption, VEM, mint authority, or Reserve authority | FR-8 |
| 25 | POL WETH is Strategic, and POL VUX remains in `S` | FR-10 |
| 26 | No post-genesis POL VUX mint or Reserve-funded POL exists | FR-10 |
| 27 | Protocol POL VUX is non-redeeming as treasury conduct and non-voting in LSG | FR-10, FR-13 |
| 28 | Returned LP/Strategy principal is principal, not revenue | FR-9, FR-11 |
| 29 | Incremental VUX POL fee yield burns; incremental WETH POL fee yield enters Hard; both bypass the general waterfall | FR-11 |
| 30 | Unrealized marks are not distributable realized revenue | FR-9 |
| 31 | General revenue percentages and operations caps are operator-reserved within the frozen funding boundaries | FR-12, §16 |
| 32 | LSG controls only relative marginal Strategic allocation among admitted Strategies | FR-13 |
| 33 | LSG cannot reach Hard, minting, arbitrary recipients, security parameters, exploit response, or upgrades | FR-13 |
| 34 | LSG activation requires affirmative operator action; no numeric readiness gate is founder-frozen | FR-13 |

### 10.5 Trust and provenance

| INV | invariant | carried by |
|---:|---|---|
| 35 | Strategic, POL, revenue, LSG, and governance failures cannot create a Hard Reserve claim | FR-8, §11 |
| 36 | The VUX-controlled Reserve's ownerless/immutable description must always accompany the external canonical WETH YELLOW disclosure | §13 |
| 37 | No product concept expands source-reuse authority; Strategic/LSG/VYRF code is VUX-original unless later provenance review explicitly changes that status | §15 |

---

## 11. Failure Behavior Requirements

> **Sources**: SPEC §25 (complete register, restated as testable requirements FB-1…FB-18); FREEZE F-34, F-35, F-44

Each row is a requirement: the canonical outcome must hold under test, review, or documented scenario analysis.

| FB | condition | required canonical outcome |
|---:|---|---|
| 1 | Rig/mining path fails | New mining may halt; existing redemption remains independent, subject to chain/backing-asset function |
| 2 | No challenger | King remains; raw accrual caps at 3,000 s; no VUX becomes owed |
| 3 | Weak demand | Less actual supply; missed opportunity expires |
| 4 | High takeover demand | VEM/clock cap issuance; extra Hard contribution increases `B/S`; Strategic leg remains Strategic |
| 5 | Strategic NAV falls 50% / 80% / 100% | Hard `B`, redemption, VEM, and mint authority unchanged; no rescue or recap mint |
| 6 | ROOT impaired or GIGA reprices | Strategic loss only; admission/position/operator risk policy respond; no Hard claim |
| 7 | POL fails or is illiquid | Price discovery and Strategic NAV may suffer; Hard arithmetic unchanged |
| 8 | POL fee routing unavailable before receipt | No anticipated revenue counted; principal classification remains; Hard principal not substituted |
| 9 | Realized Strategic revenue is zero | General distributions/operations receive no protocol revenue; external runway or cost reduction required |
| 10 | LSG absent, delayed, captured, or fails | Operators retain bounded pre-LSG policy/emergency responsibility; Hard and minting remain unreachable |
| 11 | Voters chase bribes | Only admitted/capped Strategic allocations are exposed; admission/risk authority may remove/recall |
| 12 | Operations exceed realized economics | No Reserve payroll or automatic principal relabeling; costs/funding adjust |
| 13 | Mass redemption while Strategic assets are illiquid | Hard pays synchronously pro rata; Strategic positions need not be sold and do not supplement payout |
| 14 | VUX trades below Hard backing | Holder redemption remains the hard claim; no oracle price defense or Reserve-funded action triggers |
| 15 | Governance wants Reserve rescue | No authorized path exists |
| 16 | Recapitalization mint is proposed | No authorized path exists |
| 17 | RH Chain unavailable | Actions, including redemption, are delayed with the chain; balances are not reclassified |
| 18 | Canonical RH WETH adversely upgraded | Transferability or principal may fail under the disclosed external trust risk; VUX cannot repair it with Reserve discretion |

**Acceptance criteria:**
- [ ] FB-2…FB-5, FB-7, FB-13…FB-16 demonstrated by automated tests; FB-1, FB-6, FB-8…FB-12 by review + scenario documentation; FB-17…FB-18 by documented disclosure and design analysis.

---

## 12. Non-Functional Requirements

> **Sources**: SPEC §3.4, §§9–15, §23, §27; FREEZE F-12, F-15, F-16, F-56, F-57; LIC §§1–2, §14. No performance/scalability NFRs are invented: authority imposes none, and gas strategy is reserved to `/architect`.

### NFR-SEC — Security

1. **Hard-integrity primacy**: any conflict between Hard Reserve integrity and any other concern (mining continuity, Strategic performance, POL, revenue, governance, LSG, recovery convenience) resolves for the Reserve (SPEC §3.4).
2. **Immutability posture**: the VUX-controlled Reserve surface is ownerless, immutable, non-upgradeable, non-pausable, with no arbitrary-call/approval/sweep/successor/migration path (F-12).
3. **Atomicity**: settlement and redemption commit all authorized effects or none (SPEC §9, §15).
4. **Arithmetic**: full-precision, overflow-safe arithmetic everywhere frozen formulas apply; issuance rounds down; required-contribution rounds up; redemption rounding favors the Reserve (F-15, F-16; SPEC §13).
5. **No oracle in the monetary core**: primary settlement, VEM, and redemption consume no oracle, market-price, or NAV input (F-9, F-14).
6. **Measured reality**: `D_R` measurement rejects inconsistent settlements (SPEC §15 step 8).
7. **Boundary unreachability**: LSG/Strategic/POL/revenue surfaces are structurally incapable of reaching Reserve principal, redemption math, mint authority, or routing constants (F-34, F-48).

### NFR-REL — Reliability & failure independence

1. Redemption availability is independent of mining, Strategic, POL, LSG, and revenue surfaces (FB-1; SPEC §25).
2. The monetary core (KOTH settlement, VEM, redemption) must function without any off-chain actor; operational conveniences (harvesting, reporting) may be assisted but their absence must not corrupt classification or Hard arithmetic (FB-8; SPEC §17.2).
3. Chain unavailability delays actions without reclassifying balances (FB-17).

### NFR-TRUST — Trust honesty

1. The YELLOW canonical-WETH disclosure accompanies every ownerless/immutable Reserve description (INV-36; §13).
2. VUX never describes the full backing stack as trustless, immutable, or governance-free (SPEC §23).
3. ROOT/GIGA claims carry evidence labels until verified (F-53).

### NFR-ACCT — Accounting truth

1. Classification-by-substance (SPEC §6) is complete, observable, and tamper-evident at product level.
2. Strategic NAV is disclosed under policy but never labeled backing (SPEC §21).

### NFR-COMP — Licensing & compliance posture

1. Project licence `GPL-3.0-or-later`; root `LICENSE` (unmodified GPLv3 text) and `THIRD_PARTY_NOTICES.md` obligations per LIC §14 are release requirements.
2. SPDX per-file policy per LIC §15; no invented copyright holders; notices preserved.
3. Public/legal characterization of Strategic/governance rights requires later jurisdiction-specific review (SPEC §3.5) — tracked as a launch-adjacent obligation, not resolved here.

### NFR-UX — Truthful presentation

1. FR-15's three-tier distinction is mandatory on every surface that shows mining state.
2. Estimates are labeled non-claimable; no surface promises equal outcomes or broad distribution without live evidence (SPEC §22).

---

## 13. Trust Assumptions & Required Disclosures

> **Sources**: SPEC §23; FREEZE F-56; MAP §7

1. **Canonical RH WETH**: Hard backing uses canonical Robinhood Chain WETH at `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73`. Accepted status **YELLOW**: current implementation is byte-verified canonical Arbitrum `aeWETH`; current behavior has no ordinary pause/blacklist/fee/rebase/arbitrary-mint/force-transfer/transfer-hook; bridge infrastructure includes a gateway-only burn primitive constrained by the deployed gateway; the token, gateway, and router are upgradeable; a 7-of-8 Robinhood Chain authority has a direct no-delay upgrade path (alongside a parallel seven-day timelock path); a future upgrade could block, burn, freeze, or seize Reserve WETH; VUX cannot constrain that authority or guarantee an exit window (SPEC §23).
2. **Canonical disclosure (verbatim, mandatory wherever the Reserve is described as ownerless/immutable):**
   > The VUX Hard Reserve contract is designed to be immutable and ownerless. Its backing asset is canonical Robinhood Chain WETH, which retains an external Robinhood Chain governance and upgrade trust assumption.
3. **Human-authority trust**: operators/risk authorities are trusted for Strategic stewardship within frozen boundaries — never for Reserve custody, minting, or redemption (F-49; FREEZE §4 tail).
4. **Interface, not vendored source**: canonical WETH is an external deployed runtime contract; VUX interacts through a cleared interface and never vendors its implementation (REG `external_runtime_interfaces`; LIC §13).
5. **No trustless claims**: marketing/docs must not describe the full backing stack as trustless, immutable, or governance-free (SPEC §23).

---

## 14. Authorization Boundaries & Role Model

> **Sources**: SPEC §5, §19; FREEZE §4, F-43, F-44, F-48…F-50

Conceptual responsibilities — not required contracts, addresses, or module topology (SPEC §5).

| role/surface | may | must never |
|---|---|---|
| VUX token | complete supply truth; exact genesis mint; KOTH/VEM-only post-genesis mint; transfers; authorized burns | discretionary/recovery mint |
| Hard Reserve | hold raw canonical RH WETH; redeem pro rata | Strategic activity, governance, payroll, rescue, arbitrary paths, any owner |
| KOTH/Rig | operate the one throne, Dutch price, epoch, payment, split, outgoing settlement | mint outside VEM; deviate from static `80/8/12` |
| Strategic Treasury/custody | receive/account the 12% leg and protocol-owned risk capital | enter `B`; custody architecture is reserved to `/architect` |
| POL | protocol-owned VUX/WETH market infrastructure | use Reserve funds; use post-genesis mint; redeem-as-treasury; vote |
| POL fee policy | classify and route incremental fee yield by denomination | route POL fee yield through the general waterfall |
| General revenue policy | classify realized non-POL economics; allocate permitted uses under disclosed operator policy | receive principal/marks; touch Reserve principal |
| Strategy admission/risk | diligence, admit, cap, remove, recall, bound execution | reach the Hard Reserve |
| LSG | holder relative-allocation signal among admitted Strategies (when activated) | everything in FR-13 item 3 |
| Execution | carry out bounded admitted allocation | expand recipients, caps, or security authority |
| Read-only periphery | truthful epoch/price/opportunity/estimate/accounting views | create entitlements |

Boundary law: precedence is frozen prohibitions > frozen requirements > operator-reserved judgment; an operator-reserved decision may never violate a frozen boundary (FREEZE §2).

---

## 15. Provenance & Source-Boundary Requirements (Product Level)

> **Sources**: LIC §§1–6, §§13–17, §19; REG (all pins); DELTA §§2–6; REG-DELTA; SPEC §27; FREEZE F-57

These are planning-level requirements binding this PRD and all later lifecycle phases; they authorize **no** new source reuse, select **no** dependencies, and modify **no** licence posture.

- **PROV-1 (posture)**: Project licence is `GPL-3.0-or-later`; existing `LICENSE`/`THIRD_PARTY_NOTICES.md` posture, source pins, file allowlist, dependency-selection gates, and **default-deny** policy remain authoritative and unchanged (SPEC §27; DELTA §2).
- **PROV-2 (allowlist)**: Direct v1 reuse is limited to exactly three Miner Manifold files at `bcffbf1eb963810acb14a1fd1c73d03a53a085a8` — `contracts/Rig.sol` (blob `d362ef35…`), `contracts/Unit.sol` (blob `26d491eb…`), `contracts/interfaces/IUnit.sol` (blob `7069422c…`) — under file MIT grants + collaborator permission + conservative Euler `GPL-2.0-or-later` lineage for the Rig auction skeleton, with GPLv3 selected for VUX (LIC §§4–6; REG).
- **PROV-3 (clean-source surfaces)**: The corrected surfaces are `VUX_ORIGINAL_CLEAN_SOURCE_REQUIRED` unless later provenance authority approves a specific source: static `80/8/12` settlement and Reserve-favoring dust arithmetic (except separately allowlisted generic Rig lineage); separate Strategic receipt/custody/principal-revenue accounting; Hard-only `D_R` measurement; POL principal-vs-fee-yield classification; VUX POL-fee burn; WETH POL-fee one-way Hard routing; general realized-revenue classification/policy surface; future LSG admission/signal/execution/emergency boundary; protocol-owned POL VUX non-voting treatment (DELTA §3; REG-DELTA).
- **PROV-4 (named prohibitions)**: No copying/porting/deriving from Liquid Signal Governance (`DEFERRED_NOT_V1`; its label is source-disposition only and does not exclude the VUX-original LSG product role — DELTA §4), gumball6900 (`REFERENCE_ONLY`; VYRF outcome is not a port authorization — DELTA §5), Olympus v3/docs (`REFERENCE_ONLY`), give.fun (transitive reference), Miner non-allowlisted files (Strategy/Hopper/Router/Multicall/IRig/tests), or any unlisted upstream (LIC §5, §16).
- **PROV-5 (Hard Reserve & VEM originality)**: Hard Reserve and VEM are implemented from the canonical specification's equations; if later review finds material line/structure similarity to prohibited sources (e.g., gumball `Fund.sol`), the file is reclassified as derived and re-cleared before merge (LIC §§7–8).
- **PROV-6 (pins)**: Full-40-character-SHA pins only; branches/tags/HEAD are never authority; any new source, newer revision, LSG/gumball/Olympus/ROOT/GIGA integration source, or unlisted dependency triggers a provenance refreeze **before** use (LIC §17; REG-DELTA `future_refreeze_required_for`).
- **PROV-7 (SDD gates)**: Before implementation, the SDD must select exact dependencies with immutable pins (e.g., an exact OpenZeppelin release — family cleared, version unselected), identify every imported/copied/modified file, document VUX-original vs. derived treatment per file, preserve notices, and update `THIRD_PARTY_NOTICES.md` iff selected sources require it (DELTA §6; LIC §13).
- **PROV-8 (notices & SPDX)**: LIC §14 notice obligations and LIC §15 SPDX policy (`GPL-3.0-or-later` for VUX-original; `MIT AND GPL-3.0-or-later` for materially Miner-derived files; retain upstream SPDX on unmodified files; no invented copyright holders) are release requirements.
- **PROV-9 (mechanical fences)**: Planning/SDD must encode fail-closed checks: build/review fails if an upstream URL is mutable, a SHA is not 40 chars, a non-allowlisted upstream file appears, a required notice is absent, or a dependency lacks an immutable pin (LIC §19.7).

**Acceptance criteria:**
- [ ] This PRD introduces no source selection, no dependency choice, no licence change (self-check: it does not).
- [ ] SDD phase demonstrates PROV-6/7/9 gates before any code exists.

---

## 16. Operator-Reserved Decision Register

> **Sources**: FREEZE §4 (complete); SPEC §16, §17.1, §§18–20, §26. Each reserved decision is preserved as reserved; the PRD specifies only the capability and boundary the product must provide. Freezing any of these values in a later artifact is a load-bearing failure.

| # | reserved decision | required product capability | frozen boundary that still applies |
|---:|---|---|---|
| R-1 | Strategic portfolio weights | Allocation among verified/admitted assets, observable per §6 classes | Strategic assets remain outside `B` |
| R-2 | POL size and portfolio share | POL can be grown/reduced; venues/ranges/custody choosable later | No mint, no Reserve principal; conduct rules FR-10.3 |
| R-3 | Strategic deployment timing | Staging, pausing, resuming deployment | Static receipt never forces deployment |
| R-4 | Strategic dry powder | Holding raw WETH indefinitely is a first-class state | Never counted as `B`; never VEM credit |
| R-5 | Strategy admission | Admission/diligence/limits/removal/recall authority surface | Cannot reach Hard Reserve |
| R-6 | LSG activation timing | Explicit operator-controlled activation authority, observable | Affirmative decision required; no calendar auto-activation |
| R-7 | Internal LSG readiness thresholds | Thresholds settable/evolvable within the frozen LSG role | Distribution/capital/participation/safety/concentration tests are operator judgment; never founder-frozen numbers |
| R-8 | ROOT/GIGA exposure | Admission path after verification of canonical facts | Bounded portfolio judgment only after documentation/deployment/rights/liquidity/custody facts exist |
| R-9 | General realized-revenue waterfall percentages | Disclosed, evolvable allocation policy across the five permitted uses | Principal/marks excluded; Reserve excluded; no primary skim |
| R-10 | Operations budget & compensation | Funding legitimate operations/contributors from realized economics or disclosed external runway | No primary flow, no Reserve principal, no mislabeled Strategic principal |
| R-11 | Signaler rewards | Reward surface fundable from permitted realized economics under disclosed policy | Observable; cannot convert security boundary into token-vote control |
| R-12 | Bribe experiment sizing | Tactical, measured experiments with stop rules | Realized-economics funding by default; never Hard Reserve principal; never primary strategy |
| R-13 | Market-infrastructure tactics (buybacks, purchased VUX for POL, venue/range choices) | Tactic execution under permitted funding | Cannot alter VEM/redemption; POL VUX must be existing/purchased |
| R-14 | Deployment facts (addresses, blocks, immutable WETH conversions, schedule-start timestamp, AMM implementation facts, final dependency pins) | Recorded as verified facts at deployment per FR-1.4 and PROV gates | Conversion is one-shot, founder-approved, no runtime oracle |

Boundary reminder (FREEZE §4 tail): operator discretion is never authority to raid the Reserve, mint VUX, reclassify principal, create undisclosed founder economics, or make unverified ROOT/GIGA claims.

---

## 17. Research-Guidance Quarantine

> **Sources**: FREEZE §5; SPEC §18, §20, §26; MAP §3 ("RESERVED, NOT FROZEN")

The following values are **RESEARCH GUIDANCE, NOT AUTHORITY**. No PRD requirement, SDD parameter, interface, default constant, UI copy, or implementation may present them as immutable founder parameters. They may appear in later operator policy documents as *chosen* (and changeable) values only.

| guidance value | status |
|---|---|
| General revenue `50% compound / 10% Hard / 25% operations / 10% signalers / 5% market infrastructure` | Simulation/comparison baseline only |
| `25%` operator share | Guidance; not a canonical entitlement |
| `2.5%` average Strategic-NAV operator ceiling | Guidance; not a frozen fee or cap |
| LSG gates — 60 days, 5M distributed VUX, 50 holders, 10 effective participants, 35% holder ceiling, $250K Strategic capital | Illustrative readiness values only |
| ROOT 10% pilot, 25% mature cap, 35% aggregate look-through cap | Prudent research guidance pending evidence and operator policy |
| Dry powder 30% (first 180 days), 40–60% (downturn), 10% deployment per 30 days | Scenario guidance only |
| LP-per-bribe-dollar, one-year depth, 35% retention, 1.5× direct-POL comparison thresholds | Measurement guidance only |

**Acceptance criterion:**
- [ ] Grep-level check on every later artifact: none of these values appears outside an explicitly labeled guidance/policy-example context.

---

## 18. Scope: Launch vs. Mature vs. Excluded (Non-Goals)

> **Sources**: SPEC §4, §22; FREEZE F-54; MAP §7

### 18.1 In scope — launch (P0)

All FR-1…FR-11, FR-13's boundary + activation authority (inactive), FR-14, FR-15, FR-16 boundaries; §11 failure behavior; §12 NFRs; §13 disclosures; §15 provenance gates.

### 18.2 In scope — mature core (P1)

Active LSG signaling (FR-13); general revenue waterfall use (FR-12); expanded POL; admitted Strategies; verified ROOT/GIGA admission; signaler economics; bribe experiments — all operator-paced (§16).

### 18.3 Explicitly out of scope (non-goals)

| exclusion | reason |
|---|---|
| Crown Share, hVUX, Cooler-style lending, tournaments, multiple thrones, new emission seasons | Not authorized by v1 (SPEC §4.3) |
| Oracle-mediated monetary router; any dynamic routing | Frozen static routing (F-9) |
| Reserve-backed Strategy rescue; recapitalization mint | No authorized path (FB-15, FB-16) |
| Privileged token allocation of any kind | FAIR doctrine (F-5) |
| Anti-whale machinery, wallet caps, identity gates, punitive taxes, hidden allocations | Fair access ≠ equal outcomes (F-54; SPEC §22) |
| NAV-based redemption or Strategic-NAV backing claims | Hard/Strategic separation (F-10; SPEC §3.5) |
| Guaranteed supply targets or emission promises | 4 UPS is opportunity, not target (F-19) |
| Public promotion of unverified ROOT/GIGA facts | Evidence labeling required (F-53) |
| Exact contract decomposition, custody primitive, AMM integration, LSG mechanism, keeper design, access-control primitive, dependency versions, deployment addresses | Reserved to `/architect` and later phases (SPEC §4.3; §19 herein) |

---

## 19. Reserved for `/architect` (Explicit Non-Decisions)

> **Sources**: SPEC §4.3, §5, §15, §17.2, §19, §26–§27; LIC §13, §17, §19; operator node brief (mutation boundary)

This PRD intentionally does **not** decide, and `/architect` must later decide within the frozen boundaries:

1. Contract decomposition and module/call-graph topology (including the checks-effects-interactions ordering that realizes SPEC §15 atomically).
2. Storage layout.
3. Exact custody primitive(s) for Strategic Treasury and POL.
4. Exact AMM/pool implementation, venue, fee tier, tick/range mechanics for POL.
5. Exact LSG voting algorithm, weighting, epochs, delegation, anti-capture, precision, and contract topology.
6. Keeper/automation architecture (e.g., VYRF harvest cadence/mechanism — outcome is frozen, mechanism is not).
7. Precise access-control implementation for operator/risk/execution roles.
8. Exact event schema names/layout (observability *content* is frozen in FR-14).
9. Dependency/library selection and exact pinned releases (PROV-7).
10. Deployment topology, addresses, and procedures (deployment-time facts recorded per R-14).
11. Gas optimizations.

Where a product requirement depends on one of these, this PRD states the required behavior/invariant and leaves the mechanism open. Any `/architect` output that varies a frozen value or resolves an operator-reserved decision is out of bounds.

---

## 20. Launch & Acceptance Criteria

> **Sources**: SPEC §4.1, §15, §24–§25; FREEZE §§3, 6–7; §§9–17 herein

### 20.1 Launch criteria (all P0)

- [ ] FR-1…FR-11 and FR-14…FR-16 acceptance criteria pass.
- [ ] LSG inactive with operator-controlled activation authority present and POL non-voting rule preserved (FR-13 launch portion).
- [ ] All 37 invariants (§10) demonstrated by test or review, each traced to its carrying FR.
- [ ] All 18 failure behaviors (§11) demonstrated per their assigned method.
- [ ] Genesis/WETH conversion evidence recorded (FR-1.4); `P0/N0 = 1.10`; cushion inequality holds.
- [ ] YELLOW disclosure present wherever required (§13).
- [ ] Provenance gates PROV-1…PROV-9 clean; licence/notice files per NFR-COMP.
- [ ] Truthful-UX review passes on every mining-state surface (FR-15).

### 20.2 Post-launch / mature acceptance (P1, operator-paced)

- [ ] General revenue policy surface operates within frozen principles when first used (FR-12).
- [ ] LSG activation (when it occurs) satisfies UC-9/FR-13 acceptance criteria.
- [ ] First Strategy admission, first POL expansion, first bribe experiment (if any) each traceable to §16 capabilities and §14 boundaries.

### 20.3 PRD acceptance (this document)

- [ ] Operator confirms the 20 reviewability answers (§21) match founder intent.
- [ ] Operator confirms reserved decisions (§16) remain reserved and quarantined values (§17) remain quarantined.
- [ ] On acceptance, this PRD becomes the requirements baseline for `/architect`.

---

## 21. Operator Reviewability Q&A

> **Sources**: operator node brief (Required reviewability, 20 questions); MAP §8; SPEC §28; sections of this PRD as cited per row

| # | question | answer | PRD section |
|---:|---|---|---|
| 1 | What does the user do? | Take the throne (pay WETH), hold/mine, get displaced (receive 80% recycle + settled VUX), redeem anytime, or buy/sell openly; at maturity, signal Strategic allocation via LSG | §8 UC-1…UC-5, UC-9 |
| 2 | What does the King receive? | On displacement: exactly `floor(P×8,000/10,000)` WETH recycle + exactly `Qmint = min(Qraw, Qsafe)` VUX | FR-4, FR-5 |
| 3 | Where does each payment leg go? | `king = floor(80%)` → outgoing King; `strategic = floor(12%)` → Strategic Treasury; `reserve = remainder` (≥ nominal 8% + all dust) → Hard Reserve; 0% anyone else | FR-4 |
| 4 | What safely funds VUX issuance? | Only exact measured current-settlement Hard Reserve WETH delta `D_R` | FR-5 |
| 5 | What can never fund issuance? | Strategic WETH/NAV, POL, ROOT, GIGA, stable assets, prices, expected yield, oracle marks, quotes, later deposits, the nominal 8% | FR-5.4 |
| 6 | What is guaranteed by the Hard Reserve? | Fee-free pro-rata raw-WETH redemption: `floor(B×q/S)`, pre-redemption values, Reserve-favoring rounding, `S_MIN = 1` raw VUX, non-decreasing `B/S` through authorized issuance | FR-7 |
| 7 | What is NOT guaranteed by Strategic NAV? | Anything: no redemption claim, no backing, no mint support, no rescue; it may go to zero with Hard untouched | FR-8.5–8.6, §4.2 |
| 8 | What does 4 UPS mean? | An abundant raw faucet: maximum time opportunity (≈20.655M pre-tail raw), never target supply, entitlement, or promise | FR-3.5 |
| 9 | What happens to unsupported raw opportunity? | It expires — no carry, IOU, debt, makeup, entitlement, or high-water emission | FR-5.5 |
| 10 | What happens at bootstrap? | Reserve is genesis King; clock disabled; first takeover routes ≈88%+ Hard / 12% Strategic, mints zero, and starts the first public epoch | FR-6 |
| 11 | What is Strategic principal? | Protocol-owned risk capital: 12% legs, authorized external project capital, returned deployed principal, returned LP principal — never Hard backing, never revenue by relabeling | FR-8.4, FR-9 |
| 12 | What is realized revenue? | Source-classified realized cash yield/fees/profit only — never returned principal, never unrealized marks | FR-9.2, FR-12 |
| 13 | How does POL-special VYRF work? | Incremental VUX fee yield burns; incremental WETH fee yield enters Hard one-way; returned LP principal stays Strategic; all bypass the general waterfall | FR-11 |
| 14 | What does LSG control? | Only relative preference over marginal Strategic allocation among operator-admitted opportunities | FR-13.1 |
| 15 | What does LSG explicitly not control? | Hard Reserve, minting, arbitrary recipients, low-level security parameters, exploit response, ordinary upgrades, KOTH routing, redemption, VEM | FR-13.3 |
| 16 | Who decides when LSG activates? | Operators — affirmatively, after internal (unfrozen) readiness thresholds; earlier or later per actual conditions | FR-13.4, R-6/R-7 |
| 17 | Which portfolio/revenue decisions remain adaptive? | R-1…R-14: weights, POL size, timing, dry powder, admissions, LSG gates, ROOT/GIGA exposure, waterfall percentages, ops budgets, signaler rewards, bribes, market tactics, deployment facts | §16 |
| 18 | What happens if Strategic Treasury goes to zero? | Supply accounting, Hard redemption, KOTH, VEM, and FAIR issuance survive; no rescue, no recap mint | FR-8.6, FB-5 |
| 19 | Why does VUX remain useful after the mining/TGE phase? | Surviving hard exit right + productive Strategic NAV exposure + protocol-owned liquidity + bounded allocation influence + possible signaler economics + realized compounding + verified ecosystem optionality | §3.3, §7.3, SPEC §21 |
| 20 | Which requirements are launch-critical versus mature capability? | P0 = §18.1 list; P1 mature-core = §18.2 list; excluded = §18.3 | §18, §20 |

---

## 22. Risks, Assumptions & External Dependencies

> **Sources**: SPEC §23, §25; FREEZE §7; LIC §18; process facts from this planning node

### 22.1 Risks and mitigations

| risk | probability | impact | mitigation (already frozen in requirements) |
|---|---|---|---|
| Canonical RH WETH adverse upgrade (7-of-8, no-delay path) | Low | Critical | Mandatory YELLOW disclosure (§13); no trustless claims; FB-18 documented; VUX cannot mitigate structurally — honesty is the mitigation |
| Strategic losses erode holder confidence | Medium | Medium | Failure independence (FR-8.5); Strategic-zero survival (FR-8.6); truthful NAV disclosure never labeled backing |
| Weak demand → low settled supply | Medium | Low (by design) | 4 UPS is opportunity, not promise (FR-3.5); FB-3 |
| Whale/automation dominance in KOTH | High | Low (accepted) | FAIR truth: no equal-outcome promise; contestability claim limited to genesis fairness (SPEC §22) |
| LSG capture attempts (bribed voters) | Medium | Low | Bounded role + admission/caps + emergency recall (FR-13, UC-10, FB-11) |
| Mislabeling pressure (principal→revenue) under funding stress | Medium | High | Classification law (FR-9); FB-9, FB-12; disclosed external runway only |
| UX drift into "earned while running" framing | Medium | High | FR-15 acceptance criteria; canonical wording required |
| Later artifacts freezing reserved values | Medium | High | §16/§17 registers; G-5/G-6 gates; load-bearing-failure list in operator brief |
| Provenance contamination (accidental copying) | Low | High | PROV-3/4/5 clean-source rules; similarity review; refreeze triggers |

### 22.2 Assumptions

- [ASSUMPTION] Interview suppression was correct for this unattended node: the operator brief + accepted authority pre-answer all seven discovery phases, and the operator reviews this PRD before `/architect`. — If wrong, the operator rejects or adjusts specific sections during PRD review; no downstream artifact exists yet.
- [ASSUMPTION] The one-shot founder-approved WETH/USD conversions at deployment will land near the recorded USD-equivalent targets (≈$50/$10/$1/$1,000/$909.09/$1,909.09) under the intended comparator. — If market conditions make the targets unreasonable at deployment time, founders must re-confirm or amend FREEZE targets before deployment; this PRD does not authorize deviation.
- [ASSUMPTION] Canonical RH WETH facts (address `0x0Bd7…AD73`, YELLOW status, aeWETH implementation) remain as accepted on 2026-08-09. — If a change is discovered at deployment verification, the trust disclosure and possibly the authority set must be revisited before launch.

### 22.3 External dependencies

| dependency | nature | governing requirement |
|---|---|---|
| Robinhood Chain liveness | Runtime | FB-17 (delay, never reclassify) |
| Canonical RH WETH contract | Runtime interface (never vendored) | §13; PROV; FB-18 |
| Founder-approved WETH/USD reference at deployment | One-shot procedure | FR-1.4 |
| Heesho collaborator permission (recorded) | Provenance | PROV-2; LIC §6 (private recordkeeping) |
| Disclosed external startup/incubation runway (if used) | Operations funding | FR-9.4, FB-9/FB-12 |

---

## 23. Glossary

> **Sources**: SPEC §§2, 6, 10–14, 16–20; FREEZE §§3, 6–9

| term | definition |
|---|---|
| **KOTH** | King-of-the-Hill: the one-throne WETH-paid mining/TGE game |
| **King / Contender** | Current throne holder / prospective payer |
| **Epoch** | One reign; raw accrual eligible for at most 3,000 seconds at the UPS snapshotted at opening |
| **UPS** | VUX-per-second raw accrual rate; initial 4, halving ×8, tail 4/256 |
| **Qraw** | `min(elapsed, 3,000 s) × epochUPS` — maximum raw opportunity from time; never an entitlement |
| **VEM** | VUX Emission Model: `Qsafe = floor(D_R × S_pre / B_pre)`; `Qmint = min(Qraw, Qsafe)` |
| **D_R** | Exact realized WETH increase in the Hard Reserve caused by the current settlement, measured after arrival |
| **Qmint** | Actual VUX minted to the outgoing King by a completed settlement |
| **S / B / N** | `VUX.totalSupply()` (complete) / raw canonical RH WETH physically in the Hard Reserve / conceptual `B/S` |
| **S_MIN** | Permanent 1 raw VUX held by the Reserve; redemption floor for supply |
| **Hard Reserve** | Ownerless, immutable, non-pausable raw-WETH redemption reserve; the exit right |
| **Strategic Treasury** | First-class protocol-owned risk capital, separately custodied and accounted; receives the 12% leg |
| **T_nav** | Disclosed realizable Strategic NAV — analytics only; never `B`, never backing |
| **POL** | Protocol-owned VUX/WETH liquidity; a Strategic sleeve with frozen conduct rules |
| **VYRF (POL-special)** | Frozen fee policy: incremental VUX fees burn; incremental WETH fees → Hard; principal stays Strategic |
| **General waterfall** | Disclosed operator policy for qualifying non-POL realized revenue; percentages reserved |
| **LSG** | Liquid Signal Governance: bounded holder signal over marginal Strategic allocation among admitted Strategies; core mature capability, operator-activated |
| **Signaler** | Eligible VUX holder expressing LSG preferences (mature phase) |
| **Split dust** | `P − floor(80%P) − floor(12%P)` remainder beyond the nominal 8%; always to Hard |
| **Bootstrap** | One-time state: Reserve as genesis King, clock disabled, first takeover mints zero |
| **Tail** | Permanent 0.015625 VUX/s pilot-light rate after day 240 |
| **Dutch price** | Linear 3,000 s decay from opening to the immutable ≈$1 floor |
| **YELLOW (WETH)** | Accepted trust rating of canonical RH WETH: currently clean behavior, externally upgradeable |
| **Operator / risk authority** | Bounded human stewardship roles for Strategic capital; never Reserve/mint authority |
| **Raw opportunity** | Time-derived maximum (≈20.655M pre-tail); expires if unsupported or unsettled |

---

## 24. Appendix A — Frozen Parameter Table (Verbatim Carry)

> **Sources**: FREEZE §3 rows F-1…F-57, §6, §7; SPEC §§7, 10–14, 17. Values below are frozen founder authority; any later artifact must carry them unchanged.

| parameter | frozen value |
|---|---|
| Genesis POL VUX | exactly 150,000 VUX (`150,000 × 10^18` raw) |
| Hard Reserve seed | exactly 1 raw VUX unit |
| Genesis total supply `S0` | exactly `150,000 × 10^18 + 1` raw units |
| Genesis discretionary allocation | 0 VUX to every person/discretionary address |
| Post-genesis mint authority | KOTH/VEM settlement only, to the outgoing public King only |
| Ordinary routing | `king = floor(P×8,000/10,000)`; `strategic = floor(P×1,200/10,000)`; `reserve = P − king − strategic` (nominal ≥8% + all dust to Hard); 0% others; static |
| VEM | `Qsafe = floor(D_R × S_pre / B_pre)`; `Qmint = min(Qraw, Qsafe)`; `B_pre × Qmint ≤ D_R × S_pre`; issuance rounds down; required-contribution rounds up |
| Redemption | `payout = floor(B × q / S)` pre-redemption values; fee 0; Reserve-favoring rounding; `S_MIN = 1` raw VUX |
| EPOCH_PERIOD | 3,000 seconds |
| PRICE_MULTIPLIER | 2× (price ladder only) |
| Successor opening | `max(MINIMUM_OPENING, 2 × paid price)`; linear decay `price(t) = max(DECAY_FLOOR, opening × (1 − min(t,3,000)/3,000))` |
| BOOTSTRAP_OPENING / MINIMUM_OPENING / DECAY_FLOOR | ≈ $50 / ≈ $10 / ≈ $1 WETH-equivalent, each converted once pre-deployment |
| INITIAL_UPS | 4 VUX/second, snapshotted at epoch opening |
| Halvings | eight immutable 30-day halvings: days 30, 60, 90, 120, 150, 180, 210, 240 |
| Tail | `4/256 = 0.015625` VUX/s permanent (≤ 492,750 raw VUX/year) |
| Pre-tail cumulative raw opportunity | ≈ 20,655,000 VUX (opportunity, not target): 10,368,000 / 15,552,000 / 18,144,000 / 19,440,000 / 20,088,000 / 20,412,000 / 20,574,000 / 20,655,000 at each 30-day boundary |
| TGE framing | ≈ day 180 graduation; days 180–240 wind-down; day 240 formal tail |
| Bootstrap | Reserve = genesis King; clock disabled; `Qraw = 0`; first takeover ≈88%+ Hard / 12% Strategic / 0 mint |
| Genesis WETH | POL side ≈ $1,000; `B0 = P0 × S0 / 1.10` (≈ $909.09); total external ≈ $1,909.09; `P0/N0 = 1.10`; cushion `BOOTSTRAP_OPENING ≤ P0×S0 − B0`; one-shot conversion, no runtime oracle |
| POL VYRF | VUX fee yield → burn; WETH fee yield → Hard (one-way); returned LP principal → Strategic principal; bypasses general waterfall |
| Non-POL VUX revenue | normally burned unless later explicit founder authority establishes another justified treatment |
| Canonical WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` (Robinhood Chain; YELLOW disclosure mandatory) |
| Licence | GPL-3.0-or-later; default-deny source posture; three-file Miner allowlist @ `bcffbf1eb963810acb14a1fd1c73d03a53a085a8` |

---

## 25. Appendix B — Generation Evidence & Verification Trail

> **Sources**: this planning node's execution record; grimoires/loa/ledger.json; grimoires/loa/NOTES.md; MAP §2

| fact | value |
|---|---|
| Node | Fresh `/plan-and-analyze` (operator-dispatched, unattended); cycle-002 |
| Codebase state | GREENFIELD (src/, test/, script/ contain only `.gitkeep`) → `/ride` skipped per skill decision flow |
| Context dir | EMPTY (`grimoires/loa/context/` holds only `config_snapshot.json`); discovery corpus = operator node brief + `docs/authority/` accepted set |
| Beads | HEALTHY (no sprint tasks — correct for a PRD node) |
| System Zone integrity | sha256 verified, enforcement strict; single pre-existing Aleph inventory note (mount-time condition, not drift) |
| Stale PRD handling | Never read for content (4 header lines only, to satisfy write-tool mechanics); archived byte-identically (SHA-256 verified `bea5c8ab…3945`) via native ledger archive before this file was written |
| Interview | Suppressed per operator brief (all 7 phases pre-answered by accepted authority); confirmations deferred to operator PRD review per Karpathy #1 unattended-run rule |
| Flatline postlude | Not executed — `.loa.config.yaml` has no `flatline_protocol` section (auto-trigger unmet); manual option: `/flatline-review prd` |
| Traceability convention | FREEZE F-# = FREEZE §3 row #; SPEC §# = specification section; INV-# = SPEC §24 invariant; FB-# = §11 row (SPEC §25); LIC/REG/DELTA/REG-DELTA/MAP per §1.2 |

**Terminal state:** `PRD_READY_FOR_REVIEW`. Next authorized node: **operator PRD review** (then `/architect` only after acceptance). This document invokes nothing.
