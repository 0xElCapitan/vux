# Agent-to-Agent Artifact Index

Cycle **cycle-002 "VUX v1 Strategic Treasury"** — local sprint IDs equal global IDs (1:1).

| sprint | theme | implementation | review | audit | status |
|---|---|---|---|---|---|
| sprint-1 | Provenance-gated foundation & authorized vendoring | [`sprint-1/reviewer.md`](sprint-1/reviewer.md) (remediated 2026-08-11) | [`sprint-1/engineer-feedback.md`](sprint-1/engineer-feedback.md) — **APPROVED** (re-review, 8/8 AC) | [`sprint-1/auditor-sprint-feedback.md`](sprint-1/auditor-sprint-feedback.md) — **APPROVED** (0 critical / 0 high / 0 medium / 4 low) | `LANDED_VERIFIED` — operator-accepted and landed on `master` (`23263e18`) |
| sprint-2 | VUX token & Hard Reserve | [`sprint-2/reviewer.md`](sprint-2/reviewer.md) (A-1 remediated 2026-08-11) | [`sprint-2/engineer-feedback.md`](sprint-2/engineer-feedback.md) — **APPROVED** (pass 2, A-1 re-review: 0 critical / 0 high / 1 medium / 2 low) on subject `a6313a4d5a…2b772cf`; pass 1 (7/7 AC) preserved in-file | [`sprint-2/auditor-sprint-feedback.md`](sprint-2/auditor-sprint-feedback.md) — **APPROVED** (pass 2, exact-tree re-audit: 0 critical / 0 high / **1 medium: M-1 (non-blocking, binding pre-Sprint-3 condition)** / 5 low; A-1 CLOSED) on subject `a6313a4d5a…2b772cf` (entry == exit); pass 1 preserved in-file | `LANDED_VERIFIED` — operator-accepted 2026-08-12 at digest `a6313a4d5a…2b772cf` and landed on `master` (`89a92055`); committed-tree digest re-verified byte-identical to the accepted subject |
| sprint-3 | Rig: throne, settlement, VEM + invariant suite | — | — | — | planned |
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

Trajectory logs live under `trajectory/`. Review and audit artifacts
(`engineer-feedback.md`, `auditor-sprint-feedback.md`) are written by
`/review-sprint` and `/audit-sprint` — not by `/implement`.
