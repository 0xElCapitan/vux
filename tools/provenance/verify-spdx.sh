#!/usr/bin/env bash
# Gate 3 — SPDX and copyright-holder policy (PROV-8, refreeze §5).
#
#   * every vendored file retains its upstream SPDX identifier verbatim;
#   * every VUX-owned Solidity file declares GPL-3.0-or-later, or
#     "MIT AND GPL-3.0-or-later" when it is materially Miner-derived;
#   * a Miner-derived declaration and a Miner provenance header imply each
#     other — neither can appear alone;
#   * no VUX-owned file invents a copyright holder.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
cd "$REPO_ROOT"

spdx_of() { grep -m1 -oE 'SPDX-License-Identifier:[[:space:]]*[^*/[:space:]].*' "$1" | sed 's/SPDX-License-Identifier:[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '\r'; }

# --- vendored: upstream SPDX retained verbatim ------------------------------
echo "== vendored SPDX retention =="
checked=0
check_upstream_spdx() {
  local path expected vendored actual
  while IFS=$'\t' read -r path expected vendored; do
    [[ -n "$path" ]] || continue
    checked=$((checked + 1))
    actual="$(spdx_of "$vendored" || true)"
    if [[ "$actual" != "$expected" ]]; then
      fail "vendored SPDX altered: $vendored declares '$actual', upstream is '$expected'"
    fi
  done
}
check_upstream_spdx < <(jq -r --arg d "$OZ_DIR" '
  .dependencies_selected[] | select(.repository == "OpenZeppelin/openzeppelin-contracts")
  | .authorized_files[] | [.path, .upstream_spdx, ($d + "/" + .path)] | @tsv
' "$REFREEZE_JSON" | tr -d '\r')
check_upstream_spdx < <(jq -r --arg d "$V3_DIR" '
  .dependencies_selected[] | select(.repository == "Uniswap/v3-core")
  | .authorized_files[] | [.path, .upstream_spdx, ($d + "/" + .path)] | @tsv
' "$REFREEZE_JSON" | tr -d '\r')
check_upstream_spdx < <(jq -r --arg d "$MINER_DIR" '
  .file_reuse_allowlist[] | select(.repository == "Heesho/miner-manifold")
  | [.path, .upstream_spdx, ($d + "/" + .path)] | @tsv
' "$BASE_JSON" | tr -d '\r')
(( FAILURES > 0 )) || pass "$checked/$checked vendored files retain their upstream SPDX verbatim"

# The refreeze records the exact v3-core licence tally; a silent per-file SPDX
# swap that kept the *set* intact would still be drift, so assert the counts.
echo
echo "== v3-core licence tally (refreeze §4) =="
declare -A want=([BUSL-1.1]=9 [GPL-2.0-or-later]=22 [MIT]=1)
for lic in "${!want[@]}"; do
  n="$(jq -r --arg l "$lic" '
    [.dependencies_selected[] | select(.repository == "Uniswap/v3-core")
     | .authorized_files[] | select(.upstream_spdx == $l)] | length
  ' "$REFREEZE_JSON" | tr -d '\r')"
  if [[ "$n" != "${want[$lic]}" ]]; then
    fail "v3-core $lic count is $n, accepted tally is ${want[$lic]}"
  else
    pass "v3-core $lic × $n"
  fi
done

# --- VUX-owned Solidity -----------------------------------------------------
# Scope is the repository-wide non-vendored Solidity set (census.sh), not a
# directory list: a file that escapes the declared VUX source roots is still
# held to this policy instead of silently opting out of it.
echo
echo "== VUX-owned SPDX policy (PROV-8, repository-wide) =="
vux_sol="$(vux_owned_sources)"
if [[ -z "$vux_sol" ]]; then
  info "no VUX-owned Solidity files yet"
else
  n=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    n=$((n + 1))
    declared="$(spdx_of "$f" || true)"
    # A file is Miner-derived when it carries the mandatory provenance marker.
    if grep -qE '@custom:provenance[[:space:]]+miner-manifold' "$f"; then
      if [[ "$declared" != "MIT AND GPL-3.0-or-later" ]]; then
        fail "$f is Miner-derived but declares SPDX '$declared' (PROV-8 requires 'MIT AND GPL-3.0-or-later')"
      fi
    elif [[ "$declared" == "MIT AND GPL-3.0-or-later" ]]; then
      fail "$f declares the Miner-derived SPDX without an '@custom:provenance miner-manifold' header"
    elif [[ "$declared" != "GPL-3.0-or-later" ]]; then
      fail "$f declares SPDX '$declared'; VUX-original source is 'GPL-3.0-or-later'"
    fi
  done <<< "$vux_sol"
  (( FAILURES > 0 )) || pass "$n VUX-owned Solidity file(s) match the PROV-8 SPDX policy"
fi

# --- no invented copyright holders ------------------------------------------
echo
echo "== copyright-holder policy =="
# The only holder statements this project carries are the upstream ones, quoted
# verbatim in THIRD_PARTY_NOTICES.md. VUX-owned Solidity asserts none. (Scoped
# to *.sol: the notices gate necessarily contains the upstream holder strings it
# checks for.)
invented="$(grep_sources "$vux_sol" -HniE 'copyright[[:space:]]*(\(c\)|©)')"
if [[ -n "$invented" ]]; then
  fail "copyright holder asserted in VUX-owned source (refreeze §5: no invented holders):"$'\n'"$invented"
else
  pass "no copyright holder asserted in VUX-owned source"
fi

finish
