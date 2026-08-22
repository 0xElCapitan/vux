# VUX Glossary

> **Naming rule:** Player surfaces use lore first and protocol truth second. Lore creates identity; the second label keeps the architecture understandable without requiring prior lore knowledge.

## Core world

| Lore label | Protocol label | Meaning |
|---|---|---|
| **Aether** | **WETH** | Canonical RH WETH used to pay for takeovers and routed through VUX settlement |
| **Aetherwell** | **Hard Reserve** | Ownerless canonical WETH backing VUX redemption and supporting VEM issuance |
| **Terraform Engine** | **Strategic Treasury** | Separate productive/risk capital for POL and approved strategies |
| **Hive Interface** | **VUX Interface** | Player-facing application and truth interface; not a monetary authority |
| **VUX** | **VUX token** | Token distributed to outgoing Prime Blazers through completed, supported settlement |
| **Blazer** | **Player / contender** | A participant who challenges for or occupies the throne |

## Mining and the throne

| Lore label | Protocol label | Meaning |
|---|---|---|
| **Blazing** | **Mining** | Holding the throne while raw opportunity develops; VUX mints only at displacement |
| **Prime Blazer** | **Current King** | Current throne holder |
| **Power Index** | **Takeover Price · WETH** | Current Dutch-decayed WETH price required to take the throne |
| **Blaze ’Em** | **Take the Throne** | Action that submits the current WETH takeover payment |
| **Overpowered** | **Successful Takeover** | Completed event that settles the outgoing King and seats the challenger |
| **Scorched** | **Displaced** | Outgoing King’s state after another Blazer successfully takes the throne |
| **Reign** | **Mining Epoch** | Period from becoming King until displacement |
| **Blaze Rate** | **Raw VUX / Second** | Reign’s snapshotted raw-opportunity rate; not a guaranteed mint rate |

## Mining readouts

| Player label | Protocol meaning | Ownership state |
|---|---|---|
| **Blaze Clock / Raw Clock Limit** | Time-derived maximum `Qraw` before VEM | Not owned, earned, owed, guaranteed, or claimable |
| **VUX if Displaced Now** | Current conditional settlement estimate | Not final; may rise or fall |
| **VUX Mined / Settled VUX** | VUX actually minted after completed displacement | Final after transaction settlement |

## Monetary system

| Lore/public label | Protocol meaning |
|---|---|
| **Aetherwell Backing / WETH Backing per VUX** | `B / S`, using only canonical WETH in Hard and complete VUX supply |
| **Return to the Aetherwell / Redeem VUX** | Burn VUX for its pro-rata share of Hard Reserve WETH |
| **Overpowered Flow / Takeover Routing** | Distribution of takeover WETH among the outgoing King, Hard, and Strategic |
| **VEM** | Settlement rule limiting new VUX to what measured new Hard WETH safely supports |
| **Adaptive routing** | Deterministic movement of retained takeover capital between Hard and Strategic based on current issuance need |
| **POL** | Protocol-owned VUX/WETH liquidity held in the Strategic domain |
| **VYRF** | Accepted POL fee-value treatment: VUX-denominated value burns; WETH-denominated value accretes one-way to Hard |
| **Genesis** | Two-transaction process establishing exact supply, backing, POL, identity, and authority without surviving temporary control |

## Treasury terms

**Hard Reserve (`B`)** — raw canonical WETH physically held for pro-rata redemption. Strategic assets are excluded.

**Complete supply (`S`)** — total VUX supply, including protocol-owned VUX in POL.

**Backing per VUX (`N`)** — `B / S`. It is not VUX market price and does not include Strategic NAV.

**Strategic NAV** — analytical value of Strategic assets and positions. It may gain or lose value and is never redemption backing.

**Retained capital** — takeover WETH remaining after the outgoing-King share. It routes adaptively between Hard and Strategic.

**Dry Powder** — future Strategic allocation state meaning marginal capital should remain undeployed from discretionary risk. It is not a token or backing asset.

## Signal — future only

**Signal** — future active capital-signaling architecture for relative marginal Strategic allocation. It is inactive in VUX v1.

**Signaler** — future eligible participant who submits a valid fresh Signal allocation.

**Signal Epoch** — future 14-day period with a first-24-hour fresh-signal window.

**Shadow Signal** — unpaid observation/rehearsal before paid activation; creates no retroactive reward entitlement.

**Hardened VUX** — future lore/status for VUX satisfying Signal custody, age, fresh-signal, and commitment conditions. It is not currently a separate token or receipt asset.

**The Swarm** — future holder/signaler community language; it does not imply active v1 functionality.

## Lifecycle terms

**Implemented** — code and artifacts exist. This does not by itself mean independently reviewed, audited, or accepted.

**Launch-ready** — the accepted software, evidence, runbook, and lifecycle are complete enough to prepare production deployment.

**Production-deployed** — final operator inputs were supplied, production transactions were broadcast, and verified on-chain facts were recorded.

VUX v1 is launch-ready. It is not production-deployed.

## Language requiring qualification

**Earned** — use only for VUX actually settled/minted after a successful displacement.

**Backed** — identify canonical WETH in the Hard Reserve and exclude Strategic NAV.

**Ownerless / immutable** — name the exact VUX surface and disclose the external canonical WETH governance/upgrade assumption.

**Mining reward** — distinguish the Raw Clock Limit, live estimate, and Settled VUX.

**Governance** — do not use for VUX v1 Signal. Future Signal is bounded allocation preference plus operator execution, not unrestricted governance.

## Avoid these shortcuts

- “Takeovers buy VUX.”
- “The Blaze Clock is your balance.”
- “Strategic assets back redemption.”
- “VUX is absolutely trustless.”
- “Signal is active.”
- “Launch-ready means live.”
- “Hardened VUX is a new token.”
