#!/usr/bin/env bash
# Gate 10 — requirement traceability (Sprint 8 Task 8.2).
#
# Three failures this gate exists to catch, all of which a hand-maintained table
# hides indefinitely:
#
#   1. a register row with NO evidence at all;
#   2. a row whose evidence NAMES A FILE THAT DOES NOT EXIST — the weaker of the
#      two false-coverage modes, but it still reads as coverage;
#   3. a row whose evidence names a file that EXISTS AND DOES NOT CARRY THE ROW —
#      the stronger mode, and the one that actually occurred (review H-1/M-1:
#      seven review-only rows cited whole-sprint feedback files that never
#      mentioned them). Check 2 passes such a row; only check 3 catches it.
#
# It deliberately does NOT require every row to be an automated test. The
# accepted plan assigns each row a method (sprint.md §D, prd.md:L669); forcing a
# review-only row into a synthetic test would launder the assignment, not honour
# it. What is required is named, existing, reviewable evidence.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../provenance/census.sh"
cd "$REPO_ROOT"

MATRIX="grimoires/loa/a2a/sprint-8/traceability.json"
GEN="tools/traceability/build-matrix.mjs"

echo "== regenerate from the tree =="
if node "$GEN" >/dev/null 2>&1; then
  pass "matrix regenerated from the repository tree"
else
  fail "generator failed: node $GEN"
fi

[[ -f "$MATRIX" ]] || { fail "missing $MATRIX"; finish; }

echo
echo "== register coverage =="
inv_cov=$(jq -r '.totals.inv_covered' "$MATRIX" | tr -d '\r')
fb_cov=$(jq -r '.totals.fb_covered' "$MATRIX" | tr -d '\r')
uncovered=$(jq -r '.totals.uncovered | join(", ")' "$MATRIX" | tr -d '\r')

if [[ "$inv_cov" == "37" ]]; then
  pass "INV-1…37: 37/37 rows carry named evidence"
else
  fail "INV coverage is $inv_cov/37"
fi
if [[ "$fb_cov" == "18" ]]; then
  pass "FB-1…18: 18/18 rows carry named evidence"
else
  fail "FB coverage is $fb_cov/18"
fi
[[ -n "$uncovered" ]] && fail "rows with no evidence: $uncovered"

echo
echo "== every named evidence artifact exists =="
missing=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if [[ ! -e "$f" ]]; then
    fail "evidence names a path that does not exist: $f"
    missing=$((missing + 1))
  fi
  # `tr -d '\r'`: jq emits CRLF on Windows shells, and a trailing CR makes every
  # path fail the existence test. Same guard verify-pins.sh already uses.
done < <(jq -r '[.rows[].evidence[].file] | unique | .[]' "$MATRIX" | tr -d '\r')
if (( missing == 0 )); then
  n=$(jq -r '[.rows[].evidence[].file] | unique | length' "$MATRIX")
  pass "$n distinct evidence artifact(s) all present on disk"
fi

echo
echo "== prose evidence carries the row it is cited for =="
#
# Scope: `review-checklist` and `documented-analysis` rows only. Those are the
# kinds whose evidence is a human-authored document naming its subject, so
# containment of the row id is a meaningful, deterministic floor. Test and
# implementation rows are excluded deliberately — their linkage is already
# established structurally (the `// carries:` convention and inline ids that the
# generator SCANS FOR, so containment there is true by construction), and a
# source file legitimately implements a requirement without naming it.
#
# The check is identifier containment at WORD BOUNDARIES, not prose matching.
# The boundaries are load-bearing rather than cosmetic: a bare substring test for
# `FB-1` is satisfied by `FB-11`, `FB-12`, or `FB-18`, so it would re-admit the
# exact class of false coverage this check exists to reject.
#
# What this does NOT claim: that the artifact ARGUES the row successfully. That
# is a reviewer's judgement and no gate can make it. This establishes only that
# the citation points at a document that is about the row — which is precisely
# the gap between "the path resolves" and "the evidence is for this requirement".
wrong=0
checked=0
while IFS=$'\t' read -r id kind file; do
  [[ -z "$id" ]] && continue
  checked=$((checked + 1))
  if ! grep -Eq "\b${id}\b" "$file" 2>/dev/null; then
    fail "$id is cited to $file ($kind), which never mentions $id"
    wrong=$((wrong + 1))
  fi
  # `tr -d '\r'` on the jq stream: same CRLF guard as the existence check above.
done < <(jq -r '.rows[] | .id as $i | .evidence[]
                | select(.kind == "review-checklist" or .kind == "documented-analysis")
                | [$i, .kind, .file] | @tsv' "$MATRIX" | tr -d '\r')
if (( wrong == 0 )); then
  pass "$checked review/documented-analysis citation(s) each carry their row id"
fi

echo
echo "== the matrix in the tree is the matrix the generator produces =="
if git diff --quiet -- "$MATRIX" grimoires/loa/a2a/sprint-8/traceability-matrix.md 2>/dev/null; then
  pass "committed matrix is identical to a fresh generation (no stale hand-edit)"
else
  # Untracked (first generation) is not drift; a tracked-and-different file is.
  if git ls-files --error-unmatch "$MATRIX" >/dev/null 2>&1; then
    fail "the committed matrix differs from a fresh generation — regenerate, do not hand-edit"
  else
    pass "matrix not yet tracked (first generation); nothing to drift from"
  fi
fi

finish
