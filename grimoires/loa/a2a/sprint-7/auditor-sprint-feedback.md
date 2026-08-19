# Sprint 7 — Genesis: Non-Griefable Launch Implementation & Adversarial Rehearsal — Security Audit

**Verdict:** `APPROVED`
**Auditor node:** `/audit-sprint sprint-7` — independent adversarial security audit only. No remediation, no commit, no acceptance.
**Branch:** `sprint-7` · **Baseline/HEAD:** `c58d41b8c77f3191114a5242c4bac9ff753f32dc` (unchanged; no commit made)
**Date:** 2026-08-18

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 2 (both carried from review; neither requires a Sprint-7 code change) |

No reachable condition was found under the accepted adversary model that can alter one wei of genesis
economics, divert genesis VUX or POL ownership, corrupt Hard Reserve `B0`, survive with mint or Reserve
authority, substitute the canonical pool, or extract an unauthorized callback payment. Two guards that the
security theorem rests on were confirmed **load-bearing by mutation**, not by assertion.

---

## 1. Audited identity — independently derived

Derived before consuming any report: `git status --porcelain -uall`, partitioned by path prefix,
path-sorted, rendered `<sha256>  <path>` (two spaces), joined with `\n`, **no trailing newline**, then
`sha256` of that blob.

| Property | Derived at audit entry | Review-approved | Result |
|---|---|---|---|
| Branch | `sprint-7` | `sprint-7` | ✓ |
| HEAD | `c58d41b8c77f3191114a5242c4bac9ff753f32dc` | baseline | ✓ |
| Commits ahead | `0` | 0 | ✓ |
| Registered worktrees | 1 (`C:/Users/0x007/vux`) | 1 | ✓ |
| Group A files | **11** | 11 | ✓ |
| Group A fingerprint | **`38bbdc88022762f61fd5172cb0218687e718478a91697bea647b9ae2de45312a`** | same | **MATCH** |
| Implementation committed? | No — uncommitted | uncommitted | ✓ |

**The audited tree is byte-identically the tree the reviewer approved.** No stale identity was audited.

The eleven files: `src/GenesisDeployer.sol`, `script/GenesisRehearsal.s.sol`,
`test/genesis/{GenesisFixture,GenesisWiring.t,GenesisAdversarial.t,GenesisPriceEncoding.t}.sol`,
`test/fork/RhWethFork.t.sol`, `test/harness/Vm.sol` (M), `test/mocks/MockWeth.sol` (M),
`tools/genesis/demo-nonce-negative.sh`, `tools/offchain/encode-sqrt-p0.mjs`.

**Lifecycle artifacts correctly excluded from the subject.** `grimoires/loa/skills-pending/**`,
`grimoires/loa/a2a/trajectory/*.jsonl`, `grimoires/loa/analytics/**`, `.run/`, `.beads/`,
`ledger.json.bak`, `ledger.json.lock` and the NOTES.md edit are Group C lifecycle churn, not Group A
product implementation. None enters the fingerprint.

**Identity re-derived at audit exit: `38bbdc88…45312a`, 11 files, HEAD `c58d41b8`, 0 ahead — unchanged.**
Two source mutations were performed as adversarial probes (§4) and both were restored from a
scratchpad backup with `sha256` verification. **The audit mutated no implementation bytes.**

---

## 2. Independent verification — reproduced, not inherited

I did not accept "444 tests passed" as a security result. Load-bearing facts were re-derived.

| # | Claim | My method | Result |
|---|---|---|---|
| A-1 | `POOL_INIT_CODE_HASH` | Wrote a **keccak-256 from scratch** (validated against `keccak("")` and `keccak("abc")` vectors), hashed the compiled `=0.7.6` pool creation code | `0xe34f…8b54` — **identical** to the hard-coded constant |
| A-2 | Initcode measurement | Parsed the raw artifact; counted the `GenesisParams` ABI tuple as **14 static fields** | creation **47,609 B** + args **448 B** = **48,057 B**; EIP-3860 cap 49,152; headroom **1,095 B** — reproduces exactly |
| A-3 | `sqrtP0X96` encoding | **Two** independent BigInt isqrt implementations (Newton and binary search), cross-checked against each other, with the exact floor property `r² ≤ x < (r+1)²` asserted | Both orientations reproduce the pinned constants and the shipped `.mjs` encoder exactly (4 independent implementations agree) |
| A-4 | Premium + cushion law | Exact BigInt cross-multiplication | `p0Num·10·S0 == p0Den·11·B0` holds exactly (products ~4.5e45); cushion **27,272,727,272,727,272,727 wei** ≥ 25e18 opening |
| A-5 | **Actual** POL consumption | Read the real `mint` callback payments out of an EVM trace rather than trusting the test's bound | pool took **149,999,999,999,999,999,999,981** VUX and **299,999,999,999,999,999,636** WETH → dust **19 wei VUX / 364 wei WETH** (~1.2e-18 relative) |
| A-6 | Full accumulated suite + all provenance gates | `tools/provenance/run-all.sh` | **444 passed / 0 failed / 10 skipped**; all gate sections pass |
| A-7 | Genesis suites | `forge test --match-path 'test/genesis/*'` | **47 passed / 0 failed** |
| A-8 | Secret hygiene | Ran the gate **and** independently grepped all 11 Group A files for key/mnemonic literals | Gate scans **371 files: tracked + untracked-not-ignored** — the property that matters, since the entire subject is untracked. Only hex literals in Group A are a public fork block hash and the two EIP-1967 slots |
| A-9 | Hard-fork floor of the shipped bytecode | Opcode walk that **skips PUSH immediates and strips the metadata trailer** | Floor is **Cancun** (`MCOPY` in VUX), **Shanghai** (`PUSH0`) universally — see L-1 |

**A note on my own environment.** An intermediate full-suite run showed 37 failures; all were
`vm.readFile` errors on `out/*.json` artifacts that my own mutate/restore cycle had pruned. A clean
rebuild reproduced **444 / 0 / 10**. The failures were an artifact of my probing, not a property of the
tree, and I record them rather than quietly dropping them.

---

## 3. Threat model applied

I granted the adversary everything the mandate specifies — all future addresses, the canonical pool
address, token ordering, fee/tick configuration, the accepted parameters, `POOL_INIT_CODE_HASH`, the pool
salt, and all public constructor arguments — and denied only the launch EOA / Safe private keys.

**The two structural reasons address secrecy is never the boundary, verified independently:**

1. **The one-shot gate binds `msg.sender`, not just the salt.** `deployCanonicalPool` requires
   `keccak256(abi.encode(msg.sender, salt)) == COMMITMENT`. An adversary who has extracted the salt still
   cannot call it, because they cannot *be* the predicted `GenesisDeployer` address. Before tx2 that
   address has no code and cannot originate a call; after tx2 the contract has **zero** non-view functions.
   Both operands are fixed-size, so `abi.encode` admits no packing ambiguity.
2. **tx1 → tx2 ordering is enforced by the EVM, not by luck.** The two launch transactions are
   consecutive nonces of one EOA, so no observer, builder, or reorder can land tx2 before tx1, and no
   third party can spend those nonces.

**EIP-684 collision griefing does not apply.** Occupying any of the five sequential CREATE addresses or
the CREATE2 pool address requires code or a non-zero nonce at the target. Balance alone sets neither, so
arbitrary prefunding cannot block a single deployment. Placing code there requires the launch EOA's key
(sequential) or a keccak preimage (CREATE2). Both are out of reach.

---

## 4. My own adversarial mutations

Two source mutations, applied and reverted with hash verification, targeting the guards the theorem leans
on hardest. Both are probes the review did not run.

### M-A — remove the caller-is-pool check from the genesis mint callback

Deleted `if (msg.sender != pool) revert CallbackUnauthorizedCaller(msg.sender);` from
`uniswapV3MintCallback`.

**Result — two findings, both favourable:**
- `test_CallbackForgeryFromAHostilePoolIsRejected` **fails**, and it fails on the *specific error
  selector* (`CallbackContextMismatch(1, 0) != CallbackUnauthorizedCaller`). The test asserts the exact
  revert reason rather than merely "it reverted", so check (1) is **proven load-bearing** and the test is
  discriminating rather than vacuous.
- All 11 other adversarial tests still pass: with check (1) removed, forged callbacks are still rejected
  one layer deeper by the armed-context check. Callback authentication is **genuinely layered**, not a
  single point of failure.

### M-B — corrupt `POOL_INIT_CODE_HASH` by one nibble

Changed the trailing `…b8b54` to `…b8b55`.

**Result:** the **entire launch reverts** with `PoolAddressMismatch`, and all 14 genesis tests fail at
launch. Canonical pool identity is **strictly binding**: the CREATE2 derivation forces the pool at the
canonical address to be the genuine pinned `UniswapV3Pool` creation code. "A pool with the right token
pair exists" is nowhere accepted as canonicality — I verified this by breaking it.

Both files restored; Group A fingerprint re-derived byte-identical.

---

## 5. The twelve launch-security obligations — independent disposition

| # | Obligation | My finding |
|---|---|---|
| 1 | Leaked future addresses cannot grief genesis | **Met.** Every predicted address lies in an exclusive namespace (this account's CREATE sequence, or `VuxPoolDeployer`'s CREATE2 `0xff` space). Balance-only prefunding sets neither code nor nonce, so EIP-684 never triggers. Every intended flow is verified as a **measured delta of that flow**, so a prefunded baseline is arithmetically inert |
| 2 | Hostile public-factory lookalikes are irrelevant | **Met.** The protocol never reads a shared factory. `treasury.pool()`, `pool.factory()`, and the CREATE2 derivation all converge on one address; a lookalike at any fee tier is simply a different address holding none of the protocol's liquidity |
| 3 | Canonical CREATE2 identity is exact | **Met, and proven by mutation (M-B).** I reasoned through the formula independently: `create2(poolDeployer, keccak256(abi.encode(token0,token1,fee)), POOL_INIT_CODE_HASH)`. I confirmed upstream `UniswapV3PoolDeployer.deploy` is **`internal`**, so the *only* path into that namespace is the commitment-gated, one-shot `deployCanonicalPool`. The hash constant I re-derived from scratch |
| 4 | Arbitrary prefunding cannot alter genesis | **Met.** Step 0 snapshots WETH *before* wrapping and asserts the wrap delta equals `msg.value`; only `msg.value` is wrapped, never `address(this).balance`. Prefunding the pool is also inert: v3 verifies payment as a within-operation balance delta, so a pre-existing pool balance is baseline, never payment |
| 5 | Very-large future-Reserve prefunding is sanitized | **Met.** The Reserve sweeps pre-existing WETH to `msg.sender` (a fixed same-transaction receiver, not a parameter) in its **constructor**, then requires itself born empty; `GenesisDeployer` independently re-checks `ReserveNotBornEmpty`. The sweep cannot reach approved `B0`, which arrives at step 7 — strictly after. Contamination lands at the treasury as unattributed principal-side inventory: it is never credited to `realizedRevenue`, so it is arithmetically unreachable from `allocateRevenue`, and no mint path exists to call |
| 6 | Exact physical `B0`, `N0`, `P0/N0`, first `B_pre` | **Met.** `B0` is delta-verified against a born-empty Reserve and re-asserted at close. `S0 = 150_000e18 + 1` is asserted against live `totalSupply`, so `N0 = B0/S0` and `P0/N0 = 11/10` hold on physical state. `Rig.take` reads `B_pre = weth.balanceOf(reserve)`, which is exactly `B0` at first settlement, with `king() == reserve` asserted. POL quantization dust does not perturb these: `N0` is denominated in **total supply**, not pool-held supply (see I-2) |
| 7 | No temporary deployment authority survives | **Met, structurally.** `GenesisDeployer`'s complete ABI is **13 view functions, 0 non-view, no `receive`/`fallback`** — verified from the compiled artifact, not from prose. The Reserve's sanitization capability exists only in init code and is absent from runtime (gate-verified). The treasury's callback authorization is deleted before payment and `_requireConsumed()` asserts it did not survive the operation |
| 8 | Launch EOA gains no protocol authority | **Met.** `StrategicTreasury`'s constructor grants both roles to `msg.sender` with **no role argument in existence**, so no external party can be named. `VUX`/`Rig`/`HardReserve`/`Lens` have no role surface at all. The launch EOA appears nowhere in the system |
| 9 | `VuxPoolDeployer` consumed and ownerless | **Met.** `canonicalPool` latches after `deploy` returns; the only code executing in that window is the byte-frozen pool constructor, whose entire interaction with its deployer is the `parameters()` view — there is no re-entry path to race the latch, and a re-entrant call would fail the commitment check anyway. `owner` is `address(0)` as a **`constant`** — a property of the bytecode, not an unset slot. The compiled ABI confirms the external surface is exactly `COMMITMENT`, `canonicalPool`, `deployCanonicalPool`, `owner`, `parameters` |
| 10 | Exact init price and bootstrap cushion | **Met.** I re-derived `sqrtP0X96` with two of my own isqrt implementations; four implementations now agree. Genesis asserts exact `slot0` equality after `initialize`, and the ratio/cushion laws are checked by exact wei cross-multiplication on the recorded rational — never re-derived from the lossy Q64.96 encoding |
| 11 | POL callback authorization exact, pool-bound, one-shot | **Met, and proven by mutation (M-A).** Pool-bound (`msg.sender != pool`), context-typed, per-side bounded by committed maxima, empty-data-required, and **consumed before any payment**. `_affordableLiquidity` independently *underestimates* liquidity — I verified both substitutions (`sqrtA→MIN`, `sqrtB→MAX`) move in the safe direction — so the pool cannot demand more than committed even before the callback bound applies. Payment is a bare `transfer`; no allowance is created anywhere |
| 12 | Production secrets absent; security does not depend on them | **Met.** The rehearsal reads its key from `VUX_REHEARSAL_PK`; `broadcast/` and `broadcast/**` are gitignored and gate-checked. Critically, the hygiene gate scans **untracked-not-ignored** files, which is the only reason it covers this sprint at all. And security does not *rest* on secrecy — §3 shows the `msg.sender` binding holds even with the salt fully disclosed |

---

## 6. Findings

**No critical, high, or medium findings.** Two informational observations follow. Neither is
attacker-reachable under the accepted threat model, and neither warrants mutating an audit-approved tree.

### I-1 (Informational) — `poolDeployer` is trusted by address, not by codehash

Every pool check in `GenesisDeployer` derives from the operator-supplied `p.poolDeployer`: the CREATE2
derivation, `pool.factory() == p.poolDeployer`, and `IUniswapV3Factory(p.poolDeployer).owner() == 0`.

The init-code-hash binding is strong — M-B proves a substituted deployer cannot substitute the **pool
implementation**, because the derivation only closes if the genuine pinned creation code was deployed at
the canonical salt. The residual is narrower: `owner()` is read as a **call**, so a deliberately crafted
lookalike deployer could return `address(0)` during genesis and a live owner afterwards, acquiring
`setFeeProtocol` / `collectProtocol` on the canonical pool. On the real `VuxPoolDeployer` this is
impossible — `owner` is a compile-time `constant`.

**Not attacker-reachable.** `p.poolDeployer` is a tx2 parameter chosen by the founder, who deployed it in
tx1; the threat model excludes control of the launch EOA. This is operator-error/compromise territory, not
adversary territory.

**Recommendation (Sprint 8, runbook — no code change):** record tx1's deployed **codehash** and compare it
before signing tx2. That closes the gap with a procedural step rather than a constructor byte, which
matters given R-1's 1,095-byte headroom.

### I-2 (Informational) — no on-chain invariant bounds POL leg consumption

Genesis asserts the POL position is non-empty (`PolPositionEmpty`) but nothing on-chain bounds how much of
`wPol` / `polVux` the pool actually took. The bound lives only in tests (`< 1e12` wei WETH, `< 1e18` VUX).
Measured actual is **364 wei / 19 wei** (A-5) — genuinely dust, and cost basis records amounts **paid**,
not requested, so no phantom principal is booked.

If `wPol` and `sqrtP0X96` were mutually inconsistent (an operator parameter error), a large residual would
remain at the treasury. Even then it is bounded: it stays protocol-owned, cannot touch `B0`, `S0`, the
Reserve, or mint credit, and is not credited to `realizedRevenue`. **Not attacker-reachable** — an
adversary cannot influence `wPol`, and cannot make the mint cheaper by prefunding the pool, because v3
charges on measured balance delta.

I raise it only so obligation 6's word "exact" is read precisely: the authority-defined exact quantities
(`B0`, `S0`, `N0`, `P0/N0`, `B_pre`) **are** each independently asserted; the POL leg's *placement* is
bounded rather than exact, which is correct, because v3 mint principal is bounded rather than exact.

### P-1 (Process observation — not severity-graded, not blocking)

The Sprint-7 **review** artifact fails the framework's own C6 prose↔trailer consistency gate:

```
verdict-derive.sh --file grimoires/loa/a2a/sprint-7/engineer-feedback.md --gate review --require-trailer
→ trailer says APPROVED but first line is not exactly 'All good'   (exit 1)
```

Its trailer is `APPROVED`, but its first line is a `#` heading. Every one of the nine prior approved
review artifacts in this repository opens with the exact line `All good`, so this is a deviation from an
established, machine-checked convention rather than a matter of taste — and `CLAUDE.md` names this gate as
the mechanism that keeps prose and trailer honest.

**No security consequence, and no reason to withhold audit approval.** The review's verdict is unambiguous
in prose (`APPROVED` in both its opening paragraph and §9), its counts are internally consistent, and its
substance is thorough. **I did not modify the review artifact** — it is another node's output and repairing
it is not the audit node's job. Recorded so the operator can decide whether to have the review node
re-emit it. My own artifact passes the audit-gate form of the same check.

---

## 7. Disposition of review findings L-1 and L-2

### L-1 — `evm_version` unpinned for the `=0.8.28` unit — **carried LOW, and now characterized**

Affirmed as a Sprint-8 launch-environment/runbook item. **No incompatibility affecting the reviewed
Sprint-7 bytecode was demonstrated**, and I invented no code mutation for configuration neatness.

I did sharpen it from "unknown" to a measured fact. An opcode walk that skips PUSH immediates and strips
the metadata trailer gives the shipped bytecode's hard-fork floor:

| Artifact | Fork-gated opcodes |
|---|---|
| `VUX` runtime | `PUSH0` (Shanghai), `MCOPY` (**Cancun**), `CHAINID` |
| `StrategicTreasury` runtime | `PUSH0`, `BASEFEE` (London) |
| `GenesisDeployer`, `HardReserve`, `Rig`, `Lens` runtimes | `PUSH0` (Shanghai) |
| `UniswapV3Pool` (`=0.7.6`, pinned `istanbul`) | nothing past Constantinople |

So the floor is **Cancun**, driven by `MCOPY` in `VUX`. (An earlier naive walk also flagged `BLOBHASH`;
metadata-stripping removed it — it was a false positive, and I report it as such.)

**The failure mode is fail-closed, which is the security-relevant question.** `MCOPY` is present in VUX's
**constructor region**, which executes inside the genesis constructor. On a chain below Cancun the VUX
constructor reverts, the whole launch reverts, and `GenesisDeployer` never comes into existence. There is
no partially-launched state and no scenario where genesis succeeds while leaving a bricked runtime path.

**Recommendation (Sprint 8, runbook):** extend R-2's pre-launch input set to name the EVM/hard-fork level
explicitly, stated as a concrete threshold — *does RH accept Cancun-level bytecode (`MCOPY`, `PUSH0`)?* —
alongside the EIP-3860 ceiling and block gas limit, and decide whether to pin `evm_version` at the
deployment freeze next to R-1's optimizer decision.

### L-2 — no `reviewer.md` implementation handoff — **carried LOW, process/artifact debt**

**This did not block the audit and is not a mechanical blocker.** I identified the audit subject
independently by deriving the fingerprint from `git status` before reading any report, and the substantive
implementation evidence is present in `evidence/genesis-evidence-pack.md` §10 (R-1…R-7) plus the
independent review. I did **not** manufacture a replacement report to normalize convention, and no legacy
un-suffixed A2A path was used.

**One concrete mechanical consequence, which sharpens the review's disposition.**
`.claude/scripts/validate-ac-verification.sh` takes `--report <reviewer.md>` as a *required* input and
walks that report's `## AC Verification` section against the sprint's acceptance criteria. Sprint 5's audit
ran it as a gate artifact; **for Sprint 7 it cannot be run in its intended form**, because no `reviewer.md`
exists and the evidence pack carries no `## AC Verification` section. Pointing it at the evidence pack
instead is not a substitute: without a scoped sprint slice it also pulls Sprint-8 criteria (slither,
runbook, E2E, coverage) that Sprint 7 was never meant to satisfy.

This does **not** impair the security audit. The gate's own help states it "prevents ABSENT evidence …
not FABRICATED evidence" — it is a *report-completeness* check, not a security check, and every
security-relevant claim in this audit was derived directly from the tree instead. Recorded so the operator
knows exactly which gate L-2 disables, rather than carrying L-2 as an unquantified convention deviation.

---

## 8. Disposition of implementation residuals R-1 … R-7

| Item | Security disposition |
|---|---|
| **R-1** — 1,095 B (2.2%) initcode headroom | **Correct, and not a vulnerability.** I reproduced all three figures independently, including the 448-byte tuple as 14 static fields. 48,057 < 49,152 under the accepted environment. I invented no percentage threshold absent from authority. Thin headroom is a growth constraint, now CI-enforced, not an exploit path |
| **R-2** — RH Orbit gas/size semantics uncharacterised | **Sprint-8 runbook item.** Extended per L-1 to include the Cancun threshold |
| **R-3** — `Adversary`-account separation | **Not a finding, and I tested the concern directly.** The model is faithful — nonce ordering is EVM-enforced (§3). The nonce plan does not *rely* on the model: `predict(3)`/`predict(4)` are verified in-transaction against whatever actually happens, and mis-sequencing produces a `BadCommitment` revert |
| **R-4** — dust asserted by bound, not exact value | **Not a finding; disclosure is accurate.** The pack's "observed 364 wei" matches my independent trace measurement exactly. See I-2 for the precise reading |
| **R-5** — `MockWeth` gained `deposit()` | **Not a security finding.** Additive; test-only; mirrors Q-6-measured behavior. Not deployed |
| **R-6** — rehearsal Safe / fee / tick spacing are stand-ins | **Not a finding.** R-14 operator-reserved facts; domain-checked by `VuxPoolDeployer` (`fee < 1e6`, `0 < tickSpacing < 16384`), value-frozen nowhere |
| **R-7** — off-fork Q-6 reports `[SKIP]` | **Not a finding.** Honest representation; skips are never reported as passes |

---

## 9. Q-6 / canonical WETH external assumption — used proportionally

Accepted as sufficient for what genesis actually depends on: canonical RH WETH credits
`deposit{value:x}()` 1:1 **inside a constructor** and the credit is spendable in that same constructor.
The fork run records chain 4663, block 39130641, block hash, parent hash and state root, and carries two
negative controls (`NoCreditWeth`, non-payable `deposit()`) that make the positive claim falsifiable.

**I did not treat the Sprint-5 reentrancy window as fixed, and the evidence does not claim it is.** The
Sprint-5-carry tests assert only that the *currently deployed* implementation invokes no recipient
callback, and a positive control (`test_Sprint5Carry_Control_ReceiversDetectARealCallback`) proves the four
`calls == 0` assertions can fail. Current WETH behavior preserves the finding's unreachability; it does not
repair it, and the implementation is upgradeable exactly as disclosed.

I did not reopen this into an external aeWETH provenance project — genesis depends on no materially
different property.

---

## 10. Carried residuals

| Residual | Status |
|---|---|
| Review **L-1** — `evm_version` unpinned | Carried LOW → Sprint-8 runbook, now characterized (Cancun floor, fail-closed) |
| Review **L-2** — no `reviewer.md` handoff | Carried LOW → process/artifact debt; did not impede this audit |
| Sprint-5 **A-1** — `decreasePol` inter-call reentrancy | **Carried unchanged, not reopened.** Sprint 7 does not change its reachability: I confirmed `VUX` is plain OZ ERC20 with **no `_update`/transfer hook**, `decreasePol` remains `nonReentrant` and `OPERATOR_ROLE`-gated, and Q-6 re-verified canonical WETH has no recipient callback with a positive control. No new reachable callback path exists |
| **I-1**, **I-2** (this audit) | Informational; Sprint-8 runbook note for I-1, no action for I-2 |

I did not reopen any other accepted earlier-sprint finding merely because Sprint 7 integrates those
contracts.

---

## 11. Scope, provenance, and secrets

**No unauthorized source or dependency.** Verified independently, not inherited:

- `foundry.toml`, `package.json`, `package-lock.json`, `remappings.txt`, `.gitmodules`, `vendor/`,
  `docs/authority/`, `lib/` — **all absent from porcelain**, i.e. untouched by Sprint 7.
- No `UniswapV3Factory.sol` and no v3-periphery path exists anywhere in the tree.
- Every import in the 11-file subject resolves to already-vendored OpenZeppelin, already-vendored v3-core
  **interfaces**, or internal project files. No new dependency, no new smart-contract source.
- No P1 Signal/LSG mechanism and no Sprint-8 mechanism was introduced.
- The immutable vendor census gate passes byte-identity.
- `src/v3core/VuxPoolDeployer.sol` is pre-existing Sprint-4 source, unmodified by Sprint 7.

**Slither was neither introduced nor used by this audit.** It appears only as a declaration inside two
**unmodified** `docs/authority/` refreeze registries, where it remains a Sprint-8 provenance-gated
dependency. No provenance gate was weakened, modified, or bypassed to make any audit tool convenient.

**No production secrets were introduced.** Gate output and my own independent scan of all 11 files agree
(A-8). Default deny remains binding and intact.

---

## 12. Recommendation

**APPROVED - LET'S FUCKING GO**

`SPRINT_7_AUDIT_APPROVED`.

The exact tree — fingerprint `38bbdc88022762f61fd5172cb0218687e718478a91697bea647b9ae2de45312a`, 11 files,
HEAD at baseline `c58d41b8`, zero commits ahead, uncommitted — is **safe to place before the operator for
acceptance**.

**Stop here for explicit operator disposition.** An approved audit is not operator acceptance. Do not
commit, land, or begin Sprint 8 until the operator has accepted this exact tree.

**Post-audit law:** any implementation mutation after this approval creates a new exact tree that must be
re-audited before acceptance and landing. Neither carried LOW warrants that lifecycle cost — both are
Sprint-8 runbook items, and L-1's failure mode is fail-closed.

**Carry into Sprint 8 (runbook, not code):**
1. Confirm RH's EIP-3860 ceiling, block gas limit, **and** acceptance of Cancun-level bytecode (L-1/R-2).
2. Record and compare tx1's deployed codehash before signing tx2 (I-1).
3. Resolve Q-3 (production Safe signer set and threshold) (R-6).
4. Decide `evm_version` pinning and `=0.8.28` optimizer settings together at the deployment freeze (R-1).

---

*Audited by the Loa `/audit-sprint sprint-7` node, 2026-08-18. Subject identity derived from git before*
*any report was read, and re-derived at exit — byte-identical. Two adversarial source mutations were*
*applied and restored with hash verification; no implementation byte, test, build configuration, authority*
*document, or provenance registry was left mutated. `POOL_INIT_CODE_HASH`, the price encoding, the*
*initcode measurement, the premium and cushion laws, the actual POL consumption, and the bytecode's*
*hard-fork floor were each derived independently rather than accepted on report. Nothing was committed,*
*pushed, merged, or landed; no operator acceptance was recorded; no pending skills were reconciled; the*
*ledger was not flipped.*

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":2},"sprint_id":"sprint-7","ts":"2026-08-18T00:00:00Z"} -->
