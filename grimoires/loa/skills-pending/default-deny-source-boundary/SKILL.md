---
name: default-deny-source-boundary
description: |
  When remediating a fail-closed gate whose scan roots are hardcoded directories,
  invert it into a default-deny boundary instead of lengthening the directory
  list. Enumerate the repository's actual file universe, classify every candidate
  against the AUTHORITY (a registry, census, manifest, or allowlist) plus an
  explicitly declared set of owned roots, and fail on anything in neither class.
  Apply when implementing "no unauthorized X anywhere" for source provenance,
  licence headers, secret scanning, or dependency policy. The non-obvious part is
  that inversion CREATES a new hole — the exclusion/prune list you must add to
  skip build output — so the classifier must cross-check that it still sees every
  authority row, or the boundary silently becomes a tautology.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-1 /implement (VUX provenance remediation, review CHANGES_REQUIRED)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - provenance
  - supply-chain
  - ci-gates
  - fail-closed
  - default-deny
  - shell
  - foundry
  - negative-testing
---

## Problem

A review (or your own probe — see [`fail-closed-gate-scope-probe`](../fail-closed-gate-scope-probe/SKILL.md))
has found that a gate enforcing a repository-wide claim only inspects hardcoded
directories, so a violating file in an unlisted directory passes everything. You
now have to fix it.

The obvious fix is wrong. Adding the directories the probe used reproduces the
defect at the next directory nobody thought of, and leaves N sibling detectors
each maintaining its own drifting list.

The correct fix — enumerate everything, deny by default — has a trap that is
invisible until it costs you the whole guarantee: **to enumerate "everything" you
must exclude build output and tooling zones, and that exclusion list is a new,
unguarded escape hatch.** A prune entry that is too broad silently removes real
source from the universe, and the boundary check then passes *because it is
looking at nothing*. It reports green, exactly like the bug you were fixing.

Observed in the originating session: the walk had to prune Foundry's `out/`, and
`out/` is also where the compiler writes artifacts into directories named
`<Source>.sol/`. Get the prune or the file-type test wrong and the same `find`
either sees 117 "source files" that are mostly directories, or sees zero.

---

## Trigger Conditions

### Symptoms

- A review finding, audit note, or acceptance criterion says the gate must apply
  "anywhere" / "repository-wide", and the current implementation names directories.
- Several sibling gates (licence lint, secret scan, policy grep) each repeat their
  own `find`/`grep -r` root list.
- The project has an authority artifact — registry JSON, census, SBOM, lockfile,
  manifest — that already says exactly what is authorized.
- A future sprint is expected to add source in a directory that does not exist yet.

### Code shapes that trigger this

```bash
present="$(find vendor -type f)"                       # scope = one directory
find vendor src test script -name 'Forbidden.sol'      # scope = four directories
grep -rn 'pattern' --include='*.sol' src test script   # scope = four directories
scan_files="$(git ls-files)"                           # scope = the INDEX, not the tree
```

### Context

| Context | Value |
|---------|-------|
| Technology | POSIX shell + `find`/`jq`/`git`; any compiled-artifact toolchain (Foundry, Hardhat, Bazel, cargo) |
| Timing | Remediation pass after a review returns CHANGES_REQUIRED on gate scope |
| Precondition | An authority artifact enumerating what IS authorized |

---

## Root Cause

A directory list answers "where should I look?" — a question the attacker (or the
careless commit) also gets to answer. An authority-derived classification answers
"is this file authorized?", which nobody outside the authority gets to answer.

Inverting moves the trust from *the scan roots* to *the exclusion list*. That is a
strict improvement only if the exclusion list is itself guarded, because it is now
the single place a bypass can hide.

---

## Solution

### Step 1: Define the universe as a filesystem walk, not the git index

```bash
SOURCE_UNIVERSE_PRUNE=(.git out cache build dist node_modules_BAD_EXAMPLE .claude grimoires)

source_universe() {
  local prune=() p
  for p in "${SOURCE_UNIVERSE_PRUNE[@]}"; do prune+=(-path "./$p" -o); done
  find . \( "${prune[@]}" -false \) -prune -o \( -type f -o -type l \) -name '*.sol' -print \
    | sed 's|^\./||; s|\\|/|g' | LC_ALL=C sort
}
```

Three deliberate choices:

- **Filesystem, not `git ls-files`.** Before the first commit every deliverable is
  untracked; an index-scoped walk covers none of the new work while reporting
  clean. Gitignored files are also still on disk and still compile.
- **`-type f -o -type l`.** A symlinked source file is source a compiler follows;
  `-type f` alone makes it invisible to every gate.
- **Trailing `-false`** closes the `-o`-terminated prune group so the expression
  parses.

### Step 2: Classify against the authority, not against a directory list

```bash
DECLARED_OWNED_ROOTS=(src test script)

classify_sources() {
  local -A authorized=(); local p root cls
  while IFS= read -r p; do [[ -n "$p" ]] && authorized["$p"]=1; done < <(authority_paths)
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    if [[ -n "${authorized[$p]:-}" ]]; then cls=vendored
    else
      cls=unauthorized
      for root in "${DECLARED_OWNED_ROOTS[@]}"; do
        [[ "$p" == "$root"/* ]] && { cls=owned; break; }
      done
    fi
    printf '%s\t%s\n' "$cls" "$p"
  done < <(source_universe)
}
```

`authority_paths` reads the registry/manifest — never a hand-written list. Adding a
source root is then a visible one-line edit to `DECLARED_OWNED_ROOTS` that a
reviewer sees in the diff, not a silent exemption.

### Step 3: Guard the exclusion list — the step that is easy to skip

The prune list is the new attack surface. Assert that the walk still sees the whole
authority, so a too-broad prune fails loudly instead of emptying the universe:

```bash
n_authorized="$(printf '%s\n' "$classified" | awk -F'\t' '$1 == "vendored"' | wc -l)"
expected=$(( A_COUNT + B_COUNT + C_COUNT ))     # from the authority, not a literal
if [[ "$n_authorized" != "$expected" ]]; then
  fail "walk classified $n_authorized authority rows, authority has $expected — the walk is not seeing the tree"
fi
```

Without this, `SOURCE_UNIVERSE_PRUNE=(.git out ... vendor)` — one plausible typo —
turns "zero unauthorized files" into a green tautology.

Prune **only** what is genuinely not repository source, and document each entry with
its reason. Specifically do **not** prune the conventional dependency directories
(`lib/`, `node_modules/`, `vendor/` in Go, `third_party/`): an unauthorized
dependency landing there is precisely what the boundary exists to catch.

### Step 4: Re-scope the sibling gates onto the same derived list

Publish one helper and have every other gate consume it, so a new root cannot opt
out of licence policy, secret scanning, or quarantine either:

```bash
owned_sources() { classify_sources | awk -F'\t' '$1 != "vendored" { print $2 }'; }
```

Keep authority-frozen files (byte-identical vendored upstream) **out** of
authored-source policy — their bytes are already pinned by the identity gate, and
holding them to your own licence-header rules produces unfixable false positives.

### Step 5: Prove it on the location axis

Content-axis negative tests (flip a byte, watch the hash gate fail) do not exercise
this. Add the sibling demonstration: plant a violating file **outside** the
boundary, assert the gate fails, remove it, assert green again. Two requirements
that turn a demo into evidence:

- **Assert the failure REASON, not just a non-zero exit.** A probe that breaks
  setup also exits non-zero and looks identical to a closing fence.
- **Refuse to run if the probe root already exists** — the script deletes that path
  on cleanup, and a demonstration that can destroy real work is not usable in CI.

The strongest single probe is a byte-identical **authorized** file copied to an
unauthorized location: it proves the boundary is about place, not only content.

---

## Traps

| Trap | Symptom | Remedy |
|------|---------|--------|
| Compiled-artifact layouts create decoy paths | Foundry writes `out/<Source>.sol/<Contract>.json`, so `find . -name '*.sol'` matches **directories**; count came back 117 vs 68 real files | Prune build output *and* use `-type f`/`-type l`; never rely on the extension alone |
| Prune list empties the universe | Boundary check green, count of authority rows silently 0 | Step 3 cross-check |
| `grep` omits the filename on a single-file list | Self-exclusion filters like `grep -v '^path/to/gate.sh:'` stop matching when the list narrows to one file | Pass `-H` explicitly |
| `xargs` splits on whitespace | A path containing a space becomes two arguments | `xargs -r -d '\n'` |
| Sourcing a `set -euo pipefail` library into a demo script | The demo aborts on the first intentionally-failing gate | Invoke the gate with `bash "$gate"` in a subshell; do not `source` the library into a harness that needs non-zero exits |
| Self-referencing patterns | The gate/demo file contains the literal it defends against and flags itself | Interpolate the value at write time (`printf 'X = %d days;\n' 60`) rather than widening the suppression list |

---

## Verification

### Command

```bash
# 1. The classifier agrees with the authority
bash -c 'source tools/provenance/census.sh; classify_sources' | cut -f1 | sort | uniq -c
#   63 vendored     5 vux     (0 unauthorized)

# 2. The original bypass now fails
mkdir -p ./contracts && cp <an-authorized-file> ./contracts/
bash tools/provenance/run-all.sh; echo "exit=$?"   # expect 1, was 0
rm -rf ./contracts

# 3. The location-axis demonstration closes and reopens
bash tools/provenance/demo-boundary-negative.sh; echo "exit=$?"
```

### Checklist

- [ ] Every sibling detector consumes the derived list; none retains a `find` root
- [ ] The authority-completeness cross-check exists and is itself tested (temporarily
      add a bogus prune entry and confirm the gate goes red)
- [ ] Conventional dependency directories are **not** pruned
- [ ] Each prune entry carries an inline reason
- [ ] Declared owned roots were **not** expanded to accommodate the probe location
- [ ] The location-axis negative test asserts reasons, refuses to run over existing
      paths, and proves the tree inventory is byte-identical afterwards

---

## Anti-Patterns

### Don't: add the probe's directory to the list

`contracts/` was where the reviewer put the probe, not a request to authorize
`contracts/`. Expanding the declared roots to make the finding go away converts a
provenance fix into a provenance expansion — the opposite of the criterion.

### Don't: prune generously "to keep the scan fast"

Every prune entry is a permanent exemption. The walk over a few thousand files
costs milliseconds; a wrong prune costs the guarantee.

### Don't: treat "make the selection deterministic" as the whole fix

When a check samples one item from a set (`find … | head -1`), determinism removes
the flakiness but keeps the sampling. If asserting over the entire set is free —
`jq` accepts many files in one invocation — assert the set and delete the class of
bug instead.

### Don't: ship the inversion without the location-axis test

The suite was green before the remediation too. Only a demonstration that fails
with the boundary removed distinguishes a closed fence from an untested one.

---

## Related Resources

- Review-side counterpart: [`fail-closed-gate-scope-probe`](../fail-closed-gate-scope-probe/SKILL.md)
  — how the gap is *found*; this skill is how it is *closed*.
- CWE-1053: Missing/incomplete verification of provenance.

## Related Memory

### NOTES.md References

- `## Technical Debt` → "Provenance-gate scoping … RESOLVED 2026-08-11" — records the
  standing invariant that `VUX_SOURCE_ROOTS` additions and `SOURCE_UNIVERSE_PRUNE`
  additions are provenance changes, not implementation details.
- `## Decision Log` (2026-08-11) — inversion-over-extension rationale; source
  authority deliberately not expanded; reason-asserting negative demonstrations.

### Related Skills

- `fail-closed-gate-scope-probe` (reviewing-code) — detection
- `independent-constant-reproduction` (reviewing-code) — verifying that a gate's
  constant is reproduced rather than restated

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-08-11 | Extracted from the VUX sprint-1 provenance remediation: HIGH review finding closed by repository-wide default-deny classification; 6-probe location-axis demonstration promoted to CI |
