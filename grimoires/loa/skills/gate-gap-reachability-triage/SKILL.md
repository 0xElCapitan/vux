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
version: 1.1.0
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
and *appeared* to diverge completely once reachability was tested. One looked
like it had no path into the build at all; the other compiled and emitted an
artifact.

**Correction (2026-08-11, sprint-2 `/audit-sprint`):** that first verdict was
wrong and is retracted. `Foo.SOL` **is** build-reachable and executes — the
corrected worked example is in Step 3. The triage method held; the evidence
reading did not. The example is kept rather than replaced because its failure
mode is the instructive part: the signal that produced the wrong answer was a
*resolver diagnostic*, which is detector-side evidence, so reading it as
consumer evidence repeats the exact category error this skill exists to prevent.
Full treatment: [[resolver-diagnostic-is-not-reachability]].

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

`forge build` exited **0** in both runs, so the exit code discriminates nothing.
The evidence is what the build actually *admitted*:

| Probe | Auto-discovery | Explicit import | Verdict |
|---|---|---|---|
| `UpperOnly.SOL` | "Nothing to compile" | "Unable to resolve imports" **and `Compiler run successful!`**; source in `metadata.sources`; deployed instance executes it | blind spot **asymmetric** → real mechanism |
| `outside/OutsideOnly.sol` | "Nothing to compile" | **`out/OutsideOnly.sol/` emitted** | blind spot **asymmetric** → real mechanism |

**Corrected 2026-08-11 (sprint-2 `/audit-sprint`).** Row 1 originally read
*"«Unable to resolve imports», no artifact → blind spot symmetric →
informational"*. That verdict was wrong and is retracted. Foundry emits
`Unable to resolve imports` from its **pre-resolution source-graph walker** and
then compiles the file anyway, because solc resolves the import through its own
filesystem callback: the source appears in the importing artifact's
`metadata.sources`, its creation code is embedded in the importing contract, and
a deployed instance runs it. The absent `out/UpperOnly.SOL/` directory is **not**
corroboration — artifact emission and graph discovery are the same pass, so
consulting it double-counts a single signal. Platform-independent: the import
string matches the filename byte-for-byte, so it resolves on case-sensitive CI
too; case-insensitivity is not required.

The generalisation that survives: a resolver diagnostic is a statement about the
*tool's discovery pass*, never about what compiled. It is detector-side evidence,
and admitting it as consumer evidence is the same category error the rest of this
skill guards against. Read `metadata.sources`, then **execute the code**. Full
treatment: [[resolver-diagnostic-is-not-reachability]].

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

Record refutations explicitly — and record the *evidence* that produced them, not
only the verdict. The originating session wrote "N-2 is refuted as a security
defect by direct experiment"; the sprint-2 re-audit proved that refutation
**wrong** and retracted it (the mixed-case `.SOL` source is build-reachable and
executes — see Step 3, and [[resolver-diagnostic-is-not-reachability]]). The
practice survives its own worked example, and is vindicated by it: an explicitly
recorded refutation carries the experiment that would falsify it, so it can be
re-run and overturned. A silently dropped finding cannot. State the class, the
evidence, and the experiment that would overturn it.

---

## Verification

### Command

```bash
forge build --force 2>&1 | grep -E 'Nothing to compile|Unable to resolve|Compiler run successful'
find out -maxdepth 1 -mindepth 1 -type d
jq -r '.metadata.sources | keys[]' out/Entry.sol/Entry.json   # what solc ADMITTED
```

### Expected Output

```
Nothing to compile                    # mode A: not auto-discovered
Unable to resolve imports: "./X.SOL"  # graph-walker warning — NOT a verdict
Compiler run successful!              # solc resolved it anyway, same run
out/Entry.sol                         # only Entry emitted — absence != exclusion
src/Entry.sol
src/X.SOL                             # admitted: the import DID resolve
```

The last three lines are the corrected reading. The warning and the success line
appear **together**, and a missing `out/X.SOL/` directory is not evidence of
exclusion — emission and discovery are the same pass. `metadata.sources` is what
settles admission; follow it by deploying the importing contract and calling
through to the imported symbol.

### Checklist

- [ ] Detector gap confirmed by probe **with an A/B control** (caught form goes red)
- [ ] Consumer tested in an isolated project, never in the audited tree
- [ ] BOTH reachability modes tested (auto-discovery and explicit reference)
- [ ] Verdict read from `metadata.sources` **and execution** — never from the exit
      code, never from the artifact directory listing alone, and never from a
      resolver diagnostic
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

### Don't: trust a zero exit code — or a resolver warning — as the verdict

`forge build` returns 0 whether or not a given source was admitted, so the exit
code is uninformative in both directions. The warning printed beside it is no
better: `Unable to resolve imports` comes from the pre-resolution graph walker
and coexists with `Compiler run successful!` in the same run, because solc
resolves the import through its own filesystem callback. The artifact directory
listing does not settle it either — emission and discovery are the same pass, so
a missing `out/X/` re-states the walker's blindness rather than corroborating it.
Confirm admission from `metadata.sources`, then execute the deployed contract.

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
- `## Learnings`: "**[CORRECTION 2026-08-11 at `/audit-sprint sprint-2`]**" — the
  authoritative retraction of this skill's N-2 worked example, with the corrected
  execution evidence (`test_UppercaseSolIsBuildReachableAndExecutable`).
- `## Technical Debt`: "Foundry artifact layout shadows source extensions" —
  same family of extension-vs-file-type confusion.

### Related Skills

- `fail-closed-gate-scope-probe`: **finds** location-axis gaps. This skill
  classifies what that probe surfaces. Use them in sequence: probe → triage.
- `default-deny-source-boundary`: the implementation-side fix once a gap is
  classified as real.
- `independent-constant-reproduction`: supplies the reproduction discipline that
  Step 4 depends on.
- `resolver-diagnostic-is-not-reachability`: **corrects this skill's `.SOL`
  worked example.** Same triage method, corrected evidence rule — a resolver
  diagnostic describes the tool's discovery pass, not what compiled. Read it
  before applying Step 3 to any import-resolution finding.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-11 | Initial extraction |
| 1.1.0 | 2026-08-12 | Retract the `.SOL` worked example's verdict (N-2 refutation was wrong: the source is build-reachable and executes). Corrected Problem framing, Step 3 evidence table, Verification command/output, checklist and the exit-code anti-pattern; added forward reference to `resolver-diagnostic-is-not-reachability`. Triage method unchanged. |

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
