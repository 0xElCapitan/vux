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
# Toolchain authority (2026-08-12). Pinned for the same reason as the others: a
# gate that read a mutated toolchain refreeze would enforce the mutation.
TOOLCHAIN_MD="docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.md"
TOOLCHAIN_MD_SHA256="439bdef308a79d1df20e4e43e2c3ec138af5bcd77dce3113a1a31befac20830a"
TOOLCHAIN_JSON="docs/authority/vux-v1-foundry-v1.5-toolchain-refreeze-2026-08.json"
TOOLCHAIN_JSON_SHA256="f83853492bd6894457813ef96dc23745cb1b52f04b684397623cacbc185224aa"

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
# Foundry moved v1.0.0 -> v1.5.0 on 2026-08-12 by operator decision; the Foundry
# row of refreeze §6 is superseded by TOOLCHAIN_MD (below), which changes the
# orchestrator and nothing else.
FOUNDRY_TAG="v1.5.0"
FOUNDRY_COMMIT="1c57854462289b2e71ee7654cd6666217ed86ffd"

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
# outside of. Every source file the universe contains is classified into exactly
# one of three classes:
#
#   vendored      a path enumerated by the accepted registry (the 63-file census)
#   vux           inside a declared VUX-owned source root
#   unauthorized  anything else — fails closed
#
# The universe itself is the UNION of two independent bodies of evidence
# (source_universe below): what the filesystem looks like, and what the accepted
# toolchain actually compiled. Neither alone is sufficient, and the union is
# maintained in one place so no consumer can drift onto a narrower definition.
#
# Declaring a new source root is therefore a visible, reviewable edit to
# VUX_SOURCE_ROOTS rather than a silent exemption, and neither relocating source,
# re-casing its extension, nor renaming it out of the Solidity extension
# altogether can move it out of any gate's reach. Filesystem enumeration is
# deliberate: a `git ls-files` scope would let an uncommitted (or gitignored)
# file escape.
VUX_SOURCE_ROOTS=(src test script)

# Excluded from the universe, split by WHY — the two classes carry different
# obligations, so they are no longer one undifferentiated list:
#
#   BUILD_ARTIFACT_PRUNE  not working-tree source at all. `.git` is the object
#                         store; the rest is generated and gitignored. Foundry's
#                         artifact layout additionally creates DIRECTORIES named
#                         "*.sol" under out/, which is why they must be pruned.
#                         Nothing git-trackable lives here, so exclusion is safe
#                         unconditionally.
#   LOA_ZONE_PRUNE        Loa framework/state zones, never compiled — but
#                         git-TRACKABLE. Pruning them for walk cost alone would
#                         leave a place where a `.sol` file sits unclassified and
#                         is still pulled into the build by an explicit import
#                         from a declared VUX root. They are therefore pruned AND
#                         asserted Solidity-free (`loa_zone_solidity`), so the
#                         exemption is conditional, not a hole.
#
# Nothing else is excluded. `lib/` (Foundry's conventional dependency directory)
# and `node_modules/` are deliberately IN scope — an unauthorized dependency
# landing there is exactly the failure this boundary exists to catch.
BUILD_ARTIFACT_PRUNE=(.git out out-v3core cache cache-v3core broadcast)
LOA_ZONE_PRUNE=(.claude grimoires .beads .run .ck)
SOURCE_UNIVERSE_PRUNE=("${BUILD_ARTIFACT_PRUNE[@]}" "${LOA_ZONE_PRUNE[@]}")

# Foundry's artifact output directories, one per declared compilation unit
# (foundry.toml `[profile.default] out` and `[profile.v3core] out`). These are the
# only places the toolchain records what it compiled, so they are the evidence
# base for compiled_sources() below — and they are pruned from the filesystem
# walk above, which is why the two halves cannot collide.
BUILD_OUT_DIRS=(out out-v3core)

# Every source file the ACCEPTED TOOLCHAIN actually compiled — the half of the
# universe that is extension-independent by construction.
#
# Why this exists (sprint-2 audit M-1, escalated by the Foundry v1.5.0 refreeze
# §4.1): the walk below decides membership from a FILENAME predicate, and no
# filename predicate can be complete. Foundry v1.5.0 admits an imported Solidity
# source whose name is `Payload.txt` or has no extension at all — it reaches
# solc, appears in the artifact's `metadata.sources`, is embedded in the
# importing contract, and executes from a deployed instance. Under the
# superseded v1.0.0 orchestrator the same import was refused outright
# ("unexpected file extension"), so this is a reachable form the accepted
# toolchain move CREATED rather than inherited.
#
# Widening the extension allowlist cannot fix that — it only moves the boundary
# to the next unenumerated name. This asks the compiler instead: solc records in
# every artifact's `metadata.sources` the exact set of files that produced it,
# keyed by the path it resolved, repo-relative and forward-slashed. That record
# is the toolchain's own answer to "what did you compile?", and it is keyed on
# nothing that a rename can change.
#
# Complement, never replacement: this half cannot see a dormant unauthorized file
# that nothing imports, which is exactly what the filesystem walk is good at.
# Both are needed, which is why source_universe() is their union.
#
# Freshness contract: this reads the artifacts of the LAST build, so the callers
# that must not miss a newly-imported source build first — run-all.sh compiles
# both units before any gate, and both negative demonstrations compile at
# baseline and again around every probe that changes the compilation graph.
# verify-census.sh fails closed when a unit has produced no artifacts at all, so
# the compiled half can never silently degrade to empty.
#
# With no arguments, scans every declared unit; with arguments, only those.
compiled_sources() {
  local dirs=("$@") d present=()
  (( ${#dirs[@]} > 0 )) || dirs=("${BUILD_OUT_DIRS[@]}")
  for d in "${dirs[@]}"; do [[ -d "$REPO_ROOT/$d" ]] && present+=("$d"); done
  (( ${#present[@]} > 0 )) || return 0
  ( cd "$REPO_ROOT" && find "${present[@]}" -name '*.json' -not -path '*/build-info/*' -print0 2>/dev/null \
    | xargs -0 -r jq -r 'if has("metadata") then (.metadata.sources | keys[]) else empty end' 2>/dev/null ) \
    | tr -d '\r' | sed 's|\\|/|g; s|^\./||' | sed '/^$/d' | LC_ALL=C sort -u
}

# Every Solidity-NAMED file in the working tree: repo-relative, forward-slashed,
# sorted. Symlinks are included on purpose — a symlinked *.sol is still source a
# compiler would follow, and `-type f` alone would make it invisible to every gate.
#
# Extension matching is case-INSENSITIVE, and that is load-bearing rather than
# defensive breadth (sprint-2 audit A-1). solc resolves an import through its own
# filesystem callback against the import string byte-for-byte, so `Foo.SOL` is
# real compiled source: it appears in the artifact's `metadata.sources`, its code
# is embedded in the importing contract, and a deployed instance executes it. A
# case-SENSITIVE walk made this universe narrower than the compiler's actual
# reach, and every consumer derived from it — default-deny classification
# (classify_sources), prohibited-source scanning, SPDX, the §17 quarantine —
# inherited that blind spot, while `loa_zone_solidity` below already matched
# case-insensitively. The union in source_universe() now governs every consumer
# on the same terms, so they can no longer disagree about what counts as source.
#
# This retracts the sprint-1 audit's N-2 refutation, which read Foundry's
# "Unable to resolve imports" warning as proof that `Foo.SOL` was
# build-unreachable. That warning comes from Foundry's PRE-resolution
# source-graph walker and is printed in the same run as `Compiler run
# successful!` — a resolver diagnostic describes the tool's discovery pass, never
# what compiled. demo-boundary-negative.sh's build-reachability control proves
# the premise from compiler metadata and execution instead.
filesystem_sol_sources() {
  local prune=() p
  for p in "${SOURCE_UNIVERSE_PRUNE[@]}"; do prune+=(-path "./$p" -o); done
  find . \( "${prune[@]}" -false \) -prune -o \( -type f -o -type l \) -iname '*.sol' -print 2>/dev/null \
    | sed 's|^\./||; s|\\|/|g' | sed '/^$/d' | LC_ALL=C sort
}

# THE authoritative source universe — the one definition every provenance-
# sensitive gate consumes. Two independent bodies of evidence, unioned:
#
#   filesystem_sol_sources()  what the tree LOOKS like  — catches dormant source
#                             nothing imports, at the cost of a name predicate
#   compiled_sources()        what the toolchain COMPILED — extension-independent,
#                             at the cost of seeing only what is imported
#
# Each covers the other's blind spot, and neither is authoritative alone. A file
# admitted by either is classified by classify_sources() and reaches every
# consumer (default-deny, prohibited-source scanning, SPDX, the §17 quarantine)
# on identical terms, so the consumers can no longer disagree about what counts
# as source.
source_universe() {
  { filesystem_sol_sources; compiled_sources; } | sed '/^$/d' | LC_ALL=C sort -u
}

# Every Solidity-shaped file inside a pruned Loa/state zone. Empty is the only
# acceptable answer, and `verify-census.sh` fails loudly when it is not.
#
# Why this exists (sprint-1 audit finding N-1): those zones are git-trackable, so
# a `.sol` placed in one is invisible to classify_sources — and an out-of-root
# `.sol` IS compiled and emitted as an artifact when a file inside a declared VUX
# root imports it explicitly (audit-executed reachability probe). Pruning is kept
# for walk cost; the assertion is what makes the prune safe.
#
# Matching is case-insensitive, as it always was here — this is a "nothing
# Solidity-shaped lives here" claim, and breadth is free when the only correct
# answer is zero. The universe walk above now matches on the same terms
# (sprint-2 audit A-1); previously this assertion was BROADER than the primary
# boundary it guards, which is the inverse of the intended relationship.
loa_zone_solidity() {
  local z present=()
  for z in "${LOA_ZONE_PRUNE[@]}"; do [[ -d "$REPO_ROOT/$z" ]] && present+=("$z"); done
  (( ${#present[@]} > 0 )) || return 0
  ( cd "$REPO_ROOT" && find "${present[@]}" \( -type f -o -type l \) -iname '*.sol' -print 2>/dev/null ) \
    | sed 's|\\|/|g' | LC_ALL=C sort
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

# Every source file the project OWNS — the declared VUX roots plus anything that
# escaped them, on both universe halves, so a compiler-admitted file that is not
# named `*.sol` is held to authored-source policy rather than opting out of it.
# Vendored upstream is excluded: its bytes are frozen by the drift gate, so
# authored-source policy (SPDX, §17) does not apply to it.
vux_owned_sources() { classify_sources | awk -F'\t' '$1 != "vendored" { print $2 }'; }

# grep over a newline-delimited file list, tolerating an empty list. -H is
# supplied by callers where the path must appear even for a single-file list.
grep_sources() {
  local list="$1"; shift
  [[ -n "$list" ]] || return 0
  printf '%s\n' "$list" | sed '/^$/d' | xargs -r -d '\n' grep "$@" 2>/dev/null || true
}
