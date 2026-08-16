// Exact decimal <-> raw-unit conversion. No React, no chain client — importable
// by both the browser bundle and a plain Node test runner, which is the point:
// this is the only arithmetic on the redemption path and it needs a test that
// does not require a rendered page or a live RPC.
//
// WHY THIS EXISTS. The redeem page previously computed the burn quantity as
// `BigInt(Math.trunc(Number(amount) * 1e18))`. Every 18-decimal quantity above a
// few units exceeds 2^53, so the product is an IEEE-754 double and the result is
// the nearest representable value rather than the amount the user typed.
// Measured: `12345.6789` produced 12345678900000001622016 raw — 1,622,016 MORE
// than typed, so the quote shown was larger than the redemption would return.
// The page renders "deterministic: floor(B x q / S)" directly above that number.
//
// Nothing here rounds. Excess precision is rejected rather than silently dropped:
// truncating would quote a different amount than the one entered, which is the
// same class of untruth in a quieter form.

export const DECIMALS = 18;
const SCALE = 10n ** BigInt(DECIMALS);

/**
 * Parse a decimal VUX amount into raw 18-decimal units.
 *
 * @param {string} input
 * @returns {{ raw: bigint|null, error: string|null }}
 */
export function parseUnits18(input) {
  const s = String(input ?? '').trim();
  if (s === '') return { raw: null, error: null };

  // Deliberately strict: no exponent form, no sign, no thousands separators. An
  // input this function cannot represent exactly is refused, never approximated.
  if (!/^\d*\.?\d*$/.test(s) || s === '.') {
    return { raw: null, error: 'Enter a plain decimal amount, for example 12345.6789.' };
  }

  const [whole = '', frac = ''] = s.split('.');
  if (frac.length > DECIMALS) {
    return {
      raw: null,
      error: `VUX has ${DECIMALS} decimals. That amount is more precise than VUX can represent, so no quote is shown rather than a quote for a different amount.`,
    };
  }

  const raw = BigInt(whole === '' ? '0' : whole) * SCALE + BigInt(frac === '' ? '0' : frac.padEnd(DECIMALS, '0'));
  return { raw, error: null };
}

/**
 * The redemption quote: `floor(B x q / S)`, on integers throughout.
 *
 * Floor is the Reserve-favouring direction every quantity in this protocol
 * rounds (INV-16), and BigInt division already floors for non-negative values.
 *
 * @returns {bigint|null} null when the inputs cannot produce a quote at all.
 */
export function previewRedeemRaw(B, S, q) {
  if (B === null || S === null || q === null) return null;
  if (S <= 0n || q <= 0n) return null;
  return (B * q) / S;
}
