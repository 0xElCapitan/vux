'use client';

// The two protocol transactions a user can send: `take` and `redeem`.
//
// TRUTHFULNESS RULES THAT SHAPE THIS FILE
//
//  - A transaction is never built from data the page could not read. If a live
//    read is unavailable, the button is disabled and says so; it never falls back
//    to a guessed price or a stale quantity.
//  - `maxPrice` is captured from the price the USER confirmed and sent verbatim.
//    The Dutch price falls continuously and a competing takeover can raise it, so
//    re-reading it at submit time would silently move the user's own protection.
//    The Rig reverts with `PriceAboveMax` — that revert is the guard working.
//  - Quantities never pass through a float. `redeem` submits exactly the raw
//    value `parseUnits18` produced, which is the same value the quote was
//    computed from.
//  - Pending / success / revert are reported as what they are. A submitted
//    transaction is not a settlement, and none of this copy says a reader has
//    earned, is owed, or may claim anything.
//  - The wallet must be on THIS deployment's chain before anything is signed.
//    `ADDRESSES` are chain-scoped facts; on another chain the same bytes are a
//    different contract, or nothing at all, and `approve` would hand an
//    allowance to whatever lives there. Enforced twice, on purpose: the UI
//    refuses to offer a transaction (below), and viem re-asserts the chain at
//    send time via `chain: acceptedChain`, which closes the window between the
//    render that drew the button and the click that fires it.

import { useState } from 'react';
import {
  useAccount, useConnect, useDisconnect, usePublicClient, useWalletClient, useSwitchChain,
} from 'wagmi';
import { ADDRESSES, RIG_ABI, RESERVE_ABI, WETH_ABI, formatUnits18 } from '../lib/protocol';
import { CHAIN_ID, acceptedChain } from '../lib/wagmi';
import { WALLET_COPY } from '../lib/truth-copy';

/**
 * Is the connected wallet on the deployment chain?
 *
 * `useAccount().chainId` is what the wallet reports, not what the config wishes
 * were true, so a wallet sitting on an unconfigured chain reads as a mismatch
 * rather than as `undefined === undefined`.
 */
function useAcceptedChain() {
  const { isConnected, chainId } = useAccount();
  return { isConnected, chainId, onAcceptedChain: isConnected && chainId === CHAIN_ID };
}

/** Names the mismatch and offers the switch. Never signs, never auto-switches. */
function WrongNetwork({ chainId }) {
  const { switchChain, isPending } = useSwitchChain();
  return (
    <div data-testid="wrong-network">
      <p className="note note--strong" data-testid="wrong-network-message">
        <strong>{WALLET_COPY.wrongNetworkLabel}.</strong> {WALLET_COPY.wrongNetwork}
        {' '}(<span data-testid="wrong-network-connected">{String(chainId ?? 'unknown')}</span>
        {' → '}<span data-testid="wrong-network-expected">{String(CHAIN_ID)}</span>)
      </p>
      <button
        type="button"
        disabled={isPending}
        onClick={() => switchChain({ chainId: CHAIN_ID })}
        data-testid="wrong-network-switch"
      >
        {WALLET_COPY.switchNetworkAction}
      </button>
    </div>
  );
}

/** Transaction lifecycle, reported honestly. */
const IDLE = { kind: 'idle' };

function useTx() {
  const [state, setState] = useState(IDLE);
  const run = async (steps) => {
    try {
      for (const [label, fn] of steps) {
        setState({ kind: 'pending', label });
        await fn();
      }
      setState({ kind: 'success' });
    } catch (err) {
      // Surface the protocol's own reason. A revert is information, not noise —
      // `PriceAboveMax` means the user's own guard refused a worse price.
      const reason = err?.shortMessage ?? err?.details ?? err?.message ?? String(err);
      setState({ kind: 'error', reason: String(reason) });
    }
  };
  return [state, run, () => setState(IDLE)];
}

function TxStatus({ state, testid }) {
  if (state.kind === 'idle') return null;
  return (
    <p className="note note--strong" data-testid={testid} data-tx-state={state.kind}>
      {state.kind === 'pending' && `${WALLET_COPY.pending} — ${state.label}`}
      {state.kind === 'success' && WALLET_COPY.submitted}
      {state.kind === 'error' && `${WALLET_COPY.failed} ${state.reason}`}
    </p>
  );
}

export function ConnectWallet() {
  const { address, isConnected } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const injected = connectors[0];

  if (isConnected) {
    return (
      <div className="wallet" data-testid="wallet-connected">
        <span className="wallet__addr" data-testid="wallet-address">{address}</span>
        <button type="button" onClick={() => disconnect()} data-testid="wallet-disconnect">Disconnect</button>
      </div>
    );
  }
  return (
    <div className="wallet">
      <button
        type="button"
        disabled={!injected || isPending}
        onClick={() => injected && connect({ connector: injected })}
        data-testid="wallet-connect"
      >
        {WALLET_COPY.connect}
      </button>
      <p className="note" data-testid="wallet-custody">{WALLET_COPY.noCustody}</p>
    </div>
  );
}

/**
 * Take the throne.
 *
 * @param {{ price: bigint|null, unavailable: boolean }} priceState the live Dutch
 *        price and whether it is actually current. When unavailable there is no
 *        transaction to offer — a `take` needs a price to protect against.
 */
export function TakeFlow({ price, unavailable }) {
  const { isConnected, chainId, onAcceptedChain } = useAcceptedChain();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();
  const [state, run] = useTx();

  const ready =
    isConnected && onAcceptedChain && !unavailable && price !== null && walletClient && ADDRESSES.rig;

  // The guard is the price of the render the user clicked in — `submit` closes
  // over it, so a poll landing mid-flight cannot move it, and the number shown
  // above the button is the number that gets sent.
  //
  // There is deliberately no `confirmed` state here. Holding the first click's
  // price in component state froze the displayed maximum forever (a stale value
  // wearing a live label) and made a second take reuse a guard the user only ever
  // agreed to for the first one. The closure already provides the freeze that is
  // actually wanted — per submission, not per component lifetime.
  const maxPrice = price;

  const submit = () =>
    run([
      [
        WALLET_COPY.stepApprove,
        async () => {
          const hash = await walletClient.writeContract({
            chain: acceptedChain,
            address: ADDRESSES.weth, abi: WETH_ABI, functionName: 'approve', args: [ADDRESSES.rig, maxPrice],
          });
          await publicClient.waitForTransactionReceipt({ hash });
        },
      ],
      [
        WALLET_COPY.stepTake,
        async () => {
          const hash = await walletClient.writeContract({
            chain: acceptedChain,
            address: ADDRESSES.rig, abi: RIG_ABI, functionName: 'take', args: [maxPrice],
          });
          await publicClient.waitForTransactionReceipt({ hash });
        },
      ],
    ]);

  return (
    <div className="flow" data-testid="take-flow">
      <ConnectWallet />
      {isConnected && !onAcceptedChain && <WrongNetwork chainId={chainId} />}
      {unavailable || price === null ? (
        <p className="note note--strong" data-testid="take-unavailable">{WALLET_COPY.takeNoPrice}</p>
      ) : isConnected && !onAcceptedChain ? null : (
        <>
          <p className="note" data-testid="take-maxprice">
            {WALLET_COPY.maxPriceLabel} <strong>{formatUnits18(maxPrice)} WETH</strong>
          </p>
          <p className="note" data-testid="take-maxprice-note">{WALLET_COPY.maxPriceNote}</p>
          <button
            type="button"
            disabled={!ready}
            onClick={submit}
            data-testid="take-submit"
          >
            {WALLET_COPY.takeAction}
          </button>
        </>
      )}
      <TxStatus state={state} testid="take-status" />
    </div>
  );
}

/**
 * Redeem VUX for WETH.
 *
 * @param {bigint|null} q the EXACT raw quantity `parseUnits18` produced — the
 *        same value the displayed quote was computed from. Never re-derived here.
 */
export function RedeemFlow({ q, quoteUnavailable }) {
  const { address } = useAccount();
  const { isConnected, chainId, onAcceptedChain } = useAcceptedChain();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();
  const [state, run] = useTx();

  const ready =
    isConnected && onAcceptedChain && q !== null && q > 0n && walletClient && ADDRESSES.reserve;

  const submit = () =>
    run([
      [
        WALLET_COPY.stepRedeem,
        async () => {
          // `q` verbatim: the quantity quoted is the quantity burned. Redemption
          // needs no approval — the Reserve burns from `msg.sender` directly.
          const hash = await walletClient.writeContract({
            chain: acceptedChain,
            address: ADDRESSES.reserve, abi: RESERVE_ABI, functionName: 'redeem', args: [q, address],
          });
          await publicClient.waitForTransactionReceipt({ hash });
        },
      ],
    ]);

  return (
    <div className="flow" data-testid="redeem-flow">
      <ConnectWallet />
      {isConnected && !onAcceptedChain && <WrongNetwork chainId={chainId} />}
      {q !== null && q > 0n && (
        <p className="note" data-testid="redeem-exact-amount">
          {WALLET_COPY.redeemExact} <strong data-testid="redeem-raw-amount">{String(q)}</strong>
        </p>
      )}
      {quoteUnavailable && (
        <p className="note note--strong" data-testid="redeem-quote-unavailable">{WALLET_COPY.redeemNoQuote}</p>
      )}
      {isConnected && !onAcceptedChain ? null : (
        <button type="button" disabled={!ready} onClick={submit} data-testid="redeem-submit">
          {WALLET_COPY.redeemAction}
        </button>
      )}
      <TxStatus state={state} testid="redeem-status" />
    </div>
  );
}
