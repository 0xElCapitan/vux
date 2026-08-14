# FB-6 / FB-9 / FB-10 / FB-12 — review-assigned scenario notes

**Node:** Sprint 4 implementation (Task 4.9)
**Carries:** prd.md §11 (FB register, L645-L669); acceptance assigns FB-6 and FB-9…FB-12 to
"review + scenario documentation" rather than to automated tests (prd.md:L669)
**Status:** implementation-side notes for `/review-sprint sprint-4`

Each row states the required canonical outcome, the code that makes it true, and the mechanical
evidence that exists **even though** the row is review-assigned — several are automatable in
part, and where they are, the test is named rather than left implicit.

---

## FB-6 — ROOT impaired or GIGA reprices

> Required outcome: *Strategic loss only; admission/position/operator risk policy respond; no
> Hard claim.*

**Why it holds structurally.** ROOT and GIGA are, to this code, ordinary admitted strategies:
`src/StrategicTreasury.sol` names no asset, no venue, and no counterparty. An impairment is
therefore indistinguishable from any other Strategic loss, and Sprint 4 has already proven that
class of event bit-identical-safe for the core (FB-5, below).

**How the operator responds, mechanically:**

| response | function | property |
|---|---|---|
| stop new exposure | `removeStrategy(strategy, emergency)` | instant, unblockable by any signal or module — `TreasuryAdmission.t.sol::test_RemovalIsInstantAndBlocksFurtherDeployment`, `test_AnActiveLsgModuleCannotBlockRemovalOrRecall` |
| pull what remains | `recallFromStrategy` | not gated on admission, so it still works *after* removal — `test_RecallStillWorksAfterRemoval` |
| shrink the cap | `admitStrategy(..., lowerCap, sameMode)` | re-runs the 24 h delay for *increases*; the cap itself binds immediately on the next deployment |
| recognise the loss | `closeStrategy` after removal | loss-only write-off; `testFuzz_CloseStrategyOnlyEverReducesPrincipal` |

**No Hard claim.** `invariant_BackingIsCompletelyAttributed` holds across randomized sequences
that include total strategy loss (`strategyLosesEverything` is a handler action): `B` moves only
by settlement legs, donations, the WETH-only revenue leg, and redemptions. There is no repair
path to find, because the Reserve exposes none —
`TreasuryFailureBehaviors.t.sol::test_FB5_NoRescuePathExistsAfterATotalLoss` attempts four
rescue shapes with the treasury's own identity and all four fail.

**Residual (correctly out of scope).** Whether to admit ROOT/GIGA at all, and at what cap, is
R-8 and remains unresolved — no such admission exists in this subject.

---

## FB-9 — Realized Strategic revenue is zero

> Required outcome: *General distributions/operations receive no protocol revenue; external
> runway or cost reduction required.*

**Mechanically true, and tested.** With `realizedRevenue[asset] == 0`, every one of the four
legs reverts `RevenueExceedsRealized` — including the book-only compounding leg, which does not
move an asset and could plausibly have been left unguarded:

- `TreasuryRevenue.t.sol::test_WithZeroRevenueEveryLegReverts` (all four legs, one at a time)
- `test_PrincipalUnderCustodyIsNotDistributable` — the sharper case: the treasury physically
  holds > 500 WETH of Strategic principal and still cannot pay one wei out of it.

**The consequence is the requirement.** There is no fallback path in code: no Reserve draw, no
principal relabel, no accrual, no IOU. "External runway or cost reduction required" is what the
absence of those paths *means* — the contract simply has nothing to offer, which is why FB-9's
outcome is a review statement rather than a behaviour to observe.

---

## FB-10 — LSG absent, delayed, captured, or fails

> Required outcome: *Operators retain bounded pre-LSG policy/emergency responsibility; Hard and
> minting remain unreachable.*

Four failure shapes, each with its code answer:

| shape | behaviour | evidence |
|---|---|---|
| **absent** (launch state) | `lsgModule == address(0)`; every signal surface fails closed | `test_SignalSurfacesFailClosedBeforeActivation`, `test_LaunchStateIsEmpty` |
| **delayed** | activation is an affirmative operator act with no threshold and no calendar; nothing degrades while it is absent | `test_ActivationIsAffirmativeAndUngated`, `test_TimeAloneNeverActivatesLsg` |
| **captured** | a captured module can only skew a *relative split* over the already-admitted, already-capped menu. It cannot admit, cannot raise a cap, cannot name a recipient outside the registry, and cannot reach the core | `test_ASignalCannotReachAnUnadmittedUnmaturedOrRemovedTarget`, `test_ASignalNamingTheMonetaryCoreReachesNothing` (core state asserted bit-identical after the call), `test_CapsClampTheSplitAndTheRemainderStaysInCustody` |
| **fails** (malformed, or must be severed) | a length-mismatched signal is rejected outright; `deactivateLSG()` severs consumption and funding in the same transaction, and the earmark stays in custody | `test_AMalformedSignalIsRejected`, `test_DeactivationSeversFundingAndStrandsNothing` (which also re-checks that operator removal still works with a dead module) |

**Operators retain responsibility throughout.** Admission, deployment size, deployment timing,
removal, and recall are all `OPERATOR_ROLE` and none consults the module. The module is granted
nothing standing: `test_TheModuleHoldsNoAllowanceOverTheTreasury` asserts zero allowance and no
role after a funded program.

**P1 boundary held.** No stake, epoch, weighting, reward accrual, delegation, or ranking ships —
`test_NoLsgMechanismShipsAtP0` enumerates the P1 surface and asserts each member is absent.

---

## FB-12 — Operations exceed realized economics

> Required outcome: *No Reserve payroll or automatic principal relabeling; costs/funding adjust.*

**No Reserve payroll.** The treasury's only reach toward the Reserve is the WETH-only accretion
leg, and it is one-way: `B` can rise through it and can never fall. There is no withdraw, sweep,
draw, or callback in either direction —
`TreasuryRevenue.t.sol::test_NoAllocationCanReduceBackingOrMint`, and structurally
`TreasuryFailureBehaviors.t.sol::test_FR10_3_TheTreasuryCannotEvenNameACoreAuthority`, which
shows the treasury's compilation unit contains no declaration of `HardReserve.redeem`,
`VUX.mint`, or `VUX.burnForRedemption` at all.

**No automatic principal relabeling.** There is no `declareProfit`, no revenue setter, no NAV or
mark cell, and no accrual that could turn an unpaid expense into a claim
(`TreasurySurface.t.sol::test_TheProhibitedSurfacesDoNotExist`,
`test_NoMarkOrNavCellExists`). An operating expense is payable only from
`realizedRevenue[asset]`, which only a measured realized flow can fill.

**"Costs/funding adjust" is the only remaining option**, which is the requirement. One nuance
worth review attention: the revenue accumulator is *cumulative*, so an expense approved against
revenue earned earlier remains payable later even if the assets behind that credit were
redeployed and lost. That behaviour is pinned by
`TreasuryRevenue.t.sol::test_ARedeployedAndLostRevenueCreditRemainsOutstanding` and raised as
judgment call J-3 in `reviewer.md` "Judgment Calls".

---

## Cross-reference: the automated rows this sprint carries

FB-5, FB-13, FB-15, and FB-16 are automated rather than documented, in
`test/treasury/TreasuryFailureBehaviors.t.sol`. FB-7 (POL) and FB-8 (POL fee routing) belong to
Sprint 5. FB-1…FB-4 and FB-14 are Sprint 2/3 territory and continue to pass unchanged.
