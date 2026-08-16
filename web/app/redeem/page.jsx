'use client';

import { useState } from 'react';
import ReserveDescription from '../../components/ReserveDescription';
import { Truth } from '../../components/Unavailable';
import { useTruth, ADDRESSES, LENS_ABI, formatUnits18, formatRay } from '../../lib/protocol';
import { REDEEM_COPY } from '../../lib/truth-copy';
import { parseUnits18, previewRedeemRaw } from '../../lib/units';
import { RedeemFlow } from '../../components/WalletFlows';

export default function RedeemPage() {
  const [amount, setAmount] = useState('');

  const hard = useTruth(async (c) => {
    const [B, S, bPerSRay] = await c.readContract({
      address: ADDRESSES.lens, abi: LENS_ABI, functionName: 'hardStats',
    });
    return { B, S, bPerSRay };
  });

  // The quote is computed from the SAME B and S the page is showing, so a reader
  // can check it by hand. It is never computed from a cached or older read, and
  // the amount is parsed exactly — `parseUnits18` never routes a token quantity
  // through a float, so the quantity quoted is the quantity typed.
  const { raw: q, error: amountError } = parseUnits18(amount);
  const quote = hard.unavailable ? null : previewRedeemRaw(hard.value.B, hard.value.S, q);

  return (
    <>
      <section className="hero">
        <h1>Redeem</h1>
        <p className="hero__sub">Burn VUX, receive WETH from the Hard Reserve, pro rata.</p>
      </section>

      <section className="panel">
        <h2>Reserve state</h2>
        <Truth state={hard} what="Reserve state">
          {(v) => (
            <dl className="stats" data-testid="hard-stats">
              <div><dt>Hard backing (B)</dt><dd data-testid="stat-b">{formatUnits18(v.B)} WETH</dd></div>
              <div><dt>Total supply (S)</dt><dd data-testid="stat-s">{formatUnits18(v.S)} VUX</dd></div>
              <div><dt>Backing per VUX (B/S)</dt><dd data-testid="stat-bps">{formatRay(v.bPerSRay)} WETH</dd></div>
            </dl>
          )}
        </Truth>
        <p className="note">{REDEEM_COPY.deterministic}</p>
      </section>

      <section className="panel">
        <h2>{REDEEM_COPY.quoteLabel}</h2>
        <label className="field">
          <span>VUX to burn</span>
          <input
            type="text" inputMode="decimal" value={amount} placeholder="0.0"
            onChange={(e) => setAmount(e.target.value)} data-testid="redeem-input"
          />
        </label>

        {amountError !== null && (
          <p className="note note--strong" data-testid="redeem-amount-error">{amountError}</p>
        )}

        {quote !== null ? (
          <p className="quote" data-testid="redeem-quote">
            {formatUnits18(quote)} WETH
          </p>
        ) : (
          <p className="quote quote--empty" data-testid="redeem-quote-empty">—</p>
        )}

        <p className="note note--strong" data-testid="redeem-qualifier">{REDEEM_COPY.quoteQualifier}</p>
        <p className="note note--strong" data-testid="redeem-no-entitlement">{REDEEM_COPY.noEntitlement}</p>

        {/* The flow receives the SAME raw quantity the quote above was computed
            from — never a re-parse, never a float. */}
        <RedeemFlow q={q} quoteUnavailable={hard.unavailable} />
      </section>

      <ReserveDescription />
    </>
  );
}
