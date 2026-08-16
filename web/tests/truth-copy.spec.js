// FR-15 copy suite — the truth requirements, asserted against the shipped pages.
//
// These are product requirements with a compliance character, so the assertions
// are deliberately literal: verbatim strings compared character-for-character,
// and prohibited phrases grepped out of the rendered text rather than reasoned
// about. A test that checked "the page says something reassuring about
// estimates" would pass while the copy drifted.

import { test, expect } from '@playwright/test';
import {
  TIER_1, TIER_2, TIER_3,
  CANONICAL_EXPLANATION, CONTESTABILITY_CLAIM, YELLOW_DISCLOSURE,
  PROHIBITED_OF_UNSETTLED, PROHIBITED_CLAIMS,
  STRATEGIC_LABELS, REDEEM_COPY, UNAVAILABLE,
} from '../lib/truth-copy.js';

const PAGES = ['/', '/redeem', '/accounting', '/treasury', '/trust'];
/** Pages that describe the Reserve and therefore MUST carry the disclosure. */
const RESERVE_PAGES = ['/redeem', '/accounting', '/trust'];
/** Pages that show mining state and therefore MUST show all three tiers. */
const MINING_PAGES = ['/'];

const bodyText = async (page) => (await page.locator('body').innerText()).replace(/\s+/g, ' ');

// ---------------------------------------------------------------------------
// Three-tier truth (FR-15.1) — distinct labels, distinct blocks
// ---------------------------------------------------------------------------

for (const path of MINING_PAGES) {
  test(`${path}: the three tiers are present, labelled and visually distinct`, async ({ page }) => {
    await page.goto(path);

    for (const tier of [TIER_1, TIER_2, TIER_3]) {
      const block = page.getByTestId(`tier-${tier.id}`);
      await expect(block, `tier block ${tier.id} is missing`).toBeVisible();
      await expect(page.getByTestId(`tier-label-${tier.id}`)).toHaveText(tier.label);
      await expect(page.getByTestId(`tier-qualifier-${tier.id}`)).toHaveText(tier.qualifier);
    }

    // Distinct blocks, not one number with a footnote.
    await expect(page.locator('[data-tier]')).toHaveCount(3);
    const labels = await page.locator('.tier__label').allInnerTexts();
    expect(new Set(labels).size, 'the three tier labels must differ from each other').toBe(3);
  });

  test(`${path}: the canonical explanation appears verbatim`, async ({ page }) => {
    await page.goto(path);
    await expect(page.getByTestId('canonical-explanation')).toHaveText(CANONICAL_EXPLANATION);
  });

  test(`${path}: the tier-2 label states both variability and non-claimability`, async ({ page }) => {
    await page.goto(path);
    const label = await page.getByTestId(`tier-label-${TIER_2.id}`).innerText();
    expect(label.toLowerCase()).toContain('may rise or fall');
    expect(label.toLowerCase()).toContain('not claimable');
  });
}

// ---------------------------------------------------------------------------
// Prohibited framings (FR-15.2) — grepped from rendered text, every page
// ---------------------------------------------------------------------------

for (const path of PAGES) {
  test(`${path}: no prohibited framing is PREDICATED of unsettled opportunity`, async ({ page }) => {
    await page.goto(path);
    const text = (await bodyText(page)).toLowerCase();

    // FR-15.2 prohibits raw opportunity being "described as already earned, owned,
    // claimable, owed, guaranteed, or debt". That is a rule about predication, not
    // a lexical ban, and the difference is load-bearing in both directions:
    //
    //   - tier 2's own mandated label is "...not claimable" (sdd.md:L630), so a
    //     word ban would forbid the required copy;
    //   - the verbatim contestability claim says "Every user-owned VUX was mined"
    //     (prd.md:L549), and settled VUX genuinely is owned.
    //
    // So the assertion is on the affirmative constructions, which have no
    // legitimate use anywhere in this product.
    const AFFIRMATIVE_FRAMINGS = [
      /\b(already|so far)\s+earned\b/,
      /\byou(r|'ve| have)?\s+earned\b/,
      /\bearned\s+(so far|while|during|as)\b/,
      /\b(is|are|be|being|becomes?)\s+claimable\b/,
      /\bclaim\s+(your|the)\s+(vux|reward|rewards)\b/,
      /\b(is|are|you\s+are|we)\s+owed\b/,
      /\bowed\s+to\s+you\b/,
      /\b(is|are)\s+guaranteed\b/,
      /\bguaranteed\s+(to|vux|reward|payout|return)\b/,
      /\b(protocol|your|a)\s+debt\b/,
      /\bpending\s+(rewards?|payout)\b/,
      /\bunclaimed\s+(vux|rewards?)\b/,
    ];
    for (const re of AFFIRMATIVE_FRAMINGS) {
      const hit = text.match(re);
      expect(hit, `page ${path} predicates a prohibited framing: "${hit?.[0]}" (context: ${
        hit ? text.slice(Math.max(0, hit.index - 90), hit.index + 90) : ''
      })`).toBeNull();
    }
  });
}

// Scoped form of the same rule: inside the tier-1 and tier-2 blocks, any of the
// six words may appear ONLY under negation. This is the strict reading, applied
// exactly where FR-15.2 applies it.
for (const path of MINING_PAGES) {
  test(`${path}: within the tier-1/tier-2 blocks the prohibited words appear only negated`, async ({ page }) => {
    await page.goto(path);
    for (const tier of [TIER_1, TIER_2]) {
      const scope = (await page.getByTestId(`tier-${tier.id}`).innerText()).toLowerCase().replace(/\s+/g, ' ');
      for (const word of PROHIBITED_OF_UNSETTLED) {
        const re = new RegExp(`(.{0,24})\\b${word}\\b`, 'g');
        let m;
        while ((m = re.exec(scope))) {
          const preceding = m[1];
          expect(
            /\b(not|never|no|cannot|isn't|aren't|without)\b[\s\w]*$/.test(preceding),
            `tier ${tier.id} uses "${word}" affirmatively: "...${m[0]}..."`
          ).toBe(true);
        }
      }
    }
  });

  test(`${path}: makes no broad-distribution, anti-whale or trustless claim`, async ({ page }) => {
    await page.goto(path);
    const text = (await bodyText(page)).toLowerCase();
    for (const claim of PROHIBITED_CLAIMS) {
      // "not trustless" is the disclosure; the prohibition is the positive claim.
      const idx = text.indexOf(claim);
      if (idx === -1) continue;
      const before = text.slice(Math.max(0, idx - 12), idx);
      expect(/\bnot\s$/.test(before), `page ${path} makes the prohibited claim "${claim}"`).toBe(true);
    }
  });
}

// ---------------------------------------------------------------------------
// YELLOW disclosure (INV-36) — verbatim, coupled, on every Reserve description
// ---------------------------------------------------------------------------

for (const path of RESERVE_PAGES) {
  test(`${path}: the YELLOW disclosure renders verbatim wherever the Reserve is described`, async ({ page }) => {
    await page.goto(path);
    const disclosures = page.getByTestId('yellow-disclosure');
    await expect(disclosures.first()).toBeVisible();

    const count = await disclosures.count();
    for (let i = 0; i < count; i++) {
      await expect(disclosures.nth(i).locator('.disclosure__text')).toHaveText(YELLOW_DISCLOSURE);
    }

    // The coupling is what INV-36 requires: a Reserve description without the
    // disclosure beside it is the failure being prevented.
    const descriptions = await page.getByTestId('reserve-description').count();
    expect(count, `${descriptions} Reserve description(s) but ${count} disclosure(s)`).toBe(descriptions);
  });
}

test('a Reserve description never appears without the disclosure, on any page', async ({ page }) => {
  for (const path of PAGES) {
    await page.goto(path);
    const descriptions = await page.getByTestId('reserve-description').count();
    const disclosures = await page.getByTestId('yellow-disclosure').count();
    expect(disclosures, `${path}: ${descriptions} description(s) vs ${disclosures} disclosure(s)`).toBe(descriptions);
  }
});

// ---------------------------------------------------------------------------
// Contestability, in its exact bounded form only (FR-15.4)
// ---------------------------------------------------------------------------

test('/trust: the contestability claim appears in exactly its bounded form', async ({ page }) => {
  await page.goto('/trust');
  await expect(page.getByTestId('contestability-claim')).toHaveText(CONTESTABILITY_CLAIM);
  const bound = await page.getByTestId('contestability-bound').innerText();
  expect(bound.toLowerCase()).toContain('not that outcomes are equal');
});

test('the contestability claim appears nowhere else, in whole or in fragment', async ({ page }) => {
  const fragment = 'mined under the same public';
  for (const path of PAGES.filter((p) => p !== '/trust')) {
    await page.goto(path);
    expect((await bodyText(page)).includes(fragment), `${path} repeats the contestability claim`).toBe(false);
  }
});

// ---------------------------------------------------------------------------
// Strategic is never backing (FR-14.4)
// ---------------------------------------------------------------------------

test('no page labels a Strategic value as backing', async ({ page }) => {
  for (const path of PAGES) {
    await page.goto(path);
    const text = await bodyText(page);
    // Any sentence containing both "Strategic" and "backing" must be one that
    // separates them, never one that equates them.
    for (const sentence of text.split(/(?<=[.!?])\s+/)) {
      if (!/strategic/i.test(sentence) || !/backing/i.test(sentence)) continue;
      expect(
        /not\s+(hard\s+)?backing|never\s+.{0,20}backing|not\s+counted/i.test(sentence),
        `${path}: a sentence puts Strategic and backing together without separating them: "${sentence}"`
      ).toBe(true);
    }
  }
});

test('/accounting and /treasury use the accepted strategic_nav_disclosed naming', async ({ page }) => {
  for (const path of ['/accounting', '/treasury']) {
    await page.goto(path);
    const text = await bodyText(page);
    expect(text).toContain(STRATEGIC_LABELS.navColumn);
    expect(text).toContain(STRATEGIC_LABELS.neverBacking);
  }
});

test('/treasury discloses that NAV is disclosed rather than derived', async ({ page }) => {
  await page.goto('/treasury');
  await expect(page.getByTestId('treasury-nav-qualifier')).toHaveText(STRATEGIC_LABELS.navQualifier);
  await expect(page.getByTestId('treasury-nav-disclosed')).toHaveText('Not disclosed');
});

// ---------------------------------------------------------------------------
// Estimates create no entitlement (FR-14 acceptance, prd.md:L539)
// ---------------------------------------------------------------------------

test('/redeem: the quote is labelled a quotation and disclaims entitlement', async ({ page }) => {
  await page.goto('/redeem');
  await expect(page.getByTestId('redeem-qualifier')).toHaveText(REDEEM_COPY.quoteQualifier);
  await expect(page.getByTestId('redeem-no-entitlement')).toHaveText(REDEEM_COPY.noEntitlement);
});

test('/redeem: with no amount entered, no optimistic value is displayed', async ({ page }) => {
  await page.goto('/redeem');
  await expect(page.getByTestId('redeem-quote-empty')).toHaveText('—');
  await expect(page.getByTestId('redeem-quote')).toHaveCount(0);
});

// ---------------------------------------------------------------------------
// Failure truthfulness (FB-17, FB-18) — this build has no RPC configured, so
// every live read is in its failure path. That is the state under test.
// ---------------------------------------------------------------------------

test('unreadable values render as explicitly unavailable, never as 0 or a stale number', async ({ page }) => {
  await page.goto('/');
  const unavailable = page.getByTestId('data-unavailable');
  await expect(unavailable.first()).toBeVisible();
  await expect(unavailable.first()).toContainText(UNAVAILABLE.label);

  // The tiers must show the unavailable state rather than a number.
  for (const tier of [TIER_1, TIER_2, TIER_3]) {
    const block = page.getByTestId(`tier-${tier.id}`);
    const value = await block.locator('.tier__value').innerText();
    expect(value, `tier ${tier.id} rendered a value with no data source`).toContain(UNAVAILABLE.label);
    expect(value).not.toMatch(/(^|\s)0(\.0+)?(\s|$)/);
  }
});

test('the chain-outage banner appears when live reads cannot be made (FB-17)', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByTestId('outage-banner')).toBeVisible();
  await expect(page.getByTestId('outage-banner')).toContainText(UNAVAILABLE.outage);
});

test('/trust carries the FB-18 documented disclosure of the unavailable policy', async ({ page }) => {
  await page.goto('/trust');
  await expect(page.getByTestId('trust-unavailable-policy')).toHaveText(UNAVAILABLE.neverStale);
  await expect(page.getByTestId('yellow-disclosure').first()).toBeVisible();
});

test('every page reaches the Trust page, so the disclosure is always one click away', async ({ page }) => {
  for (const path of PAGES) {
    await page.goto(path);
    await expect(page.getByTestId('nav-trust')).toBeVisible();
  }
});
