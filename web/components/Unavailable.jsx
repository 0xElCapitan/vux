'use client';

import { UNAVAILABLE } from '../lib/truth-copy';

/**
 * The explicit data-unavailable state (FB-17, sdd.md:L836).
 *
 * This component exists so that "we could not read it" has a rendering of its
 * own. The failure mode it prevents is not a crash — it is a page that keeps
 * showing the last number it happened to have, or substitutes 0, or a dash, and
 * so presents an unknown as a measurement.
 *
 * It never renders a value. There is no `value` prop to pass one through.
 */
export function Unavailable({ reason, staleSeconds, what }) {
  const message =
    reason === 'stale' ? UNAVAILABLE.stale(staleSeconds ?? '?')
      : reason === 'indexer-failed' || reason === 'no-indexer' ? UNAVAILABLE.indexer
      : reason === 'loading' ? 'Reading…'
      : UNAVAILABLE.rpc;

  const isLoading = reason === 'loading';

  return (
    <div
      className={`unavailable${isLoading ? ' unavailable--loading' : ''}`}
      role="status"
      aria-live="polite"
      data-testid="data-unavailable"
      data-reason={reason ?? 'unknown'}
    >
      {!isLoading && <strong className="unavailable__label">{UNAVAILABLE.label}</strong>}
      <span className="unavailable__message">{what ? `${what}: ${message}` : message}</span>
    </div>
  );
}

/**
 * Render `children(value)` only when the read actually produced a current value.
 * Otherwise render the unavailable state. Callers cannot reach a value without
 * passing through this gate.
 */
export function Truth({ state, what, children }) {
  if (state.unavailable || state.value === null || state.value === undefined) {
    return <Unavailable reason={state.reason} staleSeconds={state.staleSeconds} what={what} />;
  }
  return <>{children(state.value)}</>;
}

/** Chain-outage banner (FB-17). */
export function OutageBanner({ show }) {
  if (!show) return null;
  return (
    <div className="outage" role="alert" data-testid="outage-banner">
      <strong>{UNAVAILABLE.label}.</strong> {UNAVAILABLE.outage}
    </div>
  );
}
