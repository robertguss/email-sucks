import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  use: { baseURL: 'http://127.0.0.1:4010' },
  webServer: {
    command: 'cd .. && PORT=4010 mix phx.server',
    url: 'http://127.0.0.1:4010/health/ready',
    reuseExistingServer: false,
    timeout: 30_000,
  },
});
