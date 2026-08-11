# VUX v1 Canonical Specification — Strategic-Treasury Supersession

**Date:** 2026-08-09  
**Status:** `CANONICAL_AUTHORITY_CURRENT_ACCEPTED`  
**Operator acceptance:** 2026-08-09 — `OPERATOR_ACCEPTANCE`  
**Terminal state:** `SPECIFICATION_COMPLETE`

## 1. Status and authority

This document defines the corrected VUX v1 product. Operator acceptance was recorded on 2026-08-09, and this document supersedes `vux-v1-canonical-specification-2026-08.md` in full. The predecessor remains unchanged historical generation evidence.

This is product, monetary, and authority specification. It is not a Loa PRD, SDD, contract decomposition, storage design, implementation plan, sprint plan, deployment record, or source-reuse grant. It does not invoke a downstream lifecycle.

Current authority is, in descending precedence for overlap:

1. `vux-founder-parameter-freeze-strategic-treasury-supersession-2026-08.md`;
2. this canonical specification;
3. `vux-v1-strategic-treasury-provenance-boundary-delta-2026-08.md` over the preserved `vux-v1-licence-provenance-source-pin-freeze-2026-08.md` and `vux-v1-source-registry-2026-08.json`;
4. `vux-v1-authority-supersession-map-2026-08.md` for old-to-new disposition;
5. prior research and closure artifacts only where not superseded by the items above.

Newer and more specific authority governs overlap. No superseded parameter may be restored from an earlier artifact or the stale `grimoires/loa/prd.md`.

## 2. VUX in one page

VUX combines:

1. a permissionless WETH-paid King-of-the-Hill mining/TGE game;
2. an enforceable ownerless raw-WETH Hard Reserve;
3. a separately custodied productive Strategic Treasury;
4. bounded holder-directed Strategic allocation through LSG when activated;
5. protocol-owned VUX/WETH market infrastructure; and
6. realized economic activity that may compound Strategic capital, strengthen Hard backing, reward useful allocation, and fund legitimate operations.

The canonical framing is:

> The throne gets people in.  
> The Strategic Treasury gives them a reason to stay.  
> The Hard Reserve gives them a right to leave.

An ordinary takeover payment `P` is exhausted by the static gross split:

```text
80% -> outgoing King
 8% -> Hard Reserve, nominal minimum plus split dust
12% -> Strategic Treasury
 0% -> every other primary recipient
```

Time defines a raw maximum mining opportunity. The exact VUX issued to the outgoing King is capped by the exact WETH that the current settlement added to the Hard Reserve. Strategic capital, Strategic NAV, market price, POL, ROOT, GIGA, expected yield, and oracle marks never support issuance.

Every VUX unit participates in the same Hard Reserve claim. A holder may burn `q` VUX for `floor(B*q/S)` canonical RH WETH, using the complete pre-redemption supply `S` and raw Reserve WETH balance `B`. No Strategic asset enters `B`.

Genesis is deliberately minimal:

| destination | genesis VUX |
|---|---:|
| canonical protocol-owned VUX/WETH POL | 150,000 VUX |
| ownerless Hard Reserve | 1 raw VUX base unit |
| all users and discretionary addresses | 0 VUX |

After genesis, only permissionless KOTH/VEM settlement may mint. The approximately 20.655M pre-tail quantity is raw clock opportunity, not a target or entitlement. Weak demand produces less supply.

The Strategic Treasury receives 12% of every takeover from the first activation onward. It may remain in WETH or be deployed adaptively within admitted risk boundaries. Static monetary routing does not force deployment.

At maturity, VUX holders may use LSG to express relative preferences among admitted Strategic opportunities. Operators/risk authorities retain admission, limits, bounded execution, security, and emergency removal. LSG never controls the Hard Reserve or minting.

VUX/WETH POL is a Strategic sleeve with special fee treatment: incremental VUX fee yield is burned and incremental WETH fee yield enters the Hard Reserve. Returned LP principal remains Strategic principal. General Strategic revenue uses a disclosed operator-set policy; no exact general percentage is founder-frozen.

## 3. Product doctrine and holder promise

VUX makes **FAIR · SIMPLE · ELEGANT · SECURE** operational as co-equal constraints.

### 3.1 FAIR

- Permissionless mining is the public TGE and post-genesis issuance mechanism.
- Genesis VUX exists only for canonical protocol-owned POL and the one-raw-unit Reserve seed.
- No founder, operator, partner, apDAO, investor, user, sale, airdrop, or community allocation exists at genesis.
- No founder/operator receives a primary-flow share.
- Users may mine under the same rules or buy existing VUX openly.
- Fair access does not promise equal outcomes, broad distribution, anti-whale behavior, or resistance to capital and automation advantages.

### 3.2 SIMPLE

The product-facing launch loop is:

> Take the throne. Hold it. Mine while King. When displaced, receive recycled WETH and the VUX that the successor payment safely settles.

Strategic accounting and later LSG sit behind this loop. They must not change the user's ordinary takeover action into portfolio management.

### 3.3 ELEGANT

One successor payment compensates the outgoing King, strengthens the immutable Hard Reserve, capitalizes the productive Strategic Treasury, and safely settles the outgoing epoch's VUX within VEM.

### 3.4 SECURE

Hard Reserve integrity outranks mining continuity, Strategic performance, POL, revenue routing, governance, LSG, and recovery convenience. Failures outside the Reserve create no claim on its principal.

### 3.5 Exact holder promise

VUX holders receive:

1. a fee-free pro-rata raw-WETH redemption right against the ownerless Hard Reserve, with non-decreasing Hard `B/S` through authorized issuance; and
2. fungible exposure to protocol-owned Strategic capital and bounded holder-directed marginal allocation under disclosed policy, without a redemption guarantee against Strategic NAV.

VUX does not promise that ROOT, GIGA, POL, stable assets, expected yield, or Strategic marks are Hard backing. Public/legal characterization of Strategic and governance rights requires later jurisdiction-specific review and cannot weaken the accounting truth above.

## 4. Capability scope and phases

### 4.1 Minimum launch capability

- exact genesis supply and low-float VUX/WETH POL;
- one canonical RH WETH KOTH throne;
- static `80/8/12` settlement;
- ownerless Hard Reserve and fee-free redemption;
- Hard-only VEM and truthful mining UX;
- physically and accountingly separate Strategic receipt;
- bootstrap zero-mint behavior;
- POL principal versus fee-yield classification and the POL-special VYRF outcome;
- product-level accounting sufficient to observe Hard, Strategic, settlement, fee, and burn facts;
- inactive LSG with an explicit operator-controlled activation authority and preserved non-voting POL rule.

Before LSG activation, operators may retain raw Strategic WETH or use a narrow authorized Strategic bootstrap policy. Launch does not require complex active Strategies, ROOT/GIGA exposure, or active token voting.

### 4.2 Mature capability

- expanded protocol-owned VUX/WETH liquidity when economically attractive;
- admitted productive Strategies and ecosystem assets;
- active LSG allocation signaling when internally ready;
- realized-revenue funding for compounding, backing, operations, signalers, and market infrastructure under disclosed policy;
- verified ROOT/GIGA or other RH-native opportunities when admitted;
- adaptive portfolio construction and dry powder within frozen security boundaries.

LSG is a core mature product surface, not optional conceptual compatibility. Its activation date and mechanism are not launch-frozen.

### 4.3 Excluded or unresolved

V1 does not authorize Crown Share, hVUX, Cooler-style lending, tournaments, multiple thrones, new emission seasons, an oracle-mediated monetary router, Reserve-backed Strategy rescue, or privileged token allocation. It does not establish exact contract decomposition, custody primitive, AMM integration, LSG mechanism, keeper design, access-control primitive, dependency versions, or deployment addresses.

## 5. Roles and economic surfaces

These are conceptual responsibilities, not required contracts or addresses.

| role/surface | product responsibility | authority boundary |
|---|---|---|
| VUX token | complete supply, exact genesis mint, KOTH/VEM-only post-genesis mint, transfer, and authorized burns | no discretionary/recovery mint |
| Hard Reserve | hold raw canonical RH WETH and redeem pro rata | ownerless; no Strategic, governance, payroll, rescue, or arbitrary path |
| KOTH/Rig | operate the one throne, Dutch price, epoch, payment, split, and outgoing reward settlement | static `80/8/12`; cannot mint outside VEM |
| Strategic Treasury/custody | receive/account for the 12% leg and protocol-owned risk capital | separate from `B`; exact custody architecture reserved |
| POL | protocol-owned VUX/WETH market infrastructure | Strategic principal; no Reserve funds or post-genesis mint |
| POL fee policy | classify and route incremental fee yield by denomination | VUX burn and WETH-to-Hard; bypass general waterfall |
| General revenue policy | classify realized non-POL economics and allocate permitted uses | exact percentages operator-reserved; principal/marks excluded |
| Strategy admission/risk | diligence, admit, cap, remove, recall, and bound execution | operator/risk responsibility; cannot reach Hard Reserve |
| LSG | holder relative-allocation signal among admitted Strategies | marginal Strategic capital only; activation operator-reserved |
| Execution | carry out bounded admitted allocation | cannot expand recipients, caps, or security authority |
| Read-only periphery | truthful current epoch, price, raw opportunity, safe estimate, and accounting views | estimates create no entitlement |

“Operator,” “risk authority,” and “execution” identify product responsibilities only. Exact identities, keys, modules, governance primitives, and upgrade arrangements belong to future planning and architecture, subject to this specification.

## 6. Canonical quantities and accounting domains

```text
S     = VUX.totalSupply()
B     = canonicalWETH.balanceOf(HardReserve)
N     = B / S                         conceptual Hard WETH backing per VUX
T_nav = disclosed realizable Strategic NAV, never B
```

`S` includes every VUX unit: POL-held, Strategic-held, Reserve seed, mined, user-held, and protocol-held. “Circulating supply” is analytics only.

`B` includes only raw canonical RH WETH already held by the Hard Reserve. It excludes Strategic WETH, POL WETH, LP value, stable assets, ROOT, GIGA, receivables, fees not yet received, unrealized marks, oracles, and expected yield.

`T_nav` is an analytical and portfolio quantity. It may be haircut or reported under policy, but it never changes the Hard redemption formula or VEM.

Every inflow or return must be classified by source and economic substance as one of at least:

- Hard Reserve principal/accretion;
- Strategic contributed or returned principal;
- incremental POL fee yield by denomination;
- other realized Strategic revenue by denomination;
- unrealized Strategic mark.

Classification cannot be changed merely to fund a preferred recipient.

## 7. Genesis state

### 7.1 VUX genesis

With 18 decimals:

```text
Canonical POL       = 150,000 × 10^18 raw VUX units
Hard Reserve seed   = 1 raw VUX unit
Every user          = 0
Founders/operators  = 0
apDAO               = 0
Partners/investors  = 0
Airdrop/community   = 0
Public sale         = 0
Strategic Treasury  = 0
Other discretion    = 0

S0 = 150,000 × 10^18 + 1 raw VUX units
```

The 150,000 VUX is protocol liquidity inventory, not a voting or user allocation. The one raw unit is the permanent Reserve monetary seed.

### 7.2 WETH genesis

```text
P0 = actual initialized marginal VUX/WETH pool price
N0 = B0 / S0
P0 / N0 = 1.10
B0 = P0 × S0 / 1.10
```

| use | deployment-time target |
|---|---:|
| canonical POL WETH side | approximately $1,000 USD-equivalent |
| Hard Reserve `B0` | derived from actual `P0` and `S0`; approximately $909.09 USD-equivalent under the intended comparator |
| total external genesis WETH | approximately $1,909.09 USD-equivalent and no other genesis deployment |
| remaining project/apDAO capital | Strategic and undeployed |

Immediately before deployment, the POL WETH side, bootstrap opening, minimum opening, and decay floor are converted once using a founder-approved WETH/USD reference price, source, and timestamp. `B0` is derived from actual initialized geometry. Validation records rounding, token ordering, decimals, ticks, actual marginal price, `P0/N0 = 1.10`, and the conservative bootstrap-cushion condition `BOOTSTRAP_OPENING <= P0*S0 - B0`. No runtime USD oracle, refresh, or historical research conversion exists.

## 8. Supply, mint, and burn model

After the exact genesis mint:

- only the immutable authorized KOTH/VEM path may mint;
- every mint occurs in a successful public displacement and goes only to the outgoing public King;
- no treasury, POL, governance, Strategic, operator, migration, airdrop, recovery, recapitalization, or future-product minter exists;
- no target lifetime or circulating supply is promised.

Supply may decrease through ordinary holder redemption burns, direct voluntary burns if supported, incremental VUX POL fee-yield burns, and normally other realized VUX-revenue burns under applicable authority. Transfers, purchases, and LP movements do not change `S`.

The approximately 20.655M pre-tail figure is cumulative raw time opportunity. Actual supply is genesis supply plus completed VEM-capped mints minus burns. Unsupported or unsettled opportunity expires.

## 9. Hard Reserve and redemption

The Hard Reserve is not a treasury, Strategy, POL manager, operational wallet, governance executor, migration staging area, or emergency fund.

The VUX-controlled Reserve surface must be:

- ownerless;
- immutable and non-upgradeable;
- non-pausable;
- without arbitrary call, token approval, sweep, successor, migration, or discretionary principal movement.

For holder redemption of `q` VUX, using state immediately before redemption:

```text
S      = VUX.totalSupply()
B      = canonicalWETH.balanceOf(HardReserve)
payout = floor(B × q / S)
fee    = 0
```

The exact `q` is burned and `payout` canonical WETH is paid atomically. Rounding favors the Reserve. Strategic values and secondary-market price are irrelevant.

The Reserve permanently holds `S_MIN = 1` raw VUX. Redemption may not reduce supply below it. A full redemption of all externally held VUX leaves the denominator live and a positive WETH remainder due to Reserve-favoring rounding.

Protocol-owned POL VUX may not be redeemed as a treasury operation. This conduct restriction does not alter the fungible claim of a user who later acquires existing VUX from the market.

## 10. KOTH and Dutch pricing

VUX has one throne paid only in canonical RH WETH. A payer becomes the new King by paying the current Dutch-decayed price. The outgoing King receives the 80% recycle and the actual settled VUX reward. The incoming King receives the throne and starts a new epoch, not the predecessor reward.

Frozen pricing parameters are:

```text
EPOCH_PERIOD       = 3,000 seconds
PRICE_MULTIPLIER   = 2×
BOOTSTRAP_OPENING  ≈ $50 WETH-equivalent
MINIMUM_OPENING    ≈ $10 WETH-equivalent
DECAY_FLOOR        ≈ $1 WETH-equivalent
```

An ordinary successor epoch opens at:

```text
max(MINIMUM_OPENING, 2 × paid takeover price)
```

The reference price decays linearly for 3,000 seconds and is clipped at the immutable positive floor:

```text
price(t) = max(DECAY_FLOOR, opening × (1 - min(t, 3,000)/3,000))
```

After reaching the floor, the price remains there until displacement. The floor is a paid-handoff/dust-restart rule, not an issuance, oracle, backing, or quote guarantee. Bootstrap opening is separate from predecessor pricing.

## 11. Mining clock and fair-mined TGE

Each public epoch records its start and the UPS rate in force at opening. For an outgoing public epoch:

```text
elapsedEligible = min(elapsed since epoch start, 3,000 seconds)
Qraw             = elapsedEligible × epochUPS
```

`Qraw` is maximum opportunity from time, not VUX already earned, owned, claimable, owed, guaranteed, or debt. A halving does not alter an already-open epoch's snapshot. Unsettled calendar time and unused raw opportunity expire.

| interval from schedule start | epoch-open UPS | cumulative pre-tail raw opportunity | lifecycle |
|---|---:|---:|---|
| day 0–30 | 4 VUX/s | 10,368,000 VUX | launch war |
| day 30–60 | 2 VUX/s | 15,552,000 VUX | primary distribution |
| day 60–90 | 1 VUX/s | 18,144,000 VUX | primary distribution |
| day 90–120 | 0.5 VUX/s | 19,440,000 VUX | scarcity transition |
| day 120–150 | 0.25 VUX/s | 20,088,000 VUX | scarcity transition |
| day 150–180 | 0.125 VUX/s | 20,412,000 VUX | public TGE graduation center |
| day 180–210 | 0.0625 VUX/s | 20,574,000 VUX | wind-down |
| day 210–240 | 0.03125 VUX/s | 20,655,000 VUX | final pre-tail wind-down |
| day 240 onward | 0.015625 VUX/s (`4/256`) | maximum 492,750 raw VUX/year | pilot-light tail |

Four UPS deliberately defines a faucet, not a target supply. VEM determines actual output. Approximately day 180 is public TGE graduation; day 240 starts the formal tail.

## 12. Ordinary payment routing

For exact takeover payment `P`, with basis-point denominator 10,000:

```text
king      = floor(P × 8,000 / 10,000)
strategic = floor(P × 1,200 / 10,000)
reserve   = P - king - strategic
```

Therefore:

- outgoing King receives at most exactly 80%;
- Strategic Treasury receives at most exactly 12% under floor rounding;
- Hard Reserve receives nominally at least 8% and all split dust;
- all three legs sum to `P`;
- founders, operators, developers, signalers, and every other primary recipient receive zero.

This routing is static. KOTH settlement may not branch on time phase, macro view, VUX/ROOT/GIGA price, market price relative to backing, Strategic NAV, returns, dry powder, oracle data, or operator preference. Adaptive decisions begin only after the Strategic leg is received and classified as Strategic principal.

## 13. VEM

For the settlement displacing a public King:

```text
B_pre = Hard Reserve WETH before the current settlement contribution
S_pre = VUX.totalSupply() before the current settlement issuance
D_R   = exact realized WETH increase in the Hard Reserve caused by this settlement

Qsafe = floor(D_R × S_pre / B_pre)
Qmint = min(Qraw, Qsafe)
```

The implementation must use mathematically equivalent full-precision, overflow-safe arithmetic. Equality permits the full `Qraw`. Issuance rounds down; a required-contribution calculation rounds up.

```text
(B_pre + D_R)/(S_pre + Qmint) >= B_pre/S_pre
```

Equivalently:

```text
B_pre × Qmint <= D_R × S_pre
```

`D_R` is measured only after the current Hard leg reaches the Reserve. It is not the nominal 8%, a quote, a later deposit, market value, Strategic contribution, Strategic WETH/NAV, POL value, ROOT/GIGA value, expected yield, stable asset, or oracle mark.

If `Qraw > Qsafe`, only `Qsafe` is minted. The remainder never exists and creates no carry, IOU, makeup emission, debt, entitlement, high-water emission, or recapitalization claim.

When `Qsafe > Qraw`, only `Qraw` is minted. Excess Hard contribution increases `B/S`. Greed capitalizes both Hard and Strategic surfaces through the static split without extra issuance.

## 14. Bootstrap

Bootstrap is a distinct one-time state:

```text
outgoing King = ownerless Hard Reserve
bootstrap clock = disabled
bootstrap Qraw = 0
```

The first public paid takeover:

1. is permissionless and pays the bootstrap Dutch price;
2. applies the canonical split arithmetic;
3. routes the 80% outgoing-King leg, nominal Hard leg, and split dust to the Hard Reserve because the Reserve is outgoing King;
4. routes the 12% Strategic leg to Strategic custody;
5. mints zero VUX;
6. makes the payer the first public King and begins that King's epoch at the current schedule rate.

The one-time economic result is approximately 88% or greater Hard / 12% Strategic / zero minted VUX. No deployer, founder, operator, partner, or other person receives bootstrap WETH, VUX, a free clock, or a free reign.

## 15. Settlement truth and observable accounting

An ordinary displacement must produce the following economic result atomically:

1. identify the outgoing epoch and King;
2. fix exact payment `P`;
3. establish `B_pre` and `S_pre` before contribution or issuance;
4. calculate the outgoing epoch's `Qraw` from stored start, UPS, and the 3,000-second cap;
5. collect canonical WETH payment;
6. calculate `king`, `strategic`, and `reserve` using §12;
7. deliver/classify the Strategic principal and realize the Hard contribution;
8. measure exact `D_R` and reject an inconsistent result;
9. calculate `Qsafe` and `Qmint` under §13;
10. mint exactly `Qmint` to the outgoing public King;
11. deliver the exact recycle to that King;
12. establish the successor's epoch and opening price;
13. commit all authorized throne, payment, accounting, backing, and issuance effects, or none.

The exact call graph and checks-effects-interactions decomposition belong to `/architect`. Product observability must nevertheless let users/indexers distinguish at least:

- outgoing epoch/King and incoming King;
- exact paid price and all three routed amounts;
- `B_pre`, `S_pre`, exact `D_R`, `Qraw`, `Qsafe`, and actual `Qmint`;
- whether settlement is bootstrap or ordinary;
- Strategic contributed principal received;
- VUX supply changes and their cause.

Strategic/POL accounting must separately expose, at product-semantic level, contributed/returned principal, realized fee or revenue denomination, VUX burned, WETH sent to Hard, and general-waterfall amounts. LSG activation and allocation actions must be observable as activation state, admitted Strategy identity, bounded allocation signal/result, and responsible authority. Exact event names, indexing choices, and schema layout remain SDD decisions.

## 16. Strategic Treasury semantics

Strategic Treasury is first-class protocol-owned risk capital. Its permitted economic purposes may include:

- raw Strategic WETH and dry powder;
- WETH/stable productive Strategies;
- protocol-owned VUX/WETH liquidity;
- verified/admitted ROOT, GIGA, Stock Token, or other RH-native opportunities;
- other admitted productive assets or market infrastructure.

Strategic principal includes primary 12% contributions, externally authorized project capital, returned deployed principal, and returned LP principal. It is never Hard backing and is not revenue merely because custody changes or a position exits.

Unrealized gains and marks are not distributable realized revenue. Realized cash yield, fees, or profit are revenue only under disclosed classification policy. Noncash rewards remain Strategic inventory until realized or otherwise classified by explicit authority.

Strategic managers/operators may stage deployment, retain dry powder, adjust weights, or decline unattractive opportunities within risk and security boundaries. No fixed dry-powder or deployment cadence is canonical.

Strategic losses never:

- reduce or withdraw `B`;
- alter redemption;
- support VEM or minting;
- authorize recapitalization emission;
- create a Hard Reserve rescue entitlement;
- permit principal to be mislabeled as revenue.

If Strategic NAV reaches zero, supply accounting, Hard redemption, KOTH, VEM, and FAIR issuance remain functional subject to their own dependencies.

## 17. POL and POL-special VYRF

### 17.1 POL principal

Canonical VUX/WETH POL begins with 150,000 VUX and approximately $1,000 WETH-equivalent. It is initially shallow and intended for price discovery. Exact venue, pool type, fee tier, token order, ranges, custody, fee collection, and later deployment are reserved.

POL is Strategic capital:

- POL WETH never enters `B`;
- POL VUX always remains in `S`;
- Reserve principal never funds POL;
- no post-genesis VUX mint may fund POL;
- later POL VUX must be existing or purchased VUX;
- returned LP principal remains Strategic principal;
- protocol-owned POL VUX may not be redeemed as treasury management;
- protocol-owned POL VUX is non-voting for LSG.

Operators/cofounders may choose a large or dominant protocol share of economically active VUX/WETH liquidity when attractive. No percentage is frozen.

### 17.2 Special fee-yield treatment

Fee yield must be separated from returned principal and classified by denomination:

```text
incremental VUX-denominated POL fee yield  -> burn
incremental WETH-denominated POL fee yield -> Hard Reserve
returned LP principal                      -> Strategic principal
```

The VUX fee leg is not held, automatically re-LP'd, redeemed, recycled into mining, or counted as Strategic NAV after collection. The WETH fee leg enters Hard backing one-way and is not routed through the general waterfall. The policy applies to incremental fee yield, not principal.

This economic outcome is the POL-special VYRF. This specification does not require a particular router, contract, automated harvest cadence, or execution architecture.

## 18. General realized Strategic revenue and operations

The general realized-revenue waterfall applies only to qualifying non-POL economics. It does not receive POL fee yield governed by §17.

Frozen principles:

- returned principal is not revenue;
- unrealized marks are not distributable revenue;
- realized cash yield, fees, and profit may fund Strategic compounding, Hard accretion, legitimate operations/contributors, signalers/LSG, and market infrastructure;
- Hard Reserve principal may fund none of those uses;
- founders/operators receive no primary KOTH skim or privileged VUX allocation;
- Strategic principal may not be casually relabeled as revenue;
- VUX-denominated non-POL revenue normally burns unless later explicit authority establishes another justified treatment;
- a disclosed external startup/incubation runway may fund pre-scale work.

Operators/cofounders set and may evolve exact general-waterfall percentages, operating shares/caps/reserves, and performance terms as scale and needs become known. `50/10/25/10/5`, a 25% operator share, and a 2.5% NAV ceiling are research guidance, not canonical tokenomics or entitlements.

VUX must be capable of sustainably paying legitimate builders/operators from realized protocol economics if successful. If realized revenue is zero and external runway is exhausted, costs must contract or receive separately disclosed funding; Reserve or mislabeled principal is not a fallback.

## 19. LSG product and authority boundary

LSG's canonical mature role is:

> VUX holders direct relative marginal Strategic allocation among admitted opportunities.

Holders are suited to express relative capital preference. They do not directly manage every asset, security parameter, or transaction.

| responsibility | authority |
|---|---|
| admit/diligence/cap Strategies | operators/risk authorities |
| express relative allocation preference | eligible VUX holders under the future LSG mechanism |
| execute bounded allocation | constrained execution surface within admission and amount limits |
| emergency remove/recall | operator/risk authority under bounded policy |
| protocol upgrades and low-level security | separate authority; not ordinary LSG |
| Hard Reserve and minting | never LSG-controlled |

LSG cannot choose arbitrary recipients, withdraw/encumber Hard Reserve principal, modify KOTH routing, mint VUX, alter redemption, change VEM, set exploit response, or control ordinary upgrades.

Activation is threshold-gated and requires an affirmative operator decision. Operators may activate earlier or later depending on actual VUX distribution, Strategic capital, meaningful Strategy choice, implementation safety, and concentration. Exact days, supply, holders, participants, concentration, or capital thresholds are not frozen.

Before activation, the Strategic 12% leg remains Strategic. Protocol-owned POL VUX is always non-voting. The exact voting, weighting, epoch, delegation, anti-capture, precision, keeper, and execution mechanism belongs to later requirements/design work and must satisfy this boundary.

Signalers may be rewarded only from permitted realized protocol economics under disclosed policy. External or Strategy-funded incentives must be observable and cannot turn the admission/security boundary into token-vote control.

## 20. Bribes, ROOT/GIGA, and adaptive deployment

### 20.1 Liquidity bribes

The default posture is **own the liquidity**. Bribes are tactical experiments, not the primary liquidity strategy. They should use realized protocol economics by default, never Hard Reserve principal, measure incremental external liquidity and retention, and stop when they do not beat reasonable direct-POL alternatives. Exact size and performance hurdles are not frozen.

### 20.2 ROOT/GIGA

Founder/partner input expects ROOT to be professionally/private-managed, to support GIGA materially, and to receive 7.5% of GIGA supply at TGE; VUX may bid heavily for ROOT once facts are verified. These are partner/founder inputs, not public technical facts.

Until canonical contracts, documentation, token rights, allocation/vesting, custody, liquidity, valuation, and security evidence exist:

- ROOT/GIGA remain Strategic hypotheses/opportunities;
- neither supports `B`, redemption, VEM, or minting;
- no specific VUX allocation is required;
- no public authority may present the 7.5% claim as verified fact.

After verification and admission, operators/cofounders retain bounded portfolio judgment. Research caps of 10% pilot, 25% ROOT, and 35% aggregate look-through are guidance, not frozen parameters.

### 20.3 Dry powder and market conditions

Static `80/8/12` routing never forces immediate deployment. Strategic capital may remain raw WETH, and deployment may be staged or paused through downturns, manias, poor liquidity, weak evidence, or unattractive pricing. Research values such as 30%, 40–60%, or 10% per 30 days are not canonical.

## 21. User-facing semantics and mature ownership thesis

User interfaces and analytics must distinguish:

1. **raw clock limit / maximum from time** — time-only opportunity, never earned or owed;
2. **VUX if displaced now** — current estimate under current price, supply, Hard contribution, and VEM; may rise or fall and is not claimable;
3. **VUX mined / earned** — actual VUX minted by completed settlement only.

Canonical explanation:

> You mine while you hold the throne. The clock sets the maximum reward. Your exact VUX is settled when the next King pays, and only the amount safely backed by that payment is minted.

Analytics must separately report genesis POL inventory, current total supply, cumulative raw opportunity, completed mints, VUX burns by cause, redemption burns, Hard WETH and `B/S`, Strategic contributed principal, realized revenue, and disclosed Strategic NAV. Strategic NAV must not be labeled backing.

After the main TGE cools, VUX's ownership thesis is more than raw-WETH backing: a surviving hard exit right, protocol-owned market infrastructure, productive Strategic capital, bounded holder allocation influence, possible signaler economics, realized compounding, and verified ecosystem exposure. None of that converts Strategic risk into a Hard claim.

## 22. Contestability and distribution truth

Self-succession, whales, automation, and concentrated mining may dominate. VEM protects monetary integrity but does not manufacture competition or equal distribution.

Accurate claim:

> No user received VUX at genesis. Every user-owned VUX was mined under the same public KOTH/VEM rules or purchased from existing supply in the open market.

VUX may not claim broad distribution, anti-whale design, or equal outcomes without live evidence. Wallet caps, identity gates, anti-whale emission formulas, punitive taxes, or hidden allocations are not part of V1.

## 23. Canonical RH WETH external trust assumption

Hard backing uses canonical Robinhood Chain WETH at `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73`.

Accepted status is YELLOW:

- the current implementation is byte-verified canonical Arbitrum `aeWETH`;
- current token behavior has no ordinary pause, blacklist, fee, rebase, arbitrary token-owner mint, force transfer, or transfer hook;
- bridge infrastructure includes a gateway-only burn primitive whose current deployed gateway constrains ordinary use;
- the token, gateway, and router are upgradeable;
- a 7-of-8 Robinhood Chain authority has a direct no-delay upgrade path despite a parallel seven-day timelock path;
- a future upgrade could block, burn, freeze, or seize Reserve WETH;
- VUX cannot constrain that external authority or guarantee an exit window.

Canonical disclosure:

> The VUX Hard Reserve contract is designed to be immutable and ownerless. Its backing asset is canonical Robinhood Chain WETH, which retains an external Robinhood Chain governance and upgrade trust assumption.

VUX may not describe the full backing stack as trustless, immutable, or governance-free.

## 24. Protocol invariant register

### 24.1 Supply and FAIR issuance

1. `S` is always complete `VUX.totalSupply()` with no protocol-balance exclusion.
2. Genesis supply is exactly `150,000 × 10^18 + 1` raw VUX units.
3. Every user/discretionary address receives zero genesis VUX.
4. Only KOTH/VEM may mint after genesis, only to the outgoing public King during successful settlement.
5. No treasury, POL, governance, recovery, migration, recapitalization, or discretionary mint exists.
6. `Qmint <= Qraw` and `Qmint <= Qsafe` with full-precision safe arithmetic.
7. Bootstrap mints zero.
8. Unsupported opportunity expires without carry, IOU, debt, or entitlement.
9. Each epoch uses its snapshotted UPS for at most 3,000 eligible seconds.

### 24.2 Hard Reserve and VEM

10. `B` is only raw canonical RH WETH held by the Hard Reserve.
11. Strategic assets, NAV, POL, ROOT/GIGA, stable assets, prices, and yield never enter `B` or support minting.
12. Issuance uses the exact realized current-settlement `D_R` after it enters Hard.
13. Authorized issuance cannot reduce `B/S`.
14. Hard Reserve principal has no discretionary call, approval, sweep, pause, migration, successor, owner, or upgrade path.
15. Redemption uses pre-redemption `B` and `S`, burns exact `q`, pays `floor(B*q/S)` with zero fee, and preserves `S_MIN`.
16. Rounding favors the Reserve.
17. Reserve principal never becomes Strategic principal or revenue working capital.

### 24.3 Settlement and primary routing

18. Ordinary payment uses exact static `king=floor(80%)`, `strategic=floor(12%)`, `reserve=remainder` arithmetic.
19. Reserve receives nominally at least 8% and all split dust.
20. No other primary recipient exists.
21. Settlement is atomic and successor state cannot rewrite the outgoing epoch or mint recipient.
22. First activation sends approximately 88% or greater Hard, 12% Strategic, and mints zero.

### 24.4 Strategic, POL, revenue, and LSG

23. Strategic principal is separately accounted and cannot create claims on Hard.
24. Strategic total loss cannot change redemption, VEM, mint authority, or Reserve authority.
25. POL WETH is Strategic, and POL VUX remains in `S`.
26. No post-genesis POL VUX mint or Reserve-funded POL exists.
27. Protocol POL VUX is non-redeeming as treasury conduct and non-voting in LSG.
28. Returned LP/Strategy principal is principal, not revenue.
29. Incremental VUX POL fee yield burns; incremental WETH POL fee yield enters Hard; both bypass the general waterfall.
30. Unrealized marks are not distributable realized revenue.
31. General revenue percentages and operations caps are operator-reserved within the frozen funding boundaries.
32. LSG controls only relative marginal Strategic allocation among admitted Strategies.
33. LSG cannot reach Hard, minting, arbitrary recipients, security parameters, exploit response, or upgrades.
34. LSG activation requires affirmative operator action; no numeric readiness gate is founder-frozen.

### 24.5 Trust and provenance

35. Strategic, POL, revenue, LSG, and governance failures cannot create a Hard Reserve claim.
36. The VUX-controlled Reserve's ownerless/immutable description must always accompany the external canonical WETH YELLOW disclosure.
37. No product concept expands source-reuse authority; Strategic/LSG/VYRF code is VUX-original unless later provenance review explicitly changes that status.

## 25. Failure behavior

| condition | canonical outcome |
|---|---|
| Rig/mining path fails | new mining may halt; existing redemption remains independent subject to chain/backing-asset function |
| no challenger | King remains; raw accrual caps at 3,000 seconds; no VUX becomes owed |
| weak demand | less actual supply; missed opportunity expires |
| high takeover demand | VEM/clock cap issuance; extra Hard contribution increases `B/S`; Strategic leg remains Strategic |
| Strategic NAV falls 50%, 80%, or 100% | Hard `B`, redemption, VEM, and mint authority are unchanged; no rescue or recap mint |
| ROOT impaired or GIGA reprices | Strategic loss only; admission, position, and operator risk policy respond; no Hard claim |
| POL fails or is illiquid | price discovery and Strategic NAV may suffer; Hard arithmetic is unchanged |
| POL fee routing unavailable before receipt | no anticipated revenue is counted; principal classification remains; Hard principal is not substituted |
| realized Strategic revenue is zero | general distributions/operations receive no protocol revenue; external runway or cost reduction is required |
| LSG absent, delayed, captured, or fails | operators retain bounded pre-LSG policy/emergency responsibility; Hard and minting remain unreachable |
| voters chase bribes | only admitted/capped Strategic allocations are exposed; admission/risk authority may remove/recall |
| operations exceed realized economics | no Reserve payroll or automatic principal relabeling; costs/funding adjust |
| mass redemption while Strategic assets are illiquid | Hard pays synchronously pro rata; Strategic positions need not be sold and do not supplement payout |
| VUX below Hard backing | holder redemption remains the hard claim; no oracle price defense or Reserve-funded action triggers |
| governance wants Reserve rescue | no authorized path exists |
| recapitalization mint is proposed | no authorized path exists |
| RH Chain unavailable | actions, including redemption, are delayed with the chain; balances are not reclassified |
| canonical RH WETH adversely upgraded | transferability or principal may fail under the disclosed external trust risk; VUX cannot repair it with Reserve discretion |

## 26. Operator-reserved and deployment-time values

The following remain adaptive or later verified and do not reopen the frozen product:

- exact Strategic portfolio weights, Strategy admissions, deployment speed, and dry powder;
- exact POL allocation, venue, pool type, fee tier, token ordering, ranges, custody, and execution;
- exact LSG activation timing and internal readiness thresholds;
- exact future LSG voting, allocation, delegation, anti-capture, execution, and emergency mechanisms;
- ROOT/GIGA allocation after verified evidence and admission;
- exact general revenue percentages, operating budgets/caps, signaler rewards, bribe sizing, and tactical market infrastructure;
- conversion source/timestamp and exact immutable WETH launch amounts;
- addresses, deployment block, schedule-start timestamp, implementation hashes, dependency pins, and source records required by the SDD/provenance authority.

Research values `50/10/25/10/5`, 25%, 2.5%, fixed LSG gates, ROOT 10/25/35 caps, fixed dry-powder/deployment rules, and exact bribe hurdles are guidance only.

## 27. Licence and source boundary

Project licence remains **GPL-3.0-or-later**. Existing `LICENSE`, `THIRD_PARTY_NOTICES.md`, source pins, file allowlist, dependency-selection gates, and default-deny policy remain authoritative.

The corrected product identity does not authorize copying from Liquid Signal Governance, gumball6900, Olympus, or any research repository. Static Strategic routing/custody, Strategic accounting, POL-special VYRF routing, and future LSG are VUX-original clean-source surfaces unless a later provenance review approves an exact source. Product use of “LSG” does not change the existing pinned LSG repository's no-copy status.

The exact disposition is in `vux-v1-strategic-treasury-provenance-boundary-delta-2026-08.md` and its JSON companion. Architecture must select exact dependencies and implementation sources later; this specification does not.

## 28. Fresh PRD handoff and stop

The authorized fresh Loa `/plan-and-analyze` cycle must use this specification, the superseding Founder Parameter Freeze, the provenance authority/delta, and the supersession map. The stale `grimoires/loa/prd.md` is `SUPERSEDED_BEFORE_OPERATOR_ACCEPTANCE` and is historical generation evidence only.

The fresh PRD must preserve the answers made unambiguous here:

- VUX is KOTH + Hard Reserve + productive Strategic Treasury + bounded LSG + protocol-owned market infrastructure.
- Every ordinary payment routes `80/8/12`; no primary founder/operator share exists.
- Only exact current-settlement Hard WETH `D_R` funds issuance; no Strategic value does.
- Four UPS is raw opportunity, not promised supply.
- Bootstrap sends approximately 88% or greater Hard / 12% Strategic and mints zero.
- Strategic principal and unrealized marks are not revenue.
- POL VUX fee yield burns; POL WETH fee yield enters Hard; returned LP principal remains Strategic.
- Protocol POL VUX neither redeems as treasury conduct nor votes in LSG.
- LSG controls relative marginal allocation among admitted Strategies; operators decide activation; numeric gates are not frozen.
- General revenue percentages are not frozen.
- Total Strategic loss cannot reach or obligate the Hard Reserve.
- Mature ownership combines the hard exit right with productive, holder-directed Strategic economics.

This document does not invoke `/plan-and-analyze`, `/architect`, `/sprint-plan`, `/implement`, `/review-sprint`, or `/audit-sprint`.

**STOP. The fresh Loa cycle is authorized next but has not been invoked.**
