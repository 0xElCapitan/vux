# Sprint 8 — Security Audit (Paranoid Cypherpunk Auditor)

**Verdict:** `APPROVED - LET'S FUCKING GO`
**Node:** `/audit-sprint sprint-8` — final adversarial technical gate of cycle-002. No remediation, no
operator acceptance, no commit, no landing, no deployment.
**Branch:** `sprint-8` · **HEAD:** `6395cabb4deee5bae50ac79c8094053484261819` · 0 ahead · 1 worktree ·
`master` = `origin/master` = HEAD (baseline untouched).
**Counts:** **0 critical · 0 high · 0 medium · 5 low · 8 informational.** The review's four LOWs are
carried unchanged; one of them (L-2) is subsumed and extended by A-2 below.

The frozen guarantees hold. `N = B/S` is monotone non-decreasing under every reachable operation I
could construct, including adversarial genesis parameters; Strategic capital cannot reach the Hard
Reserve in any direction I could find; genesis is atomic, self-verifying and non-griefable; and the
production-secret boundary is clean when I check it myself rather than through the gate that claims
it. The five LOWs are all in **evidence and launch tooling**, not in the monetary core — three of them
are cases where a control that reads as load-bearing is, on inspection, not actually wired to the
thing it appears to protect.

---

## 1. Audit-tree identity — derived from the tree, not read from the report

I re-derived the subject before reading any Sprint-8 artifact, from `git status --porcelain` plus
`git add -An --dry-run`, using the recorded method (`sha256` over path-sorted `<sha256>  <path>` lines
joined by `\n`, no trailing newline, `LC_ALL=C` ordering).

| Group | Review-approved | Independently derived (entry) | Re-derived (exit) | Result |
|---|---|---|---|---|
| A — implementation subject (16) | `407d0bab…55764` | identical | identical | **MATCH** |
| B — activated authority (2) | `1016fe25…54437` | identical | identical | **MATCH** |
| C — lifecycle evidence (16) | `0ffd9b1d…29c72` | identical | identical | **MATCH** |
| Combined (34) | `f71d5486…e564b` | identical | identical | **MATCH** |

All four reproduced on **first** computation at entry, and again at exit after every probe and a full
`run-all.sh` execution. Full values in §12.

**The manifest's exhaustiveness claim is true, and I checked it rather than accepting it.** The
working-tree change set is exactly: the 34 subject files; `subject-manifest.md` (self-excluded);
`engineer-feedback.md` and `engineer-feedback-2.md` (review outputs, deliberately ungrouped); five
hook/retrospective trajectory files; and the declared State-Zone exclusions (`.beads/`, `.run/`,
`grimoires/loa/analytics/`, `ledger.json.bak`, `ledger.json.lock`, `skills-pending/`). Nothing else.

**The frozen product surface is byte-unchanged.** `git diff 6395cabb -- src/ test/ docs/ foundry.toml
remappings.txt lib/ grimoires/loa/{prd,sdd,sprint}.md` is empty, and `git status --porcelain` reports
no modification to any of them. `6395cabb` is the Sprint-7 landing commit, which is what makes the
G-1 evidence reuse in §9 admissible.

**The historical review artifact is intact.** `engineer-feedback.md` =
`6630a959dd5bde5fd8390ee716e395e215cb9f96b297d069c60c252c34dc4b78` — exactly the digest the re-review
recorded. Neither review artifact was modified.

**All nine authority pins in `census.sh` reproduce against the bytes on disk**, including the two new
static-analysis pins (`7769b4e3…`, `d4f9f36e…`) and the updated `THIRD_PARTY_NOTICES.md`
(`40abb254…`). The `census.sh` delta is exactly the TPN hash plus the two new authority pins — nothing
else moved.

---

## 2. Attack and probe summary

| # | Probe | Result |
|---|---|---|
| P1 | Repoint all four INV-37 `ci-gate` citations at `LICENSE` | **Gate PASSED**, exit 0, "37/37 rows carry named evidence" → **A-1** |
| P2 | Identical substitution with kind `review-checklist` | **Gate FAILED** correctly → isolates the *exemption*, not the check, as the cause |
| P3 | Word-boundary discrimination `\bFB-1\b` vs `FB-11 FB-12 FB-18`, `\bINV-3\b` vs `INV-37 INV-30` | Correct in both directions — the M-2 check is sound |
| P4 | `git diff --quiet` on the untracked matrix paths | exit 0 → anti-hand-edit assertion is currently vacuous → **INF-2** |
| P5 | Sweep's own five patterns against a synthetic filled runbook slot (private key, salt, EOA, relay token) | **All five MISS** → **A-2(b)** |
| P6 | `git ls-files -- grimoires/loa/a2a/sprint-8/` | **0 of 436** scanned files → **A-2(a)** |
| P7 | Independent secret sweep, 683 working-tree files, separator-agnostic, tracked + untracked | **Clean** — only hit is this audit's own synthetic probe echoed into `.run/audit.jsonl` |
| P8 | MetaMask non-distribution claim vs the shipped static export | **Claim holds** — 4 `metaMask` hits, all in wagmi's injected-target table; 0 `MetaMaskSDK`/`sdk-communication-layer`/`consensys`/`Non-Commercial` |
| P9 | Every `slither`/`crytic` invocation, address-target, RPC and `read-storage` path in the repo | **Exactly one invocation**, local directory target → D-S2 structurally unreachable |
| P10 | `--config-file` search across `tools/`, `.github/`, `script/`; root-level `slither.config.json` | **Never passed; absent at CWD** → **A-3** |
| P11 | EIP-3860 / EIP-170 measurement from the artifacts | 47,609 B creation — reproduces the Sprint-7 audit exactly → **A-5** |
| P12 | `lsgModule` reference sweep over `removeStrategy` / `recallFromStrategy` / `closeStrategy` | **Zero** references → FB-11 clause 2 holds mechanically |
| P13 | YELLOW disclosure: `web/lib/truth-copy.js` vs `prd.md:722` | **Byte-identical** |
| P14 | Full `run-all.sh` (11 gates + suite) | **454 passed / 0 failed / 10 skipped**; 10/11 gates green |

All probe mutations restored byte-for-byte and verified: `build-matrix.mjs` → `94e58d5d…`,
`traceability.json` → `9d016cc1…`, `traceability-matrix.md` → `dc918719…`. Backups were taken before
mutation and restoration was by copy, not `git checkout`.

**The one gate that failed locally is toolchain absence, not a tree defect, and I am not hiding it.**
`verify-static-analysis.sh` fails on this Windows host with `slither-analyzer is 'not installed'` /
`slither not importable`. Every other check inside that gate passed — authority byte-identity,
interpreter range (`python 3.11.15` selected correctly after `python3` resolved to the Microsoft Store
stub and was rejected by the range probe rather than trusted by name), D-S2 no-RPC, isolated
build-info, `forge lint` 0 high / 4 medium matching the recorded dispositions. **The gate failed
closed on a missing analyzer, which is the behaviour it is supposed to have**, and is itself a
negative demonstration I did not have to construct.

---

## 3. Monetary-core disposition — **SOUND**

I attacked the composition, not the units.

**The core invariant is `N = B/S` monotone non-decreasing, and it holds exactly.**

- **VEM is algebraically tight.** `qSafe = floor(dR·S_pre / B_pre)`, `qMint = min(qRaw, qSafe)`, so
  `B_pre·qMint ≤ B_pre·floor(dR·S_pre/B_pre) ≤ dR·S_pre` with no slack. `N' ≥ N ⟺ qMint ≤ dR·S/B` is
  therefore satisfied by construction (`src/Rig.sol:566-573`).
- **Adaptive routing cannot under-serve issuance.** `dNeed = ceil(qRaw·B_pre/S_pre)`
  (`src/Rig.sol:526`, `Math.Rounding.Ceil`) is exactly the amount that makes `qSafe ≥ qRaw`; the
  ceiling direction is the correct one. `hardTarget = min(retained, max(hardFloor, dNeed))` and
  `strategicLeg = retained − hardTarget`, so **Strategic is the residual and the Reserve is served
  first** — the Hard-Reserve-primacy ordering is structural, not policy.
- **No underflow anywhere in the split.** `retained = p − floor(0.8p) = ceil(0.2p) ≥ floor(0.12p)` for
  all `p ≥ 0`, so `hardFloor` never underflows; `hardTarget ≤ retained` so `strategicLeg` never does;
  `kingLeg + hardTarget + strategicLeg ≡ price`, so the Rig retains nothing (confirmed by
  `invariant_TheRigHoldsNoValue`, 1024 calls, 0 reverts).
- **`dR` is measured, never intended, and the check is a strict equality.** `src/Rig.sol:369-370`
  reverts unless the observed Reserve delta equals the routed amount exactly. I worked the
  reentrancy cases both ways: an inflow during settlement makes `dR > hardContribution` and reverts;
  an outflow (e.g. a reentrant `redeem`) makes it smaller and reverts, or underflows the subtraction
  and panics. **Fail-closed in both directions.** A fee-on-transfer or rebasing WETH also fails here
  rather than silently redefining `B`.
- **Every direction that could loosen VEM is closed.** Redeeming before a take *raises* `N` and
  therefore *lowers* `qSafe`; donating WETH raises `B` and lowers `qSafe`; burning VUX lowers `S` and
  lowers `qSafe`. `S` can only be increased by `Rig`, which is VEM-bounded. I found no reachable
  operation that decreases `N`.
- **Redemption is exact and Reserve-favouring.** `Math.mulDiv` full-precision, floor, CEI ordering,
  `nonReentrant`, `to == 0` rejected, burn source hard-wired to `msg.sender` with the token-side
  `onlyReserve` gate as an independent second barrier (`src/HardReserve.sol:150-173`,
  `src/VUX.sol:123-126`). The supply floor makes `B ≥ 1` permanent: after any redemption
  `B' ≥ ceil(B/S) ≥ 1`, so `_vem`'s divisor can never reach zero post-genesis.
- **Bootstrap is once-only and mints zero.** `bootstrap = (king == reserve)`; `king` is only ever set
  to `msg.sender`, and `HardReserve` has no code path that can call anything. `qRaw` is forced to 0 on
  the bootstrap branch, so the first take mints nothing while routing ~88% to the Reserve.
- **Halving boundary.** `epochUPS` is snapshotted at take time and `scheduleStart` is set after it, so
  the first mining epoch correctly gets `INITIAL_UPS`. Taking just before a halving locks the
  pre-halving rate for one reign — a bounded, VEM-clamped timing preference, not a leak.

**Zero/degenerate states — and a property worth recording.** I constructed several degenerate genesis
parameter sets (`DECAY_FLOOR = 0`, `BOOTSTRAP_OPENING = 0`, `b0 = 0`). Every one of them yields a
**non-functional or griefable protocol, never over-issuance**: a zero-price take routes `dR = 0`, so
`qSafe = 0` and `qMint = 0`. VEM bounds issuance even under adversarial parameters. That property
bounds the severity of the entire genesis-parameter class, including A-4.

Stateful invariants at `runs: 32, calls: 1024, reverts: 0` across the Rig, POL and Treasury handlers,
including `invariant_IssuanceNeverExceedsRawOpportunity`, `invariant_StrategicAndHardNeverMix`,
`invariant_SupplyIsCompletelyAttributed`, `invariant_TheSupplyFloorHolds`.

---

## 4. Hard Reserve authority and failure independence — **HOLDS**

I enumerated every path by which anything could move Reserve principal, and found none.

- **`hardReserve` appears in `StrategicTreasury` at six sites, and is a transfer *destination* at all
  of them** (`:757`, `:1231`) — plus the immutable, the constructor guard, and two event emissions.
  There is no read of the Reserve's balance, no call into it, and no withdrawal shape anywhere.
- **No allowance exists anywhere in `src/`.** A repository-wide grep for `approve`/`allowance`
  returns only documentation comments and one Treasury field name. Every value movement is a push
  (`safeTransfer`), never a pull. `test_G2_NoRescuePathFromStrategicDistressToTheReserve` asserts
  zero allowance in both directions on the live instance; I confirmed the structural reason.
- **No arbitrary-call surface.** `src/` contains **zero** occurrences of `delegatecall`, `.call{`,
  `.call(`, `assembly`, or `selfdestruct`. The one operator-reachable external call with an
  attacker-choosable target is `recallFromStrategy` → `IStrategyAdapter(strategy).recall(...)`, which
  is deliberately ungated. I worked it: the Treasury is `msg.sender`, grants no allowances, and every
  Treasury entry point a callee could reenter is either `nonReentrant`, `onlyRole`, or `msg.sender ==
  pool`. Pointing it at `HardReserve`, `VUX` or the pool reverts (no fallback / no such function).
  **No escalation.**
- **Ownerless/immutable survives assembly.** `HardReserve`'s entire state-changing external surface is
  `redeem`; the sanitization capability lives in init code only, asserted in CI by requiring the
  `PreGenesisWethSanitized` topic to be present in creation bytecode and **absent** from runtime.
  `VUX` has two immutable authorities and no repoint path. `Rig`'s only state-changing entry point is
  `take`. `Lens` is pure view. None has `receive`/`fallback` or a payable function.
- **Compromised-operator envelope.** A fully compromised `OPERATOR_ROLE` can drain Strategic:
  immediately via `allocateRevenue(toOps)` after `setOpsRecipient` (no delay, bounded by
  `realizedRevenue`), or after 24 h via `admitStrategy` + `deployToStrategy`. That is the accepted
  Strategic-only damage envelope. **What it cannot do**: mint, move Reserve principal, create a
  Strategic claim on the Reserve, reduce `B`, increase `S`, or loosen VEM. Every operator action that
  touches the monetary core moves it in the conservative direction. The `toHard` leg is WETH-gated
  (`:749`), so a fabricated revenue balance in an attacker-controlled token cannot be routed to the
  Reserve.
- **The 24-hour admission delay is not bypassable by cap manipulation.** `admitStrategy` resets
  `maturesAt` on **every** call including a re-admission, and `_deploy` refuses before maturity — so
  raising a cap costs a fresh 24 h.
- **Pool price is not an oracle.** The only `slot0()` reads are `_affordableLiquidity` (POL sizing) and
  the genesis price assertion. Neither redemption, VEM, nor Dutch pricing consults the pool, so pool
  manipulation cannot reach monetary correctness — the loss surface is POL/Strategic, and the
  callback caps (`maxVuxIn`/`maxWethIn`) bound even that to the committed amounts.
- **Callback authorization is layered.** `msg.sender == pool` + context-type match + direction check
  (`wethDelta > 0 && vuxDelta < 0`, so the Treasury can only ever pay WETH and receive VUX) +
  commitment ceiling + `data.length == 0` + `delete _ctx` **before** paying + `_requireConsumed()`
  after. Single-consumption is enforced by the delete, so a double callback fails on context
  mismatch.

**Verdict: Strategic → Hard flow is one-directional and accretive-only. Failure independence holds.**

---

## 5. Sprint-5 `decreasePol` reentrancy residual — **CARRIED, unchanged**

Nothing in Sprint 8 alters the accepted reachability assessment, and I checked rather than assumed:
`src/StrategicTreasury.sol` is byte-unchanged from `6395cabb` (the Sprint-7 landing commit), so the
inter-call window between `_pokeCollectAndClassifyFees`'s WETH transfer to the Reserve and the
subsequent `burn`/`collect` is exactly the window that was assessed. Canonical RH WETH provides no
recipient-controlled callback — established on-fork by four positive tests plus one discriminating
control (`test_Sprint5Carry_Control_ReceiversDetectARealCallback`) — and the recipient here is
`HardReserve`, which has no fallback to be called into. `decreasePol` is `nonReentrant`.

**The window exists; it remains unreachable under canonical semantics. Carried proportionally, not
declared fixed.**

---

## 6. Genesis disposition — **NON-GRIEFABLE**, one bounded gap (A-4)

Genesis executes entirely inside `GenesisDeployer`'s constructor: one transaction, no callable launch
surface, nothing to trigger, front-run or replay.

**What I verified independently:**

- **Nonce arithmetic and prediction.** `_predict` is correctly domain-restricted to `[1, 0x7f]` — the
  only range where the `0xd6 0x94 <addr> <nonce>` RLP form is valid. Predictions for nonces 3 and 4
  are **verified against the actual deployment** (`:318`, `:385`), not trusted. The only external call
  between prediction and use is `deployCanonicalPool` on the *pool deployer's* address, which cannot
  move the GenesisDeployer's nonce; nonce 4 is re-predicted immediately before use anyway.
- **Pool identity is bound to pinned bytecode.** `_deriveCanonicalPool` recomputes
  `CREATE2(poolDeployer, keccak256(abi.encode(t0,t1,fee)), POOL_INIT_CODE_HASH)` and requires equality
  with the returned pool, then re-checks `factory()`, `owner() == 0`, tokens, fee, tick spacing and
  price. A pool with the right token pair but the wrong bytecode cannot satisfy this.
- **Commitment gating is sound, and the salt is not the security boundary.**
  `VuxPoolDeployer.deployCanonicalPool` requires `keccak256(abi.encode(msg.sender, salt)) ==
  COMMITMENT` **and** one-shot consumption. Because `msg.sender` must be the committed
  `GenesisDeployer` address, salt disclosure alone does not enable anyone to call it — the salt is a
  confidentiality control, exactly as the frozen doctrine and the runbook both state. `owner` is a
  compile-time `address(0)` constant, so ownerlessness is structural rather than a storage value.
- **Contamination cannot become backing.** Pre-existing WETH at the Reserve address is swept in the
  Reserve's constructor and the balance is required to be **exactly** zero; deployer-side residual is
  reconciled by exact arithmetic (`residual == wethPreSelf + sanitized`) and swept to the **Treasury**,
  not the Reserve; the deployer must end with zero WETH and zero VUX. The decisive control is the
  **absolute** closing assertion `WETH.balanceOf(reserve) == p.b0` (`:473-474`) — I traced a
  hostile-pool-deployer scenario that injects WETH during step 4 (which the *delta* check at `:407-410`
  would miss) and it is caught here. `B0` is exact.
- **Authority handoff.** Grant-then-renounce ordering is correct, and `_verifyRoleTopology` asserts
  both grants present and both renunciations complete before the transaction can succeed. The
  deployed `GenesisDeployer` runtime is inert: view getters only, no roles, no balance, no
  `receive`/`fallback`.
- **Failure is total.** Any mismatch reverts the whole transaction and no contract exists — there is
  no partially-launched state.

**A-4 (LOW) — the premium invariant is enforced on declared scalars, not on the price the pool
actually opens at.** `_verifyBootstrapEconomics` proves `P0 = 1.1 × N0` from `p0Num/p0Den` against
`b0/s0`; `_step4` proves the pool opened at exactly `p.sqrtP0X96`. **Nothing ties `p.sqrtP0X96` to
`p0Num/p0Den`.** The linkage is established off-chain by two independent encoders whose agreement is
asserted in `GenesisPriceEncoding.t.sol`, and by rehearsal-script convention
(`script/GenesisRehearsal.s.sol:137,144-145` derives both from the same `b0/s0`) — but in production
they are two separate operator-reserved slots (runbook §5.3). A mis-encoded `sqrtP0X96` passes all
eleven in-transaction self-verifications and is caught only by the operator's post-launch §6.3 check,
after genesis is irreversible. Detail and remediation in §14.

---

## 7. Static-analysis disposition — **FAIL-CLOSED and correctly bounded**, one wiring gap (A-3)

| Property | Result |
|---|---|
| Exact accepted pins | `slither-analyzer==0.10.4`, `crytic-compile==0.3.7` asserted **as distributions**, not as the `slither` console script — the D-S4 confusion is real and the assertion is the right one |
| 49-distribution closure | **49/49** logical distributions, counted independently |
| Hash-pinned install | **1,735** `--hash=sha256:` entries; **zero** entries without a hash |
| Pre-release leakage | **zero** — the `eth-abi<6` constraint that prevents `6.0.0b1` is present and effective |
| Binding security constraints | `eth-abi==5.2.0` (> 5.0.0 ✓), `pycryptodome==3.23.0` (≥ 3.19.1 ✓) |
| `--no-deps` + `--require-hashes` | present in CI, unabbreviated, followed by `git diff --exit-code -- tools/static-analysis/` |
| Python floor | `[3.10, 3.12)`, **discovered by executing the range check**, not by trusting `command -v`. I reproduced the loop on this host: `python3` resolves to the Microsoft Store stub, is correctly rejected, and `python` 3.11.15 is selected |
| No-RPC control | 9 provider variables checked; `foundry.toml` configures no RPC; the D-S2 disposition condition holds |
| Local build-info consumption | `forge build --out out-slither --build-info --skip test/** --skip script/**`, then `--ignore-compile` — slither never invokes a compiler |
| Out-directory isolation | `out-slither/` (gitignored), so the `vm.readFile` artifact suites are not disturbed |
| No second compiler path | the `=0.7.6` v3-core unit is a separate profile with its own frozen settings; `via_ir = false` and `skip = []` are pinned there **explicitly** because inheritance from `[profile.default]` had silently broken both before |
| Detector baseline integrity | `compare-baseline.py` fails on new findings, on **stale** findings, and unconditionally on any High impact — the third rule is not redundant with the first and prevents absorb-by-regeneration |
| CI fail-closed | proved by a dedicated job that pops one disposition, requires the gate to reject, requires the rejection reason to be the expected one, and then asserts byte-exact restoration |
| Gate ordering | `set +e` after `census.sh`'s `set -e`, with `fail()`/`finish()` doing the accounting — the gate no longer depends on lucky execution order, and I confirmed it runs every check to completion on a host where two of them fail |

**A-3 (LOW) — `tools/static-analysis/slither.config.json` is existence-asserted but never loaded.**
`CONFIG` is checked at `:52-54` and never used again; `--config-file` is passed nowhere in the
repository; and no `slither.config.json` exists at the CWD, so slither's default config discovery
finds nothing. There is **no current behavioural divergence** — `ignore_compile` and `filter_paths` are
duplicated on the command line and the five `exclude_*: false` settings are already slither defaults —
but a future edit to that file would be silently inert, and the accepted authority
(`vux-v1-static-analysis-provenance-refreeze-2026-08.md:480`) describes it as performing "detector
selection and filter paths", a live role it does not have. Detail in §14.

---

## 8. D-S2 disposition — **RESIDUAL CARRIED; the package is present, not absent and not patched**

`web3==6.20.4` is in the closure (forced by slither 0.10.4) and carries GHSA-5hr4-253g-cpx2. I
attacked the unreachability assumption on all seven vectors the brief names:

| Vector | Finding |
|---|---|
| Implicit provider creation | Only one slither invocation exists in the entire repository; its target is `.`, a local directory |
| Address-target mode | No `--address` anywhere; no address-shaped target |
| Environment-derived RPC | 9 provider variables gate-checked; `foundry.toml` sets no `eth_rpc_url` for crytic-compile to inherit |
| `slither-read-storage` | **Zero** occurrences repository-wide |
| crytic-compile network fallback | `--ignore-compile` with a local `--foundry-out-directory`; no network path is entered |
| Config files widening behaviour | No config is loaded at all (see A-3). **Hardening note:** the gate does not assert the *absence* of a repo-root `slither.config.json`, which slither would auto-load — folded into A-3 |
| Future-facing CI commands | The only slither reference in CI is `pip show slither-analyzer`; the analysis itself runs through `run-all.sh` |

**The path remains structurally unreachable under the authorized invocation. The residual is carried
as stated. The vulnerable package is present.**

---

## 9. G-1 fork-evidence reuse — **VALID**

The property being reused is *external RH WETH behaviour*, which is a fact about the chain, not about
this repository. The reuse is admissible because the consuming surface is provably unchanged:
`git diff 6395cabb -- src/ test/` is empty and `6395cabb` **is** the Sprint-7 landing commit against
which the evidence was captured. I checked the discriminating power directly rather than accepting
the summary: the suite asserts chain identity (`RH_CHAIN_ID = 4663`, `assertEq(block.chainid, …)`),
constructor-context native wrap exactness and immediate spendability, absence of approval and
prefunding, callback-free `transfer`/`transferFrom`, exactly-one-event, **and three negative controls**
that fail if the harness cannot detect the thing it claims to be measuring. All ten self-skip off-fork
via `_skipOffFork()`.

Sprint 8 executed **no new fork run** and claims none. The one way this evidence goes stale is an RH
WETH upgrade — which is the disclosed YELLOW risk, and which the runbook §5.9 requires re-verifying at
deployment. **No redundant re-execution requested; the reuse is not a substitution of a changed
property.**

---

## 10. G-2 / G-3 / G-4 and FB-11 — **HOLD**

**G-2 — dual-treasury failure independence.** The 50% / 80% / 100% impairment loop destroys Strategic
WETH outright to `0xDEAD` (the strongest form, with no adapter cooperating in the accounting) and
asserts backing, supply, throne and epoch unchanged at each depth, then proves the core still settles.
The total-loss test drains Strategic to zero and shows the hard claim still pays exactly
`held·B/S`, plus zero allowances in both directions. I looked for hidden coupling through supply,
Reserve balance, redemption, allowances, revenue, POL, the signal module, accounting and callbacks.
The couplings that exist — Treasury VUX burns, Treasury WETH accretion, `totalStrategicContributed` —
are all either informational or move `N` in the holder-favourable direction. **No path from Strategic
distress to Reserve principal.**

**G-3 — truthful UX as an economic surface.** `Lens._hardToReserve` replicates `Rig._route` and I
compared them line by line: **identical**, including the bootstrap branch, and the Lens reads the Rig's
`SPLIT_KING_BP`/`STRATEGIC_CAP_BP`/`BP_DENOM` at runtime rather than hardcoding them, so constant
drift is impossible and the Rig is immutable. The one difference is honest in the safe direction: the
Rig computes `qSafe` from **measured** `dR`, the Lens from **intended** `hardTarget` — and where those
could differ, the Rig reverts. `truth-copy.js` is a genuine single source; the YELLOW disclosure is
**byte-identical** to `prd.md:722`; the prohibited-phrase lists (`earned`, `owned`, `claimable`,
`owed`, `guaranteed`, `debt`; plus `trustless`, `fair launch`, …) are asserted against rendered pages
by Playwright, not merely declared. Most convincingly, the **indexer is honest about the case that
cannot be attributed**: `VUX.burn` is permissionless, so a holder self-burn has no cause event, and
`reconstruct` labels it `other_authorized_burn` by exclusion with a source comment naming
`src/VUX.sol:115` — it also handles the burn-before-cause emission ordering and the non-uniqueness of
`tx:direction:amount` keys. **No path found that presents opportunity as earned or estimate as
guaranteed.**

**G-4 — inactive Signal boundary.** `GenesisDeployer` never references LSG, so `lsgModule` is
`address(0)` at launch by construction and both consumers revert `LSGInactive`. Activation requires
`OPERATOR_ROLE`, which only the operator Safe holds after handoff. A module can direct only *relative*
marginal allocation among **already admitted, matured, capped** strategies: eligibility is re-checked
per entry and `_deploy` re-checks the cap after the headroom clamp, so the clamp and the gate are
independent. The module cannot create a target, cannot mint, cannot reach the Reserve, and holds no
allowance or role. A hostile module can at worst revert `deployMarginalBySignal` (weight overflow
panics) — from which the operator recovers via `deactivateLSG` (no delay, no external call) and direct
deployment. **No P1 mechanism was invented or demanded.**

**FB-11.** I audited it as a security claim rather than re-reading the note. Mechanically: `lsgModule`
appears at exactly **six** sites in `StrategicTreasury` — the declaration, the activate write, the
deactivate read-and-clear, and the two consumers. `removeStrategy`, `recallFromStrategy` and
`closeStrategy` contain **zero** references to it, and `deactivateLSG` makes no external call, so a
captured module cannot block its own severance. Admission bypass, cap bypass, unauthorized target
creation, core reachability, allowance creation, deactivation failure and recall failure are all
structurally closed. Absence of P1 is not treated as a defect.

---

## 11. Launch-runbook, secret hygiene, and release factual integrity

**Runbook — accurate, with one carry-through gap (A-5).** The two-category discipline
(✅ software-established / 🔲 operator-reserved) is maintained without mixing. tx1/tx2 sequencing is
right. Private routing is stated as **confidentiality, not a security assumption**, matching the
frozen doctrine and matching what I found in the code. The one 40-hex address present is the canonical
RH WETH address, labelled "verify, do not assume" with its slot still unfilled — that is a
verification instruction, not a misleading default. 52 slots remain unfilled. I found no instruction
that would cause rehearsal-value reuse: the rehearsal broadcast is gitignored, untracked, and its
deployer is the **well-known public Anvil account** `0xf39fd6…2266`, which appears **nowhere** in
tracked or untracked repository content, as does the standard test mnemonic.

**Secret hygiene — the boundary is clean, and I established that myself.** My own separator-agnostic
sweep over **683** working-tree files (tracked *and* untracked) across private-key/salt/mnemonic
contexts, PEM and keystore shapes, BIP-39 word runs, credentialed RPC URLs, and credential-shaped
filenames returned nothing but this audit's own synthetic probe echoed into `.run/audit.jsonl`. The
verdict does not depend on truncated output: the sweep's own truncation is display-only (`head -20`
after `fail()` has already fired). **But the gate that makes this claim cannot see the document most
likely to break it** — A-2, §14.

**Release / licensing factual integrity — verified, not accepted.** I reproduced the census numbers
from the artifacts: **675** distinct off-chain packages, **74** platform-gated optional entries,
**4 MPL-2.0 + 1 `Apache-2.0 AND LGPL-3.0-or-later`** — exactly what TPN §6.3 states. The
static-analysis census is **49** distributions, **0** undeclared, **0** yanked. The four UNVERIFIED
packages are exactly the four TPN discloses. Most importantly, I tested the load-bearing claim rather
than reading it: **the shipped static export contains no ConsenSys-licensed code.** Scanning
`web/out`, the only `metaMask` occurrences are four instances of wagmi's own injected-connector target
entry (`metaMask:{id:"metaMask",name:"MetaMask",provider:e=>…e.isMetaMask…}`); `MetaMaskSDK`,
`sdk-communication-layer`, `consensys` and `Non-Commercial` occur **zero** times. **The
non-distribution claim holds.** Q-4 legal judgment remains operator/counsel reserved and I invent no
legal conclusion.

**Provenance / source boundary — strong.** The census enumerates by `find`, **not** `git ls-files`, and
`census.sh:173` documents exactly why ("a `git ls-files` scope would let an uncommitted (or
gitignored) [file evade the census]"). The source universe additionally includes *what the compiler
admitted*, read extension-independently from both units' build artifacts, which closes the
`.txt`-named and extensionless-source vectors. CI plants 16 boundary probes — out-of-root
(`contracts/`, `lib/`), mis-cased extensions at root, in `docs/`, and inside a pruned Loa zone,
Solidity named `.txt` and extensionless imported from a declared root — and requires each gate to fail
**for the boundary reason on a `^FAIL` line**, then asserts byte-exact restoration. `on: push:
branches: ['**']` with no path filters, so there is no CI path omission. The Sprint-8 `.gitignore`
change is itself a fix for this class (`coverage/` → `/coverage/`, which had been silently swallowing
the `tools/coverage/` gate). OZ/v3 pins, the Miner allowlist, `POOL_INIT_CODE_HASH`, off-chain pins,
static-analysis pins, SPDX and quarantine are internally consistent and all green.

---

## 12. Findings

### A-1 — LOW — Traceability containment exemption permits false certification of INV-37

**Where:** `tools/traceability/verify-traceability.sh:94-104` (scope), `tools/traceability/build-matrix.mjs:118-124` (`DECLARED`).

**What.** The M-2 containment check is correctly scoped and genuinely sound *within its scope* — I
confirmed the word boundaries discriminate `FB-1` from `FB-11`/`FB-12`/`FB-18` and `INV-3` from
`INV-37`/`INV-30`. But `ci-gate`, `implementation` and `playwright` evidence is exempt, and the
gate's stated rationale ("their linkage is already established structurally … the generator SCANS FOR
[the ids]") is true only for `forge-test`/`stateful-invariant`. Those three kinds are **hand-declared
in a literal map**, not discovered.

Measuring the consequence: of the 55 register rows, **INV-37 is the only one whose evidence files
never literally name it.** All four of its citations are `ci-gate`, all four are hand-declared, and all
four are exempt. INV-37 is *"No product concept expands source-reuse authority; Strategic/LSG/VYRF
code is VUX-original unless later provenance review explicitly changes that status"* — a
security-relevant invariant, and the one this repository's whole default-deny provenance system
exists to serve.

**Failure path (demonstrated, not argued).** I repointed all four INV-37 citations at `LICENSE` — a
file that exists and has nothing to do with source-reuse authority. The gate exited **0** and reported
*"INV-1…37: 37/37 rows carry named evidence"* and *"All checks passed"*. It did not even notice the
distinct-artifact count falling from 45 to 42. Making the **identical** substitution with kind
`review-checklist` produced *"FAIL INV-37 is cited to LICENSE (review-checklist), which never mentions
INV-37"* — so the exemption, not the check, is the cause. This is the H-1/M-1 defect class the review
remediated, surviving through the exempt-kind channel for one row.

**Bounded impact.** The underlying control is intact: the provenance gates are real, run on every
push, and I watched all of them pass. What is unverifiable is the *map* to INV-37, not INV-37 itself.

**Minimum bounded remediation** (either is sufficient):
1. Add an `INV-37` marker comment to the four cited gate files and extend containment to `ci-gate`
   (touches Group A + four files); **or**
2. Have the gate print explicitly that hand-declared kinds carry no containment guarantee, and list
   the affected rows so a reviewer signs them off knowingly (touches Group A only).

**Tree impact:** option 2 changes one Group-A file. Option 1 changes Group A plus four non-subject
files. **Neither is for this node.**

---

### A-2 — LOW — The launch-readiness secret sweep cannot reach the deployment runbook, and its patterns cannot match the runbook's own slot format

**Where:** `tools/provenance/final-secret-sweep.sh:33` (scope), `:44-65` (patterns), `:91` (slot assertion — carried L-2).

Three compounding gaps in the artifact that makes the launch-readiness absence claim:

**(a) Scope.** `scan()` enumerates `git ls-files` — tracked files only. **Zero of the 436 scanned files
are in `grimoires/loa/a2a/sprint-8/`**, because the entire Sprint-8 evidence directory is untracked.
This is not an unknown failure mode in this repository: the sibling gate
`verify-launch-hygiene.sh:50-56` documents it precisely — *"`git ls-files` alone made this gate
near-vacuous before the first commit: every new deliverable is untracked at that point, so the gate
reported clean over work it had never read"* — and fixes it by adding `git ls-files --others
--exclude-standard`. `census.sh:173` states the same rationale a third time. But
`verify-launch-hygiene.sh` excludes `^grimoires/`. **So the deployment runbook falls in the gap of
both gates: untracked (invisible to the sweep) and under `grimoires/` (excluded from the hygiene
gate).**

**(b) Pattern shape.** Every key-material pattern requires `[=:]` as the separator. The runbook's
operator-reserved slots are markdown table cells — `| Commitment salt (preimage) | 🔲 |`. I built a
synthetic filled-slot file in the runbook's exact format carrying a 64-hex commitment salt, a 64-hex
private key labelled "Deployer private key", a 40-hex launch EOA and a relay auth token, and ran the
sweep's five patterns against it verbatim. **All five MISS.** A resolved production secret sitting in
exactly the place the runbook instructs operators to put values would not be detected even once the
file is tracked.

**(c)** Carried L-2 compounds this: `(( slots > 0 ))` passes as long as *one* slot remains empty, so
51 filled slots out of 52 still reads as *"1 operator-reserved slot(s) present and unfilled"*.

**Bounded impact.** The repository **is** clean today — I verified that myself over 683 working-tree
files with separator-agnostic patterns, rather than through this gate. `verify-launch-hygiene.sh` does
scan `.run/` and would catch a `--private-key 0x…` command-line literal there. The runbook's own §0
prohibition and the `broadcast/`/`.env` gitignore entries are independent controls. This is a
detection gap against future operator error, not a current exposure — which is why it is LOW and not
Medium.

**Minimum bounded remediation:** in `final-secret-sweep.sh`, enumerate
`{ git ls-files; git ls-files --others --exclude-standard; }` (the rationale is already written down
twice in the same tool directory) and widen the separator class from `[=:]` to `[=:|]`. Optionally
tighten `:91` to assert the count against the expected 52. **Touches one Group-A file. Not for this
node.**

---

### A-3 — LOW — `slither.config.json` is asserted to exist but is never loaded

**Where:** `tools/provenance/verify-static-analysis.sh:38, 52-54, 172-173`.

The gate checks the config file exists and then never uses it: `--config-file` is passed nowhere in
the repository, and no `slither.config.json` exists at the CWD for slither's default discovery to
find. The existence check makes it read as load-bearing.

**No current behavioural divergence** — `ignore_compile` and `filter_paths` are duplicated as CLI
flags, and the five `exclude_*: false` entries are already slither's defaults. The exposure is drift
in two directions: a future edit to the config is silently inert, and someone removing
`--filter-paths` on the belief that the config covers it would change what is reported. The accepted
authority compounds this by describing the file as performing *"detector selection and filter paths"*
(`vux-v1-static-analysis-provenance-refreeze-2026-08.md:480`) — a role it does not have.

**Related hardening:** the gate does not assert the *absence* of a repo-root `slither.config.json`,
which slither **would** auto-load and which could reintroduce a provider path — the one
config-mediated D-S2 vector that is currently closed only by that file's absence.

**Minimum bounded remediation:** pass `--config-file "$CONFIG"` in the invocation (and optionally add
`[[ ! -f slither.config.json ]]` at the repo root as an assertion), or delete the file and correct the
authority's description of it. **The script change touches one Group-A file; the authority correction
is Group B and is an operator decision, not an auditor's. Not for this node.**

---

### A-4 — LOW — Genesis does not verify that `sqrtP0X96` encodes the declared `p0Num/p0Den`

**Where:** `src/GenesisDeployer.sol:334, 364-365, 488-508`.

`_verifyBootstrapEconomics` proves `p0Num·10·s0 == p0Den·11·b0`, i.e. `P0 = 1.1 × N0`, on the
**declared** rational. `_step4` proves the pool opened at exactly `p.sqrtP0X96`. There is no assertion
relating the two. `p0Num`/`p0Den` and `sqrtP0X96` are independent constructor parameters and, in the
runbook, independent operator-reserved slots (§5.3).

**Failure path.** An operator supplies a `sqrtP0X96` that does not encode `p0Num/p0Den`. All eleven
in-transaction self-verifications pass and genesis completes irreversibly at the wrong pool price.
It is caught only by the operator's post-launch §6.3 assertion. This is a real gap in the runbook §3
claim that *"any mismatch in the eleven-step self-verification reverts the entire transaction"*.

**Blast radius is bounded to Strategic.** A pool opened below `N0` is arbitrageable against the POL —
buy VUX cheap, redeem at `N0`. Redemption remains strictly proportional, so `N` never decreases and
the Hard Reserve is untouched; the loss lands on protocol-owned liquidity, inside the accepted
Strategic envelope. It is also operator-error-triggered, not adversary-triggered, and the runbook
requires the relation both pre-launch (§5.2 "actual marginal price, `P0/N0 = 1.10`") and post-launch
(§6.3). That is why this is LOW despite being irreversible.

**Minimum bounded remediation:** assert the encoder's own floor property in the constructor with
full-precision `mulDiv`, in the frozen orientation —
`sqrtP0X96² ≤ (p0Num << 192)/p0Den < (sqrtP0X96+1)²`. The property is already specified verbatim in
`tools/offchain/encode-sqrt-p0.mjs:9` and asserted in `GenesisPriceEncoding.t.sol`; this moves it
in-transaction.

**Tree impact: this WOULD change `src/GenesisDeployer.sol`, i.e. the review-approved audit tree, and
would require re-review.** It is therefore an operator scope decision, not an audit blocker. The
alternative — leaving it to the runbook's existing pre- and post-launch checks — is defensible; A-5
would make that alternative stronger.

---

### A-5 — LOW — Established deployment-time facts are not carried into the runbook's pre-launch check

**Where:** `grimoires/loa/a2a/sprint-8/deployment-runbook.md:236` (§5.9).

Sprint 7's audit established, by a metadata-stripped PUSH-immediate-skipping opcode walk, that the
shipped bytecode's hard-fork floor is **Cancun** (MCOPY present in VUX's *constructor* region, PUSH0
universally), and measured the launch initcode at **48,057 B** (47,609 creation + 448 args) against
the EIP-3860 cap of **49,152 B**. I reproduced the 47,609 B creation figure exactly from the artifact.
Sprint 7 explicitly recommended these be confirmed against the production chain.

Sprint 8 correctly carries the *categories* into §5.9 — "RH EVM version / hard-fork compatibility"
and "Block gas limit and initcode limit", both 🔲. But the strings `Cancun`, `MCOPY`, `48,057` and
`49,152` appear in **no Sprint-8 artifact at all**. The operator is asked to confirm a limit without
being given the value to confirm against, and to check "hard-fork compatibility" without being told
that Cancun is the established floor or that the MCOPY site is in a constructor.

**I make no headroom-percentage requirement** — none exists in authority, and I do not invent one. The
failure mode is fail-closed (a sub-Cancun chain reverts the whole genesis transaction; no partially
launched state). This is a checklist-completeness gap in a launch-critical operational check.

**Minimum bounded remediation:** add the two measured facts to §5.9 — the Cancun floor with its MCOPY
location, and the 48,057 B / 49,152 B measurement with the command that reproduces it. **Touches one
Group-C file. Not for this node.**

---

### Informational

| ID | Observation |
|---|---|
| **I-1** | `Rig.take` re-validates `B` mid-transaction via the strict `dR != hardContribution` equality (`:369-370`) but has **no counterpart for `S`**: `sPre` is snapshotted at `:324` and consumed at `:373` across three WETH transfers. Unreachable under canonical RH WETH — `transfer`/`transferFrom` are callback-free, established on-fork by four tests plus a discriminating control — and it would take a WETH upgrade adding a transfer hook, which is **strictly dominated** by the already-disclosed YELLOW risk (that same authority can "block, burn, freeze, or seize Reserve WETH"). Even then, profit requires `dR > B_pre`. Recorded as defence-in-depth asymmetry, not a new threat. |
| **I-2** | `verify-traceability.sh:111` prints *"committed matrix is identical to a fresh generation (no stale hand-edit)"* for **untracked** paths: `git diff --quiet` exits 0 on an untracked path, so the `else` branch at `:118` that correctly handles the untracked case is unreachable and the anti-hand-edit assertion is currently vacuous *and* misleadingly worded. Self-resolves on commit. Compounds carried **L-3**. |
| **I-3** | `verify-static-analysis.sh:203-204` counts `forge lint` findings with `grep -cE … \|\| true`. If `forge lint` ever fails or changes output format, `lint_high` becomes `0` and the gate reports *"0 high-severity finding(s)"*. Currently masked by `forge build` failing first, and bounded by the Foundry commit pin; the local run confirms the parse works (4 medium matched the baseline exactly, proving the pipeline is live). |
| **I-4** | `.run/` is untracked but **not** gitignored, while `.claude/*` is. `.run/audit.jsonl` (1.05 MB, 2,209 lines) records the full text of every Bash command executed in this repository and is one `git add -A` from being staged. Mitigated: `verify-launch-hygiene.sh` scans untracked-not-ignored files, so it *does* cover `.run/`, and its `--private-key` pattern does not require a `[=:]` separator. Loa framework state, outside the VUX subject — recorded for the hygiene node. |
| **I-5** | `StrategicTreasury.decreasePol:955-962` floors the POL principal cells at zero but emits `StrategicInflow(CLASS_RETURNED_PRINCIPAL, …)` for the **full** returned amount, so a profitable POL withdrawal over-reports principal and under-reports revenue to an indexer. The excess is also not added to `realizedRevenue`, so it is not spendable through `allocateRevenue` — conservative. No Hard Reserve, redemption or supply effect. |
| **I-6** | `harvestYield` (permissionless, `:592`) attributes the entire `balanceOf` delta across `IStrategyAdapter(strategy).harvest()` to that strategy. A malicious admitted strategy could call `Rig.take()` inside `harvest()`, routing a Strategic leg of its **own** WETH into the Treasury and having it recorded as `YieldHarvested` / `CLASS_OTHER_REVENUE` for itself. The attacker funds the take, so no value is created; the effect is confined to Strategic attribution labels and to `realizedRevenue`, an operator spending allowance already inside the Strategic envelope. Cannot reach the Hard Reserve. |
| **I-7** | `b0 == 0` is not explicitly rejected at genesis: with `p0Num == 0` and `bootstrapOpening == 0`, `_verifyBootstrapEconomics` passes and genesis completes, but `_vem`'s `mulDiv(dR, sPre, 0)` reverts on the first `take`, bricking the protocol with no funds at risk. Fail-closed. Noted with its positive corollary: **across every degenerate parameter set I constructed, VEM still holds — bad genesis parameters produce a non-functional or griefable protocol, never over-issuance.** |
| **I-8** | `HardReserve`, `Rig`, `Lens` and `GenesisDeployer` have no `receive`/`fallback`, so ETH forced in by `selfdestruct`/coinbase is permanently stranded. `B` is defined as the WETH balance, so this cannot affect backing or redemption. Recorded for completeness. |

### Review LOWs — independently re-inspected, **none re-graded**

| ID | Disposition |
|---|---|
| **L-1** stale "74 VUX-owned" | **Confirmed, remains LOW.** I ran `verify-spdx.sh`: it reports **75**. `e2e-goal-validation.md:203` still says 74. The gate is correct and fail-closed; only the summary restatement is stale. |
| **L-2** slot assertion is presence-only | **Confirmed, remains LOW — subsumed and extended by A-2(c).** `(( slots > 0 ))` at `final-secret-sweep.sh:91`; 52 slots present. |
| **L-3** gate regenerates two subject files in place | **Confirmed, remains LOW.** Observed again during probing; deterministic, restored byte-exact on a clean re-run. Extended by **I-2**. |
| **L-4** beads epic/task inconsistency | **Confirmed, remains LOW.** 16 open. Lifecycle bookkeeping; explicitly out of scope and correctly left alone. No security dependency found. |

Review informationals I-1/I-2 (resolved) and I-3/I-4/I-5 (open) are unchanged and were not re-graded.

---

## 13. Approval threshold — checked criterion by criterion

| Criterion | Result |
|---|---|
| No unresolved Critical/High/Medium launch-security finding | ✅ 0 / 0 / 0 |
| Hard Reserve and monetary invariants survive adversarial analysis | ✅ §3 — `N` monotone non-decreasing under every reachable operation, VEM algebraically tight, invariant suite green |
| Strategic failure independence holds | ✅ §4 — one-directional accretive-only flow, structurally and by test |
| Genesis non-griefable under accepted assumptions | ✅ §6 — atomic, self-verifying, contamination-proof, commitment-gated, absolute `B0` |
| Static-analysis / provenance gates fail-closed and correctly bounded | ✅ §7, §11 — with A-3 as a bounded wiring gap that changes no current behaviour |
| Launch-runbook / security boundaries accurate | ✅ §11 — with A-5 as a carry-through gap |
| G-1…G-6 security claims withstand attack | ✅ §9, §10 |
| Review-remediated traceability cannot falsely certify missing evidence **in the tested threat model** | ⚠️ **Met, with A-1 stated plainly.** Within the remediated scope (`review-checklist`/`documented-analysis`) the gate is provably sound — P2 confirms it rejects the exact substitution P1 slips through. Outside it, one row (INV-37) is unverifiable via a deliberate, documented exemption. The invariant itself remains enforced by the census gates and their 16-probe CI demonstration. I judge this a bounded evidence-tooling weakness, not a launch-security failure — and I record the reservation rather than glossing it. |
| Production-secret boundary clean | ✅ §11 — independently verified over 683 files, not accepted from the gate |
| Remaining LOW/informational bounded and accurately stated | ✅ |

---

## 14. Audit-node hygiene

**Files written by this node:** exactly two — `grimoires/loa/a2a/sprint-8/auditor-sprint-feedback.md`
(this file) and `grimoires/loa/a2a/sprint-8/COMPLETED`.

**No permanent implementation, authority, or evidence mutation occurred.** All four subject
fingerprints re-derive to their review-approved values at audit exit, after every probe and a full
`run-all.sh`:

```
Group A   (16) 407d0babaf2ac283e36e71f6bb27a5415c4a178ae3fb5376a902880e52855764
Group B   ( 2) 1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437
Group C   (16) 0ffd9b1d7fbcc122edbc92e1b0b7ac435cf5972e7192bbaa912a443921029e72
Combined  (34) f71d5486a09d5fbd8ed4e6b2ffc4b2ed6e062c29cb63c3b1b14b72326dee564b
```

**Temporary mutations, all restored and digest-verified:** two probes against `build-matrix.mjs`
(P1, P2), each restored from a pre-probe copy taken before mutation; the two matrix artifacts the gate
regenerates were restored to `9d016cc1…` and `dc918719…`, and `build-matrix.mjs` to `94e58d5d…`.
`verify-traceability.sh` was not modified. Restoration was by copy, not `git checkout`.

**Both review artifacts are preserved unmodified.** `engineer-feedback.md` =
`6630a959dd5bde5fd8390ee716e395e215cb9f96b297d069c60c252c34dc4b78` (the digest the re-review
recorded); `engineer-feedback-2.md` untouched.

**Build-artifact baseline.** `run-all.sh` rebuilt both compilation units with `--force` before any
gate ran, so no measurement in this report was taken against a pruned artifact set. `out-slither/`
and `out-coverage/` are gitignored and isolated from `out/` by design.

**The five operator-approved retrospective skills under `grimoires/loa/skills-pending/` are outside
this audit.** Not promoted, not re-audited, not treated as a Sprint-8 security finding. `.claude/` was
not modified and no State-Zone bypass was attempted. Beads state was not forced.

**HEAD `6395cabb4deee5bae50ac79c8094053484261819`, branch `sprint-8`, 0 commits ahead, one registered
worktree, `master` and `origin/master` at baseline — all unchanged from audit entry.**

**Nothing was committed, pushed, tagged, landed, or deployed. No operator acceptance was begun. The
cycle was not closed. `/retrospective` was not run.**

---

## 15. Recommendation

**`SPRINT_8_AUDIT_APPROVED`.**

Five LOWs and eight informational observations, none of them in the monetary core. The three I would
put in front of the operator first are **A-2** (the sweep that makes the launch-secret absence claim
cannot see the runbook, and its patterns cannot match the runbook's own slot format — and the fix is
already written down twice in the same directory), **A-1** (one security-relevant register row can be
certified against `LICENSE`), and **A-5** (Cancun and 48,057 B are known and are not written where the
operator will look for them). A-5 is a two-line addition to a Group-C file and is the cheapest real
risk reduction available before launch.

**A-4 is the only finding whose remediation would change the review-approved tree**, and I am
deliberately not pressing it: the blast radius is Strategic-only, the runbook already requires the
relation both before and after launch, and re-opening `src/` at the final gate costs more than it
buys. It belongs in the operator's launch-scope decision alongside A-5, not in a remediation loop.

What this implementation does well is worth recording as fact, not flattery: the `dR` strict-equality
check is the single best control in the system — it converts every mid-transaction Reserve mutation,
reachable or not, into a revert; the census deliberately enumerates by `find` rather than `git
ls-files` and *writes down why*; and the CI carries four separate negative-demonstration jobs that
prove gates close rather than asserting it. The gaps I found are all in places where that same
discipline was applied unevenly across sibling tools.

**Recommended next lifecycle node:** operator acceptance of Sprint 8 against the exact tree identified
in §1, then cycle-002 closeout. Not `/ship` and not deployment — the launch itself remains gated on
the runbook's open operator-reserved slots (Q-3, Q-4, R-14) and on §5.9's chain-environment
verification.

---

*Security audit by the Loa `/audit-sprint sprint-8` node, 2026-08-19. The audit subject was derived*
*from git before any Sprint-8 report was read, and re-derived at exit. Every load-bearing claim above*
*was established on this tree: four subject fingerprints, nine authority pins, fourteen probes*
*including two evidence-falsification attempts against the traceability gate and one against the*
*secret sweep, an independent 683-file secret sweep, an independent scan of the shipped web export*
*for ConsenSys-licensed code, independent reproduction of the licence-census and initcode*
*measurements, and a full `run-all.sh` (454 passed / 0 failed / 10 skipped; 10 of 11 gates green, the*
*eleventh failing closed on a locally absent analyzer). Nothing was accepted on report. No*
*implementation source, authority document, evidence artifact, or review artifact was modified —*
*every subject fingerprint is identical before and after. Nothing was committed, pushed, landed, or*
*deployed, and operator acceptance was not begun.*

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":5},"sprint_id":"sprint-8","ts":"2026-08-19T00:00:00Z"} -->
