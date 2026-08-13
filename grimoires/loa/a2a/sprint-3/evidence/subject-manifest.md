# Sprint-3 Implementation Subject Manifest

**Sprint:** cycle-002 / sprint-3 (global = local)
**Branch:** `sprint-3`
**Baseline:** `bc5dedc2025921221407cd85f5ec1e6d40ad7a7b` (`master == origin/master` at node start)
**Date:** 2026-08-13

This manifest exists so the reviewer can distinguish, without guessing, between
(A) the Sprint-3 implementation, (B) this node's lifecycle evidence, and (C)
pre-existing State Zone material that was already in the worktree when the node
started and was deliberately left untouched.

---

## A. Sprint-3 implementation subject (the reviewable code)

App Zone — the implementation itself:

| SHA-256 | path | status |
|---|---|---|
| `f0377bf95432a3881ec84dd7ca21f5de6699dad94570bb60d97e5a44b8ac2b1e` | `src/Rig.sol` | new |
| `b19f15a50e5f75b4ad1ad2ab1e0d4fad6814f2d203cab6fb844597a0791c4802` | `src/interfaces/IVUXMintable.sol` | new |

Tests — new Rig suites:

| SHA-256 | path | status |
|---|---|---|
| `f0e550774db4f5d9df195e01b3a59eaac42dbf0f13f146b6cca639ff694100d1` | `test/rig/RigFixture.sol` | new |
| `154d63b807afaa08dc6f685790e1244f0ce33516e78d1295e8fb1e0d340173cb` | `test/rig/RigMathHarness.sol` | new |
| `bf7fc492eecdbde344b5fc308099127a3b37a02841baf3b7fdc7de12f90c3c1d` | `test/rig/RigPricing.t.sol` | new |
| `3aae98d23b2fcd981b7a4e0b7c01e6e77efbad8ac98278111f822000b8679828` | `test/rig/RigRouting.t.sol` | new |
| `abc54e23df0847d67fc71c15a0923f30a05ffe751df4458777cb3dca8bb55fba` | `test/rig/RigVem.t.sol` | new |
| `bdd0e2f6638be1f111f0ef94f63db05e369751f527343c944181912fd581923c` | `test/rig/RigSettlement.t.sol` | new |
| `14ace3d5c2c05b99bd977f2018eab5b2e1c2e2b58bcd7ff2292c431564067edb` | `test/rig/RigBootstrap.t.sol` | new |
| `4650f1583872f64562f62cb5f83c8fb2122a98cfc7c57d7976515ea67e8d981f` | `test/rig/RigInvariantHandler.sol` | new |
| `9a2bef47a77040aafb9255c7ba702309382a8bb79e2b5730acc79f1932f5a527` | `test/rig/RigInvariants.t.sol` | new |
| `74810348c1648593c9c3dcbd808dca5f29ab8246a5001f65b65332acbd5f657f` | `test/rig/RigFailureBehaviors.t.sol` | new |

Modified pre-existing files — three, each a strict addition:

| SHA-256 | path | change |
|---|---|---|
| `74d5be36d3935e475808c58177ba4da038394afb6ad03a5316f150f049e6d387` | `foundry.toml` | `via_ir`/`optimizer` on `[profile.default]`; invariant profiles; `via_ir = false` pinned on `[profile.v3core]` |
| `ade0f71b56d6dcf899f15738ea37051408f66c00408d4056b79cbb5694d2b9d8` | `test/harness/Vm.sol` | +2 cheatcode declarations (`load`, `getBlockTimestamp`) |
| `ed5a32c5b7607244c7dcb173f29d9784dca30b9ba4f31194c3dc6234a5be0bff` | `test/mocks/MockWeth.sol` | +4 probes (`transferFeeBp`, `transferBonus`, `failTransfersTo`, `setReentryCall`) |

**No pre-existing Sprint-1 or Sprint-2 source was edited.** `src/VUX.sol`,
`src/HardReserve.sol`, `src/interfaces/IVUX.sol`, every vendored file, every
`tools/provenance/` script, and all Sprint-1/2 test files are byte-unchanged.
Verify with:

```bash
git diff --stat bc5dedc2 -- src test tools vendor foundry.toml
```

## B. This node's lifecycle evidence (State Zone, written by Sprint 3)

| path | contents |
|---|---|
| `grimoires/loa/a2a/sprint-3/reviewer.md` | the implementation report |
| `grimoires/loa/a2a/sprint-3/sprint-3-scope.md` | byte-exact Sprint-3 slice of `sprint.md` L236–L290 — the AC validator's scoped input (`1584e2e1d948fb61e607d3bd9727c94fa973d9576c792b18b89d723fe8a815b6`) |
| `grimoires/loa/a2a/sprint-3/evidence/subject-manifest.md` | this file |
| `grimoires/loa/a2a/sprint-3/evidence/prohibited-signal-inspection.md` | Task 3.7 — FR-4.3 checklist |
| `grimoires/loa/a2a/sprint-3/evidence/prov-3-similarity-review.md` | Task 3.7 — PROV-3 statement |
| `grimoires/loa/a2a/sprint-3/evidence/fb-1-mining-redemption-independence.md` | Task 3.7 — FB-1 review note |

Plus the ordinary lifecycle side-effects: `grimoires/loa/a2a/index.md`,
`grimoires/loa/NOTES.md`, `grimoires/loa/ledger.json`, `.beads/issues.jsonl`,
and `grimoires/loa/a2a/trajectory/*.jsonl`.

## C. Pre-existing State Zone material — NOT Sprint 3, left untouched

Present in the worktree when this node started (see the git status recorded in
the node's opening context) and deliberately neither reset, staged, cleaned, nor
modified:

| path | origin |
|---|---|
| `grimoires/loa/a2a/m1-l3-l4-provenance-hardening/` | the M-1/L-3/L-4 hardening node |
| `grimoires/loa/analytics/` | prior nodes |
| `grimoires/loa/skills-pending/` | prior nodes |
| `grimoires/loa/ledger.json.bak`, `grimoires/loa/ledger.json.lock` | prior nodes |
| `.beads/.br_history/` | beads runtime |
| `.run/` | Loa run state |
| `grimoires/loa/a2a/trajectory/{continuous-learning,guardrails,implementing-tasks,karpathy,zone-guard}-2026-08-1*.jsonl` | prior nodes (Sprint 3 appends to the same directory) |

`grimoires/loa/NOTES.md` and `grimoires/loa/a2a/index.md` were already modified
before this node began; Sprint 3 appends to both rather than rewriting them.

## D. Reproducing the fingerprint

```bash
git rev-parse HEAD                       # baseline ancestry
git status --porcelain src test foundry.toml
sha256sum src/Rig.sol src/interfaces/IVUXMintable.sol test/rig/*.sol \
          test/harness/Vm.sol test/mocks/MockWeth.sol foundry.toml
```

The tree is left **uncommitted on branch `sprint-3`**: the operator mandate for
this node forbids committing, landing, or pushing, and the sprint plan places
landing after operator acceptance (sprint.md "Native Lifecycle & Artifact
Handoff", step 5). The hashes above are therefore the fingerprint of record.
