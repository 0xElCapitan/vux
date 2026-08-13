# FB-1 Review Note — Mining / Redemption Independence

**Sprint:** cycle-002 / sprint-3 (global = local)
**FB row:** FB-1 — "Rig/mining path fails → New mining may halt; existing
redemption remains independent, subject to chain/backing-asset function"
(prd.md:L649)
**Assigned method:** review + scenario documentation (prd.md:L669) — *not* an
automated test row
**Date:** 2026-08-13

---

## 1. Why this row is documentation rather than a test

FB-1's antecedent is "the Rig/mining path fails". That is not a state the
deployed system can be placed into: `Rig` is immutable, ownerless, and has no
pause, no upgrade path, and no failure mode short of the whole chain halting
(which is FB-17, a separate row). A test would therefore have to *simulate* a
failure the architecture cannot produce, and would prove only that the
simulation was constructed correctly.

The honest claim is structural: redemption does not depend on the Rig at all, so
no behaviour of the Rig — including any hypothetical failure — can affect it.
That is a claim about the dependency graph, and this note is where it is
established. The sprint's automated coverage of the *consequence* (redemption
keeps working through arbitrary settlement activity) is in
`test/rig/RigFailureBehaviors.t.sol` and the invariant harness.

## 2. The dependency graph

Redemption is `HardReserve.redeem(q, to)`. Its complete set of reads and calls:

| step | reads / calls | involves the Rig? |
|---|---|---|
| snapshot `B` | `weth.balanceOf(address(this))` | No |
| snapshot `S` | `vux.totalSupply()` | No |
| floor check | `S_MIN` (a `constant`) | No |
| payout | `Math.mulDiv(bPre, q, sPre)` | No |
| burn | `vux.burnForRedemption(msg.sender, q)` | No |
| pay | `weth.safeTransfer(to, payout)` | No |

`HardReserve` holds two immutable references — `weth` and `vux` — and **no
reference to the Rig at all** (src/HardReserve.sol:L55-L59). It cannot call the
Rig, query it, or be blocked by it. There is no registry, no router, and no
shared mutable state between them.

The reverse direction exists but is one-way and read-only-plus-transfer: the Rig
reads `WETH.balanceOf(reserve)` and transfers WETH *to* the Reserve. Neither
operation can be refused by the Reserve, and neither leaves the Reserve in a
state that redemption consults.

## 3. What "mining halts" would actually mean

Three distinct scenarios, each with its canonical outcome:

**(a) No one takes the throne.** Mining halts in the ordinary sense. The Reserve
still holds `B`; `S` is unchanged; `redeem` continues to pay
`floor(B × q / S)`. This is FB-2's tested case
(`test_FB2_NoChallengerLeavesTheKingSeatedAndOwedNothing`), and it demonstrates
FB-1's consequence directly: a year with zero mining activity leaves redemption
completely unaffected.

**(b) Every settlement reverts.** The only ways `take` can revert are payer
insolvency, the `maxPrice` guard, or the `D_R` consistency rejection. Each
reverts the *whole* transaction, so no partial state reaches the Reserve
(`test_FailingAnyOneLegUnwindsTheWholeSettlement`,
`test_TheRejectionUnwindsEveryLeg`). `B` and `S` are exactly as they were, and
redemption is exactly as available as it was.

**(c) The VUX↔Rig mint authority is unusable.** If `VUX.mint` could not be
reached — the strongest form of "the mining path failed" — issuance stops
permanently and `S` becomes fixed. Redemption is *strictly better off*: `B` is
non-decreasing while `S` no longer grows, so `B/S` can only rise.
`test_AFailingMintUnwindsTheSettlement` covers the mechanical half (a failing
mint takes its settlement down with it rather than half-committing).

In none of the three does a holder lose the exit right or receive less than
`floor(B × q / S)`.

## 4. The stated dependencies, honestly

FB-1's canonical outcome is qualified: redemption remains independent "subject to
chain/backing-asset function". Both qualifications are real and are disclosed
rather than engineered away:

- **Chain function** — if RH Chain is unavailable, no transaction executes,
  including redemption. That is FB-17: "Actions, including redemption, are
  delayed with the chain; balances are not reclassified" (prd.md:L665). Delay,
  not reclassification.
- **Backing-asset function** — `B` *is* canonical WETH. If canonical WETH is
  adversely upgraded so transfers fail, payout fails with it. That is FB-18 and
  the standing YELLOW disclosure (prd.md:L666, L721); VUX cannot repair it with
  Reserve discretion, and deliberately holds no authority that could try.

Neither qualification is a Rig dependency. FB-1's independence claim is
unaffected by both.

## 5. Supporting automated coverage

FB-1 itself is review-assigned, but the properties it rests on are all under
test:

| property FB-1 relies on | where |
|---|---|
| Redemption pays `floor(B×q/S)` on pre-redemption state, always | `test/reserve/HardReserveRedemption.t.sol` (Sprint 2) |
| The Reserve has no authority surface beyond `redeem` + views | `test/reserve/HardReserveSurface.t.sol` (Sprint 2) |
| A dormant throne leaves redemption untouched | `test_FB2_NoChallengerLeavesTheKingSeatedAndOwedNothing` |
| A failed settlement leaves `B` and `S` bit-identical | `test_TheRejectionUnwindsEveryLeg`, `test_FailingAnyOneLegUnwindsTheWholeSettlement` |
| Redemption works interleaved with arbitrary settlement sequences | `RigInvariants` — `redeemSome` and `takeThrone` interleave freely over 16,384 calls |
| The supply floor and a positive remainder always survive | `invariant_TheSupplyFloorHolds` |

## 6. Verdict

**FB-1 holds structurally.** `HardReserve` holds no reference to `Rig` and reads
nothing the Rig controls, so no mining-path behaviour — including failure — can
reach redemption. The two stated qualifications (chain, backing asset) are
genuine, disclosed, and belong to FB-17/FB-18 rather than to this row. No
mechanism was added to "fix" anything here: a dormant market is permitted to be
dormant, and the exit right is unaffected by it.
