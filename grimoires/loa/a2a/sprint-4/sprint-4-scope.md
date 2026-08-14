## Sprint 4: Strategic Treasury I — Custody, Classification & Authority Boundaries

**Duration:** ~5–6 focused engineering days (indicative)
**Scope:** LARGE (9 tasks)

### Sprint Goal
Ship the role-gated Strategic Treasury custody and its arithmetic classification engine — admission registry with immutable per-strategy modes and the 24 h maturity delay, the three flow primitives, revenue distribution bounds, and the LSG P0 activation authority — proving that principal and marks are arithmetically non-distributable and that no treasury surface can reach the monetary core.

### Deliverables
- [ ] `VuxPoolDeployer.sol` (vendored-unit `=0.7.6`): canonical CREATE2 `deployCanonicalPool` (upstream deployer semantics), salted `msg.sender`-binding commitment gate, one-shot, Finding-4 parameter-domain checks, permanent `owner() == address(0)` (sdd.md:L190-L194)
- [ ] `StrategicTreasury.sol` (part I): constructor immutables + wiring re-verification, AccessControl roles (creator-granted), receipt accounting, admission registry (`mode` immutable, `ADMISSION_DELAY = 24 h`, instant removal), `deployToStrategy`/`recallFromStrategy` caps, `returnFor`/`harvestYield`/`redeemUnits`/`closeStrategy`, four-leg `allocateRevenue` + `signalerBudget` earmark + `burnVuxRevenue` + `setOpsRecipient` (corrected P0 revenue boundary per Task 4.5), classification events (sdd.md:L135-L148, L285-L321)
- [ ] LSG P0 authority: `lsgModule` slot (launch `address(0)`), `activateLSG`/`deactivateLSG`, `ILSGModule` interface, `deployMarginalBySignal` (code P0, use P1), treasury-side `fundSignalerProgram` gating (sdd.md:L146, L322-L344)
- [ ] Mode-aware accounting property suite + INV-23…34 boundary/invariant extensions + FB-5 scenario

### Acceptance Criteria
- [ ] Treasury constructor re-verifies `POOL.factory() == VUX_POOL_DEPLOYER`, `IUniswapV3Factory(VUX_POOL_DEPLOYER).owner() == address(0)`, token ordering/fee, and derives tick bounds from `pool.tickSpacing()`; roles granted to `msg.sender` (creator); no `setPool`/initializer exists (sdd.md:L140, L718-L725)
- [ ] Admission: `mode` fixed at admission and immutable (change = remove + re-admit + re-delay); deployment blocked until `maturesAt` (`AdmissionNotMatured`); removal/recall always instant and unblockable (sdd.md:L147)
- [ ] Accounting properties ∀ flow sequences ∀ modes (sdd.md:L856): Σ revenue distributions ≤ realized-revenue credits; returned principal never credits revenue; arbitrary-asset returns rejected (`UnknownReturnAsset`); NETTING revenue only beyond full return; CLAIM harvest with decreased `principalUnits` reverts; UNITIZED basis release conserves (Σ `basisReleased` = original basis over full unwind), gain→revenue / shortfall→loss never negative revenue; `closeStrategy` write-off only reduces principal
- [ ] `allocateRevenue` negatives: `asset == VUX` rejected (`VuxRevenueMustBurn`); non-WETH Hard leg rejected (`HardLegMustBeWeth`); over-accumulator rejected (`RevenueExceedsRealized`); ABI assertion: exactly four legs — no `toMarketInfra` parameter and no `marketInfraBudget` symbol exists (2026-08-12 remediation) — FR-12 negative acceptance "no configuration of the policy surface can reach Reserve principal or mint" (prd.md:L505-L506)
- [ ] Percentages are call-time arguments only — grep-verified no stored ratio constant exists (R-9 execution-reserved; waterfall ratios are founder-accepted doctrine, never operator-set; §17 quarantine)
- [ ] LSG P0: launch state inactive (`lsgModule == address(0)`); `activateLSG`/`deactivateLSG` operator-gated + evented; no numeric threshold or calendar in code (F-50); signal surfaces revert `LSGInactive` before activation; INV-32…34 negatives green (prd.md:L522-L524)
- [ ] FB-5: simulated 50%/80%/100% Strategic loss leaves `B`, redemption, VEM, and mint authority **bit-identical** (prd.md:L444)
- [ ] Role topology: operator roles exist on `StrategicTreasury` only; negative tests prove no treasury call path reaches Reserve principal, redemption math, mint authority, or routing constants (NFR-SEC-7; INV-33)
- [ ] `VuxPoolDeployer` unit tests: wrong salt reverts, wrong `msg.sender` with correct salt reverts, second call reverts, domain violations each revert, deployed pool address equals independent `create2(deployer, keccak256(abi.encode(token0,token1,fee)), POOL_INIT_CODE_HASH)` recompute (sdd.md:L859)

### Technical Tasks
- [ ] Task 4.1: `VuxPoolDeployer.sol` in the vendored `=0.7.6` unit — canonical `UniswapV3PoolDeployer` derivation, commitment gate, one-shot latch, domain checks, `owner()==address(0)`; unit tests incl. independent CREATE2 recompute → **[G-1, G-2]** ⇐ none
- [ ] Task 4.2: Treasury skeleton — constructor immutables + re-verification, AccessControl (`DEFAULT_ADMIN_ROLE`/`OPERATOR_ROLE` to creator), storage cells per sdd.md:L140, receipt accounting + `StrategicInflow`/`StrategicOutflow` events → **[G-2]** ⇐ Task 4.1
- [ ] Task 4.3: Admission registry — `admitStrategy`/`removeStrategy` (mode + cap + `maturesAt`; `StrategyAdmitted`/`StrategyRemoved`), `deployToStrategy`/`recallFromStrategy` (admitted+matured+cap) → **[G-2]** ⇐ Task 4.2
- [ ] Task 4.4: Flow primitives — `returnFor` (principal-first netting, in-call classification), `harvestYield` (CLAIM: measured own-balance deltas + units-intact guard), `redeemUnits` (UNITIZED: ceil basis release, gain/shortfall booking), `closeStrategy` (loss-only write-off after removal) → **[G-2]** ⇐ Task 4.3
- [ ] Task 4.5: Distribution surface (corrected P0 revenue boundary, 2026-08-12 remediation; sdd.md §1.10 + Appendix F F-2) — `allocateRevenue` with **four** call-time legs (compound / Hard **WETH-only** / ops / signalers; accumulator bound Σ ≤ `realizedRevenue[asset]`); `toOps` = payment of an actual approved operating expense ONLY (never the future 25% Operator Reserve contribution — its credit/accumulation/sweep/allocator-exclusion mechanics are a P1/future design obligation, NOT built here); `signalerBudget` as the sole earmark (no `toMarketInfra` argument, no `marketInfraBudget` symbol — market infrastructure is funded via Strategic capital deployment policy, never a revenue leg); `burnVuxRevenue`, `setOpsRecipient` + events → **[G-2]** ⇐ Task 4.4
- [ ] Task 4.6: LSG P0 authority — `lsgModule` slot, `activateLSG`/`deactivateLSG` + events, `ILSGModule` interface, `deployMarginalBySignal` (reads signal view, filters admitted+matured+cap-headroom, pro-rata floor split via §1.10 ledger, `SignalConsumed`), treasury-side `fundSignalerProgram` (requires active module, spends earmark) → **[G-4, G-2]** ⇐ Task 4.3, Task 4.5
- [ ] Task 4.7: Mode-aware accounting property suite per sdd.md:L856 (all modes, all guards, mode immutability) → **[G-2]** ⇐ Task 4.4, Task 4.5
- [ ] Task 4.8: Boundary negatives + invariant extension — INV-23/24/28/30/31 handlers added to the Sprint-3 harness; INV-32/33/34 LSG-boundary negatives; FB-5 bit-identical-core scenario; FB-15/16 no-path re-checks from treasury surfaces → **[G-2, G-4]** ⇐ Task 4.6, Task 4.7
- [ ] Task 4.9: Review documentation — FB-6/9/10/12 scenario notes; R-1…R-14 reservation sweep (nothing frozen); adversarial-adapter argument (fraud ≤ theft, sdd.md:L302) → **[G-2, G-6]** ⇐ Task 4.5

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

