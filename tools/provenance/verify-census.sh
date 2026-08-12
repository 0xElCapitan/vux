#!/usr/bin/env bash
# Gate 1 — census exactness, per-file byte identity, and excluded-source detection.
#
# Enforces (sprint.md Sprint 1 acceptance criteria 1 and 4):
#   * the accepted authority artifacts are themselves unmutated;
#   * exactly 28 + 32 + 3 vendored upstream files exist;
#   * every one matches its accepted identity byte-for-byte (drift gate);
#   * zero unauthorized Solidity source exists ANYWHERE in the repository —
#     default-deny over the whole source universe, not a scanned directory list,
#     and independent of extension case (sprint-2 audit A-1);
#   * zero unenumerated files of any type exist under vendor/;
#   * the explicitly excluded surfaces (refreeze §8) are absent, detected
#     repository-wide so relocation cannot bypass them.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
cd "$REPO_ROOT"

echo "== accepted authority integrity =="
require_authority "$REFREEZE_MD"   "$REFREEZE_MD_SHA256"
require_authority "$REFREEZE_JSON" "$REFREEZE_JSON_SHA256"
require_authority "$BASE_MD"       "$BASE_MD_SHA256"
require_authority "$BASE_JSON"     "$BASE_JSON_SHA256"
(( FAILURES > 0 )) || pass "4 accepted authority artifacts match their recorded SHA-256"

# --- census counts ----------------------------------------------------------
echo
echo "== census exactness =="
check_count() {
  local dir="$1" expected="$2" label="$3" actual
  actual="$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$actual" != "$expected" ]]; then
    fail "$label census is $actual files, accepted census is $expected ($dir)"
  else
    pass "$label: exactly $expected files"
  fi
}
check_count "$OZ_DIR"    "$OZ_COUNT"    "OpenZeppelin v5.2.0"
check_count "$V3_DIR"    "$V3_COUNT"    "Uniswap v3-core v1.0.0"
check_count "$MINER_DIR" "$MINER_COUNT" "Miner Manifold @ bcffbf1e"

# --- per-file identity (the drift gate) -------------------------------------
echo
echo "== per-file byte identity vs. accepted registry =="
drift=0; checked=0
verify_family() {
  local id_kind="$1" upstream_path identity vendored actual
  while IFS=$'\t' read -r upstream_path identity vendored; do
    [[ -n "$upstream_path" ]] || continue
    checked=$((checked + 1))
    if [[ ! -f "$vendored" ]]; then
      fail "authorized file missing from tree: $vendored"
      drift=$((drift + 1))
      continue
    fi
    if [[ "$id_kind" == "sha256" ]]; then
      actual="$(sha256_of "$vendored")"
    else
      actual="$(git hash-object "$vendored")"
    fi
    if [[ "$actual" != "$identity" ]]; then
      fail "DRIFT ($id_kind) $vendored
        accepted $identity
        actual   $actual"
      drift=$((drift + 1))
    fi
  done
}
verify_family sha256 < <(census_oz)
verify_family sha256 < <(census_v3)
verify_family blob   < <(census_miner)
(( drift > 0 )) || pass "$checked/$checked vendored files byte-identical to accepted identities"

# --- default-deny over the whole repository source universe -----------------
# The census defends itself: every Solidity file in the working tree must be
# either an enumerated census row or inside a declared VUX source root. A file
# in any other location fails, so unauthorized source cannot escape by choosing
# a directory no detector happens to scan.
echo
echo "== repository source boundary (default-deny) =="
classified="$(classify_sources)"
all_sources="$(printf '%s\n' "$classified" | cut -f2 | sed '/^$/d')"
unauthorized="$(printf '%s\n' "$classified" | awk -F'\t' '$1 == "unauthorized" { print $2 }')"
n_total="$(printf '%s\n' "$all_sources" | sed '/^$/d' | wc -l | tr -d ' ')"
n_vendored="$(printf '%s\n' "$classified" | awk -F'\t' '$1 == "vendored"' | wc -l | tr -d ' ')"
n_vux="$(printf '%s\n' "$classified" | awk -F'\t' '$1 == "vux"' | wc -l | tr -d ' ')"
info "source universe: $n_total Solidity file(s) — $n_vendored vendored (census), $n_vux VUX-owned (roots: ${VUX_SOURCE_ROOTS[*]})"

if [[ -n "$unauthorized" ]]; then
  while IFS= read -r f; do
    fail "unauthorized Solidity source — neither an accepted census row nor inside a declared VUX source root (${VUX_SOURCE_ROOTS[*]}): $f"
  done <<< "$unauthorized"
else
  pass "zero unauthorized Solidity source anywhere in the repository ($n_total file(s) classified)"
fi

# The walk must SEE the whole census, or a pruning bug would hide vendor/ and
# quietly turn the check above into a tautology.
expected_census=$(( OZ_COUNT + V3_COUNT + MINER_COUNT ))
if [[ "$n_vendored" != "$expected_census" ]]; then
  fail "source-universe walk classified $n_vendored census rows, accepted census is $expected_census — the walk is not seeing the vendored tree"
else
  pass "all $expected_census accepted census rows present in the classified source universe"
fi

# The prune list is the one place a default-deny boundary can still be sidestepped.
# Build output is generated and gitignored, but the Loa zones are git-trackable,
# so their exemption is made CONDITIONAL rather than absolute: they stay pruned
# from the walk (cost), and must contain no Solidity at all. Without this, a .sol
# committed under grimoires/ or .claude/ would be classified by nobody and still
# compile once a file in a declared VUX root imported it (sprint-1 audit N-1).
zone_sol="$(loa_zone_solidity)"
if [[ -n "$zone_sol" ]]; then
  while IFS= read -r f; do
    fail "Solidity inside a pruned Loa/state zone — unclassifiable by the source boundary yet build-reachable via an explicit import from a VUX source root (sprint-1 audit N-1): $f"
  done <<< "$zone_sol"
else
  pass "zero Solidity in the pruned Loa/state zones (${LOA_ZONE_PRUNE[*]}) — the prune stays safe"
fi

# Extension-agnostic exactness inside vendor/: the classification above covers
# Solidity everywhere, this covers a file of ANY type smuggled into vendor/.
if [[ -d vendor ]]; then
  authorized="$(census_all_paths | LC_ALL=C sort)"
  present="$(find vendor \( -type f -o -type l \) | sed 's|\\|/|g' | LC_ALL=C sort)"
  extra="$(comm -13 <(echo "$authorized") <(echo "$present"))"
  if [[ -n "$extra" ]]; then
    while IFS= read -r f; do fail "unenumerated file under vendor/: $f"; done <<< "$extra"
  else
    pass "zero unenumerated files of any type under vendor/"
  fi
fi

# --- explicitly excluded surfaces (refreeze §8) -----------------------------
# Every detector below runs over the classified source universe, so it reaches
# VUX-owned roots and unauthorized locations alike — relocating prohibited
# material into a new directory does not move it out of scope.
echo
echo "== excluded-source detection (refreeze §8, repository-wide) =="
# UniswapV3Factory.sol: the *interface* is authorized, the implementation is not.
# Matched case-insensitively for the same reason the source universe is (A-1):
# this is the one detector below that keys on a FILENAME rather than on content,
# so a case-sensitive match would still miss `UniswapV3Factory.SOL` sitting
# inside a declared VUX root — where the default-deny check does not fire.
factory_files="$(printf '%s\n' "$all_sources" | grep -iE '(^|/)UniswapV3Factory\.sol$' || true)"
if [[ -n "$factory_files" ]]; then
  fail "UniswapV3Factory.sol implementation present — excluded by refreeze §8:"$'\n'"$factory_files"
else
  pass "no UniswapV3Factory.sol implementation"
fi
# v3-periphery: the §7 evidence pin authorizes zero CODE USE. Citing it in a
# comment as the cross-confirmation source is exactly what the refreeze does, so
# the detector targets use — source files, imports, and remappings — not prose.
periphery_files="$(printf '%s\n' "$all_sources" | grep -i 'periphery' || true)"
periphery_use="$(grep_sources "$all_sources" -HnE '^[[:space:]]*import[^;]*periphery|periphery[^[:space:]]*/=')"
periphery_remap="$(grep -nE 'periphery' foundry.toml remappings.txt 2>/dev/null || true)"
if [[ -n "$periphery_files$periphery_use$periphery_remap" ]]; then
  fail "v3-periphery code use detected — the evidence pin authorizes zero code use (refreeze §7/§8):"$'\n'"$periphery_files$periphery_use$periphery_remap"
else
  pass "no v3-periphery source, import, or remapping"
fi
# Miner: exactly the three allowlisted files, nothing more. Relocation is covered
# by the layers above and beside this one — a verbatim Miner file outside
# MINER_DIR is either `unauthorized` (fails the boundary check) or lands in a
# VUX root, where verify-spdx.sh rejects its upstream `MIT` header against the
# PROV-8 policy (VUX-original is GPL-3.0-or-later; Miner-DERIVED source is the
# separately-governed `MIT AND GPL-3.0-or-later` + provenance-marker path).
unexpected_miner="$(find "$MINER_DIR" \( -type f -o -type l \) 2>/dev/null | sed 's|\\|/|g' \
  | grep -vE "^$MINER_DIR/(contracts/Rig\.sol|contracts/Unit\.sol|contracts/interfaces/IUnit\.sol)$" || true)"
if [[ -n "$unexpected_miner" ]]; then
  while IFS= read -r f; do fail "non-allowlisted Miner Manifold file: $f"; done <<< "$unexpected_miner"
else
  pass "Miner Manifold reuse limited to the 3 allowlisted files"
fi
# Prohibited / no-copy sources (refreeze §8, PRD §15) — repository-wide.
prohibited_hits="$(grep_sources "$all_sources" -HniE 'liquid-signal-governance|gumball6900|give\.fun|olympus')"
if [[ -n "$prohibited_hits" ]]; then
  fail "prohibited-source reference in Solidity sources:"$'\n'"$prohibited_hits"
else
  pass "no prohibited-source (LSG / gumball6900 / give.fun / Olympus) reference in Solidity sources"
fi

finish
