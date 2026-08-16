#!/usr/bin/env node
// Build the static export with placeholder deployment facts, so the browser
// suite can exercise the DATA-AVAILABLE branches as well as the degraded ones.
//
// WHY THIS EXISTS. `NEXT_PUBLIC_*` values are inlined at build time, so a build
// with no RPC configured can only ever render the unavailable path — `client()`
// returns null and no read is even attempted. The copy suite was built that way,
// which is why it proved the degraded states thoroughly and left every
// price-available branch dark. M-4 lived in one of those dark branches.
//
// The RPC host here is deliberately unroutable. Tests that want live data
// intercept it with `page.route()` and fulfil it themselves; tests that want the
// degraded state simply do not, and the connection is refused immediately. One
// artifact serves both, and neither needs polling disabled or price updates
// suppressed to get its result.
//
// The addresses are obvious placeholders. Real deployment identities are R-14
// founder facts (prd.md:L335) and are not recorded in this repository.

import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

const TEST_ENV = {
  NEXT_PUBLIC_RPC_URL: 'http://127.0.0.1:1/rpc',
  NEXT_PUBLIC_CHAIN_ID: '31337',
  NEXT_PUBLIC_CHAIN_NAME: 'Test',
  NEXT_PUBLIC_LENS_ADDRESS: '0x00000000000000000000000000000000000f0001',
  NEXT_PUBLIC_RIG_ADDRESS: '0x00000000000000000000000000000000000f0002',
  NEXT_PUBLIC_RESERVE_ADDRESS: '0x00000000000000000000000000000000000f0003',
  NEXT_PUBLIC_VUX_ADDRESS: '0x00000000000000000000000000000000000f0004',
  NEXT_PUBLIC_WETH_ADDRESS: '0x00000000000000000000000000000000000f0005',
};

console.log('Building the static export with test deployment facts:');
for (const [k, v] of Object.entries(TEST_ENV)) console.log(`  ${k}=${v}`);
console.log('');

const child = spawn(process.execPath, [join(ROOT, 'node_modules', 'next', 'dist', 'bin', 'next'), 'build'], {
  cwd: ROOT,
  env: { ...process.env, ...TEST_ENV },
  stdio: 'inherit',
});
child.on('exit', (code) => process.exit(code ?? 1));
