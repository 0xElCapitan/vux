---
name: solidity-string-literals-must-be-ascii
description: |
  Solidity rejects non-ASCII characters inside a `"..."` string literal
  (Error 8936: "Invalid character in string"), but the same characters are
  perfectly legal in `///` NatSpec comments and `//` line comments right next
  to those literals. When prose comments and revert-message strings are drafted
  together — especially with an em dash (—), en dash (–), or curly
  quotes (' ' " ") used for readability — the dash/quote habit bleeds from a
  comment into a nearby `require`/`revert`/`assertEq` string and the file stops
  compiling. Fix by rewriting ONLY the characters inside quoted string literals
  to their ASCII equivalents (`-`, `'`), leaving comments untouched — a blanket
  find-replace over the whole file will also mangle the prose. Apply whenever a
  Solidity compile fails with error 8936, or before it happens: when authoring
  Solidity files with typographically-styled comments, sweep string literals for
  non-ASCII before first compile.
loa-agent: implementing-tasks
extracted-from: cycle-002 sprint-7 /implement (genesis suites, GenesisDeployer.sol)
extraction-date: 2026-08-17
version: 1.0.0
tags:
  - solidity
  - compilation
  - unicode
  - foundry
  - tooling
---

## Problem

A Solidity file with rich NatSpec/comment prose (em dashes, curly quotes) fails to compile with an unhelpful-looking error pointing at a specific line, even though that line "looks like a normal string."

## Trigger Conditions

### Symptoms

- `forge build` fails on a file that has both prose comments and revert/assert message strings
- The failing line is a `require(..., "...")`, `revert Error("...")`, or `assertEq(..., "...")` call
- The string, printed in a terminal or editor, looks completely ordinary

### Error Messages

```
Error (8936): Invalid character in string. If you are trying to use Unicode
characters, use a unicode"..." string literal.
```

### Context

| Context | Value |
|---------|-------|
| Technology Stack | Solidity (any version), Foundry |
| Environment | Any — deterministic compiler behavior |
| Timing | First compile after drafting comment-heavy Solidity, or after copy-pasting prose into a test assertion string |
| Prerequisites | none |

## Root Cause

Solidity's grammar allows arbitrary UTF-8 in comments (`//`, `///`, `/* */`) but restricts ordinary `"..."` string literals to a printable-ASCII-plus-escapes subset — genuine Unicode content requires the explicit `unicode"..."` prefix. An em dash or curly quote typed while writing prose (very natural when explaining *why* a check exists) silently carries over when a similar sentence becomes a revert message, and the compiler only complains about the string, never about the comment two lines above using the identical character.

## Solution

### Step 1: Locate every non-ASCII byte inside a double-quoted literal, not just in the file generally

A whole-file regex replace is wrong — it will rewrite the same em dash inside a comment, degrading prose that was fine.

```bash
node -e '
const fs = require("fs");
for (const p of process.argv.slice(2)) {
  const out = fs.readFileSync(p, "utf8").split("\n").map(line => {
    if (/^\s*(\/\/|\*|\/\*)/.test(line)) return line;               // leave comment lines alone
    return line.replace(/"([^"\n]*)"/g, (m, inner) => {
      const fixed = inner
        .replace(/[\u2014\u2013]/g, "-")     // em/en dash -> hyphen
        .replace(/[\u2018\u2019]/g, "'")     // curly single quotes -> apostrophe
        .replace(/[\u201C\u201D]/g, "'");    // curly double quotes -> apostrophe
      return `"${fixed}"`;
    });
  }).join("\n");
  fs.writeFileSync(p, out);
}
' path/to/File.sol
```

### Step 2: Recompile and confirm the specific line clears

```bash
forge build 2>&1 | grep -E "^Error|error\["
```

If another 8936 appears elsewhere, the sweep only ran on part of the tree — re-run over the full changed-file set.

## Verification

### Command

```bash
forge build
```

### Expected Output

```
Compiler run successful
```

with zero `Error (8936)` occurrences.

### Checklist

- [ ] Only characters *inside* `"..."` literals were changed
- [ ] Comment-line prose (em dashes, curly quotes) is untouched
- [ ] `forge build` compiles clean afterward
- [ ] No other file in the same edit batch reintroduced the same character

## Anti-Patterns

### Don't: sed/replace across the whole file indiscriminately

```bash
# BAD — degrades every comment's typography along with fixing the one bad string
sed -i 's/—/-/g' File.sol
```

This "fixes" the compile error but silently rewrites prose the author deliberately styled, in every comment in the file, not just the one broken literal.

### Don't: manually hunt for the offending character by eye

Em dashes and hyphens are visually near-identical in most editors/terminals at normal zoom. Use the compiler's own line number plus a scripted scan — guessing wastes cycles re-triggering the same error one string at a time.
