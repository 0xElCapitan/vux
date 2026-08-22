# VUX Security Model

> **Status — 2026-08-20:** The eight-sprint VUX v1 engineering lifecycle is closed. Review, audit, static analysis, traceability, coverage, E2E validation, and launch-readiness evidence exist for an exact landed tree. Production deployment has not occurred.

VUX security begins by deciding which properties must not depend on an operator behaving well.

The monetary core removes authority. The Strategic layer retains bounded authority because productive capital must be operated. External dependencies are disclosed rather than described away.

![VUX authority and trust boundaries separating the ownerless monetary core, bounded Strategic operation, and external canonical WETH and chain dependency](assets/security-trust-boundary.svg)

## What VUX protects

### Hard redemption integrity

- backing uses only canonical WETH physically held by the Hard Reserve;
- holders redeem pro rata by burning VUX;
- no VUX-side administrator can spend Hard WETH; and
- Strategic assets never become Reserve claims.

### Issuance integrity

- only the Rig can mint post-genesis VUX;
- only completed public displacement can trigger that mint;
- only the outgoing public Prime Blazer can receive it;
- measured new Hard WETH is the only issuance support; and
- unsupported raw opportunity expires without debt or carry.

### Capital-domain isolation

- the operator Safe controls Strategic surfaces only;
- strategy loss cannot reach Hard;
- Signal cannot reach Hard, VEM, redemption, or minting; and
- a complete Strategic loss is survivable by design.

### Genesis integrity

- deterministic identities are committed before launch;
- genesis executes atomically in a constructor;
- hostile prefunding cannot alter accepted economics;
- public future-address knowledge is assumed; and
- no temporary launch authority survives.

### Source and evidence integrity

- third-party reuse is default-deny;
- every authorized source/dependency/toolchain family is exactly dispositioned and pinned;
- reviews and audits attach to named bytes;
- negative controls prove gates can reject known-bad mutations; and
- the final lifecycle records the exact accepted implementation and authority fingerprints.

## Authority map

| Component | Privileged controller | Authority | Worst credible VUX-side result |
|---|---|---|---|
| VUX token | None | No owner/admin/pause | Core defect may halt behavior; no discretionary mint |
| Rig / Throne | None | Constants and public takeover surface | Mining may halt on defect; backing rule cannot be waived |
| Hard Reserve | None | Redemption and views only | Core defect may affect redemption availability; no admin seizure path |
| Lens | None | Stateless views | Incorrect display if defective; creates no entitlement |
| Genesis deployers | None after use | Commitment-gated one-shot / constructor-only | Failed genesis reverts or leaves inert infrastructure |
| Canonical pool | None | Protocol-fee authority unreachable | Market/liquidity risk remains; no owner extraction path |
| Strategic Treasury | Operator Safe | Typed admission, cap, deployment, recall, POL, revenue, and future-module actions | Total Strategic loss |
| Future Signal | Not active | Future Strategic-only relative allocation input | Poor Strategic preferences inside admitted bounds |

The operator Safe holds no role on VUX, Rig, Hard Reserve, or Lens. Compromising it cannot reduce Hard backing by one wei or mint one VUX through an authorized path.

## Security by removed authority

VUX does not rely on a multisig promise to leave Hard alone. The Hard Reserve exposes no administrative spending path for the multisig to call.

Similarly:

- minting is not an operator function;
- VEM is not pausable or overrideable;
- adaptive routing is deterministic;
- genesis has no callable second stage; and
- the canonical pool’s owner/protocol-fee authority is unreachable.

This posture has a cost: an immutable core defect cannot be patched through an administrator. Depending on where a defect exists, mining or redemption could halt. VUX accepts that recovery limitation and mitigates it through a small core surface, exact provenance, testing, review, audit, and adversarial rehearsal.

## Security by bounded authority

Strategic authority is operational but typed:

- strategies must be admitted;
- deployment sizes and modes are bounded;
- capital can be recalled or closed under accepted controls;
- realized revenue cannot exceed measured/accounted availability;
- one-way Hard accretion cannot pull WETH back out; and
- no generic arbitrary-call surface silently turns the Treasury into an unrestricted wallet.

The security objective is not to make Strategic loss impossible. It is to price and contain its blast radius.

## Security by exact provenance

VUX’s source boundary is part of the architecture.

The accepted controls include:

- exact repositories, commits, files, licences, and notices;
- byte-identical vendoring where required;
- separate compiler units for VUX and the canonical pool lineage;
- immutable toolchain and dependency pins;
- a source registry and licence census;
- default-deny treatment for unlisted code;
- static-analysis and coverage gates; and
- negative demonstrations that fail when a protected assumption is mutated.

Prior-art research informed architecture choices, but research access did not become blanket permission to copy implementation.

## Security evidence

The closed v1 evidence pack includes:

- independent sprint review and security-audit records;
- invariant, property, fuzz, stateful, and adversarial tests;
- assembled E2E goal validation;
- traceability from requirements to implementation and evidence;
- launch-criteria and trust sweeps;
- measured core line coverage of `598/609` lines (`98.1%`) under the accepted gate;
- static analysis against the accepted build with every baseline result dispositioned;
- licence/source-boundary censuses;
- full-knowledge genesis rehearsal; and
- exact-SHA hosted CI passing 7/7 on the accepted Sprint-8 branch and master tree.

The final Cycle-002 closeout records:

```text
implementation fingerprint
dfeb8f58e175e62a39c4b8f50ddf6dc477d6b3ba27d38620ecb65302cef07038

activated-authority fingerprint
1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437
```

Evidence reduces uncertainty; it does not prove the absence of every defect.

## Failure behavior

| Failure | Intended containment |
|---|---|
| Strategy loses 50%, 80%, or 100% | Strategic NAV falls; Hard, redemption, supply, and VEM remain unchanged |
| Operator Safe compromised | Strategic assets at risk; no core role or mint path |
| Indexer/frontend unavailable | Core continues; UI must show data unavailable rather than invent state |
| Successor never appears | No settlement mint; raw opportunity does not become debt |
| Hard transfer/delta inconsistent | Settlement fails closed |
| Genesis postcondition wrong | Atomic transaction reverts |
| Private route leaks | Confidentiality lost; genesis correctness remains |
| Canonical WETH authority acts adversely | External catastrophic risk; VUX cannot structurally prevent it |
| RH Chain unavailable | Actions delayed; balances are not reclassified by time |

## Accepted residuals

Cycle closure carries disclosed residuals rather than pretending every risk disappeared. Material public ones include:

- canonical RH WETH external upgrade authority;
- RH Chain liveness;
- total Strategic loss under operator compromise;
- permanent loss of stray non-WETH tokens sent to the ownerless Reserve; and
- production-time chain/EVM/gas and dependency re-verification obligations.

Toolchain-specific accepted residuals remain in the technical evidence pack and should not be generalized into end-user claims.

## Launch readiness is not deployment

The exact landed v1 tree is launch-ready. Production still requires:

- Q-3 production Safe composition;
- Q-4 jurisdiction-specific legal review;
- final WETH/chain/build re-verification;
- exact operator inputs and manifest approval;
- production Tx 1 and Tx 2; and
- post-deployment fact recording.

No production address or transaction should appear before those acts occur.
