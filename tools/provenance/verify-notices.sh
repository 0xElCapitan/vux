#!/usr/bin/env bash
# Gate 4 — LICENSE and THIRD_PARTY_NOTICES integrity (PROV-8, NFR-COMP).
#
# The GPL notice obligations survive conveyance only if the notices are actually
# present and unaltered, so both the file identity and the specific upstream
# notice text the refreeze requires are checked.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
cd "$REPO_ROOT"

echo "== project licence =="
if [[ ! -f LICENSE ]]; then
  fail "LICENSE missing — the project licence is GPL-3.0-or-later"
elif ! grep -q 'GNU GENERAL PUBLIC LICENSE' LICENSE || ! grep -q 'Version 3, 29 June 2007' LICENSE; then
  fail "LICENSE is not the GNU GPL version 3 text"
else
  pass "LICENSE is the GNU GPL v3 text"
fi

echo
echo "== THIRD_PARTY_NOTICES.md =="
require_authority "$TPN" "$TPN_SHA256"
(( FAILURES > 0 )) || pass "THIRD_PARTY_NOTICES.md matches the accepted baseline SHA-256"

# Required notice content (refreeze §3/§4 — the verbatim upstream statements
# that must survive conveyance of the combined GPL work).
declare -a required=(
  'Copyright (c) 2016-2024 Zeppelin Group Ltd'
  'The Licensed Work is (c) 2021 Uniswap Labs'
  'Business Source License 1.1'
  'GPL-2.0-or-later'
)
for text in "${required[@]}"; do
  if grep -qF "$text" "$TPN"; then
    pass "notice present: ${text:0:48}"
  else
    fail "required upstream notice missing from $TPN: $text"
  fi
done

# Every vendored dependency family must be named in the notices.
# Case-sensitive -F on purpose: the Git Bash grep build aborts (SIGABRT) on the
# `-i` + `-F` combination, and these strings appear verbatim in the notices.
for name in 'openzeppelin-contracts' 'Uniswap/v3-core' 'miner-manifold'; do
  if grep -qF "$name" "$TPN"; then
    pass "notices cover $name"
  else
    fail "vendored dependency absent from $TPN: $name"
  fi
done

finish
