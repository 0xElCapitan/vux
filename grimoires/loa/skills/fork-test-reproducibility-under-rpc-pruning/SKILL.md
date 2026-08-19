---
name: fork-test-reproducibility-under-rpc-pruning
description: |
  A blockchain fork test pinned to a specific block number silently stops being
  reproducible once the RPC endpoint prunes that block's state — public RPCs are
  usually NOT archive nodes. Measure the actual retention window by binary
  search rather than assuming "public RPC = archive access", then decouple the
  test from the pin: make the exact-block binding a RUNNER INPUT (env var), not
  a source constant, and anchor every other assertion on values that survive
  across blocks (runtime-code hashes, not addresses; live balances, not one
  recorded balance). Apply whenever writing a `--fork-url`/`--fork-block-number`
  test suite against any chain's public RPC, or diagnosing "worked five minutes
  ago, now every call errors."
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-7 /implement (Q-6 native-wrap fork gate, Task 7.1)
extraction-date: 2026-08-17
version: 1.0.0
tags:
  - foundry
  - fork-testing
  - rpc
  - reproducibility
  - evm
  - solidity
---

## Problem

A fork test hard-codes a block number: `forge test --fork-url <RPC> --fork-block-number 38945000`. It passes when written. Minutes later — sometimes before the same session even finishes — every call at that block starts failing with an RPC-level error, not a test failure. The evidence the suite was supposed to produce is no longer reproducible, and nothing about the test's logic changed.

## Trigger Conditions

### Symptoms

- A fork test that passed now fails, with no code change since
- The failure is at the RPC layer, not an assertion
- Re-running against the current chain tip works fine
- The gap between "worked" and "broke" is minutes, not days

### Error Messages

```
Error: server returned an error response: error code -32000: metadata is not found, <block>
```

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Foundry (`forge test --fork-url`), any EVM chain |
| Environment | Public/free-tier RPC endpoints (official chain RPC, not a paid archive provider) |
| Timing | Any time after the pinned block ages out of the node's retained window |
| Prerequisites | none — this is a property of the RPC, not the project |

## Root Cause

"Public RPC" does not imply "archive node." Full nodes commonly retain only recent state (observed on Robinhood Chain's official public endpoint: ~6,150 blocks, ~10 minutes at ~10.6 blocks/s) and prune everything older to save disk. A block number baked into source or CI config is a promise the RPC provider never made. The retention window is discoverable but not documented anywhere obvious — it has to be measured.

## Solution

### Step 1: Measure the actual retention window before trusting any fork test

Binary search from the tip: query state (e.g. `eth_getCode` on a known contract) at decreasing depths until it errors, bracket the boundary, then narrow it.

```bash
TIP=$(cast block-number --rpc-url "$RPC")
ok() { cast code "$KNOWN_ADDR" --rpc-url "$RPC" --block "$1" 2>&1 | grep -q "^0x60"; }
lo=1; hi=6400
while ok $((TIP-hi)); do lo=$hi; hi=$((hi*2)); done
while [ $((hi-lo)) -gt 64 ]; do
  mid=$(( (lo+hi)/2 ))
  if ok $((TIP-mid)); then lo=$mid; else hi=$mid; fi
done
echo "retained depth ~ $lo blocks"
```

### Step 2: Make the exact-block binding a runner input, not a source constant

```solidity
// WRONG — the pin rots within minutes on a public RPC
uint256 constant FORK_BLOCK = 38_945_000;
assertEq(block.number, FORK_BLOCK, "fork block number");

// RIGHT — supplied by whoever runs the suite; absent = skip the pin check
uint256 wantBlock = vm.envOr("FORK_BLOCK_ENV_VAR", uint256(0));
if (wantBlock != 0) {
    assertEq(block.number, wantBlock, "fork block number");
}
```

### Step 3: Anchor every OTHER assertion on values that survive across blocks

An address's identity does not change block to block; its bytecode does, on an upgrade. Assert `codehash`, not merely code length, so an upgrade of the thing under test turns into a red test rather than a silent assumption:

```solidity
assertEq(TARGET.codehash, KNOWN_CODEHASH, "runtime identity");
```

A reviewer forking at their own fresh block then reproduces the full result on any public RPC by simply omitting the env var — only the exact-block claim is skipped, not the substance.

## Verification

### Command

```bash
# 1. unpinned — must pass on ANY fresh fork
forge test --match-path test/fork/YourFork.t.sol --fork-url "$RPC"

# 2. pinned to a fresh block — must pass
FORK_BLOCK_ENV_VAR=<current-ish block> \
forge test --match-path test/fork/YourFork.t.sol --fork-url "$RPC" --fork-block-number <same block>

# 3. pinned to a WRONG block — must fail specifically on the block-number assertion
FORK_BLOCK_ENV_VAR=<block+1> \
forge test --match-path test/fork/YourFork.t.sol --fork-url "$RPC" --fork-block-number <block>
```

### Expected Output

Case 1 and 2 both green; case 3 fails with the exact block-mismatch message, not a generic error.

### Checklist

- [ ] Retention window measured, not assumed
- [ ] Block binding is `vm.envOr`, never a hard-coded constant
- [ ] Identity assertions use `codehash`, not just presence/length
- [ ] Suite passes unpinned on a fresh block AND correctly-pinned; fails on a wrong pin

## Anti-Patterns

### Don't: assume the official/public RPC is an archive node because it's the "canonical" endpoint

The chain's own documentation may recommend a paid archive provider (e.g. Alchemy) for exactly this reason, in a section unrelated to testing. Read the RPC docs for retention before writing the fork test, or measure it directly — don't infer it from "this is the official URL."

### Don't: record the evidence run's block number as if it will remain queryable

Capture the block hash, parent hash, and state root alongside the number — reproduction depends on chain history, and a hash lets a reviewer *verify* the block identity even after they can no longer query its state directly.

## Related

Complements the general "assert the toolchain that produced the evidence" discipline — see [[assert-the-toolchain-that-produced-the-evidence]].
