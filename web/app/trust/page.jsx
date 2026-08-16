import ReserveDescription from '../../components/ReserveDescription';
import {
  CONTESTABILITY_CLAIM,
  CANONICAL_EXPLANATION,
  DISCLOSURE_TRUST_PAGE_TITLE,
  UNAVAILABLE,
  TIER_1,
  TIER_2,
  TIER_3,
} from '../../lib/truth-copy';

/**
 * The FB-18 documented-disclosure page. Static by design — it makes no chain
 * read, so it has nothing that can go stale and nothing to render unavailable.
 */
export const metadata = { title: 'VUX — Trust and disclosures' };

export default function TrustPage() {
  return (
    <>
      <section className="hero">
        <h1>{DISCLOSURE_TRUST_PAGE_TITLE}</h1>
        <p className="hero__sub">
          What VUX guarantees structurally, what it depends on externally, and what it does not claim.
        </p>
      </section>

      <section className="panel">
        <h2>The Hard Reserve</h2>
        <ReserveDescription />
      </section>

      <section className="panel">
        <h2>How mining actually works</h2>
        <p data-testid="trust-canonical-explanation">{CANONICAL_EXPLANATION}</p>
        <ul className="tier-summary">
          {[TIER_1, TIER_2, TIER_3].map((t) => (
            <li key={t.id} data-testid={`trust-tier-${t.id}`}>
              <strong>{t.label}</strong>
              <p>{t.meaning}</p>
              <p className="note">{t.qualifier}</p>
            </li>
          ))}
        </ul>
      </section>

      <section className="panel">
        <h2>What VUX claims about its distribution</h2>
        <blockquote data-testid="contestability-claim">{CONTESTABILITY_CLAIM}</blockquote>
        <p className="note" data-testid="contestability-bound">
          That is the whole claim. It says where supply came from — not that outcomes are equal, that
          distribution is broad, that whales are disadvantaged, or that capital carries no advantage.
          Anyone able to pay the price can take the throne, and more capital can take it more often.
        </p>
      </section>

      <section className="panel">
        <h2>When this interface cannot see the chain</h2>
        <p data-testid="trust-unavailable-policy">{UNAVAILABLE.neverStale}</p>
        <p className="note">
          If a read fails, the value is dropped and the surface says <em>{UNAVAILABLE.label}</em>. A
          number that stopped refreshing is treated as unavailable rather than shown as current. The
          protocol is unaffected by this interface being unable to reach it.
        </p>
      </section>

      <section className="panel">
        <h2>Custody</h2>
        <p>
          This interface holds no keys, no funds, and no session state. It reads public chain data and
          builds transactions your own wallet signs. The indexer behind the accounting pages is a
          derived, disposable replica — the chain remains the record.
        </p>
      </section>
    </>
  );
}
