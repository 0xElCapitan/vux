#!/usr/bin/env bash
# Negative demonstration — a one-byte mutation of a vendored file MUST fail the
# drift gate (sprint.md Sprint 1 acceptance criterion 2).
#
# Run as a CI job rather than recorded once in a report: a fence is only proven
# by watching it close, and re-proving it on every push keeps it proven.
#
# The mutation is applied to a copy-protected target and restored unconditionally
# via a trap, then the restored bytes are re-verified — the tree is never left
# corrupted, even if the run is interrupted.
#
# Usage: tools/provenance/demo-drift-negative.sh [vendored-file]
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/../.."

TARGET="${1:-vendor/uniswap-v3-core-v1.0.0/contracts/UniswapV3Pool.sol}"
[[ -f "$TARGET" ]] || { echo "no such vendored file: $TARGET" >&2; exit 2; }

BACKUP="$(mktemp)"
cp "$TARGET" "$BACKUP"
restore() { cp "$BACKUP" "$TARGET"; rm -f "$BACKUP"; }
trap restore EXIT

ORIGINAL_SHA="$(sha256sum "$TARGET" | cut -d' ' -f1)"
SIZE="$(wc -c < "$TARGET" | tr -d ' ')"
OFFSET="$(( SIZE / 2 ))"

echo "target        : $TARGET"
echo "original sha  : $ORIGINAL_SHA"

# The gate's source universe now includes what the compiler admitted, read from
# both units' build artifacts, and it fails closed when a unit has produced none
# (sprint-2 audit M-1). Building here keeps this demonstration self-contained:
# the drift gate is `verify-census.sh`, so its preconditions are this script's
# preconditions.
if ! command -v forge >/dev/null 2>&1; then
  echo "FAIL: forge is not on PATH — the drift gate's compiler-admitted source evidence cannot be produced." >&2
  exit 2
fi
BUILD_LOG="$(mktemp)"
if ! { FOUNDRY_PROFILE=v3core forge build && forge build; } >"$BUILD_LOG" 2>&1; then
  echo "FAIL: could not build both compilation units — nothing demonstrated." >&2
  tail -5 "$BUILD_LOG" >&2
  rm -f "$BUILD_LOG"
  exit 1
fi
rm -f "$BUILD_LOG"
echo "build         : both compilation units built"

# Baseline: the gate must be green before the mutation, or the demonstration
# proves nothing.
if ! bash "$HERE/verify-census.sh" >/dev/null 2>&1; then
  echo "FAIL: drift gate is already red before the mutation — nothing demonstrated." >&2
  exit 1
fi
echo "baseline      : drift gate green"

# Flip exactly one byte, in place, to a value guaranteed to differ.
byte="$(od -An -tu1 -j "$OFFSET" -N1 "$TARGET" | tr -d ' \n')"
if [[ "$byte" == "65" ]]; then new='\102'; else new='\101'; fi   # 'A' / 'B'
printf "$new" | dd of="$TARGET" bs=1 seek="$OFFSET" count=1 conv=notrunc status=none

MUTATED_SHA="$(sha256sum "$TARGET" | cut -d' ' -f1)"
if [[ "$MUTATED_SHA" == "$ORIGINAL_SHA" ]]; then
  echo "FAIL: mutation did not change the file." >&2
  exit 1
fi
echo "mutated 1 byte at offset $OFFSET"
echo "mutated sha   : $MUTATED_SHA"

echo
echo "--- drift gate output under mutation (expected: FAIL) ---"
bash "$HERE/verify-census.sh" 2>&1 | grep -E 'DRIFT|accepted|actual|check\(s\) failed' | head -6
gate_status="${PIPESTATUS[0]}"

restore
trap - EXIT

RESTORED_SHA="$(sha256sum "$TARGET" | cut -d' ' -f1)"
echo
echo "restored sha  : $RESTORED_SHA"

status=0
if (( gate_status == 0 )); then
  echo "FAIL: the drift gate PASSED a mutated vendored file — the fence is open." >&2
  status=1
else
  echo "ok    drift gate failed closed on a one-byte mutation (exit $gate_status)"
fi
if [[ "$RESTORED_SHA" != "$ORIGINAL_SHA" ]]; then
  echo "FAIL: restore did not reproduce the original bytes." >&2
  status=1
else
  echo "ok    exact tree restored"
fi
if ! bash "$HERE/verify-census.sh" >/dev/null 2>&1; then
  echo "FAIL: drift gate still red after restore." >&2
  status=1
else
  echo "ok    drift gate green again after restore"
fi
exit "$status"
