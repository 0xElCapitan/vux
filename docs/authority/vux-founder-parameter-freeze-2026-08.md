# VUX Founder Parameter Freeze

**Date:** 2026-08-09  
**Authority:** Founder parameter input to the canonical VUX v1 specification  
**Controlling research:** `vux-fair-mined-tge-tokenomics-reconciliation-2026-08.md`

## 1. Status

`FOUNDER_PARAMETER_FREEZE_COMPLETE`

All implementation-relevant founder parameters are frozen below or narrowly reserved for deployment-time conversion and venue mechanics. This artifact does not authorize implementation, deployment, licence changes, or preparation of the canonical v1 specification.

## 2. Binding doctrine

VUX optimizes **FAIR · SIMPLE · ELEGANT · SECURE**. Genesis VUX exists only for canonical protocol-owned VUX/WETH POL and the one-raw-unit `S_MIN`; every discretionary and user address receives zero VUX. All later issuance occurs only through permissionless KOTH/VEM mining, while users may acquire existing VUX permissionlessly through the market. Mining is the public TGE and distribution mechanism, not a privileged allocation channel.

The closed architecture remains binding: canonical Robinhood Chain WETH Hard Reserve; ownerless Reserve; all-inclusive `S = totalSupply()`; fee-free pro-rata WETH redemption; 80% outgoing King / 20% Hard Reserve / 0% primary other; measured `D`; `Qmint = min(Qraw, floor(D*S/B_pre))`; no carry, IOU, or unsupported emission; no post-genesis POL mint; no Reserve-funded POL; immutable direct Rig mint authority; and the accepted YELLOW canonical-RH-WETH infrastructure assumption.

## 3. Frozen parameters

| parameter | frozen value | rationale/source | implementation treatment |
|---|---|---|---|
| 1. `Q_POL` | **150,000 VUX** | Fair-Mined TGE §§8, 23.2, 24: minimum useful Goldilocks center; only about 0.73% of the pre-tail raw opportunity. | Mint exactly `150,000 × 10^18` raw units to canonical protocol-owned POL at genesis. It is protocol inventory, not a user allocation. |
| 2. Genesis total VUX supply | **Exactly 150,000 VUX + 1 raw VUX unit** | Fair-Mined TGE §§4, 8, 26.2; `S0 = Q_POL + S_MIN`. | Assert `totalSupply() = 150,000 × 10^18 + 1` after genesis and before public mining. |
| 3. Genesis user allocation | **0 VUX** | Binding FAIR doctrine; Fair-Mined TGE §§2, 4, 8. | Founder, apDAO, partner, investor, airdrop/community, public-sale, and every other discretionary/user address must each receive zero genesis VUX. |
| 4. WETH-side POL target | **Approximately $1,000 USD-equivalent of WETH** | Fair-Mined TGE §§1, 6.2, 23.2, 24. | Convert once immediately before deployment; do not embed the research's `$1,625/WETH` modeling conversion. |
| 5. Hard Reserve seed | **Target approximately $909.09 USD-equivalent of WETH; derive it to produce `P0/N0 = 1.10`** | Fair-Mined TGE §§5.2, 23.2. | With actual marginal pool price `P0`, set `B0 = P0 × S0 / 1.10`; under passive symmetric/full-range geometry this is approximately `W_POL / 1.10`. Deposit raw canonical RH WETH only. |
| 6. Target `P0/N0` | **1.10** | Fair-Mined TGE §§5.2, 24: modest premium and rounding cushion without a material early-seller subsidy. | Verify against the actual initialized marginal price after token ordering, decimals, ticks, and rounding. No oracle or defended premium. |
| 7. Maximum external WETH deployed at genesis | **Approximately $1,909.09 USD-equivalent; exactly the approved `W_POL + B0`, with no other genesis deployment** | Fair-Mined TGE §§1, 6.2, 23.2. | Treat this as the genesis economic cap/target. Convert the two components once predeployment and publish the resulting WETH accounting. |
| 8. Remaining project/apDAO capital | **Strategic and undeployed at genesis** | Fair-Mined TGE §§6.2, 18, 24. | Keep it outside the Hard Reserve and genesis POL. It may later fund observed-demand actions, never unsupported minting or Reserve repair. |
| 9. Epoch duration | **50 minutes (`3,000` seconds)** | Fair-Mined TGE §§10, 24, 26.1. | Immutable `EPOCH_PERIOD = 3,000 seconds`; raw accrual is capped at one epoch. |
| 10. Price multiplier | **2×** | Production prior retained by Fair-Mined TGE §§10, 26.1. | Immutable opening multiplier; with linear decay, stationary half-decay is 25 minutes. |
| 11. Initial UPS | **4 VUX/second** | Fair-Mined TGE §§9, 23.2, 24, 26.1. | `INITIAL_UPS = 4 × 10^18` raw VUX/second, snapshotted at epoch open and always subject to the VEM cap. |
| 12. Halving cadence | **Every 30 days** | Fair-Mined TGE §§12–13, 24. | Immutable calendar cadence from the deployment-set schedule start. Unsettled opportunity expires; it does not carry. |
| 13. Number of halvings | **8** | Fair-Mined TGE §§12, 23.2, 26.1. | Cuts occur at days 30, 60, 90, 120, 150, 180, 210, and 240. |
| 14. Tail vs no-tail | **Retain a pilot-light tail** | Fair-Mined TGE §14 and preferred configuration. | Mining continues after the eighth cut; no-tail is not the frozen v1 choice. |
| 15. Tail rate | **`INITIAL_UPS / 256 = 0.015625 VUX/second`** | Fair-Mined TGE §§14, 23.2, 26.1. | Immutable maximum post-day-240 UPS; it remains subject to ordinary elapsed-time and VEM caps. |
| 16. Bootstrap King | **Ownerless Reserve** | Fair-Mined TGE §§11, 22, 26. | The Reserve is the sole bootstrap outgoing King and receives no VUX reward. |
| 17. Bootstrap clock posture | **Disabled / unclocked** | Fair-Mined TGE §§11, 22, 26. | Bootstrap `Qraw = 0`; only the first public paid takeover starts a public King's mining clock. |
| 18. Bootstrap opening target | **Approximately $50 worth of WETH** | Fair-Mined TGE §§11, 23.2, 24. | Convert once to immutable WETH predeployment and verify it remains within the initialized premium cushion. |
| 19. Minimum opening target | **Approximately $10 worth of WETH** | Fair-Mined TGE §§11, 14, 26.1. | Convert once to immutable `MIN_INIT_PRICE`; this is distinct from the decay floor. |
| 20. Decay floor target | **Approximately $1 worth of WETH** | Fair-Mined TGE §§11, 14, 26.1; Mining UX Closure §8. | Convert once to immutable positive `DECAY_FLOOR`; it is a dust/restart floor, not an emission guarantee or material anti-decay mechanism. |
| 21. Redemption fee | **0%** | Fair-Mined TGE §§1, 3, 27; closed architecture. | `REDEMPTION_FEE_BPS = 0`; pro-rata WETH redemption rounds in the Reserve's favor. |
| 22. Public TGE graduation point | **Approximately day 180** | Fair-Mined TGE §§13, 21, 24: 98.82% of the pre-tail raw window is then behind the protocol. | Publicly describe day 180 as emission graduation; do not promise that raw opportunity equals actual issued supply. |
| 23. Formal tail-start point | **Day 240** | Fair-Mined TGE §§13–14, 21, 26.1. | Days 180–240 are immutable graduation/wind-down; the eighth cut begins the formal tail. |
| 24. Initial POL deepening posture | **No automatic deepening; intentionally shallow genesis POL** | Fair-Mined TGE §§18, 24. | Canonical VUX/WETH POL uses passive/wide/simple geometry where practicable. Any later deepening requires observed-demand triggers, uses Strategic WETH plus existing or purchased VUX, and never uses a mint or Reserve principal. |
| 25. LSG launch posture | **No LSG activation at launch; defer to a threshold-gated v1.1 window** | Fair-Mined TGE §20; Architecture Convergence §§1, 15. With zero genesis user voters, calendar-only launch would elevate POL inventory or dust float. | Canonical v1 must not depend on active LSG. Future activation is conjunctive and evidence-based, not calendar-only; POL VUX must not become an apDAO voting bloc. No LSG design is authorized here. |
| 26. Founder/operator genesis compensation posture | **None** | FAIR doctrine; Fair-Mined TGE §§3, 22, 25, 27. | Zero genesis VUX, zero primary-flow claim, and no founder/operator recycle or Reserve claim. Participation may occur only through permissionless purchases/mining or future explicit secondary-revenue/business economics. |

The `1/256` tail is frozen because mining remains a VUX product pillar and a permanent permissionless pilot preserves continuity without keeping the main TGE economically open. Its maximum raw opportunity is 492,750 VUX per year, only 2.39% of the 20.655 million pre-tail window; larger tails are too material. No-tail is structurally clean but is rejected here because it permanently removes that surface, while `1/256` keeps it deliberately secondary.

### Required pre-deployment conversion procedure

Immediately before deployment, record one founder-approved WETH/USD reference price, source, and timestamp. Convert the four frozen USD-equivalent targets—POL WETH side, bootstrap opening, minimum opening, and decay floor—once into immutable WETH amounts, then derive `B0` from the actual initialized `P0` and `S0` so `P0/N0 = 1.10`; document all rounding and verify the ratio and bootstrap-cushion inequalities against final pool geometry. The conversion is a deployment calculation only: no USD oracle, refresh mechanism, or historical `$1,625/WETH` constant is permitted.

## 4. Genesis accounting

```text
Genesis VUX
├── canonical POL: 150,000 VUX
├── Reserve seed: 1 raw VUX unit
└── every discretionary/user address: 0

Total: 150,000 × 10^18 + 1 raw VUX units
```

```text
Genesis WETH
├── Hard Reserve: B0 = P0 × S0 / 1.10
│   └── economic target: approximately $909.09 USD-equivalent
├── POL WETH side: approximately $1,000 USD-equivalent
└── remaining project capital: Strategic / undeployed

Maximum external genesis deployment: W_POL + B0
Economic target: approximately $1,909.09 USD-equivalent
```

`B0` is Hard Reserve principal. POL principal is Strategic and excluded from `B`; no WETH is double-counted.

## 5. Mining/TGE schedule

The deployment sets the immutable schedule-start timestamp; the exact timestamp is not frozen here. The bootstrap is unclocked, and the first permissionless paid takeover begins the first public mining epoch.

| schedule interval | frozen UPS | cumulative pre-tail raw opportunity | lifecycle meaning |
|---|---:|---:|---|
| days 0–30 | 4 VUX/s | 10,368,000 VUX (50.20%) | launch war |
| days 30–60 | 2 VUX/s | 15,552,000 VUX (75.29%) | main distribution |
| days 60–90 | 1 VUX/s | 18,144,000 VUX (87.84%) | main distribution |
| days 90–120 | 0.5 VUX/s | 19,440,000 VUX (94.14%) | scarcity transition |
| days 120–150 | 0.25 VUX/s | 20,088,000 VUX (97.26%) | scarcity transition |
| days 150–180 | 0.125 VUX/s | 20,412,000 VUX (98.82%) | public TGE graduation center |
| days 180–210 | 0.0625 VUX/s | 20,574,000 VUX (99.61%) | graduation/wind-down |
| days 210–240 | 0.03125 VUX/s | 20,655,000 VUX (100%) | final pre-tail wind-down |
| day 240 onward | 0.015625 VUX/s (`1/256`) | not part of the main TGE; maximum 492,750 raw VUX/year | pilot-light tail |

Raw opportunity is neither promised nor guaranteed supply. Each public reign accrues at its epoch-open UPS for at most 50 minutes, settlement mints only `min(Qraw, floor(D*S/B_pre))`, and all unsupported or unsettled opportunity expires with no carry, IOU, or later revival emission.

## 6. Bootstrap

The ownerless Reserve is the unclocked bootstrap King. The initial Dutch opening is approximately `$50` worth of WETH, decaying linearly over the 50-minute epoch toward the approximately `$1` WETH decay floor; approximately `$25` at half decay is an expectation, not a guaranteed fill.

The first permissionless paid takeover mints zero VUX. Its nominal 20% Reserve leg and nominal 80% outgoing-King leg both reach the outgoing Reserve, so the entire one-time activation payment becomes Hard Reserve backing; only then does the first public King's 50-minute mining clock begin. The next opening is governed by the 2× multiplier subject to the approximately `$10` WETH minimum opening.

## 7. Decisions intentionally NOT frozen here

- Exact immutable WETH amounts produced by the required pre-deployment conversion, including the conversion source, timestamp, and final rounding.
- Exact AMM venue, fee tier/fee ownership, and tick/range geometry. The implementation decision must preserve canonical VUX/WETH POL, intentionally shallow genesis liquidity, the frozen `P0/N0`, and the preference for passive/wide/simple geometry; it may not introduce automatic deepening.
- Contract addresses and the exact protocol-owned POL custody address/position.
- Deployment timestamp/block and the corresponding exact immutable schedule-start timestamp.

These are deployment mechanics only and do not reopen the frozen tokenomics family.

## 8. Superseded recommendations

This founder freeze supersedes all earlier launch recommendations involving:

- 20 million VUX genesis supply;
- 17 million VUX public genesis allocation;
- a percentage-first 85/15 genesis capital split;
- 90-day ×5 halvings;
- a `1/32` tail; and
- a one-hour epoch, where replaced by the frozen 50-minute epoch.

The predecessor artifacts remain preserved as research history and must not be deleted or rewritten.

## 9. Handoff

This artifact is the authoritative founder parameter input for the canonical VUX v1 specification.
