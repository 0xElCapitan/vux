---
name: assert-the-toolchain-that-produced-the-evidence
description: |
  A build orchestrator's version is part of the evidence chain, not ambient
  context. The same repository at the same commit can produce opposite verdicts
  under two versions of the same tool: a Foundry probe proving a mixed-case
  `.SOL` file is build-reachable PASSES under v1.5.0 and hard-fails under v1.0.0
  with `Error: unexpected file extension` — so "we reproduced it locally" and
  "CI is red" were both true and both honest. Recording a pin is not asserting
  it, printing a version is not asserting it, and matching a version substring
  is not asserting it. Apply whenever local and CI results disagree at one
  commit, whenever a security control's verdict rests on compiler or build-tool
  behavior, before trusting Foundry/solc/bundler-dependent evidence in a review
  or audit, and when adding or moving a toolchain pin. The fix is a fail-closed
  assertion on the exact 40-character release commit, enforced in the local gate
  and CI by the same code path, and proven by running it with the wrong version.
loa-agent: implementing-tasks
extracted-from: cycle-002 Foundry v1.5.0 toolchain refreeze + CI recovery (2026-08-12)
extraction-date: 2026-08-12
version: 1.0.0
tags:
  - toolchain
  - provenance
  - foundry
  - solidity
  - ci
  - supply-chain
  - evidence-integrity
  - fail-closed-gates
  - reproducibility
---

## Problem

Implementation, review, and audit ran against a locally installed Foundry
v1.5.0. CI installed the pinned v1.0.0. Both were "the same repository at the
same commit". The post-merge pipeline went red on a single check — a positive
control asserting that a mixed-case `.SOL` source file really is compiled and
executable:

```
Error: unexpected file extension
```

Under v1.5.0 that same probe emits `src/CaseReach.SOL` into solc's
`metadata.sources` and reports `[PASS]` on a deployed instance. Under v1.0.0
`forge` refuses the file before solc ever sees it.

Nothing in the repository changed between those two outcomes. The verdict of a
**security control** — is unauthorized source build-reachable? — was a function
of which binary happened to be on `PATH`.

The failure mode this creates is worse than a red pipeline. A red pipeline is
loud. The quiet version is an audit that concludes "unreachable, informational"
using a toolchain that is not the one production builds with.

---

## Trigger Conditions

### Symptoms

- Local checks pass and CI fails (or vice versa) at the same commit, with no
  code difference and no flake.
- A gate, probe, or negative demonstration produces a different verdict on two
  machines.
- An audit or review conclusion rests on "the compiler cannot see it either" or
  "the toolchain rejects this too".
- A build artifact's hash differs between environments that "should" match.
- A toolchain pin exists in config, but no check ever compares it to the running
  binary.
- `command -v <tool>` succeeds and the result is treated as *the* pinned tool.

### Error Messages

Version-dependent build-tool refusals — the exact string varies, the class does
not:

```
Error: unexpected file extension
```

```
Unable to resolve imports:
      "../src/CaseReach.SOL" in ".../test/CaseReach.t.sol"
...
Compiler run successful!
```

The second is the trap in its purest form: a resolver complaint and a successful
compile in one run. See `resolver-diagnostic-is-not-reachability`.

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Foundry (`forge`/`cast`/`anvil`), solc; generalizes to any build orchestrator with a pinned version (bundlers, `cargo`, `go`, Bazel) |
| Environment | Local dev + CI, or any two environments producing comparable evidence |
| Timing | On version bumps, on CI/local divergence, before relying on toolchain-dependent evidence in review/audit |
| Prerequisites | Toolchain publishes a verifiable identity (`forge --version` prints a 40-char commit); an official version-selection mechanism exists (`foundryup -i <tag>`) |

---

## Root Cause

Treating a build orchestrator as "not bytecode-affecting, therefore not
evidence-affecting" is the error. It is a defensible statement about
*compilation* and a false statement about *evidence*, for two independent
reasons:

1. **The orchestrator decides what reaches the compiler.** File discovery,
   extension handling, import graph walking, and remapping all happen before
   solc runs. A version that refuses a file makes that file look unreachable —
   which is exactly the conclusion an audit is trying to test.

2. **The orchestrator decides what the compiler is told.** Every build setting
   left unset in config inherits the orchestrator's default. Foundry's default
   `evm_version` moved `cancun` → `prague` between v1.0.0 and v1.5.0, so an
   unpinned profile silently changed a compiler input with no repository change.
   (See `separate-codegen-from-metadata-in-a-bytecode-diff`.)

Both are invisible in the repository. Neither is caught by pinning a version in
a comment, because a pin nobody compares against is documentation.

The secondary cause is assertion weakness. A check like:

```bash
case "$ver" in *"${FOUNDRY_VERSION#v}"*) ok ;; esac
```

accepts any build whose version string happens to contain `1.0.0` — a nightly, a
fork, a local `cargo build`, a `1.0.01`. And a CI workflow that asserts against
its *own input* (`FOUNDRY_VERSION`) is checking that the request equals the
request. The request is not the evidence; the installed binary is.

---

## Solution

### Step 1: Resolve the identity from primary upstream evidence

Never take a version→commit mapping from a prompt, a changelog, or a wiki. Ask
the source of truth, and confirm the tag object actually resolves to the commit:

```bash
gh api repos/foundry-rs/foundry/git/ref/tags/v1.5.0
# -> {"object":{"sha":"1c57854462289b2e71ee7654cd6666217ed86ffd","type":"commit"}}

gh api repos/foundry-rs/foundry/releases/tags/v1.5.0 \
  --jq '{tag_name,draft,prerelease,published_at}'
# -> draft:false, prerelease:false  (a draft/prerelease is not a release pin)
```

Note `object.type`: a lightweight tag points straight at a commit; an annotated
tag points at a tag object and needs `^{}` peeling. Recording the tag object's
SHA as the commit is a classic off-by-one-indirection error.

### Step 2: Install through the official mechanism, and keep the old version

Use the tool's own version selector so you get artifact/attestation
verification, not a hand-placed binary:

```bash
foundryup -i v1.5.0      # installs into a version slot, verifies attestation
foundryup -l             # lists installed slots
```

Two traps:

- A slot named `stable` is **mutable**. It may already contain the version you
  want (`forge Version: 1.5.0-stable`) and will silently become something else
  later. Pin to the exact tag slot, never to `stable`, `latest`, or `nightly`.
- Keep the previous version installed. It is invocable by absolute path
  (`~/.foundry/versions/v1.0.0/forge`) and you will need it for the parity
  comparison and for the negative demonstration in Step 5.

### Step 3: Confirm the binary self-reports the expected identity

```bash
forge --version
# forge Version: 1.5.0-v1.5.0
# Commit SHA: 1c57854462289b2e71ee7654cd6666217ed86ffd
```

If the installed binary does not report the expected release identity, stop.
That is a supply-chain signal, not a configuration nit.

### Step 4: Assert it fail-closed, in the shared gate

Put the assertion where **both** local validation and CI execute it, so the two
cannot drift again. Require the commit *and* the version — the commit alone
would accept a build that shipped under a different tag, the version alone
accepts anything calling itself that:

```bash
echo "== running Foundry identity =="
if ! command -v forge >/dev/null 2>&1; then
  fail "forge is not on PATH — the authoritative toolchain $FOUNDRY_TAG @ $FOUNDRY_COMMIT cannot be verified"
else
  forge_id="$(forge --version 2>/dev/null || true)"
  if [[ "$forge_id" != *"$FOUNDRY_COMMIT"* ]]; then
    fail "running Foundry does not self-report the authoritative commit $FOUNDRY_COMMIT:"$'\n'"$forge_id"
  elif [[ "$forge_id" != *"${FOUNDRY_TAG#v}"* ]]; then
    fail "running Foundry reports the authoritative commit but not version $FOUNDRY_TAG:"$'\n'"$forge_id"
  else
    pass "running Foundry is $FOUNDRY_TAG @ $FOUNDRY_COMMIT (self-reported)"
  fi
fi
```

`forge --version` prints the commit on line 2 — capture the **full** output, not
`| head -1`.

Absence must fail, not skip. `if command -v forge; then check; fi` degrades to
silence exactly when the tool is missing, which is when you least want silence.

### Step 5: Cover CI jobs that skip the shared gate

Any CI job that installs the toolchain but does not run the gate is unasserted.
In practice the job most likely to be missed is the one running the
toolchain-dependent probe:

```yaml
env:
  FOUNDRY_VERSION: v1.5.0
  FOUNDRY_COMMIT: 1c57854462289b2e71ee7654cd6666217ed86ffd

# after the install step, in EVERY job that compiles:
- name: Assert the pinned Foundry toolchain
  run: |
    ver="$(forge --version)"
    echo "$ver"
    case "$ver" in
      *"$FOUNDRY_COMMIT"*) : ;;
      *) echo "::error::expected Foundry commit ${FOUNDRY_COMMIT}, got: $ver"; exit 1 ;;
    esac
    case "$ver" in
      *"${FOUNDRY_VERSION#v}"*) : ;;
      *) echo "::error::expected Foundry ${FOUNDRY_VERSION}, got: $ver"; exit 1 ;;
    esac
```

Prefer duplicating ten lines over refactoring a fence. Sourcing a shared library
into a demonstration script that deliberately runs under `set -uo pipefail` (no
`-e`) can turn `-e` on and change which probes exit early — a behavioral change
to a safety fence in exchange for DRY is a bad trade.

---

## Verification

The assertion is a fence. An untested fence is a comment with a shell prompt.
Run the gate with the **wrong** version first on `PATH` and confirm it fails for
the right reason and only that reason:

### Command

```bash
PATH="$HOME/.foundry/versions/v1.0.0:$PATH" bash tools/provenance/verify-pins.sh; echo "EXIT=$?"
```

### Expected Output

```
ok    foundry v1.5.0 pin recorded in foundry.toml (1c57854462289b2e71ee7654cd6666217ed86ffd)
ok    =0.8.28 unit: all 50 artifact(s) under out/ compiled by 0.8.28+commit.7893614a

== running Foundry identity ==
FAIL  running Foundry does not self-report the authoritative commit 1c578544...:
forge Version: 1.0.0-v1.0.0
Commit SHA: 8692e926198056d0228c1e166b1b6c34a5bed66c

1 check(s) failed.
EXIT=1
```

Exactly **one** failure, and it is the toolchain one — every other check staying
green is what proves the assertion is discriminating rather than incidentally
tripped. (Method: `prove-which-fence-caught-it`.)

### Checklist

- [ ] Tag→commit resolved from the upstream API, `object.type` inspected
- [ ] Release confirmed non-draft, non-prerelease
- [ ] Installed via the official selector with attestation/checksum verification
- [ ] Running binary self-reports the exact 40-character commit
- [ ] Assertion requires commit **and** version, from full `--version` output
- [ ] Missing tool FAILS rather than skipping
- [ ] Every CI job that compiles asserts, not just the one running the gate
- [ ] No `stable` / `latest` / `nightly` / branch reference anywhere
- [ ] Fence proven closed by running with the previous version

---

## Anti-Patterns

### Don't: assert against the workflow input

```yaml
# BAD — checks that the request equals the request
- run: |
    forge --version | grep "${{ env.FOUNDRY_VERSION }}"
```

The input caused the install; it cannot also witness it. Assert against the
40-character commit, which the input does not contain.

### Don't: match a version substring

```bash
# BAD — accepts 1.0.01, a nightly, a fork, a local cargo build
case "$ver" in *"${FOUNDRY_VERSION#v}"*) ok ;; esac
```

### Don't: print instead of fail

```bash
# BAD — a divergence scrolls past in a 4,000-line CI log
info "running forge: $(forge --version | head -1)"
info "pinned release: foundry $TAG @ $COMMIT (installed by CI)"
```

This is the exact shape the original gate had, justified by "Foundry is an
orchestrator, not bytecode-affecting". The reasoning is incomplete (see Root
Cause) and the consequence was a red pipeline nobody could attribute.

### Don't: treat "a tool is on PATH" as "the pinned tool is on PATH"

`command -v forge` succeeding tells you a binary exists. It does not tell you
which one. The inverse trap is equally live: a toolchain can be installed under
`~/.foundry/bin` and simply absent from an MSYS/Git-Bash `PATH`, which reads as
"not installed" and tempts a reviewer into accepting a report on trust.

### Don't: rewrite history when the pin moves

Superseding a toolchain selection is a dated delta that says "v1.0.0 was
authoritative until 2026-08-12, v1.5.0 is authoritative after". Editing old
audit reports so they claim the new version was always in use destroys the only
record of the divergence — and the divergence is the finding.

---

## Related Resources

- [Foundry releases](https://github.com/foundry-rs/foundry/releases)
- [foundry-toolchain action](https://github.com/foundry-rs/foundry-toolchain)
- [GitHub git-refs API](https://docs.github.com/en/rest/git/refs)

---

## Related Memory

### NOTES.md References

- `## Learnings`: "[Review integrity - absent from PATH is not absent]" — the
  narrower precursor to this skill: a tool missing from `PATH` is not a tool
  missing from the machine. This skill generalizes it to *which* tool.
- `## Session Continuity`: 2026-08-12 Foundry v1.5.0 toolchain refreeze — probe
  12's opposite verdicts under v1.0.0/v1.5.0, and the parity validation.
- `## Decision Log`: 2026-08-12 entries on the fail-closed upgrade and on
  duplicating the assertion rather than sourcing `census.sh` into a demo script.

### Related Skills

- `resolver-diagnostic-is-not-reachability`: **refined by this skill.** That
  skill's evidence (the "Unable to resolve imports" + successful compile pairing)
  is itself toolchain-conditional — it reproduces under Foundry v1.5.0 and
  cannot be reproduced at all under v1.0.0, which rejects the file outright.
  Record the toolchain identity alongside any reachability finding.
- `separate-codegen-from-metadata-in-a-bytecode-diff`: the second mechanism by
  which an orchestrator version leaks into evidence — unset build settings
  inheriting the orchestrator default.
- `prove-which-fence-caught-it`: the method used to verify this assertion is
  discriminating.
- `independent-constant-reproduction`: reproducing a constant under a stated
  toolchain; that statement is only meaningful once the toolchain is asserted.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-12 | Initial extraction |

---

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: implementing-tasks
  phase: /retrospective --scope implementing-tasks
  session: cycle-002 foundry-v1.5-toolchain-refreeze 2026-08-12
```
