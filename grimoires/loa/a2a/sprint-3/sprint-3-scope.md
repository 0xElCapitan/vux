## Sprint 3: Rig — Throne, Settlement, VEM & the Monetary Invariant Suite

**Duration:** ~4–5 focused engineering days (indicative)
**Scope:** LARGE (7 tasks)

### Sprint Goal
Complete the monetary core: the one-throne Dutch-priced KOTH engine with the 13-step atomic settlement, the **adaptive 8%-floor routing law** (`king = floor(80%)`; `hardTarget = min(retained, max(hardFloor, D_need))` → Hard; `strategic = retained − hardTarget` → Strategic; PRD FR-4 v2.1.0, SDD Appendix F note F-1), measured-`D_R` VEM (rejection against `hardTarget`), and bootstrap semantics (confirm-only: the adaptive law degenerates exactly at `Qraw = 0`) — proven by the property/fuzz and stateful-invariant suite, including randomized `(P, Qraw, B_pre, S_pre)` regime testing, that becomes the cycle's permanent monetary regression harness.

### Deliverables
- [ ] `Rig.sol` complete: Dutch pricing + successor opening, UPS halving schedule with epoch snapshot, `scheduleStart` at first public takeover, 13-step `take(maxPrice)` with the exact adaptive legs (`hardTarget`/`strategic` residual; zero-valued Strategic transfer skipped) / `D_R` measurement + rejection against `hardTarget` / `Qsafe`/`Qmint` / CEI + `nonReentrant`, bootstrap branch, `Settled` event (variable-leg semantics; `D_need` derivable), constants as `constant` incl. the 1,200 bp Strategic **cap** (sdd.md:L101-L123, L196-L229; SDD Appendix F, F-1)
- [ ] Property/fuzz suites for FR-2/3/4/5/6 acceptance formulas
- [ ] Stateful invariant harness (introduced here, extended in Sprints 4–5) covering INV-1…22 over random `take`/`redeem` sequences
- [ ] Automated FB scenario tests: FB-2, FB-3, FB-4, FB-13, FB-14, FB-15, FB-16; review-note documentation for FB-1

### Acceptance Criteria
- [ ] Price function matches `max(DECAY_FLOOR, opening × (1 − min(t,3000)/3000))` at boundary points t = 0 / 3000 / beyond, floor clip; successor opening `max(MINIMUM_OPENING, 2×P)` including the minimum branch (prd.md:L342-L344)
- [ ] UPS at every schedule boundary equals 4 / 2 / 1 / 0.5 / 0.25 / 0.125 / 0.0625 / 0.03125 / 0.015625 VUX/s; an epoch straddling a halving settles at its opening snapshot; `Qraw` caps at exactly `3000 × epochUPS` (prd.md:L359-L361)
- [ ] Randomized `(P, Qraw, B_pre, S_pre)` regime testing (weak/cheap through strong/premium): `king = floor(P×8000/10000)`; `retained = P − king`; `strategicCap = floor(P×1200/10000)`; `hardFloor = retained − strategicCap`; `D_need = ceil(Qraw×B_pre/S_pre)`; `hardTarget = min(retained, max(hardFloor, D_need))`; `strategic = retained − hardTarget`; legs sum to `P`; `hardFloor ≤ hardTarget ≤ retained`; `0 ≤ strategic ≤ strategicCap`; dust lands in Hard; `D_need ≤ hardFloor ⇒` exact equality with the prior static split (prd.md:L376)
- [ ] Property test ∀ `(B_pre, S_pre, D_R, Qraw)`: minted amount = `min(Qraw, floor(D_R × S_pre / B_pre))` and preserves `(B_pre+D_R)/(S_pre+Qmint) ≥ B_pre/S_pre`; a measured `D_R` inconsistent with the routed `hardTarget` rejects atomically (`InconsistentReserveDelta`); no storage cell records unmet `Qraw − Qsafe` (prd.md:L393-L395); VEM measured-delta invariant unchanged (`D_actual ≡ D_R`)
- [ ] Bootstrap (confirm-only — behavior unchanged): Reserve is genesis King, clock disabled, `Qraw = 0` (so `hardTarget = hardFloor`, `strategic = strategicCap` by degeneracy), first takeover routes ≈88%+/12%/0-mint, payer's epoch opens at current schedule rate, no second bootstrap state reachable (prd.md:L407-L408)
- [ ] Partial-failure injection: no state where some legs routed and others did not (prd.md:L378); settlement cannot rewrite a prior epoch or mint recipient (INV-21)
- [ ] Code-inspection checklist (narrowed prohibition): no branch of primary settlement reads time-phase, macro, NAV, ROOT/GIGA price, market price, oracle data, or operator preference — the adaptive computation consumes exactly `(P, Qraw, B_pre, S_pre)` plus own throne state (prd.md:L233, L377) — named checklist entry for review
- [ ] Invariant suite green over random op sequences: `B/S` monotone under authorized issuance (INV-13), supply attribution complete, INV-1…22 with INV-18/INV-19 in their amended adaptive form (prd.md:L608-L609)

### Technical Tasks
- [ ] Task 3.1: Rig pricing & schedule — Dutch decay, successor opening, `INITIAL_UPS >> min((t−scheduleStart)/30 days, 8)` snapshot, bootstrap decay anchor (`epochStart` = deployment), storage layout per sdd.md:L109-L122, routing constants as `constant`; FR-2/FR-3 boundary tests → **[G-1]** ⇐ none
- [ ] Task 3.2: `take(maxPrice)` 13-step settlement — payment pull; adaptive legs (`retained`, `strategicCap`, `hardFloor`, `D_need = ceil(Qraw×B_pre/S_pre)` via `Math.mulDiv`-family ceil, `hardTarget`, `strategic` residual with zero-transfer skip); Hard-leg transfer + `D_R = balanceOf(reserve) − B_pre` equality rejection against `hardTarget`; `Math.mulDiv` VEM; effects-before-final-interactions ordering; mint to outgoing King; king-leg delivery; `Settled` emission with variable-leg semantics (sdd.md:L196-L229; SDD Appendix F, F-1) → **[G-1]** ⇐ Task 3.1
- [ ] Task 3.3: Bootstrap branch — reserve-as-King detection forcing `Qraw = 0`, king-leg redirection to Reserve, `scheduleStart` set at first public takeover; FR-6 tests incl. no-second-bootstrap → **[G-1]** ⇐ Task 3.2
- [ ] Task 3.4: Property/fuzz suites — adaptive-leg arithmetic ∀ `(P, Qraw, B_pre, S_pre)` regimes (floor/cap/dust/degeneracy properties per the FR-4 acceptance list), VEM invariant ∀ tuples, expiry-no-carry, `maxPrice` slippage guard → **[G-1]** ⇐ Task 3.2
- [ ] Task 3.5: Stateful invariant harness (INTRODUCES the cycle-wide suite) — INV-1…22 handlers (INV-18/INV-19 in amended adaptive form) over random `take`/`redeem` sequences with time warps across halvings and settlement regimes spanning `D_need ≤ hardFloor` through `D_need > retained` → **[G-1]** ⇐ Task 3.2
- [ ] Task 3.6: FB scenario tests — FB-2 (no challenger), FB-3 (weak demand), FB-4 (high demand), FB-13 (mass redemption), FB-14 (below-backing trading), FB-15/16 (no rescue/recap path exists) → **[G-1, G-2]** ⇐ Task 3.5
- [ ] Task 3.7: Review documentation — prohibited-signal inspection checklist (FR-4.3), FB-1 mining/redemption independence note, PROV-3 statement (routing/VEM/D_R written from PRD equations only; Rig skeleton from allowlisted file) → **[G-1, G-5]** ⇐ Task 3.2

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
