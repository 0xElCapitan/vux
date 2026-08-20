#!/usr/bin/env bash
# Gate 9 — static analysis behind its accepted provenance pin (PROV-9, Sprint 8 Task 8.1).
#
# Authority: docs/authority/vux-v1-static-analysis-provenance-refreeze-2026-08.md
#            (STATIC_ANALYSIS_PROVENANCE_REFREEZE_CURRENT_ACCEPTED, operator acceptance 2026-08-19)
#            + docs/authority/vux-v1-source-registry-static-analysis-refreeze-2026-08.json
#
# What this gate mechanizes, beyond "run the scanner":
#
#   D-S4  the DISTRIBUTION is `slither-analyzer`, never the unrelated PyPI package
#         `slither` (a PyGame/Scratch teaching library). The installed console
#         script is called `slither` either way, which is what makes the
#         confusion plausible and this assertion worth having.
#   D-S2  no RPC/provider endpoint is configured. The accepted disposition of
#         GHSA-5hr4-253g-cpx2 (web3 CCIP-Read SSRF, present in the environment
#         and unavoidable inside slither 0.10.x) rests on the invocation being
#         local-only. If a future edit quietly adds an endpoint, the disposition
#         lapses and operator review is required — so it fails here instead.
#   §7.2  slither NEVER invokes a compiler. `forge build --build-info` runs under
#         the accepted Foundry/solc pins and slither reads the artifacts, so the
#         analyzed AST is provably the accepted build's AST.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
# census.sh sets `-e`. This gate must NOT abort on the first non-zero command:
# nearly every check here is a probe whose failure is the finding (`pip show` on
# a package that is not installed, a `slither` run with findings, a `forge build`
# that fails). Under `-e` the script died mid-run with no diagnostic at all —
# the worst possible behaviour for a fence. `fail()` + `finish()` already give
# fail-closed semantics, and they report WHICH check failed.
set +e
cd "$REPO_ROOT"

SA_DIR="tools/static-analysis"
REQ="$SA_DIR/requirements.txt"
BASELINE="$SA_DIR/triage-baseline.json"
CONFIG="$SA_DIR/slither.config.json"
REPORT="out/slither-report.json"

ACCEPTED_SLITHER_VERSION="0.10.4"
ACCEPTED_ADAPTER_VERSION="0.3.7"

PY="${PYTHON:-python3}"

# --- the accepted authority is byte-identical -------------------------------
echo "== static-analysis authority =="
require_authority "$STATIC_ANALYSIS_MD"   "$STATIC_ANALYSIS_MD_SHA256"
require_authority "$STATIC_ANALYSIS_JSON" "$STATIC_ANALYSIS_JSON_SHA256"
(( FAILURES == 0 )) && pass "static-analysis refreeze authority byte-identical to the accepted values"

for f in "$REQ" "$BASELINE" "$CONFIG"; do
  [[ -f "$f" ]] || fail "missing $f"
done

# --- interpreter: asserted, never provisioned -------------------------------
#
# The repository's accepted posture (.github/workflows/provenance.yml, Node
# step): "Asserted rather than assumed: a runner image rollback must not
# silently change what these gates mean." No setup-python action is added.
#
# The floor is TIGHTER than the refreeze §7.3 proposal of ">=3.10, !=3.12.0",
# and the closure derivation is why: `web3<7` (forced by slither 0.10.4) forces
# `lru-dict<1.3.0`, and lru-dict 1.2.0 publishes wheels only through cp311. On
# 3.12+ pip must build it from sdist, which `--require-hashes` makes fragile.
# 3.10 and 3.11 are wheel-complete for the whole closure and both are present in
# the ubuntu-latest tool cache.
#
# Discovered by trial, not asserted by name. `command -v python3` succeeding
# proves nothing on Windows, where it resolves to the Microsoft Store stub that
# is not an interpreter at all — trusting the name made this gate die silently
# mid-run. Each candidate must actually EXECUTE the range check to qualify.
echo
echo "== interpreter =="
py_ok=""
for cand in ${PYTHON:+"$PYTHON"} python3.11 python3.10 python3 python; do
  command -v "$cand" >/dev/null 2>&1 || continue
  if "$cand" -c 'import sys;sys.exit(0 if (3,10) <= sys.version_info[:2] < (3,12) else 1)' >/dev/null 2>&1; then
    py_ok="$cand"; break
  fi
done
if [[ -n "$py_ok" ]]; then
  PY="$py_ok"
  pass "python $("$PY" -c 'import sys;print("%d.%d.%d"%sys.version_info[:3])' 2>/dev/null) ($PY) is inside the closure's wheel-complete range [3.10, 3.12)"
else
  fail "no interpreter in [3.10, 3.12) found — set PYTHON=<path>. The accepted closure is wheel-complete only there: web3<7 (forced by slither 0.10.4) forces lru-dict<1.3.0, and lru-dict 1.2.0 publishes no cp312+ wheel."
fi

# --- D-S4: the distribution, not just the command ---------------------------
echo
echo "== analyzer identity (D-S4) =="
if [[ -n "$py_ok" ]]; then
  sa_ver="$("$PY" -m pip show slither-analyzer 2>/dev/null | awk -F': ' '/^Version:/{print $2}' | tr -d '\r')"
  cc_ver="$("$PY" -m pip show crytic-compile   2>/dev/null | awk -F': ' '/^Version:/{print $2}' | tr -d '\r')"

  if [[ "$sa_ver" == "$ACCEPTED_SLITHER_VERSION" ]]; then
    pass "distribution 'slither-analyzer' == $ACCEPTED_SLITHER_VERSION (the accepted pin)"
  else
    fail "slither-analyzer is '${sa_ver:-not installed}', accepted pin is $ACCEPTED_SLITHER_VERSION"
  fi

  if [[ "$cc_ver" == "$ACCEPTED_ADAPTER_VERSION" ]]; then
    pass "distribution 'crytic-compile' == $ACCEPTED_ADAPTER_VERSION (the accepted pin)"
  else
    fail "crytic-compile is '${cc_ver:-not installed}', accepted pin is $ACCEPTED_ADAPTER_VERSION"
  fi

  # The hazard package must not be present under any circumstances.
  if "$PY" -m pip show slither >/dev/null 2>&1; then
    fail "PyPI distribution 'slither' is installed — that is the unrelated PySlither/Slither package, NOT the analyzer (refreeze §3.5). Uninstall it."
  else
    pass "unrelated PyPI distribution 'slither' absent"
  fi
fi

# --- D-S2: the no-RPC control the accepted residual depends on --------------
echo
echo "== no-RPC environment (D-S2) =="
rpc_set=()
for v in WEB3_PROVIDER_URI WEB3_HTTP_PROVIDER_URI ETH_RPC_URL RPC_URL PROVIDER_URI \
         FOUNDRY_ETH_RPC_URL ETHERSCAN_API_KEY WEB3_INFURA_PROJECT_ID WEB3_ALCHEMY_PROJECT_ID; do
  [[ -n "${!v:-}" ]] && rpc_set+=("$v")
done
if (( ${#rpc_set[@]} > 0 )); then
  fail "RPC/provider endpoint configured (${rpc_set[*]}) — the accepted D-S2 disposition of GHSA-5hr4-253g-cpx2 is conditioned on a local-only invocation. Operator review is required before widening static analysis into a provider path."
else
  pass "no RPC/provider endpoint configured — D-S2's bounded-invocation condition holds"
fi

# --- §7.2: the accepted build produces the AST slither reads ----------------
#
# Built into a DEDICATED output directory rather than the project's `out/`.
# Not cosmetic isolation — `--build-info --skip test/** --skip script/**`
# produces a different artifact set from a plain `forge build`, and
# `test/events/EventSchemaConformance.t.sol` reads those artifacts back through
# `vm.readFile` + `vm.parseJsonBytes` fourteen times in one test. Sharing `out/`
# made that test exhaust EVM memory (MemoryOOG at ~1.07e9 gas) purely because
# this gate had run first. A gate that breaks the suite it runs alongside is a
# defect in the gate.
#
# Every property the accepted D-S2 disposition is conditioned on is preserved:
# local project target, --ignore-compile, local Foundry build-info, no address
# target, no slither-read-storage, no RPC. The flag narrows blast radius; it
# widens nothing.
SA_OUT="out-slither"
echo
echo "== build-info from the accepted toolchain (isolated in $SA_OUT/) =="
if forge build --out "$SA_OUT" --build-info --skip 'test/**' --skip 'script/**' >/dev/null 2>&1; then
  bi_count=$(find "$SA_OUT/build-info" -name '*.json' -type f 2>/dev/null | wc -l | tr -d ' ')
  if (( bi_count > 0 )); then
    pass "forge emitted $bi_count build-info artifact(s) into $SA_OUT/ under the accepted Foundry/solc pins"
  else
    fail "no $SA_OUT/build-info/*.json produced — slither has nothing to read"
  fi
else
  fail "forge build --out $SA_OUT --build-info failed"
fi

# --- the analysis itself ----------------------------------------------------
echo
echo "== slither =="
# Invoked as `$PY -m slither`, never as a bare `slither` on PATH. This is not a
# portability workaround: the D-S4 identity assertion above interrogates $PY's
# site-packages, so executing through the SAME interpreter is what binds the
# assertion to the thing that actually runs. A PATH lookup could assert one
# install and execute another.
if "$PY" -c 'import slither' >/dev/null 2>&1; then
  rm -f "$REPORT"
  # Exit status is deliberately not consulted: slither returns non-zero whenever
  # findings exist, which is the normal state of a triaged baseline. The
  # dispositions are the gate, not the count.
  "$PY" -m slither . --ignore-compile --foundry-out-directory "$SA_OUT" \
        --filter-paths 'vendor/' --json "$REPORT" >/dev/null 2>&1 || true
  if [[ -s "$REPORT" ]]; then
    if "$PY" "$SA_DIR/compare-baseline.py" --report "$REPORT" --baseline "$BASELINE"; then
      pass "static-analysis baseline clean"
    else
      fail "static-analysis findings diverge from the triaged baseline (see above)"
    fi
  else
    fail "slither produced no report at $REPORT"
  fi
else
  fail "slither not importable — install with: $PY -m pip install --require-hashes --no-deps -r $REQ"
fi

# --- forge lint (Sprint 8 deliverable: "slither + forge lint in CI") ---------
#
# Part of the already-accepted Foundry v1.5.0 — no new provenance surface.
#
# `forge lint` exits 0 whether or not it finds anything, so its findings are
# counted rather than its status trusted. HIGH severity fails outright: unlike
# slither's output there is no baseline for it, and there are currently none, so
# the first one to appear should stop the build rather than be absorbed.
#
# MEDIUM findings are recorded in triage-baseline.json's `forge_lint` block with
# their dispositions (all four are guarded or idiomatic — the linter cannot see
# the domain check on the preceding line). They are reported here, not failed on,
# because the accepted gate is the slither baseline; a second baseline machine
# for four dispositioned warnings would be more machinery than the risk warrants.
echo
echo "== forge lint =="
lint_high=$(forge lint src/ --severity high 2>&1 | grep -cE '^(error|warning)\[' || true)
lint_med=$(forge lint src/ --severity med 2>&1 | grep -cE '^(error|warning)\[' || true)
if [[ "${lint_high:-0}" == "0" ]]; then
  pass "forge lint: 0 high-severity finding(s)"
else
  fail "forge lint reported $lint_high high-severity finding(s) — these are not baselined; fix them"
  forge lint src/ --severity high 2>&1 | grep -E '^(error|warning)\[|-->' | sed 's/^/        /'
fi
expected_med=$(jq -r '.forge_lint.medium_findings // 0' "$BASELINE" 2>/dev/null | tr -d '\r')
if [[ "${lint_med:-0}" == "${expected_med:-0}" ]]; then
  pass "forge lint: $lint_med medium-severity finding(s), matching the recorded dispositions"
else
  fail "forge lint medium count is $lint_med, baseline records ${expected_med:-0} — triage the difference and update tools/static-analysis/triage-baseline.json"
fi

finish
