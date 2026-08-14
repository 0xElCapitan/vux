---
name: fail-closed-depends-on-the-consumption-form
description: |
  When auditing a shell security gate, never accept "it runs under `set -euo
  pipefail`, so it fails closed" — from the implementation, from a prior review,
  or from your own reading. Whether a producer's failure reaches the shell is a
  property of the SYNTACTIC FORM the consumer uses, not of the strict-mode flags.
  Command substitution in an assignment and a pipe into `while` both propagate;
  process substitution (`while read … < <(producer)`) is invisible to `set -e`
  AND to `pipefail`, so the consumer completes normally on PARTIAL output with
  exit 0 — fail-open wearing fail-closed's clothes. Settle it with a four-form
  differential harness (60 seconds) before writing the finding, because the same
  library often mixes forms and is therefore fail-closed in one gate and fail-open
  in another. Apply when auditing provenance/CI/policy gates written in bash,
  especially when a prior artifact characterises a failure path as "fail-closed
  but opaque" — that phrasing usually means the author read the flags, not the form.
loa-agent: auditing-security
extracted-from: cycle-002 m1-l3-l4-provenance-hardening /audit-sprint (re-characterisation of review finding R-3; drove new finding A-1)
extraction-date: 2026-08-13
version: 1.0.0
tags:
  - security-audit
  - shell
  - bash
  - fail-closed
  - error-propagation
  - ci-gates
  - provenance
  - set-e
  - pipefail
  - process-substitution
---

## Problem

A security gate is written in bash, opens with `set -euo pipefail`, and derives
its verdict from a producer function (a file walk, a `jq` over artifacts, a
registry query). A prior review reaches the reasonable conclusion:

> A malformed artifact makes the `jq` batch exit non-zero; under `set -euo
> pipefail` the gate aborts with no diagnostic. **Fail-closed but opaque.**

The strict-mode flags are real and the reasoning looks sound. It is still only
half true, because `set -e` and `pipefail` do not see every way a shell consumes
a producer — and a *fail-open* path hidden under a fail-closed characterisation
is strictly worse than a known gap, since nobody goes looking for it.

The dangerous shape is a producer that emits **partial output and then fails**.
A gate that aborts is safe. A gate that silently proceeds on a truncated
universe reports **green** on evidence it never fully read.

## The discriminator

Run this before writing the finding. It takes under a minute and is decisive.

```bash
run() { bash -c "set -euo pipefail
producer() { echo partial; return 9; }
$1
echo REACHED_END"; echo "  -> exit=$?"; }

run 'v="$(producer)"'                                       # A assignment
run 'while IFS= read -r x; do :; done < <(producer)'        # B process substitution
run 'producer | while IFS= read -r x; do :; done'           # C pipe into while
run 'while IFS= read -r x; do :; done < <(producer|sort -u)' # D procsub wrapping a pipeline
```

Measured result (bash 5.x, `set -euo pipefail` in every case):

| form | consumed how | REACHED_END | exit | verdict |
|---|---|---|---|---|
| **A** | `v="$(producer)"` | no | 9 | **fail-closed** |
| **B** | `done < <(producer)` | **yes** | **0** | **fail-open** |
| **C** | `producer \| while …` | no | 9 | **fail-closed** |
| **D** | `done < <(producer \| sort -u)` | **yes** | **0** | **fail-open** |

The non-obvious part is **which pair splits**. The instinct is "pipes are the
risky one, `pipefail` fixes it" — but C is safe *because* of `pipefail`, and B/D
fail open regardless of it. `pipefail` governs pipelines; a process substitution
is not part of the consuming command's pipeline at all, so its exit status has
nowhere to land. D also shows the trap survives being wrapped: a producer whose
last stage is a successful `sort -u` looks doubly safe and is not.

## Method

1. **Locate the consumption form, not the flags.** Grep the gate and its shared
   library for `< <(`, `$(`, and `| while`. The `set -` line tells you nothing on
   its own.
2. **Run the four-form harness** above. Do not reason it out — bash's behaviour
   here is counter-intuitive enough that the measurement is the argument, and it
   is what lets you correct a prior artifact with confidence rather than hedge.
3. **Check for MIXED forms in one library.** This is the highest-yield step. A
   shared library typically has one entry point read via assignment (fail-closed)
   and another read via process substitution (fail-open). The gate that added the
   guarantee gets form A; the gates that merely *consume* the same derived value
   inherit form B and nobody notices.
4. **Enumerate every consumer of the derived value.** For each, record which form
   it uses and whether it carries its own evidence check. A guarantee documented
   for one gate is routinely stated in the README as a property of the *system*.
5. **Find the truncation source.** Fail-open only matters if the producer can
   emit partial output. `xargs … jq` is the classic: `jq` given many files aborts
   the whole batch at the first malformed one and **silently drops every later
   file in that batch** — reproduce it (`echo 'NOT JSON' > 2.json` between two
   valid files; the third file's keys vanish, `rc=5`). Combined with `2>/dev/null`
   the diagnostic is gone too.
6. **Then grade by authority.** Establish the mechanism first, severity second —
   see [`authority-not-reachability-grades-a-caller-contract-gap`]. Ask whether
   an orchestrator runs the fail-closed gate FIRST and aggregates failures into
   a non-zero exit. If it does, the overall acceptance path is still fail-closed
   and the fail-open consumers are LOW deferred hardening — but say plainly that
   the surviving gate is fail-closed *incidentally* (statement order) rather than
   *by design*, because that is what makes the fix worth doing.

## Verification

Applied at the exact-tree audit of `m1-l3-l4-provenance-hardening`:

- The review recorded R-3 as "fail-closed but opaque."
- The harness showed `verify-census.sh:87` (`compiled_default="$(compiled_sources
  out)"`, form A) genuinely fail-closed, and `classify_sources()`
  (`census.sh:328`, `done < <(source_universe)`, form D) fail-**open**.
- Consumer enumeration then produced a *new* finding (A-1): `verify-spdx.sh:69`
  and `verify-quarantine.sh:41` both consume the fail-open path and neither
  carries the zero-evidence check that only `verify-census.sh` gained — so on an
  unbuilt tree both silently revert to the very filename-keyed universe the node
  existed to close, and report green.
- Authority grading kept both at LOW: the orchestrator runs `verify-census.sh`
  first and forces `exit 1` on any gate failure, so no authoritative path can
  false-green.

Net effect: one prior finding re-characterised from fail-closed to fail-open, one
new finding surfaced, and neither promoted above LOW — the measurement changed
the *content* of the audit without inflating its severity.

## Anti-patterns

- **Reading `set -euo pipefail` and stopping.** It is necessary, not sufficient,
  and it is the single most common source of a wrong fail-closed claim.
- **Assuming `pipefail` covers process substitution.** It does not — different
  mechanism entirely.
- **Auditing only the gate that changed.** The hardening lands in one gate; the
  other consumers of the same shared derivation are where the gap lives.
- **Promoting on mechanism alone.** A real fail-open path that no acceptance path
  reaches is deferred hardening. Establish the mechanism precisely, then grade it
  honestly.
- **Trusting a README's scope.** "Gate X fails closed when …, so the half can
  never silently degrade" attributes one gate's property to the system. Check
  whether the other consumers actually have it.

## Related

- [`authority-not-reachability-grades-a-caller-contract-gap`] — the severity half:
  once you have the mechanism, grade the residual by authority, not reachability.
- [`ask-the-toolchain-not-the-filename`] — the boundary this gate was protecting.
- `.claude/rules/shell-conventions.md` — repo strict-mode conventions (empty
  arrays, arithmetic, JSON construction); this skill covers the propagation axis
  those rules do not.
