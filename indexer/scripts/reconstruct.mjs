#!/usr/bin/env node
// Independent-reconstruction acceptance test (FR-14, prd.md:L538).
//
// Runs a scripted multi-op scenario against a live chain, then recomputes `S`,
// `B`, `B/S`, the per-settlement legs and every burn cause FROM LOGS ONLY, and
// compares the result to what the chain actually holds.
//
// The two sides are kept genuinely independent:
//   - the reconstruction side calls `eth_getLogs` and nothing else;
//   - the truth side calls `eth_call` (`totalSupply`, `backing`) and nothing else.
// Neither can borrow the other's answer.
//
// Usage:  anvil --port 8545          (in another terminal)
//         npm run reconstruct
//
// Exit 0 = reconstruction matches chain state with zero ambiguity.

import { createPublicClient, createWalletClient, http, decodeEventLog, parseAbi, getAddress } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { foundry } from 'viem/chains';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { reconstruct, checkSettlementLegs, CAUSE, STRATEGIC_CLASS } from '../src/lib/reconstruct.mjs';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const RPC = process.env.VUX_RPC_URL ?? 'http://127.0.0.1:8545';
// anvil's first default account — a well-known test key, never a production secret.
const KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

const artifact = JSON.parse(readFileSync(join(REPO, 'out/TruthScenario.sol/TruthScenario.json'), 'utf8'));

const account = privateKeyToAccount(KEY);
const pub = createPublicClient({ chain: foundry, transport: http(RPC) });
const wallet = createWalletClient({ account, chain: foundry, transport: http(RPC) });

const scenarioAbi = artifact.abi;
const failures = [];
const check = (cond, msg) => { if (!cond) failures.push(msg); return cond; };
const eq = (a, b, what) => check(a === b, `${what}: reconstructed ${a} != chain ${b}`);

async function send(functionName, args = []) {
  const hash = await wallet.writeContract({ address: scenario, abi: scenarioAbi, functionName, args });
  const r = await pub.waitForTransactionReceipt({ hash });
  if (r.status !== 'success') throw new Error(`${functionName} reverted`);
  return r;
}
async function warp(seconds) {
  await pub.request({ method: 'evm_increaseTime', params: [`0x${seconds.toString(16)}`] });
  await pub.request({ method: 'evm_mine', params: [] });
}

console.log(`Independent reconstruction — RPC ${RPC}\n`);

// --- deploy the scenario -----------------------------------------------------
const deployHash = await wallet.deployContract({ abi: scenarioAbi, bytecode: artifact.bytecode.object, args: [] });
const deployReceipt = await pub.waitForTransactionReceipt({ hash: deployHash });
const scenario = deployReceipt.contractAddress;
const genesisBlock = deployReceipt.blockNumber;

let addresses;
for (const log of deployReceipt.logs) {
  const d = (() => { try { return decodeEventLog({ abi: scenarioAbi, data: log.data, topics: log.topics }); } catch { return null; } })();
  if (d?.eventName === 'ScenarioDeployed') {
    addresses = {
      weth: d.args.weth, reserve: d.args.reserve, rig: d.args.rig, vux: d.args.vux,
      treasury: d.args.treasury, alice: d.args.alice, bob: d.args.bob, carol: d.args.carol,
    };
  }
}
if (!addresses) { console.error('scenario did not emit ScenarioDeployed'); process.exit(1); }
console.log(`  scenario  ${scenario}`);
console.log(`  vux ${addresses.vux}  reserve ${addresses.reserve}  rig ${addresses.rig}\n`);

const A = { alice: addresses.alice, bob: addresses.bob, carol: addresses.carol };

// --- the scripted multi-op scenario -----------------------------------------
console.log('  running scenario:');
await send('take', [A.alice]);                       console.log('    1. bootstrap consumed (Reserve -> ALICE)');
await warp(600);
await send('take', [A.bob]);                         console.log('    2. settlement: ALICE displaced by BOB (mint to ALICE)');
await warp(1200);
await send('take', [A.carol]);                       console.log('    3. settlement: BOB displaced by CAROL (mint to BOB)');

const aliceHeld = await pub.readContract({ address: scenario, abi: scenarioAbi, functionName: 'balanceOfVux', args: [A.alice] });
await send('redeem', [A.alice, aliceHeld / 2n]);     console.log('    4. redemption: ALICE burns half her mined VUX');
await send('donateToReserve', [3n * 10n ** 18n]);    console.log('    5. unsolicited 3 WETH donation into the Reserve');
await send('selfBurn', [A.alice, aliceHeld / 4n]);   console.log('    6. permissionless holder self-burn (no cause event)');

const prefixBlock = await pub.getBlockNumber();

await warp(2900);
await send('take', [A.alice]);                       console.log('    7. settlement late in the epoch (VEM-limited)');
await warp(300);
await send('take', [A.bob]);                         console.log('    8. settlement: another ordinary epoch');

// --- the harvest leg (Task 6.5's named final step) ---------------------------
// The canonical pool and the treasury are deployed from compiled artifact bytes
// read here in Node and passed in as `bytes`. No cheatcode is involved: the
// forge fixture's `vm.getCode`/`vm.readFile` only ever READ these same files,
// and the deployment itself is an ordinary CREATE.
const deployerArtifact = JSON.parse(
  readFileSync(join(REPO, 'out-v3core/VuxPoolDeployer.sol/VuxPoolDeployer.json'), 'utf8'),
);
const treasuryArtifact = JSON.parse(
  readFileSync(join(REPO, 'out/StrategicTreasury.sol/StrategicTreasury.json'), 'utf8'),
);

const stackReceipt = await send('deployStrategicStack', [
  deployerArtifact.bytecode.object,
  treasuryArtifact.bytecode.object,
]);
let polTreasury, polPool;
for (const log of stackReceipt.logs) {
  const d = (() => { try { return decodeEventLog({ abi: scenarioAbi, data: log.data, topics: log.topics }); } catch { return null; } })();
  if (d?.eventName === 'StrategicStackDeployed') { polTreasury = d.args.treasury; polPool = d.args.pool; }
}
if (!polTreasury) { console.error('strategic stack did not emit StrategicStackDeployed'); process.exit(1); }
console.log(`    9. canonical pool ${polPool} + treasury ${polTreasury} deployed from artifact bytes`);

await send('provisionPol', [120_000n * 10n ** 18n, 240n * 10n ** 18n]);
console.log('   10. POL position minted (real pool, real pay-in callback)');
await send('accrueFees', [20n * 10n ** 18n]);
console.log('   11. third-party round-trip swaps accrued BOTH fee legs');
const harvestReceipt = await send('harvest');
console.log('   12. harvestPol(): VUX fee leg burned, WETH fee leg into the Hard Reserve\n');

// The `StrategicTreasury` contract is the emitter of `VyrfHarvest`, so it is the
// address the fold must recognise for treasury events. The Rig's residual
// destination stays the plain `TREASURY` address the scenario was accepted with
// (sdd.md:L138), and is compared separately below.
const strategicSink = addresses.treasury;
addresses = { ...addresses, treasury: polTreasury };

// --- reconstruction side: logs only ------------------------------------------
const logs = await pub.getLogs({ fromBlock: genesisBlock, toBlock: 'latest' });
const R = reconstruct(logs, addresses);

// --- truth side: chain state only --------------------------------------------
const erc20 = parseAbi(['function totalSupply() view returns (uint256)', 'function balanceOf(address) view returns (uint256)']);
const chainSupply = await pub.readContract({ address: addresses.vux, abi: erc20, functionName: 'totalSupply' });
const chainBacking = await pub.readContract({ address: addresses.weth, abi: erc20, functionName: 'balanceOf', args: [addresses.reserve] });
const chainStrategic = await pub.readContract({ address: addresses.weth, abi: erc20, functionName: 'balanceOf', args: [strategicSink] });

console.log('  reconstruction vs chain state:');
console.log(`    S      logs=${R.supply}  chain=${chainSupply}`);
console.log(`    B      logs=${R.backing}  chain=${chainBacking}`);
const chainBps = chainSupply === 0n ? null : (chainBacking * 10n ** 27n) / chainSupply;
console.log(`    B/S    logs=${R.backingPerVuxRay}  chain=${chainBps}   (ray, floored)`);
console.log(`    Strategic contributed  logs=${R.strategicContributed}  chain(WETH@treasury)=${chainStrategic}`);

eq(R.supply, chainSupply, 'S');
eq(R.backing, chainBacking, 'B');
eq(R.backingPerVuxRay, chainBps, 'B/S');
eq(R.strategicContributed, chainStrategic, 'Strategic contributed principal');

// --- per-settlement legs ------------------------------------------------------
console.log(`\n  settlements reconstructed: ${R.settlements.length}`);
for (const s of R.settlements) {
  const problems = checkSettlementLegs(s);
  check(problems.length === 0, `settlement epoch ${s.epochId}: ${problems.join('; ')}`);
  const regime = s.bootstrap ? 'bootstrap' : s.qMint === s.qRaw ? 'clock-limited' : 'VEM-limited';
  console.log(`    epoch ${String(s.epochId).padStart(2)}  ${regime.padEnd(14)} price=${s.price}  legs ${s.kingLeg}/${s.strategicLeg}/${s.reserveLeg}  qRaw=${s.qRaw} qMint=${s.qMint}`);
}

// The mint side must agree with the settlement records, independently.
const settledMintTotal = R.settlements.reduce((a, s) => a + s.qMint, 0n);
eq(R.mintsByCause[CAUSE.SETTLEMENT_MINT] ?? 0n, settledMintTotal, 'settlement mints vs Settled.qMint total');

// --- burn causes ---------------------------------------------------------------
console.log('\n  supply changes by cause:');
for (const [cause, amount] of Object.entries(R.burnsByCause)) {
  if (amount > 0n) console.log(`    burn   ${cause.padEnd(24)} ${amount}`);
}
for (const [cause, amount] of Object.entries(R.mintsByCause)) {
  if (amount > 0n) console.log(`    mint   ${cause.padEnd(24)} ${amount}`);
}
check(R.ambiguities.length === 0, `burn-cause ambiguity: ${JSON.stringify(R.ambiguities)}`);
check(R.burnsByCause[CAUSE.REDEMPTION_BURN] === aliceHeld / 2n, 'redemption burn amount');
check(R.burnsByCause[CAUSE.OTHER_AUTHORIZED_BURN] === aliceHeld / 4n, 'holder self-burn booked as other_authorized_burn');
check((R.mintsByCause[CAUSE.GENESIS] ?? 0n) > 0n, 'genesis mints attributed');

// The identity that makes attribution load-bearing: every supply change is
// attributed, and the attributed deltas sum to the chain's supply.
const attributedSum = R.supplyChanges.reduce((a, s) => a + s.delta, 0n);
eq(attributedSum, chainSupply, 'sum of attributed supply changes');
check(R.supplyChanges.every((s) => Object.values(CAUSE).includes(s.cause)), 'every supply change carries a domain cause');

// --- idempotency and reorg (sdd.md:L836) ---------------------------------------
console.log('\n  idempotency / reorg:');
const dup = reconstruct([...logs, ...logs, ...logs], addresses);
check(dup.supply === R.supply && dup.backing === R.backing && dup.supplyChanges.length === R.supplyChanges.length,
  'idempotency: replaying the same logs changed the result');
console.log(`    replaying every log 3x -> identical (S=${dup.supply}, ${dup.supplyChanges.length} changes)`);

const shuffled = reconstruct([...logs].reverse(), addresses);
check(shuffled.supply === R.supply && shuffled.backing === R.backing, 'order independence: reversed delivery changed the result');
console.log('    reversed delivery order -> identical');

// Prefix stability is what reorg handling needs: dropping the logs of blocks
// above N must return exactly the state as of N.
const prefixLogs = logs.filter((l) => BigInt(l.blockNumber) <= prefixBlock);
const P1 = reconstruct(prefixLogs, addresses);
const P2 = reconstruct([...prefixLogs].reverse(), addresses);
check(P1.supply === P2.supply && P1.backing === P2.backing, 'prefix reconstruction is not order-stable');
console.log(`    truncate to block ${prefixBlock} -> S=${P1.supply}, B=${P1.backing} (stable)`);

// And an actual chain reorg: snapshot, mine divergent history, revert, re-read.
const snap = await pub.request({ method: 'evm_snapshot', params: [] });
await warp(400);
await send('take', [A.carol]);
const forkedLogs = await pub.getLogs({ fromBlock: genesisBlock, toBlock: 'latest' });
const F = reconstruct(forkedLogs, addresses);
check(F.supply !== R.supply || F.settlements.length > R.settlements.length, 'the divergent branch did not actually diverge');
await pub.request({ method: 'evm_revert', params: [snap] });
const afterRevert = await pub.getLogs({ fromBlock: genesisBlock, toBlock: 'latest' });
const AR = reconstruct(afterRevert, addresses);
check(AR.supply === R.supply && AR.backing === R.backing && AR.settlements.length === R.settlements.length,
  `reorg: after reverting the divergent branch, reconstruction did not return to the pre-fork state (S=${AR.supply} vs ${R.supply})`);
console.log(`    real reorg: branch added epoch ${F.settlements.length}, reverted -> back to ${AR.settlements.length} settlements, S=${AR.supply}`);

// Chain state must agree after the revert too — the true end-to-end round trip.
const supplyAfterRevert = await pub.readContract({ address: addresses.vux, abi: erc20, functionName: 'totalSupply' });
eq(AR.supply, supplyAfterRevert, 'S after reorg revert');

// --- strategic flows never say "backing" ----------------------------------------
const badClass = R.strategicFlows.filter((f) => /backing/i.test(f.class));
check(badClass.length === 0, `a strategic flow class contains "backing": ${JSON.stringify(badClass)}`);
check(R.strategicFlows.some((f) => f.class === STRATEGIC_CLASS[1]), 'no ContributedPrincipal flow reconstructed');

// --- verdict ---------------------------------------------------------------------
console.log('');
if (failures.length) {
  console.log('VERDICT: FAIL — reconstruction does not match chain state.\n');
  for (const f of failures) console.log('  - ' + f);
  process.exit(1);
}
console.log('VERDICT: PASS — indexer-only recompute matches chain state with zero ambiguity.');
console.log(`         ${R.logsConsidered} logs -> ${R.settlements.length} settlements, ${R.supplyChanges.length} attributed supply changes, 0 ambiguities.`);
process.exit(0);
