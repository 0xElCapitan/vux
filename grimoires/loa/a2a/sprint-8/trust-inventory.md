# VUX v1 — Trust Inventory, YELLOW Disclosure Register, and No-Trustless-Claims Review

**Node:** `/implement sprint-8`, Task 8.7 (NFR-TRUST)
**Companion:** `grimoires/loa/a2a/sprint-8/fb-17-18-analysis.md`
**Register duty:** this file is the evidence the traceability matrix names for **INV-36** ("Sprint 8 inventory", sprint.md §D).

This is the operator-facing answer to one question: **what must you trust for VUX to behave as described, and what happens if that trust is misplaced?** It is written so a competent reviewer can answer it from artifacts alone.

---

## 1. The one-line summary that must never be softened

**VUX is not trustless.** The Hard Reserve contract is ownerless and immutable; the asset it holds is not. That external trust assumption is disclosed, never designed away.

The verbatim accepted wording, carried as a single constant at `web/lib/truth-copy.js:112-113`:

> The backing stack is not trustless. The Reserve contract is ownerless and immutable; the asset it holds is not, and that external trust assumption is disclosed above rather than designed away.

---

## 2. Trust inventory by component

Derived from the accepted trust-boundary table (`sdd.md:L360-L374`) and verified against the shipped surface by the wiring, boundary, and genesis suites.

| Component | Who must be trusted | Authority they hold | Blast radius | Colour |
|---|---|---|---|---|
| `VUX` | **nobody** | none — no owner, no admin, no pause | n/a | GREEN |
| `Rig` | **nobody** | none — constants are `constant`, no admin entry points | n/a | GREEN |
| `HardReserve` | **nobody** | none — external surface is `redeem` + views; deliberately non-pausable | n/a | GREEN |
| `Lens` | **nobody** | none — stateless views; views create no entitlement | wrong display only | GREEN |
| `VuxPoolDeployer` | **nobody** | one-shot, ownerless, commitment-gated; inert before and after | none | GREEN |
| `GenesisDeployer` | **nobody after genesis** | genesis runs in its constructor; no callable surface exists at all | a failed genesis leaves nothing | GREEN |
| Canonical v3 pool | **nobody** | `owner() == address(0)`; protocol-fee authority permanently unreachable | n/a | GREEN |
| `StrategicTreasury` | **operator Safe** | admission/caps/modes, deploy/recall/close, POL ops, LSG slot, revenue allocation, `opsRecipient` | **Strategic assets only** — total Strategic loss is survivable by design (FB-5, INV-35) | AMBER |
| Operator Safe itself | **its signers (Q-3, R-14)** | exactly the treasury-role surface above; holds **no** role on any core contract | = treasury row | AMBER |
| **Canonical RH WETH** | **7-of-8 Robinhood Chain authority** | can upgrade the token implementation on a **no-delay** path | **catastrophic-external**: could block, burn, freeze, or seize Reserve WETH | **YELLOW** |
| Robinhood Chain liveness | **chain operators** | availability only | actions delayed; balances never reclassified (FB-17) | AMBER |

**One YELLOW entry exists, and it is the only one.** Everything above it is either trustless by construction or bounded to Strategic assets.

### Why the AMBER rows are genuinely bounded

The operator Safe is the largest *internal* trust surface, and the accepted architecture spends real design effort keeping it away from the monetary core:

- it **holds no role or reference on any core contract** — verified at genesis and by negative tests (`test/genesis/GenesisWiring.t.sol`, `test/treasury/TreasurySurface.t.sol`);
- core contracts **expose no privileged entry points** for it to hold;
- `allocateRevenue` is **accumulator-bounded**, so even a fully rogue operator cannot relabel principal as distributable (`test/treasury/TreasuryRevenue.t.sol`, INV-23/24);
- the Hard-accretion leg is **one-way WETH-in**;
- worst case is total Strategic loss, which the protocol survives — that is FB-5 / INV-35, exercised at 50%, 80%, and 100% loss.

The consequence worth stating plainly: **a complete compromise of the operator Safe cannot reduce the Hard Reserve backing by one wei, and cannot mint a single VUX.**

---

## 3. The YELLOW disclosure — text, coupling, and enforcement

### The accepted verbatim text

Reproduced character-for-character from `prd.md:L722-L723`, carried once at `web/lib/truth-copy.js:105-106`:

> The VUX Hard Reserve contract is designed to be immutable and ownerless. Its backing asset is canonical Robinhood Chain WETH, which retains an external Robinhood Chain governance and upgrade trust assumption.

### The coupling rule (INV-36)

Every surface that describes the Reserve as ownerless or immutable **must** render the YELLOW text with it. The accepted implementation makes this structural rather than editorial (`sdd.md:L645`): `<ReserveDescription/>` (`web/components/ReserveDescription.jsx`) is the **only** component that renders the ownerless/immutable description, and it always renders both statements together. There is no code path that emits the first claim without the second.

That is the difference between a policy and a guarantee. A policy asks authors to remember; the single-component coupling removes the opportunity to forget.

### Accepted YELLOW facts (prd.md:L721)

| Fact | Status |
|---|---|
| Address | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |
| Current implementation | byte-verified canonical Arbitrum `aeWETH` |
| Current behaviour | no ordinary pause / blacklist / fee / rebase / arbitrary-mint / force-transfer / transfer-hook |
| Bridge infrastructure | gateway-only burn primitive, constrained by the deployed gateway |
| Upgradeability | **token, gateway, and router are all upgradeable** |
| Adverse path | **7-of-8 authority, direct no-delay upgrade** (parallel 7-day timelock path also exists) |
| Worst case | could block, burn, freeze, or seize Reserve WETH |
| VUX's ability to constrain it | **none**, and no exit window can be guaranteed |

**Deployment-time obligation (R-14, carried to the runbook):** these facts were accepted on 2026-08-09 (`prd.md:L952` records the assumption explicitly). They must be **re-verified at deployment**. If the implementation, authority set, or upgrade path has changed, the trust disclosure — and possibly the launch decision — must be revisited before launch.

---

## 4. No-trustless-claims review (NFR-TRUST)

### What is forbidden

The accepted requirement forbids describing the system as trustless, or describing the *backing stack* as immutable, while the external WETH trust assumption holds. The prohibited-phrase list is carried at `web/lib/truth-copy.js:87` and enforced mechanically.

### Mechanical enforcement

| Control | Where | What it catches |
|---|---|---|
| Prohibited-phrase list (incl. `trustless`) | `web/lib/truth-copy.js` | the vocabulary |
| Playwright copy suite | `web/tests/truth-copy.spec.js` | rendered output on every page, not just source |
| Single-component coupling | `web/components/ReserveDescription.jsx` | an ownerless/immutable claim appearing without its disclosure |
| `/trust` page | `web/app/trust/page.jsx` | the disclosure has a permanent, linkable home |

### Manual review performed at this node

Every VUX-authored surface that makes a trust claim was read and checked against the accepted wording:

| Surface | Verdict |
|---|---|
| `web/lib/truth-copy.js` | ✓ YELLOW and no-trustless constants verbatim from `prd.md:L722-L726` |
| `web/components/ReserveDescription.jsx` | ✓ couples both statements; no other component makes the claim |
| `web/app/trust/page.jsx` | ✓ discloses the external assumption without softening |
| `web/app/page.jsx`, `accounting`, `treasury`, `redeem` | ✓ no trustless claim; Reserve descriptions route through the component |
| `README.md` | ✓ no trustless claim (checked at this node) |
| `THIRD_PARTY_NOTICES.md` §6.3 | ✓ states the proprietary-dependency residual plainly rather than omitting it |
| Solidity NatSpec across `src/**` | ✓ describes *contract* immutability, which is true, and never extends it to the backing asset |

**Result: zero trustless claims; zero uncoupled ownerless/immutable descriptions.**

---

## 5. Residual register carried to launch

Bounded, accepted residuals that materially affect deployment or operation. A bounded accepted residual is allowed to remain a bounded accepted residual — this register exists so none of them is *forgotten*, not so all of them are eliminated.

| # | Residual | Severity | Disposition |
|---|---|---|---|
| R-Y1 | **Canonical RH WETH external upgrade authority (YELLOW)** — 7-of-8, no-delay, could seize/block Reserve WETH | Catastrophic-external | Unmitigable structurally. Verbatim disclosure mandatory (INV-36). Re-verify facts at deployment. See `fb-17-18-analysis.md` §FB-18. |
| R-Y2 | **RH Chain liveness (FB-17)** — actions including redemption are delayed with the chain | Liveness | No mechanism exists that could reclassify a balance in response to time or liveness. Frontend degrades to explicit "data unavailable". |
| R-Y3 | **Operator Safe compromise** — total Strategic loss | High, bounded | Cannot touch Reserve backing or mint. Survivable by design (FB-5, INV-35), exercised at 50/80/100% loss. Q-3 signer set is a launch input. |
| R-Y4 | **Proprietary non-commercial dependency in the dev/CI tree** — `@metamask/sdk` and two siblings arrive via `@wagmi/connectors`; ConsenSys Non-Commercial licence; **not distributed** (verified absent from all 38 files of the built export) | Low, disclosed | Distributed artifact is clean. Development/CI environment installs it. Recorded in `THIRD_PARTY_NOTICES.md` §6.3 and the off-chain licence census. |
| R-Y5 | **`web3` CCIP-Read SSRF (GHSA-5hr4-253g-cpx2)** in the static-analysis environment; unavoidable inside the accepted slither 0.10.x family | Medium, unreachable | Accepted residual D-S2. Structurally unreachable on the authorized local invocation; enforced by the no-RPC-environment control in `tools/provenance/verify-static-analysis.sh`. **Lapses if static analysis is ever widened to an RPC/provider path.** |
| R-Y6 | **Slither 0.10.4 predates two solc 0.8.26–0.8.28 constructs**; both verified absent from VUX source | Low, bounded | Accepted residual D-S3. 0.10.4 parsed the accepted build-info successfully at this node. No in-family fallback exists; 0.11.x would need a new operator gate. |
| R-Y7 | **Stray non-WETH tokens sent to the Reserve are permanently stuck** | Low, accepted | Accepted cost of having no sweep authority (`sdd.md:L362`). A sweep function is a seizure function. |
| R-Y8 | **Static-analysis closure is wheel-complete only on Python 3.10/3.11** — `lru-dict 1.2.0` (forced by `web3<7`) ships no cp312+ wheel | Low, operational | The gate asserts the range and fails closed. Both versions are in the ubuntu-latest tool cache. |
| R-Y9 | **RH EVM / hard-fork characterization** (Sprint 7 carry) | Informational | Recorded in the deployment runbook as a pre-launch verification item. |
| R-Y10 | **Archive-capable RPC required** for exact historical fork reproduction (Sprint 7 carry) | Informational | Runbook operator input. |
| R-Y11 | **Production block-gas / initcode limit** must be confirmed against the real chain before genesis | Operational | Runbook pre-launch check; genesis is one large creation transaction. |
| R-Y12 | **Indexer DB constraint setup requires elevated privilege** (Sprint 6 carry) | Operational | Runbook deployment step. |

---

## 6. What an operator should take from this

1. **The exit right is as strong as the design can make it.** No VUX-side actor — including a fully compromised operator Safe — can reduce backing or mint supply.
2. **One external dependency can defeat it entirely**, and it is named, quantified, and disclosed verbatim on every surface that touches the subject.
3. **Nothing in this system claims to be trustless**, and the claim is prevented mechanically rather than by editorial discipline.
4. **The residuals above are bounded and accepted, not open defects.** Each names its disposition and, where one exists, the condition under which it would stop being acceptable.
