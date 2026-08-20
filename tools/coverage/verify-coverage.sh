#!/usr/bin/env bash
# Gate 12 — line coverage on the core contracts (Sprint 8 Task 8.3).
#
# Accepted requirement: "forge build + test + coverage (line >=90% on core
# contracts; invariant suite green)" — sdd.md:L871.
#
# TWO thresholds, deliberately, because an aggregate alone is gameable: a large
# well-covered contract can carry a small neglected one over the line. The gate
# therefore requires BOTH the total AND every individual core file to clear 90%.
#
# `--ir-minimum` is required, not preferred: `forge coverage` disables the
# optimizer and `viaIR` for accurate source mapping, and the =0.8.28 unit does
# not compile that way ("stack too deep" in StrategicTreasury). `--ir-minimum`
# re-enables viaIR at minimum optimization, which is the documented resolution.
#
# The core surface is `src/**` excluding `src/interfaces/**` (no executable
# lines) and `src/v3core/**` (the =0.7.6 vendored-unit companion, built under a
# different profile). That set is DERIVED here rather than hardcoded, so a new
# core contract is covered by this gate the day it lands.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../provenance/census.sh"
set +e
cd "$REPO_ROOT"

THRESHOLD=90
LCOV="lcov.info"

echo "== core surface =="
mapfile -t CORE < <(git ls-files 'src/*.sol' | grep -v '^src/interfaces/' | grep -v '^src/v3core/' | sort)
if (( ${#CORE[@]} == 0 )); then
  fail "no core contracts found under src/ — the derivation is wrong"
  finish
fi
info "${#CORE[@]} core contract(s): ${CORE[*]}"

echo
echo "== measure =="
# Two things this step does that are not obvious, and both are load-bearing:
#
# 1. `--ir-minimum` is required, not preferred. `forge coverage` disables the
#    optimizer and viaIR for accurate source mapping, and the =0.8.28 unit does
#    not compile that way ("stack too deep" in StrategicTreasury).
#
# 2. `FOUNDRY_OUT` redirects the instrumented build away from `out/`. Many suites
#    in this repository read COMPILED ARTIFACTS back through `vm.readFile` +
#    `vm.parseJsonKeys` (the surface, census, event-schema and init-code-hash
#    tests). Coverage's build settings change the artifact JSON, so sharing `out/`
#    made 39 of those tests fail with `key ".methodIdentifiers" must return
#    exactly one JSON object` — a failure with nothing to do with coverage, and
#    order-dependent on whatever had built `out/` last. Isolating the
#    instrumented build lets those tests keep reading the real artifacts.
COV_OUT="out-coverage"

# The artifact-reading suites read `out/<C>.sol/<C>.json` by hardcoded path, so a
# NORMAL build has to exist before the instrumented run — otherwise they fail on
# a missing file. Locally `out/` is usually already there; on a fresh CI checkout
# it is not, which is exactly the case that would have failed silently.
if forge build >/dev/null 2>&1; then
  pass "normal build present in out/ for the artifact-reading suites"
else
  fail "forge build failed — the artifact-reading suites have nothing to read"
  finish
fi

if FOUNDRY_OUT="$COV_OUT" forge coverage --ir-minimum --report lcov \
     --no-match-coverage '(test|script|vendor)' >/dev/null 2>&1; then
  pass "forge coverage completed (instrumented build isolated in $COV_OUT/)"
else
  fail "forge coverage failed — rerun without >/dev/null to see the compiler output"
  finish
fi
[[ -s "$LCOV" ]] || { fail "no $LCOV produced"; finish; }

echo
echo "== per-file line coverage (floor ${THRESHOLD}%) =="
# lcov: DA:<line>,<hitcount> per instrumented line. A file's line coverage is
# (lines with hitcount > 0) / (instrumented lines).
total_found=0
total_hit=0
for f in "${CORE[@]}"; do
  block="$(awk -v want="$f" '
    $0 == "SF:" want { inblock = 1; next }
    inblock && /^end_of_record/ { inblock = 0 }
    inblock && /^DA:/ { print }
  ' "$LCOV")"

  if [[ -z "$block" ]]; then
    fail "$f has no coverage record in $LCOV — it was not instrumented"
    continue
  fi

  found=$(printf '%s\n' "$block" | wc -l | tr -d ' ')
  hit=$(printf '%s\n' "$block" | awk -F, '$2 != 0' | wc -l | tr -d ' ')
  total_found=$((total_found + found))
  total_hit=$((total_hit + hit))

  pct10=$(( hit * 1000 / found ))          # tenths of a percent, integer math
  if (( pct10 >= THRESHOLD * 10 )); then
    pass "$(printf '%-30s %3d.%d%%  (%d/%d lines)' "$f" $((pct10 / 10)) $((pct10 % 10)) "$hit" "$found")"
  else
    fail "$(printf '%-30s %3d.%d%%  (%d/%d lines) — below the %d%% floor' "$f" $((pct10 / 10)) $((pct10 % 10)) "$hit" "$found" "$THRESHOLD")"
  fi
done

echo
echo "== total =="
if (( total_found > 0 )); then
  tpct10=$(( total_hit * 1000 / total_found ))
  if (( tpct10 >= THRESHOLD * 10 )); then
    pass "$(printf 'core total %d.%d%%  (%d/%d lines) — floor is %d%%' $((tpct10 / 10)) $((tpct10 % 10)) "$total_hit" "$total_found" "$THRESHOLD")"
  else
    fail "$(printf 'core total %d.%d%%  (%d/%d lines) — below the %d%% floor' $((tpct10 / 10)) $((tpct10 % 10)) "$total_hit" "$total_found" "$THRESHOLD")"
  fi
fi

finish
