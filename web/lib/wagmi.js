'use client';

// Wallet configuration — the accepted wagmi/viem stack, nothing added.
//
// `injected()` is wagmi's built-in connector for a browser-provided wallet. No
// WalletConnect project, no hosted relay, no server component: the user's own
// extension signs, and this app never sees a key. That is the accepted posture
// (sdd.md:L451 — "none holds keys or custody") and it is why a static export can
// carry transaction flows at all.

import { createConfig, http } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { RPC_URL } from './protocol';

/** The chain id is a deployment-time fact (R-14), supplied by environment. */
export const CHAIN_ID = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? 31337);

/**
 * The one chain this deployment speaks to. Exported so the wallet flows can hand
 * it to viem's `writeContract`, which then asserts the wallet is actually on it
 * before signing — a send-time check the UI gate alone cannot provide.
 */
export const acceptedChain = {
  id: CHAIN_ID,
  name: process.env.NEXT_PUBLIC_CHAIN_NAME ?? 'Local',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: [RPC_URL || 'http://127.0.0.1:8545'] } },
};

export const wagmiConfig = createConfig({
  chains: [acceptedChain],
  connectors: [injected()],
  transports: { [CHAIN_ID]: http(RPC_URL || undefined) },
});
