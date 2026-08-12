# Security Audit — cycle-002 / Sprint 2 (VUX Token & Hard Reserve)

**Auditor role:** Paranoid Cypherpunk Auditor (`auditing-security`, native methodology)
**Audit mode:** sprint · **Node type:** AUDIT-ONLY (no lifecycle closure)
**Date:** 2026-08-11
**Canonical base:** `79c966f6c55899489fdb9db176773ef69e6ecf62`
**Predecessor gate:** `/review-sprint sprint-2` → APPROVED (7/7 AC Met; 0C/0H/0M/2L)

---

## 0. Execution provenance — how this audit was run

The stock `/audit-sprint sprint-2` wrapper was **inspected and deliberately not used as an
orchestrator**. Its declared outputs (`.claude/commands/audit-sprint.md:88-96`) include
`COMPLETED` marker creation, `a2a/index.md` status mutation, and `ledger.json` status →
`completed` — all lifecycle-closure effects that are **not authorized in this node**.

The underlying native capability `.claude/skills/auditing-security/SKILL.md` was therefore
executed directly and in full (Phase −1 → Phase 3, including the Phase 2.5 severity tally and
the Phase 3 verdict contract). The skill is write-restricted by design
(`SKILL.md:9-12` `disallowed-tools: Write/Edit/NotebookEdit`; `write_files: false`;
`execute_commands: false`), so this durable artifact was persisted manually, and the
mechanical verification (build, disassembly, fuzzing, boundary probes) was performed with
full tooling in the audit context. This is the operator-specified branch (3)+(4).

**Pre-flight per methodology:**

| Check | Result |
|---|---|
| System Zone integrity (`integrity_enforcement: strict`) | **PASS** — `git status .claude/` clean, zero drift |
| Input guardrails (`guardrails-orchestrator.sh`) | **PASS** — pii_filter PASS (0 redactions), injection_detection PASS (score 0) |
| `grimoires/loa/known-failures.md` (ICM advisory) | ABSENT — advisory only, WARN, proceeded |
| Phase 1C security dissenter | **NOT ENABLED** — no `flatline_protocol` key in `.loa.config.yaml`; no `COMPLETED` write is attempted, so `adversarial-review-gate.sh` is not engaged. No `DEGRADED_SECURITY_REVIEW` condition arises because the phase is config-disabled rather than failed. |
| Phase −1 sizing | SMALL (2 contracts, 1 interface, 5 test units) → sequential audit, no parallel split |

**Toolchain disclosure.** `forge 1.5.0-stable` was used locally; `foundry.toml` documents the
pinned release `foundry v1.0.0 @ 8692e926…` as CI-installed. This is immaterial to every
bytecode claim below, because bytecode is determined by **solc**, and the artifacts actually
analysed were verified to carry the pinned compiler: `0.8.28+commit.7893614a` for both
`HardReserve` and `VUX`, corroborated by the gate line *"all 50 artifact(s) under out/
compiled by 0.8.28+commit.7893614a"*.

---

## 1. Verdict

# APPROVED - LET'S FUCKING GO

Zero CRITICAL and zero HIGH findings. The monetary core — genesis exactness, immutable
authority, redemption arithmetic, `S_MIN` preservation, third-party-burn impossibility,
constructor sanitization, and runtime structural absence — is **sound and independently
proven**, not merely re-asserted from the review.

One **MEDIUM** finding (A-1) is raised against the *provenance boundary tooling*, not against
the contracts. It does not affect any deployed byte and does not force `CHANGES_REQUIRED`
under the one-way rule. It is recorded in §12 as a **pre-acceptance condition for the
operator's decision**, with an explicit exact-tree consequence.

---

## 2. Exact audit subject, fingerprint and digest

Subject reconstructed **independently** from repository state (not from the review artifact):
all working-tree paths differing from the canonical base, excluding the State/learning zones
`grimoires/**`, `.beads/**`, `.run/**`. This yields **exactly 18 files** (8 tracked-modified +
10 untracked-new), independently matching the review's count.

**Audit-subject digest (SHA-256 over the sorted `sha256  path` manifest):**

```
78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a
```

| SHA-256 | Path |
|---|---|
| `85e2123216dc3993ffcad06a8ff1a8db654dbcf6cd46d2de528beb2a38c0a136` | `.github/workflows/provenance.yml` |
| `47b290cdc75e512796538bc20a1de71cc8a12c0e7bede7c0ac7506651377703e` | `foundry.toml` |
| `74b8319ab155225b4533790b88d3adc71c8da117ff74d4124e180f3bd39f2c17` | `src/HardReserve.sol` |
| `5686c4c7c353711998eccb3693bda44d9ab0352ed79d69a1b853447dc5197349` | `src/VUX.sol` |
| `3910bf9d440a1755cd6bad3e0e7975ad0a1adb9a0f5a4b0e91ee9391ed83eb24` | `src/interfaces/IVUX.sol` |
| `1cff3ef705eb3deec06f9544c0a2e7db0277a17dd42949396c12eb4278e1e183` | `test/harness/Artifact.sol` |
| `8cdf7ad5ce285f8af0c27eb1c14ab9dddb2928abcc9858991afb98f9e57f7523` | `test/harness/BaseTest.sol` |
| `297c15752e88d1ece393a7ea40cda3750686595174daee58263c38b566fa0cdb` | `test/harness/Vm.sol` |
| `3d29a61312f679f635709c7eefcbc47af6cc48a0a60e37cf12b215704cff833b` | `test/mocks/MockWeth.sol` |
| `95ce221261afab1ca670bef29c6bef2c293642b9eb0085c366a92906589ad0b4` | `test/reserve/HardReserveRedemption.t.sol` |
| `1e36fa00c0eedc99bdba4b7edb53f635abaf9a870a35ede6997abec46b159b24` | `test/reserve/HardReserveSurface.t.sol` |
| `3f0b3ac7161070d16b619b23b9f6947cf8daf0aa8f7013d962ce795b51425f5a` | `test/reserve/ReserveFixture.sol` |
| `b4a3e005a76d915c1d9dace6f4a54b97b40f303c1bc9b6f6f079a4c9e3f6faaf` | `test/token/VuxToken.t.sol` |
| `8b9996456ff3b5ed6836ebb9c5c40617be4fbd446456833b8978bd04e9c09d7e` | `tools/provenance/census.sh` |
| `d629d7ff34b238e6cdd5cf49dd773a6edfd73ffc9caa15b7505057181e1f975a` | `tools/provenance/demo-boundary-negative.sh` |
| `c653a62a9b3add941428c4dbe9bfeac767c63f209a697d05ee9a9a73d0292f2c` | `tools/provenance/inspect-runtime-surface.sh` |
| `b4a373abd3e18afc05b65c416448ed4db5fd4747f65074d6c0c2252629a90045` | `tools/provenance/run-all.sh` |
| `39d721f95ed4a892d60f30290c4ee399381171e5a3cc57cedacad0d17c3b88a0` | `tools/provenance/verify-census.sh` |

**Reconciliation with the review artifact.** Both operator-declared anchors match exactly:
`src/VUX.sol` → `5686c4c7…97349` ✓ and `src/HardReserve.sol` → `74b8319a…9f2c17` ✓.
Fingerprints are content hashes; mtimes were not relied upon at any point.

### 3. Starting and ending subject identity

| Point | Digest | Files |
|---|---|---|
| Audit **entry** | `78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a` | 18 |
| After boundary probes | `78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a` | 18 |
| Audit **exit** | `78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a` | 18 |

**IDENTICAL.** No implementation/source/test/config/CI/vendor/provenance byte changed during
this audit. The verdict applies to exactly this tree. Rebuilds wrote only to `out/` and
`cache/`, both `.gitignore`d (`.gitignore:19`, `:17`) and therefore outside the subject.

### 4. Retrospective separation — independently confirmed

`/retrospective --scope implementing-tasks` and `--scope reviewing-code` both ran before this
node. Independent verification, not taken from the review:

```
git diff --name-only 79c966f6 | grep -v -E '^(grimoires/|\.beads/|\.run/)'
  → exactly the 8 tracked subject files, and nothing else
```

Every retrospective mutation is confined to `grimoires/**` (plus `.beads/`, `.run/`).
**Zero** implementation, source, test, provenance, CI, vendor, or evidence surface was touched
by learning-state capture.

The distinction is recorded explicitly, as required: **learning/state changes are legitimate
lifecycle artifacts and are permitted to move; the implementation subject being audited is
not.** In this sprint the two remained fully disjoint, so the audited subject is exactly the
subject the review approved.

---

## 5. Findings by severity (Phase 2.5 tally)

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High     | 0 |
| Medium   | 1 |
| Low      | 3 |

Informational / disposition-only items (not tallied as findings): 5.

**One-way rule:** `critical + high = 0` → `CHANGES_REQUIRED` is not forced. Medium/Low
accumulation assessed by auditor judgment → **APPROVED**.

---

## 6. VUX immutable-authority result — PROVEN

Independently verified against source **and** compiled dispatcher.

| Claim | Result | Evidence |
|---|---|---|
| Only immutable `rig` may mint post-genesis | **PROVEN** | `VUX.sol:108-111` gate; `_mint` internal, reachable only from constructor + `mint`; fuzzed 256 runs over arbitrary non-rig callers (probe `B1`) |
| Only immutable `reserve` may `burnForRedemption` | **PROVEN** | `VUX.sol:123-126`; fuzzed 256 runs over arbitrary non-reserve callers (probe `B2`) |
| Holders burn only themselves | **PROVEN** | `VUX.sol:115-117` `_burn(msg.sender, …)`; no address parameter exists (probe `B5`) |
| No setter/role/owner/upgrade can repoint authority | **PROVEN** | `rig`/`reserve` are `immutable`; VUX runtime dispatcher contains exactly 20 selectors, none of them a setter/owner/role/upgrade entry |
| Inherited ERC20 / ERC20Permit adds no authority | **PROVEN** | Inheritance is `ERC20, ERC20Permit` only (not `ERC20Burnable`, not `ERC20Votes`); the 20-selector dispatcher is closed and enumerated below |

**VUX runtime dispatcher, recovered directly from bytecode** (independent of the ABI JSON, then
cross-checked against it — `extra=none, missing=none`):

`name, symbol, decimals, totalSupply, balanceOf, transfer, approve, allowance, transferFrom,
permit, nonces, DOMAIN_SEPARATOR, eip712Domain, mint, burn, burnForRedemption, rig, reserve,
GENESIS_POL_SUPPLY, GENESIS_RESERVE_SEED`

**The VUX runtime contains ZERO `CALL` opcodes** (1 `STATICCALL`, 0 `DELEGATECALL`, 0
`CALLCODE`, 0 `CREATE`/`CREATE2`, 0 `SELFDESTRUCT`). The token therefore has no runtime
capability to move value or substitute code at all.

## 7. Genesis result — PROVEN EXACT

| Claim | Result |
|---|---|
| `150_000e18` → creator | **PROVEN** — `VUX.sol:100`, `_mint(msg.sender, GENESIS_POL_SUPPLY)` |
| `1 raw VUX` → Reserve | **PROVEN** — `VUX.sol:101` |
| Total genesis supply `150_000e18 + 1` | **PROVEN** |
| Constructor parameters cannot redirect the amounts | **PROVEN** |

Both amounts are `constant` (`VUX.sol:75, 79`) and neither is parameterised. The POL
destination is `msg.sender` — structurally unaddressable by any argument. The seed
destination is `reserve_`, which *is the definition of the Reserve*, not a redirection of an
amount. Fuzzed over 256 arbitrary `(rig_, reserve_)` pairs (probe `A2`): the allocation is
invariant in every case.

**Genesis edge conditions** (assessed strictly as "do Sprint-2 primitives violate accepted
invariants", without inventing Sprint-7 deployer policy):

- **Zero rig / zero reserve** → rejected at `VUX.sol:96` (`ZeroAddress`); Reserve likewise at
  `HardReserve.sol:108`. Verified (probe `A3`).
- **Equal rig/reserve** → not rejected. The token's own invariants continue to hold exactly
  (probe `A4`: seed = 1, supply exact, both immutables set). Conflation would grant one
  address both authorities, but *which* addresses are passed is `GenesisDeployer` policy
  (Sprint 7). **Not a Sprint-2 primitive defect** — informational only.
- **Construction order** → the VUX↔Reserve 2-cycle is resolved by CREATE address prediction
  and asserted in-fixture (`ReserveFixture.sol:34-40`). No wiring setter exists, which is the
  correct and much stronger posture.

## 8. `burnFrom` / dispatcher result — PROVEN ABSENT

`burnFrom` is absent **from the compiled dispatcher**, not merely from the source. The burn
family in the VUX runtime is exactly `burn(uint256)` and `burnForRedemption(address,uint256)`.
The canonical `burnFrom(address,uint256)` selector `0x79cc6790` does not appear.

Per the operator's instruction, ABI absence alone was **not** treated as sufficient: the
dispatcher was extracted from raw bytecode by an independently written disassembler, a live
call to `burnFrom(address,uint256)` was attempted against the deployed token and reverted
(probe `B3` step 4), and the Reserve was independently confirmed to have **no `fallback` and
no `receive`** (probe `G3`: both an unknown selector `0xdeadbeef` and empty calldata revert).
There is no dispatcher or fallback route to unexpected behaviour.

## 9. Redemption arithmetic result — PROVEN CORRECT

`HardReserve.redeem` (`HardReserve.sol:150-173`) verified line by line:

| Property | Result |
|---|---|
| Pre-state snapshot before any effect | **CORRECT** — `bPre`/`sPre` read at L157-158, before the burn at L169 |
| `payout = floor(B_pre × q / S_pre)` | **CORRECT** — `Math.mulDiv`, L167 |
| Floor direction (Reserve-favouring) | **CORRECT** — remainder retained; INV-16 |
| Zero fee | **CORRECT** — Reserve's loss == recipient's gain exactly (probe `D3`) |
| Atomic burn + transfer | **CORRECT** — no partial-success path |
| SafeERC20 semantics | **CORRECT** — a `false`-returning transfer reverts the whole redemption |
| CEI | **CORRECT** — snapshot → check → effect → interaction |
| `nonReentrant` | **CORRECT** — reentrant `redeem` reverts `ReentrancyGuardReentrantCall` |
| `S_MIN = 1`, `q ≤ S − S_MIN` | **CORRECT** — L164-165 |
| Underflow / overflow | **CORRECT** — see below |
| Payout-zero, max redemption, insufficient balance, transfer failure, revert atomicity | **CORRECT** — all independently exercised |

**`sPre - S_MIN` underflow is unreachable.** It would require `S = 0`, i.e. the Reserve's seed
burned. The seed sits at the Reserve, which holds no code that transfers or burns its own VUX;
`burnForRedemption` accepts only `msg.sender` from the Reserve, and the Reserve can never *be*
`msg.sender` to `redeem` (that would require self-invocation, which no code path performs and
`nonReentrant` would block anyway). Independently attacked in probe `C1`. `S ≥ 1` always.

**`Math.mulDiv` overflow-revert is unreachable from `redeem`** — a stronger result than
"512-bit arithmetic is used". Because `q ≤ S − 1 < S`, we have `B·q/S < B`, so
`payout ≤ B < 2²⁵⁶` always. The exit right therefore cannot be denied by arithmetic at any
scale. Verified by fuzzing `B` across the **full uint256 domain** up to `2²⁵⁶−2` (probe `D3`,
10,000 runs) — a domain the implementation suite does not reach.

## 10. Independent overflow / property result — REPRODUCED BY THREE ORACLES

The implementation's fuzz oracle was **not trusted; it was understood and validated**:

- Normal domain: `expected = (b*q)/s` computed natively — genuinely independent of the
  `Math.mulDiv` under test.
- Overflow domain: writes `B = A·S + rem` (`rem < S`) so
  `floor(B·q/S) = A·q + floor(rem·q/S)`, never forming the overflowing product. The
  decomposition is algebraically correct, and the test **asserts** its own non-vacuity
  (`q > type(uint256).max / b`) rather than assuming it. Bound analysis confirms `B·q ≈ 10⁷⁹`
  genuinely exceeds `uint256` while `A·q ≈ 10⁵⁴` and `rem·q < 10⁵²` do not. The oracle is sound.

Independent reproduction, boundary-first rather than a rerun:

| Oracle | Scale | Result |
|---|---|---|
| Implementation suite (CI profile) | 10,000 runs × 4 properties | **PASS** |
| Auditor EVM probe (own harness, own WETH mock) | 10,000 runs × 4 properties | **PASS** |
| Auditor pure-Python arbitrary-precision oracle | **400,000** cases + 20,000 random exhaustion paths | **0 violations** |

Cases deliberately targeted: `B·q` exceeding uint256; maximal floor remainder; `q → S−1`;
payout rounding to zero (`B < S`, probe `D4`); supply at minimum.

**Why the property holds** (the audit can explain it, not just count runs): `mulDiv` computes
the exact 512-bit product and divides once, so the result is the true `⌊B·q/S⌋` by
construction; flooring is the unique integer `p` with `pS ≤ Bq < (p+1)S`, which the suite
asserts in both directions; and `q < S` bounds the quotient by `B`, which is what makes the
512-bit intermediate a *safety* feature rather than a revert risk.

## 11. `S_MIN` exhaustion result — CONFIRMED AND STRENGTHENED

The review derived the exhaustive remainder as `ceil(B/S)`. **Re-derived independently and
confirmed**, then strengthened:

For a single exhaustive redemption `q = S−1`:
`payout = ⌊B(S−1)/S⌋ = B − ⌈B/S⌉`, so the remainder is exactly `⌈B/S⌉`. ✓

**Auditor-derived stronger invariant:** `⌈B/S⌉` is preserved *exactly* by **every** redemption,
for any `q ∈ [0, S−S_MIN]`. Proof: write `B = kS − r` with `k = ⌈B/S⌉`, `0 ≤ r < S`. Then
`⌊Bq/S⌋ = kq − ⌈rq/S⌉`, so `B' = kS' − r'` with `r' = r − ⌈rq/S⌉`, and `0 ≤ r' < S' = S−q`.
Hence `⌈B'/S'⌉ = k`. Therefore the exhaustion remainder is **path-independent**: it equals
`⌈B₀/S₀⌉` regardless of how many redemptions were used to get there.

Verified three ways: probe `D1` (invariance, 10,000 runs), probe `D2` (path independence,
10,000 runs), and 20,000 random multi-step exhaustion paths in Python — all exact.

Confirmed at exhaustion: `totalSupply() == 1` exactly; the permanent seed remains held by the
Reserve; and for `B₀ > 0` the WETH remainder is **strictly positive** (`⌈B₀/S₀⌉ ≥ 1`). The
`B/S` denominator stays live.

## 12. Third-party burn result — PROVEN IMPOSSIBLE (full-boundary attack)

The accepted invariant — *no holder can cause the Reserve to burn another holder's VUX* — was
attacked as a system boundary, not as a single negative test. Worst-case setup: the victim
grants the attacker a **`type(uint256).max` allowance AND signs a valid permit**, and the
Reserve holds real backing.

| Attack route | Result |
|---|---|
| Direct `burnForRedemption(victim, q)` | **REVERTS** (`NotReserve`) even with max allowance |
| `redeem(q, to)` naming the attacker | **REVERTS** — burn source is `msg.sender`, not a parameter |
| ERC20 allowance | Grants transfer authority only; never burn authority |
| `permit` → allowance | **PROVEN** no burn authority created (probe `B4`) |
| `transferFrom` then redeem | Succeeds — but burns the **attacker's own** balance, which is correct ERC-20 semantics, not a burn of another holder |
| Zero-balance caller | **REVERTS** `ERC20InsufficientBalance` |
| Crafted `to` | Redirects only the attacker's *own* payout |
| Reentrancy | **REVERTS** (`nonReentrant`) |
| Inherited ERC20 behaviour | No burn path exists in the inherited surface |

Two independent barriers hold: the Reserve passes only `msg.sender`, and the token gates on
`msg.sender != reserve`. Neither alone is relied upon.

## 13. Receiver / zero-redemption disposition

**`to == address(0)` rejection — CORRECT, not a holder-exit restriction.** It is static,
applies only to the caller's own argument, and blocks no redemption that could otherwise pay
out: the same holder redeems successfully to any non-zero address, including a third party
(probe `F1`). Canonical WETH would credit the zero address, destroying the payout *after* the
burn had committed — so the guard prevents value destruction rather than restricting exit.
Correctly classified as malformed-input rejection. **No finding.**

**`redeem(0, to)` — inert, as the review classified.** Verified: payout 0, supply unchanged,
backing unchanged; the only effect is a `Redeemed` log with zero values (probe `F2`).
Harmless. **No finding.** No policy invented for aesthetic API preference.

## 14. Constructor sanitization result — PROVEN

| Required semantic | Result |
|---|---|
| Read all canonical WETH present at the Reserve address during construction | **CORRECT** — `HardReserve.sol:112` |
| If nonzero, transfer the full amount to `msg.sender` | **CORRECT** — L114, full `contaminated` amount, creator is structural (not a parameter) |
| Emit `PreGenesisWethSanitized` | **CORRECT** — L115, exact amount; not emitted on clean deployment |
| Re-read balance | **CORRECT** — L121, re-read rather than assumed |
| Construction succeeds only if final balance is exactly zero | **CORRECT** — L122, exact `!= 0`, never relaxed to `>=` |

Independently fuzzed over 256 prefunding amounts up to `10³⁰` (probe `G1`): the future address
is contaminated *before any code exists there*, and after construction the Reserve holds
exactly zero while the creator receives exactly the full amount. Partial/failed transfer is
handled by the re-read + `NotBornEmpty` revert (the fee-on-transfer / rebasing shape).
Destination immutability holds — `msg.sender`, no parameter. The donation earns **zero mint
credit** (probe `G2`: `backing() == 0` after sanitization).

## 15. Runtime structural-absence result — PROVEN (load-bearing)

This claim was **not** accepted on source inspection, event-topic absence, or a canned opcode
count. The inspection machinery was itself validated, and the analysis was reproduced by an
**independently written disassembler** (Python, EVM-spec-derived, sharing no code with
`inspect-runtime-surface.sh`, the awk census, or `Artifact.sol`).

**Machinery validation:**

| Concern | Result |
|---|---|
| Runtime vs creation bytecode | Distinguished: creation 4,736 B, runtime 3,252 B |
| Metadata stripping | Independently re-derived: 51 B CBOR blob + 2 B length; **validated** by asserting a CBOR map header and the `solc` key rather than trusting the length word |
| Non-vacuity | Program body 3,199 B > 0 and strictly less than the runtime — strip neither vacuous nor a no-op |
| PUSH immediate skipping | Implemented per spec (PUSH1–PUSH32 immediates treated as data, never as opcodes) |
| Positive controls | `CALL` and `STATICCALL` both found where genuinely present — the search can find what it claims to look for |
| Dispatcher/ABI mapping | Selectors recovered **from bytecode** and cross-checked: `extra=none, missing=none` for both contracts |

**Reachable-control-flow attack (not merely opcode existence).** The Reserve runtime contains
exactly **2 `CALL`** and **5 `STATICCALL`** sites, and every one is accounted for:

- `CALL @ 0x508` — preceded by an `EXTCODESIZE` check, selector `0xdb6b1b4f` materialised at
  `0x4cb` → `vux.burnForRedemption`, **value = `PUSH0` (0 ETH)**.
- `CALL @ 0x893` — SafeERC20 `_callOptionalReturn`, selector `0xa9059cbb` at `0x7ee` →
  `weth.transfer`, **value = `PUSH0`**.
- 5 `STATICCALL` ↔ exactly 5 read sites (`balanceOf` ×3, `totalSupply` ×2).

**Zero unaccounted external interactions.** Decisively, the complete set of outbound selectors
present anywhere in the Reserve runtime is `{totalSupply, balanceOf, transfer,
burnForRedemption}` — **`approve` (`0x095ea7b3`) and `transferFrom` (`0x23b872dd`) are absent**.
The Reserve therefore cannot delegate spending authority over its principal and cannot pull.
Combined with 0 `DELEGATECALL`/`CALLCODE` (no code substitution or proxy), 0 `CREATE`/`CREATE2`
(no successor), 0 `SELFDESTRUCT`, and exactly one non-view dispatch entry, **the only path by
which WETH can leave the Reserve is `transfer`, from the single SafeERC20 site inside
`redeem`.**

The sanitization marker `keccak256("PreGenesisWethSanitized(uint256)")` is present in the
**creation** bytecode (positive control) and absent from the **deployed runtime** — the
capability provably did not survive deployment. Independently corroborated by probing six
plausible sweep shapes (`sweep`, `rescue`, `recover`, `withdraw`, `emergencyWithdraw`,
`transferOwnership`) against a funded live Reserve: **all revert; principal immovable except
via `redeem`** (probe `G2`).

Expected legitimate WETH interaction during `redeem` is present and correctly bounded.

## 16. External-surface result — EXACTLY THE ACCEPTED SET

Mechanically enumerated from the compiled dispatcher (6 selectors, `extra=none, missing=none`):

- **Mutator:** `redeem(uint256,address)` — the *only* state-changing function per ABI
  `stateMutability`.
- **Views:** `backing()`, `previewRedeem(uint256)`, `weth()`, `vux()`, `S_MIN()`.

Confirmed absent: owner, roles, pause, upgrade, arbitrary call, approve, sweep,
migration/successor, `receive`, `fallback`, payable entry, `selfdestruct`, generic deposit,
emergency principal withdrawal. No hidden, inherited, or fallback runtime entry exists beyond
the six.

## 17. Read-only reentrancy R-2 — LOW, precisely classified (not presently exploitable)

Assessed independently by **measuring** the window rather than reasoning about it. A purpose-
built WETH mock performs a *read-only* reentry during the payout leg and records what an
external view consumer would observe (probe `E1`):

- `totalSupply()` observed as `S − q` — the burn has already committed;
- `backing()` observed as `B_pre` — the WETH has not yet moved;
- consequently the transient `B/S` quote is **inflated** relative to the settled value.

The residual is real and correctly described by the review. Its exploitability:

| Question | Answer |
|---|---|
| Is an exploitable callback reachable with accepted canonical WETH? | **No.** Canonical WETH's `transfer` performs no external call, so the window cannot be entered. Reaching it requires substituting a token with transfer hooks — excluded by the accepted canonical-WETH trust boundary. |
| Can it affect the current Reserve itself? | **No.** Every entry re-reads live state, and `nonReentrant` blocks reentrant `redeem`. |
| Can it violate holder accounting or redemption invariants? | **No.** Final state verified exact: backing `= B − payout`, supply `= S − q`. |
| Is it only relevant to a future Sprint-3+ consumer? | **Yes** — and only one that reads Reserve views during settlement *and* is paired with a callback-capable backing asset. |

**Disposition: LOW residual, carried. No redesign required in Sprint 2.** No speculative
redesign is imposed for a hypothetical future consumer, since the present contract exposes no
exploitable invariant break. Recommended as a documented consideration for Sprint 3+ view
consumers.

## 18. N-1 closure / `BUILD_ARTIFACT_PRUNE` disposition — one MEDIUM finding

The N-1 closure was re-attacked from scratch in **fresh, auditor-chosen locations**, not by
rerunning the review's probes. Baseline verified passing before and after; **17 probes**
planted, tested, and removed, with exact-subject restoration confirmed by digest.

**Working as designed (all correctly caught, fail-closed):** root-level `.sol`; a fresh
`docs/` directory; `lib/` (Foundry's conventional dependency location); nested
`node_modules/x/y/`; `vendor/` unenumerated; and the git-trackable Loa/state zones `.ck/`,
`grimoires/`, `.beads/`, `.run/` — including an **uppercase `.SOL`** inside a Loa zone, which
the `-iname` assertion correctly catches. The split of generated-artifact pruning from
git-trackable Loa-zone pruning, with a Solidity-free assertion over the latter, is a sound
design and it holds.

### FINDING A-1 — MEDIUM — source-universe walk is case-sensitive, so the provenance boundary and the prohibited-source scan are evadable by extension case

**Component:** `tools/provenance/census.sh:184` (`source_universe()`), consumed by
`tools/provenance/verify-census.sh:82-94, 172`
**Category:** provenance / supply-chain control · **Confidence:** high (executed, not theorised)

`source_universe()` enumerates with `find … -name '*.sol'` — **case-sensitive** — while the
Loa-zone assertion `loa_zone_solidity()` (`census.sh:204`) deliberately uses `-iname`. The
primary default-deny universe is therefore *narrower* than the conditional exemption it
guards, which is the inverse of the intended relationship.

**Proof of concept (executed against the real gate):**

```
docs/AuditProbeEvil.SoL   → verify-census.sh EXITS 0  (MISSED)
AuditProbeEvil.SOL        → verify-census.sh EXITS 0  (MISSED)
AuditProbeEvil.sol        → verify-census.sh FAILS    (correctly caught)
```

Both evading paths are **git-trackable** — `git check-ignore` reports TRACKABLE — so no
`git add -f` and no gitignored-artifact abuse is required.

> **Addendum, 2026-08-11 (`/retrospective --scope auditing-security`): build-reachability is
> now EXECUTED PROOF, and it retracts a prior refutation.**
>
> The paragraph above originally asserted that `import "./Evil.SOL";` "resolves and compiles".
> That claim was untested at verdict time, and the repository's own recorded knowledge
> contradicted it: NOTES.md `## Learnings` recorded the **sprint-1 audit refuting this exact
> case as N-2**, on the grounds that *"`Foo.SOL` is invisible to Foundry too: Unable to resolve
> imports"*. The retrospective's cross-reference surfaced the conflict, so it was tested.
>
> **Result: the claim holds and the N-2 refutation is wrong.** Foundry emits
> `Unable to resolve imports` from its **pre-resolution source-graph walker**, then prints
> `Compiler run successful!` in the same run — solc resolves the import through its own
> filesystem callback. Verified three ways: `Evil.SOL` appears in the artifact's
> `metadata.sources`; the importing contract carries deployable bytecode embedding it; and a
> deployed instance **executes** it — `[PASS] test_UppercaseSolIsBuildReachableAndExecutable`,
> returning `42`. The absent `out/Evil.SOL/` artifact is not corroboration: artifact emission
> and graph discovery are the same pass, so consulting it double-counts one piece of evidence.
> Platform-independent — the import string matches the filename byte-for-byte, so it resolves
> on Linux CI too; filesystem case-insensitivity is not required.
>
> The detector and the consumer therefore have **asymmetric** blind spots, which is precisely
> the condition under which a gate gap is real rather than informational. **A-1's severity is
> unchanged at MEDIUM** (nothing escapes in the audited tree; weaponising still needs a visible
> `import` edit), but its evidentiary basis is now execution rather than assertion, and the
> contradicting N-2 entry has been retracted in NOTES.md. Verdict and counts are unchanged.

The file is build-reachable while remaining entirely unclassified.

**Impact.** This falsifies the design property stated at `census.sh:148-151` — *"relocating
source cannot move it out of any gate's reach"* — in the naming dimension. It is the same
defect class as N-1 (unclassifiable yet build-reachable); Sprint 2 closed the *zone* axis but
not the *case* axis. Because `all_sources` is derived from the same universe
(`verify-census.sh:82`), the **prohibited-source detector at `verify-census.sh:172`
(LSG / gumball6900 / give.fun / Olympus) is blinded by the same gap** — which slightly
overstates the reach claimed in the PROV-5 evidence §4.

Corroborating: the negative control `demo-boundary-negative.sh` plants only lowercase `.sol`
probes (`contracts/`, `lib/`, `grimoires/…zone.sol`), so it shares the blind spot and cannot
detect this regression.

**Why MEDIUM and not HIGH.** No such file exists in the audited tree (77 files classified,
gate green); no deployed byte is affected; and weaponising it needs a second, plainly visible
act — an `import` edit inside `src/`. Against the control's actual threat model (undisciplined
or accidental introduction of unauthorised source), a case-variant extension is an improbable
accident. It is a demonstrated weakening of a defence-in-depth backstop, not a live
vulnerability.

**Remediation (tooling only, does not touch `src/**` or `test/**`):**

```bash
# tools/provenance/census.sh:184 — make the universe walk case-insensitive,
# matching loa_zone_solidity()'s existing -iname posture
find . \( "${prune[@]}" -false \) -prune -o \( -type f -o -type l \) -iname '*.sol' -print
```

and add an uppercase-extension probe to `demo-boundary-negative.sh` so the negative control
can see the regression.

> **Exact-tree consequence.** `tools/provenance/census.sh` **is** an audited subject file
> (`8b999645…c09d7e`). Applying this fix mutates the subject and therefore invalidates
> exact-tree acceptance for that file; the resulting tree requires re-audit of the changed
> surface before commit/landing. This is precisely why it is surfaced as an operator decision
> in §22 rather than silently patched here.

### R-1 — `BUILD_ARTIFACT_PRUNE` is not assertion-covered — **LOW / harmless, as the review judged**

`BUILD_ARTIFACT_PRUNE = (.git out out-v3core cache cache-v3core broadcast)` is pruned without a
Solidity-free assertion. Probes confirm Solidity planted in `out/`, `broadcast/`, `cache/`, and
`out-v3core/` is not detected.

**Disposition: harmless generated-artifact exclusion; optional LOW hardening; not a genuine
route around default-deny.** Every one of these paths is gitignored **at file level** —
verified individually via `git check-ignore` (`.gitignore:17-19` plus the `broadcast/` +
`broadcast/**` launch-secret rules). Landing source there requires deliberately force-tracking
ignored generated output, which is the theoretical path the audit was instructed not to
overstate, and which `verify-launch-hygiene.sh` independently polices for `broadcast/`. Pruning
`.git` and Foundry's `*.sol`-named artifact **directories** is additionally necessary for the
walk to function at all. **No remediation required.**

## 19. L-1 / L-2 disposition

**L-1 — stale source-comment pointers — LOW, documentation defect only. Severity not raised.**
Confirmed exactly two occurrences, both in `src/HardReserve.sol` (`:31` and `:100`), pointing
at `test/reserve/ReserveSurface.t.sol`; the actual file is
`test/reserve/HardReserveSurface.t.sol`. Auditability is **not** materially impaired: the
referenced evidence exists and both claims are independently reproducible; the companion
pointer in `tools/provenance/inspect-runtime-surface.sh:11` is **correct**; and
`HardReserveSurface.t.sol` is the only Surface suite in that directory. Per instruction, **not
edited during this audit**.

**L-2 — `forge fmt --check` fails on four files — LOW, cosmetic. No CI requirement
manufactured.** Independently reproduced (e.g. `src/HardReserve.sol` `event Redeemed`
line-wrapping). Verified that **no CI gate runs `forge fmt`** — `.github/workflows/provenance.yml`
runs `run-all.sh`, the drift negative control, and the boundary negative control only.
Formatting is not part of accepted provenance CI. Confirmed the differences are pure
whitespace/wrapping and **hide or change no semantics**. No escalation.

## 20. R-3 / R-4 / R-5 / R-6 disposition

| ID | Assessment | Disposition |
|---|---|---|
| **R-3** — 512-bit property fixes the denominator | Correct: the overflow-domain fuzz derives `s` from the fixture, so `S` is constant across runs while `a`, `rem`, `q` vary. This narrows one dimension of the property. **Independently compensated by this audit:** probe `D3` fuzzes `B` across the full uint256 domain, and the Python oracle varies `S` over `[1, 10³⁰]` across 400,000 cases with zero violations. | **INFORMATIONAL** — no security consequence; coverage gap closed by audit evidence |
| **R-4** — `previewRedeem` accepts unbounded `q` | Verified quote-only: no state effect, no authority consequence; absurd `q` returns a quote exceeding `B`, and the real `redeem` path refuses the same `q` (probe `F3`). Documented in NatSpec as "a quotation, not an entitlement". For very large `q` the view reverts inside `mulDiv` — a view-only revert. | **INFORMATIONAL** — no finding |
| **R-5** — MockWeth zero-recipient divergence | Real: `MockWeth` extends OZ ERC20, which reverts on transfer to `address(0)`, whereas WETH9-style tokens credit it. **Unreachable in `redeem`**, because `to == address(0)` is rejected before any transfer. Consequence is confined to the mock's inability to demonstrate the *counterfactual* harm; the guard's own behaviour is directly asserted. | **INFORMATIONAL** — test-fidelity note, no security consequence |
| **R-6** — no CHANGELOG convention | Confirmed absent. No CHANGELOG convention exists in the repository and none is required by the sprint plan or accepted authority. | **INFORMATIONAL** — no finding |

## 21. Provenance / licensing / dependency result — NO REGRESSION

Full suite re-run (`tools/provenance/run-all.sh`): **all gates and 61 tests pass**.

| Claim | Result |
|---|---|
| Exactly 28 OpenZeppelin v5.2.0 files | **CONFIRMED** |
| Exactly 32 Uniswap v3-core v1.0.0 files | **CONFIRMED** |
| Exactly 3 Miner Manifold files @ `bcffbf1e` | **CONFIRMED** |
| 63/63 byte-identical to accepted identities | **CONFIRMED** |
| Source universe = 77 (63 vendored + 14 VUX-owned) | **CONFIRMED** |
| Miner VUX provenance / SPDX | **CONFIRMED** — `VUX.sol` carries `MIT AND GPL-3.0-or-later` + `@custom:provenance miner-manifold`, enforced as mutually implied |
| `HardReserve` VUX-original clean source | **CONFIRMED** — plain `GPL-3.0-or-later`, imports nothing from the Miner tree |
| 63/63 vendored SPDX retained verbatim; v3-core tally BUSL×9 / MIT×1 / GPL-2.0×22 | **CONFIRMED** |
| PROV-8 SPDX policy across 14 VUX-owned files | **CONFIRMED** |
| No `forge-std` | **CONFIRMED** — not vendored, not imported; harness is VUX-original (`Vm.sol`, `BaseTest.sol`, `Artifact.sol`) |
| No new dependency | **CONFIRMED** |
| No prohibited-source copy or reference | **CONFIRMED** (subject to A-1's scan-scope caveat) |
| `POOL_INIT_CODE_HASH` unchanged | **CONFIRMED** — `0xe34f199b…f87b8b54` reproduced; CBOR tail confirms `bytecode_hash = none` |
| Accepted source registry/authority unchanged | **CONFIRMED** |
| solc pins honoured | **CONFIRMED** — 50 artifacts under `out/` @ `0.8.28+commit.7893614a`; 32 under `out-v3core/` @ `0.7.6+commit.7338295f` |
| Secrets / PII / hardcoded addresses in subject | **NONE** — the only pattern hits are the gate definitions themselves and a cheatcode signature |

**PROV-5 evidence, inspected critically.** `evidence/prov-5-similarity-review.md` is a genuine
*structural similarity review*, not a bare declaration: it is candid that
`payout = floor(B×q/S)`, `mulDiv`, and CEI ordering are convergent by necessity, and it
identifies five substantive divergences from the prohibited families (approval-free burn
inverting the trust direction; `B` as a physical balance with no accounting cell;
constructor-time sanitization with no known counterpart; ownerless/roleless/no-sweep posture;
`S_MIN` seed held by the redeeming contract). That reasoning is sound and matches the code I
audited. Its stated rationale for keeping prohibited-source names out of `.sol` files — they
would trip the repository's own detector — is legitimate and verified. **One correction:** its
§4 claim that the detector "fails the build on any reference … anywhere in the repository's
Solidity universe" is narrowed by finding A-1.

## 22. Scope result — CLEAN

`src/` contains only `VUX.sol`, `HardReserve.sol`, and `interfaces/IVUX.sol`. `script/` is
empty. **No Sprint-3+ implementation exists:** no Rig, Dutch pricing/KOTH, VEM, 80/8/12
settlement, Strategic Treasury, VuxPoolDeployer, POL/VYRF, Lens, GenesisDeployer, LSG, or
deployment configuration. The `rig` occurrences in `VUX.sol` are the accepted immutable
authority address, not a Rig implementation.

`IVUX.sol` is correctly minimal — exactly the two members the Reserve calls, deliberately not
a mirror of the token ABI. Narrow interfaces, mocks, and the VUX-original harness are **not**
treated as scope creep.

**Documentation audit.** No `documentation-coherence` subagent reports exist for this sprint,
so coverage was **manually verified**, as the methodology permits: every subject contract
carries requirement-traceable NatSpec (`prd.md`/`sdd.md` line citations), and two dedicated
evidence artifacts exist (`prov-5-similarity-review.md`, `structural-absence-checklist.md`).
No secrets or internal URLs appear in documentation or comments. Security-critical code is
explained. Documentation coverage is **satisfied**.

---

## 23. Audit-only mutations

Exactly one file was written in the repository:

- `grimoires/loa/a2a/sprint-2/auditor-sprint-feedback.md` (this artifact) — **created**, State Zone.

Generated, gitignored, and outside the subject: `out/`, `cache/` (rebuild). All audit tooling —
the independent disassembler, the adversarial Foundry probe project (byte-identity-verified
copies of the three source files), the Python oracle, and the boundary-probe script — was
created **outside the repository** in the session scratchpad. All 17 boundary probes were
removed and exact restoration was verified by digest.

**Not mutated:** `src/**`, `test/**`, provenance tooling, CI, Foundry config, vendor, authority
docs, implementation report, review artifact, Sprint Plan, Beads, Ledger, index.

## 24. Sprint 2 was NOT marked completed or accepted

Explicitly confirmed:

- **No `COMPLETED` marker** created — `grimoires/loa/a2a/sprint-2/COMPLETED` does not exist.
- **Ledger unchanged** — `grimoires/loa/ledger.json` still records
  `sprint-2 → status: "in_progress"`, `completed: null`.
- **`a2a/index.md` not advanced**; no completion/index closure written.
- **Beads completion state untouched.**

Lifecycle remains: `IMPLEMENTED → REVIEW_APPROVED → AUDIT_APPROVED` — awaiting **explicit
operator acceptance**, which this node does not perform.

## 25. No commit / push / tag / landing

Explicitly confirmed: **none occurred.** No `git commit`, `git push`, tag creation, or landing
action was taken. The Sprint-2 implementation remains uncommitted working-tree state on
`master` at base `79c966f6`, exactly as it was at audit entry.

## 26. Pre-acceptance conditions

**None are mandatory.** The audit verdict is APPROVED and no condition blocks operator
acceptance of the exact audited tree.

One condition is offered for the operator's decision:

1. **(Operator's call) Remediate A-1 before Sprint 3 lands further product Solidity.**
   The fix is a one-token change in `tools/provenance/census.sh` plus an uppercase probe in
   `demo-boundary-negative.sh`. It touches **no contract, test, or CI file**. Because
   `census.sh` is an audited subject file, applying it **changes the subject** and requires
   re-audit of the changed surface before landing.

   - **Option A — accept now, fix in Sprint 3.** Defensible: the audited tree is clean, the
     gate is green, and A-1 affects no deployed byte. Preserves exact-tree acceptance of
     digest `78c8881204…2ac45a` as-is.
   - **Option B — fix first.** Return to `/implement sprint-2` for the tooling change only,
     then re-audit the resulting tree. Costs a cycle; closes the boundary before Sprint 3
     expands the Solidity surface the gate is meant to guard.

   Recommendation: **Option A**, with A-1 tracked as the first tooling task of Sprint 3.
   Sprint 2's own subject is provably clean, and coupling a green-gate tooling hardening to
   monetary-core acceptance buys no safety for this tree.

## 27. Material reusable learning — YES

Material, reusable learning was discovered. Retrospective is a manual sequencing step and is
**not invoked from within this audit node**.

1. **Over-approximating CFG reachability is sound but useless for solc output** — dynamic
   `JUMP` (internal function returns) forces every dispatcher entry to appear to reach every
   site. The decisive technique is **complete external-interaction accounting**: enumerate
   every `CALL`/`STATICCALL` site, bind each to a specific source-level operation via the
   materialised selector constants, and show the count is exactly saturated with none spare.
   Absence of `approve`/`transferFrom` selectors proved more than any reachability walk.
2. **Audit a gate's matching semantics, not just its logic.** A default-deny universe that is
   *narrower* than the conditional exemption it guards inverts the intended relationship.
   `-name` vs `-iname` between `source_universe()` and `loa_zone_solidity()` was the entire
   finding — and the negative control shared the blind spot, which is the general lesson:
   **negative controls inherit the blind spots of the code they were written alongside.**
3. **Deriving the stronger invariant beats verifying the stated one.** The review's
   single-shot `ceil(B/S)` remainder generalises to *`⌈B/S⌉` is preserved by every
   redemption*, making exhaustion path-independent — a closed-form result that explains the
   property instead of counting fuzz runs.
4. **`mulDiv`'s overflow revert being unreachable** (because `q < S ⟹ payout ≤ B`) is a
   stronger and more useful statement than "512-bit math is used": it converts a perceived
   liveness risk into a proof that the exit right cannot be denied by arithmetic.
5. **Auditing write-restricted skills:** running the native methodology in the audit context
   while persisting the artifact manually preserves both the verdict contract and the
   evidence-gathering capability the skill's own `allowed-tools` would forbid.

---

## Security checklist status

- [x] Secrets & credentials — none in subject; no hardcoded addresses in `src/`
- [x] Authentication & authorization — two immutable single-purpose gates, proven closed
- [x] Input validation — zero-address rejection, supply-floor bound, malformed-input guards
- [x] Data privacy — N/A (no PII); launch-secret hygiene gate present
- [x] Supply chain — 63/63 byte-identical, pins honoured, no new dependency *(see A-1)*
- [x] API/surface security — dispatcher enumerated and exactly matched, both contracts
- [x] Error handling — typed errors, whole-transaction atomicity, no partial-success path
- [x] Threat model — attacker-controlled burn source, prefunding, reentrancy, sweep, overflow all attacked
- [x] Testing — 61 implementation tests + 22 independent auditor probes, 10,000-run fuzz both sides
- [x] Documentation — manually verified (no coherence reports exist)
- [x] Blockchain/crypto — runtime opcode census, init-code-only capability, CEI, `nonReentrant`

## Next node

`/retrospective --scope auditing-security` (material reusable learning exists — §27), **then**
explicit operator acceptance of digest `78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a`.

Sprint 2 is **not** marked completed by this node. **STOP.**

**Pass-1 machine verdict (historical record — demoted from an active trailer to plain text
when pass 2 was appended, because `verdict-derive.sh:149` requires exactly one `LOA-VERDICT`
trailer and it must be the file's last line. Content preserved verbatim, nothing erased):**

```
LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":1,"low":3},"sprint_id":"sprint-2","ts":"2026-08-11T22:15:00Z"}
```

The pass-1 verdict above applied to subject `78c8881204…2ac45a`, which was **superseded** by the
A-1 remediation. It is retained as history and is **not** the operative verdict. The operative
verdict is pass 2 below, on subject `a6313a4d5a…2b772cf`.

---
---

# Security Audit — cycle-002 / Sprint 2 — **PASS 2: exact-tree re-audit after A-1 remediation**

**Auditor role:** Paranoid Cypherpunk Auditor (`auditing-security`, native methodology)
**Audit mode:** sprint · **Node type:** AUDIT-ONLY (no lifecycle closure)
**Date:** 2026-08-12
**Canonical base:** `79c966f6c55899489fdb9db176773ef69e6ecf62`
**Predecessor gate:** focused `/review-sprint sprint-2` on the remediated subject → APPROVED
**Reason for re-audit:** the pass-1 audited subject was mutated to remediate MEDIUM **A-1**;
the exact-tree discipline requires the verdict to name the tree it was proven against.

> **The pass-1 APPROVED verdict was not inherited.** Every load-bearing claim below was
> re-derived from repository state and executed evidence. Where pass 1 or the focused review
> asserted something, it was treated as a hypothesis to attack, not as a result.

---

## 1. Verdict

# VERDICT: APPROVED

**0 critical / 0 high / 1 medium / 5 low.**

One-way rule: `critical + high = 0`, so `CHANGES_REQUIRED` is not forced. The single MEDIUM
(**M-1**) is assessed below by judgment against the operator's decision framework and found
**non-blocking for Sprint-2 operator acceptance**, with a **binding pre-deployment condition**.

Sprint 2 is **NOT** marked completed, **NOT** operator-accepted, and nothing was committed,
pushed, tagged, or landed by this node.

---

## 2. Subject digest — entry, mid, exit

Subject reconstructed independently from repository state: all working-tree paths differing
from base `79c966f6`, excluding `grimoires/**`, `.beads/**`, `.run/**` → **exactly 18 files**.

| Point | Digest | Files |
|---|---|---|
| Audit **entry** | `a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf` | 18 |
| After adversarial probes + mutation test | `a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf` | 18 |
| Audit **exit** | `a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf` | 18 |

**IDENTICAL, and matches the expected digest.** The per-file manifest at exit was diffed
against the entry manifest: byte-identical, path set identical. No `HITL_REQUIRED` condition.

Digest convention (`<sha256>` + two spaces + path, `LC_ALL=C` sort **by path**, LF, trailing
newline) was **recovered**, not assumed — it reproduces the pass-1 published digest exactly.

Current manifest (4 changed vs. pass-1 entry are marked ✎; 14 are byte-identical ✓):

| SHA-256 | Path | vs pass-1 |
|---|---|---|
| `1768f4d56fe56e9b083e9717adccbabc96d65f3366c3745484f0be2cb7edbf72` | `.github/workflows/provenance.yml` | ✎ |
| `47b290cdc75e512796538bc20a1de71cc8a12c0e7bede7c0ac7506651377703e` | `foundry.toml` | ✓ |
| `74b8319ab155225b4533790b88d3adc71c8da117ff74d4124e180f3bd39f2c17` | `src/HardReserve.sol` | ✓ |
| `5686c4c7c353711998eccb3693bda44d9ab0352ed79d69a1b853447dc5197349` | `src/VUX.sol` | ✓ |
| `3910bf9d440a1755cd6bad3e0e7975ad0a1adb9a0f5a4b0e91ee9391ed83eb24` | `src/interfaces/IVUX.sol` | ✓ |
| `1cff3ef705eb3deec06f9544c0a2e7db0277a17dd42949396c12eb4278e1e183` | `test/harness/Artifact.sol` | ✓ |
| `8cdf7ad5ce285f8af0c27eb1c14ab9dddb2928abcc9858991afb98f9e57f7523` | `test/harness/BaseTest.sol` | ✓ |
| `297c15752e88d1ece393a7ea40cda3750686595174daee58263c38b566fa0cdb` | `test/harness/Vm.sol` | ✓ |
| `3d29a61312f679f635709c7eefcbc47af6cc48a0a60e37cf12b215704cff833b` | `test/mocks/MockWeth.sol` | ✓ |
| `95ce221261afab1ca670bef29c6bef2c293642b9eb0085c366a92906589ad0b4` | `test/reserve/HardReserveRedemption.t.sol` | ✓ |
| `1e36fa00c0eedc99bdba4b7edb53f635abaf9a870a35ede6997abec46b159b24` | `test/reserve/HardReserveSurface.t.sol` | ✓ |
| `3f0b3ac7161070d16b619b23b9f6947cf8daf0aa8f7013d962ce795b51425f5a` | `test/reserve/ReserveFixture.sol` | ✓ |
| `b4a3e005a76d915c1d9dace6f4a54b97b40f303c1bc9b6f6f079a4c9e3f6faaf` | `test/token/VuxToken.t.sol` | ✓ |
| `63e8ec9d21fd40568db90bc3345a520b8aefe2dab1ae394395664c14bebf8533` | `tools/provenance/census.sh` | ✎ |
| `fc37fcc28e7f9601a6b29bcb067ca56956c97dcd08be28722a6cceb1c4efa033` | `tools/provenance/demo-boundary-negative.sh` | ✎ |
| `c653a62a9b3add941428c4dbe9bfeac767c63f209a697d05ee9a9a73d0292f2c` | `tools/provenance/inspect-runtime-surface.sh` | ✓ |
| `b4a373abd3e18afc05b65c416448ed4db5fd4747f65074d6c0c2252629a90045` | `tools/provenance/run-all.sh` | ✓ |
| `2530dcd9f2b618564c5af1a709e27a62dca84fff93632f8d14f0c9f8cf82dee5` | `tools/provenance/verify-census.sh` | ✎ |

Both operator-declared product anchors are unchanged: `src/VUX.sol` → `5686c4c7…97349`,
`src/HardReserve.sol` → `74b8319a…9f2c17`.

---

## 3. Retrospective separation

Every path changed since base, partitioned:

```
SUBJECT (outside state zones) : 18   — exactly the table above, nothing else
grimoires/**                  : 35
.beads/**                     : 201
.run/**                       : 5
```

The re-review retrospective mutated **only** `grimoires/**` (plus beads/run bookkeeping).
**Zero** source, test, provenance-tooling, CI, vendor, authority, or evidence bytes were
touched by learning capture. The audited subject is exactly the subject the focused re-review
approved.

---

## 4. Four-file remediation diff — assessment

### 4.1 A `git diff` trap, caught by pre-image reconstruction

Raw `git diff` against base is **misleading** here, because the tree has been uncommitted
across several lifecycle nodes. Two concrete traps were found and disarmed:

- **`tools/provenance/run-all.sh`** shows as modified by `git diff`. It is **byte-identical to
  the pass-1 audit entry** (`b4a373ab…a90045` both sides) — it is *not* a remediation file. Its
  diff belongs to the earlier `/implement sprint-2` node.
- **`.github/workflows/provenance.yml`** shows `FOUNDRY_PROFILE: ci` as an addition, which
  reads as a new CI change. It is not. Reconstructing the pass-1 pre-image (base **plus only
  that hunk**) yields `85e2123216dc3993ffcad06a8ff1a8db654dbcf6cd46d2de528beb2a38c0a136` —
  an **exact match** to the pass-1 audited hash. So `FOUNDRY_PROFILE: ci` was already inside
  the audited subject; this node did not add it.

Exactly **4** files differ from the pass-1 audit entry, and **14 are byte-identical**,
verified hash-by-hash rather than asserted.

### 4.2 The executable delta is two tokens

Stripping comments from the diffs, the entire A-1 behavioural change is:

| File | Change | Verdict |
|---|---|---|
| `census.sh:205` | `-name '*.sol'` → `-iname '*.sol'` | **Necessary and sufficient** for the walk |
| `verify-census.sh:146` | `grep -E` → `grep -iE` on `(^\|/)UniswapV3Factory\.sol$` | **Jointly necessary** — see §6 |
| `demo-boundary-negative.sh` | +4 negative probes, +1 positive control | Evidence only |
| `provenance.yml` | job name, comments, pinned-toolchain install step | Required by the new control |

Everything else in those diffs is comment/evidence, or belongs to the pre-existing sprint-1
N-1 closure (the `BUILD_ARTIFACT_PRUNE`/`LOA_ZONE_PRUNE` split and `loa_zone_solidity`), which
was already inside the pass-1 audited subject.

### 4.3 Authorization did not expand; prunes did not weaken

- `VUX_SOURCE_ROOTS=(src test script)` — **byte-identical to base**; the string does not appear
  as a changed line in any diff. No root was added.
- Prune sets: base was one flat list `(.git out out-v3core cache cache-v3core broadcast .claude
  grimoires .beads .run .ck)`; current is the **same set** split into `BUILD_ARTIFACT_PRUNE` +
  `LOA_ZONE_PRUNE`. Set-equal, and the Loa zone is now *conditionally* exempt (asserted
  Solidity-free) rather than absolutely — strictly stronger.
- No new dependency, no `lib/`, no submodule/gitlink, no `.gitmodules`. `remappings.txt` is
  unchanged from base and maps only to the two vendored trees. `forge-std` appears solely in
  comments documenting its deliberate absence.

### 4.4 CI toolchain identity

`.github/workflows/provenance.yml` pins `FOUNDRY_VERSION: v1.0.0` (refreeze §6 →
`8692e926198056d0228c1e166b1b6c34a5bed66c`), installs it via
`foundry-rs/foundry-toolchain@82dee4ba…` (40-char pin), and — importantly — **asserts** it,
failing the build on divergence rather than leaving the claim resting on a human reading a
log. The boundary-demo job gained the same pinned install, which the new positive control
genuinely requires; the stale `# Needs only git + jq` comment was correctly retired rather
than left false. Every GitHub Action is pinned to a 40-character commit (gate-verified).

**No unrelated behaviour changed in any of the four files.**

---

## 5. A-1 — closure, independently attacked

**Confirmed CLOSED.** Attacked at **fresh probe sites**, deliberately disjoint from those used
by the implementation, the reviewer, and pass 1, with `^FAIL`-**anchored** reason matching
(pass-1 finding L-3 makes unanchored matching untrustworthy — see §12):

| # | Probe (auditor-authored, fresh site) | Exit | Anchored reason on a real `FAIL` line | Result |
|---|---|---|---|---|
| P1 | `lib/AuditorMixed.SOl` | 1 | `unauthorized Solidity source` | **CLOSED** |
| P2 | `contracts/AuditorMixed.sOL` | 1 | `unauthorized Solidity source` | **CLOSED** |
| P0a | *baseline, no probe* | 0 | no match | matcher cannot match a green gate |

`lib/` and `contracts/` were chosen deliberately: `lib/` is Foundry's conventional dependency
directory (in-scope on purpose) and `contracts/` is the Hardhat convention — neither was used
by any prior node. Both mixed-case variants fail closed for the **boundary** reason.

The baseline row is the control the operator required: the same matcher run against a
**green** gate produces no match, so a passing gate can never be mistaken for a caught probe.

---

## 6. The `-iE` filename detector — isolating assessment

The focused review's **L-4** says this changed detector has no dedicated standing probe. That
is correct, and it meant the necessity of `grep -E` → `grep -iE` was unproven. **I authored the
isolating probe** and ran it:

Probe **P3**: `test/UniswapV3Factory.SoL` — planted **inside a declared VUX root**, where
default-deny **cannot** fire (the file classifies as `vux`, which is authorized).

```
P3 test/UniswapV3Factory.SoL     exit=1   FAIL-anchored-reason=yes
   FAIL  UniswapV3Factory.sol implementation present — excluded by refreeze §8:
   ATTRIBUTION: default-deny did NOT fire — the -iE filename detector is solely responsible
```

**Attribution isolated:** the default-deny reason was explicitly checked for and was **absent**,
so the catch is attributable to the filename detector alone. This proves `-iE` is **jointly
necessary, not scope creep**: fixing the walk alone would have left `UniswapV3Factory.SOL`
inside `src/`/`test/`/`script/` completely uncaught.

**False-positive control (operator-specified):**

```
P4 test/IUniswapV3Factory.SOL    exit=0   => clean (no false positive)
```

The `(^|/)` anchor correctly prevents the authorized *interface* `IUniswapV3Factory` from
tripping the detector for the prohibited *implementation*. The regex is correctly anchored.

---

## 7. Mixed-case probe results (standing suite)

`demo-boundary-negative.sh` exit **0** — 11 negative probes plus probe 12's positive control,
which proves mixed-case `.SOL` is genuinely build-reachable by reading solc's own
`metadata.sources` **and** executing a deployed instance, rather than trusting a resolver
diagnostic. Probes 8–11 (root `.SOL`, `docs/` `.SoL`, pruned Loa zone `.sOl`, prohibited-source
behind `.SOL`) all fail closed for their stated reasons.

---

## 8. M-1 — extension-keyed universe: independent reproduction

**Reproduced independently at a fresh site, and confirmed worse than a naming curiosity.**

Probe **P5**: `docs/AuditorExt.txt` containing valid Solidity **and all three prohibited-source
names** (`Olympus`, `gumball6900`, `give.fun`):

```
P5 docs/AuditorExt.txt (default-deny)      exit=0   => gate green, nothing detected
P5 docs/AuditorExt.txt (prohibited-source) exit=0   => gate green, nothing detected
```

Neither default-deny classification nor the prohibited-source content scan fires. The file is
ordinary, git-trackable, and sits in a directory that is never pruned and never a source root.

### 8.1 Compiler-reachability evidence (not inferred)

Built in a throwaway Foundry project **outside** the repository, on the pinned **solc 0.8.28**:

1. Foundry printed `Unable to resolve imports: "./Payload.txt"` — **in the same run as**
   `Compiler run successful!`. Per the learned discipline, this diagnostic was recorded as
   evidence and **never read as a verdict**.
2. **Authoritative check —** solc's own metadata for the importing artifact:
   ```
   $ jq -r '.metadata.sources | keys[]' out/Importer.sol/Importer.json
   src/Importer.sol
   src/Payload.txt          <-- the .txt IS a compilation input
   ```
3. **Execution check —** a deployed instance runs the payload's code:
   ```
   [PASS] test_ExtSourceIsExecutable() (gas: 68396)
   ```
   (the payload returns a sentinel `31337`, asserted by `require`).

Note that **no separate artifact directory was emitted** for `Payload.txt` — which is exactly
why "an artifact appeared" is not a reachability oracle either. `metadata.sources` plus
execution is.

**Conclusion: non-`.sol` Solidity is genuinely accepted, compiled, and executable under the
pinned compiler.** M-1 is real.

### 8.2 Is the gap exploited in *this* subject? — No, proven

I applied the recommended structural fix **once, as an audit measurement**, cross-checking what
the compiler actually compiled against the classified universe. Two independent extraction
paths agreed:

| Source of truth | Count | Non-`.sol` entries |
|---|---|---|
| `out/build-info/*.json` → `source_id_to_path` | 47 | **0** |
| every artifact's `.metadata.sources` | 47 | **0** |

And the subset check against the gate's own classified universe:

```
universe: 77   compiled: 47
compiled sources NOT in the classified universe:  (empty)
classification of the compiled set:  33 vendored, 14 vux, 0 unauthorized
```

**Every source that actually became part of this build is classified and authorized.** The M-1
gap is **latent in the tooling, unexploited in the subject.**

*(Method note: the first run of this cross-check reported all 47 as unclassified. That was a
false positive — `jq` on Windows emits CRLF, so every comparison failed. It was diagnosed and
corrected before use, not reported.)*

---

## 9. M-1 — severity and disposition

**Severity: MEDIUM. Disposition: non-blocking for Sprint-2 operator acceptance, with a binding
pre-deployment condition (§20).** Neither the review's severity nor its disposition was
inherited; both were re-derived. The reasoning, against the operator's framework:

### 9.1 What the *accepted authority* actually guarantees

This is the load-bearing question, and it resolves in the tooling's favour. The accepted
default-deny is a **source-reuse authorization** rule, not a scanner predicate:

> "default deny: no copying/modification unless a file appears in the frozen file-reuse
> allowlist" — `vux-v1-strategic-treasury-provenance-boundary-delta-2026-08.md:28`

> "A file not enumerated in §3/§4 remains unauthorized. No wildcard, directory-level, or
> entire-repository authorization exists anywhere in this refreeze."
> — `vux-v1-oz-v3-provenance-refreeze-2026-08.md:19`

That obligation governs **whether VUX may copy upstream third-party source**. It is enforced by
(a) 63/63 byte-identity against the accepted registry, and (b) the `vendor/` check, which is
already **extension-agnostic**: *"zero unenumerated files of any type under `vendor/`"*
(`verify-census.sh:126-135`, gate-verified this run). **M-1 does not breach the accepted
authority's default-deny**, because the surface that rule governs is covered on every axis.

### 9.2 Where the overstatement is real

The *tooling* claims more than the authority requires, and more than it delivers:

- `census.sh:141` — "Every Solidity file in the working tree is classified into exactly one of
  three classes."
- Gate output — "zero unauthorized Solidity source **anywhere in the repository**"; §8 header
  "**repository-wide**".

On the extension axis those are **overstatements**, demonstrably so per §8. Notably, the A-1
comment block is *precise* where the header is not: it claims only that "neither relocating
source nor **re-casing its extension** can move it out of any gate's reach" (`census.sh:150`) —
true, and it does not claim extension-renaming immunity. The defect is that `census.sh:183-201`
justifies case-insensitivity by reasoning about solc's byte-for-byte import resolution — and
**that identical reasoning applies to any extension**, which the code does not follow through on.

### 9.3 Why this is not blocking for Sprint-2 acceptance

1. **The accepted invariant is not breached** (§9.1) — the authority's default-deny targets
   upstream source reuse, which is enforced extension-agnostically inside `vendor/`.
2. **The conclusion the evidence supports is true, and I verified it by a stronger method.**
   The gate's phrasing overreaches, but the compiler-metadata cross-check (§8.2) — which is
   extension-agnostic and asks the compiler rather than guessing from names — confirms this
   subject's build contains nothing unclassified. No Sprint-2 acceptance-relevant conclusion
   is invalidated.
3. **Pre-existing, not introduced.** The A-1 remediation neither created nor widened M-1;
   the subject is not made worse by the four-file change.
4. **A natural later gate exists.** `foundry.toml` records that bytecode-affecting settings are
   deliberately unset until "deployment bytecode is frozen (Sprints 7–8)". Nothing is deployed
   from this subject, so closing M-1 before that freeze loses nothing.
5. **Exploitation requires deliberate, visible product-source mutation** — an
   `import {X} from "./thing.txt";` line inside `src/`/`test/`/`script/`, the most scrutinised
   surface in the repository, and semantically conspicuous in review.

Point 5 is deliberately listed **last and is not the basis** for the disposition — the operator
warned against dismissing M-1 on visibility alone, and points 1 and 2 stand without it.

### 9.4 Why it is also not dismissible

An asymmetry the prior artifacts did not draw out, and which I judge material: A-1's mitigation
("weaponising needs a plainly visible act") is **weaker** for M-1 than for A-1. A `.SOL` still
*reads* as Solidity in a PR diff; a `.txt` does not, so a reviewer's eye is less likely to snag
on it. This is partly offset by lower accident-probability (nobody creates `Payload.txt`
containing Solidity by mistake, whereas case-variant `.SOL` can arise from tooling or a
case-insensitive filesystem). It is enough to make M-1 a **required** pre-deployment fix rather
than an optional hardening.

### 9.5 Recommended shape

Cross-check every path in every artifact's `metadata.sources` (or `build-info`) against the
classified universe, and fail closed on any compiled path that is unclassified. This closes the
case axis, the extension axis, and **any future naming axis structurally**, because it asks the
compiler what it compiled instead of inferring from filenames. §8.2 demonstrates it works on
this repository today.

It is a **complement, not a replacement**: it cannot see a dormant unauthorized file that
nothing imports, which is precisely what the existing filesystem walk is good at. Both are
needed. (This converges independently with the focused review's §14 recommendation.)

---

## 10. Probe-attribution quality

The `prove-which-fence-caught-it` principle was applied to every auditor-authored probe:

- **Isolation** — P3 was placed *inside* a declared root specifically so default-deny could not
  fire, leaving the filename detector as the only possible detector (§6).
- **Anchoring** — every reason match required the pattern to appear on a line beginning
  `^FAIL`, not merely somewhere in the output.
- **Green-gate control** — every matcher was run against a **passing** gate first and confirmed
  not to match (§5, row P0a). A non-zero exit was never accepted as proof on its own.
- **Explicit negative attribution** — for P3 the *absence* of the default-deny reason was
  asserted, not assumed.
- **Classification vs. detection distinguished** — P1/P2 exercise default-deny classification;
  P3 exercises prohibited-source/§8 filename detection; P5 tests both and finds both silent.

No finding in this report rests on an ambiguous gate attribution.

---

## 11. Mutation-test quality

The `verify-the-mutant-not-the-verdict` discipline was applied to confirm the **standing**
probes are non-vacuous, rather than trusting the implementation's report of the same experiment:

1. **Anchor uniqueness proven first.** `-iname '*.sol'` occurs **twice** (lines 205 and 227), so
   a naive substitution would have hit both. A unique anchor (`find . \(`, 1 occurrence,
   line 205 only) was established and line 227 confirmed not to contain it.
2. **Mutation proven to land.** `census.sh:205` `-iname` → `-name`; hash moved
   `63e8ec9d…bebf8533` → `4c96bacf…df7cb3eb`; `diff` showed **exactly one** changed line;
   line 227 verified untouched.
3. **Probes run against the mutant** — result:

   | Probe | Behaviour under mutant | Flip? |
   |---|---|---|
   | 8 — repo root `.SOL` | `FAIL … PASSED with the probe present — the fence is open` | **flipped** |
   | 9 — `docs/` `.SoL` | `FAIL … the fence is open` | **flipped** |
   | 11 — prohibited behind `.SOL` | `FAIL … the fence is open` | **flipped** |
   | 10 — pruned Loa zone `.sOl` | still `ok … failed closed for the right reason` | **did not flip** |

4. **Non-flip explained, not waved away.** Probe 10 is caught by `loa_zone_solidity`
   (`census.sh:227`), which was already `-iname` and which I deliberately left unmutated. Its
   non-flip is the *expected* outcome and independently confirms the two functions are distinct
   detectors. Mutant demo exit: **1**.
5. **Restored by hash.** `census.sh` restored to `63e8ec9d21fd40568db90bc3345a520b8aefe2dab1ae394395664c14bebf8533` — byte-exact — and `verify-census.sh` re-run green (exit 0).
6. **Subject digest re-verified** after restoration: `a6313a4d5a…2b772cf` (§2).

The standing probes are **discriminating**, not decorative.

---

## 12. L-3 / L-4 disposition

**L-3 — CONFIRMED (LOW), and now precisely bounded.** `demo-boundary-negative.sh:97` greps the
expected reason **unanchored** across the whole gate output, which contains `ok` lines as well
as `FAIL` lines. Empirically tested against the **green** gate:

| Reason regex | Matches a green PASS line? | Probes affected |
|---|---|---|
| `unauthorized Solidity source` | **YES** — `ok  zero unauthorized Solidity source anywhere in the repository …` | 5, 8, 9 |
| `pruned Loa/state zone` | **YES** — `ok  zero Solidity in the pruned Loa/state zones …` | 7, 10 |
| `prohibited-source reference` | no | 11 — clean |
| `UniswapV3Factory\.sol implementation present` | no | 2 — clean |

So **5 of 11** probes degrade to "failed for *some* reason" (the review's phrasing was correct;
the scope is narrower than all-probes). **Fix:** anchor on `^FAIL`.

**Not escalated**, because the A-1 evidence does not depend on it: §5–§6 re-derive the same
conclusions with `^FAIL`-anchored matching *and* a green-gate control, and §11's mutation test
independently shows probes 8/9/11 are discriminating on the right predicate.

**L-4 — CONFIRMED (LOW).** The one changed detector line (`verify-census.sh:146`) has no
standing probe. I authored the isolating probe (§6) and it passes, but it lives in this report,
not in CI — so the detector remains unguarded against future regression. **Not escalated**: the
detector is currently correct and proven so.

**I-1 (census pre-image not independently reconstructible) — INFO, resolved in practice for
this node.** Pre-image reconstruction *was* achievable for the audited paths by isolating hunks
against the base commit; `provenance.yml`'s pass-1 pre-image was reproduced to an exact hash
match (§4.1). The general observation stands as a documentation improvement, not a defect.

**I-2 (one standing probe conflates two detectors) — INFO, confirmed.** Consistent with the
L-3 finding above; same fix (anchoring) plus per-probe detector assertions. No evidence in this
report relies on a conflated probe.

None of L-3, L-4, I-1, I-2 undermines the provenance guarantee or the evidence base. **No
perfection-loop pursued.**

---

## 13. Product monetary-core regression

All five `src/**` and all eight `test/**` files are **byte-identical** to the pass-1 audit
entry (§2), so pass 1's monetary-core proofs carry over without re-proof. Reconfirmed anyway,
directly from source and from execution:

| Invariant | Evidence | Status |
|---|---|---|
| Immutable Rig mint authority | `address public immutable rig` (`VUX.sol:82`); `mint()` gated `if (msg.sender != rig) revert NotRig()` (`:108-111`); sole post-genesis mint path | ✅ |
| Immutable Reserve redemption-burn authority | `address public immutable reserve` (`:85`); `burnForRedemption()` gated `if (msg.sender != reserve) revert NotReserve()` (`:123-126`) | ✅ |
| No callable `burnFrom` | Function absent entirely; only `burn(uint256)` → `_burn(msg.sender, …)` and reserve-gated `burnForRedemption` | ✅ |
| Exact genesis supply | `GENESIS_POL_SUPPLY = 150_000e18`, `GENESIS_RESERVE_SEED = 1`, both `constant`, minted only in the constructor | ✅ |
| Pre-state `floor(B*q/S)` redemption | `test_PayoutUsesPreRedemptionStateNotPostBurnState`, `testFuzz_PayoutIsFloorOfBTimesQOverS` (10,000 runs) | ✅ |
| Full-precision overflow safety | `testFuzz_PayoutIsExactWhenBTimesQOverflowsUint256` (10,000 runs); `test_NaiveProductRevertsWhereRedeemSucceeds` | ✅ |
| S_MIN = 1 | `test_RedeemingTheFinalUnitIsRejected` | ✅ |
| Third-party burn impossibility | `test_RedemptionBurnsOnlyTheCallersOwnVux`, `test_RedeemerWithNoBalanceCannotDrainAnotherHoldersVux`, `test_TheTokenGateRejectsADirectRedemptionBurn` | ✅ |
| Constructor prefunding sanitization | `testFuzz_ConstructorSanitizesAnyPreExistingWeth` (10,000 runs), `test_PrefundingCannotDistortTheGenesisBackingTarget`, `test_SanitizationMarkerIsInInitCodeAndNotInRuntimeCode` | ✅ |
| Runtime absence of sweep/recovery | `test_RuntimeContainsNoUpgradeDestructionOrDeploymentOpcode`, `test_NoProhibitedAuthoritySurfaceExists`, `test_ReserveHoldsTheSeedAndHasNoWayToMoveIt` | ✅ |
| Reserve external surface | `test_ExternalSurfaceIsExactlyRedeemPlusViews`, `test_NoEtherCanBeSentToTheReserve` | ✅ |

Constructor additionally rejects zero dependencies (`if (rig_ == address(0) || reserve_ ==
address(0)) revert ZeroAddress()`), and reentrancy is covered (`test_ReentrantRedeemIsRejected`).

**Full suite:** `FOUNDRY_PROFILE=ci bash tools/provenance/run-all.sh` → **exit 0**, **61/61
tests passed**, property suites at **10,000 fuzz runs**. Zero regression.

---

## 14. Provenance / vendor / pool-hash regression

Executed this run, all green:

| Check | Result |
|---|---|
| Vendored byte identity | **63/63** byte-identical to accepted identities |
| Census counts | OZ **28** / v3-core **32** / Miner **3** — exact |
| Source universe | **77** Solidity files = 63 vendored + 14 VUX-owned (roots `src test script`) |
| Unauthorized source | **zero** |
| `vendor/` exactness | zero unenumerated files **of any type** (extension-agnostic) |
| Pool init-code hash | `POOL_INIT_CODE_HASH` **reproduced and equal** to the accepted constant |
| Compiler pins | solc `0.8.28` / `0.7.6`, foundry `v1.0.0` — all recorded, no short SHA |
| Action pins | every GitHub Action pinned to a 40-character commit |
| `forge-std` | absent — no `lib/`, no submodule, no import; referenced only in comments noting its absence |
| New dependencies | **none** |
| Authority artifacts | 4 accepted artifacts match recorded SHA-256 |
| SPDX | 63/63 vendored retain upstream SPDX verbatim; 14 VUX-owned match PROV-8 policy |
| HardReserve clean-source | VUX-owned, PROV-8-conformant, unchanged from pass 1 |
| §17 quarantine | green |
| Source-boundary gate | green; negative demonstration exits 0 |

---

## 15. Findings by severity

**Critical: 0 · High: 0 · Medium: 1 · Low: 5**

### MEDIUM

**M-1 — canonical source universe is keyed to Solidity-looking filename extensions.**
*Pre-existing; not introduced by the A-1 remediation.* A git-trackable file with a non-Solidity
extension can contain valid Solidity — including all three prohibited-source names — evade
default-deny classification, SPDX, §17 and the prohibited-source scan, and still be compiled
and executed via an explicit import from a declared VUX root (§8, proven by `metadata.sources`
+ execution). **Non-blocking for Sprint-2 acceptance** (§9.3): the accepted authority's
default-deny governs upstream source reuse and is enforced extension-agnostically inside
`vendor/`, and the compiler-metadata cross-check proves this subject's build is fully
classified (§8.2). **Required before deployment-bytecode freeze** (§20). Fix shape: §9.5.

### LOW

**L-3 — unanchored reason matching in the negative demonstration** (`demo-boundary-negative.sh:97`).
Confirmed; affects 5 of 11 probes (§12). Fix: anchor on `^FAIL`.

**L-4 — no standing isolating probe for the `-iE` filename detector.** Confirmed (§12). The
detector is correct today (§6), but unguarded against regression.

**L-1 — stale `HardReserve` test-pointer comments** (`src/HardReserve.sol:31`, `:100`).
Carried from pass 1; `src/**` byte-identical, so neither worsened nor resolved. Cosmetic.

**L-2 — `forge fmt --check` residue.** Carried from pass 1, unchanged. Cosmetic.

**L-5 — auditor-environment toolchain divergence (disclosed, not a subject defect).** Local
`forge` is **1.5.0-stable**; the accepted pin is **v1.0.0**. All compiler-reachability evidence
(§8.1) used the pinned **solc 0.8.28**, and CI installs *and asserts* v1.0.0 (§4.4), so the
subject's own guarantee is unaffected. Disclosed because the build-info key used in §8.2
(`source_id_to_path`) is a Foundry-1.5-era format; an implementation of §9.5 should read
`metadata.sources` (stable across both) or verify the key under v1.0.0.

**Not reopened** (no new security consequence, per instruction): R-1…R-6 residue and the
remaining pass-1 LOW items.

---

## 16. Audit-only mutations

| Path | Nature |
|---|---|
| `grimoires/loa/a2a/sprint-2/auditor-sprint-feedback.md` | **This report** (authorized). Pass-1 content preserved verbatim; its machine trailer demoted to plain text so exactly one `LOA-VERDICT` trailer remains as the final line, per `verdict-derive.sh:149`. |

**Transient, fully reverted:** 6 probe files (`lib/`, `contracts/`, `test/`, `docs/`) planted
and removed; `census.sh` mutated and restored **byte-exact by hash**; `out/`, `cache/`,
`out-v3core/`, `cache-v3core/` rebuilt (all `.gitignore`d, outside the subject). A throwaway
Foundry project was built **outside the repository** in the session scratchpad.

**Nothing else was mutated.** Specifically **not**: `src/**`, `test/**`,
`tools/provenance/**` (net-zero), CI, vendor, authorities, implementation evidence, review
evidence, Sprint Plan completion state, ledger completion.

---

## 17. Lifecycle confirmations

**No lifecycle closure.** Verified, not assumed:

- Ledger: `{"global_id": 2, "local_label": "sprint-2", "status": "in_progress", "completed": null}` — untouched.
- No `COMPLETED` marker created; `a2a/index.md` not advanced.
- Sprint 2 remains **NOT COMPLETED** and **NOT OPERATOR_ACCEPTED**.

**No commit / push / tag / landing.** No `git commit`, `git push`, `git tag`, merge, PR, or
release action was performed at any point by this node. The working tree remains uncommitted,
with the subject byte-identical to audit entry (§2).

---

## 18. Pre-acceptance conditions

**For operator acceptance of Sprint 2 at digest `a6313a4d5a…2b772cf` — required now: none.**
A-1 is closed and proven closed; the four-file remediation is safe and bounded; the product
subject is byte-identical and revalidated; no remaining defect requires remediation *before
acceptance*.

Conditions attaching to the acceptance, to be carried forward:

1. **M-1 must be closed before deployment-bytecode freeze (Sprints 7–8)** — implement the
   compiler-metadata cross-check (§9.5) as a gate, complementing the filesystem walk. This is
   binding, not advisory.
2. **L-3 and L-4 should be closed in the same bounded node** — anchor reason matching on
   `^FAIL` and add a standing isolating probe for the `-iE` filename detector. Cheap, and both
   protect the evidence base that future audits depend on.
3. **Provenance claim language should be tightened** wherever it says "anywhere in the
   repository" / "repository-wide" / "Every Solidity file", to state the extension-bounded
   scope honestly until condition 1 lands.
4. Cosmetic L-1/L-2 remain optional and carry no security consequence.

Conditions 1–3 are **out of scope for `/implement sprint-2`** as currently defined — they are
tooling hardening on a pre-existing gap, and routing them through this sprint would re-open a
subject that is otherwise ready. Recommend a separate bounded node, exactly as A-1 itself was
handled.

---

## 19. Reusable learning

**Yes — material reusable learning was discovered.** Candidates:

1. **A guarantee's scope is set by its predicate, not its prose.** Both A-1 and M-1 are the same
   defect on different axes of one predicate (`-name '*.sol'`). The durable lesson: when a gate
   claims universality, identify the *predicate* that decides membership and enumerate every
   axis it keys on (case, extension, path, symlink, encoding) — fixing one axis leaves the
   others open and can make the surviving prose *more* misleading, not less.
2. **Ask the compiler, don't guess from names.** `metadata.sources` / `build-info` is an
   authoritative, extension-agnostic answer to "what compiled?", and it is cheap. Corollary
   confirmed twice here: neither a resolver warning *nor the absence of an emitted artifact*
   is evidence of unreachability (§8.1).
3. **Distinguish the accepted invariant from the tool's phrasing.** M-1's disposition turned
   entirely on reading the *authority* (source-reuse authorization) rather than the *gate's
   output string* — and the authority's own surface was already covered extension-agnostically.
   Escalation decisions belong against the accepted invariant, not the implementation's claim.
4. **Verify the oracle before reporting its verdict.** The §8.2 cross-check first reported all
   47 sources unclassified — a CRLF artifact of `jq` on Windows, not a finding. A comparison
   that returns *everything* is a signal to debug the comparison.

Per the operator's instruction, `/retrospective` is **not** invoked automatically.

---

## 20. Next node

Recommended, in order, both requiring explicit operator invocation:

1. `/retrospective --scope auditing-security` — material reusable learning exists (§19).
2. **Explicit operator acceptance** of exact-tree subject
   `a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf`, carrying forward the
   §18 conditions.

**`/implement sprint-2` is NOT recommended** — no remediation is required before acceptance.

Sprint 2 is **not** marked completed by this node. **STOP.**

---

## 21. OPERATOR_ACCEPTANCE

**Recorded 2026-08-12, verbatim from the operator:**

> OPERATOR_ACCEPTANCE — VUX CYCLE-002 / SPRINT-2
>
> I accept the exact audited Sprint-2 subject:
>
> AUDIT_SUBJECT_DIGEST:
> a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf
>
> Lifecycle evidence:
>
> IMPLEMENTED → REVIEW_APPROVED → AUDIT_APPROVED
>
> Final audit disposition: 0 CRITICAL / 0 HIGH / 1 MEDIUM / 5 LOW. A-1 is CLOSED.
>
> The remaining MEDIUM M-1 is accepted as non-blocking for this exact Sprint-2
> subject because independent audit established that all actually compiled
> sources in the audited tree are classified and no unauthorized source is
> present. This acceptance does NOT waive M-1.
>
> **Binding carry-forward condition:** before Sprint-3 product implementation
> begins, perform a separate bounded provenance-tooling hardening node that
> closes M-1 by complementing the filesystem source-universe walk with
> compiler-derived compiled-source coverage. That bounded node should also
> address L-3 (negative-demo reason matching can match PASS output) and L-4
> (no standing isolated negative probe for the case-insensitive
> `UniswapV3Factory` filename detector). Do not reopen Sprint 2 to implement
> those changes. Do not fold unrelated LOW findings into that node.
>
> **Exact-tree rule:** any mutation to the accepted Sprint-2 implementation
> subject before landing invalidates this acceptance for the changed tree and
> requires audit of the resulting tree.
>
> This acceptance authorizes landing of the exact audited Sprint-2 subject
> only. It does not authorize: Sprint-3 implementation; provenance-tooling
> remediation; dependency expansion; operator-reserved decisions; deployment;
> tag/release.
>
> Sprint 2 is accepted for landing.

**Pre-landing verification, independently re-run at this node before acting on
the acceptance:** subject digest reproduced `a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf`
— **matches** the accepted digest exactly, no tree mutation occurred between
audit exit and this acceptance. Lifecycle closure (ledger, index, beads epic)
was performed **as this node's own action**, downstream of and authorized by
the acceptance above — see `grimoires/loa/NOTES.md` and
`grimoires/loa/a2a/index.md` for the closure record. **Landed on `master` as
`89a92055`**; the committed tree's 18-file subject was re-hashed from the
commit object itself (`git show 89a92055:<path>`, not the working tree) and
its aggregate digest reproduced byte-exactly to the accepted value.

**Scope of this node's actions, mirroring the acceptance's explicit boundary:**
sprint-2 lifecycle closure (ledger `completed`, index `LANDED_VERIFIED`, beads
epic closed) + a single `build:` commit of the exact audited subject plus its
evidence trail. **Not performed:** Sprint-3 work, provenance-tooling
remediation, dependency changes, deployment, tagging, or release.

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":1,"low":5},"sprint_id":"sprint-2","ts":"2026-08-12T00:00:00Z"} -->
