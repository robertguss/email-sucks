import { test, expect } from '@playwright/test';

for (const phase of [null, 'restoring', 'revoking']) {
  for (const width of [390, 1440]) {
    test(`safe disconnect ${phase ?? 'review'} at ${width}px`, async ({ page }) => {
      const errors: string[] = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.route('http://127.0.0.1:4010/', route => {
        const props = { gmail_connected: phase === null, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: false, gmail_checked: true, gmail_disconnect_phase: phase, csrf_token: 'fixture-csrf', notice: null, controlled: { state: 'released', verified_at: 1788566400 } };
        const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
        return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
      });
      await page.setViewportSize({ width, height: 1100 });
      await page.goto('/');
      if (phase === null) {
        await expect(page.getByRole('button', { name: 'Restore test mail and revoke access' })).not.toBeVisible();
        await page.getByText('Disconnect Gmail safely', { exact: true }).click();
      } else {
        await expect(page.getByRole('heading', { name: 'Finish disconnecting' })).toBeVisible();
        await expect(page.getByRole('button', { name: 'Load recent messages' })).toHaveCount(0);
        await expect(page.getByRole('heading', { name: 'No Gmail account connected' })).toHaveCount(0);
      }
      await expect(page.getByText('Google revocation removes all permissions', { exact: false })).toBeVisible();
      await expect(page.getByRole('button', { name: 'Reconnect for recovery' })).toHaveCount(phase === 'restoring' ? 1 : 0);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
      await page.screenshot({ path: `../.local/disconnect-${phase ?? 'review'}-${width}.png`, fullPage: true });
      await page.route('**/gmail/disconnect', route => route.fulfill({ contentType: 'text/html', body: 'Submitted' }));
      const request = page.waitForRequest('**/gmail/disconnect');
      await page.getByRole('button', { name: phase ? 'Resume safe disconnect' : 'Restore test mail and revoke access' }).click();
      const submitted = await request;
      expect(submitted.method()).toBe('POST');
      expect(Object.fromEntries(new URLSearchParams(submitted.postData()!))).toEqual({ _csrf_token: 'fixture-csrf', confirm: 'disconnect' });
      expect(errors).toEqual([]);
    });
  }
}
