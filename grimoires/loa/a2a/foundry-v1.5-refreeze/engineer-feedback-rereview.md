All good

# Focused Re-Review — Foundry v1.5.0 Toolchain Refreeze, Remediation Pass

**Node:** bounded toolchain-authority + CI-recovery node (cycle-002, post-Sprint-2)
**Gate:** `/review-sprint` methodology, narrow re-review of remediation only
**Reviewed:** 2026-08-12
**Base identity:** `master == origin/master == f997c077` (unchanged)
**Prior subject:** `3a73d6d315d55a8bb976f07a2a0b13aaeaaee4a37465cd64ef8b04d190e07a31` — APPROVED, 0/0/2/4
**Verdict:** **APPROVED** — T-1, T-2, T-3, T-4 all closed; 0 critical / 0 high / 0 medium / 3 new low

This document does not replace `engineer-feedback.md`. The prior review is preserved
verbatim: the amended authority's own restatement note (MD L166) references the draft it
supersedes, and T-1…T-6 are defined only there. Overwriting it would destroy the record
this node's own §5 exists to protect.

---

## 1. Entry identity — reconstructed, not accepted

The remediation report omitted the new fingerprint. It is established here.

### 1.1 Convention proven against a known vector first

The prior node published under raw msys `sha256sum` **binary-mode** output —
`<sha256>` + space + `*` + path, `LC_ALL=C sort -k2`, LF, trailing newline (prior review
§1.1, filed there as T-6). Before using it, I re-derived the prior fingerprint from the
prior review's own published per-file table:

```
3a73d6d315d55a8bb976f07a2a0b13aaeaaee4a37465cd64ef8b04d190e07a31   reconstructed
3a73d6d315d55a8bb976f07a2a0b13aaeaaee4a37465cd64ef8b04d190e07a31   published
```

Exact. The implementation is proven against a known vector *before* being applied to the
mutated set.

### 1.2 New subject fingerprint

```
d928361c07e6f98a116e09e72f808a47bb94d5eb6d3b5cb3100396dc2e26bf46
```

Reproduce with `sha256sum <the 8 files below> | LC_ALL=C sort -k2 | sha256sum`.

Under the *accepted audit-subject* two-space convention the same set yields
`0d578bfaa1dfafabdfdea0d60a4fad7896121b83e57eb426b6484118b53c41df`. Both are recorded so
the auditor can key off either without a convention-recovery step (T-6 still open, §7).

### 1.3 Exact 8-file subject set — same set, no additions, no removals

| SHA-256 | Path | vs. prior |
|---|---|---|
| `cb025d84481b7c186e4d6af1f0f8b1c033a72e0742d7519750de2112711fe6bd` | `.github/workflows/provenance.yml` | unchanged |
| `f83853492bd6894457813ef96dc23745cb1b52f04b684397623cacbc185224aa` | `docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.json` | **changed** |
| `439bdef308a79d1df20e4e43e2c3ec138af5bcd77dce3113a1a31befac20830a` | `docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md` | **changed** |
| `c61a680ebc5cbf3c779051f0921d9f42ebaa8e3750675aefd283bb9bee1ae445` | `foundry.toml` | unchanged |
| `42785845410c9121af15aa29e18b501548d7d6e6f630f4c0c213ace36fc19cff` | `grimoires/loa/sdd.md` | **changed** |
| `7b5ccfbb7bfaa22cc94e083589990b2fcd4bcd8f39a1740e800de54c99354a11` | `tools/provenance/README.md` | unchanged |
| `26aa14b42c6a91e3a36133501765dc11bf16bd85b1c37c5e6403cb47a3600eb7` | `tools/provenance/census.sh` | **changed** |
| `aa41bab61e1ad62856a9ca9548aed78934b313582571946005964ea6825df5bd` | `tools/provenance/verify-pins.sh` | unchanged |

**Exactly four files differ, and they are exactly the four reported.** The other four are
byte-identical to the previously reviewed subject. No file added, none removed. Scope is
bounded as declared; `HITL_REQUIRED` is not triggered.

### 1.4 census.sh mutation bounded by preimage reconstruction

`census.sh` is the one *executable* file in the mutation set, so "only re-pinned authority
hashes" was not taken on trust. Reverting **only** the two authority constants in the
current file and re-hashing:

```
04ff33996bcec249b6a4bf04519034c0e72080036fb89ed16dcc29a5be8305b3   reconstructed
04ff33996bcec249b6a4bf04519034c0e72080036fb89ed16dcc29a5be8305b3   prior published
```

Exact. The `census.sh` diff is provably **nothing but** `TOOLCHAIN_MD_SHA256`
(`census.sh:37`) and `TOOLCHAIN_JSON_SHA256` (`census.sh:39`). No logic moved.

### 1.5 Retrospective separation

Retrospective State Zone files did not contaminate the fingerprint — the manifest is the
8 declared paths only. `NOTES.md`, trajectory JSONL, and `skills-pending/` are excluded by
construction. The fingerprint was re-verified **after** every probe in this review,
including two clean-room `forge build --force` runs and the full boundary demonstration:
entry `d928361c…` == exit `d928361c…`. All scratch build directories removed; `git status`
shows no residue.

---

## 2. T-1 — **CLOSED**. Every published digest independently reproduced.

Toolchain asserted before any Foundry-dependent evidence (§8 binding rule):
`forge 1.5.0-v1.5.0`, `Commit SHA: 1c57854462289b2e71ee7654cd6666217ed86ffd`.

### 2.1 The convention is stated unambiguously

MD §9.0 (`…refreeze-2026-08.md:142`), mirrored in JSON
`parity_validation.digest_convention`:

> SHA-256 over the artifact's `bytecode.object` / `deployedBytecode.object` field taken as
> its lowercase hex **string** — `0x` prefix removed, no trailing newline, hashing the
> ASCII hex characters and **not** the decoded bytes.

It names the preimage, the encoding, the prefix handling, the newline handling, and the
§9.1 stripping rule (`n + 2` trailing bytes, `n` = big-endian value of the final two
bytes). It also states explicitly that hashing decoded bytes is a *different* valid
convention yielding different constants — precisely the ambiguity that made the superseded
column unresolvable. The `sed 's/^0x//'` in the published recipe is load-bearing, not
decorative: `.bytecode.object` does carry a `0x` prefix (verified).

### 2.2 The recipe regenerates the published values

Reproduced from **clean-room `--force` builds under both toolchains** into separate
`FOUNDRY_OUT` directories — not from the in-repo `out/` alone. All ten §9 whole-artifact
digests reproduce exactly:

- `UniswapV3Pool` creation — `888deca479325b2bdfed6c48f6ced356271fcba13e09d864a2f6986d8097fe43`, identical across both toolchains ✅
- `UniswapV3Pool` deployed — `ecd7503ff9ba5cface57946e85117c0c07796c0a5f2d7fe7ec20a54ec254510f`, identical across both toolchains ✅
- `VUX` creation — v1.0.0 `52abdc247094420c952a782105df509ac1ea49b061af0d59eed2ceee40b1890e` / v1.5.0 `d39b3892c686f3c5cd77c7ee3865e28ad4c464c87e341094fe8c7be073a5a7c7` ✅
- `VUX` deployed — v1.0.0 `05207c2747bddb2a2277192e61caea6502cb1922147ab838fed57a19c04eeb45` / v1.5.0 `77c07c4ae72b6907e26d92098b4a09b08e546dc653c37f58be6c0bc4fc7285ba` ✅
- `HardReserve` creation — v1.0.0 `1f977cbbe4a7f5ab7cf8d9cfb6e7736f6b90cce7c1522203be7ef0c2b152cd89` / v1.5.0 `27655d138a377a902d8c60d4bdff1cfba7794ce24788e3ed47174afb04289eaf` ✅
- `HardReserve` deployed — v1.0.0 `11b4ebd2928b4b6be16e7e48c16a9b6f4d1fc8cb6525fc739196d18a4a19d4ea` / v1.5.0 `d4cbe285488b96195e79e6ef4f79d4812b430e0c513303ecfb46639dcea45fd0` ✅

The v1.5.0 column was additionally re-derived from a second, forced clean rebuild to rule
out a stale artifact: identical.

### 2.3 §9.1 retained digests all reproduce, from both toolchains

| artifact | hex chars (claimed / measured) | code SHA-256, both toolchains |
|---|---|---|
| `VUX` creation | 22,666 / **22,666** | `3f8ffe9ebacd3b5962fbef8aa19e3b8fb00916e356c9bca0773d405691a52fa6` ✅ |
| `VUX` deployed | 15,872 / **15,872** | `7377122c247ecc7da63099b3818c1db506c33f71eee2c6dfa8b9429275a32ed2` ✅ |
| `HardReserve` creation | 9,366 / **9,366** | `2184162f1cdecde87cbaecd09a0a80429cff48a33baf0fa2909712aca100e105` ✅ |
| `HardReserve` deployed | 6,398 / **6,398** | `065241a187cc91b53e174775c387cf6966e76e0d55b567ccd9e606074d804a07` ✅ |

Whole-artifact byte lengths also match §9 (L164) exactly: `VUX` 11,386 / 7,989,
`HardReserve` 4,736 / 3,252, `UniswapV3Pool` 22,728 / 22,142.

### 2.4 No superseded unexplained digest remains active

All nine superseded values (`2d65f5d3…`, `b401e8e1…`, `26e3fb15…`, `fc426937…`,
`a0e919c7…`, `7c82de05…`, `1ffda37f…`, `d7e27406…`, `83dc1a3d…`) are **absent from every
subject file** and from all active authority. They survive only in the prior review that
found them and in `skills-pending/separate-codegen-from-metadata-in-a-bytecode-diff/SKILL.md`
— both retrospective State Zone, outside the subject, correctly historical. MD §9's
restatement note (L166) discloses the change rather than silently swapping constants.

### 2.5 The digest evidence supports the exact claims made

Verified independently, not inferred from tests passing:

- **Executable bytecode identical after CBOR stripping** — §2.3 above, all four artifacts,
  both toolchains, at identical length.
- **Whole-artifact differences are metadata-only** — `diff` of the two `metadata` objects
  yields **exactly one line** for each of `VUX` and `HardReserve`.
- **The differing field is `evmVersion: cancun → prague`** — read directly out of each
  artifact; `metadata.sources` hashes identical across toolchains for both contracts;
  compiler identity identical (`0.8.28+commit.7893614a` both sides).
- **`UniswapV3Pool` creation bytecode whole-artifact identical** — `888deca4…` from both
  toolchains, metadata included, consistent with `[profile.v3core]` pinning
  `evm_version = "istanbul"` explicitly.
- **The newly published pool *deployed* digest is truthful and reproducible** —
  `ecd7503f…`, identical across toolchains. It is genuine additional evidence for the
  retained whole-artifact parity claim, not decoration: it extends that claim from creation
  code to runtime code on the one artifact where the whole artifact is invariant. Accepted.

**T-1 is closed.** The load-bearing parity conclusion and the redundant presentation of it
now both reproduce from a stated convention.

---

## 3. T-2 — **CLOSED**. The source-admission consequence is explicit and correctly bounded.

New MD §4.1 (`…refreeze-2026-08.md:67-86`), with a machine-readable twin at JSON
`changed_beyond_selection.source_admission_surface`. Checked against the six things T-2
required:

| required | where | verdict |
|---|---|---|
| v1.0.0 rejects imported odd-extension source (`.txt`, extensionless) | §4.1 table both rows; §10; §11 | ✅ stated |
| v1.5.0 admits them to compilation / `metadata.sources` / execution | §4.1 table; §11 table | ✅ stated |
| the migration therefore changes source-admission behavior | §4.1 L78 | ✅ stated |
| M-1's reachable form is **created** by this transition, not inherited | §4.1 consequence 1; §11 L231; JSON `m1_reachable_form_created_by_this_transition: true` | ✅ stated |
| M-1 remains binding pre-Sprint-3 | §4.1 consequence 2; §12 obligation 1; JSON `carry_forward_disposition` | ✅ stated |
| not unsafe to land — no unauthorized such source, Sprint 3 blocked | §4.1 consequence 3 | ✅ stated |

§4.1 L78 is the sentence T-2 asked for, and it makes the non-inference explicit:

> These are independent axes: byte-identical opcodes for the sources that *are* compiled
> says nothing about which sources the orchestrator is willing to compile.

**No false parity claim.** §4's "unchanged" table does not assert source-admission parity.
Its nearest row, `source-reuse authorisation | none granted, none withdrawn`, is about
Miner reuse authorisation — a different axis — and §4.1 opens by explicitly reframing the
table ("The table above is a list of things that did not move. Exactly one thing beyond
the orchestrator selection itself **did**"). §12 obligation 1 carries "newly load-bearing
rather than inherited" into the obligation itself, so the fact survives into the document
a future node will actually read.

### 3.1 The underlying fact independently reproduced

Not inherited from the report or the prior review. Isolated project outside the
repository, no dependencies, both exact toolchains, `.txt` and extensionless sources
explicitly imported from a `.sol` root:

```
v1.0.0  Error: unexpected file extension          EXIT=1
v1.5.0                                            EXIT=0
```

Under v1.5.0, `metadata.sources` of the importing artifact contains `src/Main.sol`,
`src/NoExtension`, **and** `src/Odd.txt` — while the extension-keyed walk
`find src -iname '*.sol'` returns `src/Main.sol` alone. Compiled and invisible to
enforcement, in the same tree. Execution reachability is separately evidenced in-repo by
probe 12, re-run green this session (§6.2).

M-1 was **not** remediated here, correctly.

---

## 4. T-3 — **CLOSED**. §2.1 table renders again.

`grimoires/loa/sdd.md:423-433`. The blockquote moved out from between rows to after the
final row:

```
423  | Category | Technology | Immutable pin … |      header
424  |----------|------------|-----------------|      delimiter
425-431  seven data rows, contiguous                  (Toolchain row at 428)
432  (blank — table ends)
433  > **Toolchain supersession (2026-08-12).** …     blockquote, outside
```

Nine contiguous pipe-lines = header + delimiter + 7 rows, uninterrupted. The three rows
the misplacement previously orphaned (`AMM: @uniswap/v3-core`, `Allowlisted reuse`,
`External runtime interfaces`) are inside the table again.

Substantive content unchanged beyond the intended refreeze note. Diff against the accepted
baseline `f997c077` is **3 insertions / 1 deletion**, entirely within §2.1: the `Toolchain`
row gains `— **SUPERSEDED 2026-08-12**, see note below`, and the blockquote plus its blank
line are added. The historical pin is preserved verbatim — `tag v1.0.0 → commit
8692e926198056d0228c1e166b1b6c34a5bed66c (2025-01-31)` is untouched in the row. All twelve
tables in the authority MD are structurally valid (12 delimiter rows, no truncated table).

---

## 5. T-4 — **CLOSED**. Both SHAs truthful and independently reproduced.

| value | JSON field | independently computed by | match |
|---|---|---|---|
| `19241ed7db8a89b419e746463c6121f5b77c8237d760829e2f2604536c37392a` | `sha256_before` | `git show f997c077:grimoires/loa/sdd.md \| sha256sum` | ✅ |
| `42785845410c9121af15aa29e18b501548d7d6e6f630f4c0c213ace36fc19cff` | `sha256_after` | `sha256sum grimoires/loa/sdd.md` | ✅ |

Recorded consistently at JSON `supersedes_foundry_selection_in[2]` (L24-30), alongside
`sha256_before_ref: "operator-accepted SDD v1.6.0 content at commit f997c077"` — the right
provenance anchor, and one I verified resolves to exactly that content. The entry's
`disposition` also now records the T-3 placement fix. The two unedited entries beside it
retain their single `sha256` field; the asymmetry T-4 flagged is resolved.

---

## 6. Authority repinning and regression — green, exact

### 6.1 Repinning is exact and nothing unrelated moved

`census.sh:37` `TOOLCHAIN_MD_SHA256` = `439bdef3…` = current MD, byte-for-byte.
`census.sh:39` `TOOLCHAIN_JSON_SHA256` = `f8385349…` = current JSON, byte-for-byte. The
gate validates the **exact amended files**:

```
== toolchain authority ==
ok    toolchain refreeze authority byte-identical to the accepted values
```

No unrelated pin moved — proven by §1.4's preimage reconstruction (the only two changed
constants in the file are these), and confirmed live: `4 accepted authority artifacts match
their recorded SHA-256`; `FOUNDRY_TAG` / `FOUNDRY_COMMIT` unchanged at `v1.5.0` /
`1c578544…`; `POOL_INIT_CODE_HASH` unchanged.

### 6.2 Regression — no item regressed

`FOUNDRY_PROFILE=ci bash tools/provenance/run-all.sh` → **exit 0**.

| claim | verified |
|---|---|
| `verify-pins.sh` | ✅ standalone exit 0, all sections ok |
| `run-all.sh` | ✅ exit 0, "All provenance gates and tests passed" |
| 61/61 tests | ✅ `61 tests passed, 0 failed, 0 skipped` (6 suites) |
| 10,000-run fuzz depth | ✅ all `testFuzz_*` at `runs: 10000` |
| provenance gates | ✅ all green — census, byte identity, boundary, excluded-source, pins, SPDX, notices, quarantine, launch hygiene |
| 63/63 vendored identities | ✅ byte-identical; 28 OZ / 32 v3-core / 3 Miner exact |
| source universe | ✅ 77 Solidity files classified, **zero unauthorized** |
| canonical pool hash | ✅ `POOL_INIT_CODE_HASH reproduced and equal to the accepted constant` |
| source-boundary demo | ✅ exit 0, 12/12 probes, byte-exact restoration (`382441f2…`) |
| probe 12 positive control | ✅ `[PASS] test_MixedCaseExtensionIsBuildReachableAndExecutable` — preserved, not deleted |
| drift demo | ✅ fails closed on a one-byte mutation, exact tree restored, green after |
| running Foundry identity | ✅ self-reported `v1.5.0 @ 1c578544…`, fail-closed |
| no new dependency / no `forge-std` / no `lib/` | ✅ no `lib/`, no package manifests, no submodules; the two `forge-std` hits are `@notice` comments documenting its deliberate absence (`test/harness/BaseTest.sol:7`, `test/harness/Vm.sol:6`) |

### 6.3 Preservation — all confirmed unchanged

Foundry v1.5.0 selection; commit `1c57854462289b2e71ee7654cd6666217ed86ffd`; solc `0.8.28`
@ `7893614a…`; solc `0.7.6` @ `7338295f…`; v3 build settings (optimizer, runs 800,
istanbul, `bytecode_hash = none`); `POOL_INIT_CODE_HASH` `0xe34f199b…f87b8b54`; the four
prior accepted authority artifacts (gate-verified byte-identical); product Solidity, tests,
vendor, dependencies — `git status --porcelain -- src/ test/ script/ vendor/ .claude/ lib/`
is **empty**.

Repository history intact: `HEAD == origin/master == f997c077`; reflog shows only plain
`commit` / `checkout` / fast-forward `merge` / `cherry-pick` — no amend, rebase, reset, or
force-push. `89a92055` reachable. Red CI run `31573121028` preserved as historical evidence.

ABI / method-identifier / runtime-opcode-surface parity was established in the prior review
and is **structurally unaffected** by this mutation — the four changed files are two
authority documents, one SDD, and two hash constants; none is a compilation input. Stated
as inherited, not re-claimed as re-verified this pass.

### 6.4 M-1 — **OPEN**, and pre-Sprint-3 blocking

Not remediated (correctly). JSON `m1_status.remediated_by_this_node: false`;
`carry_forward: "bounded provenance-hardening node before Sprint-3 product
implementation"`; `carry_forward_disposition: "newly load-bearing rather than inherited;
binding pre-Sprint-3 condition, not discharged, narrowed, or deferred by this document"`.
MD §12 obligation 1: "Sprint-3 product Solidity is blocked until it closes." Re-established
as fact in §3.1 above.

---

## 7. Findings this pass

**0 critical / 0 high / 0 medium / 3 new low.** No new MEDIUM-or-higher issue was
introduced. All three are documentation hygiene; none blocks audit.

### R-1 — LOW — The remediation published no subject fingerprint

The mutation changed the subject identity and shipped no new fingerprint, so between
remediation and this review the subject had no published identity. Established here (§1.2)
under both conventions. This is the second consecutive node where subject identity cost a
reviewer a reconstruction step.

**Recommended:** record `d928361c…` and its convention wherever the prior `3a73d6d3…` was
recorded, before audit.

### R-2 — LOW — JSON companion omits the now-reproducible §9 whole-artifact digests

`…refreeze-2026-08.json:113-129` publishes `digest_convention` and the four
`code_sha256_metadata_stripped` values, but none of the ten §9 whole-artifact digests the
MD now carries. Under the prior draft that asymmetry was a virtue — the JSON deliberately
carried only reproducible values. Now that §9 reproduces, the machine-readable authority is
a strict subset of the human-readable one for no stated reason, and a machine consumer
cannot re-derive the whole-artifact half of the parity claim from the JSON alone.

**Recommended:** add the ten values to `parity_validation`, or state in the JSON that §9's
table is MD-only by design.

### R-3 — LOW — §9's constants depend on an unpinned build input, and §9.0 does not say so

`[profile.default]` deliberately leaves `evm_version` unset (`foundry.toml`; MD §9.2 L190).
§9's v1.5.0 column is therefore only stable while the orchestrator default remains
`prague`. Within this authority that is coherent — the toolchain is pinned to an exact
commit, which is what makes the values reproducible at all. But §9.0 describes the
*hashing* precisely while saying nothing about the *build-input* dependency, so a future
node on a newer Foundry gets a clean mismatch on the v1.5.0 column with no in-document
explanation — a softer replay of exactly the failure mode T-1 identified.

**Recommended:** one sentence in §9.0 — these constants hold for the pinned orchestrator
identity; a toolchain move can change them with no repository change. Same fact §12
obligation 2 already carries; §9.0 is where a reader hits it.

### Carried forward, not remediated (as scoped)

- **T-5 — LOW** — `.github/workflows/provenance.yml:80`: the drift job still installs
  Foundry with no identity assertion. `provenance.yml` is byte-identical to the prior
  subject, so this is unchanged, not regressed. Still harmless today — neither
  `demo-drift-negative.sh` nor `verify-census.sh` invokes `forge`/`cast`/`anvil`.
- **T-6 — LOW** — the fingerprint convention is still undeclared at the point of record.
  R-1 is its recurrence.

---

## 8. Adversarial Analysis

### Concerns Identified

1. **`docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md:190`** — §9.2
   records that an unset `evm_version` lets the orchestrator supply a build input, but does
   not connect that to §9's own constants becoming perishable across toolchain moves. Filed
   as R-3. The document diagnoses the hazard in one section and is exposed to it in another.
2. **`tools/provenance/census.sh:37`** — the authority MD is now SHA-pinned by a file that
   is itself in the fingerprinted subject. Any future correction to §9 requires a
   coordinated two-file edit or the gate fails closed; a coordinated mutation of both passes
   it. That is inherent to a self-hosted pin set, and the operator-accepted fingerprint is
   the mitigation — but it means the cost T-1 predicted ("correcting it after landing makes
   it an authority-supersession event") is now real and was paid once. A third correction
   pass costs the same again, which argues for folding R-1/R-2/R-3 in *before* landing.
3. **`docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.json:113`** — the
   JSON/MD asymmetry (R-2). A consumer that treats the JSON as *the* machine-readable
   authority will silently under-verify parity relative to a reader of the MD.

### Assumptions Challenged

- **Assumption**: restating §9 under §9.1's convention fully closes T-1.
- **Risk if wrong**: T-1's deeper claim was that a *future* node must be able to re-derive
  parity. Reproducibility now holds under the exact pinned toolchain — I verified all ten
  values from clean-room builds — but the constants depend on a build input that no
  repository file pins.
- **Recommendation**: T-1 is genuinely closed on its stated terms; the residue is R-3, one
  sentence, and it belongs to §12 obligation 2 rather than to this node's scope.

### Alternatives Not Considered

- **Alternative**: drop §9's whole-artifact column entirely and cite §9.1 — the cheaper of
  the two remedies the prior review offered.
- **Tradeoff**: it would have produced a smaller document and sidestepped R-3 entirely. But
  the parity claim is two-sided — "differ **only** in the trailing metadata CBOR" needs both
  the demonstrated difference and the demonstrated stripped identity. Dropping the column
  would have left the difference half unevidenced and pushed a future auditor back to
  rebuilding both toolchains to see it at all.
- **Verdict**: the harder option was the right one. Restating under a declared, verified
  convention preserves the full evidence chain and cost one extra re-pin that had to happen
  anyway.

---

## 9. Verdict

**APPROVED.**

| axis | status |
|---|---|
| subject identity reconstructed | ✅ `d928361c07e6f98a116e09e72f808a47bb94d5eb6d3b5cb3100396dc2e26bf46` |
| subject set | ✅ same 8 files, no additions or removals |
| mutation scope | ✅ exactly the 4 reported files; `census.sh` bounded to 2 constants by preimage reconstruction |
| T-1 | ✅ **CLOSED** — convention stated; all 10 §9 + 4 §9.1 digests reproduced from clean-room builds under both toolchains |
| T-2 | ✅ **CLOSED** — source-admission widening explicit in §4.1/§11/§12 + JSON; no false parity claim; fact independently reproduced |
| T-3 | ✅ **CLOSED** — §2.1 table contiguous, blockquote outside, content otherwise unchanged |
| T-4 | ✅ **CLOSED** — both SHAs truthful, independently reproduced, consistently recorded in JSON |
| new findings | ✅ 0 critical / 0 high / 0 medium / 3 low (R-1, R-2, R-3) |
| M-1 | ⚠️ **OPEN** — binding pre-Sprint-3 blocker, correctly not remediated, now recorded as created-by-this-transition |
| preservation | ✅ toolchain, solc pins, build settings, pool hash, predecessor authority, product, tests, vendor, deps, history all unchanged |
| regression | ✅ 61/61, all gates, 63/63 identities, boundary + drift demos, pool hash — exit 0 |
| **ready for exact-tree audit** | ✅ **Yes — subject `d928361c07e6f98a116e09e72f808a47bb94d5eb6d3b5cb3100396dc2e26bf46`** |

All six acceptance conditions hold. The two MEDIUMs selected for remediation are closed on
their stated terms and verified against primary evidence rather than the remediation
report; the two LOWs are truthful; scope stayed bounded; M-1 remains explicitly deferred
and blocking; nothing MEDIUM-or-higher was introduced.

R-1/R-2/R-3 are cheapest to fold in before the landing commit for the same reason T-1 was —
two of the four mutated files are SHA-pinned authority — but none blocks the audit, and
none touches a load-bearing claim.

## 10. Next steps

1. Record subject fingerprint `d928361c…` and its convention alongside the node's evidence
   — closes R-1 and the recurrence of T-6.
2. Optionally fold R-2 / R-3 into the JSON and MD §9.0 (+ re-pin both hashes in
   `census.sh`) before landing.
3. Exact-tree audit of subject `d928361c07e6f98a116e09e72f808a47bb94d5eb6d3b5cb3100396dc2e26bf46`.
4. Land as a forward fix commit through the normal lifecycle. Do not amend `f997c077` or
   `89a92055`.

Not invoked from this review: audit. Stopping here as scoped.

---

## 11. Addendum — canonical audit subject resolved (bookkeeping)

§1.2 published two digests for one subject. They are two conventions over the **same
eight files**, not two subjects. Resolved here; **R-1 is discharged by this section.**

### 11.1 The established audit convention, proven against its operator-accepted vector

The Sprint-2 audit subject digest was computed as `<sha256>` + **two spaces** + path,
`LC_ALL=C` sorted by path, LF, written to a file (hence trailing newline), then hashed —
the exact command is preserved at `.run/audit.jsonl:676`. That digest,
`a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf`, carries
`OPERATOR_ACCEPTANCE` recorded 2026-08-12 (beads `vux-31v`, comment 11).

I reconstructed it from the landing tree `89a92055` before relying on the convention:

```
18 files
a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf   reconstructed
a6313a4d5a8a75f0edf0a68b13adaf4c51f5d510b888973337620fb4f2b772cf   operator-accepted
```

Exact, at the exact recorded file count. The convention and my implementation of it are
both proven against a known operator-accepted vector.

### 11.2 Canonical audit fingerprint

```
0d578bfaa1dfafabdfdea0d60a4fad7896121b83e57eb426b6484118b53c41df
```

**This is the single fingerprint for the exact-tree audit.** Canonical manifest:

```
cb025d84481b7c186e4d6af1f0f8b1c033a72e0742d7519750de2112711fe6bd  .github/workflows/provenance.yml
f83853492bd6894457813ef96dc23745cb1b52f04b684397623cacbc185224aa  docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.json
439bdef308a79d1df20e4e43e2c3ec138af5bcd77dce3113a1a31befac20830a  docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md
c61a680ebc5cbf3c779051f0921d9f42ebaa8e3750675aefd283bb9bee1ae445  foundry.toml
42785845410c9121af15aa29e18b501548d7d6e6f630f4c0c213ace36fc19cff  grimoires/loa/sdd.md
7b5ccfbb7bfaa22cc94e083589990b2fcd4bcd8f39a1740e800de54c99354a11  tools/provenance/README.md
26aa14b42c6a91e3a36133501765dc11bf16bd85b1c37c5e6403cb47a3600eb7  tools/provenance/census.sh
aa41bab61e1ad62856a9ca9548aed78934b313582571946005964ea6825df5bd  tools/provenance/verify-pins.sh
```

### 11.3 What the other digest was

`d928361c07e6f98a116e09e72f808a47bb94d5eb6d3b5cb3100396dc2e26bf46` is the **same eight
files under the prior node's undeclared msys `sha256sum` binary-mode convention** —
`<sha256>` + one space + `*` + path. It is the convention that produced `3a73d6d3…e07a31`,
and it exists in this report solely so the two review passes can be chained: `3a73d6d3…`
(reviewed) → `d928361c…` (remediated), same convention, same 8 paths. It is **not** an
audit subject identity and must not be presented to the audit gate. This is the recurrence
of T-6 that R-1 named.

Per-file SHA-256 values are identical under both conventions — only the manifest's
separator differs — so the two digests cannot disagree about content, only about encoding.

### 11.4 Subject-membership note for the auditor

The Sprint-2 auto-discovery filter (`git diff --name-only` + untracked, minus
`grimoires/` `.beads/` `.run/`) yields **7** of these paths. `grimoires/loa/sdd.md` is the
eighth and is in the subject by **explicit declaration**, not auto-discovery: it is an
operator-accepted artifact (SDD v1.6.0) that this node edited, and its before/after hashes
are recorded in the authority JSON. An auditor re-deriving the set mechanically will find 7
and must add `sdd.md` by declaration to reach the canonical fingerprint.

### 11.5 Zero mutation

No subject byte was touched by this resolution — it reads and re-encodes, it does not
write. Both digests recomputed after this addendum are unchanged from entry; the 8-file set
and every per-file hash are identical to §1.3.

<!-- LOA-VERDICT {"gate":"review","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":3},"sprint_id":"foundry-v1.5-refreeze","ts":"2026-08-12T21:40:00Z"} -->
