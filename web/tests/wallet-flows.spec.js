// Wallet transaction flows (H-2) — `take` with its `maxPrice` guard, and `redeem`.
//
// These run against the SHIPPED static export, in the degraded state the rest of
// the suite uses (no RPC reachable). That is deliberate and it is the sharper
// test: the requirement is that unavailable data must never become a guessed
// transaction input. A flow that offers a `take` when it cannot read the price
// would be offering an unguarded transaction.
//
// A real signer is not injected here. What is asserted is everything that does
// not require one: the flows exist and are wired, they are disabled rather than
// optimistic when inputs are missing, the custody statement is present, and the
// copy makes no entitlement claim.

import { test, expect } from '@playwright/test';
import { WALLET_COPY, PROHIBITED_OF_UNSETTLED } from '../lib/truth-copy.js';

test.describe('take flow', () => {
  test.beforeEach(async ({ page }) => { await page.goto('/'); });

  test('the throne page carries a real take flow, not just an ABI', async ({ page }) => {
    await expect(page.getByTestId('take-flow')).toBeVisible();
  });

  test('with no readable price, no transaction is offered and the reason is explicit', async ({ page }) => {
    // The suite runs with no RPC, so the price is genuinely unreadable.
    await expect(page.getByTestId('take-unavailable')).toHaveText(WALLET_COPY.takeNoPrice);
    // The critical property: no submit button exists to press against a guessed price.
    await expect(page.getByTestId('take-submit')).toHaveCount(0);
    await expect(page.getByTestId('take-maxprice')).toHaveCount(0);
  });

  test('the wallet is the only signer, and the page says so', async ({ page }) => {
    await expect(page.getByTestId('wallet-custody')).toHaveText(WALLET_COPY.noCustody);
    await expect(page.getByTestId('wallet-connect')).toBeVisible();
    // Not connected, so no address is displayed and nothing is presented as ready.
    await expect(page.getByTestId('wallet-connected')).toHaveCount(0);
  });

  test('no transaction status is shown before a transaction exists', async ({ page }) => {
    await expect(page.getByTestId('take-status')).toHaveCount(0);
  });

  test('the maxPrice guard is explained as a ceiling, not a promise', async ({ page }) => {
    const note = WALLET_COPY.maxPriceNote.toLowerCase();
    expect(note).toContain('rejects it rather than charging you more');
    // The explanation must not imply the shown price is the price that will execute.
    expect(note).toContain('falls continuously');
  });
});

test.describe('redeem flow', () => {
  test.beforeEach(async ({ page }) => { await page.goto('/redeem'); });

  test('the redeem page carries a real redeem flow', async ({ page }) => {
    await expect(page.getByTestId('redeem-flow')).toBeVisible();
  });

  test('with no amount entered, the submit is disabled and no raw amount is shown', async ({ page }) => {
    await expect(page.getByTestId('redeem-submit')).toBeDisabled();
    await expect(page.getByTestId('redeem-raw-amount')).toHaveCount(0);
  });

  test('the EXACT raw quantity is displayed, and it is the integer-parsed one', async ({ page }) => {
    // The reviewer's precision case, driven through the real input element.
    await page.getByTestId('redeem-input').fill('12345.6789');
    await expect(page.getByTestId('redeem-raw-amount')).toHaveText('12345678900000000000000');
    // The float path would have produced 12345678900000001622016.
    await expect(page.getByTestId('redeem-raw-amount')).not.toHaveText('12345678900000001622016');
  });

  test('raw quantities stay exact across boundary inputs', async ({ page }) => {
    for (const [typed, raw] of [
      ['1.005', '1005000000000000000'],
      ['1000.000000000000000001', '1000000000000000000001'],
      ['0.000000000000000001', '1'],
      ['1', '1000000000000000000'],
    ]) {
      await page.getByTestId('redeem-input').fill(typed);
      await expect(page.getByTestId('redeem-raw-amount')).toHaveText(raw);
    }
  });

  test('excess decimal precision is refused, and no raw amount is offered', async ({ page }) => {
    await page.getByTestId('redeem-input').fill('1.0000000000000000001'); // 19 decimals
    await expect(page.getByTestId('redeem-amount-error')).toContainText('18 decimals');
    await expect(page.getByTestId('redeem-raw-amount')).toHaveCount(0);
    await expect(page.getByTestId('redeem-submit')).toBeDisabled();
    await expect(page.getByTestId('redeem-quote-empty')).toBeVisible();
  });

  test('malformed input yields no quantity and no quote', async ({ page }) => {
    await page.getByTestId('redeem-input').fill('abc');
    await expect(page.getByTestId('redeem-amount-error')).toBeVisible();
    await expect(page.getByTestId('redeem-raw-amount')).toHaveCount(0);
    await expect(page.getByTestId('redeem-quote')).toHaveCount(0);
  });

  test('unreadable Reserve state is disclosed, and never becomes a guessed quote', async ({ page }) => {
    await page.getByTestId('redeem-input').fill('5');
    await expect(page.getByTestId('redeem-quote-unavailable')).toBeVisible();
    // No quote is rendered, and specifically not a zero that reads like a payout.
    await expect(page.getByTestId('redeem-quote')).toHaveCount(0);
    await expect(page.getByTestId('redeem-quote-empty')).toHaveText('—');
    // But the burn quantity is still exact and still shown — the transaction is
    // well defined even when the payout preview is not.
    await expect(page.getByTestId('redeem-raw-amount')).toHaveText('5000000000000000000');
  });
});

test('wallet copy predicates no entitlement on unsettled VUX', async ({ page }) => {
  await page.goto('/');
  const text = (await page.locator('body').innerText()).toLowerCase();
  for (const re of [
    /\b(is|are|be|being|becomes?)\s+claimable\b/,
    /\b(is|are|you\s+are|we)\s+owed\b/,
    /\b(is|are)\s+guaranteed\b/,
    /\byou(r|'ve| have)?\s+earned\b/,
  ]) {
    expect(text.match(re), `wallet copy predicates a prohibited framing: ${re}`).toBeNull();
  }
  // The success message must not describe a submitted transaction as a payout.
  expect(WALLET_COPY.submitted.toLowerCase()).toContain('settled history');
  for (const w of PROHIBITED_OF_UNSETTLED) {
    expect(WALLET_COPY.takeAction.toLowerCase()).not.toContain(w);
    expect(WALLET_COPY.redeemAction.toLowerCase()).not.toContain(w);
  }
});
