'use client';

import { Truth } from '../../components/Unavailable';
import { useIndexer, useTruth, ADDRESSES, LENS_ABI, formatUnits18 } from '../../lib/protocol';
import { STRATEGIC_LABELS } from '../../lib/truth-copy';

export default function TreasuryPage() {
  const contributed = useTruth((c) =>
    c.readContract({ address: ADDRESSES.lens, abi: LENS_ABI, functionName: 'strategicContributed' })
  );
  const flows = useIndexer('/strategic-flows?limit=25');

  return (
    <>
      <section className="hero">
        <h1>Strategic Treasury</h1>
        <p className="hero__sub">
          Where the settlement residual goes, and what has happened to it since.
        </p>
      </section>

      <section className="panel panel--warn">
        <h2>What this is not</h2>
        <p data-testid="treasury-never-backing">{STRATEGIC_LABELS.neverBacking}</p>
        <p className="note">
          Redemption pays out of the Hard Reserve alone. Nothing on this page is redeemable, and
          nothing on this page appears in B or in backing per VUX.
        </p>
      </section>

      <section className="panel">
        <h2>{STRATEGIC_LABELS.contributedPrincipal}</h2>
        <Truth state={contributed} what={STRATEGIC_LABELS.contributedPrincipal}>
          {(v) => <p className="quote" data-testid="treasury-contributed">{formatUnits18(v)} WETH</p>}
        </Truth>
        <p className="note">
          Cumulative WETH routed to the Treasury as the settlement residual leg. This is contributed
          principal — the amount that went in, not a valuation of what it is worth now.
        </p>
      </section>

      <section className="panel">
        <h2>{STRATEGIC_LABELS.navDisclosed}</h2>
        <p className="quote quote--empty" data-testid="treasury-nav-disclosed">Not disclosed</p>
        <p className="note note--strong" data-testid="treasury-nav-qualifier">
          {STRATEGIC_LABELS.navQualifier}
        </p>
        <p className="note">
          Column name: <code>{STRATEGIC_LABELS.navColumn}</code>. It is never labelled backing.
        </p>
      </section>

      <section className="panel">
        <h2>Flows</h2>
        <Truth state={flows} what="Strategic flows">
          {(rows) => (
            <div className="table-wrap">
              <table data-testid="strategic-flows-table">
                <thead>
                  <tr><th>Block</th><th>Direction</th><th>Class</th><th>Amount</th></tr>
                </thead>
                <tbody>
                  {rows.map((r) => (
                    <tr key={r.id}>
                      <td>{r.blockNumber}</td>
                      <td>{r.direction}</td>
                      <td data-testid="flow-class">{r.class}</td>
                      <td>{formatUnits18(BigInt(r.amount))}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Truth>
      </section>
    </>
  );
}
