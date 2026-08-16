'use client';

import { TIER_1, TIER_2, TIER_3, CANONICAL_EXPLANATION } from '../lib/truth-copy';
import { Truth } from './Unavailable';
import { formatUnits18 } from '../lib/protocol';

/**
 * The three-tier truth panel (FR-15.1).
 *
 * The tiers are rendered as three separate blocks with their own labels and their
 * own qualifiers — never as one number with a footnote — because the requirement
 * is that they be "visually and verbally distinct" (prd.md:L552). A reader who
 * skims must still come away knowing which number is a ceiling, which is a live
 * reading, and which is settled.
 *
 * Tier 3 comes from settled history, not from a live view, and is passed in from
 * the indexer. When it is unavailable it says so rather than falling back to a
 * live estimate, which would be precisely the conflation FR-15.1 prohibits.
 */
function Tier({ tier, children }) {
  return (
    <article className="tier" data-testid={`tier-${tier.id}`} data-tier={tier.id}>
      <h3 className="tier__label" data-testid={`tier-label-${tier.id}`}>{tier.label}</h3>
      <div className="tier__value">{children}</div>
      <p className="tier__meaning">{tier.meaning}</p>
      <p className="tier__qualifier" data-testid={`tier-qualifier-${tier.id}`}>{tier.qualifier}</p>
      <p className="tier__source">Source: {tier.source}</p>
    </article>
  );
}

export default function ThreeTierPanel({ rawClockLimit, estimate, settled }) {
  return (
    <section className="tiers" aria-label="Mining state" data-testid="three-tier-panel">
      <p className="tiers__explanation" data-testid="canonical-explanation">
        {CANONICAL_EXPLANATION}
      </p>

      <div className="tiers__grid">
        <Tier tier={TIER_1}>
          <Truth state={rawClockLimit} what={TIER_1.short}>
            {(v) => <span className="num" data-testid="value-raw-clock-limit">{formatUnits18(v)} VUX</span>}
          </Truth>
        </Tier>

        <Tier tier={TIER_2}>
          <Truth state={estimate} what={TIER_2.short}>
            {(v) => (
              <>
                <span className="num" data-testid="value-estimate">{formatUnits18(v.estimateQmint)} VUX</span>
                <dl className="tier__detail">
                  <div><dt>Price now</dt><dd>{formatUnits18(v.price)} WETH</dd></div>
                  <div><dt>Clock ceiling</dt><dd>{formatUnits18(v.qRaw)} VUX</dd></div>
                  <div><dt>Backing-supported cap</dt><dd>{formatUnits18(v.qSafeEst)} VUX</dd></div>
                </dl>
              </>
            )}
          </Truth>
        </Tier>

        <Tier tier={TIER_3}>
          <Truth state={settled} what={TIER_3.short}>
            {(v) => <span className="num" data-testid="value-settled">{formatUnits18(v)} VUX</span>}
          </Truth>
        </Tier>
      </div>
    </section>
  );
}
