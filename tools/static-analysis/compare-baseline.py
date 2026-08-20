"""Compare a slither JSON report against the durable triaged baseline.

The gate's contract, stated once: **every finding must be explained**.

    * a finding whose key is NOT in the baseline  -> FAIL (new, undispositioned)
    * a baseline key that no longer appears       -> FAIL (stale disposition)
    * any finding of impact High                  -> FAIL unconditionally

The third rule is not redundant with the first. A High-impact finding must never
be silently absorbed by regenerating the baseline; it has to be fixed, or
dispositioned by a human who removes this line deliberately.

Keys are derived from the detector name plus the finding description with every
`#L<n>[-L<m>]` source reference collapsed, so editing code ABOVE a finding does
not churn the baseline while genuinely new findings still surface.

SPDX-License-Identifier: GPL-3.0-or-later
"""

import argparse
import hashlib
import io
import json
import re
import sys

LINEREF = re.compile(r'#L?\d+(?:-L?\d+)?')


def key_of(check, description):
    norm = LINEREF.sub('#', description.strip())
    norm = re.sub(r'\s+', ' ', norm)
    return hashlib.sha256((check + '|' + norm).encode('utf-8')).hexdigest()[:16]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--report', required=True)
    ap.add_argument('--baseline', required=True)
    args = ap.parse_args()

    report = json.load(io.open(args.report, encoding='utf-8'))
    baseline = json.load(io.open(args.baseline, encoding='utf-8'))

    if not report.get('success', True):
        print("FAIL  slither reported an analysis error: %s" % report.get('error'), file=sys.stderr)
        return 1

    dets = report['results']['detectors']
    found = {}
    for d in dets:
        found[key_of(d['check'], d['description'])] = d

    known = {f['key']: f for f in baseline['findings']}

    new = sorted(set(found) - set(known))
    stale = sorted(set(known) - set(found))
    high = [d for d in dets if d['impact'] == 'High']

    print("slither findings : %d" % len(found))
    print("baseline entries : %d" % len(known))

    failures = 0

    if high:
        failures += 1
        print("\nFAIL  %d HIGH-impact finding(s) — these are never baselined:" % len(high), file=sys.stderr)
        for d in high:
            print("        [%s] %s" % (d['check'], d['description'].strip().splitlines()[0]), file=sys.stderr)

    if new:
        failures += 1
        print("\nFAIL  %d finding(s) with no disposition in the baseline:" % len(new), file=sys.stderr)
        for k in new:
            d = found[k]
            print("        %s  [%s / %s] %s" % (k, d['check'], d['impact'],
                                                d['description'].strip().splitlines()[0]), file=sys.stderr)
        print("      Triage each one, then add it to %s." % args.baseline, file=sys.stderr)
        print("      Do NOT regenerate the baseline to make this pass.", file=sys.stderr)

    if stale:
        failures += 1
        print("\nFAIL  %d baseline entry/entries no longer produced by slither:" % len(stale), file=sys.stderr)
        for k in stale:
            b = known[k]
            print("        %s  [%s] %s (%s)" % (k, b['check'], b['summary'][:90], b['where']), file=sys.stderr)
        print("      The code changed. Remove these entries deliberately.", file=sys.stderr)

    if failures:
        return 1

    print("ok    every finding carries a triaged disposition; 0 high-impact")
    return 0


if __name__ == '__main__':
    sys.exit(main())
