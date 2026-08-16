// M-4 regression — the `take` guard across MORE THAN ONE transaction.
//
// The defect this pins: `TakeFlow` held the first click's price in component
// state and never cleared it, so the displayed maximum froze forever and a second
// take silently reused the guard the user had confirmed for the first one.
//
// Every other browser test runs with no RPC reachable, which is exactly why the
// bug survived: `price === null`, so the whole price-available branch was dark.
// This file runs against `scripts/build-with-test-env.mjs` (an unroutable RPC
// host) and fulfils the reads itself, so the live branch actually renders.
//
// Polling is NOT disabled and price updates are NOT suppressed — phase 2 depends
// on a real poll landing a genuinely different price.
//
// Discrimination against the reviewed buggy build: phase 2 fails (the displayed
// maximum stays frozen at P1) and phase 3 fails (the second take re-sends P1).

import { test, expect } from '@playwright/test';
import { toFunctionSelector, encodeAbiParameters, parseAbiParameters } from 'viem';

/** Must match `scripts/build-with-test-env.mjs`. */
const RPC_URL = 'http://127.0.0.1:1/rpc';

const SEL = {
  rawClockLimit: toFunctionSelector('function rawClockLimit() view returns (uint256)'),
  estimate: toFunctionSelector('function estimateIfDisplacedNow() view returns (uint256,uint256,uint256,uint256)'),
  hardStats: toFunctionSelector('function hardStats() view returns (uint256,uint256,uint256)'),
  take: toFunctionSelector('function take(uint256 maxPrice)'),
};

const P1 = 25_000_000_000_000_000_000n; // 25 WETH
const P2 = 18_000_000_000_000_000_000n; // 18 WETH — the Dutch price after decay
const Q_RAW = 2_400_000_000_000_000_000_000n;

const u256 = (...v) => encodeAbiParameters(parseAbiParameters(v.map(() => 'uint256').join(',')), v);
const ACCOUNT = '0x00000000000000000000000000000000000000a1';
const TX_HASH = `0x${'11'.repeat(32)}`;
const B32 = (b) => `0x${b.repeat(32)}`;

/**
 * An EIP-1193 provider that records what it is asked to SEND and delegates every
 * ordinary read to the mocked HTTP endpoint. One mock stays authoritative, so the
 * wallet transport and the public transport cannot disagree about chain state.
 */
async function installWallet(page) {
  await page.addInitScript(
    ({ account, txHash, rpc }) => {
      window.__sent = [];
      window.ethereum = {
        isMetaMask: true,
        request: async ({ method, params }) => {
          if (method === 'eth_requestAccounts' || method === 'eth_accounts') return [account];
          if (method === 'eth_sendTransaction') {
            window.__sent.push(params[0]);
            return txHash;
          }
          const r = await fetch(rpc, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params: params ?? [] }),
          });
          const j = await r.json();
          if (j.error) throw new Error(j.error.message ?? 'rpc error');
          return j.result;
        },
        on: () => {},
        removeListener: () => {},
      };
    },
    { account: ACCOUNT, txHash: TX_HASH, rpc: RPC_URL },
  );
}

/** Fulfil every read. `state.price` is mutable between polls; `state.block` advances. */
async function installRpc(page, state) {
  await page.route('**/rpc', async (route) => {
    const body = JSON.parse(route.request().postData() ?? '{}');
    const reply = (result) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ jsonrpc: '2.0', id: body.id, result }),
      });

    switch (body.method) {
      case 'eth_call': {
        const data = body.params?.[0]?.data ?? '';
        if (data.startsWith(SEL.estimate)) return reply(u256(Q_RAW, state.price, Q_RAW, Q_RAW));
        if (data.startsWith(SEL.rawClockLimit)) return reply(u256(Q_RAW));
        if (data.startsWith(SEL.hardStats)) return reply(u256(1n, 1n, 1n));
        return reply(u256(0n));
      }
      // The height advances on every call. viem re-checks a pending receipt when
      // it observes a NEW block, so a constant height would leave
      // `waitForTransactionReceipt` hanging — a live chain does not stand still.
      case 'eth_blockNumber':
        return reply(`0x${(++state.block).toString(16)}`);
      case 'eth_chainId':
        return reply('0x7a69'); // 31337
      case 'net_version':
        return reply('31337');
      case 'eth_getTransactionCount':
        return reply('0x0');
      case 'eth_gasPrice':
      case 'eth_maxPriorityFeePerGas':
        return reply('0x1');
      case 'eth_estimateGas':
        return reply('0x5208');
      case 'eth_getBlockByNumber':
      case 'eth_getBlockByHash':
        // No `baseFeePerGas`: keeps fee estimation on the legacy gas path.
        return reply({
          number: `0x${state.block.toString(16)}`, hash: B32('22'), parentHash: B32('33'),
          nonce: '0x0000000000000000', sha3Uncles: B32('44'), logsBloom: `0x${'00'.repeat(256)}`,
          transactionsRoot: B32('55'), stateRoot: B32('66'), receiptsRoot: B32('77'),
          miner: `0x${'00'.repeat(20)}`, difficulty: '0x0', totalDifficulty: '0x0', extraData: '0x',
          size: '0x0', gasLimit: '0x1c9c380', gasUsed: '0x5208', timestamp: '0x1',
          transactions: [], uncles: [],
        });
      // `waitForTransactionReceipt` looks the transaction up before it will
      // accept a receipt; returning null here leaves it waiting indefinitely.
      case 'eth_getTransactionByHash':
        return reply({
          hash: TX_HASH, nonce: '0x0', blockHash: B32('22'), blockNumber: '0x1',
          transactionIndex: '0x0', from: ACCOUNT, to: `0x${'00'.repeat(19)}01`,
          value: '0x0', gas: '0x5208', gasPrice: '0x1', input: '0x', type: '0x0',
          v: '0x1b', r: B32('88'), s: B32('99'), chainId: '0x7a69',
        });
      case 'eth_getTransactionReceipt':
        return reply({
          transactionHash: TX_HASH, transactionIndex: '0x0', blockHash: B32('22'),
          blockNumber: '0x1', from: ACCOUNT, to: `0x${'00'.repeat(19)}01`,
          cumulativeGasUsed: '0x5208', gasUsed: '0x5208', contractAddress: null,
          logs: [], logsBloom: `0x${'00'.repeat(256)}`, status: '0x1', type: '0x0',
          effectiveGasPrice: '0x1',
        });
      default:
        return reply(null);
    }
  });
}

/** The `maxPrice` argument of each recorded `Rig.take(uint256)`, in order. */
async function sentTakeGuards(page) {
  const sent = await page.evaluate(() => window.__sent ?? []);
  return sent.filter((t) => (t.data ?? '').startsWith(SEL.take)).map((t) => BigInt(`0x${t.data.slice(10)}`));
}

async function connect(page) {
  await page.getByTestId('wallet-connect').click();
  await expect(page.getByTestId('wallet-connected')).toBeVisible({ timeout: 20_000 });
}

test.describe('take guard across successive transactions (M-4)', () => {
  test('the guard tracks the live price and is never reused from an earlier take', async ({ page }) => {
    test.setTimeout(180_000); // a real poll cycle is 12s and this waits for one

    const state = { price: P1, block: 1 };
    await installWallet(page);
    await installRpc(page, state);
    await page.goto('/');

    // ---- phase 1: a live price renders, and it is what gets sent -------------
    await expect(page.getByTestId('take-maxprice')).toContainText('25.000000', { timeout: 30_000 });
    await expect(page.getByTestId('take-unavailable')).toHaveCount(0);
    await connect(page);

    await page.getByTestId('take-submit').click();
    await expect.poll(() => sentTakeGuards(page).then((g) => g.length), { timeout: 60_000 }).toBe(1);
    expect((await sentTakeGuards(page))[0], 'the first take sends the price the user saw').toBe(P1);

    // ---- phase 2: the price moves; the display must follow it ----------------
    // The reviewed build froze the displayed maximum at P1 here, forever.
    state.price = P2;
    await expect(page.getByTestId('take-maxprice')).toContainText('18.000000', { timeout: 90_000 });
    await expect(page.getByTestId('take-maxprice')).not.toContainText('25.000000');

    // ---- phase 3: the second take uses the SECOND confirmation ---------------
    await page.getByTestId('take-submit').click();
    await expect.poll(() => sentTakeGuards(page).then((g) => g.length), { timeout: 60_000 }).toBe(2);

    const guards = await sentTakeGuards(page);
    expect(guards[1], 'the second take sends the price confirmed for it').toBe(P2);
    expect(guards[1], 'the second take does not reuse the first take guard').not.toBe(guards[0]);
  });

  test('the approval ceiling equals the guard of the take it accompanies', async ({ page }) => {
    test.setTimeout(120_000);
    const state = { price: P1, block: 1 };
    await installWallet(page);
    await installRpc(page, state);
    await page.goto('/');

    await expect(page.getByTestId('take-maxprice')).toContainText('25.000000', { timeout: 30_000 });
    await connect(page);
    await page.getByTestId('take-submit').click();

    await expect.poll(() => page.evaluate(() => window.__sent.length), { timeout: 60_000 }).toBe(2);
    const sent = await page.evaluate(() => window.__sent);
    // approve(spender, value) — `value` is the second word of the calldata.
    expect(BigInt(`0x${sent[0].data.slice(10 + 64)}`)).toBe(P1);
  });

  test('the H-2 safety property survives a build that HAS an RPC configured', async ({ page }) => {
    // The other suites rely on the degraded path. With an RPC now compiled in,
    // an unfulfilled read must still withdraw the transaction entirely.
    await page.route('**/rpc', (route) => route.abort());
    await page.goto('/');
    await expect(page.getByTestId('take-unavailable')).toBeVisible({ timeout: 30_000 });
    await expect(page.getByTestId('take-submit')).toHaveCount(0);
    await expect(page.getByTestId('take-maxprice')).toHaveCount(0);
  });
});
