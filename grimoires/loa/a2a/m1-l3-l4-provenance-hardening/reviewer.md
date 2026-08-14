# Implementation Report — Pre-Sprint-3 Provenance-Tooling Hardening (M-1 / L-3 / L-4)

**Node:** bounded provenance-tooling hardening node (cycle-002, post-Sprint-2, pre-Sprint-3)
**Gate:** `/implement` (`implementing-tasks`)
**Implemented:** 2026-08-13
**Beads:** `vux-21r`
**Base identity:** `HEAD == 22e5e00f42da06b7c8ec666d3690e0287eb74aed` on `master` — unchanged, nothing committed
**Subject fingerprint:** `f75e4dbc57272551c73391ed04cbb32bf870f04fd3a714096bbffde17627fa9a`
**Status:** ready for focused `/review-sprint`-style review and `/audit-sprint`-style exact-tree audit

Sprint 3 was **not** started. No product, planning, economic, or authority behaviour changed.

---

## 1. Executive summary

The repository's default-deny provenance boundary decided membership with a filename
predicate (`find -iname '*.sol'`). Under the accepted Foundry v1.5.0 toolchain that predicate
is incomplete: imported Solidity named `Payload.txt`, or with no extension at all, reaches
solc, is recorded in the artifact's `metadata.sources`, is embedded in the importing contract
and executes — while the walk returns nothing for it. That is M-1.

The fix does not widen the extension allowlist, which would only move the boundary to the
next unenumerated name. The source universe is now the **union of two independent bodies of
evidence**: what the tree looks like, and what the accepted toolchain actually compiled. The
second half is keyed on nothing a rename can change.

| finding | disposition |
|---|---|
| **M-1** — canonical source universe keyed to Solidity-looking filename extensions (MEDIUM) | **CLOSED** — universe unioned with compiler-derived compiled-source coverage; fails closed on any compiled path that is unclassified; 3 standing negative probes + per-probe compiler positive controls |
| **L-3** — unanchored reason matching in the negative demonstration (LOW) | **CLOSED** — matching anchored on `^FAIL`; a baseline control proves no matcher is satisfiable by a green gate, and the control is itself mutation-tested |
| **L-4** — no standing isolating probe for the `-iE` filename detector (LOW) | **CLOSED** — probe 13 plants inside a declared VUX root where default-deny is structurally silent, and asserts the *absence* of the default-deny reason |

---

## 2. Prior findings consumed (read before mutation, not inferred from labels)

| source | what it defines |
|---|---|
| `grimoires/loa/a2a/sprint-2/auditor-sprint-feedback.md:1264-1280` | M-1 / L-3 / L-4 statements at severity |
| `…/auditor-sprint-feedback.md:963-1002` (§8, §8.1) | M-1 reproduced from `metadata.sources` + execution; probe P5 = `docs/AuditorExt.txt` carrying all three prohibited-source names |
| `…/auditor-sprint-feedback.md:1103-1113` (§9.5) | the prescribed fix shape — cross-check `metadata.sources` against the classified universe; **complement, not replacement** |
| `…/auditor-sprint-feedback.md:1167-1190` (§12) | L-3 bounded to 5 of 11 probes, fix = anchor on `^FAIL`; L-4 = the `verify-census.sh:146` detector has no standing probe |
| `…/auditor-sprint-feedback.md:1330-1353` (§18) | the three carry-forward conditions |
| `…/auditor-sprint-feedback.md:1397-1438` (§21) | **OPERATOR_ACCEPTANCE**, verbatim: close M-1 "by complementing the filesystem source-universe walk with compiler-derived compiled-source coverage"; also address L-3 and L-4; "Do not fold unrelated LOW findings into that node" |
| `grimoires/loa/a2a/foundry-v1.5-refreeze/auditor-feedback.md:131-176` (§5) | the v1.5.0 transition **creates** M-1's reachable form rather than inheriting it |
| `grimoires/loa/a2a/foundry-v1.5-refreeze/engineer-feedback-rereview.md:206-219` (§3.1) | independent reproduction: v1.0.0 `Error: unexpected file extension` / v1.5.0 `EXIT=0` |
| `grimoires/loa/skills/prove-which-fence-caught-it/SKILL.md` | probe-attribution discipline applied throughout |

The operator's acceptance text is the controlling scope statement. Findings the same
artifacts carry but the operator excluded — Sprint-2 L-1/L-2/L-5, R-1…R-6; refreeze
L-1 (drift-job restoration assertion), L-2 / R-3 (`evm_version`), R-2 (JSON/MD digest
asymmetry), T-5, T-6 — were **not** folded in. Refreeze L-3's first limb ("M-1's blocking
status is not mechanized") is discharged by construction: M-1 is closed, so there is no
blocking status left to mechanize.

---

## 3. M-1 reproduced on this exact tree before any fix

Not inherited from the reports. Planted in-repo, built with the accepted toolchain, measured:

```
metadata.sources of test/LoaProbeImporter.sol:
  docs/loa-probe-payload-noext        <- extensionless, IS compiled source
  docs/loa-probe-payload.txt          <- .txt, IS compiled source
  test/LoaProbeImporter.sol

tools/provenance/verify-census.sh (pre-fix, both payloads present):
  ok  zero unauthorized Solidity source anywhere in the repository (78 file(s) classified)
  All checks passed.                                            GATE_EXIT=0
```

The gate was **fully green** while two compiler-admitted Solidity sources sat outside every
census row and every declared root. The reproduction was removed and the tree restored before
implementation began.

---

## 4. AC Verification — against this node's acceptance threshold

| # | acceptance criterion | status | evidence |
|---|---|---|---|
| 1 | M-1 mechanically closed under actual Foundry v1.5 source admission/reachability | ✓ Met | `census.sh:201-241` (`compiled_sources`), `census.sh:273-288` (`source_universe` union), `verify-census.sh:80-100` (compiler-admitted evidence, fail-closed per unit at `:92-99`), `verify-census.sh:126-136` (default-deny over the union, origin-attributed) |
| 2 | `.txt` Solidity negative probe fails closed **for the intended provenance reason** | ✓ Met | probe 14 — `demo-boundary-negative.sh:565-578`; run output: `FAIL unauthorized compiler-admitted source … docs/boundary-probe-payload.txt`, `isolated: no FAIL line matches /unauthorized Solidity source/` |
| 3 | extensionless Solidity negative probe fails closed for the intended reason | ✓ Met | probe 15 — `demo-boundary-negative.sh:580-593`; run output: `FAIL unauthorized compiler-admitted source … docs/boundary-probe-payload-noext`, same isolation assertion |
| 4 | additional original M-1 probes still behave correctly | ✓ Met | probe 16 reproduces the audit's §8 P5 shape (`.txt` carrying Olympus / gumball6900 / give.fun) and is caught by the **prohibited-source** detector, isolated from default-deny — `demo-boundary-negative.sh:601-615`. Probes 1-12 unchanged and green |
| 5 | exact L-3 and L-4 closure criteria satisfied | ✓ Met | L-3: `demo-boundary-negative.sh:137-150` (`reason_matches`, `^FAIL` anchor), `:244-253` (the matcher inventory), `:287-302` (baseline control); L-4: `demo-boundary-negative.sh:543-548` (probe 13, isolating, negative attribution asserted) |
| 6 | existing authorized source / vendoring / provenance checks remain green | ✓ Met | `run-all.sh` exit 0; 63/63 byte-identical; 28/32/3 census exact; 4 authority artifacts match; SPDX 63/63 + 14; notices, quarantine, launch hygiene all green |
| 7 | existing product tests remain green under Foundry v1.5.0 | ✓ Met | `61 tests passed, 0 failed, 0 skipped` (6 suites), property suites at `runs: 10000` under `FOUNDRY_PROFILE=ci` |
| 8 | no product or planning behaviour changed | ✓ Met | §8 below — all six accepted parity digests re-derived exactly; `git status` empty for `src/ test/ script/ vendor/ foundry.toml remappings.txt .claude/`; PRD/SDD/Sprint hashes match the accepted chain |
| 9 | resulting tree ready for independent review and audit | ✓ Met | subject fingerprint §9; six-file manifest published; nothing committed |

---

## 5. Files changed — exactly six

| file | change |
|---|---|
| `tools/provenance/census.sh` | `compiled_sources()` added; `source_universe()` split into `filesystem_sol_sources()` + a union `source_universe()`; `BUILD_OUT_DIRS`; comment corrections where the old text overstated scope |
| `tools/provenance/verify-census.sh` | fail-closed compiler-admitted-evidence section; origin-attributed default-deny failure messages; evidence-breakdown `info` line; header claim corrected |
| `tools/provenance/demo-boundary-negative.sh` | `reason_matches()` with `^FAIL` anchor; `expect_fail` gains an optional must-NOT-match argument; baseline builds both units; baseline L-3 control; probes 13-16; restoration extended to the new probe paths and the importer artifact |
| `tools/provenance/demo-drift-negative.sh` | builds both units at baseline (the drift gate is `verify-census.sh`, whose preconditions are now this script's preconditions) |
| `tools/provenance/README.md` | documents the two-half universe, why it is extension-independent, and that the gates now require a build |
| `.github/workflows/provenance.yml` | comment/job-name corrections only — the boundary job's "need only git + jq" comment was made false by this change. **No step added, removed, or reordered**; both demos are self-contained |

Nothing else was mutated. `src/`, `test/`, `script/`, `vendor/`, `foundry.toml`,
`remappings.txt`, `THIRD_PARTY_NOTICES.md`, `LICENSE`, `.claude/`, and every
`docs/authority/**` artifact are untouched.

### 5.1 Pre-existing working-tree entries, outside this node

Present at node entry and **not written by this node** (recorded so the auditor can
mechanically separate them from the subject):

```
 M  docs/authority/vux-v1-authority-supersession-map-2026-08.md    ea07cfa2…4e1f51
 ?? docs/authority/vux-founder-acceptance-adaptive-routing-…md      a0d5d38b…f4dac3
 ?? docs/authority/vux-founder-parameter-freeze-adaptive-…md        89687ecc…8892b51
 ?? docs/authority/vux-v1-canonical-specification-adaptive-…md      04512412…68c1aa
 M  grimoires/loa/{prd,sdd,sprint,NOTES}.md                         (State Zone)
```

The accepted planning chain re-hashes to exactly the dispatched values, so it is provably
unchanged by this node:

```
791c52f2ad05c794188b218e877957889bc97b6399b965b9c5fe003ef0e2406e  grimoires/loa/prd.md      (PRD v2.1.1)
b7270458e1417171dd812f34039263eca45cd676f8009dbfaf202d90aac6b175  grimoires/loa/sdd.md      (SDD v1.7.1)
6db19ad09a2da42dbdf4847535b2a73890079efa0d91ebc691f1c7c32bfce514  grimoires/loa/sprint.md   (Sprint Plan v1.1.1)
```

**Subject-membership note for the auditor:** mechanical auto-discovery (`git diff --name-only`
+ untracked, minus `grimoires/` `.beads/` `.run/`) yields **ten** paths. Four are the
pre-existing `docs/authority/**` entries above. The node subject is the **six** files this
node mutated, by explicit declaration.

---

## 6. How the authoritative source universe is now derived

One definition, in `census.sh`, consumed by every provenance-sensitive gate:

```
source_universe()  =  filesystem_sol_sources()  ∪  compiled_sources()
```

| half | source of truth | sees | blind to |
|---|---|---|---|
| `filesystem_sol_sources()` (`census.sh:266-271`) | the working tree | every `*.sol`, case-insensitively, tracked or not | source not *named* like Solidity |
| `compiled_sources()` (`census.sh:233-241`) | `metadata.sources` of every artifact under `out/` and `out-v3core/` | every path solc resolved, whatever it is called | source nothing imports |

`classify_sources()` then classifies the union into `vendored` / `vux` / `unauthorized`
exactly as before, so **every** consumer — default-deny, prohibited-source scanning,
`verify-spdx.sh`, `verify-quarantine.sh` — inherits the wider universe with no per-consumer
change. That is what makes this one universe rather than a second, parallel scanner.

### 6.1 Why it is extension-independent

The compiled half asks the compiler what it compiled. solc records in each artifact's
`metadata.sources` the exact set of files that produced it, keyed by the path it resolved —
repo-relative, forward-slashed, and derived from import resolution, not from any name
pattern. Nothing in that path is matched against an extension, a case variant, or a suffix
list, so there is no naming axis left to move to. Verified empirically: the payload paths
`docs/boundary-probe-payload.txt` and `docs/boundary-probe-payload-noext` appear in
`metadata.sources` verbatim (§3, and per-probe positive controls in §7).

The audit's own qualifier is preserved: this is a **complement**. It cannot see a dormant
unauthorized file nothing imports — which is precisely what the filesystem walk is good at —
so both halves are kept and neither is authoritative alone.

### 6.2 Fail-closed, proven rather than asserted

The compiled half is only evidence if the compiler produced it, so a unit with **no**
artifacts is a failure, not an empty contribution (`verify-census.sh:92-99`). Demonstrated by
removing one unit's output directory:

```
ok    [profile.default]: 47 source(s) recorded by the compiler in out/
FAIL  no compiler-admitted source evidence under out-v3core/ — the [profile.v3core] unit has
      not been built, so the extension-independent half of the source universe is empty.
GATE_EXIT=1
… restored …  gate green again exit=0
```

**Freshness contract** (stated in code at `census.sh:225-230` and in the README): the compiled
half reflects the last build. Callers that must not miss a newly-imported source build first —
`run-all.sh` compiles both units before any gate, and both negative demonstrations compile at
baseline and again around every probe that changes the compilation graph. This is a real
boundary, deliberately not papered over: a stale `out/` narrows the compiled half, which is
why the per-unit emptiness check is fail-closed rather than advisory.

---

## 7. Negative-probe results — and which fence rejected each

`bash tools/provenance/demo-boundary-negative.sh` → **exit 0**, 15 negative probes.

| probe | planted | fence that rejected it | isolation asserted |
|---|---|---|---|
| 1 | `contracts/vendored/Rig.sol` (authorized bytes, wrong place) | default-deny (`unauthorized Solidity source`) + SPDX reach | — |
| 2 | `contracts/impl/UniswapV3Factory.sol` | §8 filename detector | — |
| 3 | `contracts/research/Probe.sol` (Olympus / gumball6900 / give.fun) | prohibited-source scan | — |
| 4 | `contracts/periphery/PoolAddress.sol` | v3-periphery detector | — |
| 5 | `lib/forge-std/src/Test.sol` | default-deny | — |
| 6 | `contracts/policy/Policy.sol` | §17 quarantine | — |
| 7 | `grimoires/loa/boundary-probe-zone.sol` | pruned-zone assertion | — |
| 8-10 | `.SOL` / `.SoL` / `.sOl` at root, `docs/`, pruned zone | default-deny (8, 9), pruned-zone assertion (10) | — |
| 11 | `contracts/research/CaseProbe.SOL` (prohibited names) | prohibited-source scan | — |
| **12** | *positive control* — `.SOL` in a throwaway project | compiled **and executed** (`metadata.sources` + `[PASS]`) | — |
| **13** | `test/UniswapV3Factory.SOL` — **inside** a declared VUX root | §8 **filename detector** (`UniswapV3Factory.sol implementation present`) | ✓ `no FAIL line matches /unauthorized Solidity source/` |
| **14** | `docs/boundary-probe-payload.txt` imported from `test/` | **`unauthorized compiler-admitted source`** | ✓ `no FAIL line matches /unauthorized Solidity source/` |
| **15** | `docs/boundary-probe-payload-noext` imported from `test/` | **`unauthorized compiler-admitted source`** | ✓ `no FAIL line matches /unauthorized Solidity source/` |
| **16** | `test/boundary-probe-prohibited.txt` (prohibited names) imported from `test/` | **prohibited-source scan** | ✓ `no FAIL line matches /unauthorized compiler-admitted source/` |

Probes 14-16 each carry their own compiler positive control before the catch is asserted:

```
ok  POSITIVE control: solc recorded docs/boundary-probe-payload.txt      in metadata.sources … [probe 14]
ok  POSITIVE control: solc recorded docs/boundary-probe-payload-noext    in metadata.sources … [probe 15]
ok  POSITIVE control: solc recorded test/boundary-probe-prohibited.txt   in metadata.sources … [probe 16]
```

Probes 14 and 15 are caught by a message that **only the compiled half can produce**, and the
filesystem-walk reason is asserted absent — so the catch is attributed to the new fence and
cannot be a coincidence of some other gate failing. Probe 16 is the inverse pairing: planted
inside a declared root so default-deny is structurally silent, proving the *consumers* of the
universe (not just the default-deny check) recovered on this axis.

Restoration: working-tree inventory hash identical before and after; every probe path and the
importer's artifact directory asserted removed; all three gates green again.

### 7.1 L-3 — the anchor is load-bearing, and that is mutation-tested

```
── baseline control — no reason matcher may be satisfied by a green gate (audit L-3)
  ok  none of the 8 reason matchers is satisfiable by a green gate
      1 of them WOULD match unanchored — the ^FAIL anchor is load-bearing, not decorative
```

The control was verified non-vacuous by mutating the fix away — restoring the pre-remediation
matcher (`grep -qE "$reason"` over whole output) — and re-running:

```
mutant sha : 2db49c559d81a975ed59e33bf79b0afa4c315d454f82410a45b48c5389fc8df0
  FAIL  reason /pruned Loa/state zone/ is satisfied by a PASSING gate — a probe using it
        would report a false catch
DEMO_EXIT=1
restored   : c59f9cd3e574ee8b4ca9b367cd6a49356485af92ca644ee43123f26d6fda94b8  (byte-exact)
```

The mutation was reverted from a pre-mutation copy and the restored file re-hashed to its
exact pre-mutation value.

*(Note for the reviewer: the audit measured 5 of 11 probes affected by two colliding `ok`
strings. One collision — `zero unauthorized Solidity source anywhere in the repository` — no
longer exists because that pass line's wording changed with the claim it makes; the other
survives, which is what keeps the control discriminating. Both were 5-probe causes; the
anchor closes the class regardless of how many strings happen to collide today.)*

---

## 8. Preservation — nothing product-side moved

All six accepted parity digests from the toolchain refreeze §9 (v1.5.0 column) re-derived
under its §9.0 convention — SHA-256 over the artifact's `bytecode.object` /
`deployedBytecode.object` as a lowercase hex **string**, `0x` stripped, no trailing newline:

| artifact | re-derived | accepted |
|---|---|---|
| `VUX` creation | `d39b3892c686f3c5cd77c7ee3865e28ad4c464c87e341094fe8c7be073a5a7c7` | exact |
| `VUX` deployed | `77c07c4ae72b6907e26d92098b4a09b08e546dc653c37f58be6c0bc4fc7285ba` | exact |
| `HardReserve` creation | `27655d138a377a902d8c60d4bdff1cfba7794ce24788e3ed47174afb04289eaf` | exact |
| `HardReserve` deployed | `d4cbe285488b96195e79e6ef4f79d4812b430e0c513303ecfb46639dcea45fd0` | exact |
| `UniswapV3Pool` creation | `888deca479325b2bdfed6c48f6ced356271fcba13e09d864a2f6986d8097fe43` | exact |
| `UniswapV3Pool` deployed | `ecd7503ff9ba5cface57946e85117c0c07796c0a5f2d7fe7ec20a54ec254510f` | exact |

| assertion | result |
|---|---|
| Foundry | `v1.5.0-v1.5.0` @ `1c57854462289b2e71ee7654cd6666217ed86ffd` — self-reported by the running binary, unchanged, **not downgraded** |
| solc pins | `0.8.28` @ `7893614a…`, `0.7.6` @ `7338295f…` — recorded and self-reported by all 82 artifacts |
| `evm_version` | untouched (`[profile.v3core] istanbul`; `[profile.default]` still deliberately unset) |
| `POOL_INIT_CODE_HASH` | reproduced and equal to the accepted constant |
| vendored identity | 63/63 byte-identical; 28 OZ / 32 v3-core / 3 Miner exact; zero unenumerated files of any type under `vendor/` |
| authority artifacts | 4 accepted artifacts match their recorded SHA-256; toolchain refreeze authority byte-identical |
| SPDX / notices / §17 / launch hygiene | green |
| dependencies | none added; no `lib/`, no submodule, no package manifest |
| source universe | 77 files — 63 vendored + 14 VUX-owned, **zero unauthorized**; 71 compiler-admitted; **0 reachable only through the compiler** |

Exposure in this tree remains empirically zero: the compiled set is a strict subset of the
filesystem walk, so the new half currently adds no members — it is a fence, not a fix for a
present violation.

---

## 9. Testing summary

| command | result |
|---|---|
| `FOUNDRY_PROFILE=ci bash tools/provenance/run-all.sh` | **exit 0** — "All provenance gates and tests passed" |
| `forge test` (within the above) | **61 passed, 0 failed, 0 skipped** (6 suites); `testFuzz_*` at `runs: 10000` |
| `bash tools/provenance/demo-boundary-negative.sh` | **exit 0** — 15 negative probes, 4 compiler positive controls, byte-exact restoration |
| `bash tools/provenance/demo-drift-negative.sh` | **exit 0** — fails closed on a one-byte mutation, exact bytes restored, green again |
| `bash -n` on all four modified shell scripts | clean |
| fail-closed check (one unit's `out/` removed) | gate exits 1 with the intended message; green again after restore |
| L-3 control mutation test | control fails under the pre-remediation matcher; file restored byte-exactly |

### Verification steps for the reviewer

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge --version                                        # expect 1.5.0 @ 1c578544…
FOUNDRY_PROFILE=ci bash tools/provenance/run-all.sh    # expect exit 0, 61/61
bash tools/provenance/demo-boundary-negative.sh        # expect exit 0, 15 probes
bash tools/provenance/demo-drift-negative.sh           # expect exit 0
```

---

## 10. Known limitations (disclosed, not deferred work)

1. **The compiled half is as fresh as the last build.** Stated in code and README, enforced by
   the per-unit fail-closed emptiness check and by every caller building first. A finer
   staleness assertion (artifacts newer than sources) was considered and rejected: it is
   tripped by any planted probe, which would fire the *wrong* fence in the demonstrations and
   destroy the attribution the standing suite exists to provide.
2. **The compiled half sees only what is imported.** Inherent and disclosed by the audit
   (§9.5); the filesystem walk is retained precisely for the dormant case.
3. **Probes 14-16 rebuild.** The boundary demonstration is slower by roughly six incremental
   builds (~1s each locally, cold in CI). Unavoidable: a probe the compiler never saw has not
   been planted in any meaningful sense.
4. **Not in scope, deliberately** (operator: "Do not fold unrelated LOW findings into that
   node"): Sprint-2 L-1 / L-2 / L-5; refreeze L-1 (drift-job restoration assertion is still
   `git status` without `test -z`), L-2 / R-3 (`evm_version` unset in `[profile.default]`,
   carried to the Sprints 7-8 deployment-bytecode freeze), R-2 (JSON/MD digest asymmetry),
   T-5, T-6.

---

## 11. Node subject identity

Convention — the operator-accepted audit convention proven in
`foundry-v1.5-refreeze/engineer-feedback-rereview.md:474-488` against the Sprint-2 vector:
`<sha256>` + **two spaces** + path, `LC_ALL=C` sorted **by path**, LF-terminated, written to a
file, then SHA-256 of that manifest (600 bytes, final byte `\n`).

```
f75e4dbc57272551c73391ed04cbb32bf870f04fd3a714096bbffde17627fa9a
```

```
c7033d5d1892bce0493acf8cdd46ea393c3876fc798b2e4cef517be14d4255cb  .github/workflows/provenance.yml
c94784d574eb208d993ceb43ea96750b4812e9d41d4c235ee608492f60d57ee7  tools/provenance/README.md
0763ffb219074dfb77757214e52b4467da28f5ab354a0439233c55a212ae0080  tools/provenance/census.sh
c59f9cd3e574ee8b4ca9b367cd6a49356485af92ca644ee43123f26d6fda94b8  tools/provenance/demo-boundary-negative.sh
e2542361806aaeadd001880a4e360591750252ec51219c9acc06f3433c3fb81f  tools/provenance/demo-drift-negative.sh
1b356b2357ddf114462d468074212afdc47622b7c57e786919aa3ae388a1f6a9  tools/provenance/verify-census.sh
```

Emission ordered by path and independent re-sorting with `LC_ALL=C sort -k2` produce the
identical manifest hash, so the ordering rule is unambiguous for this set.

---

## 12. Lifecycle confirmations

- **Sprint 3 not started.** No `src/` file created or modified; no Rig implementation; no
  adaptive-routing implementation; ledger `sprint-3` still `planned`.
- **No commit, push, tag, branch, PR, or merge.** `HEAD == 22e5e00f…` on `master`, unchanged.
- **No `COMPLETED` marker written**; `a2a/index.md` records the node without advancing any
  sprint status.
- **No authority, PRD, SDD, Sprint-Plan, or economic change.** No new source, dependency, or
  reuse authorization created; default-deny not weakened.
- Beads `vux-21r` tracks this node.

**Next:** focused `/review-sprint`-style review, then `/audit-sprint`-style exact-tree audit of
subject `f75e4dbc57272551c73391ed04cbb32bf870f04fd3a714096bbffde17627fa9a`.
