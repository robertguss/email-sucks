import { test, expect } from '@playwright/test';

test('Phase 0 loads and navigates through Inertia without browser errors', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' || message.type() === 'warning') errors.push(message.text());
  });
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Prove the postman.' })).toBeVisible();
  await expect(page.getByText('No Gmail account connected')).toBeVisible();
  const response = page.waitForResponse(response => response.url().endsWith('/phase-0/contract'));
  await page.getByRole('link', { name: 'Read the delivery contract' }).click();
  expect((await response).request().headers()['x-inertia']).toBe('true');
  await expect(page.getByRole('heading', { name: 'The delivery contract' })).toBeVisible();
  await page.goBack();
  await expect(page.getByRole('heading', { name: 'Prove the postman.' })).toBeVisible();
  expect(errors).toEqual([]);
});
