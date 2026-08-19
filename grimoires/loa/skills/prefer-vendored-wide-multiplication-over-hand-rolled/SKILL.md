---
name: prefer-vendored-wide-multiplication-over-hand-rolled
description: |
  When a Solidity script or contract needs `floor(a*b/c)` over values whose
  product can exceed 256 bits (any Q64.96-style price encoding, any ratio math
  on 18-decimal token amounts multiplied together), do NOT hand-roll the
  512-bit-intermediate mulmod trick inline — reach for the project's own
  already-vendored library (OpenZeppelin `Math.mulDiv` / `Math.sqrt`, or
  equivalent) instead. A hand-rolled version is easy to get subtly wrong
  (checked Solidity `a * b` overflows and reverts BEFORE the 512-bit-safe logic
  ever runs, defeating the entire point of writing it), and the project has
  almost certainly already vendored, tested, and gate-verified the correct
  implementation for exactly this purpose. Apply whenever writing deployment
  scripts, off-chain-mirroring encoders, or any new Solidity code that needs
  full-precision multiply-then-divide and the project already depends on
  OpenZeppelin (or another audited math library).
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-7 /implement (GenesisRehearsal.s.sol price encoder)
extraction-date: 2026-08-17
version: 1.0.0
tags:
  - solidity
  - arithmetic
  - overflow
  - openzeppelin
  - deployment-scripts
---

## Problem

A script needs to reproduce an existing contract's price/ratio encoding (e.g. `sqrtP0X96 = isqrt((n << 192) / d)`) but is written standalone, without importing the library the actual contract logic uses. To avoid adding an import "just for one script," a 512-bit mulDiv is hand-rolled inline using the standard Yul `mulmod`/two's-complement decomposition. The script compiles fine. On first real execution (a live broadcast, not just a static call), it reverts.

## Trigger Conditions

### Symptoms

- A deployment/rehearsal script panics or reverts partway through, specifically inside a locally-defined math helper
- The same computation, done via the project's already-vendored library elsewhere (e.g. in tests), works fine on the identical inputs
- The failing helper was written "from scratch" to avoid a perceived extra dependency, even though the dependency is already in the project

### Error Messages

```
Error: script failed: panic: arithmetic underflow or overflow (0x11)
```

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity ^0.8 (checked arithmetic by default), Foundry scripts |
| Environment | Any script/contract computing `floor(a*b/c)` where `a*b` alone can exceed `type(uint256).max` |
| Timing | First live execution with realistic (large) input values — a quick sanity check with small numbers will NOT surface it |
| Prerequisites | The project already vendors a correct wide-multiplication implementation (e.g. OpenZeppelin `Math.sol`) |

## Root Cause

A hand-rolled 512-bit mulDiv typically starts with `uint256 lo = a * b;` to get the low half of the product, intending to recover the high half separately via `mulmod`. Under Solidity ^0.8's default checked arithmetic, that very first `a * b` reverts if the product overflows 256 bits — which is exactly the case the whole routine exists to handle. The overflow-safe logic never gets a chance to run; the naive multiplication guarding it fails first. (The correct pattern computes the high/low split entirely inside `unchecked`/assembly from the start, which audited libraries already do — reimplementing it correctly from memory, under time pressure, in a one-off script, is exactly the kind of thing that's easy to get subtly wrong.)

## Solution

### Step 1: Check whether the project already vendors a wide-multiplication library

```bash
grep -rn "function mulDiv" vendor/ 2>/dev/null
cat remappings.txt   # look for @openzeppelin/contracts/ or similar
```

### Step 2: Import and use it instead of writing a new implementation

```solidity
// WRONG — reimplements what's already vendored, and gets the checked-math
// entry point wrong
function _mulDiv(uint256 a, uint256 b, uint256 denominator) private pure returns (uint256) {
    uint256 lo = a * b;  // reverts here for realistic wei-scale ratio encodings
    ...
}

// RIGHT — the ladder: does the standard library already do it? yes, use it.
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
...
uint160 price = uint160(Math.sqrt(Math.mulDiv(n, 1 << 192, d)));
```

### Step 3: Delete the hand-rolled version entirely, don't leave it as dead code

Reduces the diff, removes a second place the same bug class could recur, and means the script is verified against the exact same math the audited contracts use — a genuine correctness win, not just a style preference.

## Verification

### Command

```bash
forge script YourScript.s.sol:YourScript --sig "run()" --rpc-url <fork> --broadcast
```

### Expected Output

Successful execution against realistic (large, wei-scale) inputs — not just small illustrative numbers that happen to avoid the overflow path.

### Checklist

- [ ] No inline reimplementation of `mulDiv`/full-precision multiply-divide exists alongside an already-vendored one
- [ ] Verified against realistic (large) input magnitudes, not just toy values
- [ ] The "ladder" was actually walked: checked for a vendored solution before writing new code

## Anti-Patterns

### Don't: avoid an import to keep a script "self-contained"

A one-off deployment script still runs against real, large on-chain values. "Self-contained" is not a virtue when it means re-deriving audited arithmetic from memory; the import cost is a few characters, the reimplementation cost is a live-broadcast panic.

## Related

This is the "ladder" principle from first principles — does a native/vendored feature already cover it? — applied specifically to the recurring wide-multiplication trap. See also [[independent-oracle-for-512-bit-arithmetic]] for the companion trap when *testing* mulDiv-based code (using the same function as its own oracle proves nothing).
