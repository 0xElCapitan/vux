# Agent-to-Agent Artifact Index

Cycle **cycle-002 "VUX v1 Strategic Treasury"** — local sprint IDs equal global IDs (1:1).

| sprint | theme | implementation | review | audit | status |
|---|---|---|---|---|---|
| sprint-1 | Provenance-gated foundation & authorized vendoring | [`sprint-1/reviewer.md`](sprint-1/reviewer.md) (remediated 2026-08-11) | [`sprint-1/engineer-feedback.md`](sprint-1/engineer-feedback.md) | — | remediation complete — awaiting re-review via `/review-sprint sprint-1` |
| sprint-2 | VUX token & Hard Reserve | — | — | — | planned |
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
| `sprint-1/sprint-1-scope.md` | byte-exact Sprint-1 slice of `sprint.md`, the AC validator's scoped input (`0133a5b8…799aa`, unchanged) |
| `sprint-1/engineer-feedback.md` | review verdict — CHANGES_REQUIRED (1 high: repo-wide unauthorized-source scoping); preserved unmodified |

Trajectory logs live under `trajectory/`. Review and audit artifacts
(`engineer-feedback.md`, `auditor-sprint-feedback.md`) are written by
`/review-sprint` and `/audit-sprint` — not by `/implement`.
