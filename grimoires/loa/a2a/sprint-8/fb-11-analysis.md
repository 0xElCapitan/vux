# FB-11 — Voters Chase Bribes: Review-Assigned Scenario Analysis

**Node:** `/implement sprint-8`, bounded remediation of review finding **H-1**
**Register method:** FB-11 is assigned to *review + scenario documentation*, not to an
automated test — `prd.md:L669` ("FB-1, FB-6, FB-8…FB-12 by review + scenario documentation"),
restated at `sdd.md:L869` and carried in the plan at `sprint.md:738` ("FB-1, 6, 8, 9, 10, 11,
12 (review+scenario docs) | Sprints 3–5 named checklist entries | — | Sprint 8 matrix").
This file is that documentation. It is the evidence the traceability matrix names for FB-11.

> **Requirement (prd.md:659, §11 row 11).**
> **Condition:** *Voters chase bribes.*
> **Required canonical outcome:** *Only admitted/capped Strategic allocations are exposed;
> admission/risk authority may remove/recall.*

**Why this row previously had no artifact.** Sprint 8's matrix cited
`grimoires/loa/a2a/sprint-5/engineer-feedback.md` for FB-11. That file does not mention FB-11;
no Sprint 3–5 node produced the named checklist entry the plan assigns. The pointer was a
location declaration that pointed at nothing. This note is the missing evidence, and the
matrix now cites it.

---

## 1. What the condition actually denotes in this design

"Voters chase bribes" is not a generic governance worry here. The LSG is deliberately **not a
DAO** (`sdd.md:330`): there are no proposals, ballots, quorums, or yes/no questions. The only
thing a holder can express is a *relative preference vector over admitted strategies*, and the
only thing a bribe can buy is movement in that vector.

The bribe primitive is named and bounded in the accepted design (`sdd.md:346`, §1.11
"Signaler rewards & bribes"): `fundBribe(token, amount, start, end, strategy)` is
permissionless and creates an `EXTERNAL`-provenance reward program that **requires the target
strategy to be currently admitted**. Its counterpart `fundSignalerProgram` is the
`PROTOCOL`-provenance path, spendable only from the revenue-bounded `signalerBudget` earmark.

So the scenario to analyse is concrete: *an outside party funds reward programs to pull
signaling weight toward a strategy of its choosing, and holders follow the money.* The
question FB-11 asks is what that can reach.

**Shipping status, stated plainly.** The `LSGSignals` module — staking, preference vectors,
reward accrual, `fundBribe` — is **P1 and absent from `src/`** (`ls src/` carries no LSG
contract; `sdd.md:322` scopes P0 to "boundary + activation authority", P1 to "module
implementation"). What ships at P0 is the treasury-side surface: the `lsgModule` slot
(`src/StrategicTreasury.sol:282`, `address(0)` at launch), `activateLSG`/`deactivateLSG`
(`:799`, `:807`), the consumption path `deployMarginalBySignal` (`:835`), and the earmark
spend `fundSignalerProgram` (`:882`). FB-11's canonical outcome is therefore discharged in two
layers, and this note separates them rather than blurring them:

- **Layer 1 (P0, mechanically tested today):** the treasury-side boundary — what *any* module,
  captured or not, can cause the treasury to do.
- **Layer 2 (P1, design-bound):** the module-side accrual rules, which are accepted design not
  yet code, and which this note treats as design analysis rather than as evidence of a
  shipped mechanism.

---

## 2. Clause 1 — "Only admitted/capped Strategic allocations are exposed"

The clause has three sub-claims. Each is tested at P0 against `MockLsgModule`, which is a
**maximally adversarial** stand-in: the test author writes the signal directly, so every test
below is exactly the "captured module" case FB-11 postulates. A module that has been fully
bribed is, to the treasury, indistinguishable from `MockLsgModule` under test control.

### 2.1 Only *admitted* targets are reachable

`test/treasury/TreasuryLsgBoundary.t.sol:178`
`test_ASignalCannotReachAnUnadmittedUnmaturedOrRemovedTarget` signals four addresses at equal
weight — one admitted-and-matured, one admitted-but-unmatured, one removed, one never admitted
— and asserts:

| Target | Outstanding principal after | What it proves |
|---|---|---|
| admitted + matured | `100 ether` — "the eligible one took it all" | the menu is the admitted set |
| unmatured | `0` — "the delay is not bypassable" | a bribe cannot buy past `ADMISSION_DELAY` |
| removed | `0` — "removal is not overridable" | removal survives contrary signal |
| never admitted | `0` — "admission is not signalable" | **a bribe cannot cause an admission** |

The last row is the load-bearing one. The most valuable thing a briber could buy — getting a
new address onto the menu — is not on sale at any price, because the signal is read as a
*filter over the admitted registry*, not as an instruction.

### 2.2 Caps clamp, and the remainder does not leave custody

`:161` `test_CapsClampTheSplitAndTheRemainderStaysInCustody` admits one strategy at a
`10 ether` cap and one at `1_000 ether`, signals them 1:1, and deploys `100 ether`. The
capped strategy receives exactly `10 ether`; the other receives its own `50 ether` share
**unclamped and unredistributed**; and `60 ether` total leaves the treasury — the remaining
`40 ether` "never left custody". Two things follow that matter for FB-11: a bribe cannot raise
a cap, and **overflow above a cap is not reallocated to the briber's second choice** — it
simply is not deployed. Concentrating signal on a capped target converts bribe spend into
undeployed dry powder.

`:229` `test_ADuplicatedSignalEntryClampsRatherThanReverting` closes the adjacent denial
vector: repeating a name clamps against live headroom rather than reverting, so a captured
module cannot block allocation by malforming its own weights.

### 2.3 Nothing outside Strategic is exposed at all

`:208` `test_ASignalNamingTheMonetaryCoreReachesNothing` has the module signal the Hard
Reserve, the Rig, and the VUX token at weight `1_000` each against one admitted strategy at
weight `1`. After the call, `_assertCoreUnchanged` shows **every core value bit-identical**,
and the admitted strategy took the full `100 ether`. The core addresses are not admitted, so
they are not on the menu — the exclusion is structural, not a check that could be
misconfigured. This is INV-33 ("LSG cannot reach Hard, minting, arbitrary recipients, security
parameters, exploit response, or upgrades", `prd.md:628`) exercised through the exact surface
a briber would use.

`:371` `test_TheModuleHoldsNoAllowanceOverTheTreasury` asserts the complementary negative: the
treasury grants the module **zero standing allowance and zero role**, even immediately after
funding it. A captured module holds no authority it could exercise directly.

**Clause 1 therefore holds, and holds in the strong form**: the exposed set is exactly
`admitted ∩ matured ∩ cap-headroom`, and it is bounded above by an amount the operator chose
when they called `deployMarginalBySignal(totalAmount)` — a briber does not choose the size of
the flow, only its split.

---

## 3. Clause 2 — "Admission/risk authority may remove/recall"

`removeStrategy(address, bool emergency)` (`src/StrategicTreasury.sol:506`) is
`onlyRole(OPERATOR_ROLE)`, takes no module input, consults no signal, and has **no branch that
can fail on account of LSG state** — it flips `a.active = false` and emits. There is nothing
for a captured module to block.

`:354` `test_DeactivationSeversFundingAndStrandsNothing` proves this against a dead module in
one test: after `deactivateLSG()`, further `fundSignalerProgram` reverts with `LSGInactive`,
the earmark is **intact** (`20 ether`), and the operator then calls
`treasury.removeStrategy(address(alpha), true)` successfully — asserted as "operator authority
survives a dead module". `:83` `test_DeactivationIsInstantAndEvented` establishes that
severance takes effect immediately, with no timelock a briber could wait out or fund through.

The recall half of "remove/recall" is `recallFromStrategy` (`src/StrategicTreasury.sol:533`),
and its contract comment states the FB-11-relevant property directly: it is *"deliberately
**not** gated on admission: recall must work after removal … also not cap-gated — a cap bounds
exposure, and reducing exposure can never breach one"* (`:529`). Neither `removeStrategy` nor
`recallFromStrategy` reads `lsgModule` at all. Withdrawal of exposure is unconditional in
exactly the dimensions a captured signal might otherwise be able to obstruct.

**Clause 2 holds.** The authority FB-11 requires to remain available is not merely available —
it is on a different plane from the signal entirely (`sdd.md:357`, §1.12: "LSG allocation
authority" and "emergency/risk authority" are two of five *disjoint* planes).

---

## 4. Why the bribe cannot escalate — the accepted design argument (P1 layer)

The tests above bound what a captured module can cause **regardless of how the module
computes its signal**, which is why they are sufficient for FB-11's canonical outcome. The
module-side rules below are accepted design (`sdd.md:338`, `sdd.md:346`) and are recorded here
as analysis, not as evidence of shipped code:

- **Funding grants nothing.** "Funding a program touches no registry and grants nothing — it
  cannot admit a strategy, raise a cap, or reach the Hard Reserve, VEM, minting, redemption,
  KOTH routing, security parameters, or upgrades" (`sdd.md:346`). The funding functions write
  only program-accounting state.
- **The target must already be admitted.** `fundBribe` requires current admission, so bribe
  capital cannot even be *staged* against an address the operator has not diligenced.
- **Escrow defeats flash weight.** Weight is escrowed VUX, so stake→signal→unstake inside one
  transaction nets to zero standing weight (`sdd.md:331`). Bribing is therefore a duration
  cost, not a single-block purchase.
- **Protocol-owned VUX is structurally excluded.** The pool never stakes and the treasury is
  rejected as a staker (`staker != strategicTreasury`), so protocol voting power ≡ 0 under any
  future module (F-38, INV-27; `sdd.md:344`). A briber cannot rent the protocol's own weight.
- **Provenance never commingles.** `PROTOCOL` and `EXTERNAL` programs carry distinct ids and a
  distinct provenance field on `ProgramFunded`, so treasury-funded incentives and outside
  bribes remain distinguishable end-to-end — the disclosure surface stays truthful.
- **Additivity.** "If external bribes are zero, nothing anywhere changes: programs are
  strictly additive."

---

## 5. Residual — what is accepted, not mitigated

`sdd.md:953` (threat model row 13) states the accepted residual verbatim: **"Signal skew
within the admitted+capped menu is accepted (FB-11) — a bribe's entire effect is making an
already-diligenced, capped option more attractive."**

Stated as an outcome: a fully successful bribery campaign moves *marginal* Strategic flow, at
an operator-chosen total size, among strategies the operator already admitted and already
capped, at a moment the operator chose to deploy. It cannot enlarge the menu, the caps, the
size, or the timing, and it cannot touch the Hard Reserve, issuance, redemption, or routing at
all. `prd.md:942` grades this Medium-probability / **Low-impact** for exactly this reason.

VUX does not claim bribery is prevented. It claims — and this note is the argument, with §2
and §3 as its mechanical anchors — that **the blast radius of a fully bribed signal is a
strict subset of what the operator has already authorised.**

---

## 6. Evidence index for this row

| Claim | Anchor | Kind |
|---|---|---|
| Requirement text | `grimoires/loa/prd.md:659` | authority |
| Method assignment | `grimoires/loa/prd.md:669`; `grimoires/loa/sdd.md:869`; `grimoires/loa/sprint.md:738` | authority |
| Anti-capture design | `grimoires/loa/sdd.md:338`, `:346` | authority |
| Accepted residual | `grimoires/loa/sdd.md:953` (threat row 13); `grimoires/loa/prd.md:942` | authority |
| Admission not signalable | `test/treasury/TreasuryLsgBoundary.t.sol:178` | forge test |
| Caps clamp; overflow stays in custody | `test/treasury/TreasuryLsgBoundary.t.sol:161` | forge test |
| Core unreachable from the signal | `test/treasury/TreasuryLsgBoundary.t.sol:208` | forge test |
| Module holds no allowance or role | `test/treasury/TreasuryLsgBoundary.t.sol:371` | forge test |
| Removal/recall survives a captured module | `test/treasury/TreasuryLsgBoundary.t.sol:354`, `:83` | forge test |
| Removal path takes no LSG input | `src/StrategicTreasury.sol:506` | implementation |
| Recall ungated by admission or cap | `src/StrategicTreasury.sol:529`, `:533` | implementation |
| Module absent at P0 | `src/` carries no LSG contract; `sdd.md:322` | implementation |

All twelve anchors are in the Sprint-8 tree and were re-read while writing this note. The
`TreasuryLsgBoundary.t.sol` suite is 21 tests, all passing in the accumulated Sprint-8 run.

**FB-11 is satisfied**, with the residual in §5 accepted and disclosed rather than mitigated.
