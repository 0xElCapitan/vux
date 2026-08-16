'use client';

import { Truth } from '../../components/Unavailable';
import ReserveDescription from '../../components/ReserveDescription';
import { useIndexer, useTruth, ADDRESSES, LENS_ABI, formatUnits18, formatRay } from '../../lib/protocol';
import { STRATEGIC_LABELS } from '../../lib/truth-copy';

const CAUSES = [
  ['genesis', 'Genesis mint', 'Protocol liquidity inventory and the permanent supply floor. No user received VUX at genesis.'],
  ['settlement_mint', 'Settlement mint', 'VUX minted to an outgoing King by a completed settlement. The only path that creates user-owned VUX.'],
  ['redemption_burn', 'Redemption burn', 'Burned by a holder exercising the exit right.'],
  ['vyrf_burn', 'VYRF burn', 'POL fee yield denominated in VUX, burned outright.'],
  ['other_authorized_burn', 'Other authorized burn', 'Revenue burn, and permissionless holder self-burns — which carry no protocol cause event and are attributed by exclusion.'],
];

export default function AccountingPage() {
  const stats = useIndexer('/stats');
  const settlements = useIndexer('/settlements?limit=25');
  const hard = useTruth(async (c) => {
    const [B, S, bPerSRay] = await c.readContract({ address: ADDRESSES.lens, abi: LENS_ABI, functionName: 'hardStats' });
    return { B, S, bPerSRay };
  });

  return (
    <>
      <section className="hero">
        <h1>Accounting</h1>
        <p className="hero__sub">
          Every number here is reconstructable from chain events by anyone. The chain is the record;
          this page is a mirror of it.
        </p>
      </section>

      <section className="panel">
        <h2>Hard Reserve</h2>
        <Truth state={hard} what="Hard Reserve">
          {(v) => (
            <dl className="stats">
              <div><dt>Hard backing (B)</dt><dd>{formatUnits18(v.B)} WETH</dd></div>
              <div><dt>Total supply (S)</dt><dd>{formatUnits18(v.S)} VUX</dd></div>
              <div><dt>Backing per VUX (B/S)</dt><dd>{formatRay(v.bPerSRay)} WETH</dd></div>
            </dl>
          )}
        </Truth>
      </section>

      <section className="panel">
        <h2>Supply</h2>
        <Truth state={stats} what="Supply">
          {(v) => (
            <dl className="stats">
              <div><dt>Current supply</dt><dd>{formatUnits18(BigInt(v.currentSupply))} VUX</dd></div>
              <div><dt>Completed mints</dt><dd>{formatUnits18(BigInt(v.completedMints))} VUX</dd></div>
              <div>
                <dt>Cumulative raw opportunity</dt>
                <dd>{formatUnits18(BigInt(v.cumulativeRawOpportunity))} VUX</dd>
              </div>
            </dl>
          )}
        </Truth>
        <p className="note">
          Cumulative raw opportunity is the sum of every reign’s clock ceiling. Most of it was never
          minted — the difference expired with no record kept of it anywhere in the protocol.
        </p>
      </section>

      <section className="panel">
        <h2>Supply changes by cause</h2>
        <p className="note">
          Every change to supply is attributable to exactly one cause, joinable from the logs of a
          single transaction.
        </p>
        <ul className="causes" data-testid="cause-list">
          {CAUSES.map(([id, label, meaning]) => (
            <li key={id} data-testid={`cause-${id}`}>
              <strong>{label}</strong> <code>{id}</code>
              <p>{meaning}</p>
            </li>
          ))}
        </ul>
      </section>

      <section className="panel">
        <h2>Strategic</h2>
        {/* The LABELS are copy, not data, so they render whether or not the
            indexer is reachable. FR-14.4's naming requirement is a statement
            about what a Strategic figure is called; it cannot be contingent on
            the figure being available, or the naming quietly disappears in
            exactly the degraded state where a reader is most likely to guess.
            Only the VALUES sit behind the availability gate. */}
        <dl className="stats" data-testid="strategic-stats">
          <div>
            <dt>{STRATEGIC_LABELS.contributedPrincipal}</dt>
            <dd data-testid="strategic-contributed">
              <Truth state={stats} what={STRATEGIC_LABELS.contributedPrincipal}>
                {(v) => <>{formatUnits18(BigInt(v.strategicContributedPrincipal))} WETH</>}
              </Truth>
            </dd>
          </div>
          <div>
            <dt>
              {STRATEGIC_LABELS.navDisclosed} <code>{STRATEGIC_LABELS.navColumn}</code>
            </dt>
            <dd data-testid="strategic-nav-disclosed">
              {/* Not event-derivable (INV-30): `null` is the truthful value for
                  "not disclosed" and is never coerced to 0. This is the same
                  answer whether or not the indexer responds. */}
              Not disclosed
            </dd>
          </div>
        </dl>
        <p className="note note--strong" data-testid="strategic-never-backing">
          {STRATEGIC_LABELS.neverBacking}
        </p>
        <p className="note" data-testid="strategic-nav-qualifier">{STRATEGIC_LABELS.navQualifier}</p>
      </section>

      <section className="panel">
        <h2>Settlements</h2>
        <Truth state={settlements} what="Settlements">
          {(rows) => (
            <div className="table-wrap">
              <table data-testid="settlements-table">
                <thead>
                  <tr>
                    <th>Epoch</th><th>Price</th><th>King leg</th><th>Strategic leg</th>
                    <th>Hard leg</th><th>Clock ceiling</th><th>Minted</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((r) => (
                    <tr key={r.epochId}>
                      <td>{r.epochId}{r.bootstrap ? ' (bootstrap)' : ''}</td>
                      <td>{formatUnits18(BigInt(r.price))}</td>
                      <td>{formatUnits18(BigInt(r.kingLeg))}</td>
                      <td>{formatUnits18(BigInt(r.strategicLeg))}</td>
                      <td>{formatUnits18(BigInt(r.reserveLeg))}</td>
                      <td>{formatUnits18(BigInt(r.qRaw))}</td>
                      <td>{formatUnits18(BigInt(r.qMint))}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Truth>
      </section>

      <ReserveDescription />
    </>
  );
}
