#!/usr/bin/env bash
# Gate 2 — immutable-pin discipline (PROV-6, PROV-9).
#
# Enforces (sprint.md Sprint 1 acceptance criterion 6):
#   * foundry.toml carries both solc pins, full 40 hex characters;
#   * the Foundry toolchain pin is recorded (refreeze §6 binding rule);
#   * the compilers that actually ran self-report those pinned build commits —
#     a recorded pin nobody uses is a comment, not a fence;
#   * no short SHA and no mutable upstream reference (branch / tag / HEAD /
#     latest / master / main) is used as source authority in VUX-owned files.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
cd "$REPO_ROOT"

# --- the authority that selects the toolchain -------------------------------
echo "== toolchain authority =="
require_authority "$TOOLCHAIN_MD"   "$TOOLCHAIN_MD_SHA256"
require_authority "$TOOLCHAIN_JSON" "$TOOLCHAIN_JSON_SHA256"
(( FAILURES == 0 )) && pass "toolchain refreeze authority byte-identical to the accepted values"

# --- pins recorded, full length ---------------------------------------------
echo "== recorded pins =="
check_pin() {
  local label="$1" pin="$2" file="$3"
  if [[ ! "$pin" =~ ^[0-9a-f]{40}$ ]]; then
    fail "$label pin is not a 40-character lowercase hex commit: '$pin'"
    return
  fi
  if ! grep -qF "$pin" "$file"; then
    fail "$label pin $pin not recorded in $file"
    return
  fi
  pass "$label pin recorded in $file ($pin)"
}
check_pin "solc $SOLC_MAIN_VERSION" "$SOLC_MAIN_COMMIT" foundry.toml
check_pin "solc $SOLC_V3_VERSION"   "$SOLC_V3_COMMIT"   foundry.toml
check_pin "foundry $FOUNDRY_TAG"    "$FOUNDRY_COMMIT"   foundry.toml

# --- the compilers that ran match those pins --------------------------------
echo
echo "== compiler build identity (as actually used) =="
# Checks EVERY compiled artifact in the unit, not whichever JSON the filesystem
# happened to return first. `find … | head -1` was both non-deterministic across
# filesystems and semantically wrong: out/build-info/*.json matches that glob but
# is a compilation-input record whose only keys are id/language/source_id_to_path
# — selecting one produced a spurious fail-closed failure. build-info is excluded
# by path, and the assertion is now over the set of reported compiler identities,
# which is strictly stronger than sampling one artifact.
check_compiler() {
  local label="$1" version="$2" pin="$3" dir="$4" reported expected
  local artifacts=()
  expected="$version+commit.${pin:0:8}"
  if [[ ! -d "$dir" ]]; then
    fail "$label: no build output directory $dir/ — run tools/provenance/run-all.sh"
    return
  fi
  while IFS= read -r a; do
    [[ -n "$a" ]] && artifacts+=("$a")
  done < <(find "$dir" -type f -name '*.json' -not -path '*/build-info/*' 2>/dev/null | LC_ALL=C sort)
  if (( ${#artifacts[@]} == 0 )); then
    fail "$label: no compiled artifact under $dir/ — run tools/provenance/run-all.sh"
    return
  fi
  reported="$(jq -r '.metadata.compiler.version // empty' "${artifacts[@]}" | tr -d '\r' | LC_ALL=C sort -u)"
  if [[ -z "$reported" ]]; then
    fail "$label: none of the ${#artifacts[@]} artifact(s) under $dir/ reports .metadata.compiler.version"
    return
  fi
  if [[ "$reported" != "$expected" ]]; then
    fail "$label compiler mismatch under $dir/ — pin requires '$expected', artifacts report:"$'\n'"$reported"
  else
    pass "$label: all ${#artifacts[@]} artifact(s) under $dir/ compiled by $reported"
  fi
}
check_compiler "=$SOLC_MAIN_VERSION unit" "$SOLC_MAIN_VERSION" "$SOLC_MAIN_COMMIT" "out"
check_compiler "=$SOLC_V3_VERSION unit"   "$SOLC_V3_VERSION"   "$SOLC_V3_COMMIT"   "out-v3core"

# --- the Foundry that is actually running -----------------------------------
# Toolchain identity is part of the evidence chain, not ambient context. This
# was previously an info() print, on the reasoning that Foundry is an
# orchestrator rather than a compiler; that reasoning is incomplete. The
# orchestrator decides what reaches solc and what solc is told: probe 12 of
# demo-boundary-negative.sh passes under v1.5.0 and hard-fails under v1.0.0
# ("unexpected file extension"), and an unset evm_version inherits the
# orchestrator's default into solc's metadata. Which forge ran therefore changes
# what the evidence means, so a divergence must fail the run rather than scroll
# past in a log. Ambient PATH version is not evidence.
#
# Authority: docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md §8
echo
echo "== running Foundry identity =="
if ! command -v forge >/dev/null 2>&1; then
  fail "forge is not on PATH — the authoritative toolchain foundry $FOUNDRY_TAG @ $FOUNDRY_COMMIT cannot be verified"
else
  forge_id="$(forge --version 2>/dev/null || true)"
  if [[ "$forge_id" != *"$FOUNDRY_COMMIT"* ]]; then
    fail "running Foundry does not self-report the authoritative commit $FOUNDRY_COMMIT (foundry $FOUNDRY_TAG):"$'\n'"$forge_id"
  elif [[ "$forge_id" != *"${FOUNDRY_TAG#v}"* ]]; then
    fail "running Foundry reports the authoritative commit but not version $FOUNDRY_TAG:"$'\n'"$forge_id"
  else
    pass "running Foundry is foundry $FOUNDRY_TAG @ $FOUNDRY_COMMIT (self-reported)"
  fi
fi

# --- short-SHA and mutable-reference detection ------------------------------
# Scope: VUX-owned build/provenance/CI files. The accepted authority documents
# under docs/authority/ legitimately name tags as *evidence* alongside their
# resolved commits, and vendored upstream is byte-identical by definition — so
# neither is rewritten or scanned here.
echo
echo "== mutable-reference and short-SHA detection (VUX-owned files) =="
SCOPE=(foundry.toml remappings.txt .gitattributes)
[[ -d tools ]] && SCOPE+=(tools)
[[ -d .github ]] && SCOPE+=(.github)
[[ -d script ]] && SCOPE+=(script)

# An upstream URL that resolves through a mutable ref is never authority.
mutable="$(grep -rnE 'github\.com/[^ "'"'"')]+/(blob|tree|raw|archive)/(main|master|HEAD|latest|v?[0-9][^/ ]*)/' \
  "${SCOPE[@]}" 2>/dev/null || true)"
if [[ -n "$mutable" ]]; then
  fail "mutable upstream reference used as source authority:"$'\n'"$mutable"
else
  pass "no mutable upstream reference (branch / tag / HEAD / latest) in VUX-owned files"
fi

# A commit-shaped hex string shorter than 40 characters is a short SHA.
short="$(grep -rnoE '\b(commit|sha|rev|pin)[^a-z0-9]{0,12}[0-9a-f]{7,39}\b' \
  "${SCOPE[@]}" 2>/dev/null | grep -vE '[0-9a-f]{40}' || true)"
if [[ -n "$short" ]]; then
  fail "short SHA used as a pin (40 characters required, PROV-6):"$'\n'"$short"
else
  pass "no short SHA used as a pin"
fi

# CI actions are supply chain too: `uses: owner/repo@v1` resolves through a
# mutable tag the upstream owner can repoint at any commit.
if [[ -d .github/workflows ]]; then
  unpinned="$(grep -rnE '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*[^ ]+@' .github/workflows \
    | grep -vE '@[0-9a-f]{40}([[:space:]]|$)' || true)"
  if [[ -n "$unpinned" ]]; then
    fail "GitHub Action not pinned to a 40-character commit:"$'\n'"$unpinned"
  else
    pass "every GitHub Action pinned to a 40-character commit"
  fi
fi

finish
