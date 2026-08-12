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
# Probes 8-11 add the *naming* axis (sprint-2 audit A-1): source that stays put
# but changes what it is CALLED, by varying only the case of its extension.
# Probe 12 is a POSITIVE control for those four — it proves from compiler
# evidence that a mixed-case extension really is build-reachable, so the negative
# probes cannot degrade into asserting that the gate catches something harmless.
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

# Probe 7 lives INSIDE a real, populated directory (a pruned Loa state zone), so
# it cannot be a probe *root*: removing a root there would delete real work. It
# is a single file, refused if it already exists and deleted by exact path.
ZONE_PROBE="grimoires/loa/boundary-probe-zone.sol"

# Probes 8-10 (audit A-1) also land inside real, populated directories — the
# repository root, docs/, and a pruned Loa zone — so they are exact single-file
# paths under the same refuse-if-present / delete-by-exact-path discipline.
# Their stems are DISTINCT rather than case variants of one stem: on a
# case-insensitive filesystem `x.sol` and `x.SOL` name the same file, which would
# make the probe set ambiguous exactly where the audit's proof-of-concept ran.
CASE_PROBES=(
  "ProvenanceCaseProbeRoot.SOL"
  "docs/provenance-case-probe-docs.SoL"
  "grimoires/loa/boundary-probe-zone-case.sOl"
)

# Throwaway Foundry project for the probe-12 control, created OUTSIDE the
# repository so a compiler invocation cannot perturb the working-tree inventory.
SCRATCH=""

for r in "${PROBE_ROOTS[@]}"; do
  if [[ -e "$r" ]]; then
    echo "refusing to run: probe root ./$r already exists — this script would delete it" >&2
    exit 2
  fi
done
for f in "$ZONE_PROBE" "${CASE_PROBES[@]}"; do
  if [[ -e "$f" ]]; then
    echo "refusing to run: $f already exists — this script would delete it" >&2
    exit 2
  fi
done

cleanup() {
  local r f
  for r in "${PROBE_ROOTS[@]}"; do rm -rf "./${r:?}"; done
  rm -f "./${ZONE_PROBE:?}"
  for f in "${CASE_PROBES[@]}"; do rm -f "./${f:?}"; done
  [[ -n "$SCRATCH" ]] && rm -rf "$SCRATCH"
  return 0
}
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

unplant() {
  local r f
  for r in "${PROBE_ROOTS[@]}"; do rm -rf "./${r:?}"; done
  rm -f "./${ZONE_PROBE:?}"
  for f in "${CASE_PROBES[@]}"; do rm -f "./${f:?}"; done
}

# Minimal, syntactically valid Solidity. Probes must fail the gate on provenance
# grounds — `expect_fail` checks the REASON, so an unparseable probe would be
# caught, but writing valid source keeps the failure unambiguous at a glance.
plant_sol() {
  local path="$1" body="$2"
  mkdir -p "$(dirname "$path")"
  {
    echo '// SPDX-License-Identifier: GPL-3.0-or-later'
    echo 'pragma solidity =0.8.28;'
    printf '%s\n' "$body"
  } > "$path"
}

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

# --- probe 7 — pruned Loa/state zone (sprint-1 audit N-1) -------------------
# The other six probes attack places the boundary LOOKS at. This one attacks the
# one place it deliberately does not: the prune list. grimoires/ is git-trackable,
# so before this assertion a .sol committed there was classified by nobody while
# remaining compilable via an explicit import from src/ or test/.
note "probe 7 — unauthorized source inside a pruned Loa/state zone (audit N-1)"
{
  echo '// SPDX-License-Identifier: GPL-3.0-or-later'
  echo 'pragma solidity =0.8.28;'
  echo 'contract ZoneProbe { function drain(address to) external {} }'
} > "$ZONE_PROBE"
echo "  planted: $ZONE_PROBE  (inside a pruned zone — invisible to the source walk)"
expect_fail verify-census.sh 'pruned Loa/state zone' "unclassifiable .sol in a pruned trackable zone"
unplant
expect_green verify-census.sh

# --- probes 8-10 — the naming axis: extension case (sprint-2 audit A-1) ------
# Probes 1-7 attack WHERE unauthorized source sits. These attack what it is
# CALLED. Before this remediation `source_universe()` matched `-name '*.sol'`
# case-sensitively while the zone assertion it guards matched `-iname`, so a
# git-trackable `Evil.SOL` was classified by nobody, scanned by no detector, and
# still compiled the moment a declared source root imported it — the same
# unclassifiable-yet-build-reachable shape as N-1, on the naming axis instead of
# the location axis. Three locations, three distinct casings, so a partial fix
# (one directory, one casing) cannot pass this section.
note "probe 8 — mixed-case extension at the repository root (.SOL)"
plant_sol "${CASE_PROBES[0]}" 'contract CaseProbeRoot { function drain(address to) external {} }'
echo "  planted: ${CASE_PROBES[0]}  (repository root — differs from .sol only in case)"
expect_fail verify-census.sh 'unauthorized Solidity source' "repository root, .SOL"
unplant
expect_green verify-census.sh

note "probe 9 — mixed-case extension in an ordinary trackable non-source directory (.SoL)"
plant_sol "${CASE_PROBES[1]}" 'contract CaseProbeDocs { function drain(address to) external {} }'
echo "  planted: ${CASE_PROBES[1]}  (docs/ — git-trackable, never pruned, never a declared source root)"
expect_fail verify-census.sh 'unauthorized Solidity source' "docs/, .SoL"
unplant
expect_green verify-census.sh

# This one is reached by `loa_zone_solidity`, not by the universe walk — it was
# already case-insensitive, which is precisely how the asymmetry was found.
# Probing it anyway keeps the two halves of the boundary asserted on equal terms.
note "probe 10 — mixed-case extension inside a pruned Loa/state zone (.sOl)"
plant_sol "${CASE_PROBES[2]}" 'contract CaseProbeZone { function drain(address to) external {} }'
echo "  planted: ${CASE_PROBES[2]}  (pruned zone — reached by the zone assertion, not the walk)"
expect_fail verify-census.sh 'pruned Loa/state zone' "pruned Loa zone, .sOl"
unplant
expect_green verify-census.sh

# --- probe 11 — the prohibited-source detector, behind a mixed-case extension -
# `all_sources` is derived from the same universe, so A-1 blinded the §8
# prohibited-source scan too. Proving the default-deny catch alone would not
# prove that this consumer recovered — it is a separate grep over the same list.
note "probe 11 — prohibited-source reference hidden behind a mixed-case extension"
plant_sol "contracts/research/CaseProbe.SOL" '// adapted from Olympus, gumball6900, and give.fun
contract CaseProbeProhibited {}'
echo "  planted: contracts/research/CaseProbe.SOL  (Olympus / gumball6900 / give.fun)"
expect_fail verify-census.sh 'prohibited-source reference' "prohibited sources, .SOL extension"
unplant
expect_green verify-census.sh

# --- probe 12 — POSITIVE control: the premise, taken from the compiler --------
# Probes 8-11 prove the gates now SEE a case-variant extension. That only matters
# if such a file genuinely becomes part of a build — and the sprint-1 audit
# concluded the opposite (finding N-2, since retracted), reading Foundry's
# "Unable to resolve imports" warning as proof of unreachability. That warning
# comes from Foundry's PRE-resolution source-graph walker and is printed in the
# same run as "Compiler run successful!": solc resolves the import separately,
# through its own filesystem callback, against the import string byte-for-byte.
#
# This control therefore refuses to read any resolver diagnostic as evidence. It
# builds a throwaway project OUTSIDE the repository — so it cannot perturb the
# working-tree inventory checked below — and takes its verdict from two
# compiler-authoritative facts: solc's own record of what it compiled
# (`metadata.sources`), and an executed deployment of the imported contract.
note "probe 12 — POSITIVE control: a mixed-case-extension .SOL is compiled AND executes"
if ! command -v forge >/dev/null 2>&1; then
  bad "forge is not on PATH — the build-reachability premise behind probes 8-11 cannot be demonstrated"
else
  SCRATCH="$(mktemp -d)"
  mkdir -p "$SCRATCH/src" "$SCRATCH/test"
  cat > "$SCRATCH/foundry.toml" <<'TOML'
[profile.default]
src = "src"
test = "test"
out = "out"
libs = []
solc = "0.8.28"
TOML
  cat > "$SCRATCH/src/CaseReach.SOL" <<'SOLFILE'
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

contract CaseReach {
    function answer() external pure returns (uint256) {
        return 42;
    }
}
SOLFILE
  cat > "$SCRATCH/test/CaseReach.t.sol" <<'SOLFILE'
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.28;

import "../src/CaseReach.SOL";

// No forge-std and no harness on purpose: `require` is the whole assertion, so
// the only thing a pass can mean is that the imported mixed-case source was
// compiled, deployed, and executed.
contract CaseReachTest {
    function test_MixedCaseExtensionIsBuildReachableAndExecutable() public {
        require(new CaseReach().answer() == 42, "mixed-case .SOL did not execute");
    }
}
SOLFILE

  # FOUNDRY_PROFILE is pinned to `default` because CI exports `ci` globally and
  # this throwaway project deliberately declares no profile but the default.
  if (cd "$SCRATCH" && FOUNDRY_PROFILE=default forge build --force) >"$SCRATCH/build.log" 2>&1; then
    metadata_sources="$(jq -r '.metadata.sources | keys[]' "$SCRATCH/out/CaseReach.t.sol/CaseReachTest.json" 2>/dev/null || true)"
    if printf '%s\n' "$metadata_sources" | grep -qx 'src/CaseReach\.SOL'; then
      ok "solc recorded src/CaseReach.SOL in the importing artifact's metadata.sources — it IS compiled source"
    else
      bad "src/CaseReach.SOL absent from metadata.sources — the control did not demonstrate compilation"
      printf '%s\n' "$metadata_sources" | sed 's/^/          /' >&2
    fi
  else
    bad "the throwaway build failed — the build-reachability control could not run"
    tail -5 "$SCRATCH/build.log" | sed 's/^/          /' >&2
  fi

  if (cd "$SCRATCH" && FOUNDRY_PROFILE=default forge test --match-test test_MixedCaseExtensionIsBuildReachableAndExecutable) >"$SCRATCH/test.log" 2>&1; then
    ok "a deployed instance of the .SOL contract EXECUTED — reachability is proven, not inferred"
    grep -E '^\[PASS\]' "$SCRATCH/test.log" | head -1 | sed 's/^/          /'
  else
    bad "the .SOL contract did not execute — the build-reachability control could not run"
    tail -5 "$SCRATCH/test.log" | sed 's/^/          /' >&2
  fi

  # Printed, never consulted: this is the exact diagnostic that produced the N-2
  # error. Showing it beside a passing execution IS the retraction's evidence.
  if grep -qiE 'unable to resolve import' "$SCRATCH/build.log" "$SCRATCH/test.log" 2>/dev/null; then
    printf '          note: Foundry printed "Unable to resolve imports" in the same run that passed —\n'
    printf '                a resolver diagnostic describes the discovery pass, never what compiled\n'
    printf '                (this is the sprint-1 N-2 error; the entry is retracted in NOTES.md)\n'
  fi

  rm -rf "$SCRATCH"; SCRATCH=""
fi

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
if [[ -e "$ZONE_PROBE" ]]; then bad "$ZONE_PROBE survived cleanup"; else ok "$ZONE_PROBE removed"; fi
for f in "${CASE_PROBES[@]}"; do
  if [[ -e "$f" ]]; then bad "$f survived cleanup"; else ok "$f removed"; fi
done
if [[ -n "$SCRATCH" && -e "$SCRATCH" ]]; then bad "throwaway project $SCRATCH survived cleanup"; else ok "throwaway build project removed"; fi
for g in verify-census.sh verify-spdx.sh verify-quarantine.sh; do expect_green "$g"; done

printf '\n'
if (( status == 0 )); then
  printf '\033[32mSource-boundary fence proven closed on all 11 probes and reopened; mixed-case build-reachability proven from compiler evidence.\033[0m\n'
else
  printf '\033[31mSource-boundary demonstration FAILED.\033[0m\n' >&2
fi
exit "$status"
