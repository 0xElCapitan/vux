# Sprint 7 Review — Genesis: Non-Griefable Launch Implementation & Adversarial Rehearsal

Sprint 7 has been independently reviewed against the exact uncommitted tree and is
**APPROVED** to advance to security audit. All six tasks and all twelve launch-security
obligations are satisfied on evidence I re-derived myself. No critical, high, or medium
finding exists.

I did not rely on the implementation's green report. Every load-bearing claim below was
reproduced from the tree: the subject fingerprint, the initcode measurement, the price
encoding (three independent implementations), the nonce-stability mutation, a mutation of
my own against the Reserve sanitization path, and a planted-secret probe against the
hygiene gate. Two low findings and three informational notes remain; none is load-bearing.

---

## 1. Reviewed implementation identity — independently derived

| Property | Derived value | Reported | Match |
|---|---|---|---|
| Branch | `sprint-7` | `sprint-7` | ✓ |
| HEAD | `c58d41b8c77f3191114a5242c4bac9ff753f32dc` | baseline unchanged | ✓ |
| Commits ahead of baseline | `0` | 0 | ✓ |
| Worktrees | 1 (`C:/Users/0x007/vux`) | one normal worktree | ✓ |
| Group A files | **11** | 11 | ✓ |
| Group A fingerprint | **`38bbdc88022762f61fd5172cb0218687e718478a91697bea647b9ae2de45312a`** | same | ✓ |

Derived per the accepted recipe: `git status --porcelain -uall -z`, partitioned by path
prefix, **sorted by path**, rendered `<sha256>  <path>` (two spaces), joined with `\n`, no
trailing newline. Group A excludes `grimoires/`, `docs/authority/`, `.beads/`, `.run/`,
`grimoires/loa/analytics/`, `ledger.json.bak`, `ledger.json.lock`.

The eleven files: `src/GenesisDeployer.sol`, `script/GenesisRehearsal.s.sol`,
`test/genesis/{GenesisFixture,GenesisWiring.t,GenesisAdversarial.t,GenesisPriceEncoding.t}.sol`,
`test/fork/RhWethFork.t.sol`, `test/harness/Vm.sol` (M), `test/mocks/MockWeth.sol` (M),
`tools/genesis/demo-nonce-negative.sh`, `tools/offchain/encode-sqrt-p0.mjs`.

**No material discrepancy.** The reported identity is exact.

**Product subject vs. retrospective artifacts — correctly separated.** The pending
State-Zone learning artifacts (`grimoires/loa/skills-pending/**`, seven skills) and the
trajectory JSONL files are Group C lifecycle churn, not application-code mutation. They do
not enter Group A and did not move the fingerprint. I re-derived the fingerprint again
*after* completing all verification work (including two source mutations and a planted
secret probe) and it is byte-identical — evidence that this review node mutated nothing.

The two modified files are purely **additive**: `Vm.sol` gains five cheatcode
*declarations* (`skip`, `envOr` ×2, `envUint`, `broadcast`); `MockWeth.sol` gains a
`deposit()` that mints `msg.value`. Nothing was removed or weakened.

---

## 2. Evidence I reproduced independently

| # | Evidence | Method | Result |
|---|---|---|---|
| E-1 | Full accumulated Forge suite | `forge test` | **444 passed, 0 failed, 10 skipped** (37 suites); skips are the fork suite off-fork |
| E-2 | Genesis suites | `forge test --match-path 'test/genesis/*'` | **47 passed, 0 failed** (Wiring 28, Adversarial 12, PriceEncoding 7) |
| E-3 | Initcode measurement | parsed `out/GenesisDeployer.sol/GenesisDeployer.json` directly | creation **47,609 B** + args **448 B** = **48,057 B**; limit 49,152; headroom **1,095 B** — reproduces exactly |
| E-4 | Compiler identity | artifact metadata | `solc 0.8.28+commit.7893614a` = the pinned commit; optimizer on, runs 200; `via_ir` true |
| E-5 | `sqrtP0X96` encoding | my own BigInt **binary-search** isqrt (neither the Solidity nor the `.mjs` algorithm) | both orientations reproduce the pinned constants exactly |
| E-6 | Off-chain encoder | `node tools/offchain/encode-sqrt-p0.mjs --rehearsal` | matches E-5 and the pinned test constants |
| E-7 | Premium + cushion law | exact BigInt cross-multiplication | `10·p0Num·S0 == 11·p0Den·B0` holds; cushion = 27,272,727,272,727,272,727 wei ≥ 25e18 opening |
| E-8 | Nonce-stability negative | `tools/genesis/demo-nonce-negative.sh` | green → **red (`PredictedAddressMismatch(3, …)`)** → green; source restored byte-identical |
| E-9 | **My own mutation** — Reserve sanitization | removed *both* the sanitizing transfer **and** the born-empty guard from `HardReserve` | launch still reverts, via `GenesisDeployer`'s **own** `ReserveNotBornEmpty(1e24)` — defense-in-depth confirmed; restored byte-identical |
| E-10 | **My own probe** — hygiene gate | planted a `PRIVATE_KEY = 0x…` and `LAUNCH_SALT = 0x…` literal under `script/` | gate went 371 → 372 files, **exit 0 → 1**, both patterns caught; probe removed |
| E-11 | Provenance gates | `tools/provenance/run-all.sh` | **all 9 gate sections pass** — census/byte-identity, pins, SPDX, notices, quarantine, launch hygiene, `POOL_INIT_CODE_HASH`, runtime surface, tests |
| E-12 | `POOL_INIT_CODE_HASH` | gate reproduction from the compiled `=0.7.6` artifact | `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` = the constant hard-coded in `GenesisDeployer` |
| E-13 | Off-fork Q-6 representation | `forge test --match-path 'test/fork/*'` | **0 passed, 10 SKIPPED** — skips are never reported as passes |

E-9 is the finding I consider most valuable: it demonstrates that the exact-`B0` outcome
is protected by **two independent guards** in different contracts, and that the
`GenesisDeployer`-side guard alone is sufficient. A silently broken Reserve constructor
cannot produce a contaminated genesis; it reverts the entire launch.

---

## 3. The twelve launch-security obligations

All twelve are adequately evidenced. I verified each mapping against the actual test
bodies, not just the names.

| # | Obligation | Disposition |
|---|---|---|
| 1 | Leaked future addresses cannot grief genesis | **Met.** `test_FullKnowledgeAdversaryCannotAlterOneWeiOfGenesis` prefunds every predicted address, forces ETH, builds hostile pools, attacks the one-shot and spams — then asserts all seven addresses, exact `B0`/`S0`/seed/price, live-state `P0/N0`, and zero attacker credit |
| 2 | Hostile lookalike pools irrelevant | **Met.** Four **real** pools from pinned bytecode at tiers 100/500/3000/10000, hostile init price, built from attacker-owned rogue deployers (strictly more capability than a public factory); each `!= treasury.pool()`, protocol holds zero liquidity in each |
| 3 | Canonical CREATE2 identity exact | **Met, and genuinely independent.** The test derives from the *compiled artifact's* init-code hash; the contract uses the *accepted constant*; a separate gate ties constant to artifact. Neither derivation assumes the other's conclusion |
| 4 | Arbitrary prefunding cannot alter genesis | **Met.** 5,000 ETH to every predicted address + forced ETH; "provably stuck" rows asserted as *still present* (the correct form of that claim); forced ETH neither wrapped nor read — only `msg.value` is wrapped, never `address(this).balance` |
| 5 | Very-large Reserve prefund sanitized | **Met.** 1,000,000 ETH; precondition asserted before launch (not vacuous); ends at exactly `B0`; both events emitted; zero revenue, zero mint credit. Confirmed by my mutation E-9 |
| 6 | Exact physical `B0`, `N0`, `P0/N0`, first `B_pre` | **Met.** The ratio is checked against **live** balance and **live** supply, not the recorded constants; `B_pre` read through the Lens, i.e. the value settlement itself would observe |
| 7 | No temporary authority survives | **Met.** Renounce proven by a real reverted call **with the Safe succeeding on the same call as a positive control**; complete ABI is 13 read-only getters, enumerated from `methodIdentifiers` |
| 8 | Launch EOA gains no protocol authority | **Met.** No role argument exists anywhere in the system; asserted for launch sender, deployer, attacker and `address(0)` |
| 9 | `VuxPoolDeployer` consumed and ownerless | **Met.** Second deploy reverts for the attacker *and* for the real `GenesisDeployer`; `owner` is a `constant address(0)` — a property of the bytecode, not an unset slot |
| 10 | Exact init price + cushion | **Met.** Exact `slot0` equality, plus two negatives and a **boundary control** proving the cushion law is `<=` rather than "always fail" |
| 11 | Callback authorization one-shot, exact-pool-bound | **Met.** The genesis mint runs the real `_arm → pool.mint → _requireConsumed` path; forgery rejected for hostile pools, for the attacker, **and for the canonical pool out of context** |
| 12 | Production secrets absent | **Met, and the gate is discriminating** — proven by E-10, not accepted as an absence claim |

---

## 4. Core review questions — dispositions

**Q1 — constructor-only, no surviving surface.** Confirmed structurally, not just by test.
`GenesisDeployer` declares **no** external or public functions and **no** `receive`/
`fallback`. The only ABI entries are one `constant` and twelve immutable getters. There is
no `genesis()` to trigger, front-run, or replay.

**Q2 — nonce prediction and RLP derivation.** `_predict` builds
`keccak256(0xd6 ‖ 0x94 ‖ addr ‖ nonce)`. I verified the RLP framing: payload = 1 + 20 + 1 =
22 = `0x16`, list prefix `0xc0 + 0x16 = 0xd6`; single-byte nonce encoding is valid exactly
for `1 ≤ n ≤ 0x7f`, and the domain guard rejects everything outside. Only the two forward
references (`predict(3)`, `predict(4)`) need prediction, and both are verified
in-transaction. The extra-CREATE negative is real (E-8). Nonce stability across the pool
CREATE2 is proven as an **address fact**, not a nonce reading: treasury still at 4, Lens
still at 5, and **nonce 6 asserted empty** — which pins the sequence at exactly five
CREATEs.

**Q3 — canonical pool identity.** Tied to all four required anchors: the accepted
`VuxPoolDeployer` (`pool.factory()`), the canonical salt `keccak256(abi.encode(token0,
token1, fee))`, the accepted `POOL_INIT_CODE_HASH` (E-12), and `treasury.pool()`. A hostile
`poolDeployer` supplied by mistake cannot pass: the derived address must match under the
accepted init-code hash, which forces the genuine vendored pool implementation, and
`owner()` must be dead.

**Q4 — initialization exactness.** No floating point enters any authoritative path.
Solidity uses `Math.mulDiv` (512-bit intermediate) + `Math.sqrt` (floor); the `.mjs`
encoder uses BigInt Newton; my check used BigInt binary search. All three agree (E-5/E-6).
The floor convention is asserted as the exact integer property `r² ≤ x < (r+1)²` — which is
the "< 1 ulp" claim made precise — with a neighbouring-root discrimination test and a
**transposition** test (the most plausible encoder mistake) carrying a *derived*,
explicitly non-vacuous tolerance. Ratio and cushion are checked by exact
cross-multiplication on recorded wei, never re-derived from Q64.96.

**Q5 — POL provisioning through the real callback.** Genesis calls
`treasury.mintPolPosition`, which is `onlyRole(OPERATOR_ROLE)` and routes through the one
shared `_addLiquidity`: arm `CTX_MINT` → real `pool.mint` → `_requireConsumed()`. The
callback checks caller-is-pool, armed context, token direction, per-side committed maxima,
empty data, and **consumes before paying**. No approval is granted anywhere; all four
allowance directions assert zero.

**Q6 — contamination sanitization preserves exact physical state.** All six sub-claims
hold: Reserve born empty (guarded twice — E-9); sanitized amount distinguished and evented
(`PreGenesisWethSanitized` from the Reserve, `PreGenesisContaminationSwept` from the
deployer, both asserted by emitter); exact `B0` deposited and delta-verified; physical
`B0`/`N0`/`P0/N0`/first `B_pre` all correct on live state; contamination receives zero VEM
credit and zero revenue classification; and no runtime cleanup capability survives — the
provenance gate independently confirms the sanitization marker is **present in creation
bytecode and absent from deployed runtime**, with an opcode census showing no `CREATE`,
`CREATE2`, `CALLCODE`, `DELEGATECALL`, or `SELFDESTRUCT`.

The step-9 contamination check is an **exact identity** (`residual == wethPreSelf +
sanitized`), not a `> 0` sweep. I verified the arithmetic closes: after step 0 the deployer
holds `wethPreSelf + wPol + b0`, after step 1 `+ sanitized`, and step 7 removes exactly
`wPol` and `b0` — so the residual *is* the contamination, and asserting that identity is
what would expose a leaked intended flow.

**Q7 — prefunding and forced ETH cannot grief.** Confirmed. Only `msg.value` is wrapped, so
forced ETH is left untouched and unread; the test asserts the forced ETH is *still there*
after launch. Funding exactness is enforced in both directions (`±1 wei` both revert).

**Q8 — authority fully extinguished.** Launch EOA never appears in the system (nothing to
renounce); deployer roles renounced with a real negative *and* a Safe positive control;
Safe holds both roles; `VuxPoolDeployer` consumed and `owner` permanently `address(0)`;
`vux.balanceOf(deployer) == 0` and `weth.balanceOf(deployer) == 0` both asserted after the
sweep. The immutable core (`VUX`/`Rig`/`HardReserve`/`Lens`) is probed by `staticcall` to
confirm `hasRole`/`owner()` do not even exist.

**Q9 — supply, King, POL, dust.** `S0 = 150_000e18 + 1` exact; Reserve seed exactly 1;
`rig.king() == reserve` with `epochUPS() == 0`; POL position non-empty and owned by the
treasury, with deployer/sender/Safe positions asserted zero; quantization dust bounded and
classified as principal-side inventory, never revenue.

**Q10 — the rehearsal exercises the shipped path.** Yes. `GenesisFixture` performs the real
two-transaction choreography — it predicts the `GenesisDeployer` address from the launch
sender's nonce *after tx1 consumes one*, exactly as the founder must, and a mis-sequenced
prediction produces the same `BadCommitment` revert a real mis-sequenced launch would. The
pool and pool-deployer are the **genuine `=0.7.6` artifacts**, deployed from compiled
bytecode — not mocks. The suite is not a parallel harness: `src/GenesisDeployer.sol` itself
is under test, and E-8/E-9 confirm the shipped guards are load-bearing by mutating the
shipped source.

**Q11 — secret hygiene.** Real and sufficient for Sprint 7. The rehearsal script reads its
key from `VUX_REHEARSAL_PK`, contains no production EOA/nonce/salt/addresses/manifest/
conversion values, and `broadcast/**` is gitignored and gate-checked. The gate scans
tracked **plus untracked-not-ignored** files — which matters here, because the entire
Sprint-7 subject is untracked — and E-10 proves it actually fires.

**Q12 — Q-6 representation.** Correct on all three points. (a) The fork proof is from the
real canonical RH WETH (`0x0Bd7…AD73`, chain 4663) at block 39130641, with block hash,
parent hash and state root recorded, and identity asserted via `l1Address`/`l2Gateway`/
EIP-1967 slots. The probe wraps inside a *constructor* and spends in that same constructor
— the exact accepted topology — asserting three measured deltas (balance, `totalSupply`,
WETH's own ETH balance) with two negative controls (`NoCreditWeth`, non-payable
`deposit()`). (b) Off-fork cases report `[SKIP]`, never a pass (E-13), and the pack states
this explicitly as R-7. (c) The Sprint-5 carry is correctly scoped: it says the *currently
deployed* implementation invokes no recipient callback, records that the proxy and its
admin are upgradeable exactly as §21 discloses, and states that "the existing reachability
assessment of the Sprint-5 finding is **unchanged**" with no Sprint-5 code touched. It does
**not** claim the finding is fixed. The `HookingWeth` control makes the four `calls == 0`
assertions falsifiable, and the pack honestly discloses that a static opcode walk was run
but **not relied upon**, with the reason.

---

## 5. Initcode / gas

Treated as a review question, and the answer is that Sprint 7 discharged its obligation.

- The measurement **includes the bytes actually submitted for contract creation**: creation
  code **plus** the 448-byte ABI-encoded `GenesisParams` tuple. The test asserts the tuple
  is exactly 14 static words, so the 448 cannot silently drift.
- It uses the **accepted build configuration** — solc `0.8.28+commit.7893614a` matches the
  pinned commit; the `via_ir`/`optimizer` settings are the Sprint-3 amendment already in
  `foundry.toml`, which Sprint 7 did not modify.
- **48,057 B < 49,152 B.** The reference limit is correct: EIP-3860 `MAX_INITCODE_SIZE =
  2 × MAX_CODE_SIZE = 2 × 24,576`.
- Runtime is 1,070 B against EIP-170's 24,576 B — no pressure there.

I reproduced every figure (E-3). **The artifact is deployable under the environment Sprint 7
assumes, and I am not inventing a percentage-headroom requirement that authority does not
contain.** 1,095 bytes is thin, and the pack says so plainly rather than burying it; the
bound is now enforced by a CI test, so growth fails as a red test rather than as a dead
launch. That is the correct Sprint-7 outcome.

The un-characterised Robinhood Chain production constraints are **not** converted into a
Sprint-7 code defect. I found no contradiction. See L-1 for one narrow sharpening of that
Sprint-8 item.

---

## 6. Scope and provenance

Confirmed clean. Sprint 7 introduced **no** unauthorized smart-contract source, vendored
code, dependency, package, v3-periphery source, `UniswapV3Factory.sol`, P1 Signal/LSG
mechanism, or Sprint-8 mechanism.

- `vendor/`, `docs/authority/`, `foundry.toml`, `package.json`, `package-lock.json`,
  `remappings.txt`, `.gitmodules` — **all unmodified** (absent from porcelain).
- `prd.md`, `sdd.md`, `sprint.md` — **unmodified**.
- No `UniswapV3Factory.sol` and no v3-periphery path exists anywhere in the tree.
- Every import in the subject resolves to already-vendored OpenZeppelin, already-vendored
  v3-core **interfaces**, or internal project files.
- The immutable vendor census gate passes byte-identity (E-11).

`src/v3core/VuxPoolDeployer.sol` is pre-existing Sprint-4 source, unmodified by Sprint 7;
its genesis-context proofs are re-run here as the plan requires.

I did not reopen accepted Sprint-5 accounting decisions or Sprint-6 residuals.

---

## 7. Disposition of R-1 … R-7 and the open review questions

| Item | Disposition |
|---|---|
| **R-1** — 1,095 B (2.2%) initcode headroom | **Bounded non-blocking residual.** Measurement verified correct and under the applicable limit; now CI-enforced. Not a defect. The optimizer-tuning question is a Sprint-8 deployment-freeze decision |
| **R-2** — RH Orbit gas/size semantics not independently characterised | **Sprint-8 launch-readiness/runbook item.** Correctly disclosed, correctly deferred. See L-1 for one addition to its scope |
| **R-3** — `Adversary`-account separation is a modelling choice | **Not a finding.** The choice is faithful — no real attacker can spend the founder's nonce — and it is disclosed rather than hidden. It does not conceal a nonce-fragility class: `predict(3)`/`predict(4)` are verified in-transaction against whatever the real sequence turns out to be, nonce 6 is asserted empty, and E-8 mutates the shipped source to prove the guard fires. My answer to open question 3 is that no additional class is required |
| **R-4** — dust asserted by bound, not exact value | **Not a finding.** The load-bearing half is the *exceed* bound (`≤` the founder leg), which is exactly what a donation booked as principal would violate. v3 mint principal is bounded, not exact, so an exact assertion would be wrong, not stronger |
| **R-5** — `MockWeth` gained `deposit()` | **Not a finding.** Purely additive; semantics mirror what Q-6 *measured* rather than a guess; no existing suite is weakened. I diffed it |
| **R-6** — rehearsal Safe / fee tier / tick spacing are stand-ins | **Not a finding.** These are R-14 operator-reserved facts, domain-checked and value-frozen nowhere. Q-3 correctly remains a Sprint-8 runbook input |
| **R-7** — off-fork Q-6 reports `[SKIP]` | **Not a finding — and verified.** E-13 confirms 0 passed / 10 skipped off-fork. This is the honest representation, not a gap |
| **Open Q1** — carry 2.2% headroom into Sprint 8? | **Yes, carry it.** It is measured, under the limit, and CI-guarded. Revisiting optimizer settings changes every VUX contract's bytecode and belongs at the Sprint-8 deployment freeze, not here |
| **Open Q2** — should the runbook require RH confirmation of EIP-3860 + block gas limit? | **Yes.** Recommended as an explicit pre-launch input, extended per L-1 |
| **Open Q3** — additional adversarial class perturbing the launch account? | **Not required.** See R-3 |

---

## 8. Findings

No critical, high, or medium findings.

### L-1 (LOW) — `evm_version` is unpinned for the `=0.8.28` unit; R-2 does not name EVM-version compatibility

`[profile.v3core]` pins `evm_version = "istanbul"` explicitly and comments that the line is
load-bearing. `[profile.default]` deliberately leaves `evm_version` **unset** — documented
in `foundry.toml` as "still an R-14 [deployment fact]". The consequence is that the VUX
artifacts compile at whatever Foundry's default is; on the pinned foundry v1.5.0 the
metadata records **`evmVersion: prague`**.

This is **not a Sprint-7 defect**: the deferral is pre-existing accepted configuration from
Sprint 3, Sprint 7 did not modify `foundry.toml`, and Sprint 7 met its measurement
obligation under the accepted build. But R-2 currently scopes the un-characterised RH facts
to "the same EIP-3860 ceiling and the same block gas limit". EVM-version/opcode
compatibility is a third fact in the same family and is not named. An Orbit chain trailing
the default hard fork would be a deployability problem that neither the local suite nor the
anvil fork would surface, because both apply stock rules to newly deployed code.

**Recommendation (Sprint 8, runbook):** extend the R-2 pre-launch input set from two facts
to three — EIP-3860 ceiling, block gas limit, **and** the EVM version / hard-fork level RH
accepts — and record whether `evm_version` should be pinned explicitly for the `=0.8.28`
unit at the deployment freeze, alongside the optimizer decision already queued by R-1. No
code change is required in Sprint 7.

### L-2 (LOW) — no `reviewer.md` implementation handoff report for Sprint 7

Sprints 5 and 6 both close their implementation node with
`grimoires/loa/a2a/sprint-N/reviewer.md` — the implementer's report to the review node.
Sprint 7 has only `evidence/` (`genesis-evidence-pack.md`, `q6-native-wrap.md`,
`q6-fork-run.txt`). The operator's review mandate names `a2a/sprint-7/reviewer.md` as an
authoritative input; that file does not exist, and the R-1…R-7 residuals it refers to live
in `genesis-evidence-pack.md` §10 instead.

The **substance is present and complete** — I found nothing missing in content, and the
evidence pack is a superset of what a `reviewer.md` would have carried. This is an
artifact-convention deviation affecting the declared input set of the next node, not a
defect in the implementation.

**Recommendation:** the audit node should read `evidence/genesis-evidence-pack.md` §10 where
its mandate says `reviewer.md`. No remediation of Sprint-7 code is required.

### Informational

- **I-1.** The step-4 `pool.initialize` call precedes the derived-address verification. This
  matches the accepted SDD ordering ("then `pool.initialize(sqrtP0X96)` … **Verify**") and is
  harmless because the whole construction is atomic — a mismatch reverts the launch. Noted
  so the audit node does not re-derive it.
- **I-2.** The closing self-verification does not re-check `pool.factory()` or
  `IUniswapV3Factory(poolDeployer).owner()`, both of which the SDD's closing list mentions.
  Not a gap: both are checked in step 4 inside the same atomic transaction, `pool.factory()`
  is a pool immutable, and `VuxPoolDeployer.owner` is a compile-time `constant address(0)`
  rather than a mutable slot. The properties hold at transaction end by construction.
- **I-3.** `_verifyBootstrapEconomics` uses checked 256-bit multiplication for the premium
  identity rather than a 512-bit comparison. The overflow branch is fail-closed (it reverts
  the launch rather than wrapping into a false equality) and the realistic products sit ~30
  orders of magnitude below the limit. The reasoning is documented in-code. Correctly not
  over-engineered; the adjacent cushion computation does use `Math.mulDiv`.

---

## 9. Verdict

**`APPROVED`.** The exact Sprint-7 tree — fingerprint
`38bbdc88022762f61fd5172cb0218687e718478a91697bea647b9ae2de45312a`, 11 files, HEAD at
baseline `c58d41b8` with zero commits ahead — satisfies the accepted Sprint-7 requirements
at the project's acceptance threshold.

Genesis executes entirely inside a constructor and leaves an ABI of thirteen read-only
getters with no `receive`/`fallback`; the nonce plan is verified in-transaction and proven
load-bearing by source mutation; the canonical pool identity is closed by two independent
derivations meeting at one address under the gate-reproduced `POOL_INIT_CODE_HASH`; the
price encoding is integer-only and reproduces across three independent implementations with
its floor convention asserted as an exact integer property; POL provisioning runs the real
authenticated one-shot callback; contamination is sanitized behind two independent guards
and classified with zero mint credit and zero revenue, leaving physical `B0`, `N0`,
`P0/N0`, and first `B_pre` exact under a 1,000,000 ETH adversarial prefund; every temporary
authority is extinguished with positive controls proving the negatives are not vacuous; and
the secret-hygiene gate is discriminating rather than merely green. Scope and provenance are
unchanged and re-verified from the toolchain. Twelve of twelve launch-security obligations
are adequately evidenced. Two low findings and three informational notes remain; neither low
finding requires a Sprint-7 code change, and both are Sprint-8 runbook items.

**Recommended next node:** `/audit-sprint sprint-7`.

---

*Reviewed by the Loa `/review-sprint sprint-7` node, 2026-08-18. Every claim above was*
*re-derived on the exact tree — the full accumulated suite, the genesis suites, all nine*
*provenance gate sections, the initcode measurement from the raw artifact, a third*
*independent price-encoder implementation, the shipped nonce-stability mutation, an*
*additional mutation of my own against the Reserve sanitization path, and a planted-secret*
*probe against the hygiene gate. Nothing was accepted on report. No implementation source,*
*test, build configuration, authority document, or provenance registry was mutated — the*
*Group A fingerprint is byte-identical before and after this review. Nothing was committed,*
*pushed, or marked complete, and no audit was begun.*

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":2},"sprint_id":"sprint-7","ts":"2026-08-18T00:00:00Z"} -->
