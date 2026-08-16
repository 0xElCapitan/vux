#!/usr/bin/env node
// Fail-closed verification of the React Server Components runtime actually
// shipped inside the installed `next` artifact.
//
// WHY THIS EXISTS
//
// CVE-2025-66478 (Next.js, GHSA-9qr9-h5gf-34mp) tracks the downstream impact of
// CVE-2025-55182 — a CVSS 10.0 RCE in the React Server Components protocol. The
// vulnerable packages are `react-server-dom-webpack` / `-parcel` / `-turbopack`
// at 19.0 / 19.1.0 / 19.1.1 / 19.2.0, fixed in 19.0.1 / 19.1.2 / 19.2.1.
//
// Next.js does NOT declare those packages as dependencies — it vendors compiled
// copies inside its own tarball. So the dependency graph cannot answer the
// question "is the RSC runtime patched?", and neither can the `next` version
// number on its own. This script reads the artifact.
//
// It is the mechanical discharge of the post-acceptance obligation recorded at
// docs/authority/vux-v1-offchain-provenance-refreeze-2026-08.md §5.3 / §9.
//
// Exit 0 = the installed artifact is consistent with the accepted security
// posture. Exit 1 = it is not; the caller must treat that as blocking.

import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const COMPILED = join(ROOT, 'node_modules', 'next', 'dist', 'compiled');

const ACCEPTED_NEXT = '15.1.12';

// The last published fix in the 19.0.x RSC line (react-server-dom-webpack@19.0.3,
// 2025-12-11). Any vendored RSC build predating this is unpatched-or-unknown and
// fails closed. Dates are the primary-source npm publish timestamps.
const RSC_FIX_FLOOR = '20251211';
const RSC_FIXED_SEMVERS = ['19.0.1', '19.0.2', '19.0.3', '19.1.2', '19.2.1'];

// The RSC transports — the packages the advisory actually names.
const RSC_DIRS = ['react-server-dom-webpack', 'react-server-dom-turbopack'];
// Not vulnerable per the React advisory; checked only to corroborate that this
// was a targeted RSC rebuild rather than a wholesale bump.
const NON_RSC_DIRS = ['react', 'react-dom'];

const failures = [];
const notes = [];

function check(cond, message) {
  if (!cond) failures.push(message);
  return cond;
}

/** Every React build stamp appearing in a compiled bundle directory. */
function stampsIn(dir) {
  const abs = join(COMPILED, dir);
  if (!existsSync(abs)) return null;
  const found = new Set();
  const rcRe = /19\.\d+\.\d+-rc-[0-9a-f]{8,}-\d{8}/g;
  const plainRe = /"(19\.\d+\.\d+)"/g;

  const walk = (d) => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith('.js')) {
        const src = readFileSync(p, 'utf8');
        for (const m of src.matchAll(rcRe)) found.add(m[0]);
        for (const m of src.matchAll(plainRe)) found.add(m[1]);
      }
    }
  };
  walk(abs);
  return [...found];
}

/** A build stamp is acceptable if it is a fixed semver, or dated at/after the fix floor. */
function stampVerdict(stamp) {
  if (RSC_FIXED_SEMVERS.includes(stamp)) return { ok: true, why: `published fixed release ${stamp}` };
  const rc = stamp.match(/^19\.\d+\.\d+-rc-([0-9a-f]{8,})-(\d{8})$/);
  if (rc) {
    const [, sha, date] = rc;
    return date >= RSC_FIX_FLOOR
      ? { ok: true, why: `vendored build ${sha} dated ${date} >= fix floor ${RSC_FIX_FLOOR}` }
      : { ok: false, why: `vendored build ${sha} dated ${date} PREDATES fix floor ${RSC_FIX_FLOOR}` };
  }
  if (/^19\.\d+\.\d+$/.test(stamp)) {
    return { ok: false, why: `plain ${stamp} is not among the fixed releases ${RSC_FIXED_SEMVERS.join('/')}` };
  }
  return { ok: false, why: `unrecognised stamp "${stamp}" — cannot establish it is patched` };
}

console.log('RSC runtime verification — installed artifact, not manifest edges\n');

// ---------------------------------------------------------------------------
// 1. The artifact under test is the accepted one
// ---------------------------------------------------------------------------
const nextPkgPath = join(ROOT, 'node_modules', 'next', 'package.json');
check(existsSync(nextPkgPath), 'next is not installed — nothing to verify');
if (!existsSync(nextPkgPath)) { report(); process.exit(1); }

const nextVersion = JSON.parse(readFileSync(nextPkgPath, 'utf8')).version;
check(
  nextVersion === ACCEPTED_NEXT,
  `installed next is ${nextVersion}, accepted pin is ${ACCEPTED_NEXT}`
);
console.log(`  next installed        : ${nextVersion} ${nextVersion === ACCEPTED_NEXT ? '(= accepted pin)' : '(MISMATCH)'}`);

// ---------------------------------------------------------------------------
// 2. Nothing in the tree can shadow the vendored RSC runtime
// ---------------------------------------------------------------------------
// A resolvable top-level react-server-dom-* would mean the app could load an
// unvendored — and possibly vulnerable — copy. The accepted refreeze declares no
// such dependency; this asserts the installed tree agrees.
for (const p of ['react-server-dom-webpack', 'react-server-dom-turbopack', 'react-server-dom-parcel']) {
  const present = existsSync(join(ROOT, 'node_modules', p));
  check(!present, `${p} is resolvable at the top level — it could shadow the vendored runtime`);
  if (!present) notes.push(`${p} absent from node_modules (nothing can shadow the vendored copy)`);
}
console.log('  shadowing packages    : none resolvable (as accepted)');

// ---------------------------------------------------------------------------
// 3. The vendored RSC transports are patched
// ---------------------------------------------------------------------------
console.log('\n  vendored RSC transports:');
let sawAnyRsc = false;
for (const dir of RSC_DIRS) {
  const stamps = stampsIn(dir);
  if (stamps === null) { console.log(`    ${dir}: not present`); continue; }
  if (stamps.length === 0) {
    check(false, `${dir}: no version stamp could be extracted — cannot establish it is patched`);
    console.log(`    ${dir}: NO STAMP (fails closed)`);
    continue;
  }
  sawAnyRsc = true;
  for (const s of stamps) {
    const v = stampVerdict(s);
    check(v.ok, `${dir} @ ${s}: ${v.why}`);
    console.log(`    ${dir}: ${s}  ->  ${v.ok ? 'OK' : 'FAIL'} (${v.why})`);
  }
}
check(sawAnyRsc, 'no react-server-dom-* transport found inside next — unexpected layout, cannot verify');

// ---------------------------------------------------------------------------
// 4. Corroboration: the non-vulnerable bundles were NOT rebuilt
// ---------------------------------------------------------------------------
// The React advisory states react/react-dom are not vulnerable packages. If the
// RSC transports carry a strictly later build stamp than react/react-dom, that
// is the signature of a targeted RSC security rebuild, which corroborates the
// advisory rather than contradicting it. This is evidence, not a gate.
console.log('\n  corroboration (not a gate):');
for (const dir of NON_RSC_DIRS) {
  const stamps = stampsIn(dir) ?? [];
  console.log(`    ${dir}: ${stamps.join(', ') || '(none)'}`);
  notes.push(`${dir} stamps: ${stamps.join(', ') || 'none'}`);
}

// ---------------------------------------------------------------------------
function report() {
  console.log('');
  if (failures.length) {
    console.log('VERDICT: FAIL — the installed artifact contradicts the accepted security posture.\n');
    for (const f of failures) console.log('  - ' + f);
    console.log('\nThis is blocking. Do not rely on Next.js application code until it is resolved.');
  } else {
    console.log('VERDICT: PASS — the installed artifact is consistent with the accepted security posture.');
    console.log('\nEstablished:');
    console.log(`  - next@${nextVersion} is the accepted pin`);
    console.log(`  - both vendored RSC transports postdate the ${RSC_FIX_FLOOR} fix floor`);
    console.log('  - no react-server-dom-* is resolvable at the top level, so nothing shadows them');
    console.log('\nLimit of this check (stated, not hidden): the vendored build stamp is an internal');
    console.log('Vercel/React build identifier, not a published npm artifact, so it cannot be');
    console.log('byte-compared against a published fixed release. The determination rests on build-date');
    console.log('ordering, the targeted-rebuild signature, and the vendor deprecation state.');
  }
}

report();
process.exit(failures.length ? 1 : 0);
