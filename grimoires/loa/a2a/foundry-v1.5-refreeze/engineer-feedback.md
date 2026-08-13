All good

# Focused Review — Foundry v1.5.0 Toolchain Refreeze

**Node:** bounded toolchain-authority + CI-recovery node (cycle-002, post-Sprint-2)
**Gate:** `/review-sprint` methodology, focused scope — not a Sprint-1/Sprint-2 re-review
**Reviewed:** 2026-08-12
**Base identity:** `master == origin/master == f997c077` (unchanged; verified below)
**Verdict:** **APPROVED** — 0 critical / 0 high / 2 medium / 4 low, all non-blocking

---

## 1. Subject verification (gate zero)

The dispatch instructed me to stop with `HITL_REQUIRED` if the subject no longer
matched fingerprint `3a73d6d3…e07a31`. It matches. Reproduced independently:

```
3a73d6d315d55a8bb976f07a2a0b13aaeaaee4a37465cd64ef8b04d190e07a31
```

**8 files — 6 modified, 2 added**, exactly as reported:

| SHA-256 | Path | disposition |
|---|---|---|
| `cb025d84481b7c186e4d6af1f0f8b1c033a72e0742d7519750de2112711fe6bd` | `.github/workflows/provenance.yml` | modified |
| `b8a512f4aad2bc3e095cdce02de7fa2196a887e0c7ea9e034cf9eeaee23d0be5` | `docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.json` | **added** |
| `51c103188dfac27e5cb5b3eda9faa7c508785d4a7d1ec1508be2fab2e3f134f2` | `docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md` | **added** |
| `c61a680ebc5cbf3c779051f0921d9f42ebaa8e3750675aefd283bb9bee1ae445` | `foundry.toml` | modified |
| `31be6dfadf9f065fc1c1f97d0e4d3bcc54f43c52ac7062e7738c05597bb3d748` | `grimoires/loa/sdd.md` | modified |
| `7b5ccfbb7bfaa22cc94e083589990b2fcd4bcd8f39a1740e800de54c99354a11` | `tools/provenance/README.md` | modified |
| `04ff33996bcec249b6a4bf04519034c0e72080036fb89ed16dcc29a5be8305b3` | `tools/provenance/census.sh` | modified |
| `aa41bab61e1ad62856a9ca9548aed78934b313582571946005964ea6825df5bd` | `tools/provenance/verify-pins.sh` | modified |

### 1.1 Recovering the fingerprint convention — and a finding on the way (T-6)

The accepted audit-subject digest convention, published by the Sprint-2 auditor,
is `<sha256>` + **two spaces** + path, `LC_ALL=C` sort by path, LF, trailing
newline. I validated my implementation of it against the published pass-2
manifest and it reproduced `a6313a4d5a…2b772cf` exactly — so the implementation
was proven correct against a known vector *before* being used here.

Under that convention the 8-file set yields `f427101b…`, **not** `3a73d6d3…`.
The set was not wrong; the convention was. This node published its fingerprint
under raw msys `sha256sum` **binary-mode** output — `<sha256>` + space + `*` +
path — a different convention, stated nowhere. Recovered by search over
separator × line-ending × sort-key × trailing-newline; exactly one variant hits,
and it reproduces on a plain pipeline:

```bash
sha256sum <the 8 files> | LC_ALL=C sort -k2 | sha256sum
```

This is filed as **T-6 (LOW)**. It costs a reviewer a convention-recovery step,
and the repository already carries an extracted skill about precisely this
hazard (`skills-pending/recover-digest-convention-from-published-components`,
which names the msys `*` marker by name).

### 1.2 Retrospective separation

Retrospective mutations did not contaminate the subject. Every subject file
bands at 00:48:08–00:51:10; `NOTES.md` is 10:19 (node narrative + retrospective)
and `skills-pending/fail-closed-gate-scope-probe/SKILL.md` is 2026-08-11
(*previous* node's dirt, predating this one). Neither is in the fingerprint, and
`NOTES.md` structurally cannot be — it contains the fingerprint.

The fingerprint was re-verified **after** every probe I ran, including the full
boundary demonstration: entry `3a73d6d3…e07a31` == exit `3a73d6d3…e07a31`.

---

## 2. Upstream identity — VERIFIED from primary evidence

Not taken from the dispatch or the implementation report.

| evidence | result |
|---|---|
| GitHub git-ref API `refs/tags/v1.5.0` | `object.sha = 1c57854462289b2e71ee7654cd6666217ed86ffd`, `object.type = commit` |
| GitHub releases API `tags/v1.5.0` | `draft: false`, `prerelease: false`, `published_at: 2025-11-24T06:14:42Z`, `created_at: 2025-11-16T19:29:16Z` |
| local `forge --version` | `1.5.0-v1.5.0`, `Commit SHA: 1c57854462289b2e71ee7654cd6666217ed86ffd` |
| local `cast --version` | same version, same commit |
| local `anvil --version` | same version, same commit |

The ref, the release metadata, and all three executing binaries agree on one
40-character commit. Authority §2/§2.1 and the JSON `toolchain_transition` block
match this evidence field-for-field, including the `2025-11-16`/`2025-11-24`
commit-vs-publish distinction.

---

## 3. Authority delta — scope is correct

The new MD + JSON supersede **only** the Foundry orchestrator selection.
Independently confirmed, every "unchanged" claim of §4 / JSON `unchanged`:

| claim | verification |
|---|---|
| solc `0.8.28` @ `7893614a…` unchanged | recorded in `foundry.toml`; **self-reported** by the compiler that ran — all 50 artifacts under `out/` |
| solc `0.7.6` @ `7338295f…` unchanged | recorded; self-reported for all 32 artifacts under `out-v3core/` |
| v3 build settings unchanged | `[profile.v3core]` — optimizer `true`, runs `800`, `evm_version = "istanbul"`, `bytecode_hash = "none"` |
| `POOL_INIT_CODE_HASH` unchanged | reproduced — see §5 |
| provenance / source reuse unchanged | census gate green; Miner reuse still exactly 3 allowlisted files |
| dependency authority unchanged | no `lib/`, no `package.json`/lockfile, no `.gitmodules`, no `forge-std` (only the two comments documenting its deliberate absence) |
| economics unchanged | `src/` untouched (§10) |
| predecessor authority not rewritten | all five §5 SHAs re-hashed by me: `27aa37ec…`, `db314413…`, `50c3584a…`, `6fc9fa81…`, `963e2cfb…` — **byte-identical** |

Both new artifacts are correctly SHA-256 registered in `census.sh`
(`TOOLCHAIN_MD_SHA256`, `TOOLCHAIN_JSON_SHA256`) and verified fail-closed by
`verify-pins.sh`. The gate fired green in my run: `ok  toolchain refreeze
authority byte-identical to the accepted values`.

---

## 4. Old-pin classification — correct, no blind replacement

I enumerated every occurrence of `8692e926198056d0228c1e166b1b6c34a5bed66c`
repository-wide and checked each against its declared class.

| class | expected | actual |
|---|---|---|
| **A — active, updated** | `foundry.toml`, `census.sh`, `provenance.yml`, `verify-pins.sh` | all four now carry `v1.5.0` / `1c578544…`; **zero** residual `8692e926` occurrences |
| **B — forward-looking, noted** | `sdd.md`, `tools/provenance/README.md` | `sdd.md` retains the historical pin verbatim with a supersession pointer; README describes the strengthened gate |
| **C — historical, untouched** | accepted authority MD/JSON, sprint-1/2 reviewer + auditor + engineer feedback, prior NOTES entries, trajectory | all still name `v1.0.0`, all byte-identical |
| **D — unrelated** | Uniswap v3-core `v1.0.0` @ `e3589b19…` | untouched in `THIRD_PARTY_NOTICES.md`, `census.sh` (`V3_COMMIT` unchanged in the diff), `sprint.md`, `sdd.md`, `vendor/uniswap-v3-core-v1.0.0/` |

No collateral rewrite. The `v1.0.0` string was not treated as a search-and-replace
target — which is the failure mode this classification exists to prevent.

---

## 5. Solc and v3 invariants — unchanged, hash reproduced independently

`POOL_INIT_CODE_HASH` was reproduced **without using Foundry's own tooling** —
verifying `cast keccak` against artifacts `cast` helped produce is circular. I
implemented Keccak-256 directly (self-tested against the known digests of `""`
and `"abc"`) and hashed the pool creation bytecode:

```
0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54   (v1.5.0 build)
0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54   (v1.0.0 build)
accepted:
0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54
```

Exact, from **both** toolchains, at identical creation-code length (22,728
bytes). No compiler migration occurred: both solc pins are recorded *and*
self-reported by the compilers that actually ran.

---

## 6. Bytecode divergence — diagnosis independently reproduced

I did not accept the report's diagnosis. I built the exact current repository
under **both** toolchains (v1.0.0 from `~/.foundry/versions/v1.0.0`, v1.5.0
authoritative) into separate output directories and compared.

| artifact | v1.0.0 whole | v1.5.0 whole | CBOR-stripped code, both |
|---|---|---|---|
| `VUX` creation (11,386 B) | `a1f05f65…` | `bbb2e97f…` | **`14d19d5d…` identical** |
| `VUX` deployed (7,989 B) | `3ce648aa…` | `70d8cde4…` | **`e1878fab…` identical** |
| `HardReserve` creation (4,736 B) | `68d2a5e6…` | `04b55338…` | **`d44efcac…` identical** |
| `HardReserve` deployed (3,252 B) | `3cc547bc…` | `38a04ea0…` | **`9137a27c…` identical** |
| `UniswapV3Pool` creation (22,728 B) | `f8165e94…` | `f8165e94…` | **identical whole-artifact** |
| `UniswapV3Pool` deployed (22,142 B) | `3ef71385…` | `3ef71385…` | **identical whole-artifact** |

`metadata.evmVersion` reads **`cancun`** under v1.0.0 and **`prague`** under
v1.5.0 — read directly out of each artifact, not inferred. Lengths are pairwise
identical, so no code was added or removed.

**The contrast is the proof.** `[profile.default]` leaves `evm_version` unset
and therefore inherits the orchestrator default; `[profile.v3core]` pins
`istanbul` explicitly and is byte-identical whole-artifact, metadata included.
That is exactly the asymmetry the report claims, and it holds.

**Conclusion: the difference is metadata-only. No semantic executable-code
divergence exists.** I did not rely on tests passing to reach this — the
opcodes were compared directly.

I also verified the four `code_sha256_metadata_stripped` constants published in
the JSON companion and MD §9.1. They reproduce **exactly**, from both
toolchains, once the convention is recovered (strip `n+2` trailing bytes, then
SHA-256 over the lowercase **hex string**):

```
VUX.creation        3f8ffe9ebacd3b5962fbef8aa19e3b8fb00916e356c9bca0773d405691a52fa6
VUX.deployed        7377122c247ecc7da63099b3818c1db506c33f71eee2c6dfa8b9429275a32ed2
HardReserve.creation 2184162f1cdecde87cbaecd09a0a80429cff48a33baf0fa2909712aca100e105
HardReserve.deployed 065241a187cc91b53e174775c387cf6966e76e0d55b567ccd9e606074d804a07
```

MD §9.1's stated hex-char lengths (22,666 / 15,872 / 9,366 / 6,398) also match
my extraction exactly. The load-bearing parity evidence is fully verifiable.

The §9 *whole-artifact* column is not — see **T-1**.

---

## 7. ABI and runtime surface — no regression

| check | result |
|---|---|
| `VUX` ABI, v1.0.0 vs v1.5.0 | identical |
| `HardReserve` ABI, v1.0.0 vs v1.5.0 | identical |
| method identifiers | `VUX` 20 + `HardReserve` 6 = **26**, identical across toolchains |
| external dispatcher surface | `VUX` 20 / `HardReserve` 6 — exactly the accepted sets |
| new public/external capability | none |
| `HardReserve` mutability | exactly one state-changing function (`redeem`); no payable, no `receive()`, no `fallback()` |
| burn surface | `burn(uint256)`, `burnForRedemption(address,uint256)`; **no `burnFrom`** in the dispatcher table |
| sanitization marker | present in creation bytecode, **absent** from deployed runtime |
| runtime opcode census | `CREATE 0`, `CREATE2 0`, `CALLCODE 0`, `DELEGATECALL 0`, `SELFDESTRUCT 0`; `CALL 2`, `STATICCALL 5` verified present as positive control |

Sprint-2 runtime invariants intact. This is non-regression verification only, as
scoped.

---

## 8. Full regression under exact v1.5.0 — green

Toolchain asserted **before** relying on any Foundry-dependent evidence, per the
node's own §8 rule. `FOUNDRY_PROFILE=ci`, `run-all.sh` → **exit 0**.

| claim | verified |
|---|---|
| 61/61 tests | ✅ `61 tests passed, 0 failed, 0 skipped` |
| 10,000 fuzz runs | ✅ all four `testFuzz_*` at `runs: 10000` |
| `run-all.sh` exit 0 | ✅ |
| all provenance gates green | ✅ 8 gates |
| 63/63 vendored identities | ✅ byte-identical |
| 28 OZ / 32 v3-core / 3 Miner | ✅ exact counts |
| canonical pool hash exact | ✅ §5 |
| drift demo | ✅ green (`demo-drift-negative.sh` in CI job) |
| source-boundary demo | ✅ exit 0, all 12 probes, byte-exact restoration |
| probe 12 | ✅ §9 |
| no new dependency | ✅ |
| no `forge-std` | ✅ |
| no `lib/` | ✅ |
| no package-manager drift | ✅ no `package.json`/lockfiles |

Enforcement is exact. `verify-pins.sh` now **fails closed** on toolchain identity
rather than printing it — `ok  running Foundry is foundry v1.5.0 @
1c57854462289b2e71ee7654cd6666217ed86ffd (self-reported)`. CI requires the
executing binary to self-report the exact 40-character commit *and* the version
string, so neither a mislabelled build nor a commit that once shipped under a
different tag satisfies it. No `stable` / `latest` / `nightly` / branch reference
anywhere. The action remains pinned by immutable commit
(`foundry-rs/foundry-toolchain@82dee4ba…`), unchanged by this node.

I checked the `(( FAILURES == 0 )) && pass …` construct added to `verify-pins.sh`
under `set -euo pipefail` for an early-exit hazard. It does not early-exit;
failures accumulate and the script exits non-zero at the summary. Fail-closed
either way. No finding.

---

## 9. Probe 12 — passes for the intended reason

Not a false-positive PASS. The demonstration's own output shows all three
required properties:

1. `solc recorded src/CaseReach.SOL in the importing artifact's metadata.sources — it IS compiled source`
2. `a deployed instance of the .SOL contract EXECUTED — reachability is proven, not inferred` → `[PASS] test_MixedCaseExtensionIsBuildReachableAndExecutable`
3. Foundry's `Unable to resolve imports` diagnostic is printed *as evidence* and explicitly not read as a verdict.

11 negative probes + 1 positive control = 12, all green, working-tree inventory
identical pre/post (`d69cfd5f…`), every probe root removed. Probe 12 was
repaired by toolchain consistency, not by deletion — the positive control
survives.

---

## 10. Scope boundary — zero product mutation

`git status --porcelain -- src/ test/ script/ vendor/ .claude/` → **empty**.

No VUX economic change, no Rig/VEM, no HardReserve mutation, no dependency
addition, no compiler change, no Sprint-3 work. The only non-subject working-tree
changes are `NOTES.md`, five trajectory JSONL files, and one `skills-pending`
SKILL.md — all agent telemetry / retrospective, none in the fingerprint.

## 11. Historical integrity — intact

| check | result |
|---|---|
| `f997c077` untouched | ✅ present, `HEAD == origin/master == f997c077` |
| `89a92055` untouched | ✅ present and reachable |
| no force / rebase / amend | ✅ reflog shows plain `commit` / `checkout` / fast-forward `merge` only |
| prior Sprint-1/2 evidence historical | ✅ still names `v1.0.0`, byte-identical |
| red CI run `31573121028` | ✅ preserved as historical evidence, not rewritten |
| forward supersession, not retrospective mutation | ✅ accepted authority documents unedited; supersession is a dated new document |

---

## 12. A-1 status — REMAINS CLOSED under v1.5.0

Both remediation sites are intact and the closure still holds on the
authoritative toolchain:

- `census.sh:214` `source_universe()` → `-iname '*.sol'`
- `census.sh:236` `loa_zone_solidity()` → `-iname '*.sol'` (one universe, same terms)
- `verify-census.sh:146` factory filename detector → `grep -iE '(^|/)UniswapV3Factory\.sol$'`

Probes 8–11 (repo-root `.SOL`, `docs/` `.SoL`, pruned Loa zone `.sOl`,
prohibited-source behind `.SOL`) each fired for the boundary reason and returned
green after removal. The originally identified mixed-case extension weakness is
closed. A-1 stands closed; Sprint-1 N-2 stays retracted.

---

## 13. M-1 status — real, correctly classified, **and widened by this transition**

I reproduced M-1 independently in a throwaway project outside the repository,
under authoritative v1.5.0:

| planted source | in `metadata.sources` | executes |
|---|---|---|
| `src/Arbitrary.txt` | ✅ yes | ✅ `[PASS]` |
| `src/NoExtension` (no extension at all) | ✅ yes | ✅ `[PASS]` |

Against the same tree, the exact `census.sh` universe walk
(`find … -iname '*.sol'`) returns only `src/Main.sol` and `test/M1.t.sol` — both
odd-extension sources are **invisible to enforcement while being compiled and
executed**. The factual claim is confirmed. MEDIUM is the correct severity.

**One thing the report does not say, and should.** I ran the same project under
the superseded toolchain:

```
$ forge-v1.0.0 build --force
Error: unexpected file extension
EXIT=1
```

Under v1.0.0 the orchestrator **refused** odd-extension sources outright — an
accidental but real fence. Under v1.5.0 they compile, execute, and evade the
extension-keyed inventory. **This refreeze does not merely inherit M-1's
exposure; it creates the reachable form of it.** Both halves of this fact are
recorded in the authority (§10's v1.0.0 hard-fail row, §11's v1.5.0 evidence)
but are never joined, and §4 "what this refreeze does NOT change" does not
mention source-admission policy. Filed as **T-2**.

**Is the carry-forward sufficient? Yes — and M-1 does not make this refreeze
unsafe to land.** Reasoning:

1. The current subject contains **zero** odd-extension sources. The universe is
   77 Solidity files (63 vendored + 14 VUX-owned), fully classified, zero
   unauthorized; the Sprint-2 audit's compiler-metadata cross-check found all 47
   actually-compiled sources classified.
2. M-1 requires an explicit `import` from inside an authorized root — a
   deliberate act, not passive injection.
3. No new product Solidity is authorized before Sprint 3, and M-1 is already a
   **binding pre-Sprint-3 condition**. The exposure window is bounded by the
   same gate that closes it.
4. The alternative is worse. Staying on v1.0.0 preserves a live divergence in
   which local implementation/review/audit evidence and CI evidence come from
   different toolchains — the condition that made run `31573121028` red while
   local checks were honestly green. A widened *latent* weakness behind a
   binding gate is a smaller risk than an *active* evidence split.

T-2 asks for the widening to be stated, not for M-1 to be remediated here.
Remediating M-1 in this node would have broken its bounded scope; declining to
was correct.

---

## 14. Findings

### T-1 — MEDIUM — Authority MD §9 whole-artifact hash column is not reproducible

`docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md` §9 publishes
nine whole-artifact digests: `2d65f5d3…` (pool creation), `b401e8e1…` /
`26e3fb15…` (VUX v1.0.0), `fc426937…` / `a0e919c7…` (VUX v1.5.0), `7c82de05…` /
`1ffda37f…` (HardReserve v1.0.0), `d7e27406…` / `83dc1a3d…` (HardReserve
v1.5.0).

None reproduce. I searched SHA-256 **and** Keccak-256, over raw bytes / hex
string / `0x`-prefixed hex / trailing-newline variants, over the bytecode object
and the artifact file, from in-repo `out/` and from clean scratch builds under
both toolchains. Zero hits. My values are `f8165e94…`, `a1f05f65…` / `3ce648aa…`,
`bbb2e97f…` / `70d8cde4…`, `68d2a5e6…` / `3cc547bc…`, `04b55338…` / `38a04ea0…`.

Why this is MEDIUM and not HIGH: **no conclusion depends on these values.** The
parity finding is carried by §9.1, whose four stripped-code hashes reproduce
exactly and whose stated lengths match mine byte-for-byte; the JSON companion —
the machine-readable authority — publishes only the reproducible values. The
§9 column is a redundant presentation of a comparison I independently confirmed.

Why it is not LOW: this document is now SHA-256-pinned into the gate set and is
binding authority. A future node checking parity against these published
constants will get a mismatch and be unable to distinguish "the subject drifted"
from "the convention differed" — the exact failure this repository already
extracted a skill about. Correcting it now costs one coordinated edit
(`TOOLCHAIN_MD_SHA256` in `census.sh`); correcting it after landing makes it an
authority-supersession event.

**Recommended:** restate §9's column under the same convention as §9.1 (which is
`n+2`-stripped, hex-string SHA-256) or drop the column and cite §9.1, then
re-pin. Not required before audit.

### T-2 — MEDIUM — The authority does not record that this transition widens M-1

See §13. §4's scope statement enumerates compiler, build settings, pool hash,
source-reuse, dependencies, licence, and economic parameters — all correctly
unchanged — but omits that the orchestrator's **source-admission policy** did
change: v1.0.0 refused non-`.sol` extensions (`unexpected file extension`),
v1.5.0 admits them. The two supporting facts are in §10 and §11 but are never
connected, so a reader of §4 concludes the transition is provenance-neutral when
on this one axis it is not.

**Recommended:** add one row to §4 or one sentence to §12 obligation 1 stating
that the reachable form of M-1 is created by this transition, so the
pre-Sprint-3 condition is understood as newly load-bearing rather than inherited.
Not required before audit.

### T-3 — LOW — `sdd.md` supersession note breaks the §2.1 markdown table

The blockquote is inserted **between table rows**, after the `Toolchain` row and
before the `AMM: @uniswap/v3-core` row. In GitHub-flavored Markdown a blockquote
plus blank line terminates the table; the three following rows (`AMM:…`,
`Allowlisted reuse`, `External runtime interfaces`) have no header/delimiter pair
of their own and render as literal pipe-delimited text rather than table rows.

**Recommended:** move the blockquote to immediately **after** the final table row.
Content is correct — placement is the defect.

### T-4 — LOW — `sdd.md`'s accepted SHA moved with no before/after in the authority

`grimoires/loa/sdd.md` was at its operator-accepted SDD v1.6.0 hash
`19241ed7db8a89b419e746463c6121f5b77c8237d760829e2f2604536c37392a` at
`f997c077`; it is now `31be6dfa…`. The edit itself is authorized in kind — the
dispatch names "forward-looking docs requiring bounded supersession notes" as a
valid class, the historical pin is preserved verbatim, and no gate pins
`sdd.md`.

The gap is bookkeeping: the JSON's `supersedes_foundry_selection_in` entry for
`sdd.md` carries `edited_by_this_node: true` but **no `sha256` field**, while the
two unedited entries beside it both carry one. An accepted artifact's hash moved
and neither the prior nor the new value is recorded in the authority that
authorized the move.

**Recommended:** add `sha256_before` / `sha256_after` to that entry.

### T-5 — LOW — `drift-negative-demonstration` job installs Foundry, never asserts it, never uses it

`.github/workflows/provenance.yml:80` installs the toolchain in the drift job,
which has **no** identity-assertion step — the only Foundry-installing job of the
three without one. I verified this is harmless today: neither
`demo-drift-negative.sh` nor the `verify-census.sh` it invokes calls
`forge`/`cast`/`anvil` at all, so the job produces no Foundry-dependent evidence.

It remains an asymmetry with the node's own §8 binding rule, and the standing
install is an invitation: the first drift probe that reaches for the compiler
would run unasserted, in the one job nobody thought to guard.

**Recommended:** either drop the install (nothing uses it) or add the same
assertion block the other two jobs carry. Dropping it is the smaller diff and
makes the "needs only git + jq" property true again.

### T-6 — LOW — Subject fingerprint published under an undeclared, non-standard convention

See §1.1.

**Recommended:** publish the fingerprint under the established two-space
convention, or state the convention inline where the fingerprint is recorded.

---

## 15. Verdict

**APPROVED.**

| axis | status |
|---|---|
| v1.5 authority transition valid | ✅ **Yes** — upstream identity verified from primary evidence; supersession is narrow, dated, and forward-only |
| semantic bytecode parity established | ✅ **Yes** — independently reproduced under both toolchains; executable code byte-identical in all four differing artifacts; difference is metadata `evmVersion` only |
| CI / tooling enforcement exact | ✅ **Yes** — exact 40-char commit required and self-reported; fail-closed locally and in CI; no mutable reference; action SHA-pinned |
| A-1 status | ✅ **CLOSED** and re-verified under v1.5.0 |
| M-1 disposition | ⚠️ **Real, MEDIUM, correctly carried forward** — pre-Sprint-3 binding condition is sufficient; **but** its reachable form is created by this transition (T-2) and that should be on the record |
| historical integrity | ✅ **Intact** — no rewrite, no force-push, red CI preserved |
| scope | ✅ **Zero product mutation** — `src/`, `test/`, `script/`, `vendor/`, `.claude/` untouched |
| **ready for exact-tree audit** | ✅ **Yes** |

Counts: **0 critical / 0 high / 2 medium / 4 low.**

Neither MEDIUM undermines toolchain authority, reproducibility of the parity
*finding*, provenance enforcement, exact identity, semantic bytecode
equivalence, historical integrity, or scoped migration correctness. T-1 is a
presentation defect in a redundant column whose conclusion I verified by other
means; T-2 is a missing sentence about a fact the same document already
establishes in two places. Both are cheapest to fix before the landing commit,
because both live in a SHA-pinned authority document — but neither is a reason to
hold the refreeze, and the refreeze itself closes a live evidence divergence that
is materially worse than anything found here.

The four LOWs are documentation and hygiene residue. None blocks.

## 16. Next steps

1. Optionally fold T-1 and T-2 into the authority MD (+ re-pin `TOOLCHAIN_MD_SHA256`) and T-3/T-4 into `sdd.md` / the JSON before the landing commit.
2. Exact-tree audit of subject `3a73d6d3…e07a31`.
3. Land as a forward fix commit through the normal lifecycle; let its own CI run go green. Do not amend `f997c077` or `89a92055`.

T-1…T-6 are carried forward as disclosed context for the audit; none requires a
return to implementation.

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":2,"low":4},"sprint_id":"foundry-v1.5-refreeze","ts":"2026-08-12T18:09:24Z"} -->
