## Sprint 6: Truth Surfaces — Lens, Indexer & Truthful UX

**Duration:** ~5–6 focused engineering days (indicative)
**Scope:** LARGE (8 tasks)

### Sprint Goal
Make the protocol's economic truth independently observable and truthfully presented: the read-only Lens three-tier views, a complete event schema proven reconstructable by an independent indexer, and a frontend whose mining-state copy passes the FR-15 three-tier truth and YELLOW-disclosure requirements — with all off-chain dependencies entering only through the fail-closed provenance gate.

### Deliverables
- [ ] Off-chain provenance refreeze evidence + operator acceptance (refreeze §9 set), then pinned installs
- [ ] `Lens.sol`: `rawClockLimit`, `estimateIfDisplacedNow`, `hardStats`, `wethNeededForFullQraw` (rounds UP), `strategicContributed` (sdd.md:L704-L713)
- [ ] Event-schema completeness audit vs. FR-14.1–14.4; burn-cause pairing verification (sdd.md:L542)
- [ ] ponder indexer + PostgreSQL 16.4 schema (§3.3) + read-only REST; independent-reconstruction test
- [ ] Frontend (Throne/Redeem/Accounting/Treasury/Trust pages), `truth-copy.ts` single source, `<ReserveDescription/>` YELLOW coupling, Playwright copy suite

### Acceptance Criteria
- [ ] **Gate first:** zero off-chain package installed/used before the operator-accepted pin set exists (fail-closed; refreeze §9) — evidence: pins + integrity hashes recorded, acceptance logged, lockfiles match pins
- [ ] Independent-reconstruction test: an indexer-only recompute of `S`, `B`, `B/S`, per-settlement legs, and burn causes over a scripted multi-op scenario **matches chain state with zero ambiguity** (FR-14 acceptance, prd.md:L538); reorg/idempotency handling per sdd.md:L836
- [ ] Three-tier truth on every mining surface: tier labels distinct, prohibited framings absent ("earned", "owed", "claimable", "guaranteed" for tiers 1–2), estimate labeled variable + non-claimable; canonical explanation available verbatim (prd.md:L546-L553)
- [ ] YELLOW disclosure renders verbatim wherever the Reserve is described as ownerless/immutable — single-component coupling (INV-36; prd.md:L722-L723)
- [ ] Contestability claim appears only in its exact bounded form; no broad-distribution/anti-whale/equal-outcome claim anywhere (prd.md:L549)
- [ ] NAV column named `strategic_nav_disclosed`; the word "backing" never labels Strategic values (FR-14.4)
- [ ] Failure truthfulness: RPC failure → explicit "data unavailable" (never stale-as-live); chain outage messaging per FB-17; FB-18 documented disclosure present on `/trust` (sdd.md:L836)
- [ ] `previewRedeem`/estimates create no entitlement — copy + no-optimistic-display tests (prd.md:L539)

### Technical Tasks
- [ ] Task 6.1: OFF-CHAIN PROVENANCE GATE — produce the pin census (ponder 0.8.x exact, Next.js 15.1.4, React 19.0.0, viem 2.21.x exact, wagmi 2.14.x exact, Playwright 1.49.x exact, PostgreSQL 16.4) with integrity evidence; **STOP for operator acceptance**; then pinned lockfile installs + CI lockfile-drift gate → **[G-5]** ⇐ none
- [ ] Task 6.2: `Lens.sol` + tests — three-tier views, estimate parity against actual settlement outcomes, `wethNeededForFullQraw` round-UP (F-16), no-entitlement semantics → **[G-3, G-1]** ⇐ none
- [ ] Task 6.3: Event completeness audit — every FR-14.1–14.4 observable mapped to an emit site; burn-cause pairing (Transfer→0 joined to `Redeemed`/`VyrfHarvest`/`VuxRevenueBurned`) verified on scripted flows → **[G-3, G-2]** ⇐ none
- [ ] Task 6.4: ponder indexer + PostgreSQL schema (§3.3 tables incl. `legs_sum` constraint) + read-only REST endpoints → **[G-3]** ⇐ Task 6.1, Task 6.3
- [ ] Task 6.5: Independent-reconstruction test — scripted anvil scenario (genesis-fixture → takeovers → redemptions → harvest) recomputed from events only; equality vs. chain state; reorg/idempotency cases → **[G-3, G-2]** ⇐ Task 6.4
- [ ] Task 6.6: Frontend — five pages per sdd.md:L633-L643, `truth-copy.ts` lint-guarded constants, `<ReserveDescription/>`, wallet flows (`take` with maxPrice guard, `redeem`), no-optimistic-entitlement states → **[G-3]** ⇐ Task 6.1
- [ ] Task 6.7: Playwright copy suite — three-tier labels, prohibited-phrase greps, YELLOW presence on every Reserve description, estimate non-claimable labeling (sdd.md:L863) → **[G-3]** ⇐ Task 6.6
- [ ] Task 6.8: Failure-truthfulness states — data-unavailable rendering, FB-17 outage messaging, FB-18 `/trust` disclosure content → **[G-3]** ⇐ Task 6.6

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
