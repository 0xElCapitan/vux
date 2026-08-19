## Sprint 7: Genesis — Non-Griefable Launch Implementation & Adversarial Rehearsal

**Duration:** ~5–6 focused engineering days (indicative)
**Scope:** LARGE (6 tasks)

### Sprint Goal
Implement the two-transaction constructor-genesis exactly as accepted (CREATE nonce-predicted wiring, protocol-owned CREATE2 pool, in-transaction funding wrap, closing self-verification) and **prove** — by fork rehearsal against a full-knowledge adversary — that leaked addresses, hostile lookalike pools, arbitrary prefunding, and mempool racing cannot alter one wei of the exact genesis state.

### Deliverables
- [ ] Q-6 evidence: fork-verified canonical-WETH native-wrap (`deposit()`) semantics, recorded for R-14
- [ ] `GenesisDeployer.sol`: constructor-executed genesis steps 0–10 per sdd.md:L158-L171 (snapshot + in-tx `WETH.deposit`, five CREATEs with predict-verify, commitment-gated pool deploy + initialize + verify, POL provisioning, exact `B0` transfer, Safe grant, renounce, residual sanitizing sweep, closing self-verification)
- [ ] Off-chain deterministic `sqrtP0X96` encoder (floor `isqrt((n<<192)/d)` convention + quantization-delta evidence, sdd.md:L185)
- [ ] Genesis wiring proof suite + full-knowledge adversarial rehearsal + two-transaction launch rehearsal script (rehearsal values only)
- [ ] Genesis evidence pack mapping every launch-security proof obligation to its test artifact

### Acceptance Criteria
The rehearsal suites must prove all twelve launch-security obligations (operator brief), each mapped to a named test:
- [ ] Leaked future addresses cannot grief genesis (full-knowledge adversary; launch succeeds unchanged at intended addresses)
- [ ] Hostile public-factory lookalike pools (every fee tier, hostile init, one-sided liquidity) are irrelevant — referenced nowhere
- [ ] Canonical pool CREATE2 identity exact: independent recompute `create2(vuxPoolDeployer, keccak256(abi.encode(token0,token1,fee)), POOL_INIT_CODE_HASH)` equals deployed pool equals `treasury.POOL()` (sdd.md:L859)
- [ ] Arbitrary prefunding (WETH to every predicted address + forced ETH) cannot alter exact genesis state — per-address defense table outcomes verified (sdd.md:L172-L184)
- [ ] Future-HardReserve prefunding constructor-sanitized: **very large** prefund → `PreGenesisWethSanitized` → ends as unattributed Strategic inventory
- [ ] Final physical Reserve balance is exactly `B0` (`WETH.balanceOf(reserve) == B0`), physical `N0 = B0/S0` and `P0/N0 = 1.10` intact, first-settlement `B_pre == B0` (sdd.md:L187)
- [ ] No temporary authority survives: roles renounced, deployer holds nothing, one-shot consumed (second `deployCanonicalPool` reverts), no callable genesis surface exists
- [ ] Launch EOA gains no protocol authority (role-topology sweep: Safe-only on treasury; zero roles elsewhere)
- [ ] `VuxPoolDeployer` consumed and ownerless (`owner() == address(0)`; `setFeeProtocol` unreachable)
- [ ] Exact pool initialization price verified: `slot0.sqrtPriceX96 == sqrtP0X96`; ratio/cushion checks in recorded wei values (`BOOTSTRAP_OPENING ≤ P0×S0 − B0`)
- [ ] Callback authorization one-shot and exact-pool-bound during genesis POL provisioning (mint callback path exercised in-genesis)
- [ ] Production secrets remain outside repo/CI artifacts: rehearsal uses rehearsal values only; `broadcast/**` hygiene check green; launch-secret checklist per sdd.md:L270
- [ ] Plus: mutated-extra-CREATE negative reverts the whole launch (nonce stability); commitment-gate negatives (wrong salt / wrong sender / second call); domain-violation negatives; `vux.balanceOf(deployer) == 0` and `weth.balanceOf(deployer) == 0` after sweep; POL position liquidity > 0 owned by treasury; `rig.king() == reserve`; S0 exact; gas/initcode headroom measured (sdd.md:L859-L860)

### Technical Tasks
- [ ] Task 7.1: Q-6 evidence task — fork-verify canonical WETH `deposit()` native-wrap; record evidence; **if the fact fails: STOP → operator fallback transition** (pre-approval funding + §1.7 control) before continuing → **[G-1]** ⇐ none
- [ ] Task 7.2: `GenesisDeployer.sol` — constructor genesis steps 0–10 with `predict(n)` RLP computation, in-tx equality requires, commitment-bound pool deployment, POL provisioning through the authenticated mint callback, exact-`B0` delta-verified transfer, Safe handoff, renounce, sanitizing sweep, closing self-verification (sdd.md:L158-L187) + off-chain `sqrtP0X96` encoder → **[G-1]** ⇐ Task 7.1
- [ ] Task 7.3: Genesis wiring proof suite — predicted-vs-actual equality, mutated-nonce negative, independent CREATE2 recompute, nonce stability across pool CREATE2, commitment/domain negatives, exact `slot0`, recorded-wei ratio/cushion, contamination arithmetic, closing-sweep completeness, gas/initcode headroom (sdd.md:L859) → **[G-1]** ⇐ Task 7.2
- [ ] Task 7.4: Full-knowledge adversarial rehearsal per sdd.md:L860 — prefund every predicted address (incl. very-large Reserve prefund), hostile lookalikes at every tier, salt-extraction + wrong-sender attempts, one-shot consumption attempts, mempool racing/spam, forced ETH; assert exact economics, zero attacker credit, zero surviving authority, callback forgery reverts → **[G-1, G-2]** ⇐ Task 7.3
- [ ] Task 7.5: Two-transaction launch rehearsal script (tx1 + tx2, rehearsal values) + `broadcast/**`/secret-hygiene check (no production values anywhere) → **[G-1]** ⇐ Task 7.2
- [ ] Task 7.6: Genesis evidence pack — obligation → test-artifact map for the twelve proofs + rehearsal transcripts, for audit and operator review → **[G-1, G-6]** ⇐ Task 7.4, Task 7.5

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
