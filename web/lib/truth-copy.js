// truth-copy — the single source for every user-facing truth string.
//
// FR-15 is a product requirement, not a styling preference, so the strings that
// carry it live in exactly one module: review reads one file, the Playwright copy
// suite asserts against one file, and a page cannot quietly paraphrase a
// requirement into something friendlier.
//
// Anything exported from here is user-visible copy. If a string is not here, it
// is not a truth claim.
//
// NOTE ON THE FILE EXTENSION. sprint.md Task 6.6 names this module `truth-copy.ts`.
// It is `.js` because the accepted off-chain provenance refreeze does not
// authorize the `typescript` package (it is an OPTIONAL peer everywhere it
// appears in the accepted set, and §8 excludes it explicitly). Next.js requires
// the `typescript` package to compile `.ts`/`.tsx`, so authoring in TypeScript
// would mean unauthorized dependency expansion. The newer, more specific
// authority governs. Recorded for review rather than silently renamed.

// ---------------------------------------------------------------------------
// The three-tier truth (FR-15.1, sdd.md:L627-L631)
//
// The tiers are three different KINDS of fact, not three precisions of one fact:
// a ceiling, a live reading, and settled history. Every mining surface must show
// them as distinct.
// ---------------------------------------------------------------------------

export const TIER_1 = {
  id: 'raw-clock-limit',
  label: 'Raw clock limit — maximum from time',
  short: 'Raw clock limit',
  meaning:
    'The most the clock can produce for the current reign. It is a ceiling, not a balance, and it does not accrue to anyone.',
  // Stated positively as well as negatively: a reader should learn what the
  // number IS, not only the six words we refuse to use about it.
  qualifier: 'Not a balance. It expires unrecorded if the next settlement cannot support it.',
  source: 'Lens.rawClockLimit()',
};

export const TIER_2 = {
  id: 'estimate-if-displaced-now',
  label: 'VUX if displaced now — live estimate, may rise or fall, not claimable',
  short: 'VUX if displaced now',
  meaning:
    'What a settlement in this block would mint to the current King, under the price, supply and backing right now.',
  qualifier: 'A live estimate. Every input moves, so it may rise or fall. Reading it reserves nothing.',
  source: 'Lens.estimateIfDisplacedNow()',
};

export const TIER_3 = {
  id: 'vux-mined-settled',
  label: 'VUX mined (settled)',
  short: 'VUX mined',
  meaning: 'VUX actually minted by a completed settlement. This is the only amount that has been mined.',
  qualifier: 'Settled history. Nothing here is an estimate.',
  source: 'indexer settlement history',
};

export const TIERS = [TIER_1, TIER_2, TIER_3];

/** Verbatim availability is required (FR-15.3, prd.md:L548). Do not reword. */
export const CANONICAL_EXPLANATION =
  'You mine while you hold the throne. The clock sets the maximum reward. Your exact VUX is settled when the next King pays, and only the amount safely backed by that payment is minted.';

/**
 * The contestability claim, in its exact bounded form (FR-15.4, prd.md:L549).
 * This is the ONLY contestability claim the product may make. It is a statement
 * about how supply originated — not about distribution, fairness, or outcomes.
 */
export const CONTESTABILITY_CLAIM =
  'No user received VUX at genesis. Every user-owned VUX was mined under the same public KOTH/VEM rules or purchased from existing supply in the open market.';

/**
 * Phrases that may never describe tier-1 or tier-2 quantities (FR-15.2,
 * prd.md:L547), plus the broader-claim family FR-15.4 forbids. The Playwright
 * suite greps rendered pages for these.
 */
export const PROHIBITED_OF_UNSETTLED = ['earned', 'owned', 'claimable', 'owed', 'guaranteed', 'debt'];

export const PROHIBITED_CLAIMS = [
  'fair launch',
  'anti-whale',
  'equal outcome',
  'equal outcomes',
  'evenly distributed',
  'broad distribution',
  'widely distributed',
  'trustless',
  'governance-free',
  'risk-free',
  'guaranteed return',
  'guaranteed yield',
];

// ---------------------------------------------------------------------------
// Hard Reserve (FR-7, INV-10) and the mandatory YELLOW disclosure
// ---------------------------------------------------------------------------

/**
 * VERBATIM AND MANDATORY wherever the Reserve is described as ownerless or
 * immutable (prd.md:L722-L723, INV-36). Reproduced character-for-character from
 * the accepted PRD. `<ReserveDescription/>` is the only component that renders a
 * Reserve description, and it always renders this alongside it — the coupling is
 * structural rather than a rule someone has to remember.
 */
export const YELLOW_DISCLOSURE =
  'The VUX Hard Reserve contract is designed to be immutable and ownerless. Its backing asset is canonical Robinhood Chain WETH, which retains an external Robinhood Chain governance and upgrade trust assumption.';

export const RESERVE_DESCRIPTION =
  'The Hard Reserve holds raw canonical WETH and pays it out pro rata against burned VUX. Backing is the contract’s physical WETH balance — there is no other accounting cell.';

/** No-trustless-claims language (prd.md:L726). */
export const NO_TRUSTLESS_CLAIM =
  'The backing stack is not trustless. The Reserve contract is ownerless and immutable; the asset it holds is not, and that external trust assumption is disclosed above rather than designed away.';

// ---------------------------------------------------------------------------
// Strategic — never "backing" (FR-14.4)
// ---------------------------------------------------------------------------

export const STRATEGIC_LABELS = {
  contributedPrincipal: 'Strategic contributed principal',
  navDisclosed: 'Strategic NAV (disclosed)',
  navColumn: 'strategic_nav_disclosed',
  navQualifier:
    'Disclosed, not derived. A mark is not a transfer, so this figure cannot be reconstructed from chain events and is not protocol truth.',
  neverBacking:
    'Strategic value is not Hard backing. It is not redeemable, and it is not counted in B or in backing per VUX.',
};

// ---------------------------------------------------------------------------
// Redemption — a quotation, never an entitlement (FR-14 acceptance, prd.md:L539)
// ---------------------------------------------------------------------------

export const REDEEM_COPY = {
  quoteLabel: 'Payout at current state',
  quoteQualifier:
    'A quotation computed from B and S as they are right now, not a reservation. Both move, including in the transaction ahead of yours.',
  deterministic: 'Redemption is fee-free and deterministic: floor(B × q / S) on the values at execution.',
  noEntitlement: 'Viewing a quote reserves nothing and entitles you to nothing.',
};

// ---------------------------------------------------------------------------
// Failure truthfulness (FB-17, FB-18, sdd.md:L836)
//
// The rule these encode: an unavailable number is reported as unavailable. It is
// never replaced by a stale value, a zero, or a dash that reads like a measured
// result.
// ---------------------------------------------------------------------------

export const UNAVAILABLE = {
  label: 'Data unavailable',
  rpc: 'Data unavailable — could not reach the chain. Nothing below is current, so nothing below is shown.',
  indexer: 'Data unavailable — the indexer is unreachable. Settled history cannot be shown right now.',
  stale: (seconds) =>
    `Data unavailable — the last successful read was ${seconds}s ago and is no longer current. A stale value is not shown as a live one.`,
  outage:
    'The chain appears to be unreachable. The protocol continues to hold whatever it held; this interface simply cannot see it, and will not guess.',
  neverStale: 'This interface does not display a stale value as if it were current.',
};

// ---------------------------------------------------------------------------
// Wallet flows (sdd.md:L633, §4.4)
//
// A submitted transaction is not a settlement and not an entitlement. None of
// this copy tells a reader they have earned, are owed, or may claim anything;
// it describes what the wallet is being asked to sign and what came back.
// ---------------------------------------------------------------------------

export const WALLET_COPY = {
  connect: 'Connect wallet',
  noCustody:
    'Your wallet signs. This interface holds no keys, takes no custody, and has no server to sign on your behalf.',

  maxPriceLabel: 'Maximum price you will pay:',
  maxPriceNote:
    'The price falls continuously, and a takeover in the same block can raise it. This maximum is the price shown when you confirm, sent with the transaction — if the price is above it when the transaction lands, the protocol rejects it rather than charging you more.',
  takeAction: 'Approve WETH and take the throne',
  takeNoPrice:
    'Data unavailable — the current price cannot be read, so no transaction is offered. A price that cannot be read cannot be guarded against.',

  redeemExact: 'Exact amount this transaction will burn (raw units):',
  redeemAction: 'Burn VUX and redeem',
  redeemNoQuote:
    'Data unavailable — Reserve state cannot be read, so no quote is shown. The transaction below still burns exactly the amount you entered.',

  wrongNetworkLabel: 'Wrong network',
  wrongNetwork:
    'Your wallet is connected to a different network than this deployment. No approval and no transaction will be requested while the networks differ — the addresses on this page mean nothing on another chain.',
  switchNetworkAction: 'Switch your wallet to the correct network',

  stepApprove: 'approving WETH',
  stepTake: 'taking the throne',
  stepRedeem: 'redeeming',
  pending: 'Waiting for your wallet and the chain',
  submitted:
    'Transaction confirmed on chain. What it actually produced is settled history — read it on the Accounting page rather than assuming this figure.',
  failed: 'The transaction did not go through:',
};

export const DISCLOSURE_TRUST_PAGE_TITLE = 'Trust and disclosures';
