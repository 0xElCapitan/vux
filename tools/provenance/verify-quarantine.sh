#!/usr/bin/env bash
# Gate 5 — PRD §17 research-guidance quarantine (prd.md:L818).
#
# PRD §17 values are RESEARCH GUIDANCE, NOT AUTHORITY: "No PRD requirement, SDD
# parameter, interface, default constant, UI copy, or implementation may present
# them as immutable founder parameters." This gate is the mechanical form of
# that criterion — it fails if a §17 value or concept appears in implementation
# artifacts outside an explicitly labelled guidance context.
#
# Scope: VUX-owned implementation and build/CI configuration, wherever the
# implementation actually lives — the fixed entries below plus every
# non-vendored Solidity file in the repository-wide source universe
# (census.sh), so relocating implementation material into an unscanned
# directory cannot bypass §17.
#
# Deliberately NOT scanned: docs/authority/** and grimoires/** (where these
# values are *discussed as guidance* by design — legitimate research text, and
# the source universe excludes the Loa zones outright) and vendor/**
# (byte-identical upstream, frozen by the drift gate).
#
# Escape hatch: a line carrying the marker `loa:guidance-example` is exempt —
# that is the "explicitly labeled guidance/policy-example context" the PRD
# acceptance criterion allows, and it is visible in review.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
cd "$REPO_ROOT"

SCOPE=()
for p in src test script tools .github foundry.toml remappings.txt; do
  [[ -e "$p" ]] && SCOPE+=("$p")
done
# Add every non-vendored Solidity file that lives OUTSIDE the fixed entries —
# the paths a hand-maintained directory list would miss. Entries already covered
# above are skipped so a violation is reported once, not twice.
while IFS= read -r p; do
  [[ -n "$p" ]] || continue
  case "$p" in src/*|test/*|script/*|tools/*|.github/*) continue ;; esac
  SCOPE+=("$p")
done < <(vux_owned_sources)

# Each entry: <label>|<extended regex>
#
# Values that are frozen AUTHORITY and therefore must NOT be quarantined are
# excluded by construction: the 80/8/12 routing constants, the 30-day halving
# period, the 3000-second Dutch decay window, and the 24-hour admission delay.
declare -a PATTERNS=(
  "LSG readiness window (60 days)|\b60[[:space:]_]*days\b"
  "dry-powder window (180 days)|\b180[[:space:]_]*days\b"
  "LSG capital gate (\$250K)|\b250_?000\b"
  "LSG distributed-VUX gate (5M)|\b5_?000_?000\b"
  "operator share / NAV ceiling concepts|\b(operatorShare|operator_share|navCeiling|nav_ceiling|operatorCeiling)\b"
  "dry-powder policy|\b(dryPowder|dry_powder)\b"
  "LSG holder/participant gates|\b(holderCeiling|holder_ceiling|effectiveParticipants|minHolders)\b"
  "ROOT/GIGA look-through caps|\b(rootCap|gigaCap|lookThroughCap|look_through_cap)\b"
  "signaler/LP measurement guidance|\b(lpPerBribe|retentionRate|bribeDollar|depthThreshold)\b"
  "general revenue split ratios|\b(compoundPct|opsPct|signalerPct|marketInfraPct|hardPct|revenueSplit)\b"
)

echo "== PRD §17 research-guidance quarantine =="
if (( ${#SCOPE[@]} == 0 )); then
  info "no implementation artifacts to scan yet"
  finish
fi

for entry in "${PATTERNS[@]}"; do
  label="${entry%%|*}"
  regex="${entry#*|}"
  hits="$(grep -rnE "$regex" "${SCOPE[@]}" 2>/dev/null | grep -v 'loa:guidance-example' || true)"
  # This file necessarily contains the patterns it searches for.
  hits="$(printf '%s\n' "$hits" | grep -v '^tools/provenance/verify-quarantine.sh:' | sed '/^$/d' || true)"
  if [[ -n "$hits" ]]; then
    fail "§17 guidance value present as implementation authority — $label:"$'\n'"$hits"
  else
    pass "clean: $label"
  fi
done

finish
