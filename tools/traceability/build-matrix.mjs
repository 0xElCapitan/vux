// Traceability matrix generator — Sprint 8 Task 8.2.
//
// Produces the INV-1…37 / FB-1…18 / FR evidence map from the repository itself,
// so the matrix cannot drift from the tree the way a hand-maintained table does.
//
// Evidence is deliberately NOT forced into one shape. The accepted plan assigns
// each register row a method (sprint.md §D, sdd.md:L867, prd.md:L669), and a row
// whose assigned method is "review checklist" or "documented analysis" is
// satisfied by naming that artifact — not by inventing an automated test to make
// the table look uniform. What the matrix requires is NAMED, REVIEWABLE evidence.
//
// Sources scanned:
//   * `// carries:` file headers in test/**            (the repository's convention)
//   * inline INV-n / FB-n mentions inside test bodies  (function-level precision)
//   * declared non-test evidence below                 (CI gates, Playwright, docs)
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const REPO = process.cwd();
const INV_MAX = 37;
const FB_MAX = 18;

// ---------------------------------------------------------------- file walking
function walk(dir, out = []) {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

const rel = (p) => relative(REPO, p).split('\\').join('/');

// ------------------------------------------------------- requirement id parsing
// Expands "INV-1 … INV-22", "INV-1...INV-5", "FB-2,3,4" and plain "INV-7".
function expandIds(text) {
  const ids = new Set();
  const RANGE = /\b(INV|FB)-(\d+)\s*(?:…|\.\.\.|--|—|through|to)\s*(?:(?:INV|FB)-)?(\d+)/gi;
  let m;
  while ((m = RANGE.exec(text)) !== null) {
    const [, kind, a, b] = m;
    const lo = Math.min(+a, +b), hi = Math.max(+a, +b);
    for (let i = lo; i <= hi; i++) ids.add(`${kind.toUpperCase()}-${i}`);
  }
  const SINGLE = /\b(INV|FB)-(\d+)/gi;
  while ((m = SINGLE.exec(text)) !== null) ids.add(`${m[1].toUpperCase()}-${+m[2]}`);
  return ids;
}

// ------------------------------------------------------------ evidence gathering
const evidence = new Map();               // id -> [{file, line, kind, detail}]
const add = (id, rec) => {
  if (!evidence.has(id)) evidence.set(id, []);
  const list = evidence.get(id);
  if (!list.some((r) => r.file === rec.file && r.line === rec.line)) list.push(rec);
};

const solFiles = walk(join(REPO, 'test')).filter((p) => p.endsWith('.sol'));

for (const path of solFiles) {
  const src = readFileSync(path, 'utf8');
  const lines = src.split(/\r?\n/);
  const file = rel(path);
  const isInvariantSuite = /Invariants?\.t\.sol$/.test(file);

  // 1. the file-level `// carries:` block (header + indented continuations)
  for (let i = 0; i < lines.length; i++) {
    if (!/^\s*\/\/\s*carries:/i.test(lines[i])) continue;
    let block = lines[i];
    for (let j = i + 1; j < lines.length && /^\s*\/\/\s{2,}\S/.test(lines[j]); j++) block += ' ' + lines[j];
    for (const id of expandIds(block)) {
      add(id, {
        file, line: i + 1,
        kind: isInvariantSuite ? 'stateful-invariant' : 'forge-test',
        detail: 'file-level `// carries:` declaration',
      });
    }
    break;
  }

  // 2. inline mentions, attributed to the enclosing test/invariant function
  let fn = null, fnLine = 0;
  for (let i = 0; i < lines.length; i++) {
    const f = lines[i].match(/^\s*function\s+([A-Za-z0-9_]+)\s*\(/);
    if (f) { fn = f[1]; fnLine = i + 1; }
    if (!/\b(INV|FB)-\d+/.test(lines[i])) continue;
    if (/^\s*\/\/\s*carries:/i.test(lines[i])) continue;
    const inAssertion = /assert|revert|expect|"/.test(lines[i]);
    for (const id of expandIds(lines[i])) {
      add(id, {
        file, line: i + 1,
        kind: fn && /^(test|invariant|statefulFuzz)/.test(fn)
          ? (fn.startsWith('invariant') ? 'stateful-invariant' : 'forge-test')
          : 'forge-test',
        detail: fn ? `${fn}()${inAssertion ? ' — assertion' : ''} (declared L${fnLine})` : 'inline reference',
      });
    }
  }
}

// ------------------------------------------- declared non-Solidity-test evidence
//
// Rows whose accepted method is not a forge test. Each entry names a concrete,
// reviewable artifact. These are declarations OF LOCATION, not of sufficiency —
// verify-traceability.sh checks that every path here actually exists.
const DECLARED = {
  'INV-36': [
    { file: 'web/lib/truth-copy.js', kind: 'implementation', detail: 'YELLOW disclosure text, single source' },
    { file: 'web/components/ReserveDescription.jsx', kind: 'implementation', detail: 'component that always couples ownerless/immutable with the YELLOW text (sdd.md:L645)' },
    { file: 'web/tests/truth-copy.spec.js', kind: 'playwright', detail: 'copy suite asserting verbatim rendering + zero prohibited phrases' },
    { file: 'grimoires/loa/a2a/sprint-8/trust-inventory.md', kind: 'documented-analysis', detail: 'Sprint 8 YELLOW inventory (plan §D: "Sprint 8 inventory")' },
  ],
  'INV-37': [
    { file: 'tools/provenance/verify-census.sh', kind: 'ci-gate', detail: 'census + byte identity + excluded sources' },
    { file: 'tools/provenance/verify-pins.sh', kind: 'ci-gate', detail: 'immutable-pin discipline; no mutable ref as authority' },
    { file: 'tools/provenance/verify-static-analysis.sh', kind: 'ci-gate', detail: 'Sprint 8: the static-analysis toolchain itself cannot expand source authority' },
    { file: '.github/workflows/provenance.yml', kind: 'ci-gate', detail: 'every gate runs on every push (plan §D: "every sprint\'s CI")' },
  ],
};

// FB rows whose accepted method is review checklist / documented analysis
// (sprint.md §D: "FB-1, 6, 8, 9, 10, 11, 12 (review+scenario docs)"; "FB-17, 18
// (documented disclosure/analysis)"). prd.md:L669 assigns the method.
//
// Each target must CONTAIN the row it is cited for. Sprint 8's first pass cited
// whole-sprint `engineer-feedback.md` files by sprint number, which is where the
// row was *discussed*, not where it was *carried* — seven of nine targets never
// mentioned their row (review H-1/M-1). verify-traceability.sh now asserts the
// containment, so a repeat of that substitution fails the gate rather than
// reading as coverage.
const FB_REVIEW_ONLY = {
  'FB-1': 'grimoires/loa/a2a/sprint-3/evidence/fb-1-mining-redemption-independence.md',
  'FB-6': 'grimoires/loa/a2a/sprint-4/evidence/fb-6-9-10-12-scenario-notes.md',
  'FB-8': 'grimoires/loa/a2a/sprint-5/engineer-feedback.md',
  'FB-9': 'grimoires/loa/a2a/sprint-4/evidence/fb-6-9-10-12-scenario-notes.md',
  'FB-10': 'grimoires/loa/a2a/sprint-4/evidence/fb-6-9-10-12-scenario-notes.md',
  'FB-11': 'grimoires/loa/a2a/sprint-8/fb-11-analysis.md',
  'FB-12': 'grimoires/loa/a2a/sprint-4/evidence/fb-6-9-10-12-scenario-notes.md',
  'FB-17': 'grimoires/loa/a2a/sprint-8/fb-17-18-analysis.md',
  'FB-18': 'grimoires/loa/a2a/sprint-8/fb-17-18-analysis.md',
};

for (const [id, recs] of Object.entries(DECLARED)) for (const r of recs) add(id, { ...r, line: 0 });
for (const [id, file] of Object.entries(FB_REVIEW_ONLY)) {
  add(id, { file, line: 0, kind: 'review-checklist', detail: 'accepted method is review/documented analysis, not an automated test (prd.md:L669, sprint.md §D)' });
}

// ------------------------------------------------------------------- assembly
const rows = [];
for (let i = 1; i <= INV_MAX; i++) rows.push(`INV-${i}`);
for (let i = 1; i <= FB_MAX; i++) rows.push(`FB-${i}`);

const matrix = rows.map((id) => {
  const ev = (evidence.get(id) || []).slice().sort((a, b) => {
    const rank = { 'stateful-invariant': 0, 'forge-test': 1, playwright: 2, 'ci-gate': 3, implementation: 4, 'review-checklist': 5, 'documented-analysis': 6 };
    return (rank[a.kind] ?? 9) - (rank[b.kind] ?? 9) || a.file.localeCompare(b.file) || a.line - b.line;
  });
  const kinds = [...new Set(ev.map((e) => e.kind))];
  return { id, covered: ev.length > 0, methods: kinds, count: ev.length, evidence: ev };
});

const uncovered = matrix.filter((r) => !r.covered).map((r) => r.id);

mkdirSync(join(REPO, 'grimoires/loa/a2a/sprint-8'), { recursive: true });
writeFileSync(
  join(REPO, 'grimoires/loa/a2a/sprint-8/traceability.json'),
  JSON.stringify({
    schema_version: 1,
    generated_by: '/implement sprint-8, Task 8.2 (tools/traceability/build-matrix.mjs)',
    registers: { INV: INV_MAX, FB: FB_MAX },
    totals: {
      inv_covered: matrix.filter((r) => r.id.startsWith('INV') && r.covered).length,
      fb_covered: matrix.filter((r) => r.id.startsWith('FB') && r.covered).length,
      uncovered,
    },
    rows: matrix,
  }, null, 2) + '\n',
  'utf8',
);

// --------------------------------------------------------------- markdown view
const short = (e) => (e.line ? `${e.file}:${e.line}` : e.file);
const md = [];
md.push('# Sprint 8 — Traceability Matrix (INV-1…37, FB-1…18)');
md.push('');
md.push('> Generated by `tools/traceability/build-matrix.mjs` from the repository tree.');
md.push('> Verified by `tools/traceability/verify-traceability.sh` (fail-closed, runs in CI).');
md.push('');
md.push('Evidence is not forced into one shape. The accepted plan assigns each row a method');
md.push('(sprint.md §D; sdd.md:L867; prd.md:L669) — a row whose assigned method is a review');
md.push('checklist or a documented analysis is satisfied by naming that artifact, not by');
md.push('inventing an automated test to make the table look uniform. The bar is **named,');
md.push('reviewable evidence**.');
md.push('');
md.push(`**INV coverage:** ${matrix.filter((r) => r.id.startsWith('INV') && r.covered).length}/${INV_MAX}  •  `
  + `**FB coverage:** ${matrix.filter((r) => r.id.startsWith('FB') && r.covered).length}/${FB_MAX}`
  + (uncovered.length ? `  •  **UNCOVERED: ${uncovered.join(', ')}**` : '  •  **no uncovered row**'));
md.push('');
for (const reg of ['INV', 'FB']) {
  md.push(`## ${reg === 'INV' ? 'Invariants INV-1…37' : 'Failure behaviours FB-1…18'}`);
  md.push('');
  md.push('| ID | Method(s) | Evidence |');
  md.push('|---|---|---|');
  for (const r of matrix.filter((x) => x.id.startsWith(reg))) {
    const ev = r.evidence.slice(0, 4).map(short).map((s) => `\`${s}\``).join('<br>');
    const more = r.count > 4 ? `<br>…+${r.count - 4} more` : '';
    md.push(`| **${r.id}** | ${r.methods.join(', ') || '—'} | ${ev || '**none**'}${more} |`);
  }
  md.push('');
}
md.push('## Full evidence listing');
md.push('');
for (const r of matrix) {
  md.push(`### ${r.id} — ${r.count} evidence item(s)`);
  for (const e of r.evidence) md.push(`- \`${short(e)}\` — *${e.kind}* — ${e.detail}`);
  md.push('');
}
writeFileSync(join(REPO, 'grimoires/loa/a2a/sprint-8/traceability-matrix.md'), md.join('\n'), 'utf8');

console.log(`INV covered: ${matrix.filter((r) => r.id.startsWith('INV') && r.covered).length}/${INV_MAX}`);
console.log(`FB  covered: ${matrix.filter((r) => r.id.startsWith('FB') && r.covered).length}/${FB_MAX}`);
console.log(uncovered.length ? `UNCOVERED: ${uncovered.join(', ')}` : 'no uncovered row');
