---
name: ask-the-toolchain-not-the-filename
description: |
  A default-deny gate that enumerates its universe with a filename predicate
  (`find -iname '*.sol'`, `**/*.py`, `*.tf`) is exactly as wide as that predicate
  — and no filename predicate is complete, because the toolchain decides what it
  admits, not the filesystem. Compilers, bundlers and interpreters resolve
  imports by path string, not by extension: Foundry v1.5.0 compiles and executes
  Solidity imported as `Payload.txt` or with no extension at all. Widening the
  allowlist only moves the boundary to the next unenumerated name. The fix is to
  stop guessing from names: derive the enforcement universe as the UNION of the
  filesystem walk and the toolchain's own record of what it compiled (solc's
  `metadata.sources`, a bundler's module graph, a compiler's depfile), because
  each half covers the other's blind spot — the walk sees dormant files nothing
  imports, the toolchain half sees admitted files no name predicate matches.
  Apply when implementing or hardening "no unauthorized X anywhere" for source
  provenance, licence headers, dependency policy, or secret scanning. Two
  non-obvious consequences carry the risk: the toolchain half is only evidence if
  a build actually produced it (so an absent build must FAIL, not contribute
  nothing), and any freshness assertion you add will be tripped by your own
  negative probes, firing the wrong fence and destroying probe attribution.
loa-agent: implementing-tasks
extracted-from: cycle-002 / bounded pre-Sprint-3 provenance-tooling hardening node (M-1/L-3/L-4)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - default-deny
  - provenance
  - fail-closed-gates
  - toolchain-admission
  - build-artifacts
  - implementation-technique
  - negative-controls
---

## Problem

A repository-wide default-deny boundary classified every file it could see into
`vendored` / `owned` / `unauthorized`, and failed closed on the third class. It
enumerated "every file it could see" like this:

```bash
find . ... -iname '*.sol' -print          # the source universe
```

Every consumer — default-deny classification, prohibited-content scanning, SPDX
policy, a quarantine gate — derived from that one list, which is exactly the
right architecture. But the list's membership rule was a **filename** rule, and
the thing it was defending against was decided by a **compiler**.

Under the accepted toolchain, Solidity imported as `docs/payload.txt` — or from a
file with no extension at all — reaches solc, is recorded in the importing
artifact's `metadata.sources`, is embedded in that contract's bytecode, and
executes from a deployed instance. `find -iname '*.sol'` returns nothing for it.

Measured on the real tree, before any fix, with two such payloads present:

```
metadata.sources of the importer:
  docs/loa-probe-payload-noext        <- extensionless, IS compiled source
  docs/loa-probe-payload.txt          <- .txt, IS compiled source

verify-census.sh:
  ok    zero unauthorized Solidity source anywhere in the repository (78 file(s) classified)
  All checks passed.                                       GATE_EXIT=0
```

The gate was **green** while two unclassified sources were already in the build.
Every downstream consumer inherited the blindness at once, so the licence check,
the prohibited-content scan and the quarantine gate were all silent too.

---

## Trigger Conditions

### Symptoms

- A gate claims "no unauthorized X **anywhere**" but its universe comes from a
  name pattern (`-name`, `-iname`, `**/*.ext`, `git ls-files '*.ext'`).
- A toolchain upgrade is defended with output parity (identical bytecode/bundle)
  — parity covers what the tool *emits*, never what it *accepts*.
- An audit finding says a detector is "extension-keyed", "case-sensitive", or
  "evadable by renaming", and the proposed fix is a longer extension list.
- You can write a file the build consumes that `git grep`-style tooling and the
  gate both ignore.
- A previously latent naming gap becomes reachable after a version bump, with no
  repository change.

### Error Messages

None — that is the hazard. The gate prints `ok` and exits 0. The only signal is
the *absence* of a file you know is in the build from the gate's own accounting
line (`source universe: 78 file(s)` while the compiler reports 80).

### Context

| Context | Value |
|---|---|
| Gate shape | Multi-check fail-closed script whose universe is one shared derived list |
| Toolchain | Any that resolves inputs by path string rather than extension — solc/Foundry, webpack/rollup/esbuild, tsc, cargo, bazel |
| Timing | Hardening an audit finding about an extension- or case-keyed predicate; or after a toolchain migration widened admission |
| Prerequisites | The toolchain emits a machine-readable record of its inputs (`metadata.sources`, `build-info`, `.d` depfiles, a bundler stats/graph file) |
| Cross-domain | Licence-header gates keyed on `*.js`, secret scanners keyed on `*.env`, IaC policy keyed on `*.tf` — all the same shape |

---

## Root Cause

**A membership predicate cannot be more complete than the authority that decides
membership.** The gate asked the filesystem "which files look like source?"; the
security-relevant question is "which files did the toolchain treat as source?".
Those are different questions, and only the second one has an authoritative
answer — the toolchain's.

Extensions are a *convention* for humans and for the tool's discovery pass. Import
resolution is a *mechanism*: solc calls back to the filesystem with the import
string byte-for-byte. Nothing in that path consults an extension, which is why
each new naming axis (case, extension, no extension, unicode homoglyph, trailing
dot) is another instance of one defect, not a new one. Fixing an axis at a time
also makes the surviving prose *more* misleading, because "anywhere in the
repository" keeps getting reasserted while remaining false.

---

## Solution

### Step 1: Ask the toolchain what it compiled

Read the tool's own record of its inputs. For Foundry/solc, every artifact JSON
carries `metadata.sources`, keyed by the path the compiler resolved —
repo-relative and forward-slashed, so it joins directly against a filesystem
census with no normalisation beyond CR-stripping.

```bash
# Extension-independent by construction: nothing here matches a name pattern.
compiled_sources() {
  find "${BUILD_OUT_DIRS[@]}" -name '*.json' -not -path '*/build-info/*' -print0 \
    | xargs -0 -r jq -r 'if has("metadata") then (.metadata.sources | keys[]) else empty end' \
    | tr -d '\r' | sed 's|\\|/|g; s|^\./||' | sed '/^$/d' | LC_ALL=C sort -u
}
```

Verify the join before trusting it — a path-format mismatch makes *everything*
look unauthorized, which is a comparison bug wearing a finding's clothes:

```bash
comm -23 <(compiled_sources) <(filesystem_walk)   # expect empty on a clean tree
```

### Step 2: Union the two halves into ONE universe

Do not add a second, parallel scanner. Keep exactly one definition so every
consumer inherits the widening with no per-consumer change.

```bash
filesystem_sol_sources() { find . ... -iname '*.sol' -print | ... ; }   # unchanged

source_universe() {
  { filesystem_sol_sources; compiled_sources; } | sed '/^$/d' | LC_ALL=C sort -u
}
```

| half | sees | blind to |
|---|---|---|
| filesystem walk | every name-matching file, tracked or not | source not *named* like source |
| toolchain record | every path the compiler resolved, whatever it is called | source nothing imports |

Neither is authoritative alone. This is a **complement, not a replacement** — the
walk is the only thing that catches a dormant unauthorized file, which is
precisely what a toolchain record can never contain.

### Step 3: Fail closed when the toolchain half is missing

This is the step that is easy to skip and fatal to skip. An unbuilt project
yields an empty toolchain half, which silently collapses the universe back to the
filename predicate — the exact defect being fixed, now invisible because the gate
still passes.

```bash
for unit in out out-v3core; do
  if [[ "$(compiled_sources "$unit" | wc -l)" == "0" ]]; then
    fail "no compiler-admitted source evidence under $unit/ — that unit has not
          been built, so the extension-independent half of the universe is empty."
  fi
done
```

Assert **per compilation unit**, not globally: a project with two units passes a
global non-empty check while one unit contributes nothing.

### Step 4: Attribute the catch to the half that made it

The two halves mean different things — the walk catches a file that merely
*exists*, the toolchain half catches one that is already *in a build*. Emit
different messages, or your negative probes cannot prove which fence fired.

```bash
if grep -qxF "$f" <<<"$walked"; then
  fail "unauthorized source — neither an accepted census row nor inside a declared root: $f"
else
  fail "unauthorized compiler-admitted source — the toolchain compiled this file, yet it is
        neither an accepted census row nor inside a declared root; its filename kept it out
        of the walk: $f"
fi
```

### Step 5: Make the probes rebuild, and assert admission before the catch

A probe the compiler never saw has not been planted. Each negative probe must
plant a payload **plus an importer inside a declared source root**, rebuild, then
assert two things in order:

```bash
plant  docs/probe-payload.txt          # payload — invisible to the walk
plant  test/ProbeImporter.sol          # importer — the only place an import can originate
rebuild
assert_compiled "docs/probe-payload.txt"     # POSITIVE control: it is in metadata.sources
expect_fail gate 'unauthorized compiler-admitted source' \
                 'unauthorized source'       # ...and the OTHER half did not fire
```

The positive control matters because the negative probe is meaningless if the
toolchain refused the payload for an unrelated reason (a syntax error, a pragma
mismatch, a resolver change). Assert admission from `metadata.sources` — never
from a resolver diagnostic, and never from "an artifact directory appeared".

Restoration must remove the **importer's artifact**, not just the source files:
the payload lives on in the compiled half until that artifact is gone, so a probe
teardown that only deletes sources leaves the gate red.

---

## Verification

### Command

```bash
bash tools/provenance/run-all.sh          # builds both units, then every gate
bash tools/provenance/demo-boundary-negative.sh
```

### Expected Output

```
ok    [profile.default]: 47 source(s) recorded by the compiler in out/
ok    [profile.v3core]: 32 source(s) recorded by the compiler in out-v3core/
      source universe: 77 file(s) — 63 vendored (census), 14 owned
        evidence: 77 from the filename walk, 71 compiler-admitted, 0 reachable ONLY through the compiler
ok    zero unauthorized source in the classified universe (77 file(s) classified)

── probe 14 — Solidity in a .txt file, imported from a declared root
  ok    POSITIVE control: solc recorded docs/…payload.txt in metadata.sources
  ok    gate failed closed for the right reason [imported .txt payload] (exit 1)
          isolated: no FAIL line matches /unauthorized source/
          FAIL  unauthorized compiler-admitted source — … docs/…payload.txt
```

The `0 reachable ONLY through the compiler` line is the healthy steady state: on
a clean tree the toolchain half adds no members, so it is a fence, not a fix for
a present violation. A non-zero value there is a live finding.

Fail-closed proof (do this, do not assert it):

```
$ mv out-v3core out-v3core.tmpbak && bash gate; mv out-v3core.tmpbak out-v3core
FAIL  no compiler-admitted source evidence under out-v3core/ …      exit 1
… restored …                                                        exit 0
```

### Checklist

- [ ] The toolchain record's path format was joined against the census and proven to match (empty `comm -23` on a clean tree)
- [ ] There is exactly ONE universe function; no consumer re-derives its own list
- [ ] An unbuilt compilation unit FAILS the gate, proven by removing its output directory
- [ ] The emptiness check is per-unit, not global
- [ ] Walk-caught and toolchain-caught violations produce distinguishable messages
- [ ] Every negative probe rebuilds, asserts `metadata.sources` admission first, and asserts the other half did *not* fire
- [ ] Probe teardown removes the importer's artifact, and the gate is proven green again afterwards
- [ ] The gate's prose claim was corrected to match what it now actually enforces

---

## Anti-Patterns

### Don't: extend the extension allowlist

```bash
# BAD — this is the same bug with a longer list; the next name wins.
find . \( -iname '*.sol' -o -iname '*.txt' -o -iname '*.sol.bak' \) -print
```

There is no finite list. `.txt` was the demonstrated bypass, not the class.

### Don't: let a missing build contribute an empty set

```bash
# BAD — no artifacts means no compiled paths means nothing unauthorized. Green, and blind.
compiled="$(compiled_sources)"   # "" when nothing was built
```

An absent evidence source is a failure, never a quiet zero. This is the same
shape as a prune list that makes a check pass *because it is looking at nothing*.

### Don't: add a "artifacts newer than sources" staleness assertion

This is the trap that looks like rigour. It is tripped by **your own probes** —
planting any probe file makes the tree newer than the build, so the staleness
check fires instead of the boundary check, and every negative probe now proves
"something failed" rather than "the fence caught it". That destroys exactly the
attribution the probe suite exists to provide.

Handle freshness with a **pipeline contract** instead: the per-unit emptiness
check is fail-closed, the gate runner builds before any gate, and each demo
builds at baseline and again around every probe that changes the compilation
graph. State the ceiling in code rather than pretending it is not there.

### Don't: read admission from a resolver diagnostic or an emitted artifact directory

A resolver warning describes the tool's discovery pass, not what compiled — and
no separate artifact directory is emitted for an imported non-standard-named
payload, so "an artifact appeared" is not an oracle either. `metadata.sources`
is. (See `resolver-diagnostic-is-not-reachability`.)

### Don't: keep the old prose claim

"Every Solidity file in the working tree is classified" and "zero unauthorized
source **anywhere in the repository**" were overstatements on the naming axis
before the fix. If the fix lands but the sentence does not change, the next
reader inherits the same false confidence the gate used to produce.

---

## Related Resources

- `tools/provenance/census.sh` — `compiled_sources()`, `filesystem_sol_sources()`, and the union `source_universe()`
- `tools/provenance/verify-census.sh` — per-unit fail-closed evidence check and origin-attributed failure messages
- `tools/provenance/demo-boundary-negative.sh` — probes 14/15/16 with per-probe `metadata.sources` positive controls
- `grimoires/loa/a2a/sprint-2/auditor-sprint-feedback.md` §8, §9.5, §15 — the M-1 finding and its prescribed fix shape
- `grimoires/loa/a2a/foundry-v1.5-refreeze/auditor-feedback.md` §5 — why a toolchain move *created* the reachable form

---

## Related Memory

### NOTES.md References

- `## Learnings` — "[Implementation technique — an enforcement universe cannot be narrower than the toolchain]"

### Related Skills

- [[default-deny-source-boundary]] — the predecessor. That one inverts *location*
  scoping into default-deny and warns that the prune list becomes the new hole;
  this one closes the *naming* axis of the same boundary. Apply both: location
  and naming are independent axes of one predicate.
- [[matcher-asymmetry-in-default-deny-gates]] — the audit lens that finds this
  class by comparing two predicates over the same universe. That skill detects
  the asymmetry; this one removes the predicate that causes it.
- [[parity-proves-emission-not-admission]] — the review-side sibling: a toolchain
  bump defended by output parity can still widen admission. That finding is what
  escalates this work from "hardening" to "required".
- [[resolver-diagnostic-is-not-reachability]] — supplies the oracle used in
  Step 5; never take a warning or a missing artifact dir as evidence.
- [[prove-which-fence-caught-it]] — why Step 4's distinguishable messages and
  Step 5's negative assertion are mandatory rather than stylistic.
- [[verify-the-mutant-not-the-verdict]] — apply it to the *control* as well as
  the subject: a fix that removes instances of the hazard can quietly starve the
  regression control that guards it, so revert the fix and require the control
  to fail.

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-08-13 | Extracted from the bounded pre-Sprint-3 provenance-tooling hardening node (M-1) |

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
  phase: /implement (bounded node — M-1/L-3/L-4 provenance-tooling hardening)
  session: 2026-08-13
```
