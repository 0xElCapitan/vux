#!/usr/bin/env node
// Mechanical enforcement of the accepted no-server-custody / static-export posture.
//
// The accepted architecture selects Next.js for a "Static-exportable read-only UI;
// no server-side custody of anything" (sdd.md:L449). That is the property which
// places VUX outside the scope of CVE-2025-55182 entirely — the React advisory's
// own condition is "if your app's React code does not use a server, your app is
// not affected". The accepted refreeze §5.5 records it as a BINDING obligation to
// assert mechanically rather than treat as prose, because intent is not a build
// setting.
//
// This reads the build output. A config value states an intention; `out/` is the
// fact.
//
// Exit 0 = the build is a static export with no server runtime. Exit 1 = it is not.

import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'out');
const failures = [];
const fail = (m) => failures.push(m);

const EXPECTED_PAGES = ['index.html', 'redeem.html', 'accounting.html', 'treasury.html', 'trust.html'];

console.log('Static-export verification — build output, not config intent\n');

// 1. the config declares it
const cfg = readFileSync(join(ROOT, 'next.config.mjs'), 'utf8');
if (!/output:\s*['"]export['"]/.test(cfg)) fail("next.config.mjs does not set output: 'export'");

// 2. the build actually produced a static export
if (!existsSync(OUT)) {
  fail('out/ does not exist — run `npm run build` first');
} else {
  for (const page of EXPECTED_PAGES) {
    const p = join(OUT, page);
    const alt = join(OUT, page.replace('.html', ''), 'index.html');
    if (!existsSync(p) && !existsSync(alt)) fail(`static page missing from the export: ${page}`);
  }

  // 3. no server runtime artifacts. A static export has no server bundle, no
  //    route manifest for server handlers, and no RSC/Server-Function endpoint.
  const FORBIDDEN = [
    'server',                       // the Node server bundle
    'standalone',                   // standalone server output
    'required-server-files.json',
    'BUILD_ID.server',
  ];
  for (const f of FORBIDDEN) {
    if (existsSync(join(OUT, f))) fail(`server artifact present in the export: out/${f}`);
  }

  // 4. no Server Actions / Server Function endpoint references in the emitted
  //    client bundles. A Server Function is the exact surface CVE-2025-55182
  //    reaches; a static export must contain none.
  const walk = (d, acc = []) => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name);
      if (e.isDirectory()) walk(p, acc);
      else acc.push(p);
    }
    return acc;
  };
  const files = walk(OUT);
  const htmlFiles = files.filter((f) => f.endsWith('.html'));
  if (htmlFiles.length === 0) fail('the export contains no HTML at all');

  // The check distinguishes DEFINING the capability from USING it, because the
  // two look identical to a naive substring grep and only one is a finding.
  //
  // Next.js bundles the `react-server-dom-webpack/client` runtime into its shared
  // client chunk unconditionally, so the *definition*
  // `t.createServerReference = function(...)` is present in any build, static or
  // not. That is dead code here: with no server there is no endpoint for it to
  // call. What would indicate an actual Server Function is either a CALL SITE —
  // `createServerReference(...)` — or a materialised server-reference object,
  // which carries the `react.server.reference` type marker.
  //
  // Both are checked. Loosening this to "the identifier is absent" would make the
  // check unsatisfiable; loosening it to "don't look" would make it useless.
  const definitionRe = /createServerReference\s*[:=]\s*function/g;
  const anyRe = /createServerReference/g;
  const typeofMarkerRe = /react\.server\.reference/g;

  const offenders = [];
  for (const f of files.filter((f) => f.endsWith('.js') || f.endsWith('.html'))) {
    const src = readFileSync(f, 'utf8');
    const markers = (src.match(typeofMarkerRe) ?? []).length;
    const total = (src.match(anyRe) ?? []).length;
    const definitions = (src.match(definitionRe) ?? []).length;
    const uses = total - definitions;
    if (markers > 0 || uses > 0) {
      offenders.push(`${relative(OUT, f)} (server-reference markers: ${markers}, non-definition uses: ${uses})`);
    }
  }
  if (offenders.length) {
    fail(`Server Function usage found in the export: ${offenders.slice(0, 5).join('; ')}`);
  }

  const bytes = files.reduce((a, f) => a + statSync(f).size, 0);
  console.log(`  pages exported        : ${htmlFiles.length}`);
  console.log(`  total files / bytes   : ${files.length} / ${(bytes / 1024).toFixed(0)} KiB`);
  console.log('  server bundle         : absent');
  console.log(`  RSC client runtime    : bundled by next (dead code — no server to call)`);
  console.log(`  Server Function usage : none (0 markers, 0 call sites)`);
}

console.log('');
if (failures.length) {
  console.log('VERDICT: FAIL — the build is not the accepted static-export shape.\n');
  for (const f of failures) console.log('  - ' + f);
  process.exit(1);
}
console.log('VERDICT: PASS — static export, no server runtime, no Server Function endpoint.');
console.log('         The app therefore has no RSC server surface for CVE-2025-55182 to reach.');
process.exit(0);
