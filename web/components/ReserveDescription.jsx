'use client';

import { YELLOW_DISCLOSURE, RESERVE_DESCRIPTION, NO_TRUSTLESS_CLAIM } from '../lib/truth-copy';

/**
 * The ONLY component that describes the Hard Reserve.
 *
 * INV-36 requires the mandatory YELLOW disclosure to render verbatim wherever the
 * Reserve is described as ownerless or immutable. Coupling the two statements
 * inside one component makes that structural: there is no way to render the
 * flattering half without the qualifying half, because they are the same
 * component. A page that wanted to describe the Reserve without the disclosure
 * would have to stop using this component, which is a visible change rather than
 * a quiet omission.
 *
 * The disclosure text is imported, never inlined, so it cannot drift from the
 * accepted PRD wording by an edit here.
 */
export default function ReserveDescription({ variant = 'full' }) {
  return (
    <section className="reserve-description" data-testid="reserve-description">
      {variant === 'full' && (
        <p className="reserve-description__body" data-testid="reserve-description-body">
          {RESERVE_DESCRIPTION}
        </p>
      )}

      <aside
        className="disclosure disclosure--yellow"
        role="note"
        aria-label="Mandatory Hard Reserve trust disclosure"
        data-testid="yellow-disclosure"
      >
        <span className="disclosure__tag">Trust disclosure</span>
        <p className="disclosure__text">{YELLOW_DISCLOSURE}</p>
      </aside>

      {variant === 'full' && (
        <p className="reserve-description__note" data-testid="no-trustless-claim">
          {NO_TRUSTLESS_CLAIM}
        </p>
      )}
    </section>
  );
}
