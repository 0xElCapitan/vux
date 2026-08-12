All good

Sprint 2 re-reviewed after the A-1 remediation and approved. Audit finding A-1
is structurally closed, the closure is non-vacuously proven by reviewer-authored
mutation testing, and no regression exists. The exact product monetary subject is
byte-unchanged.

---

# Sprint-2 Re-Review (pass 2) — A-1 remediation, focused scope

**Reviewer:** Senior Technical Lead (`/review-sprint sprint-2`, re-review)
**Date:** 2026-08-11
**Verdict:** APPROVED — 0 critical / 0 high / 1 medium / 2 low
**Scope:** the four-file A-1 remediation only. Pass-1 findings and the audit's
LOW residue were not reopened (see §13).
**Prior review:** pass 1 (APPROVED, 7/7 AC) — preserved verbatim below the
divider at the end of this file, unedited.

The single MEDIUM (**M-1**, §11) is a **newly discovered, pre-existing,
out-of-A-1-scope** residual on a different axis. It is explicitly **not** a
blocker for this node and **not** a regression — rationale in §11 and §14.

---

## 1. Exact current subject digest

Subject reconstructed independently from repository state — every working-tree
path differing from base commit `79c966f6`, excluding `grimoires/**`,
`.beads/**`, `.run/**` — **exactly 18 files**, matching the audit's path set
row-for-row.

```
a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf
```

**The digest convention was recovered independently, not taken from
`reviewer.md`.** The audit records only "SHA-256 over the sorted `sha256  path`
manifest". Reconstructing that manifest from the audit's own per-file table
(`auditor-sprint-feedback.md:76-93`) and hashing it reproduces the audit-entry
digest byte-exactly:

```
audit-digest-reproduced: 78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a
audit-digest-claimed:    78c888120480eb101eee77d375b08ca5b2621f5f8e760a708c5904feca2ac45a
```

Applying that same rule (`<sha256>` + two spaces + `<path>`, `LC_ALL=C` sorted
by path, LF, trailing newline) to the current 18 files yields
`a6313a4d5a…2b772cf` — matching the implementation's claim. Both anchors hold:

| Path | SHA-256 | Status |
|---|---|---|
| `src/VUX.sol` | `5686c4c7c353711998eccb3693bda44d9ab0352ed79d69a1b853447dc5197349` | unchanged |
| `src/HardReserve.sol` | `74b8319ab155225b4533790b88d3adc71c8da117ff74d4124e180f3bd39f2c17` | unchanged |

**Post-review re-verification:** after all reviewer probing, mutation testing and
compiler runs described below, the subject digest was recomputed and is
`a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf` — **identical**.
This review mutated no subject byte.

---

## 2. Four-file remediation diff — disposition

Exactly **4** of the 18 subject files differ from the audit-entry table; the
other **14 are byte-identical**, verified hash-by-hash rather than asserted.

| Path | Audit entry | Current | Disposition |
|---|---|---|---|
| `tools/provenance/census.sh` | `8b9996456ff3b5ed…e9c09d7e` | `63e8ec9d21fd4056…bebf8533` | **ACCEPTED** |
| `tools/provenance/verify-census.sh` | `39d721f95ed4a892…d0d17c3b88a0` | `2530dcd9f2b61856…cf82dee5` | **ACCEPTED** |
| `tools/provenance/demo-boundary-negative.sh` | `d629d7ff34b238e6…181e1f975a` | `fc37fcc28e7f9601…c4efa033` | **ACCEPTED** |
| `.github/workflows/provenance.yml` | `85e2123216dc3993…a38c0a136` | `1768f4d56fe56e9b…cb7edbf72` | **ACCEPTED** |

Notably **`tools/provenance/run-all.sh` is byte-identical** (`b4a373abd3e18afc…`)
to the audit entry, as are `inspect-runtime-surface.sh` (`c653a62a…`),
`foundry.toml` (`47b290cd…`) and all five `src/**` + eight `test/**` files. A
`git diff` against `HEAD` shows `run-all.sh` as modified, but that hunk belongs
to the **Sprint-2 baseline**, not the remediation — the hash proves it.

### 2.1 Two of the four pre-images were reconstructed byte-exactly

Rather than trust the report's description of what changed, the audit-entry
pre-image was reconstructed from the current file by reverting only the claimed
edits, then hashed against the audit's recorded value:

| File | Reverted | Reconstructed pre-image | Matches audit entry |
|---|---|---|---|
| `.github/workflows/provenance.yml` | job name, probe-12 comment block, toolchain step, planting comment | `85e2123216dc3993ffcad06a8ff1a8db654dbcf6cd46d2de528beb2a38c0a136` | **YES — exact** |
| `tools/provenance/verify-census.sh` | header comment line, 4 detector comment lines, `grep -iE` → `grep -E` | `39d721f95ed4a892d60f30290c4ee399381171e5a3cc57cedacad0d17c3b88a0` | **YES — exact** |

This is the strongest available evidence and it settles two questions
definitively:

- **`verify-census.sh`'s remediation is exactly one functional token** (`-E` →
  `-iE`) plus comments. Nothing else changed in that file.
- **`.github/workflows/provenance.yml`'s remediation added only the pinned
  toolchain step and comments.** In particular the top-level `FOUNDRY_PROFILE: ci`
  env entry — which `git diff` against `HEAD` also surfaces — was **already
  present in the audited subject** (it survives in the reconstructed pre-image,
  and is independently corroborated by `reviewer.md:378` and pass-1
  `engineer-feedback.md:72`, both written before the remediation). The report's
  claim "No other job, permission, trigger or pin was touched" is **accurate**.

### 2.2 `census.sh` — functional delta is provably one token

`census.sh`'s pre-image could **not** be reconstructed byte-exactly: the report
describes its comment changes by line range rather than by content, and the
audit-entry file is not preserved anywhere. Recorded as an evidence limitation
(§13, informational), **not** a finding — because the functional question is
answerable directly. Stripping comments and blank lines from `HEAD`'s version and
from the current version gives the complete executable delta across *both*
Sprint-2 and the remediation:

```
-SOURCE_UNIVERSE_PRUNE=(.git out ... .claude grimoires .beads .run .ck)
+BUILD_ARTIFACT_PRUNE=(.git out out-v3core cache cache-v3core broadcast)
+LOA_ZONE_PRUNE=(.claude grimoires .beads .run .ck)
+SOURCE_UNIVERSE_PRUNE=("${BUILD_ARTIFACT_PRUNE[@]}" "${LOA_ZONE_PRUNE[@]}")
-  find . ... -name  '*.sol' -print
+  find . ... -iname '*.sol' -print
+loa_zone_solidity() { ... }
```

The prune split and `loa_zone_solidity()` are the **Sprint-1 N-1 closure**, part
of the audited baseline (`auditor-sprint-feedback.md` reviewed them). The
remediation's entire executable contribution to `census.sh` is
**`-name` → `-iname` at `census.sh:205`**. `VUX_SOURCE_ROOTS`,
`census_*`, `classify_sources`, `vux_owned_sources` and `grep_sources` are
untouched.

---

## 3. A-1 closure result — **CLOSED**

The defect: `source_universe()` (`census.sh:205`) defined the canonical Solidity
universe case-sensitively while `loa_zone_solidity()` (`census.sh:227`) asserted
its exemption case-insensitively, making the primary default-deny universe
*narrower* than the conditional exemption it guards. Because
`classify_sources()` (`census.sh:232`) and every downstream consumer —
`all_sources` (`verify-census.sh:83`), `vux_owned_sources()` (`census.sh:253`),
feeding `verify-spdx.sh:69` and `verify-quarantine.sh:41`) — derive from that one
walk, a mis-cased file was invisible to **every** gate simultaneously.

**Verified closed at the root**, not per-consumer: `census.sh:205` now reads
`-iname '*.sol'`, and it is the single universe definition. Every `*.sol`
matcher in `tools/` and `.github/` was enumerated to confirm no second,
still-case-sensitive universe survives:

| Location | Matcher | Disposition |
|---|---|---|
| `census.sh:205` `source_universe()` | `-iname` | **fixed — the universe** |
| `census.sh:227` `loa_zone_solidity()` | `-iname` | unchanged (was already correct) |
| `demo-boundary-negative.sh:150` donor selector | `-name` | **correct as-is** — selects a known-authorized census row for a probe; not a universe definition, and vendor/ is entirely lowercase |

No other `*.sol` matcher exists in the tooling.

**Direction of the remaining case-sensitive comparisons was checked, not
assumed.** `classify_sources()`'s root test (`census.sh:239`,
`[[ "$p" == "$root"/* ]]`) and the Miner allowlist inversion
(`verify-census.sh:170`) are both case-*sensitive*, and both fail **closed**: a
`SRC/Foo.sol` or a `vendor/…/Rig.SOL` misses the authorization pattern and is
reported, not exempted. That is the correct asymmetry.

---

## 4. `verify-census.sh` case-insensitive filename detector — **disposition A: necessary completion**

The remediation changed `grep -E` → `grep -iE` on the `UniswapV3Factory.sol`
filename detector (`verify-census.sh:146`). This exceeds the audit's literal
suggested diff. **Judged on the invariant and tested by mutation, it is
necessary — not broadened behaviour.**

The implementation's argument is that once the walk is case-insensitive, a
`UniswapV3Factory.SOL` inside a **declared source root** is classified `vux`
(legitimately — it *is* inside a declared root), so default-deny does not fire
and this filename detector is the only remaining check. Tested independently
rather than accepted:

**Probe P5 — reviewer-authored, planted in `script/` (a declared root):**

```
--- P5 UniswapV3Factory.SOL inside authorized root script/  (exit 1) ---
    FAIL  UniswapV3Factory.sol implementation present — excluded by refreeze §8:
          source universe: 78 Solidity file(s) — 63 vendored, 15 VUX-owned
```

The `15 VUX-owned` count confirms the probe was classified **authorized** —
default-deny did **not** fire, and no `unauthorized Solidity source` FAIL line
appears. The filename detector fired **alone**. The isolation is real, not
incidental.

**Mutation M2 — regress only that one token, prove the mutant landed, re-probe:**

```
  ok    [M2] mutation landed
          before: 146:factory_files="$(printf '%s\n' "$all_sources" | grep -iE '(^|/)UniswapV3Factory\.sol$' || true)"
          after : 146:factory_files="$(printf '%s\n' "$all_sources" | grep -E  '(^|/)UniswapV3Factory\.sol$' || true)"
          sha256 2530dcd9f2b61856 -> fe88f6ae34d6e00e
          probe script/UniswapV3Factory.SOL   -> PASSES (fence OPEN) — -iE is NECESSARY
          probe script/UniswapV3Factory.sol   -> fails closed (lowercase path unaffected)
  ok    restored tools/provenance/verify-census.sh — sha256 2530dcd9f2b618564c5af1a709e27a62dca84fff93632f8d14f0c9f8cf82dee5 matches the subject exactly
```

Without `-iE`, `script/UniswapV3Factory.SOL` passes **every gate**. With it, the
gate fails closed. The A-1 class is only closed with this change; fixing the walk
alone would have left a mis-cased excluded implementation authorized-and-unseen.

**False-positive control (P6).** `-iE` could over-match the *authorized*
`IUniswapV3Factory` interface. It does not — the `(^|/)` anchor is unaffected by
case folding:

```
--- P6 authorized interface name, .SOL (false-positive control)  (exit 0) ---
```

`script/IUniswapV3Factory.SOL` planted → gate green. And M2's second probe shows
the pre-existing lowercase path behaves identically before and after. The change
**widens detection on exactly one axis and changes nothing else**.

**Verdict: A — necessary completion of the same A-1 class closure. ACCEPTED.**

---

## 5. Fresh mixed-case negative probes — reviewer-controlled

Written from scratch in the scratchpad, with reviewer-chosen names, locations and
casings. Nothing sourced from `demo-boundary-negative.sh`.

| Probe | Path | Casing | Expected gate + reason | Result |
|---|---|---|---|---|
| P1 | `ReviewProbeAlpha.SOL` | `.SOL` | `verify-census` / unauthorized source | **failed closed** |
| P2 | `docs/review-probe-bravo.SoL` | `.SoL` | `verify-census` / unauthorized source | **failed closed** |
| P3 | `grimoires/loa/review-probe-charlie.sOl` | `.sOl` | `verify-census` / pruned Loa/state zone | **failed closed** |
| P4 | `script/ReviewProbeEcho.SOL` (prohibited content, **inside a declared root**) | `.SOL` | `verify-census` / prohibited-source reference **in isolation** | **failed closed** |
| P5 | `script/UniswapV3Factory.SOL` (**inside a declared root**) | `.SOL` | `verify-census` / factory detector **in isolation** | **failed closed** |
| P6 | `script/IUniswapV3Factory.SOL` | `.SOL` | **must not fire** | **green — no false positive** |

Each failure was confirmed to be for the intended **boundary** reason by matching
the `FAIL`-prefixed line, not merely by exit code (see L-3, §12).

**P4 is a strictly stronger probe than the implementation's probe 11.** Probe 11
plants in `contracts/`, an *unauthorized* location, so default-deny and the
prohibited-source detector both fire and the probe cannot distinguish which one
caught it. P4 plants inside `script/`, so the file is classified `vux`
(`15 VUX-owned`), default-deny cannot fire, and the **only** FAIL line is:

```
    FAIL  prohibited-source reference in Solidity sources:
```

This proves the §8 prohibited-source scan genuinely recovered its reach over
mixed-case Solidity — the audit's stated caveat that A-1 "slightly overstates the
reach claimed in the PROV-5 evidence §4" is closed on evidence.

**The standing demonstration was also run in full:** `demo-boundary-negative.sh`
→ **exit 0**, 11 probes + probe 12, working-tree inventory identical before and
after (`ca5a02196dfca945…`), all three gates green again at exit.

---

## 6. Positive build-reachability control — **VALID**, and independently reproduced

This is the load-bearing item: Sprint-1's N-2 conclusion failed here, so the
control was audited rather than run.

**The control's method is sound.** `demo-boundary-negative.sh:288-380` builds a
throwaway Foundry project in `mktemp -d` **outside the repository** (so a
compiler run cannot perturb the inventory hash the demonstration depends on), and
takes its verdict from two compiler-authoritative facts — solc's own
`metadata.sources` record, and an executed deployment. It reads **no** resolver
output as evidence; the `Unable to resolve imports` string is *printed* beside a
passing execution and never consulted. That juxtaposition is the retraction's
evidence, and it is the correct construction.

**Independently reproduced with a reviewer-chosen casing (`.SoL`, not `.SOL`),
reviewer-chosen content, and reviewer-written artifact inspection.** Three
independent lines of evidence, none of them a resolver diagnostic:

**(a) solc recorded it as compiled source.**

```
importer metadata.sources: ['src/ReviewerReach.SoL', 'test/ReviewerReach.t.sol']
```

**(b) The mixed-case file's compiled program bytes are physically embedded in the
importer's creation code.** An identical copy named `.sol` was compiled in a
*separate* project and its metadata-stripped program compared byte-for-byte:

```
.sol-compiled ReviewerReach program length: 358
that exact program is embedded in the .SoL importer's creation code: True
```

**(c) It executes.** A `require` on the deployed instance's return value, no
`forge-std`, no harness — a pass can only mean CREATE + CALL succeeded:

```
[PASS] test_MixedCaseSoLExecutes() (gas: 74398)
```

**The control is stronger than the report claims, and the reason matters.**
Foundry emitted **no standalone artifact** for the `.SoL` file, and its
build-info `source_id_to_path` lists only `test/ReviewerReach.t.sol`. The
lowercase control printed `Unable to resolve` **0 times**; the mixed-case one
printed it alongside `Compiler run successful!` in the same run. So Foundry's
*discovery and artifact layer* does not see the file while *solc* compiles,
embeds and executes it. That is precisely the trap N-2 fell into, demonstrated
from the tool's own output. **The N-2 retraction is correct and the premise
behind probes 8-11 is proven, not inferred.**

---

## 7. Mutation-test falsification — assessed against all six required properties

**Finding first: there is no *standing* falsification harness in the subject.**
The falsification recorded at `reviewer.md:695-710` was a one-time manual act
during implementation; the artifact records the flip verdicts but not the
proof-of-mutation step it claims to have performed. Under the very lesson this
node extracted — a mutation test is meaningless unless it proves the mutation
landed — a verdict transcript is not self-evidencing. **It was therefore
reproduced by the reviewer, with proof-of-mutation, rather than accepted.**

Reviewer harness result (M1, regressing the universe walk):

```
  ok    [M1] mutation landed
          before: 205:  find . ( ... ) -prune -o ( -type f -o -type l ) -iname '*.sol' -print
          after : 205:  find . ( ... ) -prune -o ( -type f -o -type l ) -name  '*.sol' -print
          sha256 63e8ec9d21fd4056 -> 4c96bacffd306dac
          probe ReviewProbeAlpha.SOL                     -> PASSES (fence OPEN)
          probe docs/review-probe-bravo.SoL              -> PASSES (fence OPEN)
          probe grimoires/loa/review-probe-charlie.sOl   -> fails closed
          probe script/ReviewProbeEcho.SOL               -> PASSES (fence OPEN)
          probe script/UniswapV3Factory.SOL              -> PASSES (fence OPEN)
  ok    restored tools/provenance/census.sh — sha256 63e8ec9d21fd40568db90bc3345a520b8aefe2dab1ae394395664c14bebf8533 matches the subject exactly
```

| Required property | How it was satisfied |
|---|---|
| proves the mutation anchor is unique | `grep -cE <anchor>` asserted `== 1` before any edit; a non-unique anchor aborts the mutation |
| asserts the regressed content actually changed | the old anchor asserted **absent** after `sed`; before/after lines echoed verbatim; sha256 printed `63e8ec9d… -> 4c96bacf…` |
| runs the detector against that mutated state | all five probes re-planted and `verify-census.sh` re-run under the mutant |
| records which probes flip | table above — 4 flip to `fence OPEN`, 1 does not |
| restores the original file by hash | restored from a pristine pre-mutation copy, not by reverse-`sed` |
| proves exact restoration | sha256 asserted equal to the subject hash `63e8ec9d…bebf8533`; working-tree inventory asserted identical (`ca5a02196dfca945…`) |

**The flip pattern independently reproduces the implementation's.** Probe P3
(pruned Loa zone, `.sOl`) correctly does **not** flip: it is reached by
`loa_zone_solidity()`, which was already `-iname`. That asymmetry *is* finding
A-1 observed from the other side — the same result the implementation reported
for its probe 10, obtained here with entirely different probes.

The `-iname` fix is therefore **non-vacuously proven**: four independent
mixed-case evasions are live without it and closed with it. M2 (§4) does the same
for the `-iE` detector change.

---

## 8. Source-root / default-deny invariant — UNCHANGED. Detection widened, authority did not.

```
153:VUX_SOURCE_ROOTS=(src test script)
175:BUILD_ARTIFACT_PRUNE=(.git out out-v3core cache cache-v3core broadcast)
176:LOA_ZONE_PRUNE=(.claude grimoires .beads .run .ck)
```

| Invariant | Result |
|---|---|
| `VUX_SOURCE_ROOTS` exactly `src test script` | **YES** — byte-identical; present unchanged in both reconstructed pre-images and the current file |
| No new source root | **YES** |
| No new exemption | **YES** — `docs/`, repository root and the Loa zones all fail closed (P1, P2, P3) |
| `BUILD_ARTIFACT_PRUNE` unchanged | **YES** |
| `LOA_ZONE_PRUNE` unchanged | **YES** |
| All current Solidity classified | **YES** — `77 Solidity file(s) — 63 vendored (census), 14 VUX-owned` |
| Unauthorized Solidity fails closed regardless of extension casing | **YES** — P1/P2/P3 across `.SOL`, `.SoL`, `.sOl` |
| Prohibited-source scans consume the widened universe | **YES** — proven **in isolation** by P4 |

The classified universe is **77 files, 63 + 14** — identical to the audited
count. The fix widened the *predicate* over the same tree and caught the same
files, because none of them was mis-cased. **No authorization expanded.**

---

## 9. CI workflow — pinning intact, scope minimal, fail-closed preserved

| Check | Result |
|---|---|
| Pinned Foundry identity is the accepted one | **YES** — `foundry-rs/foundry-toolchain@82dee4ba654bd2146511f85f0d013af94670c4de # v1.4.0` with `version: ${{ env.FOUNDRY_VERSION }}`, byte-identical to the pins already at `provenance.yml:43` (gates) and `:69` (drift demo) |
| `FOUNDRY_VERSION` unchanged | **YES** — `v1.0.0` (refreeze §6); the gate job's toolchain-identity assertion at `:56` is untouched |
| No mutable/unpinned toolchain introduced | **YES** — every `uses:` in the file is a 40-char commit SHA; `verify-pins.sh` re-confirms `every GitHub Action pinned to a 40-character commit` |
| No unrelated CI scope changed | **YES — proven by pre-image reconstruction** (§2.1): reverting only the job name, the probe-12 comment block, the toolchain step and the planting comment reproduces the audit-entry hash `85e2123216dc3993…` exactly. No trigger, permission, job or other env entry moved. The top-level `FOUNDRY_PROFILE: ci` predates the remediation. |
| Workflow remains fail-closed | **YES** — the demonstration step is an unconditional `run:`, no `continue-on-error`, and `demo-boundary-negative.sh` exits non-zero on any probe failure |

The justification is sound: the job's prior comment claimed "the source-boundary
gates never invoke the compiler", which probe 12 makes false. Adding the pinned
compiler to that job is the minimum change that keeps the comment honest.

---

## 10. Complete regression — GREEN

`bash tools/provenance/run-all.sh` → **exit 0**. Both compilation units built,
all 8 gates green, full suite run.

| Claim | Result |
|---|---|
| Complete provenance run green | **exit 0**, 8/8 gates |
| Sprint-2 tests green | **61 passed / 0 failed / 0 skipped**, 6 suites |
| Product-source hashes unchanged | **YES** — §12 |
| 63/63 vendored identities unchanged | **YES** — `63/63 vendored files byte-identical`; counts exactly OZ 28 / v3-core 32 / Miner 3 |
| Canonical pool init-code hash unchanged | **YES** — `POOL_INIT_CODE_HASH reproduced and equal to the accepted constant`, `accepted: 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`, pool compiled by `0.7.6+commit.7338295f` |
| No new dependency | **YES** — `remappings.txt` unchanged at 2 entries |
| No forge-std | **YES** — `lib/` does not exist |
| No authority artifact drift | **YES** — `4 accepted authority artifacts match their recorded SHA-256`; `THIRD_PARTY_NOTICES.md matches the accepted baseline SHA-256` |
| No Sprint-3+ implementation | **YES** — the 18-file subject contains no new Solidity; `src/` is still `VUX.sol`, `HardReserve.sol`, `interfaces/IVUX.sol` |

Runtime-surface gate unchanged: `exactly one state-changing function: redeem`,
`no payable function`, `no receive() and no fallback()`, `no burnFrom in the
dispatcher table`, `HardReserve external surface is exactly the accepted set`,
`VUX external surface is exactly the accepted set`, sanitization marker present
in creation bytecode. SPDX gate: `14 VUX-owned Solidity file(s) match the PROV-8
SPDX policy`, `63/63 vendored files retain their upstream SPDX verbatim`. §17
quarantine: all 10 guidance values clean. Launch hygiene: clean.

**Environment note (not a finding).** The local toolchain is
`forge 1.5.0-stable`, whereas the accepted pin is `v1.0.0`. The pin is asserted
by the CI workflow (`provenance.yml:56`), not by the local scripts, so local
runs do not enforce it. This is a pre-existing Sprint-2 condition, identical for
the pass-1 review and the audit, and unchanged by the remediation. CI remains the
authority for toolchain identity.

---

## 11. Findings by severity

### 0 critical / 0 high

### MEDIUM

#### M-1 — the universe predicate is still extension-keyed, so the *extension* axis evades exactly as the *case* axis did

**Not a regression, not in A-1's scope, and not a blocker for this node** — see
the disposition below. Recorded because it is the same structural class as A-1
and the reviewer found it while probing the fix.

`census.sh:205` closes the *case* axis (`.sol` / `.SOL` / `.SoL`). The predicate
is still `-iname '*.sol'`, so a Solidity file carrying any other extension is
invisible to the same set of gates, for the same reason, and is build-reachable
by the same mechanism. Demonstrated, not asserted:

```
docs/ReviewerExtensionProbe.txt   (Solidity, containing "Olympus, gumball6900, give.fun")
  -> verify-census.sh PASSES with the probe present — the universe does NOT see it
```

and the file really compiles and runs, by the same compiler-evidence method as §6:

```
[PASS] test_X() (gas: 68184)
  metadata.sources: src/ExtReach.txt
  metadata.sources: test/ExtReach.t.sol
```

So a prohibited-source copy in `docs/` named `.txt` currently passes every gate
while being fully compilable via an explicit import from a declared root — the
identical shape as A-1 and as Sprint-1 N-1, on a third axis.

**Severity MEDIUM**, graded consistently with the audit's own grading of A-1 and
for the same reasons it gave: no such file exists in the tree (`77 files
classified`, all gates green), no deployed byte is affected, and weaponising it
requires a second plainly-visible act — an `import` edit inside `src/`. It is a
defence-in-depth gap, not a live vulnerability.

**Disposition: DISCLOSED, NOT BLOCKING.** The operator dispatched a bounded node
scoped to A-1; the audit's A-1 write-up (`auditor-sprint-feedback.md:440-518`)
addresses only extension **case** and prescribes exactly the two changes the
implementation made. This residual pre-dates the remediation, was not worsened by
it, and closing it is a design decision — not a defect in this node's work.
Blocking on it would be the perfection loop the node boundary forbids. It is
carried to the exact-tree re-audit as disclosed context and is a candidate for a
future bounded node, exactly as A-1 itself was handled. See §14 for the design
option.

### LOW

#### L-3 — `expect_fail`'s reason regexes also match the corresponding PASS lines

`demo-boundary-negative.sh:96-103`. `expect_fail` requires a non-zero exit **and**
that the output match a reason regex. But `'unauthorized Solidity source'` is a
substring of the success line `pass "zero unauthorized Solidity source anywhere
in the repository"` (`verify-census.sh:95`), and `'pruned Loa/state zone'` is a
substring of `pass "zero Solidity in the pruned Loa/state zones …"`
(`verify-census.sh:120`). So for probes 1, 5, 8, 9, 7 and 10 the reason check
degenerates to "the gate failed for *some* reason" — the assertion is weaker than
it reads. This reviewer hit the same trap building the probe harness; it was
caught only by anchoring on the `FAIL`-prefixed line.

**Fix:** anchor the reason on the failure prefix, e.g.
`grep -qE "^FAIL  $reason"` (or pass the `FAIL` prefix in each call site's
regex). Non-blocking — the M1 flip evidence shows the probes are non-vacuous in
practice, and each detector was independently confirmed to fire in isolation
(§4, §5).

#### L-4 — the `-iE` filename detector change has no standing negative probe

`verify-census.sh:146` was changed, but `demo-boundary-negative.sh` gained no
probe for it. Probe 2 covers `contracts/impl/UniswapV3Factory.sol` (lowercase,
unauthorized location, caught by default-deny anyway); nothing covers
`UniswapV3Factory.SOL` **inside a declared root**, which is the only case the
change exists for. The audit's instruction was to add an uppercase probe so the
negative control can see a regression; that was done for the walk (probes 8-11)
but not for the detector the implementer chose to change. Verified here only by
reviewer-controlled P5/M2, which do not persist in CI.

**Fix:** add a probe planting `script/UniswapV3Factory.SOL` and asserting
`UniswapV3Factory\.sol implementation present` — 4 lines, same shape as probe 8.
Non-blocking, but it is the one changed line in the subject with no standing
regression guard.

### Informational

- **I-1 — `census.sh`'s audit-entry pre-image is not third-party reconstructible.**
  `reviewer.md:610-616` describes its comment changes by line range rather than
  by content, and the pre-image is not preserved. `provenance.yml` and
  `verify-census.sh` were reconstructed byte-exactly; `census.sh` was not. The
  functional question is settled by other means (§2.2 — the executable delta is
  one token), so this affects auditability of the *narrative*, not of the
  behaviour. Recording the pre-image hash **and** the exact diff text, as the
  other two files effectively allowed, would close it.
- **I-2 — probe 11 does not isolate the prohibited-source detector.**
  `demo-boundary-negative.sh:279-285` plants under `contracts/`, an unauthorized
  location, so default-deny fires too. Reviewer probe P4 (planted in `script/`)
  is the isolating form and confirms the detector genuinely recovered. Subsumed
  by L-3's fix if the reason anchor is tightened.

---

## 12. Product-source hash result — UNCHANGED

```
5686c4c7c353711998eccb3693bda44d9ab0352ed79d69a1b853447dc5197349  src/VUX.sol
74b8319ab155225b4533790b88d3adc71c8da117ff74d4124e180f3bd39f2c17  src/HardReserve.sol
3910bf9d440a1755cd6bad3e0e7975ad0a1adb9a0f5a4b0e91ee9391ed83eb24  src/interfaces/IVUX.sol
```

Byte-identical to the audit-subject table. All eight `test/**` files likewise
byte-identical. **No Solidity was written, edited or deleted by the remediation.**
The 7/7 acceptance criteria verified at pass 1 are undisturbed — no product code
and no test changed, so the AC evidence and the 61/61 suite behind them stand
exactly as recorded.

---

## 13. Known LOW residue — deliberately not reopened, verified not worsened

Per the node's doctrine these were **not** re-litigated. They were checked only
to confirm the remediation did not silently touch them:

| Finding | Check | Observed |
|---|---|---|
| **L-1** stale `ReserveSurface.t.sol` comment pointers | `grep -n ReserveSurface.t.sol src/HardReserve.sol` | still 2 hits, `:31` and `:100` — **unchanged** |
| **L-2** `forge fmt --check` residue | `forge fmt --check` | same 4 files still differ (`src/HardReserve.sol`, `test/harness/Harness.t.sol`, `test/reserve/HardReserveRedemption.t.sol`, `test/reserve/HardReserveSurface.t.sol`) — **unchanged** |
| **R-1** `BUILD_ARTIFACT_PRUNE` not assertion-covered | `census.sh:175` | byte-identical — **unchanged** |
| **R-2 … R-6** | not touched | audit disposition stands |

No perfection loop occurred. None of these is reopened by this review.

---

## 14. Adversarial Analysis

### Concerns identified

1. **`tools/provenance/census.sh:205` — the universe predicate is extension-keyed,
   so A-1's class is closed on the case axis only.** A `.txt` Solidity file in
   `docs/` evades every gate and still compiles and executes (M-1, §11, with a
   reproduction). The design property asserted at `census.sh:148-152` — "neither
   relocating source nor re-casing its extension can move it out of any gate's
   reach" — is now true as written, but narrower than the property a reader will
   assume it guarantees.
2. **`tools/provenance/demo-boundary-negative.sh:96-103` — the negative control's
   "failed for the right reason" assertion is weaker than it reads** (L-3): the
   reason regexes match the corresponding PASS lines.
3. **`tools/provenance/verify-census.sh:146` — the one changed detector line has
   no standing probe** (L-4). The remediation added four probes for the walk and
   zero for the detector it also changed.
4. **`tools/provenance/demo-boundary-negative.sh:279-285` — probe 11 conflates
   default-deny with the prohibited-source detector** (I-2); it cannot show which
   one caught the probe.
5. **`tools/provenance/demo-boundary-negative.sh:150` — the donor selector remains
   `-name`.** Correct today (vendor/ is entirely lowercase, and it selects an
   authorized row rather than defining a universe), but it is now the only
   `-name` left in the tooling, and a future mis-cased vendored row would make it
   select nothing and abort with `no vendored donor file found` — a confusing
   setup failure rather than a boundary failure. Worth a one-line comment or
   `-iname`.

### Assumption challenged

- **Assumption:** widening the predicate to `-iname` is safe because "a wider net
  over the same tree catches the same 77 files, because none of them was
  mis-cased" (`reviewer.md:664-666`).
- **Risk if wrong:** a legitimately-named file newly caught by the wider net
  would be classified `unauthorized` and break a green gate — a false positive.
- **Validated, not accepted:** the classified universe is `77 Solidity file(s) —
  63 vendored (census), 14 VUX-owned` both before and after, and the census
  completeness assertion (`all 63 accepted census rows present`) still passes, so
  nothing was reclassified. The false-positive surface introduced by `-iE` was
  separately probed (P6, the authorized `IUniswapV3Factory` name) and is empty.
  The assumption holds and is now evidenced rather than argued.

### Alternative not considered

- **Alternative:** derive the source universe — or a cross-check on it — from the
  **compiler's own record** rather than a filesystem extension predicate: assert
  that every path in every artifact's `metadata.sources` is a classified file.
  Probe 12 already reads exactly that field, so the machinery exists.
- **Tradeoff:** it closes the case axis, the extension axis and any future naming
  axis structurally, because it asks the compiler what it compiled instead of
  guessing from names. But it sees only what the build reaches — a dormant
  unauthorized file that nothing imports would be invisible. It is a
  **complement** to the filesystem walk, not a replacement.
- **Verdict:** the current approach is justified for this bounded node — A-1 was
  scoped to case, and the one-token fix is the minimal correct closure. The
  compiler-derived cross-check is the natural shape for M-1 and is the
  recommended design starting point if the operator scopes a node for it.

### Escalation

Not triggered. The MEDIUM, both LOWs and both informational items are
non-blocking and individually addressable; none requires a return to
`/implement sprint-2`.

---

## 15. Retrospective separation — independently confirmed

Verified from repository state, not from `reviewer.md`:

```
{ git diff --name-only HEAD; git ls-files --others --exclude-standard; }
  | grep -v -E '^(grimoires/|\.beads/|\.run/)'
  -> exactly 18 paths — the implementation subject, and nothing else
```

The `/retrospective --scope implementing-tasks` run therefore mutated **zero**
implementation, source, test, provenance, CI, vendor or evidence surface. The
decisive check is the digest itself: the subject computed **after** the
retrospective is `a6313a4d5a…2b772cf`, exactly the digest the implementation
recorded **before** it. Learning-state capture is fully disjoint from the subject.

Both extracted skills live in the State zone —
`grimoires/loa/skills-pending/verify-the-mutant-not-the-verdict/` and
`grimoires/loa/skills-pending/recover-digest-convention-from-published-components/`.
**Neither was reviewed or promoted here**, per the node's instruction; only their
containment was verified.

---

## 16. Files mutated by this review

Exactly two files, both in the State zone:

| Path | Zone | Change |
|---|---|---|
| `grimoires/loa/a2a/sprint-2/engineer-feedback.md` | State | this pass-2 report prepended; the complete pass-1 review preserved verbatim below |
| `grimoires/loa/a2a/index.md` | State | sprint-2 review/status columns updated to the pass-2 verdict (native review-workflow output) |

`grimoires/loa/sprint.md` needed no change — its Sprint-2 checkmarks were set at
pass 1 and the remediation changed no product code or test, so the 7/7 AC
dispositions stand.

Reviewer probe scripts, the mutation harness and the two throwaway Foundry
projects were written to the session scratchpad, **outside the repository**.
Probes planted inside the repository (P1-P6 and `docs/ReviewerExtensionProbe.txt`)
were removed by exact path under an unconditional trap; `census.sh` and
`verify-census.sh` were mutated only inside the M1/M2 harness and restored from
pristine copies with sha256 equality asserted. The working-tree inventory hash is
identical before and after
(`ca5a02196dfca945eddb9498de619107479f5bd2efd68d9db3fb4253c624d82b`), and the
18-file subject digest is unchanged at `a6313a4d5a…2b772cf`.

**Not mutated:** source, tests, provenance tooling, CI, vendor, authorities,
dependencies, `reviewer.md`, `auditor-sprint-feedback.md`. No commit, push, tag,
branch or landing. `/audit-sprint` not invoked.

---

## 17. Previous feedback status

| Item | Status |
|---|---|
| Pass-1 review (APPROVED, 7/7 AC, 2 low) | **Preserved unedited below.** Its L-1/L-2 and R-1…R-6 remain open by design (§13) |
| Audit **A-1** (MEDIUM) | **RESOLVED** — structurally closed at the universe definition, proven by reviewer mutation testing (§3, §4, §7) |
| Audit **R-1, L-1, L-2** (LOW) | **Deliberately not addressed**, per node scope; verified unchanged (§13) |

---

## 18. Overall assessment

The remediation does the one thing it was dispatched to do, at the one place that
governs every consumer, and it proves the fix rather than asserting it. The
`-iE` filename-detector change is not scope creep: without it a mis-cased
excluded implementation sits inside a declared root and passes every gate — I
mutated that single token and watched the fence open. The positive
build-reachability control is the part that most deserved skepticism, given that
Sprint-1's N-2 failed on exactly this question, and it holds up under an
independent reconstruction that goes further than the original: the imported
file's compiled program bytes are physically embedded in the importer's creation
code, while Foundry emits no artifact for it and prints a resolver warning in the
same successful run. That is the clearest available statement of why a resolver
diagnostic is not reachability evidence.

Detection widened; authority did not. Same three source roots, same two prune
lists, same 77 classified files, same 63 vendored identities, same pool init-code
hash, same product bytes, 61/61 green, CI pinning intact.

The one MEDIUM I raise is a residual I found while probing the fix, on a
different axis, pre-existing and outside A-1's scope. Disclosing it and letting
the operator scope a bounded node is the same handling A-1 itself received; using
it to block a correct, narrowly-bounded remediation would be the perfection loop
this node explicitly forbids.

**APPROVED.**

## 19. Next steps

1. **Recommended next lifecycle node: audit-only Sprint-2 exact-tree re-audit** of
   subject `a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf`.
   Not invoked here.
2. Operator acceptance remains withheld until that re-audit returns.

**Carried to the re-audit as disclosed context:** M-1 (extension-axis residual,
MEDIUM), L-3, L-4, I-1, I-2, plus the untouched L-1, L-2 and R-1…R-6. None
requires a return to `/implement sprint-2`.

---
---

# ─────────── PRESERVED: pass-1 review (2026-08-11), verdict APPROVED ───────────

The complete first-pass review follows **verbatim and unedited**. It reviewed
subject `78c8881204…2ac45a` (pre-remediation) and is retained as historical
review evidence; where it and the pass-2 report above disagree, the pass-2
report is current.

# Sprint-2 Review — `VUX.sol` & `HardReserve.sol` (cycle-002, global = local sprint-2)

**Reviewer:** Senior Technical Lead (`/review-sprint sprint-2`)
**Date:** 2026-08-11
**Verdict:** APPROVED — 0 critical / 0 high / 0 medium / 2 low
**Prior feedback:** none — this is the first review pass for sprint-2.

## 1. Exact implementation subject reviewed

Base commit `79c966f6c55899489fdb9db176773ef69e6ecf62`; the entire Sprint-2
implementation is uncommitted working-tree state. SHA-256 of the subject at
review time:

```
5686c4c7c353711998eccb3693bda44d9ab0352ed79d69a1b853447dc5197349  src/VUX.sol
74b8319ab155225b4533790b88d3adc71c8da117ff74d4124e180f3bd39f2c17  src/HardReserve.sol
3910bf9d440a1755cd6bad3e0e7975ad0a1adb9a0f5a4b0e91ee9391ed83eb24  src/interfaces/IVUX.sol
b4a3e005a76d915c1d9dace6f4a54b97b40f303c1bc9b6f6f079a4c9e3f6faaf  test/token/VuxToken.t.sol
95ce221261afab1ca670bef29c6bef2c293642b9eb0085c366a92906589ad0b4  test/reserve/HardReserveRedemption.t.sol
1e36fa00c0eedc99bdba4b7edb53f635abaf9a870a35ede6997abec46b159b24  test/reserve/HardReserveSurface.t.sol
3f0b3ac7161070d16b619b23b9f6947cf8daf0aa8f7013d962ce795b51425f5a  test/reserve/ReserveFixture.sol
3d29a61312f679f635709c7eefcbc47af6cc48a0a60e37cf12b215704cff833b  test/mocks/MockWeth.sol
1cff3ef705eb3deec06f9544c0a2e7db0277a17dd42949396c12eb4278e1e183  test/harness/Artifact.sol
8cdf7ad5ce285f8af0c27eb1c14ab9dddb2928abcc9858991afb98f9e57f7523  test/harness/BaseTest.sol
297c15752e88d1ece393a7ea40cda3750686595174daee58263c38b566fa0cdb  test/harness/Vm.sol
8b9996456ff3b5ed6836ebb9c5c40617be4fbd446456833b8978bd04e9c09d7e  tools/provenance/census.sh
39d721f95ed4a892d60f30290c4ee399381171e5a3cc57cedacad0d17c3b88a0  tools/provenance/verify-census.sh
d629d7ff34b238e6cdd5cf49dd773a6edfd73ffc9caa15b7505057181e1f975a  tools/provenance/demo-boundary-negative.sh
c653a62a9b3add941428c4dbe9bfeac767c63f209a697d05ee9a9a73d0292f2c  tools/provenance/inspect-runtime-surface.sh
b4a373abd3e18afc05b65c416448ed4db5fd4747f65074d6c0c2252629a90045  tools/provenance/run-all.sh
47b290cdc75e512796538bc20a1de71cc8a12c0e7bede7c0ac7506651377703e  foundry.toml
85e2123216dc3993ffcad06a8ff1a8db654dbcf6cd46d2de528beb2a38c0a136  .github/workflows/provenance.yml
```

## 2. Retrospective-vs-implementation separation (verified before review)

`/retrospective --scope implementing-tasks` ran after `/implement sprint-2`. The
two are cleanly separated by mtime with **no overlap**:

| Window | Last mutation | Paths |
|---|---|---|
| Implementation subject | `09:56:27` (`.github/workflows/provenance.yml`) | `src/`, `test/`, `tools/provenance/`, `foundry.toml`, CI |
| Evidence artifacts | `09:59:09` | `a2a/sprint-2/evidence/**` |
| Lifecycle closure | `10:07:16` | `.beads/`, `ledger.json`, `a2a/index.md` |
| Implementation report | `10:15:55` | `a2a/sprint-2/reviewer.md` |
| **Retrospective** | **`10:32:19` – `10:36:45`** | `grimoires/loa/skills-pending/**`, `trajectory/*.jsonl`, `NOTES.md` |

No `src/`, `test/`, provenance-tool, CI, Foundry-config, vendor, or Sprint-2
evidence path carries a post-`10:15` mtime. The retrospective produced only Loa
learning/state artifacts, exactly as reported. The subject reviewed is the
subject the reported evidence was produced against — no re-verification of a
drifted tree was required.

## 3. Independent verification performed (not inherited from `reviewer.md`)

Foundry v1.5.0 (local; CI pins v1.0.0 and asserts it) plus reviewer-authored
Python/bash inspection:

- `FOUNDRY_PROFILE=ci forge test` — **61/61 pass**, fuzz depth **10,000 runs** on
  all six fuzz properties.
- `bash tools/provenance/run-all.sh` under `FOUNDRY_PROFILE=ci` (exact CI env) —
  all gates + tests green. CI-parity confirmed: `run-all.sh:21-22` builds both
  units before the gates, and `verify-init-code-hash.sh:16` pins
  `FOUNDRY_PROFILE=v3core`, so the workflow-level `ci` profile cannot leak into
  the frozen `=0.7.6` unit.
- **Reviewer-authored PUSH-aware opcode census** (independent Python, CBOR-validated
  metadata strip) over `.deployedBytecode.object`, reproducing the recorded figures
  exactly: `body=3199 create=0 callcode=0 delegatecall=0 create2=0 selfdestruct=0
  call=2 staticcall=5`.
- **Reviewer-authored dispatcher-table extraction** (PUSH4 immediates) for both
  contracts, plus raw-byte selector scan.
- `cast keccak 'PreGenesisWethSanitized(uint256)'` recomputed =
  `0x6e819700d501e9b84b099d0e58ba58b903458fcd121aeea3074dc83521a872a8`; topic
  present in creation bytecode, absent from runtime — confirmed by my own scan.
- **Four reviewer-controlled boundary probes** planted in `.beads/`, `.run/`,
  `grimoires/loa/` (top-level) and `grimoires/loa/deepprobe/nested/` (uppercase
  `.SOL`) — all blocked for the intended reason; clean tree green; working-tree
  inventory restored byte-for-byte (`c8f6ac8e…19b7d` before and after).
- `bash tools/provenance/demo-boundary-negative.sh` — 7/7 probes closed and
  reopened, inventory hash-verified.
- `forge fmt --check` (fast-gate parity) — see L-2.

## 4. Acceptance-criteria dispositions (7/7 met)

| AC | Disposition | Independent basis |
|---|---|---|
| **AC-1** INV-1…5 | ✓ Met | `src/VUX.sol:100-101` mints are structurally fixed constants with no parameter in the amount position; POL recipient is `msg.sender`, not an argument. Compiled ABI carries exactly one mint entry, gated at `src/VUX.sol:109`. Genesis log-set enumeration (`test/token/VuxToken.t.sol:92`) makes "zero elsewhere" universal, not a spot check. Total supply `150_000e18 + 1`. |
| **AC-2** `burnForRedemption` / no `burnFrom` | ✓ Met | See §5. |
| **AC-3** redemption property | ✓ Met | See §6. |
| **AC-4** Reserve external surface | ✓ Met | See §9. |
| **AC-5** constructor sanitization + runtime absence | ✓ Met | See §8 and §10. |
| **AC-6** third-party burn impossibility | ✓ Met | See §7. |
| **AC-7** PROV-5 | ✓ Met | `evidence/prov-5-similarity-review.md` carries the required statement, an enumerated not-consulted list, and a genuine post-hoc **structural** assessment (not a bare declaration) that separates specification-determined convergence from design-freedom divergence. Corroborated by a green `verify-census.sh` prohibited-source detector. Keeping prohibited project names out of `.sol` (they would trip the repository's own detector) is correct and is disclosed at `src/HardReserve.sol:41-43`. |

The `## AC Verification` section of `reviewer.md` is present, walks all seven
criteria verbatim, and every `file:line` claim I sampled resolved to the asserted
symbol. No `✗ Not met`, no `⏸ [ACCEPTED-DEFERRED]`, no vague evidence.

## 5. VUX immutable authority, genesis, and callable-surface result

Authority is exactly as accepted (`sdd.md` §1.4, §5.2.1): immutable `rig`
(`src/VUX.sol:82`), immutable `reserve` (`:85`), `mint` onlyRig (`:108`), `burn`
self-only (`:115`), `burnForRedemption` onlyReserve (`:123`). No setter, no
owner, no role, no pause, no upgrade. Base is `ERC20, ERC20Permit` only —
`ERC20Votes` and its `_afterTokenTransfer`/`_mint`/`_burn` overrides are gone,
and I verified the `@custom:modifications` notice (`:55-71`) line-by-line against
the vendored upstream `vendor/miner-manifold-bcffbf1e/contracts/Unit.sol`: every
claimed modification is accurate.  SPDX `MIT AND GPL-3.0-or-later` with the
`@custom:provenance miner-manifold` marker; the SPDX/notices gates are green.

**Genesis is structurally fixed, not discretionary.** The two mint amounts are
`constant`s and the POL recipient is `msg.sender`; the constructor's only
parameters are `rig_`/`reserve_`, neither of which appears in an amount position
nor in the POL recipient position. There is no constructor argument that could
turn a fixed allocation into a discretionary one.

**No callable general `burnFrom` — independently established.** I rejected the
text-search framing for the same reason the implementer did, and confirmed the
justification empirically: `out/VUX.sol/VUX.json` contains the ASCII string
`burnFrom` **exactly once**, in solc's `devdoc`, put there by the NatSpec at
`src/VUX.sol:31` that documents the deletion. Their method note is factually
correct, not merely plausible. The claim was therefore verified at the callable
surface:

| Signature | Selector | PUSH4 dispatcher table | Raw runtime bytes | Expected |
|---|---|---|---|---|
| `burnFrom(address,uint256)` | `79cc6790` | absent | absent | absent |
| `owner()` | `8da5cb5b` | absent | absent | absent |
| `delegate(address)` | `5c19a95c` | absent | absent | absent |
| `sweep(address)` | `01681a62` | absent | absent | absent |
| `burn(uint256)` | `42966c68` | **present** | present | **positive control** |
| `burnForRedemption(address,uint256)` | `db6b1b4f` | **present** | present | **positive control** |
| `mint(address,uint256)` | `40c10f19` | **present** | present | **positive control** |

The three positive controls prove the method detects selectors that genuinely
exist. The VUX runtime's PUSH4 set is exactly 20 function selectors plus the
`ffffffff` dispatch mask — a one-to-one match with the compiled ABI, so nothing
is routed that the ABI omits. I enumerated all 20 myself and confirmed each is
standard ERC-20, standard ERC20Permit (`permit`/`nonces`/`DOMAIN_SEPARATOR`/
`eip712Domain`), a protocol function named in `sdd.md` §5.2.1, or a read-only
`constant`/`immutable` getter. No inherited or introduced authority beyond normal
ERC20/ERC20Permit user functionality.

## 6. Redemption arithmetic and fuzz assessment

Ordering at `src/HardReserve.sol:157-172` is CEI and correct: `bPre`/`sPre` are
snapshotted before any effect; `payout = Math.mulDiv(bPre, q, sPre)` (three-arg
form = floor); burn commits before payout; `SafeERC20` makes a `false`-returning
transfer revert; the whole transaction is atomic. `nonReentrant` is present.
Zero fee — no fee term exists anywhere in the payout path.

**The two oracles are genuinely independent of `Math.mulDiv`, and I confirmed the
overflow-domain one is not the implementation in disguise.**

- Native domain (`HardReserveRedemption.t.sol:110`): `expected = (b * q) / s` in
  plain EVM `MUL`/`DIV`. Bounds `b ≤ 1e40`, `s ≤ ~1e30` keep `b*q` inside 256
  bits, so the oracle is arithmetic the code under test never touches. Rounding
  is bracketed both ways — `payout·s ≤ b·q < (payout+1)·s` — which pins *floor*
  specifically rather than merely "some truncation".
- Overflow domain (`:159`): `B = A·S + rem` with `rem < S`, so
  `floor(B·q/S) = A·q + floor(rem·q/S)`. This is exact integer algebra, computed
  natively, and it **never forms the overflowing product**. It shares no code
  path, no helper, and no algorithm with the 512-bit `mulDiv` under test — a bug
  in `mulDiv` cannot be mirrored by it. The overflow domain is **asserted**
  (`q > type(uint256).max / b`), not assumed. The companion
  `test_NaiveProductRevertsWhereRedeemSucceeds` (`:187`) supplies the
  discrimination proof: the same inputs make a plain 256-bit product revert while
  `redeem` returns the exact answer.

**The custom harness was audited, because a broken `bound` would make every fuzz
result vacuous.** `BaseTest.bound` (`test/harness/BaseTest.sol:98`) is
`min + (x % (max - min + 1))` with the correct `[0, type(uint256).max)` overflow
guard; the modulo bias is documented and compensated by dedicated boundary units.
Assertions revert with `AssertionFailed`, which Foundry counts as a failure — and
`test/harness/Harness.t.sol` contains an `AssertionProbe` meta-suite
(`test_FailingUintEqualityRevertsWithValues` et al.) that proves the assertions
actually fail when they should. There is deliberately no `assertApproxEq*`, so no
rounding regression can slip through a tolerance.

Boundary coverage is complete for the classes that matter: `q = 0` (`:381`),
`q = S − S_MIN` (`:249`, fuzzed), `q = S` rejected with `SupplyFloor(S, S-1)`
(`:237`), tiny `B` and payout-zero and floor-remainder (`:209`, `:110`), large
`B` (`1e40`), overflow product (`:159`), insufficient holder balance (`:282`),
and transfer-failure atomicity (`:337`).

**Exhaustive-redemption remainder — verified as a universal claim, not a sampled
one.** I derived it independently: after redeeming `q = S − 1`, the remainder is
`B − floor(B(S−1)/S) = ceil(B/S)`, which is `≥ 1` for every `B ≥ 1`. I checked
this identity numerically across six extreme `(B,S)` pairs including
`B = 1e40, S = 150000e18+1`; it holds exactly. The fuzz test's conclusion is
therefore true over the whole domain, not merely over sampled points, and
`S_MIN = 1` raw survives with a strictly positive WETH remainder.

I did **not** require `q > 0`; no accepted authority asks for it.

## 7. Third-party burn impossibility — end-to-end result

Proven at every layer, with no gap:

1. **Direct unauthorized call fails** — `burnForRedemption` reverts `NotReserve()`
   for every caller except the immutable `reserve` (`src/VUX.sol:124`), fuzzed
   over the address space (`test/token/VuxToken.t.sol:190`, 10,000 runs) and
   probed directly (`HardReserveRedemption.t.sol:310`).
2. **The Reserve's immutable code passes only `msg.sender`** —
   `src/HardReserve.sol:169`. `msg.sender` is not a parameter and is not derived
   from one. There is no second call site.
3. **Allowance/permit cannot redirect it** — `burnForRedemption` never consults
   `_allowances` (`src/VUX.sol:123-126`); `test_AllowanceDoesNotUnlockBurnForRedemption`
   (`VuxToken.t.sol:204`) and `test_RedemptionNeedsNoApprovalAtAnyPoint`
   (`HardReserveRedemption.t.sol:325`, allowance zero before *and* after) close it.
4. **A zero-balance attacker cannot drain a funded victim** —
   `HardReserveRedemption.t.sol:282`: the call reverts `ERC20InsufficientBalance`
   and the victim's balance is untouched.
5. **No alternate Reserve entry can select a victim** — the compiled dispatcher
   table has exactly one mutator (§9), so there is no other entry point to try.

## 8. Constructor sanitization result

`src/HardReserve.sol:112-122` reads the **actual pre-existing** balance, sends
the **entire** amount to `msg.sender` (a fixed same-transaction receiver with no
parameter that could misdirect it — the same structural choice the token makes
for its POL recipient), emits `PreGenesisWethSanitized(contaminated)`, then
**re-reads** and reverts `NotBornEmpty(residual)` unless the balance is exactly
zero. Exactness is never relaxed to `>=`.

The re-read is not decoration: `test_ConstructionAbortsIfTheReserveCannotBeBornEmpty`
(`HardReserveSurface.t.sol:136`) drives a token that reports success while moving
nothing and confirms construction aborts — the fee-on-transfer/rebasing shape.
Sanitization is fuzzed to `type(uint128).max` (`:91`, 10,000 runs), the event is
log-exhaustively proven **not** to fire on a clean deployment (`:120`) so it
genuinely distinguishes attacker donations from founder capital, and
`test_PrefundingCannotDistortTheGenesisBackingTarget` (`:160`) shows a
1,000,000-ether donation followed by a `B0` deposit lands the Reserve on exactly
`B0`. The one external call during construction is `balanceOf`/`transfer` on the
WETH address, whose result is verified rather than trusted.

No Sprint-7 genesis implementation was required or attempted here.

## 9. Exact Hard Reserve external surface

The compiled dispatcher table is exactly six entries — one mutator and five views
— which I enumerated from `out/HardReserve.sol/HardReserve.json` myself:

| Signature | Selector | Mutability | Origin |
|---|---|---|---|
| `redeem(uint256,address)` | `7bde82f2` | nonpayable | **the only state-changing function** — `sdd.md` §5.2.3 |
| `backing()` | `c9503fe2` | view | `sdd.md` §5.2.3 |
| `previewRedeem(uint256)` | `4cdad506` | view | `sdd.md` §5.2.3 |
| `weth()` | `3fc8cef3` | view | auto-getter, `public immutable` |
| `vux()` | `8ccba076` | view | auto-getter, `public immutable` |
| `S_MIN()` | `e46f4eb6` | view | auto-getter, `public constant` |

The five views are the two non-`redeem` entries named in `sdd.md` §5.2.3 plus the
two immutable identity getters and the `S_MIN` constant getter — every one
read-only and state-free. This is legitimate immutable exposure, not accidental
API expansion: none can move value, and §5.2.3's binding constraint ("NO other
state-changing function exists") is satisfied exactly.

Absent, confirmed at the compiled surface and — where a surface check alone would
be insufficient — at the opcode level: owner, AccessControl, pause, upgrade
(no `DELEGATECALL`), approve, sweep, arbitrary call, migration/successor (no
`CREATE`/`CREATE2`), `receive`, `fallback`, payable entry (constructor and
`redeem` both nonpayable; ABI payable scan empty), `selfdestruct`, generic
deposit, emergency principal withdrawal. The four call targets in the runtime are
exactly the legitimate ones: `balanceOf`, `totalSupply`, `burnForRedemption`,
`transfer`.

## 10. Runtime structural-absence assessment — the method itself was audited

I did not accept the printed census. I verified the inspection method against
each failure mode the review brief names, then reproduced the result with my own
tooling.

- **Strips compiler metadata correctly.** `Artifact.stripMetadata`
  (`test/harness/Artifact.sol:31`) derives the length from the two-byte
  big-endian CBOR suffix, so it works under `bytecode_hash = ipfs` or `none`. My
  independent implementation added a CBOR-map sanity check and computed the
  **same 53-byte tail** (3252 → 3199).
- **Does not read PUSH immediates as opcodes.** `Artifact.countOpcode` (`:48`)
  advances `op - 0x5f` bytes for `0x60..0x7f`; the awk twin
  (`inspect-runtime-surface.sh:154`) does the same. Both are correct for
  PUSH1…PUSH32, and my own PUSH-aware walk agrees on every count.
- **Has a positive control, of the right kind.** `CALL` and `STATICCALL` are
  asserted **present** (`HardReserveSurface.t.sol:203-206`; script `:169-170`),
  so a walk that silently scanned nothing would fail rather than "prove" absence.
  The event-topic check asserts presence in creation code before asserting
  absence in runtime (`:181`).
- **Guards against vacuous stripping.**
  `test_MetadataStrippingRemovesATailAndNotTheProgram` (`:219`) requires the
  stripper to remove something and leave >90% of the image; the script re-checks
  `body > 0` and `body < full` (`:165-166`).
- **Examines the deployed runtime, not creation code.**
  `.deployedBytecode.object` (`:57`). Creation code is read only for the
  positive control.
- **Not a comparison against a hard-coded "good" report.** The declared ABI sets
  in `inspect-runtime-surface.sh:33-38` are expectations diffed both ways against
  the jq-extracted live dispatcher table; drift in either direction fails. The
  opcode counts are computed, never asserted equal to a stored blob.
- **Two implementations that could not fail identically.** Solidity plus
  `Artifact.sol` versus jq plus awk, sharing no code. The event topic is
  recomputed from its signature with `cast keccak` (`:51`), so the constant
  cannot rot.

**The claim that actually matters is proven.** The audit target is not literal
absence of `CALL` — `redeem` must make one to pay WETH, and it does. It is that
the constructor's transfer-out authority does not survive as a discretionary
runtime path. That holds: the sanitization topic is present in creation bytecode
and absent from runtime (verified by my own raw-byte scan of both images), the
runtime contains zero `CREATE`/`CREATE2`/`CALLCODE`/`DELEGATECALL`/`SELFDESTRUCT`,
and the dispatcher exposes no entry point from which a transfer could be reached.
The two `CALL` sites are reachable only from inside `redeem`, whose burn source
is `msg.sender` and whose payout is bounded by `floor(B x q / S)`.

## 11. N-1 provenance closure and default-deny assessment

The sprint-1 LOW residue is genuinely closed, and closed as a *class* rather than
an instance. `census.sh:154-176` splits the old undifferentiated prune into
`BUILD_ARTIFACT_PRUNE` (generated, gitignored, not working-tree source) and
`LOA_ZONE_PRUNE` (git-trackable), and makes the second exemption **conditional**:
`loa_zone_solidity()` (`:185`) enumerates any Solidity-shaped file in those zones
and `verify-census.sh:106` fails closed with the reason spelled out.

Attacked structurally and mechanically:

- `VUX_SOURCE_ROOTS` is still exactly `src test script` (`census.sh:152`) — the
  Loa/state zones were **not** silently promoted to source. Confirmed in the live
  gate output: "source universe: 77 Solidity file(s) — 63 vendored (census), 14
  VUX-owned (roots: src test script)".
- The standing seventh probe (`demo-boundary-negative.sh`) fails closed for the
  intended reason and restores the working-tree inventory exactly.
- **My own probes**, independent of theirs, planted in `.beads/`, `.run/`,
  `grimoires/loa/`, and a deep-nested **uppercase `.SOL`** — all four blocked for
  the zone reason, clean tree still green, inventory hash identical before and
  after. The case-insensitivity claim is real.
- A new entry added to `LOA_ZONE_PRUNE` is covered automatically, because
  `loa_zone_solidity()` iterates that array — the bypass cannot be reopened by
  extending the Loa list. See R-1 for the narrower residual.
- All 14 VUX-owned Solidity files classify; zero unauthorized Solidity anywhere.

## 12. Provenance, vendor and pool-hash regression

Every Sprint-1 guarantee re-verified green in this session:

| Check | Result |
|---|---|
| Accepted authority artifacts | 4/4 SHA-256 match |
| OpenZeppelin v5.2.0 | exactly 28 files |
| Uniswap v3-core v1.0.0 | exactly 32 files |
| Miner Manifold @ `bcffbf1e` | exactly 3 files |
| Vendored byte identity | 63/63 identical |
| `POOL_INIT_CODE_HASH` | `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54` reproduced |
| forge-std | absent (probe 5 proves the fence catches it in `lib/`) |
| Unauthorized dependency / source-authority expansion | none |
| PRD §17 quarantine | green |
| Default-deny boundary | green — 7 standing + 4 reviewer probes |

New source is classified correctly: `VUX.sol` Miner-derived with
`MIT AND GPL-3.0-or-later` plus the `@custom:provenance miner-manifold` marker
(the SPDX gate enforces those as mutually implied); `HardReserve.sol` and
`IVUX.sol` VUX-original with plain `GPL-3.0-or-later`. `IVUX.sol` correctly
reproduces no declaration from the allowlisted `IUnit.sol`.

## 13. Sprint-3+ scope result

**Zero Sprint-3+ implementation.** No `Rig.sol`, no Dutch/KOTH settlement, no
VEM, no 80/8/12 routing, no `StrategicTreasury`, no POL/VYRF, no
`GenesisDeployer`, no `Lens`, no frontend/indexer, no operator-reserved value.
`GenesisDeployer` appears only in NatSpec prose explaining who the constructor's
creator will structurally be — documentation, not code. `IVUX.sol`, `MockWeth`,
the harness additions and `inspect-runtime-surface.sh` are each narrowly
necessary for Sprint-2 verification and are not scope creep: `IVUX` declares
exactly the two members `HardReserve` calls, and the `Vm.sol`/`BaseTest.sol`
changes are **purely additive** (43 insertions, 0 deletions), every addition
consumed by a Sprint-2 test.

## 14. Explicit review questions

### `to == address(0)` — disposition A: acceptable, non-blocking

`src/HardReserve.sol:155` is malformed-input rejection, not an authority gate. It
is static, depends on no address but the caller's own argument, on no protocol
state, and on no party's discretion. It blocks **no redemption that could
otherwise pay out**: under canonical WETH9 semantics `transfer(address(0), wad)`
credits the zero address, destroying the payout *after* the burn has already
committed; under OZ-ERC20 semantics it reverts anyway. In both cases the check
fails earlier on an operation that canonical WETH cannot usefully perform. It
therefore does not touch the accepted "no approval gate, pause, allowlist, or
discretionary block" property (`sdd.md` §1.4). Recorded as acceptable — and the
test discriminates correctly, asserting the specific `HardReserve.ZeroAddress`
selector (`HardReserveRedemption.t.sol:377`) rather than any revert, so deleting
the check would fail the test rather than silently pass.

### `redeem(0, to)` — permitted, non-blocking

No accepted authority requires `q > 0`, and I did not invent one. Behaviour is
inert: `payout = mulDiv(B, 0, S) = 0`, `_burn(msg.sender, 0)` moves nothing,
`safeTransfer(to, 0)` moves nothing, supply and backing are unchanged
(`HardReserveRedemption.t.sol:381` asserts exactly this). No accounting error and
no authority bypass — `nonReentrant` still engages and the burn source is still
`msg.sender`. No reentrancy issue. The only consequence is that a caller holding
no VUX can emit a zero-valued `Redeemed` log; that is log noise an indexer
filters on `q > 0`, not accounting ambiguity, and it is not a meaningful griefing
surface since the griefer pays full gas for zero effect. Treated as harmless
zero-value behaviour, as instructed.

### Custom events on `VUX.sol` — correct as-is

I checked the accepted event schema rather than assuming one. `sdd.md` §3.2
assigns **no** event to `VUX.sol`; ERC-20 `Transfer` from and to the zero address
already carries every supply change, and burn-cause attribution is explicitly
architected as the pairing of that `Transfer` with the causing contract's event
in the same transaction ("each burn site emits exactly one cause event in the
same transaction"). Declaring a VUX-specific event would *add* unrequested
surface. This is correct surface minimisation, not an omission. The Reserve's two
events match `sdd.md` §3.2 **field-for-field**, including indexing.

## 15. Adversarial Analysis

### Concerns identified

1. **Stale evidence pointers in a monetary-core file** — `src/HardReserve.sol:31`
   and `src/HardReserve.sol:100` both cite `test/reserve/ReserveSurface.t.sol`,
   which does not exist; the file is `test/reserve/HardReserveSurface.t.sol`.
   These two lines are the in-source pointer to the mechanical evidence for the
   load-bearing structural-absence claim, so an auditor following them finds
   nothing. See L-1.
2. **The formatter is not a gate, and the tree is not formatter-clean** —
   `forge fmt --check` exits 1 on `src/HardReserve.sol` (the `Redeemed`
   declaration at `:70-72`), `test/reserve/HardReserveRedemption.t.sol`,
   `test/reserve/HardReserveSurface.t.sol`, and the pre-existing Sprint-1
   `test/harness/Harness.t.sol:60-62`. See L-2.
3. **A read-only window exists between burn and payout** —
   `src/HardReserve.sol:169-170`. After the burn and before the transfer, `S` has
   fallen while `B` has not, so `backing()` and `previewRedeem()` transiently
   over-quote. `nonReentrant` blocks re-entering `redeem`, but it does not block
   a *view* read from a contract invoked during the payout. Unreachable today
   (canonical WETH has no transfer hook, and no other protocol contract exists),
   which is why this is non-blocking — but it becomes live the moment a Sprint-3+
   contract reads these views inside a settlement path. See R-2.
4. **The overflow-domain property fixes the denominator** —
   `test/reserve/HardReserveRedemption.t.sol:165`: `s` is constant across all
   10,000 runs of `testFuzz_PayoutIsExactWhenBTimesQOverflowsUint256`, and `b` is
   constructed as `a*s + rem` rather than sampled freely. The construction is
   sound — every `B` has a unique `(A, rem)` decomposition — and the native-domain
   property does vary supply, so combined coverage is adequate; but the
   512-bit-specific test exercises one denominator. See R-3.
5. **`previewRedeem` accepts `q` beyond the redeemable ceiling** —
   `src/HardReserve.sol:182` applies no `q <= S - S_MIN` bound, so it quotes a
   payout for a `q` that `redeem` would reject with `SupplyFloor`. Documented as
   a quotation rather than an entitlement, and the divergence occurs only at
   inputs that cannot execute. See R-4.
6. **`MockWeth` diverges from canonical WETH9 exactly where the zero-address
   rationale lives** — `test/mocks/MockWeth.sol:33` extends OZ ERC-20, whose
   `transfer` **reverts** on a zero recipient, whereas WETH9 credits it. The
   `src/HardReserve.sol:153-154` comment reasons from WETH9 semantics the mock
   cannot exhibit. Harmless for every Sprint-2 claim (the guard short-circuits
   first), but a modelling gap to retire when real WETH is wired. See R-5.

### Assumptions challenged

- **Assumption:** the compiled ABI is a faithful account of what the deployed
  contract will route — i.e. that asserting over `.methodIdentifiers` is
  equivalent to asserting over the dispatcher.
  **Risk if wrong:** every structural-absence claim in this sprint rests on it; a
  selector routed in bytecode but omitted from the ABI would be invisible.
  **Verdict: validated, not assumed.** The implementation already hedges this at
  `test/token/VuxToken.t.sol:264` with a live call to `burnFrom(address,uint256)`.
  I went further and extracted the PUSH4 dispatcher table straight from the
  runtime image for both contracts: VUX routes exactly its 20 ABI selectors, the
  Reserve exactly its 6, with no extras. The assumption holds for this build and
  is now independently evidenced rather than inherited.
- **Assumption:** `msg.sender` at construction is the `GenesisDeployer`. Both the
  sanitization receiver (`src/HardReserve.sol:114`) and the genesis POL recipient
  (`src/VUX.sol:100`) depend on it.
  **Risk if wrong:** a hand-deployed Reserve sends sanitized WETH to an EOA, and a
  hand-deployed token sends 150,000 VUX to an EOA.
  **Verdict: correct choice, and it must stay explicit.** Using `msg.sender`
  rather than a parameter is precisely what removes the misdirection argument, so
  every alternative is worse. The obligation lands on Sprint 7 to prove in-
  transaction that the deployer is the creator. Both files document it; the
  Sprint-7 wiring proof suite must discharge it.

### Alternatives not considered

- **Alternative:** wire `forge fmt --check` into `tools/provenance/run-all.sh` as
  a gate, the way every other invariant in this repository is mechanised.
  **Tradeoff:** costs one gate and a one-time reformat; buys elimination of a
  drift channel currently policed by nobody, in a repository whose entire thesis
  is that claims are asserted mechanically rather than read.
  **Verdict:** worth doing, but **not** in Sprint 2 — it would touch a Sprint-1
  file (`Harness.t.sol`) outside this sprint's surface, which is exactly the
  "while I'm here" edit the surgical-changes principle forbids. Recommended as a
  scoped follow-up.
- **Alternative:** assert the *runtime dispatcher table* (PUSH4 extraction) in
  addition to `.methodIdentifiers`, inside `inspect-runtime-surface.sh`.
  **Tradeoff:** roughly fifteen lines of awk; removes the last inferential step
  between "the ABI says X" and "the bytecode routes X".
  **Verdict:** the current approach is justified —
  `test_NoBurnFromEntryPointExistsAtRuntime` covers the specific dangerous case
  behaviourally, and I have now covered the general case by hand for this build.
  Worth reconsidering when the surface grows in Sprint 3.

## 16. Non-blocking observations

**L-1 (low) — stale evidence path in `src/HardReserve.sol:31` and `:100`.**
Both cite `test/reserve/ReserveSurface.t.sol`; the file is
`test/reserve/HardReserveSurface.t.sol`. The fix is a one-word edit in each
NatSpec block. No code, ABI, or bytecode impact. Not blocking: the evidence
exists, and `evidence/structural-absence-checklist.md` points to the correct path
throughout.

**L-2 (low) — `forge fmt --check` exits 1 on four files.** `src/HardReserve.sol`
(`:70-72`, the `Redeemed` declaration, which fits on one line under the default
120-column setting), `test/reserve/HardReserveRedemption.t.sol`,
`test/reserve/HardReserveSurface.t.sol`, and Sprint-1's
`test/harness/Harness.t.sol:60-62`. **Assessed as non-blocking, and this is a
deliberate judgment:** `forge fmt` is wired into neither
`.github/workflows/provenance.yml` nor `tools/provenance/run-all.sh`, and
`foundry.toml` declares no `[fmt]` section, so this is **not** a CI-parity break
— CI does not run it. Because a Sprint-1 file is equally non-clean, there is also
no established formatter convention that Sprint 2 regressed. Pure whitespace,
zero semantic or bytecode effect. Recommended for a scoped follow-up together
with the gate (see Alternatives), not for repair inside Sprint 2.

**R-1 (residual) — the prune split creates a narrower footgun.**
`loa_zone_solidity()` (`census.sh:185`) iterates only `LOA_ZONE_PRUNE`; a future
git-trackable directory added to `BUILD_ARTIFACT_PRUNE` instead would reopen
exactly the N-1 hole. Strictly safer than the Sprint-1 state (one undifferentiated
list, no assertion at all), and any such edit is reviewable, so this is an
observation rather than a defect. A future hardening could assert that every
`BUILD_ARTIFACT_PRUNE` entry is gitignored.

**R-2 (residual) — read-only reentrancy window.** See Adversarial concern 3.
Unreachable with canonical WETH; re-examine when Sprint-3+ contracts read
`backing()` or `previewRedeem()` inside settlement.

**R-3 (residual) — fixed denominator in the 512-bit property.** See concern 4.

**R-4 (residual) — `previewRedeem` unbounded in `q`.** See concern 5.

**R-5 (residual) — `MockWeth` zero-recipient semantics.** See concern 6. Retire
when real WETH is wired (Sprint 7).

**R-6 (residual) — no `CHANGELOG.md` convention exists in this repository.** The
generic review checklist treats a missing changelog entry as blocking; applied
literally here it would invent a requirement. This repository has never had a
`CHANGELOG.md`, documents releases through `docs/authority/` plus the grimoire
artifacts, and Sprint 1 passed both the review and audit gates on that basis.
Recorded as a documentation-convention decision for the operator before v1
release, explicitly **not** held against Sprint 2. Every Sprint-2 documentation
obligation the accepted authority actually defines — the PROV-5 similarity
statement, the structural-absence checklist, security-relevant code comments, and
SDD/PRD alignment — is satisfied.

## 17. Previous feedback status

Not applicable — no prior `engineer-feedback.md` existed for sprint-2. This is
the first review pass.

## 18. Process and quality gates

- **Complexity:** the longest function is `redeem` at 23 lines, 2 parameters,
  nesting depth 1. No duplication, no circular dependencies, no dead code.
  Lean already. Ship.
- **Karpathy principles:** *Think Before Coding* — assumptions are surfaced in
  `reviewer.md` and in-source (the `burnFrom` method note, the `to == address(0)`
  rationale). *Simplicity First* — `HardReserve.sol` is 185 lines including a
  heavy NatSpec header; nothing speculative, no abstraction with one caller, no
  configurability nobody asked for, and `IVUX` declares two members rather than
  mirroring the token ABI. *Surgical Changes* — harness changes are additive
  only; no adjacent code was "improved". *Goal-Driven* — every non-trivial branch
  carries a runnable check that fails if the logic breaks.
- **Fast-gate parity:** `forge build` clean (lint warnings on test files only,
  where the mock's return value is known); `forge test` 61/61 at CI fuzz depth;
  full `run-all.sh` green under the exact CI environment. Solidity has no
  separate type-check step. Formatter: see L-2.
- **Adversarial cross-model review (Phase 2.5):** not run —
  `.loa.config.yaml` declares no `flatline_protocol` block, so
  `flatline_protocol.code_review.enabled` is not `true` and the phase does not
  apply. No `adversarial-review.json` failure record is owed, because the phase
  was not attempted-and-failed but is disabled by configuration. Recorded here
  for the audit trail.
- **Subagent reports:** none present (`/validate` not run — optional). Full
  manual review performed.
- **Beads:** all six Sprint-2 tasks (`vux-fs8`, `vux-3ot`, `vux-3gq`, `vux-33a`,
  `vux-2gu`, `vux-3ha`) are closed; epic `vux-31v` remains in progress pending
  audit.

## 19. Overall assessment

This is the first monetary-core sprint and it was held to that standard. The
authority boundary — mint gating, burn gating, genesis exactness, redemption
arithmetic, constructor-only capability, and runtime structural absence — is
**exact**, and I confirmed each of those properties against the compiled
artifacts with tooling that shares no code with the implementation's own.

What raises this above a green-suite pass is that the absence claims are
falsifiable and that the *detectors themselves* are guarded: every absence
assertion carries a positive control, the metadata stripper is checked for
non-vacuity, the fuzz oracles are algebraically independent of the code under
test, and the assertion harness has a meta-suite proving it fails when it should.
Those are the properties that make "we found nothing" mean something, and they
are present. The Sprint-1 N-1 residue was closed as a class before the first
product Solidity landed — the right sequencing — and it survived four probes I
wrote myself.

Two low findings remain, both cosmetic and neither touching the monetary or
authority boundary; six residual risks are recorded for the audit and for
Sprints 3 and 7. Under this sprint's bounded-objective doctrine that is inside
the acceptance threshold. Approved.

## 20. Next steps

1. `/retrospective --scope reviewing-code`
2. `/audit-sprint sprint-2`

L-1, L-2 and R-1…R-6 are carried forward as disclosed context for the audit; none
requires a return to `/implement sprint-2`.


<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":1,"low":2},"sprint_id":"sprint-2","ts":"2026-08-12T04:40:00Z"} -->
