// Audit M-6: the wallet must be on THIS deployment's chain before anything is
// signed.
//
// `ADDRESSES` are chain-scoped facts. On another chain the same 20 bytes are a
// different contract, or nothing at all — and the take flow's FIRST action is
// `approve(rig, maxPrice)` against `ADDRESSES.weth`. So the property under test
// is not "a warning is shown" but "zero signature requests are made".
//
// The harness is deliberately self-contained rather than shared with
// `take-guard.spec.js`: that file pins the closed M-4 guard, and refactoring it
// to hand this suite a chain knob would put a previously-approved regression at
// risk for no benefit.

import { test, expect } from '@playwright/test';
import { encodeAbiParameters, parseAbiParameters, toFunctionSelector } from 'viem';

const RPC_URL = 'http://127.0.0.1:1/rpc';
const ACCEPTED_CHAIN_ID = 31337; // the test build's NEXT_PUBLIC_CHAIN_ID
const ACCEPTED_HEX = '0x7a69';
const FOREIGN_HEX = '0x1'; // Ethereum mainnet — a wallet left on the wrong network

const SEL = {
  rawClockLimit: toFunctionSelector('function rawClockLimit() view returns (uint256)'),
  estimate: toFunctionSelector('function estimateIfDisplacedNow() view returns (uint256,uint256,uint256,uint256)'),
  hardStats: toFunctionSelector('function hardStats() view returns (uint256,uint256,uint256)'),
  take: toFunctionSelector('function take(uint256 maxPrice)'),
};

const P1 = 25_000_000_000_000_000_000n;
const Q_RAW = 2_400_000_000_000_000_000_000n;
const u256 = (...v) => encodeAbiParameters(parseAbiParameters(v.map(() => 'uint256').join(',')), v);
const ACCOUNT = '0x00000000000000000000000000000000000000a1';
const TX_HASH = `0x${'11'.repeat(32)}`;
const B32 = (b) => `0x${b.repeat(32)}`;

/**
 * An EIP-1193 provider whose reported chain is under the test's control.
 *
 * `window.__sent` records every `eth_sendTransaction`. A wrong-chain assertion
 * is only meaningful if a send WOULD otherwise have been recorded, which the
 * correct-chain test in this same file establishes.
 */
async function installWallet(page, { chainIdHex }) {
  await page.addInitScript(
    ({ account, txHash, rpc, chainIdHex: initialChain }) => {
      window.__sent = [];
      window.__chainId = initialChain;
      const listeners = {};
      window.ethereum = {
        isMetaMask: true,
        request: async ({ method, params }) => {
          if (method === 'eth_requestAccounts' || method === 'eth_accounts') return [account];
          // The WALLET's chain, deliberately independent of the read transport.
          if (method === 'eth_chainId') return window.__chainId;
          if (method === 'net_version') return String(parseInt(window.__chainId, 16));
          if (method === 'wallet_switchEthereumChain') {
            // A switch the user declines: the wallet stays where it was. Nothing
            // may treat an ATTEMPTED switch as a successful one.
            return null;
          }
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
        on: (ev, fn) => { (listeners[ev] ??= []).push(fn); },
        removeListener: (ev, fn) => {
          listeners[ev] = (listeners[ev] ?? []).filter((f) => f !== fn);
        },
      };
      // Move the wallet to another chain the way a wallet actually does it.
      window.__emitChainChanged = (hex) => {
        window.__chainId = hex;
        for (const fn of listeners.chainChanged ?? []) fn(hex);
      };
    },
    { account: ACCOUNT, txHash: TX_HASH, rpc: RPC_URL, chainIdHex },
  );
}

/** Reads always succeed, so a withheld transaction can only be the chain guard. */
async function installRpc(page, state) {
  await page.route('**/rpc', async (route) => {
    const body = JSON.parse(route.request().postData() ?? '{}');
    const reply = (result) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ jsonrpc: '2.0', id: body.id ?? 1, result }),
      });
    switch (body.method) {
      case 'eth_call': {
        const data = body.params?.[0]?.data ?? '';
        if (data.startsWith(SEL.estimate)) return reply(u256(Q_RAW, state.price, Q_RAW, Q_RAW));
        if (data.startsWith(SEL.rawClockLimit)) return reply(u256(Q_RAW));
        if (data.startsWith(SEL.hardStats)) return reply(u256(1n, 1n, 1n));
        return reply(u256(0n));
      }
      case 'eth_blockNumber':
        return reply(`0x${(++state.block).toString(16)}`);
      case 'eth_chainId':
        return reply(ACCEPTED_HEX);
      case 'net_version':
        return reply(String(ACCEPTED_CHAIN_ID));
      case 'eth_getTransactionCount':
        return reply('0x0');
      case 'eth_gasPrice':
      case 'eth_maxPriorityFeePerGas':
        return reply('0x1');
      case 'eth_estimateGas':
        return reply('0x5208');
      case 'eth_getBlockByNumber':
      case 'eth_getBlockByHash':
        return reply({
          number: `0x${state.block.toString(16)}`, hash: B32('22'), parentHash: B32('33'),
          nonce: '0x0000000000000000', sha3Uncles: B32('44'), logsBloom: `0x${'00'.repeat(256)}`,
          transactionsRoot: B32('55'), stateRoot: B32('66'), receiptsRoot: B32('77'),
          miner: `0x${'00'.repeat(20)}`, difficulty: '0x0', totalDifficulty: '0x0', extraData: '0x',
          size: '0x0', gasLimit: '0x1c9c380', gasUsed: '0x5208', timestamp: '0x1',
          transactions: [], uncles: [],
        });
      case 'eth_getTransactionByHash':
        return reply({
          hash: TX_HASH, nonce: '0x0', blockHash: B32('22'), blockNumber: '0x1',
          transactionIndex: '0x0', from: ACCOUNT, to: `0x${'00'.repeat(19)}01`,
          value: '0x0', gas: '0x5208', gasPrice: '0x1', input: '0x', type: '0x0',
          v: '0x1b', r: B32('88'), s: B32('99'), chainId: ACCEPTED_HEX,
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

const connect = async (page) => {
  await page.getByTestId('wallet-connect').click();
  await expect(page.getByTestId('wallet-connected')).toBeVisible({ timeout: 20_000 });
};
const sentCount = (page) => page.evaluate(() => (window.__sent ?? []).length);

test.describe('chain verification before any signature (audit M-6)', () => {
  test('a wrong-chain wallet produces zero signature requests on take', async ({ page }) => {
    test.setTimeout(120_000);
    await installWallet(page, { chainIdHex: FOREIGN_HEX });
    await installRpc(page, { price: P1, block: 1 });
    await page.goto('/');

    // Reads are healthy — a price is on screen. Only the chain is wrong.
    await expect(page.getByTestId('take-maxprice')).toContainText('25.000000', { timeout: 30_000 });
    await connect(page);

    // The mismatch is named, not merely implied.
    await expect(page.getByTestId('wrong-network')).toBeVisible({ timeout: 20_000 });
    await expect(page.getByTestId('wrong-network-expected')).toHaveText(String(ACCEPTED_CHAIN_ID));

    // And the transaction is withdrawn entirely, not just disabled.
    await expect(page.getByTestId('take-submit')).toHaveCount(0);
    expect(await sentCount(page), 'no approval and no take may be requested').toBe(0);
  });

  test('a wrong-chain wallet produces zero signature requests on redeem', async ({ page }) => {
    test.setTimeout(120_000);
    await installWallet(page, { chainIdHex: FOREIGN_HEX });
    await installRpc(page, { price: P1, block: 1 });
    await page.goto('/redeem');
    await connect(page);

    await expect(page.getByTestId('wrong-network')).toBeVisible({ timeout: 20_000 });
    await expect(page.getByTestId('redeem-submit')).toHaveCount(0);
    expect(await sentCount(page), 'no redeem may be requested off-chain-of-record').toBe(0);
  });

  test('a declined switch is not treated as success', async ({ page }) => {
    test.setTimeout(120_000);
    await installWallet(page, { chainIdHex: FOREIGN_HEX });
    await installRpc(page, { price: P1, block: 1 });
    await page.goto('/');
    await connect(page);

    await expect(page.getByTestId('wrong-network-switch')).toBeVisible({ timeout: 20_000 });
    await page.getByTestId('wrong-network-switch').click();

    // The stub wallet does not actually move. Readiness must not advance.
    await expect(page.getByTestId('wrong-network')).toBeVisible();
    await expect(page.getByTestId('take-submit')).toHaveCount(0);
    expect(await sentCount(page)).toBe(0);
  });

  test('the correct chain still sends the canonical take — the guard is not a blanket block', async ({ page }) => {
    test.setTimeout(180_000);
    await installWallet(page, { chainIdHex: ACCEPTED_HEX });
    await installRpc(page, { price: P1, block: 1 });
    await page.goto('/');

    await expect(page.getByTestId('take-maxprice')).toContainText('25.000000', { timeout: 30_000 });
    await connect(page);
    await expect(page.getByTestId('wrong-network')).toHaveCount(0);

    await page.getByTestId('take-submit').click();
    // approve + take
    await expect.poll(() => sentCount(page), { timeout: 60_000 }).toBe(2);

    const sent = await page.evaluate(() => window.__sent);
    const take = sent.find((t) => (t.data ?? '').startsWith(SEL.take));
    expect(take, 'the canonical take is still reachable on the accepted chain').toBeTruthy();
    // M-4 preserved: the guard is still the price the user saw, unchanged by M-6.
    expect(BigInt(`0x${take.data.slice(10)}`)).toBe(P1);
  });

  test('a chain change after render invalidates readiness before any further send', async ({ page }) => {
    test.setTimeout(180_000);
    await installWallet(page, { chainIdHex: ACCEPTED_HEX });
    await installRpc(page, { price: P1, block: 1 });
    await page.goto('/');

    await expect(page.getByTestId('take-maxprice')).toContainText('25.000000', { timeout: 30_000 });
    await connect(page);
    await expect(page.getByTestId('take-submit')).toBeVisible();

    // The wallet moves under the open page, exactly as a user switching networks
    // in their extension would.
    await page.evaluate((hex) => window.__emitChainChanged(hex), FOREIGN_HEX);

    await expect(page.getByTestId('wrong-network')).toBeVisible({ timeout: 30_000 });
    await expect(page.getByTestId('take-submit')).toHaveCount(0);
    expect(await sentCount(page), 'stale readiness must not survive a chain change').toBe(0);
  });
});
