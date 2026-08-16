'use client';

// The read layer. Every value a surface shows arrives through here, together
// with whether it is actually current.
//
// The rule this module exists to enforce: a read either produced a fresh value
// or it did not. There is no third state where a stale number is passed onward
// wearing a live label. `useTruth` returns `{ value, unavailable, reason }`, and
// callers cannot get at a value without also getting at its availability.

import { useCallback, useEffect, useRef, useState } from 'react';
import { createPublicClient, http } from 'viem';

/** Deployment-time facts (R-14). Supplied by environment; never frozen here. */
export const ADDRESSES = {
  lens: process.env.NEXT_PUBLIC_LENS_ADDRESS ?? '',
  reserve: process.env.NEXT_PUBLIC_RESERVE_ADDRESS ?? '',
  rig: process.env.NEXT_PUBLIC_RIG_ADDRESS ?? '',
  vux: process.env.NEXT_PUBLIC_VUX_ADDRESS ?? '',
  weth: process.env.NEXT_PUBLIC_WETH_ADDRESS ?? '',
};
export const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL ?? '';
export const INDEXER_URL = process.env.NEXT_PUBLIC_INDEXER_URL ?? '';

/** A read is treated as no longer current after this long. */
export const STALE_AFTER_MS = 30_000;

export const LENS_ABI = [
  { type: 'function', name: 'rawClockLimit', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  {
    type: 'function', name: 'estimateIfDisplacedNow', stateMutability: 'view', inputs: [],
    outputs: [
      { name: 'estimateQmint', type: 'uint256' }, { name: 'price', type: 'uint256' },
      { name: 'qRaw', type: 'uint256' }, { name: 'qSafeEst', type: 'uint256' },
    ],
  },
  {
    type: 'function', name: 'hardStats', stateMutability: 'view', inputs: [],
    outputs: [{ name: 'B', type: 'uint256' }, { name: 'S', type: 'uint256' }, { name: 'bPerSRay', type: 'uint256' }],
  },
  { type: 'function', name: 'wethNeededForFullQraw', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'strategicContributed', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
];

export const RESERVE_ABI = [
  { type: 'function', name: 'previewRedeem', stateMutability: 'view', inputs: [{ type: 'uint256' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'redeem', stateMutability: 'nonpayable', inputs: [{ name: 'q', type: 'uint256' }, { name: 'to', type: 'address' }], outputs: [{ type: 'uint256' }] },
];

export const WETH_ABI = [
  { type: 'function', name: 'approve', stateMutability: 'nonpayable', inputs: [{ name: 'spender', type: 'address' }, { name: 'value', type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'balanceOf', stateMutability: 'view', inputs: [{ type: 'address' }], outputs: [{ type: 'uint256' }] },
];

export const RIG_ABI = [
  { type: 'function', name: 'currentPrice', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'take', stateMutability: 'nonpayable', inputs: [{ name: 'maxPrice', type: 'uint256' }], outputs: [] },
];

function client() {
  if (!RPC_URL) return null;
  return createPublicClient({ transport: http(RPC_URL) });
}

/**
 * Read protocol state, reporting availability as a first-class result.
 *
 * @param {(c: import('viem').PublicClient) => Promise<any>} read
 * @param {number} pollMs
 */
export function useTruth(read, pollMs = 12_000) {
  const [state, setState] = useState({ value: null, unavailable: true, reason: 'loading', at: null });
  const readRef = useRef(read);
  readRef.current = read;

  const run = useCallback(async () => {
    const c = client();
    if (!c) {
      setState({ value: null, unavailable: true, reason: 'no-rpc', at: null });
      return;
    }
    try {
      const value = await readRef.current(c);
      setState({ value, unavailable: false, reason: null, at: Date.now() });
    } catch (err) {
      // The previous value is DROPPED, not retained. Keeping it would be exactly
      // the stale-as-live presentation the requirement forbids (sdd.md:L836).
      setState({ value: null, unavailable: true, reason: 'rpc-failed', at: null, error: String(err?.shortMessage ?? err?.message ?? err) });
    }
  }, []);

  useEffect(() => {
    let alive = true;
    const tick = () => { if (alive) run(); };
    tick();
    const id = setInterval(tick, pollMs);
    return () => { alive = false; clearInterval(id); };
  }, [run, pollMs]);

  // Age out a value that stopped refreshing, even if no read has thrown yet.
  const [, force] = useState(0);
  useEffect(() => {
    const id = setInterval(() => force((n) => n + 1), 5_000);
    return () => clearInterval(id);
  }, []);

  if (!state.unavailable && state.at && Date.now() - state.at > STALE_AFTER_MS) {
    return { ...state, value: null, unavailable: true, reason: 'stale', staleSeconds: Math.round((Date.now() - state.at) / 1000) };
  }
  return state;
}

/** Fetch from the read-only indexer, with the same availability contract. */
export function useIndexer(path, pollMs = 15_000) {
  const [state, setState] = useState({ value: null, unavailable: true, reason: 'loading' });
  useEffect(() => {
    let alive = true;
    const run = async () => {
      if (!INDEXER_URL) { if (alive) setState({ value: null, unavailable: true, reason: 'no-indexer' }); return; }
      try {
        const r = await fetch(`${INDEXER_URL}${path}`);
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        const value = await r.json();
        if (alive) setState({ value, unavailable: false, reason: null });
      } catch (err) {
        if (alive) setState({ value: null, unavailable: true, reason: 'indexer-failed', error: String(err?.message ?? err) });
      }
    };
    run();
    const id = setInterval(run, pollMs);
    return () => { alive = false; clearInterval(id); };
  }, [path, pollMs]);
  return state;
}

const RAY = 10n ** 27n;

/** Format wei-ish integers without inventing precision. */
export function formatUnits18(v, dp = 6) {
  if (v === null || v === undefined) return null;
  const n = BigInt(v);
  const neg = n < 0n;
  const a = neg ? -n : n;
  const whole = a / 10n ** 18n;
  const frac = (a % 10n ** 18n).toString().padStart(18, '0').slice(0, dp);
  return `${neg ? '-' : ''}${whole.toLocaleString('en-US')}${dp > 0 ? '.' + frac : ''}`;
}

/** Backing per VUX from the ray value, floored — never rounded up (INV-16). */
export function formatRay(v, dp = 8) {
  if (v === null || v === undefined) return null;
  const n = BigInt(v);
  const whole = n / RAY;
  const frac = (n % RAY).toString().padStart(27, '0').slice(0, dp);
  return `${whole.toString()}.${frac}`;
}
