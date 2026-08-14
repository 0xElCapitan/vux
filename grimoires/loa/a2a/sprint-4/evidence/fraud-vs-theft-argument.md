# Adversarial-adapter argument: classification fraud ≤ theft

**Node:** Sprint 4 implementation (Task 4.9)
**Carries:** sdd.md:L302 (§1.10 rule 4), threat-model row 9 (sdd.md:L949), FR-9.3
**Status:** implementation-side evidence for `/review-sprint sprint-4`

---

## The claim under test

> "an adapter that lies about `principalUnits()` (or mislabels flows) to manufacture 'revenue'
> can, by the same lie, simply steal the funds — classification fraud is strictly no more
> powerful than theft, and both are bounded by the same admission diligence, per-(strategy,
> asset) caps, 24 h maturity, instant removal, and Strategic-only blast radius"
> — sdd.md:L302

The accepted design does **not** claim adapters are trustworthy. It claims that trusting one
buys an attacker nothing beyond what admitting it already conceded. Sprint 4's job is to make
that true of the *implementation*, which means two separate obligations:

1. every revenue credit is computed from an amount the **treasury measured on its own
   balances**, never from an adapter's return value; and
2. the worst outcome of a lie stays inside the Strategic blast radius.

---

## 1. What an adapter can actually influence

`IStrategyAdapter` (`src/interfaces/IStrategyAdapter.sol`) is the complete surface. Per member:

| member | what a lie achieves | why it is bounded |
|---|---|---|
| `principalUnits()` | inflate/deflate the reported position size | Read only as a **delta** or as an ordering guard. Inflating it lets `harvestYield` pass its units-intact check — but the credit that follows is still the treasury's own measured balance delta, so the adapter must **actually deliver** the tokens it wants credited. |
| `rewardAssets()` | name assets that were not paid, or name one twice | An unpaid asset measures a zero delta and credits nothing (`StrategicTreasury.sol` skips `gained == 0`). A duplicate is credited **exactly once** (first-occurrence scan) — closed deliberately, because it is the one lie that costs the adapter nothing. |
| `harvest()` | pay nothing, or pay in an unexpected asset | Paying nothing credits nothing (FB-8). Paying an unlisted asset credits nothing — it lands as principal-side inventory (§1.10 rule 5). |
| `deposit()` | mint arbitrary units for a real deposit | Units are the *denominator* of `basisReleased = ceil(basis × units / unitsHeld)`. Inflating them shrinks each redemption's released basis, which **delays** revenue recognition — the conservative direction. Deflating them accelerates basis release, which reduces revenue. Neither creates revenue. |
| `redeem()` | pay less than the units are worth | A shortfall books as `StrategyLossRealized`, never as negative revenue. The `minOut` bound is applied to the treasury's own measured receipt, so the adapter cannot misreport its way past it. |
| `recall()` | return less than asked, or nothing | The measured receipt is classified; an under-delivery simply leaves principal outstanding. Returning nothing **is** the theft case. |

The through-line: on every path, an adapter that wants a wei of revenue credited must first
send that wei to the treasury. `_classifyReturn` and the two mode-specific paths all read
`IERC20(asset).balanceOf(address(this))` before and after, and book the difference.

**Mechanical evidence.** `test/treasury/TreasuryFlows.t.sol`:
`test_OnlyWhatActuallyArrivesRetiresPrincipal` (under-delivery on the pull),
`test_ADuplicatedRewardAssetIsCreditedExactlyOnce`,
`test_AHarvestThatShrinksThePositionReverts`,
`test_MinOutIsEnforcedAgainstTheMeasuredReceipt`,
`test_AShortfallRedemptionBooksALossAndNoRevenue`.
`test/treasury/TreasuryAccountingProperties.t.sol::testFuzz_RevenueCreditNeverExceedsValueDelivered`
states the through-line as a property over all three modes.

---

## 2. The sharpest form of the lie, stated plainly

The strongest classification attack available is **misattribution**, and it does not need a
lying adapter at all — `returnFor` is permissionless and the caller chooses the strategy:

1. operator deploys 100 WETH to admitted strategy `A` → `outstandingPrincipal[A] = 100`;
2. the capital is returned via `returnFor(B, WETH, 100)` for a *different* admitted strategy
   `B` with zero outstanding → all 100 credits as revenue, while `A`'s 100 still stands;
3. `allocateRevenue(WETH, 0, 0, 100, 0)` pays it out as an operating expense.

Principal has become a distribution. This is **not** a defect introduced by the
implementation — it is the accepted design's attribution model (`returnFor` is
caller-attributed by construction, sdd.md:L300), and it is exactly what rule 4 disposes of:

- both steps require the operator, who **already** controls admission and deployment. An
  operator willing to do this can instead call `deployToStrategy(strategyTheyControl, …)` and
  hold the capital outright. The misattribution route is strictly weaker: it converts capital
  into a *disclosed, evented* payment to a disclosed recipient, where the direct route
  converts it into silence.
- the blast radius is identical either way and is Strategic-only: no step touches `B`,
  redemption, VEM, mint authority, or Rig routing (proven independently in
  `TreasuryInvariants.t.sol::invariant_BackingIsCompletelyAttributed` and
  `invariant_SupplyIsCompletelyAttributed`, which hold across randomized sequences that
  include exactly these operations).

The guarantee the classification engine actually makes is therefore precise, and worth stating
in the terms it holds: **no accidental or arithmetic path relabels principal as revenue.** It
is not a guarantee against a determined operator, and no accepted authority claims otherwise —
the operator surface is the FR-16 boundary argument, which is this sprint's audit subject.

---

## 3. What the implementation added beyond the accepted text

Two guards were added because they close lies that cost the adapter nothing, and neither
changes an accepted interface:

1. **Duplicate reward assets are credited once.** Without it, `rewardAssets() = [X, X]` books
   one measured delta twice and creates revenue from a single flow. This is the only lie
   identified that produces revenue *without* delivering value, so it is the only one that
   would have escaped the rule-4 argument.
2. **`returnFor` credits its measured receipt, not its `amount` argument.** On an
   under-delivering asset, crediting the argument retires more principal than arrived, and the
   gap resurfaces later as revenue that was never earned.

Both are covered by named tests (above) and by the property suite.

---

## 4. Residual, surfaced rather than closed

`realizedRevenue` is an **accumulator, not a segregated balance** — the accepted bound is
`Σ legs ≤ realizedRevenue[asset]` (sdd.md:L312) with no custody condition. An operator who
earns revenue, redeploys the assets behind it, and loses them leaves the credit standing, and a
later principal inflow can settle it. Pinned by
`TreasuryRevenue.t.sol::test_ARedeployedAndLostRevenueCreditRemainsOutstanding` and raised for
disposition in `reviewer.md` "Judgment Calls" (J-3). It is the same operator-trust class as §2
above and reaches nothing outside Strategic.
