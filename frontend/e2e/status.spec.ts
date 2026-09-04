import { expect, test } from '@playwright/test';

const ranges = ['24h', '7d', '30d', '90d', '180d', '1y', '2y'] as const;

async function expectChartRendered(page: import('@playwright/test').Page) {
  const chart = page.getByTestId('chart');
  await expect(chart).toBeVisible();
  const canvas = chart.locator('canvas');
  await expect
    .poll(async () => {
      if ((await canvas.count()) === 0) return 0;
      const box = await canvas.first().boundingBox();
      return box?.height ?? 0;
    })
    .toBeGreaterThan(160);

  const box = await chart.boundingBox();
  expect(box).not.toBeNull();
  expect(box!.height).toBeGreaterThan(180);
  expect(box!.width).toBeGreaterThan(200);

  await expect
    .poll(async () => canvas.first().evaluate((node) => (node as HTMLCanvasElement).width))
    .toBeGreaterThan(100);

  const ink = await canvas.first().evaluate((node) => {
    const c = node as HTMLCanvasElement;
    const ctx = c.getContext('2d');
    if (!ctx || c.width < 10 || c.height < 10) return 0;
    const { data } = ctx.getImageData(0, 0, c.width, c.height);
    let colored = 0;
    for (let i = 0; i < data.length; i += 16) {
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      const a = data[i + 3];
      if (a < 12) continue;
      const nearWhite = r > 240 && g > 240 && b > 240;
      const nearBlack = r < 18 && g < 18 && b < 18;
      if (!nearWhite && !nearBlack) colored += 1;
    }
    return colored;
  });
  expect(ink).toBeGreaterThan(40);
}

test('status page shows incidents by default and chart in second tab', async ({
  page,
}) => {
  await page.goto('/');

  await expect(page.getByTestId('status-banner')).toContainText(
    'Schulportal Erreichbar',
  );
  await expect(page.getByTestId('holiday-hint')).toContainText(/schulferien/i);
  await expect(page.getByTestId('uptime-bar-24h')).toBeVisible();
  await expect(page.getByTestId('uptime-bar-1h')).toBeVisible();
  await expect(page.getByTestId('uptime-bar-1h').getByTestId('uptime-cell')).toHaveCount(
    60,
  );
  await page.getByTestId('uptime-bar-1h').getByTestId('uptime-cell').last().hover();
  await expect(page.getByTestId('uptime-bar-1h').getByTestId('uptime-bar-tooltip')).toBeVisible();
  await expect(page.getByTestId('uptime-bar-1h').getByTestId('uptime-bar-tooltip')).toContainText(
    /ms|kein Wert|Keine Daten/,
  );
  await page.getByTestId('uptime-bar-24h').getByTestId('uptime-cell').last().hover();
  await expect(page.getByTestId('uptime-bar-24h').getByTestId('uptime-bar-tooltip')).toBeVisible();
  await expect(page.getByTestId('uptime-bar-24h').getByTestId('uptime-bar-tooltip')).toContainText(
    /ms|kein Wert|Keine Daten|Erreichbar/,
  );
  await expect(page.getByTestId('incident-list')).toContainText('30 Minuten');
  await expect(page.getByTestId('incident-list')).toContainText('3 Stunden');
  await expect(page.getByTestId('incident-list')).toContainText('Behoben');
  await expect(page.getByTestId('chart')).toHaveCount(0);
  await expect(page.getByTestId('uptime-stats')).toHaveCount(0);

  await page.getByTestId('tab-uptime').click();
  await expect(page.getByTestId('uptime-stats')).toBeVisible();
  await expect(page.getByTestId('uptime-stats')).toContainText('97.92%');
  await expect(page.getByTestId('uptime-stats')).toContainText('2 Jahre');

  await page.getByTestId('tab-latency').click();
  await expect(page.getByTestId('holiday-legend')).toContainText('Keine Daten');
  await expectChartRendered(page);

  for (const id of ranges) {
    await page.getByTestId(`range-${id}`).click();
    await expectChartRendered(page);
  }
});
