# Sprint 7 — Genesis: Non-Griefable Launch Implementation & Adversarial Rehearsal — Implementation Report

**Status:** **`SPRINT_7_IMPLEMENTED_READY_FOR_REVIEW`**
**Branch:** `sprint-7` · **Baseline:** `c58d41b8c77f3191114a5242c4bac9ff753f32dc` (= `master` = `origin/master`, unchanged — no commit made)
**Date:** 2026-08-17 (Task 7.1 / Q-6 HITL pass · resumed after operator acceptance · Tasks 7.2–7.6)
**Node:** `/implement sprint-7` — implementation only. No review, audit, operator acceptance of the sprint, landing, commit, push, or Sprint-8 work performed by this node.

**Subject fingerprint** (derived from git per the accepted recipe):

| Group | Files | Fingerprint |
|---|---|---|
| A — implementation subject | 11 | `38bbdc88022762f61fd5172cb0218687e718478a91697bea647b9ae2de45312a` |
| B — activated authority | 0 | — (no accepted authority document touched) |

---

## ⚠ Historical accuracy notice — this file is a retroactive restoration

**This `reviewer.md` was not written during Sprint-7 implementation.** It was
created after the fact, on 2026-08-18, to repair an accidental omission: the
Sprint Plan requires `/implement sprint-7` to produce this artifact, and the
implementation node reached `SPRINT_7_IMPLEMENTED_READY_FOR_REVIEW` without
writing it.

The omission was caught and dispositioned by the two nodes that followed, both
against the exact tree this file now describes:

- `/review-sprint sprint-7` (`engineer-feedback.md`) independently re-derived
  every substantive claim from the tree itself — not from a missing report —
  and carried the absence as **finding L-2 (LOW)**, recommending the audit
  node read `evidence/genesis-evidence-pack.md` §10 in `reviewer.md`'s place.
  Verdict: **`APPROVED`**.
- `/audit-sprint sprint-7` (`auditor-sprint-feedback.md`) confirmed L-2 as
  **carried LOW, process/artifact debt**, noted the one concrete mechanical
  consequence (`validate-ac-verification.sh` could not run in its intended
  form), and confirmed the omission did not impair the audit. Verdict:
  **`APPROVED`**, recorded in `COMPLETED`.

**This restoration does not, and cannot, change either verdict.** It exists
only to (a) supply the durable native handoff artifact the Sprint Plan
requires and (b) run the `validate-ac-verification.sh` check that the missing
file made impossible to run in its intended form at the time. Specifically,
this file:

- **Did not exist** when `/review-sprint sprint-7` ran. The review consumed
  the implementation tree and `evidence/genesis-evidence-pack.md` directly,
  not this file.
- **Was not validated** before `grimoires/loa/a2a/sprint-7/COMPLETED` was
  written. The `COMPLETED` marker's approval is unaffected by anything in
  this document.
- **Is constructed only from implementation-era evidence** — the exact
  Group A tree, the accepted Sprint Plan, `evidence/genesis-evidence-pack.md`,
  `evidence/q6-native-wrap.md`, `evidence/q6-fork-run.txt`, and the original
  `SPRINT_7_IMPLEMENTED_READY_FOR_REVIEW` terminal report. It deliberately
  does **not** import findings the review or audit nodes discovered on their
  own (their independent mutations, their opcode-floor characterization,
  their planted-secret probe) — importing those would make this report
  falsely appear stronger than what implementation actually produced and
  handed off.
- `engineer-feedback.md` and `auditor-sprint-feedback.md` are **unmodified**
  by this restoration. Both continue to record, accurately, that `reviewer.md`
  was absent when they ran.

---

## Executive Summary

Sprint 7 is implemented. All six tasks are complete; the twelve accepted
launch-security obligations are met, each mapped to a named test.

Task 7.1 (Q-6) was a fail-closed intra-sprint operator gate: canonical
Robinhood Chain WETH's native-wrap semantics had to be verified on a real
fork before `GenesisDeployer.sol` could be written. The node halted at
`HITL_REQUIRED — SPRINT_7_Q6_NATIVE_WRAP_EVIDENCE_READY_FOR_OPERATOR_ACCEPTANCE`
with **zero implementation begun**, and resumed at Task 7.2 only after the
operator returned `OPERATOR_ACCEPTANCE — SPRINT_7_Q6_NATIVE_WRAP_ACCEPTED`.
The rejected pre-approval funding fallback was never activated or
implemented.

**Nine gates, all green:**

| Gate | Result |
|---|---|
| `forge test` (whole accumulated suite) | **444 passed, 0 failed, 10 skipped** |
| Genesis wiring suite | **28 passed** |
| Adversarial rehearsal suite | **12 passed** |
| Price-encoding suite | **7 passed** |
| Q-6 fork suite, on-fork | **10 passed** (10 `[SKIP]` off-fork — never represented as a pass) |
| `tools/provenance/run-all.sh` | **exit 0**, all 8 gate sections green |
| `tools/provenance/verify-launch-hygiene.sh` | green, 371 files scanned |
| Nonce-stability mutation demo (`tools/genesis/demo-nonce-negative.sh`) | green → red → green, source restored byte-identical |
| `forge fmt --check` | clean on every file this sprint touched |

**The core deliverable is a constructor with no callable surface.**
`GenesisDeployer.sol`'s complete ABI is thirteen read-only getters — no
`genesis()`, no setter, no initializer. Genesis executes entirely inside the
`GenesisDeployer` creation transaction (tx2, following the inert
commitment-gated `VuxPoolDeployer` of tx1), and a full-knowledge adversary —
given every future address, the pool address, token ordering, fee/tick
configuration, the init-code hash, **and the commitment salt itself** — was
proven unable to alter one wei of the intended economics or acquire any
protocol authority
(`GenesisAdversarialTest.test_FullKnowledgeAdversaryCannotAlterOneWeiOfGenesis`).

No previously accepted implementation was modified. No new dependency,
vendored file, package, or provenance surface entered the tree.

---

## AC Verification

Sprint 7 acceptance criteria, verbatim from `grimoires/loa/sprint.md:483-495`
(preserved as a point-in-time slice at
`grimoires/loa/a2a/sprint-7/sprint-7-scope.md`). **13 of 13 met.**

> Leaked future addresses cannot grief genesis (full-knowledge adversary; launch succeeds unchanged at intended addresses)

**✓ Met.** `test/genesis/GenesisAdversarial.t.sol:test_FullKnowledgeAdversaryCannotAlterOneWeiOfGenesis`.
The adversary is given every predicted address before tx2 runs and prefunds,
forces ETH, builds hostile pools, attacks the one-shot, and spams — the
legitimate launch then lands at all seven predicted addresses
(`src/GenesisDeployer.sol` steps 1–6) with `B0`, `S0`, the Reserve seed, and
`slot0.sqrtPriceX96` all exact.

> Hostile public-factory lookalike pools (every fee tier, hostile init, one-sided liquidity) are irrelevant — referenced nowhere

**✓ Met.** `test/genesis/GenesisAdversarial.t.sol:test_HostileLookalikePoolsAtEveryFeeTierAreIrrelevant`
and `…test_CallbackForgeryFromAHostilePoolIsRejected`. Four real pools, built
from pinned v3-core bytecode via attacker-owned `VuxPoolDeployer` instances,
at fee tiers 100/500/3000/10000, each hostile-initialized. Every one is
`!= treasury.pool()`, the protocol holds zero liquidity in any of them
(`StrategicTreasury.sol` pool identity is a constructor immutable with no
registry lookup), and every forged callback from a hostile pool reverts.

> Canonical pool CREATE2 identity exact: independent recompute `create2(vuxPoolDeployer, keccak256(abi.encode(token0,token1,fee)), POOL_INIT_CODE_HASH)` equals deployed pool equals `treasury.POOL()` (sdd.md:L859)

**✓ Met.** `test/genesis/GenesisWiring.t.sol:test_CanonicalPoolCreate2IdentityIsExactEndToEnd`.
The recompute is derived from the *compiled pool artifact's* own init-code
hash (`PoolDeployerHarness._poolInitCodeHash`), while `GenesisDeployer.sol`'s
`_deriveCanonicalPool` uses the *hard-coded accepted constant*
`POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`
— two independent derivations meeting at one address, plus
`test_PoolInitCodeHashConstantMatchesTheCompiledArtifact` tying the constant
to the artifact directly.

> Arbitrary prefunding (WETH to every predicted address + forced ETH) cannot alter exact genesis state — per-address defense table outcomes verified (sdd.md:L172-L184)

**✓ Met.** `test/genesis/GenesisAdversarial.t.sol:test_PrefundingEveryPredictedAddressLeavesGenesisExact`
and `…test_ForcedNativeEthIsIrrelevantToEveryGenesisQuantity`. 5,000 ETH to
nine predicted addresses plus `selfdestruct`-forced ETH to seven; `B0` stays
exact; the "provably stuck" defense-table rows (VUX/Rig/Lens/pool-deployer)
are asserted *still present*, not merely absent from any accounting cell;
forced ETH is neither wrapped nor read (`GenesisDeployer.sol` step 0 wraps
only `msg.value`, never `address(this).balance`).

> Future-HardReserve prefunding constructor-sanitized: **very large** prefund → `PreGenesisWethSanitized` → ends as unattributed Strategic inventory

**✓ Met.** `test/genesis/GenesisAdversarial.t.sol:test_VeryLargeReservePrefundIsSanitizedAndReclassified`.
A **1,000,000 ETH** prefund to the predicted Reserve address; `HardReserve`'s
constructor (`src/HardReserve.sol`) sanitizes it to the deployer before the
runtime exists and requires itself born empty; the Reserve ends genesis at
exactly `B0`; `PreGenesisWethSanitized` and the deployer's
`PreGenesisContaminationSwept` are both emitted; `realizedRevenue[WETH] == 0`
and `vux.totalSupply()` is unchanged (zero VEM credit).

> Final physical Reserve balance is exactly `B0` (`WETH.balanceOf(reserve) == B0`), physical `N0 = B0/S0` and `P0/N0 = 1.10` intact, first-settlement `B_pre == B0` (sdd.md:L187)

**✓ Met.** `test/genesis/GenesisWiring.t.sol:test_PhysicalB0AndTheDerivedBackingFacts`
and `…test_FirstSettlementBPreIsExactlyB0`. The `P0/N0 = 1.10` identity is
checked against the **live** `weth.balanceOf(reserve)` and **live**
`vux.totalSupply()`, not the recorded input constants; `B_pre` is read
through `Lens.hardStats()` — the same value the first real settlement would
observe.

> No temporary authority survives: roles renounced, deployer holds nothing, one-shot consumed (second `deployCanonicalPool` reverts), no callable genesis surface exists

**✓ Met.** `test/genesis/GenesisWiring.t.sol:test_FinalRoleTopologyIsSafeOnly`,
`…test_TheDeployerCannotExerciseTreasuryAuthorityAfterwards`, and
`…test_GenesisDeployerExposesOnlyReadOnlyGetters`. Renounce is proven by a
real reverted call from the deployer with the Safe succeeding on the
identical call as a positive control; `GenesisDeployer.sol`'s complete ABI,
enumerated from the compiled artifact's `methodIdentifiers`, is thirteen
read-only getters and nothing else; `VuxPoolDeployer.deployCanonicalPool`
reverts with `PoolAlreadyDeployed` on a second call
(`test_OneShotIsConsumedAfterGenesis`).

> Launch EOA gains no protocol authority (role-topology sweep: Safe-only on treasury; zero roles elsewhere)

**✓ Met.** `test/genesis/GenesisWiring.t.sol:test_FinalRoleTopologyIsSafeOnly`
and `GenesisAdversarial.t.sol`'s role-topology assertions. No role argument
exists anywhere in the constructor chain; `StrategicTreasury` grants both
roles only to `msg.sender` (`GenesisDeployer`, transiently); zero role is
asserted for the launch sender, the deployer post-renounce, the attacker,
and `address(0)`.

> `VuxPoolDeployer` consumed and ownerless (`owner() == address(0)`; `setFeeProtocol` unreachable)

**✓ Met.** `test/genesis/GenesisWiring.t.sol:test_OneShotIsConsumedAfterGenesis`
and `GenesisAdversarial.t.sol:test_ProtocolFeeAuthorityIsPermanentlyUnreachable`.
`VuxPoolDeployer.owner` (`src/v3core/VuxPoolDeployer.sol`) is a `constant
address(0)` — a property of the bytecode, not an unset slot; the second
deploy reverts for the attacker *and* for the real `GenesisDeployer`;
`setFeeProtocol` is unreachable for the attacker *and* for the operator Safe.

> Exact pool initialization price verified: `slot0.sqrtPriceX96 == sqrtP0X96`; ratio/cushion checks in recorded wei values (`BOOTSTRAP_OPENING ≤ P0×S0 − B0`)

**✓ Met.** `test/genesis/GenesisWiring.t.sol:test_PoolInitializedAtExactlySqrtP0X96`
and `…test_RecordedWeiRatioAndCushionHold`, plus the whole
`test/genesis/GenesisPriceEncoding.t.sol` suite (7 cases). `sqrtP0X96` is
computed by the deterministic off-chain encoder
(`tools/offchain/encode-sqrt-p0.mjs`, BigInt, floor at both steps, no
floating point) and reproduced independently by the Solidity path
(`Math.mulDiv` + `Math.sqrt`) — two implementations sharing no code, agreeing
exactly at `3543191142285914205917298257` (VUX-token0) and
`1771595571142957102963385194354` (WETH-token0). The cushion law is checked
by exact cross-multiplication on recorded wei, never re-derived from the
Q64.96 encoding, with two negatives
(`test_EconomicsNegative_OffRatioP0RevertsTheLaunch`,
`…OpeningBeyondTheCushionRevertsTheLaunch`) and a boundary control
(`test_Control_TheExactCushionBoundaryLaunches`) proving the law is `<=`
rather than "always fail".

> Callback authorization one-shot and exact-pool-bound during genesis POL provisioning (mint callback path exercised in-genesis)

**✓ Met.** `test/genesis/GenesisAdversarial.t.sol:test_GenesisPolCallbackWasExercisedAndLeftNoApproval`
and `…test_CallbackForgeryFromAHostilePoolIsRejected`. Genesis step 7 calls
the real `StrategicTreasury.mintPolPosition`, which arms the Sprint-5
transient one-shot context, calls the real pool `mint`, and consumes the
context before paying. A non-zero POL position after genesis *is* the proof
the callback ran and paid — v3 verifies payment as a within-operation
balance delta. All four allowance directions are asserted zero; forged
callbacks fail for every hostile pool, for an EOA, and for the canonical
pool called out of context.

> Production secrets remain outside repo/CI artifacts: rehearsal uses rehearsal values only; `broadcast/**` hygiene check green; launch-secret checklist per sdd.md:L270

**✓ Met.** `tools/provenance/verify-launch-hygiene.sh` — green, 371 files
scanned (tracked plus untracked-not-ignored, which matters because the
entire Sprint-7 subject is untracked). The two-transaction rehearsal
(`script/GenesisRehearsal.s.sol`) reads its key from `VUX_REHEARSAL_PK`,
contains no production EOA/nonce/salt/address/manifest/conversion value, and
its live broadcast run's artifact under `broadcast/` is confirmed invisible
to git via `git check-ignore`.

> Plus: mutated-extra-CREATE negative reverts the whole launch (nonce stability); commitment-gate negatives (wrong salt / wrong sender / second call); domain-violation negatives; `vux.balanceOf(deployer) == 0` and `weth.balanceOf(deployer) == 0` after sweep; POL position liquidity > 0 owned by treasury; `rig.king() == reserve`; S0 exact; gas/initcode headroom measured (sdd.md:L859-L860)

**✓ Met.** All named sub-proofs present:
`tools/genesis/demo-nonce-negative.sh` (a **source mutation** of
`src/GenesisDeployer.sol`, not a Solidity test double — green → red on
`PredictedAddressMismatch(3, …)` → restored, SHA-256 verified
byte-identical); commitment negatives with a positive control
(`GenesisWiring.t.sol:test_CommitmentNegative_*`,
`test_Control_TheSameFreshTx1LaunchesWithTheRightSalt`); five domain
negatives plus a valid-input acceptance
(`test_DomainNegatives_EachViolationIsRejectedAndValidInputIsAccepted`);
`test_CleanLaunchClosesWithZeroResidual` (deployer VUX/WETH/ETH all exactly
zero); `test_PolPositionIsRealAndOwnedByTheTreasury`;
`test_BootstrapKingIsTheReserve` (`rig.king() == reserve`);
`test_ExactGenesisSupplyAndReserveSeed` (`S0 = 150_000e18 + 1`); and
`test_InitcodeAndRuntimeHeadroom`, which measures the **launch
transaction's** init code — creation code plus the ABI-encoded
`GenesisParams` constructor arguments (448 bytes for the 14-field static
tuple) — at 48,057 B against the 49,152 B EIP-3860 ceiling, cross-checked
against the live broadcast rehearsal's recorded payload of identical size.

---

## Tasks Completed

### Task 7.1 — Q-6 evidence (operator HITL gate)

**Status:** Complete, operator-accepted.

Canonical Robinhood Chain WETH's native-wrap semantics verified on a real
fork (`test/fork/RhWethFork.t.sol`): `WETH.deposit{value: msg.value}()`
credits 1:1 **inside a constructor** and the credit is spendable in that same
constructor — the exact accepted funding topology
(`ConstructorWrapProbe`). Discrimination proven by two mock controls plus a
mutation that disables all three delta checks at once, isolating them as the
only thing separating real native-wrap semantics from a token that merely
accepts value. The narrow Sprint-5 WETH-transfer-callback carry was also
discharged: no recipient-controlled callback on the current deployed
transfer path, preserving (not fixing) the existing Sprint-5 LOW's
unreachability assessment.

Full record: `evidence/q6-native-wrap.md`, verbatim run
`evidence/q6-fork-run.txt`. Operator disposition:
`OPERATOR_ACCEPTANCE — SPRINT_7_Q6_NATIVE_WRAP_ACCEPTED`. The fallback
pre-approval funding topology was **not** implemented.

### Task 7.2 — `GenesisDeployer.sol` + off-chain price encoder

**Status:** Complete.
**Files:** `src/GenesisDeployer.sol` (new), `tools/offchain/encode-sqrt-p0.mjs` (new)

Constructor-executed genesis, steps 0–10 per the accepted order
(sdd.md:L158-L171): contamination snapshot + in-tx `WETH.deposit`; five
`CREATE`s (`HardReserve`, `Rig`, `VUX`, `StrategicTreasury`, `Lens`) with
`predict(n)`/actual equality checks; commitment-gated CREATE2 pool deploy +
`initialize` + full identity verification; POL provisioning through the real
authenticated mint callback; exact delta-verified `B0` transfer; Safe role
grant; renounce; classified sanitizing sweep (`residual == wethPreSelf +
sanitized` exactly); closing self-verification. No callable
post-deployment surface exists.

### Task 7.3 — Genesis wiring proof suite

**Status:** Complete. **28/28 passing.**
**File:** `test/genesis/GenesisWiring.t.sol` (new)

Predicted-vs-actual equality for every deployment and forward-reference
edge; independent CREATE2 recompute; commitment and parameter-domain
negatives with positive controls; exact `slot0`; recorded-wei ratio/cushion
with negatives and a boundary control; funding-exactness negatives; deployer
zero-balance closure; POL position ownership; exact supply; bootstrap King;
role-topology closure with a positive control; gas/initcode headroom.

### Task 7.4 — Full-knowledge adversarial rehearsal

**Status:** Complete. **12/12 passing.**
**File:** `test/genesis/GenesisAdversarial.t.sol` (new)

Every accepted adversarial class exercised: arbitrary prefunding of every
predicted address, a 1,000,000 ETH Reserve prefund, forced ETH, four real
hostile lookalike pools at every fee tier, salt extraction, guessed salts,
wrong-sender attempts (EOA and contract), premature one-shot consumption,
namespace-occupation attempts, mempool spam, and callback forgery. The
launch completed exact at every intended address with zero attacker credit
of any kind.

### Task 7.5 — Two-transaction launch rehearsal script

**Status:** Complete.
**File:** `script/GenesisRehearsal.s.sol` (new)

`simulate()` (in-EVM, no key or node) and `run()` (two genuine broadcast
transactions). `run()` was exercised against a local anvil forked from
Robinhood Chain, so it wraps the *real* canonical WETH while sending nothing
to a real network: tx1 (`VuxPoolDeployer`, 24,578 B initcode) then tx2
(`GenesisDeployer`, 48,057 B initcode, value 572.727272727272727272 ETH),
both status success, tx2 landing on the address tx1's commitment bound to.
Rehearsal values only; the rehearsal key is supplied via environment
variable and never written to a file.

### Task 7.6 — Genesis evidence pack

**Status:** Complete.
**File:** `evidence/genesis-evidence-pack.md` (new)

All twelve accepted launch-security obligations mapped to named
test/implementation/expected/actual rows, plus the additional
nonce/commitment/domain/balance/POL/supply/gas/initcode proofs, the
adversarial class table, the price-encoding record, and seven stated
residuals (R-1…R-7).

---

## Files Created / Modified

| File | Action | Description |
|---|---|---|
| `src/GenesisDeployer.sol` | Created | Constructor-executed genesis (Task 7.2) |
| `script/GenesisRehearsal.s.sol` | Created | Two-transaction rehearsal script (Task 7.5) |
| `test/fork/RhWethFork.t.sol` | Created | Q-6 fork gate + Sprint-5 carry (Task 7.1) |
| `test/genesis/GenesisFixture.sol` | Created | Real two-transaction launch fixture |
| `test/genesis/GenesisWiring.t.sol` | Created | Wiring proof suite, 28 tests (Task 7.3) |
| `test/genesis/GenesisAdversarial.t.sol` | Created | Adversarial rehearsal, 12 tests (Task 7.4) |
| `test/genesis/GenesisPriceEncoding.t.sol` | Created | Price-encoder proof, 7 tests |
| `tools/offchain/encode-sqrt-p0.mjs` | Created | Independent off-chain `sqrtP0X96` encoder |
| `tools/genesis/demo-nonce-negative.sh` | Created | Source-mutation nonce-stability negative |
| `test/harness/Vm.sol` | Modified — additive only | 5 new cheatcode declarations (`skip`, `envOr`×2, `envUint`, `broadcast`) |
| `test/mocks/MockWeth.sol` | Modified — additive only | `deposit()` mirroring Q-6's measured semantics |

No `src/` file other than the new `GenesisDeployer.sol` was touched. No
Sprint 1–6 test file was modified. No script/tool outside `tools/genesis/`
and `tools/offchain/` was touched.

---

## Residuals and Qualifications

Carried verbatim in scope from `evidence/genesis-evidence-pack.md` §10 — not
repeated in full detail here to avoid drift between the two documents;
summarized for the handoff:

- **R-1** — EIP-3860 headroom is 1,095 B (2.2%), measured and CI-guarded, not a defect.
- **R-2** — Robinhood Chain's own EIP-3860/block-gas semantics not independently characterised; Sprint-8 runbook item.
- **R-3** — The adversarial rehearsal's `Adversary`-account separation is a disclosed modelling choice.
- **R-4** — POL principal is asserted as a bound (`<=`), not an exact value, because v3 liquidity quantization makes exact equality wrong, not stronger.
- **R-5** — `MockWeth` gained an additive `deposit()` mirroring measured Q-6 semantics.
- **R-6** — Rehearsal Safe/fee-tier/tick-spacing are stand-ins; Q-3 remains untouched.
- **R-7** — Off-fork, the Q-6 suite reports `[SKIP]`, never a pass.

---

## Provenance and Scope Confirmation

No new external dependency, vendored file, package, or provenance surface
entered the tree. `vendor/`, `docs/authority/`, `foundry.toml`,
`package.json`, `package-lock.json`, `remappings.txt` — all unmodified.
`prd.md`, `sdd.md`, `sprint.md` — unmodified. No `UniswapV3Factory.sol`, no
v3-periphery import. No accepted Sprint 1–6 architecture or accounting
decision reopened. No operator-reserved value (Q-3 Safe composition,
production fee tier, founder conversion values, production nonce/salt) was
resolved. No Sprint-8 work performed.

---

## Terminal Report (as originally issued)

The implementation node's own terminal report at
`SPRINT_7_IMPLEMENTED_READY_FOR_REVIEW` stated the branch/baseline identity,
the Group A subject (11 files, fingerprint
`38bbdc88022762f61fd5172cb0218687e718478a91697bea647b9ae2de45312a`), the
twelve-obligation summary, the test/gate results, and the R-1…R-7 residuals
reproduced above. That report was delivered in the implementation node's own
chat output and was not, at the time, also written to this file — the defect
this restoration repairs.

---

*This implementation report was restored on 2026-08-18, after
`/review-sprint sprint-7` (`APPROVED`) and `/audit-sprint sprint-7`
(`APPROVED`, `COMPLETED`) had already run against the exact tree described
above. It supplies the durable native artifact the Sprint Plan requires and
was not consumed by, and could not have influenced, either completed gate.
No implementation byte was changed to produce it — the Group A fingerprint
above is unchanged from the fingerprint both the review and the audit
verified.*
