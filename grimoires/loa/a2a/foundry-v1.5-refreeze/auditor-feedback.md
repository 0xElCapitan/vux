# Exact-Tree Audit — Foundry v1.5.0 Toolchain Refreeze

**Node:** bounded toolchain-authority + CI-recovery node (cycle-002, post-Sprint-2)
**Gate:** `/audit-sprint` methodology (`auditing-security`), audit-only posture
**Audited:** 2026-08-12
**Base identity:** `master == origin/master == f997c077` (unchanged, not rewritten)
**Subject fingerprint:** `0d578bfaa1dfafabdfdea0d60a4fad7896121b83e57eb426b6484118b53c41df`
**Verdict:** **APPROVED** — 0 critical / 0 high / 0 medium / 3 low. Safe to accept and land.

Posture: no fix implemented, no commit, no push, no mutation of the audited subject.
Entry fingerprint == exit fingerprint, verified after every probe.

---

## 1. Entry gate — fingerprint independently reproduced

Convention as dispatched: `<sha256><two spaces><path>`, `LC_ALL=C` sort by path,
LF-terminated manifest, SHA-256 of the manifest (813 bytes, final byte `\n` confirmed).

```
0d578bfaa1dfafabdfdea0d60a4fad7896121b83e57eb426b6484118b53c41df   reproduced == dispatched
```

Per-file manifest (the exact 8-file subject, `grimoires/loa/sdd.md` included by explicit
declaration — the auto-discovery filter excludes `grimoires/` and returns only seven):

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

### 1.1 Chain of custody to the APPROVED re-review — closed by cross-convention proof

The focused re-review published this same set under a *different* convention
(msys binary-mode, `sort -k2`), leaving T-6 open. Both conventions were run against the
tree in front of me:

| convention | expected | reproduced |
|---|---|---|
| dispatched two-space | `0d578bfa…c41df` | exact |
| re-review binary-mode | `d928361c…26bf46` | exact |

Both reproduce on one tree, so **the audited tree is byte-identical to the tree the focused
re-review APPROVED.** The custody chain is unbroken without a convention-recovery step; T-6's
practical cost is discharged for this node (the durability gap itself is L-3 below).

---

## 2. Toolchain identity — asserted from executing binaries, not from documents

Per the refreeze's own §8 binding rule, no Foundry-dependent evidence below was relied on
before asserting which binary produced it.

| identity | claimed | binary self-report |
|---|---|---|
| authoritative | `v1.5.0` @ `1c57854462289b2e71ee7654cd6666217ed86ffd` | `forge Version: 1.5.0-v1.5.0` / `Commit SHA: 1c57854462289b2e71ee7654cd6666217ed86ffd` — **exact** |
| superseded | `v1.0.0` @ `8692e926198056d0228c1e166b1b6c34a5bed66c` | `forge Version: 1.0.0-v1.0.0` / `Commit SHA: 8692e926198056d0228c1e166b1b6c34a5bed66c` — **exact** |

The v1.5.0 binary's `Build Timestamp` (2025-11-24T06:08:41Z) is consistent with the
authority's independently-recorded `published_at: 2025-11-24T06:14:42Z` (MD §2.1).

CI asserts the same identity twice — `.github/workflows/provenance.yml:56-69` (gates job) and
`:115-126` (source-boundary job). The commit test precedes the version test and is an exact
40-character match, so the workflow `version:` input is treated as the request and the binary
as the evidence. `forge --version` is multi-line since v1.0.0; `ver="$(forge --version)"`
(`:58`, no `head -1`) captures the `Commit SHA:` line, and `case` globs span newlines. Correct.

---

## 3. Enforcement surfaces — executed, not read

All eight provenance gates executed locally under the exact authoritative toolchain.

| gate | result |
|---|---|
| `verify-pins.sh` | **exit 0** — toolchain authority byte-identical; 3 pins recorded at 40 chars; 50/50 + 32/32 artifacts self-report the pinned solc builds; running forge asserted; no mutable ref; no short SHA; every Action commit-pinned |
| `verify-census.sh` | **exit 0** — 4 authority artifacts match; 28+32+3 exact; 63/63 byte-identical; 77 sources classified, **zero unauthorized**; zero Solidity in pruned Loa zones; zero unenumerated files of any type under `vendor/` |
| `verify-init-code-hash.sh` | **exit 0** — `POOL_INIT_CODE_HASH` reproduced `= 0xe34f199b…8b54`; 2/2 tests pass incl. CBOR-tail confirmation of `bytecode_hash = none` |
| `verify-spdx.sh` / `verify-notices.sh` / `verify-quarantine.sh` / `verify-launch-hygiene.sh` | **exit 0** each |
| `forge test` | **61/61 passed, 0 failed** |

The `verify-pins.sh` upgrade from `info()` print to fail-closed assertion (`:94-105`) is the
substantive hardening of this node, and it is real: with `forge` absent or divergent the gate
`fail()`s and `finish` exits 1. The guarded-`pass` idiom at `:21`
(`(( FAILURES == 0 )) && pass …`) was checked against `set -e` — bash does not abort on a
non-final `&&` operand, so a mutated authority still reaches `finish` and still exits 1.
Fail-closed holds.

`census.sh:36-39` pins both new authority artifacts by SHA-256, and both pins match the files
in this tree exactly — the authority that selects the toolchain is itself tamper-evident.

---

## 4. Parity — every published constant re-derived clean-room under both toolchains

The refreeze's central safety claim is that the orchestrator moved and the product did not.
That claim was not accepted from the narrative. The exact tree was rebuilt under the
superseded v1.0.0 binary into a separate `FOUNDRY_OUT` outside the audited subject, and every
constant in MD §9/§9.1 was re-derived under the §9.0 convention.

**All 14 published digests reproduce exactly. Zero unverified.**

| claim | verification |
|---|---|
| §9 whole-artifact, v1.5.0 column (6 values) | all 6 reproduce exactly |
| §9 whole-artifact, v1.0.0 column (4 values) | all 4 reproduce exactly from a clean-room v1.0.0 build |
| §9.1 stripped-code digests (4 values) | all 4 reproduce, **and are IDENTICAL across the two toolchains** |
| §9.1 code lengths (22,666 / 15,872 / 9,366 / 6,398 hex chars) | exact |
| §9 artifact lengths (11,386 / 7,989 / 4,736 / 3,252 bytes) | exact, pairwise identical across toolchains |
| §9 ABI + method identifiers | VUX 20 and HardReserve 6 — identical, both toolchains |
| §9.1 cause: "exactly one difference in each contract" | `diff` of the full `metadata` objects yields **exactly one line each**: `"evmVersion": "cancun"` → `"prague"`. Nothing else. |
| §9.2 contrast: `[profile.v3core]` pins `istanbul` | `UniswapV3Pool` creation **and** deployed identical whole-artifact, metadata included, both toolchains |

The §9.2 root-cause diagnosis is therefore proven by its own control, not asserted: the unit
that pins `evm_version` is whole-artifact identical; the unit that leaves it unset differs only
in the metadata tail. **No semantic product regression exists — the emitted opcodes are
byte-identical in all four differing artifacts.**

The MD §9 restatement note (L166), which discloses that an earlier draft published
non-reproducing constants under no stated convention, is accurate and the correction is
complete: the superseded values do not appear anywhere in the subject.

---

## 5. Source-admission surface — the security-relevant change, audited on its own axis

§4.1 correctly refuses to file this under "unchanged". Output parity proves *emission*, never
*admission*: a file the old orchestrator refused appears in neither build's output, so widened
admission is structurally invisible to a bytecode diff.

Verified as stated: under v1.0.0 an imported odd-extension or extensionless Solidity source
hard-fails (`Error: unexpected file extension`) and never reaches solc; under v1.5.0 it reaches
`metadata.sources`, compiles, and executes. The provenance universe
(`census.sh:214`, `-iname '*.sol'`) is extension-keyed and cannot see it. This is M-1, and
§4.1/§11 are correct that **this transition creates M-1's reachable form rather than inheriting
it.** Disclosing that in the authority — rather than leaving it to be inferred by joining §10
and §11 — is the right call and is load-bearing.

### 5.1 Exposure in this exact tree is empirically zero

The safety-to-land argument was not taken on faith. Measured directly:

| probe | result |
|---|---|
| import targets across all 77 Solidity files that are not `*.sol` | **none** — every import resolves to a `.sol` path |
| non-`.sol` files inside declared VUX roots (`src`, `test`, `script`) | 3 empty `.gitkeep` placeholders only; none imported |
| extensionless files in `src`/`test`/`script`/`vendor` | **none** |
| non-`.sol` files under `vendor/` | **none** |
| unauthorized entries in the classified universe | **0 of 77** (63 vendored + 14 VUX) |

So the reachable form exists in the tooling and has **zero instances in the subject**.

### 5.2 Why landing with M-1 open is safe

1. Zero instances present (§5.1), measured, not argued.
2. Exploitation requires a deliberate `import` from inside an authorized root — a
   diff-visible source edit, not passive injection.
3. The accepted authority's default-deny governs source *reuse*, and that surface is already
   enforced extension-agnostically by the `vendor/` check ("zero unenumerated files of **any
   type**") — which passes.
4. Sprint-3 product Solidity is blocked until M-1 closes (MD §12.1, JSON `m1_status`).
5. **The alternative is worse.** Staying on v1.0.0 preserves a live local-vs-CI evidence
   divergence — the actual defect behind red run `31573121028`, where implementation, review
   and audit ran under a different orchestrator than CI. That is an active integrity problem;
   M-1's widened admission is a latent one with zero instances and a standing gate in front of
   Sprint 3.

**M-1 disposition: remains OPEN, correctly graded, severity correctly escalated from
"inherited" to "newly load-bearing". Not remediated here, deliberately and correctly. Binding
pre-Sprint-3 condition intact.**

---

## 6. Preservation and drift

| assertion | result |
|---|---|
| `src/`, `test/`, `script/`, `vendor/`, `.claude/` | **zero** modified, **zero** untracked |
| `lib/` | does not exist (`libs = []`; no `forge-std`) |
| dependency addition | none — `dependencies_changed: false` verified against the tree |
| compiler migration | none — both solc pins unchanged and self-reported by all 82 artifacts |
| v3 build settings | unchanged (`optimizer`/`800`/`istanbul`/`none`, `foundry.toml:86-89`) |
| `POOL_INIT_CODE_HASH` | preserved and reproduced |
| economics / protocol params | untouched (no product Solidity changed) |
| Sprint 3 implementation | none |
| historical authority (5 predecessor artifacts) | all re-hash **byte-identical** to their pinned values |
| tracked non-grimoire changes | exactly the 5 files declared in MD §7 |

Historical preservation is handled correctly: Sprint-1/2 reports and old CI records still name
v1.0.0 and were not rewritten (MD §5, L100). The `sdd.md` change is a pointer added *beneath*
the table with the historical pin preserved verbatim — and the JSON's `sha256_before`
(`19241ed7…37392a`) was independently re-derived from `git show f997c077:` and matches, as does
`sha256_after`. The SDD supersession note is accurate and correctly scoped.

MD/JSON consistency was checked field-by-field across the transition, unchanged, parity,
probe-12 and M-1 blocks: **no contradiction found.**

---

## 7. Findings

### L-1 — Non-asserting restoration check in the drift-negative job (pre-existing)

**Severity:** LOW · **Component:** `.github/workflows/provenance.yml:89-90`

```yaml
- name: Assert the working tree was restored exactly
  run: git diff --exit-code && git status --porcelain --untracked-files=no
```

`git status` exits 0 regardless of tree state, so its output is printed but never asserted;
`--untracked-files=no` additionally excludes untracked residue. The only real assertion is
`git diff --exit-code` (unstaged tracked changes). The sibling source-boundary job does it
correctly at `:137-140` with `test -z "$(git status --porcelain)" || { …; exit 1; }` — the
asymmetry is the finding, in a step whose entire purpose is proving exact restoration.

**Not introduced by this node** (unchanged by the diff) and currently unreachable:
`demo-drift-negative.sh` restores via `trap`+`cp` from a `mktemp` backup, never stages, creates
no untracked files in the repo, and independently re-verifies the restored SHA-256 (`:74-79`)
plus re-runs the drift gate green (`:80-85`). Impact is confined to the strength of the CI-level
restoration claim in an ephemeral runner.

**Remediation:** mirror `:137-140`. Not required before landing.

### L-2 — `[profile.default]` inherits a build input from the orchestrator version

**Severity:** LOW · **Component:** `foundry.toml:33-49`, MD §9.2

`evm_version` is deliberately unset, so the VUX unit takes the Foundry default — which moved
`cancun` → `prague` across this transition, changing recorded metadata (and therefore the CBOR
tail and artifact hash) with no repository change. Verified: **opcodes are byte-identical**, so
there is no semantic regression today, and the contrast unit that pins `istanbul` is
whole-artifact identical.

Already recorded as carried-forward obligation MD §12.2 for the Sprints 7–8 deployment-bytecode
freeze, with the §9.2 finding on the record. Nothing is deployed before that freeze, so this is
not blocking. Pinning it here would freeze an unverified RH-chain opcode-support assumption and
was correctly not authorized in this node.

### L-3 — The pre-Sprint-3 blocker and the fingerprint convention are prose-only

**Severity:** LOW · **Component:** governance surface (no gate)

Two durability gaps, both outside the 8-file subject:

1. **M-1's blocking status is not mechanized.** No gate in `tools/` or `.github/` references
   M-1 or Sprint 3; the block rests on MD §12.1, NOTES.md and operator acceptance. Confirmed by
   search. Enforcement is the operator, not the harness.
2. **The audit-subject fingerprint convention is recorded only in node evidence**, not in any
   durable authority artifact (this is T-6, deliberately left open by two prior gates). Its
   recovery cost is discharged for this node by §1.1, but the next node re-incurs it.

Raised because "M-1 disposition and pre-Sprint-3 blocking status" is a declared audit surface
and this is materially useful on the record. **Deliberately not remediated** — mechanizing the
M-1 gate is M-1 hardening work, which this audit is scoped out of. Natural home: the bounded
pre-Sprint-3 provenance-hardening node, alongside the compiler-`metadata.sources` cross-check
that closes every naming axis at once.

---

## 8. Observations (not findings)

- The `drift-negative-demonstration` job installs the Foundry toolchain but never asserts its
  identity. Correct as-is: `verify-census.sh` never invokes the compiler, so no evidence in
  that job is toolchain-dependent. The install is simply unnecessary. The asymmetric decision
  to *add* the assertion to the boundary job (which runs the toolchain-dependent probe 12) is
  the right one and is reasoned in place at `:110-114`.
- The version test `*"${FOUNDRY_VERSION#v}"*` is a substring match and would accept e.g.
  `1.5.01`. Non-issue: the exact 40-character commit test that precedes it fully determines the
  build.
- Probe 12 was preserved rather than deleted to obtain green CI (MD §10 finding 1). Retaining a
  positive control that was *failing for a real reason* is the correct disposition and is
  visible in `demo-boundary-negative.sh:287-373`, which takes its verdict from `metadata.sources`
  plus an executed deployment and builds outside the repository.

---

## 9. Exit gate

Recomputed after every probe, including the clean-room v1.0.0 builds (written to
`FOUNDRY_OUT` directories outside the subject and removed; no residue).

```
entry: 0d578bfaa1dfafabdfdea0d60a4fad7896121b83e57eb426b6484118b53c41df
exit:  0d578bfaa1dfafabdfdea0d60a4fad7896121b83e57eb426b6484118b53c41df
```

Per-file manifests diffed: **identical**. The audited subject was not mutated.

---

## 10. Verdict

**APPROVED - LET'S FUCKING GO** — the Foundry v1.5.0 refreeze is safe to accept and land.

0 critical / 0 high / 0 medium / 3 low. **No blocking findings.**

It establishes v1.5.0 as authoritative without introducing a security, provenance, compiler,
dependency, historical-integrity, or semantic-product regression. The one security-relevant
surface it *does* change — source admission — is disclosed on its own axis rather than buried,
its consequence for M-1 is escalated rather than inherited, and its exposure in this tree is
measurably zero. M-1 remains OPEN and binding before Sprint 3.

<!-- LOA-VERDICT {"gate":"audit","verdict":"APPROVED","counts":{"critical":0,"high":0,"medium":0,"low":3},"sprint_id":"foundry-v1.5-refreeze","ts":"2026-08-12T00:00:00Z"} -->
