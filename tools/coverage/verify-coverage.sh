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

# --- diagnostics -------------------------------------------------------------
#
# The two load-bearing commands below used to run under `>/dev/null 2>&1`. That
# is what made this gate undiagnosable: when it failed on hosted CI it emitted
# one line — "forge coverage failed — rerun without >/dev/null" — and nothing
# else, so establishing WHY required reproducing the runner on a developer's
# machine. A fence that fails without evidence is only half a fence.
#
# Output is therefore captured rather than discarded. A successful run still
# prints a single line, so a green log stays readable; a failing run prints the
# exit status and the TAIL of the real output. The tail rather than the whole
# log because a compiler or test failure reports at the end, and an unbounded
# dump of an instrumented build would bury it. An empty tail with a non-zero
# status is itself evidence — that is what a killed process looks like.
DIAG_TAIL=200
DIAG_DIR="$(mktemp -d)"
# `:?` rather than a bare expansion: if mktemp ever fails, DIAG_DIR is empty and
# an unguarded recursive delete of "" is not a cleanup, it is a loaded gun.
trap 'rm -rf "${DIAG_DIR:?}"' EXIT
DIAG_LOG=""
DIAG_STATUS=0

# run_logged <slug> <cmd...> — run with stdout+stderr captured, status preserved.
run_logged() {
  local slug="$1"; shift
  DIAG_LOG="$DIAG_DIR/$slug.log"
  "$@" >"$DIAG_LOG" 2>&1
  DIAG_STATUS=$?
  return "$DIAG_STATUS"
}

# diag <what> — report what the last run_logged actually did. Failure path only.
diag() {
  local total shown
  total=$(wc -l < "$DIAG_LOG" | tr -d ' ')
  shown=$(( total > DIAG_TAIL ? DIAG_TAIL : total ))
  printf '      ---- %s: exit %d, last %d of %d output line(s) ----\n' \
    "$1" "$DIAG_STATUS" "$shown" "$total" >&2
  tail -n "$DIAG_TAIL" "$DIAG_LOG" | sed 's/^/      | /' >&2
  printf '      ---- end %s ----\n' "$1" >&2
}

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

# Recorded because it is not visible from the measurement itself and it changes
# what this step costs: [profile.ci] raises fuzz to 10,000 runs and invariants to
# 256x64, so the same command is a very different workload locally and on CI.
info "FOUNDRY_PROFILE=${FOUNDRY_PROFILE:-default}"

# The artifact-reading suites read `out/<C>.sol/<C>.json` by hardcoded path, so a
# NORMAL build has to exist before the instrumented run — otherwise they fail on
# a missing file. Locally `out/` is usually already there; on a fresh CI checkout
# it is not, which is exactly the case that would have failed silently.
if run_logged forge-build forge build; then
  pass "normal build present in out/ for the artifact-reading suites"
else
  fail "forge build failed — the artifact-reading suites have nothing to read"
  diag "forge build"
  finish
fi

# BOTH compilation units, and the second one is not optional. `foundry.toml`
# grants the suites read access to `./out` AND `./out-v3core`, and they use it:
# the genesis, POL, event-schema and init-code-hash suites read
# `out-v3core/VuxPoolDeployer.sol/...` and `out-v3core/UniswapV3Pool.sol/...`
# through `vm.readFile`. That unit is =0.7.6 under a DIFFERENT profile, so the
# build above cannot produce it — only `FOUNDRY_PROFILE=v3core` can, which is
# why run-all.sh builds both before running any gate.
#
# This job never runs run-all.sh, so on a fresh CI checkout `out-v3core/` did
# not exist and 52 tests died in `vm.readFile` with "No such file or directory"
# — while locally the directory is always left behind by an earlier run-all.sh
# and the gate measured 98.19%. Same fresh-checkout assumption that broke the
# static-analysis gate on the same day, in the other compilation unit.
if run_logged forge-build-v3core env FOUNDRY_PROFILE=v3core forge build; then
  pass "=0.7.6 vendored unit present in out-v3core/ for the artifact-reading suites"
else
  fail "FOUNDRY_PROFILE=v3core forge build failed — the suites reading out-v3core/ have nothing to read"
  diag "forge build (=0.7.6 unit)"
  finish
fi

if run_logged forge-coverage env FOUNDRY_OUT="$COV_OUT" forge coverage --ir-minimum \
     --report lcov --no-match-coverage '(test|script|vendor)'; then
  pass "forge coverage completed (instrumented build isolated in $COV_OUT/)"
else
  fail "forge coverage failed"
  diag "forge coverage --ir-minimum"
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
