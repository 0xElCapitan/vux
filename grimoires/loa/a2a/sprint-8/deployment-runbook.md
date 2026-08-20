# VUX v1 — Deployment Runbook

**Node:** `/implement sprint-8`, Task 8.6
**Status:** launch-readiness artifact. **This runbook does not launch anything and contains no production value.**

---

## How to read this document

Everything below is in exactly one of two categories, and they are never mixed:

| | Meaning |
|---|---|
| ✅ **SOFTWARE-ESTABLISHED** | Proven from this repository and its rehearsal evidence. Reproduce it by running the named command. |
| 🔲 **OPERATOR-RESERVED** | A production fact that only the operator/founder can supply, **at deployment time**. It appears here as an empty slot. Resolving one of these in the repository would be a defect — see §0. |

If you are looking for a production address, key, salt, price, or Safe composition and cannot find it, that is the runbook working correctly.

---

## 0. The boundary this runbook enforces

The accepted plan reserves specific decisions to the operator (PRD §16, R-1…R-14) and quarantines research guidance from canonical status (PRD §17). Sprint 8 **records slots**; it does not fill them.

**Never committed, at any point, for any reason:**

- production private keys or mnemonics;
- the production launch EOA, its nonce strategy, or its funding trail;
- the production salt or its preimage;
- predicted production addresses before launch;
- the final private genesis manifest;
- the founder USD→WETH conversion inputs where authority reserves them;
- private-builder credentials, endpoints, or configuration;
- production broadcast artifacts.

Enforced mechanically by `tools/provenance/verify-launch-hygiene.sh` (in CI): `broadcast/**` and `.env` are gitignored and untracked, and the tracked tree is scanned for private-key literals, key-on-a-command-line patterns, mnemonics, and commitment-salt literals. Templates and checklists are tracked; values are not.

---

## 1. Pre-launch gate conditions

None of these blocks Sprint-8 implementation. **All of them block production launch.**

| Gate | Owner | Status at Sprint 8 |
|---|---|---|
| **Q-3 — operator Safe composition** (signer set, threshold) | operator | 🔲 **OPEN.** Deployment fact (R-14). Rehearsals used rehearsal values. Slot: §5.1. |
| **Q-4 — jurisdiction-specific legal review** (NFR-COMP-3) | operator + counsel | 🔲 **OPEN.** Blocks public launch, not code. Slot: §5.7. |
| **Q-6 — RH native asset / `WETH.deposit()` fact** | closed | ✅ **CLOSED at Sprint 7.** Fork-rehearsal evidence: `test/fork/RhWethFork.t.sol`. Canonical WETH wraps native value in-transaction, so the constructor's `deposit()` path is sound. If a re-verification at deployment contradicts this, **stop** and switch to the accepted fallback (pre-approval funding flow + §1.7 private submission, `sdd.md:L974`). |
| **R-14 deployment facts** | operator/founder | 🔲 **OPEN by design.** Recorded at deployment. Slots: §5. |
| Full provenance + test gate green on the exact launch commit | engineering | ✅ Reproduce: `bash tools/provenance/run-all.sh` |

---

## 2. What Sprint 8 has established (✅ software-established)

Reproduce each with the command given. Nothing here needs a production value.

| Fact | Evidence | Reproduce |
|---|---|---|
| Vendored census byte-identical (28 OZ + 32 v3-core + 3 Miner) | `tools/provenance/verify-census.sh` | `bash tools/provenance/run-all.sh` |
| `POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` reproduced from source | `tools/provenance/verify-init-code-hash.sh` | same |
| All pins immutable, no mutable ref used as authority | `tools/provenance/verify-pins.sh` | same |
| SPDX / notices correct against vendored reality | `verify-spdx.sh`, `verify-notices.sh` | same |
| PRD §17 research values quarantined out of implementation | `verify-quarantine.sh` | same |
| No launch secret or broadcast artifact in the tree | `verify-launch-hygiene.sh` | same |
| Static analysis triaged, 0 high-impact, baseline enforced | `verify-static-analysis.sh` + `tools/static-analysis/triage-baseline.json` | same |
| INV-1…37 and FB-1…18 all carry named evidence | `grimoires/loa/a2a/sprint-8/traceability-matrix.md` | `bash tools/traceability/verify-traceability.sh` |
| Genesis is non-griefable under full-knowledge adversaries | `test/genesis/GenesisAdversarial.t.sol` | `forge test --match-path 'test/genesis/*'` |
| Genesis wiring verified in-transaction, fail-closed | `test/genesis/GenesisWiring.t.sol` | same |
| Q-6 native-value wrap holds on a real fork | `test/fork/RhWethFork.t.sol` | requires an archive RPC — see §5.9 |

**Structural security property, restated because it governs every operational choice below** (`sdd.md:L156`): genesis succeeds at the intended addresses with the intended economics **even if an adversary knows every future VUX address in advance**. No step reads or writes a shared permissionless namespace, and no assertion or economic quantity depends on an attacker-reachable balance. Address confidentiality is hygiene layered on top; it is never the security boundary.

---

## 3. Launch topology

Two founder transactions (`sdd.md:L155-L159`).

### tx1 — inert infrastructure

Deploys `VuxPoolDeployer(commitment)`.

- Publishes only its own address, its bytecode, and a **32-byte salted commitment**.
- `commitment = keccak256(abi.encode(genesisDeployerAddr, salt))` with a high-entropy secret salt.
- Nothing about any protocol address is derivable from it.
- It holds no funds and no roles, and nothing it exposes does anything without the preimage.
- Private submission is **recommended** but not required — there is nothing to leak.

### tx2 — the launch transaction

Creates `GenesisDeployer`, carrying the genesis funding as **native value**, which the constructor wraps via canonical `WETH.deposit()`.

- Genesis executes **inside the constructor**. There is no `genesis()` function, no founder gate, no callable launch surface — nothing to trigger, front-run, or replay.
- Any mismatch in the eleven-step self-verification reverts the entire transaction and the contract never exists.
- No approval to any predicted address is ever published.

---

## 4. Private same-block submission (REQUIRED for confidentiality; NOT a security assumption)

`sdd.md:L268` is explicit, and this runbook repeats the distinction rather than blurring it:

> **private routing is REQUIRED for production confidentiality and NON-LOAD-BEARING for security**

### Why it is required

The funding trail is the last derivation window. An ordinary public gas-funding transfer to the fresh tx2 EOA puts that EOA on-chain before launch, and any observer can then compute `GenesisDeployer = f(EOA, nonce 0)` and from it the VUX address.

### The required posture

Submit as a **private same-block bundle**:

```
{ fund-tx2-EOA  →  tx2 }
```

both transactions together through private/builder routing, so that the tx2 EOA's **first on-chain appearance is the launch block itself**. The VUX address becomes publicly derivable only in the block that irrevocably creates and verifies everything — a zero-length public window.

### What is tracked here, and what is not

| Tracked (template) | Not tracked (operator supplies at launch) |
|---|---|
| the two-transaction shape above | the builder/relay endpoint |
| the ordering requirement (fund, then tx2, same block) | any credential, API key, or auth header |
| the zero-public-window property to verify afterwards | the tx2 EOA address, key, or nonce |
| the failure procedure below | the funding amount and source |

### If routing fails or leaks

**Genesis is still safe.** It cannot be pre-created, pre-initialized, pre-funded into failure or distortion, occupied, raced, or poisoned. Security by obscurity is not claimed anywhere. The correct response to a leak is an operational decision about launch timing and optics, **not** an emergency security response.

---

## 5. Operator-reserved input slots (🔲 fill at deployment)

> Every slot below is deliberately empty. Filling one in this repository would resolve an operator-reserved value in source — prohibited by PRD §16 and by the Sprint-8 boundary tripwires.

### 5.1 Q-3 — Operator Safe composition (R-14)

| Field | Value |
|---|---|
| Safe address | 🔲 |
| Signer set (addresses) | 🔲 |
| Threshold (m-of-n) | 🔲 |
| Signer-rotation policy | 🔲 |
| Verified: Safe holds roles on `StrategicTreasury` **only** | 🔲 (assert post-launch; core contracts expose no privileged entry points) |

### 5.2 Founder one-shot USD→WETH conversion (FR-1.4, R-14)

Converted **once**, immediately before deployment, using a founder-approved reference. **No runtime USD oracle or refresh mechanism exists or may be added.**

| Field | Value |
|---|---|
| WETH/USD reference price | 🔲 |
| Price source | 🔲 |
| Timestamp (UTC) | 🔲 |
| Rounding rule applied | 🔲 |
| POL WETH side (≈ $1,000 USD-equiv) → wei | 🔲 |
| `BOOTSTRAP_OPENING` → wei | 🔲 |
| `MINIMUM_OPENING` → wei | 🔲 |
| `DECAY_FLOOR` → wei | 🔲 |
| Total external genesis deployment (≈ $1,909.09 USD-equiv, and nothing else) | 🔲 |

**Validation to record alongside (FR-1.4):** rounding, token ordering, decimals, ticks, actual marginal price, `P0/N0 = 1.10`, and the bootstrap-cushion condition `BOOTSTRAP_OPENING ≤ P0×S0 − B0`.

### 5.3 Derived genesis economics

| Field | Value |
|---|---|
| `S0` | ✅ `150,000 × 10^18 + 1` raw units (frozen, FR-1.2) |
| `P0` (actual initialized) | 🔲 |
| `B0 = P0 × S0 / 1.10` | 🔲 |
| `sqrtP0X96` (off-chain deterministic encoding) | 🔲 — encoder proven at `test/genesis/GenesisPriceEncoding.t.sol` |

### 5.4 Pool configuration (R-14)

| Field | Value |
|---|---|
| Fee tier | 🔲 |
| `tickSpacing` | 🔲 |
| `token0` / `token1` (canonical sort) | 🔲 |
| Full-range tick bounds aligned to `tickSpacing` | 🔲 |

Domain-checked at deployment, **never value-frozen**: `token0 < token1`, both nonzero and distinct; `fee < 1_000_000`; `0 < tickSpacing < 16384`.

### 5.5 Schedule start (R-14)

| Field | Value |
|---|---|
| `scheduleStart` timestamp | 🔲 — set by the bootstrap takeover, not at genesis (`src/Rig.sol`) |

### 5.6 Launch identity and secrets (never committed)

| Field | Handling |
|---|---|
| tx1 deployer EOA | 🔲 operator-held |
| tx2 launch EOA | 🔲 operator-held, **fresh**, first appearance = launch block |
| Commitment salt (high entropy) | 🔲 operator-held, **never** committed, never logged |
| `commitment = keccak256(abi.encode(genesisDeployerAddr, salt))` | 🔲 computed offline |
| Private-relay endpoint / credentials | 🔲 operator-held |

### 5.7 Q-4 — Legal review (NFR-COMP-3)

| Item | Value |
|---|---|
| Jurisdiction(s) reviewed | 🔲 |
| Counsel / firm | 🔲 |
| Date completed | 🔲 |
| Determination on Strategic/governance characterization | 🔲 |
| **Blocks public launch** | ✅ yes — code is unaffected |

### 5.8 Post-deployment recorded facts (R-14)

Record immediately after launch, then re-run the verification in §6.

| Contract | Address | Deployment block |
|---|---|---|
| `VuxPoolDeployer` | 🔲 | 🔲 |
| `GenesisDeployer` | 🔲 | 🔲 |
| `VUX` | 🔲 | 🔲 |
| `Rig` | 🔲 | 🔲 |
| `HardReserve` | 🔲 | 🔲 |
| `StrategicTreasury` | 🔲 | 🔲 |
| `Lens` | 🔲 | 🔲 |
| Canonical pool | 🔲 | 🔲 |
| Canonical WETH (verify, do not assume) | 🔲 — expected `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` | — |
| tx1 / tx2 hashes | 🔲 | 🔲 |
| Final dependency pins as deployed | 🔲 | — |

### 5.9 Chain-environment facts to verify before launch

Two categories, not to be mixed: **established repository/rehearsal facts** (measured against the
current tree, below) and **production-reserved launch verification** (the operator's independent
confirmation of the actual Robinhood Chain production environment at launch time). A rehearsal
measurement is historical evidence, not a promise that production deployment will succeed — the
operator must still confirm the applicable EVM/hardfork capability, initcode enforcement, and
block gas / transaction feasibility on the real target chain.

| Item | Why it matters | Status |
|---|---|---|
| **RH EVM version / hard-fork compatibility** | Sprint-7's audit established, by opcode-walk, the current constructor/initcode's required hardfork floor as **Cancun** (MCOPY present in VUX's constructor region, PUSH0 universally) — an established repository/rehearsal fact, re-confirmed by the Sprint-8 audit (A-5). The `=0.8.28` unit targets a specific EVM; an unexpected production fork level changes opcode availability. | 🔲 operator must independently confirm the actual production environment's applicable EVM/hardfork capability before launch |
| **Block gas limit and initcode limit** | Genesis is one large creation transaction. Sprint-7's audit measured the current constructor/initcode at **48,057 bytes**, against the EIP-3860 initcode ceiling of **49,152 bytes** — a measured headroom of **1,095 bytes** on the rehearsed tree. This is an established repository/rehearsal fact, not a production guarantee; no percentage-headroom threshold is asserted. | 🔲 operator must independently confirm actual production block gas limit, initcode enforcement, and transaction feasibility before launch |
| **Archive-capable RPC** | Required for exact historical fork reproduction of the Q-6 evidence and any post-launch forensic replay. | 🔲 endpoint is an operator input |
| **Canonical WETH facts re-verified** | `prd.md:L952` records the 2026-08-09 acceptance as an assumption. If implementation, authority set, or upgrade path changed, the YELLOW disclosure — and possibly the launch decision — must be revisited. | 🔲 re-verify at launch |
| **Indexer DB privileges** | Constraint setup needs elevated privilege (Sprint-6 carry). | 🔲 operator input |

---

## 6. Post-launch verification (run immediately, before announcing)

Assert reality against the frozen genesis. Any failure is a critical incident.

1. **Supply**: `VUX.totalSupply() == 150,000 × 10^18 + 1`.
2. **Distribution**: 150,000 × 10^18 in the canonical POL position; 1 raw unit in `HardReserve`; **zero** at every other address — founders, operators, developers, apDAO, partners, investors, users, airdrops, public sale, Strategic Treasury, and every discretionary recipient. *Any nonzero discretionary genesis balance is a critical failure.*
3. **Backing**: `WETH.balanceOf(reserve) == B0` exactly, and `P0/N0 == 1.10`.
4. **Cushion**: `BOOTSTRAP_OPENING ≤ P0×S0 − B0` held at initialization.
5. **Authority**: `HardReserve`, `VUX`, `Rig`, `Lens` have no owner and no admin; the operator Safe holds roles on `StrategicTreasury` **only**; `GenesisDeployer` holds no authority and no balance.
6. **Pool**: `pool.factory() == VuxPoolDeployer` and `pool.owner() == address(0)` — protocol-fee authority permanently unreachable.
7. **One-shot consumed**: `VuxPoolDeployer` cannot deploy again.
8. **Residual WETH**: sanitized in-transaction; sweep verified.
9. **Bootstrap**: first takeover mints **zero** and splits ≈88%+ Hard / 12% Strategic.
10. **LSG**: inactive, with activation authority present and INV-32…34 boundaries unreachable.
11. **Indexer**: reconstruction from events equals on-chain state.
12. **Frontend**: YELLOW disclosure renders verbatim on every surface describing the Reserve as ownerless/immutable; zero prohibited phrases.

Record every result in the R-14 fact template (§5.8), then re-run `bash tools/provenance/run-all.sh` against the exact launch commit.

---

## 7. Local reproduction notes

The static-analysis gate needs an interpreter in **[3.10, 3.12)** carrying the accepted closure — the range is not arbitrary: `web3<7` (forced by slither 0.10.4) forces `lru-dict<1.3.0`, and `lru-dict 1.2.0` publishes no cp312+ wheel.

```bash
python3.11 -m venv .sa-venv                      # outside the repo, or gitignored
./.sa-venv/bin/python -m pip install --require-hashes --no-deps -r tools/static-analysis/requirements.txt
PYTHON=./.sa-venv/bin/python bash tools/provenance/run-all.sh
```

The gate discovers a suitable interpreter on its own (`python3.11`, `python3.10`, `python3`, `python`) and fails closed with an actionable message if none qualifies. CI needs no `PYTHON` because both 3.10 and 3.11 are in the `ubuntu-latest` tool cache.

---

## 8. What this runbook deliberately does not do

- It does not deploy. Cycle-002 ends at **launch readiness**.
- It does not resolve Q-3 or Q-4.
- It does not compute or store a conversion price.
- It does not name a production address, key, salt, or endpoint.
- It does not claim that private routing makes genesis safe. Genesis is safe without it.
