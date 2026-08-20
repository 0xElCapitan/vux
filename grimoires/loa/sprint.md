# Sprint Plan: VUX v1 — cycle-002 "VUX v1 Strategic Treasury"

**Version:** 1.1.1 (v1.0.0 + adaptive-routing reconciliation amendment + focused revenue-surface remediation, both 2026-08-12 — Sprint 3 now implements the adaptive 8%-floor routing law; Sprint 4 Task 4.5 narrowed to the corrected four-leg P0 revenue boundary; see the amendment note below)
**Date:** 2026-08-10 (amended 2026-08-12)
**Author:** Sprint Planner Agent (Loa `/sprint-plan`, unattended operator-dispatched node); v1.1.0 amendment by the authorized consolidated reconciliation node
**Status:** `SPRINT_PLAN_ACCEPTED` (v1.0.0, 2026-08-10) — v1.1.0 renders the 2026-08-12 founder acceptance; reconciliation-package operator acceptance pending
**Operator acceptance:** 2026-08-10 — `OPERATOR_ACCEPTANCE` (v1.0.0); the v1.1.0 amendment's controlling authority is `docs/authority/vux-founder-acceptance-adaptive-routing-lsg-holder-liquidity-2026-08.md` (`FOUNDER_ACCEPTANCE_COMPLETE`)
**Cycle:** `cycle-002` (Sprint Ledger: local `sprint-1…8` = global `sprint-1…8`, 1:1)

### v1.1.0 amendment note (2026-08-12 — adaptive-routing reconciliation)

Sprint 3's objective, acceptance criteria, and Tasks 3.2/3.4/3.5 now target the **adaptive 8%-floor retained-capital routing law** (PRD FR-4 v2.1.0; SDD v1.7.0 Appendix F note F-1) instead of the superseded static `80/8/12` legs. Sprint 1 (landed `23263e18`) and Sprint 2 (landed `89a92055`) are untouched history. **`/implement sprint-3` remains blocked until BOTH independent pre-Sprint-3 conditions close:** (a) operator acceptance of the consolidated reconciliation package (authority deltas + MAP §10 + PRD v2.1.1 + SDD v1.7.1 + this plan v1.1.1, incl. the 2026-08-12 revenue-surface remediation); and (b) the M-1/L-3/L-4 provenance-tooling hardening node (Sprint-2 carry, operator acceptance 2026-08-12) — not performed by the reconciliation node. Future doctrine accepted alongside the routing law (revenue waterfall `50/25/20/5/0` + Operator Reserve, LSG 7/14 epochal doctrine, future lending/LLTV posture) adds **zero** scope to any sprint in this plan — see PRD Appendix C §§C.3–C.4 and SDD Appendix F notes F-2/F-3/F-4 for the boundary.

### Operator-accepted implementation interpretations (recorded verbatim; not a plan revision)

These clarify already-accepted authority for Sprint 1 and Sprint 4 and do not alter sprint count, boundaries, tasks, or dependencies:

1. **Sprint 1 default confirmed binding:** the VUX-original minimal test harness is the accepted approach; `forge-std` is NOT added or imported. A future narrow operator-approved provenance refreeze may authorize it only if the default becomes materially burdensome.
2. **`VuxPoolDeployer.sol` provenance classification confirmed:** when implemented (Sprint 4, Task 4.1), it is VUX-owned derivative source compiled in the pinned Solidity `=0.7.6` compilation domain — it must remain visibly distinct from the byte-identical upstream-vendored v3-core census. "Vendored unit" in this plan does not authorize modifying upstream files or placing VUX-owned derivative source inside the immutable upstream census.

## Authority Chain (binding inputs — all hashes verified at plan time)

| artifact | path | status | SHA-256 (re-pinned 2026-08-12) |
|---|---|---|---|
| PRD | `grimoires/loa/prd.md` (v2.1.1 — v2.0.0 accepted baseline `4e5cacf72d276377cb20897d9e1fe8aea721cc5edb2b0fd55e5cfde79ec89377` + adaptive-routing amendment + 2026-08-12 revenue-surface remediation) | `PRD_ACCEPTED` + amendment pending reconciliation acceptance | `791c52f2ad05c794188b218e877957889bc97b6399b965b9c5fe003ef0e2406e` |
| SDD | `grimoires/loa/sdd.md` (v1.7.1 — v1.6.0 accepted baseline `19241ed7db8a89b419e746463c6121f5b77c8237d760829e2f2604536c37392a`, which the 2026-08-12 Foundry-v1.5 toolchain note had already amended to `42785845410c9121af15aa29e18b501548d7d6e6f630f4c0c213ace36fc19cff` before this reconciliation; + adaptive-routing amendment + 2026-08-12 revenue-surface remediation) | `SDD_ACCEPTED` + amendment pending reconciliation acceptance | `b7270458e1417171dd812f34039263eca45cd676f8009dbfaf202d90aac6b175` |
| Founder acceptance (adaptive routing / LSG / holder liquidity) | `docs/authority/vux-founder-acceptance-adaptive-routing-lsg-holder-liquidity-2026-08.md` | `FOUNDER_ACCEPTANCE_COMPLETE` | `a0d5d38bf9b631a12d6f22cbe66007f9c64cdb0f43a2d9de080b5f48c8f4dac3` |
| Founder Freeze adaptive-routing delta | `docs/authority/vux-founder-parameter-freeze-adaptive-routing-supersession-2026-08.md` | `FOUNDER_AUTHORITY_CURRENT_ACCEPTED` (with base) | `89687ecc9b5ff849b2341d4684ee8e089675a776c7a5a69fc92d7dddc8892b51` |
| Canonical Specification adaptive-routing delta | `docs/authority/vux-v1-canonical-specification-adaptive-routing-supersession-2026-08.md` | `CANONICAL_AUTHORITY_CURRENT_ACCEPTED` (with base) | `04512412b416cad395e99bdb16e00b9082e3436e24369ef5b875b4f8e368c1aa` |
| Authority supersession map | `docs/authority/vux-v1-authority-supersession-map-2026-08.md` (updated §1 + §10; §10.4 revised at remediation) | `SUPERSESSION_MAP_CURRENT_ACCEPTED` | `ea07cfa200d44a99214d7332de996053312c5f4bedf68c970bc22ff3984e1f51` |
| OZ/v3 provenance refreeze | `docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md` | `PROVENANCE_REFREEZE_CURRENT_ACCEPTED` | `27aa37ec82fffaea4deb63d5ccd87f66a7e71bad1afa9e7d95d814035e8e3203` |
| Refreeze registry delta | `docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json` | `PROVENANCE_REFREEZE_CURRENT_ACCEPTED` | `db3144135251af34f6bef9da61300a2644c381c4763f2347753657de6afaf4f1` |
| THIRD_PARTY_NOTICES.md | `THIRD_PARTY_NOTICES.md` (§6/§6.1/§6.2 accepted) | accepted | `963e2cfb8fe8306ee6d2cfd6e14fa417a7a61fd7bfddc3fe5aedc2b577170873` |

The base authority set (FREEZE/SPEC/DELTA/REG/LIC/MAP per prd.md:L25-L33) governs through the PRD/SDD. This plan decides sprint structure only: it resolves **no** operator-reserved decision (PRD §16, R-1…R-14), freezes **no** research-guidance value (PRD §17), and reopens **no** accepted architecture. Any conflict resolves for the PRD/SDD.

---

## Executive Summary

Cycle-002 delivers **VUX v1 P0 launch readiness** in **8 sequential sprints**: (1) provenance-gated foundation and the first authorized vendoring; (2) the token + Hard Reserve exit-right primitives; (3) the Rig settlement/VEM engine plus the monetary invariant suite; (4) Strategic Treasury custody, classification, and authority boundaries; (5) POL, callback authentication, and VYRF; (6) truth surfaces (Lens, indexer, frontend); (7) the non-griefable genesis implementation with adversarial rehearsal; (8) launch-readiness hardening, full traceability, and end-to-end goal validation.

The cycle ends at **launch readiness**, not launch: production deployment execution (founder USD→WETH conversion, Safe facts, private-bundle submission, R-14 fact recording) is a post-cycle operator/founder action using the Sprint 8 runbook.

**Total sprints:** 8 (global IDs 1–8)
**Indicative effort:** ~33–41 focused engineering days total (per-sprint estimates below). The lifecycle is **gate-paced** — each sprint ends in review → audit → operator acceptance — so calendar dates are deliberately not fabricated; sprints are sequenced, not scheduled.
**Team assumption:** single implementing agent per sprint via `/implement`, operator as reviewer/acceptor (recorded assumption; see Appendix E).

### Material deviations from SDD §8's five-phase decomposition

SDD §8 states "Sprint granularity is refined at `/sprint-plan`; phases below are the dependency-ordered decomposition" (sdd.md:L880). Deviations and why:

1. **Phase 1 split (→ Sprints 1, 2, 3):** the provenance refreeze *execution* (byte-identical vendoring, CI drift gates, `POOL_INIT_CODE_HASH` reproduction) is its own evidence-heavy risk domain with its own reviewer mindset (licence/census exactness, not Solidity). Mixing it with monetary-core code would blur both reviews. Sprint 1 is provenance only.
2. **Whole-contract sprint ownership:** Phase 1 put `VUX.sol` with Rig pricing and Phase 2 finished Rig + Reserve. Instead: Sprint 2 = `VUX.sol` + `HardReserve.sol` complete (the two "narrow-authority twins" — mint=rig, burnForRedemption=reserve); Sprint 3 = `Rig.sol` complete. No contract is half-built across a sprint boundary, so each audit reads a whole surface.
3. **Phase 3 split (→ Sprints 4, 5):** the treasury bundles three risk domains; ~15 tasks in one sprint would breach the reviewability bar. Sprint 4 = custody/accounting/authority (classification is arithmetic); Sprint 5 = POL/callbacks/VYRF (v3 integration correctness). Both audits stay single-domain.
4. **`VuxPoolDeployer.sol` pulled forward from Phase 5 into Sprint 4:** the treasury constructor *verifies* `POOL.factory() == VUX_POOL_DEPLOYER` and `owner() == address(0)` (sdd.md:L140), so treasury tests need the real pool-deployment primitive. Building it in Sprint 4 avoids mock-weakened constructor verification; its genesis-context proofs re-run in Sprint 7.
5. **Phase 5 split (→ Sprints 7, 8):** the operator brief requires genesis to be "a dedicated, evidence-heavy implementation boundary". Sprint 7 is exactly the genesis security closure (implementation + wiring proofs + adversarial rehearsal); Sprint 8 is launch-readiness closure (static analysis, traceability, runbook, E2E). Merging them would put ~14 tasks and two review mindsets in one audit.
6. **Off-chain provenance gates placed at first use** (refreeze §9): Sprint 6 opens with the ponder/Next.js/React/viem/wagmi/Playwright/PostgreSQL pin gate; Sprint 8 opens with the slither gate. Nothing off-chain is installed before its operator-accepted pin set exists.

---

## Sprint Overview

| Sprint (global=local) | Theme | Key deliverables | Depends on |
|---|---|---|---|
| 1 | Provenance-gated foundation & authorized vendoring | Foundry dual-unit scaffold; OZ 28-file + v3-core 32-file + Miner 3-file byte-identical vendoring; fail-closed CI (drift, pins, SPDX, quarantine, `POOL_INIT_CODE_HASH`) | — |
| 2 | VUX token & Hard Reserve (exit-right primitives) | `VUX.sol`, `HardReserve.sol` complete; redemption property suite; constructor sanitization proofs | 1 |
| 3 | Rig: throne, settlement, VEM + monetary invariant suite | `Rig.sol` complete (pricing, schedule, 13-step `take`, bootstrap); INV-1…22 stateful invariant harness; FB scenario tests | 2 |
| 4 | Strategic Treasury I: custody, classification, authority | `VuxPoolDeployer.sol`; treasury custody/roles/admission/modes/revenue bounds; LSG P0 activation authority; INV-23…34 handlers | 3 |
| 5 | Strategic Treasury II: POL, callbacks, VYRF | POL position ops; one-shot callback authentication + negative suite; `harvestPol` VYRF; fee/principal invariant | 4 |
| 6 | Truth surfaces: Lens, indexer, truthful UX | Off-chain provenance gate; `Lens.sol`; event completeness audit; ponder+PostgreSQL indexer + reconstruction test; frontend + Playwright copy suite | 5 |
| 7 | Genesis: non-griefable launch + adversarial rehearsal | Q-6 evidence; `GenesisDeployer.sol`; wiring proof suite; full-knowledge adversarial rehearsal; genesis evidence pack | 6 |
| 8 | Launch readiness: hardening, traceability, E2E | Slither gate + triage; 37-INV/18-FB traceability matrix; §20.1 sweep; release compliance; deployment runbook (Q-3 input slot); Task 8.E2E goal validation | 7 |

**Sequencing rationale:** provenance before any code (nothing exists to contaminate); monetary core before treasury (Rig routes the Strategic residual leg treasury tests consume); treasury before POL (POL is a treasury sleeve); all contracts before truth surfaces (Lens/indexer read them); everything before genesis (GenesisDeployer deploys the full set, Lens included at nonce 5); genesis before readiness (the §20.1 sweep needs rehearsal evidence). The two genuinely-open technical risks land early-mid: provenance/toolchain fidelity (Sprint 1) and v3 integration (Sprints 4–5).

---

## P0 / P1 Boundary (explicit)

**In cycle-002 (P0, per prd.md:L828):** FR-1…FR-11 complete; FR-12 boundary (accounting + `allocateRevenue` bounds + negative tests — no policy *use*); FR-13 boundary + activation authority (slot, `activateLSG`/`deactivateLSG`, `ILSGModule` interface, `deployMarginalBySignal` **code**, treasury-side POL-non-voting rule, INV-32…34 negatives — LSG ships **inactive**); FR-14; FR-15; FR-16 boundaries; FB-1…18 per assigned method; NFRs; §13 disclosures; PROV-1…9 gates.

**Excluded from cycle-002 (P1, per sdd.md:L909 and prd.md:L830-832):** `LSGSignals` module implementation (stake/signal + reward-program engine) and its boundary/reward test suite; production strategy adapters; first general-waterfall *use*; the future Operator Reserve credit/accumulation/sweep/allocator-exclusion mechanics (design obligation before the founder-accepted `50/25/20/5/0` waterfall activates — 2026-08-12 remediation); POL expansion tooling; ROOT/GIGA adapters (each additionally behind verification + provenance refreeze, F-53/PROV-6); signaler economics in operation; bribe experiments. P1 plugs into the P0 slots (`lsgModule`, admission registry, `signalerBudget` earmark) with **zero P0 contract changes** — the P0 interfaces, activation slots, accounting surfaces, and negative tests that make this true are in Sprints 4–5.

**Boundary tripwires (enforced every sprint):** any task that would implement P1 mechanism, resolve an operator-reserved value (R-1…R-14), or promote a §17 research value into code/parameters is out of scope for this cycle and must be rejected at review. The §17 quarantine grep runs in CI from Sprint 1.

---

## Native Lifecycle & Artifact Handoff (applies to every sprint)

Per sprint N (global = local for this cycle):

1. **`/implement sprint-N`** — input: this file (`grimoires/loa/sprint.md`) + `grimoires/loa/sdd.md` + `grimoires/loa/prd.md`. Beads tasks for sprint N (labels `sprint:N`, epic per sprint) are pre-created by this node; `/implement` manages their lifecycle natively. Output: implementation + tests + report at `grimoires/loa/a2a/sprint-N/reviewer.md` (AC verification table validated by `validate-ac-verification.sh` before any `COMPLETED` marker).
2. **`/review-sprint sprint-N`** — input: `a2a/sprint-N/reviewer.md` + the actual tree. Output: `grimoires/loa/a2a/sprint-N/engineer-feedback.md` ("All good" + sprint.md checkmarks on approval; findings otherwise → back to `/implement`).
3. **`/audit-sprint sprint-N`** — input: reviewed tree + review artifact. Output: `grimoires/loa/a2a/sprint-N/auditor-sprint-feedback.md` (`APPROVED` verdict + `COMPLETED` marker on approval; `CHANGES_REQUIRED` otherwise → back to `/implement`).
4. **Operator acceptance stop** — operator reviews the audit-approved tree + evidence and explicitly accepts. **No sprint proceeds past this stop implicitly.**
5. **Landing** — commit on the sprint branch → branch CI green → direct-FF landing to `master` → post-merge verification (CI re-run + artifact hash spot-check).

**Post-audit mutation rule (binding):** after ANY post-audit implementation mutation, the resulting exact tree is re-audited before acceptance/commit — a narrow re-audit scoped to the mutation is acceptable; skipping audit is not.

**Branch hygiene:** sprint branches may remain until cycle completion; administrative closeout/pruning is batched at cycle end (Sprint 8 prepares the list; `/ship`-time execution). No per-sprint pruning ceremony.

**Review/audit freshness guard:** review and audit MUST consume the `a2a/sprint-N/` artifacts for the sprint under review (global-ID dirs, populated by the ledger-aware skills) — never the legacy un-suffixed `a2a/*.md` paths, which do not exist in this repo.

**Cross-sprint invariant suite ownership:** the forge stateful-invariant harness is **introduced** in Sprint 3 (Task 3.5, INV-1…22) and **extended** in Sprint 4 (Task 4.8, INV-23/24/28/30/31/32/33/34) and Sprint 5 (Task 5.5, INV-25/26/27/29 + VYRF ordering). The genesis rehearsal harness is introduced in Sprint 7. Later sprints run the full accumulated suite in CI; a sprint that breaks an earlier invariant fails its own gate.

---

## Operator Gates & Open Facts (preserved, not resolved)

| Gate | Where | What the operator supplies / decides | Blocking behavior |
|---|---|---|---|
| **New-dependency hard gate** (standing) | any sprint | Any smart-contract source outside the accepted census (refreeze §3/§4 + Miner 3-file allowlist) requires an operator-accepted provenance refreeze **before use** | Fail-closed halt; never silently added |
| **Test-harness provenance decision** | Sprint 1 (Task 1.2) | Default (no decision needed): VUX-original minimal test base (zero new source). Option: operator-accepted narrow `forge-std` refreeze delta if preferred | Default proceeds without operator action; the option is a HITL stop |
| **Off-chain provenance refreeze** (refreeze §9) | Sprint 6 (Task 6.1) | Accept exact pins for ponder / Next.js / React / viem / wagmi / Playwright / PostgreSQL | No off-chain install/use before acceptance |
| **Static-analysis provenance refreeze** (refreeze §9) | Sprint 8 (Task 8.1) | Accept exact slither (and any added CI toolchain) pin | No slither use before acceptance |
| **Q-6 — RH native asset / `WETH.deposit()` fact** | Sprint 7 (Task 7.1) | Review fork-rehearsal evidence that canonical WETH wraps native value in-transaction | If the fact fails: STOP → operator transition to the accepted fallback (pre-approval funding flow + §1.7 private-submission control, sdd.md:L974) before Sprint 7 continues |
| **Q-3 — operator Safe composition** | Sprint 8 (runbook input slot) | Signer set / threshold (deployment fact, R-14) | Blocks **production launch execution only** — never blocks any sprint's implementation (rehearsals use rehearsal values) |
| **Q-4 — jurisdiction-specific legal review** | parallel to Sprints 6–8 | Launch-adjacent legal review of Strategic/governance characterization (NFR-COMP-3) | Blocks **public launch**, not code; tracked in the Sprint 8 runbook as a pre-launch condition |
| **Per-sprint acceptance** | every sprint | Accept the audit-approved tree; authorize landing | Sprint N+1 does not start before sprint N acceptance |
| **Pre-Sprint-3 binding conditions (2026-08-12)** | before `/implement sprint-3` | (a) Accept the consolidated adaptive-routing reconciliation package (authority deltas + MAP §10 + PRD v2.1.1 + SDD v1.7.1 + this plan v1.1.1, incl. the revenue-surface remediation); (b) close the independent M-1/L-3/L-4 provenance-tooling hardening node (Sprint-2 carry) | BOTH block `/implement sprint-3`; neither is waived, folded into another node, or performed by the reconciliation node |
| **Deployment-time founder facts** (R-14) | post-cycle | Fee tier/tickSpacing, one-shot USD→WETH conversions, launch identity/secrets, Safe facts, schedule start | Recorded at deployment per the Sprint 8 runbook; never frozen in this plan |

---

## Sprint 1: Provenance-Gated Foundation & Authorized Vendoring

**Duration:** ~3–4 focused engineering days (indicative)
**Scope:** LARGE (8 tasks)

### Sprint Goal
Stand up the Foundry repository with the accepted provenance authority mechanically enforced — every authorized upstream file vendored byte-identically, every fail-closed CI gate live — so that no later sprint can drift from the accepted census even by one byte.

### Deliverables
- [x] Foundry scaffold with dual compilation units: `=0.8.28` (VUX-original + Miner-derived) and `=0.7.6` vendored v3 unit with the exact refreeze §7 build settings (optimizer 800, `evm_version = "istanbul"`, `bytecode_hash = "none"`); Foundry pinned `v1.0.0` → `8692e926…` (refreeze §6)
- [x] Vendored source: exactly 28 OpenZeppelin v5.2.0 files (refreeze §3), exactly 32 Uniswap v3-core v1.0.0 files (refreeze §4), exactly 3 Miner Manifold files @ `bcffbf1e…` (PROV-2) — byte-identical, upstream SPDX retained
- [x] Fail-closed CI: per-file byte-identity drift gate vs. the accepted registry, 40-char pin lint, mutable-URL detector, unauthorized-file detector, `POOL_INIT_CODE_HASH` recomputation, SPDX lint, TPN/LICENSE integrity, §17 quarantine grep
- [x] Test harness with zero unauthorized source (default: VUX-original minimal base)

### Acceptance Criteria
- [x] Census exactness: repository contains exactly 28 + 32 + 3 vendored upstream files; per-file SHA-256 equals the accepted registry values (`docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json`); zero unenumerated upstream source anywhere
- [x] Drift gate demonstrated fail-closed: a 1-byte mutation of any vendored file makes CI fail (negative demonstration recorded in the sprint report)
- [x] `POOL_INIT_CODE_HASH` reproduced in CI from the vendored `=0.7.6` unit and equal to `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` (refreeze §7 obligation 1) — CI fails closed on mismatch
- [x] No `UniswapV3Factory.sol` implementation, no v3-periphery file, no non-allowlisted Miner file present (refreeze §8) — enforced by the unauthorized-file detector
- [x] §17 research-guidance quarantine grep live and green (prd.md:L818)
- [x] `foundry.toml` carries both solc pins (`7893614a…`, `7338295f…`); CI fails on any missing/short/mismatched pin (PROV-9)
- [x] `.gitignore` excludes `broadcast/**` production artifacts per the sdd.md:L270 launch-secret posture
- [x] Zero new dependencies beyond the accepted census (test harness included)

### Technical Tasks
- [x] Task 1.1: Foundry scaffold — dual-profile `foundry.toml` (`=0.8.28` main; `=0.7.6` vendored unit with refreeze §7 settings), `src/test/script` layout, remappings, `broadcast/**` gitignore hygiene → **[G-5]** ⇐ none
- [x] Task 1.2: Test-harness provenance decision — implement the VUX-original minimal test base (Vm cheatcode interface + assertion helpers; zero new upstream source); record the optional operator `forge-std` refreeze path as NOT taken unless the operator decides otherwise → **[G-5]** ⇐ Task 1.1
- [x] Task 1.3: Vendor OpenZeppelin v5.2.0 — the exact 28-file census of refreeze §3 from commit `acd4ff74de833399287ed6b31b4debf6b2b35527`, byte-identical, MIT SPDX retained → **[G-5]** ⇐ Task 1.1
- [x] Task 1.4: Vendor Uniswap v3-core v1.0.0 — the exact 32-file census of refreeze §4 from commit `e3589b192d0be27e100cd0daaf6c97204fdb1899`, byte-identical, per-file SPDX retained (9 BUSL-1.1 / 22 GPL-2.0-or-later / 1 MIT) → **[G-5]** ⇐ Task 1.1
- [x] Task 1.5: Land the 3 allowlisted Miner Manifold files (blob-pinned per PROV-2) byte-identical as derivation reference, with notices → **[G-5]** ⇐ Task 1.1
- [x] Task 1.6: Fail-closed provenance CI (PROV-9): per-file SHA-256 drift gate vs. registry, 40-char pin lint, mutable-URL detector, unauthorized-file detector, TPN/LICENSE presence+integrity checks, §17 quarantine grep; include the 1-byte-mutation negative demonstration → **[G-5]** ⇐ Task 1.3, Task 1.4, Task 1.5
- [x] Task 1.7: `POOL_INIT_CODE_HASH` deterministic recomputation in CI from the vendored unit; assert equality with the accepted constant (refreeze §7) → **[G-5, G-1]** ⇐ Task 1.4
- [x] Task 1.8: SPDX lint per PROV-8 policy (VUX-original `GPL-3.0-or-later`; Miner-derived `MIT AND GPL-3.0-or-later`; upstream retained; no invented holders) → **[G-5]** ⇐ Task 1.6

### Dependencies
- Accepted refreeze authority (already `PROVENANCE_REFREEZE_CURRENT_ACCEPTED`) — authorizes exactly this import surface; nothing else
- Optional operator gate: `forge-std` decision (default path needs no operator action)

### Security Considerations
- **Trust boundaries:** upstream fetch is the only external input — pinned commits only, verified by per-file hash against the accepted registry; tags/branches are never authority (PROV-6)
- **External dependencies:** this sprint IS the dependency import; everything else in the cycle builds on its gates
- **Sensitive data:** none; CI must not require secrets

### Risks & Mitigation
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Vendoring mangles bytes (CRLF, encoding) breaking census hashes / `POOL_INIT_CODE_HASH` | Medium | High | `core.autocrlf=false` discipline per refreeze §7; per-file SHA-256 gate catches any mangling immediately |
| Compiler-settings drift silently changes pool bytecode | Low | High | Refreeze §7 obligation 3: any settings change requires a new refreeze; CI recomputation makes drift loud |
| Test-harness scope creep pulls in unauthorized source | Medium | Medium | Default VUX-original harness; hard-gate rule; unauthorized-file detector |

### Success Metrics
- CI pipeline green with all 7 gate classes active; drift gate negative-demonstrated
- 28/32/3 file counts exact; 100% per-file hash match vs. registry
- `POOL_INIT_CODE_HASH` equality reproduced in CI (not just recorded)

---

## Sprint 2: VUX Token & Hard Reserve (Exit-Right Primitives)

**Duration:** ~3–4 focused engineering days (indicative)
**Scope:** MEDIUM (6 tasks)

### Sprint Goal
Ship the two narrow-authority immutable primitives — the VUX token (mint=rig, burnForRedemption=reserve, no `burnFrom`) and the ownerless Hard Reserve with one-transaction approval-free redemption and constructor-time contamination sanitization — with their exact-math and authority-gate proofs.

### Deliverables
- [x] `VUX.sol` complete (adapted from allowlisted `Unit.sol`/`IUnit.sol`): ERC20+Permit, constructor genesis mint semantics (`150_000e18` to creator + 1 raw to reserve), `mint` onlyRig, `burn`, `burnForRedemption` onlyReserve, **no** general `burnFrom` (sdd.md:L97)
- [x] `HardReserve.sol` complete: `redeem(q, to)` one-tx approval-free (CEI, `nonReentrant`, `floor(B×q/S)`, zero fee, `S_MIN`), views, constructor sanitization (born-empty + `PreGenesisWethSanitized`), structural absences (sdd.md:L125-L133)
- [x] Redemption property/fuzz suite + token authority negative suite + runtime-bytecode inspection evidence

### Acceptance Criteria
- [x] INV-1…5 unit-tested: complete-supply truth; exact genesis constructor amounts; mint gated to the immutable `rig` address; no discretionary mint/burn path (prd.md:L581-L587)
- [x] `burnForRedemption` reverts for every caller except the immutable `reserve`; no `burnFrom` symbol exists in the ABI (sdd.md:L678; FR-7.4 "no approval gate", prd.md:L251)
- [x] Property test ∀ tested `(B, S, q)`: `payout = floor(B×q/S)`, zero fee, Reserve-favoring rounding, pre-redemption values (prd.md:L425-L426); exhaustive-redemption test preserves `S_MIN = 1` raw and a positive WETH remainder (prd.md:L253)
- [x] Reserve external surface is exactly `redeem` + views: no owner, roles, pause, upgrade, arbitrary call, approval, sweep, receive-hook, selfdestruct, payable path (FR-7.2, INV-14) — verified by ABI enumeration + review checklist
- [x] Constructor sanitization proven: prefunded predicted address → constructor transfers full amount to creator, emits `PreGenesisWethSanitized`, requires born-empty; **runtime bytecode inspection proves no transfer-out/sweep path survives deployment** (sdd.md:L132)
- [x] Reserve code passes only `msg.sender` to `burnForRedemption` — negative test proves it cannot burn a third party (sdd.md:L130)
- [x] PROV-5 similarity statement recorded: Hard Reserve implemented from the canonical equations; no prohibited source consulted (prd.md:L764)

### Technical Tasks
- [x] Task 2.1: `VUX.sol` — adapt allowlisted `Unit.sol`/`IUnit.sol` (SPDX `MIT AND GPL-3.0-or-later`); ERC20+ERC20Permit base from vendored OZ; constructor mint semantics; `mint` onlyRig; `burn`; `burnForRedemption` onlyReserve; delete `burnFrom` → **[G-1]** ⇐ none
- [x] Task 2.2: Token authority suite — INV-1…5 units, mint/burn gate negatives (`NotRig`/`NotReserve`), ABI assertion that no `burnFrom` exists → **[G-1]** ⇐ Task 2.1
- [x] Task 2.3: `HardReserve.sol` — VUX-original from spec equations: `redeem` (snapshot `B`/`S` → burn via `burnForRedemption(msg.sender, q)` → pay; `nonReentrant`; `q ≤ S − S_MIN`), `backing()`/`previewRedeem` views, constructor sanitization block → **[G-1]** ⇐ Task 2.1
- [x] Task 2.4: Redemption property/fuzz suite — exact payout formula, zero fee, rounding direction, `S_MIN` exhaustion, INV-10/14/15/16/17 → **[G-1]** ⇐ Task 2.3
- [x] Task 2.5: Constructor-sanitization tests + runtime-bytecode inspection artifact (no surviving transfer-out path) → **[G-1]** ⇐ Task 2.3
- [x] Task 2.6: Structural-absence review checklist (FR-7.2/7.3) + PROV-5 similarity-review note for `HardReserve.sol` → **[G-1, G-5]** ⇐ Task 2.3

### Dependencies
- Sprint 1: vendored OZ base (ERC20/Permit/ReentrancyGuard/SafeERC20/Math), Miner reference files, CI gates
- Tests instantiate `rig`/`reserve` with harness addresses — no Rig contract needed yet (sdd.md:L97: the token trusts two immutable addresses, whatever they are)

### Security Considerations
- **Trust boundaries:** the token's entire privileged surface is two immutable single-purpose callers; the Reserve's is none — this sprint's audit IS the verification of that claim
- **External dependencies:** canonical-WETH interface only (never vendored, prd.md:L725); tests use a local mock WETH clearly marked test-only
- **Sensitive data:** none

### Risks & Mitigation
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Adaptation from Miner `Unit.sol` drags in unneeded surface | Medium | High | Surface diff review against sdd.md:L97 responsibilities; ABI enumeration test; audit gate |
| Sanitization capability accidentally reachable at runtime | Low | Critical | Init-code-only placement + runtime-bytecode inspection + negative tests (Task 2.5) |
| Rounding direction error in redemption | Low | High | Property suite asserts floor + Reserve-favoring direction on randomized inputs |

### Success Metrics
- 100% of FR-7 automatable acceptance checkboxes green; fuzz ≥10,000 runs in CI
- ABI surface exactly matches sdd.md §5.2.1/§5.2.3 (no extra mutator)
- Zero findings of class "unexpected authority" at audit

---

## Sprint 3: Rig — Throne, Settlement, VEM & the Monetary Invariant Suite

**Duration:** ~4–5 focused engineering days (indicative)
**Scope:** LARGE (7 tasks)

### Sprint Goal
Complete the monetary core: the one-throne Dutch-priced KOTH engine with the 13-step atomic settlement, the **adaptive 8%-floor routing law** (`king = floor(80%)`; `hardTarget = min(retained, max(hardFloor, D_need))` → Hard; `strategic = retained − hardTarget` → Strategic; PRD FR-4 v2.1.0, SDD Appendix F note F-1), measured-`D_R` VEM (rejection against `hardTarget`), and bootstrap semantics (confirm-only: the adaptive law degenerates exactly at `Qraw = 0`) — proven by the property/fuzz and stateful-invariant suite, including randomized `(P, Qraw, B_pre, S_pre)` regime testing, that becomes the cycle's permanent monetary regression harness.

### Deliverables
- [x] `Rig.sol` complete: Dutch pricing + successor opening, UPS halving schedule with epoch snapshot, `scheduleStart` at first public takeover, 13-step `take(maxPrice)` with the exact adaptive legs (`hardTarget`/`strategic` residual; zero-valued Strategic transfer skipped) / `D_R` measurement + rejection against `hardTarget` / `Qsafe`/`Qmint` / CEI + `nonReentrant`, bootstrap branch, `Settled` event (variable-leg semantics; `D_need` derivable), constants as `constant` incl. the 1,200 bp Strategic **cap** (sdd.md:L101-L123, L196-L229; SDD Appendix F, F-1)
- [x] Property/fuzz suites for FR-2/3/4/5/6 acceptance formulas
- [x] Stateful invariant harness (introduced here, extended in Sprints 4–5) covering INV-1…22 over random `take`/`redeem` sequences
- [x] Automated FB scenario tests: FB-2, FB-3, FB-4, FB-13, FB-14, FB-15, FB-16; review-note documentation for FB-1

### Acceptance Criteria
- [x] Price function matches `max(DECAY_FLOOR, opening × (1 − min(t,3000)/3000))` at boundary points t = 0 / 3000 / beyond, floor clip; successor opening `max(MINIMUM_OPENING, 2×P)` including the minimum branch (prd.md:L342-L344)
- [x] UPS at every schedule boundary equals 4 / 2 / 1 / 0.5 / 0.25 / 0.125 / 0.0625 / 0.03125 / 0.015625 VUX/s; an epoch straddling a halving settles at its opening snapshot; `Qraw` caps at exactly `3000 × epochUPS` (prd.md:L359-L361)
- [x] Randomized `(P, Qraw, B_pre, S_pre)` regime testing (weak/cheap through strong/premium): `king = floor(P×8000/10000)`; `retained = P − king`; `strategicCap = floor(P×1200/10000)`; `hardFloor = retained − strategicCap`; `D_need = ceil(Qraw×B_pre/S_pre)`; `hardTarget = min(retained, max(hardFloor, D_need))`; `strategic = retained − hardTarget`; legs sum to `P`; `hardFloor ≤ hardTarget ≤ retained`; `0 ≤ strategic ≤ strategicCap`; dust lands in Hard; `D_need ≤ hardFloor ⇒` exact equality with the prior static split (prd.md:L376)
- [x] Property test ∀ `(B_pre, S_pre, D_R, Qraw)`: minted amount = `min(Qraw, floor(D_R × S_pre / B_pre))` and preserves `(B_pre+D_R)/(S_pre+Qmint) ≥ B_pre/S_pre`; a measured `D_R` inconsistent with the routed `hardTarget` rejects atomically (`InconsistentReserveDelta`); no storage cell records unmet `Qraw − Qsafe` (prd.md:L393-L395); VEM measured-delta invariant unchanged (`D_actual ≡ D_R`)
- [x] Bootstrap (confirm-only — behavior unchanged): Reserve is genesis King, clock disabled, `Qraw = 0` (so `hardTarget = hardFloor`, `strategic = strategicCap` by degeneracy), first takeover routes ≈88%+/12%/0-mint, payer's epoch opens at current schedule rate, no second bootstrap state reachable (prd.md:L407-L408)
- [x] Partial-failure injection: no state where some legs routed and others did not (prd.md:L378); settlement cannot rewrite a prior epoch or mint recipient (INV-21)
- [x] Code-inspection checklist (narrowed prohibition): no branch of primary settlement reads time-phase, macro, NAV, ROOT/GIGA price, market price, oracle data, or operator preference — the adaptive computation consumes exactly `(P, Qraw, B_pre, S_pre)` plus own throne state (prd.md:L233, L377) — named checklist entry for review
- [x] Invariant suite green over random op sequences: `B/S` monotone under authorized issuance (INV-13), supply attribution complete, INV-1…22 with INV-18/INV-19 in their amended adaptive form (prd.md:L608-L609)

### Technical Tasks
- [x] Task 3.1: Rig pricing & schedule — Dutch decay, successor opening, `INITIAL_UPS >> min((t−scheduleStart)/30 days, 8)` snapshot, bootstrap decay anchor (`epochStart` = deployment), storage layout per sdd.md:L109-L122, routing constants as `constant`; FR-2/FR-3 boundary tests → **[G-1]** ⇐ none
- [x] Task 3.2: `take(maxPrice)` 13-step settlement — payment pull; adaptive legs (`retained`, `strategicCap`, `hardFloor`, `D_need = ceil(Qraw×B_pre/S_pre)` via `Math.mulDiv`-family ceil, `hardTarget`, `strategic` residual with zero-transfer skip); Hard-leg transfer + `D_R = balanceOf(reserve) − B_pre` equality rejection against `hardTarget`; `Math.mulDiv` VEM; effects-before-final-interactions ordering; mint to outgoing King; king-leg delivery; `Settled` emission with variable-leg semantics (sdd.md:L196-L229; SDD Appendix F, F-1) → **[G-1]** ⇐ Task 3.1
- [x] Task 3.3: Bootstrap branch — reserve-as-King detection forcing `Qraw = 0`, king-leg redirection to Reserve, `scheduleStart` set at first public takeover; FR-6 tests incl. no-second-bootstrap → **[G-1]** ⇐ Task 3.2
- [x] Task 3.4: Property/fuzz suites — adaptive-leg arithmetic ∀ `(P, Qraw, B_pre, S_pre)` regimes (floor/cap/dust/degeneracy properties per the FR-4 acceptance list), VEM invariant ∀ tuples, expiry-no-carry, `maxPrice` slippage guard → **[G-1]** ⇐ Task 3.2
- [x] Task 3.5: Stateful invariant harness (INTRODUCES the cycle-wide suite) — INV-1…22 handlers (INV-18/INV-19 in amended adaptive form) over random `take`/`redeem` sequences with time warps across halvings and settlement regimes spanning `D_need ≤ hardFloor` through `D_need > retained` → **[G-1]** ⇐ Task 3.2
- [x] Task 3.6: FB scenario tests — FB-2 (no challenger), FB-3 (weak demand), FB-4 (high demand), FB-13 (mass redemption), FB-14 (below-backing trading), FB-15/16 (no rescue/recap path exists) → **[G-1, G-2]** ⇐ Task 3.5
- [x] Task 3.7: Review documentation — prohibited-signal inspection checklist (FR-4.3), FB-1 mining/redemption independence note, PROV-3 statement (routing/VEM/D_R written from PRD equations only; Rig skeleton from allowlisted file) → **[G-1, G-5]** ⇐ Task 3.2

### Dependencies
- Sprint 2: `VUX.mint` (onlyRig), `HardReserve` physical-balance measurement target
- Treasury leg target in tests is a plain address — the treasury contract is NOT required (the Strategic residual leg is a plain WETH transfer, skipped when zero, sdd.md:L138); `Rig.totalStrategicContributed` carries the P0 contributed-principal accounting (cumulative variable legs) until Sprint 4

### Security Considerations
- **Trust boundaries:** `take` is permissionless; the only external calls are canonical-WETH transfers — SafeERC20 + `nonReentrant` + CEI per sdd.md:L227
- **External dependencies:** none new
- **Sensitive data:** none

### Risks & Mitigation
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Rounding/precision drift between spec math and implementation | Medium | High | `Math.mulDiv` floor only; property tests assert the exact PRD formulas; no assembly (sdd.md:L926) |
| Settlement ordering bug lets successor state leak into outgoing settlement | Low | Critical | 13-step order tests + INV-21 invariant + mutation-style negative (reordered mock) at review |
| Miner `Rig.sol` skeleton contaminates VUX-original surfaces | Low | High | PROV-3 separation documented per file section; similarity review at audit; non-allowlisted Miner files never opened |

### Success Metrics
- Fuzz ≥10,000 runs; invariant suite ≥10,000 depth-configured runs green in CI
- All 7 automated FB rows for this sprint green; INV-1…22 handler coverage complete
- Zero prohibited-signal findings from the inspection checklist

---

## Sprint 4: Strategic Treasury I — Custody, Classification & Authority Boundaries

**Duration:** ~5–6 focused engineering days (indicative)
**Scope:** LARGE (9 tasks)

### Sprint Goal
Ship the role-gated Strategic Treasury custody and its arithmetic classification engine — admission registry with immutable per-strategy modes and the 24 h maturity delay, the three flow primitives, revenue distribution bounds, and the LSG P0 activation authority — proving that principal and marks are arithmetically non-distributable and that no treasury surface can reach the monetary core.

### Deliverables
- [x] `VuxPoolDeployer.sol` (vendored-unit `=0.7.6`): canonical CREATE2 `deployCanonicalPool` (upstream deployer semantics), salted `msg.sender`-binding commitment gate, one-shot, Finding-4 parameter-domain checks, permanent `owner() == address(0)` (sdd.md:L190-L194)
- [x] `StrategicTreasury.sol` (part I): constructor immutables + wiring re-verification, AccessControl roles (creator-granted), receipt accounting, admission registry (`mode` immutable, `ADMISSION_DELAY = 24 h`, instant removal), `deployToStrategy`/`recallFromStrategy` caps, `returnFor`/`harvestYield`/`redeemUnits`/`closeStrategy`, four-leg `allocateRevenue` + `signalerBudget` earmark + `burnVuxRevenue` + `setOpsRecipient` (corrected P0 revenue boundary per Task 4.5), classification events (sdd.md:L135-L148, L285-L321)
- [x] LSG P0 authority: `lsgModule` slot (launch `address(0)`), `activateLSG`/`deactivateLSG`, `ILSGModule` interface, `deployMarginalBySignal` (code P0, use P1), treasury-side `fundSignalerProgram` gating (sdd.md:L146, L322-L344)
- [x] Mode-aware accounting property suite + INV-23…34 boundary/invariant extensions + FB-5 scenario

### Acceptance Criteria
- [x] Treasury constructor re-verifies `POOL.factory() == VUX_POOL_DEPLOYER`, `IUniswapV3Factory(VUX_POOL_DEPLOYER).owner() == address(0)`, token ordering/fee, and derives tick bounds from `pool.tickSpacing()`; roles granted to `msg.sender` (creator); no `setPool`/initializer exists (sdd.md:L140, L718-L725)
- [x] Admission: `mode` fixed at admission and immutable (change = remove + re-admit + re-delay); deployment blocked until `maturesAt` (`AdmissionNotMatured`); removal/recall always instant and unblockable (sdd.md:L147)
- [x] Accounting properties ∀ flow sequences ∀ modes (sdd.md:L856): Σ revenue distributions ≤ realized-revenue credits; returned principal never credits revenue; arbitrary-asset returns rejected (`UnknownReturnAsset`); NETTING revenue only beyond full return; CLAIM harvest with decreased `principalUnits` reverts; UNITIZED basis release conserves (Σ `basisReleased` = original basis over full unwind), gain→revenue / shortfall→loss never negative revenue; `closeStrategy` write-off only reduces principal
- [x] `allocateRevenue` negatives: `asset == VUX` rejected (`VuxRevenueMustBurn`); non-WETH Hard leg rejected (`HardLegMustBeWeth`); over-accumulator rejected (`RevenueExceedsRealized`); ABI assertion: exactly four legs — no `toMarketInfra` parameter and no `marketInfraBudget` symbol exists (2026-08-12 remediation) — FR-12 negative acceptance "no configuration of the policy surface can reach Reserve principal or mint" (prd.md:L505-L506)
- [x] Percentages are call-time arguments only — grep-verified no stored ratio constant exists (R-9 execution-reserved; waterfall ratios are founder-accepted doctrine, never operator-set; §17 quarantine)
- [x] LSG P0: launch state inactive (`lsgModule == address(0)`); `activateLSG`/`deactivateLSG` operator-gated + evented; no numeric threshold or calendar in code (F-50); signal surfaces revert `LSGInactive` before activation; INV-32…34 negatives green (prd.md:L522-L524)
- [x] FB-5: simulated 50%/80%/100% Strategic loss leaves `B`, redemption, VEM, and mint authority **bit-identical** (prd.md:L444)
- [x] Role topology: operator roles exist on `StrategicTreasury` only; negative tests prove no treasury call path reaches Reserve principal, redemption math, mint authority, or routing constants (NFR-SEC-7; INV-33)
- [x] `VuxPoolDeployer` unit tests: wrong salt reverts, wrong `msg.sender` with correct salt reverts, second call reverts, domain violations each revert, deployed pool address equals independent `create2(deployer, keccak256(abi.encode(token0,token1,fee)), POOL_INIT_CODE_HASH)` recompute (sdd.md:L859)

### Technical Tasks
- [x] Task 4.1: `VuxPoolDeployer.sol` in the vendored `=0.7.6` unit — canonical `UniswapV3PoolDeployer` derivation, commitment gate, one-shot latch, domain checks, `owner()==address(0)`; unit tests incl. independent CREATE2 recompute → **[G-1, G-2]** ⇐ none
- [x] Task 4.2: Treasury skeleton — constructor immutables + re-verification, AccessControl (`DEFAULT_ADMIN_ROLE`/`OPERATOR_ROLE` to creator), storage cells per sdd.md:L140, receipt accounting + `StrategicInflow`/`StrategicOutflow` events → **[G-2]** ⇐ Task 4.1
- [x] Task 4.3: Admission registry — `admitStrategy`/`removeStrategy` (mode + cap + `maturesAt`; `StrategyAdmitted`/`StrategyRemoved`), `deployToStrategy`/`recallFromStrategy` (admitted+matured+cap) → **[G-2]** ⇐ Task 4.2
- [x] Task 4.4: Flow primitives — `returnFor` (principal-first netting, in-call classification), `harvestYield` (CLAIM: measured own-balance deltas + units-intact guard), `redeemUnits` (UNITIZED: ceil basis release, gain/shortfall booking), `closeStrategy` (loss-only write-off after removal) → **[G-2]** ⇐ Task 4.3
- [x] Task 4.5: Distribution surface (corrected P0 revenue boundary, 2026-08-12 remediation; sdd.md §1.10 + Appendix F F-2) — `allocateRevenue` with **four** call-time legs (compound / Hard **WETH-only** / ops / signalers; accumulator bound Σ ≤ `realizedRevenue[asset]`); `toOps` = payment of an actual approved operating expense ONLY (never the future 25% Operator Reserve contribution — its credit/accumulation/sweep/allocator-exclusion mechanics are a P1/future design obligation, NOT built here); `signalerBudget` as the sole earmark (no `toMarketInfra` argument, no `marketInfraBudget` symbol — market infrastructure is funded via Strategic capital deployment policy, never a revenue leg); `burnVuxRevenue`, `setOpsRecipient` + events → **[G-2]** ⇐ Task 4.4
- [x] Task 4.6: LSG P0 authority — `lsgModule` slot, `activateLSG`/`deactivateLSG` + events, `ILSGModule` interface, `deployMarginalBySignal` (reads signal view, filters admitted+matured+cap-headroom, pro-rata floor split via §1.10 ledger, `SignalConsumed`), treasury-side `fundSignalerProgram` (requires active module, spends earmark) → **[G-4, G-2]** ⇐ Task 4.3, Task 4.5
- [x] Task 4.7: Mode-aware accounting property suite per sdd.md:L856 (all modes, all guards, mode immutability) → **[G-2]** ⇐ Task 4.4, Task 4.5
- [x] Task 4.8: Boundary negatives + invariant extension — INV-23/24/28/30/31 handlers added to the Sprint-3 harness; INV-32/33/34 LSG-boundary negatives; FB-5 bit-identical-core scenario; FB-15/16 no-path re-checks from treasury surfaces → **[G-2, G-4]** ⇐ Task 4.6, Task 4.7
- [x] Task 4.9: Review documentation — FB-6/9/10/12 scenario notes; R-1…R-14 reservation sweep (nothing frozen); adversarial-adapter argument (fraud ≤ theft, sdd.md:L302) → **[G-2, G-6]** ⇐ Task 4.5

### Dependencies
- Sprint 3: `Rig.Settled` + `totalStrategicContributed` attribution for the Strategic residual leg — a variable amount in `[0, floor(12%·P)]` per settlement (sdd.md:L303 rule 5)
- Sprint 1: vendored v3-core unit (pool + deployer pattern) for Task 4.1; vendored OZ AccessControl
- Test fixtures deploy a real vendored pool via `VuxPoolDeployer` for constructor-verification tests — no mocks for identity checks

### Security Considerations
- **Trust boundaries:** the treasury is the protocol's ONLY privileged surface; this sprint's audit is the FR-16 boundary argument — every privileged action maps to a §16-reserved decision or a frozen prohibition (prd.md:L568)
- **External dependencies:** none new (vendored unit already landed)
- **Sensitive data:** none; test Safe is a fixture address

### Risks & Mitigation
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Classification guard gap lets principal book as revenue | Low | Critical | Property suite over all modes/sequences; no `declareProfit` symbol; audit focus item |
| Accidentally freezing an operator-reserved execution parameter/threshold (R-9/R-10 execution scope — the waterfall ratios themselves are founder-accepted doctrine, not operator-reserved) | Medium | High | Call-time-arguments-only design; §17 quarantine grep; Task 4.9 reservation sweep |
| Cross-compilation-unit interface mismatch (0.8.28 treasury ↔ 0.7.6 pool) | Medium | Medium | Interface-only coupling via vendored v3-core interfaces; fixture-deployed real pool in tests |
| P1 scope creep (implementing LSGSignals mechanics) | Medium | Medium | P1 tripwire: only the slot/interface/execution-read ship; module implementation rejected at review |

### Success Metrics
- Accounting property suite green over ≥10,000 fuzz runs per mode; FB-5 bit-identity proven
- 100% of treasury mutators covered by at least one negative (unauthorized caller) test
- Zero stored policy-ratio constants (mechanical grep)

---

## Sprint 5: Strategic Treasury II — POL, Callback Authentication & VYRF

**Duration:** ~4–5 focused engineering days (indicative)
**Scope:** MEDIUM (6 tasks)

### Sprint Goal
Complete the treasury's POL sleeve against the vendored pool — position mint/increase/decrease and in-protocol VUX purchase behind one-shot context-authenticated callbacks with zero standing approvals — and realize the frozen VYRF outcome (VUX fees burn; WETH fees → Hard one-way; principal stays Strategic) as a mechanically tested ordering fact.

### Deliverables
- [x] POL operations: `mintPolPosition`, `increasePol`, `decreasePol` (fee-first ordering), `buyVuxForPol` (slippage-bounded in-protocol swap) with cost-basis cells `polVuxPrincipal`/`polWethPrincipal` (sdd.md:L139-L143)
- [x] One-shot callback authentication: `uniswapV3MintCallback`/`uniswapV3SwapCallback` with arm→validate→consume→pay context lifecycle and `CallbackNotConsumed` outer check (sdd.md:L252-L258)
- [x] `harvestPol()` permissionless VYRF: poke → collect → VUX burn + WETH→`HardReserve` in one call; `VyrfHarvest` event (sdd.md:L141-L144)
- [x] Full callback negative suite + VYRF/POL invariant extensions + fork E2E harvest scenario

### Acceptance Criteria
- [x] Callback negative suite green (sdd.md:L858): forged caller; canonical pool with no active context; wrong callback type; wrong token direction; amount above committed maximum; nested/reentrant attempt; nonempty data; **duplicate second callback under one armed operation reverts even from the canonical pool** (mock double-callback test); outer op with unconsumed authorization reverts (`CallbackNotConsumed`)
- [x] Zero standing approvals after every pool operation (asserted per-op)
- [x] VYRF ordering invariant: position `tokensOwed` outside a `decreasePol` execution consists of fees only (sdd.md:L142); principal sweeps atomically inside `decreasePol` against cost-basis cells
- [x] End-to-end scenario: fee accrual → `harvestPol` → VUX fee burn observed with cause pairing, WETH fees land in `B`, returned principal books as principal (FR-11 acceptance, prd.md:L489-L490); the general-waterfall surface provably cannot receive POL fee yield
- [x] `buyVuxForPol`: `minVuxOut` + `sqrtPriceLimitX96` enforced; purchased VUX books as POL inventory principal; no path mints VUX for POL (INV-26 negative)
- [x] No code path calls `HardReserve.redeem` from the treasury (FR-10.3 conduct, negative test + review)
- [x] INV-25/26/27 (treasury-side)/28/29 handlers added to the invariant harness; FB-7 (POL failure leaves Hard arithmetic unchanged) and FB-8 (unharvested fees counted nowhere) scenarios green
- [x] `harvestPol` is permissionless, parameter-free, and performs no swap (sdd.md:L144) — keeper absence cannot corrupt classification (NFR-REL-2)

### Technical Tasks
- [x] Task 5.1: POL position ops — `mintPolPosition`/`increasePol` with committed-maxima context arming; direct-on-pool position (no periphery, no NFT); quantization-dust inventory treatment (sdd.md:L168) → **[G-2]** ⇐ none
- [x] Task 5.2: `decreasePol` (poke → collect fees → burn liquidity → collect principal, atomically) + `buyVuxForPol` (CTX_SWAP, measured output verification) → **[G-2]** ⇐ Task 5.1
- [x] Task 5.3: `harvestPol()` VYRF — zero-liquidity poke, collect, VUX burn + WETH transfer to Reserve in-call, `VyrfHarvest`; `nonReentrant`; permissionless → **[G-2, G-1]** ⇐ Task 5.1
- [x] Task 5.4: Callback authentication negative suite per sdd.md:L858 incl. the mock-pool double-callback rig and zero-approval assertions → **[G-2]** ⇐ Task 5.1, Task 5.2
- [x] Task 5.5: VYRF/POL invariant + scenario extension — `tokensOwed` invariant, INV-25…29 handlers, FB-7/FB-8, wash-trading-is-donation documentation note (sdd.md:L950) → **[G-2]** ⇐ Task 5.3
- [x] Task 5.6: Fork E2E + conduct review — anvil-fork harvest end-to-end (sdd.md:L862); FR-10.3 no-redeem-path review; INV-26 no-mint-sourcing negative → **[G-2, G-6]** ⇐ Task 5.3, Task 5.4

### Dependencies
- Sprint 4: treasury skeleton, `VuxPoolDeployer`, admission/accounting cells the POL legs book against
- Sprint 2: `HardReserve` as the WETH-fee destination; `VUX.burn` for fee burns

### Security Considerations
- **Trust boundaries:** the callbacks are the one place an external contract (the exact pool) calls into the treasury mid-operation — the one-shot context gate IS their authentication (sdd.md:L257); everything else is `nonReentrant`
- **External dependencies:** vendored pool only; no new source
- **Sensitive data:** none

### Risks & Mitigation
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Fee/principal confusion in the collect ordering | Low | Critical | The tested `tokensOwed` invariant is exactly this failure mode; fee-first ordering enforced in one function |
| Callback authentication bypass | Low | Critical | Five-check validation order + consume-before-pay + negative suite incl. duplicate/nested/forged cases |
| 0.7.6 pool behavioral surprise vs. expectations | Low | High | Pinned byte-identical source + fork E2E; refreeze bytecode fidelity already CI-enforced |

### Success Metrics
- Callback negative suite: 9 distinct rejection classes each covered; zero standing approvals asserted after 100% of pool ops
- VYRF E2E: all three legs (burn, Hard accretion, principal) separately observable with cause pairing
- Invariant harness green with POL handlers at ≥10,000 runs

---

## Sprint 6: Truth Surfaces — Lens, Indexer & Truthful UX

**Duration:** ~5–6 focused engineering days (indicative)
**Scope:** LARGE (8 tasks)

### Sprint Goal
Make the protocol's economic truth independently observable and truthfully presented: the read-only Lens three-tier views, a complete event schema proven reconstructable by an independent indexer, and a frontend whose mining-state copy passes the FR-15 three-tier truth and YELLOW-disclosure requirements — with all off-chain dependencies entering only through the fail-closed provenance gate.

### Deliverables
- [x] Off-chain provenance refreeze evidence + operator acceptance (refreeze §9 set), then pinned installs
- [x] `Lens.sol`: `rawClockLimit`, `estimateIfDisplacedNow`, `hardStats`, `wethNeededForFullQraw` (rounds UP), `strategicContributed` (sdd.md:L704-L713)
- [x] Event-schema completeness audit vs. FR-14.1–14.4; burn-cause pairing verification (sdd.md:L542)
- [x] ponder indexer + PostgreSQL 16.4 schema (§3.3) + read-only REST; independent-reconstruction test
- [x] Frontend (Throne/Redeem/Accounting/Treasury/Trust pages), `truth-copy.ts` single source, `<ReserveDescription/>` YELLOW coupling, Playwright copy suite

### Acceptance Criteria
- [x] **Gate first:** zero off-chain package installed/used before the operator-accepted pin set exists (fail-closed; refreeze §9) — evidence: pins + integrity hashes recorded, acceptance logged, lockfiles match pins
- [x] Independent-reconstruction test: an indexer-only recompute of `S`, `B`, `B/S`, per-settlement legs, and burn causes over a scripted multi-op scenario **matches chain state with zero ambiguity** (FR-14 acceptance, prd.md:L538); reorg/idempotency handling per sdd.md:L836
- [x] Three-tier truth on every mining surface: tier labels distinct, prohibited framings absent ("earned", "owed", "claimable", "guaranteed" for tiers 1–2), estimate labeled variable + non-claimable; canonical explanation available verbatim (prd.md:L546-L553)
- [x] YELLOW disclosure renders verbatim wherever the Reserve is described as ownerless/immutable — single-component coupling (INV-36; prd.md:L722-L723)
- [x] Contestability claim appears only in its exact bounded form; no broad-distribution/anti-whale/equal-outcome claim anywhere (prd.md:L549)
- [x] NAV column named `strategic_nav_disclosed`; the word "backing" never labels Strategic values (FR-14.4)
- [x] Failure truthfulness: RPC failure → explicit "data unavailable" (never stale-as-live); chain outage messaging per FB-17; FB-18 documented disclosure present on `/trust` (sdd.md:L836)
- [x] `previewRedeem`/estimates create no entitlement — copy + no-optimistic-display tests (prd.md:L539)

### Technical Tasks
- [x] Task 6.1: OFF-CHAIN PROVENANCE GATE — produce the pin census (ponder 0.8.x exact, Next.js 15.1.4, React 19.0.0, viem 2.21.x exact, wagmi 2.14.x exact, Playwright 1.49.x exact, PostgreSQL 16.4) with integrity evidence; **STOP for operator acceptance**; then pinned lockfile installs + CI lockfile-drift gate → **[G-5]** ⇐ none
- [x] Task 6.2: `Lens.sol` + tests — three-tier views, estimate parity against actual settlement outcomes, `wethNeededForFullQraw` round-UP (F-16), no-entitlement semantics → **[G-3, G-1]** ⇐ none
- [x] Task 6.3: Event completeness audit — every FR-14.1–14.4 observable mapped to an emit site; burn-cause pairing (Transfer→0 joined to `Redeemed`/`VyrfHarvest`/`VuxRevenueBurned`) verified on scripted flows → **[G-3, G-2]** ⇐ none
- [x] Task 6.4: ponder indexer + PostgreSQL schema (§3.3 tables incl. `legs_sum` constraint) + read-only REST endpoints → **[G-3]** ⇐ Task 6.1, Task 6.3
- [x] Task 6.5: Independent-reconstruction test — scripted anvil scenario (genesis-fixture → takeovers → redemptions → harvest) recomputed from events only; equality vs. chain state; reorg/idempotency cases → **[G-3, G-2]** ⇐ Task 6.4
- [x] Task 6.6: Frontend — five pages per sdd.md:L633-L643, `truth-copy.ts` lint-guarded constants, `<ReserveDescription/>`, wallet flows (`take` with maxPrice guard, `redeem`), no-optimistic-entitlement states → **[G-3]** ⇐ Task 6.1
- [x] Task 6.7: Playwright copy suite — three-tier labels, prohibited-phrase greps, YELLOW presence on every Reserve description, estimate non-claimable labeling (sdd.md:L863) → **[G-3]** ⇐ Task 6.6
- [x] Task 6.8: Failure-truthfulness states — data-unavailable rendering, FB-17 outage messaging, FB-18 `/trust` disclosure content → **[G-3]** ⇐ Task 6.6

### Dependencies
- Sprints 2–5: complete contract set + event schema (Lens and indexer read them)
- Operator gate: off-chain pin acceptance (Task 6.1) — intra-sprint HITL stop

### Security Considerations
- **Trust boundaries:** off-chain components are read-only truth surfaces + transaction builders; none holds keys or custody (sdd.md:L451); indexer REST is public-data, no auth, no write endpoints
- **External dependencies:** the entire off-chain stack enters here — behind the gate; lockfile-drift CI added
- **Sensitive data:** none; no server-side session state

### Risks & Mitigation
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Indexer misreports accounting truth | Medium | Medium | Derived + rebuildable store; independent-reconstruction acceptance test; on-chain events remain canonical (sdd.md:L930) |
| UX copy drifts into "earned while running" framing | Medium | High | Single `truth-copy.ts` source + lint + Playwright prohibited-phrase greps (FR-15 acceptance) |
| Off-chain supply-chain surprise (transitive deps) | Medium | Medium | Exact pins + lockfile integrity gate; fail-closed acceptance before install |

### Success Metrics
- Reconstruction test: 100% equality on `S`, `B`, `B/S`, legs, burn causes over the scripted scenario
- Playwright suite: 0 prohibited-phrase hits; YELLOW disclosure on 100% of Reserve descriptions
- CI: lockfile-drift gate active; pinned versions equal accepted pins

---

## Sprint 7: Genesis — Non-Griefable Launch Implementation & Adversarial Rehearsal

**Duration:** ~5–6 focused engineering days (indicative)
**Scope:** LARGE (6 tasks)

### Sprint Goal
Implement the two-transaction constructor-genesis exactly as accepted (CREATE nonce-predicted wiring, protocol-owned CREATE2 pool, in-transaction funding wrap, closing self-verification) and **prove** — by fork rehearsal against a full-knowledge adversary — that leaked addresses, hostile lookalike pools, arbitrary prefunding, and mempool racing cannot alter one wei of the exact genesis state.

### Deliverables
- [x] Q-6 evidence: fork-verified canonical-WETH native-wrap (`deposit()`) semantics, recorded for R-14
- [x] `GenesisDeployer.sol`: constructor-executed genesis steps 0–10 per sdd.md:L158-L171 (snapshot + in-tx `WETH.deposit`, five CREATEs with predict-verify, commitment-gated pool deploy + initialize + verify, POL provisioning, exact `B0` transfer, Safe grant, renounce, residual sanitizing sweep, closing self-verification)
- [x] Off-chain deterministic `sqrtP0X96` encoder (floor `isqrt((n<<192)/d)` convention + quantization-delta evidence, sdd.md:L185)
- [x] Genesis wiring proof suite + full-knowledge adversarial rehearsal + two-transaction launch rehearsal script (rehearsal values only)
- [x] Genesis evidence pack mapping every launch-security proof obligation to its test artifact

### Acceptance Criteria
The rehearsal suites must prove all twelve launch-security obligations (operator brief), each mapped to a named test:
- [x] Leaked future addresses cannot grief genesis (full-knowledge adversary; launch succeeds unchanged at intended addresses)
- [x] Hostile public-factory lookalike pools (every fee tier, hostile init, one-sided liquidity) are irrelevant — referenced nowhere
- [x] Canonical pool CREATE2 identity exact: independent recompute `create2(vuxPoolDeployer, keccak256(abi.encode(token0,token1,fee)), POOL_INIT_CODE_HASH)` equals deployed pool equals `treasury.POOL()` (sdd.md:L859)
- [x] Arbitrary prefunding (WETH to every predicted address + forced ETH) cannot alter exact genesis state — per-address defense table outcomes verified (sdd.md:L172-L184)
- [x] Future-HardReserve prefunding constructor-sanitized: **very large** prefund → `PreGenesisWethSanitized` → ends as unattributed Strategic inventory
- [x] Final physical Reserve balance is exactly `B0` (`WETH.balanceOf(reserve) == B0`), physical `N0 = B0/S0` and `P0/N0 = 1.10` intact, first-settlement `B_pre == B0` (sdd.md:L187)
- [x] No temporary authority survives: roles renounced, deployer holds nothing, one-shot consumed (second `deployCanonicalPool` reverts), no callable genesis surface exists
- [x] Launch EOA gains no protocol authority (role-topology sweep: Safe-only on treasury; zero roles elsewhere)
- [x] `VuxPoolDeployer` consumed and ownerless (`owner() == address(0)`; `setFeeProtocol` unreachable)
- [x] Exact pool initialization price verified: `slot0.sqrtPriceX96 == sqrtP0X96`; ratio/cushion checks in recorded wei values (`BOOTSTRAP_OPENING ≤ P0×S0 − B0`)
- [x] Callback authorization one-shot and exact-pool-bound during genesis POL provisioning (mint callback path exercised in-genesis)
- [x] Production secrets remain outside repo/CI artifacts: rehearsal uses rehearsal values only; `broadcast/**` hygiene check green; launch-secret checklist per sdd.md:L270
- [x] Plus: mutated-extra-CREATE negative reverts the whole launch (nonce stability); commitment-gate negatives (wrong salt / wrong sender / second call); domain-violation negatives; `vux.balanceOf(deployer) == 0` and `weth.balanceOf(deployer) == 0` after sweep; POL position liquidity > 0 owned by treasury; `rig.king() == reserve`; S0 exact; gas/initcode headroom measured (sdd.md:L859-L860)

### Technical Tasks
- [x] Task 7.1: Q-6 evidence task — fork-verify canonical WETH `deposit()` native-wrap; record evidence; **if the fact fails: STOP → operator fallback transition** (pre-approval funding + §1.7 control) before continuing → **[G-1]** ⇐ none
- [x] Task 7.2: `GenesisDeployer.sol` — constructor genesis steps 0–10 with `predict(n)` RLP computation, in-tx equality requires, commitment-bound pool deployment, POL provisioning through the authenticated mint callback, exact-`B0` delta-verified transfer, Safe handoff, renounce, sanitizing sweep, closing self-verification (sdd.md:L158-L187) + off-chain `sqrtP0X96` encoder → **[G-1]** ⇐ Task 7.1
- [x] Task 7.3: Genesis wiring proof suite — predicted-vs-actual equality, mutated-nonce negative, independent CREATE2 recompute, nonce stability across pool CREATE2, commitment/domain negatives, exact `slot0`, recorded-wei ratio/cushion, contamination arithmetic, closing-sweep completeness, gas/initcode headroom (sdd.md:L859) → **[G-1]** ⇐ Task 7.2
- [x] Task 7.4: Full-knowledge adversarial rehearsal per sdd.md:L860 — prefund every predicted address (incl. very-large Reserve prefund), hostile lookalikes at every tier, salt-extraction + wrong-sender attempts, one-shot consumption attempts, mempool racing/spam, forced ETH; assert exact economics, zero attacker credit, zero surviving authority, callback forgery reverts → **[G-1, G-2]** ⇐ Task 7.3
- [x] Task 7.5: Two-transaction launch rehearsal script (tx1 + tx2, rehearsal values) + `broadcast/**`/secret-hygiene check (no production values anywhere) → **[G-1]** ⇐ Task 7.2
- [x] Task 7.6: Genesis evidence pack — obligation → test-artifact map for the twelve proofs + rehearsal transcripts, for audit and operator review → **[G-1, G-6]** ⇐ Task 7.4, Task 7.5

### Dependencies
- Sprints 2–6: all deployed-by-genesis contracts exist (`VUX`, `Rig`, `HardReserve`, `StrategicTreasury`, `Lens`, `VuxPoolDeployer`)
- Sprint 1: `POOL_INIT_CODE_HASH` CI constant (refreeze §7 obligation 2: wiring uses exactly this constant)
- Operator gate: Q-6 evidence review (fallback transition is an operator decision)

### Security Considerations
- **Trust boundaries:** genesis touches only canonical WETH externally; every other address is protocol-namespace-exclusive — the rehearsal proves the theorem, not just the happy path
- **External dependencies:** none new
- **Sensitive data:** rehearsal values ONLY; production EOA/keys/nonces/salt/manifest/broadcast artifacts never enter repo or CI (sdd.md:L270)

### Risks & Mitigation
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Q-6 fact differs (WETH not native-wrap) | Low | Medium | Documented fallback (pre-approval flow + private submission) as an operator transition — structural security unaffected (sdd.md:L974) |
| Initcode/gas limits crowd the constructor-genesis | Low | High | Headroom measured in rehearsal (sdd.md:L859); two-tx topology already chosen to avoid EIP-3860 pressure (sdd.md:L407) |
| Rehearsal passes but misses an adversarial class | Low | Critical | The §7 adversarial matrix is enumerated from the accepted threat row 23; audit gate reviews rehearsal completeness against the twelve obligations |

### Success Metrics
- 12/12 launch-security obligations mapped to green tests in the evidence pack
- Adversarial rehearsal: 100% of attack classes end in unchanged exact economics; zero attacker-visible state deltas beyond classified donations
- Mutation negatives (nonce, salt, sender, domain) each revert the entire launch

---

## Sprint 8: Launch Readiness — Hardening, Traceability & E2E Goal Validation

**Duration:** ~4–5 focused engineering days (indicative)
**Scope:** LARGE (8 tasks)

### Sprint Goal
Close the cycle: static-analysis hardening behind its provenance gate, the complete 37-invariant/18-failure-behavior traceability matrix, the §20.1 launch-criteria sweep, release-compliance files, the deployment runbook with every operator-reserved input slot explicit — and the end-to-end validation that every PRD goal is achieved by the assembled system.

### Deliverables
- [x] Slither 0.10.x behind its accepted pin (refreeze §9) + triaged baseline + forge lint in CI
- [x] Traceability matrix: INV-1…37 → carrying tests; FB-1…18 → assigned method evidence (test / review checklist / documented analysis per prd.md:L669); FR acceptance-checkbox sweep
- [x] §20.1 launch-criteria sweep (all eight rows) + core coverage ≥90% gate (sdd.md:L871)
- [x] Release compliance: root `LICENSE` (unmodified GPLv3), `THIRD_PARTY_NOTICES.md` accuracy vs. vendored reality, SPDX sweep (NFR-COMP)
- [x] Deployment runbook: founder one-shot USD→WETH conversion procedure, private same-block bundle procedure, launch-secret checklist, R-14 fact-recording template, **Q-3 Safe-composition required-input slot**, Q-6 recorded evidence, Q-4 pre-launch legal-review checklist item
- [x] Task 8.E2E goal-validation evidence; cycle closeout prep (branch batch-pruning list)

### Acceptance Criteria
- [x] Zero unexplained slither findings (triaged baseline documented); slither entered CI only after its pin acceptance
- [x] Traceability: 37/37 invariants and 18/18 FB rows have named evidence per their assigned method; review-only items (FB-1, FB-6, FB-8…FB-12, FB-17, FB-18; prohibited-signal inspection) have named checklist entries in the review artifacts (sdd.md:L867)
- [x] §20.1 sweep green: FR-1…FR-11 + FR-14…FR-16 acceptance criteria pass; LSG inactive with activation authority present; all 37 invariants demonstrated; all 18 FB behaviors demonstrated; genesis/conversion evidence *procedure* verified (production values at deployment); YELLOW disclosure present; PROV-1…9 clean; truthful-UX review passed (prd.md:L878-L886)
- [x] Line coverage ≥90% on core contracts; full accumulated invariant suite green
- [x] Runbook complete with every operator-reserved input explicitly slotted (Q-3 Safe facts, fee tier/tickSpacing, conversion values, schedule start) and none resolved in-repo
- [x] Release files exact: GPLv3 text unmodified; TPN §6/§6.1/§6.2 match vendored reality byte-for-byte with the accepted version
- [x] E2E validation (Task 8.E2E) documents each goal G-1…G-6 with pass evidence; no goal marked "not achieved" without explicit justification
- [x] No production secret, address, or broadcast artifact anywhere in repo/CI (final hygiene sweep)

### Technical Tasks
- [x] Task 8.1: Static-analysis provenance gate — slither 0.10.x pin evidence; **STOP for operator acceptance**; then slither + forge lint in CI with triaged baseline → **[G-5]** ⇐ none
- [x] Task 8.2: Traceability matrix — INV/FB/FR evidence map generated from test headers (`// carries:` convention, sdd.md:L867) + named review-checklist entries for review-only items → **[G-6, G-1, G-2]** ⇐ none
- [x] Task 8.3: §20.1 launch-criteria sweep + ≥90% core-coverage gate + full-suite CI run → **[G-1, G-2, G-3, G-4, G-5]** ⇐ Task 8.2
- [x] Task 8.4: Task 8.E2E — End-to-End Goal Validation (see table below) → **[G-1, G-2, G-3, G-4, G-5, G-6]** ⇐ Task 8.3
- [x] Task 8.5: Release compliance — LICENSE/TPN/SPDX verification against vendored reality (NFR-COMP; PROV-8) → **[G-5]** ⇐ Task 8.1
- [x] Task 8.6: Deployment runbook — conversion procedure, private-bundle procedure, launch-secret checklist, R-14 template, Q-3 input slot, Q-6 evidence reference, Q-4 pre-launch checklist item → **[G-1, G-6]** ⇐ Task 8.2
- [x] Task 8.7: Operator docs — YELLOW disclosure inventory, FB-17/FB-18 documented analyses, no-trustless-claims review (NFR-TRUST) → **[G-3, G-6]** ⇐ Task 8.5
- [x] Task 8.8: Cycle closeout prep — branch batch-pruning list, artifact inventory for `/ship`-time archive (NOT executed here) → **[G-6]** ⇐ Task 8.4

### Task 8.E2E: End-to-End Goal Validation

**Priority:** P0 (Must Complete). **Goal Contribution:** all goals.

| Goal ID | Goal | Validation Action | Expected Result |
|---------|------|-------------------|-----------------|
| G-1 | Faithful monetary core | Fork scenario: rehearsal genesis → bootstrap takeover → ordinary takeovers across a halving **and across adaptive regimes (`D_need ≤ hardFloor` through `D_need > retained`)** → redemptions; assert frozen-parameter table (PRD Appendix A, incl. the adaptive routing law) against deployed constants and observed leg behavior verbatim | INV-1…22 hold (INV-18/19 amended form); constants match verbatim; adaptive floor/cap/dust properties observed; bootstrap ≈88%+/12%/0-mint |
| G-2 | Dual-treasury separation | Strategic loss 50/80/100% + POL failure scenarios on the assembled system | INV-23…31, INV-35 hold; core state bit-identical (FB-5); FB-7 |
| G-3 | Truthful UX | Playwright suite + reconstruction test on the assembled stack | Three tiers distinct; zero prohibited phrases; indexer equality |
| G-4 | LSG-ready boundary | Activation-slot lifecycle (activate mock module → deactivate) + INV-32…34 negatives | Inactive at launch; authority present; boundaries structurally unreachable |
| G-5 | Provenance discipline | Full CI gate run: census drift, pins, SPDX, quarantine grep, `POOL_INIT_CODE_HASH`, lockfile gates | Zero unauthorized source; all gates green |
| G-6 | Operator reviewability | Evidence pack + traceability matrix review: every §21 question answerable from artifacts | 20/20 answerable; matrix complete |

**Acceptance Criteria:**
- [x] Each goal validated with documented evidence; integration points verified end-to-end
- [x] No goal marked "not achieved" without explicit justification

### Dependencies
- Sprint 7: genesis evidence pack (the sweep consumes it)
- Operator gates: slither pin acceptance (Task 8.1); Q-3/Q-4 remain launch-blocking operator items recorded in the runbook — they do not block this sprint's implementation

### Security Considerations
- **Trust boundaries:** no new code surface; this sprint hardens and evidences the existing one
- **External dependencies:** slither (behind gate) only
- **Sensitive data:** the runbook TEMPLATE ships in-repo; production values are operator-supplied at deployment and never committed (sdd.md:L270)

### Risks & Mitigation
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Slither findings force post-audit code mutation | Medium | Medium | Post-audit mutation rule: mutate → narrow re-audit of the exact tree before acceptance |
| Traceability reveals an uncovered invariant late | Low | High | Matrix is generated from test headers accumulated since Sprint 3 — gaps surface at each sprint's review, not only here |
| Runbook accidentally freezes an operator-reserved value | Medium | High | Runbook uses input slots; R-1…R-14 sweep re-run as a named checklist item |

### Success Metrics
- 37/37 INV + 18/18 FB + 6/6 goals evidenced; §20.1 checklist 8/8 green
- Core coverage ≥90%; slither baseline fully triaged
- Runbook review: 0 resolved operator-reserved values

---

## Risk Register (plan-level)

| ID | Risk | Sprint | Probability | Impact | Mitigation | Owner |
|----|------|--------|-------------|--------|------------|-------|
| R1 | Byte-fidelity/toolchain drift breaks `POOL_INIT_CODE_HASH` or census | 1 | Medium | High | Refreeze §7 CI obligations; per-file hash gates; negative demo | Sprint 1 |
| R2 | Test-harness provenance (forge-std not in census) | 1 | resolved-by-default | Medium | VUX-original minimal harness default; operator refreeze option | Sprint 1 |
| R3 | v3 integration (callbacks/VYRF ordering) subtle error | 4–5 | Low | Critical | One-shot context design + enumerated negative suite + fork E2E + `tokensOwed` invariant | Sprints 4–5 |
| R4 | Classification guard gap (principal→revenue) | 4 | Low | Critical | Mode property suite; no declaration path; audit focus | Sprint 4 |
| R5 | Genesis adversarial class missed | 7 | Low | Critical | Enumerated §7 rehearsal matrix vs. threat row 23; 12-obligation evidence pack; audit completeness review | Sprint 7 |
| R6 | Reserved-value freeze / §17 leakage in any artifact | all | Medium | High | CI quarantine grep from Sprint 1; per-sprint R-1…R-14 review sweep | every sprint |
| R7 | Off-chain supply chain (npm transitive) | 6, 8 | Medium | Medium | Fail-closed pin gates + lockfile-drift CI | Sprints 6, 8 |
| R8 | Post-audit mutation lands unaudited | any | Low | High | Binding re-audit rule in the lifecycle section | every sprint |
| R9 | Scope creep pulls P1 (LSG module, adapters) into P0 | 4–5 | Medium | Medium | Explicit P1 exclusion list + review tripwire | Sprints 4–5 |
| R10 | Q-6 fact fails at rehearsal | 7 | Low | Medium | Documented operator fallback transition; security unaffected | Sprint 7 |

## Success Metrics Summary

| Metric | Target | Measurement Method | Sprint |
|--------|--------|-------------------|--------|
| Vendored census exactness | 28+32+3 files, 100% hash match | CI drift gate vs. registry | 1 (then continuous) |
| `POOL_INIT_CODE_HASH` equality | exact accepted constant | CI recomputation | 1 (then continuous) |
| Monetary property/fuzz depth | ≥10,000 runs green | forge fuzz/invariant CI | 3–5 |
| FB rows automated | FB-2,3,4,5,7,13,14,15,16 green | forge scenario tests | 3–5 |
| Callback rejection classes | 9/9 covered | negative suite | 5 |
| Indexer reconstruction equality | 100% on S/B/legs/causes | reconstruction test | 6 |
| Prohibited-phrase hits | 0 | Playwright + lint greps | 6 |
| Launch-security obligations | 12/12 evidenced | genesis evidence pack | 7 |
| Traceability | 37/37 INV, 18/18 FB, 6/6 goals | matrix + E2E | 8 |
| Core line coverage | ≥90% | forge coverage CI | 8 |

## Dependencies Map

```
S1 provenance/vendoring
 └─▶ S2 VUX + HardReserve
      └─▶ S3 Rig settlement/VEM + invariant suite
           └─▶ S4 Treasury custody/accounting/authority (+VuxPoolDeployer)
                └─▶ S5 Treasury POL/callbacks/VYRF
                     └─▶ S6 Lens + indexer + UX   [off-chain pin gate]
                          └─▶ S7 Genesis + adversarial rehearsal   [Q-6 gate]
                               └─▶ S8 Readiness + E2E   [slither gate; Q-3/Q-4 recorded]
                                    └─▶ (post-cycle) operator launch execution per runbook
```

Strictly sequential; no sprint requires authority or code produced by a later sprint. (Verified per sprint: S2 tests use harness addresses for `rig`/`reserve`; S3's treasury leg target is a plain address; S4 builds `VuxPoolDeployer` before the treasury constructor tests need it; S6 reads S2–S5 surfaces; S7 deploys S2–S6 artifacts; S8 consumes S7 evidence.)

---

## Appendix

### A. PRD Feature Mapping (complete P0 coverage)

| PRD surface | Sprint home(s) | Status |
|---|---|---|
| FR-1 genesis state & supply | 2 (VUX ctor semantics), 7 (GenesisDeployer + rehearsal), 8 (conversion-evidence procedure in runbook) | Planned |
| FR-2 throne & Dutch pricing | 3 | Planned |
| FR-3 clock, UPS schedule, tail | 3 | Planned |
| FR-4 settlement & adaptive 8%-floor routing (v2.1.0) | 3 | Planned |
| FR-5 VEM issuance cap | 3 | Planned |
| FR-6 bootstrap settlement | 3 | Planned |
| FR-7 Hard Reserve & redemption | 2 (contract + math), 3 (settlement interplay) | Planned |
| FR-8 Strategic receipt & custody separation | 4 (custody; Strategic residual leg routed in 3) | Planned |
| FR-9 classification (P0 accounting) | 4 | Planned |
| FR-10 POL (P0 classification/conduct) | 5 | Planned |
| FR-11 VYRF (P0 outcome) | 5 | Planned |
| FR-12 revenue policy surface (P0 boundary) | 4 (bounds + negatives); policy USE = P1 | Planned |
| FR-13 LSG (P0 boundary + activation authority) | 4 (slot/interface/negatives); module implementation = P1 | Planned |
| FR-14 observability / accounting truth | 3–5 (events at emit sites), 6 (completeness audit + indexer + reconstruction) | Planned |
| FR-15 truthful mining UX | 6 | Planned |
| FR-16 operator/risk/emergency boundaries | 4 (role topology), 2/3/5 (structural absences), 8 (traceability review) | Planned |
| §10 INV-1…37 register | introduced 3, extended 4–5, closed 8 (see Appendix D) | Planned |
| §11 FB-1…18 | per assigned method across 3–8 (see Appendix D) | Planned |
| §12 NFR-SEC / REL / TRUST / ACCT / COMP / UX | SEC 2–5,7; REL 3,5; TRUST 6,8; ACCT 4,6; COMP 1,8; UX 6 | Planned |
| §13 YELLOW disclosure | 6 (UI/docs), 8 (inventory review) | Planned |
| §15 PROV-1…9 | 1 (gates live), 6/8 (off-chain gates), continuous CI | Planned |
| §16 R-1…R-14 reserved | preserved everywhere; per-sprint review sweep + runbook input slots (8) | Reserved (not resolved) |
| §17 quarantine | CI grep from 1 | Enforced |
| §20.1 launch criteria | 8 (sweep) | Planned |
| §21 operator reviewability | 8 (evidence pack answers) | Planned |
| §22 assumptions/dependencies | Q-3/Q-4/Q-6 per Operator Gates section | Preserved |

### B. SDD Component Mapping

| SDD component | Sprint | Status |
|---|---|---|
| Repo/CI/provenance scaffold (§2.1, §7.3) | 1 | Planned |
| `VUX.sol` (§1.4, §5.2.1) | 2 | Planned |
| `HardReserve.sol` (§1.4, §5.2.3) | 2 | Planned |
| `Rig.sol` (§1.4, §1.5, §5.2.2) | 3 | Planned |
| `VuxPoolDeployer.sol` (§1.4) | 4 (implementation + unit proofs), 7 (genesis-context proofs) | Planned |
| `StrategicTreasury.sol` — custody/accounting/admission/LSG slot (§1.10, §1.11 P0 surface, §5.2.5) | 4 | Planned |
| `StrategicTreasury.sol` — POL sleeve/callbacks/VYRF (§1.6) | 5 | Planned |
| `Lens.sol` (§5.2.4) | 6 | Planned |
| Event schema (§3.2) | emit sites 3–5; completeness audit 6 | Planned |
| Indexer + PostgreSQL (§3.3) + REST (§5.3) | 6 | Planned |
| Frontend (§4) | 6 | Planned |
| `GenesisDeployer.sol` (§1.4, §1.7) | 7 | Planned |
| Deployment runbook (§1.7, Phase 5) | 8 | Planned |
| `LSGSignals` module (§1.11), strategy adapters, waterfall use, ROOT/GIGA | **P1 — excluded from cycle-002** | Deferred |

### C. PRD Goal Mapping

| Goal ID | Goal Description | Contributing Tasks | Validation Task |
|---------|------------------|-------------------|-----------------|
| G-1 | Faithful monetary core (genesis, KOTH, adaptive 8%-floor routing, VEM, redemption exactly as frozen) | 2.1–2.6, 3.1–3.7, 4.1, 5.3, 6.2, 7.1–7.6 | Sprint 8: Task 8.E2E |
| G-2 | Dual-treasury separation, failure independence | 3.6, 4.1–4.9, 5.1–5.6, 6.3, 6.5, 7.4 | Sprint 8: Task 8.E2E |
| G-3 | Truthful UX (three-tier truth never conflated) | 6.2–6.8, 8.7 | Sprint 8: Task 8.E2E |
| G-4 | LSG-ready boundary (inactive, bounded, activation authority present) | 4.6, 4.8 | Sprint 8: Task 8.E2E |
| G-5 | Provenance discipline (default-deny carried through) | 1.1–1.8, 2.6, 3.7, 6.1, 8.1, 8.5 | Sprint 8: Task 8.E2E |
| G-6 | Operator reviewability (acceptance questions answerable from artifacts) | 4.9, 5.6, 7.6, 8.2, 8.4, 8.6–8.8 | Sprint 8: Task 8.E2E |

**Goal Coverage Check:**
- [x] All PRD goals have at least one contributing task
- [x] All goals have a validation task in the final sprint (Task 8.E2E)
- [x] No orphan tasks (every task annotated with ≥1 goal)

**Per-Sprint Goal Contribution:** S1: G-5 (+G-1 hash constant). S2: G-1, G-5. S3: G-1, G-2, G-5. S4: G-2, G-4, G-1, G-6. S5: G-2, G-1, G-6. S6: G-3, G-2, G-5, G-1. S7: G-1, G-2, G-5, G-6. S8: all six.

### D. Invariant & Failure-Behavior Ownership (verification spine)

| Register | Introduced / proven | Extended / re-proven | Closed |
|---|---|---|---|
| INV-1…5 (supply/genesis-mint gates) | Sprint 2 units | Sprint 3 harness; Sprint 7 genesis | Sprint 8 matrix |
| INV-6…9, 12, 13, 18…22 (VEM/settlement) | Sprint 3 property+invariant | Sprints 4–5 full-suite runs | Sprint 8 |
| INV-10, 14…17 (Reserve/redemption) | Sprint 2 | Sprint 3 harness | Sprint 8 |
| INV-23, 24, 28, 30, 31 (Strategic accounting) | Sprint 4 | Sprint 5 | Sprint 8 |
| INV-25, 26, 27, 29 (POL/VYRF) | Sprint 5 (27 treasury-side; module-side = P1) | Sprint 7 genesis POL | Sprint 8 |
| INV-32…34 (LSG boundary) | Sprint 4 negatives | — (module tests = P1) | Sprint 8 |
| INV-35 (failure independence) | Sprint 4 FB-5 | Sprint 7 rehearsal | Sprint 8 |
| INV-36 (YELLOW coupling) | Sprint 6 | Sprint 8 inventory | Sprint 8 |
| INV-37 (no source-authority expansion) | Sprint 1 gates | every sprint's CI | Sprint 8 |
| FB-2,3,4,13,14,15,16 (automated) | Sprint 3 | Sprints 4–5 | Sprint 8 |
| FB-5, FB-7 (automated) | Sprint 4 / Sprint 5 | Sprint 8 E2E | Sprint 8 |
| FB-1, 6, 8, 9, 10, 11, 12 (review+scenario docs) | Sprints 3–5 named checklist entries | — | Sprint 8 matrix |
| FB-17, 18 (documented disclosure/analysis) | Sprint 6 (UI states + /trust) | Sprint 8 docs | Sprint 8 |

### E. Generation Evidence & Recorded Assumptions

| fact | value |
|---|---|
| Node | `/sprint-plan` (planning-sprints skill), operator-dispatched unattended, cycle-002 |
| Beads | HEALTHY (br 0.1.23); epics+tasks created at this node with edge-or-none dependencies |
| Ledger | Schema reconciled at this node (dual-schema sync: `next_sprint_number` added, `global_sprint_counter` kept consistent); sprints 1–8 registered natively via `add_sprint`; cycle-002 `sdd` field set |
| Integrity | System Zone sha256 strict; single pre-existing Aleph inventory note (baseline-identical, not drift) |
| Flatline postlude | Not executed — `.loa.config.yaml` has no `flatline_protocol` section (auto-trigger unmet); manual option: `/flatline-review sprint` |
| Interview | Suppressed per operator node brief (planning envelope pre-answers capacity/priorities/sequencing); assumptions below per Karpathy #1 unattended rule |
| Artifact path | `grimoires/loa/sprint.md` (live-skill convention; operator brief's `sprint-plan.md` was conditional on the live skill) |

Recorded assumptions (falsifiable):
- [ASSUMPTION] Single implementing agent per sprint; strictly sequential sprints. — If the operator parallelizes, the dependency map above still gates ordering; only wall-clock changes.
- [ASSUMPTION] The VUX-original minimal test harness (no forge-std) is acceptable as the default. — If the operator prefers forge-std, a narrow refreeze delta at Sprint 1 substitutes with no downstream impact.
- [ASSUMPTION] Slither enters CI at Sprint 8 (whole-surface triage) rather than Sprint 1. — If the operator prefers earlier static analysis, the Task 8.1 gate moves earlier verbatim; nothing else changes.
- [ASSUMPTION] Cycle-002 ends at launch readiness; production launch execution (R-14 facts, Q-3 Safe, private bundle) is a post-cycle operator/founder action per the Sprint 8 runbook. — If the operator wants launch inside this cycle, a Sprint 9 (deployment execution) is added after Q-3/Q-4/Q-6 close; no earlier sprint changes.

---

*Generated by Sprint Planner Agent (Loa `/sprint-plan`), cycle-002. Sprints registered in the Sprint Ledger as global sprint-1…sprint-8.*
