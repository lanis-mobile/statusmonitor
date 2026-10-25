import { expect, test } from '@playwright/test';

test('official notices are primary and monitoring remains accessible', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByTestId('tab-official')).toHaveAttribute('aria-selected', 'true');
  await expect(page.getByTestId('official-service')).toHaveCount(6);
  await expect(page.getByTestId('official-status')).toContainText('iCloud-Adressen');
  await expect(page.getByTestId('official-status')).toContainText('28.10.2026 15:00');
  await expect(page.getByTestId('status-banner')).toBeVisible();
  await expect(page.getByRole('tablist')).toHaveCount(1);
  await expect(page.getByRole('tab').first()).toHaveText('Offizielle Meldungen');
  await expect(page.getByTestId('tab-monitor')).toHaveCount(0);
  await page.getByTestId('tab-incidents').click();
  await expect(page.getByTestId('incident-list')).toBeVisible();
  await page.getByTestId('tab-official').click();
  await expect(page.getByTestId('official-status')).toBeVisible();
});

test('hostile API strings remain text and never create executable DOM', async ({ page }) => {
  const attack = '<img src=x onerror="window.pwned=1"><svg onload="window.pwned=2"></svg><script>window.pwned=3</script>';
  await page.route('**/api/official', (route) => route.fulfill({ json: {
    sourceUrl: 'javascript:window.pwned=4', fetchedAt: 1784116800, stale: false,
    services: [{ id: attack, name: attack, status: 'restricted', maintenance: true, notice: attack, update: attack }],
  } }));
  await page.goto('/');
  const official = page.getByTestId('official-status');
  await expect(official.getByTestId('official-service')).toHaveCount(1);
  await expect(official).toContainText(attack);
  await expect(official.locator('img, svg, script, iframe, object, embed, style')).toHaveCount(0);
  await expect(official.locator('[onerror], [onload], [onclick]')).toHaveCount(0);
  await expect(official.locator('a')).toHaveAttribute('href', 'https://status.schulportal.hessen.de/');
  expect(await page.evaluate(() => (window as unknown as { pwned?: number }).pwned)).toBeUndefined();
});

test('failed official fetch does not block monitoring; retry recovers', async ({ page }) => {
  let fail = true;
  await page.route('**/api/official', (route) => fail ? route.fulfill({ status: 503 }) : route.continue());
  await page.goto('/');
  await expect(page.getByTestId('official-status')).toContainText('derzeit nicht verfügbar');
  await page.getByTestId('tab-incidents').click();
  await expect(page.getByTestId('incident-list')).toBeVisible();
  await page.getByTestId('tab-official').click();
  fail = false;
  await page.getByRole('button', { name: 'Erneut versuchen' }).click();
  await expect(page.getByTestId('official-service')).toHaveCount(6);
});

test('official data stays available when login measurements fail', async ({ page }) => {
  await page.route('**/api/summary', (route) => route.fulfill({ status: 503 }));
  await page.goto('/');
  await expect(page.getByTestId('official-service')).toHaveCount(6);
});

test('periodic refresh retains old data and displays stale warning', async ({ page }) => {
  await page.clock.install();
  let calls = 0;
  await page.route('**/api/official', async (route) => {
    calls++;
    if (calls > 1) await route.fulfill({ status: 503 });
    else await route.continue();
  });
  await page.goto('/');
  await expect(page.getByTestId('official-service')).toHaveCount(6);
  await page.clock.fastForward(60_000);
  await expect(page.getByTestId('official-status')).toContainText('Letzter gespeicherter Stand');
  await expect(page.getByTestId('official-service')).toHaveCount(6);
  expect(calls).toBe(2);
});

test('short list keeps current notices visible and history expandable without a design selector', async ({ page }) => {
  await page.goto('/');
  const content = page.getByTestId('official-status');
  await expect(content.getByRole('group', { name: 'Darstellung testen' })).toHaveCount(0);
  await expect(page.getByTestId('official-service')).toHaveCount(6);
  const first = page.getByTestId('official-service').first();
  await expect(first).toContainText('PaedOrg');
  await expect(first.getByText('Die E-Mailzustellung aus dem Schulportal an iCloud-Adressen ist aktuell gestört.', { exact: true })).toBeVisible();
  await expect(first.getByText(/28.10.2026 12:00/).first()).toBeVisible();
  await expect(first.getByText(/28.10.2026 15:00/).first()).toBeVisible();
  const archive = first.locator('details');
  await expect(archive.getByText(/Letzte Einschränkung:/).first()).not.toBeVisible();
  await archive.locator('summary').click();
  await expect(archive.getByText(/Letzte Einschränkung:/).first()).toBeVisible();
  await page.setViewportSize({ width: 375, height: 812 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
});
