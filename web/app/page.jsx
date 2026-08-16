'use client';

import ThreeTierPanel from '../components/ThreeTierPanel';
import { OutageBanner } from '../components/Unavailable';
import { TakeFlow } from '../components/WalletFlows';
import { useTruth, useIndexer, ADDRESSES, LENS_ABI, formatUnits18 } from '../lib/protocol';
import { TIER_1, TIER_2 } from '../lib/truth-copy';

export default function ThronePage() {
  const rawClockLimit = useTruth((c) =>
    c.readContract({ address: ADDRESSES.lens, abi: LENS_ABI, functionName: 'rawClockLimit' })
  );

  const estimate = useTruth(async (c) => {
    const [estimateQmint, price, qRaw, qSafeEst] = await c.readContract({
      address: ADDRESSES.lens, abi: LENS_ABI, functionName: 'estimateIfDisplacedNow',
    });
    return { estimateQmint, price, qRaw, qSafeEst };
  });

  const stats = useIndexer('/stats');
  const settled = stats.unavailable
    ? { unavailable: true, reason: stats.reason, value: null }
    : { unavailable: false, reason: null, value: BigInt(stats.value.completedMints) };

  // Both live reads failing together is the chain-outage signal (FB-17).
  const outage = rawClockLimit.unavailable && estimate.unavailable
    && rawClockLimit.reason !== 'loading' && estimate.reason !== 'loading';

  return (
    <>
      <OutageBanner show={outage} />

      <section className="hero">
        <h1>Mine while you hold the throne.</h1>
        <p className="hero__sub">
          Take the throne by paying the falling price. You mine for as long as you hold it — and the
          amount is settled when the next King pays.
        </p>
      </section>

      <ThreeTierPanel rawClockLimit={rawClockLimit} estimate={estimate} settled={settled} />

      <section className="panel">
        <h2>Taking the throne</h2>
        <p>
          The price falls with time. Whoever pays it displaces the current King, and that payment is
          what settles the outgoing reign.
        </p>
        <p className="note">
          A takeover in the same block can raise the price above what you saw. Set a maximum price
          you are willing to pay; the transaction reverts rather than overpaying.
        </p>
        {!estimate.unavailable && (
          <p className="note" data-testid="take-price-note">
            Price now: {formatUnits18(estimate.value.price)} WETH.
          </p>
        )}
        <p className="note note--strong" data-testid="no-entitlement-note">
          {TIER_1.qualifier} {TIER_2.qualifier}
        </p>

        <TakeFlow
          price={estimate.unavailable ? null : estimate.value.price}
          unavailable={estimate.unavailable}
        />
      </section>
    </>
  );
}
