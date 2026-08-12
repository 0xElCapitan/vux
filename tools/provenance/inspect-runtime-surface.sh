#!/usr/bin/env bash
# Gate 8 — deployed-surface and runtime-capability inspection.
#
# The Hard Reserve's safety rests on two claims about what the DEPLOYED contract
# can do, and both are claims about compiled output rather than about source:
#
#   1. its entire state-changing external surface is `redeem`;
#   2. the constructor's WETH transfer-out capability does not survive into the
#      runtime bytecode.
#
# The forge suite (test/reserve/HardReserveSurface.t.sol) asserts both in CI.
# This script asserts them AGAIN with an implementation that shares no code with
# it — jq and awk over the build artifacts, no Solidity, no test runner, no
# `Artifact.sol` — and prints the underlying numbers so a reviewer or auditor can
# read the evidence instead of trusting a green check. Two independent
# implementations agreeing is the point; one of them being wrong in the same way
# as the other is the failure mode this rules out.
#
# It is also a fail-closed gate, not just a report: any violation exits non-zero.
#
# Usage: tools/provenance/inspect-runtime-surface.sh
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
cd "$REPO_ROOT"

RESERVE_ARTIFACT="out/HardReserve.sol/HardReserve.json"
VUX_ARTIFACT="out/VUX.sol/VUX.json"

# Accepted external surfaces. Any addition or removal is a deliberate,
# reviewable edit here as well as in the Solidity suite.
RESERVE_ABI="S_MIN() backing() previewRedeem(uint256) redeem(uint256,address) vux() weth()"
VUX_ABI="DOMAIN_SEPARATOR() GENESIS_POL_SUPPLY() GENESIS_RESERVE_SEED() allowance(address,address) \
approve(address,uint256) balanceOf(address) burn(uint256) burnForRedemption(address,uint256) decimals() \
eip712Domain() mint(address,uint256) name() nonces(address) \
permit(address,address,uint256,uint256,uint8,bytes32,bytes32) reserve() rig() symbol() totalSupply() \
transfer(address,uint256) transferFrom(address,address,uint256)"

# keccak256("PreGenesisWethSanitized(uint256)") — the sanitization path's unique
# 32-byte marker. Recomputed below with `cast` when available, so the constant
# cannot silently rot; the check does not depend on `cast` being installed.
SANITIZED_TOPIC="6e819700d501e9b84b099d0e58ba58b903458fcd121aeea3074dc83521a872a8"

for f in "$RESERVE_ARTIFACT" "$VUX_ARTIFACT"; do
  [[ -f "$f" ]] || { fail "build artifact missing: $f (run: forge build)"; finish; }
done

# --- authority-of-the-constant check ----------------------------------------
if command -v cast >/dev/null 2>&1; then
  recomputed="$(cast keccak 'PreGenesisWethSanitized(uint256)' | sed 's/^0x//')"
  if [[ "$recomputed" != "$SANITIZED_TOPIC" ]]; then
    fail "SANITIZED_TOPIC is stale: recorded $SANITIZED_TOPIC, keccak256 is $recomputed"
  else
    pass "sanitization event topic recomputed from its signature"
  fi
else
  warn "cast unavailable — using the recorded event topic without recomputation"
fi

# --- sorted external signature set, straight from the dispatcher table -------
signatures_of() { jq -r '.methodIdentifiers | keys[]' "$1" | tr -d '\r' | LC_ALL=C sort; }

check_surface() {
  local label="$1" artifact="$2" accepted="$3" actual expected extra missing
  actual="$(signatures_of "$artifact")"
  expected="$(printf '%s\n' $accepted | LC_ALL=C sort)"
  extra="$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))"
  missing="$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))"

  info "$label external functions: $(printf '%s\n' "$actual" | wc -l | tr -d ' ')"
  if [[ -n "$extra" ]]; then
    while IFS= read -r s; do fail "$label exposes an unaccepted external function: $s"; done <<< "$extra"
  fi
  if [[ -n "$missing" ]]; then
    while IFS= read -r s; do fail "$label is missing an accepted external function: $s"; done <<< "$missing"
  fi
  [[ -n "$extra$missing" ]] || pass "$label external surface is exactly the accepted set"
}

echo "== external surfaces (compiled dispatcher tables) =="
check_surface "HardReserve" "$RESERVE_ARTIFACT" "$RESERVE_ABI"
check_surface "VUX"         "$VUX_ARTIFACT"     "$VUX_ABI"

# --- Reserve: exactly one state-changing function, and nothing payable -------
echo
echo "== HardReserve mutability profile (ABI stateMutability) =="
mutators="$(jq -r '[.abi[] | select(.type == "function" and .stateMutability != "view" and .stateMutability != "pure") | .name] | join(" ")' "$RESERVE_ARTIFACT" | tr -d '\r')"
if [[ "$mutators" != "redeem" ]]; then
  fail "HardReserve state-changing functions are '$mutators', accepted is exactly 'redeem'"
else
  pass "exactly one state-changing function: redeem"
fi

payables="$(jq -r '[.abi[] | select(.stateMutability == "payable") | (.type + ":" + (.name // "-"))] | join(" ")' "$RESERVE_ARTIFACT" | tr -d '\r')"
[[ -z "$payables" ]] && pass "no payable function" || fail "payable surface present: $payables"

hooks="$(jq -r '[.abi[] | select(.type == "receive" or .type == "fallback") | .type] | join(" ")' "$RESERVE_ARTIFACT" | tr -d '\r')"
[[ -z "$hooks" ]] && pass "no receive() and no fallback()" || fail "ether-accepting hook present: $hooks"

# --- VUX: no allowance-gated burn -------------------------------------------
echo
echo "== VUX burn surface =="
burns="$(signatures_of "$VUX_ARTIFACT" | grep -i 'burn' || true)"
info "burn-family signatures: $(printf '%s' "$burns" | tr '\n' ' ')"
if printf '%s\n' "$burns" | grep -q 'burnFrom'; then
  fail "a burnFrom-style allowance-gated burn is dispatchable"
else
  pass "no burnFrom in the dispatcher table"
fi
# Positive control: the scan is capable of finding a burn signature.
printf '%s\n' "$burns" | grep -q 'burnForRedemption' \
  || fail "positive control failed — the burn-family scan found nothing at all"

# --- runtime bytecode --------------------------------------------------------
echo
echo "== HardReserve runtime bytecode =="
creation="$(jq -r '.bytecode.object' "$RESERVE_ARTIFACT" | tr -d '\r' | sed 's/^0x//')"
deployed="$(jq -r '.deployedBytecode.object' "$RESERVE_ARTIFACT" | tr -d '\r' | sed 's/^0x//')"
info "creation code ${#creation} hex chars ($(( ${#creation} / 2 )) bytes); runtime ${#deployed} hex chars ($(( ${#deployed} / 2 )) bytes)"

# Positive control first: a search that cannot find the marker where it IS
# present would "prove" the absence claim below by being broken.
case "$creation" in
  *"$SANITIZED_TOPIC"*) pass "sanitization marker present in the CREATION bytecode (positive control)" ;;
  *) fail "sanitization marker absent from the creation bytecode — the search or the build is wrong, so the absence result below means nothing" ;;
esac
case "$deployed" in
  *"$SANITIZED_TOPIC"*) fail "sanitization marker SURVIVES into the deployed runtime bytecode" ;;
  *) pass "sanitization marker absent from the DEPLOYED runtime bytecode — the capability did not survive deployment" ;;
esac

# Opcode census over the runtime image, metadata stripped. Written without
# gawk's strtonum so it behaves identically under mawk on CI runners.
echo
echo "== HardReserve runtime opcode census (metadata stripped) =="
opcode_census="$(printf '%s\n' "$deployed" | awk '
  function hexval(c,   p) { p = index("0123456789abcdef", tolower(c)); return p - 1 }
  function byteat(s, i) { return hexval(substr(s, i * 2 + 1, 1)) * 16 + hexval(substr(s, i * 2 + 2, 1)) }
  {
    code = $0
    n = length(code) / 2
    # solc appends CBOR metadata plus a two-byte big-endian length of it. Those
    # bytes are data; walking them as instructions invents opcodes at random.
    if (n >= 2) {
      metalen = byteat(code, n - 2) * 256 + byteat(code, n - 1)
      if (metalen > 0 && metalen + 2 <= n) n = n - metalen - 2
    }
    body = n
    i = 0
    while (i < n) {
      op = byteat(code, i)
      count[op]++
      if (op >= 96 && op <= 127) i += op - 95   # skip PUSH1..PUSH32 immediates
      i++
    }
    printf "body=%d create=%d callcode=%d delegatecall=%d create2=%d selfdestruct=%d call=%d staticcall=%d\n",
      body, count[240], count[242], count[244], count[245], count[255], count[241], count[250]
  }')"
info "$opcode_census"

read_field() { printf '%s\n' "$opcode_census" | tr ' ' '\n' | grep "^$1=" | cut -d= -f2; }

body="$(read_field body)"
(( body > 0 )) || fail "metadata stripping left no program body — the opcode census would be vacuous"
(( body < ${#deployed} / 2 )) || fail "metadata stripping removed nothing — the census may be walking data as code"

# Positive controls: the walk must see the calls the Reserve genuinely makes.
(( $(read_field call) > 0 ))       || fail "positive control failed — no CALL found, yet redeem transfers WETH"
(( $(read_field staticcall) > 0 )) || fail "positive control failed — no STATICCALL found, yet redeem reads balanceOf"
pass "opcode walk verified against known-present opcodes (CALL, STATICCALL)"

for forbidden in create:"no CREATE (deploys no successor)" \
                 create2:"no CREATE2 (deploys no successor)" \
                 callcode:"no CALLCODE" \
                 delegatecall:"no DELEGATECALL (no proxy or upgrade path)" \
                 selfdestruct:"no SELFDESTRUCT"; do
  key="${forbidden%%:*}"; desc="${forbidden#*:}"
  if (( $(read_field "$key") > 0 )); then
    fail "$key present in the deployed runtime — structural absence claim broken"
  else
    pass "$desc"
  fi
done

finish
