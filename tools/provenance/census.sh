#!/usr/bin/env bash
# Shared census library for the VUX provenance gates.
#
# Single source of truth for "which upstream files are authorized, at which
# commit, with which byte identity, and where they live in this repository".
# Every fact here is READ FROM the operator-accepted authority artifacts under
# docs/authority/ — nothing is restated by hand, so the gates cannot drift from
# the accepted registry.
#
# Authority:
#   docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md      (§3/§4/§6/§7/§8)
#   docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json
#   docs/authority/vux-v1-source-registry-2026-08.json              (Miner allowlist)
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- Accepted authority artifacts, pinned by SHA-256 -------------------------
# These hashes are the operator-accepted values. A gate that read a mutated
# registry would "pass" against the mutation; pinning them makes the authority
# itself tamper-evident.
REFREEZE_MD="docs/authority/vux-v1-oz-v3-provenance-refreeze-2026-08.md"
REFREEZE_MD_SHA256="27aa37ec82fffaea4deb63d5ccd87f66a7e71bad1afa9e7d95d814035e8e3203"
REFREEZE_JSON="docs/authority/vux-v1-source-registry-oz-v3-refreeze-2026-08.json"
REFREEZE_JSON_SHA256="db3144135251af34f6bef9da61300a2644c381c4763f2347753657de6afaf4f1"
BASE_JSON="docs/authority/vux-v1-source-registry-2026-08.json"
BASE_JSON_SHA256="6fc9fa81d80eda1f1017c6cb79f297b9a608150538e76ad97d8de1c8b5d2fe04"
BASE_MD="docs/authority/vux-v1-licence-provenance-source-pin-freeze-2026-08.md"
BASE_MD_SHA256="50c3584a1483b40ffb6391260a2bf42df32220c64724fdcc672ca62c01ace3a2"
TPN="THIRD_PARTY_NOTICES.md"
TPN_SHA256="963e2cfb8fe8306ee6d2cfd6e14fa417a7a61fd7bfddc3fe5aedc2b577170873"

# --- Accepted pins (refreeze §2/§6/§7) --------------------------------------
OZ_REPO="OpenZeppelin/openzeppelin-contracts"
OZ_URL="https://github.com/OpenZeppelin/openzeppelin-contracts"
OZ_COMMIT="acd4ff74de833399287ed6b31b4debf6b2b35527"
OZ_TAG="v5.2.0"
OZ_DIR="vendor/openzeppelin-contracts-v5.2.0"
OZ_COUNT=28

V3_REPO="Uniswap/v3-core"
V3_URL="https://github.com/Uniswap/v3-core"
V3_COMMIT="e3589b192d0be27e100cd0daaf6c97204fdb1899"
V3_TAG="v1.0.0"
V3_DIR="vendor/uniswap-v3-core-v1.0.0"
V3_COUNT=32

MINER_REPO="Heesho/miner-manifold"
MINER_URL="https://github.com/Heesho/miner-manifold"
MINER_COMMIT="bcffbf1eb963810acb14a1fd1c73d03a53a085a8"
MINER_DIR="vendor/miner-manifold-bcffbf1e"
MINER_COUNT=3

SOLC_MAIN_VERSION="0.8.28"
SOLC_MAIN_COMMIT="7893614a31fbeacd1966994e310ed4f760772658"
SOLC_V3_VERSION="0.7.6"
SOLC_V3_COMMIT="7338295feebfb3f044e265d5cf05ef1841b258b1"
FOUNDRY_TAG="v1.0.0"
FOUNDRY_COMMIT="8692e926198056d0228c1e166b1b6c34a5bed66c"

POOL_INIT_CODE_HASH="0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54"

# --- Output helpers ---------------------------------------------------------
RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
[[ -t 1 ]] || { RED=""; GREEN=""; YELLOW=""; RESET=""; }

FAILURES=0
fail()  { printf '%sFAIL%s  %s\n' "$RED" "$RESET" "$*" >&2; FAILURES=$((FAILURES + 1)); }
pass()  { printf '%sok%s    %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { printf '%swarn%s  %s\n' "$YELLOW" "$RESET" "$*"; }
info()  { printf '      %s\n' "$*"; }

# Exit non-zero if any fail() was recorded. Every gate ends with this — the
# gates are fail-closed by construction.
finish() {
  if (( FAILURES > 0 )); then
    printf '\n%s%d check(s) failed.%s\n' "$RED" "$FAILURES" "$RESET" >&2
    exit 1
  fi
  printf '\n%sAll checks passed.%s\n' "$GREEN" "$RESET"
}

sha256_of() { sha256sum "$1" | cut -d' ' -f1; }

# Verify one authority artifact against its accepted SHA-256.
require_authority() {
  local path="$1" expected="$2" actual
  if [[ ! -f "$REPO_ROOT/$path" ]]; then
    fail "authority artifact missing: $path"
    return
  fi
  actual="$(sha256_of "$REPO_ROOT/$path")"
  if [[ "$actual" != "$expected" ]]; then
    fail "authority artifact mutated: $path
        expected $expected
        actual   $actual"
  fi
}

# Emit "<upstream-path>\t<sha256>\t<repo-relative vendored path>" for one
# dependency family, read straight from the accepted registry.
#
# `tr -d '\r'` is load-bearing, not cosmetic: the Windows jq build writes CRLF
# line endings, and an unstripped CR ends up inside the emitted file path — it
# silently produces vendored files named "Foo.sol\r".
census_oz() {
  jq -r --arg repo "$OZ_REPO" --arg dir "$OZ_DIR" '
    .dependencies_selected[] | select(.repository == $repo)
    | .authorized_files[] | [.path, .sha256, ($dir + "/" + .path)] | @tsv
  ' "$REPO_ROOT/$REFREEZE_JSON" | tr -d '\r'
}

census_v3() {
  jq -r --arg repo "$V3_REPO" --arg dir "$V3_DIR" '
    .dependencies_selected[] | select(.repository == $repo)
    | .authorized_files[] | [.path, .sha256, ($dir + "/" + .path)] | @tsv
  ' "$REPO_ROOT/$REFREEZE_JSON" | tr -d '\r'
}

# The Miner allowlist predates the refreeze and is recorded by git blob OID
# only (base registry `file_reuse_allowlist`). Byte identity is therefore
# checked against the blob OID, which is what the accepted authority pins.
census_miner() {
  jq -r --arg repo "$MINER_REPO" --arg dir "$MINER_DIR" '
    .file_reuse_allowlist[] | select(.repository == $repo)
    | [.path, .git_blob_oid, ($dir + "/" + .path)] | @tsv
  ' "$REPO_ROOT/$BASE_JSON" | tr -d '\r'
}

# All vendored files that are supposed to exist, one repo-relative path per line.
census_all_paths() {
  { census_oz; census_v3; census_miner; } | cut -f3
}

# --- repository source universe (the default-deny boundary) -----------------
#
# The gates must reason about the repository's ACTUAL source universe, not a
# hand-maintained list of directories that an unauthorized file can simply step
# outside of. Every Solidity file in the working tree is classified into exactly
# one of three classes:
#
#   vendored      a path enumerated by the accepted registry (the 63-file census)
#   vux           inside a declared VUX-owned source root
#   unauthorized  anything else — fails closed
#
# Declaring a new source root is therefore a visible, reviewable edit to
# VUX_SOURCE_ROOTS rather than a silent exemption, and relocating source cannot
# move it out of any gate's reach. Filesystem enumeration is deliberate: a
# `git ls-files` scope would let an uncommitted (or gitignored) file escape.
VUX_SOURCE_ROOTS=(src test script)

# Excluded from the universe, each because it is not repository source:
#   .git                                git object store, not a working tree
#   out out-v3core cache cache-v3core   Foundry build output — note its artifact
#                                       layout creates DIRECTORIES named "*.sol"
#   broadcast                           gitignored launch artifacts (sdd.md:L270)
#   .claude grimoires .beads .run .ck   Loa framework/state zones, never compiled
# Nothing else is excluded. `lib/` (Foundry's conventional dependency directory)
# and `node_modules/` are deliberately IN scope — an unauthorized dependency
# landing there is exactly the failure this boundary exists to catch.
SOURCE_UNIVERSE_PRUNE=(.git out out-v3core cache cache-v3core broadcast .claude grimoires .beads .run .ck)

# Every Solidity file in the working tree: repo-relative, forward-slashed, sorted.
# Symlinks are included on purpose — a symlinked *.sol is still source a compiler
# would follow, and `-type f` alone would make it invisible to every gate.
source_universe() {
  local prune=() p
  for p in "${SOURCE_UNIVERSE_PRUNE[@]}"; do prune+=(-path "./$p" -o); done
  find . \( "${prune[@]}" -false \) -prune -o \( -type f -o -type l \) -name '*.sol' -print 2>/dev/null \
    | sed 's|^\./||; s|\\|/|g' | LC_ALL=C sort
}

# Classify the source universe. Emits "<class>\t<path>", one per line.
classify_sources() {
  local -A authorized=()
  local p root cls
  while IFS= read -r p; do [[ -n "$p" ]] && authorized["$p"]=1; done < <(census_all_paths)
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    if [[ -n "${authorized[$p]:-}" ]]; then
      cls=vendored
    else
      cls=unauthorized
      for root in "${VUX_SOURCE_ROOTS[@]}"; do
        if [[ "$p" == "$root"/* ]]; then cls=vux; break; fi
      done
    fi
    printf '%s\t%s\n' "$cls" "$p"
  done < <(source_universe)
}

# Every Solidity file the project OWNS — the declared VUX roots plus anything
# that escaped them. Vendored upstream is excluded: its bytes are frozen by the
# drift gate, so authored-source policy (SPDX, §17) does not apply to it.
vux_owned_sources() { classify_sources | awk -F'\t' '$1 != "vendored" { print $2 }'; }

# grep over a newline-delimited file list, tolerating an empty list. -H is
# supplied by callers where the path must appear even for a single-file list.
grep_sources() {
  local list="$1"; shift
  [[ -n "$list" ]] || return 0
  printf '%s\n' "$list" | sed '/^$/d' | xargs -r -d '\n' grep "$@" 2>/dev/null || true
}
