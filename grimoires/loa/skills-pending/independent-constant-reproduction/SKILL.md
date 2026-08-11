---
name: independent-constant-reproduction
description: |
  When a report claims a deterministic constant was "reproduced" (init-code
  hash, merkle root, build checksum, reproducible-build digest), re-running the
  project's own test proves only internal consistency — the test and the
  constant can both be wrong together, or the constant may simply be compared
  against another hard-coded copy. Break the circularity by recomputing the
  value with an implementation the project does not own, self-validated against
  published vectors first. Apply during code review and audit of any
  determinism or reproducibility claim. Includes the argv-length workaround for
  hashing large payloads on the command line.
loa-agent: reviewing-code
extracted-from: cycle-002 sprint-1 /review-sprint (POOL_INIT_CODE_HASH verification)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - code-review
  - verification
  - reproducible-builds
  - cryptography
  - keccak256
  - solidity
  - circular-evidence
---

## Problem

A report states that a constant is reproduced from source under pinned build
settings, and cites a passing test as evidence:

```solidity
assertEq(keccak256(creationCode), ACCEPTED_CONSTANT, "INIT_CODE_HASH");
```

Running that test and seeing it pass proves the artifact currently in the build
directory hashes to the value hard-coded in the test file. It does not prove:

- the constant matches the *authority's* accepted value (the test's copy could
  have been edited to match a drifted build);
- the build actually used the pinned compiler and settings;
- the artifact was rebuilt at all rather than read from a stale cache;
- the hash function the project uses is the one the ecosystem means.

The claim under review is "reproduced from source"; the available evidence is
"self-consistent". Those are different claims and only the first is usually
what an acceptance criterion requires.

---

## Trigger Conditions

### Symptoms

- A requirement says "reproduced", "recomputed", "deterministic", or "fails
  closed on mismatch" — and the cited evidence is the project's own test.
- The expected value appears as a literal in the test file *and* in the
  authority document (two copies that could silently diverge).
- Build settings that affect the output are declared in config but not asserted
  against the artifact that was actually produced.
- A cached build directory exists and it is unclear whether a rebuild occurred.

### Error Messages

Hashing a large payload on the command line commonly hits:

```
/path/to/cast: Argument list too long
```

This is `E2BIG` from `execve`, not a hash mismatch — do not misread it as a
failed verification.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity/Foundry, reproducible builds, any pinned-toolchain artifact |
| Environment | Code review, security audit, provenance/supply-chain assessment |
| Timing | Whenever a determinism claim is load-bearing for approval |
| Prerequisites | Ability to force a clean rebuild and run one independent runtime |

---

## Root Cause

Evidence is circular when the thing being verified and the thing doing the
verifying share an origin. The project's test, the project's build config, and
the project's constant are one system; a green test is that system agreeing
with itself. Independence has to come from outside it — a different
implementation, validated separately, applied to the same bytes.

---

## Solution

### Step 1: Force a genuine rebuild

Never hash whatever happens to be sitting in the output directory.

```bash
FOUNDRY_PROFILE=<pinned-profile> forge build --force
```

Confirm from the log that compilation actually ran (`Compiling N files with
Solc X.Y.Z`), not `No files changed, compilation skipped`.

### Step 2: Read the build semantics off the ARTIFACT, not the config

The config states intent; the artifact records what happened. Compare them.

```bash
jq -r '.metadata.compiler.version' out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json
jq -c '.metadata.settings
       | {optimizer, evmVersion, bytecodeHash: .metadata.bytecodeHash}' \
       out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json
```

```
0.7.6+commit.7338295f
{"optimizer":{"enabled":true,"runs":800},"evmVersion":"istanbul","bytecodeHash":"none"}
```

### Step 3: Check cheap structural facts before the hash

Length and trailing metadata catch truncated or differently-configured
artifacts with a far clearer failure than an opaque hash mismatch.

```bash
OBJ=$(jq -r '.bytecode.object' <artifact>); HEX=${OBJ#0x}
echo "bytes : $(( ${#HEX} / 2 ))"      # expect the recorded length
echo "tail  : ${HEX: -24}"             # expect the recorded CBOR tail
```

### Step 4: Recompute with an implementation the project does not own

Prefer, in order: a different installed tool, a different language runtime, or
a small self-written implementation. **Self-validate it against published
vectors before trusting its output** — an unvalidated reimplementation is worse
evidence than the project's test.

For Keccak-256 (Ethereum variant: rate 136 bytes, domain pad `0x01`, *not*
NIST SHA3's `0x06`), known vectors:

```
keccak256("")        = c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
keccak256("abc")     = 4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45
keccak256("testing") = 5f16f4c7f149ac4f9510d9cf8cf384038ad348b3bcdc01915f95de12df9d1b02
```

```js
// node — read the artifact, hash the bytes, never pass them as argv
const art = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));
const buf = Buffer.from(art.bytecode.object.replace(/^0x/, ''), 'hex');
console.log('0x' + keccak256(buf));   // keccak256 = your validated implementation
```

Note: `crypto.createHash('sha3-256')` is **NIST SHA3**, not Keccak-256, and
Python's `hashlib.sha3_256` likewise. They differ only in the padding byte and
will silently produce a wrong-but-plausible digest.

### Step 5: Compare against the AUTHORITY's value, not the test's copy

Read the expected constant from the accepted authority document/registry, and
compare that to your independently computed digest. If the test file's literal
also matches, that is a bonus consistency check — not the primary evidence.

---

## Verification

### Command

```bash
node keccak.js out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json
```

### Expected Output

```
vector keccak256("")        = c5d2460186f7233c...5d85a470 OK
vector keccak256("abc")     = 4e03657aea45a94f...fa12d6c45 OK
vector keccak256("testing") = 5f16f4c7f149ac4f...df9d1b02 OK
self-validation: PASS

compiler           : 0.7.6+commit.7338295f
creation code bytes: 22728
cbor tail          : a164736f6c6343000706000a
keccak256          : 0xe34f199b...f87b8b54
accepted           : 0xe34f199b...f87b8b54
VERDICT            : MATCH
```

### Checklist

- [ ] Rebuild forced and compilation confirmed in the log
- [ ] Compiler identity + every output-affecting setting read from the artifact
- [ ] Length and trailing-metadata facts checked before the digest
- [ ] Independent implementation self-validated against published vectors
- [ ] Digest compared against the AUTHORITY's constant, not only the test's
- [ ] Any tooling error (e.g. `Argument list too long`) distinguished from a mismatch

---

## Anti-Patterns

### Don't: treat a passing project test as reproduction evidence

```bash
# WEAK - proves the system agrees with itself
forge test --match-path test/provenance/InitCodeHash.t.sol   # 2 passed
```

### Don't: pass large payloads as argv

```bash
# BAD - E2BIG on payloads of a few tens of KB; looks like a failure
cast keccak "0x$(jq -r '.bytecode.object' artifact.json)"
```

Read the payload from a file inside the hashing program instead.

### Don't: substitute SHA3-256 for Keccak-256

```js
// BAD - different padding byte; wrong digest, no error raised
crypto.createHash('sha3-256').update(buf).digest('hex');
```

### Don't: trust a self-written hasher without vectors

An unvalidated reimplementation that happens to disagree produces a false
finding; one that happens to agree proves nothing. Validate first, always.

---

## Related Resources

- FIPS 202 (SHA-3) vs. original Keccak submission — the padding-byte difference
- Reproducible Builds project — independent rebuild as the verification standard

---

## Related Memory

### NOTES.md References

- `## Decision Log`: 2026-08-11 [review sprint-1] "Verified by reproduction, not
  by reading" — records why the method was chosen
- `## Session Continuity`: 2026-08-11 /review-sprint sprint-1 — the reproduced
  values and settings

### Related Skills

- `fail-closed-gate-scope-probe`: the sibling review technique — demonstrate a
  gate's blind spot empirically rather than asserting it from source reading

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction from cycle-002 sprint-1 review |

---

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: reviewing-code
  phase: /review-sprint
  session: cycle-002-sprint-1-review
```
