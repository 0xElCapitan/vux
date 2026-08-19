---
name: hardfork-opcode-placement-grades-deployability
description: |
  An unpinned `evm_version` (or any toolchain-default build setting) means the
  compiler may emit opcodes newer than the target chain accepts. Detecting WHICH
  gated opcodes are present is only half the audit; the half that decides severity
  is WHERE they sit. A gated opcode reached during the deployment transaction
  makes a chain mismatch FAIL-CLOSED — creation reverts, nothing is deployed, no
  partial state exists. The same opcode on a runtime-only path that the deployment
  never touches is the dangerous case: deployment succeeds and the system goes
  live with a permanently unreachable function. Same opcode, same chain, opposite
  severity. Locate it by finding the runtime image embedded in the creation code
  and walking ONLY the constructor prefix. Apply when grading an unpinned
  `evm_version`, an Orbit/L2/alt-EVM launch, or any "will this bytecode run on
  that chain?" question — especially when a constructor deploys other contracts.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-7 /audit-sprint (review L-1 disposition, unpinned evm_version)
extraction-date: 2026-08-18
version: 1.0.0
tags:
  - solidity
  - solc
  - evm
  - bytecode
  - hard-fork
  - evm-version
  - deployability
  - severity-grading
  - constructor
  - l2
---

## Problem

A build leaves `evm_version` unset, so solc compiles at the toolchain's default
(Foundry v1.5.0 → `prague`). The deployment target is an L2 / Orbit / alt-EVM chain
whose hard-fork level is not independently recorded.

The audit question is usually framed as *"which fork-gated opcodes are in the
bytecode?"* — and answering only that produces an ungraded finding. Two systems can
contain the identical opcode at the identical fork level and carry completely
different risk:

- **Fail-closed**: the opcode executes during contract creation → an unsupported
  opcode reverts the creation transaction → nothing deploys → the launch simply
  does not happen.
- **Live partial brick**: the opcode sits only on a runtime path the deployment
  never exercises → creation succeeds → the protocol goes live → the function
  reverts forever the first time a user calls it.

Reporting "the bytecode requires Cancun" without saying which of these it is leaves
the operator unable to grade their own launch risk.

---

## Trigger Conditions

### Symptoms

- `foundry.toml` has `evm_version` unset in the profile that builds production contracts
  (often with a sibling profile that DOES pin it — that sibling is a free control group)
- Artifact metadata reads `"evmVersion": "prague"` (or any fork newer than the target chain's known level)
- The deployment target is an L2, Orbit chain, appchain, or fork whose hard-fork level is an unrecorded deployment fact
- A review/audit finding says "confirm the EVM version" without naming a threshold
- A constructor deploys other contracts (their constructors run inside the same creation transaction)

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity, solc, Foundry |
| Environment | Deployment to a chain whose hard-fork level is not the toolchain default |
| Timing | Pre-launch audit; deployment freeze; bytecode freeze |
| Prerequisites | Compiled artifacts with `bytecode.object` and `deployedBytecode.object` |

---

## Root Cause

`evm_version` is a property of the deployment chain, not of the source. Left unset,
it silently becomes a dependency on the toolchain's default. solc then freely emits
`PUSH0` (Shanghai), `MCOPY` (Cancun), transient storage (Cancun), and so on.

An undefined opcode does not corrupt execution — it reverts the current frame. So
the *consequence* is decided entirely by which frame it lands in, and contract
creation is a different frame from a later external call. Nothing in the opcode
census itself tells you which one.

---

## Solution

### Step 1: Census the gated opcodes — with both scan traps handled

Use the established walker (see **Related Memory**): strip solc's trailing CBOR
metadata and skip PUSH immediates, or you will report opcodes that are really data
bytes. In this session a naive walk reported `BLOBHASH`/Cancun that vanished once
the metadata trailer was stripped — a fabricated finding avoided by one guard.

### Step 2: Split creation code into constructor region vs embedded runtime

The creation code is `constructor logic ‖ runtime image ‖ (constructor args)`. Find
the runtime image inside the creation code and walk only the prefix before it — that
prefix is what executes during deployment.

```js
const ci = artifact.bytecode.object.replace(/^0x/, '');        // creation
const ri = artifact.deployedBytecode.object.replace(/^0x/, ''); // runtime
const idx = ci.indexOf(ri);            // runtime image embedded verbatim
if (idx < 0) throw new Error('runtime not found verbatim — do not infer, investigate');
const constructorRegion = '0x' + ci.slice(0, idx);
const seen = walk(constructorRegion);  // metadata-stripped, PUSH-skipping walker
console.log('gated opcode in constructor path:', seen.has(0x5e)); // MCOPY
```

`indexOf` returning `-1` is a real signal (immutables patched into the runtime image,
unusual codegen) — treat it as "investigate", never as "absent".

### Step 3: Grade the finding from the placement

| Placement | Chain below required fork | Severity framing |
|---|---|---|
| Gated opcode in constructor region | Creation reverts; **nothing deploys** | **Fail-closed.** Deployability/runbook item, not a security defect. No partially-launched state to inherit |
| Gated opcode only on a runtime path not exercised at deployment | Deployment succeeds; that path reverts forever | **Live defect.** A shipped system with a permanently dead function |

### Step 4: State the runbook item as a threshold, not a question

Convert "confirm the EVM version" into a checkable predicate the operator can answer
with a yes or no:

> *Does the target chain accept Cancun-level bytecode (`MCOPY`, `PUSH0`)?*

---

## Verification

### Command

```bash
node -e "const a=require('./out/Token.sol/Token.json');const ci=a.bytecode.object.replace(/^0x/,''),ri=a.deployedBytecode.object.replace(/^0x/,'');console.log('runtime offset:',ci.indexOf(ri))"
```

### Expected Output

A non-negative offset, after which the constructor-region walk yields a definite
present/absent verdict for each gated opcode.

```
runtime offset: 4356
gated opcode in constructor path: true   → fail-closed
```

### Checklist

- [ ] Metadata trailer stripped before any opcode conclusion
- [ ] PUSH immediates skipped in the walk
- [ ] Runtime image located inside creation code (offset ≥ 0, not inferred)
- [ ] Each gated opcode classified constructor-region vs runtime-only
- [ ] Finding states fail-closed or live-defect explicitly
- [ ] Runbook item phrased as a fork-level threshold, not "confirm the version"
- [ ] Sibling pinned profile (if any) cited as the control showing the omission is deliberate

---

## Anti-Patterns

### Don't: report the fork floor without the placement

```
// BAD — ungraded, and the operator cannot act on it
"The bytecode requires Cancun. Confirm the chain's EVM version."
```

This is the same sentence whether the failure mode is a harmless failed deploy or a
live protocol with a dead function.

### Don't: assume any chain mismatch is automatically fail-closed

It is fail-closed only because the opcode happens to execute during creation. Verify
placement; do not assume it.

### Don't: invent a code change to "tidy" an unpinned setting

Pinning `evm_version` changes every contract's bytecode. On an audit-approved tree
that forces a full re-audit. If the failure mode is fail-closed and no incompatibility
is demonstrated, the correct output is a runbook threshold, not a diff.

### Don't: treat a fork-run as evidence of chain opcode support

Forking a chain's *state* still executes newly deployed code under your local EVM's
rules. A green fork test says nothing about whether the real chain accepts the opcodes.

---

## Related Memory

- `grimoires/loa/skills/init-code-only-capability-proof` — **the scanning technique**:
  metadata stripping + PUSH-immediate skipping, and creation-vs-runtime presence
  assertions. This skill reuses that walker and adds the *placement-grades-severity*
  step and the constructor-region split.
- `grimoires/loa/skills/separate-codegen-from-metadata-in-a-bytecode-diff` — the
  CBOR-tail mechanics and the `evmVersion` metadata field; also states the underlying
  class: any unset build setting is a silent dependency on a toolchain default.
- `grimoires/loa/skills/inherited-build-flags-reach-frozen-units` — profile inheritance
  can carry a setting into a unit meant to be frozen.
- NOTES.md `## Learnings` — Sprint-7 audit, review finding L-1 disposition.
