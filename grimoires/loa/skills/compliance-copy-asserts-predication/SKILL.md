---
name: compliance-copy-asserts-predication
description: |
  A requirement says a thing must never be *described as* earned/guaranteed/safe.
  Testing that as a banned-word list fails on the requirement's own mandated
  copy — because the mandated disclaimer contains the banned word under negation,
  and adjacent legitimate uses exist. Apply when writing automated tests for
  disclosure, marketing, or truthfulness copy requirements. Provides the two-layer
  scoped-negation + affirmative-construction test design.
loa-agent: implementing-tasks
extracted-from: sprint-6-task-6.7 (VUX v1, FR-15 truthful-UX copy suite)
extraction-date: 2026-08-14
version: 1.0.0
tags:
  - compliance-testing
  - copy-requirements
  - playwright
  - truthful-ux
---

## Problem

A requirement reads: *"Raw opportunity shall never be described as already earned,
owned, claimable, owed, guaranteed, or debt."*

Implemented as a page-wide banned-word grep, the test failed on three pages — and
every hit was **required** text:

| Page | Hit | Why it is mandatory |
|---|---|---|
| `/` | "not **claimable**" | the accepted tier-2 label contains it, under negation |
| `/accounting` | "user-**owned** VUX" | describes *settled* VUX, which genuinely is owned |
| `/trust` | "Every user-**owned** VUX was mined…" | the verbatim contestability claim |

The test could only be made to pass by violating the specification it was meant
to enforce.

## Trigger Conditions

### Symptoms

- A prohibited-phrase test fails on text the requirements mandate verbatim
- The banned word appears inside a required disclaimer, under negation
- The banned word has a legitimate sense for a *different* subject in the domain
- Someone proposes rewording accepted/verbatim copy to satisfy the test

### The tell

The requirement's verb is **"described as"**, **"characterised as"**, **"presented
as"**, **"labelled"**, or **"claimed to be"** — a predication over a subject, not
a vocabulary restriction.

### Context

| Context | Value |
|---|---|
| Technology Stack | Playwright / any rendered-text assertion |
| Timing | writing automated tests for disclosure or truthfulness requirements |
| Prerequisites | requirement text available verbatim |

## Root Cause

A word ban and a predication ban differ on exactly the cases that matter:

| Text | Word ban | Predication ban | Correct |
|---|---|---|---|
| "not claimable" | ✗ fails | ✓ passes | passes — it is the disclaimer |
| "user-owned VUX" (settled) | ✗ fails | ✓ passes | passes — different subject |
| "your VUX is claimable" | ✗ fails | ✗ fails | fails |
| "already earned" | ✗ fails | ✗ fails | fails |

The banned-word test is simultaneously **too strict** (it forbids the mandated
disclaimer) and, on its own, **too weak** — because it says nothing about a
paraphrase like "pending rewards" that contains no banned word at all.

## Solution

### Layer 1: scoped negation — where the requirement actually applies

Inside the elements that display the constrained quantity, the words may appear
**only under negation**:

```javascript
for (const tier of [TIER_1, TIER_2]) {
  const scope = (await page.getByTestId(`tier-${tier.id}`).innerText())
    .toLowerCase().replace(/\s+/g, ' ');
  for (const word of PROHIBITED) {
    const re = new RegExp(`(.{0,24})\\b${word}\\b`, 'g');
    let m;
    while ((m = re.exec(scope))) {
      expect(
        /\b(not|never|no|cannot|isn't|aren't|without)\b[\s\w]*$/.test(m[1]),
        `tier ${tier.id} uses "${word}" affirmatively: "...${m[0]}..."`
      ).toBe(true);
    }
  }
}
```

This is strict where the requirement is strict, and it *permits* the mandated
disclaimer rather than fighting it.

### Layer 2: affirmative constructions — everywhere, no scoping

Ban the phrasings that have no legitimate use anywhere in the product. These catch
paraphrases the word list misses:

```javascript
const AFFIRMATIVE_FRAMINGS = [
  /\b(already|so far)\s+earned\b/,
  /\byou(r|'ve| have)?\s+earned\b/,
  /\b(is|are|be|being|becomes?)\s+claimable\b/,
  /\b(is|are|you\s+are|we)\s+owed\b/,
  /\b(is|are)\s+guaranteed\b/,
  /\bguaranteed\s+(to|reward|payout|return)\b/,
  /\bpending\s+(rewards?|payout)\b/,     // no banned word — still prohibited framing
  /\bunclaimed\s+(rewards?)\b/,
];
```

### Layer 3: allow prohibited *claims* only under negation

For claim families ("trustless", "fair launch", "anti-whale"), the disclosure page
legitimately says "the backing stack is **not** trustless". Check the preceding
words rather than banning the term:

```javascript
const idx = text.indexOf(claim);
if (idx !== -1) {
  const before = text.slice(Math.max(0, idx - 12), idx);
  expect(/\bnot\s$/.test(before), `makes the prohibited claim "${claim}"`).toBe(true);
}
```

### Layer 4: verbatim equality for mandated strings

Where copy must appear verbatim, assert character-for-character against the single
copy module — never `toContain`, which passes on a truncation:

```javascript
await expect(page.getByTestId('canonical-explanation')).toHaveText(CANONICAL_EXPLANATION);
```

## Verification

### Command

```bash
npx playwright test
```

### Expected Output

```
  25 passed
```

### Checklist

- [ ] Requirement's verb identified — "described as" means predication, not vocabulary
- [ ] Words banned only within the scope the requirement names, and only unnegated
- [ ] Affirmative-construction list covers paraphrases containing no banned word
- [ ] Prohibited claims permitted under negation, so disclosures can be made
- [ ] Mandated strings asserted with equality, not containment
- [ ] No accepted/verbatim copy was reworded to make a test pass

## Anti-pattern

**Never reword accepted copy to satisfy a test.** If a test fails on text the
requirements mandate, the test encodes the requirement wrongly. Fix the test. The
copy is the specification's output; the test is your model of it.

## Related

- `truth-labels-outlive-their-data` — the sibling finding from the same suite: a
  compliance *label* must not sit behind a data-availability gate.
