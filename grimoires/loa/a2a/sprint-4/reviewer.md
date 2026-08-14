# Sprint 4 — Strategic Treasury I: Custody, Classification & Authority Boundaries

**Node:** `/implement sprint-4` (cycle-002, global sprint 4)
**Branch:** `sprint-4`, from the landed baseline `84abced4f90b9b8d11d960ebb438125b84914272`
**Subject fingerprint:** `72896e9d80d16b229a78e19f8f51c4ed117f622423970bdb491b7d0575d3966b` (24 files)
**Terminal state:** `SPRINT_4_IMPLEMENTED`
**Next:** `/review-sprint sprint-4`

---

## 1. Executive Summary

Tasks 4.1–4.9 are complete. The sprint ships the role-gated Strategic Treasury, its arithmetic
classification engine, the `VuxPoolDeployer` genesis primitive, and the inactive P0 LSG
boundary — plus the property, invariant, and failure-behaviour evidence the accepted plan
requires.

The central claim is negative and is carried by structure rather than by policy: **there is no
path from any Strategic surface to the monetary core.** The treasury holds no reference to a
privileged Reserve/Rig/VUX function — none exist to hold — and its compilation unit does not
even contain the *declarations* of `HardReserve.redeem`, `VUX.mint`, or
`VUX.burnForRedemption`. A 50%, 80%, or 100% Strategic loss leaves `B`, `S`, the redemption
quote, the four VEM inputs, and the three authority edges bit-identical.

The second claim is arithmetic: **principal and marks cannot become distributable revenue.**
Every revenue credit is a measured balance delta passed through a mechanical guard. There is no
`declareProfit`, no revenue setter, no oracle, and no mark or NAV cell anywhere in the contract.

| metric | result |
|---|---|
| Tests | **298 passed / 0 failed** (baseline was 144; **+154** this sprint) |
| CI depth | **298/298** under `FOUNDRY_PROFILE=ci` — fuzz 10,000 runs, invariants 256 × 64 = **16,384 calls, 0 reverts** |
| Accounting property fuzz | 9 properties × **10,000 runs each**, covering all three modes (success metric: ≥10,000 per mode) |
| Provenance gates | **8/8 green**, `POOL_INIT_CODE_HASH` reproduced byte-identical |
| Treasury mutators with an unauthorized-caller negative | **13/13** (100%, success metric) |
| Stored policy-ratio constants | **0** (mechanical, closed-world ABI enumeration) |
| Commits / pushes / merges | **none** — tree left uncommitted for exact-tree review |

---

## AC Verification

### AC-1

> Treasury constructor re-verifies `POOL.factory() == VUX_POOL_DEPLOYER`, `IUniswapV3Factory(VUX_POOL_DEPLOYER).owner() == address(0)`, token ordering/fee, and derives tick bounds from `pool.tickSpacing()`; roles granted to `msg.sender` (creator); no `setPool`/initializer exists (sdd.md:L140, L718-L725)

**Status:** ✓ Met
**Evidence:** `src/StrategicTreasury.sol:323` (`factory()` check), `src/StrategicTreasury.sol:326`
(`owner() == address(0)`), `src/StrategicTreasury.sol:331` (token ordering),
`src/StrategicTreasury.sol:334` (fee), `src/StrategicTreasury.sol:349` (tick bounds derived from
`pool.tickSpacing()`), `src/StrategicTreasury.sol:352` (both roles to `msg.sender`).
Verified against a **real** pool by `test/treasury/TreasuryConstructor.t.sol:26`,
`test/treasury/TreasuryConstructor.t.sol:53` (bounds aligned and inside the tick domain),
`test/treasury/TreasuryConstructor.t.sol:65` (bounds follow a *different* spacing, so they are
derived and not hard-coded), `test/treasury/TreasuryConstructor.t.sol:85` (roles), and the five
rejections at `test/treasury/TreasuryConstructor.t.sol:132`, `:144`, `:157`, `:167`, `:185`,
plus the zero-address guard at `test/treasury/TreasuryConstructor.t.sol:196`.
`setPool`/initializer absence is closed-world at `test/treasury/TreasurySurface.t.sol:93` and
named explicitly at `test/treasury/TreasurySurface.t.sol:109`.

### AC-2

> Admission: `mode` fixed at admission and immutable (change = remove + re-admit + re-delay); deployment blocked until `maturesAt` (`AdmissionNotMatured`); removal/recall always instant and unblockable (sdd.md:L147)

**Status:** ✓ Met
**Evidence:** `src/StrategicTreasury.sol:390` (mode immutability, plus the unit-ledger condition
on a post-removal mode change at `src/StrategicTreasury.sol:391`),
`src/StrategicTreasury.sol:400` (`ADMISSION_DELAY` maturity stamped per `admitStrategy`),
`src/StrategicTreasury.sol:416` (removal is a single flag write),
`src/StrategicTreasury.sol:440` (recall is deliberately not admission-gated).
Tests: `test/treasury/TreasuryAdmission.t.sol:75` (`AdmissionNotMatured`),
`test/treasury/TreasuryAdmission.t.sol:88` (the maturity boundary is exact at ±1 s),
`test/treasury/TreasuryAdmission.t.sol:105` (re-admission restarts the delay),
`test/treasury/TreasuryAdmission.t.sol:120` and `test/treasury/TreasuryAdmission.t.sol:132`
(mode immutable while admitted; change only via remove + re-admit + re-delay),
`test/treasury/TreasuryAdmission.t.sol:147` (stale units block a mode change),
`test/treasury/TreasuryAdmission.t.sol:221` (removal instant),
`test/treasury/TreasuryAdmission.t.sol:238` (recall works after removal),
`test/treasury/TreasuryAdmission.t.sol:253` (an active LSG module cannot block either).

### AC-3

> Accounting properties ∀ flow sequences ∀ modes (sdd.md:L856): Σ revenue distributions ≤ realized-revenue credits; returned principal never credits revenue; arbitrary-asset returns rejected (`UnknownReturnAsset`); NETTING revenue only beyond full return; CLAIM harvest with decreased `principalUnits` reverts; UNITIZED basis release conserves (Σ `basisReleased` = original basis over full unwind), gain→revenue / shortfall→loss never negative revenue; `closeStrategy` write-off only reduces principal

**Status:** ✓ Met
**Evidence:** each clause, in order —
Σ ≤ credits: `test/treasury/TreasuryAccountingProperties.t.sol:90` (10,000 runs);
returned principal never revenue: `test/treasury/TreasuryFlows.t.sol:85`;
arbitrary-asset rejected: `test/treasury/TreasuryAccountingProperties.t.sol:220` (all modes,
10,000 runs) and `test/treasury/TreasuryFlows.t.sol:98`;
NETTING beyond full return: `test/treasury/TreasuryAccountingProperties.t.sol:55` (10,000 runs)
and the boundary case at `test/treasury/TreasuryFlows.t.sol:48`;
CLAIM units-intact: `test/treasury/TreasuryAccountingProperties.t.sol:116` (10,000 runs) and
`test/treasury/TreasuryFlows.t.sol:210`;
UNITIZED conservation: `test/treasury/TreasuryAccountingProperties.t.sol:160` (10,000 runs) and
`test/treasury/TreasuryFlows.t.sol:346`;
gain→revenue / shortfall→loss: `test/treasury/TreasuryAccountingProperties.t.sol:192` (10,000
runs), `test/treasury/TreasuryFlows.t.sol:297` and `test/treasury/TreasuryFlows.t.sol:315`;
`closeStrategy` reduces only: `test/treasury/TreasuryAccountingProperties.t.sol:238` (10,000
runs) and `test/treasury/TreasuryFlows.t.sol:403`.
Implementation: `src/StrategicTreasury.sol:861` (`_classifyReturn`, the single classification
point), `src/StrategicTreasury.sol:499` (`harvestYield`), `src/StrategicTreasury.sol:549`
(`redeemUnits`), `src/StrategicTreasury.sol:597` (`closeStrategy`).

### AC-4

> `allocateRevenue` negatives: `asset == VUX` rejected (`VuxRevenueMustBurn`); non-WETH Hard leg rejected (`HardLegMustBeWeth`); over-accumulator rejected (`RevenueExceedsRealized`); ABI assertion: exactly four legs — no `toMarketInfra` parameter and no `marketInfraBudget` symbol exists (2026-08-12 remediation) — FR-12 negative acceptance "no configuration of the policy surface can reach Reserve principal or mint" (prd.md:L505-L506)

**Status:** ✓ Met
**Evidence:** `src/StrategicTreasury.sol:655` (`VuxRevenueMustBurn`),
`src/StrategicTreasury.sol:656` (`HardLegMustBeWeth`), `src/StrategicTreasury.sol:660`
(`RevenueExceedsRealized`).
Tests: `test/treasury/TreasuryRevenue.t.sol:241` (VUX rejected, including an all-zero call),
`test/treasury/TreasuryRevenue.t.sol:127` (non-WETH Hard leg),
`test/treasury/TreasuryRevenue.t.sol:51` (over-accumulator, at the exact boundary),
`test/treasury/TreasuryRevenue.t.sol:68` (zero revenue ⇒ all four legs revert).
ABI assertion: `test/treasury/TreasurySurface.t.sol:151` (four-leg selector present, five-leg
absent, exactly one overload) and `test/treasury/TreasurySurface.t.sol:172` (`marketInfraBudget`
absent as a getter **and** as a selector in the deployed runtime image, with the live earmark's
selector as the positive control).
FR-12 negative acceptance: `test/treasury/TreasuryRevenue.t.sol:287`.

### AC-5

> Percentages are call-time arguments only — grep-verified no stored ratio constant exists (R-9 execution-reserved; waterfall ratios are founder-accepted doctrine, never operator-set; §17 quarantine)

**Status:** ✓ Met
**Evidence:** `src/StrategicTreasury.sol:650` — `allocateRevenue` takes four `uint256` amounts and
the contract stores no ratio anywhere.
Mechanical: `test/treasury/TreasurySurface.t.sol:194` (ten ratio-shaped getters asserted absent)
plus `test/treasury/TreasurySurface.t.sol:93`, whose closed-world enumeration means a ratio
constant cannot be added later without failing; `tools/provenance/verify-quarantine.sh` passes
10/10 §17 patterns over `src test script tools .github foundry.toml`.
Full row-by-row sweep in `grimoires/loa/a2a/sprint-4/evidence/r1-r14-reservation-sweep.md:1`.

### AC-6

> LSG P0: launch state inactive (`lsgModule == address(0)`); `activateLSG`/`deactivateLSG` operator-gated + evented; no numeric threshold or calendar in code (F-50); signal surfaces revert `LSGInactive` before activation; INV-32…34 negatives green (prd.md:L522-L524)

**Status:** ✓ Met
**Evidence:** `src/StrategicTreasury.sol:204` (the slot, launch value `address(0)`),
`src/StrategicTreasury.sol:706` and `src/StrategicTreasury.sol:714` (`activateLSG` /
`deactivateLSG`, `OPERATOR_ROLE`, evented), `src/interfaces/ILSGModule.sol:33` (signal-only
interface — one `view`).
Tests: `test/treasury/TreasuryConstructor.t.sol:219` (launch state),
`test/treasury/TreasuryLsgBoundary.t.sol:61` (affirmative, ungated activation),
`test/treasury/TreasuryLsgBoundary.t.sol:75` (time alone never activates — the F-50 complement),
`test/treasury/TreasuryLsgBoundary.t.sol:117` (fail-closed signal surfaces),
INV-32 at `test/treasury/TreasuryLsgBoundary.t.sol:178`, INV-33 at
`test/treasury/TreasuryLsgBoundary.t.sol:208` (core state asserted bit-identical after a signal
that names the Reserve, Rig, and token), INV-34 at `test/treasury/TreasuryLsgBoundary.t.sol:61`
and `test/treasury/TreasuryLsgBoundary.t.sol:75`. No P1 mechanism ships:
`test/treasury/TreasurySurface.t.sol:243`.

### AC-7

> FB-5: simulated 50%/80%/100% Strategic loss leaves `B`, redemption, VEM, and mint authority **bit-identical** (prd.md:L444)

**Status:** ✓ Met
**Evidence:** `test/treasury/TreasuryFailureBehaviors.t.sol:72` (the shared assertion),
`test/treasury/TreasuryFailureBehaviors.t.sol:94`, `:98`, `:102` (the three loss magnitudes).
The comparison covers twelve values — `B`, `S`, the redemption quote at two sizes, King, price,
`currentUPS`, `epochUPS`, `epochStart`, `epochId`, and the three authority edges — captured by
`test/treasury/TreasuryFixture.sol:172` and compared field-by-field at
`test/treasury/TreasuryFixture.sol:189`.
Sharpened at `test/treasury/TreasuryFailureBehaviors.t.sol:111`: the settlement *after* a total
loss reads exactly the untouched `B_pre` and `S_pre` and still caps issuance at `Qsafe`.
Complemented by `test/treasury/TreasuryFailureBehaviors.t.sol:154` (no rescue path exists) and by
`test/treasury/TreasuryInvariants.t.sol:70`, which holds the same identity across randomized
sequences that include total strategy loss.

### AC-8

> Role topology: operator roles exist on `StrategicTreasury` only; negative tests prove no treasury call path reaches Reserve principal, redemption math, mint authority, or routing constants (NFR-SEC-7; INV-33)

**Status:** ✓ Met
**Evidence:** `test/treasury/TreasuryConstructor.t.sol:85` (roles held only by the creator; the
Rig, Reserve, token, and zero address hold none), `test/treasury/TreasuryConstructor.t.sol:120`
(no core contract even answers `hasRole`), `test/treasury/TreasuryInvariants.t.sol:108` (asserted
between every pair of operations, including for an active LSG module).
No-path negatives: `test/treasury/TreasuryFailureBehaviors.t.sol:181` (the treasury's own
identity is refused by `NotRig()` and `NotReserve()`),
`test/treasury/TreasuryFailureBehaviors.t.sol:201` (the treasury's compilation unit contains no
declaration of `HardReserve.redeem`, `VUX.mint`, or `VUX.burnForRedemption`),
`test/treasury/TreasuryFailureBehaviors.t.sol:236` (no core selector is emitted as an outbound
call — shift-robust, with two positive controls),
`test/treasury/TreasuryInvariants.t.sol:94` (routing constants never move).
Unauthorized-caller negatives cover **all 13** treasury mutators:
`test/treasury/TreasuryAdmission.t.sol:281` (4), `test/treasury/TreasuryFlows.t.sol:451` (2),
`test/treasury/TreasuryRevenue.t.sol:359` (3), `test/treasury/TreasuryLsgBoundary.t.sol:125` (4).

### AC-9

> `VuxPoolDeployer` unit tests: wrong salt reverts, wrong `msg.sender` with correct salt reverts, second call reverts, domain violations each revert, deployed pool address equals independent `create2(deployer, keccak256(abi.encode(token0,token1,fee)), POOL_INIT_CODE_HASH)` recompute (sdd.md:L859)

**Status:** ✓ Met
**Evidence:** `test/treasury/VuxPoolDeployer.t.sol:109` (wrong salt),
`test/treasury/VuxPoolDeployer.t.sol:118` (correct salt, wrong `msg.sender`) plus its complement
at `test/treasury/VuxPoolDeployer.t.sol:127`, `test/treasury/VuxPoolDeployer.t.sol:152` and
`test/treasury/VuxPoolDeployer.t.sol:164` (second call, same pair and a different pair), and the
eight domain violations one at a time at `test/treasury/VuxPoolDeployer.t.sol:176`, `:182`,
`:188`, `:196`, `:202`, `:208`, `:214`, `:220`, with the legal edges accepted at
`test/treasury/VuxPoolDeployer.t.sol:229`.
Independent recompute: `test/treasury/PoolDeployerHarness.sol:63` derives the address from
`keccak256(pool creation code)` read out of `out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json`
rather than from the accepted constant, so this test and
`test/provenance/PoolInitCodeHash.t.sol:31` close the loop without either assuming the other's
conclusion. Asserted at `test/treasury/VuxPoolDeployer.t.sol:47` and again on the treasury's
bound pool at `test/treasury/TreasuryConstructor.t.sol:41`.
Implementation: `src/v3core/VuxPoolDeployer.sol:101`.

---

## 2. Tasks Completed

| task | deliverable | files | tests |
|---|---|---|---|
| **4.1** | `VuxPoolDeployer.sol` — canonical CREATE2 deployment, salted `msg.sender`-binding commitment gate, one-shot latch, Finding-4 domain checks, permanently dead `owner()` | `src/v3core/VuxPoolDeployer.sol` (117 L), `foundry.toml` | `VuxPoolDeployer.t.sol` (20) |
| **4.2** | Treasury skeleton — constructor immutables + real-pool re-verification, creator-granted roles, the complete accounting-cell set, classification events | `src/StrategicTreasury.sol`, `src/interfaces/IVUXBurnable.sol` | `TreasuryConstructor.t.sol` (14), `TreasurySurface.t.sol` (7) |
| **4.3** | Admission registry — immutable mode, `ADMISSION_DELAY = 24 h`, instant removal, per-(strategy, asset) caps, `deployToStrategy`/`recallFromStrategy` | `src/StrategicTreasury.sol` | `TreasuryAdmission.t.sol` (21) |
| **4.4** | Flow primitives — `returnFor` (principal-first netting, in-call), `harvestYield` (measured deltas + units-intact), `redeemUnits` (ceil basis release, gain/shortfall), `closeStrategy` (loss-only write-off) | `src/StrategicTreasury.sol`, `src/interfaces/IStrategyAdapter.sol` | `TreasuryFlows.t.sol` (27) |
| **4.5** | Distribution surface — four-leg `allocateRevenue` with the accumulator bound, WETH-only Hard leg, `signalerBudget` as the sole earmark, `burnVuxRevenue`, `setOpsRecipient` | `src/StrategicTreasury.sol` | `TreasuryRevenue.t.sol` (18) |
| **4.6** | LSG P0 authority — `lsgModule` slot (launch `address(0)`), `activateLSG`/`deactivateLSG`, `ILSGModule`, `deployMarginalBySignal`, treasury-side `fundSignalerProgram` | `src/StrategicTreasury.sol`, `src/interfaces/ILSGModule.sol` | `TreasuryLsgBoundary.t.sol` (21) |
| **4.7** | Mode-aware accounting property suite | — | `TreasuryAccountingProperties.t.sol` (9 × 10,000) |
| **4.8** | Boundary negatives + invariant extension (INV-23/24/28/30/31 + INV-32/33/34) and FB-5 / FB-15 / FB-16 | — | `TreasuryInvariants.t.sol` (8), `TreasuryFailureBehaviors.t.sol` (9) |
| **4.9** | Review documentation | `evidence/*.md` (5) | — |

### Changed-file inventory

24 files, listed with per-file SHA-256 in
[`evidence/subject-manifest.md`](evidence/subject-manifest.md): 5 new `src/` files, 1 modified
build config, 5 new/1 modified mocks, and 12 new test files. Two files were *modified* rather
than created — `foundry.toml` (three lines + rationale, §5 J-1) and `test/mocks/MockWeth.sol`
(one inert-by-default `transferFrom` override). Nothing else in the landed tree was touched:
`src/VUX.sol`, `src/HardReserve.sol`, `src/Rig.sol`, `vendor/`, `docs/authority/`, and the
Sprint-1…3 test suites are byte-identical.

---

## 3. Technical Highlights

### 3.1 Classification is arithmetic, and the arithmetic is measured

Every credit the treasury makes is `balanceOf(this)` **after** minus `balanceOf(this)` **before**,
never an amount an adapter reported. This is load-bearing in both directions, and two guards
were added because they close lies that would otherwise cost an adversarial adapter nothing:

- **`returnFor` credits its measured receipt, not its `amount` argument.** On an
  under-delivering asset, crediting the argument would retire more principal than arrived — and
  the missing principal would resurface later as revenue that was never earned
  (`TreasuryFlows.t.sol::test_OnlyWhatActuallyArrivesRetiresPrincipal`).
- **A duplicated reward asset is credited exactly once.** `rewardAssets() = [X, X]` measures one
  delta and would otherwise book it twice — the only identified lie that manufactures revenue
  *without* delivering value (`test_ADuplicatedRewardAssetIsCreditedExactlyOnce`).

The complete adversarial analysis, member by member, is in
[`evidence/fraud-vs-theft-argument.md`](evidence/fraud-vs-theft-argument.md).

### 3.2 Basis conservation is exact, not approximate

`redeemUnits` releases `ceil(outstandingPrincipal × units / unitsHeld)` via
`Math.mulDiv(..., Rounding.Ceil)` — full precision, conservative direction (it minimises
immediate revenue). Over a full unwind the final redemption has `units == unitsHeld`, so
`ceil(basis × u / u) == basis` absorbs whatever the intermediate ceilings left: `Σ basisReleased`
equals the original basis **to the wei**. Proven at a hand-checkable non-1:1 unit price
(`test_BasisReleaseConservesOverAFullUnwind`: 10 wei of basis against 30 units, unwound 7/7/7/9)
and over the input space
(`testFuzz_UnitizedBasisConservesOverAnyFullUnwind`, 10,000 runs).

### 3.3 Attributed invariants, not measured ones

`TreasuryInvariants.t.sol` runs the treasury **and** the real monetary core in the same
randomized sequences — settlements, redemptions, donations, admissions, deployments, total
strategy losses, recalls, harvests, redemptions, write-offs, allocations. The two headline
invariants compare `B` and `S` against the sum of their *causes* (the `Settled` event's legs, the
`Redeemed` payout, the `toHard` argument the handler passed), never against a measurement of the
thing under test. An invariant fed by a measurement of its own subject is a tautology; this one
fails the moment a single unattributed wei reaches the Reserve. 16,384 calls, 0 reverts.

### 3.4 Structural absence, proven against the artifact

`TreasurySurface.t.sol` enumerates the external surface **closed-world**: every accepted entry
present, and every present entry accepted (44/44). A new privileged function cannot appear
without failing a test. On top of that: no `setPool`/initializer/upgrade, no `declareProfit` or
revenue setter, no mark or NAV cell, no policy-ratio getter, no P1 LSG mechanism, and — the
2026-08-12 remediation, asserted at selector level in the deployed image — no `toMarketInfra`
argument and no `marketInfraBudget` symbol.

**A note on the method, because it bit once.** Under `via_ir` + optimizer, solc emits
`PUSH4 (sel >> s); PUSH1 (0xe0 + s); SHL` for whichever small `s` suits it — the F-46 self-burn's
`0x42966c68` is stored as `0x0852cd8d` with `s = 3`. A naive 4-byte substring search finds
nothing and calls it absence. The first draft of the FR-10.3 bytecode test did exactly that and
its **positive control caught it**. The shipped test enumerates every legal shift and keeps the
control; the primary, encoding-independent proof is
`test_FR10_3_TheTreasuryCannotEvenNameACoreAuthority`, which reads the compiler's own
`metadata.sources` and shows `src/interfaces/IVUX.sol` and `src/interfaces/IVUXMintable.sol` are
not in the treasury's source set at all.

### 3.5 Real pool, no mock-weakened identity

`sprint.md:L331` requires the constructor-verification fixtures to deploy a real pool. They do:
`PoolDeployerHarness` deploys the genuine `=0.7.6` `VuxPoolDeployer` artifact by raw CREATE and
lets it deploy a genuine vendored `UniswapV3Pool` by CREATE2, then the tests re-derive the
address independently from `keccak256(creation code)` read out of the pool artifact. Mocks appear
in exactly two negatives — `PoolOwnerNotDead` and `PoolTickSpacingInvalid` — because a real
`VuxPoolDeployer` has `owner` as a compile-time constant zero and rejects out-of-domain tick
spacings before a pool exists. An unreachable guard and a broken one look identical, so those two
are exercised against a controllable pool and the file says so.

---

## 4. Testing Summary

```bash
export PATH="$HOME/.foundry/bin:$PATH"

bash tools/provenance/run-all.sh                 # 8 gates + full suite (both units built --force)
forge test                                       # 298 passed / 0 failed
FOUNDRY_PROFILE=ci forge test                    # same, at 10,000 fuzz / 16,384 invariant calls
forge test --match-path 'test/treasury/*'        # 154 Sprint-4 tests
```

| suite | tests | carries |
|---|---:|---|
| `VuxPoolDeployer.t.sol` | 20 | Task 4.1 acceptance; commitment gate, one-shot, domain checks, CREATE2 recompute, namespace exclusivity |
| `TreasuryConstructor.t.sol` | 14 | AC-1, AC-8; identity re-verification against a real pool, derived tick bounds, role topology |
| `TreasurySurface.t.sol` | 7 | AC-1, AC-4, AC-5; closed-world ABI, prohibited surfaces, no ratios, no marks, no P1 LSG |
| `TreasuryAdmission.t.sol` | 21 | AC-2; mode immutability, exact maturity boundary, caps, instant unblockable removal/recall |
| `TreasuryFlows.t.sol` | 27 | AC-3; the three primitives at their guard boundaries + `closeStrategy` |
| `TreasuryRevenue.t.sol` | 18 | AC-4, AC-5; accumulator bound, three asset-shaped rejections, F-46 burn, FR-12 negative |
| `TreasuryLsgBoundary.t.sol` | 21 | AC-6; activation authority, fail-closed surfaces, INV-32/33/34, FB-10 |
| `TreasuryAccountingProperties.t.sol` | 9 | AC-3; ∀ flow sequences ∀ modes, 10,000 runs each |
| `TreasuryInvariants.t.sol` | 8 | INV-23/24/28/30/31/33; attributed `B` and `S` identities under mixed sequences |
| `TreasuryFailureBehaviors.t.sol` | 9 | AC-7; FB-5 (50/80/100%), FB-13, FB-15, FB-16, FR-10.3 |

**Regression:** the complete Sprint-1…3 suite (144 tests) passes unchanged, including the
Sprint-3 Rig invariant harness, the redemption arithmetic, the VEM property suites, and the
provenance/default-deny gates.

---

## 5. Judgment Calls for Review Disposition

Each of these is a decision the accepted authority did not settle outright. None is blocking;
all are surfaced deliberately.

### J-1 — `foundry.toml`: giving a VUX-owned file a compile root in the `=0.7.6` unit

`VuxPoolDeployer.sol` must compile under the pinned `=0.7.6` solc while staying visibly outside
the immutable upstream census (sprint.md:L19). Foundry admits exactly one directory per compile
role, and all three (`src`/`test`/`script`) already pointed at the vendored tree. Resolution:
the file lives at `src/v3core/` — inside the declared VUX source root, so every provenance gate
classifies it `vux` — and `[profile.v3core] script` points there. `src` and `test` still point at
the vendored tree, so the full 32-file census still compiles and the pool artifact is still
produced.

Two guard lines came with it, and the second is the interesting one:

- `[profile.default] skip = ["src/v3core/**"]` — keeps the `=0.8.28` unit from trying to compile
  a `=0.7.6` file.
- `[profile.v3core] skip = []` — **cancels the inherited skip.** Foundry profiles inherit from
  `[profile.default]`, so the line above silently propagated into the vendored unit and made it
  skip the very file it was added to compile. The failure was quiet: the build stayed green and
  merely stopped emitting the artifact, which surfaced only when the tests could not read it.

This is the **same inheritance hazard the Sprint-3 decision log flagged as an unresolved
residual** (`via_ir` leaking into `[profile.v3core]`), hit a second time in a new key. The
structural fix — a gate comparing this profile's *effective* settings against the accepted
refreeze set — remains outside Sprint-4 scope, and is now a twice-observed hazard rather than a
once-observed one. **No bytecode-affecting setting changed in either unit**;
`verify-init-code-hash.sh` reproduces the accepted `POOL_INIT_CODE_HASH` byte-identical.

### J-2 — `IStrategyAdapter` shape (six members) and `ILSGRewardProgram`

The accepted architecture names `adapter.principalUnits()` and `adapter.harvest()` (sdd.md:L294)
and the measured-units deposit rule (sdd.md:L295) but does not publish a full adapter interface;
admission is "P0 code, P1 use". The shipped interface is the minimum the accepted flows require:
`principalUnits`, `rewardAssets`, `harvest`, `deposit`, `redeem`, `recall`, with a per-mode table
in the file showing which modes call which. Two consequences worth a reviewer's eye:

- Deployment is a plain push for `NETTING`/`CLAIM` and a push-then-`deposit` for `UNITIZED` —
  because the measured-units rule requires the units to move inside the call, and `NETTING`
  targets are specified as opaque with no position handle.
- `fundSignalerProgram` needs a module-side entry point, but the accepted `ILSGModule` is exactly
  one `view` (sdd.md:L769-L772). Widening it would blur the boundary argument, so the funding
  call lives in a **separate, equally narrow** `ILSGRewardProgram` in the same file. The module
  is granted nothing standing: the treasury pushes the exact amount, then calls
  (`test_TheModuleHoldsNoAllowanceOverTheTreasury`).

### J-3 — `realizedRevenue` is an accumulator, not a segregated balance

The accepted bound is `Σ legs ≤ realizedRevenue[asset]` (sdd.md:L312), with no custody condition.
So an operator who earns revenue, redeploys the assets behind it as risk capital, and loses them
leaves the credit standing — and a **later principal inflow can settle it**. Pinned explicitly by
`TreasuryRevenue.t.sol::test_ARedeployedAndLostRevenueCreditRemainsOutstanding`.

A stronger rule is available and was deliberately **not** imposed: refuse to deploy assets
covering an outstanding credit until `toCompound` has converted them to principal. That reading
has real support (the compounding leg exists precisely to convert revenue into principal), but no
accepted authority states it, it removes operator capability, and the behaviour it prevents is
the same operator-trust class the SDD already disposes of at rule 4 — an operator willing to do
this can deploy principal to a strategy they control instead. A drafted
"credited revenue is always physically held" invariant was removed for the same reason and the
removal is documented in place (`TreasuryInvariants.t.sol`). **Recommend explicit review
disposition.**

### J-4 — `closeStrategy` write-off applies to all three modes

sdd.md:L301 assigns the write-off to `NETTING`/`CLAIM` (UNITIZED shortfalls book at redemption).
The implementation permits it in every mode, because restricting it would strand a dead
`UNITIZED` strategy's residual basis on the books forever, and a write-off can only *reduce*
principal in any mode. `unitsHeld` is deliberately left intact, so a later recovery books against
a zero basis — entirely as revenue, which is correct once the basis has been recognised as a
loss (`test_RecoveryAfterAWriteOffIsRevenue`).

### J-5 — `deployMarginalBySignal` uses filter-then-split

sdd.md:L337 reads "filters to admitted + matured + cap-headroom strategies, splits `totalAmount`
pro-rata by weight". Implemented literally: ineligible weights are **not** in the denominator, so
the eligible set absorbs the whole requested amount (still cap-clamped, with the operator holding
the size). The alternative — leaving the ineligible share undeployed — is a different reading.
Pinned and explained at `TreasuryLsgBoundary.t.sol::test_SignalConsumedSnapshotsWhatWasRead`.

### J-6 — `=0.7.6` predates custom errors

`VuxPoolDeployer` carries the accepted error names (`BadCommitment`, `PoolAlreadyDeployed`,
`InvalidPoolParams`, sdd.md:L829-L830) as `require` revert strings, because custom errors arrived
in 0.8.4. The three `InvalidPoolParams` domains are given distinct suffixes so each violation is
independently testable.

### J-7 — `StrategicInflow` class 1 has no emitter

The 12% settlement leg arrives as a plain WETH transfer with no callback (sdd.md:L138), so the
treasury is never invoked and cannot observe it. Attribution lives in `Rig.Settled` +
`Rig.totalStrategicContributed`, and the untracked receipt defaults to principal-side inventory
(§1.10 rule 5). Class 3 (`PolFeeYield`) is Sprint 5. Documented in-code at
`src/StrategicTreasury.sol:114`.

### J-8 — Two new error names not in the accepted schema

`SlippageExceeded` (the `minOut` bound on `redeemUnits`) and `MalformedSignal` (a length-mismatched
module answer) have no row in sdd.md §6.1, which enumerates errors for behaviours the SDD names
without exhausting them. Five constructor-verification errors are likewise new
(`PoolFactoryMismatch`, `PoolOwnerNotDead`, `PoolTokensMismatch`, `PoolFeeMismatch`,
`PoolTickSpacingInvalid`), one per AC-1 check, each with its own negative test. Where the accepted
schema *did* offer a fit, it was reused rather than extended — an over-earmark in
`fundSignalerProgram` reverts `RevenueExceedsRealized`, and an unadmitted asset reverts
`StrategyNotAdmitted`. The accepted table's `NotClosed()` is not declared: `StillAdmitted()` is
the same guard and declaring an unused error would be dead code.

---

## 6. Known Limitations and Scope Boundaries

**Deliberately not built** (later sprints own these): the POL sleeve and its cost-basis cells,
the pool callbacks, VYRF harvest, and `buyVuxForPol` (Sprint 5); `Lens`, the indexer, and the
truth surfaces (Sprint 6); `GenesisDeployer` and the launch rehearsal (Sprint 7). The
`LSGSignals` module implementation is P1 and out of cycle entirely — no stake, epoch, weighting,
reward accrual, delegation, ranking, threshold, or calendar ships, and `TreasurySurface.t.sol`
asserts that mechanically.

**No lending surface** of any kind was introduced: no hook, registry, wrapper, receipt token,
collateral status, oracle, transfer restriction, special redemption path, LLTV constant, or
lender integration.

**Test-only mocks** stand in for external systems (`MockWeth`, `MockErc20`, `MockStrategy`,
`MockLsgModule`, `MockPool`). None is imported by `src/`. The pool is *not* mocked in the
positive path — see §3.5.

**`deployMarginalBySignal` iterates the module's array.** A hostile module can return a long
array and make the call expensive; it cannot make it do anything else, and the operator chooses
whether to call it at all. No bound is imposed because none is specified and the accepted
anti-capture argument is topological rather than gas-based.

---

## 7. Verification Steps for the Reviewer

```bash
export PATH="$HOME/.foundry/bin:$PATH"

# 1. Baseline and subject identity
git rev-parse HEAD                                    # 84abced4… — no commit was made
sha256sum foundry.toml src/StrategicTreasury.sol src/interfaces/ILSGModule.sol \
  src/interfaces/IStrategyAdapter.sol src/interfaces/IVUXBurnable.sol \
  src/v3core/VuxPoolDeployer.sol test/mocks/MockErc20.sol test/mocks/MockLsgModule.sol \
  test/mocks/MockPool.sol test/mocks/MockStrategy.sol test/mocks/MockWeth.sol \
  test/treasury/*.sol | LC_ALL=C sort -k2 | sha256sum
# expect 72896e9d80d16b229a78e19f8f51c4ed117f622423970bdb491b7d0575d3966b

# 2. Provenance, census, quarantine, launch hygiene, init-code hash, runtime surface
bash tools/provenance/run-all.sh                      # 8 gates + 298 tests

# 3. Depth
FOUNDRY_PROFILE=ci forge test                         # fuzz 10,000 / invariant 16,384 calls

# 4. The two claims, directly
forge test --match-path 'test/treasury/TreasuryFailureBehaviors.t.sol' -vv   # FB-5 / FB-15 / FB-16
forge test --match-path 'test/treasury/TreasuryInvariants.t.sol' -vv         # attributed B and S

# 5. Zero stored ratios / no deleted market-infra leg
jq -r '.methodIdentifiers | keys[]' out/StrategicTreasury.sol/StrategicTreasury.json
bash tools/provenance/verify-quarantine.sh
```

**Suggested review focus, in order:** §5 J-3 (the accumulator-vs-custody disposition) and J-1
(the twice-observed profile-inheritance hazard) first; then J-2 and J-5 as interface/semantic
readings; then the `_classifyReturn` / `harvestYield` / `redeemUnits` guards line by line against
sdd.md §1.10; then the closed-world ABI enumeration as the structural backstop.

---

## 8. Node Closeout

- **Tasks 4.1–4.9:** complete. Beads `vux-m80`, `vux-le0`, `vux-wqx`, `vux-1zg`, `vux-1sf`,
  `vux-h6f`, `vux-2nn`, `vux-3ll`, `vux-2tg` closed with reasons.
- **Sprint 5:** not started. No POL, callback, VYRF, or `Lens` code exists in this subject.
- **No commit, push, merge, tag, release, or deployment occurred.** The tree is left uncommitted
  and available for exact-tree review.
- **Pre-existing State Zone material preserved** — see `evidence/subject-manifest.md` §C.
- **No operator-reserved decision resolved** — see `evidence/r1-r14-reservation-sweep.md`.
- **No `COMPLETED` marker written.** That marker is `/audit-sprint`'s to write on approval; this
  node is implementation only.
- **Ledger status left at `planned`, deliberately.** The native updater
  (`ledger-lib.sh::update_sprint_status 4 in_progress`) could not acquire its lock: this
  environment's `flock` is BusyBox, which has no `-w` timeout flag, and a zero-byte
  `grimoires/loa/ledger.json.lock` was already present in the working tree at node start. Both
  are pre-existing conditions the mandate says to preserve rather than clear, and the field is
  bookkeeping — no acceptance state depends on it. Flagged here so review sees a deliberate
  omission rather than a missed step. Sprint-4 progress is tracked in beads
  (all nine tasks closed with reasons) and in this report.

**Recommended next node:** `/review-sprint sprint-4`.
