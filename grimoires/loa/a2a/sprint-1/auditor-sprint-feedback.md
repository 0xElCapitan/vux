# Sprint 1 — Security & Provenance Audit

**Gate:** independent security/provenance audit (post review-approval)
**Cycle:** cycle-002 · **Sprint:** global sprint-1 = local sprint-1
**Auditor role:** Paranoid Cypherpunk Auditor (`auditing-security`)
**Date:** 2026-08-11

---

## Audit subject identity

The audit was performed against the exact fresh-review-approved prospective tree.
A reproducible fingerprint was established **before** substantive audit actions and
re-verified after, so implementation mutation during the node is detectable.

| Item | Value |
|---|---|
| Git HEAD | `9aae6a0f16975980b008f10937b2719f717255b0` (branch `master`) |
| `AUDIT_SUBJECT_DIGEST` | `fe8bc661334222f36d14686ce306a83bf665647c2f952835922762ee2d15fca3` |
| Subject definition | 110 files: `tools/ test/ vendor/ docs/ src/ script/ .github/workflows/` + `foundry.toml remappings.txt .gitattributes .gitignore THIRD_PARTY_NOTICES.md LICENSE` + `prd.md sdd.md sprint.md` + the three `a2a/sprint-1/` artifacts |

Per-subtree identities (recorded pre-audit, re-verified post-audit — **all UNCHANGED**):

| Subtree / file | SHA-256 |
|---|---|
| `tools/` | `5994cbeee83c22a968b8e43760726c13dae91fd2cfa6f7280d30deb330b66502` |
| `test/` | `948aa8ecab505558487340330b6e9270cba1164674b51f7ecb0a6b2672c67d79` |
| `vendor/` | `83a7269963a7c63d325882dbfea9d568763f70789926a0bfabce6dae5b7d02a0` |
| `docs/authority/` | `cb6d3913da3adc53f2721ba401850ba0bcdb9c4d394342bb2d3a62b1f9b9acd1` |
| `.github/workflows/` | `8ed59fc4bd768d7af183c1d30eb8fdd31a5b88701e05b5e65eae4e4010fd2cf7` |
| `foundry.toml` | `63c97f74d9ce62507bcd12f2c9defe9bc648e03841fe3137400986197bcbafb3` |
| `remappings.txt` | `95434498908e3c09e997d9b95fc64631e735c7618c55ae62c4c5cfb3c77eb392` |
| `.gitattributes` | `6bf7979cd79cf5ee2b6d0ebf89702413ee9990bb8d55a605140f3e47ab4e02db` |
| `.gitignore` | `50466e766bc66648ec6ef80272ce295d91c0e2b8de4ffae8b9b4e6124dab9064` |
| `THIRD_PARTY_NOTICES.md` | `963e2cfb8fe8306ee6d2cfd6e14fa417a7a61fd7bfddc3fe5aedc2b577170873` |

Review artifacts audited (unmutated by this node):

| Artifact | SHA-256 |
|---|---|
| `a2a/sprint-1/reviewer.md` | `585f3dd1f50d523d9bf9964335fe509fb2cc9e0b0d110891f65a8a003d211e26` |
| `a2a/sprint-1/engineer-feedback.md` | `89af901bbd0e644b94e861dbb6dc9c9b865a6b7b7ccf0de5d2b95de9f3d888ad` |
| `grimoires/loa/sprint.md` | `8de038beab9d16a16a6c3d6eb9abc51553a03fd1f2f25e33ef7c849e7dabb6ee` |

Binding upstream authority independently re-hashed and **matching** the operator-stated
values: `prd.md` `4e5cacf7…`, `sdd.md` `19241ed7…`, refreeze `27aa37ec…`, registry delta
`db314413…`, TPN baseline `963e2cfb…`.

> The `AUDIT_SUBJECT_DIGEST` excludes Loa telemetry (`.run/*.jsonl`,
> `a2a/trajectory/*.jsonl`) because framework hooks append to those on every tool call
> in any session. Their bytes were never part of the pre-audit implementation subject
> and are not claimed as such.

---

## Executive summary

Sprint 1 is foundation and provenance only; there is no VUX monetary or product contract
to audit yet. The central security claim under test was that **later implementation cannot
silently introduce unauthorized source, mutate accepted upstream, alter compiler/source
authority, substitute mutable dependencies, or falsify the deterministic v3-core
reproduction without the repository gates failing loudly.**

I attempted to falsify that claim rather than re-run the implementation and review
checklists. The load-bearing parts of it hold, and they hold under independent
reproduction rather than on the implementation's own say-so:

- **Vendored identity is independently reproduced.** I re-derived all 63 authorized
  identities myself from the accepted registries — 60 via SHA-256, 3 via git blob OID —
  without invoking the project's own scripts. Zero drift. The on-disk set and the
  registry set are exactly equal in both directions (no extras, no omissions, any file
  type).
- **The init-code hash is genuinely derived, not restated.** I discarded the existing
  build output, rebuilt the `=0.7.6` unit from vendored source (32 files,
  `0.7.6+commit.7338295f`), and hashed the creation bytecode with an **independently
  written keccak256** (self-tested against published vectors) rather than Foundry's own
  hasher. Result: `0xe34f199b…b8b54`, 22,728 bytes, CBOR tail `a164736f6c6343000706000a`
  — the accepted constant, reproduced end to end. The gate is not a constant compared to
  itself.
- **Default-deny is real and fails closed.** I executed the boundary demonstration: six
  probes (out-of-root vendored copy, relocated `UniswapV3Factory.sol`, relocated
  prohibited sources, relocated periphery, `forge-std` in `lib/`, relocated §17 value)
  each made the correct gate fail *for the correct reason*, and the working-tree
  inventory hash was identical before and after.
- **The drift gate closes.** I ran the drift demonstration in an isolated repository copy
  (so the real `vendor/` was never mutated) against **all three** identity paths — a
  v3-core file, an OpenZeppelin file, and a Miner file on the blob-OID path. Each
  one-byte mutation failed the gate and restored exactly.

The residual findings are four LOW-severity hardening items and three informational
observations. None of them is an exploitable default-deny bypass, fail-open enforcement,
falsifiable vendored identity, mutable-dependency substitution, incorrect compiler
semantics, false hash reproduction, licence escape, or secret exposure. Notably, one of
the reviewer's carried findings (**N-2**) is **refuted as a security defect** by direct
experiment.

**Overall risk level: LOW.**

---

## Key statistics

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 4 |
| Informational | 3 |

Verification performed: 63/63 vendored identities independently reproduced · 6/6 boundary
probes executed · 3/3 drift-identity paths executed · 11/11 `forge test` assertions passing
· 6/6 read-only gates green · 1 clean-room rebuild · 3 adversarial probes authored by the
audit node.

---

## Disposition of the review's residual findings (N-1 … N-5)

These arrived as audit **inputs**, not as mandatory failures. Each was classified
independently, and the goalposts were not moved to manufacture another iteration.

### N-1 — pruned Loa zones are invisible to the source universe → **LOW (confirmed, deferred)**

`tools/provenance/census.sh:163` prunes `.claude grimoires .beads .run .ck` from
`SOURCE_UNIVERSE_PRUNE`. `grimoires/` is git-tracked, so this is a genuine blind spot
rather than a paper one.

**Probe (audit-authored, executed):** planted an unauthorized contract at
`grimoires/loa/audit-probe-tmp.sol` → `verify-census.sh` stayed **green**. Confirmed blind.

**Reachability (audit-authored, executed in an isolated scratch project):** an out-of-root
`.sol` is **not** reached by Foundry auto-discovery (`forge build` reported "Nothing to
compile"), but **is** compiled and emitted as an artifact when explicitly imported by a
file inside a declared root. So the mechanism is real.

**Why LOW, not blocking.** Exploitation requires an explicit `import` statement inside
`src/`, `test/`, or `script/` — a visible line in the reviewed diff, in the most
review-exposed part of the repository. The bypass defeats the *mechanical* gate, not
human review. Present exposure is zero: there is no Solidity anywhere under the pruned
zones, `src/` and `script/` contain only `.gitkeep`, and the only five VUX-owned `.sol`
files are the test harness. The operator's own remediation authority explicitly permitted
excluding Loa zones.

**Recommended (pre-Sprint-2, when `src/` begins carrying real source and imports become
routine):** keep the prune for performance but add a one-line assertion that the pruned
Loa zones contain zero `*.sol`, e.g.
`find .claude grimoires .beads .run .ck -name '*.sol' -print -quit` must be empty. This
closes the hole without un-pruning the zones.

### N-2 — case-sensitive `*.sol` misses `Foo.SOL` → **INFORMATIONAL (refuted as a defect)**

**Probe (audit-authored, executed, with A/B control):** `contracts/Probe.SOL` in an
unauthorized location → `verify-census.sh` **green** (blind spot confirmed). The
byte-identical file renamed `contracts/Probe.sol` → gate **red**, failing closed. So the
glob at `census.sh:171` is indeed case-sensitive.

**But the compiler shares the same blind spot.** In an isolated scratch project:

- auto-discovery of `src/UpperOnly.SOL` → `forge build` reported **"Nothing to compile"**;
- an explicit `import {UpperOnly} from "./UpperOnly.SOL";` → **"Unable to resolve
  imports"** — Foundry's resolver does not treat `.SOL` as Solidity either.

There is therefore **no path by which a `.SOL` file enters the build**, so its invisibility
to the gate has no provenance or build consequence. This is precisely the "theoretical
filesystem curiosity with no practical build consequence" class that must not block
progression. Recommend closing N-2 rather than carrying it as debt.

*Residual watch item:* the refutation depends on Foundry's extension matching staying
case-sensitive. Changing `-name '*.sol'` to `-iname '*.sol'` is a one-character hardening
that would make the gate robust to a future toolchain change; optional, not required.

### N-3 — `find` does not descend directory symlinks → **LOW (deferred)**

`source_universe()` (`census.sh:171`) uses `\( -type f -o -type l \)`, so symlinked
*files* are seen — the comment at `census.sh:166-167` is accurate. Un-descended
*directory* symlinks remain a theoretical vector. Not testable on this platform
(symlink creation is unavailable at the current privilege level), and the present tree
contains **zero symlinks anywhere** (verified) and zero hard-linked vendored files.
A directory symlink is also a conspicuous, git-visible repository object, and the
extension-agnostic sweep at `verify-census.sh:108-117` would catch one introduced under
`vendor/`. Deferred hardening; `find -L` with cycle guarding is the fix if it is ever
wanted.

### N-4 — `grimoires/` excluded from launch-secret scanning → **LOW (confirmed, pre-launch)**

`tools/provenance/verify-launch-hygiene.sh:58` excludes `^(vendor/|docs/authority/|grimoires/)`
from the secret scan. Excluding `vendor/` and `docs/authority/` is defensible (both are
hash-frozen). `grimoires/` is different: it is mutable, agent-written, **and tracked**, so
a secret written there would be committed unscanned.

**Probe (audit-authored, executed):** ran all four hygiene patterns plus a broad
`0x[0-9a-fA-F]{64}` sweep across all 35 tracked/untracked-not-ignored `grimoires/` files.
Result: **zero** secrets; the only 64-hex literal is the accepted pool init-code hash in
`NOTES.md:52`. Sprint 1 contains no production secret or broadcast artifact.

Assessment: this is a **coverage gap with no current exposure**, not a live secret-leak
boundary defect — Sprint 1 has no launch EOA, no salt, and no broadcast material to leak.
It must be closed before any deployment-runbook or launch material lands (Sprint 7).
Fix is a one-token edit: drop `grimoires/` from the exclusion (it already scans clean, so
this costs nothing today).

### N-5 — CI asserts the Foundry tag, not the 40-character commit → **LOW (hardening)**

`.github/workflows/provenance.yml:51-54` matches `forge --version` against
`*"${FOUNDRY_VERSION#v}"*` — a substring match on `1.0.0`. Two observations: the match is
loose (it would also accept `11.0.0`, or a build date containing `1.0.0`), and `forge
--version` reports only a short commit, so a literal 40-character assertion is not
directly available from the tool. The accepted 40-char commit
`8692e926198056d0228c1e166b1b6c34a5bed66c` *is* recorded in `foundry.toml:19` and lint-
enforced by `verify-pins.sh:33`.

**Why this does not block.** Foundry is not bytecode-determining here, and I verified that
empirically rather than assuming it: the full clean-room reproduction of the accepted
`POOL_INIT_CODE_HASH` was performed under **forge 1.5.0-stable**, not the pinned v1.0.0,
and produced byte-identical creation code. The hash is solc-determined. Every
bytecode-affecting setting is explicit in `foundry.toml:53-56`; solc build identity is
asserted from artifact metadata across *all* artifacts (`verify-pins.sh:45-72`); and the
init-code-hash gate independently reproduces the constant. A repointed Foundry tag
therefore cannot silently change the pool bytecode without the gate failing loudly.

**Recommended:** tighten to an anchored match on the short commit reported by
`forge --version` (`8692e92`) plus an exact version match, rather than a floating
substring. One-line change.

---

## Findings

No CRITICAL, HIGH, or MEDIUM findings. The four LOW findings are N-1, N-3, N-4 and N-5
above. The three informational observations are recorded below because a provenance audit
should state what the system does *not* cover, so the uncovered part is not mistaken for
covered.

### INFO-1 — `PoolInitCodeHash.t.sol` reads a pre-existing artifact

`test/provenance/PoolInitCodeHash.t.sol:32` reads
`out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json` via `vm.readFile`. Under a bare
`forge test`, a stale artifact would satisfy the assertion; if the artifact is absent the
test fails closed. This is **not** a defect on any gate path:
`verify-init-code-hash.sh:16` runs `forge build --force` first, `run-all.sh:21-22` rebuilds
both units before any gate, `verify-pins.sh:72` asserts every `out-v3core/` artifact's
compiler identity, and the drift gate independently detects any vendored mutation. The
test's own docstring (`:13-17`) already scopes it correctly. Recorded for accuracy, no
action required.

### INFO-2 — copy-and-relabel into a declared VUX root is outside the model

Verbatim upstream source copied into `src/`, `test/`, or `script/` with its SPDX header
rewritten to `GPL-3.0-or-later` would classify as `vux` (`census.sh:186-188`), satisfy the
PROV-8 policy (`verify-spdx.sh:85-87`), and never be compared against a census identity
(the drift gate only walks enumerated census paths). This is an inherent limit of
hash-based provenance: it detects mutation of *enumerated* files and source in
*unauthorized locations*, not unattributed copying into an authorized one.

The boundary demonstration's probe 1 covers the out-of-root variant (where the retained
upstream SPDX trips the gate); the in-root relabelled variant is covered by human review,
which is why declared roots are declared. Present exposure is zero — `src/` and `script/`
contain no Solidity at all. **Recommended:** name this residual explicitly in
`tools/provenance/README.md` so a future reader does not over-read the guarantee.

### INFO-3 — pathological filenames fail closed (verified, no action)

I checked the newline/whitespace injection class specifically, since `source_universe()`
and `grep_sources()` are newline-delimited. A `*.sol` filename containing a newline splits
into fragments; no fragment can begin with `src/`, `test/`, or `script/` (a filename cannot
contain `/`), so every fragment classifies as `unauthorized` and the census gate **fails
closed**. Detector greps over such a path would miss its contents, but the file has already
failed the boundary check, so the composite result is still closed. No action.

---

## High-priority audit surfaces — results

### 1. Repository-wide default deny — **PASS**

The three-class model (`vendored` / `vux` / `unauthorized`) at `census.sh:176-192` is
sound, and it is filesystem-enumerated rather than `git ls-files`-scoped, so an
uncommitted or gitignored file cannot escape. Declared roots are exactly `src test script`
(`census.sh:152`); `contracts/`, `lib/`, `node_modules/`, and arbitrary top-level
directories are **not** authorized, and probes 1/5 of the boundary demonstration prove
each fails closed. Observed classification on the audited tree: **68 Solidity files = 63
vendored + 5 VUX-owned, 0 unauthorized**, matching my own independent enumeration exactly.

The anti-tautology guard at `verify-census.sh:99-104` is the strongest single piece of
design here: it asserts the walk actually classified all 63 census rows, so a pruning bug
that hid `vendor/` would fail loudly instead of silently turning "zero unauthorized" into
a vacuous truth.

### 2. `SOURCE_UNIVERSE_PRUNE` as a security boundary — **PASS with LOW finding (N-1)**

Every exclusion reviewed. `.git` (object store), `out out-v3core cache cache-v3core`
(build output — correctly excluded, and note the Foundry artifact layout creates
**directories** named `*.sol`, which the `\( -type f -o -type l \)` predicate correctly
excludes from the file count), `broadcast` (gitignored launch artifacts), and the five Loa
zones. The prune is top-level-anchored (`-path "./$p"`), so a nested `foo/out/Bar.sol`
is *not* pruned — stricter than it needed to be, which is the right direction. Disposition
of the Loa-zone residue is N-1 above.

### 3. Filename/case and traversal edge cases — **PASS**

N-2 refuted by experiment, N-3 deferred, INFO-3 verified fail-closed. Additional checks:
zero uppercase-extension Solidity anywhere in the tree, zero case-insensitive duplicate
paths (collision risk), zero symlinks, zero hard-linked vendored files.

### 4. Vendored integrity — **PASS**

Independently reproduced, without using the project's scripts:

| Family | Count | Identity kind | Result |
|---|---|---|---|
| OpenZeppelin v5.2.0 | 28 | SHA-256 | 28/28 exact |
| Uniswap v3-core v1.0.0 | 32 | SHA-256 | 32/32 exact |
| Miner Manifold @ `bcffbf1e` | 3 | git blob OID | 3/3 exact |
| **Total** | **63** | — | **0 drift** |

Bidirectional set equality against the registry holds for files of **any** type (not just
`.sol`): nothing present-but-unauthorized, nothing authorized-but-missing. No path alias,
duplicate source, symlink, case collision, or hard link can substitute for the accepted
bytes. Line-ending normalization is defended at two layers: `.gitattributes` pins
`vendor/** -text` and `*.sol -text` regardless of the cloner's `core.autocrlf`, and CI
independently asserts the checkout preserved bytes
(`provenance.yml:36-37`). Re-verified 63/63 again at the end of the audit — still zero
drift, so the audit node itself mutated nothing.

### 5. Deterministic v3 reproduction — **PASS (strongest evidence in the sprint)**

Clean-room procedure: existing `out-v3core/` moved aside, `cache-v3core/` emptied, unit
rebuilt with `FOUNDRY_PROFILE=v3core forge build --force`.

| Fact | Accepted | Reproduced |
|---|---|---|
| Compiler | `0.7.6+commit.7338295f` | `0.7.6+commit.7338295f` (all 32 artifacts) |
| Creation code length | 22,728 bytes | 22,728 bytes |
| `POOL_INIT_CODE_HASH` | `0xe34f199b…b8b54` | `0xe34f199b…b8b54` |
| CBOR tail | `a164736f6c6343000706000a` | `a164736f6c6343000706000a` |
| Optimizer / runs / EVM / metadata | on / 800 / istanbul / none | `foundry.toml:53-56` |

Freshly rebuilt bytecode is byte-identical to the pre-audit artifact. The hash was computed
with an **independent keccak256 implementation** written for this audit and self-tested
against three published Keccak-256 vectors before use — so the reproduction does not rely
on Foundry, on `cast`, or on the project's tooling. The gate **cannot** pass by comparing
one restated constant against another: `PoolInitCodeHash.t.sol:32-35` hashes bytes read
from the compiled artifact, and the artifact is produced by the pinned `=0.7.6` unit whose
compiler identity is independently asserted.

### 6. Compiler / Foundry supply-chain boundary — **PASS with LOW finding (N-5)**

Both solc pins present at full 40 characters and lint-enforced. Compiler identity is
asserted from artifact metadata across the **set** of all artifacts per unit
(`verify-pins.sh:45-72`) rather than a sampled one — strictly stronger, and the code
comment documents why the previous `head -1` approach was both non-deterministic and
wrong. Verified green: 18/18 artifacts under `out/` at `0.8.28+commit.7893614a`, 32/32
under `out-v3core/` at `0.7.6+commit.7338295f`. Every GitHub Action is pinned to a
40-character commit; no mutable `blob|tree|raw|archive` upstream reference and no short SHA
is used as authority anywhere in VUX-owned files.

**Evidence ceiling, stated honestly:** no CI run under the pinned Foundry **v1.0.0** has
ever executed — the workflow file is still untracked, so no pipeline has run at all. All
local execution in this audit was under **forge 1.5.0-stable**. I did **not** fabricate
pinned-CI evidence. A first green CI run under Foundry v1.0.0 remains a pre-landing
requirement; the configuration is otherwise correct, and the fact that the init-code hash
reproduces identically under a *different* Foundry version is positive evidence that the
pinned run will agree.

### 7. Shell / CI security — **PASS**

Reviewed all 13 files under `tools/provenance/` and `.github/workflows/provenance.yml` as
security-sensitive enforcement code.

- **Exit-status discipline is correct where it matters most.**
  `demo-drift-negative.sh:57-58` captures `${PIPESTATUS[0]}` — the gate's status, not
  `grep`'s / `head`'s — immediately after the pipeline. `demo-boundary-negative.sh:52`
  captures `rc=$?` from the command substitution. Both are exactly the pipeline/exit-code
  mistake class this audit was told to hunt, and both are handled right.
- **`set -e` assumptions are sound.** Gates use `set -euo pipefail` with a `fail()` that
  returns 0, so `-e` does not abort before the aggregate `finish()` runs; `finish()`
  (`census.sh:77-83`) exits 1 on any recorded failure. `run-all.sh` deliberately drops
  `-e` (`set -uo pipefail`) and aggregates into a `failed=()` array so one violation cannot
  hide the others, then exits 1 — correct fail-closed aggregation, not fail-open.
- **Degradation paths fail closed, not open.** If `jq` were missing or the registry
  unreadable, the authorized set would be empty and *every* vendored file would classify
  `unauthorized` → loud failure. If build output is absent, `check_compiler` fails rather
  than skipping. If the source-universe walk under-collects, the anti-tautology guard
  fires. CI additionally asserts `jq --version` before the gates run.
- **Quoting/word-splitting/globbing**: arrays used throughout for multi-path arguments;
  `xargs -r -d '\n'` used for file lists (`-r` prevents an empty-list invocation);
  `${r:?}` guards the probe-root deletions in `demo-boundary-negative.sh:38`.
- **Temporary files / cleanup**: `mktemp`-based with `trap … EXIT` in
  `demo-drift-negative.sh:22-24` and `vendor-sync.sh:20-21`; cleanup does not mask failure
  — both demonstrations *re-verify* after restore and return non-zero if restoration or
  the re-check fails.
- **Self-exclusion is scoped, not blanket**: the two scripts that must contain the literals
  they hunt exclude only their own path
  (`verify-quarantine.sh:72`, `verify-launch-hygiene.sh:66`), not a directory.
- **CI/local divergence**: CI runs `bash tools/provenance/run-all.sh` — the same entry
  point a developer runs — so the gate set cannot drift between environments. No secrets
  are used or required, matching the accepted Sprint-1 security consideration.
- **`vendor-sync.sh`** verifies `rev-parse HEAD` equals the pinned commit after cloning
  (`:34-39`), so a repointed tag is caught — the tag is a fetch optimisation, never
  authority — and verifies each file's identity **before** copying (`:54-66`). It uses
  process substitution rather than a pipe specifically so the subshell cannot discard the
  failure count, and documents why (`:77-78`).

One portability note, non-blocking: `xargs -d`, `find -printf`, and `grep -I` are GNU
extensions. CI is `ubuntu-latest` and local development is Git Bash, both GNU. Not a
finding, but worth knowing if the gate set ever runs on BSD/macOS.

### 8. Negative demonstrations — **PASS (both executed by the audit node)**

Both were independently inspected **and run**, and both establish their claim.

*Drift demonstration* — executed in an isolated repository copy so the audited `vendor/`
was never mutated, and extended beyond the standing demo to all three identity paths:

| Target | Identity path | Gate under mutation | Restored | Green again |
|---|---|---|---|---|
| `uniswap-v3-core/…/UniswapV3Pool.sol` | SHA-256 | FAIL (exit 1) | exact | yes |
| `openzeppelin/…/token/ERC20/ERC20.sol` | SHA-256 | FAIL (exit 1) | exact | yes |
| `miner-manifold/contracts/Rig.sol` | git blob OID | FAIL (exit 1) | exact | yes |

The probe definitely occurs (mutation is asserted to change the SHA before the gate runs,
`:48-51`), the baseline is asserted green first (`:36-39`) so a pre-red gate cannot
manufacture false success, and the failure is confirmed to be a `DRIFT` line rather than an
unrelated red gate.

*Boundary demonstration* — executed in-repo (its probe roots `contracts/` and `lib/` are
external to the delivered tree, it refuses to run if either already exists, and it cleans
up via `trap`): **6/6 probes failed closed for the intended reason**, each verified by
matching a specific expected message rather than merely observing a non-zero exit; each
probe removed and each gate re-proven green; and the working-tree inventory hash was
identical before and after (`ae7a459d…33f5`), which I corroborated with my own independent
inventory hash taken around my own probes.

### 9. Licence / provenance boundary — **PASS**

No copy authority was broadened. Verified absent: `UniswapV3Factory.sol` implementation
(the *interface* is authorized and present, the implementation is not), all v3-periphery
source/imports/remappings, any Miner file beyond the three allowlisted, LSG /
gumball6900 / give.fun / Olympus references, and `forge-std` (the test harness is
VUX-original with zero external test dependencies — `BaseTest.sol`, `Vm.sol`,
`Harness.t.sol`). 63/63 vendored files retain their upstream SPDX verbatim; the v3-core
licence tally matches the accepted 9 BUSL-1.1 / 22 GPL-2.0-or-later / 1 MIT exactly, which
defends against a per-file swap that preserved the set; 5/5 VUX-owned files satisfy the
PROV-8 policy; no invented copyright holder. `LICENSE` is the GPL-3 text and
`THIRD_PARTY_NOTICES.md` matches the accepted baseline `963e2cfb…` byte-for-byte with all
four required upstream notices present.

Enforcement is not trivially bypassable: the SPDX policy is driven by the same
repository-wide derived source list as the census, so a file that escapes the declared
roots is still held to it (proven live by boundary probe 1) rather than silently opting
out. §17 research-guidance quarantine is live and green across all 10 patterns, reaches
relocated implementation (probe 6), and its `loa:guidance-example` escape hatch is
review-visible by construction. **No new provenance rule was invented during this audit.**

### 10. Launch / repository hygiene — **PASS with LOW finding (N-4)**

`.gitignore` excludes `broadcast/**`; no broadcast artifact, `.env` file, or build output
is tracked; all four launch-secret patterns are clean across 248 scanned files (tracked
**plus** untracked-not-ignored — the fix for the pre-first-commit vacuity is present and
correct, and matters here precisely because the entire sprint is still uncommitted).
Sprint 1 contains no production secret or broadcast artifact. `grimoires/` coverage is
N-4 above.

---

## Scope regression — **PASS**

| Check | Result |
|---|---|
| Zero Sprint-2+ product implementation | confirmed |
| `src/` contains no Solidity | confirmed (`src/.gitkeep` only) |
| `script/` contains no Solidity | confirmed (`script/.gitkeep` only) |
| No `VUX.sol` / `HardReserve.sol` / `StrategicTreasury.sol` / `VuxPoolDeployer.sol` / `GenesisDeployer.sol` / `Lens.sol` | absent |
| No `Rig.sol` VUX implementation | only `vendor/miner-manifold-bcffbf1e/contracts/Rig.sol`, an authorized census row |
| No LSG / POL / VYRF implementation | confirmed |
| No operator-reserved R-1…R-14 decision | confirmed |
| No off-chain dependency installation | confirmed (zero deps beyond the census; no `forge-std`, no `lib/`, no `node_modules/`) |
| No Slither | confirmed |
| No commit / push / tag | confirmed — HEAD unchanged at `9aae6a0f` |

---

## Acceptance-criteria verification (8/8)

| # | Criterion | Verdict | Independent evidence |
|---|---|---|---|
| 1 | Census exactness 28+32+3, per-file SHA-256 vs registry, zero unenumerated | PASS | 63/63 re-derived by the audit node; bidirectional set equality, any file type |
| 2 | Drift gate demonstrated fail-closed on a 1-byte mutation | PASS | executed in an isolated copy across all 3 identity paths; exact restoration proven |
| 3 | `POOL_INIT_CODE_HASH` reproduced from the vendored `=0.7.6` unit, fails closed on mismatch | PASS (CI execution pending) | clean-room rebuild + independent keccak256 → accepted constant |
| 4 | No Factory implementation / no v3-periphery / no non-allowlisted Miner | PASS | gate green + boundary probes 2 and 4 |
| 5 | §17 quarantine live and green | PASS | 10/10 patterns clean + boundary probe 6 |
| 6 | Both solc pins, 40-char, CI fails on missing/short/mismatched | PASS | `verify-pins.sh` green; artifact-metadata assertion across all artifacts |
| 7 | `.gitignore` excludes `broadcast/**` | PASS | verified |
| 8 | Zero new dependencies beyond the census (harness included) | PASS | VUX-original harness; boundary probe 5 proves `lib/forge-std` is caught |

`forge test`: **11/11 passing** (3 vendored-surface, 2 init-code-hash, 6 harness including a
256-run fuzz and four assertions that verify failing assertions actually revert).

---

## Security checklist status

- [x] Secrets & credentials — no hardcoded key, mnemonic, or salt; scan gate live
- [x] Supply-chain security — 40-char commit pins, SHA-pinned Actions, no mutable ref as authority
- [x] Input validation at trust boundaries — the only external input is upstream fetch, verified per file before it lands
- [x] Dependency integrity — 63/63 byte-identical, independently reproduced
- [x] Build determinism — init-code hash reproduced clean-room with an independent hasher
- [x] Fail-closed enforcement — verified by execution, not by reading
- [x] Licence & notice compliance — SPDX retention, licence tally, TPN integrity
- [x] CI security — no secrets required, least-privilege `contents: read`, pinned Actions
- [x] Documentation coherence — `tools/provenance/README.md` present; every gate carries an authority citation in-header
- [x] No PII / data-privacy surface in scope (no application code exists yet)
- [n/a] Auth/authz, injection sinks, API security — no application or on-chain VUX code in Sprint 1

---

## Audit-node mutation statement

Files created by this node:

- `grimoires/loa/a2a/sprint-1/auditor-sprint-feedback.md` (this artifact)

Build output regenerated (gitignored, explicitly outside the source universe, not part of
the audit subject): `out-v3core/`, `cache-v3core/` — rebuilt during the clean-room
reproduction; contents byte-identical to the pre-audit artifact.

Loa framework telemetry appended automatically by hooks on every tool call, in any session:
`.run/audit.jsonl`, `.run/karpathy-task-state.jsonl`.

Temporary probes, all outside the delivered tree or fully reverted with the tree inventory
hash verified identical before and after: `contracts/` and `lib/` probe roots (removed),
one `grimoires/loa/audit-probe-tmp.sol` (removed), isolated scratch Foundry projects and an
isolated repository copy under the session scratchpad.

**Not touched:** implementation, provenance scripts, CI, tests, vendored source,
dependencies, review artifacts, Sprint Plan, PRD/SDD/authority, Beads/task state, Sprint
Ledger, `a2a/index.md`. **No `COMPLETED` marker created. No commit, push, tag, or landing.
Sprint 2 not started.**

Verified post-audit: implementation-surface subtree hashes all unchanged; 63/63 vendored
identities re-verified with zero drift; `AUDIT_SUBJECT_DIGEST` covers the audited subject
and excludes this artifact's own bytes, so no audit bookkeeping is falsely claimed as part
of the pre-audit implementation subject.

---

## Pre-landing conditions

These are **not** audit blockers. Audit approval establishes eligibility for operator
acceptance; these must be satisfied before the sprint lands.

1. **First green CI run under the pinned Foundry v1.0.0.** No pipeline has executed —
   `.github/workflows/provenance.yml` is still untracked. AC-3's "reproduced in CI" is
   satisfied mechanically and locally but not yet in CI. Required on the branch before
   direct-FF landing.
2. **The whole Sprint-1 deliverable must actually land in the commit.** `tools/` (13),
   `vendor/` (63), `test/` (5), `foundry.toml`, `remappings.txt`, `.gitattributes`, the
   workflow, and 7 `docs/authority/` files are currently **untracked**. `.gitattributes`
   must land in the same commit as `vendor/`, or a fresh Windows clone can mangle line
   endings and break every identity.
3. **Post-merge verification** should re-run `tools/provenance/run-all.sh` on the landed
   tree.

Recommended before Sprint 2 (LOW findings, none blocking): N-1 zero-`.sol` assertion over
the pruned Loa zones; N-4 removal of `grimoires/` from the hygiene exclusion; N-5 anchored
Foundry commit assertion. N-3 optional. N-2 recommended for closure as refuted.

---

## Verdict

The central Sprint-1 security claim survived a falsification attempt. Vendored identity is
independently reproduced and exact at 63/63; the deterministic v3-core reproduction is
genuinely derived rather than restated, confirmed clean-room with an independent hasher;
default-deny is repository-wide, self-defending against its own pruning bugs, and proven
fail-closed by executed demonstrations on both axes; compiler and dependency authority rest
on 40-character immutable commits; and the licence/provenance boundary was not broadened.

Zero CRITICAL, zero HIGH, zero MEDIUM. Four LOW hardening items — one of which (N-2) is
affirmatively refuted as a defect by direct experiment — none of which violates the
accepted Sprint-1 security or provenance boundary, and all of which have zero present
exposure because Sprint 1 contains no product source, no secrets, and no deployable
material.

Sprint 1 is **eligible for EC/operator acceptance**. This is an audit verdict only; it is
not operator acceptance, and the sprint is neither accepted nor complete.

**APPROVED - LET'S FUCKING GO**

**Recommended next node:** EC/operator acceptance of Sprint 1.

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":4},"sprint_id":"sprint-1","ts":"2026-08-11T00:20:00Z"} -->
