# VUX Founder Parameter Freeze — Strategic-Treasury Supersession

**Date:** 2026-08-09  
**Status:** `FOUNDER_AUTHORITY_CURRENT_ACCEPTED`  
**Operator acceptance:** 2026-08-09 — `OPERATOR_ACCEPTANCE`  
**Authority:** Binding founder parameter successor for the corrected VUX v1 product  
**Controlling decision record:** accepted founder decisions following `vux-strategic-treasury-capital-routing-reconciliation-2026-08.md`

## 1. Activation and precedence

Operator acceptance was recorded on 2026-08-09. This document supersedes `vux-founder-parameter-freeze-2026-08.md` in full as the current Founder Parameter Freeze. The predecessor remains immutable historical authority evidence and must not be edited or deleted.

This successor preserves every predecessor parameter not explicitly changed below. It does not authorize implementation, deployment, a Loa lifecycle invocation, or a source-provenance expansion. The exact old-to-new disposition is recorded in `vux-v1-authority-supersession-map-2026-08.md`.

The controlling product doctrine remains:

> **FAIR · SIMPLE · ELEGANT · SECURE**

The corrected identity is:

> The throne gets people in.  
> The Strategic Treasury gives them a reason to stay.  
> The Hard Reserve gives them a right to leave.

The mature-product shorthand is **ROOT for the people**: holders may direct marginal Strategic capital among admitted opportunities, while bounded operator/risk authorities retain admission, execution, security, and emergency responsibility. The Hard Reserve is never governed through that surface.

## 2. Authority classification

This freeze uses three non-overlapping classifications.

- **FROZEN** — product/economic authority that a PRD or SDD may not vary.
- **OPERATOR-RESERVED / ADAPTIVE** — bounded judgment intentionally retained by operators/cofounders; no fixed number is implied.
- **RESEARCH GUIDANCE, NOT AUTHORITY** — useful assumptions or comparison values that must not be represented as founder tokenomics.

Silence does not convert guidance into a frozen value. An operator-reserved decision may not violate a frozen boundary.

## 3. FROZEN doctrine and parameters

| # | parameter or boundary | frozen value / outcome |
|---:|---|---|
| 1 | Public product | One canonical WETH-paid KOTH throne; permissionless mining is the public TGE and post-genesis issuance path. |
| 2 | Genesis POL VUX | Exactly `150,000 VUX` to canonical protocol-owned VUX/WETH POL. This is protocol liquidity inventory, not a user allocation. |
| 3 | Permanent Reserve seed | Exactly `1` raw VUX base unit to the ownerless Hard Reserve. |
| 4 | Genesis total supply | Exactly `150,000 × 10^18 + 1` raw VUX units. |
| 5 | Genesis user/discretionary allocation | `0 VUX` to founders, operators, developers, apDAO, partners, investors, users, airdrops/community, public sale, and every other discretionary address. |
| 6 | Post-genesis mint authority | Only permissionless KOTH settlement subject to VEM; only the outgoing public King may receive the settlement mint. |
| 7 | Ordinary primary routing | Gross-payment form `80 / 8 / 12`: 80% outgoing King, nominally at least 8% Hard Reserve, 12% Strategic Treasury, and 0% every other primary recipient. |
| 8 | Split arithmetic | `king = floor(80% of P)`; `strategic = floor(12% of P)`; `reserve = P - king - strategic`. Hard Reserve receives all split dust. |
| 9 | Monetary-routing posture | Static `80/8/12`. No macro, market-price, NAV, Strategy-return, ROOT/GIGA-price, calendar-phase, or oracle-mediated dynamic KOTH router. |
| 10 | Hard/Strategic separation | Hard Reserve principal and Strategic principal are physically and accountingly distinct. Strategic assets never enter `B`. |
| 11 | Hard backing quantities | `S = VUX.totalSupply()`; `B =` raw canonical RH WETH physically held by the Hard Reserve; `N = B/S`. |
| 12 | Hard Reserve properties | Raw canonical RH WETH only; ownerless; immutable/non-upgradeable; non-pausable; no arbitrary call, approval, sweep, successor, migration, or discretionary principal authority. |
| 13 | Redemption | Ordinary fee-free pro-rata WETH redemption; `payout = floor(B*q/S)` using pre-redemption values; Reserve-favoring rounding; `S_MIN = 1` raw VUX. |
| 14 | Hard-only VEM | Only the exact measured current-settlement Hard Reserve delta `D_R` supports issuance. Strategic WETH/NAV, POL, ROOT, GIGA, stable assets, prices, and expected yield receive zero mint credit. |
| 15 | VEM rule | `Qsafe = floor(D_R × S_pre / B_pre)` and `Qmint = min(Qraw, Qsafe)`, with full-precision safe arithmetic. |
| 16 | Issuance invariant | `(B_pre + D_R)/(S_pre + Qmint) >= B_pre/S_pre`; authorized issuance cannot reduce Hard WETH backing per VUX. |
| 17 | Unsupported opportunity | No carry, IOU, debt, makeup emission, entitlement, high-water emission, Strategic-NAV mint, oracle-backed mint, or recapitalization mint. |
| 18 | Initial UPS | `4 VUX/second`, snapshotted at epoch opening and always limited by VEM. |
| 19 | Raw-clock meaning | 4 UPS is an abundant raw faucet/opportunity, not target supply. Approximately 20.655M pre-tail VUX is raw opportunity, not promised issuance. |
| 20 | Epoch | `3,000 seconds` eligible raw accrual maximum for each public reign. |
| 21 | Takeover multiplier | `2×`; it is a price-ladder multiplier, not a mining multiplier. |
| 22 | Halving schedule | Eight immutable 30-day halvings at days 30, 60, 90, 120, 150, 180, 210, and 240. |
| 23 | Tail | Permanent `INITIAL_UPS/256 = 0.015625 VUX/second` pilot-light tail after day 240, still clock- and VEM-limited. |
| 24 | TGE framing | Approximate day 180 public graduation; days 180–240 wind-down; day 240 formal tail. Actual supply is whatever safely settles. |
| 25 | Bootstrap King | The ownerless Hard Reserve is the sole genesis King and has no mining clock. |
| 26 | Bootstrap settlement | `Qraw = 0`; first public takeover mints zero; payer becomes first public King and begins the public clock. |
| 27 | Bootstrap routing | Ordinary arithmetic applies: outgoing-King 80% terminates at the Reserve, nominal Hard leg and dust enter the Reserve, and 12% enters Strategic custody. Approximately 88% or greater enters Hard and 12% enters Strategic. |
| 28 | Bootstrap price targets | Approximately $50 WETH-equivalent opening, approximately $10 minimum opening, and approximately $1 positive decay floor, each converted once before deployment. |
| 29 | Genesis WETH-side POL target | Approximately $1,000 WETH-equivalent, converted once before deployment. |
| 30 | Genesis backing relationship | `P0/N0 = 1.10`; derive `B0 = P0 × S0 / 1.10`, approximately $909.09 WETH-equivalent under the intended comparator. |
| 31 | External genesis deployment | Approximately $1,909.09 WETH-equivalent, exactly the approved POL WETH side plus derived `B0`; no other external genesis deployment. |
| 32 | Remaining project/apDAO capital | Strategic and undeployed at genesis unless separately authorized; never Hard backing, unsupported mint support, or Reserve repair. |
| 33 | Strategic Treasury status | First-class core VUX surface and protocol-owned risk capital, separately accounted from the Hard Reserve. |
| 34 | Strategic failure independence | Strategic loss, including total loss, cannot reduce `B`, change redemption, authorize minting, withdraw Reserve principal, or create a recapitalization entitlement. |
| 35 | Strategic-zero survival | Existing supply accounting, Hard WETH redemption, KOTH, VEM, and FAIR issuance constraints survive Strategic NAV reaching zero. |
| 36 | POL classification | VUX/WETH POL is a Strategic Treasury sleeve. POL WETH is never `B`; POL VUX remains in `S`; returned LP principal remains Strategic principal. |
| 37 | POL VUX sourcing | No post-genesis VUX may be minted for POL. Later POL VUX must be existing or purchased VUX. |
| 38 | POL conduct | Protocol-owned POL VUX may not be redeemed against the Hard Reserve as a treasury operation and is non-voting for LSG. |
| 39 | POL-special VYRF | Incremental VUX-denominated POL fee yield is burned; incremental WETH-denominated POL fee yield enters the Hard Reserve one-way. Neither passes through the general Strategic realized-revenue waterfall. |
| 40 | Principal versus POL yield | Returned LP principal is Strategic principal, not POL fee yield or distributable revenue. |
| 41 | General Strategic revenue boundary | Returned principal and unrealized marks are never distributable revenue. Only realized cash yield, fees, or profit may enter a general revenue policy. |
| 42 | Permitted general revenue uses | Realized economics may fund Strategic compounding, Hard Reserve accretion, legitimate operations/contributors, LSG/signaler incentives, and market infrastructure under disclosed policy. |
| 43 | Primary compensation prohibition | Founders, operators, developers, and signalers receive no genesis allocation and no primary KOTH flow. |
| 44 | Reserve use prohibition | Hard Reserve principal never funds payroll, bribes, Strategies, POL, operating costs, or Strategic-loss rescue. |
| 45 | Strategic-principal discipline | Strategic principal may not be casually relabeled as revenue. A disclosed external startup/incubation runway may fund pre-scale work. |
| 46 | Non-POL VUX revenue posture | VUX-denominated protocol revenue outside POL is normally burned unless later explicit founder authority establishes another justified treatment. |
| 47 | LSG mature role | LSG is a core mature product surface through which holders express relative preferences for marginal Strategic allocation among bounded admitted Strategies. |
| 48 | LSG limits | LSG cannot control the Hard Reserve, minting, arbitrary recipients, low-level security parameters, exploit response, or ordinary protocol upgrades. |
| 49 | LSG authority separation | Admission/due diligence/risk limits, bounded execution, emergency removal/recall, and security remain operator/risk responsibilities. |
| 50 | LSG activation posture | Inactive until internally threshold-gated and affirmatively activated at operator discretion when distribution, capital, useful Strategy choice, safety, and concentration are sufficient. |
| 51 | Pre-LSG flow | Absence of active LSG never redirects the 12% Strategic leg into the Hard Reserve. Strategic capital may remain raw WETH or follow narrow authorized bootstrap policy. |
| 52 | Bribe posture | Default is to own durable liquidity. Protocol-funded VUX/WETH bribes are measured tactical experiments funded from realized protocol economics by default, never Hard Reserve principal. |
| 53 | ROOT/GIGA classification | Strategic hypotheses/opportunities until canonical facts exist; never `B`, never VEM support, and never a redemption promise. |
| 54 | FAIR distribution truth | Fair access does not promise equal outcomes. No anti-whale monetary machinery, identity gate, wallet cap, or hidden allocation is introduced. |
| 55 | Mining UX truth | Distinguish raw clock/maximum opportunity, live “VUX if displaced now” estimate, and final VUX minted by completed settlement. Only the last is mined/earned. |
| 56 | External WETH trust | The VUX-controlled Reserve is ownerless and immutable, but canonical RH WETH retains the accepted YELLOW Robinhood Chain governance/upgrade trust assumption. |
| 57 | Provenance posture | Project licence remains GPL-3.0-or-later; current allowlisted reuse and pins remain unchanged; corrected Strategic/LSG/VYRF surfaces are VUX-original unless later provenance authority says otherwise. |

## 4. OPERATOR-RESERVED / ADAPTIVE decisions

The following are deliberately not founder-fixed tokenomics:

| decision | reserved authority and frozen boundary |
|---|---|
| Strategic portfolio weights | Operators/cofounders may allocate among verified and admitted assets; Strategic assets remain outside `B`. |
| POL size and portfolio share | Operators/cofounders choose amount, timing, venues, ranges, and opportunity cost; no mint or Reserve principal. |
| Strategic deployment timing | Static receipt does not require immediate deployment. Operators may stage, pause, or resume deployment. |
| Strategic dry powder | Amount and duration adapt to verified opportunity, liquidity, risk, and market conditions. |
| Strategy admission | Operator/risk authorities conduct diligence, establish limits, and may remove or recall admitted Strategies. |
| LSG activation timing | Operators may activate earlier or later according to readiness; no calendar date alone activates LSG. |
| Internal LSG readiness thresholds | Distribution, capital, participation, Strategy choice, safety, and concentration tests are set and may evolve within the frozen LSG role. |
| ROOT/GIGA exposure | Operators/cofounders exercise bounded portfolio judgment only after canonical documentation, deployment, rights, liquidity, and custody facts exist. |
| General realized-revenue waterfall | Operators/cofounders set and evolve exact percentages within §3's principal, Hard Reserve, and permitted-use boundaries. |
| Operations budget and compensation | Exact shares, caps, reserves, and performance terms adapt to realized protocol economics; no primary flow, Reserve principal, or mislabeled Strategic principal. |
| Bribe experiment sizing | Tactical size, venue, duration, measurement, and stop rules are adaptive; failed rental must not become the primary liquidity strategy. |
| Market-infrastructure tactics | Buybacks, purchased VUX for POL, liquidity venue/range, and other tactics require their own permitted funding and cannot alter VEM/redemption. |
| Deployment facts | Addresses, blocks, immutable WETH conversions, schedule-start timestamp, AMM implementation facts, and final dependency pins remain later verified facts. |

Operator discretion is not authority to raid the Reserve, mint VUX, reclassify principal, create undisclosed founder economics, or make unverified ROOT/GIGA claims.

## 5. RESEARCH GUIDANCE, NOT AUTHORITY

The following remain useful scenario assumptions but are expressly not frozen:

| research value | disposition |
|---|---|
| General revenue `50% compound / 10% Hard / 25% operations / 10% signalers / 5% market infrastructure` | Simulation/comparison baseline only. |
| `25%` operator share | Guidance only; not a canonical entitlement. |
| `2.5%` average Strategic NAV operator ceiling | Guidance only; not a frozen fee or cap. |
| LSG gates of 60 days, 5M distributed VUX, 50 holders, 10 effective participants, 35% holder ceiling, or $250K Strategic capital | Illustrative readiness values only. |
| ROOT 10% pilot, 25% mature cap, and 35% aggregate ROOT/GIGA look-through cap | Prudent research guidance pending evidence and operator policy. |
| 30% first-180-day dry powder, 40–60% downturn dry powder, or 10% deployment per 30 days | Scenario/deployment guidance only. |
| Exact LP-per-bribe-dollar, one-year depth, 35% retention, or 1.5× direct-POL comparison thresholds | Measurement guidance only. |

No PRD, SDD, interface, or implementation may present these values as immutable founder parameters merely because they appeared in research or simulation.

## 6. Canonical ordinary settlement and VEM

For exact payment `P`:

```text
king      = floor(P × 8,000 / 10,000)
strategic = floor(P × 1,200 / 10,000)
reserve   = P - king - strategic
```

Before issuance:

```text
B_pre = canonical WETH in Hard Reserve before this settlement contribution
S_pre = VUX.totalSupply() before this settlement mint
D_R   = exact realized Hard Reserve WETH increase caused by this settlement

Qsafe = floor(D_R × S_pre / B_pre)
Qmint = min(Qraw, Qsafe)
```

`D_R` is measured after the Reserve contribution reaches the Hard Reserve. It is not an assumed 8%, a quote, an oracle value, or a Strategic balance. Settlement must be atomic and use full-precision arithmetic. The Strategic transfer receives zero issuance credit.

## 7. Bootstrap and genesis accounting

```text
Genesis VUX
├── canonical protocol-owned POL: 150,000 VUX
├── ownerless Hard Reserve seed: 1 raw VUX unit
└── all users/discretionary addresses: 0

Genesis total: 150,000 × 10^18 + 1 raw units
```

The first public activation applies the canonical split while the Reserve is outgoing King:

```text
80% outgoing-King leg  ─┐
nominal 8% Hard leg     ├─> Hard Reserve (plus all split dust)
12% Strategic leg      ───> Strategic Treasury
Qraw = Qmint = 0
```

This is approximately 88% or greater Hard / 12% Strategic. It does not create a free founder/operator reign, VUX reward, or payment.

The required pre-deployment conversion procedure from the predecessor freeze remains unchanged: record a founder-approved WETH/USD reference price, source, and timestamp; convert the four USD-equivalent launch targets once; derive `B0` from actual initialized `P0` and `S0`; record rounding; verify `P0/N0 = 1.10` and the bootstrap-cushion inequalities. No runtime USD oracle or refresh mechanism is permitted.

## 8. Strategic Treasury, POL, and revenue boundaries

Strategic principal is protocol-owned risk capital, including undeployed Strategic WETH, deployed Strategy principal, ROOT/GIGA or other admitted assets, and VUX/WETH POL principal. It is not the Hard Reserve and is not distributable merely because it is marked above cost.

POL has a special revenue policy:

```text
returned VUX/WETH LP principal     -> Strategic principal
incremental VUX POL fee yield      -> burn
incremental WETH POL fee yield     -> Hard Reserve
```

The POL fee legs bypass the general realized-revenue waterfall. Burning VUX reduces `S`; routing WETH yield to the Reserve increases `B`. Neither policy authorizes principal redemption, a new mint, or an automated implementation decomposition.

For other Strategic activity, source and realization determine classification. Realized economics may fund the permitted uses in §3. Exact percentages are operator-reserved. Hard Reserve principal, returned Strategic principal, and unrealized marks are never payroll or distributable revenue.

## 9. LSG boundary

LSG makes holder-directed marginal allocation real without making token voting the protocol security model.

Holders may express relative allocation preferences only among operator/risk-admitted Strategies and only over available Strategic capital. Operators/risk authorities retain admission, diligence, caps, bounded execution, and emergency removal/recall. Upgrade authority and low-level security controls remain separate.

Activation is an affirmative operator decision after internal threshold tests. No exact readiness number is frozen. Before activation, operators may keep Strategic WETH undeployed or follow a narrow authorized bootstrap policy. Protocol-owned POL VUX is always excluded from LSG voting power.

## 10. Superseded recommendations

On acceptance, this freeze supersedes all earlier authority asserting:

- `80% King / 20% Hard Reserve / 0% Strategic`;
- zero primary Strategic Treasury flow;
- all incremental WETH protocol revenue necessarily enters the Hard Reserve regardless of source;
- Strategic Treasury is economically secondary;
- LSG is merely optional/deferred compatibility;
- maximizing Hard Reserve alone is the VUX product objective;
- a bootstrap activation sends 100% of payment to the Hard Reserve;
- fixed `50/10/25/10/5`, 25%, 2.5%, numeric LSG gates, ROOT/GIGA caps, dry-powder rules, or bribe hurdles are founder-frozen.

Earlier historical recommendations already superseded by the predecessor freeze—20M genesis, 17M public genesis allocation, 85/15 genesis capital, 90-day ×5 halvings, `1/32` tail, and one-hour epoch—remain superseded and are not revived.

## 11. Handoff

This is the current Founder Parameter Freeze for the authorized fresh Loa `/plan-and-analyze` cycle together with:

1. `vux-v1-canonical-specification-strategic-treasury-supersession-2026-08.md`;
2. `vux-v1-licence-provenance-source-pin-freeze-2026-08.md` plus its Strategic-Treasury provenance delta;
3. `vux-v1-authority-supersession-map-2026-08.md`.

This document does not invoke that cycle or authorize architecture or implementation.
