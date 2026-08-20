## Sprint 8: Launch Readiness — Hardening, Traceability & E2E Goal Validation

**Duration:** ~4–5 focused engineering days (indicative)
**Scope:** LARGE (8 tasks)

### Sprint Goal
Close the cycle: static-analysis hardening behind its provenance gate, the complete 37-invariant/18-failure-behavior traceability matrix, the §20.1 launch-criteria sweep, release-compliance files, the deployment runbook with every operator-reserved input slot explicit — and the end-to-end validation that every PRD goal is achieved by the assembled system.

### Deliverables
- [ ] Slither 0.10.x behind its accepted pin (refreeze §9) + triaged baseline + forge lint in CI
- [ ] Traceability matrix: INV-1…37 → carrying tests; FB-1…18 → assigned method evidence (test / review checklist / documented analysis per prd.md:L669); FR acceptance-checkbox sweep
- [ ] §20.1 launch-criteria sweep (all eight rows) + core coverage ≥90% gate (sdd.md:L871)
- [ ] Release compliance: root `LICENSE` (unmodified GPLv3), `THIRD_PARTY_NOTICES.md` accuracy vs. vendored reality, SPDX sweep (NFR-COMP)
- [ ] Deployment runbook: founder one-shot USD→WETH conversion procedure, private same-block bundle procedure, launch-secret checklist, R-14 fact-recording template, **Q-3 Safe-composition required-input slot**, Q-6 recorded evidence, Q-4 pre-launch legal-review checklist item
- [ ] Task 8.E2E goal-validation evidence; cycle closeout prep (branch batch-pruning list)

### Acceptance Criteria
- [ ] Zero unexplained slither findings (triaged baseline documented); slither entered CI only after its pin acceptance
- [ ] Traceability: 37/37 invariants and 18/18 FB rows have named evidence per their assigned method; review-only items (FB-1, FB-6, FB-8…FB-12, FB-17, FB-18; prohibited-signal inspection) have named checklist entries in the review artifacts (sdd.md:L867)
- [ ] §20.1 sweep green: FR-1…FR-11 + FR-14…FR-16 acceptance criteria pass; LSG inactive with activation authority present; all 37 invariants demonstrated; all 18 FB behaviors demonstrated; genesis/conversion evidence *procedure* verified (production values at deployment); YELLOW disclosure present; PROV-1…9 clean; truthful-UX review passed (prd.md:L878-L886)
- [ ] Line coverage ≥90% on core contracts; full accumulated invariant suite green
- [ ] Runbook complete with every operator-reserved input explicitly slotted (Q-3 Safe facts, fee tier/tickSpacing, conversion values, schedule start) and none resolved in-repo
- [ ] Release files exact: GPLv3 text unmodified; TPN §6/§6.1/§6.2 match vendored reality byte-for-byte with the accepted version
- [ ] E2E validation (Task 8.E2E) documents each goal G-1…G-6 with pass evidence; no goal marked "not achieved" without explicit justification
- [ ] No production secret, address, or broadcast artifact anywhere in repo/CI (final hygiene sweep)

### Technical Tasks
- [ ] Task 8.1: Static-analysis provenance gate — slither 0.10.x pin evidence; **STOP for operator acceptance**; then slither + forge lint in CI with triaged baseline → **[G-5]** ⇐ none
- [ ] Task 8.2: Traceability matrix — INV/FB/FR evidence map generated from test headers (`// carries:` convention, sdd.md:L867) + named review-checklist entries for review-only items → **[G-6, G-1, G-2]** ⇐ none
- [ ] Task 8.3: §20.1 launch-criteria sweep + ≥90% core-coverage gate + full-suite CI run → **[G-1, G-2, G-3, G-4, G-5]** ⇐ Task 8.2
- [ ] Task 8.4: Task 8.E2E — End-to-End Goal Validation (see table below) → **[G-1, G-2, G-3, G-4, G-5, G-6]** ⇐ Task 8.3
- [ ] Task 8.5: Release compliance — LICENSE/TPN/SPDX verification against vendored reality (NFR-COMP; PROV-8) → **[G-5]** ⇐ Task 8.1
- [ ] Task 8.6: Deployment runbook — conversion procedure, private-bundle procedure, launch-secret checklist, R-14 template, Q-3 input slot, Q-6 evidence reference, Q-4 pre-launch checklist item → **[G-1, G-6]** ⇐ Task 8.2
- [ ] Task 8.7: Operator docs — YELLOW disclosure inventory, FB-17/FB-18 documented analyses, no-trustless-claims review (NFR-TRUST) → **[G-3, G-6]** ⇐ Task 8.5
- [ ] Task 8.8: Cycle closeout prep — branch batch-pruning list, artifact inventory for `/ship`-time archive (NOT executed here) → **[G-6]** ⇐ Task 8.4

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
- [ ] Each goal validated with documented evidence; integration points verified end-to-end
- [ ] No goal marked "not achieved" without explicit justification

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
