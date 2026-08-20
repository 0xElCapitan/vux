# VUX v1 Static-Analysis Provenance Refreeze (slither)

**Status:** `STATIC_ANALYSIS_PROVENANCE_REFREEZE_CURRENT_ACCEPTED`
**Date:** 2026-08-19 (candidate) / **operator acceptance 2026-08-19**
**Node:** `/implement sprint-8`, Task 8.1 (branch `sprint-8`, baseline `6395cabb4deee5bae50ac79c8094053484261819`)
**Companion registry:** `docs/authority/vux-v1-source-registry-static-analysis-refreeze-2026-08.json`

**Operator acceptance is recorded (2026-08-19, §10).** This document is the evidence packet for the
operator gate recorded at `vux-v1-oz-v3-provenance-refreeze-2026-08.md` §9 and at
`grimoires/loa/sprint.md` ("Static-analysis provenance refreeze — no slither use before acceptance").
It proposed an exact pin set; that set is now accepted and the §9 sequence is authorized.

**§1–§8 are preserved as the pre-acceptance evidence record and read in the past tense from here
on.** They state what was true at the gate — nothing installed, imported, executed, or added to CI —
and that remains the accurate history of how the pins were established. Substantive
pin/provenance/licence/security/compatibility content (§3–§8) is **unchanged** by this acceptance;
the mutation is confined to this header, the §9 gate framing, §10, and §11.

---

## 1. Purpose, scope, and non-actions

This refreeze covers **only** the static-analysis toolchain Sprint 8 Task 8.1 needs. It authorizes no
smart-contract source, changes no existing pin, adds no compiler, and reopens no accepted product
decision.

**Non-actions — verified, not merely asserted:**

- `slither` was **not installed** into the VUX project, into any environment on the machine, or into
  CI. No `slither` binary exists on `PATH` (`which slither` → not found).
- `slither` was **not executed against VUX** — not against `src/`, not against `vendor/`, not against
  build artifacts.
- No dependency manifest was created or mutated for it. There is no `requirements*.txt`, no
  `pyproject.toml`, no `setup.cfg`, no `Pipfile`, no `poetry.lock`, no `uv.lock`, and no Python
  virtual environment anywhere in the tree (§8.4 records the sweep).
- **No package artifact was downloaded.** Integrity evidence below is the registry-published sha256
  digest — precisely what `pip --require-hashes` verifies at install time and what a lockfile
  records. Fetching a wheel or sdist to hash it locally would sit on the wrong side of the gate's
  "or otherwise using" clause. This holds the identical line the accepted off-chain refreeze held
  (`vux-v1-offchain-provenance-refreeze-2026-08.md` §1), and one consequence is disclosed honestly
  as **D-S1** rather than papered over.
- No static analyzer was silently substituted. No alternative tool was installed or evaluated by
  execution.
- Only read-only metadata was fetched: PyPI JSON packuments over HTTPS, `git ls-remote` against each
  upstream repository, GitHub release metadata, the GitHub Advisory Database, the GHCR manifest API,
  and four individual upstream **source-repository** files quoted in §5.3/§7.2/§7.4 (the same class of
  read the accepted OZ/v3 refreeze performed when it enumerated the 32-file census).

The OZ, v3-core, Foundry-v1.5, and off-chain refreezes authorize nothing here, and nothing here was
inferred from them.

---

## 2. Verification method

| Step | Method |
|---|---|
| Exact version inside the accepted family | PyPI packument enumeration of **stable** releases only, cross-checked against the **full** upstream tag namespace (48 tags enumerated, not a filtered subset) |
| Immutable upstream identity | `git ls-remote refs/tags/<tag>` with `^{}` peel against the repository named in the package's own `Homepage`/`url` field |
| Cross-check of that identity | GitHub releases API (`draft`, `prerelease`, `published_at`) for the same tag |
| Integrity | PyPI-published `digests.sha256` for **both** the wheel and the sdist, at the exact version |
| Licence | Package `license` field at the exact version, plus the upstream repository licence file |
| Health | PyPI `yanked` flag at the exact version **and** across the whole 0.10.x line |
| Declared dependency surface | `requires_dist` at the exact version, corroborated against upstream `setup.py` **at the pinned commit** |
| Security qualification | GitHub Advisory Database (`ecosystem=pip`) queried per package; each hit resolved against the version the accepted constraint admits |
| Compatibility | Upstream release notes for the feature boundary; the actual VUX source checked for the features in question; the platform adapter read at the pinned commit |

Mutable references (`dist-tags.latest`, `>=`/`~=` ranges, branch names, `:latest` image tags) are
**not** authority anywhere in this document. Every version string below is exact.

---

## 3. The proposed pin

### 3.1 The gated tool

| # | Package | Family (authority) | **Exact pin** | Role | Published | Licence | Yanked |
|---|---|---|---|---|---|---|---|
| 1 | `slither-analyzer` | 0.10.x | **0.10.4** | CI static analysis, dev-only | 2024-08-23 | AGPL-3.0 | no |
| 2 | `crytic-compile` | (transitive of #1) | **0.3.7** | compilation-artifact adapter | 2024-04-07 | AGPL-3.0 | no |

`crytic-compile` is named explicitly rather than left to the resolver because §7.2's whole
compatibility argument depends on the behaviour of one file in it, and because §3.4 establishes
which member of the admitted range slither 0.10.4 was actually built against.

### 3.2 Immutable upstream identity

| Package @ version | Repository | Tag | Tag kind | Commit (40-char) |
|---|---|---|---|---|
| `slither-analyzer@0.10.4` | `crytic/slither` | `0.10.4` | lightweight | `aeeb2d368802844733671e35200b30b5f5bdcf5c` |
| `crytic-compile@0.3.7` | `crytic/crytic-compile` | `0.3.7` | lightweight | `20df04f37af723eaa7fa56dc2c80169776f3bc4d` |

Both tags are lightweight — the ref resolves directly to a commit object, so no `^{}` peel line is
produced and the ref value *is* the commit. GitHub release `0.10.4`: `draft: false`,
`prerelease: false`, `published_at: 2024-08-23T13:33:25Z`.

### 3.3 Integrity evidence

| Artifact | sha256 |
|---|---|
| `slither_analyzer-0.10.4-py3-none-any.whl` | `344745d885c8d883b78616622c3b443a56cab4022e09c475a3f570358cf24a14` |
| `slither_analyzer-0.10.4.tar.gz` | `bb89945509c7c1d461db2af1bfd85a7a02878334050e23aefc88d65568783a32` |
| `crytic_compile-0.3.7-py3-none-any.whl` | `bd8fc87f89afea5db714df13e302dcbaf50dd7c806fa424ace661384aa60634b` |
| `crytic-compile-0.3.7.tar.gz` | `c7713d924544934d063e68313da8d588a3ad82cd4f40eae30d99f2dd6e640d4b` |

Both wheels are `py3-none-any` — pure Python, no compiled extension, no platform variance, no build
step at install time.

### 3.4 Version selection inside the accepted family

The accepted family is `0.10.x`. The **complete** 0.10.x line is exactly five releases, and PyPI and
the upstream tag namespace agree on it with no member present in one and absent from the other:

| Version | Upstream tag commit | On PyPI | Yanked |
|---|---|---|---|
| 0.10.0 | `e3dcf1ecd3e9de60da046de471c5663ab637993a` | yes | no |
| 0.10.1 | `35230939bc763663de15f7c70ac9a8d0ac04a5a5` | yes | no |
| 0.10.2 | `fdf54f624d8c468afb3d8197eb9e98e377dac440` | yes | no |
| 0.10.3 | `798c1f6387ea0ce94ff792292095e4f9d0075bc9` | yes | no |
| **0.10.4** | `aeeb2d368802844733671e35200b30b5f5bdcf5c` | yes | no |

**0.10.4 is proposed because it is the last and most-patched member of the accepted family.** This is
the same conservatism the operator accepted for `next@15.1.12` inside the accepted 15.1.x family.
The 0.11.x line exists (through 0.11.6) and is **not** proposed: it is outside the accepted family
and would require its own operator decision. §7.1 records the one circumstance that would force that
conversation, and establishes by evidence that it does not arise here.

`crytic-compile` is pinned at **0.3.7** rather than at the top of slither's admitted
`>=0.3.7,<0.4.0` range because 0.3.7 is the *only* member of that range that existed when slither
0.10.4 was released — it is therefore the version 0.10.4 was developed and tested against:

| crytic-compile | Published | Relative to slither 0.10.4 (2024-08-23) |
|---|---|---|
| **0.3.7** | 2024-04-07 | **before — contemporaneous** |
| 0.3.8 | 2025-01-17 | after |
| 0.3.9 | 2025-04-15 | after |
| 0.3.10 | 2025-05-02 | after |
| 0.3.11 | 2025-11-14 | after (≈15 months) |

Letting the resolver take 0.3.11 would silently pair a 2024 analyzer with a 2025 adapter. §7.2
verifies the load-bearing behaviour in **both** 0.3.7 and 0.3.11, so either choice is defensible;
0.3.7 is proposed as the one the upstream project actually shipped against.

### 3.5 Name-confusion hazard — recorded, because default deny exists for exactly this

The PyPI name **`slither`** is a **different, unrelated package**: `slither` 0.3.0, MIT, "A Python
module that uses PyGame to bring Scratch-like features to Python", `PySlither/Slither`. It has five
releases and no relationship to Trail of Bits or to static analysis.

The static analyzer is **`slither-analyzer`**. The CLI it installs is named `slither`, which is
precisely what makes the confusion plausible. Any instruction, runbook line, or CI step that says
`pip install slither` installs unrelated third-party code into the VUX toolchain. The §8 CI design
therefore installs by hash-pinned requirement, never by bare name, and the §9 gate asserts the
distribution name.

---

## 4. Licence determination

### 4.1 The licences

| Package | Licence at the exact version |
|---|---|
| `slither-analyzer@0.10.4` | AGPL-3.0 |
| `crytic-compile@0.3.7` | AGPL-3.0 |
| `packaging` | Apache-2.0 OR BSD-2-Clause |
| `prettytable` | BSD-3-Clause |
| `pycryptodome` | BSD-2-Clause + Public Domain (dual) |
| `web3` | MIT |
| `eth-abi` | MIT |
| `eth-typing` | MIT (classifier) |
| `eth-utils` | MIT (classifier) |
| `solc-select` (via crytic-compile) | AGPL-3.0 |

### 4.2 Why no obligation propagates to VUX

The project licence is `GPL-3.0-or-later` and **does not change**. AGPL-3.0 imposes no obligation on
VUX here, for four independent reasons — any one of which suffices:

1. **No conveyance.** VUX does not distribute slither. It is a developer/CI tool fetched from PyPI by
   whoever runs the gate, exactly as `forge` and `solc` are.
2. **No modification.** Nothing in slither is patched, forked, or vendored. AGPL §13's network clause
   triggers on *modified* versions made available to remote users over a network; there is no
   modified version and no network service.
3. **No linking or incorporation.** No VUX source imports slither, no slither code enters
   `src/`, `vendor/`, `test/`, `script/`, `indexer/`, or `web/`, and no shipped artifact contains any
   of it. Slither reads VUX build output; VUX does not read slither.
4. **Analyzer output is not a derivative of the analyzer.** The triaged findings baseline this sprint
   produces is a description of VUX code, authored under the project licence.

This is the same class as the accepted treatment of the Foundry toolchain: *"toolchain is not
imported source"* (`vux-v1-oz-v3-provenance-refreeze-2026-08.md` §6). Slither belongs to that class,
not to the vendored-source class of §3/§4 nor to the installed-runtime class of the off-chain
refreeze — the shipped artifact is byte-identical whether or not slither ever runs.

**Recorded for completeness, not relied upon:** even in a hypothetical where conveyance did occur,
GPL-3.0-or-later and AGPL-3.0 are compatible in the direction that matters (GPLv3 §13 expressly
permits combination with AGPLv3 work). No compatibility defect exists on any reading.

**`THIRD_PARTY_NOTICES.md` impact:** none required by conveyance. Task 8.5 will record the
static-analysis toolchain in the notices file as a **toolchain** entry alongside the existing
Foundry/solc treatment, not as a vendored-source or distributed-dependency entry.

---

## 5. The dependency surface entering the VUX toolchain

### 5.1 Direct runtime dependencies of `slither-analyzer@0.10.4`

Taken from `requires_dist` at the exact version and corroborated verbatim against upstream `setup.py`
at commit `aeeb2d36…` (the two agree):

| # | Requirement | Declared constraint |
|---|---|---|
| 1 | `packaging` | (unbounded) |
| 2 | `prettytable` | `>=3.10.2` |
| 3 | `pycryptodome` | `>=3.4.6` |
| 4 | `crytic-compile` | `>=0.3.7,<0.4.0` |
| 5 | `web3` | `>=6.20.2,<7` |
| 6 | `eth-abi` | `>=4.0.0` |
| 7 | `eth-typing` | `>=3.0.0` |
| 8 | `eth-utils` | `>=2.1.0` |

The `dev` / `doc` / `lint` / `test` extras (`openai`, `pdoc`, `black`, `pylint`, `pytest*`,
`deepdiff`, `numpy`, `coverage`, `filelock`, `pytest-insta`) are **not** installed — extras are opt-in
and none is requested. `crytic-compile@0.3.7` adds three of its own: `pycryptodome>=3.4.6`, `cbor2`,
`solc-select>=v1.0.4`.

### 5.2 D-S1 — the transitive closure is real and is a disclosed obligation

`web3<7` is the expensive edge. `web3@6.20.4` (the highest 6.x, the version the constraint resolves
to) itself declares sixteen runtime requirements — `aiohttp`, `ckzg<2`, `eth-abi`, `eth-account`,
`eth-hash[pycryptodome]`, `eth-typing`, `eth-utils`, `hexbytes`, `jsonschema`, `lru-dict`,
`protobuf`, `pywin32` (Windows only), `requests`, `typing-extensions`, `websockets<14`,
`pyunormalize` — each of which recurses. The realistic closure is on the order of 40–60
distributions.

**This document does not enumerate that closure**, for the reason stated in §1: enumerating it
faithfully means running a resolver, and pinning it with verifiable hashes means fetching
distribution metadata for every member — work that belongs on the far side of the gate. Inventing a
closure by hand would produce a list that pip might not reproduce, which is worse than an honest
deferral.

**Proposed discharge (§9, action 2):** immediately on acceptance, materialize a **fully-pinned,
hash-required** `tools/static-analysis/requirements.txt` as a durable Sprint-8 candidate artifact —
every distribution in the closure pinned `==` with its `--hash=sha256:…` — and install and use
slither **only** from that exact reviewed file, by the §8.1 invariant:

```bash
python3 -m pip install --require-hashes --no-deps -r tools/static-analysis/requirements.txt
```

`--no-deps` is not optional and is not shorthand: the installed environment must be exactly the
fully enumerated, pinned, hashed file, with pip forbidden from resolving anything additional. That is
the exact Python analogue of the accepted `npm ci --ignore-scripts` + committed-lockfile posture, and
it fails closed on any digest mismatch. A transitive **licence** census over that file discharges the
same obligation the accepted off-chain refreeze carries as D-3.

**Lifecycle boundary (binding):** the requirements file is intended for inclusion in the later
reviewed/accepted Sprint-8 landing candidate. `/implement sprint-8` **does not create a Git commit**.
Nothing in this document authorizes one.

**Bounded by construction:** the §3.1/§3.3 digests are the anchors. If the generated closure
contains anything that is not a transitive consequence of those two pins, that is a defect, not an
authorization — and it stops with a new bounded HITL rather than being added.

### 5.3 `solc-select` enters the toolchain but is never exercised

`crytic-compile` hard-depends on `solc-select>=v1.0.4`, so it **is** installed. It is nevertheless
never used on the proposed invocation: §7.2 establishes that `--ignore-compile` makes crytic-compile
skip compilation entirely and parse existing build artifacts, so no compiler is selected, downloaded,
or run by the static-analysis path. Recorded because "installed but unexercised" is a provenance fact
the operator is entitled to see, not because it creates an active obligation. It carries no advisory
(§6.1) and downloads nothing unless invoked.

### 5.4 No wrapper tooling — nothing else enters CI

Three wrapper options were considered and **none is proposed**:

| Option | Disposition |
|---|---|
| `crytic/slither-action` GitHub Action | **Rejected.** It is a fourth-party wrapper that pip-installs slither internally — it *adds* a provenance obligation (the action's own pin, its own transitive surface) while *hiding* the one underneath it. |
| `actions/setup-python` | **Rejected.** The repository's accepted posture for interpreters is explicit at `.github/workflows/provenance.yml`: *"Asserted rather than assumed: a runner image rollback must not silently change what these gates mean. No setup-node action is added for this."* The Python step mirrors it exactly — use the runner's `python3`, assert its floor (§7.3). |
| Official OCI image `ghcr.io/crytic/slither` | **Rejected**, though verified to exist: index digest `sha256:c2a1f1f237891730cdc90ce1c6bb3bf9b507639ccfae46f2e6b9826892c2e923`, amd64 manifest `sha256:00ec7d03b798e46091ea51e43be9b390798624539d74d41195986277c4f6bdb5`. One immutable content-addressed pin is attractive, but the closure inside it is **opaque** — it cannot be enumerated or licence-censused without pulling it — it bundles solc binaries VUX does not want, it lacks the accepted Foundry, and it would introduce Docker to a repository that uses none. Recorded as the fallback if §9 action 2 proves impractical; it would need its own operator decision. |

**Net new CI surface under the proposal: zero new GitHub Actions, zero new container runtimes, zero
new compilers.** In the eventual landed repository, one `run:` step installs from the hash-pinned
requirements file using the runner's existing Python.

---

## 6. Security qualification

Every package named in §3.1 and §5.1 was queried against the GitHub Advisory Database
(`ecosystem=pip`), and each hit was resolved against the version the accepted constraint actually
admits.

### 6.1 Clean

| Package | Advisories |
|---|---|
| `slither-analyzer` | **none** |
| `crytic-compile` | **none** |
| `solc-select` | **none** |
| `eth-utils` | **none** |
| `eth-typing` | **none** |
| `prettytable` | **none** |
| `packaging` | **none** |

### 6.2 Present, resolved above the fix

| Package | Advisory | Severity | Vulnerable | Patched | Disposition |
|---|---|---|---|---|---|
| `eth-abi` | GHSA-rqr8-pxh7-cq3g | medium | `<4.2.0` | 4.2.0 | slither declares `eth-abi>=4.0.0` **unbounded above**, and `web3@6.20.4` likewise declares `eth-abi>=4.0.0` with no cap — the resolver takes the current 5.x. **Fixed.** |
| `eth-abi` | GHSA-3qwc-47jf-5rf7 | medium | `<=5.0.0` | 5.0.1 | Same reasoning; requires the pinned closure to land **above 5.0.0**. **Named as a binding constraint on §9 action 2.** |
| `pycryptodome` | GHSA-j225-cvw7-qrx7 | high | `<3.19.1` | 3.19.1 | Declared `>=3.4.6` unbounded; resolver takes current 3.2x. **Fixed.** Binding constraint on §9 action 2: closure must land ≥3.19.1. |
| `pycryptodome` | GHSA-hgg3-g7gr-66r7 | high | `<3.6.6` | 3.6.6 | Subsumed by the above. **Fixed.** |

### 6.3 D-S2 — `web3` CCIP-Read SSRF is unavoidable inside the accepted family

| Advisory | GHSA-5hr4-253g-cpx2 |
|---|---|
| Severity | **medium** |
| Summary | web3.py: SSRF via CCIP Read (EIP-3668) `OffchainLookup` URL handling |
| Vulnerable | `>=6.0.0b3, <7.15.0` |
| First patched | **7.15.0** |
| What slither 0.10.4 admits | `web3>=6.20.2,**<7**` |

**There is no member of `web3` 6.x that fixes this.** The fix landed in 7.15.0, and slither 0.10.4
excludes all of 7.x. No version choice inside the accepted `slither` 0.10.x family avoids it. This is
stated plainly rather than resolved, because it cannot be resolved by pin selection.

**Reachability on the VUX invocation — structural, and evidenced rather than argued:**

1. The vulnerability requires an outbound `eth_call` to a configured RPC provider, a contract that
   reverts with `OffchainLookup`, and a subsequent HTTP fetch to the gateway URL that revert names.
2. The proposed invocation (§8) targets a **local directory** with `--ignore-compile`. It reads
   `out/build-info/*.json` from disk. It constructs no `Web3` provider and makes no RPC call.
3. `slither/__main__.py` — the module behind the `slither` console script — **does not import
   `web3`** at the pinned commit. Its imports are the standard library, `crytic_compile`, and
   `slither` internals.
4. `web3` is imported at `slither/tools/read_storage/read_storage.py`, which backs the **separate**
   `slither-read-storage` console script. That script is not invoked, and the CI step runs `slither`.
5. The etherscan/address-target code path in `crytic_compile` is likewise unreachable: it activates
   only when the target is a `0x…` address, and the target is `.`.

**Proposed mechanical control rather than a promise** (§9, action 4): the CI step asserts that no
RPC endpoint is configured in the job environment, so a future edit that quietly adds one fails the
gate instead of silently widening reachability.

**Residual, stated honestly:** the package is present in the environment. The finding is
*unreachable on the invocation VUX runs*, not *absent*. It is proposed as an accepted, bounded,
documented residual, and it is the single strongest argument in favour of the operator preferring
slither 0.11.x — which is why §7.1 and this section are placed adjacent for the decision.

---

## 7. Compatibility with the accepted repository and toolchain

### 7.1 D-S3 — slither 0.10.4 predates two solc language features; **neither appears in VUX source**

Slither **0.11.0** (2025-02-03) release notes state it *"adds support for the latest Solidity features
like using a custom error in a require statement and transient storage"*. Slither 0.10.4 (2024-08-23)
therefore predates support for:

- `require(cond, CustomError())` — solc 0.8.26/0.8.27
- the `transient` data location — solc 0.8.28

The VUX-original compilation unit is pinned at exact pragma **`=0.8.28`** (all twelve `src/**` files;
`src/v3core/VuxPoolDeployer.sol` is `=0.7.6` and belongs to the other unit). Both features are
therefore *expressible* in this unit — so the question is not theoretical and was checked against the
actual tree rather than assumed:

| Feature | Sweep over `src/`, `test/`, `script/` | Result |
|---|---|---|
| `transient` data location | `grep -rn '\btransient\b'` | **4 comment/prose occurrences and 1 test-message string; zero uses as a data location.** |
| `require(…, CustomError())` | `grep -rnE 'require\([^;]*,\s*[A-Z][A-Za-z0-9_]*\s*\('` | **zero matches.** |

VUX declares 70 custom errors and raises them with `revert CustomError()` — the pre-0.8.26 form,
fully supported by slither 0.10.4. The two unsupported constructs are absent from the source slither
would parse.

**Bounding the risk honestly.** 0.10.4 is the *last* member of the accepted family: if it turns out
it cannot parse the `=0.8.28` build-info for a reason not anticipated here, there is **no fallback
inside 0.10.x**, and the fallback is a new operator gate for 0.11.x. That contingency is named now
rather than discovered mid-sprint. The evidence above makes it unlikely; it does not make it
impossible, because the only complete proof is execution, which is on the far side of this gate.

### 7.2 No compiler is invoked — slither analyzes the **accepted build's** AST

This is the load-bearing design property, and it was verified at the pinned commit of the adapter
rather than assumed.

`crytic_compile/platform/foundry.py` at crytic-compile `0.3.7` (`20df04f3…`) — and identically at
`0.3.11` (`46ab5fda…`) — branches on `ignore_compile`. When set, it **skips the `forge build`
subprocess entirely** and calls `hardhat_like_parsing()` over `<project>/<out>/build-info`. In 0.3.7
the out-directory default is literally `"out"`, which is the VUX default profile's `out` verbatim.

Consequences, each of which is a provenance property and not a convenience:

1. **Slither adds no compiler to the toolchain.** It never invokes `forge`, never invokes `solc`,
   never asks `solc-select` to download anything.
2. **The analyzed AST is the accepted build's AST** — produced by the accepted Foundry
   `v1.5.0 @ 1c57854462289b2e71ee7654cd6666217ed86ffd` and pinned `solc 0.8.28`. Static analysis and
   compilation cannot silently diverge, because there is only one compilation.
3. The `POOL_INIT_CODE_HASH` reproduction, the census gates, and the compiler-identity assertions are
   untouched: slither is a *reader* of `out/`, downstream of every existing gate.

**Verified now, with the accepted toolchain only and no slither involved:**
`forge build --build-info --skip "test/**" --skip "script/**"` emits
`out/build-info/3c26e421b798f41c.json` (4,963,733 bytes) carrying `solcVersion: 0.8.28`, its
`solcLongVersion`, the full standard-json `input` (`viaIR: true`, optimizer enabled), and
`output.sources` with an `ast` on each of 48 sources — 12 VUX-original `src/**`, 28 vendored OZ
v5.2.0, 8 vendored v3-core interfaces. That is exactly the structure `hardhat_like_parsing` consumes.

### 7.3 Python floor — asserted, not provisioned

| Constraint source | Requirement |
|---|---|
| `slither-analyzer@0.10.4` | `>=3.8` |
| `crytic-compile@0.3.7` | `>=3.8, !=3.12.0` |
| Proposed CI assertion | **`>=3.10` and not exactly `3.12.0`** |

`>=3.10` is proposed rather than the bare `>=3.8` floor because it is slither's own current stated
minimum and comfortably satisfies every member of the closure; the `!=3.12.0` exclusion is
crytic-compile's, carried verbatim. `ubuntu-latest` currently provides Python 3.12.x, which
satisfies both. Per §5.4 no `setup-python` action is added — the step asserts the floor and fails
closed if a runner-image change violates it, exactly as the Node step does.

### 7.4 The `=0.7.6` vendored unit is out of analysis scope — by provenance rule, not convenience

`vendor/uniswap-v3-core-v1.0.0/**` is byte-identical upstream source under an immutable census; the
drift gate fails closed on a one-byte change. VUX **cannot act on a finding in it** without breaking
the census. Analyzing it would generate findings whose only honest disposition is "cannot fix,
upstream, out of authority" — noise that dilutes the baseline this sprint exists to make meaningful.

Scope is therefore the **VUX-original production surface**: `src/**` excluding `src/v3core/`. Vendored
OZ and v3-core interface files appear in the build-info because `src/` imports them and slither must
resolve them to build a correct call graph; they are excluded from *reporting* via `--filter-paths`,
not from *parsing*. `test/**` and `script/**` are excluded from the build-info entirely (`--skip`) —
they are not the shipped artifact.

---

## 8. Proposed installation method and CI invocation

### 8.1 Installation

```bash
python3 -m pip install --require-hashes --no-deps -r tools/static-analysis/requirements.txt
```

This exact invocation is the load-bearing installation invariant; it is quoted in full wherever this
document describes installing slither, and it is never abbreviated. `--require-hashes` makes pip
verify every artifact against the digest recorded in the file and **fail closed** on any mismatch or
on any requirement lacking a hash. `--no-deps` forbids pip from resolving anything beyond that file,
so the installed set is exactly the reviewed set — this flag is required, not a convenience, and must
not be weakened or generalized. Together these are the Python equivalent of `npm ci --ignore-scripts`
against a committed lockfile.

### 8.2 Invocation

```bash
forge build --build-info --skip "test/**" --skip "script/**"
slither . --ignore-compile --filter-paths "vendor/" --json out/slither-report.json
```

Step 1 uses only the accepted Foundry/solc. Step 2 reads its output. No network, no compiler, no
address target.

### 8.3 Where the gate lands

The table describes the **eventual landed repository**. Each row is materialized during
`/implement sprint-8` as a durable Sprint-8 candidate artifact and carried into the later
reviewed/accepted landing candidate; the implementation node itself creates no Git commit.

| Surface | Change |
|---|---|
| `tools/static-analysis/requirements.txt` | new — fully pinned, hash-required (§9 action 2) |
| `tools/static-analysis/slither.config.json` | new — detector selection and filter paths |
| `tools/provenance/verify-static-analysis.sh` | new gate — asserts the pin, the distribution name (§3.5), the Python floor, the no-RPC-env control (§6.3), and the triaged baseline |
| `tools/provenance/run-all.sh` | one `run_gate` line appended |
| `tools/provenance/census.sh` | this document + its JSON companion registered as SHA-256-pinned authority, per the existing `TOOLCHAIN_MD`/`TOOLCHAIN_JSON` pattern |
| `.github/workflows/provenance.yml` | one job: assert Python floor → install → `forge build --build-info` → slither → baseline diff |
| `THIRD_PARTY_NOTICES.md` | toolchain entry (Task 8.5), not a conveyance entry (§4.2) |

`forge lint` — named alongside slither in the Sprint 8 deliverables — is part of the already-accepted
Foundry v1.5.0 and introduces **no** new provenance surface.

### 8.4 Install-state evidence at the time of writing

| Check | State |
|---|---|
| `which slither` | not found |
| `requirements*.txt` / `pyproject.toml` / `setup.cfg` / `Pipfile` / `poetry.lock` / `uv.lock` | absent from the tree |
| Python virtual environment in the tree | absent |
| `tools/static-analysis/` | does not exist |
| slither in any CI workflow | absent (`provenance.yml`, `post-merge.yml`) |
| slither baseline artifact | absent |

---

## 9. Exclusions, and the authorized sequence

**This refreeze is accepted (§10).** It authorizes **exactly** `slither-analyzer==0.10.4` and
`crytic-compile==0.3.7` plus the transitive closure those two pins *necessarily* imply, installed by
the §8.1 method, and nothing more. Explicitly **not** authorized:

- any other version of either package, **including a later patch** — a newer revision requires its
  own refreeze under the standing full-SHA-only pin policy;
- **slither 0.11.x** — outside the accepted family; a separate operator decision (§6.3, §7.1);
- the PyPI package **`slither`** (§3.5) — unrelated third-party code;
- `crytic/slither-action`, `actions/setup-python`, or any other GitHub Action (§5.4);
- the `ghcr.io/crytic/slither` container image (§5.4) — verified to exist, recorded as a fallback,
  not authorized;
- any other static analyzer (Mythril, Securify, Semgrep, Aderyn, Wake, Echidna, Medusa, Manticore);
- any slither **plugin** or detector package;
- slither's `dev`/`doc`/`lint`/`test` extras (§5.1);
- any dependency that is *not* a transitive consequence of the two pins — such a discovery **stops
  with a new bounded HITL** rather than being added (§5.2);
- any smart-contract source. OZ / v3-core / Miner allowlists unchanged, `POOL_INIT_CODE_HASH`
  untouched, Foundry and off-chain refreezes unaffected.

Preserved unchanged: default deny, full-SHA-only pin policy, the Miner Manifold three-file allowlist,
`Heesho/liquid-signal-governance` `DEFERRED_NOT_V1`, and every operator-reserved value (Q-3, Q-4,
Q-6, R-1…R-14).

**The authorized actions, in order:**

1. Create `tools/static-analysis/`.
2. Materialize the fully-pinned, hash-required `requirements.txt` from exactly the two accepted pins,
   as a **durable Sprint-8 candidate artifact** (**D-S1**, §5.2). Binding constraints on the resolved
   closure: `eth-abi` **>5.0.0**, `pycryptodome` **≥3.19.1** (§6.2). Verify the recorded
   `slither-analyzer` and `crytic-compile` digests equal §3.3 byte-for-byte. Produce the transitive
   **licence** census.
3. Install and use slither **only** from that exact reviewed file, by the §8.1 invariant quoted in
   full (`--require-hashes --no-deps`, never abbreviated), then run §8.2 against the actual VUX
   implementation.
4. Add the gate and the CI job (§8.3), including the no-RPC-env control (**D-S2**, §6.3) and the
   distribution-name assertion (§3.5).
5. Triage every finding against real reachability and authority consequence; establish the durable
   triaged baseline. Fix real defects within accepted Sprint-8 scope with proportional verification;
   do **not** mutate accepted protocol architecture to appease a scanner.
6. Record the toolchain entry in `THIRD_PARTY_NOTICES.md` (Task 8.5).

**Lifecycle boundary on this whole sequence (binding).** Every artifact above is produced as a
durable Sprint-8 candidate artifact, intended for inclusion in the later reviewed/accepted Sprint-8
landing candidate. **`/implement sprint-8` creates no Git commit**, and no action authorized here may
be read as authorizing one. Committing, pushing, merging, and landing are later operator-gated
lifecycle nodes; this refreeze governs provenance only and confers no Git authority.

If the closure cannot be pinned as in action 2, or if §7.1's contingency materialises, **stop with a
new bounded HITL** rather than improvising.

---

## 10. Acceptance

Operator acceptance was recorded on **2026-08-19**, authorizing exactly `slither-analyzer==0.10.4`
and `crytic-compile==0.3.7` at the identities and digests of §3.2/§3.3, plus the transitive closure
those two pins necessarily imply — and no more. It does not authorize arbitrary dependency
expansion, and it grants **no wildcard family authorization**: a later patch of either package
requires its own refreeze under the standing full-SHA-only pin policy.

This acceptance activates the §3 pins, makes §8 the accepted installation and invocation method,
discharges the pre-use gate of Sprint 8 Task 8.1, and authorizes the §9 sequence.

**Pre-acceptance candidate digests, independently re-verified immediately before this mutation:**

| Artifact | sha256 at HITL presentation | Re-verified |
|---|---|---|
| `vux-v1-static-analysis-provenance-refreeze-2026-08.md` | `82033b9379cc67df4fe27330f2d09afb9472739dd32c7b8f839d251835dcf91d` | **match** |
| `vux-v1-source-registry-static-analysis-refreeze-2026-08.json` | `ac6afaa9614038a2ba996811c0cff3d09dfa94caff46148ab4385e176148f789` | **match** |

Both matched. The accepted pin table was compared entry-by-entry against §3.1/§3.2/§3.3: 2/2 exact
match on distribution, version, repository, commit, and all four artifact digests; no broadening.

**Disclosure states at acceptance:**

| ID | Disclosure | State at acceptance |
|---|---|---|
| **D-S1** | Transitive closure not enumerated pre-acceptance | **ACCEPTED as disclosed; discharge authorized** — derive the closure from the accepted pins, materialize the fully-pinned hash-required file per §9 action 2, preserve the §6.2 binding constraints, produce the transitive licence census. Any package that is **not** a transitive consequence of the accepted pins → **STOP with a bounded HITL**. |
| **D-S2** | `web3` CCIP-Read SSRF (GHSA-5hr4-253g-cpx2), unavoidable inside slither 0.10.x | **ACCEPTED as a documented residual, on the §6.3 characterization verbatim: the vulnerable package is PRESENT in the static-analysis environment and the vulnerable path is structurally unreachable on the authorized invocation.** The acceptance is conditioned on the bounded invocation — local project target, `--ignore-compile`, local Foundry build-info, no address target, no `slither-read-storage`, no configured RPC path. The mechanical no-RPC-environment control is **required**, not optional. This residual MUST NOT be restated as "fixed", "absent", or "non-vulnerable". **If any later change widens static-analysis execution into an RPC/provider path, this disposition lapses and operator review is required.** |
| **D-S3** | slither 0.10.4 predates two solc 0.8.26–0.8.28 language features; both verified absent from VUX source | **ACCEPTED as a bounded risk; execution authorized.** If slither 0.10.4 cannot consume the accepted build-info or parse the implementation for an unanticipated compatibility reason → **STOP**. Silent upgrade to 0.11.x is **prohibited**; any 0.11.x use requires a new provenance/operator gate. |
| **D-S4** | PyPI `slither` ≠ `slither-analyzer` | **CONTROL ACCEPTED AND BINDING.** The authorized distribution is `slither-analyzer`. `pip install slither` MUST NEVER be executed. The distribution-name assertion and hash-pinned installation are retained. |

**Standing prohibitions preserved by this acceptance:** no other analyzer, no slither plugins, no
upgrade of either pin, no dependency outside the derived closure, no architecture change made merely
to satisfy a scanner, and — per §9's lifecycle boundary — **no Git commit during
`/implement sprint-8`**.

---

## 11. Authority disposition

This refreeze **completes** the last open clause of the deferred obligation recorded at
`vux-v1-oz-v3-provenance-refreeze-2026-08.md` §9 — *"slither 0.10.x and any additional
CI/static-analysis toolchain"* — which the accepted off-chain refreeze explicitly left open and
routed here (`vux-v1-offchain-provenance-refreeze-2026-08.md` §10: *"remains open and deferred to
Sprint 8, Task 8.1"*). **With this acceptance, refreeze §9 carries no remaining deferred
obligation** — the off-chain and static-analysis clauses are both discharged.

No predecessor authority file is rewritten, no historical attribution is removed, and no precedence
above the licence/pin layer changes: FREEZE/SPEC supersessions, the accepted PRD, and the accepted
SDD govern product and architecture; this refreeze governs only static-analysis toolchain provenance
and licence state for the enumerated packages. Consistent with the strategic-treasury-delta, OZ/v3,
Foundry-v1.5, and off-chain precedents, the refreeze self-describes its authority disposition here
rather than via a separate authority-map delta.

No predecessor authority file is edited by this acceptance. Per the strategic-treasury-delta, OZ/v3,
Foundry-v1.5, and off-chain precedents, discharge is self-described here; the predecessor's §9 text is
preserved verbatim and reads as history.

**ACCEPTED 2026-08-19. The §9 sequence is authorized. `/implement sprint-8` resumes — without a Git
commit.**
