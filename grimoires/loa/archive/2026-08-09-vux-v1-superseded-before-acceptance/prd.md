# Product Requirements Document: VUX v1

**Version:** 1.0.0
**Date:** 2026-08-09
**Author:** Loa `/plan-and-analyze` (discovering-requirements), cycle-001
**Status:** Review
**Terminal state:** `PRD_READY_FOR_REVIEW`

---

## Document Control & Binding Authority

This PRD derives the VUX v1 product requirements from the accepted founder/product/protocol authorities committed in this repository. It compresses those authorities into actionable, verifiable product requirements. It does not restate them in full, does not reopen frozen decisions, and cannot override them. Where this PRD and an authority disagree, the authority governs and this PRD must be corrected.

Authority precedence (newer and more specific governs overlap):

| Key | Document | Role |
|---|---|---|
| FREEZE | `docs/authority/vux-founder-parameter-freeze-2026-08.md` | Frozen founder parameters |
| SPEC | `docs/authority/vux-v1-canonical-specification-2026-08.md` | Canonical founder/product/protocol authority |
| LIC | `docs/authority/vux-v1-licence-provenance-source-pin-freeze-2026-08.md` | Licence, provenance, source-pin freeze |
| REG | `docs/authority/vux-v1-source-registry-2026-08.json` | Machine-readable source registry |
| TPN | `THIRD_PARTY_NOTICES.md` | Frozen provenance obligations |

Frozen values are requirements, not recommendations. This PRD offers no alternatives to them. Historical research under `docs/research/` is evidence only and cannot restore superseded requirements.

**What this PRD answers:** what VUX v1 must do, and what observable properties must be true for the product to be accepted.
**What this PRD must not answer:** how contracts are decomposed or implemented. That belongs to `/architect` (SDD) after this PRD is accepted.

> **Sources**: SPEC §1 (L7–21), SPEC §27 (L648–658); FREEZE §1 (L7–11), §9 (L126–129); LIC §1 (L9–24), §19 (L402–416); README.md (L15–26)

---

## Executive Summary

VUX v1 is a one-throne, WETH-paid King-of-the-Hill (KOTH) game whose permissionless mining process is the public VUX token-generation and distribution event (TGE). A participant takes the throne by paying its current Dutch-decayed price in canonical Robinhood Chain WETH. On an ordinary displacement, 80% of the payment recycles to the outgoing King and 20% becomes raw WETH backing in an ownerless Hard Reserve. The same settlement mints VUX to the outgoing King: elapsed reign time sets the maximum raw reward, and the VUX Emission Model (VEM) caps the actual mint at what the successor's realized Reserve contribution safely backs. Unsupported VUX is never created.

Every VUX unit holds an identical pro-rata claim on the Hard Reserve: burn `q` VUX, receive `floor(B × q / S)` canonical WETH, fee-free, where `S` is the complete total supply and `B` is the Reserve's raw WETH balance. Genesis is deliberately minimal and non-discretionary — 150,000 VUX of protocol-owned market inventory (POL), a permanent 1-raw-unit Reserve seed, and zero VUX for every user and discretionary address. No founder, investor, partner, treasury, airdrop, or public-sale allocation exists. After genesis, new VUX comes only from permissionless KOTH/VEM settlement; users may also buy existing VUX permissionlessly on the open market.

The product doctrine is four co-equal operational constraints: **FAIR** (equal public rules, no privileged allocation), **SIMPLE** (one throne, one payment asset, one backing asset, one split, one clock, one cap), **ELEGANT** (one successor payment compensates the outgoing King, adds backing, and funds safe issuance), and **SECURE** (Hard Reserve redemption integrity outranks every other concern and fails closed). This PRD makes those constraints, the frozen economics, the settlement truth, the failure behavior, the truthful mining UX, and the source/provenance boundary testable for the v1 release.

> **Sources**: SPEC §2 (L23–45), §3 (L47–83); FREEZE §2 (L13–17)

---

## Problem Statement

### The Problem

Token launches conventionally require trusting discretionary insiders: privileged genesis allocations, unbacked or oracle-driven emissions, treasuries with claims on user value, upgrade/recovery powers over reserves, and marketing that labels estimates as entitlements. There is no widely available launch shape in which distribution is fully permissionless from block one, every issued unit is provably backed at issuance time, and the reserve honoring redemption is credibly outside everyone's discretion — including the founders'.

### User Pain Points

- Genesis allocations dilute public participants before they can act (insider/VC/airdrop privilege).
- Emission schedules promise supply regardless of demand, creating unbacked inflation or "catch-up" mints.
- Reserves and treasuries carry owner, pause, sweep, migration, or governance powers that can impair redemption exactly when it matters.
- Mining/reward interfaces mislabel time-based estimates as "earned" or "claimable" balances.
- Backing claims conflate protocol-controlled promises with external infrastructure trust that users are never told about.

### Current State

Greenfield. No VUX contracts exist and no production deployment is authorized from this repository. The accepted authority set (FREEZE, SPEC, LIC/REG) is complete and frozen; this PRD is the first Loa lifecycle artifact derived from it.

### Desired State

A live VUX v1 where: mining is the entire public TGE under equal rules; genesis VUX exists only as canonical protocol-owned POL (150,000 VUX) and the permanent 1-raw-unit Reserve seed; every settlement mint is backed at or above the pre-settlement backing ratio; any holder can always redeem pro-rata, fee-free, against raw canonical WETH held by an ownerless, immutable Reserve; failures anywhere else cannot reach Reserve principal; and every user-facing mining number is labelled truthfully.

> **Sources**: SPEC §2 (L23–45), §3 (L51–83), §19 (L482–492); README.md (L8–13); FREEZE §2 (L13–17)

---

## Goals & Success Metrics

### Primary Goals

| ID | Goal | Measurement | Validation Method |
|----|------|-------------|-------------------|
| G-1 | **FAIR** — mining is the public TGE; genesis carries zero user/discretionary allocation; identical permissionless rules for all | Genesis holdings exactly {POL: 150,000 VUX; Reserve: 1 raw unit; all others: 0}; zero privileged mint/flow paths in code | Genesis-state assertions; settlement/mint path review; invariant tests INV-1..6, INV-22..23 |
| G-2 | **SIMPLE** — the user loop stays "take the throne, hold it, mine, get recycled WETH + safely settled VUX when displaced" | One throne, one payment asset, one backing asset, one ordinary split, one raw clock, one issuance cap; no new user-facing instrument or entitlement | PRD/SDD scope review; absence of carry/IOU/entitlement surfaces (INV-11) |
| G-3 | **ELEGANT** — one successor payment compensates the outgoing King, adds fresh backing, and funds safe issuance | Settlement realizes all three jobs from the single payment with no redundant monetary machinery | Settlement sequence tests (FR-9); scope review |
| G-4 | **SECURE** — Hard Reserve redemption integrity outranks mining, POL, Strategic activity, revenue, governance, and recovery convenience | Reserve surface has no owner/upgrade/pause/sweep/discretionary path; redemption independent of all other subsystems | Authority-boundary review (FR-2); failure-mode tests (NFR-REL-1); INV-15..21, 34..37 |
| G-5 | **Truthful mining UX** — no deceptive mining language anywhere in protocol data or periphery | Raw clock limit / "VUX if displaced now" / "VUX mined" kept distinct; prohibited labels absent | UX truth review against SPEC §18 (FR-13, NFR-COMP-3) |
| G-6 | **Finite, credible mined TGE** — 30-day halvings from 4 VUX/s, eight cuts, graduation ≈ day 180, formal `1/256` tail from day 240 | Schedule constants immutable; epoch snapshot semantics correct across boundaries | Schedule/clock tests (FR-6) |
| G-7 | **Provenance-clean implementation basis** — GPL-3.0-or-later posture with default-deny source policy | Only the three allowlisted Miner files (at the frozen pin) reused; clean-source surfaces original; notices preserved | Provenance gates in review/audit (NFR-COMP-1/2) |

### Key Performance Indicators (KPIs)

Pre-launch verification KPIs (baselines are N/A — greenfield):

| Metric | Target | Timeline | Goal ID |
|--------|--------|----------|---------|
| Invariant register coverage (Appendix A) | 37/37 with runnable checks | Before `/audit-sprint` approval of final sprint | G-1..G-4 |
| Settlement observability facts reconstructible by an external indexer | 10/10 per settlement | Implementation acceptance | G-3, G-5 |
| Failure-register outcomes with tests | 13/13 (Appendix A rows F-1..F-13) | Implementation acceptance | G-4 |
| Genesis-state assertions passing on deployment rehearsal | 100% | Deployment-readiness gate | G-1 |
| Provenance violations (non-allowlisted source, mutable pins, missing notices) | 0 | Every review/audit gate | G-7 |

### Constraints

- Frozen founder parameters (Appendix B) are carried verbatim; this PRD proposes no alternatives.
- USD-equivalent values are one-time pre-deployment conversion targets; **no runtime USD/oracle requirement may exist** (FREEZE conversion procedure; SPEC §6.2).
- v1 scope is deliberately narrow; the exclusion list (Scope & Prioritization) is a requirement, not a preference.
- The four doctrines are co-equal, but when recovery convenience conflicts with the hard redemption promise, the Hard Reserve fails closed (SPEC §3).

> **Sources**: SPEC §3 (L47–83), §22 (L539–595); FREEZE §3 (L19–54), §5 (L80–96); LIC §1 (L14–24)

---

## User Personas & Use Cases

### Primary Persona: Public Miner / King (Challenger)

**Profile:** Any permissionless address — human or bot; capital-advantaged actors and automation are expressly tolerated (FAIR promises equal rules, not equal outcomes).
**Goals:** Take the throne at an acceptable Dutch price; hold it to accrue clock time; be displaced profitably (recycle + settled VUX).
**Behaviors:** Watches current price and decay; may self-succeed; may compete aggressively for early high-UPS epochs.
**Pain points addressed:** No insider head start (bootstrap mints nothing and pays no one); reward rules identical for all; settlement outcome fully observable.

### Secondary Personas

| Persona | Description | Needs |
|---|---|---|
| VUX Holder / Redeemer | Holds VUX acquired by mining or market purchase | Always-available, fee-free pro-rata redemption at `floor(B × q / S)`; redemption independent of mining/POL/governance health |
| Market Participant | Buys/sells existing VUX permissionlessly via the canonical POL pool | Genesis price discovery (shallow by design); truthful supply analytics |
| Indexer / Frontend / Data Consumer | Builds explorers, dashboards, mining UIs | Canonical settlement records exposing the 10 settlement facts; quoting data with truth-preserving labels |
| Deployer / Protocol Operator (genesis only) | Executes the genesis deployment and one-time conversions | Deterministic deployment validation requirements; **no** ongoing privilege, allocation, or primary-flow share afterward |
| Robinhood Chain WETH authority (external trust actor) | Controls upgradeable canonical WETH infrastructure | Not a user. A disclosed YELLOW trust assumption VUX cannot constrain (NFR-TRUST-1) |

**Explicitly absent roles:** founder/team/investor/partner/airdrop/public-sale/treasury beneficiaries (no genesis allocation, no primary-flow share, no bootstrap privilege); LSG signalers (LSG inactive in v1).

### Use Cases

#### UC-1: Bootstrap activation (first public takeover)
**Actor:** Public Miner
**Preconditions:** Genesis deployed; ownerless Reserve is the unclocked bootstrap King; bootstrap Dutch price live (opening ≈ $50 WETH-equivalent converted pre-deployment).
**Flow:**
1. Miner pays the then-current bootstrap Dutch price in canonical WETH.
2. Settlement mints **zero** VUX regardless of how long bootstrap was open.
3. Both nominal legs (80% outgoing-King + 20% Reserve) terminate at the Reserve — the entire payment becomes Hard Reserve backing.
4. Payer becomes the first public King; their 3,000-second epoch opens at the then-current schedule UPS.
**Postconditions:** First public mining epoch running; next opening governed by `max(MINIMUM_OPENING, 2 × paid price)`.
**Acceptance Criteria:**
- [ ] Bootstrap settlement mints 0 VUX and pays no human or discretionary address.
- [ ] Reserve balance increases by exactly the full activation payment.
- [ ] First public epoch records start time and snapshotted UPS.

#### UC-2: Ordinary paid displacement
**Actor:** Public Miner (incoming) vs. current King (outgoing)
**Preconditions:** A public King holds the throne; Dutch price is live.
**Flow:** Incoming pays the fixed takeover price → 80/20 split realized (Reserve leg first-class and measured) → outgoing epoch's `Qraw` established → VEM computes `Qmint` → exactly `Qmint` minted to outgoing King → exact 80% recycle paid to outgoing King → incoming King's fresh epoch opens.
**Postconditions:** All effects settled atomically; settlement record exposes the 10 canonical facts.
**Acceptance Criteria:**
- [ ] The two legs sum to the entire payment; the Reserve receives any integer-division remainder.
- [ ] `Qmint = min(Qraw, floor(D × S_pre / B_pre))` using pre-settlement state and exact realized `D`.
- [ ] Failure anywhere reverts the whole settlement (no partial state).

#### UC-3: Hold the throne / mine
**Actor:** Current King
**Flow:** Clock accrues eligible time up to 3,000 seconds at the epoch-open snapshotted UPS; periphery shows raw clock limit and estimated "VUX if displaced now."
**Acceptance Criteria:**
- [ ] Accrual stops at 3,000 eligible seconds; no further growth while undisplaced.
- [ ] Estimates are labelled as estimates and may decrease (see User Experience).

#### UC-4: Redemption
**Actor:** VUX Holder
**Flow:** Holder burns `q` VUX → receives `floor(B × q / S)` canonical WETH atomically, fee 0, using pre-redemption `B` and `S`.
**Acceptance Criteria:**
- [ ] Rounding favors the Reserve; backing per remaining VUX never decreases from a redemption.
- [ ] Redemption may not reduce total supply below `S_MIN = 1` raw unit; every externally held VUX unit remains redeemable.
- [ ] Redemption functions with mining halted, POL dead, Strategic losses, zero revenue, and LSG absent.

#### UC-5: Market acquisition
**Actor:** Market Participant
**Flow:** Buys existing VUX from the canonical POL pool or any holder; no protocol privilege, mint, or accounting change (`S` unchanged by transfers).
**Acceptance Criteria:**
- [ ] Secondary-market price never enters VEM or redemption arithmetic.

#### UC-6: Observe and index settlement
**Actor:** Indexer / Frontend
**Flow:** For each settlement, reads canonical records to reconstruct: outgoing epoch; outgoing King; incoming King; paid price; recycle amount; `D`; `B_pre`; `S_pre`; `Qraw`; actual `Qmint`.
**Acceptance Criteria:**
- [ ] All 10 facts distinguishable from settlement records without reconstructing entitlements from mutable state.

> **Sources**: SPEC §2 (L23–45), §9 (L229–245), §14 (L365–384), §15 (L386–405), §18 (L456–480), §19 (L482–492), §21 (L517–537); FREEZE §3 rows 16–20, 26 (L38–48), §6 (L98–102)

---

## Functional Requirements

All functional requirements are **Must Have (P0)**: canonical v1 is already the minimum surface (SPEC §4), and no requirement below is optional for acceptance. IDs are stable for SDD/sprint traceability. "Immutable" below states a required product outcome (no authority can change the behavior post-genesis); the enforcement mechanism is SDD territory.

### FR-1: VUX token and complete supply accounting
**Description:** An 18-decimal VUX token whose `totalSupply()` is the single monetary supply `S`, with the exact genesis mint and a single immutable post-genesis mint path.
**Acceptance Criteria:**
- [ ] Genesis mints exactly `150,000 × 10^18` raw units to canonical protocol-owned POL and `1` raw unit to the Hard Reserve; `totalSupply() = 150,000 × 10^18 + 1` after genesis and before public mining; every user and discretionary address (founder, apDAO, partner, investor, airdrop/community, public-sale, treasury, other) holds 0.
- [ ] After genesis, new VUX can be created **only** by the immutable authorized KOTH/VEM settlement path; the recipient is only the outgoing public King being settled; the amount is exactly the FR-7/FR-9 settlement result.
- [ ] No treasury, governance, POL, Reserve, operator, migration, airdrop, recovery, or future-product mint path exists; no post-genesis free mint exists.
- [ ] `S` counts every VUX unit without exclusion (POL-held, Strategic-held, Reserve seed, mined, protocol-held); "circulating supply" has no monetary role.
- [ ] Supply decreases only via redemption burns, direct holder burns, and burns of incremental VUX-denominated revenue; transfers and POL movements never change `S`.
- [ ] The mint authority handoff is exact and immutable; there is deliberately no recovery minter (a Rig failure may permanently stop new issuance).
**Dependencies:** FR-7, FR-9 (mint amount); FR-14 (genesis assertions).

> **Sources**: SPEC §5 (L119–128), §6.1 (L130–152), §7 (L182–197), §22 INV-1..6, 11, 13 (L547–559); FREEZE §3 rows 1–3 (L23–25), §4 (L56–65)

### FR-2: Hard Reserve custody and authority boundary
**Description:** An ownerless Hard Reserve holding only raw canonical Robinhood Chain WETH, defining `B`, with no discretionary surface of any kind.
**Acceptance Criteria:**
- [ ] `B` equals exactly `canonicalWETH.balanceOf(HardReserve)`; POL WETH, Strategic WETH, expected revenue, unreceived fees, claims, credit, LP value, and marked assets never enter `B`.
- [ ] The VUX-controlled Reserve surface is ownerless; immutable/non-upgradeable; non-pausable; without arbitrary calls; without arbitrary token approvals; without sweep; without migration/successor authority; without discretionary principal movement.
- [ ] Ordinary principal outflow is holder redemption only (FR-3); WETH received becomes backing permanently and is never reclassified as Strategic capital or revenue working capital.
- [ ] No v1 recovery power, emergency path, or future mechanism can weaken this boundary; failures elsewhere create no claim on Reserve principal.
- [ ] The Reserve is not a treasury, yield strategy, POL manager, governance executor, operational wallet, or migration staging area.
**Dependencies:** External canonical RH WETH (NFR-TRUST-1).

> **Sources**: SPEC §5 (L119–128), §8 (L199–227), §22 INV-15..16, 21, 35–36 (L564–570, L593–594); FREEZE §2 (L15–17)

### FR-3: Fee-free pro-rata redemption
**Description:** Any holder burns `q` VUX and atomically receives `floor(B × q / S)` canonical WETH at zero fee, computed from pre-redemption state.
**Acceptance Criteria:**
- [ ] When a holder redeems `q` VUX, the system shall burn exactly `q`, pay exactly `floor(B × q / S)` WETH using `S = totalSupply()` and `B = canonicalWETH.balanceOf(Reserve)` immediately before the redemption, charge fee = 0, and settle atomically.
- [ ] Rounding favors the Reserve; a redemption never decreases backing per remaining VUX.
- [ ] A redemption may not reduce total supply below `S_MIN = 1` raw unit, which the ownerless Reserve retains permanently; every externally held VUX unit is redeemable, and full external redemption leaves `S = S_MIN` with a positive WETH remainder — the monetary denominator stays live with no owner, reset, or recapitalization.
- [ ] Redemption depends on no other subsystem: it functions with mining/Rig failed, POL impaired, Strategic losses, revenue absent, and LSG absent (subject only to the chain and backing asset functioning).
- [ ] AMM price, POL balances, Strategic assets, and external valuations never enter the redemption calculation.
- [ ] Protocol-owned POL VUX is never redeemed against the Hard Reserve as a treasury-management operation (a protocol-conduct rule; it does not restrict the fungible claim of a user who acquired VUX on the market).
**Dependencies:** FR-1 (burn), FR-2 (custody).

> **Sources**: SPEC §2 (L29), §8 (L214–227), §22 INV-17..20, 30 (L566–569, L585); FREEZE §3 row 21 (L43)

### FR-4: KOTH throne and ordinary split
**Description:** One canonical throne; an ordinary paid displacement routes the entire payment 80% to the outgoing King and 20% to the Hard Reserve, with zero to every other primary recipient.
**Acceptance Criteria:**
- [ ] Exactly one throne exists in v1.
- [ ] When an ordinary displacement settles, the system shall route 80% of the payment to the outgoing King and 20% to the Hard Reserve, with the 80% leg rounded down where division is inexact and the remainder going to the Reserve; the two legs sum to the entire payment.
- [ ] 0% flows to founder, team, developer, operator, signaler, treasury, or any other primary recipient — no privileged party exists in bootstrap or primary flows.
- [ ] The outgoing King receives the recycle and the settled VUX reward (FR-7); the incoming King receives only the throne and a fresh epoch.
**Dependencies:** FR-5 (price), FR-9 (sequence).

> **Sources**: SPEC §9 (L229–245), §22 INV-22..23 (L574–575); FREEZE §2 (L17), §3 row 26 (L48)

### FR-5: Dutch takeover pricing
**Description:** Linear Dutch price decay per epoch with immutable frozen parameters and a positive floor.
**Acceptance Criteria:**
- [ ] Frozen parameters carried exactly: `EPOCH_PERIOD = 3,000 s`; `PRICE_MULTIPLIER = 2×`; bootstrap opening ≈ $50, minimum opening ≈ $10, decay floor ≈ $1 — each USD target converted **once** pre-deployment into immutable WETH constants (FR-14); no runtime USD logic.
- [ ] An ordinary successor epoch opens at `max(MINIMUM_OPENING, 2 × paid takeover price)`; the bootstrap opening is set separately and not derived from any predecessor payment.
- [ ] The reference price decays linearly from the opening toward zero over 3,000 seconds, clipped at the immutable positive floor: `price(t) = max(DECAY_FLOOR, opening × (1 − min(t, 3000)/3000))`; after reaching the floor the takeover price remains at the floor until displacement.
- [ ] The floor is a dust/restart and paid-handoff rule only — not an issuance guarantee, oracle price, dynamic backing floor, or preservation of a prior settlement quote.
- [ ] The 2× multiplier is a takeover price-ladder multiplier, never a mining-reward multiplier.
**Dependencies:** FR-14 (one-time conversions).

> **Sources**: SPEC §10 (L247–273); FREEZE §3 rows 9–10, 18–20 (L31–32, L40–42)

### FR-6: Mining clock and mined-TGE schedule
**Description:** Time-based raw accrual per public epoch, on an immutable halving schedule with a permanent pilot-light tail.
**Acceptance Criteria:**
- [ ] Each public epoch records its start time and the UPS rate in force at epoch open, and accrues no more than 3,000 seconds of eligible raw time: `Qraw = min(elapsed, 3000) × epochUPS`.
- [ ] `Qraw` is a maximum time-derived opportunity — never owned, earned, claimable, guaranteed, or protocol debt; unused or unsupported raw opportunity expires with no carry, IOU, makeup, or revival.
- [ ] The deployment sets one immutable schedule-start timestamp; UPS follows the frozen schedule: 4 VUX/s (day 0–30), 2 (30–60), 1 (60–90), 0.5 (90–120), 0.25 (120–150), 0.125 (150–180), 0.0625 (180–210), 0.03125 (210–240), and `INITIAL_UPS/256 = 0.015625` VUX/s permanently from day 240 (the tail; maximum 492,750 raw VUX/year).
- [ ] Epochs snapshot the then-current rate at open; a halving boundary never retroactively re-rates an open epoch; a reign crossing boundaries still accrues only its snapshotted rate for at most 3,000 eligible seconds.
- [ ] The bootstrap King has no clock (`Qraw = 0`) — mining begins only when a public participant becomes King.
- [ ] Cumulative pre-tail raw opportunity (20.655M VUX) is a ceiling, never promised issuance; graduation (~day 180) and tail start (day 240) are schedule facts and communications milestones, not on-chain mechanisms.
**Dependencies:** FR-8 (bootstrap), FR-14 (schedule-start reserved to deployment).

> **Sources**: SPEC §11 (L275–308), §22 INV-11..12 (L557–558); FREEZE §3 rows 9, 11–15, 17, 22–23 (L31–45), §5 (L80–96)

### FR-7: VEM safe-issuance cap
**Description:** The monetary safety rule capping every settlement mint at the amount the realized fresh backing supports.
**Acceptance Criteria:**
- [ ] For an ordinary settlement, with `B_pre` = Reserve WETH before the current contribution, `S_pre` = totalSupply before the current issuance, and `D` = the exact measured fresh WETH added to the Reserve by this settlement: `Qsafe = floor(D × S_pre / B_pre)` and `Qmint = min(Qraw, Qsafe)`.
- [ ] The defining invariant holds for every mint: `B_pre × Qmint ≤ D × S_pre` (equivalently `(B_pre + D)/(S_pre + Qmint) ≥ B_pre/S_pre`) — new issuance never reduces backing per VUX; equality at the frontier permits the full amount.
- [ ] `D` is the Reserve's exact realized balance increase attributable to the current ordinary settlement — never an assumed percentage, quoted value, AMM price, oracle valuation, or later deposit; issuance may depend on the contribution only after it has reached the Reserve and been measured.
- [ ] Issuance rounds down; any required-backing calculation rounds up; monetary rounding never crosses the safe frontier.
- [ ] If the clock advertises more than the payment safely funds, only `Qsafe` mints and the unsupported remainder ceases to exist — no carry, IOU, debt, makeup mint, entitlement ledger, high-water mark, or oracle-priced issuance.
- [ ] When `Qsafe > Qraw`, only `Qraw` mints; the excess contribution stays in the Reserve and raises backing per VUX ("greed capitalizes VUX through the existing 20% leg" — no extra greed tax). Secondary-market premiums are not captured and never alter VEM arithmetic.
- [ ] Arithmetic is mathematically equivalent full-precision, overflow-safe computation that does not rely on overflowing 256-bit cross-products. **The implementation library/mechanics are deliberately not chosen here — the SDD must choose and pin them.**
**Dependencies:** FR-9 (ordering: contribution before issuance).

> **Sources**: SPEC §12 (L310–347), §13 (L349–363), §22 INV-7..10, 14 (L553–556, L560); FREEZE §2 (L17); LIC §8 (L191–203)

### FR-8: Ownerless bootstrap state
**Description:** A distinct one-time state in which the ownerless Reserve is the unclocked outgoing King.
**Acceptance Criteria:**
- [ ] Bootstrap state: outgoing King = ownerless Hard Reserve; mining clock disabled; `Qraw = 0`.
- [ ] The first public paid takeover: is permissionless at the then-current bootstrap Dutch price; mints exactly 0 VUX regardless of bootstrap duration; makes the payer the first public King; opens that King's epoch at the schedule rate then in force.
- [ ] Both nominal legs of the activation payment terminate at the ownerless Reserve, so the entire payment becomes Hard Reserve backing.
- [ ] No person or discretionary address receives bootstrap WETH, bootstrap VUX, a free clock, or a privileged first reign.
**Dependencies:** FR-4, FR-5, FR-14 (bootstrap opening constant).

> **Sources**: SPEC §14 (L365–384), §22 INV-13, 26 (L559, L578); FREEZE §3 rows 16–18 (L38–40), §6 (L98–102)

### FR-9: Settlement truth — sequence and atomicity
**Description:** The canonical observable economic sequence every ordinary displacement must realize, atomically.
**Acceptance Criteria:**
- [ ] Every ordinary displacement realizes, in effect: (1) outgoing epoch and King identified; (2) takeover price fixed for the transaction; (3) pre-settlement `B_pre` and `S_pre` established before contribution or issuance; (4) `Qraw` established from the outgoing epoch's start, snapshotted UPS, and 3,000 s cap; (5) exact successor WETH collected; (6) complete 80/20 split realized with the Reserve contribution paid before issuance depends on it; (7) exact realized `D` measured, with mismatch rejected; (8) `Qmint` determined under VEM; (9) exactly `Qmint` minted to the outgoing King; (10) exactly the 80% recycle paid to the outgoing King; (11) successor epoch opened with the then-current snapshotted rate and required opening price; (12) all authorized state, payment, backing, and issuance effects settle atomically or none do.
- [ ] The outgoing epoch and outgoing King determine `Qraw` and the mint recipient; successor state cannot rewrite them.
- [ ] The exact software call graph and checks-effects-interactions decomposition are **not** fixed here — they belong to the SDD; this PRD fixes the economic result, ordering dependencies, atomicity, and observable facts.
**Dependencies:** FR-4..FR-8.

> **Sources**: SPEC §15 (L386–405), §22 INV-24..25 (L576–577)

### FR-10: Settlement observability
**Description:** Canonical settlement records sufficient for external reconstruction of every settlement outcome.
**Acceptance Criteria:**
- [ ] For every settlement, records expose at least: outgoing epoch; outgoing King; incoming King; paid price; recycle amount; realized `D`; `B_pre`; `S_pre`; `Qraw`; actual `Qmint` — distinguishable by a user or indexer without reconstructing an entitlement from mutable state.
- [ ] Records are sufficient to explain why `Qmint` differed from `Qraw` (clock-bound vs. VEM-bound) for any settlement.
- [ ] Exact event/record encoding is SDD territory; the observable fact set above is the product requirement.
**Dependencies:** FR-9.

> **Sources**: SPEC §15 (L403–405), §18 (L474–480)

### FR-11: Canonical genesis POL
**Description:** One canonical protocol-owned VUX/WETH liquidity position from genesis, deliberately shallow, classified as Strategic capital.
**Acceptance Criteria:**
- [ ] Genesis POL: VUX side exactly 150,000 VUX; WETH side ≈ $1,000 USD-equivalent (one-time pre-deployment conversion); initialized so `P0/N0 = 1.10` (verified against actual token ordering, decimals, ticks, and rounding — FR-14).
- [ ] Posture is intentionally shallow, simple, and passive/wide where practicable — sufficient for price discovery, not capitalized for mercenary extraction; **no automatic deepening rule exists in v1**.
- [ ] POL is Strategic, never backing: POL WETH never enters `B`; POL VUX always remains inside `S`; Reserve principal never funds POL; no post-genesis VUX mint exists for POL; later POL VUX must be existing or market-purchased VUX; returned LP principal remains Strategic principal (not revenue); protocol-owned POL VUX is never redeemed against the Reserve as treasury management.
- [ ] Trading/POL failure may impair price discovery but cannot change Reserve accounting or the redemption formula.
- [ ] AMM venue, pool type, range, fee tier, ticks, and fee ownership are **reserved** (Appendix C) — the accepted authority does not choose them and neither does this PRD.
**Dependencies:** FR-14 (conversion, `P0/N0` validation).

> **Sources**: SPEC §16 (L407–439), §22 INV-27..31 (L582–586); FREEZE §3 rows 1, 4–8, 24 (L23–30, L46)

### FR-12: Revenue classification and routing
**Description:** Minimal, source-determined revenue policy; v1 assumes revenue may be zero.
**Acceptance Criteria:**
- [ ] If incremental protocol revenue exists: incremental VUX revenue → burn; incremental WETH revenue → Hard Reserve. Source determines classification.
- [ ] Returned POL principal is Strategic principal, never relabelable as revenue; VUX received as incremental revenue is burned (never held, LP'd, redeemed, or recycled); WETH inside the Reserve is principal and never becomes revenue working capital.
- [ ] v1 functions correctly with zero or negligible revenue; no WETH buyback, oracle-based buyback, Reserve-funded buyback, or complex YRF exists.
**Dependencies:** FR-2 (Reserve), FR-1 (burn).

> **Sources**: SPEC §17 (L441–454), §22 INV-31..32 (L586–587)

### FR-13: Read-only quoting/periphery and mining data
**Description:** Truth-preserving read-only surfaces for mining UX and analytics.
**Acceptance Criteria:**
- [ ] Periphery/read surfaces report at least: current epoch (and King), current Dutch price, raw clock limit (elapsed-eligible × snapshotted UPS), and estimated "VUX if displaced now" under current conditions — without turning any estimate into an entitlement.
- [ ] Data distinctions required by the UX truth rules (see User Experience) are supported: raw clock limit ≠ displaced-now estimate ≠ actually mined; analytics can distinguish genesis POL inventory, current total supply, cumulative raw opportunity, actual settlement mints, burns, and redemption burns.
- [ ] Periphery is read-only with respect to monetary state; a bespoke on-chain module is not required if equivalent truthful read paths exist (SDD decides placement).
**Dependencies:** FR-6, FR-9, FR-10.

> **Sources**: SPEC §4 (L97–99), §5 (L117), §18 (L456–480)

### FR-14: Genesis deployment outcomes and validation
**Description:** Required outcomes and validations that bind the (later) deployment node; deployment itself is outside this PRD's mutation scope.
**Acceptance Criteria:**
- [ ] Immediately before deployment, one founder-approved WETH/USD reference price with source and timestamp is recorded, and the four USD targets (POL WETH side ≈ $1,000; bootstrap opening ≈ $50; minimum opening ≈ $10; decay floor ≈ $1) are converted **once** into immutable WETH amounts, with all rounding documented. No USD oracle, refresh rule, or historical research constant (e.g. $1,625/WETH) may be embedded.
- [ ] `B0` (Hard Reserve seed WETH, economic target ≈ $909.09) is derived from the actual initialized pool state to satisfy `P0/N0 = 1.10`, i.e. `B0 = P0 × S0 / 1.10`, verified after token ordering, decimals, ticks, and rounding; deposited as raw canonical RH WETH only.
- [ ] Deployment validation establishes `BOOTSTRAP_OPENING ≤ P0 × S0 − B0` (even a maximal bootstrap payment cannot lift backing per VUX above the initialized pool price).
- [ ] Maximum external genesis deployment is exactly the approved `W_POL + B0` (economic target ≈ $1,909.09); remaining project/apDAO capital stays Strategic and undeployed at genesis; the resulting WETH accounting is published.
- [ ] Post-genesis assertions pass: exact total supply (FR-1); exact genesis holdings; LSG inactive; founder/operator genesis compensation = none; bootstrap state armed (FR-8).
- [ ] The exact conversion source/timestamp, converted constants, final `B0`, schedule-start timestamp, addresses, and block/tx records are **reserved deployment facts** (Appendix C) — required to exist and satisfy the constraints above, not chosen here.
**Dependencies:** FR-1, FR-2, FR-5, FR-8, FR-11.

> **Sources**: FREEZE §3 rows 4–8, 25–26 + conversion procedure (L26–30, L47–48, L52–54), §4 (L56–78), §7 (L104–111); SPEC §6 (L130–180), §22 preamble (L543), §24 (L617–632)

---

## Non-Functional Requirements

### Security

- **NFR-SEC-1 — Reserve boundary by construction:** The Hard Reserve authority boundary (FR-2) is a security property, not an operational policy: no owner, upgrade, pause, arbitrary call/approval, sweep, migration, or discretionary principal path may exist in any code path, and no recovery power may be added to "fix" failures elsewhere. Failures outside the Reserve must be structurally incapable of creating a claim on Reserve principal.
- **NFR-SEC-2 — Mint authority immutability:** Post-genesis mint capability exists solely on the immutable authorized settlement path (FR-1); its absence of an admin/recovery minter is deliberate and permanent.
- **NFR-SEC-3 — Atomicity:** Settlement (FR-9) and redemption (FR-3) are all-or-nothing; no partial economic effect is ever observable.
- **NFR-SEC-4 — Monetary arithmetic:** All supply, VEM, split, and redemption arithmetic is full-precision and overflow-safe; payouts and issuance round down, required contributions round up, and rounding never crosses the VEM frontier or reduces backing per remaining VUX. (Library selection and overflow mechanics: SDD.)
- **NFR-SEC-5 — Manipulation independence:** No oracle inputs exist; AMM state, secondary-market price, shallow-pool manipulation, and external valuations cannot enter VEM, redemption, pricing-floor, or supply arithmetic.

> **Sources**: SPEC §22 INV-14, 16, 24, 33–36 (L560, L565, L576, L588–594), §12 (L327–329), §8 (L219–223); FREEZE §2 (L15–17)

### Reliability (fail-closed behavior)

- **NFR-REL-1 — Failure register:** Each accepted failure condition has a required, testable outcome (F-1..F-13, Appendix A part 2). Highlights: Rig/mining failure may permanently halt new mining but must not intentionally disable redemption; no challenger ⇒ no settlement and no VUX owed; weak demand ⇒ less issuance, never catch-up emission; aggressive bidding ⇒ more backing, never emission above the clock; tail dormancy is not a solvency failure; POL failure impairs trading only; Strategic losses stay Strategic; LSG absence/failure cannot impair v1; secondary price cannot alter VEM/redemption arithmetic; large redemptions stay pro-rata and preserve the monetary floor (`S_MIN`, non-decreasing `B/S`); no emergency authority may weaken the ownerless Reserve.
- **NFR-REL-2 — Redemption liveness independence:** Redemption remains available whenever the chain and the backing asset function, regardless of every other subsystem's state.

> **Sources**: SPEC §23 (L597–615), §22 INV-18, 34–36 (L567, L592–594)

### External trust disclosure

- **NFR-TRUST-1 — Canonical RH WETH (YELLOW) disclosure:** The backing asset is canonical Robinhood Chain WETH (`0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73`), whose token/gateway/router infrastructure is externally upgradeable (7-of-8 authority with a no-delay path). VUX must never describe the complete backing stack as trustless, immutable, or governance-free. All materials distinguishing claims must separate (a) the VUX-controlled Reserve's designed immutability from (b) the external RH WETH governance/upgrade trust assumption. The canonical disclosure, required in substance wherever backing immutability is described: *"The VUX Hard Reserve contract is designed to be immutable and ownerless. Its backing asset is canonical Robinhood Chain WETH, which retains an external Robinhood Chain governance and upgrade trust assumption."* Ordinary RH Chain availability failures are distinct: they delay execution without changing recorded balances.

> **Sources**: SPEC §21 (L517–537), §22 INV-37 (L595), §23 (L613–615); REG `external_runtime_interfaces` (L294–301)

### Compliance — licence and provenance

- **NFR-COMP-1 — Licence posture:** Project licence `GPL-3.0-or-later` (root `LICENSE` = unmodified GPLv3 text; never bare "GPL-3.0" or `-only`). Per-file SPDX policy per LIC §15: VUX-original files written from SPEC → `GPL-3.0-or-later`; files materially derived from Miner `Rig.sol`/`Unit.sol`/`IUnit.sol` → `MIT AND GPL-3.0-or-later` with Miner (and, for Rig, Euler) provenance and dated modification notices; byte-identical allowlisted files retain `MIT`; third-party dependency files keep their upstream headers verbatim. No invented copyright holder, ever.
- **NFR-COMP-2 — Source provenance (default deny):** Only `Heesho/miner-manifold@bcffbf1eb963810acb14a1fd1c73d03a53a085a8` files `contracts/Rig.sol`, `contracts/Unit.sol`, `contracts/interfaces/IUnit.sol` are cleared for direct v1 reuse; Rig's auction skeleton is conservatively treated as Euler FeeFlow-descended (`GPL-2.0-or-later`, GPLv3 selected; evidence pin `euler-xyz/fee-flow@3bee858a…`). Hard Reserve, VEM, revenue routing, and quoting/periphery are **VUX-original** implementations from SPEC — they must not start from gumball/Fund, Olympus, LSG, or any non-allowlisted source. Prohibited (LIC §16): copying any Miner file outside the allowlist; Miner/LSG `Strategy.sol`, `Hopper.sol`, `Router.sol`, `Multicall.sol`, `IRig.sol`, upstream tests; LSG voting/bribe/governance files; gumball6900 code; give.fun code; Olympus code or docs prose; mutable refs (`main`/`HEAD`/`latest`/unresolved tags) as source authority; whole-repo vendoring; notice erasure or superficial rewrites to dodge copyleft. Implementation must fail review/build if an upstream URL is mutable, a SHA is not 40 hex chars, a non-allowlisted upstream file appears, a required notice is absent, or a dependency lacks an immutable pin. Pin changes require an explicit provenance delta with operator approval (LIC §17). If review finds material similarity between a "clean-source" file and a prohibited ancestor (e.g. Fund.sol), the file is reclassified as derived and re-cleared before merge.
- **NFR-COMP-3 — Truthful public claims (FAIR discipline):** The only correct genesis claim: *"No user received VUX at genesis. Every user-owned VUX was mined under the same public KOTH/VEM rules or purchased from existing supply in the open market."* Never claim that every user-owned VUX was personally mined by that user. Never claim broad distribution, anti-whale behavior, or equal outcomes without live evidence; FAIR promises equal public rules and absence of privileged allocation — not equal outcomes, broad ownership, equal gas access, or resistance to automation. Raw-opportunity figures (e.g. 20.655M) are ceilings, never promised supply. Emission graduation (~day 180) is described as graduation, not as "supply fully issued."

> **Sources**: LIC §1–§2 (L9–43), §5 (L97–121), §15 (L324–338), §16 (L340–357), §17 (L359–372), §19 (L402–416); REG (L4–12, L213–268); TPN §1–§6; SPEC §19 (L482–492); FREEZE §3 row 22 (L44)

### Performance / Scalability

No performance or scalability targets are imposed by the accepted authorities beyond ordinary single-chain contract execution; none are invented here. Gas-efficiency choices are SDD/implementation territory and must never trade away any invariant above.

> **Sources**: SPEC §4 (L84–103) — absence of any performance requirement in the authority set

---

## User Experience

VUX v1's UX surface is small but truth-critical. The three mining concepts below must remain distinct in every protocol-adjacent surface (periphery, frontend, analytics, documentation, marketing).

### Key User Flows

#### Flow 1: Mine
```
See price → Pay takeover (become King) → Clock accrues (≤ 3,000 s at snapshotted UPS)
→ Displaced by next King → Receive 80% recycle + exactly Qmint VUX
```

#### Flow 2: Redeem
```
Hold q VUX → Burn q → Receive floor(B × q / S) WETH (fee 0, atomic)
```

#### Flow 3: Observe
```
Read settlement record → Reconstruct all 10 facts → Explain Qmint vs Qraw
```

### Mining language truth rules (binding)

| Concept | Canonical label | May show | Must NEVER be labelled |
|---|---|---|---|
| Clock progress | **raw clock limit** / **maximum from time** | monotone eligible elapsed time (≤3,000 s), snapshotted rate, time-derived maximum | mined, earned, claimable, owned, guaranteed, owed |
| Current estimate | **VUX if displaced now** | estimated settlement amount under current price/Reserve/supply/contribution; may rise before the clock/cap crossover, fall with Dutch decay, plateau at the floor, or fall as backing rises; may differ across blocks | claimable, earned, already mined |
| Settled reality | **VUX mined / earned** | only VUX actually minted by completed settlement (canonical records) | — (this is the only place "mined/earned" is allowed) |

Canonical explanation (verbatim substance, required wherever mining is explained):

> You mine while you hold the throne. The clock sets the maximum reward. Your exact VUX is settled when the next King pays, and only the amount safely backed by that payment is minted.

### Interaction Patterns

- Estimates are explicitly revocable-downward: UI must not freeze or "lock in" a displaced-now quote.
- Analytics must distinguish: genesis POL inventory, current total supply, cumulative raw opportunity, actual settlement mints, burns, redemption burns.
- Backing claims always carry the NFR-TRUST-1 disclosure in substance.

### Accessibility Requirements

The accepted authorities impose none; frontend accessibility standards are a later product decision and are not invented here.

> **Sources**: SPEC §18 (L456–480), §13 (L359–363), §21 (L533–535); FREEZE §5 (L96)

---

## Technical Considerations

### Architecture Notes (boundary only — decomposition is SDD territory)

The canonical conceptual surfaces (SPEC §5): VUX token; Hard Reserve + redemption; KOTH/Rig + VEM; bootstrap state; canonical POL; read-only periphery. These are **conceptual responsibilities, not a contract count**: VEM may be inline Rig policy; revenue routing need not be a separate facility; quoting needs no bespoke on-chain module if truthful read paths exist. Canonical monetary quantities: `S = VUX.totalSupply()`, `B = canonicalWETH.balanceOf(Reserve)`, `N = B/S` (conceptual). This PRD fixes observable outcomes and invariants; `/architect` owns decomposition, call graphs, checks-effects-interactions, and event encodings.

### Integrations

| System | Integration Type | Purpose / Constraint |
|--------|------------------|----------------------|
| Canonical RH WETH (`0x0Bd7…AD73`) | External deployed runtime contract via cleared interface | Payment + backing asset. Never vendored/copied; YELLOW trust disclosure required (NFR-TRUST-1) |
| AMM venue (unselected) | Canonical genesis POL pool | Venue/pool type/fee/range **reserved** (Appendix C); must preserve FR-11 posture |
| OpenZeppelin Contracts | Dependency family (MIT), cleared | **No release selected.** SDD must pin an exact immutable release/digest, record imported paths, and preserve notices **before** coding. Ancestor lockfile (4.9.6) and research mentions (5.6.1) are not decisions |

### Dependencies

- Robinhood Chain liveness (execution-delay risk only; balances unaffected).
- Canonical RH WETH behavioral continuity (accepted YELLOW external trust assumption).
- No oracle, keeper, governance, LSG, or revenue dependency exists in v1.

### Technical Constraints

- Toolchain/Solidity version, arithmetic library, AMM venue, pool geometry, contract count, and deployment architecture are **not chosen in this PRD**; the SDD must select and immutably pin implementation dependencies before code is written (LIC §13, §17, §19.6).
- Source reuse is constrained by NFR-COMP-2 (default deny; three-file allowlist at the frozen pin; conservative Euler lineage on Rig-derived auction portions).
- No System Zone (`.claude/`) modifications are authorized by this cycle.
- Unit.sol feature selection (e.g. retention of permit/votes extensions) is an SDD decision inside the allowlisted lineage.

> **Sources**: SPEC §4 (L84–103), §5 (L105–128), §24 (L617–632); LIC §13 (L280–306), §17 (L359–372), §19 (L402–416); REG `dependency_families` (L270–293), `external_runtime_interfaces` (L294–301)

---

## Scope & Prioritization

### In Scope (v1)

- VUX token and complete total-supply accounting (FR-1)
- Raw canonical RH WETH Hard Reserve with the full authority boundary (FR-2)
- Fee-free pro-rata redemption with permanent `S_MIN` (FR-3)
- One canonical WETH-paid KOTH throne with the 80/20/0 split (FR-4)
- Dutch takeover pricing with frozen parameters (FR-5)
- Finite mined-TGE clock, halving schedule, permanent `1/256` tail (FR-6)
- VEM safe-issuance cap (FR-7)
- Ownerless, unclocked bootstrap state (FR-8)
- Atomic canonical settlement with full observability (FR-9, FR-10)
- Canonical genesis VUX/WETH POL, Strategic separation (FR-11)
- Minimal revenue classification/routing (FR-12)
- Truthful read-only mining/settlement periphery (FR-13)
- Genesis deployment outcomes/validation constraints (FR-14)
- External RH WETH trust disclosure (NFR-TRUST-1)

### In Scope (Future Iterations — acknowledged, NOT designed here)

LSG activation (threshold-gated, conjunctive, evidence-based — never calendar-only; must satisfy every SPEC §20 boundary condition), Crown Share, hVUX, Cooler-style lending, ROOT/veGIGA integrations, tournaments, multiple thrones, new campaigns/seasons, additional Strategic uses. Any future extension must preserve all-inclusive `S`, raw-WETH `B`, the ownerless Reserve, holder redemption, absence of Reserve discretion, and Strategic/backing separation; no future mechanism inherits a claim on Reserve principal.

### Explicitly Out of Scope (exclusion is a requirement)

| Excluded | Reason |
|---|---|
| LSG activation; signaler governance | Genesis LSG = inactive; v1 must operate correctly without it |
| Crown Share; hVUX; Cooler-style lending; ROOT bond perks; veGIGA integrations; tournaments; multiple thrones; new mining seasons | Future-compatibility only; not v1 requirements (SPEC §4, §26) |
| Active treasury strategies; automatic POL deepening; POL price defense | Strategic capital is undeployed at genesis; deepening needs separate authorization |
| Complex YRF; any buyback (incl. Reserve-funded / oracle-based) | Revenue policy is intentionally boring (SPEC §17) |
| Oracle-based monetary policy; runtime USD logic | USD figures are one-time deployment conversions only |
| Anti-whale emission machinery; wallet caps; identity gates; punitive primary taxes | FAIR promises equal rules, not equal outcomes (SPEC §19) |
| Dynamic governance recovery of the Hard Reserve; any emergency recovery authority | Would weaken the ownerless Reserve promise (INV-36) |
| Deployment addresses, AMM selection, dependency pins, contract architecture | Reserved to SDD/deployment (Appendix C) |

### Priority Matrix

Every in-scope requirement is P0 / Must Have: canonical v1 is already the minimum coherent monetary product, and no listed surface can be deferred without breaking an invariant or a doctrine. There is deliberately no P1/P2 backlog in this PRD.

| Feature | Priority | Effort | Impact |
|---------|----------|--------|--------|
| FR-1..FR-14, NFR-SEC-*, NFR-REL-*, NFR-TRUST-1, NFR-COMP-* | P0 | M (aggregate) | Critical — release-gating |

> **Sources**: SPEC §4 (L84–103), §16.2 (L433–439), §17 (L441–454), §19 (L482–492), §20 (L494–515), §26 (L642–646); FREEZE §3 rows 24–26 (L46–48)

---

## Success Criteria

### Launch Criteria (all must hold before any production deployment is authorized)

**Genesis & deployment validation**
- [ ] `totalSupply() = 150,000 × 10^18 + 1` raw units after genesis, before public mining; holdings exactly {canonical POL: 150,000 VUX; Hard Reserve: 1 raw unit; every other address: 0}.
- [ ] One-time conversion record exists (WETH/USD source + timestamp + documented rounding) for the four USD targets; the four immutable WETH constants are set; no runtime USD/oracle logic exists anywhere.
- [ ] `P0/N0 = 1.10` verified against the actually initialized pool (ordering/decimals/ticks/rounding); `B0 = P0 × S0 / 1.10` in raw canonical WETH; `BOOTSTRAP_OPENING ≤ P0 × S0 − B0` holds.
- [ ] External genesis deployment equals exactly `W_POL + B0` (target ≈ $1,909.09); remaining capital Strategic/undeployed; WETH accounting published.
- [ ] LSG inactive; founder/operator genesis compensation none; bootstrap state armed (ownerless King, clock disabled).

**Behavioral acceptance (test-verified)**
- [ ] Redemption: exact `floor(B × q / S)` at fee 0 from pre-state; burns exact `q`; atomic; Reserve-favoring rounding; `S_MIN` floor enforced; independent of mining/POL/Strategic/revenue/LSG state.
- [ ] Split: 80/20 with round-down 80% leg, remainder to Reserve, legs sum exactly to payment, zero to any other recipient.
- [ ] Bootstrap: zero mint; entire activation payment realized as Reserve backing; payer becomes first King; clock starts only then.
- [ ] VEM: `Qmint = min(Qraw, floor(D × S_pre / B_pre))` with exact measured `D`; invariant `B_pre × Qmint ≤ D × S_pre` in both regimes (clock-bound and VEM-bound) and at the exact frontier (equality mints full `Qraw`); no carry/IOU/makeup path exists.
- [ ] Clock/schedule: 3,000 s eligible cap; epoch-open UPS snapshot; halving boundary never re-rates an open epoch; tail rate `INITIAL_UPS/256` permanent from day 240; unused opportunity expires.
- [ ] Pricing: successor opening `max(MINIMUM_OPENING, 2 × paid)`; linear 3,000 s decay; positive immutable floor; floor persists until displacement.
- [ ] Settlement: 12-step sequence realized; atomicity (all-or-none) demonstrated under injected failure; `D`-mismatch rejected; outgoing epoch/King immutable inputs.
- [ ] Observability: all 10 settlement facts reconstructible externally per settlement; `Qmint` vs `Qraw` explainable.
- [ ] POL/Strategic: POL WETH excluded from `B`; POL VUX included in `S`; no post-genesis mint or Reserve funding path for POL.
- [ ] Revenue: VUX revenue burns; WETH revenue reaches the Reserve; returned POL principal classified Strategic.
- [ ] Failure register: all 13 outcomes (Appendix A part 2) have passing tests, including redemption liveness with mining halted and no-emergency-authority verification.
- [ ] Invariant register: all 37 invariants (Appendix A) covered by runnable checks that fail if the invariant breaks.

**Provenance & licensing gates**
- [ ] Root `LICENSE` = unmodified GPLv3; project metadata states `GPL-3.0-or-later`; SPDX policy applied per file class; `THIRD_PARTY_NOTICES.md` updated as reuse actually lands; required Miner/Euler attributions and dated modification notices present; no invented copyright holder.
- [ ] Zero non-allowlisted third-party source in the build; all pins full 40-char SHAs; all implementation dependencies immutably pinned by the SDD before coding; review/build fails on violations.

**UX truth**
- [ ] No surface labels raw clock or displaced-now estimates as earned/claimable/owned/guaranteed; canonical explanation present; NFR-TRUST-1 disclosure present wherever backing immutability is claimed.

### Post-Launch Success (schedule-relative; no calendar dates exist yet)

- [ ] Through the first halving boundary (day 30 after schedule start): boundary behavior observed correct (open epochs unaffected; new epochs snapshot the halved rate); no invariant violation observed on live settlements.
- [ ] Graduation (~day 180) and tail start (day 240) communicated per the claims discipline (graduation ≠ "supply issued"; tail ≠ TGE continuation).

### Long-term Success

- [ ] Zero discretionary Reserve outflows forever (the only principal outflows are holder redemptions).
- [ ] `B/S` never decreased by any settlement or redemption (monotone non-decreasing backing per VUX, absent external RH WETH events).

> **Sources**: SPEC §22 (L539–595), §23 (L597–615), §6.2 (L155–180), §15 (L386–405); FREEZE §3 (L21–48), §4 (L56–78), §5 (L80–96); LIC §14 (L308–322), §19 (L402–416)

---

## Risks & Mitigation

| ID | Risk | Probability | Impact | Mitigation Strategy |
|----|------|-------------|--------|---------------------|
| R-1 | Canonical RH WETH infrastructure adversely upgraded (block/burn/freeze/seize of Reserve WETH) — the accepted YELLOW assumption | Low–Med | Critical | Cannot be mitigated on-chain by VUX (no exit window exists). Mandatory truthful disclosure (NFR-TRUST-1); never claim a trustless backing stack; monitor RH governance externally. Accepted by founder authority |
| R-2 | RH Chain unavailability delays all execution incl. redemption | Med | Med | Accepted: delay ≠ loss; recorded balances unchanged; disclose distinctly from upgrade risk |
| R-3 | Weak mining demand → far less issuance than raw ceiling | Med | Low (by design) | None needed: VEM design outcome, not failure. Claims discipline prevents supply promises (NFR-COMP-3) |
| R-4 | Whale/self-succession concentration of mined distribution | High | Med (reputational) | Accepted: FAIR = equal rules, not equal outcomes. No anti-whale machinery in v1; truthful claims only; future campaigns stay outside v1 and cannot retroactively alter settlement |
| R-5 | Rig/mining defect after launch halts mining permanently (no recovery minter by design) | Low | High (product), None (solvency) | Fail-closed design accepted; redemption unaffected (NFR-REL-1/2); quality gates: full implement→review→audit cycle, invariant tests, EDD |
| R-6 | Shallow POL manipulated or drained; price discovery degrades | Med | Low (monetary) | Monetary arithmetic independent of AMM state (NFR-SEC-5); POL is Strategic; no defense obligation exists |
| R-7 | Provenance/licence breach during implementation (non-allowlisted code, notice loss, unpinned deps) | Med | High (legal/release) | Default-deny registry; review/build hard-fails (NFR-COMP-2); provenance delta process; derived-similarity recheck before merge |
| R-8 | Deceptive-labelling drift in periphery/frontends ("earned", "claimable") | Med | Med | Binding UX truth rules (FR-13, User Experience); review gate includes label audit |
| R-9 | Deployment conversion/geometry error (wrong `P0/N0`, cushion violated, undocumented rounding) | Low | High | FR-14 validation gates: 1.10 verification post-rounding, cushion inequality, published accounting; deployment blocked until green |
| R-10 | Scope creep re-introducing excluded machinery (buybacks, oracles, recovery powers) | Med | High | Exclusion list is a requirement; audit gate checks Scope table; invariants INV-5, 33, 36 make violations test-visible |

### Assumptions

- [ASSUMPTION] The operator-designated authority set (FREEZE, SPEC, LIC, REG, TPN) is complete and final for v1 — no other binding product authority exists. If wrong: this PRD must be regenerated against the missing authority before `/architect`.
- [ASSUMPTION] Canonical RH WETH at `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` remains the intended backing asset at deployment time. If wrong: NFR-TRUST-1 and FR-14 must be re-derived from a new founder freeze before deployment.
- [ASSUMPTION] Operator review of this PRD substitutes for the interactive per-phase interview confirmations of the discovery skill (autonomous node; authorities pre-answer all phases). If wrong: rerun `/plan-and-analyze` interactively before acceptance.

### Dependencies on External Factors

- Robinhood Chain governance conduct and chain liveness (R-1, R-2).
- Market conditions at the one-time pre-deployment WETH/USD conversion (affects only the immutable constants' realized WETH values, inside FR-14's procedure).

> **Sources**: SPEC §21 (L517–537), §23 (L597–615), §19 (L482–492); FREEZE §3 rows 22–26 (L44–48); LIC §16–§17 (L340–372)

---

## Timeline & Milestones

No calendar dates are authorized: the mined-TGE schedule is anchored to the deployment-set immutable schedule-start timestamp (reserved), and lifecycle dates depend on operator review gates. Milestones are therefore ordered, not dated.

| Milestone | Gate | Deliverables |
|-----------|------|--------------|
| M-1: PRD accepted | Operator review of this document | Accepted PRD (this file) |
| M-2: SDD complete | `/architect` (forbidden until M-1) | Contract decomposition; pinned dependencies (exact OZ release/digest); arithmetic mechanics; event encodings; toolchain |
| M-3: Sprint plan | `/sprint-plan` | Sprints with beads tasks, acceptance criteria traced to FR/NFR/INV IDs |
| M-4: Implementation complete | `/implement` → `/review-sprint` → `/audit-sprint` per sprint | Code + tests satisfying all Launch Criteria testable pre-deployment; provenance gates green |
| M-5: Deployment readiness | Deployment validation per FR-14 | Conversion record; derived constants; genesis rehearsal green |
| M-6: Genesis deployment | Operator authorization (outside this PRD) | Live genesis; schedule start `T0` fixed on-chain |
| Protocol anchors | `T0`+180d ≈ public TGE graduation; `T0`+240d = formal tail start | Communications per claims discipline |

> **Sources**: SPEC §24 (L617–632), §27 (L648–658); FREEZE §5 (L80–96), §7 (L104–111)

---

## Appendix

### A. Invariant register traceability (load-bearing; all 37 must have runnable checks)

Numbering follows SPEC §22 order.

**Supply and issuance**

| INV | Substance (compressed) | Carried by |
|---|---|---|
| 1 | `S` is always `VUX.totalSupply()`; no exclusions | FR-1 |
| 2 | Genesis supply exactly `150,000 × 10^18 + 1` raw units | FR-1, FR-14 |
| 3 | Zero genesis VUX to every user/discretionary address | FR-1, FR-14 |
| 4 | Post-genesis minting only via immutable KOTH/VEM path | FR-1 |
| 5 | No free/treasury/POL/governance/recovery/migration/discretionary mint | FR-1 |
| 6 | Every mint goes only to the outgoing public King during successful settlement | FR-1, FR-9 |
| 7 | Authorized issuance cannot reduce `B/S` | FR-7 |
| 8 | Issuance uses exact realized contribution, never nominal/assumed | FR-7 |
| 9 | Contribution realized and measured before issuance depends on it | FR-7, FR-9 |
| 10 | `Qmint ≤ min(Qraw, VEM frontier)` | FR-7 |
| 11 | Raw opportunity never becomes debt/carry/IOU/makeup/entitlement | FR-6, FR-7 |
| 12 | No stale accrual: stored rate, ≤3,000 eligible seconds per epoch | FR-6 |
| 13 | Bootstrap mints zero | FR-8 |
| 14 | Full-precision overflow-safe arithmetic; rounding never crosses the frontier | FR-7, NFR-SEC-4 |

**Hard Reserve and redemption**

| INV | Substance | Carried by |
|---|---|---|
| 15 | `B` = raw canonical RH WETH at the Reserve, nothing else | FR-2 |
| 16 | No discretionary outflow/call/approval/sweep/pause/migration/owner/upgrade | FR-2, NFR-SEC-1 |
| 17 | Redemption: pre-state, exact burn, `floor(B×q/S)`, fee 0 | FR-3 |
| 18 | Redemption independent of mining/POL/Strategic/revenue/LSG | FR-3, NFR-REL-2 |
| 19 | `S_MIN = 1` raw unit permanently Reserve-held; denominator stays live | FR-3 |
| 20 | Monetary rounding favors the Reserve; backing per remaining VUX never reduced | FR-3, NFR-SEC-4 |
| 21 | Reserve principal never relabeled/transferred to Strategic or working capital | FR-2, FR-12 |

**Settlement and primary economics**

| INV | Substance | Carried by |
|---|---|---|
| 22 | 80/20/0 split; Reserve receives any remainder | FR-4 |
| 23 | No bootstrap or primary-flow privilege for any party | FR-4, FR-8 |
| 24 | Settlement atomicity (all-or-none) | FR-9, NFR-SEC-3 |
| 25 | Outgoing epoch/King determine `Qraw` + recipient; successor cannot rewrite | FR-9 |
| 26 | First activation: full payment to Reserve, zero mint, then first epoch | FR-8 |

**POL, Strategic capital, revenue, markets**

| INV | Substance | Carried by |
|---|---|---|
| 27 | POL/Strategic WETH never in backing arithmetic | FR-11 |
| 28 | POL/Strategic VUX never out of supply arithmetic | FR-11, FR-1 |
| 29 | No post-genesis POL action uses a mint or Reserve principal | FR-11 |
| 30 | Protocol POL VUX never redeemed as treasury management | FR-11, FR-3 |
| 31 | Returned LP principal is Strategic, never revenue | FR-11, FR-12 |
| 32 | Incremental VUX revenue burns; incremental WETH revenue → Reserve | FR-12 |
| 33 | AMM manipulation/pool failure/secondary price cannot change VEM or redemption | NFR-SEC-5 |

**Security and trust boundaries**

| INV | Substance | Carried by |
|---|---|---|
| 34 | Rig failure may halt mining, must not halt/condition redemption | NFR-REL-1/2 |
| 35 | Non-Reserve failures create no claim on Reserve principal | NFR-SEC-1, NFR-REL-1 |
| 36 | No v1 recovery power may weaken the ownerless immutable Reserve | FR-2, NFR-SEC-1 |
| 37 | Reserve "ownerless/immutable" described only with the external RH WETH disclosure | NFR-TRUST-1 |

**Failure register (F-1..F-13 → NFR-REL-1 tests)**: F-1 Rig fails → mining may halt permanently, redemption unaffected · F-2 no challenger → no settlement, nothing owed, accrual stops at 3,000 s · F-3 weak demand → less issuance, no catch-up · F-4 high demand → clock-limited issuance, excess raises backing · F-5 tail dormancy → no solvency issue, no tail enlargement right · F-6 POL impaired → trading degrades, monetary arithmetic unaffected · F-7 Strategic losses → stay Strategic · F-8 zero revenue / routing fails pre-receipt → v1 functional, no principal substitution · F-9 LSG absent/fails → v1 functional · F-10 large redemptions → pro-rata, Reserve-favoring rounding, `B/S` non-decreasing, `S_MIN` remains · F-11 price below backing → redemption is the response; no oracle/defense/Reserve action triggers · F-12 chain unavailable → execution delayed, balances unchanged · F-13 WETH infrastructure adversely upgraded → accepted external trust risk; not repairable with Reserve powers.

> **Sources**: SPEC §22 (L539–595), §23 (L597–615)

### B. Frozen economic parameters (carried verbatim; deployment treatment per FR-14)

| Parameter | Frozen value |
|---|---|
| Genesis POL VUX | 150,000 VUX (`150,000 × 10^18` raw) |
| Hard Reserve seed `S_MIN` | 1 raw VUX unit (permanent) |
| Genesis user/discretionary VUX | 0 |
| Genesis total supply | exactly `150,000 × 10^18 + 1` raw units |
| POL WETH side | ≈ $1,000 USD-equivalent (one-time conversion) |
| Target `P0/N0` | 1.10 |
| Hard Reserve seed `B0` | derived: `P0 × S0 / 1.10` (≈ $909.09 target) |
| Max external genesis deployment | `W_POL + B0` (≈ $1,909.09 target); rest Strategic/undeployed |
| `EPOCH_PERIOD` | 3,000 seconds |
| `PRICE_MULTIPLIER` | 2× (price ladder, not reward) |
| `INITIAL_UPS` | 4 VUX/s (`4 × 10^18` raw/s), epoch-open snapshot |
| Halving period / count | 30 days / 8 cuts (days 30…240) |
| UPS by interval | 4 → 2 → 1 → 0.5 → 0.25 → 0.125 → 0.0625 → 0.03125 → tail |
| Tail | retained; `INITIAL_UPS/256 = 0.015625` VUX/s from day 240 (≤ 492,750 raw VUX/yr) |
| Bootstrap King / clock | ownerless Hard Reserve / disabled (`Qraw = 0`) |
| Bootstrap opening | ≈ $50 WETH-equivalent (one-time conversion) |
| Minimum opening | ≈ $10 WETH-equivalent (one-time conversion) |
| Decay floor | ≈ $1 WETH-equivalent (one-time conversion; dust/restart rule) |
| Redemption fee | 0 (`REDEMPTION_FEE_BPS = 0`) |
| Public TGE graduation | ≈ day 180 (communications milestone) |
| Formal tail start | day 240 |
| Genesis LSG | inactive |
| Founder/operator genesis compensation | none |

> **Sources**: FREEZE §3 (L21–48), §4 (L56–78), §5 (L80–96); SPEC §6 (L130–180), §10 (L249–257), §11 (L296–308)

### C. Reserved decisions register (genuinely later; constraints bind now, realizations do not)

| Reserved item | Binding constraint now | Realized by |
|---|---|---|
| WETH/USD reference source + timestamp | One founder-approved price, recorded, used once | Deployment (FR-14) |
| Exact immutable WETH constants (POL side, bootstrap opening, min opening, decay floor) | Converted once from frozen USD targets; rounding documented | Deployment (FR-14) |
| Exact derived `B0` | `P0 × S0 / 1.10` after actual pool geometry/rounding; cushion inequality holds | Deployment (FR-14) |
| AMM venue, pool type, fee tier, range/ticks, fee ownership, POL custody address | Must preserve FR-11 posture (shallow/passive/wide; no auto-deepening) | SDD + deployment |
| OpenZeppelin exact release (and any other library) | Immutable release commit/package digest + imported paths + notices, pinned **before coding** | SDD |
| Solidity/toolchain versions | Only as compatibility requires; pinned in SDD | SDD |
| Contract decomposition/count; call graphs; CEI structure; event/record encodings | Must realize FR-9/FR-10 observable facts + all invariants | SDD |
| VEM arithmetic mechanics (full-precision mul/div implementation) | NFR-SEC-4 properties | SDD |
| `Unit.sol` feature selection; `IUnit` vs original `IVUX` | Within LIC allowlist treatment + SPDX policy | SDD |
| Deployment addresses; deployment block/txs; schedule-start timestamp | Immutable once set; schedule anchors to it | Deployment |
| Final implementation commit hashes; final dependency pins | Full 40-char SHAs / integrity digests only | SDD + release |

No item above reopens frozen tokenomics; if any realization would, it requires a founder-level provenance/parameter delta first.

> **Sources**: SPEC §24 (L617–632); FREEZE §7 (L104–111); LIC §13 (L280–306), §17 (L359–372)

### D. Authority bibliography

**Binding (this PRD derives from, and defers to, these):**
- `docs/authority/vux-founder-parameter-freeze-2026-08.md` — frozen founder parameters (FREEZE)
- `docs/authority/vux-v1-canonical-specification-2026-08.md` — canonical product/protocol authority (SPEC)
- `docs/authority/vux-v1-licence-provenance-source-pin-freeze-2026-08.md` — licence/provenance/source-pin freeze (LIC)
- `docs/authority/vux-v1-source-registry-2026-08.json` — machine-readable registry (REG)
- `THIRD_PARTY_NOTICES.md` — frozen provenance obligations (TPN)
- `README.md` — repository authority map

**Evidence only (cannot restore superseded requirements):** materials under `docs/research/` and all upstream repositories named in REG (study only under their classifications).

> **Sources**: README.md (L15–26); SPEC §1 (L13–21); LIC §4–§5 (L81–121)

### E. Glossary

| Term | Definition |
|------|------------|
| VUX | The protocol token; 18 decimals; `S = totalSupply()` all-inclusive |
| Canonical RH WETH | Canonical Robinhood Chain WETH (`0x0Bd7…AD73`); payment + backing asset; external YELLOW trust assumption |
| Hard Reserve | Ownerless, immutable custody of raw canonical WETH; defines `B`; honors redemption |
| `S` / `B` / `N` | Total VUX supply / Reserve raw WETH balance / conceptual backing per VUX (`B/S`) |
| `S_MIN` | 1 raw VUX unit permanently held by the Reserve; monetary denominator floor |
| KOTH / Rig | King-of-the-Hill throne game / the mining-settlement surface implementing it |
| King (outgoing/incoming) | Current throne holder being displaced / successor who paid the takeover |
| Epoch | One reign's pricing-and-mining window; 3,000 s eligible clock; snapshotted UPS |
| UPS | VUX-per-second raw accrual rate; halving schedule from 4 VUX/s; tail `1/256` |
| `Qraw` | Time-derived maximum reward for the outgoing epoch (`min(elapsed,3000) × epochUPS`); never owed |
| `D` | Exact realized fresh WETH balance increase at the Reserve from the current settlement |
| `Qsafe` / `Qmint` | `floor(D × S_pre / B_pre)` / `min(Qraw, Qsafe)` — the actual mint |
| VEM | VUX Emission Model — the safe-issuance cap rule (FR-7) |
| Dutch decay | Linear price decline from the opening toward the immutable positive floor over 3,000 s |
| Recycle | The 80% payment leg paid to the outgoing King |
| Bootstrap | One-time state: ownerless Reserve as unclocked King; first takeover mints zero and fully backs the Reserve |
| POL | Canonical protocol-owned VUX/WETH liquidity (150,000 VUX side); Strategic, never backing |
| Strategic capital | Project capital outside the Hard Reserve promise; losses never reach backing |
| LSG | Liquid Signal Governance — inactive in v1; future-compatible only |
| TGE / graduation / tail | Mined token-generation event / ≈ day-180 milestone / permanent `1/256` pilot-light from day 240 |
| Source pin | Full 40-char Git SHA fixing an upstream source; mutable refs are never authority |

> **Sources**: SPEC §2 (L23–45), §5 (L105–128), §10–§14 (L247–384); FREEZE §3 (L21–48); LIC §4 (L81–95)

---

*Generated by Loa `/plan-and-analyze` (discovering-requirements) for cycle-001 · VUX v1 · Terminal state: `PRD_READY_FOR_REVIEW` · `/architect` not invoked.*
