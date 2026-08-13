# Agent-to-Agent Artifact Index

Cycle **cycle-002 "VUX v1 Strategic Treasury"** — local sprint IDs equal global IDs (1:1).

| sprint | theme | implementation | review | audit | status |
|---|---|---|---|---|---|
| sprint-1 | Provenance-gated foundation & authorized vendoring | [`sprint-1/reviewer.md`](sprint-1/reviewer.md) (remediated 2026-08-11) | [`sprint-1/engineer-feedback.md`](sprint-1/engineer-feedback.md) — **APPROVED** (re-review, 8/8 AC) | [`sprint-1/auditor-sprint-feedback.md`](sprint-1/auditor-sprint-feedback.md) — **APPROVED** (0 critical / 0 high / 0 medium / 4 low) | `LANDED_VERIFIED` — operator-accepted and landed on `master` (`23263e18`) |
| sprint-2 | VUX token & Hard Reserve | [`sprint-2/reviewer.md`](sprint-2/reviewer.md) (A-1 remediated 2026-08-11) | [`sprint-2/engineer-feedback.md`](sprint-2/engineer-feedback.md) — **APPROVED** (pass 2, A-1 re-review: 0 critical / 0 high / 1 medium / 2 low) on subject `a6313a4d5a…2b772cf`; pass 1 (7/7 AC) preserved in-file | [`sprint-2/auditor-sprint-feedback.md`](sprint-2/auditor-sprint-feedback.md) — **APPROVED** (pass 2, exact-tree re-audit: 0 critical / 0 high / **1 medium: M-1 (non-blocking, binding pre-Sprint-3 condition)** / 5 low; A-1 CLOSED) on subject `a6313a4d5a…2b772cf` (entry == exit); pass 1 preserved in-file | `LANDED_VERIFIED` — operator-accepted 2026-08-12 at digest `a6313a4d5a…2b772cf` and landed on `master` (`89a92055`); committed-tree digest re-verified byte-identical to the accepted subject |
| sprint-3 | Rig: throne, settlement, VEM + invariant suite | [`sprint-3/reviewer.md`](sprint-3/reviewer.md) (8/8 AC, validator exit 0 on the scoped slice) | [`sprint-3/engineer-feedback.md`](sprint-3/engineer-feedback.md) — **APPROVED** (8/8 AC re-derived on the exact tree: 0 critical / 0 high / 0 medium / 6 low + 3 informational) on subject `src/Rig.sol` `f0377bf9…8ac2b1e` / `foundry.toml` `74d5be36…049e6d387`; `via_ir` compiler-mode change dispositioned in §8 | [`sprint-3/auditor-sprint-feedback.md`](sprint-3/auditor-sprint-feedback.md) — **APPROVED** (exact-tree audit: 0 critical / 0 high / 0 medium / 8 low) on subject `src/Rig.sol` `f0377bf9…8ac2b1e` (entry == exit); 8 LOW findings carried forward as non-blocking (`evm_version`/`decayFloor`/`treasury!=reserve` deferred to Sprint 7/8, remainder documentation) | `OPERATOR_ACCEPTED_READY_TO_LAND` — operator accepted 2026-08-13; `COMPLETED` marker written (`sprint-3/COMPLETED`); uncommitted on branch `sprint-3`, baseline `bc5dedc2`; `sprint.md` unchanged since review approval (`bcaebd18…abaa5557`); landing (branch → `master`) deferred to the dedicated landing node |
| sprint-4 | Strategic Treasury I: custody, classification, authority | — | — | — | planned |
| sprint-5 | Strategic Treasury II: POL, callbacks, VYRF | — | — | — | planned |
| sprint-6 | Truth surfaces: Lens, indexer, truthful UX | — | — | — | planned |
| sprint-7 | Genesis: non-griefable launch & adversarial rehearsal | — | — | — | planned |
| sprint-8 | Launch readiness: hardening, traceability, E2E | — | — | — | planned |

## sprint-1 artifacts

| file | role |
|---|---|
| `sprint-1/reviewer.md` | implementation report + AC verification table — refreshed at the remediation node (finding dispositions, negative-test evidence, 8/8 ACs) |
| `sprint-1/sprint-1-scope.md` | byte-exact Sprint-1 slice of `sprint.md`, the AC validator's scoped input (`0133a5b8…799aa`) — the **pre-approval** slice; `sprint.md`'s hash changed when the Sprint-1 checkboxes were ticked on approval, criteria text unchanged |
| `sprint-1/engineer-feedback.md` | review verdict — **APPROVED** at the second pass (C-1 + all 4 MEDIUM closed, verified by reviewer-controlled probes); 5 non-blocking hardening findings N-1…N-5 carried to audit as disclosed context |

## sprint-2 artifacts

| file | role |
|---|---|
| `sprint-2/reviewer.md` | implementation report + AC verification table (7/7 ACs, validator exit 0), with the appended **A-1 remediation pass** section (root cause, exact universe fix, 4 mixed-case negative probes, compiler-evidence build-reachability control, full regression, subject digests) |
| `sprint-2/sprint-2-scope.md` | byte-exact Sprint-2 slice of `sprint.md`, the AC validator's scoped input (`c5060bff…4c8d508`) |
| `sprint-2/evidence/prov-5-similarity-review.md` | PROV-5 clean-source statement + post-hoc structural similarity assessment for `HardReserve.sol` (AC-7) |
| `sprint-2/evidence/structural-absence-checklist.md` | FR-7.2 / FR-7.3 / INV-14 / INV-5 row-by-row checklist, each row naming the mechanical artifact that would fail (AC-4) |
| `sprint-2/engineer-feedback.md` | review verdict — **APPROVED**. Pass 2 (A-1 re-review) prepended, pass 1 preserved verbatim below the divider. Pass 2 independently recovered the subject-digest convention, byte-exactly reconstructed the `provenance.yml` and `verify-census.sh` audit-entry pre-images, ran 6 reviewer-authored mixed-case probes and 2 proof-of-mutation falsification tests, and reproduced the build-reachability control from compiler evidence. Raises **M-1** (extension-axis residual, MEDIUM, pre-existing and outside A-1 scope) + L-3, L-4, I-1, I-2 as disclosed context |
| `sprint-2/auditor-sprint-feedback.md` | audit verdict — **APPROVED** with 1 MEDIUM (**A-1**: case-sensitive source-universe walk, evadable by extension case) + 3 LOW (R-1, L-1, L-2); entry == exit subject digest `78c8881204…2ac45a`. Contains the addendum retracting the sprint-1 **N-2** refutation. **Preserved as written** — the remediation is recorded in `reviewer.md`, not by rewriting this artifact |

## sprint-3 artifacts

| file | role |
|---|---|
| `sprint-3/reviewer.md` | implementation report + AC verification table (8/8 ACs, validator exit 0 on the scoped slice); §6 records the two build-configuration judgment calls (`via_ir` enablement and the v3core inheritance leak it caused, caught by the `POOL_INIT_CODE_HASH` gate) |
| `sprint-3/sprint-3-scope.md` | byte-exact Sprint-3 slice of `sprint.md` L236–L290, the AC validator's scoped input (`1584e2e1…e8a815b6`) — the **pre-approval** slice, verified byte-exact at review entry; `sprint.md`'s hash changed when the 19 Sprint-3 checkboxes were ticked on approval, criteria text unchanged (same status as `sprint-1-scope.md`/`sprint-2-scope.md`) |
| `sprint-3/engineer-feedback.md` | review verdict — **APPROVED**. Every load-bearing claim re-derived on the exact tree rather than accepted on report: all 16 subject-manifest hashes re-computed, `_route`/`_vem` checked term-for-term against prd.md:L368/L386, 144/144 tests and CI-depth (fuzz 10,000 / invariant 16,384 calls, 0 reverts) re-run, Rig surface enumerated from the artifact (26 entries, `take` the only mutator), all four prohibited-signal commands reproduced. §8 is the standalone `via_ir` disposition: necessity proven by reproducing `Stack too deep` under both legacy configurations, Sprint-2 `VUX`/`HardReserve` runtime-bytecode deltas measured against a `bc5dedc2` worktree build, and the accumulated evidence shown sufficient because it is live-regenerated from `out/` with positive controls; frozen v3-core creation bytecode confirmed byte-identical (`0df5293b…`). Carries L-1…L-6 + I-1…I-3 as disclosed context |
| `sprint-3/evidence/subject-manifest.md` | SHA-256 manifest separating (A) the Sprint-3 implementation subject, (B) this node's lifecycle evidence, and (C) pre-existing State Zone material left untouched |
| `sprint-3/evidence/prohibited-signal-inspection.md` | FR-4.3 named checklist (AC-7) — all 14 primary-path branches enumerated; the `pure` modifier on both formulas and the four-`immutable` reference graph as the structural argument |
| `sprint-3/evidence/prov-3-similarity-review.md` | PROV-3 clean-source statement — per-section split of the Miner-derived skeleton vs. the VUX-original monetary surfaces, plus the sources-not-consulted list |
| `sprint-3/evidence/fb-1-mining-redemption-independence.md` | FB-1 review note (review-assigned row) — redemption's dependency graph contains no reference to the Rig |

## bounded nodes (not sprints)

| node | theme | implementation | review | audit | status |
|---|---|---|---|---|---|
| `foundry-v1.5-refreeze` | Foundry v1.0.0 → v1.5.0 toolchain refreeze + CI recovery | authority artifacts under `docs/authority/` | [`foundry-v1.5-refreeze/engineer-feedback-rereview.md`](foundry-v1.5-refreeze/engineer-feedback-rereview.md) — **APPROVED** (T-1…T-4 closed; 0/0/0/3) | [`foundry-v1.5-refreeze/auditor-feedback.md`](foundry-v1.5-refreeze/auditor-feedback.md) — **APPROVED** (0/0/0/3) on subject `0d578bfa…c41df` | operator-accepted and landed (`22e5e00f`); M-1 carried forward as the binding pre-Sprint-3 condition |
| `m1-l3-l4-provenance-hardening` | Pre-Sprint-3 provenance-tooling hardening — close M-1 / L-3 / L-4 | [`m1-l3-l4-provenance-hardening/reviewer.md`](m1-l3-l4-provenance-hardening/reviewer.md) | [`m1-l3-l4-provenance-hardening/engineer-feedback.md`](m1-l3-l4-provenance-hardening/engineer-feedback.md) — **APPROVED** (0/0/0/4) on subject `f75e4dbc…27fa9a`; M-1/L-3/L-4 independently confirmed closed, freshness control assessed sufficient on every authoritative path | — | **REVIEW_APPROVED**, awaiting exact-tree audit of subject `f75e4dbc…27fa9a`; uncommitted, `HEAD == 22e5e00f` |

**Superseded 2026-08-13.** Both pre-Sprint-3 conditions closed and landed: the M-1/L-3/L-4
provenance-hardening node at `26ca4cd6` and the adaptive-routing reconciliation package at
`bc5dedc2`, the latter being `master == origin/master` at Sprint-3 node start. `26ca4cd6` is an
ancestor of `HEAD`, so the block above is discharged and `/implement sprint-3` was authorized.

## `m1-l3-l4-provenance-hardening` artifacts

| file | role |
|---|---|
| `m1-l3-l4-provenance-hardening/reviewer.md` | implementation report — prior findings consumed, live pre-fix reproduction of M-1, the two-half source universe and why it is extension-independent, 15-probe negative results with per-probe fence attribution, the L-3 control's own mutation test, preservation evidence (6 accepted parity digests re-derived), and the 6-file subject manifest |

Trajectory logs live under `trajectory/`. Review and audit artifacts
(`engineer-feedback.md`, `auditor-sprint-feedback.md`) are written by
`/review-sprint` and `/audit-sprint` — not by `/implement`.
