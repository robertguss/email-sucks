import { test, expect } from '@playwright/test';

// Synthetic signed-in props. Actual session authorization is covered by controller tests.
test.beforeEach(async ({ page }) => {
  await page.route('http://127.0.0.1:4010/', async route => {
    const props = { gmail_connected: true, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: false, gmail_checked: true, csrf_token: 'fixture', notice: null };
    const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
    await route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
  });
});

test('explicit load shows safe text, loading feedback and no persisted message data', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  let release!: () => void;
  const gate = new Promise<void>(resolve => { release = resolve; });
  let requests = 0;
  await page.route('**/gmail/messages', async route => {
    requests++;
    await gate;
    await route.fulfill({ json: { messages: [{ id: 'fixture', sender: 'Test Sender', subject: '<img src=x onerror=alert(1)>', received_at: '2026-09-04T12:00:00Z', unread: true }] } });
  });
  await page.goto('/');
  expect(requests).toBe(0);
  await page.getByRole('button', { name: 'Load recent messages' }).click();
  await expect(page.getByRole('button', { name: 'Loading messages…' })).toBeDisabled();
  await page.screenshot({ path: '../.local/desk-loading.png', fullPage: true });
  release();
  await expect(page.getByText('Loaded 1 message.')).toBeVisible();
  await expect(page.getByRole('heading', { name: '<img src=x onerror=alert(1)>' })).toBeVisible();
  await expect(page.locator('.message-list img')).toHaveCount(0);
  expect(await page.evaluate(() => JSON.stringify({ history: history.state, local: { ...localStorage }, session: { ...sessionStorage } }))).not.toContain('Test Sender');
  await page.getByRole('button', { name: 'Hide messages' }).click();
  await expect(page.locator('.message-list')).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('empty and failed requests are distinct and retryable', async ({ page }) => {
  let status = 200;
  await page.route('**/gmail/messages', route => route.fulfill({ status, json: status === 200 ? { messages: [] } : { error: 'unavailable' } }));
  await page.goto('/');
  await page.getByRole('button', { name: 'Load recent messages' }).click();
  await expect(page.getByText('No Inbox messages to show.')).toBeVisible();
  await page.screenshot({ path: '../.local/desk-empty.png', fullPage: true });
  status = 503;
  await page.getByRole('button', { name: 'Load recent messages' }).click();
  await expect(page.getByRole('alert')).toContainText('Could not load messages');
  await page.screenshot({ path: '../.local/desk-error.png', fullPage: true });
  await expect(page.getByText('No Inbox messages to show.')).toHaveCount(0);
  status = 401;
  await page.getByRole('button', { name: 'Load recent messages' }).click();
  await expect(page.getByRole('link', { name: 'Return to connection setup' })).toBeVisible();
});

for (const scheme of ['light', 'dark'] as const) {
  for (const width of [390, 1440]) {
    test(`Desk preview layout at ${width}px in ${scheme}`, async ({ page }) => {
      await page.setViewportSize({ width, height: 1000 });
      await page.emulateMedia({ colorScheme: scheme });
      await page.route('**/gmail/messages', route => route.fulfill({ json: { messages: [
        { id: '1', sender: 'Margaret Ellison', subject: 'The Hollis contract, revised', received_at: '2026-09-04T14:00:00Z', unread: true },
        { id: '2', sender: 'Tomás Reyes', subject: 'Can you speak Thursday morning?', received_at: '2026-09-04T12:30:00Z', unread: false },
        { id: '3', sender: 'Priya Natarajan', subject: 'Draft two, with your notes folded in', received_at: '2026-09-03T15:00:00Z', unread: false },
        { id: '4', sender: 'Owen Blackwood', subject: 'Invoice for August', received_at: '2026-09-03T11:00:00Z', unread: true },
        { id: '5', sender: 'Clara Whitmore', subject: 'A book you might like', received_at: '2026-09-02T11:00:00Z', unread: false },
      ] } }));
      await page.goto('/');
      await page.getByRole('button', { name: 'Load recent messages' }).click();
      await expect(page.getByText('Loaded 5 messages.')).toBeVisible();
      await page.evaluate(() => document.fonts.ready);
      expect(await page.evaluate(() => document.fonts.check('19px Newsreader'))).toBe(true);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
      await page.screenshot({ path: `../.local/desk-${width}-${scheme}.png`, fullPage: true });
      await page.locator('.connection-details summary').click();
      await expect(page.getByRole('button', { name: 'Check connection', exact: true })).toBeVisible();
      await expect(page.getByRole('button', { name: 'Sign out of this app' })).toBeVisible();
      await page.keyboard.press('Tab');
      await expect(page.getByRole('button', { name: 'Check connection', exact: true })).toBeFocused();
      expect(await page.getByRole('button', { name: 'Check connection', exact: true }).evaluate(el => getComputedStyle(el).outlineStyle)).not.toBe('none');
    });
  }
}
