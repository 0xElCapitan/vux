All good

# Sprint 5 Review — Strategic Treasury II: POL, Callback Authentication & VYRF

Sprint 5 has been independently reviewed against the exact uncommitted tree and is
**APPROVED** to advance to security audit. All 8 acceptance criteria are met on evidence
I re-derived myself — including the two things this node was told not to take on report:
the **duplicate-callback differential** and the **liquidity-inversion measurement**. No
critical, high, or medium finding exists.

The disposition the mandate reserved for the reviewer is recorded in full: **J-1**
(`buyVuxForPol` does not increment `polVuxPrincipal`) resolves as **outcome 2 — the
requirement is under-specified as to storage cell, and the implementation is a permissible
realization**, in fact the only one that does not double-count inside the cell set
sdd.md:L140 closes. It is not a violation and not HITL (§7).

Because "8/8 with a validator exit 0" is not evidence that the *properties* are exercised,
I did not rely on the implementation's validator at all. I walked every AC against the tree
myself, and then measured the suite's discriminating power directly with an **8-mutation
battery** against a scratchpad copy of the source. **7 of 8 mutations were caught.** The
one that was not is L-1 below.

**Verdict:** `APPROVED` — 0 critical / 0 high / 0 medium / 2 low (+2 informational, 1 carried residual)
**Recommendation:** proceed to `/audit-sprint sprint-5`

---

## 1. Subject under review (identity re-derived from git, not from a file list)

| fact | value |
|---|---|
| worktree / branch | `C:\Users\0x007\vux-sprint-5`, `sprint-5` |
| `git rev-parse HEAD` | `cf0108109e428da0483b8470726f9e48ee740777` — the Sprint-4 closeout baseline |
| commits ahead of baseline | **0** (`git rev-list --count cf010810..HEAD`) |
| implementation state | uncommitted working tree, per node mandate |
| subject size | **12 files** — 2 modified, 10 new |
| subject fingerprint | **`37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a`** — reproduced exactly |

I derived the manifest from the repository rather than from the expected list, using the
same partition the manifest documents, and re-ran the exhaustiveness checks myself:

```bash
{ git diff --name-only cf010810 -- . ; git ls-files --others --exclude-standard ; } \
  | LC_ALL=C sort -u > R.txt
grep -E '^(src/|test/|script/|foundry\.toml$|remappings\.txt$)' R.txt > A.txt
grep -E '^(grimoires/|\.beads/|\.run/)'                          R.txt > B.txt
xargs -a A.txt sha256sum | LC_ALL=C sort -k2 | sha256sum
```

`R` = 38, `A` = **12**, `B` = 26; `A ∪ B == R` **OK**; `A ∩ B == ∅` (0); all 12 present on
disk. `B` grew from the manifest's recorded 22 to 26 as later lifecycle bookkeeping landed,
and `A` did not move — which is the property the partition exists to make visible.
`git status --porcelain -- src test script foundry.toml remappings.txt` returns exactly
those 12 rows and nothing else, so **no App-Zone change escaped the manifest**.

**The two modifications are both justified and both additive.**
`git diff -U0 cf010810 -- src/StrategicTreasury.sol` is +400/−8, and every one of the 8
removed lines is a **doc comment** — the "Sprint boundary" NatSpec block and a
"Class 3 (PolFeeYield) is Sprint 5" comment, both now stale. **No Sprint-4 function body
changed.** `test/treasury/TreasurySurface.t.sol` grows its closed-world accepted-surface
array from 44 to 53; the 9 additions are exactly the POL surface the SDD declares
(`mintPolPosition` L729, `increasePol` L730, `decreasePol` L731, `buyVuxForPol` L732,
`harvestPol` L755, the two callbacks L761–L762, and the two cells from L140) and nothing
else. I checked each against the SDD line rather than against the report.

**Authority chain unmoved.** `grimoires/loa/sprint.md` hashes
`4531a508ae2a032c66f9bdeec7937760b66f973b49d99d948686b4ea17f4bebf` — unchanged from
baseline, Sprint-5 boxes not ticked at implementation exit. `docs/authority/`,
`vendor/`, `remappings.txt`, and `foundry.toml` are all absent from `R` entirely, i.e.
**byte-identical to baseline**. The scope slice `sprint-5-scope.md` (`829f3437…834a7e`) is
`diff`-identical to `sed -n '353,407p' grimoires/loa/sprint.md`.

The two skills under `grimoires/loa/skills-pending/` were treated as **pending only** — not
consulted, not promoted, not used as review authority.

---

## 2. Evidence I reproduced (not inherited)

| claim | my result |
|---|---|
| full suite, default profile | **349 passed / 0 failed / 0 skipped**, 28 suites |
| full suite, `FOUNDRY_PROFILE=ci` | **349 passed / 0 failed / 0 skipped** (10,000 fuzz runs) |
| POL invariants at CI depth | 9 invariants, each `runs: 256, calls: 16384, reverts: 0` |
| POL handler coverage | **22 selectors**, 671–806 calls each, **0 reverts, 0 discards** under `fail_on_revert = true` |
| `tools/provenance/run-all.sh` | exit 0 — "All provenance gates and tests passed" |
| resolved `=0.7.6` settings | `solc=0.7.6 optimizer=true optimizer_runs=800 evm_version=istanbul bytecode_hash=none via_ir=false` |
| `POOL_INIT_CODE_HASH` | reproduced byte-identical (inside `run-all.sh`) |
| E2E against live anvil v1.5.0 | **ran green**, all observables emitted and asserted |
| liquidity-inversion deviation | **19 wei VUX / 364 wei WETH** — matches the claim exactly |

The invariant handler table is worth naming explicitly: the POL actions do **not** run in a
POL-only harness. `addPol`, `decreasePolSome`, `harvestPolNow`, `buyVuxForPolNow`,
`tradeWethForVux`, and `tradeVuxForWeth` are interleaved with all sixteen Sprint-4 actions
(`settle`, `redeemSome`, `donateToReserve`, `admit`, `deploy`, `recall`, `harvest`,
`redeemUnits`, `strategyLosesEverything`, `closeStrategy`, `allocate`, `burnVuxRevenue`, …)
in the same randomized sequences. So the suite asks whether POL breaks anything that was
true without it, not merely whether POL is self-consistent.

---

## 3. Is the evidence discriminating? — an 8-mutation battery

The mandate is explicit that a passing count is not proof the property is exercised. I
copied the tree to a scratchpad (verifying the copy reproduces the subject fingerprint
byte-for-byte), applied one textual mutation at a time to `src/StrategicTreasury.sol`, and
ran the **full** suite against each. The implementation subject was never touched.

| # | mutation — the property it breaks | full-suite result | caught |
|---|---|---|---|
| M1 | `decreasePol`: burn liquidity **before** the fee poke/collect (breaks fee-first ordering) | 4 failed | ✅ |
| M2 | consume the one-shot context **after** payment instead of before | **0 failed** | ❌ **L-1** |
| M3 | remove `_requireConsumed()` from `_addLiquidity` | 1 failed — `test_9_AnUnconsumedAuthorization…` | ✅ |
| M4 | make `_affordableLiquidity` non-conservative (×2) | 20 failed | ✅ |
| M5 | route WETH fee yield into `realizedRevenue` instead of the Hard Reserve | 10 failed | ✅ |
| M6 | remove the `minVuxOut` measured-delta check | 1 failed — `test_BuyVuxForPolEnforcesMinVuxOut` | ✅ |
| M7 | remove `msg.sender != pool` in the mint callback | 1 failed — `test_1_ForgedCallerIsRejected` | ✅ |
| M8 | remove both committed-maximum checks in the mint callback | 1 failed — `test_5_AmountAboveTheCommittedMaximum…` | ✅ |

**7 of 8 caught.** M1's failure set is the interesting one: alongside the named ordering
tests it produces an **arithmetic underflow** inside
`invariant_TokensOwedIsFeesOnly` — the `ghostFeesCharged − ghostFeesCollected` subtraction
going negative is precisely what happens when principal is classified as fee yield, and it
is the mechanism that makes the invariant non-circular (§6). M4's blast radius (20 failures
including `setUp`) confirms the conservative direction is load-bearing throughout, not a
local nicety.

The suite is discriminating. It is not tautological.

---

## 4. Acceptance criteria — walked against the tree

Every criterion quoted from the accepted scope slice.

**AC-1 — callback negative suite, nine classes. ✓ Met.** See §5; this is the deepest
section of the review.

**AC-2 — zero standing approvals after every pool operation. ✓ Met, on two independent
legs.** Behaviourally, `_assertNoStandingApprovals` checks **2 tokens × 4 spenders** (pool,
Reserve, Rig, swapper) and fires after `mintPolPosition`, `increasePol`, `decreasePol`,
`buyVuxForPol`, and `harvestPol` — five call sites plus the all-operations sweep at
`TreasuryCallbackAuth.t.sol:259`. Structurally, `PolConduct.t.sol:135` asserts the deployed
runtime contains **no `approve(address,uint256)` call site at all**, so no allowance can
exist to check. I confirmed in source that payment in both callbacks is `safeTransfer`
(`src/StrategicTreasury.sol:1051-1052`, `:1077`) and that no `approve` appears anywhere in
the contract.

**AC-3 — VYRF ordering invariant. ✓ Met.** See §6.

**AC-4 — end-to-end scenario + the waterfall provably cannot receive POL fee yield.
✓ Met.** I ran the E2E myself (§9). The second half is arithmetic, and I verified it in
source rather than by test: `allocateRevenue` computes `total = toCompound + toHard + toOps
+ toSignalers` and reverts `RevenueExceedsRealized` unless `total ≤ realizedRevenue[asset]`
(`:751-753`). **No POL path writes `realizedRevenue`** — `_pokeCollectAndClassifyFees`
burns the VUX leg and transfers the WETH leg, `decreasePol` writes only the two basis
cells, `buyVuxForPol` writes no accounting cell at all. So POL fee yield is
*arithmetically unreachable* from the distribution surface rather than merely un-routed to
it. `burnVuxRevenue` likewise burns exactly `realizedRevenue[vux]`, never the treasury's
balance — so it cannot reach POL inventory either. M5 confirms a test would catch a
regression here.

**AC-5 — `buyVuxForPol` bounds; purchased VUX books as POL inventory principal; no mint
path. ✓ Met.** `sqrtPriceLimitX96` is passed into `pool.swap` and enforced by the venue
(negative test asserts the pool's own `"SPL"` revert at a limit equal to the current
price); `minVuxOut` is checked against the treasury's **own measured balance delta**
(`:987-988`), not a pool return value — M6 confirms the check is live. INV-26 is proven
three ways: the token refuses the treasury itself (`NotRig()`), the whole sleeve exercised
end-to-end adds zero supply, and `invariant_NoPolPathEverIncreasesSupply` holds over 16,384
calls. The "books as POL inventory principal" clause is **J-1** — §7.

**AC-6 — no `HardReserve.redeem` code path. ✓ Met, with real controls.** See §8.

**AC-7 — INV-25/26/27/28/29 handlers + FB-7/FB-8. ✓ Met.** Nine POL invariants, all at
`runs: 256, calls: 16384, reverts: 0` (I re-ran them). FB-7 is covered twice
(`test_FB7_APolPriceCollapseLeavesHardArithmeticBitIdentical`,
`test_FB7_FullyUnwindingPolLeavesTheReserveUntouched`) and FB-8 twice
(`…UnharvestedFeesAreCountedNowhere`, `…HarvestTimingChangesWhenNotWhere`), plus the
wash-trading-is-donation scenario the SDD threat model calls for (sdd.md:L950).

**AC-8 — `harvestPol` permissionless, parameter-free, no swap. ✓ Met.**
`function harvestPol() external nonReentrant` — no arguments, no role modifier; called from
a role-less `KEEPER` in test and from `address(0xC0FFEE)` in the E2E.
`test_HarvestPolPerformsNoSwap` asserts `slot0.sqrtPriceX96` is **bit-identical** across the
call. NFR-REL-2 is covered by `test_KeeperAbsenceCannotCorruptClassification` (six
unharvested trade rounds over six days collect correctly in one late call) and by
`test_FB8_HarvestTimingChangesWhenNotWhere` (eager vs. lazy paths reach the same
classification). A no-fee harvest is an honest two-zero-leg no-op rather than a revert,
which is the right choice for a permissionless entry point.

---

## 5. Callback authentication — the critical trust boundary

**Validation order matches sdd.md:L256 exactly**, and I read it off the source rather than
the report (`:1031-1053` mint, `:1061-1078` swap): (1) `msg.sender != pool`; (2) armed
context type; (3) token direction resolved through the **immutable** `token0` ordering;
(4) owed ≤ committed maxima; (5) `data.length != 0`; then `delete _ctx`; then payment by
`safeTransfer`. Authorization therefore requires **both** the exact immutable canonical pool
caller **and** a matching active one-shot context — neither alone suffices.

**The rig is genuinely the canonical pool.** `MockCallbackPool` is passed as both
`poolDeployer` and `pool` to a second treasury (`rigged`), and its `_one()` helper calls
`ITreasuryCallbacks(msg.sender).uniswapV3MintCallback(...)` — so the callback arrives with
`msg.sender == address(rogue) == rigged.pool()`. Every class below therefore holds *while
the caller is the canonical pool*.

| class | evidence | rejection |
|---|---|---|
| 1 forged caller | `test_1` — three callers incl. default and `NON_OPERATOR` | `CallbackUnauthorizedCaller` |
| 2 canonical pool, no context | `test_2` — `vm.prank(pool)` on the **real vendored pool** | `CallbackContextMismatch` |
| 3 wrong callback type | `test_3` — mint answered with swap CB and vice versa | `CallbackContextMismatch` |
| 4 wrong token/delta direction | `test_4` — both-deltas-positive, and the exact inverse | `CallbackDirectionMismatch` |
| 5 amount above committed max | `test_5` — one wei over, on each token of each callback | `CallbackAmountExceedsCommitment` |
| 6 nested/reentrant | `test_6` — callback re-enters `harvestPol` | `ReentrancyGuardReentrantCall` |
| 7 nonempty data | `test_7` — `0xdeadbeef` on both callbacks | `CallbackDataNotEmpty` |
| 8 duplicate second callback | `test_8` — see below | `CallbackContextMismatch` |
| 9 unconsumed authorization | `test_9` — pool takes the call, never calls back | `CallbackNotConsumed` |

**The duplicate-callback case, examined as the mandate required.** This is *not* inferred
from storage. `MockCallbackPool._fire()` in `DOUBLE_CALLBACK` mode invokes `_one()` twice
with identical arguments, both from its own address, inside the same armed outer operation.
The differential is exact and the test constructs it deliberately: at `:213-214` the same
operations with the same amounts **succeed** with one callback; the only thing that changes
before `:222-226` is `setMode(DOUBLE_CALLBACK)`, and both then revert. The assertion is
also discriminating in a way worth noting — `mintPolPosition` is called a second time at
`:223`, and had the revert come from `PolPositionExists` instead of
`CallbackContextMismatch` the `expectPartialRevert` would have failed. It did not, so the
second callback genuinely reached and failed check (2), having **passed** check (1).

**The positive control is real.** `test_Control_AWellFormedCallbackFromTheRigIsAccepted`
proves the rig can produce a callback the treasury accepts: the payment goes through
(`COMMIT_VUX / 2` leaves the treasury), the basis books, and no approval remains. Without
it, every "reverts" assertion in the file could have been green because the rig never
produced a usable callback at all. Class 2 additionally runs against the **real** vendored
pool, so the doctrine's core claim ("being the canonical pool is not authorization") does
not rest on a mock.

**Consume-before-pay.** The ordering is correct in the implementation — `delete _ctx` is
strictly before both `safeTransfer` calls in both callbacks, in a three-line window that
leaves no ambiguity. It is **not covered by any test**: mutation M2 (consume *after* pay)
passes all 349 tests. That is L-1. It is non-blocking because the failure mode it guards is
structurally unreachable in the deployed system — both payment tokens are constructor
immutables, `VUX` is `contract VUX is ERC20, ERC20Permit` with **no `_update` override and
no transfer hook**, and canonical WETH9 has none either, so nothing can re-enter during
payment. The duplicate and unconsumed classes that AC-1 *does* enumerate are both caught
(M3, and `test_8`'s differential).

**Reentrancy interplay is as designed, not as assumed.** The callbacks deliberately do not
take `nonReentrant` — they arrive while the outer operation holds it, so taking it would
deadlock every legitimate mint. `test_6` proves the guard still closes the nesting path
from inside a callback, which is exactly why not taking it is safe.

---

## 6. VYRF — fee versus principal, as a security property

**`harvestPol`** is `poke → collect → classify`, in one call, via
`_pokeCollectAndClassifyFees()` (`:1219-1236`): `burn(tickLower, tickUpper, 0)` credits
accrued fees to `tokensOwed`; `collect(…, max, max)` withdraws them; the VUX leg is burned
through `IVUXBurnable.burn` and the WETH leg `safeTransfer`red to `hardReserve`, both in the
same call, with `StrategicInflow(CLASS_POL_FEE_YIELD, …)` on each and a closing
`VyrfHarvest`. Neither leg is ever credited to `realizedRevenue`.

**`decreasePol`** (`:945-963`) is `poke + collect fees → burn(liquidity) → collect principal
→ book`, atomically and in that order, sharing the *same* classification helper so the two
paths cannot drift. The second `collect` uses `(max, max)`, which is correct precisely
because the first collect emptied `tokensOwed`: under the pinned v3-core semantics no swap
can interleave within one transaction, so what `burn(liquidity)` credits is principal to the
wei. This is on-chain ordering, not an off-chain reconstruction and not an accounting
approximation — I verified there is no reconstruction anywhere in the path.

**The `tokensOwed` invariant's fee bound is genuinely independent.**
`invariant_TokensOwedIsFeesOnly` asserts `owed ≤ ghostFeesCharged − ghostFeesCollected`,
where `ghostFeesCharged*` is accumulated by the handler from **its own swap inputs and the
pinned fee tier** — `Math.mulDiv(amountIn, feeTier, 1_000_000 - feeTier, Ceil) + 1` — never
from `collect`'s return and never from `tokensOwed`. `ghostFeesCollected*` does come from
the `VyrfHarvest` event, but that is what closes the loop rather than opening it: a
misclassification inflates the *classified* total, which trips
`invariant_VyrfClassifiedAmountsNeverExceedFeesCharged` directly and drives the subtraction
in the first invariant negative. M1 demonstrates both firing for real. Rounding direction is
also correct — the bound over-approximates by ≤1 wei per swap and is always used on the
large side of a `≤`, so it can never be vacuously satisfied by under-approximation.

**The general waterfall cannot receive POL fee yield** — §4, AC-4. Verified arithmetically
in source and confirmed by mutation M5.

Point-observations that back the ordering claim: `test_DecreasePolCollectsFeesFirstThen
SweepsPrincipalAtomically` asserts `S` fell by *exactly* the VUX fee leg, `B` rose by
*exactly* the WETH fee leg, the principal stayed in the treasury, and **`tokensOwed == 0`
on both tokens after the call**. `test_ReturnedPrincipalIsNeverRevenue` drives a large
one-way swap so one leg returns above its basis and the other below, and confirms neither
direction creates a revenue credit — impermanent gain surfaces as basis asymmetry, never as
revenue.

---

## 7. J-1 — POL VUX principal semantics (reviewer disposition)

**Determination: outcome 2 — the requirement is under-specified as to storage cell, and the
current implementation is a permissible realization.** The authority read as a whole leans
further, toward outcome 1; it supports nothing resembling outcome 3 or 4.

**Governing citations.**

- **sprint.md:L372 (AC-5)** and **sdd.md:L139**: "purchased VUX **books as POL inventory
  principal**". Neither names a cell.
- **sdd.md:L140**: the treasury owns "**exactly these** accounting cells" — a closed set in
  which `polVuxPrincipal`/`polWethPrincipal` are the only POL members.
- **sdd.md:L143**: those two are the "**cost-basis cells**" that `decreasePol` books
  *returned* principal **against** — and the implementation accordingly *retires* them on
  return (`:955-958`).
- **sdd.md:L168**: genesis quantization dust "remains treasury-held **POL inventory** —
  evented, principal-classified, never revenue". This is decisive: the SDD's own use of
  "POL inventory" attaches to value that is deliberately **outside** the basis cells, since
  `_addLiquidity` books only what the pool measurably took.
- **sdd.md:L147**: "bare transfers default to principal-side inventory, never revenue."
- **sdd.md:L523**: `VuxPurchasedForPol` is the SDD-prescribed event for "existing-supply POL
  sourcing (INV-26)" — exactly what the implementation emits.
- **SPEC §17.1 / §24.4 INV-25, INV-26, INV-28**; **SPEC §16** ("not revenue merely because
  custody changes or a position exits").

**Reasoning.** "Books as POL inventory principal" is a **classification** requirement, and
the implementation satisfies every component of it: the purchased VUX is principal (no
purchase path writes `realizedRevenue` — I checked the function body), remains in `S`
(INV-25), was sourced from existing supply without any mint (INV-26), is separately
observable through the event the SDD itself specifies, and enters the position basis when
it enters the position. Booking it into `polVuxPrincipal` at purchase time would **double
count**: the identical VUX is counted again when `increasePol` pays it to the pool, and
`decreasePol` would retire that doubled basis only once — permanently corrupting the cell
whose defined role is the position's cost basis. It would also break
`invariant_PolBasisNeverExceedsWhatWasPaidIn` ("cost basis is created only by paying the
pool"). The obvious repair, a third cell for undeployed inventory, is closed off by
sdd.md:L140's "exactly these"; I did not invent one, nor silently redefine an existing one.

Two further consistency checks support the reading. First, genesis provisions the 150,000
VUX by **plain transfer** and `mintPolPosition` books it — if the cells meant total POL
inventory rather than position basis, that transfer would need a booking hook that neither
the SDD nor the code has. Second, the implementation's own NatSpec on `burnVuxRevenue`
calls the treasury's loose VUX balance "**POL inventory principal**" while `polVuxPrincipal`
is named the basis — the two terms are used distinctly and consistently throughout.

**Not HITL.** One document states a classification and another closes a cell set; both are
satisfied simultaneously by the current code. That is not a contradiction and reserves
nothing to the operator. FR-9.1's five classes govern "every inflow/return"; an in-custody
asset conversion is neither, so no `StrategicInflow` class is owed for the swap.

---

## 8. POL sourcing and Hard Reserve separation

| requirement | verification |
|---|---|
| no post-genesis VUX mint can source POL | token-level refusal of the treasury itself (`NotRig()`), whole-sleeve zero-supply-delta test, and `invariant_NoPolPathEverIncreasesSupply` over 16,384 calls |
| `buyVuxForPol` uses existing supply, enforces both bounds | §4 AC-5; M6 confirms `minVuxOut` is live |
| POL **principal** WETH never enters `B` | `invariant_BackingIsAttributedIncludingTheVyrfLeg` — `B` equals genesis + attributed causes − redemptions, with the VYRF fee leg among the causes and POL principal pointedly not; a `decreasePol` misfiling principal as fee appears immediately as an unattributed delta |
| returned principal remains Strategic principal | `decreasePol` books to basis cells only; `test_ReturnedPrincipalIsNeverRevenue`; INV-28 invariant |
| POL failure cannot alter Hard arithmetic | FB-7 × 2, incl. a full unwind leaving the Reserve untouched |
| treasury-owned POL VUX not redeemed against Hard | below |

**FR-10.3, inspected independently.** The absence claim rests on three legs, and I checked
the controls rather than the conclusion.

1. **Compilation-unit leg — the strongest.** I dumped `metadata.sources` from the Sprint-5
   artifact myself. The treasury compiles against exactly: `src/StrategicTreasury.sol`,
   three `src/interfaces/` files (`ILSGModule`, `IStrategyAdapter`, `IVUXBurnable`),
   vendored OZ v5.2.0, and vendored v3-core **interfaces only**. `src/HardReserve.sol`,
   `src/Rig.sol`, `src/VUX.sol`, `IVUX`, and `IVUXMintable` are **absent** — the treasury
   cannot *name* `HardReserve.redeem`. `hardReserve` is a bare `address` whose only use in
   the whole file is `weth.safeTransfer(hardReserve, …)`.
2. **Bytecode leg — with a real negative control.** `_hasCallSite` anchors on the full
   three-instruction `PUSH4 sel; PUSH1 0xe0+s; SHL` idiom, bounds the shift to the eight the
   compiler can emit, and skips lossy shifts. It carries **six positive controls**
   (pool `mint`/`burn`/`collect`/`swap`/`positions`, the F-46 self-burn) *and* a **negative
   control**: `harvestPol()`'s four bytes are asserted **present** in the image while the
   scan still answers "no call site". That is the discrimination a permissive scan would
   fail, and it is the control an absence claim actually needs. `redeem(uint256,address)`,
   `mint(address,uint256)`, `burnForRedemption(address,uint256)`, and
   `approve(address,uint256)` all answer "no call site".
3. **Behavioural leg.** The full POL lifecycle runs while the treasury holds VUX and no
   `Redeemed` event is emitted anywhere; `B` never falls.

INV-27's other half — POL VUX non-voting — is proven from the ABI: no `stake`,
`setPreference`, or `claim` surface exists, against a positive control that `activateLSG` is
present.

---

## 9. Conservative liquidity inversion — measured, not estimated

**The substitution is conservative in the required direction, and I verified the reasoning
rather than accepting it.** v3 charges
`amount0 = ceil(L·Q96·(√B − √P)/(√B·√P))` and `amount1 = ceil(L·(√P − √A)/Q96)`. Inverting
needs `√A`/`√B`. The implementation substitutes the domain endpoints:
`√A → MIN_SQRT_RATIO`, `√B → MAX_SQRT_RATIO`. Since `x/(x − p)` is strictly decreasing in
`x` (derivative `−p/(x−p)² < 0`) and `1/(p − a)` decreases as `a` falls, and since the
constructor derives `tickLower = (MIN_TICK/spacing)·spacing`, `tickUpper =
(MAX_TICK/spacing)·spacing` — strictly *inside* the domain endpoints — **both** sides are
underestimates, hence so is their minimum. `Math.mulDiv` floors, which underestimates
again. The pool therefore can never demand more than the committed maxima, which is the
only property the callback's amount check depends on.

**Reproduced measurement.** On the 150,000-VUX / 300-WETH genesis-shaped position:

```
vuxDust = 19 wei      vuxPaid  = 149999999999999999999981
wethDust = 364 wei    wethPaid = 299999999999999999636
liquidity = 6708203932499369089234
```

**Exactly the claimed 19 wei VUX / 364 wei WETH.** I also fuzzed the conservativeness
property directly (256 runs over `vuxAmt ∈ [1e12, 140_000e18]`, `wethAmt ∈ [1e12, 1000
ether]`): the pool never took more than committed on either token. And M4 shows the suite
would catch a regression here loudly (20 failures).

**No unauthorized dependency.** `MIN_SQRT_RATIO`/`MAX_SQRT_RATIO` are local `private
constant`s (`:150-151`), not imports. The `metadata.sources` dump in §8 contains **no
`TickMath`, no `FullMath`, no `LiquidityAmounts`, and no v3-periphery** — only v3-core
*interfaces*. The dust is treated exactly as sdd.md:L168 requires: it never entered the
position, is never booked as basis, stays principal-side inventory, and is never revenue
(`test_QuantizationDustStaysPrincipalSideInventory` asserts basis + dust accounts for every
committed wei on both tokens).

---

## 10. Provenance, compiler identity, pool fidelity

`tools/provenance/run-all.sh` exits 0 end-to-end on my run ("All provenance gates and tests
passed"), with `POOL_INIT_CODE_HASH` reproduced byte-identical inside it.

**`foundry.toml` was not changed by Sprint 5** — established by `git diff --stat cf010810 --
foundry.toml remappings.txt` returning empty, not by reading the file. **No new dependency**
— `vendor/` and `remappings.txt` appear nowhere in `R`, and the §8 source dump shows the
only added imports are already-accepted census members (vendored `IUniswapV3Pool`, OZ
`SafeCast`).

**Effective settings, asked of the toolchain rather than inferred from profile appearance:**
`FOUNDRY_PROFILE=v3core forge config` resolves to `solc = 0.7.6`, `optimizer = true`,
`optimizer_runs = 800`, `evm_version = "istanbul"`, `bytecode_hash = "none"`,
`via_ir = false` — byte-for-byte the accepted refreeze §7 set. This matters here because the
profile-inheritance hazard has fired twice before; Sprint 5 gave it no new opportunity, and
I confirmed that rather than assuming it.

---

## 11. Fork / E2E evidence — my own determination

**I did not inherit the "no RH fork available" claim.** I searched independently:
`foundry.toml` has no `rpc_endpoints` block; there is **no `.env` file**; `.github/workflows/`
contains no RPC or fork configuration and `provenance.yml` states in-file that CI must not
require secrets; and a repo-wide scan for RPC-shaped URLs and RH chain identifiers returns
**nothing** outside prose. The only RH facts in accepted authority are the canonical WETH
**address** (`0x0Bd7…AD73`) and the YELLOW trust disclosure. There is no endpoint and no
chain id anywhere — the endpoint is an R-14 deployment-time fact.

**So the fork target is genuinely unavailable, and the classification is: an unavailable
external prerequisite that accepted authority already defers — not a blocking Sprint-5
failure and not a requirement contradiction.** The reasoning is textual:

- **prd.md:L489 (FR-11 acceptance)** — the criterion the SDD row itself points at — requires
  an "End-to-end scenario: fee accrual → classification → VUX burn observed with cause;
  WETH lands in `B`; principal legs stay Strategic." **No fork.**
- **Sprint-5 AC-4** restates exactly that, and likewise names no fork.
- **Sprint-5 Task 5.6** — the task-level instrument, which cites sdd.md:L862 — specifies an
  "**anvil-fork** harvest end-to-end". That is what was delivered.
- **sdd.md:L862** bundles "Genesis rehearsal + pool integration + VYRF harvest … on an
  RH-chain fork" into **one row whose method column is "forge script + anvil fork"**, and
  the genesis rehearsal half is explicitly Sprint 7 (sprint.md:L105). The row spans
  Sprints 5–8; its RH qualifier completes where the genesis rehearsal does.

**I reproduced the E2E myself**, against a live anvil v1.5.0 node over JSON-RPC:
`forge script script/PolVyrfE2E.s.sol:PolVyrfE2E --fork-url http://127.0.0.1:8545` → "Script
ran successfully", with all observables emitted and every `_require` passing:

```
polLiquidity 6708203932499369089234 | polVuxPrincipal 149999999999999999999981
vyrfVuxFeesBurned 52800988584206190418 | vuxBurnedOnTokenInSameTx 52800988584206190418
vyrfWethFeesToHard 120000000000000000    | backingDelta      120000000000000000
principalVuxReturned 74973599505707896904780 | principalWethReturned 150052819581424978293
```

The burn-cause pairing is exact (the `Transfer`-to-zero total equals the `VyrfHarvest` leg
in the same transaction), `B` rose by exactly the WETH leg, `harvestPol` was called by a
role-less address, returned principal retired basis and credited no revenue, and
`tokensOwed` was zero at the close. The one thing an RH fork would add is the **real**
canonical WETH's behaviour — precisely the YELLOW dependency Sprint 7's genesis rehearsal
and Sprint 8's E2E own. Recorded as carried residual **R-1**, not a Sprint-5 gap. It is kept
separate from Sprint 7's Q-6 native-WETH question and from R-14 deployment facts.

---

## 12. Findings

### L-1 (low) — consume-before-pay is implemented but not exercised by any test

- **Severity:** LOW — evidence gap, not an implementation defect.
- **Property:** sdd.md:L255-L256 and the Sprint-5 deliverable's "arm→validate→**consume**→pay"
  lifecycle.
- **Evidence:** mutation M2 moves `delete _ctx` after both `safeTransfer` calls in
  `uniswapV3MintCallback`; the full suite still reports **349 passed / 0 failed**. The
  duplicate-callback test cannot detect it, because the first callback still consumes before
  returning, so the second still finds `CTX_NONE`.
- **Why non-blocking:** the code is correct as written (`src/StrategicTreasury.sol:1049`,
  `:1075` — consume strictly precedes payment), and the failure mode is structurally
  unreachable: both payment tokens are constructor immutables, `VUX` is a plain
  `ERC20, ERC20Permit` with no `_update` override or transfer hook, and canonical WETH9 has
  none, so nothing can re-enter during payment.
- **Bounded remediation target (not for this node):** one negative test in
  `TreasuryCallbackAuth.t.sol` driving re-entry from inside the payment via the
  `reentryCallTarget` hook that already exists in `test/mocks/MockWeth.sol` and is currently
  unused by Sprint 5.

### L-2 (low) — tautological assertion at `test/treasury/TreasuryPol.t.sol:338`

- **Severity:** LOW — dead assertion; no coverage loss.
- **Evidence:** `assertEq(treasury.polVuxPrincipal(), treasury.polVuxPrincipal(), "and its
  basis unmoved")` compares a value with itself and cannot fail. The intended property — a
  harvest never moves cost basis — **is** correctly covered 18 lines later at `:356`
  (`assertEq(treasury.polVuxPrincipal(), basisBefore, …)` against a real pre-call snapshot).
- **Bounded remediation target:** capture `polVuxPrincipal` before the `harvestPol` call at
  `:317` and compare against it, or delete the line as redundant.

### Informational

- **I-1** — `_affordableLiquidity` can revert on `Math.mulDiv` overflow when
  `sqrtPriceX96` sits within ~1.8e19 of `MAX_SQRT_RATIO` (denominator collapse). This is a
  liveness edge at an absurd price regime, on an operator-gated function, and it **fails
  closed**. No safety impact; noted only so the audit need not rediscover it.
- **I-2** — `decreasePol` has no `PolPositionMissing` guard, so calling it on an empty
  position surfaces v3-core's `"NP"` rather than the named error. Cosmetic;
  operator-gated; fails closed. (`harvestPol`'s guard *is* necessary and present, because
  a zero-liquidity poke reverts `"NP"` in the pinned pool.)

### Carried residual

- **R-1** — RH-chain fork evidence, §11. Owned by Sprint 7 (genesis rehearsal) and Sprint 8
  (E2E), where the endpoint becomes an R-14 recorded fact.

---

## 13. Scope and mutation discipline

No Sprint-4 accepted LOW finding was reopened, and no operator-reserved future policy was
re-litigated. I confirmed the Sprint-4 carry-forwards are left exactly as accepted (J-3/R-9
accumulator semantics, permissionless `returnFor`, `recallFromStrategy`/`UnknownReturnAsset`,
the `activateLSG` doc mismatch) — none is touched by this sprint's diff.

Every mutation in §3 was applied to a **scratchpad copy** whose subject fingerprint was
verified identical before use. The implementation subject was never modified: the
mid-review and exit re-derivations both return
`37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a` over the same 12 files.

---

## 14. Terminal state

**`APPROVED`.** The exact Sprint-5 tree — fingerprint
`37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a`, 12 files — satisfies the
accepted Sprint-5 requirements at the project's acceptance threshold. Callback
authentication requires both the exact immutable pool and a live one-shot context and is
proven across all nine rejection classes with a valid positive control and a real
duplicate-callback differential; fee-versus-principal separation is on-chain ordering with
a non-circular invariant bound; Hard Reserve integrity, POL sourcing boundaries, and the
FR-10.3 no-redeem absence hold on controlled evidence; the liquidity inversion is
conservative in the required direction with its deviation measured, not estimated;
provenance, compiler identity, and pool fidelity are unchanged and re-verified from the
toolchain. J-1 is resolved on accepted authority without inventing or redefining an
accounting cell. Two low findings and two informational notes remain; none is load-bearing.

**Recommended next node:** `/audit-sprint sprint-5`.

---

*Reviewed by the Loa `/review-sprint sprint-5` node, 2026-08-14. Every claim above was*
*re-derived on the exact tree — including the full suite at both depths, the provenance*
*gates, the E2E against a live anvil node, the inversion measurement, and an 8-mutation*
*discrimination battery. Nothing was accepted on report. No implementation source, test,*
*build configuration, authority document, or provenance registry was mutated; nothing was*
*committed, pushed, or marked complete.*

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":2},"sprint_id":"sprint-5","ts":"2026-08-14T00:00:00Z"} -->
