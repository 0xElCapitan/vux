# Sprint 8 Review — Launch Readiness: Hardening, Traceability & E2E Goal Validation

Sprint 8 has been independently reviewed against the exact uncommitted tree. The verdict is
**CHANGES_REQUIRED** — **0 critical, 1 high, 3 medium, 4 low**.

This is a strong sprint. Nearly every load-bearing claim in the implementation report is
true and I reproduced it myself rather than accepting it: the 49-distribution static-analysis
closure (installed, and its reachability derived independently from package metadata), all
eleven provenance gates, the 454-test accumulated suite, 98.19% core line coverage recomputed
from raw lcov, the two Slither dispositions that required judgment, the MetaMask
non-distribution claim (re-tested with fingerprints the implementation did not use), and the
runbook's 52 unresolved slots. Two negative probes confirmed the new gates fail closed.

The blocking finding is narrow and is exactly the class this review exists to catch: the
traceability matrix reports **18/18 failure behaviours covered**, and for **FB-11 that
coverage does not exist**. Its sole evidence is a hardcoded pointer to a file that never
mentions FB-11, and the gate that is supposed to police the matrix cannot detect this because
it verifies only that the *path* exists. Six further rows are cited to the wrong artifacts.
The remediation is bounded — one scenario note, six corrected citations, one added gate
assertion — and touches no Solidity.

---

## 1. Reviewed implementation identity — independently derived

| Property | Derived value | Reported | Match |
|---|---|---|---|
| Branch | `sprint-8` | `sprint-8` | ✓ |
| HEAD | `6395cabb4deee5bae50ac79c8094053484261819` | same | ✓ |
| `master` / `origin/master` | both at `6395cabb` | untouched at baseline | ✓ |
| Commits ahead of baseline | `0` | 0 | ✓ |
| Worktrees | 1 (`C:/Users/0x007/vux`) | one worktree | ✓ |
| Group A — implementation subject | **16 files** | 16 | ✓ |
| Group A fingerprint | `7410273de4f81eb63d1af5b0723dd7d000637008290c019e27377f67c84de72c` | same | ✓ |
| Group B — activated authority | **2 files** | 2 | ✓ |
| Group B fingerprint | `1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437` | same | ✓ |
| Group C — lifecycle evidence | **15 files** | 15 | ✓ |
| Group C fingerprint | `d438e6835bdaba8493ce3d875bbe4ccece5d99fe95b90471d58f79c16bfdea97` | same | ✓ *(see below)* |
| Combined stable subject | **33 files** | 33 | ✓ |
| Combined fingerprint | `11d3dbd5e8cd803c58ff07ef494e409ef4802569149519bdac505dc6855d9078` | same | ✓ |

**All four reported fingerprints reproduce exactly.** I did not take the manifest's word for
the method — I re-derived each group from `git status --porcelain` plus
`git ls-files --others --exclude-standard`, hashed `<sha256>  <path>` (two spaces), joined
with `\n`, no trailing newline.

**One drift, fully attributed — not product mutation.** Group C did not reproduce on first
computation. Exactly one member had changed: `grimoires/loa/NOTES.md`. Removing lines
301–305 — five `[implement sprint-8, retrospective]` entries — restores the recorded per-file
digest `c2f196f7…` **and** the Group C fingerprint `d438e683…` exactly, and with it the
combined `11d3dbd5…`. The cause is a **retrospective / continuous-learning node that ran at
17:39–17:43**, after the manifest was sealed at 14:54: it wrote five
`grimoires/loa/skills-pending/*/SKILL.md` files and `continuous-learning-2026-08-19.jsonl`,
and appended the matching five lines to NOTES.md. Every one of the 23 added NOTES lines is
`implement sprint-8`-authored content; none originates from this review session. Recorded as
**I-1**, not a finding against the implementation.

**Trajectory churn correctly excluded.** `karpathy-2026-08-19.jsonl` and
`zone-guard-2026-08-19.jsonl` are appended by hooks on every tool call. Excluding them from
the fingerprint while still listing them is the right call, and the manifest's stated reason
is correct: a fingerprint nobody can reproduce reads as tamper evidence while carrying no
information.

**Dependencies correctly in no group.** Both npm trees and the Python closure are gitignored,
reproduced from committed lockfiles/requirements, and hash-verified at install.

---

## 2. What I ran

Everything below was executed on this exact tree, not read from the report.

| Verification | Result | Matches report |
|---|---|---|
| `forge test` (accumulated, 38 suites) | **454 passed, 0 failed, 10 skipped** (464) | ✓ |
| `tools/provenance/run-all.sh` | **11/11 gates green + suite; exit 0** | ✓ |
| `tools/coverage/verify-coverage.sh` | **exit 0** — 598/609, per-file + total floors | ✓ |
| Core line coverage recomputed from raw `lcov.info` | **98.19% (598/609)**; GenesisDeployer/HardReserve/Lens/VUX 100%, Rig 98.70%, Treasury 96.93% | ✓ |
| Slither via the gate | **68 findings, 68 baseline entries, 0 high** | ✓ |
| `forge lint` | **0 high, 4 medium**, all four dispositions verified against source | ✓ |
| Traceability gate | 37/37 INV, 18/18 FB, 44 artifacts present, matrix == fresh generation | ✓ (but see H-1) |
| Playwright copy suite | **46 passed** | ✓ |
| Indexer | **24 passed** (incl. reconstruction equality) | ✓ |
| Web unit | **10 passed** | ✓ |
| `verify:static` / `verify:rsc` | **PASS / PASS** | ✓ |
| Python closure install (`--require-hashes --no-deps`, fresh venv) | **49 installed, exit 0** | ✓ |
| Installed env vs reviewed file | **49 = 49, exact equality**, no extras/omissions/drift | ✓ |
| Reachability from the 2 accepted roots (derived from installed metadata) | **49/49 reachable, 0 orphans** | ✓ |
| Pre-release scan across all 49 pins | **0 pre-releases** | ✓ |
| Evidence-pack path integrity | **88/88** distinct repo-relative paths exist; **257** line refs all within file bounds; 0 dangling | ✓ |
| Native AC verification (scoped slice) | `ac_count: 10, pass: true, violations: []`, exit 0 | ✓ |
| **Probe A** — drop one Slither disposition | gate **FAILS**, names the exact finding, then continues to `forge lint` and reports "1 check(s) failed" | fail-closed confirmed |
| **Probe B** — break one evidence path | traceability gate **FAILS**: "evidence names a path that does not exist" | fail-closed confirmed |

Both probes were restored byte-for-byte and verified by digest.

**Scope slice is correct.** `sprint-8-scope.md` is byte-identical to `sprint.md` lines
529–603 (75 lines) — the Sprint-8 section proper, with plan-level appendices correctly
excluded. The AC validator ran against that slice and found all ten criteria. Sprint 7's
missing-handoff failure is **not** repeated.

---

## 3. Findings

### HIGH

#### H-1 — FB-11 is reported as covered and is not. AC-2 is materially unmet for that row.

`traceability.json` reports `totals.uncovered: []` and 18/18 FB coverage;
`launch-criteria-sweep.md` Row 4 reports "✅ satisfied — 18/18"; `reviewer.md` AC-2 reports
"✓ Met". For **FB-11 ("Voters chase bribes", prd.md §11 row 11)** the underlying evidence
does not exist.

FB-11's only evidence item is:

```
FB-11 | review-checklist -> grimoires/loa/a2a/sprint-5/engineer-feedback.md
```

produced by a hardcoded map at `tools/traceability/build-matrix.mjs:135`. That file contains
**zero** references to FB-11. Searching the whole repository, the only occurrences of `FB-11`
outside the Sprint-8 matrix and the generator that writes it are:

- `grimoires/loa/prd.md:942` — a risk-table cross-reference *to* FB-11, not evidence *for* it;
- `grimoires/loa/sdd.md:338, 351, 953` — SDD design rationale (§1.11 anti-capture, threat row 13).

The SDD material is the **accepted specification being verified**, not verification evidence.
The plan assigns FB-11 to "review + scenario docs … Sprints 3–5 named checklist entries"
(`sprint.md` §D; method assigned at `prd.md:L669`). `grimoires/loa/a2a/sprint-5/evidence/`
contains only `subject-manifest.md`. No scenario note for FB-11 was produced at Sprint 5, and
Sprint 8 did not produce one either — it recorded a pointer instead.

This is the one place in Sprint 8 where a claim is louder than its evidence. The comparison
that makes it clear: FB-17 and FB-18 have exactly this method and got a real artifact
(`fb-17-18-analysis.md`, 6 and 4 substantive references). FB-11 got a filename.

**Severity rationale.** Launch-readiness evidence, not protocol security — the underlying
protocol risk is low (the LSG module is P1 and absent; the P0 boundary is separately proven by
the 21-test `TreasuryLsgBoundary.t.sol` suite). But AC-2 is an explicit acceptance criterion
and "18/18" is an explicit approval condition, and both are false as written. Graded HIGH
because the defect is in the *evidence claim*, which is the entire product of this sprint.

**Remediation (bounded):** produce a named FB-11 scenario note — the honest one is short, and
`sdd.md` threat row 13 already contains its substance: the menu is operator-admitted only,
caps clamp, execution is operator-held, removal is unblockable, escrow defeats flash weight,
so a bribe's entire effect is making an already-diligenced capped option more attractive, and
the mechanism it would act on is P1 and not shipped. Then point FB-11 at it.

---

### MEDIUM

#### M-1 — Six review-checklist citations name artifacts that do not contain the cited row.

`FB_REVIEW_ONLY` (`build-matrix.mjs:129-139`) maps nine rows to files. Seven of the nine
targets do not mention the row they carry:

| Row | Cited artifact | Contains the row? | Real evidence |
|---|---|---|---|
| FB-1 | `sprint-3/engineer-feedback.md` | **no** (has FB-3, FB16) | `sprint-3/evidence/fb-1-mining-redemption-independence.md` |
| FB-6 | `sprint-4/engineer-feedback.md` | **no** (has FB-15, FB-5) | `sprint-4/evidence/fb-6-9-10-12-scenario-notes.md` |
| FB-8 | `sprint-4/engineer-feedback.md` | **no** | 5 named forge tests (carried) |
| FB-9 | `sprint-4/engineer-feedback.md` | **no** | `sprint-4/evidence/fb-6-9-10-12-scenario-notes.md` + tests |
| FB-10 | `sprint-5/engineer-feedback.md` | **no** (has FB-7, FB-8) | `sprint-4/evidence/fb-6-9-10-12-scenario-notes.md` + tests |
| FB-11 | `sprint-5/engineer-feedback.md` | **no** | **none** → H-1 |
| FB-12 | `sprint-5/engineer-feedback.md` | **no** | `sprint-4/evidence/fb-6-9-10-12-scenario-notes.md` + tests |
| FB-17 | `sprint-8/fb-17-18-analysis.md` | **yes** (6) | ✓ |
| FB-18 | `sprint-8/fb-17-18-analysis.md` | **yes** (4) | ✓ |

For the six rows other than FB-11 the evidence genuinely exists — it is simply cited to the
wrong file. The dedicated notes are real and good; `fb-6-9-10-12-scenario-notes.md` even
announces its four rows in its title. An operator following the matrix, which is the artifact
G-6 exists to make sufficient, lands on a document that never mentions the row. That is the
failure the matrix was built to prevent, reintroduced one layer up.

The same wrong attribution is restated in `launch-criteria-sweep.md` Row 4 ("named
review-checklist entries | sprint-3/4/5 `engineer-feedback.md`") and in `reviewer.md` AC-2.

**Remediation:** repoint the six rows at the artifacts that carry them, and correct Row 4 and
AC-2 to match.

#### M-2 — The traceability gate cannot detect H-1 or M-1, and the report overstates what it proves.

`verify-traceability.sh` checks that each evidence path **exists**. It cannot check that the
artifact contains the row. `reviewer.md` AC-2 presents this as:

> "The gate additionally verifies **every named evidence path exists on disk** (44 distinct
> artifacts) … That check caught five dangling references during development, which is the
> failure mode that makes a matrix worse than none."

A dangling reference is the *weaker* failure mode. The stronger one — a path that exists and
does not contain the row — is unguarded, and it is the one that actually occurred, seven times.

Credit where due: `build-matrix.mjs:107-108` is honest about exactly this ("These are
declarations OF LOCATION, not of sufficiency"), and the AC validator states the same limit
("prevents ABSENT evidence, not FABRICATED evidence"). The code is candid; the review
artifacts are not.

**Remediation:** for `review-checklist` and `documented-analysis` rows, assert
`grep -q "<id>" "<file>"`. That single line closes H-1 and M-1 mechanically and would have
failed this tree.

#### M-3 — `e2e-goal-validation.md` quotes the plan's G-1 validation action with "Fork scenario:" removed.

The plan (`sprint.md:571`, verbatim in `sprint-8-scope.md:43`):

> `| G-1 | Faithful monetary core | **Fork scenario:** rehearsal genesis → bootstrap takeover → … | …`

The evidence document (`e2e-goal-validation.md:33`), under the label "**Validation action
(plan):**":

> "rehearsal genesis → bootstrap takeover → …"

"Fork scenario:" is dropped, as is "(PRD Appendix A, incl. the adaptive routing law)". The
plan assigns modality per goal and the distinction is deliberate — G-2 says "on the assembled
system", G-3 "on the assembled stack", G-1 alone says "Fork scenario". G-1 was delivered on
the local assembled system (`GoalValidation.t.sol` extends `GenesisFixture`, which uses
`MockWeth`). The string "fork" appears **zero** times in `e2e-goal-validation.md`,
`launch-criteria-sweep.md`, and `traceability-matrix.md`.

**On the substance, I largely agree with the implementation, which is why this is MEDIUM and
not HIGH.** I examined what fork modality actually discriminates for G-1. The fork suite
(`test/fork/RhWethFork.t.sol`) tests exactly one thing: canonical RH WETH behaviour —
constructor-context native wrap exactness and spendability, no approval/prefunding, and the
Sprint-5 carry that `transfer`/`transferFrom` invoke no recipient callback and emit exactly
one event, each with a discriminating control. Everything else in G-1 — routing law, VEM cap,
halving schedule, redemption arithmetic — is chain-independent. That WETH fact was closed at
Sprint 7 against a **real** fork, and I verified the record rather than assuming it:
`sprint-7/evidence/q6-fork-run.txt` records RH mainnet, `eth_chainId = 4663`, fork block
39130641 with block hash, parent hash and state root, and **10 passed / 0 failed / 0
skipped** — operator-accepted as `SPRINT_7_Q6_NATIVE_WRAP_ACCEPTED`. Reuse of that evidence
is permitted by the plan and I am not asking for redundant fork work.

The defect is presentational and it matters: the artifact of record for G-1 **elides the
requirement it discharged by reuse instead of naming the reuse**. A reviewer who reads only
`e2e-goal-validation.md` cannot tell that a modality requirement existed, let alone how it was
met. The 10 self-skipping fork tests in the 464-test run are also unexplained there (they are
explained in `reviewer.md`, which is not the G-1 evidence artifact).

**Remediation:** quote the plan's G-1 row verbatim including "Fork scenario:", and add a short
paragraph naming the Sprint-7 fork evidence, what it discriminates, and why the remainder of
G-1 is chain-independent. That is a paragraph, not a test run — the argument is already true.

---

### LOW

**L-1 — Stale count in two evidence documents.** `e2e-goal-validation.md:176` and
`launch-criteria-sweep.md:118` both record "74 VUX-owned files match PROV-8". The gate on this
tree reports **75** (74 pre-existing + the new `test/e2e/GoalValidation.t.sol`). The gate is
right and passes; two documents that present themselves as a record of that gate run carry a
number it does not produce.

**L-2 — The runbook-slot assertion is a presence check, not a count check.**
`final-secret-sweep.sh:92` computes `slots=$(grep -c '🔲' …)` and passes when `slots > 0`.
`reviewer.md` AC-5 describes this as "**52 unfilled slots**, mechanically counted and asserted".
Fifty-one resolved slots would still pass. The finding is about the guard, not the tree — I
confirmed all 52 slots are genuinely unfilled and that the only two hex values in the runbook
are the canonical RH WETH address (matching `RhWethFork.t.sol:218`, framed "verify, do not
assume", slot still empty) and `POOL_INIT_CODE_HASH`. Suggested: `(( slots == 52 ))`, or
derive the expected count from the section headings.

**L-3 — `verify-traceability.sh` mutates two Group-C subject files as a side effect.** It
regenerates `traceability.json` and `traceability-matrix.md` in-tree before comparing. Running
the gate therefore changes two files of the reviewed subject. It is deterministic and
re-running restores them byte-exactly (I verified both digests after my probe), but an
exact-tree audit that runs the gate and then fingerprints will see churn unless it re-runs
cleanly first. Worth a one-line note in the gate, or a `--check` mode that generates to a
temporary path.

**L-4 — Beads: the Sprint-8 epic is closed while all eight Sprint-8 tasks are open.**
`vux-21f` (Sprint 8 epic) is `closed`; tasks 8.1–8.8 are all `open`; `vux-1p9` (Sprint 7 epic)
and its six children are `open` although Sprint 7 landed and was accepted; `vux-3g4`
(Sprint 4) likewise. The implementation's NOTES record of this is **accurate in every
particular** — I verified the graph, the blocker relationship (`vux-1p9` blocks `vux-3q1` and
`vux-3gz`, so `br close` skips them), and the both-directions inconsistency. Declining to
`--force` past a declared blocker is the right call and I am not asking for it to be forced.

**Disposition per the review brief: purely lifecycle/bookkeeping drift.** It is **not** a
violation of Sprint-8 implementation acceptance — every substantive claim beads would track is
independently verified above — and it **can remain a bounded closure item** for a hygiene node
or `/ship`. The one part worth flagging beyond the implementation's own record is the
*direction* it did not: a closed epic over open tasks asserts completion for a sprint that has
not yet been reviewed or audited.

---

## 4. Focused-question dispositions

**FOCUS 1 — G-1 assembled / fork evidence.** The complete monetary E2E path *was* executed on
an assembled system launched through the real two-transaction genesis choreography — bootstrap
(zero mint, 88%+/12%), all three adaptive regimes with the test proving its own regime
coverage, a halving boundary derived from `rig.HALVING_PERIOD()`/`MAX_HALVINGS()` and probed
past the cap for tail flatness, and redemption on a mined system. The fork-discriminating
component (RH WETH semantics) legitimately reuses Sprint-7's operator-accepted, genuinely
on-fork evidence, which I verified rather than assumed. Nothing is satisfied by assertion or
by unrelated component tests. **G-1 is achieved; the artifact's presentation of it is
defective — M-3.**

**FOCUS 2 — Slither load-bearing dispositions. Both correct.**
`reentrancy-no-eth` / `redeemUnits`: verified at source — `onlyRole(OPERATOR_ROLE)` +
`nonReentrant` (:643-644); `amountOut` is the treasury's own measured balance delta (:656-658),
so a re-entrant adapter cannot inflate it. I did **not** accept "role-gated" as the proof, and
it is not the only leg. I enumerated the entire re-entrancy surface: **every** permissionless
state-mutating function (`returnFor`, `harvestYield`, `harvestPol`) is `nonReentrant`, and
OpenZeppelin's guard is a single shared lock, so the only reachable cross-function writer is
`closeStrategy` — `onlyRole(OPERATOR_ROLE)` *and* requiring the strategy already de-admitted.
The stale-`basis` write-after-call ordering is real but reachable only by an adapter holding
`OPERATOR_ROLE`, and such an adapter already holds `deployToStrategy`; threat row 9's
"fraud ≤ theft" therefore holds structurally, bounded by cap + 24h maturity + instant removal +
Strategic-only blast radius (core contracts carry no roles at all, threat row 8). The
disposition is if anything stronger than stated.
`unused-return` / `burn`,`swap`: verified. `decreasePol` ignores `burn`'s return and consumes
`collect`'s (:950-953) — consuming both would double-count, since `burn` only credits
`tokensOwed` and `collect` sweeps it. `buyVuxForPol` ignores `swap`'s return in favour of
`vux.balanceOf` measured across the call (:981-988), with `sqrtPriceLimitX96` binding inside
and `minVuxOut` on the measured receipt. Trusting the pool's return to silence the detector
would make the code worse. `burn(...,0)` is the canonical v3 fee-poke idiom.

**FOCUS 3 — Static-analysis supply-chain closure. Verified independently, not read.** Exactly
two authorized roots. I installed the closure into a fresh venv with
`--require-hashes --no-deps` (exit 0), then derived the dependency graph **from installed
package metadata** and BFS'd from the two roots: **49/49 reachable, 0 orphans**, with a
concrete parent for every distribution. Installed set == reviewed file exactly (49 = 49, no
extras, no omissions, no version drift). Stable-only constraint justified and factually
confirmed: `eth-account==0.11.3` really does declare `eth-abi >=4.0.0-b.2`, which is what
admits pre-releases. `eth-abi==5.2.0` (> 5.0.0) ✓. `pycryptodome==3.23.0` (≥ 3.19.1) ✓.
**0 pre-releases** across all 49. No unauthorized wrapper/action/plugin: the workflows use only
`actions/checkout` and `foundry-rs/foundry-toolchain`, both 40-char SHA-pinned; no
`setup-python`, no `crytic/slither-action`, no container. **D-S2 is preserved exactly as
accepted** — `web3==6.20.4` **is present** in the environment and the disposition is "vulnerable
package present, affected path unreachable on the authorized invocation", enforced by a live
no-RPC control; none of the prohibited restatements ("fixed", "absent", "non-vulnerable")
appears anywhere. No scanner-driven architecture distortion: `slither.config.json` disables
**no** detector and suppresses **no** severity class; `filter_paths: vendor/` excludes
byte-identical censused upstream from *reporting* while still *parsing* it for a correct call
graph — the right trade, and reasoned in the file.

**FOCUS 4 — MetaMask / ConsenSys residual. Factually accurate; absence independently
re-established with a stronger test.** Entry path confirmed from the lockfile: root `web` →
`wagmi@2.14.16` → `@wagmi/connectors@5.7.12` → `@metamask/sdk@0.32.0`, and all three MetaMask
SDK packages are `dev:false, optional:false, peer:false` — **production, non-optional**, exactly
as the implementation states. Licence facts confirmed at source: `package.json` declares **no**
`license`; the tarball `LICENSE` is a ConsenSys proprietary grant limited to Non-Commercial Use
(defined to include a ≤10,000-MAU ceiling) — a field-of-use restriction incompatible with
GPL-3.0-or-later conveyance. **On distribution I did not rely on the implementation's evidence,
because three of its six search strings (`ConsenSys`, `Non-Commercial`, `MetaMaskSDK`) are
comment/identifier text a minifier strips or renames.** I instead extracted string literals —
which minifiers preserve — from the real installed SDK bundle and searched the built export for
fourteen of them (`metamask_getProviderState`, `metamask-provider`, `METAMASK_STREAM_FAILURE`,
`__isMetaMaskShim__`, `metamask_connectSign`, `SocketService`, `metamask-sdk.api.cx.metamask.io`,
`socket.io-client`, `METAMASK_EXTENSION_CONNECT_CAN_RETRY`, `metamask_batch`,
`metamask_chainChanged`, `sdk-communication-layer`, and the two above). **All absent**, with
positive controls (`eth_requestAccounts`, `wagmi`, `metaMask`) present, proving the scan
discriminates. The single `metaMask` hit is exactly what TPN claims — an entry in wagmi's own
MIT injected-wallet detection table (`metaMask:{id:"metaMask",name:"MetaMask",provider:e=>d(e,e=>{if(!e.isMetaMask…`),
a detection predicate, not SDK code. The structural argument also holds: `wagmi` and
`@wagmi/connectors` both declare `sideEffects: false`, and only `injected()` is configured, so
tree-shaking of the `metaMask()` connector is sound rather than hopeful. TPN §6.3 characterizes
this correctly and does not overreach — "the distributed artifact is clean; the development and
CI environment installs proprietary non-commercial code … a bounded, disclosed residual carried
to the operator, not a resolved one." **I make no legal determination**; the jurisdiction
question is correctly routed to Q-4 as a pre-launch legal gate with its own runbook slot (§5.7),
which is where it belongs. Recorded as **I-3** only that TPN's own stated evidence is weaker
than its conclusion deserves.

**FOCUS 5 — TPN and historical hash reconciliation. Implementation's disposition is correct:
category (1), deliberately historical.** The live gate is `census.sh:33` `TPN_SHA256`, consumed
by `verify-notices.sh:24 require_authority` — it was updated to `40abb254…` and matches the
actual file. **No gate reads `sprint.md`**: every `sprint.md` reference in `tools/` and
`.github/` is a prose citation ("Enforces (sprint.md Sprint 1 acceptance criterion 6)"), never a
hash read. `sprint.md:33` is the accepted Sprint Plan's point-in-time Authority Chain, and the
plan is itself accepted at its own SHA, so editing it would invalidate that acceptance.
`vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md:98` is a "predecessor authority unchanged at
this refreeze" attestation, and that document's own hash is pinned in `census.sh`
(`TOOLCHAIN_MD_SHA256`) — editing it would **break a live gate**. Leaving both untouched is
required, not merely permitted. Critically, the **new** Sprint-8-authored authority makes no TPN
hash claim at all, so no new staleness was introduced. The Sprint-6 precedent invoked
(`sdd.md:L449`, "stale descriptive reference, not a normative contradiction") is real. **No
finding**; recorded as **I-4** that a reader of the Authority Chain sees a TPN hash that no
longer matches the file.

**FOCUS 6 — Release-compliance truth. Established.** Root `LICENSE` unmodified GPLv3
(`sha256:8ceb4b9e…`, 674 lines) — gate green. TPN now reflects reality; the repaired §6 preamble
replaced a statement ("None installed. Nothing imported or vendored yet.") that was flatly false
against 63 vendored files and two npm roots. SPDX gate: 63/63 vendored retain upstream SPDX
verbatim, 75/75 VUX-owned match PROV-8, no invented copyright holder. Both censuses are coherent
and reproducible from committed inputs — off-chain 675 packages, static-analysis 49
distributions with 0 undeclared and 0 yanked, copyleft family 4 (three AGPL-3.0 Trail of Bits +
`certifi` MPL-2.0), matching TPN §6.4 exactly. Static analysis is classified as **toolchain**,
consistent with the accepted treatment of solc and Foundry, and the AGPL non-propagation
argument is sound on its own strongest leg: the shipped artifact is byte-identical whether or
not slither is installed. No unauthorized source entered — source universe 138 = 63 vendored +
75 VUX-owned, zero unauthorized, and the only new Solidity in the whole sprint is
`test/e2e/GoalValidation.t.sol` inside an already-accepted root. (L-1 is the only defect here.)

**FOCUS 7 — Runbook reserved-value discipline. Clean.** 52 slots, covering every required
category: Q-3 Safe facts §5.1, conversion values §5.2, genesis price §5.3, fee/tickSpacing §5.4,
schedule start §5.5, launch secrets §5.6, Q-4 §5.7, R-14 post-deployment §5.8, chain environment
§5.9. **None** silently acquires a production value: no filled slot, no default, no copied
rehearsal value, no predicted address, no 64-hex secret. The only two addresses present are the
canonical RH WETH (an established public chain fact already in accepted authority, matching
`RhWethFork.t.sol:218`, and explicitly framed "verify, do not assume" with its slot still empty)
and `POOL_INIT_CODE_HASH` (a CI-reproduced software constant). §17 quarantine gate clean on all
ten guidance values. The structure is executable while the production facts stay absent —
exactly the intended shape. Private routing is stated precisely and prominently: "REQUIRED for
confidentiality; **NOT a security assumption**", "non-load-bearing for security", "Security by
obscurity is not claimed anywhere", and "Genesis is still safe. It cannot be pre-created,
pre-initialized, pre-funded into failure or distortion, occupied, raced, or poisoned." (L-2 is
about the guard, not the tree.)

**FOCUS 8 — Trust inventory. Accurate.** Canonical RH WETH is explicitly **YELLOW** — "7-of-8
Robinhood Chain authority", no-delay upgrade path, "catastrophic-external: could block, burn,
freeze, or seize Reserve WETH" — and is the only YELLOW entry, with everything above it either
trustless by construction or bounded to Strategic assets. No absolute trustless claim survives
anywhere; the document opens with "**VUX is not trustless.**" and the prohibited-phrase list is
enforced mechanically (`truth-copy.js:87` + Playwright on rendered output, 46/46). INV-36
coupling is structural, not editorial: `ReserveDescription.jsx` is the only component that
describes the Reserve as ownerless/immutable and always renders the YELLOW text with it. FB-17
and FB-18 have real, substantive analyses, and the FB-17 degraded-state disclosure is
mechanically asserted ("the chain-outage banner appears when live reads cannot be made"). R-Y1
correctly records the YELLOW as structurally unmitigable.

**FOCUS 9 — Secret hygiene. Adequate, and it avoids the trap.** Scope confirmed: `git ls-files`
= **436**, no directory excluded — genuinely wider than the per-push gate. Patterns require
key-shaped *context* rather than entropy, which is correct reasoning (a bare 64-hex scan matches
every census digest and commit SHA in the repository). **On truncated-output false assurance:
the scan is clean.** `scan()` captures the complete hit set into `$hits`, decides pass/fail on
`[[ -z "$hits" ]]`, and truncates only the *display* via `head -20` — the verdict is over all
results. Classes covered map to the runbook's own §5.6 launch-secret list (EOAs, commitment
salt, relay credentials) plus PEM blocks, mnemonics, credential-shaped tracked files, and
broadcast artifacts. The absence is proven without any production value existing, as required.
Bounded honestly: absence is established for key-shaped *context*, not every conceivable
encoding — which `reviewer.md` states accurately.

**FOCUS 10 — Toolchain/gate isolation defects. Fixes verified, and they fail loudly.** All six
repairs check out. Slither artifacts isolated via `--foundry-out-directory out-slither`, coverage
via `FOUNDRY_OUT=out-coverage`, both gitignored, and the coverage gate additionally asserts "normal
build present in `out/` for the artifact-reading suites" — so the poisoning class is now guarded,
not merely avoided. The `set -e` fix is demonstrably load-bearing: under **Probe A** the gate
reported the failing check, then *continued* to run `forge lint` and closed with "1 check(s)
failed" — accumulate-and-report, exactly what `-e` was destroying. Interpreter selection is by
trial rather than by name, and I watched it work on this machine, where `python3` really does
resolve to the Microsoft Store stub: the gate rejected it and selected `python` 3.11.15 after
executing the range check. `.gitignore` anchoring verified both ways — `git check-ignore` no
longer matches `tools/coverage/verify-coverage.sh`, while root `coverage/` is still ignored. The
§17 quarantine repair is the right trade: every E2E boundary now derives from
`rig.HALVING_PERIOD()`/`rig.MAX_HALVINGS()` rather than a literal, which is independently better
than relaxing the gate. **Probe B** confirms the traceability gate fails loudly on a broken path.
Neither gate is green by execution order. (Their remaining weakness is M-2 — depth, not order.)

---

## 5. Sprint-8 AC-by-AC disposition

| AC | Criterion (abbrev.) | Report | My disposition |
|---|---|---|---|
| AC-1 | Zero unexplained slither findings; slither entered CI only after pin acceptance | ✓ Met | **✓ Met** — 68/68 dispositioned, 0 high, reproduced; fail-closed proven by Probe A; pre-acceptance install state recorded in the registry and CI entry post-dates `activation: ACTIVE` |
| AC-2 | 37/37 INV + 18/18 FB with named evidence per assigned method; review-only rows have named checklist entries | ✓ Met | **✗ NOT MET** — 37/37 INV holds; FB-11 has no evidence for its assigned method (**H-1**) and six further review-only rows are cited to artifacts that do not contain them (**M-1**) |
| AC-3 | §20.1 sweep green, 8/8 | ✓ Met | **✓ Met** — 8/8 resolved, procedure/production split correct; Row 4's citation inherits M-1 |
| AC-4 | ≥90% core line coverage; accumulated suite green | ✓ Met | **✓ Met** — 98.19% recomputed from raw lcov, dual floors, derived core surface; 454/0/10 |
| AC-5 | Runbook complete, every reserved input slotted, none resolved | ✓ Met | **✓ Met** — 52 slots, all categories, zero leakage (guard weakness = **L-2**, not an AC miss) |
| AC-6 | GPLv3 unmodified; TPN §6/§6.1/§6.2 match vendored reality | ✓ Met | **✓ Met** — LICENSE byte-verified; §6.1/§6.2 census content unchanged and gate-verified 63/63 |
| AC-7 | G-1…G-6 documented with pass evidence; none "not achieved" unjustified | ✓ Met | **✓ Met** — 6/6 evidenced; G-1's presentation defective (**M-3**) but the goal is achieved |
| AC-8 | No production secret/address/broadcast artifact anywhere | ✓ Met | **✓ Met** — 436 files, no exclusions, complete-set verdict |
| AC-9 | Each goal documented; integration points verified end-to-end | ✓ Met | **✓ Met** — assembled-system integration genuinely exercised |
| AC-10 | No goal marked "not achieved" without justification | ✓ Met | **✓ Met** — clause not exercised |

**9 of 10 met. AC-2 is the exception.**

Native AC verification (`validate-ac-verification.sh`, scoped slice): `ac_count: 10, pass:
true, violations: []`. Note its own declared limit — it proves evidence is not *absent*, not
that it is *sufficient*. H-1 lives precisely in that gap, which is why it took a content check
to find.

---

## 6. G-1…G-6 disposition

| Goal | Verdict | Basis |
|---|---|---|
| **G-1** Faithful monetary core | **Achieved** | Assembled two-tx genesis; bootstrap 0-mint/88%+/12%; all three adaptive regimes with self-proving coverage; halving + flat tail derived from contract constants; pro-rata redemption on a mined system; frozen constants read off the live instance. Fork-discriminating WETH facts reused from Sprint-7's verified on-fork run. Presentation defective — **M-3** |
| **G-2** Dual-treasury separation | **Achieved** | Loss at 50/80/100% *of what remains* (doc states this precisely), value destroyed to `0xDEAD` with no adapter cooperating; backing, supply, throne and epoch unchanged at each depth; core keeps functioning afterwards; total drain leaves the hard claim paying exactly `floor(held × B / S)`; no allowance in either direction. FB-5/FB-7 carried. "Bit-identical" = those four core cells, which is the correct state and conceals no *disallowed* Strategic difference (Strategic state changes, as it must) — **I-5** |
| **G-3** Truthful UX | **Achieved** | Three tiers stay distinct across Lens → events/indexer → reconstruction → API/frontend. 46 Playwright + 24 indexer (incl. reconstruction equality, eventless donations, null-not-zero) + 10 web unit, all reproduced; static-export and RSC gates PASS. No earned/owed/guaranteed leakage; prohibited phrases asserted on rendered output |
| **G-4** LSG-ready boundary | **Achieved, correctly bounded** | `lsgModule() == address(0)` on the assembled genesis output; 365 days pass without activation (affirmative, never calendar-driven); unauthorized caller rejected; activate/deactivate lifecycle works with instant deactivation; INV-32…34 negatives hold; 21-test boundary suite. **P1 did not enter** — no `LSGSignals`, no reward machinery, no adapters. I did not ask for the Signal module |
| **G-5** Provenance discipline | **Achieved** | Default-deny holds; 11/11 gates real and reproduced; static-analysis authority activation authorized *only* slither/crytic-compile (registry: `wildcard_family_authorization_granted: false`, `unrelated_dependency_expansion_authorized: false`); the 49 Python distributions are tooling only, never conveyed; no unauthorized Solidity (138-file universe, zero unauthorized); census 63/63 and `POOL_INIT_CODE_HASH` intact |
| **G-6** Operator reviewability | **Achieved with a caveat** | 20/20 §21 questions answerable from artifacts; evidence pack complete; 88/88 repo-relative paths exist and 257 line refs are all in bounds. The caveat is real: for seven FB rows the matrix routes an operator to a document that does not discuss the row (**H-1/M-1**), which is a G-6-shaped defect — the artifacts must be sufficient *without* chat memory |

---

## 7. Slither / forge-lint review

68 findings across 11 detector classes; **0 high-impact**; 68/68 dispositioned (37
accepted-design, 16 false-positive, 15 informational). Reproduced through the gate on this
tree. The baseline is keyed and the gate rejects an unknown finding, a stale entry, and any
High unconditionally — Probe A confirmed the first of those live, naming the exact orphaned
finding and refusing the tree. No detector or severity class is suppressed; the `vendor/`
reporting filter is correct and reasoned (parsed for call-graph correctness, excluded from
reporting because acting on a finding there would break a byte-identical census).

`forge lint`: **0 high, and high is deliberately not baselined** — the first high-severity
finding stops the build rather than being absorbed, which is the right policy. All four medium
dispositions verified against source, not accepted on assertion:

- `StrategicTreasury.sol:441-443` — `(MIN_TICK / spacing) * spacing`: the truncation **is** the
  tick-alignment operation. Genuine false positive.
- `StrategicTreasury.sol:1071` — `uint256(wethDelta)` is guarded on the immediately preceding
  line (`if (wethDelta <= 0 || vuxDelta >= 0) revert CallbackDirectionMismatch(...)` at :1069).
  Confirmed at source; the cast cannot wrap.
- `GenesisDeployer.sol:554` — `bytes1(uint8(nonce))` is guarded at :552
  (`if (nonce == 0 || nonce > 0x7f) revert NoncePredictionOutOfDomain(nonce)`). Confirmed;
  domain 1…0x7f, uint8 cannot truncate.

No architecture was distorted to satisfy a scanner, and no cosmetic zero-warning target was
pursued — the stated target is "no unexplained or improperly dispositioned finding", which is
the correct one.

---

## 8. Finding counts

| Severity | Count | IDs |
|---|---|---|
| Critical | **0** | — |
| High | **1** | H-1 |
| Medium | **3** | M-1, M-2, M-3 |
| Low | **4** | L-1, L-2, L-3, L-4 |
| Informational | 5 | I-1 … I-5 |

**Classification.** Protocol correctness/security: **0**. Launch-readiness evidence: H-1, M-1,
M-3. Tooling reliability: M-2, L-2, L-3. Provenance/licence/release correctness: **0**
(L-1 is a stale count in a report, not a provenance defect). Documentation/lifecycle
bookkeeping: L-1, L-4.

---

## 9. Bounded remediation list

Return to `/implement sprint-8`. Nothing here requires a Solidity change, a new test run, or
any authority edit.

1. **[H-1]** Author a named FB-11 scenario/review note (the substance already exists at
   `sdd.md` threat row 13 and §1.11) and repoint FB-11's evidence at it.
2. **[M-1]** Repoint the six mis-cited review-checklist rows at the artifacts that actually
   carry them — FB-1 → `sprint-3/evidence/fb-1-mining-redemption-independence.md`;
   FB-6/9/10/12 → `sprint-4/evidence/fb-6-9-10-12-scenario-notes.md`; FB-8 → its named forge
   tests — in `build-matrix.mjs`, and correct the restatements in `launch-criteria-sweep.md`
   Row 4 and `reviewer.md` AC-2.
3. **[M-2]** Add a content assertion to `verify-traceability.sh` for `review-checklist` and
   `documented-analysis` rows (`grep -q "<id>" "<file>"`), and soften AC-2's description of
   what the gate proves. Confirm it fails on the pre-fix tree.
4. **[M-3]** Quote the plan's G-1 validation action verbatim in `e2e-goal-validation.md`
   including "**Fork scenario:**", and add a short paragraph naming the Sprint-7 fork evidence
   (`sprint-7/evidence/q6-fork-run.txt`, chainid 4663, block 39130641, 10/10), what it
   discriminates, and why the rest of G-1 is chain-independent. Also note there why the 10
   fork tests self-skip in the 464-test run.
5. **[L-1]** Correct "74 VUX-owned files" → **75** in `e2e-goal-validation.md:176` and
   `launch-criteria-sweep.md:118`.
6. **[L-2]** Strengthen the runbook-slot assertion from `slots > 0` to an exact count, and
   align AC-5's wording with what it asserts.
7. **[L-3]** *(optional)* Give `verify-traceability.sh` a check-only mode, or note in the gate
   that it regenerates two subject files in place.
8. **[L-4]** *(defer)* Leave the beads graph alone. Record it for a hygiene node or `/ship`
   closeout, together with the Sprint-7 and Sprint-4 epics. Do **not** `--force` past the
   declared blocker.

Items 5–8 are not independently blocking; fold them in while items 1–4 are addressed.

---

## 10. Review-node hygiene

**Files written by this review:** exactly one —
`grimoires/loa/a2a/sprint-8/engineer-feedback.md` (this file).

**Implementation and authority bytes are unchanged.** Re-verified after every probe:
Group A reproduces `7410273de4f81eb63d1af5b0723dd7d000637008290c019e27377f67c84de72c` and
Group B reproduces `1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437` —
byte-identical to entry. All fourteen non-NOTES Group C files match their recorded digests,
and `NOTES.md` is unchanged from review entry (`6e254c9a…`).

**Temporary mutations, all restored and digest-verified:** Probe A dropped one entry from
`triage-baseline.json` (restored, `d5ad0067…` before and after); Probe B repointed one path in
`build-matrix.mjs` (restored, `e48bd7da…` before and after). Probe B additionally caused the
gate to regenerate `traceability.json` and `traceability-matrix.md` in place — both were
regenerated from the restored generator and verified back to their manifest digests
(`2169e2a1…`, `81a26f03…`). See **L-3**.

Build artifacts (`out/`, `out-slither/`, `out-coverage/`, `lcov.info`) and the review's Python
venv are gitignored and outside every subject group.

**Nothing was committed, pushed, tagged, landed, deployed, or marked complete. No audit was
begun. No sprint was closed. No beads state was changed.**

---

## 11. Recommendation

**`SPRINT_8_REVIEW_CHANGES_REQUIRED`.**

I want to be plain about proportion: this sprint is close, and the work behind it is of high
quality. Zero protocol findings. The static-analysis provenance chain is the most rigorous
piece of supply-chain work in this cycle — a hash-pinned closure I could install and prove
orphan-free from metadata alone, with the analyzer reading the accepted build rather than
making its own. Six real defects were found and repaired in the verification surfaces, and the
implementation reported them itself rather than letting them pass as green. The runbook holds
the line on reserved values. The trust documentation refuses the comfortable claim.

I am not holding approval for cosmetic perfection, and I am not asking for redundant fork work
or for the beads graph to be forced clean. I am holding it for one thing: an acceptance
criterion and an approval condition both state 18/18 failure-behaviour coverage, and for FB-11
that coverage does not exist — its evidence is a filename, and the gate meant to catch that
checks only that the filename resolves. Six further rows point at the wrong documents. On a
sprint whose entire product is launch-readiness *evidence*, evidence that does not exist where
it is claimed is the one thing that has to be fixed before audit, not after.

The fix is a few hours of writing and one line of gate logic.

**Recommended next node:** `/implement sprint-8` for items 1–4 (with 5–8 folded in), then a
focused re-review of the changed rows and the strengthened gate. Audit should follow the
re-review, not this node.

---

*Reviewed by the Loa `/review-sprint sprint-8` node, 2026-08-19. Every claim above was*
*re-derived on the exact tree: all four subject fingerprints, the full accumulated suite, all*
*eleven provenance gates, the coverage gate plus an independent recomputation from raw lcov,*
*a from-scratch install of the 49-distribution Python closure with reachability derived from*
*installed metadata, the Playwright/indexer/web suites, the static-export and RSC gates, the*
*native AC validator against the scoped plan slice, two fail-closed negative probes, a*
*minification-surviving fingerprint test against the built export that the implementation did*
*not run, and source-level verification of both load-bearing Slither dispositions and all four*
*forge-lint dispositions. Nothing was accepted on report. No implementation source, test,*
*build configuration, authority document, or provenance registry was mutated — Group A and*
*Group B are byte-identical before and after this review. Nothing was committed, pushed, or*
*marked complete, and no audit was begun.*

<!-- LOA-VERDICT {"gate":"review","verdict":"CHANGES_REQUIRED","counts":{"critical":0,"high":1,"medium":3,"low":4},"sprint_id":"sprint-8","ts":"2026-08-19T00:00:00Z"} -->
