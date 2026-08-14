# Sprint 4 Security Audit — Strategic Treasury I: Custody, Classification & Authority Boundaries

**Node:** `/audit-sprint sprint-4` (cycle-002, global sprint 4)
**Audited subject:** `72896e9d80d16b229a78e19f8f51c4ed117f622423970bdb491b7d0575d3966b` — **24 files**,
recomputed at node entry and again at node exit, and proven **exhaustive** in both directions (§1).
**Baseline:** `84abced4f90b9b8d11d960ebb438125b84914272`; implementation uncommitted, `HEAD` on `master`.
**Verdict:** **`APPROVED`** — 0 critical / 0 high / 0 medium / **4 low** (+4 informational)
**Terminal state:** `SPRINT_4_AUDIT_APPROVED` — awaiting `OPERATOR_ACCEPTANCE`

---

## Executive summary

Sprint 4 delivers the protocol's only privileged surface, and the central security question is
whether that privilege can reach the monetary core or convert principal into distributable
revenue. It cannot, and the reason is structural rather than procedural.

I verified the isolation claim on **three independent legs**, because no single one is sufficient.
(1) The treasury's compilation unit — read from the compiler's own `metadata.sources` — contains no
declaration of `HardReserve`, `Rig`, `VUX`, `IVUX`, or `IVUXMintable`, with positive controls
proving the method detects sources that *are* present. (2) The source contains no `assembly`, no
`delegatecall`, no low-level `call`, no `create`/`create2`, and — load-bearing — **no `approve` of
any kind**, so there is no mechanism to construct a call from a computed selector and no allowance
is ever granted to a strategy or module. (3) A shift-aware scan of the compiled runtime *and*
creation bytecode finds all ten positive controls via the exact `PUSH4 (sel >> s); PUSH1 (0xe0+s);
SHL` idiom — including the `s = 3` encoding of `burn(uint256)` that a naive four-byte search
misses — and finds **zero** of nine dangerous selectors. Leg (3) proves something leg (1) cannot:
`setFeeProtocol`/`collectProtocol` are *nameable* (the pool-owner interface is in the unit) yet are
never emitted.

The classification engine is sound. Every one of the five write sites into `realizedRevenue` credits
a **measured balance delta**, never an adapter-reported amount; there is no `declareProfit`, no
revenue setter, no oracle, and no mark or NAV cell in the 44-entry closed-world ABI. I confirmed by
independent proof-of-concept that no sequence creates credit without a corresponding asset arrival —
a lying adapter reporting `principalUnits()` inflated by `1e30` while delivering nothing credits
exactly zero — and that principal-side inventory the treasury already holds **cannot be laundered
into revenue**, because the treasury has no un-booked outbound path for it.

Two reachable behaviours deserved careful grading rather than dismissal. The **permissionless
`returnFor` misattribution** route is real and needs no operator: a malicious admitted strategy can
return its own deployed principal attributed to a *different* admitted pair, crediting the whole
amount as revenue while its own `outstandingPrincipal` stands. I graded the economics
independently rather than accepting the existing narrative, and it lands exactly where SDD §1.10
rule 4 places it — the attacker must surrender the assets, gains nothing, the proceeds reach an
operator-designated recipient rather than the attacker, and the protocol ends at most where a plain
theft would have left it. It is disclosed on-chain by `ReturnedFromStrategy`, which names the
credited strategy. Not stronger than the accepted J-3 semantics; recorded as LOW-3.

The one gap the independent review did not surface is **LOW-1**: `recallFromStrategy` routes into
the same classifier as `returnFor` but omits the `UnknownReturnAsset` guard, so an operator can
credit revenue for an asset that the accepted guard would reject on the `returnFor` path. It is
operator-gated, requires genuine asset delivery, cannot be triggered by an attacker, and — verified
by PoC — cannot launder existing holdings. Accepted authority attaches the guard to `returnFor` **by
name** (SDD §1.10 rule 2), so this is an under-specification and a defense-in-depth gap, not a
requirement violation. Non-blocking.

Nothing found is exploitable, reaches the monetary core, or breaches an accepted requirement.

| metric | independently measured |
|---|---|
| Subject identity | fingerprint reproduced; **24 files**, exhaustive both directions |
| Tests | **298 / 298** default profile; **298 / 298** at `FOUNDRY_PROFILE=ci` |
| Fuzz depth | **30** distinct properties at `runs: 10000` (review reported 14 — under-count, §13) |
| Invariants | **16** at `runs: 256, calls: 16384`; **0** reporting anything but `reverts: 0` |
| Sprint-4 tests | **154** (`test/treasury/*`) |
| Provenance gates | **8 / 8** green, both units force-rebuilt from source |
| `POOL_INIT_CODE_HASH` | **reproduced byte-identical** by my own control-validated Keccak-256 |
| Closed-world ABI | **44 / 44**, cross-checked from two independent artifact fields |
| Independent adversarial PoCs | **14 / 14** pass (`evidence/auditor-adversarial-poc.sol.txt`) |

---

## 1. Audit subject — identity and completeness

The mandate warns that a matching fingerprint over a listed manifest proves integrity of the listed
files and nothing about a 25th. Both directions were established.

**Direction 1 — every listed file retains its reviewed hash.** Recomputed from the file list, not
read from `evidence/subject-manifest.md`:

```
72896e9d80d16b229a78e19f8f51c4ed117f622423970bdb491b7d0575d3966b   (24 files)
```

**Direction 2 — no implementation-relevant file exists outside the manifest.** `git status
--porcelain -uall` (full untracked expansion, so collapsed directories cannot hide a member) over
`src test foundry.toml script tools vendor .github docs` returns **exactly 24 entries** and nothing
else. `--ignored` over the same roots adds nothing, so `.gitignore` conceals no member. A
whole-repository untracked scan excluding only the State Zone returns the same 24. `find` over
`src/v3core/` and `test/treasury/` — the two directories the manifest reaches by glob — enumerates
**only** `.sol` files, so no non-Solidity member escaped the `*.sol` pattern.

**Tracked deltas vs. baseline: 2 files only.** `foundry.toml` (+47 / −4) and
`test/mocks/MockWeth.sol` (+12 / −0). I read the `MockWeth` diff rather than the diffstat: it adds a
`transferFrom` override guarded on `transferFeeBp == 0` that delegates to `super`, so it is inert by
default and no earlier suite changes behaviour. `docs/` and `vendor/` are **byte-identical** to
baseline (`git status` empty for both). No Sprint-1…3 source file is touched.

**Node exit re-verification.** A transient audit-only PoC directory (`test/audit-poc/`, never
overlapping any subject file) was created, executed, and removed. The fingerprint and the 24-entry
completeness check were **both re-run after removal and both match**, so the audited tree is
byte-identical at exit to what it was at entry. The PoC source is preserved as durable audit
evidence at `evidence/auditor-adversarial-poc.sol.txt` (`.txt` so it can never be compiled).

---

## 2. Method

Every load-bearing claim below was re-derived. Where the implementation or review reported a
manifest, census, ABI, mutator set, or gate subject, I enumerated it from an independent source
rather than confirming its members. Where an *absence* is claimed, the detection method carries a
**positive control**; an absence scan without one proves nothing, and one of my own scans is
reported below precisely because its first form produced false positives.

---

## 3. Strategic classification integrity — the primary target

I derived the laws from SDD §1.10 (L285–L321) before reading the implementation.

**Every write into `realizedRevenue` is a measured delta.** There are exactly five sites, and all
five are mechanical:

| site | credit | measured from |
|---|---|---|
| `_classifyReturn` `:867` | `received − min(received, outstanding)` | `balanceOf` delta across the transfer |
| `harvestYield` `:527` | `balanceOf(this) − before[i]` | own-balance delta across `harvest()` |
| `redeemUnits` `:576` | `amountOut − basisReleased` | own-balance delta across `redeem()` |
| `allocateRevenue` `:661` | **decrement only** | — |
| `burnVuxRevenue` `:687` | **zeroise only** | — |

No adapter return value is ever credited. There is no `declareProfit`, no revenue setter, no
oracle, and no mark or NAV cell — confirmed against the 44-entry ABI, not the comments.

| accepted rule (SDD §1.10) | implementation | verified by |
|---|---|---|
| Returned deployed principal remains principal | `:861-867` nets principal-first, `principalPart = min(received, outstanding)` | PoC K, `TreasuryFlows.t.sol:85` |
| Marks are never revenue | no mark/NAV cell exists in the ABI at all | closed-world ABI (§13) |
| Arbitrary return assets rejected where required | `:470-472` — the accepted two-clause guard, verbatim | PoC B (and **LOW-1** for the recall path) |
| NETTING credits only beyond full principal return | `:863-867` | fuzz ×10,000; PoC C |
| CLAIM cannot reduce units via a "yield" claim | `:510-513` `unitsAfter < unitsBefore` reverts | fuzz ×10,000 |
| CLAIM credits a duplicated reward asset once | `:515-523` O(n²) dedup | **PoC E** |
| UNITIZED basis release conservative and conserved | `:562` `mulDiv(..., Rounding.Ceil)`; full unwind has `units == held` so `ceil(basis·u/u) == basis` | fuzz ×10,000 |
| Gain may create revenue; shortfall never negative revenue | `:574-579` — `lossPart` is **evented**, never subtracted | fuzz ×10,000 |
| `closeStrategy` cannot manufacture revenue | `:597-607` zeroes principal, never touches `realizedRevenue` | **PoC G** (multi-asset) |
| No discretionary reclassification path | none in the ABI; one write path per primitive | **PoC K** |

**Arithmetic safety, checked by hand.** `basisReleased ≤ basis` for all `units ≤ held`, so `:570`
cannot underflow; `units == 0 || units > held` reverts, so `mulDiv` never divides by zero; `:864`
cannot underflow by construction of the `min`; `:525` and `:566` revert (fail-closed) if a measured
balance *decreased*; `:852` reverts if an adapter reports shrinking units on deposit. Solidity
0.8.28 checked arithmetic makes the `allocateRevenue` leg sum revert rather than wrap — confirmed by
PoC C with `type(uint256).max`.

**No credit without delivery.** PoC E drives a CLAIM adapter that inflates `principalUnits()` by
`1e30`, lists a duplicated reward asset, and delivers **nothing**: credit is exactly zero. It then
delivers 1 ether once with the duplicate still present: credit is exactly 1 ether.

**Bare inflow is never revenue.** PoC F funds the treasury with 500 ether by plain transfer;
`realizedRevenue` stays zero and every nonzero allocation leg reverts `RevenueExceedsRealized`.

---

## 4. J-3 — security disposition

The accepted P0 model is a lifetime accumulator bounded by `Σ legs ≤ realizedRevenue[asset]`
(SDD:L312) with no custody or high-water condition. The reviewed consequence — a standing historical
credit later settled by fresh fungible principal — is intended, and I did not reopen it. Four
accepted authorities converge and I re-read each: SDD:L312 states the bound without a custody
condition; SDD:L295 and §1.10 rule 3 refuse **twice** to net losses against revenue; PRD §16 **R-9**
reserves qualifying-revenue computation *including realized-loss / high-water restoration* to
operator execution; PRD **FR-12.4** forbids any P0 surface from implementing that machinery.

**My task was the different one the mandate set: does the implementation allow anything *stronger*
than the accepted lifetime-credit model?** I tested each named route:

| candidate route | result |
|---|---|
| Credit without satisfying the mode-specific recognition rule | **No** — PoC E: lying units + zero delivery ⇒ zero credit |
| Double-crediting the same economic return | **No** — deltas are point-in-time; duplicate reward assets credited once (PoC E); reentrancy blocked (PoC L) |
| Increasing credit through principal-only returns | **Reachable** via caller-chosen attribution — graded in §5; bounded at "≤ theft" |
| Bypassing the allocation accumulator | **No** — PoC C: repeated partials exhaust exactly; +1 wei reverts; overflow reverts |
| Consuming more than credited revenue | **No** — PoC C and PoC J (earmark path) |
| Credit manipulation through arbitrary assets | **Confined** — per-asset mappings; a lying token can only distort its own cell. See **LOW-1** for the recall-path asymmetry |
| Role/caller combinations enlarging the J-3 consequence | **No** — PoC H: total role takeover leaves the core bit-identical |
| Hard Reserve or mint authority as settlement liquidity | **No** — structurally impossible (§7) |

**Disposition: the implementation is not stronger than the accepted model.** The one route that
increases credit from principal (§5) is the SDD §1.10 rule-4 class, which accepted authority
disposes of by name. No Sprint-4 change requested.

---

## 5. Permissionless `returnFor` — threat model, independently graded

Review LOW-2 sharpened the actor model correctly, and the mandate instructs me not to rely on the
existing fraud-vs-theft narrative. I graded the reachable economics myself.

**What an arbitrary caller can do.** `returnFor(strategy, asset, amount)` is permissionless and the
caller chooses the attribution target. The guard at `:470` admits the call when the pair has
outstanding principal **or** was ever admitted (`maturesAt` survives removal and close — deliberate,
because it is what makes post-write-off recovery bookable as revenue, J-4). When outstanding is
zero, the **entire** measured receipt credits `realizedRevenue`.

**The sharpest reachable sequence — confirmed by PoC A, no operator involvement:**

1. Operator admits S₁ and S₂ for WETH; deploys `P` to S₁.
2. S₁ calls `returnFor(S₂, WETH, P)` — permissionless.
3. `realizedRevenue[WETH] += P`; `outstandingPrincipal[S₁][WETH]` **still stands at `P`**.
4. Operator later allocates `P` as revenue; PoC A drives it to `opsRecipient` and asserts arrival.

**Economic grading.** The attacker must *surrender the assets* — PoC A asserts S₁'s balance ends at
zero — and receives nothing. The proceeds reach an operator-designated recipient, never the
attacker. Against the counterfactual of simple theft the protocol ends **no worse**: theft costs it
`P` outright, whereas here `P` returns and at worst leaves again as an unearned "operating expense".
This is precisely SDD §1.10 rule 4 — *"an adapter that ... mislabels flows to manufacture 'revenue'
can, by the same lie, simply steal the funds ... No mode extends what a malicious strategy could
already do."* The claim holds on the code, not merely in the prose.

**Separation of authority holds.** Creating credit and extracting value require **distinct**
authorities: creation is permissionless but value-consuming; payout is `OPERATOR_ROLE` throughout.
Blast radius is bounded by admission diligence, per-(strategy, asset) caps, the 24 h maturity, and
instant unblockable removal — all verified in §9.

**Detectability is a real control.** PoC A2 asserts the emitted
`ReturnedFromStrategy(S₂, WETH, 0, P)`: the event **names the credited strategy**, so revenue
attributed to a pair that never held principal is visible on-chain. Combined with R-9 reserving
qualifying-revenue computation to off-chain operator execution, the on-chain accumulator is an upper
bound rather than the distribution authority.

**Collusion / compromised operator.** Severity does not change relative to the accepted trust model:
an operator willing to collude can deploy principal to a strategy it controls directly (SDD §1.10
rule 4's own disposal), which is strictly simpler than this route.

**Disposition: accepted residual, not an implementation defect.** Recorded as LOW-3 for the
documentation inaccuracy only.

---

## 6. Revenue allocation surface

Verified against the corrected four-leg P0 surface, at the ABI and in sequence.

- **Aggregate bound.** `:658-661` — checked sum, then `RevenueExceedsRealized`, then decrement.
  PoC C: three partial allocations exhaust the credit exactly; the next wei reverts; overflow-shaped
  arguments revert on checked arithmetic rather than wrapping.
- **Accumulator cannot be bypassed by repetition** — the decrement precedes every transfer (CEI) and
  the function is `nonReentrant`. PoC L arms a hostile-token re-entry into `returnFor` from inside
  the ops transfer: it reverts and the credit is left intact.
- **`asset == VUX` rejected** `:655`; PoC I also confirms `signalerBudget[VUX]` can never be created.
- **Non-POL VUX revenue is burn-only** — `burnVuxRevenue` zeroes the credit before burning, and
  `IVUXBurnable.burn` acts on the caller's own balance.
- **Hard leg accepts only canonical WETH** `:656`.
- **No fifth leg, no `marketInfraBudget`** — absent from the 44-entry ABI (§13).
- **No stored waterfall percentages** — the treasury contains **zero** ratio/bp/percent/denominator
  constants (mechanical scan, §15). The only numeric constants are `ADMISSION_DELAY = 24 hours`,
  event class/kind tags, and the canonical Uniswap tick domain.
- **No P0 Operator Reserve machinery** — no credit ledger, accumulator, or sweep exists.
  `toOps` transfers immediately to a disclosed recipient and creates **no** standing entitlement.
- **`signalerBudget` cannot become a general pool** — fillable only by `allocateRevenue`, spendable
  only by `fundSignalerProgram` on an active module. PoC J: over-spend by 1 wei reverts; the exact
  amount is pushed and the earmark exhausts to zero, never negative.

The absent `50/25/20/5/0` waterfall is correctly **not** Sprint-4 code and is not graded as a defect.

---

## 7. Strategic-loss / Hard-Reserve failure independence

I attempted to falsify the defining property and could not.

**Structural isolation, three independent legs.**

1. **Compilation unit** (`metadata.sources`, parsed by me from the artifact): `src/HardReserve.sol`,
   `src/Rig.sol`, `src/VUX.sol`, `src/interfaces/IVUX.sol`, `src/interfaces/IVUXMintable.sol` are
   **absent**. Positive controls (`StrategicTreasury.sol`, `IVUXBurnable.sol`) are present, so the
   method detects what is there. The treasury cannot *name* a monetary-core authority.
2. **Call-construction capability** (source): no `assembly`, no `delegatecall`, no low-level `call`,
   no `create`/`create2`, no `selfdestruct`, and **no `approve`/`forceApprove`/`safeApprove`**. The
   treasury therefore has no mechanism to build a call from a computed selector, and grants no
   allowance to any strategy or module — the token authority it holds over third parties is nil.
   *This closes review I-3's residual*: the bytecode half being idiom-specific stops mattering when
   no idiom-independent construction path exists.
3. **Runtime reachability** (bytecode, controls-validated): all **10** positive controls found via
   the exact `PUSH4 (sel >> s); PUSH1 (0xe0+s); SHL` idiom — including `burn(uint256)` at `s = 3`
   and `recall(address,uint256)` at `s = 1`, both of which a naive four-byte search misses. All
   **9** dangerous selectors absent: `mint(address,uint256)`, `burnForRedemption(address,uint256)`,
   `redeem(uint256,address)`, `backing()`, `take(uint256)`, `treasury()`,
   `setFeeProtocol(uint8,uint8)`, `collectProtocol(address,uint128,uint128)`,
   `approve(address,uint256)`.

> **Method note.** My first scan enumerated all 32 shifts and reported all nine dangerous selectors
> as *present*. That was a false positive, not a finding: at `s ≥ 24` the shifted value collapses to
> one significant byte and matches noise. Constraining the scan to the real codegen idiom — where
> the shifted value still requires a `PUSH4` — resolved it. The shipped
> `TreasuryFailureBehaviors.t.sol::_hasCallSite` is **sound**: it bounds `s < 8` *and* requires the
> shift to be lossless (`shifted << s == sel`), which is exactly the set of shifts a compiler can
> use, and it carries two positive controls. Two independent methods now agree.

**Cross-check by ABI intersection.** The treasury's complete outbound selector set (enumerated from
its source) intersects the monetary core's surfaces only at VUX's ordinary ERC-20 members
(`balanceOf`, `transfer`, `transferFrom`) and `burn(uint256)` — all acting on the treasury's own
balance, conferring nothing any holder lacks. `HardReserve.redeem(uint256,address)` and
`IStrategyAdapter.redeem(uint256)` are **different selectors**, so a misdirected adapter call cannot
land on the Reserve's redemption.

**Runtime behaviour.** FB-5 bit-identity holds at 50 % / 80 % / 100 % loss across twelve core values
including `B`, `S`, the redemption quote at two sizes, the four VEM inputs, and the three authority
edges — and the fixture is **non-vacuous** (real `VUX`/`HardReserve`/`Rig`, real CREATE2 pool, and
it asserts the capital genuinely left). My own PoCs A, D, and H snapshot and re-assert the core
across misattribution, a hostile signal that names the Reserve directly, and a total role takeover.
`hardReserve` is reachable only as a plain `safeTransfer` destination on the one-way WETH accretion
leg. **FB-13, FB-15, FB-16 re-checked from the privileged surface and hold.**

The treasury also declares **no `receive`, no `fallback`, and no `payable` function**, so it cannot
take custody of native value at all.

---

## 8. Privilege topology

Audited over the **full inherited and declared external ABI**, not the 13 locally described mutators.

The 44 entries partition **exhaustively** with no remainder: 13 constants/immutables + 10 accounting
views + 6 inherited AccessControl + 13 operator mutators + 2 permissionless mutators. `grep -c
'onlyRole(OPERATOR_ROLE)'` returns exactly **13**, matching the mutator class 1:1. The only
non-role-gated state-mutating externals are `returnFor` and `harvestYield`, both permissionless by
accepted design (SDD §1.10 rule 2 and the CLAIM row) and both `nonReentrant`.

- `DEFAULT_ADMIN_ROLE` administers both roles (OZ default; `_setRoleAdmin` is never called), so it
  can escalate itself to `OPERATOR_ROLE`. **That escalation is confined to Strategic authority.**
  PoC H performs a total hostile takeover — attacker granted both roles, original admin evicted from
  both — and the monetary core is **bit-identical** afterwards.
- No Strategic role holder can mint VUX, burn another holder's VUX, move Reserve principal, change
  redemption, alter Rig routing, change VEM, replace an immutable identity, create upgrade
  authority, or create a core pause/recovery path — §7 establishes each structurally.
- **No `genesisOperator` argument exists**, so the external genesis caller cannot receive authority
  and there is no argument to misconfigure. All identities are `immutable`; there is no `setPool`,
  initializer, or upgrade path in the ABI.
- **Fail-closed under role loss.** If the sole admin renounces, roles freeze; if the sole operator
  renounces, every operator surface becomes permanently unreachable. Both directions remove
  capability rather than granting it — value can still flow *in* via the permissionless primitives
  but nothing can flow out. Fail-closed. Recorded as informational INFO-4.

---

## 9. Admission, caps, and strategy adversaries

| control | implementation | verified |
|---|---|---|
| Mode immutable while admitted | `:389-391` — change requires `!active` **and** an empty unit ledger | existing suite; reasoned through the remove→re-admit path |
| 24 h maturity, re-stamped per admission | `:400`; boundary exact at ±1 s | existing suite |
| Deployment blocked before maturity | `:841`, and `_eligibleForSignal` `:883` for the signal path | existing suite |
| Per-(strategy, asset) caps | `:843-844`, re-checked inside the shared `_deploy` | **PoC D** |
| Removal instant and unblockable | `:413-418` — one flag write, no delay, signal, or module in its path | **PoC D** (with an active module) |
| Recall not admission-gated | `:440` — deliberate; removal must never trap value | existing suite |
| Malicious adapter reentrancy | every value-moving external is `nonReentrant`; every non-guarded mutator is role-gated | **PoC L** |
| Measurement callbacks cannot mutate | `principalUnits()`, `rewardAssets()`, `currentAllocationSignal()` are `view` ⇒ `STATICCALL` | interface read |
| Partial / malformed returns | credited by measured delta, never by the `amount` argument | existing suite + `MockWeth` fee probe |
| Zero / extreme amounts | zero-delta paths short-circuit; checked arithmetic reverts on extremes | PoC C, PoC E |

A strategy may lose or steal Strategic capital within its accepted blast radius. I found **no route
by which it escapes that radius** or corrupts a classification or security boundary beyond the
rule-4 class graded in §5. The treasury grants no allowance, so a strategy's authority over treasury
assets is exactly what the treasury pushes to it and nothing more.

---

## 10. LSG P0 boundary

- `lsgModule` launches `address(0)`; `activateLSG`/`deactivateLSG` are `OPERATOR_ROLE` and evented.
- `ILSGModule` is exactly one `view`, so consumption is a `STATICCALL` — a hostile module **cannot**
  mutate state or re-enter during `deployMarginalBySignal`.
- Signal surfaces fail closed with `LSGInactive` before activation; length-mismatched answers revert
  `MalformedSignal` rather than being interpreted.
- **PoC D**: a hostile signal naming an unadmitted strategy *and* the Hard Reserve itself deploys
  **nothing** to either, clamps the admitted target exactly at its cap, and leaves the core
  bit-identical. Removal remains instant with the module active.
- `deployMarginalBySignal` routes through the **same** `_deploy` as manual deployment, so a signal
  can never be subject to weaker checks. It cannot cause admission, raise a cap, name a recipient
  outside the registry, or block removal/recall.
- `fundSignalerProgram` is bounded by `signalerBudget`, which only `allocateRevenue` can fill
  (PoC J). The module receives a push-then-call with **no allowance, role, or standing authority**.
- **No P1 mechanism ships.** A mechanical scan of the treasury and `ILSGModule` for stake, staking,
  epoch, delegation, ranking, accrual, weighting, snapshot, checkpoint, quorum, ballot, and vote
  returns **zero** non-comment hits. No 7-day age, 14-day epoch, first-24-hour window, or activation
  threshold exists. Absent P1 functionality is **not** graded as a defect.

---

## 11. `VuxPoolDeployer`

Audited as VUX-owned derivative source in the pinned `=0.7.6` domain.

- **Commitment gate** `:106` — `keccak256(abi.encode(msg.sender, salt)) == COMMITMENT`, bound to
  `msg.sender` rather than `tx.origin`. Possession of the preimage is insufficient; the suite proves
  both directions (wrong sender with the correct salt reverts; the committed caller succeeds).
- **Front-running** is closed by construction: the CREATE2 namespace belongs exclusively to this
  contract, and the only function occupying it requires the committed caller. Everything public in
  advance — predicted address, pair, fee, init-code hash — helps an adversary not at all.
- **Zero commitment rejected at construction** `:67` — otherwise the genesis primitive would be
  permanently unusable.
- **One-shot latch** `:105`/`:114`, on the *deployer* rather than the parameter tuple: a second call
  for a different pair is refused just as hard. Writing `canonicalPool` after `deploy` returns is
  sound — I verified at the vendored source that the pool constructor's **only** external call is
  `IUniswapV3PoolDeployer(msg.sender).parameters()`, so there is no re-entry path to race the latch;
  and a re-entrant call would fail the commitment anyway, since `msg.sender` would be the pool.
- **Domain checks** `:108-111`, all eight violations tested individually, with the legal edges
  (`fee = 999_999`, `tickSpacing = 16383`) accepted — so the check is not silently over-restrictive.
  The concrete `(fee, tickSpacing)` pair stays an R-14 deployment fact: domain-checked, never frozen.
- **Permanently dead `owner()`** `:58` — `address public constant owner = address(0)`, a property of
  the bytecode. I confirmed at the vendored pool source that `onlyFactoryOwner` requires
  `msg.sender == IUniswapV3Factory(factory).owner()`; with `factory` = this deployer and a constant
  zero owner, `setFeeProtocol` and `collectProtocol` are **unreachable forever**, and no residual
  factory governance surface exists.
- **CREATE2 reproduction.** I recomputed `POOL_INIT_CODE_HASH` myself with an independent Keccak-256
  carrying known-answer controls (empty string and `"abc"`), over the creation bytecode of the
  freshly force-rebuilt pool artifact: **22,728 bytes →
  `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`**, byte-identical to the
  accepted constant. The test-side derivation reads the same hash from the artifact rather than from
  the constant, so the identity test and the provenance gate close the loop without either assuming
  the other's conclusion.
- **Census unaffected** — the file lives under `src/`, is classified VUX-owned by every gate, and the
  immutable upstream census is unchanged and byte-identical.

---

## 12. Build, provenance, and resolved settings

**Resolved settings, not TOML text** (`forge config` per profile):

| setting | `[profile.v3core]` resolved | accepted refreeze §7 | |
|---|---|---|---|
| `solc` | `0.7.6` | `0.7.6` | ✓ |
| `optimizer` / `optimizer_runs` | `true` / `800` | `true` / `800` | ✓ |
| `evm_version` | `istanbul` | `istanbul` | ✓ |
| `bytecode_hash` | `none` | `none` | ✓ |
| `via_ir` | `false` | `false` | ✓ (Sprint-3 override holds) |
| `skip` | `[]` | — | ✓ (Sprint-4 override holds) |

`[profile.default]` and `[profile.ci]` resolve identically to each other on every bytecode-affecting
key (`0.8.28`, `via_ir = true`, optimizer 200, `prague`, `ipfs`, `skip = ["src/v3core/**"]`), so the
CI profile differs from default **only** in fuzz and invariant depth — the frozen unit is not
reachable by inheritance from either.

**The frozen unit is genuinely emitted, not merely configured.** Both units were force-rebuilt from
source: `out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json` carries **22,728 bytes** of creation and
**22,142 bytes** of runtime bytecode — real code, not an empty artifact — and
`out-v3core/VuxPoolDeployer.sol/VuxPoolDeployer.json` is present with **24,546 bytes** of creation
bytecode. Foundry is **v1.5.0** at commit `1c57854462289b2e71ee7654cd6666217ed86ffd`, matching the
pinned authority exactly.

**All 8 gates green** — census, pins, SPDX, notices, quarantine, launch hygiene, init-code hash,
runtime surface — each exercising the intended current subject. The §17 quarantine gate passes
**10/10** patterns, including *general revenue split ratios*, *LSG capital gate ($250K)*, and *LSG
readiness window (60 days)*, so no operator-reserved threshold or ratio was frozen into code.

**Disposition on the recurrence (review L-4).** The current tree is correctly contained at the level
that matters, and `verify-init-code-hash.sh` fails closed, so the existing gates protect the frozen
unit **today**. The security significance is the failure *class*: a green build that silently stops
emitting an artifact. The Sprint-4 instance was caught by a test failing to read an artifact, not by
a gate, and the existing gate only detects inheritance leaks that happen to alter bytecode. Recorded
as **LOW-4** with a future hardening recommendation; **not implemented here**, correctly outside
Sprint-4 scope.

---

## 13. Evidence quality and non-vacuity

I did not merely rerun the happy path.

- **Closed-world ABI**: 44 entries, cross-checked from **two independent artifact fields**
  (`methodIdentifiers` and the `abi` array) — both return 44, and the class partition leaves no
  remainder, so there is no unaccounted 45th selector. No `fallback`, no `receive`, no `payable`.
- **Fuzz**: **30** distinct properties at `runs: 10000`, of which 9 are the Sprint-4 accounting
  suite covering all three modes. The review reported 14; the true figure is higher, so the
  direction is conservative and creates no false-green risk (INFO-1).
- **Invariants**: **16** at `runs: 256, calls: 16384`; a filter for lines *not* reporting
  `reverts: 0` returns **0**.
- **Invariant non-vacuity**: the harness runs the treasury **and** the real monetary core in the same
  randomized sequences, and compares `B`/`S` against the **sum of their causes** rather than against
  a measurement of the subject. `test_EveryHandlerActionDoesRealWork` drives one of each action and
  asserts an `effectiveCalls()` increase per action, so a harness that silently short-circuited
  could not report green.
- **The removed J-3 invariant** is recorded in place at `TreasuryInvariants.t.sol:171-179` with its
  reason, and the behaviour it would have caught is pinned as a passing test and escalated. I read
  it directly: disclosure, not concealment.
- **Absence evidence**: every absence claim I relied on carries a positive control, and I discarded
  my own first scan when its controls exposed it as unsound (§7).
- **Fixture non-vacuity**: the FB-5 helper asserts the capital genuinely left and was not silently
  reclassified before comparing core values; the pool is real, not mocked, in the positive path.
- **My own 14 adversarial PoCs** pass against the exact tree and are preserved as evidence.

---

## 14. Accumulated monetary-core regression

The complete Sprint-1…3 suite passes unchanged at both depths inside the 298 total, including the
Rig invariant harness, the redemption arithmetic, the VEM property suites, and the
provenance/default-deny gates. No Sprint-1…3 source file is modified. No new Strategic privilege
path into VUX minting, Hard Reserve principal, redemption, Rig routing, VEM, or genesis authority
exists — established structurally in §7 rather than only by Sprint-4 tests.

---

## 15. Operator-reserved decisions

**None resolved.** The strategy registry ships **empty**; every concrete value a test needs is a
`test/`-only fixture. The `verify-quarantine.sh` gate passes 10/10 §17 patterns over
`src test script tools .github foundry.toml`.

Mechanical scan of the treasury: the **only** numeric constants are `ADMISSION_DELAY = 24 hours`
(the accepted single delay), the event class/kind tags, the canonical Uniswap tick domain
(`±887272`), and the tick-spacing bound `16384` — all protocol-invariant facts, not economic
parameters. **Zero** ratio/bp/percent/waterfall/denominator constants. `block.timestamp` appears at
exactly three sites, all relative maturity arithmetic; **no absolute date exists anywhere**,
satisfying F-50. R-9/R-10 execution scope is preserved by the call-time-arguments-only design.

Before writing each finding below I checked whether the missing behaviour is required by current
accepted Sprint-4 authority, absent entirely, or reserved elsewhere. Nothing here asks the
implementation to build reserved machinery.

---

## 16. Findings

### Severity tally

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 4 |

### LOW-1 — `recallFromStrategy` omits the `UnknownReturnAsset` guard that `returnFor` enforces *(new — not raised by the review)*

**Component:** `src/StrategicTreasury.sol:440-448` (`recallFromStrategy`) vs. `:469-476` (`returnFor`).

**Reachable sequence** (verified, PoC B): a strategy `S` is admitted for WETH. The operator calls
`recallFromStrategy(S, X, n)` where `X` was never admitted for `S` and has no outstanding principal.
Both paths funnel into `_classifyReturn`, which credits `received − min(received, outstanding)`; with
`outstanding == 0` the **entire** arriving delta becomes `realizedRevenue[X]`. The identical inflow
offered through `returnFor` reverts `UnknownReturnAsset`. PoC B asserts both halves in one test.

**Consequence:** an operator can create a revenue credit for an asset the accepted guard would reject
on the `returnFor` path, then distribute it through `allocateRevenue` (compound / ops / signalers —
the Hard leg still rejects non-WETH).

**Bounds — why this is LOW and not higher:**
- **Not attacker-reachable.** The operator names strategy, asset, and amount; a malicious strategy
  cannot force that choice, and can only add value by sending more than owed.
- **Requires genuine delivery.** The credit is a measured balance delta; no asset arrival, no credit.
- **No laundering path** (verified, PoC K). Principal-side inventory the treasury already holds
  cannot be routed out and pulled back as revenue: `deployToStrategy` books it as principal so the
  recall nets it back to principal, and the only other outbound legs are revenue-bounded and revert
  at zero credit. Only genuinely new external inflows can be credited.
- **No monetary-core reachability** (§7); blast radius confined to Strategic accounting for the
  named asset.

**Governing requirement:** SDD §1.10 rule 2 attaches the guard to `returnFor` **by name** — *"`returnFor`
accepts only assets with outstanding principal (or the admitted deployment asset)"*. Sprint AC-3
states the rule as *"arbitrary-asset returns rejected (`UnknownReturnAsset`)"* without naming a
function. The implementation satisfies the rule everywhere authority states it, so this is an
**under-specification and a defense-in-depth gap, not a requirement violation.**

**Smallest remediation envelope (future node, NOT Sprint 4):** lift the two-clause guard from
`returnFor` into `_classifyReturn`, or duplicate it at the head of `recallFromStrategy` — roughly two
lines plus one negative test. Deferring is reasonable; imposing it now is also safe, but no accepted
Sprint-4 criterion requires it.

### LOW-2 — `activateLSG` silently replaces a live module, contradicting its own docstring *(new)*

**Component:** `src/StrategicTreasury.sol:706-710`; docstring at `:712-713`.

The `deactivateLSG` docstring states *"A module swap is deactivate + activate; there is no in-place
replacement."* `activateLSG` writes `lsgModule = module` unconditionally. PoC M confirms a live
module is displaced in place, emitting only `LSGActivated(new)` with **no** `LSGDeactivated(old)`.

**Consequence:** no authority consequence — the call is operator-gated and evented, and the module
holds no allowance, role, or standing authority either way (verified §10). The defect is
observability and documentation: an indexer tracking module lifecycle sees an activation with no
matching deactivation, and the in-code comment misdescribes the contract's actual behaviour.

**Governing requirement:** SDD §1.11 records *"module swap = deactivate + activate"* as operator
procedure, not as a contract-enforced precondition; AC-6 requires only that both surfaces be
operator-gated and evented, which holds. Non-blocking.

**Remediation envelope (future):** either revert when `lsgModule != address(0)`, or emit
`LSGDeactivated(previous)` before overwriting — one to two lines. Alternatively correct the comment.

### LOW-3 — `evidence/fraud-vs-theft-argument.md` §2 understates the actor set *(confirms review L-2)*

§2 concludes *"both steps require the operator."* Step 2 (`returnFor`) is **permissionless**, so a
malicious admitted strategy creates the mislabeled credit **unilaterally**; only the payout is
operator-gated. I re-derived the actor graph and the economics from the code rather than from the
document (§5): the bounding conclusion **survives intact** — the route is not stronger than theft,
the attacker surrenders the assets and gains nothing, and the event discloses the misattribution.
Documentation accuracy only. **Not mutated during this audit**, per the mandate.

### LOW-4 — resolved-profile inheritance is a twice-observed hazard with no structural guard *(confirms review L-4)*

Non-blocking today: I verified resolved settings for all three profiles myself, both units were
force-rebuilt, the frozen artifact is genuinely emitted, and I reproduced `POOL_INIT_CODE_HASH`
byte-identically with an independently written, control-validated Keccak-256 (§11, §12). The
security significance is the failure class — a green build that silently stops emitting an artifact,
caught in Sprint 4 by a *test* rather than by a gate, because the existing gate only detects
inheritance leaks that alter bytecode. **Recommendation:** a future bounded hardening node comparing
`[profile.v3core]`'s **effective** settings against the accepted refreeze set. Correctly outside
Sprint-4 scope; **not implemented here.**

### Informational

- **INFO-1 — fuzz tally under-reported.** Actual coverage is **30** distinct properties at 10,000
  runs, not the 14 reported. Conservative direction; no false-green risk. Worth correcting in the
  next evidence touch.
- **INFO-2 — FR-10.3's bytecode residual is closed more strongly than argued.** Review I-3 notes the
  bytecode half is idiom-specific. It does not need to carry the claim: the treasury source has no
  `assembly`, `delegatecall`, low-level `call`, or `create`, so it cannot construct a call from a
  computed selector at all. Absence is structural, not encoding-dependent.
- **INFO-3 — `ledger.json` Sprint 4 remains `planned`** (review L-3). Independently confirmed as
  bookkeeping, not falsification: the file is **byte-identical to baseline**, and all nine Beads
  tasks (`vux-m80`, `vux-le0`, `vux-wqx`, `vux-1zg`, `vux-1sf`, `vux-h6f`, `vux-2nn`, `vux-3ll`,
  `vux-2tg`) are confirmed `closed` in `.beads/issues.jsonl`. Repair at operator acceptance.
  **Not repaired here**, per the mandate.
- **INFO-4 — role renunciation is fail-closed.** Losing the sole admin freezes role management;
  losing the sole operator makes every operator surface permanently unreachable. Both remove
  capability rather than granting it. Sprint 7 owns the grant-and-renounce ceremony; worth an
  explicit ordering check there.
- **INFO-5 — every ever-admitted (strategy, asset) pair is a permanent `returnFor` target.**
  `maturesAt` is never cleared by removal or close, so anyone may donate assets into a revenue
  credit. This is the intended "recovery after a write-off is revenue" semantic (J-4) and costs the
  caller real value. No action.

### Review findings carried forward without Sprint-4 action

**L-1** (carry PRD §16 R-9 qualifying-revenue / realized-loss / high-water restoration into the
future P1 waterfall design) is correctly **not** Sprint-4 implementation work — FR-12.4 forbids P0
from implementing it. I confirm the forward obligation and its rationale independently in §4.

---

## 17. Verdict

The exact reviewed Sprint-4 tree — fingerprint
`72896e9d80d16b229a78e19f8f51c4ed117f622423970bdb491b7d0575d3966b`, 24 files, proven exhaustive and
byte-identical at node exit — has **no blocking security, monetary-integrity, accounting, authority,
or provenance defect.**

Strategic classification integrity holds across NETTING, CLAIM, and UNITIZED under adversarial call
sequences; no route creates credit stronger than the accepted J-3 lifetime-credit model; the
permissionless `returnFor` threat boundary is real, bounded, disclosed, and correctly dispositioned
by accepted authority; the realized-revenue accumulator cannot be bypassed; Strategic failure at any
magnitude cannot reach the monetary core, which is isolated on three independent structural grounds;
privilege escalation is confined to Strategic authority even under total takeover; admission,
maturity, caps, and removal behave as accepted; the LSG P0 boundary is contained with no P1 leakage;
`VuxPoolDeployer` is sound and its CREATE2 identity reproduces; resolved v3-core build settings match
the accepted refreeze set and `POOL_INIT_CODE_HASH` reproduces byte-identically; provenance and
default-deny gates are green; accumulated Sprint-1…3 guarantees are unregressed; and the test, fuzz,
and invariant evidence is non-vacuous. **No operator-reserved decision was silently resolved.**

**APPROVED - LET'S FUCKING GO**

### Recommended next node

Operator acceptance / Sprint-4 landing preparation.

This audit deliberately did **not**: create the `COMPLETED` marker, update the Sprint Ledger status,
repair `ledger.json`, advance Beads state, commit, push, merge, or begin Sprint 5. Sprint closure is
an operator-gated lifecycle step and is left to the operator. No implementation source, test, build
configuration, authority document, or provenance registry was mutated by this node.

### Carried forward (no Sprint-4 action)

| item | owner |
|---|---|
| Extend the `UnknownReturnAsset` guard to the recall path, or hoist it into `_classifyReturn` (LOW-1) | next bounded treasury node |
| Reconcile `activateLSG` in-place replacement with its docstring, or emit `LSGDeactivated` (LOW-2) | next bounded treasury node |
| Structural guard over `[profile.v3core]` **effective** settings vs. the accepted refreeze set (LOW-4) | future provenance hardening node |
| Correct `fraud-vs-theft-argument.md` §2's actor set; correct the fuzz tally (LOW-3, INFO-1) | next documentation touch |
| Carry R-9 qualifying-revenue / realized-loss / high-water restoration into the P1 waterfall design (review L-1) | P1 waterfall design, before activation |
| Repair `ledger.json` Sprint-4 status; tidy branch/HEAD bookkeeping (INFO-3, review I-2) | operator acceptance |
| Role grant-and-renounce ordering, given fail-closed renunciation (INFO-4) | Sprint 7 `GenesisDeployer` |

---

*Audited by the Loa `/audit-sprint sprint-4` node, cycle-002, 2026-08-13. Every claim above was*
*re-derived adversarially on the exact tree; nothing was accepted on report. Absence claims carry*
*positive controls. Independent proof-of-concept source is preserved at*
*`evidence/auditor-adversarial-poc.sol.txt`.*

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":4},"sprint_id":"sprint-4","ts":"2026-08-13T18:40:00Z"} -->
