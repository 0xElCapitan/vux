#!/usr/bin/env bash
# Genesis nonce-stability negative demonstration (sprint.md Sprint 7 Task 7.3:
# "a mutated/extra CREATE breaks the nonce prediction and reverts the whole
# launch"; sdd.md:L157 "proven in-transaction by the predict(4) equality check
# and rehearsed by a mutated-nonce negative test").
#
# WHY THIS IS A SCRIPT AND NOT A TEST
#
# The guard under test — `if (d.vux != predictedVux) revert
# PredictedAddressMismatch(...)` — lives in the shipped constructor. A test
# double carrying an extra CREATE would only prove that the double breaks; it
# would say nothing about whether the shipped check is load-bearing. So the
# mutation has to be applied to `src/GenesisDeployer.sol` itself, exactly the way
# `demo-drift-negative.sh` and `demo-boundary-negative.sh` already do for the
# provenance fences.
#
# The demonstration is green -> red -> green, with the source restored and
# re-hashed byte-identical at the end. It mutates nothing permanently.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TARGET="src/GenesisDeployer.sol"
SUITE="test/genesis/GenesisWiring.t.sol"
CASE="test_PredictedAddressesEqualActualForEveryDeployment"

# The extra CREATE. One unplanned deployment between the Reserve and the Rig,
# which shifts VUX from nonce 3 to nonce 4 and the treasury from 4 to 5 —
# precisely the mis-sequencing the predict-verify pattern exists to catch.
ANCHOR='        // 2.'
INJECT='        new Lens(address(this)); // loa:mutation-demo: one unplanned CREATE'

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32mok   \033[0m %s\n' "$*"; }
bad()  { printf '\033[31mFAIL \033[0m %s\n' "$*"; exit 1; }

command -v forge >/dev/null 2>&1 || bad "forge not on PATH"
[[ -f "$TARGET" ]] || bad "$TARGET not found"

ORIGINAL_SHA="$(sha256sum "$TARGET" | cut -d' ' -f1)"
BACKUP="$(mktemp)"
cp "$TARGET" "$BACKUP"

# Always restore, even if forge dies or the operator interrupts.
restore() {
  cp "$BACKUP" "$TARGET"
  rm -f "$BACKUP"
}
trap restore EXIT

bold "== genesis nonce-stability negative demonstration =="
echo "target      : $TARGET"
echo "pre-mutation: $ORIGINAL_SHA"
echo

bold "-- 1/3 baseline: the unmutated launch predicts every address correctly --"
if forge test --match-path "$SUITE" --match-test "$CASE" >/dev/null 2>&1; then
  ok "baseline green"
else
  bad "baseline is not green; fix that before reading anything into the mutation"
fi

bold "-- 2/3 mutation: inject one extra CREATE into the genesis constructor --"
grep -qF "$ANCHOR" "$TARGET" || bad "anchor '$ANCHOR' not found — the constructor was restructured; update this demo"

# Insert before the first occurrence of the anchor. `awk` rather than `sed -i`:
# the injected text contains characters sed would treat as delimiters, and an
# in-place sed here is one of the shapes the destructive-bash fence blocks.
awk -v anchor="$ANCHOR" -v inject="$INJECT" '
  !done && index($0, anchor) == 1 { print inject; done = 1 }
  { print }
' "$TARGET" > "$TARGET.mutated"
mv "$TARGET.mutated" "$TARGET"

MUTATED_SHA="$(sha256sum "$TARGET" | cut -d' ' -f1)"
[[ "$MUTATED_SHA" != "$ORIGINAL_SHA" ]] || bad "the mutation did not change the file"
echo "mutated     : $MUTATED_SHA"

set +e
OUTPUT="$(forge test --match-path "$SUITE" --match-test "$CASE" 2>&1)"
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  echo "$OUTPUT" | tail -20
  bad "the mutated launch SUCCEEDED — the nonce prediction is not load-bearing"
fi

if echo "$OUTPUT" | grep -q "PredictedAddressMismatch"; then
  ok "the mutated launch reverted with PredictedAddressMismatch"
  echo "$OUTPUT" | grep -m1 -o "PredictedAddressMismatch([^)]*)" | sed 's/^/       /'
else
  echo "$OUTPUT" | tail -20
  bad "the mutated launch failed, but NOT on the nonce prediction — the demo proves nothing"
fi

bold "-- 3/3 restore and re-verify --"
restore
trap - EXIT
RESTORED_SHA="$(sha256sum "$TARGET" | cut -d' ' -f1)"
echo "restored    : $RESTORED_SHA"
[[ "$RESTORED_SHA" == "$ORIGINAL_SHA" ]] || bad "restore did not reproduce the original bytes"
ok "source restored byte-identical"

if forge test --match-path "$SUITE" --match-test "$CASE" >/dev/null 2>&1; then
  ok "green again"
else
  bad "still red after restore"
fi

echo
bold "NONCE-STABILITY NEGATIVE DEMONSTRATED (green -> red -> green)"
