# Sprint 8 — subject manifest

**Branch:** `sprint-8` · **Baseline:** `6395cabb4deee5bae50ac79c8094053484261819` · **Commits ahead:** `0`

**Revision:** post-bounded-remediation (H-1, M-1, M-2, M-3), 2026-08-19. The
pre-remediation identity is preserved in §"Pre-remediation identity" below, so the reviewer
can verify the delta rather than take the new numbers on trust.

**Derived from git** — `git add -An --dry-run` for new paths plus `git status --porcelain`
for modified tracked paths — not from expectation, and partitioned by path prefix so the
three groups are exhaustive and disjoint by construction.

**Fingerprint method:** `sha256` over path-sorted `<sha256>  <path>` lines joined with `\n`,
no trailing newline. Verified before use by reproducing the recorded Sprint-6 Group B
fingerprint (`1e6515cc…67a2c`) exactly.

**Excluded** as pre-existing State-Zone churn not authored by this node: `.beads/`, `.run/`,
`grimoires/loa/analytics/`, `ledger.json.bak`, `ledger.json.lock`. This file is excluded from
its own groups, since a manifest cannot contain its own digest.

**Dependencies are in no group.** The two npm trees are reproduced from the committed
lockfiles and the Python closure from `tools/static-analysis/requirements.txt`; all three are
gitignored, and all three are hash-verified at install time.

## Group A — implementation subject (16 files)

fingerprint: 407d0babaf2ac283e36e71f6bb27a5415c4a178ae3fb5376a902880e52855764

d98677492fd5fe06…  .github/workflows/provenance.yml
0e7530cd81099e57…  .gitignore
40abb254306bd77a…  THIRD_PARTY_NOTICES.md
72e6cdfa786bdbe8…  test/e2e/GoalValidation.t.sol
1e0a6f43624d91bc…  tools/coverage/verify-coverage.sh
1f52b35c06c969b4…  tools/offchain/licence-census.mjs
9bdd517e31373c5e…  tools/provenance/census.sh
c58b4b72a9e2d0d0…  tools/provenance/final-secret-sweep.sh
ccaa00eaebba8777…  tools/provenance/run-all.sh
13e06766e919bd9d…  tools/provenance/verify-static-analysis.sh
83ddd3ef21a480ea…  tools/static-analysis/compare-baseline.py
ff44ce18832a5547…  tools/static-analysis/requirements.txt
2b45af0e6359f15f…  tools/static-analysis/slither.config.json
d5ad0067d0a25e43…  tools/static-analysis/triage-baseline.json
94e58d5d157b1ee7…  tools/traceability/build-matrix.mjs
b0e4a2e3d9fd8a96…  tools/traceability/verify-traceability.sh

## Group B — activated authority (2 files)

fingerprint: 1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437

d4f9f36ebaa37010…  docs/authority/vux-v1-source-registry-static-analysis-refreeze-2026-08.json
7769b4e392501636…  docs/authority/vux-v1-static-analysis-provenance-refreeze-2026-08.md

**Group B is byte-identical to its pre-remediation value.** No accepted-authority byte
changed in remediation; the fingerprint is unchanged rather than recomputed to match.

## Group C — lifecycle evidence (16 files)

fingerprint: 0ffd9b1d7fbcc122edbc92e1b0b7ac435cf5972e7192bbaa912a443921029e72

0d781eb78cc27ac0…  grimoires/loa/NOTES.md
06dd09c37337934b…  grimoires/loa/a2a/index.md
61b3bc994b2393b2…  grimoires/loa/a2a/sprint-8/cycle-closeout-prep.md
d1fe1c868c7c5c25…  grimoires/loa/a2a/sprint-8/deployment-runbook.md
0d733a80a0831db4…  grimoires/loa/a2a/sprint-8/e2e-goal-validation.md
7d5e84745856ac57…  grimoires/loa/a2a/sprint-8/fb-11-analysis.md
47060440755f529c…  grimoires/loa/a2a/sprint-8/fb-17-18-analysis.md
7fef63b1740ab49e…  grimoires/loa/a2a/sprint-8/launch-criteria-sweep.md
68c6db2edc83348e…  grimoires/loa/a2a/sprint-8/offchain-licence-census.json
f6395be785545a9b…  grimoires/loa/a2a/sprint-8/reviewer.md
994e3e01afbc9963…  grimoires/loa/a2a/sprint-8/sprint-8-scope.md
f42ffc9b4f3878f5…  grimoires/loa/a2a/sprint-8/static-analysis-licence-census.json
dc9187198d9784a6…  grimoires/loa/a2a/sprint-8/traceability-matrix.md
9d016cc1880847b4…  grimoires/loa/a2a/sprint-8/traceability.json
fa298d444bbce8d3…  grimoires/loa/a2a/sprint-8/trust-inventory.md
e1fe420edbf1da7a…  grimoires/loa/a2a/trajectory/implement-sprint-8-2026-08-19.jsonl

`grimoires/loa/a2a/sprint-8/engineer-feedback.md` is **deliberately absent from every group**.
It is the review node's own output and the historical record of the findings this node
remediates; including it in the implementation subject would let a later node rewrite it under
cover of a fingerprint update. It was not modified.

## Combined subject (34 files)

fingerprint: f71d5486a09d5fbd8ed4e6b2ffc4b2ed6e062c29cb63c3b1b14b72326dee564b

## Pre-remediation identity, for delta verification

Independently re-derived at the start of the remediation node before anything was changed:

| Group | Pre-remediation | Post-remediation |
|---|---|---|
| A (16 files) | `7410273de4f81eb63d1af5b0723dd7d000637008290c019e27377f67c84de72c` | `407d0babaf2ac283e36e71f6bb27a5415c4a178ae3fb5376a902880e52855764` |
| B (2 files) | `1016fe2554237f78b091212dbe44c26a0f7e59f220a427790a5a2ff2ec254437` | **unchanged** |
| C | `d438e6835bdaba8493ce3d875bbe4ccece5d99fe95b90471d58f79c16bfdea97` (15 files, as first recorded) → `6d5af1a94912a23b37ab3067250a227b4bc01d1ea74f6c9b28eda409691127bd` (15 files, after the implementation retrospective's NOTES churn) | `0ffd9b1d7fbcc122edbc92e1b0b7ac435cf5972e7192bbaa912a443921029e72` (16 files) |
| Combined | `11d3dbd5e8cd803c58ff07ef494e409ef4802569149519bdac505dc6855d9078` (33) → `c29c9fc63b11e02419ed7396b03ac41bf57925dc4fb85c46f34e9137172b2d3e` (33) | `f71d5486a09d5fbd8ed4e6b2ffc4b2ed6e062c29cb63c3b1b14b72326dee564b` (34) |

**Group C moved twice, for two different reasons, and the two must not be confused.** The
first move (`d438e683…` → `6d5af1a9…`) is **not** remediation: it is the implementation
retrospective appending learning state to `NOTES.md`, which happened after the manifest was
first written and before the review node ran. The reviewer independently confirmed `NOTES.md`
at `6e254c9a…` on entry and re-confirmed it unchanged on exit, so that drift is fully
accounted for. Every one of the other fourteen Group C files, and all sixteen Group A and both
Group B files, reproduced their recorded digests exactly at the start of remediation.

**Files changed by the remediation node — nine, all in Groups A and C:**

| File | Group | Finding |
|---|---|---|
| `tools/traceability/build-matrix.mjs` | A | H-1, M-1 — seven citations repointed |
| `tools/traceability/verify-traceability.sh` | A | M-2 — containment assertion added |
| `grimoires/loa/a2a/sprint-8/fb-11-analysis.md` | C | H-1 — **new file**, the missing evidence |
| `grimoires/loa/a2a/sprint-8/traceability.json` | C | regenerated by the gate |
| `grimoires/loa/a2a/sprint-8/traceability-matrix.md` | C | regenerated by the gate |
| `grimoires/loa/a2a/sprint-8/e2e-goal-validation.md` | C | M-3 — G-1 fork modality restored |
| `grimoires/loa/a2a/sprint-8/launch-criteria-sweep.md` | C | M-1 — Row 4 restatement corrected |
| `grimoires/loa/a2a/sprint-8/reviewer.md` | C | M-1, M-2, M-3 — AC-2/AC-7 corrected; remediation record added |
| `grimoires/loa/NOTES.md` | C | lifecycle — status + two decision-log entries |

Nothing under `src/`, `test/`, `docs/authority/`, `grimoires/loa/prd.md`,
`grimoires/loa/sdd.md`, or `grimoires/loa/sprint.md` changed: `git diff 6395cabb` over those
paths is empty, and `git status --porcelain` reports no modification to any of them.

**Negative-probe restoration.** The three M-2 probes temporarily mutated
`build-matrix.mjs`, which caused the gate to regenerate `traceability.json` and
`traceability-matrix.md` in place. All three were restored and re-verified byte-for-byte
against their pre-probe digests (`94e58d5d…`, `9d016cc1…`, `dc918719…`) — the values recorded
in Groups A and C above are those same post-restore digests.

## Listed but deliberately NOT fingerprinted

Appended by Loa hooks on **every tool call**, so a fingerprint over them is stale the instant
it is written and a reviewer re-deriving it would always mismatch. A fingerprint that cannot
be reproduced is worse than none: it reads as tamper evidence while carrying no information.
They are recorded here so the change set stays exhaustive.

- `grimoires/loa/a2a/trajectory/karpathy-2026-08-19.jsonl`
- `grimoires/loa/a2a/trajectory/zone-guard-2026-08-19.jsonl`
- `grimoires/loa/a2a/trajectory/karpathy-2026-08-20.jsonl`
- `grimoires/loa/a2a/trajectory/zone-guard-2026-08-20.jsonl`

Expected learning-state churn from the implementation retrospective, outside the product
subject and outside this remediation's scope (the five pending skills remain
operator-approved but unpromoted behind the State-Zone execution fence):

- `grimoires/loa/a2a/trajectory/continuous-learning-2026-08-19.jsonl`
- `grimoires/loa/skills-pending/`

## How to re-derive

```bash
# for each path in a group, in the order listed:
sha256sum <path>
# then, over "<sha256>  <path>" lines joined by \n with no trailing newline:
printf '%s' "$body" | sha256sum
```
