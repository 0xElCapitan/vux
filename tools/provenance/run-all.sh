#!/usr/bin/env bash
# The complete fail-closed provenance gate set (PROV-9).
#
# Runs every gate, always to completion, and exits non-zero if any failed — so
# one violation does not hide the others. This is what CI runs and what a
# developer runs locally before handing work off.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/../.."

failed=()
run_gate() {
  local name="$1" script="$2"
  printf '\n\033[1m──────── %s ────────\033[0m\n' "$name"
  if bash "$script"; then :; else failed+=("$name"); fi
}

echo "Building both compilation units..."
FOUNDRY_PROFILE=v3core forge build --force >/dev/null || failed+=("build: =0.7.6 vendored unit")
forge build --force >/dev/null || failed+=("build: =0.8.28 unit")

run_gate "census, byte identity, excluded sources" "$HERE/verify-census.sh"
run_gate "immutable pins"                          "$HERE/verify-pins.sh"
run_gate "SPDX and copyright policy"               "$HERE/verify-spdx.sh"
run_gate "LICENSE and third-party notices"         "$HERE/verify-notices.sh"
run_gate "PRD §17 research-guidance quarantine"    "$HERE/verify-quarantine.sh"
run_gate "launch-secret and broadcast hygiene"     "$HERE/verify-launch-hygiene.sh"
run_gate "POOL_INIT_CODE_HASH reproduction"        "$HERE/verify-init-code-hash.sh"
run_gate "deployed surface and runtime capability" "$HERE/inspect-runtime-surface.sh"
run_gate "static analysis (slither, triaged baseline)" "$HERE/verify-static-analysis.sh"
run_gate "requirement traceability (INV/FB)"       "$HERE/../traceability/verify-traceability.sh"
run_gate "final secret sweep (whole namespace)"    "$HERE/final-secret-sweep.sh"

printf '\n\033[1m──────── test suite ────────\033[0m\n'
forge test || failed+=("forge test")

printf '\n\033[1m════════ summary ════════\033[0m\n'
if (( ${#failed[@]} > 0 )); then
  printf '\033[31mFAILED\033[0m — %d gate(s):\n' "${#failed[@]}"
  printf '  - %s\n' "${failed[@]}"
  exit 1
fi
printf '\033[32mAll provenance gates and tests passed.\033[0m\n'
