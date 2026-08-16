#!/usr/bin/env node
// Standing gate over the accepted off-chain dependency surface.
//
// Asserts, for BOTH accepted roots, that:
//   1. every manifest dependency is an EXACT version string (no ranges);
//   2. every manifest pin equals the accepted census in the activated refreeze;
//   3. every lockfile entry for an accepted pin matches its accepted sha512;
//   4. no accepted package appears in a root it was not assigned to;
//   5. no REQUIRED peer dependency is unmet — an unmet one is a new required
//      dependency outside the accepted refreeze, which must STOP for a bounded
//      HITL rather than be silently added.
//
// Ordinary transitive packages resolved deterministically by the accepted graph
// are censused and integrity-checked (6), not treated as new decisions.
//
// Exit 0 = the installed surface equals the accepted surface. Exit 1 = drift.

import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const REGISTRY = join(REPO, 'docs', 'authority', 'vux-v1-source-registry-offchain-refreeze-2026-08.json');

const registry = JSON.parse(readFileSync(REGISTRY, 'utf8'));
const failures = [];
const fail = (m) => failures.push(m);

if (registry.status !== 'OFFCHAIN_PROVENANCE_REFREEZE_CURRENT_ACCEPTED' || registry.activation !== 'ACTIVE') {
  fail(`refreeze is not active (status=${registry.status}, activation=${registry.activation}) — nothing may be installed`);
}

// Accepted surface, indexed by root.
const accepted = new Map(); // package -> {version, integrity, roots:Set}
for (const p of registry.pins_final) {
  if (!p.root) continue; // PostgreSQL is a service, not an npm package
  const roots = new Set(p.root.split(/\s+and\s+|,\s*/).map((r) => r.trim().replace(/\/$/, '')));
  accepted.set(p.package, { version: p.version, integrity: p.integrity_sha512, roots });
}
for (const t of registry.disclosed_exact_transitives ?? []) {
  accepted.set(t.package, {
    version: t.version,
    integrity: t.integrity_sha512,
    roots: new Set([t.root.replace(/\/$/, '')]),
    transitive: true,
  });
}

const ROOTS = ['indexer', 'web'];
const census = {};

for (const root of ROOTS) {
  const dir = join(REPO, root);
  const manifestPath = join(dir, 'package.json');
  const lockPath = join(dir, 'package-lock.json');

  if (!existsSync(manifestPath)) { fail(`${root}/package.json missing`); continue; }
  if (!existsSync(lockPath)) { fail(`${root}/package-lock.json missing — the lockfile must be committed`); continue; }

  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const lock = JSON.parse(readFileSync(lockPath, 'utf8'));
  const declared = { ...(manifest.dependencies ?? {}), ...(manifest.devDependencies ?? {}) };

  // (1) exact version strings only
  for (const [pkg, range] of Object.entries(declared)) {
    if (!/^\d+\.\d+\.\d+$/.test(range)) {
      fail(`${root}: "${pkg}": "${range}" is not an exact version string`);
    }
  }

  // (2) manifest pins equal the accepted census, and (4) belong to this root
  for (const [pkg, version] of Object.entries(declared)) {
    const a = accepted.get(pkg);
    if (!a) {
      fail(`${root}: "${pkg}" is not in the accepted refreeze — unauthorized dependency expansion`);
      continue;
    }
    if (a.version !== version) {
      fail(`${root}: ${pkg}@${version} != accepted ${a.version}`);
    }
    if (!a.roots.has(root)) {
      fail(`${root}: ${pkg} is accepted for root(s) ${[...a.roots].join('/')} — not ${root}`);
    }
  }

  // (2b) every accepted package assigned to this root is actually declared,
  //      unless it is a disclosed transitive (which arrives via its parent).
  for (const [pkg, a] of accepted) {
    if (a.roots.has(root) && !a.transitive && !(pkg in declared)) {
      fail(`${root}: accepted pin ${pkg}@${a.version} is assigned to this root but not declared`);
    }
  }

  // (3) lockfile integrity for accepted pins
  for (const [pkg, a] of accepted) {
    if (!a.roots.has(root)) continue;
    const node = lock.packages?.[`node_modules/${pkg}`];
    if (!node) { fail(`${root}: ${pkg} absent from the lockfile`); continue; }
    if (node.version !== a.version) fail(`${root}: lockfile ${pkg}@${node.version} != accepted ${a.version}`);
    if (a.integrity && node.integrity !== a.integrity) {
      fail(`${root}: ${pkg} integrity ${node.integrity} != accepted ${a.integrity}`);
    }
  }

  // (5) unmet REQUIRED peers — the "stop for a bounded HITL" trigger
  const installed = new Map();
  for (const [path, node] of Object.entries(lock.packages ?? {})) {
    if (!path.startsWith('node_modules/')) continue;
    installed.set(path.replace(/^node_modules\//, ''), node.version);
  }
  for (const [path, node] of Object.entries(lock.packages ?? {})) {
    if (!path.startsWith('node_modules/')) continue;
    const owner = path.replace(/^node_modules\//, '');
    for (const [peer, range] of Object.entries(node.peerDependencies ?? {})) {
      if (node.peerDependenciesMeta?.[peer]?.optional) continue;
      // Nested resolution: a peer may sit beside the owner or at the root.
      const nested = lock.packages?.[`${path}/node_modules/${peer}`];
      if (nested || installed.has(peer)) continue;
      fail(`${root}: REQUIRED peer "${peer}" (${range}) of ${owner} is UNMET — new required dependency outside the accepted refreeze; STOP for a bounded HITL`);
    }
  }

  // (6) transitive census
  const pkgs = Object.entries(lock.packages ?? {})
    .filter(([p]) => p.startsWith('node_modules/'))
    .map(([p, n]) => ({ name: p.replace(/^node_modules\//, ''), version: n.version, integrity: n.integrity, license: n.license, dev: !!n.dev }));
  const missingIntegrity = pkgs.filter((p) => !p.integrity && !p.link);
  census[root] = {
    total: pkgs.length,
    direct: Object.keys(declared).length,
    withoutIntegrity: missingIntegrity.map((p) => `${p.name}@${p.version}`),
    lockfileVersion: lock.lockfileVersion,
  };
  if (missingIntegrity.length) {
    fail(`${root}: ${missingIntegrity.length} lockfile entries carry no integrity digest: ${missingIntegrity.slice(0, 5).map((p) => p.name).join(', ')}`);
  }
}

console.log('Accepted off-chain surface — standing gate\n');
console.log(`  refreeze: ${registry.status} / ${registry.activation} (accepted ${registry.operator_acceptance?.date})`);
for (const [root, c] of Object.entries(census)) {
  console.log(`  ${root.padEnd(8)} direct=${String(c.direct).padStart(2)}  transitive-closure=${String(c.total).padStart(3)}  lockfileVersion=${c.lockfileVersion}  all entries carry integrity: ${c.withoutIntegrity.length === 0}`);
}

console.log('');
if (failures.length) {
  console.log('VERDICT: FAIL — installed surface differs from the accepted surface.\n');
  for (const f of failures) console.log('  - ' + f);
  process.exit(1);
}
console.log('VERDICT: PASS — both roots equal the accepted census; every required peer is met;');
console.log('               every lockfile entry carries an integrity digest.');
process.exit(0);
