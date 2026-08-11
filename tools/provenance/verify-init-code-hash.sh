#!/usr/bin/env bash
# Gate 7 — deterministic POOL_INIT_CODE_HASH reproduction (refreeze §7).
#
# Builds the vendored =0.7.6 unit with the accepted settings and asserts the
# resulting UniswapV3Pool creation bytecode hashes to the accepted constant.
# The assertion itself lives in test/provenance/PoolInitCodeHash.t.sol so that
# `forge test` alone is already fail-closed on this; this script is the
# self-contained CI entry point.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
cd "$REPO_ROOT"

echo "== building the vendored =$SOLC_V3_VERSION unit =="
if ! FOUNDRY_PROFILE=v3core forge build --force; then
  fail "vendored v3-core unit failed to compile under solc $SOLC_V3_VERSION"
  finish
fi

ARTIFACT="out-v3core/UniswapV3Pool.sol/UniswapV3Pool.json"
if [[ ! -f "$ARTIFACT" ]]; then
  fail "pool artifact not produced: $ARTIFACT"
  finish
fi

compiler="$(jq -r '.metadata.compiler.version' "$ARTIFACT" | tr -d '\r')"
if [[ "$compiler" != "$SOLC_V3_VERSION+commit.${SOLC_V3_COMMIT:0:8}" ]]; then
  fail "pool compiled by '$compiler', pin requires $SOLC_V3_VERSION+commit.${SOLC_V3_COMMIT:0:8}"
else
  pass "pool compiled by $compiler"
fi

echo
echo "== reproducing POOL_INIT_CODE_HASH =="
info "accepted: $POOL_INIT_CODE_HASH"
if forge test --match-path 'test/provenance/PoolInitCodeHash.t.sol' -vv; then
  pass "POOL_INIT_CODE_HASH reproduced and equal to the accepted constant"
else
  fail "POOL_INIT_CODE_HASH reproduction FAILED — the vendored unit no longer
        produces the accepted creation bytecode. Per refreeze §7 obligation 3,
        any compiler or bytecode-affecting settings change requires a new
        operator-accepted refreeze; do NOT edit the accepted constant."
fi

finish
