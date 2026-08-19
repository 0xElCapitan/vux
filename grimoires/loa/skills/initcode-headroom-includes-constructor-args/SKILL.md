---
name: initcode-headroom-includes-constructor-args
description: |
  EIP-3860's 49,152-byte init-code size limit applies to what actually gets
  sent on-chain as a CREATE/CREATE2 payload: the contract's creation bytecode
  PLUS the ABI-encoded constructor arguments appended after it. A headroom
  check that reads only `artifact.bytecode.object` (or its length) from the
  compiled JSON measures just the creation code and silently OVERSTATES the
  true headroom by however many bytes the constructor arguments add — which is
  easy to miss for a contract whose constructor takes a struct or several
  static parameters. Apply when writing a test/CI gate that asserts a
  deployer-pattern or any-constructor-args contract fits EIP-3860, or when
  reconciling a "measured 47,609 bytes, limit 49,152" headroom claim against an
  actual broadcast payload that turns out larger.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-7 /implement (GenesisDeployer initcode headroom test)
extraction-date: 2026-08-17
version: 1.0.0
tags:
  - solidity
  - eip-3860
  - foundry
  - deployment
  - gas
---

## Problem

A test asserts a contract's compiled creation code fits under the EIP-3860 init-code ceiling and passes with comfortable-looking headroom. The actual deployment transaction — which includes the constructor arguments — is meaningfully larger than what the test measured, so the real headroom is smaller than reported, or in a worse case the real transaction would exceed the limit the test claimed was safely under.

## Trigger Conditions

### Symptoms

- A "gas/initcode headroom" test reads `.bytecode.object` from a Foundry artifact and compares its length to 49,152
- The contract's constructor takes one or more non-trivial arguments (a struct, several addresses/uint256s)
- A real broadcast (`--broadcast`) or `cast estimate`/trace of the actual deployment transaction shows a larger payload than the artifact-only figure

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Foundry, any EVM chain enforcing EIP-3860 (post-Shanghai) |
| Environment | Any contract deployed via `CREATE`/`CREATE2` with constructor arguments |
| Timing | Discovered by comparing a unit test's measured figure against a real broadcast rehearsal's recorded payload size |
| Prerequisites | Constructor takes arguments (a zero-argument constructor has no gap) |

## Root Cause

`artifact.bytecode.object` in a Foundry (or any Solidity toolchain) build artifact is the creation bytecode ONLY — it has no knowledge of what arguments a particular deployment will pass. The EVM's `CREATE`/`CREATE2` opcodes, and EIP-3860's size check, operate on the full transaction `data` (for a top-level deployment) or full `init_code` (for CREATE2), which is `creationCode ++ abi.encode(constructorArgs)`. A test that never re-attaches the encoded arguments is measuring a strictly smaller, and therefore strictly more optimistic, number than what actually faces the limit.

## Solution

### Step 1: Compute the constructor argument encoding size directly, using the real argument struct/values

```solidity
uint256 constructorArgs = abi.encode(_yourConstructorArgs()).length;
```

For a struct of N `uint256`/`address`/`bytes32`/enum-sized fields (a "static" ABI type with no dynamic members), this is deterministically `N * 32` — assert that too, so a future field addition to the struct is caught explicitly rather than silently inflating the measured total.

### Step 2: Sum creation code and constructor-argument encoding before comparing to the limit

```solidity
bytes memory creationCode = vm.parseJsonBytes(artifact, ".bytecode.object");
uint256 launchInitcode = creationCode.length + constructorArgs;
assertLt(launchInitcode, 49_152, "the launch transaction's init code fits EIP-3860");
```

### Step 3: Cross-check against a real broadcast, not just arithmetic

Run the actual deployment (rehearsal values are fine) with `--broadcast` against a local/forked node and read the recorded transaction's `input` field length from the broadcast JSON — it should equal the computed `launchInitcode` exactly. If it doesn't, something else (proxy bytecode wrapping, a library link placeholder, etc.) is also contributing bytes the test isn't accounting for.

## Verification

### Command

```bash
forge test --match-test test_InitcodeAndRuntimeHeadroom -vv
# then, separately, a real broadcast:
forge script Deploy.s.sol --rpc-url <fork> --broadcast
node -e 'const j=require("./broadcast/Deploy.s.sol/<chainid>/run-latest.json"); console.log((j.transactions[<i>].transaction.input.length-2)/2)'
```

### Expected Output

The test's computed `launchInitcode` figure and the broadcast's actual `input` byte length match exactly.

### Checklist

- [ ] Headroom test sums creation code length AND `abi.encode(constructorArgs).length`
- [ ] The constructor-args size itself is asserted (not just folded silently into the total), so a struct field addition is visible
- [ ] Cross-checked at least once against a real broadcast payload, not only against the artifact

## Anti-Patterns

### Don't: report "headroom" from the artifact alone in evidence/documentation

Stating "creation code is 47,609 bytes against a 49,152 limit, so headroom is 1,543 bytes" when the constructor takes a 14-field struct (448 bytes of args) overstates the true headroom (1,095 bytes) by exactly the argument size — a reviewer relying on that number would be misled by a margin that happens to still round to "looks fine" but wouldn't always.
