# Cycle-002 Closeout Preparation

**Node:** `/implement sprint-8`, Task 8.8
**Status:** **PREPARED, NOT EXECUTED.**

> Nothing in this document has been performed. No branch was pruned, no archive was created, no cycle was marked complete, and `/ship` was not run. Closeout executes only after Sprint-8 review, audit, operator acceptance, landing, and post-landing verification — in that order. This file is the inventory those later nodes will consume.

---

## 1. Branch inventory and batch-pruning list

The accepted branch-hygiene rule (`sprint.md`, Native Lifecycle): *"sprint branches may remain until cycle completion; administrative closeout/pruning is batched at cycle end (Sprint 8 prepares the list; `/ship`-time execution). No per-sprint pruning ceremony."*

### Local branches

| Branch | Head | Tracks | Disposition at `/ship` |
|---|---|---|---|
| `master` | `6395cabb` | `origin/master` | **KEEP** — the trunk |
| `sprint-8` | (this work) | — | **KEEP until landed**, then prune with the rest |
| `sprint-7` | `6395cabb` | — | **PRUNE** — landed; identical to `master` |
| `sprint-4` | `91c698d6` | — | **PRUNE** — landed and superseded |
| `hardening/m1-l3-l4-provenance` | `26ca4cd6` | `origin/…` | **PRUNE** — the Sprint-2-carry hardening node, landed |
| `hygiene/post-sprint-1-learning` | `79c966f6` | `origin/…` | **PRUNE** — landed |
| `preserve/operator-loa-config-2026-08-11` | `2a598a34` | — | **OPERATOR DECISION** — named `preserve/*` on purpose; do not prune without an explicit instruction |

### Remote branches (`origin`)

| Branch | Head | Disposition |
|---|---|---|
| `origin/master` | `6395cabb` | **KEEP** |
| `origin/sprint-7` | `6395cabb` | **PRUNE** after cycle acceptance |
| `origin/sprint-1` | `23263e18` | **PRUNE** after cycle acceptance |
| `origin/hardening/m1-l3-l4-provenance` | `26ca4cd6` | **PRUNE** |
| `origin/hygiene/post-sprint-1-learning` | `79c966f6` | **PRUNE** |
| `loa-upstream/main` | `76458ff2` | **KEEP** — framework upstream remote, not a cycle branch |

**Pruning precondition (binding):** every branch above marked PRUNE must first be confirmed merged into `master` — `git branch --merged master`. A branch that is not an ancestor of `master` is not administrative residue and must not be pruned as though it were. `preserve/*` is excluded from batch pruning by name.

---

## 2. Durable artifact inventory

### Authority (`docs/authority/`) — all `CURRENT_ACCEPTED`, none superseded by this cycle

| Artifact | Status |
|---|---|
| `vux-v1-licence-provenance-source-pin-freeze-2026-08.md` + base registry JSON | base FREEZE/REG |
| `vux-founder-parameter-freeze-2026-08.md` (+ strategic-treasury, adaptive-routing supersessions) | FREEZE + Δ |
| `vux-v1-canonical-specification-2026-08.md` (+ two supersessions) | SPEC + Δ |
| `vux-v1-authority-supersession-map-2026-08.md` | MAP |
| `vux-v1-oz-v3-provenance-refreeze-2026-08.md` + registry | on-chain provenance |
| `vux-v1-strategic-treasury-provenance-boundary-delta-2026-08.md` | boundary delta |
| `vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.{md,json}` | toolchain |
| `vux-v1-offchain-provenance-refreeze-2026-08.md` + registry | off-chain |
| **`vux-v1-static-analysis-provenance-refreeze-2026-08.md` + registry** | **NEW this sprint — closes the last open clause of oz-v3 §9** |
| `vux-founder-acceptance-adaptive-routing-lsg-holder-liquidity-2026-08.md` | founder acceptance |

**With Sprint 8's acceptance, refreeze §9 carries no remaining deferred provenance obligation.**

### Grimoire artifacts

| Path | Content |
|---|---|
| `grimoires/loa/prd.md` | PRD v2.1.1 |
| `grimoires/loa/sdd.md` | SDD v1.7.1 |
| `grimoires/loa/sprint.md` | Sprint Plan v1.1.1 |
| `grimoires/loa/NOTES.md` | decision log, learnings, technical debt |
| `grimoires/loa/ledger.json` | sprint ledger, cycle-002 |
| `grimoires/loa/a2a/sprint-1…8/` | per-sprint reviewer / engineer-feedback / auditor-feedback / COMPLETED |
| `grimoires/loa/a2a/trajectory/` | per-node trajectory JSONL |
| `grimoires/loa/a2a/{audits,foundry-v1.5-refreeze,m1-l3-l4-provenance-hardening}/` | out-of-band node artifacts |

### Sprint-8 evidence pack (new)

| Path |
|---|
| `grimoires/loa/a2a/sprint-8/reviewer.md` |
| `grimoires/loa/a2a/sprint-8/traceability-matrix.md` + `traceability.json` |
| `grimoires/loa/a2a/sprint-8/launch-criteria-sweep.md` |
| `grimoires/loa/a2a/sprint-8/e2e-goal-validation.md` |
| `grimoires/loa/a2a/sprint-8/trust-inventory.md` |
| `grimoires/loa/a2a/sprint-8/fb-17-18-analysis.md` |
| `grimoires/loa/a2a/sprint-8/deployment-runbook.md` |
| `grimoires/loa/a2a/sprint-8/offchain-licence-census.json` |
| `grimoires/loa/a2a/sprint-8/static-analysis-licence-census.json` |
| `grimoires/loa/a2a/sprint-8/cycle-closeout-prep.md` (this file) |
| `grimoires/loa/a2a/sprint-8/subject-manifest.md` |
| `grimoires/loa/a2a/sprint-8/sprint-8-scope.md` |

### New tooling and implementation (new this sprint)

| Path | Role |
|---|---|
| `tools/static-analysis/requirements.txt` | 49-distribution hash-pinned closure |
| `tools/static-analysis/slither.config.json` | detector/filter configuration |
| `tools/static-analysis/triage-baseline.json` | 68 findings, every one dispositioned |
| `tools/static-analysis/compare-baseline.py` | baseline differ |
| `tools/provenance/verify-static-analysis.sh` | gate 9 |
| `tools/provenance/final-secret-sweep.sh` | gate 11 (whole namespace) |
| `tools/traceability/build-matrix.mjs` + `verify-traceability.sh` | gate 10 |
| `tools/coverage/verify-coverage.sh` | gate 12 (its own CI job) |
| `tools/offchain/licence-census.mjs` | D-3 discharge |
| `test/e2e/GoalValidation.t.sol` | Task 8.E2E, 10 tests |

---

## 3. Items reserved for `/ship`-time execution

**None of these is performed here.**

1. Execute the §1 branch pruning, after confirming each PRUNE branch is merged into `master`.
2. Archive cycle-002 (`/archive-cycle`) into a dated archive directory.
3. Mark cycle-002 `archived` in `grimoires/loa/ledger.json` and open the successor cycle.
4. Tag the landed cycle head.
5. Run the post-merge pipeline via `post-merge-orchestrator.sh` (never ad-hoc commands; never a manual tag).
6. Carry the residual register (§4) into the successor cycle's opening context.

---

## 4. Accepted residual inventory carried out of cycle-002

Full detail and dispositions: `grimoires/loa/a2a/sprint-8/trust-inventory.md` §5.

| # | Residual | Class |
|---|---|---|
| R-Y1 | Canonical RH WETH external upgrade authority (**YELLOW**) | catastrophic-external, unmitigable, disclosed |
| R-Y2 | RH Chain liveness (FB-17) | liveness |
| R-Y3 | Operator Safe compromise → total Strategic loss | high, bounded, survivable |
| R-Y4 | Proprietary non-commercial dependency in the dev/CI tree (**not distributed**) | low, disclosed |
| R-Y5 | `web3` CCIP-Read SSRF in the static-analysis env (**D-S2**, unreachable) | medium, unreachable, control enforced |
| R-Y6 | slither 0.10.4 predates two solc constructs (**D-S3**, both absent from source) | low, bounded |
| R-Y7 | Stray non-WETH tokens sent to the Reserve are permanently stuck | low, accepted |
| R-Y8 | Static-analysis closure wheel-complete only on Python 3.10/3.11 | low, operational |
| R-Y9 | RH EVM / hard-fork characterization | informational, pre-launch check |
| R-Y10 | Archive-capable RPC required for exact fork reproduction | informational, operator input |
| R-Y11 | Production block-gas / initcode limit confirmation | operational, pre-launch check |
| R-Y12 | Indexer DB constraint privilege | operational |

**Open operator gates carried to production launch (not cycle blockers):** Q-3 (Safe composition) and Q-4 (legal review). Both are slotted in the runbook. Q-6 is **closed** (Sprint 7 fork evidence).

---

## 5. Launch-readiness evidence locations

| Question an operator will ask | Answer lives at |
|---|---|
| Is every invariant and failure behaviour covered? | `traceability-matrix.md` |
| Are the PRD launch criteria met? | `launch-criteria-sweep.md` |
| Does the assembled system achieve the six goals? | `e2e-goal-validation.md` |
| What must I trust? | `trust-inventory.md` |
| How do I launch, and what must I supply? | `deployment-runbook.md` |
| What third-party code is here, under what licence? | `THIRD_PARTY_NOTICES.md` + the two censuses |
| What did the scanner find, and why is each finding acceptable? | `tools/static-analysis/triage-baseline.json` |
| Can I reproduce all of this? | `bash tools/provenance/run-all.sh` and `bash tools/coverage/verify-coverage.sh` |

---

## 6. What must NOT happen before closeout

- No `/ship`.
- No cycle archive.
- No branch pruning.
- No production deployment.
- No commit on `sprint-8` during `/implement` — landing is a later operator-gated node.
