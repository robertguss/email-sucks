import { test, expect, type Page } from '@playwright/test';
import type { HistoryStatus } from '../js/components/GmailHistory';

type HistoryState = HistoryStatus['state'];

for (const state of ['not_started', 'pending', 'ready'] as const satisfies readonly HistoryState[]) {
  test(`saved history ${state} shows truthful counts and fixed read-only forms`, async ({ page }) => {
    await mockHistory(page, state);
    await page.goto('/');
    const panel = page.getByRole('region', { name: 'Saved message history', exact: true });
    await expect(panel).toBeVisible();
    await expect(panel).toContainText('No messages are opened, marked as read, or moved');
    await expect(panel).toContainText('New arrivals are outside this test');
    await expect(panel.getByRole('button', { name: 'Rescan saved messages', exact: true })).toHaveCount(state === 'not_started' ? 0 : 1);
    if (state === 'ready') {
      await expect(panel).toContainText('3 available');
      await expect(panel).toContainText('1 unavailable');
      await expect(panel).toContainText('The latest check failed');
      await expect(panel).toContainText('last successful check');
      await expect(panel).not.toContainText('provider_unavailable');
    } else {
      await expect(panel).toContainText('No completed check yet');
    }
    for (const width of [390, 1440]) {
      await page.setViewportSize({ width, height: 1000 });
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      if (state === 'ready') await panel.screenshot({ path: test.info().outputPath(`history-${width}.png`) });
    }
    await page.route('**/gmail/history/sync', route => route.fulfill({ contentType: 'text/html', body: 'Submitted' }));
    const waiting = page.waitForRequest('**/gmail/history/sync');
    await panel.getByRole('button', { name: 'Check saved message history', exact: true }).click();
    const request = await waiting;
    expect(request.method()).toBe('POST');
    expect(Object.fromEntries(new URLSearchParams(request.postData()!))).toEqual({ _csrf_token: 'test-csrf' });
  });
}

test('history controls are hidden during disconnect', async ({ page }) => {
  await mockHistory(page, 'ready', true);
  await page.goto('/');
  await expect(page.getByRole('region', { name: 'Saved message history', exact: true })).toHaveCount(0);
});

async function mockHistory(page: Page, state: HistoryState, disconnect = false) {
  await page.route('http://127.0.0.1:4010/', route => {
    const props = { gmail_connected: !disconnect, gmail_configured: true, gmail_email: 'fixture@example.test', gmail_reconnect: false, gmail_checked: true, gmail_disconnect_phase: disconnect ? 'restoring' : null, csrf_token: 'test-csrf', notice: null, history: { state, members: state === 'not_started' ? 0 : 4, available: state === 'ready' ? 3 : 0, unavailable: state === 'ready' ? 1 : 0, revision: state === 'ready' ? 2 : 0, checked_at: state === 'ready' ? 1788614400 : null, mode: state === 'ready' ? 'expired_rescan' : null, error: state === 'ready' ? 'provider_unavailable' : null } };
    const payload = JSON.stringify({ component: 'PhaseZero', props, url: '/', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
    return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
  });
}
