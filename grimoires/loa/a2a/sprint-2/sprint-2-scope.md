## Sprint 2: VUX Token & Hard Reserve (Exit-Right Primitives)

**Duration:** ~3–4 focused engineering days (indicative)
**Scope:** MEDIUM (6 tasks)

### Sprint Goal
Ship the two narrow-authority immutable primitives — the VUX token (mint=rig, burnForRedemption=reserve, no `burnFrom`) and the ownerless Hard Reserve with one-transaction approval-free redemption and constructor-time contamination sanitization — with their exact-math and authority-gate proofs.

### Deliverables
- [ ] `VUX.sol` complete (adapted from allowlisted `Unit.sol`/`IUnit.sol`): ERC20+Permit, constructor genesis mint semantics (`150_000e18` to creator + 1 raw to reserve), `mint` onlyRig, `burn`, `burnForRedemption` onlyReserve, **no** general `burnFrom` (sdd.md:L97)
- [ ] `HardReserve.sol` complete: `redeem(q, to)` one-tx approval-free (CEI, `nonReentrant`, `floor(B×q/S)`, zero fee, `S_MIN`), views, constructor sanitization (born-empty + `PreGenesisWethSanitized`), structural absences (sdd.md:L125-L133)
- [ ] Redemption property/fuzz suite + token authority negative suite + runtime-bytecode inspection evidence

### Acceptance Criteria
- [ ] INV-1…5 unit-tested: complete-supply truth; exact genesis constructor amounts; mint gated to the immutable `rig` address; no discretionary mint/burn path (prd.md:L581-L587)
- [ ] `burnForRedemption` reverts for every caller except the immutable `reserve`; no `burnFrom` symbol exists in the ABI (sdd.md:L678; FR-7.4 "no approval gate", prd.md:L251)
- [ ] Property test ∀ tested `(B, S, q)`: `payout = floor(B×q/S)`, zero fee, Reserve-favoring rounding, pre-redemption values (prd.md:L425-L426); exhaustive-redemption test preserves `S_MIN = 1` raw and a positive WETH remainder (prd.md:L253)
- [ ] Reserve external surface is exactly `redeem` + views: no owner, roles, pause, upgrade, arbitrary call, approval, sweep, receive-hook, selfdestruct, payable path (FR-7.2, INV-14) — verified by ABI enumeration + review checklist
- [ ] Constructor sanitization proven: prefunded predicted address → constructor transfers full amount to creator, emits `PreGenesisWethSanitized`, requires born-empty; **runtime bytecode inspection proves no transfer-out/sweep path survives deployment** (sdd.md:L132)
- [ ] Reserve code passes only `msg.sender` to `burnForRedemption` — negative test proves it cannot burn a third party (sdd.md:L130)
- [ ] PROV-5 similarity statement recorded: Hard Reserve implemented from the canonical equations; no prohibited source consulted (prd.md:L764)

### Technical Tasks
- [ ] Task 2.1: `VUX.sol` — adapt allowlisted `Unit.sol`/`IUnit.sol` (SPDX `MIT AND GPL-3.0-or-later`); ERC20+ERC20Permit base from vendored OZ; constructor mint semantics; `mint` onlyRig; `burn`; `burnForRedemption` onlyReserve; delete `burnFrom` → **[G-1]** ⇐ none
- [ ] Task 2.2: Token authority suite — INV-1…5 units, mint/burn gate negatives (`NotRig`/`NotReserve`), ABI assertion that no `burnFrom` exists → **[G-1]** ⇐ Task 2.1
- [ ] Task 2.3: `HardReserve.sol` — VUX-original from spec equations: `redeem` (snapshot `B`/`S` → burn via `burnForRedemption(msg.sender, q)` → pay; `nonReentrant`; `q ≤ S − S_MIN`), `backing()`/`previewRedeem` views, constructor sanitization block → **[G-1]** ⇐ Task 2.1
- [ ] Task 2.4: Redemption property/fuzz suite — exact payout formula, zero fee, rounding direction, `S_MIN` exhaustion, INV-10/14/15/16/17 → **[G-1]** ⇐ Task 2.3
- [ ] Task 2.5: Constructor-sanitization tests + runtime-bytecode inspection artifact (no surviving transfer-out path) → **[G-1]** ⇐ Task 2.3
- [ ] Task 2.6: Structural-absence review checklist (FR-7.2/7.3) + PROV-5 similarity-review note for `HardReserve.sol` → **[G-1, G-5]** ⇐ Task 2.3

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
