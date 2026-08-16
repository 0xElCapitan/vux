#!/usr/bin/env node
// Runtime gate: the DELIVERED ponder application actually indexes a live chain.
//
// `verify-ponder-codegen.mjs` proves the app builds. This proves it RUNS: it
// deploys the scenario to anvil, starts `ponder start` against it, waits for the
// app's own API to serve indexed rows, and asserts those rows are the ones the
// chain produced. Nothing here consults the standalone fold — the fold is an
// independent oracle, not a substitute for exercising the shipped handlers.
//
// The gate is written so a ponder that never ran CANNOT pass: every assertion is
// about rows the app must have written, and absence is failure. A dead process,
// an empty database and a silent build error all land in the same place.
//
// Usage:  anvil --port 8545      (in another terminal)
//         node scripts/verify-ponder-runtime.mjs
//
// Exit 0 = the delivered indexer ran and produced the expected rows.

import { spawn } from 'node:child_process';
import { readFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPublicClient, createWalletClient, http, decodeEventLog } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { foundry } from 'viem/chains';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const REPO = join(ROOT, '..');
const RPC = process.env.VUX_RPC_URL ?? 'http://127.0.0.1:8545';
const PORT = Number(process.env.PONDER_PORT ?? 42169);
// anvil's first default account — a well-known test key, never a production secret.
const KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

const artifact = JSON.parse(readFileSync(join(REPO, 'out/TruthScenario.sol/TruthScenario.json'), 'utf8'));
const abi = artifact.abi;
const account = privateKeyToAccount(KEY);
const pub = createPublicClient({ chain: foundry, transport: http(RPC) });
const wallet = createWalletClient({ account, chain: foundry, transport: http(RPC) });

const failures = [];
const check = (cond, msg) => { if (!cond) failures.push(msg); return cond; };

let scenario;
const send = async (functionName, args = []) => {
  const hash = await wallet.writeContract({ address: scenario, abi, functionName, args });
  const r = await pub.waitForTransactionReceipt({ hash });
  if (r.status !== 'success') throw new Error(`${functionName} reverted`);
  return r;
};
const warp = async (s) => {
  await pub.request({ method: 'evm_increaseTime', params: [`0x${s.toString(16)}`] });
  await pub.request({ method: 'evm_mine', params: [] });
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

console.log('Ponder runtime verification — the delivered app against a live chain\n');

// --- 1. a scenario on chain ---------------------------------------------------
const dep = await pub.waitForTransactionReceipt({
  hash: await wallet.deployContract({ abi, bytecode: artifact.bytecode.object, args: [] }),
});
scenario = dep.contractAddress;
const startBlock = dep.blockNumber;

let A;
for (const log of dep.logs) {
  const d = (() => { try { return decodeEventLog({ abi, data: log.data, topics: log.topics }); } catch { return null; } })();
  if (d?.eventName === 'ScenarioDeployed') A = d.args;
}
if (!A) { console.error('scenario did not emit ScenarioDeployed'); process.exit(1); }

await send('take', [A.alice]);
await warp(600);
await send('take', [A.bob]);
const held = await pub.readContract({ address: scenario, abi, functionName: 'balanceOfVux', args: [A.alice] });
await send('redeem', [A.alice, held / 4n]);

// The H-1 proof, on a real chain: two identical burns in ONE transaction.
const DUP = held / 8n;
const dupReceipt = await send('doubleSelfBurn', [A.alice, DUP]);

const stack = await send('deployStrategicStack', [
  JSON.parse(readFileSync(join(REPO, 'out-v3core/VuxPoolDeployer.sol/VuxPoolDeployer.json'), 'utf8')).bytecode.object,
  JSON.parse(readFileSync(join(REPO, 'out/StrategicTreasury.sol/StrategicTreasury.json'), 'utf8')).bytecode.object,
]);
let treasury;
for (const log of stack.logs) {
  const d = (() => { try { return decodeEventLog({ abi, data: log.data, topics: log.topics }); } catch { return null; } })();
  if (d?.eventName === 'StrategicStackDeployed') treasury = d.args.treasury;
}
await send('provisionPol', [120_000n * 10n ** 18n, 240n * 10n ** 18n]);
await send('accrueFees', [20n * 10n ** 18n]);
await send('harvest');
// Ponder skips historical sync until the start block is finalized, and anvil's
// `finalized` tag trails the head. Mine past that window so the app indexes the
// scenario rather than idling — this advances the chain, it does not weaken the
// gate: every assertion below is still about the scenario's own logs.
for (let i = 0; i < 96; i++) await pub.request({ method: 'evm_mine', params: [] });

const headBlock = await pub.getBlockNumber();
const finalized = await pub.getBlock({ blockTag: 'finalized' }).catch(() => null);
console.log(`  scenario deployed and driven to block ${headBlock} (finalized ${finalized?.number ?? 'n/a'})`);
console.log(`  duplicate-burn tx ${dupReceipt.transactionHash} (2 x ${DUP})\n`);

// --- 2. run the delivered app -------------------------------------------------
rmSync(join(ROOT, '.ponder'), { recursive: true, force: true });

const env = {
  ...process.env,
  PONDER_RPC_URL_1: RPC,
  VUX_CHAIN_ID: '31337',
  VUX_START_BLOCK: String(startBlock),
  VUX_RIG_ADDRESS: A.rig,
  VUX_RESERVE_ADDRESS: A.reserve,
  VUX_TREASURY_ADDRESS: treasury,
  VUX_TOKEN_ADDRESS: A.vux,
};

// stdin stays an open pipe: ponder builds through vite, and vite kills the
// process on stdin EOF. See verify-ponder-codegen.mjs.
const child = spawn(
  process.execPath,
  [
    join(ROOT, 'node_modules', 'ponder', 'dist', 'bin', 'ponder.js'),
    'start',
    // `ponder start` refuses to run without an explicit database schema, which is
    // the correct fail-closed behaviour: an unnamed schema could collide with a
    // real deployment's tables. A run-scoped name keeps this gate isolated.
    '--schema',
    'vux_runtime_check',
    '--port',
    String(PORT),
    '--log-level',
    'warn',
  ],
  { cwd: ROOT, env, stdio: ['pipe', 'pipe', 'pipe'] },
);
let childLog = '';
child.stdout.on('data', (d) => { childLog += d; });
child.stderr.on('data', (d) => { childLog += d; });
let exited = null;
child.on('exit', (code) => { exited = code; });

const api = async (path) => {
  const r = await fetch(`http://127.0.0.1:${PORT}${path}`);
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.json();
};

// --- 3. wait for the app to serve indexed rows --------------------------------
let settlements = null;
let lastProbe = 'never probed';
const deadline = Date.now() + 180_000;
while (Date.now() < deadline) {
  if (exited !== null) break;
  try {
    const rows = await api('/settlements');
    lastProbe = `served ${Array.isArray(rows) ? `${rows.length} rows` : JSON.stringify(rows).slice(0, 200)}`;
    // Wait for the app to have caught up to the whole scenario, not merely to
    // have opened a port: two `take` calls means two `Settled` events.
    if (Array.isArray(rows) && rows.length >= 2) { settlements = rows; break; }
  } catch (e) {
    lastProbe = `probe error: ${e.message}`;
  }
  await sleep(2000);
}

let supplyChanges = [];
let stats = null;
if (settlements) {
  supplyChanges = await api('/supply-changes?limit=500');
  stats = await api('/stats');
}
child.kill('SIGKILL');

// --- 4. assertions about rows the app must have written -----------------------
check(exited === null, `ponder exited early with code ${exited}`);
check(settlements !== null, `the delivered ponder app never served indexed settlements (last probe: ${lastProbe})`);

if (settlements) {
  check(settlements.length >= 2, `expected >= 2 settlements (bootstrap + one ordinary), got ${settlements.length}`);

  const dupTx = dupReceipt.transactionHash.toLowerCase();
  const dupRows = supplyChanges.filter((r) => String(r.txHash).toLowerCase() === dupTx);
  // The H-1 property, proven through the SHIPPED handlers on real logs.
  check(dupRows.length === 2, `duplicate-burn tx produced ${dupRows.length} rows, expected 2`);
  check(
    new Set(dupRows.map((r) => r.id)).size === dupRows.length,
    'duplicate-burn rows do not carry distinct ids',
  );
  check(
    dupRows.every((r) => BigInt(r.delta) === -DUP),
    'duplicate-burn rows do not each carry the burned amount',
  );

  const causes = new Set(supplyChanges.map((r) => r.cause));
  for (const c of ['genesis', 'settlement_mint', 'redemption_burn', 'vyrf_burn', 'other_authorized_burn']) {
    check(causes.has(c), `no supply change indexed with cause '${c}'`);
  }

  // The app's own /stats must equal the chain, computed from ITS rows.
  const chainSupply = await pub.readContract({
    address: A.vux,
    abi: [{ type: 'function', name: 'totalSupply', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] }],
    functionName: 'totalSupply',
  });
  check(
    BigInt(stats.currentSupply) === chainSupply,
    `indexed S ${stats?.currentSupply} != chain totalSupply ${chainSupply}`,
  );

  console.log(`  settlements indexed     : ${settlements.length}`);
  console.log(`  supply changes indexed  : ${supplyChanges.length}`);
  console.log(`  duplicate-burn rows     : ${dupRows.length} (distinct ids: ${new Set(dupRows.map((r) => r.id)).size})`);
  console.log(`  causes present          : ${[...causes].sort().join(', ')}`);
  console.log(`  indexed S vs chain      : ${stats.currentSupply} / ${chainSupply}`);
}

console.log('');
if (failures.length) {
  console.log('VERDICT: FAIL — the delivered ponder path did not index as required.\n');
  for (const f of failures) console.log('  - ' + f);
  if (childLog.trim()) console.log('\n--- ponder output ---\n' + childLog.slice(-3000));
  process.exit(1);
}
console.log('VERDICT: PASS — the delivered ponder app indexed the live chain; its own rows match chain state.\n');
process.exit(0);
