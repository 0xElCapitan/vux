---
name: gate-gap-reachability-triage
description: |
  When a review hands an audit a list of detector blind spots ("the glob is
  case-sensitive", "find doesn't follow symlinks", "the pin asserts a tag not a
  commit"), classify each by testing whether the PROTECTED CONSUMER can actually
  reach the gap — not by inspecting the detector alone. A detector and the tool
  it protects frequently share the same blind spot, in which case the gap has no
  exploitable consequence and is informational; where the blind spots are
  asymmetric, the gap is real. Apply during security audit, severity triage of
  carried-forward review findings, or whenever deciding whether a known gap
  blocks progression. The non-obvious part: the detector's blind spot is the
  wrong thing to measure, and measuring it instead of reachability inflates
  informational findings into blockers and produces perfection loops.
loa-agent: auditing-security
extracted-from: cycle-002 sprint-1 /audit-sprint (VUX provenance foundation, N-1..N-5 triage)
extraction-date: 2026-08-11
version: 1.0.0
tags:
  - security-audit
  - severity-triage
  - ci-gates
  - provenance
  - supply-chain
  - reachability
  - negative-testing
  - foundry
  - solidity
---

## Problem

A review approves an implementation but carries forward a list of non-blocking
detector gaps. The audit node must classify each one: *deferred hardening* or
*blocker*. The tempting method — read the detector, confirm the gap is real,
assign severity by how alarming it sounds — is wrong in both directions:

- it **inflates** gaps whose consequence cannot occur (the audit blocks on a
  filesystem curiosity, producing another implement→review→audit loop for no
  security gain);
- it **deflates** gaps that sound identical but are genuinely reachable, because
  the two are indistinguishable from the detector's source alone.

Observed in the originating session: two findings that read almost identically —
"the source-universe walk misses `Foo.SOL`" and "the source-universe walk prunes
`grimoires/`" — were both confirmed as real detector blind spots by direct probe,
and then diverged completely once reachability was tested. One had no path into
the build at all; the other compiled and emitted an artifact.

The detector gap is a necessary condition for a vulnerability, never a sufficient
one.

---

## Trigger Conditions

### Symptoms

- A review verdict is APPROVED but ships N non-blocking findings for the audit to
  disposition.
- A finding is phrased as a property of the *detector* ("case-sensitive glob",
  "`find` does not descend symlinks", "scan excludes directory X", "asserts the
  tag not the commit") rather than as a demonstrated consequence.
- A finding's write-up ends at "…could therefore be introduced without the gate
  failing" with no evidence that the artifact would ever be consumed.
- Pressure to either rubber-stamp the list or re-open every item.

### Context

| Context | Value |
|---------|-------|
| Node | `/audit-sprint`, `/audit`, security review, release gate |
| Technology Stack | any detector/consumer pair — provenance gates + compiler, secret scanners + deploy tooling, licence scanners + packager, linters + runtime |
| Timing | after review approval, before operator acceptance |
| Prerequisites | ability to run the real consumer in an isolated scratch project |

---

## Root Cause

A gate is a *proxy* for a property the real consumer enforces or violates.
Detector and consumer are usually built on the same primitives — the same
extension matching, the same path resolution, the same case sensitivity — so
their blind spots are **correlated, not independent**. Whenever they coincide,
the gap is unreachable and therefore not a vulnerability.

Reading the detector measures the proxy. Only running the consumer measures the
property.

---

## Solution

Build a throwaway project that exercises the **consumer**, not the repository
under audit. Two phases, because reachability has two independent modes.

### Step 1: Probe the detector (establish the gap is real, with an A/B control)

Plant the artifact, run the gate, then rename to the known-caught form. Without
the control, a green gate is ambiguous — it may be misconfigured rather than
blind.

```bash
mkdir -p contracts && printf '%s\n' "$PROBE" > contracts/Probe.SOL
bash tools/provenance/verify-census.sh >/dev/null 2>&1 && echo "GREEN -> blind"

mv contracts/Probe.SOL contracts/Probe.sol          # identical bytes, caught form
bash tools/provenance/verify-census.sh >/dev/null 2>&1 || echo "RED -> fails closed"
```

### Step 2: Probe the consumer in an isolated scratch project

Never mutate the audited tree for this. Reachability has two modes and they give
different answers, so test both:

```bash
SP="$SCRATCH/casetest"; mkdir -p "$SP/src" "$SP/outside"; cd "$SP"
printf '[profile.default]\nsrc="src"\nout="out"\nlibs=[]\nsolc="0.8.28"\n' > foundry.toml

printf '...contract UpperOnly {}\n'   > src/UpperOnly.SOL          # mode A: auto-discovery
printf '...contract OutsideOnly {}\n' > outside/OutsideOnly.sol    # mode A: out-of-root

forge build --force        # -> "Nothing to compile": neither is auto-discovered

# mode B: explicit import from a normal in-root file
printf 'import "./UpperOnly.SOL";\nimport "../outside/OutsideOnly.sol";\n...' > src/Entry.sol
forge build --force
```

### Step 3: Read the answer off the artifacts, not the exit code

`forge build` exited **0** in both runs. The discriminating evidence is which
artifacts were emitted and what the resolver said:

| Probe | Auto-discovery | Explicit import | Verdict |
|---|---|---|---|
| `UpperOnly.SOL` | "Nothing to compile" | **"Unable to resolve imports"**, no artifact | blind spot **symmetric** → informational |
| `outside/OutsideOnly.sol` | "Nothing to compile" | **`out/OutsideOnly.sol/` emitted** | blind spot **asymmetric** → real mechanism |

A build that "succeeds" while silently dropping an unresolvable import is the
trap here: only the emitted-artifact list and the resolver diagnostic separate
the two cases.

### Step 4: For pin/version findings, reproduce under a deliberately different version

The same move applies to "the pin is asserted loosely". Instead of arguing about
the assertion, prove whether the pinned component determines the output:

> The accepted `POOL_INIT_CODE_HASH` was reproduced byte-identically under
> **forge 1.5.0** while the pin is **v1.0.0**. The constant is solc-determined,
> not Foundry-determined, so a repointed Foundry tag cannot silently change the
> bytecode without the init-code-hash gate failing. Severity: LOW.

Reproducing under a *different* version is stronger evidence than reproducing
under the pinned one — it demonstrates the dimension the finding worries about is
not output-determining.

### Step 5: Classify, and say which way each went

| Class | Criterion | Disposition |
|---|---|---|
| Symmetric blind spot | consumer cannot reach the artifact | informational; recommend **closing** the finding, not carrying it |
| Asymmetric, requires a visible edit | reachable only via an in-diff line in a reviewed root | LOW; deferred hardening with a named trigger |
| Asymmetric, silently reachable | consumer reaches it with no reviewable signal | blocker |
| Not output-determining | the pinned/loose component cannot alter the artifact | LOW; hardening |

Record refutations explicitly. "N-2 is refuted as a security defect by direct
experiment" is a more useful audit output than silently dropping it, and it stops
the finding from being re-raised every cycle.

---

## Verification

### Command

```bash
forge build --force 2>&1 | grep -E 'Nothing to compile|Unable to resolve'
find out -maxdepth 1 -mindepth 1 -type d
```

### Expected Output

```
Nothing to compile                    # mode A: not auto-discovered
Unable to resolve imports: "./X.SOL"  # mode B: not reachable by import either
out/Entry.sol                         # only the in-root file emitted
```

### Checklist

- [ ] Detector gap confirmed by probe **with an A/B control** (caught form goes red)
- [ ] Consumer tested in an isolated project, never in the audited tree
- [ ] BOTH reachability modes tested (auto-discovery and explicit reference)
- [ ] Verdict read from emitted artifacts + resolver diagnostics, not exit code
- [ ] Audited tree proven byte-identical after probing
- [ ] Each finding assigned a class, refutations stated explicitly

---

## Anti-Patterns

### Don't: infer severity from the detector's source

```bash
# BAD - proves the gap exists, says nothing about whether it matters
grep -n "name '\*.sol'" census.sh && echo "case-sensitive -> BYPASS, blocker"
```

Every gap looks like a bypass from inside the detector. The severity lives in the
consumer.

### Don't: trust a zero exit code as "the consumer accepted it"

`forge build` returns 0 while dropping an unresolvable import whose symbol is
unused. Had the probe *used* the imported symbol, compilation would have failed
loudly — so a passing build is not evidence of successful resolution. Check the
artifact list.

### Don't: probe reachability inside the audited tree

Writing probe sources into `src/`, `test/`, or `script/` mutates the audit
subject and risks residue on interruption. Use an external scratch project; keep
in-tree probes to the detector step, with a verified inventory hash before/after.

### Don't: elevate a finding merely because the reviewer recorded it

Carrying a reviewer's severity forward unexamined is the mechanism by which
audits become perfection loops. The audit's job is independent classification —
including downgrade and refutation.

---

## Related Memory

### NOTES.md References

- `## Learnings`: "[Review technique — gate scoping]" — the detection side; this
  skill is the triage side that runs after it.
- `## Technical Debt`: "Foundry artifact layout shadows source extensions" —
  same family of extension-vs-file-type confusion.

### Related Skills

- `fail-closed-gate-scope-probe`: **finds** location-axis gaps. This skill
  classifies what that probe surfaces. Use them in sequence: probe → triage.
- `default-deny-source-boundary`: the implementation-side fix once a gap is
  classified as real.
- `independent-constant-reproduction`: supplies the reproduction discipline that
  Step 4 depends on.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction |

---

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: auditing-security
  phase: /audit-sprint
  session: cycle-002-sprint-1-audit
```
