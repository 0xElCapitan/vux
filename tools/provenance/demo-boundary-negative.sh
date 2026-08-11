#!/usr/bin/env bash
# Negative demonstration — unauthorized source placed OUTSIDE the accepted
# census and the declared VUX source roots MUST fail the provenance gates
# (sprint.md Sprint 1 acceptance criteria 1 and 4).
#
# Sibling of demo-drift-negative.sh. That one proves the fence closes on a
# one-byte mutation of authorized bytes; this one proves it closes on the other
# axis — authorized-looking bytes in an unauthorized *place*, and prohibited
# material that tries to escape detection by choosing a different directory.
#
# Every probe is planted, proven to fail for the RIGHT reason (not merely to
# fail), removed, and the gate proven green again — the same fence-closes-and-
# reopens discipline that makes the drift demonstration trustworthy. Probe roots
# are removed unconditionally via a trap and the working-tree inventory is
# compared before and after, so the tree is never left dirty even if the run is
# interrupted.
#
# Usage: tools/provenance/demo-boundary-negative.sh
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/../.."

# Probe roots. Both are chosen because they are the conventional places
# unauthorized source actually lands: contracts/ is the Hardhat convention and
# lib/ is Foundry's dependency directory — neither was in any gate's scope
# before this remediation.
PROBE_ROOTS=(contracts lib)

for r in "${PROBE_ROOTS[@]}"; do
  if [[ -e "$r" ]]; then
    echo "refusing to run: probe root ./$r already exists — this script would delete it" >&2
    exit 2
  fi
done

cleanup() { local r; for r in "${PROBE_ROOTS[@]}"; do rm -rf "./${r:?}"; done; }
trap cleanup EXIT

INVENTORY_BEFORE="$(git status --porcelain --untracked-files=all | LC_ALL=C sort | sha256sum | cut -d' ' -f1)"

status=0
note() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*" >&2; status=1; }

# Run a gate, require it to FAIL, and require the failure to be the boundary
# violation rather than a broken probe setup.
expect_fail() {
  local gate="$1" reason="$2" label="$3" out rc
  out="$(bash "$HERE/$gate" 2>&1)"; rc=$?
  if (( rc == 0 )); then
    bad "$gate PASSED with the probe present — the fence is open [$label]"
    return
  fi
  if ! printf '%s\n' "$out" | grep -qE "$reason"; then
    bad "$gate failed (exit $rc) but not for the boundary reason [$label]; expected /$reason/, got:"
    printf '%s\n' "$out" | grep -E 'FAIL' | head -4 >&2
    return
  fi
  ok "$gate failed closed for the right reason [$label] (exit $rc)"
  printf '%s\n' "$out" | grep -E "$reason" | head -2 | cut -c1-150 | sed 's/^/          /'
}

expect_green() {
  local gate="$1"
  if bash "$HERE/$gate" >/dev/null 2>&1; then
    ok "$gate green again after probe removal"
  else
    bad "$gate still red after probe removal — the tree was not restored"
  fi
}

unplant() { local r; for r in "${PROBE_ROOTS[@]}"; do rm -rf "./${r:?}"; done; }

# --- baseline ---------------------------------------------------------------
note "baseline — every gate this demonstration exercises must be green first"
for g in verify-census.sh verify-spdx.sh verify-quarantine.sh; do
  if bash "$HERE/$g" >/dev/null 2>&1; then ok "$g green before any probe"; else bad "$g is already red"; fi
done
if (( status != 0 )); then
  echo "aborting: baseline is not green, so nothing could be demonstrated." >&2
  exit 1
fi

# An authorized donor: with the census gate green above, every file under
# vendor/ is provably an enumerated census row, so this is byte-identical
# accepted upstream source. No accepted census row declares GPL-3.0-or-later
# (refreeze §3 MIT / §4 9 BUSL-1.1 + 22 GPL-2.0-or-later + 1 MIT / PROV-2 MIT),
# which is what makes the SPDX assertion in probe 1 deterministic.
DONOR="$(find vendor -type f -name '*.sol' | LC_ALL=C sort | head -1)"
[[ -f "$DONOR" ]] || { echo "no vendored donor file found" >&2; exit 2; }
printf '\ndonor (authorized, byte-identical census row): %s\n' "$DONOR"

# --- probe 1 — authorized bytes, unauthorized location ----------------------
note "probe 1 — byte-identical AUTHORIZED upstream source in an unauthorized location"
mkdir -p contracts/vendored
cp "$DONOR" "contracts/vendored/$(basename "$DONOR")"
echo "  planted: contracts/vendored/$(basename "$DONOR")  (bytes identical to an accepted census row)"
expect_fail verify-census.sh 'unauthorized Solidity source' "out-of-root vendored copy"
# The same derived list governs SPDX, so a new source root cannot opt out of it.
expect_fail verify-spdx.sh   'declares SPDX'                "out-of-root vendored copy, SPDX reach"
unplant
expect_green verify-census.sh
expect_green verify-spdx.sh

# --- probe 2 — excluded implementation, relocated ---------------------------
note "probe 2 — refreeze §8 excluded implementation relocated out of the old scan roots"
mkdir -p contracts/impl
cp "$DONOR" contracts/impl/UniswapV3Factory.sol
echo "  planted: contracts/impl/UniswapV3Factory.sol"
expect_fail verify-census.sh 'UniswapV3Factory\.sol implementation present' "Factory name detector, relocated"
unplant
expect_green verify-census.sh

# --- probe 3 — prohibited sources, relocated --------------------------------
note "probe 3 — prohibited-source references relocated out of the old scan roots"
mkdir -p contracts/research
{
  echo '// SPDX-License-Identifier: GPL-3.0-or-later'
  echo 'pragma solidity =0.8.28;'
  echo '// adapted from Olympus, gumball6900, and give.fun'
  echo 'contract Probe {}'
} > contracts/research/Probe.sol
echo "  planted: contracts/research/Probe.sol  (Olympus / gumball6900 / give.fun)"
expect_fail verify-census.sh 'prohibited-source reference' "prohibited sources, relocated"
unplant
expect_green verify-census.sh

# --- probe 4 — v3-periphery, relocated --------------------------------------
note "probe 4 — v3-periphery code use relocated out of the old scan roots"
mkdir -p contracts/periphery
cp "$DONOR" contracts/periphery/PoolAddress.sol
echo "  planted: contracts/periphery/PoolAddress.sol"
expect_fail verify-census.sh 'v3-periphery code use detected' "periphery detector, relocated"
unplant
expect_green verify-census.sh

# --- probe 5 — Foundry's conventional dependency directory ------------------
note "probe 5 — an unauthorized dependency in lib/, Foundry's conventional location (AC-8, forge-std)"
mkdir -p lib/forge-std/src
{
  echo '// SPDX-License-Identifier: MIT'
  echo 'pragma solidity >=0.6.2;'
  echo 'contract Test {}'
} > lib/forge-std/src/Test.sol
echo "  planted: lib/forge-std/src/Test.sol"
expect_fail verify-census.sh 'unauthorized Solidity source' "forge-std in lib/"
unplant
expect_green verify-census.sh

# --- probe 6 — §17 quarantine, relocated ------------------------------------
note "probe 6 — PRD §17 research-guidance value relocated out of the old quarantine scope"
mkdir -p contracts/policy
{
  echo '// SPDX-License-Identifier: GPL-3.0-or-later'
  echo 'pragma solidity =0.8.28;'
  # Interpolated so THIS script does not itself carry the literal it plants —
  # tools/ is inside the quarantine gate's own scope.
  printf 'contract Policy { uint256 internal constant READINESS = %d days; }\n' 60
} > contracts/policy/Policy.sol
echo "  planted: contracts/policy/Policy.sol"
expect_fail verify-quarantine.sh 'guidance value present as implementation authority' "§17 value, relocated"
unplant
expect_green verify-quarantine.sh

# --- restoration ------------------------------------------------------------
note "restoration"
cleanup
trap - EXIT
INVENTORY_AFTER="$(git status --porcelain --untracked-files=all | LC_ALL=C sort | sha256sum | cut -d' ' -f1)"
if [[ "$INVENTORY_AFTER" == "$INVENTORY_BEFORE" ]]; then
  ok "working-tree inventory identical to pre-probe state ($INVENTORY_AFTER)"
else
  bad "working-tree inventory changed: $INVENTORY_BEFORE -> $INVENTORY_AFTER"
fi
for r in "${PROBE_ROOTS[@]}"; do
  if [[ -e "$r" ]]; then bad "probe root ./$r survived cleanup"; else ok "probe root ./$r removed"; fi
done
for g in verify-census.sh verify-spdx.sh verify-quarantine.sh; do expect_green "$g"; done

printf '\n'
if (( status == 0 )); then
  printf '\033[32mSource-boundary fence proven closed on all 6 probes, and reopened.\033[0m\n'
else
  printf '\033[31mSource-boundary demonstration FAILED.\033[0m\n' >&2
fi
exit "$status"
