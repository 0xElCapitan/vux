# VUX v1 Off-Chain Provenance Refreeze (ponder / Next.js / React / React DOM / viem / wagmi / @tanstack/react-query / hono / Playwright / PostgreSQL)

**Status:** `OFFCHAIN_PROVENANCE_REFREEZE_CURRENT_ACCEPTED`
**Operator acceptance:** 2026-08-14 — the exact set in §3.1/§3.2 plus the disclosed exact transitive
`@tanstack/query-core@5.71.1`. Acceptance applies **only** to the exact identities, licences,
integrity evidence, source/release pins, package-root assignments, and dependency roles recorded
here. **No wildcard family authorization is granted. No unrelated dependency expansion is authorized.**
**Date:** 2026-08-14 (pass 2 — HITL reconciliation; pass 3 — acceptance activation)
**Produced by:** `/implement sprint-6`, Task 6.1 (intra-sprint operator gate)
**Discharges:** the deferred obligation recorded at
`docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md` §9 — "exact immutable pins recorded in
an operator-accepted refreeze **before their first import/use**".

**Pass-2 operator disposition consumed:**

| Item | Disposition | Effect in this document |
|---|---|---|
| **D-1** | **RESOLVED** — select `next = 15.1.12`; do not use `15.1.4`; preserve `react`/`react-dom` `= 19.0.0` unless primary-source evidence forbids it; explicitly verify the `react-server-dom-*` surface | §3 pin recorded; §5 is the required security evidence; React pins **preserved** (§5.4) |
| **D-2** | Candidate expansion **AUTHORIZED**; final pins **not yet accepted** — verify independently | §3/§4 record both peers with full evidence; **both PASS** (§4.3) |
| **D-3 / D-4** | Provenance **disclosures**, not blockers | §6.1 / §6.2 |

---

## 1. Purpose, scope, and non-actions

This refreeze covers **only** the off-chain surface Sprint 6 needs: the indexer, the read-only
frontend, the chain client, the copy-assertion test runner, and the derived database. It authorizes
no smart-contract source, changes no existing pin, and reopens no accepted product decision.

**Non-actions — verified, not merely asserted:**

- Nothing was installed. There is no `package.json`, no `package-lock.json`, no `node_modules`, no
  `.npmrc`, and no lockfile of any kind anywhere in the tree at the time of writing.
- No gated package was imported, executed, scaffolded from, or generated from. No package manifest
  or lockfile was created.
- **No package tarball was downloaded.** Integrity evidence is the registry-published Subresource
  Integrity digest (§3.3), which is precisely what a package manager verifies at install time and
  what a lockfile records. Fetching a tarball to hash it locally would sit on the wrong side of the
  gate's "or otherwise using" clause. One consequence of holding that line is recorded honestly in
  §5.3 rather than papered over.
- Only read-only metadata was fetched: registry packuments over HTTPS, `git ls-remote` against each
  upstream repository, and two vendor security advisories (§5).
- Scope was not expanded. The two additions in §3.2 are **required peer dependencies of already-named
  packages**, authorized by the operator's D-2 disposition; no unrelated dependency was introduced.

The OpenZeppelin and Uniswap v3-core refreezes authorize nothing here, and nothing here was inferred
from them.

---

## 2. Verification method

| Step | Method |
|---|---|
| Exact version inside each accepted family | Registry packument enumeration of **stable** releases only (pre-release identifiers excluded) |
| Immutable upstream identity | `git ls-remote refs/tags/<tag>` with `^{}` peel, against the repository named in the package's own `repository` field. **Full tag namespace enumerated** — see §6.3 |
| Cross-check of that identity | Registry `gitHead` for the exact version, compared against the peeled tag |
| Integrity | Registry-published `dist.integrity` (sha512, SRI) + `dist.shasum` (sha1, legacy) |
| Licence | Package `license` field at the exact version, plus the upstream repository licence |
| Health | Registry `deprecated` field at the exact version **and across the whole release line** |
| Security qualification | Vendor advisories read as primary sources; declared dependency graphs diffed version-to-version (§5) |
| Compatibility | Each parent's declared `peerDependencies` range checked against the proposed child pin (§4.3) |

Mutable references (`dist-tags.latest`, `^`/`~` ranges, branch names) are **not** authority anywhere
in this document. Every version string below is exact.

---

## 3. The final pin set

### 3.1 Named gate set (refreeze §9)

| # | Package | Family (authority) | **Exact pin** | Root | Role | Published | Licence | Deprecated |
|---|---|---|---|---|---|---|---|---|
| 1 | `ponder` | 0.8.x | **0.8.33** | `indexer/` | direct | 2025-01-27 | MIT | no |
| 2 | `next` | 15.1.x | **15.1.12** | `web/` | direct | 2026-01-26 | MIT | no |
| 3 | `react` | 19.0.0 | **19.0.0** | `web/` | direct (peer of `next`) | 2024-12-05 | MIT | no |
| 4 | `react-dom` | 19.0.0 | **19.0.0** | `web/` | direct (peer of `next`) | 2024-12-05 | MIT | no |
| 5 | `viem` | 2.21.x | **2.21.60** | `indexer/` + `web/` | direct (peer of `ponder`, `wagmi`) | 2024-12-30 | MIT | no |
| 6 | `wagmi` | 2.14.x | **2.14.16** | `web/` | direct | 2025-03-31 | MIT | no |
| 7 | `@playwright/test` | 1.49.x | **1.49.1** | `web/` | direct, dev/test only | 2024-12-10 | Apache-2.0 | no |
| 8 | PostgreSQL | 16.4 | **16.4** | — (service) | deployment fact | — | PostgreSQL Licence | n/a |

### 3.2 Required peers admitted under D-2

Neither is optional; the parent is non-functional without it. Both are peers of already-named
packages, not new capability.

| # | Package | Constraint | **Exact pin** | Root | Role | Published | Licence | Deprecated |
|---|---|---|---|---|---|---|---|---|
| 9 | `@tanstack/react-query` | `wagmi` peer `>=5.0.0` | **5.71.1** | `web/` | required peer | 2025-03-31 | MIT | no |
| 10 | `hono` | `ponder` peer `>=4.5` | **4.6.19** | `indexer/` | required peer | 2025-01-26 | MIT | no |

**Deterministic transitive disclosed:** `@tanstack/react-query@5.71.1` declares
`"@tanstack/query-core": "5.71.1"` — an **exact** pin, not a range, so it introduces no resolution
freedom. Recorded for completeness: MIT, published 2025-03-31, not deprecated, zero dependencies,
zero peer dependencies, integrity
`sha512-4+ZswCHOfJX+ikhXNoocamTUmJcHtB+Ljjz/oJkC7/eKB5IrzEwR4vEwZUENiPi+wISucJHR5TUbuuJ26w3kdQ==`.

### 3.3 Immutable upstream identities and integrity

| Package @ version | Repository | Tag | Tag kind | Commit (40-char) | `gitHead` cross-check |
|---|---|---|---|---|---|
| `ponder@0.8.33` | ponder-sh/ponder | `ponder@0.8.33` | annotated | `134e576494a59feea9b311e6270d8c403dae99f7` | packument has no `gitHead` |
| `next@15.1.12` | vercel/next.js | `v15.1.12` | annotated | `b3aab81a4d8274e669139b74f1c3aa3956865abd` | **matches** |
| `react@19.0.0` | facebook/react | `v19.0.0` | lightweight | `7aa5dda3b3e4c2baa905a59b922ae7ec14734b24` | divergent — §6.2 |
| `react-dom@19.0.0` | facebook/react | `v19.0.0` | lightweight | `7aa5dda3b3e4c2baa905a59b922ae7ec14734b24` | divergent — §6.2 |
| `viem@2.21.60` | wevm/viem | `viem@2.21.60` | annotated | `f90e2b8b4aaef2307c22b8f7dd95152ba7eab5bb` | packument has no `gitHead` |
| `wagmi@2.14.16` | wevm/wagmi | `wagmi@2.14.16` | annotated | `12682359f1274d61d4553bc5dab4f09ba49531a5` | packument has no `gitHead` |
| `@playwright/test@1.49.1` | microsoft/playwright | `v1.49.1` | lightweight | `88bc8afc78ea6ff13d2bbb312b99eb924962766c` | **matches** |
| `@tanstack/react-query@5.71.1` | TanStack/query | `v5.71.1` | annotated | `6c105d6ddfc797ab5fe106d6020978f711e3af43` | packument has no `gitHead` |
| `hono@4.6.19` | honojs/hono | `v4.6.19` | annotated | `d40fffbec624bae50f8fc3b619125dda9a8c50e2` | packument has no `gitHead` |

Every commit above is the **peeled** (`^{}`) object for annotated tags, never the tag object.
`react`'s and `playwright`'s `v*` tags are lightweight and point directly at the commit.

| Package @ version | sha512 (SRI — recorded by the lockfile, enforced by the installer) |
|---|---|
| `ponder@0.8.33` | `sha512-YyugehvRl0SxhEOQ/v3UZgNIvNIdXoxAlyKXBficmf0jN9Zz/fUJ4tKPdEyFwOB5ZfcMUWlxr6ldjb4N4Jk62A==` |
| `next@15.1.12` | `sha512-fClyhVCGTATGYBnETgKAi7YU5+bSwzM5rqNsY3Dg5wBoBMwE0NSvWA3fzwYj0ijl+LMeiV8P2QAnUFpeqDfTgw==` |
| `react@19.0.0` | `sha512-V8AVnmPIICiWpGfm6GLzCR/W5FXLchHop40W4nXBmdlEceh16rCN8O8LNWm5bh5XUX91fh7KpA+W0TgMKmgTpQ==` |
| `react-dom@19.0.0` | `sha512-4GV5sHFG0e/0AD4X+ySy6UJd3jVl1iNsNHdpad0qhABJ11twS3TTBnseqsKurKcsNqCEFeGL3uLpVChpIO3QfQ==` |
| `viem@2.21.60` | `sha512-fzelL587wOtgNNKphbFCa/Ac9AgFGYKNdEZ04s5OO9Ua6Wu/3qIwjRmq3Z2rmiixr8HSqOHXjWLua6NiuUoRDg==` |
| `wagmi@2.14.16` | `sha512-njOPvB8L0+jt3m1FTJiVF44T1u+kcjLtVWKvwI0mZnIesZTQZ/xDF0M/NHj3Uljyn3qJw3pyHjJe31NC+VVHMA==` |
| `@playwright/test@1.49.1` | `sha512-Ky+BVzPz8pL6PQxHqNRW1k3mIyv933LML7HktS8uik0bUXNCdPhoS/kLihiO1tMf/egaJb4IutXd7UywvXEW+g==` |
| `@tanstack/react-query@5.71.1` | `sha512-6BTkaSIGT58MroI4kIGXNdx/NhirXPU+75AJObLq+WBa39WmoxhzSk0YX+hqWJ/bvqZJFxslbEU4qIHaRZq+8Q==` |
| `@tanstack/query-core@5.71.1` | `sha512-4+ZswCHOfJX+ikhXNoocamTUmJcHtB+Ljjz/oJkC7/eKB5IrzEwR4vEwZUENiPi+wISucJHR5TUbuuJ26w3kdQ==` |
| `hono@4.6.19` | `sha512-Xw5DwU2cewEsQ1DkDCdy6aBJkEBARl5loovoL1gL3/gw81RdaPbXrNJYp3LoQpzpJ7ECC/1OFi/vn3UZTLHFEw==` |

**PostgreSQL 16.4** — source tarball `postgresql-16.4.tar.bz2`, published sha256:

```
971766d645aa73e93b9ef4e3be44201b4f45b5477095b049125403f9f3386d6f
```

Source: `https://ftp.postgresql.org/pub/source/v16.4/postgresql-16.4.tar.bz2.sha256`. PostgreSQL is a
**deployment-time fact** under the same recording discipline (refreeze §9) — a service the indexer
connects to, not a package the repository installs. Nothing in the tree links it.

---

## 4. Licence and compatibility determination

### 4.1 Licence

| Licence | Packages | GPL-3.0-or-later compatible |
|---|---|---|
| MIT | ponder, next, react, react-dom, viem, wagmi, @tanstack/react-query (+ query-core), hono | Yes — permissive, one-way compatible |
| Apache-2.0 | `@playwright/test` | Yes with GPLv3 specifically (not GPLv2); test-only, never distributed |
| PostgreSQL Licence | PostgreSQL 16.4 | Yes — permissive, BSD/MIT-style; separate service, not linked |

**Determination: the project's `GPL-3.0-or-later` posture is unchanged.** No copyleft-incompatible
licence enters, none obliges relicensing, and none of these are smart-contract source — **the audited
on-chain surface acquires no dependency whatsoever from this refreeze.**

`@playwright/test`'s Apache-2.0 patent clause is compatible with GPLv3 but would not be with GPLv2,
which is why the project's `or-later` selection of GPLv3 is recorded explicitly rather than assumed.

`THIRD_PARTY_NOTICES.md` requires a new section on acceptance. It has **not** been edited — notices
for uninstalled packages would assert a distribution that has not happened.

### 4.2 Node engine coherence

`ponder@0.8.33` requires `node >=18.14`; `next@15.1.12` requires `^18.18.0 || ^19.8.0 || >=20.0.0`;
`hono@4.6.19` requires `>=16.9.0`. The binding constraint is Next's, so both roots run on Node ≥ 20
without conflict.

### 4.3 Peer-range satisfaction — every edge checked

| Parent | Declared peer range | Proposed pin | Satisfied |
|---|---|---|---|
| `wagmi@2.14.16` | `viem: 2.x` | `viem@2.21.60` | ✓ |
| `wagmi@2.14.16` | `react: >=18` | `react@19.0.0` | ✓ |
| `wagmi@2.14.16` | `@tanstack/react-query: >=5.0.0` | `5.71.1` | ✓ |
| `ponder@0.8.33` | `viem: >=2` | `viem@2.21.60` | ✓ |
| `ponder@0.8.33` | `hono: >=4.5` | `hono@4.6.19` | ✓ |
| `next@15.1.12` | `react: ^18.2.0 \|\| ^19.0.0` | `react@19.0.0` | ✓ |
| `next@15.1.12` | `react-dom: ^18.2.0 \|\| ^19.0.0` | `react-dom@19.0.0` | ✓ |
| `react-dom@19.0.0` | `react: ^19.0.0` | `react@19.0.0` | ✓ |
| `@tanstack/react-query@5.71.1` | `react: ^18 \|\| ^19` | `react@19.0.0` | ✓ |

`typescript` is an **optional** peer of `wagmi`, `ponder` and `viem` (`peerDependenciesMeta.optional`)
and is therefore not admitted here. Adding it would be scope expansion, not gate discharge.

**Both D-2 candidates PASS verification.** No deviation or nearest-compatible substitution was
required.

### 4.4 Era appropriateness of the D-2 patches

| Package | Pin | Published | Parent | Parent published | Δ |
|---|---|---|---|---|---|
| `@tanstack/react-query` | 5.71.1 | 2025-03-31 08:35 UTC | `wagmi@2.14.16` | 2025-03-31 19:00 UTC | **same day**, ~10 h earlier |
| `hono` | 4.6.19 | 2025-01-26 09:32 UTC | `ponder@0.8.33` | 2025-01-27 18:55 UTC | **1 day earlier** |

Each is the newest in-major release existing at the moment its parent was published — i.e. the
version the parent was actually built and released against. This is the narrowest defensible
selection: it satisfies the declared range, and it minimises the untested-combination surface, which
matters here because this stack renders a truth surface where a subtle state or render regression is
a *truthfulness* risk, not merely a bug. The newest-in-major alternatives (`5.101.4` from 2026-07-21,
`4.13.2` from 2026-08-13) would pair 2026 peers with 2025 parents for no stated benefit.

---

## 5. Security qualification — D-1 (required evidence)

The operator required that the `next@15.1.12` selection be verified against the `react-server-dom-*`
surface **from evidence, not inferred from the version number**. This section is that evidence.

### 5.1 What the vulnerability actually is

Primary sources: `https://nextjs.org/blog/CVE-2025-66478` (advisory published 2025-12-03, updated
2025-12-06) and `https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components`.

- **CVE-2025-66478** (Next.js, `GHSA-9qr9-h5gf-34mp`) tracks the **downstream** impact on Next.js App
  Router applications. Rated **CVSS 10.0**, remote code execution.
- It **originates upstream in React** as **CVE-2025-55182** — the React Server Components protocol
  allowed untrusted input to influence server-side execution.
- Affected Next.js: **15.x, 16.x, and 14.3.0-canary.77+**. Explicitly *not* affected: 13.x, 14.x
  stable, **Pages Router applications, and the Edge Runtime**.

### 5.2 Which packages are actually vulnerable

Per the React advisory, the vulnerable packages are the three RSC transport packages —
`react-server-dom-webpack`, `react-server-dom-parcel`, `react-server-dom-turbopack` — at versions
`19.0`, `19.1.0`, `19.1.1`, `19.2.0`; fixed in `19.0.1`, `19.1.2`, `19.2.1`.

**`react` and `react-dom` are not listed as directly vulnerable packages.** This is corroborated
independently by the registry: the entire `react` and `react-dom` `19.0.x` line —
`19.0.0` through `19.0.8` — carries **no npm deprecation**, whereas Vercel *did* deprecate every
affected `next` release. Two independent signals agree.

### 5.3 The `react-server-dom-*` surface of `next@15.1.12` — what was verified

**Declared surface (verified, primary source).** The complete manifests of `next@15.1.4` and
`next@15.1.12` were diffed. Both declare exactly seven dependencies —
`busboy@1.6.0`, `postcss@8.4.31`, `@next/env` (version-tracking), `styled-jsx@5.1.6`,
`@swc/counter@0.1.3`, `@swc/helpers@0.5.15`, `caniuse-lite@^1.0.30001579` — plus identical
`peerDependencies` and identical `optionalDependencies` (`sharp` + the nine `@next/swc-*` platform
binaries). **No `react-server-dom-*` entry appears in `dependencies`, `peerDependencies`, or
`optionalDependencies` at either version.**

Consequence: **there is no dependency edge through which a vulnerable `react-server-dom-*` could be
reintroduced.** The graph cannot resolve one because it does not reference one. This is the strongest
statement obtainable pre-install, and it is a statement about the manifest, not about the version
number.

**Bundled surface (honest residual).** Next.js vendors its RSC runtime inside its own tarball
(`next/dist/compiled/…`). That copy's version is therefore **not expressible as a lockfile entry and
cannot be pinned or verified independently of `next` itself** — the `next` pin *is* the control, and
its sha512 (§3.3) is the integrity evidence for it. Byte-level confirmation of the bundled RSC
version would require unpacking the `next@15.1.12` tarball, which is a gated package this node may
not use. Recorded as a **post-acceptance, pre-import obligation** (§8 step 3) rather than claimed.

**Version-selection evidence.** The advisory names `15.1.9` as the 15.1.x fix. The npm registry,
read at the time of writing, nevertheless marks `15.1.9` **and** `15.1.10` deprecated with the same
security notice, while `15.1.11` (2025-12-11) and `15.1.12` (2026-01-26) carry none — a pattern
consistent with `15.1.9` having been an incomplete fix completed by `15.1.11`. **The operator's
selection of `15.1.12` is therefore strictly more conservative than the advisory's own stated
remedy**, and is the highest clean release in the accepted 15.1.x family. Full line status:

| Releases | Registry status |
|---|---|
| 15.1.0 – 15.1.10 | **deprecated — security vulnerability** |
| 15.1.11, 15.1.12 | clean |

### 5.4 Determination on `react` / `react-dom` = 19.0.0

The operator directed that `19.0.0` be preserved unless primary-source evidence proves the
combination cannot lawfully accompany `next@15.1.12`. **No such evidence exists**, on three
independent grounds:

1. `react` and `react-dom` are not among the vulnerable packages (§5.2);
2. neither is deprecated at `19.0.0`, nor anywhere in the `19.0.x` line;
3. `next@15.1.12` declares `react: ^18.2.0 || ^19.0.0` — `19.0.0` is squarely in range (§4.3).

**`react = 19.0.0` and `react-dom = 19.0.0` are preserved**, as directed.

*Disclosure, not a recommendation to change:* React published `19.0.1` on 2025-12-03 (the advisory
date) and `19.0.2`/`19.0.3` on 2025-12-11, mirroring the Next.js remediation timeline, and the
advisory says updates are "recommended" for `react`/`react-dom` even though they are not the
vulnerable packages. The 19.0.x line currently runs to `19.0.8`. Moving the React pin is an
authority-level choice the operator has already made in the other direction; it is recorded here so
the choice is visible rather than silent.

### 5.5 The architectural safety argument (accepted authority, independent of any pin)

The React advisory states the scope condition directly: *"If your app's React code does not use a
server, your app is not affected by this vulnerability."*

The accepted SDD specifies exactly that architecture: Next.js is selected for a
"**Static-exportable read-only UI; no server-side custody of anything**" (sdd.md:L449); "Off-chain
components are read-only truth surfaces plus transaction builders; none holds keys or custody"
(sdd.md:L453); and Sprint 6's own security note records "**Sensitive data:** none; no server-side
session state" (sprint.md:L450). A statically exported Next.js application has no server, hence no
RSC endpoint and no Server Function endpoint, hence nothing for this vulnerability class to reach.

This is a property of the **accepted architecture**, not of any version number — but it is an
*intended* property, and intent is not a build setting. **Binding Task 6.6 obligation:** the frontend
must be built as a static export with no server-side RSC or Server-Function endpoint, and that must
be asserted mechanically rather than assumed. Recorded in §8 step 5.

Defence in depth is therefore doubled: the patched `next` pin removes the vulnerable runtime, and the
static-export architecture removes the attack surface it would run in.

---

## 6. Disclosures (D-3, D-4, and one pass-1 correction)

### 6.1 D-3 — `ponder` pulls a second React major; transitive census deferred

`ponder@0.8.33` declares `react ^18.2.0` as a **direct** dependency, so a React 18 tree enters
wherever ponder is installed. Under the §7 two-root topology this is confined to `indexer/` and
**cannot reach** `web/`'s React 19 tree — the two roots have separate `node_modules` and separate
lockfiles, so the split is structural, not resolver-dependent. The resulting topology is
deterministic (every version string exact) and internally compatible (§4.3).

`ponder@0.8.33` carries 32 direct dependencies and `next@15.1.12` seven. A full transitive census is
not producible without resolving a lockfile, which requires the acceptance this gate withholds.
**Post-acceptance obligation** (§8 step 3): generate the lockfiles, produce the transitive licence
census from them, and record it **before any code imports a gated package**.

### 6.2 D-4 — `react` registry `gitHead` differs from the `v19.0.0` tag

- packument `gitHead`: `63cde684f5340b1ca73f6244501aac1c3d2c92a8`
- tag `v19.0.0`: `7aa5dda3b3e4c2baa905a59b922ae7ec14734b24`

Both are immutable 40-char commits. The divergence is a normal consequence of React's release
pipeline publishing from a build commit and tagging separately; no other pin in this set shows it.
The authoritative identity of the artifact that will actually be installed is the sha512 in §3.3,
which the lockfile records and the installer enforces. Recorded so a later reviewer comparing the two
does not read it as drift.

### 6.3 Correction to pass 1 — `@tanstack/react-query@5.71.1` **does** have a resolvable tag

Pass 1 of this document stated that upstream tags for `@tanstack/react-query@5.71.1` were "not
currently resolvable via `git ls-remote`". **That was wrong**, and the cause was methodological: the
search was truncated by a `head` filter over a 4,424-tag namespace, and TanStack changed tag schemes
across eras — older releases use a repo-wide `v<version>` tag, newer ones a per-package
`@tanstack/<pkg>@<version>` tag. Enumerating the full namespace resolves it cleanly:

- tag object `828249fd05e76d1fe66d110f8c1a80691711d2d0` → **peeled commit
  `6c105d6ddfc797ab5fe106d6020978f711e3af43`** (annotated).

The identity is recorded in §3.3. The verification method in §2 now specifies full-namespace
enumeration so the same truncation cannot recur.

---

## 7. Dependency and lockfile surface

**Two roots, not one workspace.** Each gets its own manifest and its own lockfile:

```
indexer/    package.json + package-lock.json
              ponder@0.8.33 · viem@2.21.60 · hono@4.6.19

web/        package.json + package-lock.json
              next@15.1.12 · react@19.0.0 · react-dom@19.0.0 · viem@2.21.60
              wagmi@2.14.16 · @tanstack/react-query@5.71.1
              @playwright/test@1.49.1  (dev)
```

This is not organisational preference. It is what keeps D-3's `react@^18` tree out of the frontend
**structurally** rather than by relying on resolver nesting, and it matches the SDD's own component
boundary: the indexer and the frontend are separate deployables that do not import each other
(sdd.md §2.2, §5.3).

**Manifest discipline**

- Every dependency written as an **exact version string** — no `^`, no `~`, no ranges.
- `.npmrc` sets `save-exact=true`, so a later `npm install <pkg>` cannot silently reintroduce a range.
- Both lockfiles committed.

**CI lockfile-drift gate** (Sprint 6 AC: "CI: lockfile-drift gate active; pinned versions equal
accepted pins")

- `npm ci` in both roots — fails closed when a lockfile disagrees with its manifest, and unlike
  `npm install` never rewrites the lockfile.
- A check asserting each manifest's pinned version equals the accepted pin in **this** document, so
  the gate catches *accepted-pin* drift and not merely manifest/lockfile disagreement.
- `npm ci` verifies each package's recorded integrity digest on extraction; the §3.3 sha512 values are
  what must appear in the committed lockfiles.

**Trust boundary.** Both roots are read-only with respect to protocol authority: the indexer derives
a disposable replica from chain events and never writes on-chain; the frontend reads and builds
transactions the user signs. Neither holds keys or custody (sdd.md:L451, L453).

---

## 8. Exclusions, and the authorized sequence on acceptance

This refreeze, if accepted, authorizes **exactly** the ten packages and versions in §3.1/§3.2 plus
the disclosed exact transitive `@tanstack/query-core@5.71.1`, and nothing more. Explicitly **not**
authorized:

- any other version of any listed package, including a later patch — a newer revision requires its
  own refreeze, per the standing full-SHA-only pin policy;
- `typescript`, which is an **optional** peer everywhere it appears in this set;
- `slither` and any other CI/static-analysis toolchain — that gate is **Sprint 8, Task 8.1**, untouched;
- Tailwind CSS — named as a design choice at sdd.md:L623, absent from the refreeze §9 obligation list
  and **not** requested here; a further operator gate if Task 6.6 needs it;
- any UI component library, styling framework, state library, ORM, or test utility not listed;
- any smart-contract source. OZ / v3-core / Miner allowlists unchanged, `POOL_INIT_CODE_HASH`
  untouched, Foundry toolchain refreeze unaffected.

Preserved unchanged: default deny, full-SHA-only pin policy, the Miner Manifold three-file allowlist,
`Heesho/liquid-signal-governance` `DEFERRED_NOT_V1`, and every operator-reserved value (Q-3, Q-4,
Q-6, R-1…R-14).

**Operator acceptance is recorded (2026-08-14).** The pre-install gate is satisfied for exactly the
set above. Creating the two package roots, exact manifests, deterministic lockfiles, and installing
and using that set is authorized. Anything outside the set is not: if installation reveals a new
required direct or peer dependency not covered here, **stop with a new bounded HITL** rather than
adding it.

The authorized actions, in order:

1. Write `indexer/package.json` and `web/package.json` with the exact pins in §7, plus `.npmrc`.
2. Generate and commit both lockfiles; verify every recorded integrity digest equals §3.3.
3. Produce the transitive licence census from the lockfiles (**D-3**, §6.1) **and** confirm the
   bundled `react-server-dom-*` version inside `next@15.1.12` is a fixed release
   (`19.0.1` / `19.1.2` / `19.2.1` or later) — the §5.3 residual. Update `THIRD_PARTY_NOTICES.md`.
4. Add the CI lockfile-drift gate (§7).
5. Configure the `web/` build as a **static export with no server-side RSC or Server-Function
   endpoint**, asserted mechanically (§5.5 binding obligation).
6. Proceed to Tasks 6.4 → 6.8.

Sprint 6 Tasks 6.2 (`Lens.sol`) and 6.3 (event-completeness audit) are complete and required none of
this — they touch no off-chain package.

---

## 9. Acceptance

Operator acceptance was recorded on **2026-08-14**, authorizing exactly the ten packages and versions
enumerated in §3.1/§3.2, plus the disclosed exact transitive `@tanstack/query-core@5.71.1` where the
accepted dependency graph requires it — and no more. It does not authorize arbitrary dependency
expansion, and it grants **no wildcard family authorization**: a later patch of any listed package
requires its own refreeze under the standing full-SHA-only pin policy.

This acceptance activates the §3 authorizations, makes the §7 two-root topology the accepted
dependency surface, and discharges the pre-install gate of Sprint 6 Task 6.1.

| Item | State at acceptance |
|---|---|
| **D-1** | RESOLVED — `next = 15.1.12`; `react`/`react-dom` preserved at `19.0.0` on the §5.4 evidence |
| **D-2** | ACCEPTED — `@tanstack/react-query@5.71.1`, `hono@4.6.19`; both verified PASS (§4.3), no substitution required |
| **D-3** | Disclosure preserved (§6.1) — `ponder`'s `react@^18` tree, confined to `indexer/`; transitive census obligation live |
| **D-4** | Disclosure preserved (§6.2) — `react` `gitHead` vs. tag divergence |

**Two disclosed discrepancies are preserved, not smoothed away** (operator direction):

1. **Bundled RSC runtime required post-acceptance verification** (§5.3). The declared graph is
   provably clean; the copy Next vendors inside its own tarball was not verifiable before install.
   This is now discharged — see `grimoires/loa/a2a/sprint-6/evidence/next-rsc-bundled-verification.md`.
2. **Historical advisory / npm deprecation disagreement inside the earlier 15.1.x patch sequence**
   (§5.3). The advisory names `15.1.9` as the 15.1.x fix; npm still deprecates `15.1.9` and `15.1.10`.
   The accepted `15.1.12` is strictly more conservative than the vendor's stated remedy. The
   disagreement is retained as a fact about the upstream record, not reconciled.

**Pre-acceptance candidate digests, re-verified immediately before this mutation:**

| Artifact | sha256 at HITL presentation |
|---|---|
| `vux-v1-offchain-provenance-refreeze-2026-08.md` | `f39dcf424abdc319be38fe4a888144470de8b31de4d929e6c5f15e178d2ee0d6` |
| `vux-v1-source-registry-offchain-refreeze-2026-08.json` | `8449ebb367b5650c20018384810349d78ebaf402f781d9c8d1af103098fe7699` |

Both matched. Substantive pin/provenance content (§3–§7) is **unchanged** by this acceptance; the
mutation is confined to the status header, the §8 gate framing, and this section.

## 10. Authority disposition

This refreeze **completes** the deferred off-chain obligation recorded at
`vux-v1-oz-v3-provenance-refreeze-2026-08.md` §9 for ponder / Next.js + React / viem + wagmi /
Playwright / PostgreSQL. The `slither` and CI/static-analysis portion of that obligation remains
**open and deferred to Sprint 8, Task 8.1**.

No predecessor authority file is rewritten, no historical attribution is removed, and no precedence
above the licence/pin layer changes: FREEZE/SPEC supersessions, the accepted PRD, and the accepted
SDD govern product and architecture; this refreeze governs only off-chain source provenance and
licence state for the enumerated packages. Consistent with the strategic-treasury-delta and OZ/v3
precedents, the refreeze self-describes its authority disposition here rather than via a separate
authority-map delta.

**One accepted-authority reconciliation is recorded rather than performed:** `sdd.md:L449` names
Next.js `15.1.4`. The accepted pin is `15.1.12` — a security-patch selection inside the same accepted
15.1.x family, which the operator's D-1 disposition states "does not reopen the accepted frontend
architecture or authorize a major/minor family change". The SDD is **not** edited by this node; the
divergence is recorded here and carried to review as a documentation-reconciliation item.
