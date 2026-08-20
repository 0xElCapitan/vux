---
name: gitignore-unanchored-tool-dir-collision
description: |
  A .gitignore entry written without a leading slash (e.g. `coverage/`)
  matches a directory of that name AT ANY DEPTH in the repository, not just at
  the root. If a new tool/gate directory happens to share that name deeper in
  the tree (e.g. `tools/coverage/`), it is silently untracked by git even
  after being created and populated -- it will build, test, and pass locally
  forever, then fail CI the first time a workflow tries to reference it by
  path, because it was never committed. Apply this whenever adding a new
  top-level-looking directory under an existing repo that already has
  generic-sounding .gitignore entries (build/, dist/, out/, cache/,
  coverage/, logs/, etc.).
loa-agent: implementing-tasks
extracted-from: sprint-8 (VUX v1, Task 8.3)
extraction-date: 2026-08-19
version: 1.0.0
tags:
  - git
  - gitignore
  - ci-gates
  - tooling
  - silent-failure
---

## Problem

A new script/tool is added at `tools/<name>/<script>`, where `<name>` happens
to match an existing `.gitignore` pattern that was intended for a build
artifact directory elsewhere in the tree (commonly `coverage/`, `dist/`,
`build/`, `out/`, `cache/`, `tmp/`). The new file is written successfully,
tested successfully, and used successfully in the current working tree --
`git status` never mentions it, which looks like "nothing to commit" rather
than "this file is being hidden from you". It is never actually committed,
and the first thing that discovers this is CI running on a fresh checkout,
failing with a missing-file error that has nothing obviously to do with
`.gitignore`.

## Trigger Conditions

### Symptoms

- A newly created file/directory under `tools/`, `scripts/`, `src/`, or
  similar does not appear in `git status --porcelain` or `git add -A` output,
  even though it was just written to disk and is not inside any obviously
  ignored directory like `node_modules/` or `.git/`.
- Sibling directories created in the same session (with different names) DO
  show up as untracked (`??`) in `git status`, highlighting that this one
  specific directory is the odd one out.
- CI (or a fresh clone) fails with "file not found" / "no such file or
  directory" for a path that exists and works perfectly on the machine that
  created it.

### Error Messages

None locally -- the symptom is an ABSENCE (the file never appears as
untracked). In CI: a shell "No such file or directory" or a script-not-found
error referencing the exact path of the new tool.

### Context

| Context | Value |
|---|---|
| Technology Stack | Git, any repository with pre-existing `.gitignore` patterns for build output |
| Environment | Any |
| Timing | The moment a new directory is created under any parent whose leaf name collides with an unanchored ignore pattern |
| Prerequisites | An existing `.gitignore` entry written WITHOUT a leading slash for a common/generic directory name |

## Root Cause

Git's `.gitignore` pattern matching treats a pattern with no slash (or only a
trailing slash, like `coverage/`) as matching that name at ANY depth in the
tree -- equivalent to `**/coverage/`. Anchoring to the repository root
requires an explicit leading slash (`/coverage/`). A `.gitignore` written
early in a project's life to ignore a root-level build-output directory
(`coverage/` for a JS test-coverage report, for example) will, without anyone
intending it, also match and hide `tools/coverage/`, `packages/api/coverage/`,
or any other directory anywhere in the tree that happens to share that exact
leaf name -- including directories that hold real, hand-authored source that
should absolutely be tracked.

## Solution

### Step 1: When a new directory silently fails to appear as untracked, check it explicitly

```bash
git check-ignore -v path/to/new/dir/file.sh
```

Output shows the exact `.gitignore` line and file responsible, for example:
```
.gitignore:19:coverage/    tools/coverage/verify-coverage.sh
```

### Step 2: Anchor the original pattern to the location it was actually meant for

```gitignore
# BAD: matches at any depth, including tools/coverage/
coverage/

# GOOD: matches only the repository-root coverage/ directory
/coverage/
```

Anchoring never loosens anything -- it only removes the accidental
any-depth matching. If the intent really was "ignore every directory named
`coverage` anywhere", state that explicitly and knowingly (`**/coverage/` is
equivalent to the original unanchored form, so at minimum leave a comment
explaining that the broad match is deliberate) rather than leaving it
ambiguous.

### Step 3: Sweep the whole repo for the same class of collision before committing

```bash
for d in $(git status --porcelain --ignored=matching | awk '$1=="!!"{print $2}' | xargs -n1 dirname | sort -u); do
  git check-ignore -v "$d" 2>/dev/null
done
```

Or more simply, for a known new tool root: `git check-ignore -v
tools/*/` and eyeball anything unexpected.

## Verification

### Command

```bash
git check-ignore -v tools/coverage/verify-coverage.sh && echo "STILL IGNORED (bad)" || echo "trackable (good)"
```

### Expected Output

```
trackable (good)
```

And a confirmation that the ORIGINAL intended target is still ignored:

```bash
mkdir -p coverage && touch coverage/probe.tmp
git check-ignore -v coverage/probe.tmp   # should still report the anchored pattern
rm -rf coverage
```

### Checklist

- [ ] Every new tool/source directory is confirmed trackable with
      `git check-ignore -v <path>` (expect no output / nonzero exit) before
      assuming it will be committed.
- [ ] The `.gitignore` anchoring change is verified not to have un-ignored the
      originally intended build-output directory at its real location.
- [ ] `git status --porcelain` shows the new files as `??` (untracked, ready
      to add) rather than being silently absent.

## Anti-Patterns

### Do not trust "git status shows nothing to commit" as proof of "nothing new"

Absence of a file in `git status` output is ambiguous between "there is
nothing new here" and "something new here is being hidden". When in doubt
about a specific new path, check it explicitly rather than reading a clean
`git status` as reassuring.

### Do not write generic `.gitignore` entries without considering repo-wide collision risk

Short, common directory names (`coverage`, `dist`, `build`, `out`, `tmp`,
`cache`, `logs`, `bin`) are exactly the names most likely to be reused
elsewhere in a growing repository for legitimate, trackable purposes. Anchor
these patterns to their actual location from the start, or use a more
specific name for the ignored directory in the first place.

## Related Memory

### NOTES.md References

- `grimoires/loa/NOTES.md` Decision Log, 2026-08-19, `[implement sprint-8, task
  8.3]` -- the concrete instance: a bare `coverage/` line swallowed
  `tools/coverage/verify-coverage.sh`, the coverage gate itself, which would
  have passed locally forever and failed CI on "file not found".

### Related Skills

- `forge-gate-build-output-isolation` -- another silent-CI-failure class
  discovered while hardening the same set of gates.

## Changelog

| Version | Date | Changes |
|---|---|---|
| 1.0.0 | 2026-08-19 | Initial extraction |

## Metadata (Auto-Generated)

```yaml
quality_gates:
  discovery_depth: true
  reusability: true
  trigger_clarity: true
  verification: true
extraction_source:
  agent: implementing-tasks
  phase: /implement sprint-8
  session: 84ce6375-f0f4-4712-b2e9-21c25ba3ec54
```
