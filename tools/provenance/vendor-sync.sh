#!/usr/bin/env bash
# Re-vendor the authorized upstream census from the pinned upstream commits.
#
# This is the only mechanism that puts upstream bytes into the repository. It
# copies EXACTLY the files enumerated in the accepted registry — nothing else —
# and refuses to write anything if a fetched file's identity does not match the
# accepted value. Idempotent: running it on a clean tree is a no-op.
#
# Usage: tools/provenance/vendor-sync.sh
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"

cd "$REPO_ROOT"
require_authority "$REFREEZE_JSON" "$REFREEZE_JSON_SHA256"
require_authority "$BASE_JSON" "$BASE_JSON_SHA256"
(( FAILURES == 0 )) || finish

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# core.autocrlf=false on every clone: upstream bytes must arrive unmangled
# (refreeze §7 build-setting row "line endings unmangled").
clone_at() {
  local url="$1" commit="$2" dest="$3" tag="${4:-}"
  if [[ -n "$tag" ]]; then
    git -c core.autocrlf=false -c advice.detachedHead=false \
      clone --quiet --depth 1 --branch "$tag" "$url" "$dest"
  else
    git -c core.autocrlf=false clone --quiet "$url" "$dest"
    git -C "$dest" -c advice.detachedHead=false checkout --quiet "$commit"
  fi
  local head
  head="$(git -C "$dest" rev-parse HEAD)"
  if [[ "$head" != "$commit" ]]; then
    fail "pin mismatch for $url: expected $commit, got $head"
    finish
  fi
  info "$url @ $commit verified"
}

# Copy the enumerated files, verifying the identity of each byte-for-byte.
# id_kind is "sha256" (refreeze census) or "blob" (Miner allowlist).
sync_family() {
  local src="$1" id_kind="$2"
  local upstream_path identity vendored actual
  while IFS=$'\t' read -r upstream_path identity vendored; do
    [[ -n "$upstream_path" ]] || continue
    if [[ ! -f "$src/$upstream_path" ]]; then
      fail "authorized file absent from pinned upstream: $upstream_path"
      continue
    fi
    if [[ "$id_kind" == "sha256" ]]; then
      actual="$(sha256_of "$src/$upstream_path")"
    else
      actual="$(git -C "$src" hash-object "$upstream_path")"
    fi
    if [[ "$actual" != "$identity" ]]; then
      fail "upstream identity mismatch ($id_kind) for $upstream_path
        expected $identity
        actual   $actual"
      continue
    fi
    mkdir -p "$(dirname "$vendored")"
    cp "$src/$upstream_path" "$vendored"
  done
}

echo "== fetching pinned upstream =="
clone_at "$OZ_URL"    "$OZ_COMMIT"    "$WORK/oz"    "$OZ_TAG"
clone_at "$V3_URL"    "$V3_COMMIT"    "$WORK/v3"    "$V3_TAG"
clone_at "$MINER_URL" "$MINER_COMMIT" "$WORK/miner"

echo
echo "== vendoring authorized census =="
# Process substitution, not a pipe: a piped `while read` would run sync_family
# in a subshell and silently discard its fail() count.
sync_family "$WORK/oz"    sha256 < <(census_oz)
sync_family "$WORK/v3"    sha256 < <(census_v3)
sync_family "$WORK/miner" blob   < <(census_miner)
(( FAILURES == 0 )) || finish

pass "$OZ_COUNT OpenZeppelin + $V3_COUNT Uniswap v3-core + $MINER_COUNT Miner Manifold files vendored"
info "run tools/provenance/verify-census.sh to confirm the landed tree"
