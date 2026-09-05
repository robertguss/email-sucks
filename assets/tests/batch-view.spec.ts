import { test, expect, type Page } from '@playwright/test';

const content = { id: 'message-one', subject: 'A quieter morning', sender: 'Sam <sam@example.test>', preview: 'A small note to look at when you have a moment.', received_at: '2026-09-05T14:00:00Z', status: 'available' as const };
const item = { id: 'thread-one', contents: [content], messages: 1, reviewed: false, status: 'available' as const };
const batch = { revision: 4, state: 'ready', items: [item], total: 1, remaining: 1, pending: 0, unavailable: 0 };

async function shell(page: Page) {
  await page.route('http://127.0.0.1:4010/batch', route => {
    const payload = JSON.stringify({ component: 'BatchView', props: { csrf_token: 'test-csrf' }, url: '/batch', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
    return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
  });
}

test('review persists after reload and undo; Gmail writes are never requested', async ({ page }) => {
  await shell(page);
  let reviewed = false;
  await page.route('**/gmail/batch-view', route => route.fulfill({ json: { ...batch, remaining: reviewed ? 0 : 1, items: [{ ...item, reviewed }] } }));
  await page.route('**/gmail/batch-view/review', route => {
    expect(route.request().method()).toBe('POST');
    expect(route.request().headers()['x-csrf-token']).toBe('test-csrf');
    const body = route.request().postDataJSON();
    expect(body).toEqual({ revision: 4, item_id: item.id, reviewed: !reviewed });
    reviewed = body.reviewed;
    return route.fulfill({ json: { ...batch, remaining: reviewed ? 0 : 1, items: [{ ...item, reviewed }] } });
  });
  await page.goto('/batch');
  await expect(page.getByRole('heading', { name: 'Your delivery', exact: true })).toBeVisible();
  await expect(page.getByText(content.preview)).toBeVisible();
  await page.getByRole('button', { name: 'Mark reviewed', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'You’re caught up', exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByRole('button', { name: 'Mark unreviewed', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Mark unreviewed', exact: true }).click();
  await expect(page.getByText('1 conversation left to review.')).toBeVisible();
});

test('pending and unavailable items cannot be reviewed or appear caught up', async ({ page }) => {
  await shell(page);
  await page.route('**/gmail/batch-view', route => route.fulfill({ json: { ...batch, state: 'pending', remaining: 0, pending: 1, unavailable: 1, total: 2, items: [{ ...item, status: 'pending', contents: [{ ...content, status: 'pending' }] }, { ...item, id: 'gone', status: 'unavailable', contents: [{ ...content, status: 'unavailable' }] }] } }));
  await page.goto('/batch');
  await expect(page.getByRole('heading', { name: 'Delivery needs attention' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Mark reviewed', exact: true })).toHaveCount(0);
  await expect(page.getByText('You’re caught up')).toHaveCount(0);
});

test('failed review stays unreviewed and stale state requests refresh', async ({ page }) => {
  await shell(page);
  await page.route('**/gmail/batch-view', route => route.fulfill({ json: batch }));
  await page.route('**/gmail/batch-view/review', route => route.fulfill({ status: 409, json: { error: 'stale_batch' } }));
  await page.goto('/batch');
  await page.getByRole('button', { name: 'Mark reviewed', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('Refresh');
  await expect(page.getByRole('button', { name: 'Mark unreviewed' })).toHaveCount(0);
});

for (const colorScheme of ['light', 'dark'] as const) {
  test(`safe text and responsive layout in ${colorScheme}`, async ({ page }) => {
    await shell(page);
    await page.emulateMedia({ colorScheme });
    await page.route('**/gmail/batch-view', route => route.fulfill({ json: { ...batch, items: [{ ...item, contents: [{ ...content, preview: '<img src=x onerror=alert(1)> Plain text, no remote images.' }] }] } }));
    await page.goto('/batch');
    await expect(page.getByText('<img src=x onerror=alert(1)> Plain text, no remote images.')).toBeVisible();
    await expect(page.locator('main img')).toHaveCount(0);
    for (const width of [390, 1440]) {
      await page.setViewportSize({ width, height: 1000 });
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
      await page.screenshot({ path: test.info().outputPath(`batch-${colorScheme}-${width}.png`), fullPage: true });
    }
  });
}

 test('every message in a frozen group is visible before group review', async ({ page }) => {
  await shell(page);
  const second = { ...content, id: 'message-two', sender: 'Lee <lee@example.test>', subject: 'Another saved message', preview: 'The second distinct preview.' };
  await page.route('**/gmail/batch-view', route => route.fulfill({ json: { ...batch, items: [{ ...item, messages: 2, contents: [content, second] }] } }));
  await page.goto('/batch');
  for (const message of [content, second]) {
    await expect(page.getByText(message.sender, { exact: true })).toBeVisible();
    await expect(page.getByRole('heading', { name: message.subject, exact: true })).toBeVisible();
    await expect(page.getByText(message.preview, { exact: true })).toBeVisible();
  }
  await expect(page.getByRole('button', { name: 'Mark reviewed', exact: true })).toHaveCount(1);
 });

 test('reviewed then deleted message stays incomplete with truthful Gmail advice', async ({ page }) => {
  await shell(page);
  let deleted = false;
  await page.route('**/gmail/batch-view', route => route.fulfill({ json: { ...batch, remaining: 0, unavailable: deleted ? 1 : 0, state: deleted ? 'pending' : 'ready', items: [{ ...item, reviewed: true, status: deleted ? 'unavailable' : 'available', contents: [{ ...content, status: deleted ? 'unavailable' : 'available' }] }] } }));
  await page.goto('/batch');
  await expect(page.getByRole('heading', { name: 'You’re caught up' })).toBeVisible();
  deleted = true;
  await page.getByRole('button', { name: 'Refresh delivery' }).click();
  await expect(page.getByRole('heading', { name: 'Delivery needs attention' })).toBeVisible();
  await expect(page.getByText(/Check Gmail for the unavailable/)).toBeVisible();
  await expect(page.getByText(/Check the recovery controls/)).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Mark unreviewed' })).toHaveCount(0);
 });

 for (const status of [401, 503]) {
  test(`initial ${status} response shows recovery copy without false completion`, async ({ page }) => {
    await shell(page);
    await page.route('**/gmail/batch-view', route => route.fulfill({ status, json: { error: 'unavailable' } }));
    await page.goto('/batch');
    await expect(page.getByRole('alert')).toContainText(status === 401 ? 'connection needs attention' : 'couldn’t confirm');
    await expect(page.getByRole('heading', { name: 'You’re caught up' })).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Refresh delivery' })).toBeEnabled();
  });
 }
