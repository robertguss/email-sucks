import { test, expect, type Page } from '@playwright/test';
import type { TrialSummary } from '../js/components/TrialControls';
const idle: TrialSummary = { state: 'not_started', next_due: null, error: null, instructions: null, latest_run_id: null, running: false };
const instructions = { sender: 'sender@example.test', recipient: 'owner@example.test', subject: 'phase0-delivery-trial-001', marker: 'postman-probe-fixture' };
const active: TrialSummary = { ...idle, state: 'active', next_due: '2099-09-05T18:30:00Z', instructions };
const empty = { revision: null, run_id: null, state: 'empty', items: [], total: 0, remaining: 0, pending: 0, unavailable: 0 };
async function shell(page: Page) {
  await page.route('http://127.0.0.1:4010/batch', route => {
    const payload = JSON.stringify({ component: 'BatchView', props: { csrf_token: 'test-csrf' }, url: '/batch', version: 'fixture', clearHistory: false, encryptHistory: true }).replaceAll('&', '&amp;').replaceAll("'", '&#39;');
    return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/assets/app.css"></head><body><div id="app" data-page='${payload}'></div><script type="module" src="/assets/app.js"></script></body></html>` });
  });
  await page.route('**/gmail/batch-view', route => route.fulfill({ json: empty }));
  await page.route('**/gmail/trial/view', route => route.fulfill({ json: empty }));
}
test('explicit start reveals exact instructions; stop ends the trial', async ({ page }) => {
  await shell(page);
  let summary = idle;
  await page.route('**/gmail/trial', route => route.fulfill({ json: summary }));
  await page.route('**/gmail/trial/start', route => { expect(route.request().headers()['x-csrf-token']).toBe('test-csrf'); summary = active; return route.fulfill({ json: summary }); });
  await page.route('**/gmail/trial/stop', route => { summary = { ...idle, state: 'stopped' }; return route.fulfill({ json: summary }); });
  await page.goto('/batch');
  await expect(page.getByText(instructions.marker)).toHaveCount(0);
  await page.getByRole('button', { name: 'Start delivery trial' }).click();
  await page.getByText('Send a test message', { exact: true }).click();
  for (const value of Object.values(instructions)) await expect(page.getByText(value, { exact: true })).toBeVisible();
  await expect(page.getByText(/Next delivery:/)).toBeVisible();
  await page.getByRole('button', { name: 'Stop & restore' }).click();
  await expect(page.getByRole('heading', { name: 'Trial stopped' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Start delivery trial' })).toHaveCount(0);
  await expect(page.getByText(instructions.marker)).toHaveCount(0);
});
test('Check Now uses a receipt and polls completion into exact trial review', async ({ page }) => {
  await shell(page);
  let summary = active;
  let reviewed = false;
  const content = { id: 'mail1', sender: 'A sender', subject: 'Delivered together', preview: 'A test note.', status: 'available', received_at: null };
  const view = () => ({ ...empty, state: 'ready', run_id: 'run1', revision: 1, total: 1, remaining: reviewed ? 0 : 1, items: [{ id: 'thread1', contents: [content], messages: 1, reviewed, status: 'available' }] });
  await page.route('**/gmail/trial', route => route.fulfill({ json: summary }));
  await page.route('**/gmail/trial/check-now', route => { expect(route.request().postDataJSON().request_id).toMatch(/^[\da-f-]{36}$/); summary = { ...active, running: true }; return route.fulfill({ json: summary }); });
  await page.route('**/gmail/trial/view', route => route.fulfill({ json: summary.latest_run_id ? view() : empty }));
  await page.route('**/gmail/trial/review', route => { expect(route.request().postDataJSON()).toEqual({ run_id: 'run1', revision: 1, item_id: 'thread1', reviewed: true }); reviewed = true; return route.fulfill({ json: view() }); });
  await page.goto('/batch');
  await page.getByRole('button', { name: 'Check Now', exact: true }).click();
  await expect(page.getByText('Checking and delivering saved test mail…')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Check Now', exact: true })).toBeEnabled();
  summary = { ...active, latest_run_id: 'run1' };
  await expect(page.getByRole('heading', { name: 'Delivered together' })).toBeVisible({ timeout: 10000 });
  await page.getByRole('button', { name: 'Mark reviewed', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'You’re caught up' })).toBeVisible();
  await expect(page.getByText(/Next delivery:/)).toBeVisible();
});
test('unknown status hides instructions and disables delivery actions', async ({ page }) => {
  await shell(page);
  let failed = false;
  await page.route('**/gmail/trial', route => route.fulfill(failed ? { status: 503, json: {} } : { json: active }));
  await page.goto('/batch');
  await expect(page.getByRole('button', { name: 'Check Now', exact: true })).toBeEnabled();
  failed = true;
  await page.getByRole('button', { name: 'Refresh status' }).click();
  await expect(page.getByRole('alert')).toContainText('couldn’t confirm');
  await expect(page.getByRole('button', { name: 'Check Now', exact: true })).toBeDisabled();
  await expect(page.getByText('Send a test message', { exact: true })).toHaveCount(0);
  await expect(page.getByRole('heading', { name: 'You’re caught up' })).toHaveCount(0);
});
for (const colorScheme of ['light', 'dark'] as const) {
  test(`trial layout is readable in ${colorScheme}`, async ({ page }) => {
    await shell(page);
    await page.emulateMedia({ colorScheme });
    await page.route('**/gmail/trial', route => route.fulfill({ json: active }));
    await page.goto('/batch');
    await page.getByText('Send a test message', { exact: true }).click();
    for (const width of [390, 1440]) {
      await page.setViewportSize({ width, height: 1000 });
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
      await page.screenshot({ path: test.info().outputPath(`trial-${colorScheme}-${width}.png`), fullPage: true });
    }
  });
}

test('accepted Check Now with lost response reuses its receipt after completion and reload', async ({ page }) => {
  await shell(page);
  await page.route('**/gmail/trial', route => route.fulfill({ json: active }));
  const receipts: string[] = [];
  await page.route('**/gmail/trial/check-now', route => {
    receipts.push(route.request().postDataJSON().request_id);
    return route.fulfill(receipts.length === 1 ? { status: 503, json: {} } : { json: active });
  });
  await page.goto('/batch');
  await page.getByRole('button', { name: 'Check Now', exact: true }).click();
  await expect(page.getByRole('alert')).toBeVisible();
  // The server accepted and finished the first request; status is active, not running.
  await page.reload();
  await page.getByRole('button', { name: 'Check Now', exact: true }).click();
  await expect(page.getByText('Check requested. Your next scheduled delivery stays in place.')).toBeVisible();
  expect(receipts).toHaveLength(2);
  expect(receipts[0]).toBe(receipts[1]);
});

test('failed overdue delivery shows attention and keeps stop available', async ({ page }) => {
  await shell(page);
  await page.route('**/gmail/trial', route => route.fulfill({ json: { ...active, next_due: '2020-01-01T00:00:00Z', error: 'provider_unavailable' } }));
  await page.goto('/batch');
  await expect(page.getByText('Delivery is overdue. Waiting for confirmation.')).toBeVisible();
  await expect(page.getByRole('alert')).toContainText('Delivery is not confirmed');
  await expect(page.getByRole('button', { name: 'Stop & restore' })).toBeEnabled();
  await expect(page.getByText('Send a test message', { exact: true })).toHaveCount(0);
});


test('missing cleanup permission persists across status refresh and exposes scoped reconnect', async ({ page }) => {
  await shell(page);
  await page.route('**/gmail/trial', route => route.fulfill({ json: { ...idle, state: 'stopping', error: 'filter_settings_required' } }));
  await page.goto('/batch');
  await page.getByRole('button', { name: 'Refresh status' }).click();
  await expect(page.getByRole('alert')).toContainText('Gmail filter access needs to be restored');
  const form = page.locator('form[action="/auth/google"]');
  await expect(form.locator('input[name="purpose"]')).toHaveValue('filters');
  await expect(form.locator('input[name="_csrf_token"]')).toHaveValue('test-csrf');
  await expect(page.getByRole('button', { name: 'Reconnect for filter cleanup' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Stop & restore' })).toBeEnabled();
});
