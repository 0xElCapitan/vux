---
name: invariant-derivation-over-fuzz-depth
description: |
  When auditing a claimed numeric property, the audit's job is to explain WHY it
  holds, not to re-run the implementation's fuzz suite at a higher depth. Two
  derivations repay the effort far more than extra runs. First, look for a
  CONSERVED QUANTITY: a claim about a single terminal state ("full redemption
  leaves ceil(B/S)") is usually the corollary of a per-operation invariant
  ("ceil(B/S) is unchanged by EVERY redemption"), which is stronger, provable in
  a few lines, and makes the result path-independent. Second, bound the operands
  to prove a REVERT IS UNREACHABLE: `q <= S-1 < S` forces `payout <= B`, so
  `mulDiv`'s overflow revert can never fire from the redemption path — converting
  a perceived liveness risk into a proof that the exit right cannot be denied.
  Validate derivations with a high-volume oracle written OUTSIDE the EVM. Apply
  to pro-rata redemption, share/asset conversion, fee splits, rounding-direction
  and exhaustion claims.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-2 /audit-sprint (HardReserve redemption arithmetic)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - security-audit
  - arithmetic
  - property-testing
  - invariants
  - defi
  - solidity
  - formal-reasoning
---

## Problem

A review approves a monetary formula on the strength of a passing property suite:
`payout = floor(B*q/S)`, 10,000 fuzz runs, plus an exhaustion test asserting that
redeeming the whole external float leaves `ceil(B/S)` WETH behind.

An audit that responds by re-running the same suite at the same or higher depth
adds nothing: it inherits the suite's domain, its oracle, and its blind spots. A
passing fuzz run is evidence that no counterexample was *sampled*, which is a
much weaker statement than the invariant the protocol actually depends on.

Worse, the audit cannot answer the questions that decide severity:

- Is the terminal-state claim true for **every** redemption path, or only the
  single-shot one the test exercises?
- Can the arithmetic ever **revert** and thereby deny the exit right?

Neither is reachable by turning the run count up.

## Trigger Conditions

### Symptoms

- A review approves a monetary/rounding property citing fuzz depth as the evidence.
- The claim concerns a **terminal state** ("after full redemption…", "when the pool empties…").
- 512-bit intermediates (`mulDiv`, `FullMath`) are used and overflow behaviour is discussed as a risk.
- An audit brief asks you to "explain why the property holds, not report 10,000 invocations".

### Error Messages

None — the failure mode is an under-justified approval, not a failure.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity; OZ `Math.mulDiv` / Uniswap `FullMath`; Foundry fuzzing |
| Environment | Audit of pro-rata redemption, vault share math, fee splits |
| Timing | After validating the implementation's oracle; before assigning severity |
| Prerequisites | The formula, the operand bounds enforced in code, and an out-of-EVM scripting language |

## Root Cause

Fuzzing samples; it does not quantify. For scale-invariant arithmetic the
sampled space is enormous and the interesting structure lives at boundaries the
generator rarely hits. More fundamentally, a terminal-state assertion tests one
*path* to that state — but the protocol permits arbitrary interleavings of
partial redemptions, and nothing in the test constrains those.

The structure is usually there to be found: pro-rata systems conserve a ratio by
construction, and flooring perturbs it in a bounded way. Once the conserved
quantity is identified, the terminal claim follows as a corollary for all paths
at once, and the proof is short.

## Solution

### Step 1: Restate the terminal claim as a candidate per-operation invariant

The claim: redeeming the whole float `q = S - S_MIN` leaves `ceil(B/S)`.

Single-shot check first — `payout = floor(B(S-1)/S) = B - ceil(B/S)`, so the
remainder is `ceil(B/S)`. ✓

Now the generalisation to test: *is `ceil(B/S)` unchanged by an arbitrary
redemption?*

### Step 2: Prove it

Write `B = kS - r` with `k = ceil(B/S)` and `0 <= r < S`. For a redemption of `q`:

```
floor(Bq/S) = floor((kS - r)q / S) = kq - ceil(rq/S)
B' = B - floor(Bq/S) = kS - r - kq + ceil(rq/S) = kS' - r'
     where S' = S - q  and  r' = r - ceil(rq/S)
```

Then `r' >= 0` (since `q <= S` gives `ceil(rq/S) <= r`), and
`r' <= r - rq/S = r(S-q)/S < S(S-q)/S = S - q = S'`.

So `0 <= r' < S'`, hence `ceil(B'/S') = k`. **`ceil(B/S)` is invariant under
every redemption**, so the exhaustion remainder is `ceil(B0/S0)` regardless of
how many steps were taken — path-independence the original test never claimed.

### Step 3: Bound the operands to prove reverts unreachable

`mulDiv` reverts when the quotient exceeds `uint256`. In `redeem`, the code
enforces `q <= S - S_MIN`, so `q < S`, so:

```
payout = floor(B*q/S) < B  <=  type(uint256).max
```

The revert branch is **unreachable from the redemption path at any scale**. This
reframes the 512-bit intermediate: it is not a mitigation for a liveness risk, it
is what makes the exit right undeniable. Note the same bound does *not* hold for
an unbounded-`q` preview function — locate exactly where the bound is enforced.

### Step 4: Validate the derivation outside the EVM, at volume

Derivations can be wrong. Check them with an implementation sharing nothing with
the contract or its tests — arbitrary-precision integers, no Solidity.

```python
for _ in range(400_000):
    S = randint(1, 10**30); B = randint(0, (2**256-1)//2); q = randint(0, S-1)
    payout = (B*q)//S
    assert payout*S <= B*q < (payout+1)*S          # floor is exact
    assert payout <= B                              # revert unreachable
    if S-q > 0:
        assert -(-B//S) == -(-(B-payout)//(S-q))    # ceil(B/S) invariant

for _ in range(20_000):                             # random multi-step paths
    B0, S0 = B, S
    while S > 1:
        q = randint(1, S-1); B -= (B*q)//S; S -= q
    assert B == -(-B0//S0)                          # path-independent remainder
```

```
cases: 400000 violations: 0
exhaustion path-independence: 20000 random paths, remainder == ceil(B0/S0) exactly
```

### Step 5: Encode the derived invariant as a property in your own harness

Fuzz the *per-operation* invariant, not just the terminal state — it is strictly
stronger and fails faster when broken.

## Verification

### Command

```bash
forge test --match-test 'testFuzz_D' -vv     # auditor probe: invariance + path independence
python oracle.py                              # out-of-EVM confirmation
```

### Expected Output

```
[PASS] testFuzz_CeilBOverSIsInvariantUnderRedemption(uint256,uint256) (runs: 10000)
[PASS] testFuzz_ExhaustionRemainderIsPathIndependent(uint256,uint256) (runs: 10000)
[PASS] testFuzz_RedeemNeverRevertsFromArithmeticAtExtremeScale(uint256,uint256) (runs: 10000)
cases: 400000 violations: 0
```

### Checklist

- [ ] Terminal claim restated as a candidate per-operation invariant
- [ ] Invariant proved algebraically, not just sampled
- [ ] Operand bounds located in code and used to prove revert unreachability
- [ ] Derivation validated by an out-of-EVM oracle at high volume
- [ ] Invariant encoded as a property in the auditor's own harness
- [ ] Checked whether the bound holds for view/preview paths too

## Anti-Patterns

### Don't: raise the fuzz depth and call it independent verification

```bash
# BAD - inherits the suite's domain, oracle and blind spots
FOUNDRY_FUZZ_RUNS=100000 forge test
```

Ten times the runs is the same experiment, louder.

### Don't: accept a terminal-state assertion as a statement about all paths

`test_FullRedemptionLeavesRemainder` exercises exactly one interleaving. Absent a
per-operation invariant, nothing constrains the others.

### Don't: describe 512-bit math as "overflow protection" without locating the bound

If `q < S` is what makes the quotient fit, say so and cite the line enforcing it.
Otherwise the reader cannot tell whether the revert is unreachable or merely
unobserved.

## Related Memory

### NOTES.md References

- `## Learnings`: "[Audit technique — derive the invariant, don't deepen the fuzz]" (added 2026-08-11).

### Related Skills

- `independent-oracle-for-512-bit-arithmetic`: the implementation-side counterpart — how to build a non-circular oracle. This skill is the audit-side move: derive the invariant so no oracle needs to be trusted.
- `fuzz-harness-validity-audit`: validate the harness before reading any depth claim; run it before this skill.

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction |

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: auditing-security
  phase: /audit-sprint sprint-2
  session: cycle-002-sprint-2-audit
```
