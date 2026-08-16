---
name: absolute-form-requests-defeat-origin-form-path-guards
description: |
  A static-file server's path-containment check (`normalize()` + a
  `base.startsWith(ROOT)` prefix test) is tested with `fetch()` or a browser and
  every traversal probe returns 404 — because HTTP clients construct
  origin-form request targets (`GET /../x`), and Node's `path.normalize`
  collapses `..` against the URL's own leading `/` before the guard ever runs.
  The same server accepts absolute-form request lines (`GET http://a/../../x
  HTTP/1.1`), which Node's raw HTTP parser passes through unmodified as
  `req.url`, producing a `clean` path that legitimately begins with `..` and
  slips the prefix check. Apply whenever auditing or reviewing a hand-rolled
  static file server's path-containment logic — do not grade reachability from
  `fetch()`-based testing or from source reading alone. Provides the raw-socket
  probe technique and the concrete distinction between the two request forms.
loa-agent: auditing-security
extracted-from: sprint-6 (VUX v1 Truth Surfaces), audit-remediation re-audit — L-5 static-server re-grade
extraction-date: 2026-08-15
version: 1.0.0
tags:
  - path-traversal
  - http
  - static-file-server
  - security-audit
  - request-smuggling-adjacent
---

## Problem

`web/scripts/serve-static.mjs` serves a Next.js static export and contains a
containment guard:

```js
const clean = normalize(decodeURIComponent(urlPath.split('?')[0])).replace(/^([/\\])+/, '');
const base = join(OUT, clean);
if (!base.startsWith(OUT)) return null;
```

A prior audit graded the equivalent finding LOW/unreachable after testing with
`..`, URL-encoded `..`, double-encoded `..`, backslash separators, and mixed
separators via `fetch()` — all returned 404, and source reading confirmed
`normalize()` should collapse any of those against the leading `/`. The
conclusion "unreachable" was recorded and carried forward across a full audit
cycle. It was wrong: a differently-shaped request line reaches the server with
a `clean` value that genuinely starts with `..`, and the prefix check admits
it. A canary file placed one directory above the server's root was served over
HTTP with a 200 status and its contents in the body.

## Trigger Conditions

### Symptoms

- Reviewing/auditing a hand-rolled (not framework/library) static file server
  whose containment logic is `normalize(path)` + a string-prefix comparison
  against the root directory
- Prior testing used only a browser, `fetch()`, `curl <url>`, or an HTTP client
  library, and all traversal payloads were rejected
- The audit brief or your own instinct wants to grade the finding LOW based on
  "normalize() handles it" without an active adversarial probe

### Context

| Context | Value |
|---------|-------|
| Technology Stack | any server built on Node's raw `http.createServer`, or equivalent low-level HTTP libraries in other languages that expose the raw request line |
| Timing | any security review/audit of a custom static file server, especially one promoted from "test convenience" to a more-exposed role (e.g. `npx serve` replaced with an in-repo script, now bound to `npm start`) |
| Prerequisites | ability to open a raw TCP socket to the target — not available through `fetch()`/browser APIs |

## Root Cause

HTTP has two distinct request-target forms (RFC 7230 §5.3):

- **origin-form**: `GET /path HTTP/1.1` — what every browser, `fetch()`, and
  standard HTTP client library sends for a same-origin or already-connected
  request. It always begins with `/`.
- **absolute-form**: `GET http://host/path HTTP/1.1` — normally used only when
  talking to a proxy, but nothing in a raw `http.createServer` handler refuses
  it from a direct client. Node's parser extracts everything after the host as
  `req.url` **without stripping or normalizing the leading structure**.

`path.normalize()` only collapses `..` segments *relative to the string it is
given*. Fed `/../../../x` (origin-form, always slash-anchored), it produces
`x` — every `..` cancels against an implicit leading root. Fed the raw
absolute-form value, the code path that strips the URL's own leading
separator sees no leading separator to strip (the value has already been
through a different `split('?')` and `join`), and `normalize()` legitimately
returns a string beginning with `..`. `join(OUT, '..' + sep + 'x')` then
resolves to a path *outside* `OUT`, and a bare `startsWith(OUT)` — with no
trailing-separator boundary check — cannot distinguish `OUT-sibling` from `OUT`
followed by more path.

Testing exclusively through `fetch()`/browsers can never surface this: those
clients only ever construct origin-form requests, so the code path that fails
is structurally untested by anything except a client that controls the raw
request line.

## Solution

### Step 1: Read the guard for its EXACT boundary condition, not its intent

Two independent weaknesses to check, because either alone can be benign but
together are not:

```js
if (!base.startsWith(OUT)) return null;   // (a) no trailing-separator check —
                                            //     `OUT-sibling` passes if OUT
                                            //     has no trailing separator
```

The trailing-separator gap is usually cosmetic if nothing normalizes to a
leading `..` in the first place — which is exactly what (b), below, defeats.

### Step 2: Probe with a raw socket, constructing request lines a client library cannot

```js
import net from 'node:net';
const raw = (requestLine) => new Promise((resolve) => {
  const s = net.connect(PORT, HOST, () => {
    s.write(`${requestLine}\r\nHost: localhost\r\nConnection: close\r\n\r\n`);
  });
  let buf = '';
  s.on('data', (d) => { buf += d.toString('latin1'); });
  s.on('end', () => resolve(buf));
});

await raw('GET /../package.json HTTP/1.1');                 // origin-form: blocked
await raw('GET http://a/../../../package.json HTTP/1.1');   // absolute-form: THE probe
```

Vary the traversal depth (`../`, `../../`, `../../../`) since the number of
`..` segments needed depends on how deep the server root sits relative to
interesting siblings.

### Step 3: Confirm reachability with a canary, not a source-code inference

Place a uniquely-named file just outside the served root, request it via the
absolute-form probe, assert the response body contains the canary content
(not merely a 200 status — some misconfigurations 200 an empty or generic
page), then delete the canary and re-verify the audited tree's identity hash
is restored exactly.

```bash
echo "CANARY-$(date +%s)" > ../outside-marker.txt
# probe, assert leak, then:
rm ../outside-marker.txt
```

### Step 4: Bound the severity by the ACTUAL escape region, not by "traversal exists"

Once confirmed reachable, determine what the prefix weakness actually exposes
— it is not automatically full filesystem read. In this case the reachable set
was exactly `{siblings of OUT whose name is itself a prefix match, i.e.
OUT + more characters}` — a narrow, name-collision-dependent region, not
arbitrary `../../../etc/passwd`-style traversal (double-`..` origin-form paths
were still normalized away). Enumerate what actually sits in that region
before grading impact.

## Verification

### Command

```bash
node attack-static.mjs
```

### Expected Output

```
ESCAPE  absolute-form escape       HTTP/1.1 200 OK
  ok    origin-form ..             HTTP/1.1 404 Not Found
  ok    encoded ..                 HTTP/1.1 404 Not Found
  ok    control: real asset        HTTP/1.1 200 OK
```

(A confirmed-vulnerable server shows the split above: origin-form and encoded
variants blocked, absolute-form admitted, the positive control still serving
real content — proving the probe methodology itself works.)

### Checklist

- [ ] Tested with both origin-form (`fetch()`/browser-equivalent) AND
      raw-socket absolute-form/malformed request lines
- [ ] A canary file outside the root was actually served, not inferred from
      source reading
- [ ] Canary removed and the audited subject's identity hash re-verified
      unchanged after the probe
- [ ] Escape region enumerated (what actually sits in the reachable path
      space) before assigning severity — "traversal exists" and "arbitrary
      file read" are different findings

## Anti-Patterns

### Don't: grade reachability from `path.normalize()` behavior alone

`normalize()` is correct and sufficient for slash-anchored input. The finding
lives in what happens when the input is NOT slash-anchored, which only a raw
client can produce.

### Don't: accept a 404 count from `fetch()`-based probes as proof of containment

```js
// INSUFFICIENT — every one of these constructs origin-form under the hood
await fetch(`${base}/../package.json`);
await fetch(`${base}/%2e%2e/package.json`);
```

A clean sweep of 404s here proves the origin-form path is safe. It says
nothing about absolute-form, and reporting "0 escapes" from this alone is a
false negative.

## Related Memory

### Related Skills

- `a-passing-regression-test-proves-nothing-alone` — same discipline of
  requiring an executed, discriminating probe rather than a plausible-looking
  clean result before trusting a security property
- `capability-definition-is-not-use` — same shape of error (a syntactic-level
  check — grep for an API name / string-prefix match — that looks sufficient
  until the actual call path is traced)

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-15 | Initial extraction |

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: auditing-security
  phase: /audit-sprint (re-audit)
  session: sprint-6 audit-remediation re-audit, L-5 static-server re-grade
```
