import { test, expect } from '@playwright/test';

for (const state of ['not_started', 'hold_pending', 'held', 'release_pending', 'released']) {
  test(`controlled actions reflect saved ${state} state and submit CSRF`, async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.route('http://127.0.0.1:4010/', route => {
      const props = { gmail_connected: true, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: false, gmail_checked: true, csrf_token: 'fixture-csrf', notice: null, controlled: { state, verified_at: state === 'held' || state === 'released' ? 1788566400 : null } };
      const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
      return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
    });
    await page.setViewportSize({ width: 390, height: 1000 });
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Controlled hold and release' })).toBeVisible();
    await expect(page.getByText(`Saved state: ${state}`, { exact: false })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Hold test message' })).toHaveCount(state === 'not_started' ? 1 : 0);
    await expect(page.getByRole('button', { name: 'Release to Inbox' })).toHaveCount(['hold_pending', 'held', 'release_pending'].includes(state) ? 1 : 0);
    await expect(page.getByRole('button', { name: 'Recover / verify' })).toHaveCount(state === 'not_started' ? 0 : 1);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await page.screenshot({ path: `../.local/controlled-${state}.png`, fullPage: true });
    const action = state === 'not_started' ? 'hold' : state === 'held' ? 'release' : 'recover';
    await page.route(`**/gmail/controlled/${action}`, route => route.fulfill({ contentType: 'text/html', body: 'Submitted' }));
    const request = page.waitForRequest(`**/gmail/controlled/${action}`);
    await page.locator(`form[action="/gmail/controlled/${action}"] button`).click();
    const submitted = await request;
    expect(submitted.method()).toBe('POST');
    expect(new URLSearchParams(submitted.postData()!).get('_csrf_token')).toBe('fixture-csrf');
    expect(errors).toEqual([]);
  });
}
