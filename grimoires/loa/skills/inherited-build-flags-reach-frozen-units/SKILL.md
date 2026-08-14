---
name: inherited-build-flags-reach-frozen-units
description: |
  A build tool with profile inheritance (Foundry `[profile.*]`, tsconfig
  `extends`, Gradle subprojects, Maven parent POMs) applies every key set on the
  parent to every child that does not explicitly override that key. When one
  child compiles a byte-frozen vendored unit whose output must reproduce a
  published constant, adding a single bytecode-affecting key to the parent
  silently changes that child's output — and the change is invisible in the
  child's own config file, because the key does not appear there. The dangerous
  case is a child that looks safe: it pins several settings explicitly, which
  reads as "this unit's settings are fully specified" when it only means "these
  particular keys cannot be inherited". Apply when adding ANY bytecode- or
  output-affecting setting to a shared parent profile in a repository that also
  reproduces a frozen artifact hash, and when reviewing such a diff. The fix is
  cheap (pin the new key explicitly in the frozen child) but finding it depends
  on comparing EFFECTIVE resolved config, not config files.
loa-agent: implementing-tasks
extracted-from: cycle-002 / sprint-3 (Rig settlement; `via_ir` enablement)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - foundry
  - build-configuration
  - profile-inheritance
  - provenance
  - reproducible-builds
  - frozen-artifacts
---

## Problem

Enabling `via_ir = true` + `optimizer = true` on Foundry's `[profile.default]`
broke five provenance gates at once, including `POOL_INIT_CODE_HASH`
reproduction for a byte-identical vendored Uniswap v3-core tree.

Nothing in `[profile.v3core]` had been edited. Its own block already pinned the
complete refreeze-mandated set — `optimizer`, `optimizer_runs`, `evm_version`,
`bytecode_hash`, `solc` — with a comment stating that changing any of them
invalidates the hash and requires a new operator-accepted refreeze.

`via_ir` was not in that set, because it had never needed to be: nothing set it
anywhere. The moment the parent profile set it, the child inherited it, the
vendored unit compiled through a different pipeline, and its creation bytecode
changed.

Symptom shape worth recognizing: **the diff touches only the parent, and the
failure is in the child.**

## Trigger Conditions

### Symptoms

- A frozen artifact hash / init-code hash / checksum gate fails after a change
  that did not touch the vendored or frozen sources at all.
- A vendored compilation unit fails to build, or builds to different output,
  with no edit to its own profile block.
- `git diff` on the config shows additions only under the parent profile.

### When to apply proactively

- Adding any bytecode- or output-affecting key (`via_ir`, `optimizer`,
  `optimizer_runs`, `evm_version`, `bytecode_hash`, `cbor_metadata`, target
  flags) to a shared parent profile.
- Reviewing such a diff in a repo that publishes a reproducible constant.
- Introducing a NEW child profile in such a repo.

### When this does NOT apply

- Repos with a single compilation profile and no frozen output.
- Keys with no effect on emitted artifacts (`fs_permissions`, `verbosity`,
  test-only keys such as `fuzz`/`invariant` depth).

## Root Cause

Profile inheritance is defined as key-level merge, not block-level replacement.
A child profile is a **delta** against the parent, so its config file reads as a
complete specification while actually specifying only the keys it happens to
name. Every key it does not name is a live channel from the parent.

The trap is that pinning *more* keys explicitly makes the child look *more*
sealed while closing only the channels for those keys. A reviewer scanning
`[profile.v3core]` and seeing five explicit pins plus a "changing ANY of these
invalidates the hash" warning reasonably concludes the unit is isolated. It is
not: it is isolated against those five.

This is the mirror image of the already-recorded hazard that *an unset build
setting is a silent dependency on the toolchain's default*. Same mechanism, one
level up: **an unset build setting is also a silent dependency on the parent
profile.** The two failure directions share a single remedy — for a frozen unit,
enumerate the settings that must hold and pin every one of them, including the
ones currently unset everywhere.

## Solution

### 1. Diagnose against EFFECTIVE config, never the config file

The file cannot show you an inherited key. The resolver can:

```bash
FOUNDRY_PROFILE=v3core forge config | grep -E '^(via_ir|optimizer|optimizer_runs|evm_version|bytecode_hash|solc)'
```

Run it for the frozen profile before and after the parent change and diff the
two. Any key that moved is the finding — this is what turns "the gate broke
somehow" into a one-line fix.

### 2. Pin the leaked key explicitly in the frozen child

```toml
[profile.v3core]
optimizer = true
optimizer_runs = 800
evm_version = "istanbul"
bytecode_hash = "none"
# Pinned OFF explicitly, and this line is load-bearing. Profiles inherit from
# [profile.default], so a `via_ir = true` added there propagates here and changes
# this unit's compilation pipeline — and therefore POOL_INIT_CODE_HASH.
via_ir = false
```

State *why* the line exists. A future reader deleting an apparently redundant
`via_ir = false` reintroduces the bug, and the comment is the only thing that
stops them.

### 3. Re-verify the frozen constant, not just the build

A successful build is not the assertion. Re-run the gate that reproduces the
published constant.

### 4. Prefer a structural guard when the repo warrants it

Pinning one key fixes one leak; the channel stays open for the next key anyone
adds to the parent. The structural close is a check that the frozen profile's
**effective** settings equal the frozen set exactly:

```bash
# Fails on any key that appears, disappears, or changes — including keys nobody
# thought to enumerate when the guard was written.
diff <(FOUNDRY_PROFILE=v3core forge config --json | jq -S '{via_ir,optimizer,optimizer_runs,evm_version,bytecode_hash,solc}') \
     docs/authority/frozen-v3core-settings.json
```

This inverts the burden: instead of remembering to override each new key, an
un-overridden key fails loudly.

## Verification

1. **Reproduce the leak** — set the key on the parent, then
   `FOUNDRY_PROFILE=<child> forge config | grep <key>` and confirm it shows the
   parent's value with the child's file unedited.
2. **Confirm the gate catches it** — the frozen-constant gate must fail. If it
   passes while the setting differs, the gate is the real finding.
3. **Apply the pin, re-resolve** — the key now shows the frozen value.
4. **Re-run the constant gate** — reproduces the published value.
5. **Confirm the parent still has what it needed** — the whole point was to
   enable the key for the parent unit; verify it is still on there.

Observed in this session: leak confirmed via `forge config`, gate failed closed
(`verify-init-code-hash.sh`), pin applied, `POOL_INIT_CODE_HASH` reproduced at
`0xe34f199b…8b54`, all provenance gates green, 144/144 tests.

## Anti-Patterns

- **Reading the child's config block to decide what it compiles with.** It shows
  overrides, not settings. Always resolve.
- **Treating several explicit pins as evidence of isolation.** Pinning `n` keys
  seals `n` channels, not the profile.
- **Fixing it by moving the new key from the parent into every child that needs
  it.** Works today, silently wrong for the next child anyone adds — the frozen
  unit should carry the pin, because it is the unit with the requirement.
- **Accepting a green build as the verification.** The vendored unit compiled
  fine under the wrong pipeline; only the constant gate knew.
- **Deleting the "redundant" `via_ir = false`.** It is redundant only while the
  parent leaves it unset.

## Related Resources

- `foundry.toml` — `[profile.default]` rationale block and the `[profile.v3core]`
  pin, both carrying the reason inline.
- `tools/provenance/verify-init-code-hash.sh` — the gate that caught it.
- `grimoires/loa/a2a/sprint-3/reviewer.md` §6.2 — the finding as disclosed to
  review, including the residual hazard class.
- Foundry docs: profile inheritance / config resolution.

## Related Memory

- [[separate-codegen-from-metadata-in-a-bytecode-diff]] — the inverse direction
  of the same mechanism: an *unset* key inherits the **toolchain's** default.
  That entry used `[profile.v3core]`'s explicit pins as a control group, which is
  exactly the assumption this skill shows to be partial. Read together they give
  the complete rule: for a frozen unit, pin every setting that must hold,
  including ones currently unset everywhere.
- [[assert-the-toolchain-that-produced-the-evidence]] — same theme one layer out:
  the build orchestrator's own version is part of the evidence chain.
- [[independent-constant-reproduction]] — why the frozen constant must be
  re-derived rather than re-read.

## Changelog

- 1.0.0 (2026-08-13) — extracted from cycle-002 / sprint-3.

## Metadata (Auto-Generated)

- Applications: 1
- Success rate: 1/1
- Last applied: 2026-08-13
