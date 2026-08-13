# Prohibited-Signal Inspection Checklist — `Rig.take` primary settlement

**Sprint:** cycle-002 / sprint-3 (global = local)
**Subject:** `src/Rig.sol` — `take`, `_route`, `_vem`, `currentPrice`, `currentUPS`
**Requirement:** FR-4.3 narrowed prohibition (prd.md:L370), FR-4 acceptance
"Code inspection: no conditional on any prohibited signal in the primary path"
(prd.md:L377); sdd.md:L228; FREEZE-Δ §3.2
**Date:** 2026-08-13

---

## 1. The requirement, restated

> "no macro, market-price, NAV, Strategy-return, ROOT/GIGA-price,
> calendar-phase, oracle-mediated, or operator-discretion branch shall exist
> anywhere in primary settlement; the settlement-local, deterministic
> monetary-closure computation on exactly `(P, Qraw, B_pre, S_pre)` is the sole
> sanctioned adaptivity" (prd.md:L370)

Two claims must hold: (a) the sanctioned inputs are the *only* adaptive inputs,
and (b) no prohibited signal is *reachable* to become one.

## 2. Claim (b) is structural, and stronger than inspection

`Rig` holds exactly four external references, all `immutable`, all set at
construction: `weth`, `vux`, `reserve`, `treasury` (src/Rig.sol:L96-L131).

| reference | what `Rig` calls on it | could it yield a prohibited signal? |
|---|---|---|
| `weth` (`IERC20`) | `balanceOf`, `safeTransfer`, `safeTransferFrom` | No — a balance is not a price, NAV, or mark |
| `vux` (`IVUXMintable`) | `totalSupply`, `mint` | No — the interface declares exactly two members |
| `reserve` (`address`) | used only as a transfer target and `balanceOf` argument | No — not called at all |
| `treasury` (`address`) | used only as a transfer target | No — not called at all |

There is no oracle reference, no pool reference, no registry, no price feed, no
operator address, and no setter that could introduce one — the contract has no
non-`immutable` address cell and no owner (proven mechanically by
`test_FB15_FB16_TheRigExposesNoRescueOrRecapitalizationPath` and
`test_TheRigExternalSurfaceIsExactlyTheAcceptedOne`,
test/rig/RigFailureBehaviors.t.sol).

`IVUXMintable` is deliberately narrow for this reason (src/interfaces/IVUXMintable.sol):
a shared wide interface would put reachable authority behind an import.

**Therefore no prohibited signal can be read, because none is reachable.** This
is a claim about the contract's reference graph, not about the current shape of
its control flow, so it cannot be invalidated by a later edit that adds a branch
— only by a later edit that adds a *reference*, which is visible in the diff.

## 3. Claim (a) — the adaptive computation, line by line

The adaptive law is `_route(price, qRaw, bPre, sPre)` (src/Rig.sol:L500-L516) and
the issuance cap is `_vem(dR, sPre, bPre, qRaw)` (src/Rig.sol:L487-L493).

**Both are `pure`.** That is compiler-enforced: a `pure` function cannot read
storage, balances, `block.*`, or make any call. The four parameters are therefore
provably the complete input set of the adaptive computation — not by inspection,
but because the alternative does not compile.

The `RigMathHarness` wrappers (test/rig/RigMathHarness.sol) are `external pure`
for the same reason: the signature *is* the evidence.

## 4. Every branch in the primary path

Enumerated exhaustively. "Prohibited?" asks whether the condition reads anything
outside `(P, Qraw, B_pre, S_pre)` plus own throne state.

| # | site | branch condition | reads | prohibited? |
|---|---|---|---|---|
| 1 | `take` | `s.price > maxPrice` | `P`, caller argument | No — caller's own slippage bound |
| 2 | `take` | `!s.bootstrap` (Qraw accrual) | own storage (`king`, `reserve`) | No — own throne state |
| 3 | `take` | `s.strategicLeg != 0` | derived from `P`, `Qraw`, `B_pre`, `S_pre` | No |
| 4 | `take` | `s.bootstrap ? … : …` (Hard leg) | own throne state | No |
| 5 | `take` | `s.dR != hardContribution` | measured `D_R`, routed intent | No — measured reality |
| 6 | `take` | `s.qMint != 0` | derived | No |
| 7 | `take` | `!s.bootstrap && s.kingLeg != 0` | own throne state, derived | No |
| 8 | `take` | `if (s.bootstrap) scheduleStart = …` | own throne state | No |
| 9 | `_route` | `qRaw == 0` | `Qraw` | No — sanctioned input |
| 10 | `_route` | `Math.min` / `Math.max` in `hardTarget` | the four sanctioned inputs | No |
| 11 | `_vem` | `Math.min(qRaw, qSafe)` | sanctioned inputs, measured `D_R` | No |
| 12 | `currentPrice` | `elapsed >= EPOCH_PERIOD`; `Math.max(DECAY_FLOOR, …)` | `block.timestamp`, own storage, frozen constants | No — see §5 |
| 13 | `currentUPS` | `start == 0`; halving clamp | `block.timestamp`, own storage, frozen constants | No — see §5 |
| 14 | `_successorOpening` | `uint192` overflow clamp; `Math.max(MINIMUM_OPENING, …)` | `P`, frozen immutable | No |

**No row reads** a market price, secondary VUX price, NAV, Strategic NAV,
Strategy return, ROOT price, GIGA price, oracle datum, macro state, treasury
composition, operator preference, or governance input. None of those values
exists anywhere in the contract's reachable state.

## 5. The two `block.timestamp` reads are not "calendar-phase logic"

Rows 12 and 13 read `block.timestamp`. This is explicitly sanctioned, not an
exception being argued for:

- `currentPrice` uses elapsed time **within the current epoch** to evaluate the
  frozen Dutch function (FR-2.3). Time is the independent variable of the price
  function; it is not a phase selector.
- `currentUPS` uses elapsed time **since `scheduleStart`** to evaluate the frozen
  halving schedule (FR-3.3). The prohibition is on "calendar 'season' logic
  beyond the frozen UPS schedule" — this *is* the frozen UPS schedule.

The distinguishing test: neither read selects between *behaviours*. Both evaluate
a single frozen formula whose value happens to depend on time. There is no
branch anywhere that says "if we are in period X, route differently."

The SDD states the same conclusion independently: `take` "reads only
`block.timestamp`, its own storage, `WETH.balanceOf(reserve)`, and
`VUX.totalSupply()` — exactly the input set of the sanctioned settlement-local
adaptive law" (sdd.md:L228).

## 6. FR-4.4 — adaptive portfolio decisions

> "Adaptive *portfolio* decisions begin only **after** the Strategic leg is
> received and classified as Strategic principal" (prd.md:L371)

Satisfied by construction: the Strategic leg is a plain `safeTransfer` to an
address (src/Rig.sol, step 7). The Rig makes no call to the treasury, receives no
return value, and has no interface for it. Nothing downstream of the transfer can
influence anything upstream of it, in this or any later transaction. Sprint 4's
treasury cannot change this without changing `Rig.sol` itself.

## 7. Mechanical re-verification

The reviewer can reproduce every claim above without re-reading the contract:

```bash
# 1. The adaptive functions are `pure` — the compiler's own statement that
#    they read nothing. Both lines must print `pure`.
grep -n 'function _route\|function _vem' -A4 src/Rig.sol | grep -c pure   # expect 2

# 2. The contract holds no mutable address cell (no setter target can exist).
grep -nE '^\s+address (public|internal|private)( |$)' src/Rig.sol         # expect only `address public king;`

# 3. No prohibited-signal vocabulary appears anywhere in the source.
grep -niE 'oracle|price[Ff]eed|getPrice|nav|quote|slot0|observe|twap|aggregator|chainlink|root|giga' src/Rig.sol
#    expect: only DECAY_FLOOR/currentPrice/epochOpening/maxPrice/PriceAboveMax
#    (the Dutch-price vocabulary), and no external price source.

# 4. The surface is exactly the accepted one, asserted against the artifact.
forge test --match-test test_TheRigExternalSurfaceIsExactlyTheAcceptedOne
```

## 8. Verdict

**No prohibited-signal finding.** The adaptive computation's input set is
`(P, Qraw, B_pre, S_pre)` plus own throne state, enforced by the `pure` modifier
on both formulas rather than asserted by inspection, and no prohibited signal is
reachable from the contract's immutable reference graph in the first place.
