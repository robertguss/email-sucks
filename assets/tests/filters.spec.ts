import { test, expect } from '@playwright/test';

for (const state of ['not_started', 'preparing', 'active', 'disabling', 'disabled']) {
  test(`filter ${state} exposes bounded actions and protects submissions`, async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.route('http://127.0.0.1:4010/', route => {
      const props = { gmail_connected: true, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: false, gmail_checked: true, gmail_filter_settings: true, csrf_token: 'test-csrf', notice: null, filters: { state, error: state === 'preparing' ? 'provider_unavailable' : null, marker: 'postman-probe-12345678901234567890123456789012', filters: 2, pending: 1, excluded: 1, restored: 0 } };
      const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
      return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
    });
    await page.setViewportSize({ width: 390, height: 1000 });
    await page.goto('/');
    const panel = page.locator('section[aria-labelledby="filters-heading"]');
    await expect(panel.getByRole('heading', { name: 'Bounded filter compatibility test' })).toBeVisible();
    if (state === 'not_started') {
      await expect(panel.getByRole('button', { name: 'Activate temporary test filters', includeHidden: true })).not.toBeVisible();
      await panel.getByText('Review and start the filter test', { exact: true }).click();
    }
    await expect(panel.getByRole('button', { name: 'Activate temporary test filters' })).toHaveCount(state === 'not_started' ? 1 : 0);
    await expect(panel.getByRole('button', { name: 'Recover filter operation' })).toHaveCount(['preparing', 'disabling'].includes(state) ? 1 : 0);
    await expect(panel.getByRole('heading', { name: 'Active test marker' })).toHaveCount(state === 'active' ? 1 : 0);
    await expect(panel.getByRole('button', { name: 'Inspect filter test' })).toHaveCount(['active', 'disabled'].includes(state) ? 1 : 0);
    if (state === 'active') await expect(panel).toContainText('recovery leaves Trash untouched');
    const action = state === 'not_started' ? 'activate' : state === 'active' ? 'disable' : state === 'disabled' ? 'inspect' : 'recover';
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    if (state === 'active') {
      await panel.screenshot({ path: test.info().outputPath('filters-mobile.png') });
      await page.setViewportSize({ width: 1440, height: 1000 });
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      await panel.screenshot({ path: test.info().outputPath('filters-desktop.png') });
    }
    await page.route(`**/gmail/filters/${action}`, route => route.fulfill({ contentType: 'text/html', body: 'Submitted' }));
    const waiting = page.waitForRequest(`**/gmail/filters/${action}`);
    await panel.locator(`form[action="/gmail/filters/${action}"] button`).click();
    const request = await waiting;
    expect(request.method()).toBe('POST');
    expect(Object.fromEntries(new URLSearchParams(request.postData()!))).toEqual({ _csrf_token: 'test-csrf' });
    expect(errors).toEqual([]);
  });
}

test('filter settings consent is separate from ordinary Gmail connection', async ({ page }) => {
  await page.route('http://127.0.0.1:4010/', route => {
    const props = { gmail_connected: true, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: false, gmail_checked: true, gmail_filter_settings: false, csrf_token: 'test-csrf', notice: null };
    const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
    return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
  });
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'Activate temporary test filters' })).toHaveCount(0);
  const ordinary = page.getByRole('button', { name: 'Reconnect for Gmail modification access' }).locator('..');
  await expect(ordinary.locator('input[name="purpose"]')).toHaveCount(0);
  await page.route('**/auth/google', route => route.fulfill({ contentType: 'text/html', body: 'Submitted' }));
  const waiting = page.waitForRequest('**/auth/google');
  await page.getByRole('button', { name: 'Allow filter settings access' }).click();
  const request = await waiting;
  expect(request.method()).toBe('POST');
  expect(Object.fromEntries(new URLSearchParams(request.postData()!))).toEqual({ _csrf_token: 'test-csrf', purpose: 'filters' });
});

for (const state of ['not_started', 'active', 'preparing', 'disabling']) {
  test(`disconnect recovery requests filter permission only for ${state} experiment`, async ({ page }) => {
    await page.route('http://127.0.0.1:4010/', route => {
      const props = { gmail_connected: true, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: true, gmail_checked: false, gmail_filter_settings: false, gmail_disconnect_phase: 'restoring', csrf_token: 'test-csrf', notice: null, filters: { state, error: null, marker: null, filters: 0, pending: 0, excluded: 0, restored: 0 } };
      const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
      return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
    });
    await page.goto('/');
    await page.route('**/auth/google', route => route.fulfill({ contentType: 'text/html', body: 'Submitted' }));
    const waiting = page.waitForRequest('**/auth/google');
    await page.getByRole('button', { name: 'Reconnect for recovery', exact: true }).click();
    const request = await waiting;
    expect(request.method()).toBe('POST');
    expect(Object.fromEntries(new URLSearchParams(request.postData()!))).toEqual(state === 'not_started' ? { _csrf_token: 'test-csrf' } : { _csrf_token: 'test-csrf', purpose: 'filters' });
  });
}
