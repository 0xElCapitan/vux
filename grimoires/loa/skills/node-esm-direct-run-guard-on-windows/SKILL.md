---
name: node-esm-direct-run-guard-on-windows
description: |
  The common Node ESM idiom for "only run main() if this file was invoked
  directly, not imported" — comparing `import.meta.url` against a
  string-spliced `file://${process.argv[1]}` — silently never matches on
  Windows, so the script produces no output and exits 0 with no error at all.
  Windows paths use backslashes and Node's own `import.meta.url` for a file
  produces a THREE-slash `file:///C:/...` URL, while naive string splicing
  produces a two-slash, backslash-containing string that never equals it. Use
  `url.pathToFileURL(process.argv[1]).href` instead, which handles the
  platform-specific URL encoding correctly. Apply whenever writing a
  cross-platform Node `.mjs`/ESM CLI script with a direct-invocation guard, or
  debugging a Node script that runs with zero output/errors when executed
  directly but whose exported functions work fine when imported.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-7 /implement (tools/offchain/encode-sqrt-p0.mjs)
extraction-date: 2026-08-17
version: 1.0.0
tags:
  - node
  - esm
  - windows
  - cross-platform
  - cli
---

## Problem

A Node ESM script defines exported functions plus a `main()` gated by a
"run only if invoked directly" check, so it's usable both as a CLI and as an
importable module. Run directly (`node script.mjs --flag value`), it produces
no output and exits 0 — no error, no stack trace, nothing. The exported
functions work correctly when imported and called from another script.

## Trigger Conditions

### Symptoms

- `node script.mjs <args>` exits cleanly with zero output
- The same functions, `import`ed into another file and called explicitly, work correctly
- Running on Windows (via Git Bash, PowerShell, or cmd.exe as the parent shell)
- The script uses the `import.meta.url === 'file://' + process.argv[1]` guard pattern (or an equivalent manual string comparison)

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Node.js ESM (`.mjs`, or `"type": "module"`) |
| Environment | Windows, any shell (the OS path convention is what matters, not the shell) |
| Timing | First run of a newly-written CLI-capable ESM script on Windows |
| Prerequisites | none |

## Root Cause

`import.meta.url` for a locally executed file is a properly-encoded `file://` URL — on Windows this is `file:///C:/Users/.../script.mjs` (three slashes: two for the scheme, one leading the drive letter). `process.argv[1]` on Windows is a native OS path like `C:\Users\...\script.mjs` (backslashes, no `file://` prefix at all). A naive template-string splice — `` `file://${process.argv[1]}` `` — produces `file://C:\Users\...\script.mjs`: two slashes, raw backslashes, no proper percent-encoding. That string can never equal the real `import.meta.url`, so the guard's condition is always false, `main()` never runs, and because the failure is a silently-false comparison rather than a thrown error, nothing indicates why.

## Solution

### Step 1: Replace manual string construction with `pathToFileURL`

```javascript
// WRONG — silently never matches on Windows
if (import.meta.url === `file://${process.argv[1].replace(/\/g, '/')}`) main();
// (even the backslash-replace patch above is still wrong: it fixes the
// separator but not the missing leading slash / percent-encoding)

// RIGHT — handles platform path-to-URL conversion correctly on every OS
import { pathToFileURL } from 'node:url';
if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
```

### Step 2: Verify by actually invoking the script directly, not just importing it in a test

A unit test that only imports and calls the exported functions will never exercise this guard at all — it has to be run as `node script.mjs` from a shell to prove the direct-invocation path fires.

## Verification

### Command

```bash
node tools/yourscript.mjs --your-flag value
```

### Expected Output

The script's actual output (not silence), matching what calling the exported function directly would produce.

### Checklist

- [ ] Direct-invocation guard uses `pathToFileURL(process.argv[1]).href`, not manual `file://` string construction
- [ ] Verified by running the script directly from a shell, not only by importing and calling its exports
- [ ] Verified specifically on Windows if the project targets it (this bug is invisible on POSIX systems, where the naive splice happens to work)

## Anti-Patterns

### Distinguish from: "Node's ESM loader needs an explicit file:// URL for absolute Windows paths"

A prior retrospective (NOTES.md, 2026-08-15) dropped that candidate for shallow
discovery depth: Node's loader THROWS `ERR_UNSUPPORTED_ESM_URL_SCHEME` on a bare
Windows path passed to `import()`, which is a one-line fix once you read the
error. This skill is a different, deeper trap: the broken guard produces NO
error at all — the script exits 0 with silent empty output, so there is
nothing to look up. Diagnosing it requires noticing the absence of output and
working out why a structurally-plausible string comparison is false.

### Don't: patch only the backslash separator and assume that's sufficient

```javascript
// STILL WRONG — fixes one symptom, not the actual mismatch
`file://${process.argv[1].replace(/\/g, '/')}`
```

`import.meta.url` on Windows is `file:///C:/...` (three slashes, drive letter directly after them); this patched string is still `file://C:/...` (two slashes). They still never match. Use the built-in conversion function rather than trying to hand-reconstruct the URL encoding rules.
