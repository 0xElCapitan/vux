## Sprint 5: Strategic Treasury II — POL, Callback Authentication & VYRF

**Duration:** ~4–5 focused engineering days (indicative)
**Scope:** MEDIUM (6 tasks)

### Sprint Goal
Complete the treasury's POL sleeve against the vendored pool — position mint/increase/decrease and in-protocol VUX purchase behind one-shot context-authenticated callbacks with zero standing approvals — and realize the frozen VYRF outcome (VUX fees burn; WETH fees → Hard one-way; principal stays Strategic) as a mechanically tested ordering fact.

### Deliverables
- [ ] POL operations: `mintPolPosition`, `increasePol`, `decreasePol` (fee-first ordering), `buyVuxForPol` (slippage-bounded in-protocol swap) with cost-basis cells `polVuxPrincipal`/`polWethPrincipal` (sdd.md:L139-L143)
- [ ] One-shot callback authentication: `uniswapV3MintCallback`/`uniswapV3SwapCallback` with arm→validate→consume→pay context lifecycle and `CallbackNotConsumed` outer check (sdd.md:L252-L258)
- [ ] `harvestPol()` permissionless VYRF: poke → collect → VUX burn + WETH→`HardReserve` in one call; `VyrfHarvest` event (sdd.md:L141-L144)
- [ ] Full callback negative suite + VYRF/POL invariant extensions + fork E2E harvest scenario

### Acceptance Criteria
- [ ] Callback negative suite green (sdd.md:L858): forged caller; canonical pool with no active context; wrong callback type; wrong token direction; amount above committed maximum; nested/reentrant attempt; nonempty data; **duplicate second callback under one armed operation reverts even from the canonical pool** (mock double-callback test); outer op with unconsumed authorization reverts (`CallbackNotConsumed`)
- [ ] Zero standing approvals after every pool operation (asserted per-op)
- [ ] VYRF ordering invariant: position `tokensOwed` outside a `decreasePol` execution consists of fees only (sdd.md:L142); principal sweeps atomically inside `decreasePol` against cost-basis cells
- [ ] End-to-end scenario: fee accrual → `harvestPol` → VUX fee burn observed with cause pairing, WETH fees land in `B`, returned principal books as principal (FR-11 acceptance, prd.md:L489-L490); the general-waterfall surface provably cannot receive POL fee yield
- [ ] `buyVuxForPol`: `minVuxOut` + `sqrtPriceLimitX96` enforced; purchased VUX books as POL inventory principal; no path mints VUX for POL (INV-26 negative)
- [ ] No code path calls `HardReserve.redeem` from the treasury (FR-10.3 conduct, negative test + review)
- [ ] INV-25/26/27 (treasury-side)/28/29 handlers added to the invariant harness; FB-7 (POL failure leaves Hard arithmetic unchanged) and FB-8 (unharvested fees counted nowhere) scenarios green
- [ ] `harvestPol` is permissionless, parameter-free, and performs no swap (sdd.md:L144) — keeper absence cannot corrupt classification (NFR-REL-2)

### Technical Tasks
- [ ] Task 5.1: POL position ops — `mintPolPosition`/`increasePol` with committed-maxima context arming; direct-on-pool position (no periphery, no NFT); quantization-dust inventory treatment (sdd.md:L168) → **[G-2]** ⇐ none
- [ ] Task 5.2: `decreasePol` (poke → collect fees → burn liquidity → collect principal, atomically) + `buyVuxForPol` (CTX_SWAP, measured output verification) → **[G-2]** ⇐ Task 5.1
- [ ] Task 5.3: `harvestPol()` VYRF — zero-liquidity poke, collect, VUX burn + WETH transfer to Reserve in-call, `VyrfHarvest`; `nonReentrant`; permissionless → **[G-2, G-1]** ⇐ Task 5.1
- [ ] Task 5.4: Callback authentication negative suite per sdd.md:L858 incl. the mock-pool double-callback rig and zero-approval assertions → **[G-2]** ⇐ Task 5.1, Task 5.2
- [ ] Task 5.5: VYRF/POL invariant + scenario extension — `tokensOwed` invariant, INV-25…29 handlers, FB-7/FB-8, wash-trading-is-donation documentation note (sdd.md:L950) → **[G-2]** ⇐ Task 5.3
- [ ] Task 5.6: Fork E2E + conduct review — anvil-fork harvest end-to-end (sdd.md:L862); FR-10.3 no-redeem-path review; INV-26 no-mint-sourcing negative → **[G-2, G-6]** ⇐ Task 5.3, Task 5.4

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

