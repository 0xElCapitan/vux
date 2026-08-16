// Exact-arithmetic regression for the redemption path (`web/lib/units.js`).
//
// This runs under `node --test` rather than Playwright on purpose: the copy suite
// runs with no RPC configured, so `hard.unavailable` is always true and the quote
// branch never executes there. The money arithmetic needs coverage that does not
// depend on a rendered page reaching a chain.
//
//   node --test web/tests/units.test.mjs

import test from 'node:test';
import assert from 'node:assert/strict';

import { parseUnits18, previewRedeemRaw } from '../lib/units.js';

/** The reference conversion: pure string manipulation, no arithmetic at all. */
const exact = (s) => {
  const [w = '', f = ''] = s.split('.');
  return BigInt((w === '' ? '0' : w) + f.padEnd(18, '0').slice(0, 18));
};

/** What the page did before this fix — kept to prove the tests discriminate. */
const viaFloat = (s) => BigInt(Math.trunc(Number(s) * 1e18));

test('M-1: the exact case review measured', () => {
  const { raw } = parseUnits18('12345.6789');
  assert.equal(raw, 12345678900000000000000n);
  assert.equal(raw, exact('12345.6789'));
  // The defect, pinned: the old path overstated by 1,622,016 raw units, so the
  // quote shown was LARGER than the redemption would return.
  assert.equal(viaFloat('12345.6789') - raw, 1622016n);
});

test('M-1: boundary values that the float path corrupted', () => {
  for (const [input, expected] of [
    ['1.005', 1005000000000000000n],
    ['1000.000000000000000001', 1000000000000000000001n],
    ['0.000000000000000001', 1n],
    ['0.1', 100000000000000000n],
    ['1', 1000000000000000000n],
    ['123.456', 123456000000000000000n],
    ['7.7', 7700000000000000000n],
  ]) {
    const { raw, error } = parseUnits18(input);
    assert.equal(error, null, `${input} should parse`);
    assert.equal(raw, expected, `${input} exact`);
    assert.equal(raw, exact(input), `${input} matches the string reference`);
  }
});

test('M-1: at least one boundary genuinely discriminates against the float path', () => {
  const differing = ['1.005', '1000.000000000000000001', '12345.6789'].filter(
    (s) => viaFloat(s) !== parseUnits18(s).raw,
  );
  assert.equal(differing.length, 3, 'every listed case must expose the old defect');
});

test('M-1: a huge amount stays exact where a double could not', () => {
  const s = '999999999.999999999999999999';
  const { raw } = parseUnits18(s);
  assert.equal(raw, exact(s));
  assert.notEqual(viaFloat(s), raw);
});

test('excess precision is refused explicitly, never silently truncated', () => {
  const { raw, error } = parseUnits18('1.0000000000000000001'); // 19 decimals
  assert.equal(raw, null, 'no quantity is invented');
  assert.match(error, /18 decimals/);
});

test('malformed and empty input are distinguished', () => {
  assert.deepEqual(parseUnits18(''), { raw: null, error: null }, 'empty is not an error, it is no input');
  assert.deepEqual(parseUnits18('   '), { raw: null, error: null });
  for (const bad of ['abc', '1e18', '-1', '1.2.3', '.', '1,000']) {
    assert.notEqual(parseUnits18(bad).error, null, `${bad} must be refused`);
    assert.equal(parseUnits18(bad).raw, null);
  }
});

test('trailing and leading forms parse to the same exact value', () => {
  assert.equal(parseUnits18('.5').raw, parseUnits18('0.5').raw);
  assert.equal(parseUnits18('5.').raw, parseUnits18('5').raw);
});

// ---------------------------------------------------------------------------
// The quote itself
// ---------------------------------------------------------------------------

test('previewRedeemRaw floors, and equals floor(B*q/S)', () => {
  const B = 1_000_000_000_000_000_000n; // 1 WETH
  const S = 3_000_000_000_000_000_000n; // 3 VUX
  const { raw: q } = parseUnits18('1');
  assert.equal(previewRedeemRaw(B, S, q), (B * q) / S);
  assert.equal(previewRedeemRaw(B, S, q), 333333333333333333n, 'floors, never rounds up (INV-16)');
});

test('the quote uses the SAME raw quantity the user typed', () => {
  const B = 7_777_777_777_777_777_777n;
  const S = 12_345_678_900_000_000_000_000n;
  const typed = '12345.6789';
  const { raw: q } = parseUnits18(typed);
  assert.equal(q, exact(typed), 'quantity is exact');
  assert.equal(previewRedeemRaw(B, S, q), (B * exact(typed)) / S, 'quote is a function of that exact quantity');
  assert.notEqual(previewRedeemRaw(B, S, q), (B * viaFloat(typed)) / S, 'and differs from the old float quote');
});

test('a quote is withheld rather than guessed when inputs cannot support one', () => {
  assert.equal(previewRedeemRaw(1n, 0n, 1n), null, 'S = 0 yields no quote, not a division');
  assert.equal(previewRedeemRaw(1n, 1n, 0n), null, 'zero burn is not a zero payout claim');
  assert.equal(previewRedeemRaw(null, 1n, 1n), null, 'unavailable backing yields no quote');
  assert.equal(previewRedeemRaw(1n, 1n, null), null, 'unparsed amount yields no quote');
});
