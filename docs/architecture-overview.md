# VUX Architecture Overview

> **Status — 2026-08-20:** VUX v1 engineering and launch-readiness evidence are complete. Production deployment has not occurred; production addresses and final deployment inputs are not yet published.

VUX is a WETH-paid King-of-the-Hill game that distributes VUX through public competition and routes retained takeover capital between a hard redemption reserve and a separate productive treasury.

The shortest accurate mental model has three parts:

1. **The Throne** creates the player game and public distribution loop.
2. **The Aetherwell / Hard Reserve** protects a direct WETH redemption right.
3. **The Terraform Engine / Strategic Treasury** holds separate productive/risk capital.

Everything else exists to keep those three jobs coherent.

## The machine in one view

![VUX system overview showing a takeover, outgoing-player settlement, and the separate Hard and Strategic capital domains](assets/vux-system-overview.svg)

The challenger receives the throne and starts a new Blaze Clock. The outgoing Prime Blazer receives settlement. Those are different sides of the same takeover.

## One takeover, step by step

### 1. A Blazer reads the current state

The Hive Interface shows:

- the **Prime Blazer / Current King**;
- the **Power Index / Takeover Price · WETH**;
- the current price-decay path and floor;
- the King’s **Blaze Clock / Raw Clock Limit**;
- **VUX if Displaced Now**; and
- the snapshotted **Blaze Rate / raw VUX per second**.

The Blaze Clock and VUX if Displaced Now can move differently. The first is time-only. The second asks what settlement could support at the current state.

### 2. The challenger pays WETH

The takeover transaction pays the current Power Index. It is not a VUX purchase. The successful challenger receives no VUX from entering.

### 3. The outgoing King is settled

For an ordinary takeover, 80% of the payment goes to the outgoing Prime Blazer. The remaining 20% is retained by the protocol.

### 4. Retained capital routes between Hard and Strategic

Hard receives at least the accepted floor and may receive the entire retained 20% when current mining settlement needs it. Strategic receives the residual, capped at 12% of the gross payment and possibly zero.

The routing decision is deterministic and settlement-local. It does not consult market price, Strategic performance, an oracle, Signal, governance, or operator judgment.

### 5. VEM measures what actually reached Hard

The protocol measures the exact new canonical WETH that arrived in the Hard Reserve during the settlement. Strategic capital receives no issuance credit.

VEM mints the smaller of:

- the time-derived Raw Clock Limit; or
- the amount supported by the measured Hard contribution without reducing pre-settlement Hard backing per VUX.

Unsupported opportunity expires. It is never carried as debt or promised later.

### 6. The challenger becomes the new Prime Blazer

The new reign begins at its snapshotted Blaze Rate. The next Power Index opens at twice the paid takeover price, subject to the accepted minimum, then decays linearly toward the floor over 50 minutes.

## Why VUX separates Hard and Strategic

Trying to make one treasury perform both jobs would make the redemption promise depend on investment performance. VUX refuses that coupling.

### Aetherwell / Hard Reserve

- holds raw canonical RH WETH;
- backs pro-rata VUX redemption;
- provides the only capital that supports VEM issuance;
- has an ownerless core posture; and
- cannot fund Strategic risk.

### Terraform Engine / Strategic Treasury

- holds productive protocol capital;
- owns canonical POL;
- may deploy into admitted strategies under bounded authority;
- may gain or lose value; and
- may later consume Signal as a bounded allocation input.

A total Strategic loss does not create a claim against Hard. A Strategic gain does not automatically increase Hard backing.

## Genesis establishes infrastructure; competition creates user supply

Genesis creates the contracts, exact initial Hard backing, and canonical protocol-owned VUX/WETH liquidity. It gives founders, operators, developers, partners, investors, airdrops, and discretionary recipients zero VUX.

The first public paid takeover is bootstrap:

- the Reserve is the outgoing King;
- zero VUX mints;
- the first public Prime Blazer is seated; and
- the public mining clock begins.

Later public takeovers are the only v1 path that can mint VUX to users, and every mint remains subject to VEM.

## Authority and trust at a glance

The monetary core removes or minimizes authority:

- no arbitrary-call surface in the Hard Reserve;
- no administrator who can spend Reserve WETH;
- no discretionary mint path;
- no Signal access to Hard, VEM, redemption, or minting;
- no surviving temporary genesis authority; and
- exact provenance/default-deny controls over the implementation tree.

The Strategic Treasury deliberately retains bounded operational authority because productive capital must be managed. Compromise of that authority can destroy Strategic assets, but it cannot spend Hard Reserve WETH or mint VUX.

VUX is not absolutely trustless. The Hard Reserve is ownerless, while canonical RH WETH retains an external governance and upgrade trust assumption. That dependency must be disclosed wherever the ownerless Reserve promise is made.

## Current v1 versus future Signal

VUX v1 contains an inactive, bounded attachment seam for future Signal. Signal requirements/design are approved and its repository authority is frozen, but Signal implementation has not been built or activated.

Future Signal is intended to express relative preference over marginal **Strategic** allocation only. Operators continue to control strategy admission, caps, execution, recall, and emergency actions. Signal never obtains monetary-core authority.

## Continue reading

- **How Mining Works** — the player experience and a full bidding-war example.
- **Monetary Policy** — supply, backing, redemption, VEM, emissions, and adaptive routing.
- **Treasury Architecture** — the exact Hard/Strategic boundary.
- **Genesis** — why public knowledge and prefunding cannot change launch economics.
- **Security Model** — protected properties, authority, evidence, and accepted residuals.
- **Trust and Dependencies** — canonical RH WETH and external assumptions.
- **Signal and Future Architecture** — the long game, clearly separated from v1.
