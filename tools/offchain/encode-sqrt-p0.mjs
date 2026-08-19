#!/usr/bin/env node
// Deterministic genesis price encoder (sdd.md:L185).
//
// The authoritative rule, verbatim:
//
//   orientation : (token0, token1) = addressSort(vux, weth); the encoded ratio
//                 is token1-per-token0, i.e. n/d = P0 when VUX is token0,
//                 else 1/P0
//   encoding    : sqrtP0X96 = isqrt( (n << 192) / d )   — FLOOR at both steps
//
// Integer-only, by construction: BigInt throughout, integer division for the
// ratio, Newton floor-isqrt for the root. No floating point enters this file,
// which is the point — `Math.sqrt` on a 2^192-scaled ratio silently loses ~200
// bits and would produce a plausible, wrong constant.
//
// This is the INDEPENDENT implementation. The in-repo Solidity encoder lives in
// `test/genesis/GenesisFixture.sol::_encodeSqrtP0X96` (OpenZeppelin `Math.mulDiv`
// + `Math.sqrt`), and `test/genesis/GenesisPriceEncoding.t.sol` asserts the two
// agree on the recorded rehearsal values. Two implementations sharing no code is
// what makes the agreement evidence.
//
// Usage:
//   node tools/offchain/encode-sqrt-p0.mjs --n <int> --d <int>
//   node tools/offchain/encode-sqrt-p0.mjs --b0 <wei> --s0 <wei> [--vux-is-token0]
//   node tools/offchain/encode-sqrt-p0.mjs --rehearsal      # both orientations
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { pathToFileURL } from "node:url";

const Q192 = 1n << 192n;
const MIN_SQRT_RATIO = 4295128739n;
const MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342n;
const UINT160_MAX = (1n << 160n) - 1n;

/** Floor integer square root (Newton). Exact for every BigInt >= 0. */
export function isqrt(x) {
  if (x < 0n) throw new RangeError('isqrt: negative');
  if (x < 2n) return x;
  // Seed from the bit length so Newton converges in a handful of steps.
  let r = 1n << (BigInt(x.toString(2).length) + 1n) / 2n;
  for (;;) {
    const next = (r + x / r) >> 1n;
    if (next >= r) break;
    r = next;
  }
  // Correct any residual off-by-one, then assert the floor property outright.
  while (r * r > x) r -= 1n;
  while ((r + 1n) * (r + 1n) <= x) r += 1n;
  return r;
}

/** The accepted encoding: floor at both steps. */
export function encodeSqrtP0X96(n, d) {
  if (d <= 0n) throw new RangeError('encodeSqrtP0X96: denominator must be positive');
  if (n <= 0n) throw new RangeError('encodeSqrtP0X96: numerator must be positive');
  const ratio = (n * Q192) / d; // floor
  const root = isqrt(ratio); //   floor
  if (root > UINT160_MAX) throw new RangeError('encodeSqrtP0X96: exceeds uint160');
  return root;
}

/**
 * Quantization evidence for a recorded conversion (FR-1.4 "actual marginal
 * price"): the effective encoded ratio is sqrtP0X96^2 / 2^192, and the delta is
 * how far that sits below the exact rational n/d. Reported as an exact rational
 * so the "< 1 ulp" claim is checkable rather than asserted.
 */
export function quantization(n, d, root) {
  const exactNum = n * Q192; //                 exact  n/d, scaled by 2^192
  const encoded = root * root; //               effective ratio, same scale
  const deltaNum = exactNum - encoded * d; //   (n/d - sqrt^2/2^192) * d * 2^192
  const nextUlp = (root + 1n) * (root + 1n) * d - exactNum;
  return {
    effectiveRatioNum: encoded,
    effectiveRatioDen: Q192,
    // floor means the encoding never overstates the price
    underEstimates: deltaNum >= 0n,
    // strictly inside one ulp of the root: root^2 <= x < (root+1)^2
    withinOneUlp: deltaNum >= 0n && nextUlp > 0n,
  };
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) out[key] = true;
    else {
      out[key] = next;
      i++;
    }
  }
  return out;
}

function report(label, n, d) {
  const root = encodeSqrtP0X96(n, d);
  const q = quantization(n, d, root);
  const inTickMathRange = root >= MIN_SQRT_RATIO && root < MAX_SQRT_RATIO;
  return {
    orientation: label,
    n: n.toString(),
    d: d.toString(),
    sqrtP0X96: root.toString(),
    inTickMathRange,
    floorNeverOverstates: q.underEstimates,
    withinOneUlp: q.withinOneUlp,
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const rows = [];

  if (args.rehearsal) {
    // The rehearsal conversion record used by the Sprint-7 genesis suites.
    // Rehearsal values only — the production record is an R-14 founder fact.
    const S0 = 150_000n * 10n ** 18n + 1n;
    const B0 = 272_727_272_727_272_727_272n;
    const p0Num = 11n * B0; // P0 = 1.10 x B0/S0, as the exact rational
    const p0Den = 10n * S0;
    rows.push(report('vux-is-token0', p0Num, p0Den));
    rows.push(report('weth-is-token0', p0Den, p0Num));
  } else if (args.n && args.d) {
    rows.push(report('explicit', BigInt(args.n), BigInt(args.d)));
  } else if (args.b0 && args.s0) {
    const b0 = BigInt(args.b0);
    const s0 = BigInt(args.s0);
    const p0Num = 11n * b0;
    const p0Den = 10n * s0;
    const vuxFirst = Boolean(args['vux-is-token0']);
    rows.push(
      vuxFirst ? report('vux-is-token0', p0Num, p0Den) : report('weth-is-token0', p0Den, p0Num),
    );
  } else {
    console.error('usage: --n <int> --d <int> | --b0 <wei> --s0 <wei> [--vux-is-token0] | --rehearsal');
    process.exit(2);
  }

  console.log(JSON.stringify(rows, null, 2));
}

// Only run when invoked directly, so the exported functions stay importable.
// `pathToFileURL` rather than string-splicing `file://`: on Windows the latter
// yields a two-slash URL against Node's three-slash `import.meta.url` and the
// guard silently never fires.
if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
