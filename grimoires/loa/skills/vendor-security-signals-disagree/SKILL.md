---
name: vendor-security-signals-disagree
description: |
  Registry deprecation flags, advisory "fixed in" lists, and release timelines are
  three independent signals about the same vulnerability, and they routinely
  disagree — an advisory names a fixed version the registry still marks
  vulnerable, and the package at the CVE's origin carries no deprecation at all.
  Apply when selecting a patched version or judging whether a pinned dependency is
  affected. Provides the cross-check and the rule that absence of a flag is never
  evidence of safety.
loa-agent: implementing-tasks
extracted-from: sprint-6-task-6.1 (VUX v1, CVE-2025-66478 / CVE-2025-55182 pin selection)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - cve-verification
  - dependency-selection
  - supply-chain
  - provenance
---

## Problem

Selecting a patched version from an advisory produced two contradictions:

1. **The advisory's own fix was still flagged vulnerable.** The Next.js advisory
   listed `15.1.9` as the 15.1.x fix. The npm registry marked `15.1.9` **and**
   `15.1.10` deprecated with the same security notice; only `15.1.11`+ were clean.
2. **The package at the vulnerability's origin carried no flag.** The CVE
   originated upstream in React (`CVE-2025-55182`), yet `react@19.0.0` — and the
   whole `19.0.x` line — showed **no npm deprecation**, while the downstream
   vendor had deprecated every affected release of its own package.

Reading either signal alone gives a wrong answer. Trusting the advisory's "fixed
in" pins a version the registry says is vulnerable. Trusting the absence of a
deprecation concludes React was unaffected, when React was the origin.

## Trigger Conditions

### Symptoms

- An advisory's "fixed versions" list conflicts with registry deprecation state
- A package implicated by a CVE carries no deprecation flag
- Multiple patch releases land on the same day (a completion follow-up)
- You are about to justify a pin with "it's not deprecated, so it's fine"
- You are about to justify a pin with "the advisory says this version is fixed"

### Context

| Context | Value |
|---|---|
| Technology Stack | npm/PyPI/crates or any registry with deprecation metadata |
| Timing | selecting an exact pin under a security constraint |
| Prerequisites | a published advisory and registry access |

## Root Cause

The three signals are produced by different parties with different incentives and
at different times:

| Signal | Author | Updated after publication? | Failure mode |
|---|---|---|---|
| advisory "fixed in" | the vendor's security team | rarely | frozen at first-fix; misses incomplete fixes |
| registry deprecation | whoever publishes the package | yes, retroactively | applied inconsistently across orgs |
| release timeline | the release process | n/a | needs interpretation |

Deprecating for security is a **policy choice**, not a protocol. Vercel deprecated
its affected releases; the React team did not deprecate theirs. So an unflagged
package is one where nobody chose to flag it — which is not the same as one
nobody needed to flag.

An advisory published on day 1 also cannot describe a fix that turned out to be
incomplete on day 8.

## Solution

### Step 1: Read the upstream advisory, not only the downstream one

A downstream advisory tracks impact; the upstream one names the actually
vulnerable packages and versions. They frequently differ, and the upstream package
set is what you must check your pins against.

### Step 2: Enumerate the whole release line's deprecation state

Never check only the version you intend to pin:

```javascript
const doc = await get('https://registry.npmjs.org/<pkg>');
const line = Object.keys(doc.versions)
  .filter(v => v.startsWith('15.1.') && !v.includes('-'))
  .sort(byPatch);
for (const v of line) {
  const m = doc.versions[v];
  console.log(`${v.padEnd(8)} ${doc.time[v].slice(0,10)}  ${m.deprecated ? 'DEPRECATED: ' + m.deprecated.slice(0,70) : 'ok'}`);
}
```

The shape of the boundary is the finding:

```
15.1.0 – 15.1.10   DEPRECATED — security vulnerability
15.1.11 2025-12-11 ok
15.1.12 2026-01-26 ok
```

### Step 3: When the signals disagree, take the more recent one — and record the disagreement

Registry deprecation is mutable and can be applied after an incomplete fix is
discovered; an advisory usually is not revised. Prefer the registry, choose the
conservative version, and **write the disagreement into the record**:

```markdown
The advisory names `15.1.9` as the 15.1.x fix. The registry nevertheless marks
`15.1.9` and `15.1.10` deprecated — consistent with `15.1.9` having been an
incomplete fix completed by `15.1.11` (note `15.1.10` and `15.1.11` published the
same day). The accepted `15.1.12` is therefore strictly more conservative than the
vendor's own stated remedy.
```

A future reader comparing the advisory to your pin will otherwise see an
unexplained gap and assume error.

### Step 4: Treat an absent flag as no information

To decide whether a package is affected, use the advisory's package list and, for
bundled code, the artifact. Corroborate with the flag; never conclude from it.

```
react@19.0.0 not deprecated  ->  no information
react not in the advisory's vulnerable-package list  ->  evidence
```

State it that way in the record, so the reasoning is auditable:

> `react` and `react-dom` are not listed as vulnerable packages. This is
> corroborated — not established — by the registry: the entire 19.0.x line carries
> no deprecation, whereas the downstream vendor did deprecate every affected
> release. Two independent signals agree.

### Step 5: Read same-day release clusters as a fix sequence

Two releases on one day, the earlier deprecated and the later clean, is the
signature of a completion patch. It tells you the first fix was insufficient — and
that the advisory almost certainly still names the first one.

## Verification

### Command

```bash
node -e "/* enumerate the line's deprecation state, as Step 2 */"
```

### Expected Output

```
15.1.9   2025-12-03  DEPRECATED: This version has a security vulnerability...
15.1.11  2025-12-11  ok
15.1.12  2026-01-26  ok
```

### Checklist

- [ ] Upstream advisory read, not only the downstream tracker
- [ ] Whole release line enumerated, not just the candidate version
- [ ] Advisory "fixed in" cross-checked against registry deprecation
- [ ] Disagreement resolved conservatively AND recorded in the artifact
- [ ] No conclusion drawn from the *absence* of a deprecation flag
- [ ] Same-day release clusters interpreted as fix sequences
- [ ] For bundled/vendored code, the artifact checked too — see the related skill

## Related

- `verifying-vendored-dependency-patches` — once a version is selected, the
  registry cannot tell you what is inside a vendoring framework's tarball.
