# Sprint 5 Security Audit — Strategic Treasury II: POL, Callback Authentication & VYRF

**Node:** `/audit-sprint sprint-5` (cycle-002, global sprint 5)
**Worktree / branch:** `C:\Users\0x007\vux-sprint-5`, `sprint-5`
**Baseline:** `cf0108109e428da0483b8470726f9e48ee740777` — HEAD, zero commits ahead, uncommitted
**Subject:** 12 files, fingerprint `37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a` — re-derived from git at node **entry and exit**

**Verdict:** `APPROVED` — 0 critical / 0 high / 0 medium / **3 low** (+2 informational, 1 process observation, 1 carried residual)
**Recommendation:** Sprint 5 may proceed to operator acceptance.

---

## 0. Executive summary

Review approval was treated as evidence, not as a security conclusion. Every load-bearing
claim was re-established adversarially, and the audit's central effort went where the mandate
pointed: *can any adversarial state cause fee/principal confusion?*

**It can — and I built a working PoC.** `decreasePol` makes **external token calls between the
fee collect and the principal burn** (the VYRF disposal: `VUX.burn` and the WETH transfer to
the Hard Reserve). Across that gap the canonical pool is **unlocked**. A re-entrant payment
token that swaps the pool there moves `feeGrowthInside` after the fee poke and before
`pool.burn(liquidity)`, so the principal collect sweeps the newly accrued fees and books them
as **returned POL principal**. The differential is exact to the wei:

| | swap outside the window | swap inside the window |
|---|---|---|
| VUX burned as VYRF fee yield | **7,325,346,449,782,639,753** | **0** |
| VUX booked as returned principal | 59,996,337,326,775,108,680,101 | **60,003,662,673,224,891,319,854** |

The entire VUX fee leg — 7.325 VUX that FR-11.1 requires to be burned — moved from "burned"
to "principal", and `S` did not fall.

**This is graded LOW and non-blocking**, because the enabling precondition does not exist in
the accepted deployment and is excluded by the accepted trust model: `VUX` is
`contract VUX is ERC20, ERC20Permit` with **no `_update` override and no transfer hook**
(verified in source), and canonical RH WETH is WETH9-shaped with no hook. The only route in is
a hostile upgrade of canonical WETH — the explicitly disclosed YELLOW dependency that
independently destroys `B ≡ WETH.balanceOf(HardReserve)` and redemption, making this vector
strictly redundant with a total-compromise scenario. It is recorded as **A-1** with a bounded
hardening, not as a Sprint-5 acceptance failure.

Everything else held under attack. Review's **L-1** and **L-2** are both **affirmed as LOW** —
and L-1's security argument came out *stronger* than review stated it (§4.4). **J-1's
outcome-2 survived** a targeted attempt to falsify it by sequence rather than by terminology
(§7). The `tokensOwed` bound's directionality was derived independently from the pinned
v3-core fee math rather than reproduced (§6).

---

## 1. Subject identity — re-derived, not accepted

```bash
BASE=cf0108109e428da0483b8470726f9e48ee740777
{ git diff --name-only "$BASE" -- . ; git ls-files --others --exclude-standard ; } | LC_ALL=C sort -u > R.txt
grep -E '^(src/|test/|script/|foundry\.toml$|remappings\.txt$)' R.txt > A.txt
xargs -a A.txt sha256sum | LC_ALL=C sort -k2 | sha256sum
```

| check | result |
|---|---|
| `git rev-parse HEAD` | `cf010810…` — equals baseline |
| commits ahead | **0** |
| subject file count | **12** |
| entry fingerprint | `37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a` ✅ |
| manifest identical to the review-node manifest | ✅ `diff` clean |
| `git status --porcelain -- src test script foundry.toml remappings.txt` | exactly 12 rows, nothing else |
| `docs/authority/`, `vendor/`, `prd.md`, `sdd.md`, `sprint.md` | absent from `R` — **byte-identical to baseline** |

The audited tree is therefore the reviewed tree, and no authority document moved between the
two nodes.

## 2. Independence of method

The four skills under `grimoires/loa/skills-pending/` were **not** promoted, audited, or
treated as authority. Two were consulted as hypotheses only; every conclusion below rests on
evidence produced in this node.

All destructive experiments ran against a **scratchpad copy** whose subject fingerprint was
verified byte-identical before use. The implementation subject was never mutated.

Reproduced independently in this node:

| evidence | result |
|---|---|
| full suite, default profile | 349 passed / 0 failed |
| full suite, `FOUNDRY_PROFILE=ci` | **349 passed / 0 failed** (10,000 fuzz runs) |
| `tools/provenance/run-all.sh` | **exit 0** — "All provenance gates and tests passed" |
| `tools/provenance/verify-init-code-hash.sh` | **exit 0** — `POOL_INIT_CODE_HASH` = `0xe34f199b…b8b54`, equal to the accepted constant; CBOR tail confirms `bytecode_hash = none` |
| v3-core `lock` coverage | read from vendored source: `mint` (L463), `collect` (L496), `burn` (L521) carry `lock`; `swap` self-locks (L615/L787) |

## 3. Findings

### A-1 (LOW, new) — external calls inside `decreasePol`'s fee→principal window permit fee/principal confusion under a re-entrant payment token

**Requirement at risk:** FR-11.1 ("Incremental VUX-denominated POL fee yield → **burn**"),
INV-29 (SPEC §24.4 #29), and the sdd.md:L260 ordering rationale.

**Mechanism.** `decreasePol` (`src/StrategicTreasury.sol:945-963`) calls
`_pokeCollectAndClassifyFees()` first. That helper does `burn(0)` → `collect(max,max)` → and
then **disposes** of the fees with two external calls (`:1227` `IVUXBurnable(vux).burn`,
`:1231` `weth.safeTransfer(hardReserve, …)`). Only *after* it returns does `decreasePol` call
`pool.burn(tickLower, tickUpper, liquidity)`.

sdd.md:L260 justifies the whole separation with *"no swap can interleave"* inside one
transaction. That is stated unconditionally but is **conditional on the two payment tokens
being non-reentrant** — an unstated premise.

**PoC (built in this node).** `DelayedSwapper` re-arms `MockWeth`'s one-shot on its first
invocation and swaps on its second, so the re-entry lands in the gap rather than inside
`collect`:

- First attempt (re-entry from *inside* `pool.collect`) **fails**: `LOK` — v3-core's `lock`
  modifier. This is a genuine protection and is reported as such.
- Second attempt (re-entry from the Hard-Reserve transfer, *after* `collect` returned)
  **succeeds**: `swapSucceeded=TRUE`, `swapErr=0x`. The pool is unlocked there.

Result, against an identical control that performs the identical swap outside the window:

| observable | control | attack |
|---|---|---|
| `VyrfHarvest` VUX leg (burned) | 7,325,346,449,782,639,753 | **0** |
| `PolPositionChanged` `vuxBack` (principal) | 59,996,337,326,775,108,680,101 | **60,003,662,673,224,891,319,854** |
| `wethBack` | 120,007,325,793,649,586,684 | 120,007,325,793,649,586,684 |
| subsequent `harvestPol()` VUX fees | 0 | 0 |

The two deltas are **equal to the wei** (`7,325,346,449,782,639,753`) and opposite in sign:
the fee leg was not lost, it was *reclassified* as principal. `wethBack` is unchanged because
the price at burn time is identical in both arms, which isolates the reclassification as the
only difference.

**Why LOW and not higher.** The precondition is a re-entrant payment token, and neither
exists:

- `VUX` — `contract VUX is ERC20, ERC20Permit`; **no `_update`/`_beforeTokenTransfer`
  override**; `burn(uint256) { _burn(msg.sender, amount); }` makes no external call. Verified
  in source, not assumed.
- canonical RH WETH (`0x0Bd7…AD73`) — WETH9-shaped, no transfer hook.

The only route is a hostile upgrade of canonical WETH, which prd.md:L160 already classifies as
an external YELLOW dependency "VUX cannot constrain", and whose realization independently
zeroes `B` and breaks redemption. Under the accepted trust model **no accepted invariant is
violated**, which is the test that separates a claim-precision defect from a breach.

*Counterargument recorded for the operator:* one could argue MEDIUM on the grounds that a
future WETH could gain a benign-but-reentrant notification hook without being hostile. I
discounted it because such hooks (ERC-777/1363 style) fire on sender or recipient, and every
address in this path — pool, treasury, Hard Reserve — is a protocol contract that registers no
hook. The operator may overrule this grading.

**Bounded remediation target (NOT for this node).** Move fee *disposal* after all pool
interaction, keeping fee *collection* first as sdd.md:L143 requires:

```
(vuxFees, wethFees) = _pokeAndCollectFees();   // poke + collect, no external disposal
pool.burn(tickLower, tickUpper, liquidity);
pool.collect(...);  book principal;
_classifyFees(vuxFees, wethFees);              // burn + transfer, after all pool interaction
```

This preserves the accepted collect ordering, leaves `harvestPol` behaviourally identical, and
removes every external call from the window. It is a hardening for a future sprint, not a
Sprint-5 acceptance blocker.

### L-1 (LOW, affirmed) — consume-before-pay is untested

**Disposition: review's LOW stands, and the security argument is stronger than review stated.**

I reproduced the gap (mutation moving `delete _ctx` after both `safeTransfer` calls leaves the
suite fully green), so the evidence gap is real. But the property is defended **three times
over**, not once:

1. **The context is already consumed** during payment (`:1049`, `:1075`) — the property itself.
2. **The pool is locked.** Callback payment happens inside `pool.mint`/`pool.swap`, both of
   which hold v3-core's lock. My PoC v1 demonstrates this empirically: a re-entrant token
   attempting a pool operation from that context reverts `LOK`. So even a hostile token cannot
   reach the pool from inside a callback.
3. **Every treasury entry point is `nonReentrant`** and the outer guard is held.

Review graded on (1) and token-hook absence; (2) is an independent structural barrier review
did not name. LOW confirmed, non-blocking. The remediation review proposed (a negative test
using `MockWeth`'s existing `reentryCallTarget`) remains the right fix and is now clearly
worthwhile, since this audit used exactly that facility to find A-1.

### L-2 (LOW, affirmed) — tautological assertion at `test/treasury/TreasuryPol.t.sol:338`

`assertEq(treasury.polVuxPrincipal(), treasury.polVuxPrincipal(), …)` cannot fail. Confirmed
dead, and confirmed harmless: the intended property is genuinely covered at `:356` against a
real pre-call snapshot. No security impact, no coverage loss. LOW stands.

### I-1 (informational) — `_affordableLiquidity` near-`MAX_SQRT_RATIO` fails closed

Tested directly by writing `slot0` to `MAX_SQRT_RATIO − 1`: `increasePol` **reverts**
(`Panic(0x11)`, arithmetic overflow) rather than returning a non-conservative liquidity. Fails
closed, exactly as required. Unreachable by trading: after a 100,000-WETH swap the price moves
only to `sqrtP ≈ 2.2e30` against `MAX = 1.46e48`.

### I-2 (informational) — liquidity adds are bounded in amount, not in price

sdd.md:L258 explicitly decides that "for liquidity adds, the committed `max*In` values are the
slippage bound". An operator adding at a manipulated price is therefore bounded in absolute
exposure but can acquire an unfavourable inventory mix. This is accepted design, borne
entirely by the Strategic Treasury (FB-7, sdd.md:L262), and it never touches `B`, redemption,
VEM, or minting. Noted so the audit trail records it as considered and accepted, not missed.

### P-1 (process observation) — the review artifact failed the framework's own verdict validator

`verdict-derive.sh --file …/engineer-feedback.md --gate review --require-trailer` exited **1**:
*"trailer says APPROVED but first line is not exactly 'All good'"*. The review gate was
therefore not machine-consistent. **Repaired in this node** (single-line prepend, no
substantive change); re-run exits **0** — `CONSISTENT: gate=review verdict=APPROVED`. The
audit gate carries no such first-line rule, confirmed against the accepted sprint-4 artifact
(exit 0). Disclosed rather than silently fixed.

---

## 4. Callback authentication — adversarial

### 4.1 Lifecycle completeness

`arm → validate → consume → pay → require consumed` is structurally complete. Exactly **two**
`_arm` call sites exist (`:983` swap, `:1159` mint) and **each is followed by
`_requireConsumed()`** (`:985`, `:1162`) — verified by enumeration, so no path can arm an
authorization without requiring its consumption.

### 4.2 Attack surface, enumerated

| attack | outcome |
|---|---|
| forged caller | `msg.sender != pool` → `CallbackUnauthorizedCaller` |
| canonical pool, no armed context | consumed/never-armed reads `CTX_NONE` → `CallbackContextMismatch` |
| wrong callback type | type mismatch → same gate |
| duplicate second callback from the canonical pool | first consumes; second finds `CTX_NONE` → reverts, taking the outer op with it |
| stale / replayed context across transactions | impossible: `_requireConsumed()` reverts the outer op, and a revert rolls storage back — a context cannot survive its transaction |
| attacker-armed context | all three arming entry points are `onlyRole(OPERATOR_ROLE)` |
| wrong token / delta direction | swap: exactly one positive delta, on the committed input token; mint: a token the op committed nothing to has maximum **0**, so any amount owed on it fails the commitment check |
| amount above committed maximum | `CallbackAmountExceedsCommitment` on each token of each callback |
| nonempty data | `CallbackDataNotEmpty` |
| nested / reentrant | outer `nonReentrant` + already-consumed context + v3 `lock` |
| standing approvals | **no `approve`/`forceApprove`/`safeIncreaseAllowance` appears anywhere in the source**; payment is `safeTransfer`; the runtime carries no `approve(address,uint256)` call site |

### 4.3 Trust roots

The constructor cross-binds the identities rather than trusting arguments: `pool.factory() ==
poolDeployer`, `IUniswapV3Factory(poolDeployer).owner() == address(0)`, and — load-bearing —
`pool.token0()/token1() == sorted(vux, weth)`. A hostile payment token therefore implies a
hostile pool implies a hostile pool deployer, all of which are genesis constructor arguments
(Sprint 7 / R-14 scope), not anything reachable post-deployment. There is no `setPool`,
initializer, or wiring authority at any time.

### 4.4 Does any reachable composition defeat consume-before-pay?

**No.** See L-1 above: the context is consumed before payment, the pool is locked during the
callback (empirically `LOK`), and every treasury entry point is `nonReentrant`. The
composition that *does* bite — A-1 — is not in the callback path at all; it is in
`decreasePol`'s post-`collect` window, where the pool is unlocked.

## 5. VYRF ordering

`harvestPol` is `poke → collect → classify`, and because the classification is its **last**
action there is no window: a re-entrant token there could only accrue fees for the next
harvest, never reclassify anything. **A-1 is `decreasePol`-only**, which bounds the finding.

`decreasePol` performs collection in the accepted order — fees are collected before
`burn(liquidity)`, and the principal collect uses `(max, max)` correctly because the first
collect emptied `tokensOwed`. Nothing else can credit `tokensOwed`: v3 keys the position on
`msg.sender`, so only the treasury's own `burn` touches it, and both of its `burn` call sites
are immediately followed by a `collect`.

## 6. The `tokensOwed` bound — directionality derived, not reproduced

The invariant asserts `owed ≤ ghostFeesCharged − ghostFeesCollected`. I established the bound
from the pinned v3-core math rather than from the invariant's green result:

- **Upper bound is genuinely upper.** In v3's exact-input `SwapMath`, the fully-consumed branch
  charges `ceil(amountRemaining · fee / 1e6)` and the price-limited branch charges
  `mulDivRoundingUp(amountIn, fee, 1e6 − fee)` on an `amountIn` no larger than the input. The
  handler's `ceil(amountIn · fee / (1e6 − fee)) + 1` dominates **both**, since
  `fee/1e6 < fee/(1e6 − fee)`. The full-range position has no initialized interior ticks, so a
  swap is a single step and no multi-step summation escapes the bound.
- **Position credit rounds down.** `tokensOwed` is credited by `liquidity · Δ feeGrowthInside /
  Q128`, floored — so credited ≤ charged.
- **Contamination direction.** `ghostFeesCollected` does come from the subject's own
  `VyrfHarvest` event, but a misclassification *inflates* it, which **tightens** the bound and
  underflow-reverts the unsigned subtraction. The subject-derived term is the detector, not the
  blind spot. Confirmed by mutation: reordering `decreasePol` produced
  `[FAIL: panic: arithmetic underflow or overflow]` exactly as predicted.
- **The complementary bound** `ghostVyrfVuxBurned ≤ ghostFeesChargedVux` closes the other
  direction.

## 7. J-1 — attacked by sequence, not re-litigated by terminology

Review resolved J-1 as outcome 2. I did not reopen the terminology; I tried to **falsify it
with an adversarial sequence**:

| attempted sequence | result |
|---|---|
| `buyVuxForPol` → `increasePol` (does the same VUX get counted twice?) | No. The purchase writes **no** accounting cell; basis is created only by paying the pool. |
| `decreasePol` returning more than basis (price move) | Basis floors at 0 (`basis > back ? basis − back : 0`) — no underflow, no negative revenue. |
| Extract purchased VUX as revenue | Impossible: `allocateRevenue` rejects `asset == VUX`; `burnVuxRevenue` burns only `realizedRevenue[vux]`, never the balance; no POL path writes `realizedRevenue`. |
| Use `buyVuxForPol` to retire `polWethPrincipal` | It does not touch either cell — WETH spent was loose dry powder, so nothing is retired or invented. |
| Non-operator manipulation of either cell | All POL mutators are `onlyRole(OPERATOR_ROLE)`; the one permissionless entry (`harvestPol`) touches neither cell. |

Outcome 2 **survives**. Note that even under the A-1 attack J-1 holds: the inflated `vuxBack`
retires *more* basis, and basis only ever falls — no revenue is created in either direction.

## 8. Impossibility claims

| claim | independent basis |
|---|---|
| no treasury → `HardReserve.redeem` path | `HardReserve.sol`/`Rig.sol`/`VUX.sol`/`IVUX`/`IVUXMintable` are **absent from the treasury's `metadata.sources`** — it cannot name the function. `hardReserve` is a bare `address` whose only use is `weth.safeTransfer(hardReserve, …)`. Runtime scan finds no `redeem(uint256,address)` call site, under a negative control (`harvestPol()`'s bytes present in the image, still answering "no call site") and six positive controls. |
| no post-genesis mint sources POL | `VUX.mint` is `onlyRig`; the token refuses the treasury itself (`NotRig()`); no `mint(address,uint256)` call site in the runtime; `invariant_NoPolPathEverIncreasesSupply` holds over 16,384 calls. |
| no Reserve-funded POL | The treasury calls **no function** on `hardReserve`; the Reserve's only outbound path is `redeem`, which requires burning the caller's own VUX and has no treasury call path. |
| general revenue cannot capture POL fee yield | `allocateRevenue` is bounded by `realizedRevenue[asset]`; no POL path writes that cell, so POL fee yield is *arithmetically* unreachable from the distribution surface. |

## 9. Provenance, compiler identity, pool fidelity

`foundry.toml` and `remappings.txt` are **absent from the repository delta** — unchanged, so
the twice-observed profile-inheritance hazard had no new opportunity to fire. `vendor/` is
untouched. The treasury's compilation unit contains only VUX-original source, vendored
OpenZeppelin v5.2.0, and vendored v3-core **interfaces** — no `TickMath`, no `FullMath`, no
`LiquidityAmounts`, no v3-periphery, no copied helper. `POOL_INIT_CODE_HASH` reproduces
byte-identical and the CBOR tail confirms `bytecode_hash = none`. All provenance gates exit 0.

## 10. Liquidity inversion — conservative in every regime

The substitution `√A → MIN_SQRT_RATIO`, `√B → MAX_SQRT_RATIO` is conservative because
`x/(x − p)` decreases in `x` and `1/(p − a)` decreases as `a` falls, and the constructor
derives `tickLower`/`tickUpper` *strictly inside* the domain endpoints. I checked all three
price regimes, not just in-range: below range the true charge is one-sided and larger per unit
of liquidity (so the estimate stays under), above range likewise, and `Math.mulDiv`'s floor
underestimates again. Empirically: conservativeness held at extreme prices in both directions,
and the one corner where the arithmetic breaks down **fails closed** (I-1).

## 11. R-1 — carried residual, re-evaluated

Sprint-5 security does not depend on behaviour unestablished by the accepted local evidence, so
R-1 remains a residual rather than an audit failure. A-1 does, however, give Sprints 7/8 a
**concrete, bounded check to add** to the genesis rehearsal: confirm that the real canonical RH
WETH's `transfer` makes no external call. That is a static property of the deployed token, not
something requiring a fork. Q-6 (native-WETH verification) and R-14 (deployment facts) remain
separate and untouched.

## 12. Terminal state

**`APPROVED`** — 0 critical / 0 high / 0 medium / 3 low (+2 informational, 1 process
observation, 1 carried residual). No finding is load-bearing against the accepted Sprint-5
requirements under the accepted trust model, and no code or test change is required for
acceptance. A-1's hardening and L-1's negative test are carried forward as bounded future
work, not as Sprint-5 blockers.

**Exit identity re-derived:** 12 files, fingerprint
`37fa6943f8190acb679e08931a950e3c2e8697c1eefd058a5a6a75cf1d06475a` — unchanged from entry. No
implementation source, test, build configuration, authority document, or provenance registry
was mutated in this node.

**APPROVED - LET'S FUCKING GO**

---

*Audited by the Loa `/audit-sprint sprint-5` node, 2026-08-14. Review approval was consumed as*
*evidence, never inherited as a conclusion. Every claim above was re-derived on the exact tree;*
*the central finding is supported by a working proof-of-concept with an exact conservation*
*differential, built against a scratchpad copy that reproduced the subject fingerprint*
*byte-for-byte. Nothing was committed, pushed, landed, or promoted.*

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":3},"sprint_id":"sprint-5","ts":"2026-08-14T00:00:00Z"} -->
