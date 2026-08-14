All good

# Focused Review — Pre-Sprint-3 Provenance-Tooling Hardening (M-1 / L-3 / L-4)

**Node:** `m1-l3-l4-provenance-hardening` (cycle-002, post-Sprint-2, pre-Sprint-3)
**Gate:** `/review-sprint` (`reviewing-code`), focused-node scope
**Reviewed:** 2026-08-13
**Beads:** `vux-21r`
**Verdict:** **APPROVED** — 0 critical · 0 high · 0 medium · 4 low (all non-blocking)

**Exact-tree identity — reproduced independently at review time:**

| item | value | status |
|---|---|---|
| subject fingerprint | `f75e4dbc57272551c73391ed04cbb32bf870f04fd3a714096bbffde17627fa9a` | reproduced exactly (600-byte manifest, final byte LF) |
| base identity | `HEAD == 22e5e00f42da06b7c8ec666d3690e0287eb74aed` on `master` | unchanged, nothing committed |
| subject membership | exactly the six declared files | confirmed against `git diff --name-only` |

Per-file digests re-derived and matched all six reported values:

```
c7033d5d1892bce0493acf8cdd46ea393c3876fc798b2e4cef517be14d4255cb  .github/workflows/provenance.yml
c94784d574eb208d993ceb43ea96750b4812e9d41d4c235ee608492f60d57ee7  tools/provenance/README.md
0763ffb219074dfb77757214e52b4467da28f5ab354a0439233c55a212ae0080  tools/provenance/census.sh
c59f9cd3e574ee8b4ca9b367cd6a49356485af92ca644ee43123f26d6fda94b8  tools/provenance/demo-boundary-negative.sh
e2542361806aaeadd001880a4e360591750252ec51219c9acc06f3433c3fb81f  tools/provenance/demo-drift-negative.sh
1b356b2357ddf114462d468074212afdc47622b7c57e786919aa3ae388a1f6a9  tools/provenance/verify-census.sh
```

The fingerprint was re-derived a second time **after** every verification run below and was
byte-identical, so nothing this review executed perturbed the subject.

---

## 1. Method — verified, not accepted

Every claim below was re-derived on this tree. The implementation report was read for
*orientation*, and its assertions were then discarded in favour of measurement. The prior
findings were read from the durable artifacts rather than inferred from their labels:
`sprint-2/auditor-sprint-feedback.md:1264-1280` (M-1/L-3/L-4 at severity), `:1167-1190` (§12,
L-3 bounded to 5 of 11 probes; L-4 detector unguarded), `:1397-1426` (`OPERATOR_ACCEPTANCE`,
the controlling scope statement), and `foundry-v1.5-refreeze/auditor-feedback.md:131-176`
(the v1.5.0 transition **creates** M-1's reachable form).

Executed independently at review time:

| check | result |
|---|---|
| `demo-boundary-negative.sh` | **exit 0** — 15 negative probes, 4 compiler positive controls |
| `demo-drift-negative.sh` | **exit 0** — builds both units, fails closed on 1 byte, exact restore |
| working-tree inventory around both demos | **identical** (`f1bd17b3…98a4490` before and after) |
| `FOUNDRY_PROFILE=ci run-all.sh` | **exit 0** — all 8 gates green, **61 passed / 0 failed / 0 skipped** (6 suites) |
| zero-artifact fail-closed (`out-v3core/` removed) | **exit 1** with the intended message; green again after restore |
| universe arithmetic re-derived from `census.sh` | fs 77 · compiled 71 · union 77 · compiler-only 0 |
| artifact metadata coverage | 50/50 artifacts under `out/` carry `.metadata` (object) |

---

## 2. M-1 — CLOSED

The authoritative universe is genuinely the union, and the compiler-derived half is genuinely
extension-independent.

**One definition, not a second scanner.** `census.sh:286` defines
`source_universe() = filesystem_sol_sources() UNION compiled_sources()`. `classify_sources()`
(`census.sh:320-330`) consumes it unchanged, and a repository-wide grep confirms **no other
gate maintains its own `find`** — the only `-iname '*.sol'` walks in `tools/provenance/**` are
`census.sh:269` (the filesystem half) and `census.sh:308` (the pruned-zone assertion). So the
claim that every consumer inherits the wider universe "with no per-consumer change" is
structurally true, not asserted:

| consumer | reads | reaches the compiled half |
|---|---|---|
| default-deny | `classify_sources` at `verify-census.sh:110-136` | yes |
| §8 `UniswapV3Factory` filename detector | `all_sources` at `verify-census.sh:186` | yes |
| v3-periphery detector | `all_sources` at `verify-census.sh:195-196` | yes |
| prohibited-source scan | `all_sources` at `verify-census.sh:217` | yes |
| `verify-spdx.sh:69` | `vux_owned_sources()` | yes |
| `verify-quarantine.sh:41` | `vux_owned_sources()` | yes |

**Extension-independence is structural.** `compiled_sources()` (`census.sh:233-241`) reads
`metadata.sources` keys from every artifact under `out/` and `out-v3core/`. Confirmed on this
tree that those keys are repo-relative and forward-slashed (`src/VUX.sol`,
`vendor/openzeppelin-contracts-v5.2.0/contracts/token/ERC20/ERC20.sol`), derived from import
resolution. No extension, case-variant, or suffix list appears anywhere in that path — there is
no naming axis left to move to.

**No allowlist was widened.** `filesystem_sol_sources()` retains the identical `-iname '*.sol'`
predicate it had before (`census.sh:269`); the fix is the union, not a longer extension list.
Confirmed by diff: the walk's `find` expression is unchanged apart from an added `sed` guard.

**Default-deny was not weakened.** `classify_sources()` still resolves to exactly three classes
with `unauthorized` failing closed. The only change to its behaviour is that its *input* is
wider. Independently confirmed: with `out-v3core/` removed the default-deny check still
classified all 77 files and passed — the halves are complementary, and removing one does not
open the other.

**Imported `.txt` and extensionless Solidity are caught — measured, not argued.**

```
probe 14  docs/boundary-probe-payload.txt
          ok POSITIVE control: solc recorded ... in metadata.sources
          FAIL unauthorized compiler-admitted source ...
          isolated: no FAIL line matches /unauthorized Solidity source/

probe 15  docs/boundary-probe-payload-noext
          ok POSITIVE control: solc recorded ... in metadata.sources
          FAIL unauthorized compiler-admitted source ...
          isolated: no FAIL line matches /unauthorized Solidity source/
```

**Zero-artifact units fail closed.** Re-verified by removing one unit's output directory:

```
ok    [profile.default]: 47 source(s) recorded by the compiler in out/
FAIL  no compiler-admitted source evidence under out-v3core/ — the [profile.v3core] unit has
      not been built, so the extension-independent half of the source universe is empty.
GATE_EXIT=1                    ... after restore: GATE_EXIT=0
```

This matches the fix shape the audit prescribed at §9.5 — cross-check `metadata.sources`
against the classified universe, **complement not replacement** — and the operator's acceptance
text verbatim (`:1419-1421`): close M-1 "by complementing the filesystem source-universe walk
with compiler-derived compiled-source coverage".

---

## 3. Freshness control — sufficient on every authoritative path

This was the principal judgment point, so it was traced exhaustively rather than reasoned about
in the abstract.

**The gate contains no freshness assertion.** Read in full: `verify-census.sh:80-100` invokes no
build, compares no mtime, and validates no cache. It requires only that each unit's artifact
count be non-zero. Therefore a stale-but-non-empty `out/` yields the *pre-build* universe. That
is established by construction, not by experiment, and the implementation states it plainly
(`census.sh:225-230`, README "the gates require a build", report §10.1).

**Every caller that can establish a green verdict:**

| path | builds first | stale-artifact false-green |
|---|---|---|
| CI `gates` to `run-all.sh:20-22` (`forge build --force` x2) | yes | **no** — and `out/` is gitignored + untracked, so a fresh checkout has no artifacts at all |
| CI `drift-negative-demonstration` to `demo-drift-negative.sh:34-51` | yes (added by this node) | **no** |
| CI `source-boundary-negative-demonstration` to `demo-boundary-negative.sh:257-269` | yes | **no** |
| local `run-all.sh` | yes (`--force`) | **no** |
| local `demo-*.sh` | yes | **no** |
| direct `bash tools/provenance/verify-census.sh` (or `-spdx` / `-quarantine`) | **no** | **yes** — see R-1 |

Two structural facts make the CI half airtight, and both were verified rather than assumed:
`out/` and `out-v3core/` are gitignored and carry **zero tracked files** (`git ls-files` empty
for both), so CI cannot inherit stale artifacts; and `[profile.ci]` (`foundry.toml:59`) declares
no `out` override, so it inherits `out = "out"` — confirmed empirically by the
`FOUNDRY_PROFILE=ci` run reporting `47 source(s) ... in out/`. Had `ci` redirected output, the
new evidence check would have failed CI outright; it does not.

**Assessment: the alternative control is sufficient.** No CI path and no gate-suite path can
false-green. The single residual (R-1) is a developer-convenience path that decides nothing,
is not the documented entry point, and is **strictly narrower than the pre-node behaviour** on
this exact axis — before this change, even `run-all.sh` false-greened on an imported non-`.sol`
source. M-1's closure criterion is that the boundary is extension-independent wherever it is
authoritative, and it is.

**The rejection of timestamp freshness is upheld.** Asserting artifacts-newer-than-sources would
fire on every probe that plants an uncompiled file, displacing the fence under test and
destroying the attribution the standing suite exists to provide. That reasoning is sound and the
decision is correct. It does not, however, extend to every possible freshness control — see the
alternative in §9, which the implementation did not consider and which does not carry that
drawback.

---

## 4. Fence attribution — probes 13-16 prove the intended fence

Verified from the live run, not from the report's table.

| probe | planted | fence proven | isolation assertion (observed) |
|---|---|---|---|
| 13 | `test/UniswapV3Factory.SOL` — **inside** a declared VUX root | §8 filename detector (`verify-census.sh:186`) | `no FAIL line matches /unauthorized Solidity source/` |
| 14 | `docs/boundary-probe-payload.txt` imported from `test/` | `unauthorized compiler-admitted source` (`verify-census.sh:131`) | `no FAIL line matches /unauthorized Solidity source/` |
| 15 | `docs/boundary-probe-payload-noext` imported from `test/` | same | `no FAIL line matches /unauthorized Solidity source/` |
| 16 | `test/boundary-probe-prohibited.txt` imported from `test/` | prohibited-source scan (`verify-census.sh:217`) | `no FAIL line matches /unauthorized compiler-admitted source/` |

The attribution logic is sound in both directions:

- **Probe 13** sits inside `test/`, so `classify_sources` labels it `vux` and default-deny is
  silent *by construction* — leaving the `-iE` filename detector as the only thing that can
  fire. Asserting the **absence** of the default-deny reason is what makes it isolating rather
  than merely passing. This is the standing probe L-4 said did not exist.
- **Probes 14/15** are caught by a message only the compiled half can emit
  (`verify-census.sh:126-133` branches on membership in the filesystem walk using `grep -qxF` —
  exact whole-line fixed matching, so the branch cannot be spoofed by a substring), with the
  filesystem-walk reason asserted absent. The catch cannot be a coincidence of another gate.
- **Probes 14/15/16** each prove compiler admission *before* asserting the catch, reading the
  importer artifact's own `metadata.sources` (`assert_compiled`,
  `demo-boundary-negative.sh:213-223`). Neither a resolver diagnostic nor the mere existence of
  an artifact directory is treated as evidence — the correct oracle, and the one the sprint-1
  N-2 retraction exists to enforce.
- **Probe 16** is the inverse pairing: planted where default-deny is structurally silent, so
  only a *consumer* of the universe can catch it. This is the probe that proves the fix reached
  the prohibited-source scan and not just the boundary check.

**Anchored matching cannot be satisfied by PASS output.** `reason_matches()`
(`demo-boundary-negative.sh:150`) filters to `^FAIL` before matching. Verified that the anchor
is stable in every context where matching occurs: `census.sh:76` disables colour when stdout is
not a tty, `fail()` (`census.sh:79`) writes `FAIL` at column 0, and `expect_fail` always
captures via command substitution with `2>&1` — a pipe, never a tty. Every multi-line `fail()`
call in `verify-census.sh` carries its reason on the **first** line, so no reason can hide below
the anchor. Observed directly in the live output.

---

## 5. L-3 — CLOSED

The fix is the `^FAIL` anchor at `demo-boundary-negative.sh:150`, exactly as prescribed at
`sprint-2/auditor-sprint-feedback.md:1182`. The standing baseline control
(`demo-boundary-negative.sh:287-302`) runs all 8 reason matchers against the concatenated
output of three **green** gates and requires none to match. Observed:

```
ok  none of the 8 reason matchers is satisfiable by a green gate
    1 of them WOULD match unanchored — the ^FAIL anchor is load-bearing, not decorative
```

The report is candid that the audit's 2 unanchored collisions became 1 because the pass-line
wording changed with the claim it makes (`verify-census.sh:135`). That disclosure is accurate
and the control remains discriminating. The residual fragility is recorded as R-2 —
non-blocking, because L-3's actual defect (matching against `ok` lines) is fixed at the matcher
itself and does not depend on the control's non-vacuity.

---

## 6. L-4 — CLOSED

`demo-boundary-negative.sh:534-548` is the standing isolating probe the audit said was missing
(`:1187-1190` — "it lives in this report, not in CI"). It now lives in CI: the
`source-boundary-negative-demonstration` job runs the demonstration on every push and PR
(`provenance.yml:135-136`). The probe targets the detector's weakest axis (a filename predicate
probed with a mixed-case extension) from the one location where no other gate can mask the
result. Verified firing and isolating in the live run.

---

## 7. Preservation — nothing product-side moved

Re-derived independently rather than read from the report:

| assertion | observed |
|---|---|
| Foundry | `1.5.0-v1.5.0`, commit `1c57854462289b2e71ee7654cd6666217ed86ffd` — self-reported by the running binary; **not downgraded** |
| solc pins | `0.8.28 @ 7893614a…`, `0.7.6 @ 7338295f…` recorded **and** self-reported by all 50 + 32 artifacts |
| `evm_version` | untouched — `[profile.v3core] istanbul` (`foundry.toml:88`), `[profile.default]` still unset |
| vendored census | 28 OZ / 32 v3-core / 3 Miner exact; **63/63 byte-identical**; zero unenumerated files of any type under `vendor/` |
| `POOL_INIT_CODE_HASH` | reproduced and equal to the accepted constant |
| authority artifacts | 4 accepted artifacts match their recorded SHA-256; toolchain refreeze byte-identical |
| SPDX / notices / §17 / launch hygiene | all green (63/63 upstream verbatim; 14 VUX-owned under PROV-8) |
| dependencies | none added — no `lib/`, no submodule, no package manifest |
| product tree | `git status` **empty** for `src/ test/ script/ vendor/ foundry.toml remappings.txt THIRD_PARTY_NOTICES.md LICENSE` |
| planning chain | `prd.md` `791c52f2…e2406e`, `sdd.md` `b7270458…ac6b175`, `sprint.md` `6db19ad0…2bfce514` — all match the accepted chain exactly |

**Subject-membership separation confirmed independently.** The four `docs/authority/**`
working-tree entries the report declares outside this node carry mtimes of 19:52-21:12, and the
six subject files carry 22:20-22:48 — the authority entries provably predate the node's
mutations. `grimoires/**` and `.beads/**` changes are State Zone bookkeeping (a2a index, NOTES,
the `vux-21r` record) and correctly excluded from the subject. `run-all.sh` is **unmodified**,
confirming its build-first behaviour is pre-existing rather than introduced to satisfy this
node's own freshness argument.

---

## 8. Scope discipline — held

No excluded finding was reopened, and none was worsened by this mutation:

- **Sprint-2 L-1 / L-2 / L-5, R-1…R-6** — untouched (`src/**` byte-identical).
- **Refreeze L-1** (drift-job restoration assertion is `git status` without `test -z`) — the
  drift job's assertion at `provenance.yml:90` is a *context* line in the diff, unchanged. The
  boundary job's stronger porcelain-emptiness assertion (`:141`) is likewise pre-existing.
  Asymmetry preserved as-is; correct.
- **Refreeze L-2 / R-3** (`evm_version` unset in `[profile.default]`) — `foundry.toml`
  untouched.
- **R-2, T-5, T-6** — untouched.

The `.github/workflows/provenance.yml` change is comment and job-name text only, with the sole
substantive consequence that the boundary job's "need only git + jq" comment — made false by
this node — was corrected. No step was added, removed, or reordered; verified against the diff.
Both demonstrations are self-contained, and the drift job already installs Foundry
(`provenance.yml:80-82`), so `demo-drift-negative.sh`'s new hard `forge` precondition
(`:36-39`) cannot break CI.

---

## 9. Adversarial Analysis

### Concerns Identified

1. **`tools/provenance/verify-census.sh:87-100`** — the compiler-admitted evidence section
   asserts only non-emptiness per unit. A stale non-empty `out/` therefore supplies the
   pre-build universe to a direct gate invocation. Bounded to a non-authoritative path (§3),
   but real. See R-1.
2. **`tools/provenance/demo-boundary-negative.sh:287-302`** — the L-3 control *reports*
   `unanchored_hits` but never asserts it is greater than zero. It fell from 2 to 1 in this very
   node because a pass-line was reworded; one further rewording would silently reduce it to 0,
   at which point the control still passes while proving nothing about the anchor. See R-2.
3. **`tools/provenance/census.sh:239`** — `jq` runs under `xargs` with stderr discarded. A
   single malformed artifact makes that batch exit non-zero; with `set -euo pipefail`
   (`census.sh:16`, `verify-census.sh:21`) the command substitution at `verify-census.sh:87`
   then aborts the gate with **no message at all**. Fail-closed, but undiagnosable. See R-3.
4. **`tools/provenance/census.sh:304-308`** — `loa_zone_solidity()` remains extension-keyed, so
   a *dormant* non-Solidity-named Solidity file inside a pruned Loa zone is invisible to both
   halves. Harmless while dormant (an unimported file is unreachable, and importing it moves it
   into the compiled half where default-deny catches it), but the asymmetry with the now
   extension-independent main universe is worth recording. See R-4.

### Assumptions Challenged

- **Assumption:** every Foundry artifact carries `.metadata`, so the `has("metadata")` guard
  (`census.sh:239`) never silently drops a compilation unit's sources.
- **Verified true today** — 50/50 artifacts under `out/` carry `.metadata` as an object.
- **Risk if wrong:** a `bytecode_hash = "none"` setting or a narrowed `extra_output` would strip
  metadata from some or all artifacts. Partial loss narrows the universe **without tripping
  anything**, because the emptiness check at `verify-census.sh:92-99` only requires a per-unit
  count greater than zero.
- **Recommendation (non-blocking):** make the assumption explicit rather than implicit — either
  a comment at `census.sh:239` naming the config settings this depends on, or count
  metadata-less artifacts and fail on a non-zero count.

### Alternatives Not Considered

- **Alternative:** **content-hash freshness** instead of timestamp freshness. Every
  `metadata.sources` entry already carries a `keccak256` field — verified present on this tree
  (`src/VUX.sol -> keccak256,license,urls`). Asserting that each compiled source's recorded
  hash matches its current bytes would prove the artifacts correspond to *this* tree.
- **Tradeoff:** it closes R-1 exactly. To introduce a new source into a build you must edit an
  existing compiled source (the importer), whose hash then mismatches — so it catches the stale
  case precisely. Critically, it is **not** tripped by merely planting an uncompiled file, which
  is the specific objection that correctly rules out mtime-based freshness. The implementation
  rejected "a finer staleness assertion (artifacts newer than sources)" for a reason that is
  valid for mtime and does not transfer to this variant.
- **Verdict:** the current approach is **justified for this node** — R-1 is not reachable on any
  authoritative path, the operator's acceptance scoped this node to the union fix, and folding
  in a new control would widen a deliberately bounded subject. Recommended as targeted
  follow-up hardening at the Sprint 7-8 deployment-bytecode freeze, alongside the already
  carried `evm_version` item. **Not required for closure.**

---

## 10. Non-blocking observations

Recorded for the audit trail. None blocks closure; none reopens an excluded finding.

| id | severity | location | observation |
|---|---|---|---|
| R-1 | LOW | `verify-census.sh:87-100` | No freshness assertion. Direct invocation of a single gate with a stale non-empty `out/` yields the pre-build universe. Not reachable via CI (untracked `out/` plus `--force` build) or `run-all.sh`; strictly narrower than pre-node behaviour; disclosed in code, README and report §10.1. Closing variant in §9. |
| R-2 | LOW | `demo-boundary-negative.sh:287-302` | The L-3 control does not assert its own non-vacuity. Add a hard check that at least one matcher would match unanchored, so a future pass-line rewording cannot silently retire the proof that the `^FAIL` anchor is load-bearing. |
| R-3 | LOW | `census.sh:239` plus `verify-census.sh:21,87` | A malformed artifact JSON makes the `xargs` / `jq` batch exit non-zero; under `set -euo pipefail` the gate aborts with no diagnostic. Fail-closed but opaque. Consider invoking `jq` per file, or capturing and reporting the failure. Latent only — 50/50 artifacts are currently well-formed. |
| R-4 | LOW | `census.sh:304-308` | `loa_zone_solidity()` is still extension-keyed. Dormant non-Solidity-named Solidity in a pruned zone is seen by neither half; the imported case is caught by the compiled half as `unauthorized`. Consistent with the disclosed complement limitation (report §10.2). |

---

## 11. Karpathy principles

| principle | assessment |
|---|---|
| **Think Before Coding** | Met. M-1 was reproduced live on this exact tree before any mutation (report §3) rather than inherited from the reports; assumptions and limitations are stated in §10 rather than left implicit. |
| **Simplicity First** | Met. The fix is one new function plus a union, reusing the compiler's own record instead of building a parser. The tempting wrong answer — widening the extension list — was explicitly rejected in-code (`census.sh:213-216`). Consumers required **zero** per-consumer changes, which is the strongest available evidence the abstraction sits at the right level. |
| **Surgical Changes** | Met. Six files, all provenance tooling. Comment corrections are confined to statements this change made false — notably the `provenance.yml` "need only git and jq" comment. No adjacent refactoring, no drive-by formatting; `run-all.sh` was left alone even though it is the linchpin of the freshness argument. |
| **Goal-Driven** | Met. Each finding closes against a runnable check that fails if the logic breaks: probes 14/15 for M-1, the baseline control for L-3, probe 13 for L-4 — all standing in CI, not one-off session evidence. Per-probe positive controls prevent the suite from degrading into asserting that the gate catches something harmless. |

Documentation coherence: `tools/provenance/README.md` documents both halves, the
extension-independence argument, and the build requirement. `grimoires/loa/a2a/index.md` records
the node without advancing any sprint status. No CLAUDE.md or SDD surface changed, and none
needed to — the node adds no command, skill, or architectural element.

---

## 12. Next steps

1. Exact-tree audit of subject
   `f75e4dbc57272551c73391ed04cbb32bf870f04fd3a714096bbffde17627fa9a`.
2. Operator acceptance of the audited tree, then landing.
3. Sprint 3 remains blocked until the above completes, per the Sprint-2 `OPERATOR_ACCEPTANCE`
   carry-forward condition (`sprint-2/auditor-sprint-feedback.md:1419-1426`).
4. R-1 through R-4 carried as non-blocking; the R-1 closing variant (§9) is recommended for the
   Sprint 7-8 deployment-bytecode freeze, not for this node.

No implementation change is requested. Nothing in this review was written to the implementation
tree; the subject fingerprint re-derived identically after every verification run.

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":4},"sprint_id":"m1-l3-l4-provenance-hardening","ts":"2026-08-13T06:55:31Z"} -->
