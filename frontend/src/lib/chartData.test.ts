import { describe, expect, it } from 'vitest';
import { windowForIncident } from './chartData';

describe('windowForIncident', () => {
  const now = 1_000_000;

  it('uses 24h for an outage that started in the last day', () => {
    expect(windowForIncident(now, now)).toBe('24h');
    expect(windowForIncident(now - 24 * 3600, now)).toBe('24h');
  });

  it('uses 7d once the start is older than 24 hours', () => {
    expect(windowForIncident(now - 24 * 3600 - 1, now)).toBe('7d');
    expect(windowForIncident(now - 7 * 86400, now)).toBe('7d');
  });

  it('uses 30d once the start is older than 7 days', () => {
    expect(windowForIncident(now - 7 * 86400 - 1, now)).toBe('30d');
    expect(windowForIncident(now - 14 * 86400, now)).toBe('30d');
    expect(windowForIncident(now - 29 * 86400, now)).toBe('30d');
  });
});
