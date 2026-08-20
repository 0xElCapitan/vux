#!/usr/bin/env bash
# Sprint 8 — final launch-secret hygiene sweep over the COMPLETE repository namespace.
#
# `verify-launch-hygiene.sh` (the CI gate) deliberately excludes `vendor/`,
# `docs/authority/`, and `grimoires/` — sensible for a per-push gate, because
# those trees discuss provenance values as text and would produce constant noise.
#
# This sweep is the launch-readiness complement: it scans **every tracked file**,
# with no directory exclusions at all, because an absence claim made at launch
# must cover the namespace an attacker would actually search. It is a Sprint-8
# evidence artifact, not a per-push gate.
#
# The naive scan (any 64-hex literal) is useless here: the repository is FULL of
# legitimate 64-hex values — sha256 census digests, git commit SHAs,
# POOL_INIT_CODE_HASH, keccak topics. Matching those produces a list nobody
# reads. Every pattern below therefore requires key-shaped CONTEXT, not just
# key-shaped entropy.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/census.sh"
set +e
cd "$REPO_ROOT"

echo "== scope =="
total=$(git ls-files | wc -l | tr -d ' ')
info "scanning ALL $total tracked files — no directory excluded"
echo

scan() {
  local label="$1" pattern="$2"
  local hits
  hits="$(git ls-files -z | xargs -0 grep -nIE "$pattern" 2>/dev/null)"
  if [[ -z "$hits" ]]; then
    pass "clean: $label"
  else
    fail "POSSIBLE SECRET — $label"
    printf '%s\n' "$hits" | head -20 | sed 's/^/        /'
  fi
}

echo "== key material in key-shaped context =="
# An assignment whose NAME says private key / secret, carrying a long hex value.
scan "private-key assignment" \
  '(private_?key|privkey|secret_?key|signing_?key|deployer_?key)[[:space:]]*[=:][[:space:]]*.?0x[0-9a-fA-F]{64}'
# A key handed to a tool on a command line.
scan "key on a command line" \
  '--private-key[[:space:]]+(0x)?[0-9a-fA-F]{64}'
# PEM-encoded key blocks.
scan "PEM private-key block" \
  'BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY'
# A BIP-39 mnemonic: twelve or more lowercase words in a row on one line, in a
# mnemonic-shaped assignment.
scan "mnemonic assignment" \
  '(mnemonic|seed_?phrase)[[:space:]]*[=:][[:space:]]*.?([a-z]+[[:space:]]+){11,}[a-z]+'

echo
echo "== launch-confidentiality material (§1.7) =="
# The commitment salt is the one value whose leak breaks launch confidentiality.
scan "commitment salt literal" \
  '(commitment_?salt|genesis_?salt|launch_?salt|SALT)[[:space:]]*[=:][[:space:]]*.?0x[0-9a-fA-F]{64}'
scan "production launch EOA declaration" \
  '(launch_?eoa|deployer_?eoa|tx2_?eoa)[[:space:]]*[=:][[:space:]]*.?0x[0-9a-fA-F]{40}'
scan "private-relay credential" \
  '(flashbots|builder|relay)_?(key|token|secret|auth)[[:space:]]*[=:][[:space:]]*[^[:space:]]{16,}'

echo
echo "== credential files and broadcast artifacts =="
for pat in '.env' '.env.*' '*.pem' '*.key' '*.p12' '*.keystore' 'secrets.*'; do
  found="$(git ls-files -- "$pat" 2>/dev/null)"
  if [[ -n "$found" ]]; then
    fail "credential-shaped file tracked: $found"
  fi
done
pass "no credential-shaped file tracked (.env, *.pem, *.key, *.p12, *.keystore, secrets.*)"

bc="$(git ls-files -- 'broadcast/**' 2>/dev/null)"
if [[ -n "$bc" ]]; then
  fail "broadcast artifact tracked: $bc"
else
  pass "no broadcast artifact tracked"
fi

echo
echo "== production-value slots must remain UNFILLED =="
# The runbook's slots are the canonical list. A filled slot is a resolved
# operator-reserved value, which is a defect regardless of how it got there.
RUNBOOK="grimoires/loa/a2a/sprint-8/deployment-runbook.md"
if [[ -f "$RUNBOOK" ]]; then
  slots=$(grep -c '🔲' "$RUNBOOK")
  if (( slots > 0 )); then
    pass "$slots operator-reserved slot(s) present and unfilled in the runbook"
  else
    fail "the runbook contains no unfilled slots — either it was gutted or values were resolved in-repo"
  fi
else
  fail "missing $RUNBOOK"
fi

finish
