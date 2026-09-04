import { test, expect } from '@playwright/test';

// Synthetic signed-in props. Actual session authorization is covered by controller tests.
test.beforeEach(async ({ page }) => {
  await page.route('http://127.0.0.1:4010/', async route => {
    const props = { gmail_connected: true, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: false, gmail_checked: true, csrf_token: 'fixture', notice: null };
    const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
    await route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
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
  status = 503;
  await page.getByRole('button', { name: 'Load recent messages' }).click();
  await expect(page.getByRole('alert')).toContainText('Could not load messages');
  await expect(page.getByText('No Inbox messages to show.')).toHaveCount(0);
  status = 401;
  await page.getByRole('button', { name: 'Load recent messages' }).click();
  await expect(page.getByRole('link', { name: 'Return to connection setup' })).toBeVisible();
});
