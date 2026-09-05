import { test, expect, type Page } from '@playwright/test';

for (const state of ['not_started', 'preparing', 'active', 'disabling', 'disabled']) {
  test(`ordinary arrival ${state} keeps its actions separate from completed Trash test`, async ({ page }) => {
    await mockArrival(page, state);
    await page.setViewportSize({ width: 390, height: 1000 });
    await page.goto('/');
    const panel = page.locator('section[aria-labelledby="arrival-filters-heading"]');
    await expect(panel.getByRole('heading', { name: 'Ordinary arrival hold test' })).toBeVisible();
    await expect(page.locator('section[aria-labelledby="filters-heading"]')).toContainText('Cleanup is complete');
    await expect(panel).toContainText('one tracked temporary Gmail filter');
    await expect(panel).toContainText('phase0-filter-arrival-001');
    await expect(panel).not.toContainText('phase0-filter-trash-001');
    if (state === 'not_started') {
      await expect(panel.getByRole('button', { name: 'Activate ordinary arrival filter', includeHidden: true })).not.toBeVisible();
      await panel.getByText('Review and start the ordinary arrival test', { exact: true }).click();
      await expect(panel).toContainText('preserving its unread state');
      await expect(panel).toContainText('Trash, Spam, Drafts');
    }
    await expect(panel.getByRole('button', { name: 'Activate ordinary arrival filter' })).toHaveCount(state === 'not_started' ? 1 : 0);
    await expect(panel.getByRole('button', { name: 'Recover filter operation' })).toHaveCount(['preparing', 'disabling'].includes(state) ? 1 : 0);
    await expect(panel.getByRole('heading', { name: 'Active test marker' })).toHaveCount(state === 'active' ? 1 : 0);
    await expect(panel.getByRole('button', { name: 'Inspect filter test' })).toHaveCount(['active', 'disabled'].includes(state) ? 1 : 0);
    for (const width of [390, 1440]) {
      await page.setViewportSize({ width, height: 1000 });
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      if (state === 'active') await panel.screenshot({ path: test.info().outputPath(`arrival-${width}.png`) });
    }
    const action = state === 'not_started' ? 'activate' : state === 'active' ? 'disable' : state === 'disabled' ? 'inspect' : 'recover';
    await page.route(`**/gmail/arrival-filters/${action}`, route => route.fulfill({ contentType: 'text/html', body: 'Submitted' }));
    const waiting = page.waitForRequest(`**/gmail/arrival-filters/${action}`);
    await panel.locator(`form[action="/gmail/arrival-filters/${action}"] button`).click();
    const request = await waiting;
    expect(request.method()).toBe('POST');
    expect(Object.fromEntries(new URLSearchParams(request.postData()!))).toEqual({ _csrf_token: 'test-csrf' });
  });
}

test('ordinary recovery requests settings permission even with the Trash experiment disabled', async ({ page }) => {
  await mockArrival(page, 'preparing', true);
  await page.goto('/');
  const form = page.getByRole('button', { name: 'Reconnect for recovery', exact: true }).locator('..');
  await expect(form.locator('input[name="purpose"]')).toHaveValue('filters');
});

test('ordinary activation waits for completed Trash cleanup', async ({ page }) => {
  for (const primaryState of ['active', 'preparing', 'disabled']) {
    await page.unroute('http://127.0.0.1:4010/');
    await mockArrival(page, 'not_started', false, primaryState);
    await page.goto('/');
    const panel = page.locator('section[aria-labelledby="arrival-filters-heading"]');
    const activation = panel.locator('form[action="/gmail/arrival-filters/activate"]');
    if (primaryState === 'disabled') {
      await panel.getByText('Review and start the ordinary arrival test', { exact: true }).click();
      await expect(activation.getByRole('button', { name: 'Activate ordinary arrival filter' })).toBeVisible();
    } else {
      await expect(activation).toHaveCount(0);
      await expect(panel).toContainText('Complete cleanup of the Trash compatibility test');
    }
  }
});

async function mockArrival(page: Page, state: string, disconnect = false, primaryState = 'disabled') {
  await page.route('http://127.0.0.1:4010/', route => {
    const status = { state, error: null, marker: 'postman-probe-12345678901234567890123456789012', filters: 1, pending: 0, excluded: 0, restored: 0 };
    const props = { gmail_connected: !disconnect, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: false, gmail_checked: true, gmail_filter_settings: !disconnect, gmail_filter_recovery: !['not_started', 'disabled'].includes(state), gmail_disconnect_phase: disconnect ? 'restoring' : null, csrf_token: 'test-csrf', notice: null, filters: { ...status, state: primaryState, filters: primaryState === 'disabled' ? 0 : 2 }, arrival_filters: status };
    const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
    return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
  });
}
