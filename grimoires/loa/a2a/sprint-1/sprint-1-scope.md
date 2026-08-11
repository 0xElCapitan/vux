## Sprint 1: Provenance-Gated Foundation & Authorized Vendoring

**Duration:** ~3–4 focused engineering days (indicative)
**Scope:** LARGE (8 tasks)

### Sprint Goal
Stand up the Foundry repository with the accepted provenance authority mechanically enforced — every authorized upstream file vendored byte-identically, every fail-closed CI gate live — so that no later sprint can drift from the accepted census even by one byte.

### Deliverables
- [ ] Foundry scaffold with dual compilation units: `=0.8.28` (VUX-original + Miner-derived) and `=0.7.6` vendored v3 unit with the exact refreeze §7 build settings (optimizer 800, `evm_version = "istanbul"`, `bytecode_hash = "none"`); Foundry pinned `v1.0.0` → `8692e926…` (refreeze §6)
- [ ] Vendored source: exactly 28 OpenZeppelin v5.2.0 files (refreeze §3), exactly 32 Uniswap v3-core v1.0.0 files (refreeze §4), exactly 3 Miner Manifold files @ `bcffbf1e…` (PROV-2) — byte-identical, upstream SPDX retained
- [ ] Fail-closed CI: per-file byte-identity drift gate vs. the accepted registry, 40-char pin lint, mutable-URL detector, unauthorized-file detector, `POOL_INIT_CODE_HASH` recomputation, SPDX lint, TPN/LICENSE integrity, §17 quarantine grep
- [ ] Test harness with zero unauthorized source (default: VUX-original minimal base)

### Acceptance Criteria
- [ ] Census exactness: repository contains exactly 28 + 32 + 3 vendored upstream files; per-file SHA-256 equals the accepted registry values (`docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json`); zero unenumerated upstream source anywhere
- [ ] Drift gate demonstrated fail-closed: a 1-byte mutation of any vendored file makes CI fail (negative demonstration recorded in the sprint report)
- [ ] `POOL_INIT_CODE_HASH` reproduced in CI from the vendored `=0.7.6` unit and equal to `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` (refreeze §7 obligation 1) — CI fails closed on mismatch
- [ ] No `UniswapV3Factory.sol` implementation, no v3-periphery file, no non-allowlisted Miner file present (refreeze §8) — enforced by the unauthorized-file detector
- [ ] §17 research-guidance quarantine grep live and green (prd.md:L818)
- [ ] `foundry.toml` carries both solc pins (`7893614a…`, `7338295f…`); CI fails on any missing/short/mismatched pin (PROV-9)
- [ ] `.gitignore` excludes `broadcast/**` production artifacts per the sdd.md:L270 launch-secret posture
- [ ] Zero new dependencies beyond the accepted census (test harness included)

### Technical Tasks
- [ ] Task 1.1: Foundry scaffold — dual-profile `foundry.toml` (`=0.8.28` main; `=0.7.6` vendored unit with refreeze §7 settings), `src/test/script` layout, remappings, `broadcast/**` gitignore hygiene → **[G-5]** ⇐ none
- [ ] Task 1.2: Test-harness provenance decision — implement the VUX-original minimal test base (Vm cheatcode interface + assertion helpers; zero new upstream source); record the optional operator `forge-std` refreeze path as NOT taken unless the operator decides otherwise → **[G-5]** ⇐ Task 1.1
- [ ] Task 1.3: Vendor OpenZeppelin v5.2.0 — the exact 28-file census of refreeze §3 from commit `acd4ff74de833399287ed6b31b4debf6b2b35527`, byte-identical, MIT SPDX retained → **[G-5]** ⇐ Task 1.1
- [ ] Task 1.4: Vendor Uniswap v3-core v1.0.0 — the exact 32-file census of refreeze §4 from commit `e3589b192d0be27e100cd0daaf6c97204fdb1899`, byte-identical, per-file SPDX retained (9 BUSL-1.1 / 22 GPL-2.0-or-later / 1 MIT) → **[G-5]** ⇐ Task 1.1
- [ ] Task 1.5: Land the 3 allowlisted Miner Manifold files (blob-pinned per PROV-2) byte-identical as derivation reference, with notices → **[G-5]** ⇐ Task 1.1
- [ ] Task 1.6: Fail-closed provenance CI (PROV-9): per-file SHA-256 drift gate vs. registry, 40-char pin lint, mutable-URL detector, unauthorized-file detector, TPN/LICENSE presence+integrity checks, §17 quarantine grep; include the 1-byte-mutation negative demonstration → **[G-5]** ⇐ Task 1.3, Task 1.4, Task 1.5
- [ ] Task 1.7: `POOL_INIT_CODE_HASH` deterministic recomputation in CI from the vendored unit; assert equality with the accepted constant (refreeze §7) → **[G-5, G-1]** ⇐ Task 1.4
- [ ] Task 1.8: SPDX lint per PROV-8 policy (VUX-original `GPL-3.0-or-later`; Miner-derived `MIT AND GPL-3.0-or-later`; upstream retained; no invented holders) → **[G-5]** ⇐ Task 1.6

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

