---
name: verifying-vendored-dependency-patches
description: |
  A CVE names package X, your lockfile has no edge to X, and the framework you
  actually installed bundles a compiled copy of X inside its own tarball. The
  dependency graph therefore cannot answer "is the vulnerable code patched?" —
  and neither can the framework's version number. Apply when verifying a
  security fix in any framework that vendors its dependencies (Next.js, bundled
  runtimes, shaded JARs, vendored Go modules). Provides the artifact-level
  verification, the build-stamp ordering test, and the asymmetry inference that
  corroborates a targeted security rebuild.
loa-agent: implementing-tasks
extracted-from: sprint-6-task-6.1 (VUX v1, off-chain provenance gate)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - supply-chain
  - cve-verification
  - vendored-dependencies
  - provenance
  - nextjs
---

## Problem

An advisory names specific packages and fixed versions. You pin a patched release
of the *framework*, then try to prove the vulnerable code is actually gone — and
discover the framework declares no dependency on the named packages at all,
because it vendors compiled copies inside its own tarball.

Every graph-level check comes back clean and proves nothing:

- `npm ls <vulnerable-package>` → not found
- lockfile audit → no such entry
- integrity digests → all match, for packages that aren't the ones at risk

The vendored copy has no version in its `package.json`, so even reading it does
not immediately answer the question.

## Trigger Conditions

### Symptoms

- An advisory names package X; `npm ls X` / lockfile search finds no X
- The framework's own `package.json` lists neither X nor anything resembling it
- A vendored directory (`dist/compiled/`, `vendor/`, shaded namespace) contains X
- The vendored copy's `package.json` has no `version` field
- Someone proposes to close the item on "we upgraded the framework, so it's fine"

### Context

| Context | Value |
|---|---|
| Technology Stack | any framework that vendors deps — Next.js, bundlers, shaded JVM artifacts, vendored Go |
| Timing | after installing a security-patched release, before relying on the code |
| Prerequisites | the package is installed; you can read its files |

## Root Cause

Vendoring severs the dependency edge. The bundler copies compiled output into the
distributing package, so the consumer's resolver never sees the vulnerable
package and no lockfile entry exists to pin, audit, or verify. The *only* control
over the vendored version is the outer package's pin, and the only evidence about
its content is the bytes on disk.

The framework version number is a proxy, not evidence — which is exactly what a
verification instruction like "do not infer this from the version number" is
guarding against.

## Solution

### Step 1: Establish what is actually vulnerable, from the advisory

Read the upstream advisory, not the downstream one alone. Record the vulnerable
package names, the affected version ranges, and the fixed versions — plus their
**publish dates**, which become the fix floor.

Do not assume the framework's own advisory names the same packages; a downstream
advisory often tracks an upstream one with a different package set.

### Step 2: Prove the declared surface is clean — and say what that does and does not prove

Diff the complete manifest of the vulnerable version against the patched one:

```bash
# dependencies, peerDependencies AND optionalDependencies, both versions
node -e "
const https=require('https');
https.get('https://registry.npmjs.org/<pkg>',{headers:{accept:'application/json'}},r=>{
  let b='';r.on('data',d=>b+=d);r.on('end',()=>{const j=JSON.parse(b);
  for (const v of ['<vulnerable>','<patched>']) {
    const m=j.versions[v];
    console.log(v, JSON.stringify({d:m.dependencies,p:m.peerDependencies,o:Object.keys(m.optionalDependencies||{})}));
    console.log('  names <vulnerable-package> anywhere:', /<vulnerable-package>/.test(JSON.stringify(m)));
  }});});
"
```

The finding is worth stating precisely: **no dependency edge exists through which
a vulnerable copy could be reintroduced.** That is a real property. It is not the
property under test.

### Step 3: Extract build stamps from the vendored bytes

Compiled React-family bundles carry a stamp like `19.0.0-rc-<sha8>-<YYYYMMDD>`;
other ecosystems embed a version constant. Walk the vendored tree and collect them:

```javascript
const rcRe = /\d+\.\d+\.\d+-rc-[0-9a-f]{8,}-\d{8}/g;
const plainRe = /"(\d+\.\d+\.\d+)"/g;
// walk vendored dir, read every .js, collect both patterns into a Set
```

### Step 4: Test the stamp against the fix floor

```javascript
const FIX_FLOOR = '20251211';           // date of the LAST published fix in the line
const FIXED = ['19.0.1','19.1.2','19.2.1'];

function verdict(stamp) {
  if (FIXED.includes(stamp)) return {ok:true};
  const rc = stamp.match(/^\d+\.\d+\.\d+-rc-([0-9a-f]{8,})-(\d{8})$/);
  if (rc) return {ok: rc[2] >= FIX_FLOOR, why:`build ${rc[1]} dated ${rc[2]}`};
  return {ok:false, why:`unrecognised stamp — cannot establish it is patched`};
}
```

Fail closed on an unrecognised stamp. "I could not determine the version" must
not render as a pass.

### Step 5: The asymmetry inference — the strongest evidence available

Also stamp the packages the advisory says are **not** vulnerable. If the
vulnerable ones were rebuilt and the non-vulnerable ones were not, that asymmetry
is a *targeted security rebuild*, and it independently corroborates the advisory's
package scope:

```
react-server-dom-webpack    19.0.0-rc-8eb60861-20260126   <- rebuilt, 7 weeks after the fix
react-server-dom-turbopack  19.0.0-rc-8eb60861-20260126   <- rebuilt
react                       19.0.0-rc-65e06cb7-20241218   <- untouched
react-dom                   19.0.0-rc-65e06cb7-20241218   <- untouched
```

A wholesale version bump moves all four. A cosmetic change moves none. Only a
targeted fix produces this split — so the split is evidence, not decoration.

### Step 6: Prove nothing can shadow the vendored copy

A resolvable top-level copy of the vulnerable package would let application code
load an unvendored — possibly vulnerable — version:

```javascript
for (const p of ['<vuln-a>','<vuln-b>','<vuln-c>'])
  assert(!existsSync(join(ROOT,'node_modules',p)), `${p} could shadow the vendored runtime`);
```

### Step 7: Reduce the attack surface architecturally, and assert that too

If the vulnerability requires a capability your app does not use (a server, a
particular endpoint), assert the built artifact genuinely lacks it. Then the
verification stands on two legs instead of one.

## Verification

### Command

```bash
node scripts/verify-rsc-runtime.mjs
```

### Expected Output

```
  next installed        : 15.1.12 (= accepted pin)
  vendored RSC transports:
    react-server-dom-webpack: 19.0.0-rc-8eb60861-20260126  ->  OK (dated 20260126 >= fix floor 20251211)
VERDICT: PASS — the installed artifact is consistent with the accepted security posture.
```

### Checklist

- [ ] Upstream advisory read; vulnerable packages and fixed versions recorded with dates
- [ ] Manifest diff performed; the "no edge exists" finding stated with its limits
- [ ] Build stamps extracted from the vendored bytes, not from a version field
- [ ] Stamps tested against a fix floor, failing closed on anything unrecognised
- [ ] Non-vulnerable packages stamped too, so the asymmetry can be read
- [ ] Shadowing check performed
- [ ] The check is a re-runnable script, not a one-off investigation

## Limits — state them in the output

Vendored build stamps are frequently **internal identifiers that are not published
artifacts**. Confirm this rather than assuming it:

```bash
# is the stamp a published version at all?
curl -s https://registry.npmjs.org/<vulnerable-package> | node -e "..."
```

If it is not published, no byte-comparison against a fixed release is possible,
and the verification rests on date ordering + rebuild asymmetry + shadowing +
architecture. **Say so in the tool's own output.** A verification that hides its
limit is a verification a reviewer cannot calibrate.

## Related

- `[Implementation technique — proving a capability is absent]` (NOTES.md) — absence
  claims need positive controls; this skill is the case where the absence is
  *structural* (no edge exists) and therefore proves less than it appears to.
- `capability-definition-is-not-use` — the companion failure when grepping bundles.
