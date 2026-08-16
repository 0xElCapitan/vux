# Bundled RSC runtime verification — `next@15.1.12`

**Discharges:** the post-acceptance obligation recorded at
`docs/authority/vux-v1-offchain-provenance-refreeze-2026-08.md` §5.3 / §9 item 1 — *"bundled RSC
runtime required post-acceptance verification"*.
**Operator instruction:** inspect the actual installed artifact; do not infer from manifest edges;
fail closed if the install contradicts the accepted security posture.
**Date:** 2026-08-14 · **Verdict: PASS**

**Mechanical form:** `web/scripts/verify-rsc-runtime.mjs` (`npm run verify:rsc`, exit 0 = pass).
This document records the evidence; the script re-checks it on demand and in CI.

---

## 1. What is actually vulnerable

| | |
|---|---|
| Downstream tracker | **CVE-2025-66478** (Next.js, `GHSA-9qr9-h5gf-34mp`) |
| Upstream origin | **CVE-2025-55182** (React) |
| Severity | **CVSS 10.0**, remote code execution |
| Mechanism | the React Server Components protocol allowed untrusted input to influence server-side execution |
| Vulnerable packages | `react-server-dom-webpack`, `react-server-dom-parcel`, `react-server-dom-turbopack` at `19.0`, `19.1.0`, `19.1.1`, `19.2.0` |
| Fixed | `19.0.1`, `19.1.2`, `19.2.1` |
| **Not** vulnerable | `react`, `react-dom` |
| Advisory scope condition | *"If your app's React code does not use a server, your app is not affected by this vulnerability."* |

Published fix dates (npm, primary source): `react-server-dom-webpack@19.0.1` 2025-12-03,
`@19.0.2` 2025-12-11, `@19.0.3` 2025-12-11. The verification's fix floor is therefore **2025-12-11**.

---

## 2. Why the manifest cannot answer this

Next.js declares **no** `react-server-dom-*` dependency — it vendors compiled copies inside its own
tarball. Verified by a complete manifest diff of the two versions:

| | `next@15.1.4` | `next@15.1.12` |
|---|---|---|
| `dependencies` | `busboy@1.6.0`, `postcss@8.4.31`, `@next/env`, `styled-jsx@5.1.6`, `@swc/counter@0.1.3`, `@swc/helpers@0.5.15`, `caniuse-lite@^1.0.30001579` | identical except `@next/env`, which tracks the next version |
| `peerDependencies` | identical | identical |
| `optionalDependencies` | `sharp` + 9 `@next/swc-*` | identical |
| `react-server-dom-*` declared anywhere | **no** | **no** |

So the dependency graph has **no edge** through which a vulnerable RSC copy could be reintroduced —
a real property, but not the property under test. The installed bytes are.

---

## 3. What the installed artifact contains

Extracted from `web/node_modules/next/dist/compiled/**` by walking every `.js` file and collecting
React build stamps:

| Bundled package | Build stamp | Verdict |
|---|---|---|
| `react-server-dom-webpack` | `19.0.0-rc-8eb60861-20260126` | **OK** — 2026-01-26 ≥ fix floor 2025-12-11 |
| `react-server-dom-turbopack` | `19.0.0-rc-8eb60861-20260126` | **OK** — same |
| `react` | `19.0.0-rc-65e06cb7-20241218` | not a vulnerable package |
| `react-dom` | `19.0.0-rc-65e06cb7-20241218` | not a vulnerable package |

**The two vulnerable transports were rebuilt from a React source state dated 2026-01-26 — the same
date `next@15.1.12` was published — while the two non-vulnerable bundles were left at their original
2024-12-18 build.** That asymmetry is the signature of a *targeted RSC security rebuild*, and it
independently corroborates the advisory's statement that `react`/`react-dom` are not the vulnerable
packages. A wholesale version bump would have moved all four; a cosmetic change would have moved none.

Additional check: no `react-server-dom-webpack`, `-turbopack`, or `-parcel` is resolvable at the top
level of `web/node_modules`, so nothing in the installed tree can shadow the vendored copies.

---

## 4. Version-selection evidence

The advisory names `15.1.9` as the 15.1.x fix. The npm registry nevertheless marks `15.1.9` **and**
`15.1.10` deprecated with the security notice; only `15.1.11` (2025-12-11) and `15.1.12` (2026-01-26)
are clean. The most consistent reading is that `15.1.9` was an incomplete fix completed by `15.1.11`
— note `15.1.10` and `15.1.11` were published the same day.

**The accepted `15.1.12` is therefore strictly more conservative than the vendor's own stated
remedy.** This disagreement between the advisory text and the registry deprecation state is preserved
in the refreeze rather than reconciled away (§9 item 2).

---

## 5. Defence in depth: the app has no server for this to reach

The advisory's scope condition is explicit, and the accepted architecture satisfies it: Next.js was
selected for a *"Static-exportable read-only UI; no server-side custody of anything"* (sdd.md:L449),
with *"no server-side session state"* (sprint.md:L450).

That intent is now mechanical, not prose — `web/scripts/verify-static-export.mjs` (`npm run
verify:static`) asserts against the **build output**:

- `next.config.mjs` sets `output: 'export'`;
- all five accepted pages are emitted as static HTML (6 documents incl. `_not-found`);
- no server bundle, no `standalone/`, no `required-server-files.json`;
- **zero** `react.server.reference` markers and **zero** `createServerReference` call sites.

### A false positive worth recording

The first run of the static-export gate **failed**, flagging `createServerReference` in a shared
client chunk. Triage showed it was the *definition* — `t.createServerReference = function(…)` — from
the `react-server-dom-webpack/client` runtime that Next bundles into its client chunk
unconditionally, with **zero** `react.server.reference` markers anywhere.

Defining the capability is not using it: with no server there is no endpoint for it to call, and no
server-reference object is ever materialised. The detector was **sharpened rather than relaxed** — it
now counts call sites and type markers separately from definitions, so it still fires on a real
Server Function while not firing on dead library code. Recorded because loosening a security check is
exactly the kind of change that should carry its reason on the record.

---

## 6. Verdict and its stated limit

**PASS — the accepted install does not contain an unpatched vulnerable RSC implementation.**

Established on four independent legs:

1. the vendored RSC transports postdate every published fix by ~6–7 weeks;
2. the targeted-rebuild asymmetry corroborates the advisory's package scope;
3. nothing in the tree can shadow the vendored copies;
4. the app is a static export with no server, so the vulnerable surface is not reachable even in
   principle.

**Limit, stated rather than hidden:** the vendored build stamp `8eb60861-20260126` is an internal
Vercel/React build identifier and is **not** a published npm artifact — confirmed by enumerating the
`react-server-dom-webpack` packument, where the older `65e06cb7-20241218` stamp *is* published and the
newer one is not. It therefore cannot be byte-compared against a published fixed release. The
determination rests on build-date ordering, the rebuild signature, the shadowing check, and the
architectural scope condition — not on a byte-for-byte equality proof, which the upstream release
model does not make available.
