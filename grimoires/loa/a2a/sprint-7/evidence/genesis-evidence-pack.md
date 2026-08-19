# Sprint 7 — Genesis evidence pack

**Node:** `/implement sprint-7` · **Branch:** `sprint-7` · **Baseline:** `c58d41b8c77f3191114a5242c4bac9ff753f32dc`
**Tasks covered:** 7.1 (operator-accepted) · 7.2 · 7.3 · 7.4 · 7.5 · 7.6
**Status:** implementation complete, ready for independent review. No commit, no push, no review, no audit.

> **Purpose.** A reviewer must be able to check every accepted launch-security
> obligation without inferring which test proves which property. Every row below
> names the obligation, the implementation path that carries it, the exact test
> or script that exercises it, the expected result, and the observed one.
>
> **How to reproduce everything in this pack** — four commands:
>
> ```bash
> forge test                                                  # 444 passed / 0 failed / 10 skipped
> bash tools/provenance/run-all.sh                            # exit 0
> bash tools/genesis/demo-nonce-negative.sh                   # green -> red -> green
> forge script script/GenesisRehearsal.s.sol:GenesisRehearsal --sig "simulate()"
> ```
>
> The Q-6 fork run and the broadcast rehearsal need a node; their exact commands
> are in §7 and §8.

---

## 1. The twelve accepted launch-security obligations

| # | Obligation | Implementation | Evidence (test / artifact) | Expected | Actual |
|---|---|---|---|---|---|
| 1 | **Leaked future addresses cannot grief genesis** | `src/GenesisDeployer.sol` (whole constructor; every flow delta-verified) | `GenesisAdversarialTest.test_FullKnowledgeAdversaryCannotAlterOneWeiOfGenesis` | launch succeeds at the intended addresses with exact economics under total leakage | **PASS** — all seven addresses as predicted; `B0`, `S0`, seed, price all exact |
| 2 | **Hostile public-factory lookalike pools are irrelevant** | `StrategicTreasury` pool identity is a constructor immutable; no registry lookup exists anywhere | `GenesisAdversarialTest.test_HostileLookalikePoolsAtEveryFeeTierAreIrrelevant`, `…test_CallbackForgeryFromAHostilePoolIsRejected` | hostile pools at every tier, hostile init price, referenced nowhere; their callbacks rejected | **PASS** — 4 hostile pools (tiers 100/500/3000/10000), each `!= treasury.pool()`, protocol holds zero liquidity in each, every forged callback reverts |
| 3 | **Canonical CREATE2 pool identity is exact** | `GenesisDeployer._deriveCanonicalPool` + step-4 and step-10 verification against the accepted `POOL_INIT_CODE_HASH` | `GenesisWiringTest.test_CanonicalPoolCreate2IdentityIsExactEndToEnd`, `…test_PoolInitCodeHashConstantMatchesTheCompiledArtifact` | independent recompute == deployed pool == `treasury.POOL()` | **PASS** — the test derives from the *compiled artifact's* hash while the contract uses the *accepted constant*; the two independent derivations meet |
| 4 | **Arbitrary prefunding cannot alter genesis** | delta-verified flows; per-address defense table realised in steps 0/1/7/9 | `GenesisAdversarialTest.test_PrefundingEveryPredictedAddressLeavesGenesisExact`, `…test_ForcedNativeEthIsIrrelevantToEveryGenesisQuantity`, `…test_PrefundingTheCanonicalPoolAddressDoesNotBlockCreate2` | every predicted address prefunded (5,000 ETH each) + forced ETH; genesis exact | **PASS** — `B0` exact; VUX/Rig/Lens/pool-deployer donations provably stuck and still present; forced ETH neither wrapped nor read |
| 5 | **Very-large future-Reserve prefund is constructor-sanitized** | `HardReserve` constructor sanitization (init-code only) + `GenesisDeployer` step-9 classified sweep | `GenesisAdversarialTest.test_VeryLargeReservePrefundIsSanitizedAndReclassified`, `…test_NoSanitizationOrRecoveryAuthoritySurvivesIntoRuntime` | **1,000,000 ETH** prefund → born empty → `PreGenesisWethSanitized` → unattributed Strategic inventory; zero VEM credit; zero revenue | **PASS** — Reserve ends at exactly `B0`; both events emitted; `realizedRevenue[WETH] == 0`; supply unchanged; no runtime sweep/recovery path exists |
| 6 | **Exact physical `B0`, `N0`, `P0/N0`, first `B_pre`** | step 7 delta-verified `B0` transfer; step 10 `_verifyBootstrapEconomics` | `GenesisWiringTest.test_PhysicalB0AndTheDerivedBackingFacts`, `…test_FirstSettlementBPreIsExactlyB0`, `…test_RecordedWeiRatioAndCushionHold` | `WETH.balanceOf(reserve) == B0`; `P0/N0 == 1.10` on *live* state; `B_pre == B0` | **PASS** — ratio checked against the live balance and live supply, not against the recorded constants; `B_pre` read through the Lens |
| 7 | **No temporary authority survives** | step 8 grant → step 9 renounce → step 10 `_verifyRoleTopology` | `GenesisWiringTest.test_FinalRoleTopologyIsSafeOnly`, `…test_TheDeployerCannotExerciseTreasuryAuthorityAfterwards`, `…test_GenesisDeployerExposesOnlyReadOnlyGetters` | deployer holds nothing and can exercise nothing; no callable `genesis()` surface | **PASS** — renounce proven by a real reverted call, with the Safe succeeding on the same call as the control; the deployer's complete ABI is 13 read-only getters |
| 8 | **Launch EOA gains no protocol authority** | no role argument exists anywhere; treasury grants only to `msg.sender` (the deployer), transiently | `GenesisWiringTest.test_FinalRoleTopologyIsSafeOnly`, `GenesisAdversarialTest._assertAuthorityTopologyIntact` | launch sender holds no role, no VUX, no position | **PASS** — asserted for the launch sender, the deployer, the attacker, and `address(0)` |
| 9 | **`VuxPoolDeployer` consumed and ownerless** | one-shot latch + `owner()` is a `constant address(0)` | `GenesisWiringTest.test_OneShotIsConsumedAfterGenesis`, `GenesisAdversarialTest.test_SaltExtractionAndWrongSenderCannotConsumeTheOneShot`, `…test_ProtocolFeeAuthorityIsPermanentlyUnreachable` | second deploy reverts for everyone; `setFeeProtocol` unreachable | **PASS** — reverts for the attacker *and* for the real `GenesisDeployer`; `setFeeProtocol` unreachable for the attacker *and* for the operator Safe |
| 10 | **Exact pool initialization price and bootstrap cushion** | step 4 exact `slot0` equality; step 10 cushion check in recorded wei | `GenesisWiringTest.test_PoolInitializedAtExactlySqrtP0X96`, `…test_RecordedWeiRatioAndCushionHold`, `…test_EconomicsNegative_*`, whole `GenesisPriceEncodingTest` | `slot0.sqrtPriceX96 == sqrtP0X96` exactly; `BOOTSTRAP_OPENING <= P0*S0 - B0` | **PASS** — plus two negatives (off-ratio `P0`, opening beyond cushion) and a boundary control proving the law is `<=` and not "always fail" |
| 11 | **Genesis POL callback authorization exact and one-shot** | Sprint-5 transient context, exercised by the real genesis mint | `GenesisAdversarialTest.test_GenesisPolCallbackWasExercisedAndLeftNoApproval`, `…test_CallbackForgeryFromAHostilePoolIsRejected` | callback fired during genesis; no standing approval; forgeries revert | **PASS** — liquidity > 0 *is* the proof the callback paid (v3 verifies payment as a within-operation delta); all four allowances zero; even the canonical pool is rejected out of context |
| 12 | **Production secrets absent from repo and CI** | `.gitignore` `broadcast/**`; rehearsal key read from env; rehearsal values only | `tools/provenance/verify-launch-hygiene.sh` | all checks green; no key, mnemonic, or salt literal; no tracked broadcast artifact | **PASS** — 371 files scanned (tracked + untracked-not-ignored); the live broadcast rehearsal wrote to `broadcast/`, which `git check-ignore` confirms is invisible to git |

---

## 2. Additional accepted proofs (nonce, commitment, domain, balance, POL, supply, gas, initcode)

| Proof | Evidence | Expected | Actual |
|---|---|---|---|
| Predicted == actual, every deployment | `test_PredictedAddressesEqualActualForEveryDeployment` | nonces 1–5 exact | **PASS** — recomputed with `vm.computeCreateAddress`, a different implementation from the contract's RLP encoder; all six forward-reference edges also checked |
| Pool CREATE2 consumes no GenesisDeployer nonce | `test_PoolCreate2DoesNotConsumeAGenesisDeployerNonce` | treasury still at 4, Lens at 5, nonce 6 empty | **PASS** |
| **Mutated / extra CREATE reverts the whole launch** | `tools/genesis/demo-nonce-negative.sh` (source mutation) | revert on `PredictedAddressMismatch`, then restore byte-identical | **PASS** — green → red → green; `PredictedAddressMismatch(3, 0xA11d…Cd00, 0x5Fa3…3303)`; SHA-256 identical before and after |
| Commitment negatives | `test_CommitmentNegative_WrongSaltRevertsTheLaunch`, `…_RightSaltWrongSenderFails`, `test_Control_TheSameFreshTx1LaunchesWithTheRightSalt` | wrong salt and wrong sender both fail; right salt succeeds | **PASS** — with a positive control so the gate is not merely closed |
| Parameter-domain negatives | `test_DomainNegatives_EachViolationIsRejectedAndValidInputIsAccepted` | five distinct rejections + one acceptance | **PASS** — `zeroToken`, `tokenOrder`, `fee`, `tickSpacing` (0 and 16384), then a valid deploy |
| Funding must be exact | `test_FundingNegative_UnderAndOverFundingBothRevert` | `msg.value != wPol + b0` reverts both ways | **PASS** |
| Deployer zero VUX and zero WETH | `test_CleanLaunchClosesWithZeroResidual`, obligations 4/5 rows | exactly zero after the sweep | **PASS** — also zero ETH on the clean path |
| Contamination arithmetic | `GenesisDeployer._steps8to9…` requires `residual == wethPreSelf + sanitized` exactly | a leaked intended flow fails the identity | **PASS** — `contaminationSwept == 5,000 + 1,000,000 ETH` in the full-knowledge run |
| POL position exists and is the treasury's | `test_PolPositionIsRealAndOwnedByTheTreasury`, `test_PolProvisioningConsumedTheGenesisAllocation` | liquidity > 0, owned by treasury, nobody else | **PASS** — deployer, launch sender, Safe and attacker all hold zero |
| Exact genesis supply | `test_ExactGenesisSupplyAndReserveSeed`, `test_NoDiscretionaryFounderOrTeamVuxExists` | `S0 = 150_000e18 + 1`; zero discretionary VUX | **PASS** — every unit accounted for as POL-side or the Reserve seed |
| Bootstrap King | `test_BootstrapKingIsTheReserve` | `rig.king() == reserve`, `epochUPS == 0` | **PASS** |
| Immutable core has no role surface | `test_ImmutableCoreHasNoRoleSurface` | no `hasRole`/`owner()` on VUX/Rig/Reserve/Lens | **PASS** — `VuxPoolDeployer.owner()` exists deliberately and is dead, which is the property, not its absence |
| Deterministic price encoder | `GenesisPriceEncodingTest` (7 cases) | Solidity encoder == independent BigInt encoder; floor at both steps | **PASS** — see §5 |
| Gas and initcode headroom | `test_InitcodeAndRuntimeHeadroom` + the broadcast rehearsal | fits EIP-3860 / EIP-170 | **PASS**, but **tight** — see §6 |
| Two-transaction rehearsal integrity | `script/GenesisRehearsal.s.sol` | tx1 then tx2, exact economics | **PASS** — see §8 |
| Launch-secret hygiene | `verify-launch-hygiene.sh` | green | **PASS** |

---

## 3. What was built (Task 7.2)

`src/GenesisDeployer.sol` — 1 contract, constructor-executed genesis, **no callable
post-deployment surface**. Its complete ABI is thirteen read-only getters
(`POOL_INIT_CODE_HASH`, the eight system addresses, `operatorSafe`, and the three
contamination figures) — asserted exhaustively, not claimed.

Constructor steps, in the accepted order (sdd.md:L158-L171):

| Step | What | Verification in the same transaction |
|---|---|---|
| 0 | contamination snapshot + `WETH.deposit{value: msg.value}()` | wrap delta `== msg.value` exactly |
| 1 | `HardReserve` (nonce 1) | born empty; sanitized amount measured as a delta |
| 2 | `Rig` (nonce 2) | — (its forward edges verified at step 3/5) |
| 3 | `VUX` (nonce 3) | `address(vux) == predict(3)` |
| 4 | commitment-gated CREATE2 pool + `initialize` | derived address, `factory()`, `owner()==0`, token order, fee, tickSpacing, `slot0 == sqrtP0X96` — all exact |
| 5 | `StrategicTreasury` (nonce 4) | `== predict(4)` (which also proves the pool consumed no nonce) |
| 6 | `Lens` (nonce 5) | — |
| 7 | POL provisioning through the authenticated callback + exact `B0` | `B0` delta-verified |
| 8 | grant both roles to the operator Safe | — |
| 9 | renounce both; sanitizing sweep | `residual == wethPreSelf + sanitized` exactly, then `balanceOf(this) == 0` |
| 10 | closing self-verification | supply, seed, zero balances, physical `B0`, ratio, cushion, pool identity, POL liquidity, one-shot consumed, `king == reserve`, role topology |

**Genesis funding law preserved:** founder capital enters *only* as native value
wrapped in-transaction. The rejected pre-approval flow was **not** restored — Q-6
passed and the operator did not activate the fallback. Only `msg.value` is
wrapped (never `address(this).balance`), so forced ETH stays unread.

**No founder runtime authority was introduced.** No `genesis()`, no setter, no
initializer, no proxy, no `selfdestruct`, no `delegatecall`.

---

## 4. Adversarial rehearsal (Task 7.4) — what the adversary was given

Every class below fires **between tx1 and tx2**, with the attacker knowing all
seven future addresses, the pool address, token ordering, fee/tick configuration,
the init-code hash, and **the commitment salt itself**.

| Attack class | How it was exercised | Outcome |
|---|---|---|
| all future addresses known | derived and used throughout | no effect |
| arbitrary WETH prefunding | 5,000 ETH to each of 9 addresses | classified, never credited |
| very-large Reserve prefund | **1,000,000 ETH** | sanitized; Reserve born empty; ends at exactly `B0` |
| forced native ETH | `selfdestruct` push to 7 addresses | unread by every genesis quantity |
| hostile lookalike pools | real pinned v3 pools at **all four** fee tiers, from attacker-owned factories-of-one, hostile init price | referenced nowhere |
| hostile initialization | attacker-chosen price on each lookalike | irrelevant |
| salt extraction | real salt from an EOA | `BadCommitment` |
| guessed salt | arbitrary salt | `BadCommitment` |
| wrong sender, right salt | EOA **and** an attacker-controlled contract | `BadCommitment` |
| premature one-shot consumption | four attempts, varied parameters | all fail; genesis still consumes it |
| namespace occupation | attacker CREATE2 with identical salt and identical init code, from their own deployer | lands elsewhere; canonical slot still empty |
| mempool spam / racing | repeated wraps, transfers and failed gate calls | no shared state to race |
| callback forgery | from every hostile pool, from the canonical pool out of context, from an EOA | all revert |

**Result:** the launch completed at the intended addresses with exact economics.
No attacker-controlled balance received VEM mint credit, founder-capital
classification, realized-revenue classification, or protocol authority.

Two modelling decisions worth a reviewer's attention, both deliberate:

- **The adversary is a separate account** (`Adversary` contract). Attacker
  `CREATE`s must not spend the *launch* account's nonce — that is a capability no
  real attacker has, and letting it happen would break the tx1 commitment for
  reasons unrelated to security. The first draft did exactly that; it is fixed.
- **Impersonating `predictedGenesis` is deliberately not attempted.** No key and
  no code exist at that address, so `msg.sender` cannot be it. Forging it with a
  cheatcode would test the cheatcode, not the gate. The gate is instead attacked
  from every identity an adversary can actually hold.

---

## 5. Deterministic price encoding

Rule (sdd.md:L185): orientation is token1-per-token0; `sqrtP0X96 = isqrt((n <<
192) / d)`, **floor at both steps**. No floating point in the authoritative
encoder — `tools/offchain/encode-sqrt-p0.mjs` is BigInt throughout, and the
Solidity path uses `Math.mulDiv` + `Math.sqrt`.

Recorded rehearsal inputs (rehearsal values only; the production record is an
R-14 founder fact):

| Quantity | Exact wei |
|---|---|
| `S0` | `150000000000000000000001` |
| `B0` | `272727272727272727272` |
| `P0` as `n/d` | `2999999999999999999992 / 1500000000000000000000010` |
| `sqrtP0X96` (VUX is token0) | `3543191142285914205917298257` |
| `sqrtP0X96` (WETH is token0) | `1771595571142957102963385194354` |

Independent recomputation: `node tools/offchain/encode-sqrt-p0.mjs --rehearsal`
produces both constants; `GenesisPriceEncodingTest` asserts the Solidity encoder
reproduces them exactly. The two implementations share no code.

**Quantization delta**, stated as the exact integer property rather than a
tolerance: with `x = mulDiv(n, 2^192, d)`, the encoder returns the largest `r`
with `r² <= x`, and `(r+1)² > x`. That *is* the "< 1 ulp" claim — `r² <= x` says
the encoding never overstates the price, `(r+1)² > x` says it is never more than
one representable step below it. Both asserted, both orientations. A reciprocity
check catches the single most plausible encoder error (a transposed orientation),
with a tolerance derived from the floor error rather than guessed.

The pool stores the supplied value verbatim, so the post-initialize check is
**exact equality**, and the ratio/cushion laws are verified in exact wei on the
recorded values — never re-derived from the Q64.96 encoding.

---

## 6. Gas and initcode headroom — **measured, and tight**

| Measurement | Value | Limit | Headroom |
|---|---|---|---|
| `GenesisDeployer` creation code | 47,609 B | — | — |
| ABI-encoded constructor args (`GenesisParams`, 14 static words) | 448 B | — | — |
| **Launch transaction init code** | **48,057 B** | **49,152 B** (EIP-3860) | **1,095 B (2.2%)** |
| `GenesisDeployer` runtime | 1,070 B | 24,576 B (EIP-170) | 23,506 B |
| tx1 gas used | 5,311,024 | — | — |
| **tx2 (genesis) gas used** | **12,675,925** | — | — |

The 48,057 B figure is the **as-broadcast** payload from the live rehearsal, not
an estimate: measuring the artifact alone would overstate headroom by the 448
bytes of constructor arguments. The five embedded creation codes account for
36,585 B of it (`StrategicTreasury` alone is 20,131 B).

**This is a genuine residual, carried forward** — see §10 R-1.

---

## 7. Task 7.1 — Q-6, operator-accepted

Fully recorded in [`q6-native-wrap.md`](q6-native-wrap.md) with the verbatim run
in [`q6-fork-run.txt`](q6-fork-run.txt). Summary: canonical RH WETH
(`0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73`, chain 4663) wraps native value 1:1
**inside a constructor** and the credit is spendable in that same constructor; no
approval or pre-funding required. Operator accepted; the fallback pre-approval
topology was **not** implemented.

Sprint-5 carry, dispositioned narrowly by the operator: current `transfer` and
`transferFrom` invoke no recipient-controlled callback. This preserves the
existing unreachability assessment of the accepted Sprint-5 LOW; it does **not**
mean the underlying reentrancy window was fixed, and no Sprint-5 code was
touched.

**Q-6 evidence was re-established, not inherited.** Tasks 7.2–7.6 touched the
Q-6 suite's bytes (`forge fmt` reformatting) and its harness
(`test/harness/Vm.sol` gained two additive cheatcode declarations, `envUint` and
`broadcast`, used only by the rehearsal script). The whole suite was therefore
re-run on a fresh fork — **block 39130641**, hash
`0x662b5a64a30484e22a08db30fb3ed5c0517c49ad1077c2965b3776edd98da304` — and
returned **10/10 PASS, unchanged**. `q6-fork-run.txt` holds that re-run.
Off-fork the suite reports 10 `[SKIP]`, never a pass.

---

## 8. Task 7.5 — two-transaction rehearsal

Two entry points in `script/GenesisRehearsal.s.sol`:

- `simulate()` — in-EVM choreography, no key, no node. **Ran successfully**,
  gas 32,569,364.
- `run()` — two genuine broadcast transactions from a rehearsal EOA.

The broadcast rehearsal was run against a **local anvil forked from Robinhood
Chain**, so it exercises the *real* canonical WETH while sending nothing to a
real network:

```bash
anvil --fork-url https://rpc.mainnet.chain.robinhood.com --fork-block-number 39120939 --port 8545
VUX_REHEARSAL_PK=<throwaway anvil dev key> \
VUX_REHEARSAL_WETH=0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73 \
forge script script/GenesisRehearsal.s.sol:GenesisRehearsal --rpc-url http://127.0.0.1:8545 --broadcast
```

| | tx1 | tx2 |
|---|---|---|
| type | CREATE (`VuxPoolDeployer`) | CREATE (`GenesisDeployer`) |
| nonce | 256 | 257 |
| value | 0 | 572,727,272,727,272,727,272 wei |
| init code | 24,578 B | 48,057 B |
| gas used | 5,311,024 | 12,675,925 |
| status | success | success |
| block | 39,120,940 | 39,120,941 |

`ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`, and tx2 landed on the address the tx1
commitment bound to.

**Rehearsal values only.** No production launch EOA, key, nonce plan, salt,
predicted address, manifest, conversion value, or private-builder configuration
appears anywhere. The key was supplied through the environment and never written
to a file. `broadcast/` is gitignored — `git check-ignore` confirms the artifact
this run produced is invisible to git.

---

## 9. Accumulated verification

| Gate | Result |
|---|---|
| `forge test` (whole accumulated suite) | **444 passed / 0 failed / 10 skipped** (baseline 397 + 47 new genesis cases; the 10 skips are the fork suite off-fork) |
| Genesis wiring suite | 28/28 |
| Adversarial rehearsal | 12/12 |
| Price encoding | 7/7 |
| Q-6 fork suite (on-fork) | 10/10 |
| `tools/provenance/run-all.sh` | **exit 0** — all 8 gates green |
| `verify-launch-hygiene.sh` | green, 371 files scanned |
| `verify-init-code-hash.sh` | `POOL_INIT_CODE_HASH` reproduced |
| Vendored census | 63/63 byte-identical |
| Nonce-stability mutation demo | green → red → green, source restored byte-identical |

**No new external dependency, vendored file, package, or provenance surface
entered the tree.** `vendor/` and `docs/authority/` untouched. No v3-periphery.
No `UniswapV3Factory.sol`.

---

## 10. Residuals and qualifications

Stated without inflation and without concealment.

**R-1 — EIP-3860 headroom is 1,095 bytes (2.2%).** The launch transaction is
48,057 B against a 49,152 B ceiling. Any material growth in `VUX`, `Rig`,
`HardReserve`, `StrategicTreasury`, or `Lens` pushes genesis over the limit and
the launch becomes unsendable. `test_InitcodeAndRuntimeHeadroom` now fails in CI
if that happens, so the failure mode is a red test rather than a dead launch —
but the margin is thin and the operator should know it. Levers if it ever binds,
none of which are exercised here: enabling/tuning the optimizer for the
`=0.8.28` unit (currently `optimizer = true` with `optimizer_runs` unset, i.e.
solc's default 200 — a bytecode-affecting change to every VUX contract, and a
Sprint-8 deployment-freeze decision), or splitting a contract out of the
constructor. **Not a defect; a measured constraint.**

**R-2 — Robinhood Chain is an Arbitrum Orbit chain and its gas/size semantics
were not independently characterised.** The 48,057 B / 12.68 M gas figures come
from an anvil fork, which applies stock EVM rules. Whether RH applies the same
EIP-3860 ceiling and the same block gas limit is an R-14 deployment fact. The
rehearsal establishes that the launch works under stock rules; confirming RH's
own limits belongs in the Sprint-8 runbook.

**R-3 — The `Adversary`-account separation is a modelling choice, stated so a
reviewer can disagree with it.** Attacker `CREATE`s are performed from a distinct
account so they cannot consume the launch account's nonce. This is faithful (no
real attacker can spend the founder's nonce), but it is a choice, and a reviewer
should confirm it does not hide a nonce-fragility class. The `predict(4)` check
plus the source-mutation demo are the direct evidence that the nonce plan is
verified in-transaction regardless.

**R-4 — Quantization dust is asserted by bound, not by exact value.** `v3`
rounds liquidity into whole units, so the pool takes slightly less than the
offered legs (observed: 364 wei of WETH). The tests assert POL principal never
*exceeds* the founder legs and the shortfall is dust. The exceed-bound is the
load-bearing half — a donation booked as principal is exactly what exceeding
would look like — but the dust bound itself (`< 1e12` wei) is a threshold, not an
exact figure.

**R-5 — `MockWeth` gained a `deposit()`.** Additive only, and its semantics
mirror what Q-6 *measured* on the real canonical WETH rather than a guess. The
genesis suites need a wrapped-native token; using the existing mock keeps the
genesis and accumulated suites on one WETH.

**R-6 — Rehearsal Safe, fee tier, and tick spacing are stand-ins.** Q-3
(production Safe signer set and threshold) is untouched and remains a Sprint-8
runbook input. `feeTier = 3000` / `tickSpacing = 60` are rehearsal figures,
domain-checked by `VuxPoolDeployer` and value-frozen nowhere.

**R-7 — Off-fork, the Q-6 suite reports `[SKIP]`, never a pass.** A green default
`forge test` claims nothing about Q-6. The only Q-6 verdict is the recorded fork
run. The public RH RPC's ~10-minute state-retention window (measured in Task 7.1)
is unchanged and does not invalidate the accepted evidence.

### Open review questions

1. **§10 R-1** — is 2.2% initcode headroom acceptable to carry into Sprint 8, or
   should the `=0.8.28` optimizer settings be revisited at the deployment freeze?
2. **§10 R-2** — should the Sprint-8 runbook require RH-chain confirmation of the
   EIP-3860 ceiling and block gas limit as an explicit pre-launch input?
3. **§4** — is the `Adversary`-account separation the right model, or does a
   reviewer want an additional class where the launch account itself is
   perturbed between tx1 and tx2?
