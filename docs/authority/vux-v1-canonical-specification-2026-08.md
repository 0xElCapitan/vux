# VUX v1 Canonical Specification

**Date:** 2026-08-09  
**Status:** Canonical founder/product/protocol authority for VUX v1  
**Terminal state:** `SPECIFICATION_COMPLETE`

## 1. Status and authority

This document defines what VUX v1 is. It consolidates the accepted founder, product, economic, settlement, architecture, and external-trust decisions into one implementation-independent authority.

It is not a Loa PRD, a software design document, a contract decomposition, an implementation plan, a sprint plan, or a deployment record. It does not authorize Solidity, deployment, licence changes, or later product mechanisms.

The governing authority order is:

1. `vux-founder-parameter-freeze-2026-08.md` — binding founder parameters;
2. `vux-fair-mined-tge-tokenomics-reconciliation-2026-08.md` — tokenomics and mined-TGE authority;
3. `vux-mining-ux-implementation-closure-2026-08.md` — settlement, arithmetic, and mining-UX authority;
4. `vux-architecture-simplification-prior-art-convergence-2026-08.md` — architecture convergence authority;
5. `rh-chain-canonical-weth-trust-surface-2026-08.md` — canonical RH WETH trust-surface authority.

Newer and more specific decisions govern overlapping points. Earlier research remains evidence and project history, not a source from which superseded parameters may be restored.

## 2. VUX v1 in one page

VUX v1 is a one-throne, WETH-paid King-of-the-Hill game whose permissionless mining process is the public VUX token-generation and distribution event.

A public participant takes the throne by paying its current Dutch-decayed WETH price. On an ordinary displacement, 80% of that payment is recycled to the outgoing King and 20% becomes raw WETH in an ownerless Hard Reserve. The same settlement may mint VUX to the outgoing King. Time determines the maximum raw reward, but the exact amount is capped by the fresh backing that the successor's payment actually added. Unsupported VUX is never created.

Every VUX unit has the same pro-rata claim on the Hard Reserve. A holder may burn `q` VUX and receive `floor(B*q/S)` canonical RH WETH, where `B` is the Reserve's raw WETH balance and `S` is the complete VUX total supply immediately before redemption. The fee is zero. No protocol balance is excluded from `S`, and no asset outside the Reserve enters `B`.

Genesis is deliberately minimal and non-discretionary:

| destination | genesis VUX |
|---|---:|
| canonical protocol-owned VUX/WETH POL | 150,000 VUX |
| ownerless Hard Reserve | 1 raw VUX base unit |
| every user and discretionary address, in aggregate | 0 VUX |

The genesis POL receives an approximately $1,000 USD-equivalent WETH side. The initial Hard Reserve is derived so the initialized pool price divided by genesis backing per VUX is `1.10`, with an economic target of approximately $909.09 USD-equivalent. The combined external genesis deployment target is therefore approximately $1,909.09 USD-equivalent. These dollar values are one-time deployment targets, never runtime oracle rules.

After genesis, the only permitted source of new VUX is permissionless KOTH settlement through the VEM rule. Users may also acquire already-existing VUX in the open market. There is no founder, operator, apDAO, partner, investor, airdrop, public-sale, community, treasury, or other discretionary genesis allocation, and no such party receives a primary-flow share.

Mining begins only when the first public participant takes the throne. A public reign has a 3,000-second maximum raw clock, a rate snapshotted at epoch open, 30-day halvings beginning from 4 VUX per second, eight cuts through day 240, and a permanent `1/256` pilot-light tail. The public TGE graduates at approximately day 180; days 180–240 are the wind-down; day 240 begins the formal tail.

VUX v1 does not depend on active governance, meaningful fee revenue, deep liquidity, continuing mining dominance, or later financial products. Mining, POL, Strategic activity, and future LSG may fail without converting their losses or obligations into claims on Reserve principal. Redemption integrity is the hard boundary.

## 3. Product doctrine

VUX v1 makes **FAIR · SIMPLE · ELEGANT · SECURE** operational.

### FAIR

- Mining is the public TGE and distribution mechanism.
- Genesis VUX exists only for canonical protocol-owned POL and the one-raw-unit permanent Reserve seed.
- Every public participant faces the same permissionless KOTH/VEM rules.
- Users may buy already-existing VUX permissionlessly in the open market.
- No founder or selected constituency receives a free allocation, free clock, free first reign, primary-flow tax, or discretionary mint.
- Fair access does not promise equal outcomes, broad ownership, resistance to capital advantages, or resistance to automation.

### SIMPLE

The product-facing loop is:

> Take the throne. Hold it. Mine while you are King. When someone displaces you, receive recycled WETH and the VUX your reign safely settled.

Internal accounting may be sophisticated, but it must not create a new instrument or entitlement that users must learn. VUX v1 has one throne, one payment asset, one backing asset, one ordinary split, one raw clock, and one issuance cap.

### ELEGANT

One successor payment performs three jobs:

1. compensates the outgoing King;
2. adds fresh WETH backing;
3. safely creates the outgoing King's settled VUX reward.

VUX v1 does not add redundant monetary machinery where this relationship already resolves the need.

### SECURE

Hard Reserve redemption integrity outranks mining continuity, POL operation, Strategic Treasury activity, revenue routing, governance, and all future mechanisms. A failure outside the Hard Reserve must not create a discretionary claim on Reserve principal.

The four doctrines are co-equal product constraints. When system recovery would conflict with the hard redemption promise, the Hard Reserve fails closed and remains outside the recovery authority.

## 4. Scope and exclusions

### In scope for canonical v1

- the VUX token and its complete supply accounting;
- the raw-WETH Hard Reserve and pro-rata redemption;
- one KOTH/Rig throne paid in canonical RH WETH;
- the time-based mining limit and finite mined-TGE schedule;
- the VEM issuance cap;
- the ownerless bootstrap state;
- canonical protocol-owned VUX/WETH POL at genesis;
- separation of Hard Reserve backing from Strategic capital;
- minimal revenue classification and routing;
- read-only quoting/periphery needed for truthful mining UX.

These are conceptual surfaces, not a required contract count. VEM may be inline policy within the Rig. Revenue routing need not be a separate facility. Frontend quoting need not require a bespoke on-chain module. Software decomposition belongs to the later Loa SDD unless a boundary is required by this specification's observable outcomes and invariants.

### Explicitly outside v1

VUX v1 neither requires nor designs Crown Share, hVUX, Cooler-style lending, ROOT bond perks, veGIGA rewards, tournaments, multiple thrones, new emission seasons, active treasury strategies, complex YRF, new oracle systems, or an active LSG. It also does not establish deployment addresses, AMM mechanics, implementation source pins, licence compatibility, or contract architecture.

## 5. Canonical system model

The minimum conceptual components are:

| surface | canonical responsibility |
|---|---|
| VUX token | record the complete supply; permit the exact genesis mint; after genesis accept minting only from the immutable authorized mining path; support burning for redemption and revenue policy |
| Hard Reserve and redemption | hold raw canonical RH WETH; define `B`; pay fee-free pro-rata redemption; retain the permanent VUX seed; expose no discretionary principal path |
| KOTH/Rig and VEM | price and settle the one throne; collect WETH; realize the 80/20 split; cap issuance using measured backing; mint only to the outgoing King; begin the successor's epoch |
| Bootstrap state | place the ownerless Reserve on the throne without a clock and convert the first public activation payment into backing without minting VUX |
| Canonical POL | provide deliberately shallow VUX/WETH price discovery from protocol-owned Strategic capital; remain outside Hard Reserve accounting |
| Read-only periphery | report the current epoch, price, raw clock limit, and estimated settlement amount without turning an estimate into an entitlement |

Canonical monetary quantities are:

```text
S = VUX.totalSupply()
B = canonicalWETH.balanceOf(Reserve)
N = B / S                         conceptual backing per VUX
```

`S` always includes POL-held VUX, Strategic-held VUX, the Reserve seed, all mined VUX, and VUX temporarily held by any protocol component. “Circulating supply” may be an analytics label only; it has no monetary role.

`B` contains only raw canonical RH WETH already held by the Hard Reserve. POL WETH, Strategic WETH, expected revenue, fees not yet received, claims, credit, LP value, and marked assets are not backing.

## 6. Genesis state

### 6.1 VUX genesis

With 18 VUX decimals:

```text
Canonical POL        = 150,000 × 10^18 raw VUX units
Hard Reserve seed    = 1 raw VUX unit
Every user           = 0
Founders              = 0
apDAO                 = 0
Partners              = 0
Investors             = 0
Airdrop/community     = 0
Public sale           = 0
Treasury allocation   = 0
Other discretion      = 0

Genesis total supply = 150,000 × 10^18 + 1 raw VUX units
```

The 150,000 VUX is canonical protocol-owned liquidity inventory, not a user or governance allocation. The one raw unit is a permanent monetary seed held by the ownerless Reserve.

### 6.2 WETH genesis

Let:

```text
S0 = genesis total VUX supply
P0 = actual initialized marginal VUX/WETH pool price
N0 = B0 / S0
```

The frozen relationship is:

```text
P0 / N0 = 1.10
B0       = P0 × S0 / 1.10
```

The economic targets are:

| use | deployment-time target |
|---|---:|
| canonical POL WETH side | approximately $1,000 USD-equivalent |
| Hard Reserve `B0` | derived from actual `P0` and `S0`; approximately $909.09 USD-equivalent under the intended passive/symmetric comparator |
| total external genesis WETH | approximately $1,909.09 USD-equivalent, and no other genesis deployment |
| remaining project/apDAO capital | Strategic and undeployed at genesis |

Immediately before deployment, the four USD-equivalent launch targets—POL WETH side, bootstrap opening, minimum opening, and decay floor—are converted once using a founder-approved WETH/USD reference price, source, and timestamp. `B0` is then derived from the actual initialized `P0` and `S0`. Deployment validation must document rounding; verify the 1.10 relationship against actual token ordering, decimals, ticks, and initialized marginal price; and establish `BOOTSTRAP_OPENING ≤ P0 × S0 − B0`, so even the maximum bootstrap payment cannot lift backing per VUX above the initialized pool price. No USD oracle, refresh rule, historical research price, or runtime USD logic exists.

## 7. VUX supply and mint model

Genesis supply is fixed by §6. After genesis:

- new VUX may be minted only by the immutable authorized KOTH/VEM mining path;
- the mint recipient is the outgoing public King whose epoch is being settled;
- the amount is exactly the settlement result defined in §12;
- no treasury, governance, POL, Reserve, operator, migration, airdrop, recovery, or future product path may mint;
- no post-genesis free mint exists;
- no promised lifetime or circulating supply exists.

Supply may decrease through holder redemption burns, direct holder burns, and the burn of incremental VUX-denominated protocol revenue. Transfers, market purchases, and POL movements do not change `S`.

The 20.655 million figure is the cumulative pre-tail raw time opportunity, not guaranteed issuance. Actual total supply is genesis supply plus completed VEM-capped settlement mints, less burns. Weak demand produces less actual supply; it does not create deferred issuance.

Mint authority is direct and immutable after the exact genesis handoff. The absence of a recovery minter is deliberate: a Rig failure may permanently stop new issuance, but it must not compromise existing holder redemption.

## 8. Hard Reserve and redemption

The Hard Reserve is raw canonical Robinhood Chain WETH only. It is not a treasury, yield strategy, POL manager, governance executor, operational wallet, or migration staging area.

The VUX-controlled Reserve surface must be:

- ownerless;
- immutable and non-upgradeable;
- without arbitrary call, approval, or sweep capability;
- without successor or migration authority;
- without pause;
- without discretionary principal movement.

Its ordinary principal outflow is holder redemption. WETH sent to it becomes backing and cannot later be reclassified as Strategic capital or revenue working capital.

For a redemption of `q` VUX, using the state immediately before that redemption:

```text
S      = VUX.totalSupply()
B      = canonicalWETH.balanceOf(Reserve)
payout = floor(B × q / S)
fee    = 0
```

The holder's `q` VUX is burned and the holder receives `payout` WETH atomically. Rounding favors the Reserve. AMM price, POL balances, Strategic assets, and external valuations do not enter the calculation.

The permanent seed defines the last-holder behavior. The Reserve continuously retains `S_MIN = 1` raw VUX unit, and a redemption may not reduce total supply below it. Therefore every externally held VUX unit can be redeemed, while the disclosed one-unit seed remains. Because payout rounds down and `q ≤ S-S_MIN`, a full redemption of all externally held VUX leaves `S = S_MIN` and a positive WETH remainder. The monetary denominators remain live without an owner, reset, or discretionary recapitalization.

Protocol-owned POL VUX may not be redeemed against the Hard Reserve as a treasury-management operation. This restriction governs protocol conduct, not the fungible claim of a user who later acquires existing VUX from the market.

## 9. KOTH game

VUX v1 has one canonical throne.

A public participant becomes the new King by paying the current takeover price in canonical RH WETH. An ordinary paid displacement routes the full payment as follows:

```text
80% → outgoing King
20% → Hard Reserve
 0% → founder, team, developer, operator, signaler, treasury, or any other primary recipient
```

The 80% amount rounds down when the split is not exact, and the split remainder goes to the Reserve. The two legs must sum to the entire payment.

The outgoing King also receives the exact VUX reward settled for the outgoing epoch. The incoming King receives neither the outgoing recycle nor the outgoing reward. The incoming King receives the throne and begins a new epoch.

The multiplier is a takeover price-ladder multiplier, not a mining-reward multiplier.

## 10. Dutch pricing

Frozen pricing parameters are:

```text
EPOCH_PERIOD       = 3,000 seconds
PRICE_MULTIPLIER   = 2×
BOOTSTRAP_OPENING  ≈ $50 WETH-equivalent
MINIMUM_OPENING    ≈ $10 WETH-equivalent
DECAY_FLOOR        ≈ $1 WETH-equivalent
```

The ordinary successor epoch opens at:

```text
max(MINIMUM_OPENING, 2 × paid takeover price)
```

From that opening, the reference Dutch price decays linearly toward zero over 3,000 seconds and is clipped at the immutable positive decay floor. Conceptually, for eligible elapsed time `t`:

```text
price(t) = max(DECAY_FLOOR, opening × (1 − min(t, 3,000) / 3,000))
```

After the reference curve reaches the floor, the takeover price remains at the floor until displacement. The floor is a dust/restart and paid-handoff rule. It is not an issuance guarantee, an oracle price, a dynamic backing floor, or a mechanism that preserves a prior settlement quote.

The bootstrap opening is set separately and is not derived from a predecessor payment.

## 11. Mining clock and mined-TGE schedule

Mining begins when a public participant becomes King. The ownerless bootstrap King has no clock.

Each public epoch records:

- its start time;
- the UPS rate in force when the epoch opens;
- no more than 3,000 seconds of eligible raw accrual.

For an outgoing public epoch:

```text
elapsedEligible = min(elapsed since epoch start, 3,000 seconds)
Qraw             = elapsedEligible × epochUPS
```

`Qraw` is the raw clock limit: the maximum reward permitted by elapsed time. It is not VUX already owned, earned, claimable, guaranteed, or owed.

The deployment sets the immutable schedule-start timestamp. Each new epoch snapshots the then-current schedule rate. A halving does not retroactively change an already-open epoch. A reign that crosses one or more schedule boundaries still accrues only its snapshotted rate and only for 3,000 eligible seconds. Unsettled calendar opportunity and unused raw opportunity expire; neither carries forward.

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

The public TGE graduates at approximately day 180, when about 98.82% of the pre-tail raw opportunity is behind the protocol. Day 240 is the formal tail boundary. The tail preserves a small permanent permissionless mining surface; it is not a continuation of the main TGE and is not intended to remain the mature ownership thesis.

## 12. VEM

VEM is the monetary safety rule, not a separate financial product.

For the ordinary settlement currently displacing a public King, let:

```text
B_pre = Hard Reserve WETH before the current Reserve contribution
S_pre = VUX totalSupply before the current issuance
D     = exact measured fresh WETH added to the Hard Reserve by the current ordinary settlement
```

Then:

```text
Qsafe = floor(D × S_pre / B_pre)
Qmint = min(Qraw, Qsafe)
```

The implementation must use mathematically equivalent full-precision, overflow-safe arithmetic. It must not rely on overflowing 256-bit cross-products. Equality at the frontier permits the full `Qraw`. Issuance rounds down, and any calculation of a required backing contribution rounds up.

The defining economic inequality is:

```text
(B_pre + D) / (S_pre + Qmint) ≥ B_pre / S_pre
```

Equivalently, authorized issuance must satisfy:

```text
B_pre × Qmint ≤ D × S_pre
```

Therefore new issuance never reduces WETH backing per remaining VUX. Exact-frontier issuance preserves backing per VUX; clock-bound issuance below the frontier increases it.

`D` is the Reserve's exact realized balance increase attributable to the current ordinary settlement, not an assumed percentage, quoted value, AMM price, oracle valuation, or later deposit. Issuance may depend on the contribution only after it has reached the Reserve and been measured.

If the clock advertises more raw opportunity than the successor payment safely funds, only `Qsafe` is minted. The unsupported remainder does not exist. There is no carry, IOU, makeup, entitlement ledger, high-water mark, oracle-priced mint, or debt.

## 13. Greed and premium behavior

When a successor payment is large enough that:

```text
Qsafe > Qraw
```

only `Qraw` is minted. The contribution above the amount needed to support that mint remains in the Hard Reserve, increasing backing per existing VUX.

The canonical interpretation is:

> VUX does not tax greed with an extra fee. Greed capitalizes VUX through the existing 20% Reserve leg.

This statement applies to primary throne payments. VUX does not capture every market premium: secondary-market trades are transfers between holders and liquidity, and their price does not alter VEM or redemption arithmetic.

## 14. Bootstrap

Bootstrap is a distinct one-time state:

```text
outgoing King = ownerless Hard Reserve
bootstrap mining clock = disabled
bootstrap Qraw = 0
```

The first public paid takeover:

1. is permissionless and pays the then-current bootstrap Dutch price;
2. mints zero VUX, regardless of how long bootstrap remained open;
3. makes the payer the first public King;
4. begins that public King's mining epoch at the schedule rate then in force.

The nominal 20% Reserve leg and nominal 80% outgoing-King leg both terminate at the ownerless Reserve. Consequently, the entire one-time activation payment becomes Hard Reserve backing. The bootstrap does not create a founder, deployer, operator, partner, or discretionary recipient.

No person receives bootstrap WETH, bootstrap VUX, a free clock, or a free first reign.

## 15. Settlement truth

For every ordinary displacement, the protocol outcome must guarantee the following observable economic sequence:

1. identify the outgoing epoch and outgoing King;
2. fix the takeover price for the transaction;
3. establish pre-settlement `B_pre` and `S_pre` before contribution or issuance;
4. establish the outgoing epoch's `Qraw` from its start, snapshotted UPS, and 3,000-second cap;
5. collect the successor's exact WETH payment;
6. realize the complete ordinary split, with the Reserve contribution paid before issuance depends on it;
7. measure the exact realized Reserve contribution `D` and reject a mismatch;
8. determine `Qmint` under VEM;
9. mint exactly `Qmint` VUX to the outgoing King;
10. pay exactly the 80% recycle to the outgoing King;
11. begin the successor's fresh epoch with the then-current snapshotted rate and required opening price;
12. settle all authorized state, payment, backing, and issuance effects atomically, or settle none of them.

The exact software call graph and checks-effects-interactions decomposition belong to the Loa SDD. This specification fixes the economic result, ordering dependencies, atomicity, and observable facts.

Canonical settlement records must expose enough information for a user or indexer to distinguish at least the outgoing epoch and King, new King, paid price, recycle, realized `D`, `B_pre`, `S_pre`, `Qraw`, and actual `Qmint` without reconstructing an entitlement from mutable state.

## 16. POL and Strategic capital

### 16.1 Canonical genesis POL

One canonical protocol-owned VUX/WETH liquidity position exists from genesis.

```text
VUX side          = 150,000 VUX
WETH-side target  ≈ $1,000 USD-equivalent
initial P0/N0     = 1.10 target
```

Its posture is intentionally shallow, simple, and passive or wide where practicable: sufficient for price discovery, not generously capitalized for mercenary extraction. The exact AMM venue, pool type, range, fee tier, ticks, and fee ownership are not frozen here.

POL is Strategic capital, not backing:

- POL WETH never enters `B`;
- POL VUX always remains inside `S`;
- Reserve principal never funds POL;
- no post-genesis VUX mint exists for POL;
- later POL VUX must be existing VUX or VUX purchased from holders;
- returned LP principal remains Strategic principal, not revenue;
- protocol-owned POL VUX may not be redeemed against the Hard Reserve as a treasury operation.

Trading or POL failure may impair price discovery but cannot change the Reserve's accounting or holder redemption formula.

### 16.2 Strategic capital

Project or apDAO capital not used for the frozen genesis Reserve and POL deployment remains Strategic and undeployed at genesis. It is outside the Hard Reserve and outside the v1 holder promise.

More available capital does not automatically authorize deeper genesis liquidity, a larger genesis Reserve, price defense, post-launch intervention, or an additional VUX mint. Any later Strategic use requires separate authorization and must preserve every Hard Reserve, supply, and POL invariant in this document.

V1 includes no automatic POL deepening rule.

## 17. Revenue policy

VUX v1 does not depend on material secondary revenue. The launch assumption is that realized protocol revenue may be zero or negligible.

If incremental protocol revenue exists:

```text
incremental VUX revenue  → burn
incremental WETH revenue → Hard Reserve
```

Source determines classification. Returned POL principal is Strategic principal, not revenue, and may not be relabeled to obtain a Reserve or burn treatment. VUX acquired as incremental protocol revenue is burned rather than held, LP'd, redeemed, or recycled. WETH already inside the Reserve is principal and can never become revenue working capital.

V1 introduces no explicit WETH buyback, oracle-based buyback, Reserve-funded buyback, or complex YRF. The policy is intentionally boring.

## 18. User-facing mining semantics

The user interface and periphery must keep three concepts distinct.

### Mining and clock progress

“Mining” may describe the ongoing activity of holding the throne. Clock progress is monotone elapsed eligible time, capped at 3,000 seconds, together with the current epoch's snapshotted rate.

If the time-derived VUX quantity is shown, its canonical label is **raw clock limit** or **maximum from time**. It must not be called mined, earned, claimable, owned, guaranteed, or owed.

### VUX if displaced now

**VUX if displaced now** is the current estimated settlement amount under current price, Reserve, supply, and contribution conditions. It may increase before the clock/cap crossover, decrease afterward as the Dutch price falls, plateau at the floor, or decrease when backing per VUX rises. It is an estimate until a displacement transaction settles and may differ across blocks.

It must never be labelled claimable, earned, or already mined.

### VUX mined or earned

**VUX mined** and **VUX earned** refer only to VUX actually minted by completed settlement. Completed settlement records are canonical.

Canonical explanation:

> You mine while you hold the throne. The clock sets the maximum reward. Your exact VUX is settled when the next King pays, and only the amount safely backed by that payment is minted.

Analytics must distinguish genesis POL inventory, current total supply, cumulative raw opportunity, actual settlement mints, burns, and redemption burns.

## 19. Contestability and fair-distribution truth

Fair genesis does not guarantee broad distribution.

Accepted modeling shows that self-succession can dominate, whales may concentrate mining, and a monopoly miner may safely mine a large fraction of the available distribution. VEM protects monetary integrity; it does not manufacture independent competitors, equal capital, equal gas access, broad ownership, or equal outcomes.

The accurate launch claim is:

> No user received VUX at genesis. Every user-owned VUX was mined under the same public KOTH/VEM rules or purchased from existing supply in the open market.

VUX v1 must not claim to be widely distributed, anti-whale, or equal-outcome without live evidence. It does not add wallet caps, anti-whale emission formulas, identity gates, punitive primary taxes, or hidden allocations. Future campaigns or product responses to concentration remain outside v1 and may not alter this monetary settlement retroactively.

## 20. LSG compatibility boundary

LSG is not launch-critical v1.

At genesis:

```text
LSG = inactive
```

VUX v1 must operate correctly without LSG, signalers, staked governance, or governed revenue destinations.

Any future LSG-compatible surface must satisfy all of the following:

- it cannot redirect, withdraw, encumber, or vote over Hard Reserve principal;
- it cannot redirect the KOTH 20% Reserve leg;
- it may govern only separately admitted Strategic or secondary flows;
- genesis POL-held VUX may not become an apDAO-controlled genesis voting bloc;
- activation must depend on actual distribution and meaningful capital or revenue, not calendar passage alone;
- its failure must not impair redemption or change `B` or `S` accounting.

This document does not design LSG or freeze its future thresholds.

## 21. Canonical RH WETH external trust assumption

The Hard Reserve's backing asset is canonical Robinhood Chain WETH. The accepted canonical address is `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73`.

The current accepted evidence is YELLOW—an acceptable explicit external trust assumption:

- the current implementation is byte-verified canonical Arbitrum `aeWETH`;
- its current token behavior has no ordinary pause, blacklist, transfer fee, rebase, arbitrary token-level owner mint, force transfer, or transfer hook;
- `aeWETH` has a gateway-only bridge-burn primitive that can name an arbitrary account, while the currently deployed gateway constrains ordinary use to the initiating holder's balance;
- the token, its WETH gateway, and its gateway router are upgradeable infrastructure;
- a 7-of-8 Robinhood Chain authority has a direct no-delay upgrade path, notwithstanding a parallel seven-day timelock path;
- an upgrade of the token or gateway infrastructure could remove the current constraint and block, burn, freeze, or seize the Reserve's WETH;
- VUX cannot constrain, override, or provide an on-chain exit window against that external authority.

Therefore VUX must not describe the complete backing stack as trustless, immutable, or governance-free.

The canonical disclosure is:

> The VUX Hard Reserve contract is designed to be immutable and ownerless. Its backing asset is canonical Robinhood Chain WETH, which retains an external Robinhood Chain governance and upgrade trust assumption.

Ordinary RH Chain availability failures are distinct: they may delay all contract execution without changing recorded balances. The external upgrade authority is the principal-risk assumption.

## 22. Protocol invariant register

The following are load-bearing v1 requirements.

Genesis initialization must also establish the frozen `P0/N0 = 1.10` relationship after actual pool rounding and keep the maximum bootstrap opening inside the resulting premium cushion.

### Supply and issuance

1. `S` is always `VUX.totalSupply()`; every VUX unit is counted without exclusion.
2. Genesis total supply is exactly `150,000 × 10^18 + 1` raw VUX units.
3. Every user and discretionary address receives zero genesis VUX.
4. After genesis, only the immutable authorized KOTH/VEM mining path may create VUX.
5. No post-genesis free, treasury, POL, governance, recovery, migration, or discretionary mint exists.
6. Every post-genesis mint is issued only to the outgoing public King and only during successful displacement settlement.
7. Authorized issuance cannot reduce `B/S`.
8. Issuance uses the exact realized backing contribution from the current ordinary settlement, not a nominal or assumed amount.
9. The Reserve contribution is realized and measured before issuance may depend on it.
10. `Qmint` never exceeds either the outgoing epoch's `Qraw` or the exact VEM frontier.
11. Raw mining opportunity never becomes debt, carry, an IOU, a later makeup, or an entitlement ledger.
12. Halving and time transitions cannot create stale indefinite accrual: each epoch uses its stored rate for no more than 3,000 eligible seconds.
13. Bootstrap can mint no VUX.
14. Supply arithmetic and VEM arithmetic must be full-precision and overflow-safe; monetary rounding may not cross the safe frontier.

### Hard Reserve and redemption

15. `B` is always the raw canonical RH WETH balance held at the Hard Reserve and nothing else.
16. Hard Reserve principal has no discretionary outflow, arbitrary call, approval, sweep, pause, migration, successor, owner, or upgrade path.
17. Holder redemption uses pre-redemption `B` and `S`, burns the exact submitted VUX, and pays `floor(B*q/S)` WETH with zero fee.
18. Redemption does not depend on functioning mining, POL, Strategic Treasury, revenue routing, or LSG.
19. `S_MIN = 1` raw VUX unit remains permanently held by the ownerless Reserve and keeps the monetary denominator live.
20. Monetary rounding favors the Reserve and cannot reduce backing per remaining VUX.
21. Reserve principal may never be relabeled, transferred, or converted into Strategic principal or revenue working capital.

### Settlement and primary economics

22. An ordinary paid takeover routes 80% to the outgoing King, 20% to the Hard Reserve, and 0% to every other primary recipient; the Reserve receives any split remainder.
23. No founder, operator, developer, team, signaler, partner, investor, or treasury has a bootstrap or primary-flow privilege.
24. Settlement is atomic: all authorized throne, payment, backing, issuance, and epoch effects occur, or none occur.
25. The outgoing epoch and outgoing King determine `Qraw` and the mint recipient; successor state cannot rewrite them.
26. The first public activation routes its complete payment economically to the Reserve, mints zero VUX, and only then establishes the first public mining epoch.

### POL, Strategic capital, revenue, and markets

27. POL and Strategic WETH never enter Hard Reserve backing arithmetic.
28. POL and Strategic VUX never leave total-supply arithmetic.
29. No post-genesis POL action may use a VUX mint or Reserve principal.
30. Protocol-owned POL VUX may not be redeemed against the Hard Reserve as treasury management.
31. Returned LP principal remains Strategic principal and cannot be relabeled as revenue.
32. Incremental VUX revenue is burned; incremental WETH revenue enters the Hard Reserve.
33. Shallow AMM manipulation, pool failure, or secondary-market price cannot change VEM or redemption arithmetic.

### Security and trust boundaries

34. A Rig failure may halt new mining but must not intentionally halt or condition redemption.
35. Strategic, POL, revenue, governance, and future-product failures cannot create a claim on Reserve principal.
36. No v1 recovery power may weaken the ownerless, immutable Hard Reserve boundary.
37. The VUX-controlled Reserve may be described as ownerless and immutable only while the separate external RH WETH upgrade trust assumption is disclosed accurately.

## 23. Failure behavior

VUX v1 fails closed around the hard claim and does not invent emergency powers to make recovery convenient.

| condition | canonical outcome |
|---|---|
| Rig or mining path fails | new mining may halt permanently; existing VUX redemption remains independent and available subject to the chain and backing asset functioning |
| no challenger arrives | the current King remains; no new settlement occurs; no VUX becomes owed; raw accrual stops at 3,000 eligible seconds |
| weak demand | less VUX is actually issued; missed raw opportunity expires; there is no catch-up emission |
| high takeover demand | issuance remains clock-limited where `Qsafe > Qraw`; excess Reserve contribution increases backing rather than inflation |
| tail economics become unattractive | mining may become dormant; this creates no solvency problem and no right to a larger tail |
| POL is shallow, out of range, drained, paused, or unavailable | trading and price discovery may degrade; `B`, `S`, VEM, and redemption remain independent |
| Strategic Treasury loses its assets | Strategic losses remain Strategic; Reserve principal and redemption accounting are unchanged |
| revenue is zero or routing fails before receipt | v1 remains functional without expected accretion; no Reserve principal may be substituted |
| LSG is absent or fails | v1 remains functional; no hard claim changes |
| large redemptions occur | VUX and WETH leave pro rata with Reserve-favoring rounding; `B/S` does not decrease and `S_MIN` remains |
| secondary price falls below backing | permissionless holder redemption remains the hard claim; no oracle, price defense, or Reserve-funded market action is triggered |
| RH Chain is unavailable | contract actions, including redemption, are delayed with the chain; recorded balances are not thereby reclassified or lost |
| canonical RH WETH infrastructure is adversely upgraded | backing transferability or principal may fail; this is the explicitly accepted external trust risk, not a failure VUX can repair with Reserve powers |

## 24. Deployment-time reserved values

The following are intentionally outside this canonical founder behavior and will be fixed, verified, or recorded later without reopening tokenomics:

- the WETH/USD conversion source and timestamp;
- the exact immutable WETH amounts for POL, bootstrap opening, minimum opening, and decay floor;
- the exact derived `B0` after pool initialization geometry and rounding;
- the exact AMM venue and pool type;
- pool fee tier, token ordering, ticks, range, and fee ownership;
- VUX protocol deployment addresses;
- deployment block and transaction records;
- the exact schedule-start timestamp;
- final implementation commit hashes;
- final source, provenance, and dependency commit pins.

These are implementation or deployment facts. They do not reopen the 150,000-VUX POL seed, the one-raw-unit `S_MIN`, the 1.10 initial relationship, the economic deployment targets, the 80/20/0 split, the mining schedule, the VEM rule, or any other frozen v1 behavior.

## 25. Licensing and source metadata

The intended project licence is **GPL-3.0-or-later**. This is project metadata only.

Conceptual provenance includes Miner Manifold's KOTH/Rig shape, gumball6900/Fund-derived pro-rata Reserve concepts, selected Olympus policy shapes, and future LSG compatibility. This document makes no source-code ancestry census, chain-of-title conclusion, licence compatibility determination, or source-pin freeze.

No licence file or SPDX header is created or changed by this specification. A separate VUX licence/provenance/source-pin freeze must follow as its own authority node.

## 26. Future compatibility

Future VUX versions may consider LSG, Crown Share, hVUX or Cooler-shaped lending, ROOT or veGIGA integrations, tournaments, multiple thrones, new campaigns or seasons, and additional Strategic uses. V1 neither promises nor designs them.

Any later extension must preserve the all-inclusive `S`, raw-WETH `B`, ownerless Reserve, holder redemption, absence of Reserve discretion, and separation of Strategic risk from backing unless a future founder authority explicitly replaces the VUX promise. No future mechanism inherits a claim on Reserve principal merely because it benefits VUX.

## 27. Loa PRD handoff

This document is the canonical founder/product/protocol authority for VUX v1.

It is not a Loa PRD or SDD.

After the separate VUX licence/provenance/source-pin freeze is accepted, Loa must begin the development lifecycle with `/plan-and-analyze`, using this specification, the founder parameter freeze, and the licence/provenance freeze as authoritative inputs.

`/architect` must not begin until the resulting Loa PRD has been reviewed and accepted.

This specification does not begin the licence/provenance freeze, invoke `/plan-and-analyze`, invoke `/architect`, create a sprint plan, or authorize implementation.
