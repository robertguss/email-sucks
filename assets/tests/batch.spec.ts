import { test, expect } from '@playwright/test';

for (const state of ['not_started', 'holding', 'held', 'releasing', 'released']) {
  test(`batch ${state} displays progress and submits only a CSRF-protected action`, async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.route('http://127.0.0.1:4010/', route => {
      const props = { gmail_connected: true, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: false, gmail_checked: true, csrf_token: 'test-csrf', notice: null, batch: { state, total: 3, held: 1, released: 1, pending: 1, errors: 1, repeat_revision: 4 } };
      const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
      return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
    });
    await page.setViewportSize({ width: 390, height: 1000 });
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Three-message batch test' })).toBeVisible();
    await expect(page.getByText('3 saved messages;', { exact: false })).toContainText('1 pending, 1 errors');
    await expect(page.getByRole('button', { name: 'Hold the three test messages' })).toHaveCount(state === 'not_started' ? 1 : 0);
    await expect(page.getByRole('button', { name: 'Release the batch to Inbox' })).toHaveCount(['holding', 'held', 'releasing'].includes(state) ? 1 : 0);
    const action = state === 'not_started' ? 'hold' : state === 'held' ? 'release' : state === 'released' ? 'repeat' : 'recover';
    if (state === 'released') await page.getByText('Repeat the batch recovery test', { exact: true }).click();
    await page.route(`**/gmail/batch/${action}`, route => route.fulfill({ contentType: 'text/html', body: 'Submitted' }));
    const waiting = page.waitForRequest(`**/gmail/batch/${action}`);
    await page.locator(`form[action="/gmail/batch/${action}"] button`).click();
    const request = await waiting;
    expect(request.method()).toBe('POST');
    expect(Object.fromEntries(new URLSearchParams(request.postData()!))).toEqual({ _csrf_token: 'test-csrf', ...(action === 'repeat' ? { repeat_revision: '4' } : {}) });
    expect(errors).toEqual([]);
  });
}
