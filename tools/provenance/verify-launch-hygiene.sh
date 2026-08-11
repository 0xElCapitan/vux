#!/usr/bin/env bash
# Gate 6 — launch-secret and broadcast-artifact hygiene (sdd.md:L270).
#
# The SDD's launch-secret posture is deployment-runbook law: production Foundry
# broadcast artifacts embed addresses, nonces, and calldata, and the launch EOA,
# commitment salt, and predicted addresses must not reach the public repository
# or public CI logs before the launch block. This gate is its repository half.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
cd "$REPO_ROOT"

echo "== broadcast-artifact exclusion =="
if [[ ! -f .gitignore ]]; then
  fail ".gitignore missing"
elif ! grep -qE '^[[:space:]]*broadcast/(\*\*)?[[:space:]]*$' .gitignore; then
  fail ".gitignore does not exclude broadcast/** (sdd.md:L270 launch-secret posture)"
else
  pass ".gitignore excludes broadcast/**"
fi

tracked_broadcast="$(git ls-files 'broadcast/*' 'broadcast/**' 2>/dev/null || true)"
if [[ -n "$tracked_broadcast" ]]; then
  fail "broadcast artifacts are tracked in git:"$'\n'"$tracked_broadcast"
else
  pass "no broadcast artifact tracked in git"
fi

echo
echo "== environment-file hygiene =="
tracked_env="$(git ls-files 2>/dev/null | grep -E '(^|/)\.env($|\.)' | grep -v '\.env\.example$' || true)"
if [[ -n "$tracked_env" ]]; then
  fail "environment file tracked in git:"$'\n'"$tracked_env"
else
  pass "no .env file tracked in git"
fi

echo
echo "== launch-secret literals in tracked files =="
# Deliberately narrow patterns: a literal key/mnemonic assignment or a key
# passed on a command line. Bare 32-byte hex is NOT flagged — the accepted
# POOL_INIT_CODE_HASH and every keccak constant have exactly that shape.
declare -a PATTERNS=(
  "private key literal|(PRIVATE_KEY|PRIVKEY|SECRET_KEY)[[:space:]]*[:=][[:space:]]*[\"']?0x[0-9a-fA-F]{64}"
  "private key on a command line|--private-key[[:space:]]+[\"']?0x[0-9a-fA-F]{64}"
  "mnemonic literal|(MNEMONIC|mnemonic)[[:space:]]*[:=][[:space:]]*[\"'][a-z]+([[:space:]]+[a-z]+){11,}"
  "commitment salt literal|(COMMITMENT_SALT|LAUNCH_SALT|launchSalt)[[:space:]]*[:=][[:space:]]*[\"']?0x[0-9a-fA-F]{64}"
)
# Tracked files PLUS untracked-but-not-ignored files. `git ls-files` alone made
# this gate near-vacuous before the first commit: every new deliverable is
# untracked at that point, so the gate reported clean over work it had never
# read. Ignored files stay out of scope by design — they are never committed, so
# they cannot leak a launch secret into the repository. (The broadcast/, .env,
# and build-output checks above and below are correctly git-scoped: those ask
# "is this TRACKED", which is a question only git can answer.)
scan_files="$( { git ls-files; git ls-files --others --exclude-standard; } 2>/dev/null \
  | LC_ALL=C sort -u | grep -vE '^(vendor/|docs/authority/|grimoires/)' || true)"
info "scanning $(printf '%s\n' "$scan_files" | sed '/^$/d' | wc -l | tr -d ' ') file(s): tracked + untracked-not-ignored, excluding vendor/ docs/authority/ grimoires/"
for entry in "${PATTERNS[@]}"; do
  label="${entry%%|*}"
  regex="${entry#*|}"
  hits=""
  if [[ -n "$scan_files" ]]; then
    hits="$(printf '%s\n' "$scan_files" | sed '/^$/d' | xargs -r -d '\n' grep -HnEI "$regex" 2>/dev/null \
      | grep -v '^tools/provenance/verify-launch-hygiene.sh:' || true)"
  fi
  if [[ -n "$hits" ]]; then
    fail "$label found in tracked files:"$'\n'"$hits"
  else
    pass "clean: $label"
  fi
done

echo
echo "== build-output exclusion =="
for dir in out out-v3core cache cache-v3core; do
  if git ls-files "$dir" 2>/dev/null | grep -q .; then
    fail "build output tracked in git: $dir/"
  else
    pass "$dir/ untracked"
  fi
done

finish
