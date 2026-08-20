// Transitive licence census for the two off-chain package roots.
//
// Closes disclosure **D-3** of the accepted off-chain provenance refreeze
// (`docs/authority/vux-v1-offchain-provenance-refreeze-2026-08.md` §6.1), whose
// §8 action 3 requires "the transitive licence census from the lockfiles".
// Sprint 6 landed the lockfiles but not the census; Sprint 8 Task 8.5 closes it.
//
// Reads the committed lockfiles for identity (name, version, resolved URL,
// integrity) and the installed tree for the licence each package DECLARES —
// lockfiles do not carry licence fields, so the package's own manifest is the
// only first-hand source. A package present in the lockfile but absent from
// node_modules is reported as UNVERIFIED rather than guessed.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { readFileSync, existsSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const ROOTS = ['indexer', 'web'];

function licenceOf(manifest) {
  if (!manifest) return null;
  const l = manifest.license ?? manifest.licenses;
  if (typeof l === 'string') return l;
  if (Array.isArray(l)) return l.map((x) => (typeof x === 'string' ? x : x?.type)).filter(Boolean).join(' OR ');
  if (l && typeof l === 'object' && l.type) return l.type;
  return null;
}

const all = new Map();     // "name@version" -> record
const perRoot = {};

for (const root of ROOTS) {
  const lock = JSON.parse(readFileSync(join(root, 'package-lock.json'), 'utf8'));
  const names = [];
  for (const [path, entry] of Object.entries(lock.packages || {})) {
    if (path === '') continue;                       // the root project itself
    if (entry.link) continue;                        // workspace symlink, not a distribution
    const name = entry.name || path.split('node_modules/').pop();
    const version = entry.version;
    if (!name || !version) continue;

    const manifestPath = join(root, path, 'package.json');
    const manifest = existsSync(manifestPath)
      ? JSON.parse(readFileSync(manifestPath, 'utf8'))
      : null;

    // A lockfile entry with no installed manifest is not automatically a gap.
    // npm records EVERY platform variant of an optional binary dependency and
    // installs only the one matching the host, so `os`/`cpu`/`optional` tell us
    // whether absence is expected. Saying that precisely is the difference
    // between a census and a list of shrugs.
    const platformGated = Boolean(entry.os || entry.cpu);
    const optional = Boolean(entry.optional || entry.devOptional || platformGated);

    const declared = licenceOf(manifest);
    const key = `${name}@${version}`;
    names.push(key);
    if (!all.has(key)) {
      all.set(key, {
        name,
        version,
        licence: declared ?? (optional ? 'NOT-INSTALLED-OPTIONAL' : 'UNVERIFIED'),
        licence_source: manifest
          ? 'installed package.json'
          : optional
            ? `optional${platformGated ? `/platform-gated (os=${JSON.stringify(entry.os ?? null)}, cpu=${JSON.stringify(entry.cpu ?? null)})` : ''} — not installed on this host, so not part of the artifact built here`
            : 'NOT INSTALLED and NOT optional — a real gap',
        optional,
        platform_gated: platformGated,
        dev: !!entry.dev,
        resolved: entry.resolved ?? null,
        integrity: entry.integrity ?? null,
        roots: [],
      });
    }
    all.get(key).roots.push(root);
  }
  perRoot[root] = names.length;
}

const rows = [...all.values()].sort((a, b) => a.name.localeCompare(b.name) || a.version.localeCompare(b.version));

const byLicence = {};
for (const r of rows) byLicence[r.licence] = (byLicence[r.licence] || 0) + 1;

// Only a NON-optional package with no readable manifest is a genuine gap.
const unverified = rows.filter((r) => r.licence === 'UNVERIFIED');
const notInstalledOptional = rows.filter((r) => r.licence === 'NOT-INSTALLED-OPTIONAL');
const copyleft = rows.filter((r) => /GPL|AGPL|LGPL|MPL|EPL|CDDL|SSPL|BUSL/i.test(r.licence) && !/LGPL-3.0-or-later WITH/i.test(r.licence));

const out = {
  schema_version: 1,
  generated_by: '/implement sprint-8, Task 8.5 (tools/offchain/licence-census.mjs)',
  closes: {
    disclosure: 'D-3',
    authority: 'docs/authority/vux-v1-offchain-provenance-refreeze-2026-08.md',
    section: '6.1 / §8 action 3',
  },
  method: 'identity (name, version, resolved, integrity) from the committed lockfiles; licence from each package\'s own installed manifest — the only first-hand source, since npm lockfiles carry no licence field. Not installed => UNVERIFIED, never guessed.',
  project_license: 'GPL-3.0-or-later',
  totals: {
    distinct_packages: rows.length,
    entries_per_root: perRoot,
    unverified_real_gaps: unverified.length,
    not_installed_optional: notInstalledOptional.length,
    copyleft_or_weak_copyleft: copyleft.length,
    by_licence: Object.fromEntries(Object.entries(byLicence).sort((a, b) => b[1] - a[1])),
  },
  copyleft_detail: copyleft.map((r) => ({ name: r.name, version: r.version, licence: r.licence, dev: r.dev, roots: r.roots })),
  unverified_detail: unverified.map((r) => ({ name: r.name, version: r.version, roots: r.roots, why: r.licence_source })),
  not_installed_optional_detail: notInstalledOptional.map((r) => ({ name: r.name, version: r.version, platform_gated: r.platform_gated, roots: r.roots })),
  packages: rows,
};

writeFileSync('grimoires/loa/a2a/sprint-8/offchain-licence-census.json', JSON.stringify(out, null, 2) + '\n', 'utf8');

console.log(`distinct packages : ${rows.length}  (indexer ${perRoot.indexer}, web ${perRoot.web})`);
console.log(`real licence gaps : ${unverified.length}`);
console.log(`optional/not-inst : ${notInstalledOptional.length} (platform-gated binaries npm records but does not install here)`);
console.log(`copyleft-family   : ${copyleft.length}${copyleft.length ? ' -> ' + copyleft.map((r) => `${r.name}@${r.version} (${r.licence})`).join(', ') : ''}`);
console.log('by licence        :');
for (const [l, n] of Object.entries(byLicence).sort((a, b) => b[1] - a[1])) console.log(`   ${String(n).padStart(4)}  ${l}`);
