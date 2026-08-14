All good

# Sprint 4 Review — Strategic Treasury I: Custody, Classification & Authority Boundaries

Sprint 4 has been independently reviewed against the exact current tree and is
**APPROVED** to advance to security audit. All 9 acceptance criteria are met on
evidence I re-derived myself rather than accepted from the implementation report.
No critical, high, or medium finding exists.

The two dispositions the mandate required explicitly are recorded in full: **J-3**
(`realizedRevenue` as accumulator) resolves **in favour of the implementation** — the
stronger rule the implementer declined to impose would have resolved operator-reserved
decision **R-9** and implemented future waterfall doctrine at P0, both of which accepted
authority forbids (§4). **J-1** (the Foundry profile-inheritance hazard, now twice
observed) is **corrected in the present tree at the resolved-settings level**, not merely
in TOML text, and the current gates are sufficient to protect the frozen unit today (§8).

**Verdict:** `APPROVED` — 0 critical / 0 high / 0 medium / 4 low (+3 informational)
**Recommendation:** proceed to `/audit-sprint sprint-4`

---

## 1. Subject under review (tree identity, recomputed independently)

| fact | value |
|---|---|
| `git rev-parse HEAD` | `84abced4f90b9b8d11d960ebb438125b84914272` — the LANDED_VERIFIED Sprint-3 baseline |
| `git rev-parse sprint-4` | `84abced4…` (branch exists at baseline; **no commit was made** — see I-2) |
| implementation state | uncommitted working tree, per node mandate |
| subject fingerprint | **`72896e9d80d16b229a78e19f8f51c4ed117f622423970bdb491b7d0575d3966b`** — reproduced exactly |
| subject size | **24 files** — reproduced exactly |

The fingerprint was recomputed from the file list independently, not read from
`evidence/subject-manifest.md`. I then verified the list is **exhaustive** rather than
merely correct: `git status --porcelain -- src test foundry.toml script tools vendor
.github docs` returns exactly the 24 subject files and nothing else, so no App-Zone
change escaped the manifest.

**Modified vs. baseline — 2 tracked files only** (`git diff --stat 84abced4`):

| file | delta | assessment |
|---|---|---|
| `foundry.toml` | +47 / −4 | §8 |
| `test/mocks/MockWeth.sol` | +12 / −0 | inert-by-default `transferFrom` override; guarded on `transferFeeBp == 0` → delegates to `super`, so no earlier suite changes behaviour. Read the full diff, not the summary. |

`docs/authority/` and `vendor/` are **byte-identical** to baseline (`git status` empty for
both paths). No Sprint-1…3 source file is touched.

**Authority chain re-hashed independently:**

| artifact | expected (sprint.md:L25-L26) | measured | |
|---|---|---|---|
| `grimoires/loa/prd.md` v2.1.1 | `791c52f2ad05…f0e2406e` | `791c52f2ad05c794188b218e877957889bc97b6399b965b9c5fe003ef0e2406e` | ✓ |
| `grimoires/loa/sdd.md` v1.7.1 | `b7270458e141…aac6b175` | `b7270458e1417171dd812f34039263eca45cd676f8009dbfaf202d90aac6b175` | ✓ |
| `grimoires/loa/sprint.md` v1.1.1 | — | `bcaebd18f8cc5b35c28ee23745cf7b07945c82bd66df589e1eccaf0eabaa5557` | ✓ — the exact post-tick value the Sprint-3 review gate recorded; unchanged since |

`sprint-4-scope.md` verified **byte-exact** against `sprint.md` L292–L350 before this
gate's checkbox bookkeeping (§10).

---

## 2. Acceptance criteria — all 9 met

Each was re-derived against source and artifact. Line references are my own reading.

| AC | verdict | what I verified independently |
|---|---|---|
| **AC-1** constructor re-verification, creator roles, no `setPool`/initializer | ✓ | `src/StrategicTreasury.sol:322` `factory()`, `:325` `owner()==0`, `:328-331` canonical sort + token match, `:333` fee, `:336` spacing domain, `:349-350` bounds *derived* from `pool.tickSpacing()`, `:352-353` both roles to `msg.sender`. No `setPool`/`initialize`/upgrade exists in the 44-entry ABI (§3). |
| **AC-2** mode immutable, 24 h maturity, instant unblockable removal | ✓ | `:389-391` mode change requires `!active` **and** empty unit ledger; `:400` `maturesAt` stamped per admission; `:413-418` removal is one flag write with no delay, signal, or module in its path; `:440` recall deliberately not admission-gated. `ADMISSION_DELAY = 24 hours` at `:95`. |
| **AC-3** accounting properties ∀ flows ∀ modes | ✓ | Term-for-term against SDD §1.10 in §4 below. 9 fuzz properties, 10,000 runs each, reproduced. |
| **AC-4** `allocateRevenue` negatives + four-leg ABI assertion | ✓ | `:655` `VuxRevenueMustBurn`, `:656` `HardLegMustBeWeth`, `:660` `RevenueExceedsRealized`. ABI shows `allocateRevenue(address,uint256,uint256,uint256,uint256)` — exactly four amount legs, exactly one overload, no `toMarketInfra`, no `marketInfraBudget` (§3). |
| **AC-5** call-time percentages only, zero stored ratios | ✓ | Four `uint256` arguments; **no ratio getter exists in the closed-world ABI** (§3). `verify-quarantine.sh` green over `src test script tools .github foundry.toml`. |
| **AC-6** LSG P0 inactive launch, operator activation, no threshold/calendar | ✓ | `:204` slot, launch `address(0)`; `:706`/`:714` operator-gated + evented; `ILSGModule` is exactly one `view`. No numeric threshold or date anywhere in the contract. |
| **AC-7** FB-5 bit-identity at 50/80/100% loss | ✓ | §6 — re-derived, non-vacuous. |
| **AC-8** role topology; no path to Reserve/redemption/mint/routing | ✓ | §5 — proven structurally, at the compilation-unit level. |
| **AC-9** `VuxPoolDeployer` unit tests incl. independent CREATE2 recompute | ✓ | §7. |

---

## 3. The external surface, enumerated closed-world and independently

I enumerated `out/StrategicTreasury.sol/StrategicTreasury.json` `methodIdentifiers`
myself: **44 entries, all accounted for.**

| class | n | members |
|---|---:|---|
| immutable identities + constants | 13 | `ADMISSION_DELAY`, `DEFAULT_ADMIN_ROLE`, `OPERATOR_ROLE`, `weth`, `vux`, `hardReserve`, `poolDeployer`, `pool`, `token0`, `token1`, `feeTier`, `tickLower`, `tickUpper` |
| accounting views | 10 | `outstandingPrincipal`, `realizedRevenue`, `signalerBudget`, `unitsHeld`, `opsRecipient`, `lsgModule`, `allocationCount`, `admissionOf`, `limitOf`, `strategyAssets` |
| AccessControl (inherited, intended) | 6 | `getRoleAdmin`, `grantRole`, `revokeRole`, `renounceRole`, `hasRole`, `supportsInterface` |
| operator mutators | 13 | the `onlyRole(OPERATOR_ROLE)` set — count reproduced mechanically (`grep -c` = 13) |
| by-design permissionless mutators | 2 | `returnFor`, `harvestYield` (SDD:L294/L300 specify both as permissionless) |

**Structurally absent, verified against the artifact rather than the source text:** no
`setPool`, initializer, or upgrade path; no `declareProfit` or any revenue setter; no mark
or NAV cell; no policy-ratio getter; no `marketInfraBudget`; no Operator Reserve
accumulator; no `genesisOperator`; no POL/callback/VYRF/`Lens` surface (Sprint 5); no LSG
P1 mechanism. The treasury source contains no `delegatecall`, `selfdestruct`, `assembly`,
or `create`.

The **13 role-gated mutators** are exactly the set requiring unauthorized-caller
negatives, and the sprint's 13/13 claim maps 1:1 onto them. `returnFor`/`harvestYield` are
correctly excluded — they are permissionless by accepted design, not by omission.

---

## 4. Strategic accounting — derived from accepted authority, compared term-for-term

I derived the laws from SDD §1.10 (L285–L321) and PRD FR-9/FR-12 first, then compared.

| accepted law | implementation | ✓ |
|---|---|---|
| Contributed capital is principal | Class 1 has no emitter; a bare receipt credits **nothing** — it cannot reach `realizedRevenue` | ✓ |
| Returned deployed principal is principal | `_classifyReturn` `:861-872` nets principal-first; `principalPart = min(received, outstanding)` | ✓ |
| Returned LP principal is principal | POL is Sprint 5; no POL cell exists to violate this | ✓ (n/a) |
| Bare/unattributed transfers default to principal-side inventory | No cell is written on a bare transfer ⇒ never revenue. Conservative default holds by construction (rule 5) | ✓ |
| Unrealized marks cannot enter revenue | **No mark or NAV storage cell exists** (verified against the 44-entry ABI, not the comments). Every credit is a measured balance delta | ✓ |
| NETTING principal-first | `:863-867`; revenue is `received − min(received, outstanding)` | ✓ |
| CLAIM measured delta + units preserved | `:506-513` snapshot → `harvest()` → `unitsAfter < unitsBefore` reverts; `:525` credits `balanceOf` delta, never an adapter's return value; `:516-523` credits a duplicated reward asset exactly once | ✓ |
| UNITIZED conservative basis release, gain/shortfall | `:562` `mulDiv(basis, units, held, Rounding.Ceil)` — ceiling minimises immediate revenue; `:574-579` gain→`realizedRevenue`, shortfall→`lossPart` **evented, never negative revenue** | ✓ |
| `closeStrategy` loss-only | `:597-607` zeroes residual principal and emits loss. It never touches `realizedRevenue` — no sequence of closes creates a wei of revenue | ✓ |
| Arbitrary return assets cannot create revenue | `:470-472` `UnknownReturnAsset` unless the asset has outstanding principal **or** is the admitted deployment asset — the accepted guard, verbatim | ✓ |
| Mode is immutable | `:389-391` | ✓ |
| No `declareProfit` or classification escape hatch | None in the ABI; classification has exactly one write path per primitive | ✓ |

**Arithmetic soundness spot-checks:** `basisReleased ≤ basis` for all `units ≤ held`, so
`:570` cannot underflow; `:864` cannot underflow by construction of the `min`; `:525`
reverts (fail-closed) if a reward balance *decreased* during harvest. CEI holds on every
distributing path — `realizedRevenue`/`signalerBudget` are decremented **before** the
transfer (`:661`, `:794`, `:687`), and every external-call path carries `nonReentrant`.

### The J-3 disposition — REQUIRED, and resolved in favour of the implementation

**The sequence, answered concretely.** I confirmed each step against the code, and the
implementer has pinned the whole sequence as a passing test
(`TreasuryRevenue.t.sol:324`), including the honest intermediate assertion that with an
empty treasury the leg simply fails on balance:

1. realize `R` → `realizedRevenue[A] += R` (measured, genuine);
2. do not allocate;
3. `deployToStrategy` books `outstandingPrincipal += R` **without** decrementing
   `realizedRevenue` — the same wei is now both deployed basis and unspent credit;
4. total loss → `closeStrategy` writes off the basis; the credit still stands;
5. fresh Strategic principal of `A` arrives as bare inventory;
6. `allocateRevenue(A, 0, 0, R, 0)` pays `R` out of that principal.

**Step 6 succeeds. The disposition is that this is explicitly intended by accepted
authority, and imposing the stronger rule would have violated it.** Four independent
accepted statements converge:

1. **The bound is stated without a custody condition.** SDD:L312 — `Σ of all four legs ≤
   realizedRevenue[asset]`. The implementation is term-for-term.
2. **Accepted authority explicitly refuses to net losses against revenue.** SDD:L295
   books a UNITIZED shortfall as principal reduction, *"evented — **never negative
   revenue**"*; §1.10 rule 3 confines a write-off to *"reduce **principal** accounting"*.
   A standing credit surviving a loss is the direct consequence of a rule the SDD states
   twice, deliberately.
3. **The corrective discipline is operator-reserved, by name.** PRD §16 **R-9** reserves
   *"qualifying-revenue computation **incl. realized-loss/high-water restoration**"* to
   operator execution. Both founder authorities agree
   (`vux-founder-parameter-freeze-adaptive-routing-supersession-2026-08.md:95`;
   `vux-founder-acceptance-adaptive-routing-lsg-holder-liquidity-2026-08.md:200`, which
   records high-water/realized-loss restoration as **ADDED to the qualifying-revenue
   definition**). This is precisely the rule that would prevent step 6 — and it is
   reserved to the operator, not to the contract.
4. **P0 is forbidden from implementing it.** PRD FR-12.4 — the waterfall and Operator
   Reserve mechanics are future doctrine, *"**not implemented by any P0 surface**"*, with
   the credit/accumulation/sweep mechanics a P1 design obligation. The Sprint Plan's own
   risk register (sprint.md:L51) names *"accidentally freezing an operator-reserved
   execution parameter (R-9/R-10 execution scope)"* as a **Medium/High risk this sprint
   must avoid**, mitigated by *"call-time-arguments-only design"*.

**Against the four higher-level requirements the mandate named** — none is breached,
because none is a custody condition:

- *returned principal is never revenue* — satisfied at the classification point: no
  returned principal is ever credited to `realizedRevenue` (`:863-867`). No principal is
  reclassified in the sequence; the credit **predates** the principal inflow.
- *principal may not be relabeled to fund a preferred recipient* (FR-9.3/9.4) — **no
  relabeling operation exists anywhere in the contract.** There is no reclassification
  function to invoke.
- *zero realized revenue provides no fallback to principal* — satisfied mechanically and
  exactly: with `realizedRevenue[asset] == 0` every nonzero leg reverts
  (`TreasuryRevenue.t.sol:68`).
- *principal and marks arithmetically unreachable* — satisfied in the sense the SDD means
  and cites (prd.md:L505-L506, whose negative acceptance is *"no configuration of the
  policy surface can reach **Reserve** principal or mint"*): marks have no cell, principal
  is netted first, so neither ever **enters** the accumulator.

**Not HITL.** There is no contradiction to escalate: normal precedence resolves it
cleanly. The accumulator model and the loss-restoration discipline are not competing
readings of one rule — they are two *different* rules assigned to two *different*
authorities, on-chain and operator-reserved respectively, by the same accepted documents.
The implementer's restraint was **required**, not merely permitted.

The forward obligation this creates is recorded as **L-1**.

### Malicious-strategy blast radius

The mandate's criterion — *a malicious strategy may steal, but must gain no stronger
ability to convert principal into distributable revenue* — holds. The sharpest available
route (which the implementer states plainly rather than arguing away) is misattribution:
a strategy holding deployed principal calls `returnFor(otherAdmittedStrategy, …)`, so the
capital credits as revenue while its own `outstandingPrincipal` stands. I verified this is
reachable. It is nonetheless **not stronger than theft**: the attacker must *return the
money* to do it, gains nothing, and the magnitude is bounded by the same per-(strategy,
asset) cap; the payout still requires an affirmative operator call. This is exactly the
class SDD §1.10 rule 4 disposes of, and `returnFor`'s caller-attributed permissionless
shape is accepted architecture (SDD:L300) implemented verbatim. Recorded as **L-2** and
**I-1** for the audit node, which owns the operator-boundary argument.

---

## 5. Authority topology and Hard-Reserve isolation

**The negative claim is structural, and I verified it at the strongest available level.**
I parsed `metadata.sources` out of the compiled artifact myself. The treasury's entire
compilation unit is:

```
src/StrategicTreasury.sol, src/interfaces/{ILSGModule,IStrategyAdapter,IVUXBurnable}.sol,
vendored OZ (AccessControl, IERC20, SafeERC20, Math, ReentrancyGuard, …),
vendored v3-core INTERFACES only (IUniswapV3Factory, IUniswapV3Pool, …)
```

`src/HardReserve.sol`, `src/Rig.sol`, `src/VUX.sol`, `src/interfaces/IVUX.sol`, and
`src/interfaces/IVUXMintable.sol` are **absent**. The treasury cannot *name* a
monetary-core authority, let alone call one — an argument no computed-selector trick can
defeat. Consequently it cannot move Reserve principal, alter redemption, mint VUX, alter
Rig routing, create VEM credit, use Strategic NAV as backing, authorize recapitalization,
or create a rescue entitlement. `hardReserve` is a plain transfer destination reached only
by the one-way WETH-only accretion leg; the sole token authority imported is
`IVUXBurnable.burn`, which acts on the caller's own balance.

**Role topology:** `DEFAULT_ADMIN_ROLE` + `OPERATOR_ROLE`, both granted to `msg.sender` at
`:352-353`. No `genesisOperator` argument exists, so the external genesis caller cannot
receive authority and no argument exists to misconfigure. No initializer, no mutable pool
replacement — all identities are `immutable`. The six inherited AccessControl entries are
**intended role management over this contract's own roles**, not monetary-core authority;
the core holds no roles for them to reach. Sprint 7 owns the grant-and-renounce.

**FB-15/16 re-checked from the new privileged surface:** `TreasuryFailureBehaviors.t.sol`
§175 ff — the treasury's own identity is refused by `NotRig()`/`NotReserve()` (`:181`),
plus the two FR-10.3 proofs (`:201`, `:236`).

---

## 6. Strategic/Hard-Reserve failure independence (FB-5) — re-derived

`_assertLossLeavesTheCoreBitIdentical` is **non-vacuous**, which I checked before
accepting it: it asserts the capital genuinely left (`weth.balanceOf(VOID) == lost`) and
that the loss was not silently reclassified (`outstandingPrincipal` unchanged;
`realizedRevenue == 0`). It then compares **twelve** core values field-by-field —
`B`, `S`, `previewRedeem` at two sizes, King, price, `currentUPS`, `epochUPS`,
`epochStart`, `epochId`, and the three authority edges (`vux.rig()` = mint authority,
`vux.reserve()` = redemption-burn authority, `rig.treasury()` = routing constant).

Bit-identity holds at **50% / 80% / 100%** (`:94`, `:98`, `:102`). The sharpest form is
`:111`: the settlement *after* a total loss reads exactly the untouched `B_pre`/`S_pre`
and still caps issuance at `Qsafe` — if a Strategic loss could reach VEM at all, it would
reach it there. `TreasuryInvariants.t.sol` holds the same identity across randomized
sequences that include total strategy loss.

---

## 7. `VuxPoolDeployer` — correctness and provenance

Reviewed as VUX-owned derivative source in the pinned `=0.7.6` domain.

- **Derivation by inheritance, not copying** — `contract VuxPoolDeployer is
  UniswapV3PoolDeployer`. Upstream's CREATE2 semantics and argument-free `parameters()`
  init-code pattern are preserved untouched, which is *why* `POOL_INIT_CODE_HASH` is
  unaffected. The upstream census is not modified and does not contain this file.
- **Commitment gate** `:106` — `keccak256(abi.encode(msg.sender, salt)) == COMMITMENT`.
  Bound to `msg.sender`, not `tx.origin`: possession of the preimage is insufficient.
  Zero commitment rejected at construction (`:67`).
- **One-shot latch** `:105` + `:114`. Writing `canonicalPool` *after* `deploy` returns is
  sound, not merely convenient: the only external code executed is the byte-frozen
  vendored pool constructor, whose entire interaction with its deployer is the
  `parameters()` view — there is no re-entry path to race the latch.
- **Domain checks** `:108-111` — zero token, token ordering, fee `< 1_000_000`,
  `tickSpacing ∈ (0, 16384)`. `token1 != 0` follows from `token0 != 0 ∧ token0 < token1`.
  Domain-checked without value-freezing: the concrete `(fee, tickSpacing)` pair stays an
  **R-14** deployment fact. Correct.
- **Permanently dead `owner()`** `:58` — `address public constant owner = address(0)`,
  a property of the bytecode rather than of an unset slot, making the pool's
  `setFeeProtocol`/`collectProtocol` unreachable forever.
- **Independent CREATE2 reproduction** — `PoolDeployerHarness.sol:63` derives the address
  from `keccak256(creation code)` read out of the emitted pool artifact rather than from
  the accepted constant, so the identity test and the `POOL_INIT_CODE_HASH` gate close the
  loop without either assuming the other's conclusion. The positive path uses a **real**
  vendored pool; mocks appear only in the two negatives that a real deployer makes
  unreachable, and the file says so.

Provenance classification is correct and not improperly folded into the census:
`verify-census.sh` green with the census unchanged.

---

## 8. Build, provenance, and the recurring profile-inheritance hazard — REQUIRED disposition

**I established resolved settings, not TOML text**, via `FOUNDRY_PROFILE=v3core forge
config`:

| setting | resolved | accepted refreeze §7 | |
|---|---|---|---|
| `solc` | `0.7.6` | `0.7.6` | ✓ |
| `optimizer` / `optimizer_runs` | `true` / `800` | `true` / `800` | ✓ |
| `evm_version` | `istanbul` | `istanbul` | ✓ |
| `bytecode_hash` | `none` | `none` | ✓ |
| `via_ir` | `false` | `false` | ✓ (Sprint-3 override holds) |
| `skip` | `[]` | — | ✓ (Sprint-4 override holds) |
| `src` / `test` / `script` | vendored census / vendored census / `src/v3core` | — | ✓ |

**The frozen unit is genuinely emitted and correct**, not merely configured to be:

- `out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json` present; creation **45,458** and
  runtime **44,286** hex chars — real bytecode, not an empty artifact.
- `out-v3core/VuxPoolDeployer.sol/VuxPoolDeployer.json` present.
- `verify-init-code-hash.sh` — **`POOL_INIT_CODE_HASH` reproduced byte-identical** to the
  accepted constant, plus `test_CborTailConfirmsBytecodeHashNone`.

**All 8 gates green** (`census`, `pins`, `spdx`, `notices`, `quarantine`,
`launch-hygiene`, `init-code-hash`, `runtime-surface`), each exercising the intended
current subject: Foundry **v1.5.0**, VUX `=0.8.28` with the accepted `via_ir` identity,
authorized census unchanged, no source-authority expansion, default-deny gates green, and
the six accepted authority artifacts byte-identical (`docs/` unmodified vs. baseline).

**Disposition on the recurrence.** This is the **same inheritance hazard the Sprint-3
decision log recorded as an unresolved residual**, reached a second time through a
different key (`skip` rather than `via_ir`). The failure mode is the dangerous one — the
build stayed green and merely stopped emitting the artifact. The present tree is corrected
at the level that matters (resolved settings, verified above), the frozen unit reproduces
byte-identically, and `verify-init-code-hash.sh` **fails closed** — so the accepted gates
**are sufficient to protect the frozen unit today** and this is **not blocking**.

It is, however, now a **twice-observed** hazard rather than a once-observed one, and the
existing gate only catches keys that happen to be bytecode-affecting: the Sprint-4
instance was caught by a *test* failing to read an artifact, not by a gate. **Recorded as
L-4: a future bounded hardening node comparing `[profile.v3core]`'s *effective* settings
against the accepted refreeze set is warranted.** Correctly outside Sprint-4 scope; no
implementation was mutated during this review.

---

## 9. Test, property, and invariant adequacy — reproduced, not accepted

Every reported number was re-run rather than read.

| claim | my measurement | |
|---|---|---|
| 298 tests | `298 passed / 0 failed` (default profile) | ✓ |
| CI depth | `298 passed / 0 failed` under `FOUNDRY_PROFILE=ci` | ✓ |
| fuzz 10,000 | **14** fuzz properties at `runs: 10000` (9 of them the accounting suite) | ✓ |
| invariants 16,384 / 0 reverts | **16** invariants at `runs: 256, calls: 16384` — **every one `reverts: 0`** | ✓ |
| 9 accounting properties | `grep -c "function testFuzz_"` = **9** | ✓ |
| +154 Sprint-4 tests | `--match-path 'test/treasury/*'` → **154 passed** | ✓ |
| 13/13 mutators with unauthorized negatives | 13 role-gated mutators confirmed mechanically (§3) | ✓ |
| 44/44 closed-world ABI | enumerated independently (§3) | ✓ |
| 8/8 provenance gates | re-run (§8) | ✓ |
| 9/9 AC | re-derived (§2) | ✓ |

**Non-vacuity and property↔claim correspondence checked, not assumed.** The properties
assert exact equalities against independently computed expectations rather than
re-measuring the subject — e.g. `testFuzz_NettingRecognisesOnlyTheExcessOverFullReturn`
computes `expectedRevenue = max(0, Σreturned − deployed)` in the test and requires
equality across a *three-chunk* sequence, and
`testFuzz_DistributionsNeverExceedRealizedCredits` tests **both** directions (credit + 1
reverts, exactly the credit clears to zero). The invariant harness compares `B` and `S`
against the sum of their *causes* — a measured-subject invariant would be a tautology —
and ships an explicit anti-degeneracy test asserting every handler action does real work.

**The removed J-3 property was removed for the right reason.** I read the in-place record
at `TreasuryInvariants.t.sol:171-179`: the drafted "credited revenue is always physically
held" invariant was withdrawn because it is **stronger than the accepted design**
(SDD:L312 bounds by `realizedRevenue`, not by custody) — and the behaviour it would have
caught is **pinned as an explicit passing test** and escalated for disposition rather than
suppressed. It did not discover a requirement violation; §4 confirms independently that no
requirement is violated. This is disclosure, not concealment.

**Selector-search method — the retrospective learning is correctly applied.** The
mandate's warning is honoured: the **primary** proof is `metadata.sources` reachability
(§5), which is encoding-independent, and it carries three positive controls. The bytecode
half enumerates every legal shift of the `via_ir` `PUSH4 (sel >> s); PUSH1 (0xe0 + s);
SHL` idiom — the naive 4-byte grep is explicitly rejected — and keeps **two positive
controls** proving the enumeration finds call sites that really exist. Absence is never
claimed without a control. See **I-3** for the one hedge worth carrying to audit.

---

## 10. Scope discipline and operator-reserved decisions

**No Sprint-5 source entered the subject.** Grepped `src/` for the POL sleeve, pool
callbacks, VYRF, and `Lens`: the only hits are **comments declaring their absence** and
the Sprint-5 boundary note. Confirmed against the 44-entry ABI, which is the load-bearing
check. No lending surface of any kind (no LLTV, collateral, borrow, liquidation, receipt
token, or oracle).

**No LSG P1 mechanics ship.** `ILSGModule` is exactly one `view`;
`ILSGRewardProgram` is a second, equally narrow interface carrying the one call
`fundSignalerProgram` must make — the module is granted no allowance, role, or standing
authority. No staking, epoch logic, age requirement, signal weighting, reward accrual,
delegation, 7/14-day policy, or activation threshold exists.
`test_NoLsgMechanismShipsAtP0` asserts nine P1-shaped selectors absent with positive
controls. Inactive state fails closed (`LSGInactive`) on both signal surfaces.

**No operator-reserved decision resolved.** I spot-checked the R-1…R-14 sweep against the
code for the rows the mandate names: no production strategy, cap, ROOT/GIGA decision, or
allocation policy is frozen — the registry ships **empty**, every value needed for a test
to run is a `test/`-only fixture, and `verify-quarantine.sh` passes 10/10 §17 patterns.
R-9/R-10 execution scope is preserved precisely by the call-time-arguments-only design
(§4).

**Revenue surface — exactly four uses**, verified at the ABI: Strategic compounding, Hard
Reserve accretion (WETH-only, `:656`), actual approved operating expenses, signaler
incentives. Call-time amounts only; bound correctly enforced at `:658-661`;
VUX-denominated non-POL revenue is burn-only (`:655` + `burnVuxRevenue`);
`signalerBudget` is the only earmark; no `toMarketInfra`, no `marketInfraBudget`, no
stored waterfall ratios, no Operator Reserve implementation, no `50/25/20/5/0` encoded.
`toOps` creates no standing entitlement: it transfers immediately to a disclosed
recipient with no accumulator, credit ledger, or sweep behind it.

**Review bookkeeping applied.** The 22 Sprint-4 checkboxes in `sprint.md` L292–L350 were
ticked `[ ]` → `[x]`, one character each, per the Sprint-3 gate's convention. Two expected
downstream consequences, both pre-existing convention rather than defects: (1)
`sprint-4-scope.md` — verified byte-exact **before** ticking (§1) — now differs on exactly
those 22 characters, the same status `a2a/index.md` already records for the Sprint-1…3
scope slices; (2) re-hashing `sprint.md` at the audit node will not match the §1 value.
No criterion, task, deliverable, or authority row was altered; Sprint Plan stays
**v1.1.1**.

---

## 11. Findings

No critical, high, or medium finding exists. Nothing below blocks the audit gate.

### L-1 — J-3's corrective discipline is unenforced on-chain **by design**; carry it to the P1 obligation

**Governing requirement:** PRD §16 R-9; PRD FR-12.4; SDD:L312.
Because `realizedRevenue` is a lifetime accumulator and realized losses never reduce it
(§4), the operator's R-9 *qualifying-revenue computation — including realized-loss /
high-water restoration* — is the **only** thing standing between a stale credit and a
principal-funded payout. That allocation is correct and required at P0. The forward
obligation should be explicit: **FR-12.4 already mandates a P1/future design before the
accepted waterfall activates, and that design must carry the realized-loss/high-water
restoration rule**, since P0 deliberately does not. Recorded so the requirement is not
lost between sprints. **No Sprint-4 change requested.**

### L-2 — `fraud-vs-theft-argument.md` §2 understates the actor set

**Governing requirement:** SDD §1.10 rule 4; Task 4.9 deliverable.
§2 concludes *"both steps require the operator"*. Steps 1 and 3 do; **step 2 (`returnFor`)
is permissionless**, so a malicious admitted strategy can create the mislabeled revenue
credit **unilaterally**, with the payout still gated on the operator. The bounding
argument survives intact (§4) and the conclusion is unchanged, but the audit node will
reason about this document's actor set directly. One clarifying sentence would remove the
ambiguity. Documentation only.

### L-3 — `ledger.json` Sprint-4 status remains `planned`

**Governing requirement:** lifecycle bookkeeping; no acceptance state depends on it.
Verified as **bookkeeping, not falsification**: `ledger.json` is git-tracked and
**byte-identical to baseline** — nothing was corrupted or misstated. The reported cause
reproduces exactly: this environment's `flock` is BusyBox `v1.38.0`, whose usage string
offers only `[-sxun]` — **no `-w`**. All nine Beads tasks (`vux-m80`, `vux-le0`,
`vux-wqx`, `vux-1zg`, `vux-1sf`, `vux-h6f`, `vux-2nn`, `vux-3ll`, `vux-2tg`) are
independently confirmed `closed` in `.beads/issues.jsonl`, and Beads is the authoritative
task lifecycle. **Correct disposition: repair at acceptance** (`planned` → the appropriate
terminal status). Per mandate, not mutated here, and the pre-existing zero-byte
`ledger.json.lock` was left untouched.

### L-4 — profile-inheritance hazard is now twice-observed; a bounded hardening node is warranted

**Governing requirement:** refreeze §7 obligation 3.
Non-blocking today (§8): resolved settings are correct, the frozen artifact is emitted,
and the hash reproduces byte-identically behind a fail-closed gate. But the Sprint-4
instance was caught by a *test failing to read an artifact*, not by a gate — the existing
gate only detects inheritance leaks that happen to alter bytecode. A future bounded node
adding a structural guard over `[profile.v3core]`'s **effective** settings would close the
class. Correctly out of Sprint-4 scope.

### Informational

- **I-1 — CLAIM-mode principal-as-yield.** A CLAIM adapter that returns principal from
  `harvest()` while reporting constant `principalUnits()` has that principal credited as
  revenue. This is the accepted SDD:L294 guard implemented **verbatim** (`unitsAfter ≥
  unitsBefore`) and is the §1.10 rule-4 class — bounded by admission diligence, caps, 24 h
  maturity, and instant removal, with the protocol retaining the assets. Flagged as
  context for the audit node's operator-boundary argument, not as a defect.
- **I-2 — branch/HEAD bookkeeping.** `HEAD` is on `master`; the `sprint-4` branch exists
  but was not checked out. Both refs are `84abced4` and nothing is committed, so the
  reviewed subject is unaffected. Worth tidying at acceptance.
- **I-3 — the bytecode half of FR-10.3 is idiom-specific.** `_hasCallSite` matches one
  `via_ir` codegen idiom; a different encoding (e.g. a pre-shifted `PUSH32`) would not be
  matched. The test says so, and the **primary** proof (`metadata.sources`, §5) is
  encoding-independent and stronger, so the claim is properly carried. No action; noted so
  the audit node relies on the structural half.

---

## 12. Terminal state

**`APPROVED`.** The exact Sprint-4 tree — fingerprint
`72896e9d80d16b229a78e19f8f51c4ed117f622423970bdb491b7d0575d3966b`, 24 files — faithfully
satisfies the accepted Strategic Treasury I scope. Tasks 4.1–4.9 and all nine acceptance
criteria are met; all three Sprint-4 success metrics are met (accounting properties green
at ≥10,000 runs per mode with FB-5 bit-identity proven; 100% of treasury mutators covered
by an unauthorized-caller negative; zero stored policy-ratio constants). Custody,
classification, operator-authority containment, Strategic/Hard-Reserve failure
independence, the LSG P0 boundary, `VuxPoolDeployer`, build/provenance integrity, and
scope discipline all hold on independently re-derived evidence.

**Recommended next node:** `/audit-sprint sprint-4`.

---

*Reviewed by the Loa `/review-sprint sprint-4` node, cycle-002, 2026-08-13. Every claim*
*above was re-derived on the exact tree; nothing was accepted on report. No implementation*
*source, test, build configuration, authority document, or provenance registry was mutated.*

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":4},"sprint_id":"sprint-4","ts":"2026-08-13T17:05:00Z"} -->
