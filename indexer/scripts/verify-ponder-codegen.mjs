#!/usr/bin/env node
// Standing gate: the delivered ponder application actually builds and generates.
//
// This exists because the failure it catches was silent. `ponder codegen` loads
// config, schema AND the API module; a broken import in any of them aborts the
// build. Ponder then shuts down through a path that exits **0** and, with the
// pretty logger, prints nothing at all. The observable signature of a completely
// non-functional indexer was therefore indistinguishable from success: a CI step
// running `ponder codegen` would go green while generating nothing.
//
// So this gate does not trust the exit code. It requires the artifacts to exist,
// to be non-empty, and to contain the accepted §3.3 tables — the build cannot be
// "successful" without having actually compiled the schema.
//
// Exit 0 = the delivered ponder path builds and generates. Exit 1 = it does not.

import { spawn } from 'node:child_process';
import { existsSync, readFileSync, rmSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const ENV_DTS = join(ROOT, 'ponder-env.d.ts');
const SCHEMA_GQL = join(ROOT, 'generated', 'schema.graphql');

// Every accepted §3.3 table, plus the pairing table the burn-cause join needs.
const REQUIRED_TYPES = ['settlement', 'supplyChange', 'redemption', 'strategicFlow', 'supplyChangePair'];

const failures = [];
const fail = (m) => failures.push(m);

console.log('Ponder codegen verification — generated artifacts, not exit codes\n');

// Remove prior output so a stale artifact from an earlier run cannot stand in
// for a build that no longer works.
for (const p of [ENV_DTS, SCHEMA_GQL]) rmSync(p, { force: true });

const env = {
  ...process.env,
  // Placeholders: codegen compiles the schema and never opens a connection. The
  // config fails closed on absence by design, so the gate must supply them.
  VUX_RIG_ADDRESS: process.env.VUX_RIG_ADDRESS ?? '0x0000000000000000000000000000000000000001',
  VUX_RESERVE_ADDRESS: process.env.VUX_RESERVE_ADDRESS ?? '0x0000000000000000000000000000000000000002',
  VUX_TREASURY_ADDRESS: process.env.VUX_TREASURY_ADDRESS ?? '0x0000000000000000000000000000000000000003',
  VUX_TOKEN_ADDRESS: process.env.VUX_TOKEN_ADDRESS ?? '0x0000000000000000000000000000000000000004',
};

// stdin is an open pipe that is never ended. Ponder builds through vite, and
// vite installs a stdin 'end' handler that terminates the process; handing the
// child /dev/null (`stdio: 'ignore'`) or a closed pipe delivers EOF immediately
// and kills the build before codegen runs. Holding stdin open is what makes this
// gate reproducible outside an interactive terminal.
const cliExit = await new Promise((resolve) => {
  const child = spawn(
    process.execPath,
    [join(ROOT, 'node_modules', 'ponder', 'dist', 'bin', 'ponder.js'), 'codegen'],
    { cwd: ROOT, env, stdio: ['pipe', 'pipe', 'pipe'] },
  );
  const timer = setTimeout(() => child.kill('SIGKILL'), 180_000);
  child.stdout.resume();
  child.stderr.resume();
  child.on('exit', (code) => {
    clearTimeout(timer);
    resolve(code ?? 1);
  });
  child.on('error', () => {
    clearTimeout(timer);
    resolve(1);
  });
});

// The exit code is recorded, never relied upon — see the header.
if (!existsSync(ENV_DTS)) fail('ponder-env.d.ts was not generated (the build aborted before codegen)');
else if (statSync(ENV_DTS).size === 0) fail('ponder-env.d.ts is empty');

if (!existsSync(SCHEMA_GQL)) {
  fail('generated/schema.graphql was not generated (the build aborted before codegen)');
} else {
  const gql = readFileSync(SCHEMA_GQL, 'utf8');
  if (gql.trim().length === 0) fail('generated/schema.graphql is empty');
  for (const t of REQUIRED_TYPES) {
    if (!new RegExp(`\\b${t}\\b`, 'i').test(gql)) {
      fail(`generated/schema.graphql does not mention the '${t}' table — the schema did not compile`);
    }
  }
}

console.log(`  ponder CLI exit code  : ${cliExit} (recorded, not trusted)`);
console.log(`  ponder-env.d.ts       : ${existsSync(ENV_DTS) ? `${statSync(ENV_DTS).size} bytes` : 'ABSENT'}`);
console.log(`  generated/schema.graphql: ${existsSync(SCHEMA_GQL) ? `${statSync(SCHEMA_GQL).size} bytes` : 'ABSENT'}`);
if (existsSync(SCHEMA_GQL)) console.log(`  accepted tables present : ${REQUIRED_TYPES.length}/${REQUIRED_TYPES.length}`);

console.log('');
if (failures.length) {
  console.log('VERDICT: FAIL — the delivered ponder path does not build.\n');
  for (const f of failures) console.log('  - ' + f);
  console.log('');
  process.exit(1);
}
console.log('VERDICT: PASS — config, schema and API modules all load; codegen produced the accepted tables.\n');
