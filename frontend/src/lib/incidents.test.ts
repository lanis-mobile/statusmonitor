import { describe, expect, it } from 'vitest';
import { mapIncidents, type Incident } from './incidents';

const now = 1_788_264_754;

describe('mapIncidents empty and passthrough', () => {
  it('returns an empty list when there are no incidents', () => {
    expect(mapIncidents([], 'operational', now)).toEqual([]);
    expect(mapIncidents([], 'down', now)).toEqual([]);
    expect(mapIncidents([], 'misconfigured', now)).toEqual([]);
  });

  it('does not mutate the input array', () => {
    const input = [
      { start: 300, end: 360 },
      { start: 100, end: 160 },
    ];
    const copy = input.map((item) => ({ ...item }));
    mapIncidents(input, 'operational', now);
    expect(input).toEqual(copy);
  });

  it('preserves exact start and end timestamps', () => {
    const items = mapIncidents(
      [{ start: 1_788_182_760, end: 1_788_182_820 }],
      'operational',
      now,
    );
    expect(items[0].start).toBe(1_788_182_760);
    expect(items[0].end).toBe(1_788_182_820);
    expect(items[0].end - items[0].start).toBe(60);
  });
});

describe('mapIncidents newest first', () => {
  it('sorts by start time then reverses so the latest is first', () => {
    const items = mapIncidents(
      [
        { start: 100, end: 160 },
        { start: 300, end: 360 },
        { start: 200, end: 260 },
      ],
      'operational',
      now,
    );
    expect(items.map((i) => i.start)).toEqual([300, 200, 100]);
  });

  it('still newest-first when the API already sent chronological order', () => {
    const items = mapIncidents(
      [
        { start: 100, end: 160 },
        { start: 200, end: 260 },
      ],
      'operational',
      now,
    );
    expect(items.map((i) => i.start)).toEqual([200, 100]);
  });

  it('still newest-first when the API sent reverse order', () => {
    const items = mapIncidents(
      [
        { start: 200, end: 260 },
        { start: 100, end: 160 },
      ],
      'operational',
      now,
    );
    expect(items.map((i) => i.start)).toEqual([200, 100]);
  });
});

describe('mapIncidents does not merge or inflate durations', () => {
  it('keeps a 1-minute and 6-minute outage four minutes apart as two items', () => {
    const items = mapIncidents(
      [
        { start: 1_788_182_760, end: 1_788_182_820 },
        { start: 1_788_183_060, end: 1_788_183_420 },
      ],
      'operational',
      now,
    );
    expect(items).toHaveLength(2);
    expect(items[0].end - items[0].start).toBe(360);
    expect(items[1].end - items[1].start).toBe(60);
  });

  it('does not stretch a 1-minute outage to a 5-minute or 1-hour bucket', () => {
    const items = mapIncidents(
      [{ start: now - 10 * 86400, end: now - 10 * 86400 + 60 }],
      'operational',
      now,
    );
    expect(items[0].end - items[0].start).toBe(60);
  });

  it('keeps many 1-minute outages as separate 60-second spans', () => {
    const spans = [1000, 2000, 3000, 4000].map((start) => ({
      start,
      end: start + 60,
    }));
    const items = mapIncidents(spans, 'operational', now);
    expect(items).toHaveLength(4);
    expect(items.every((item) => item.end - item.start === 60)).toBe(true);
  });
});

describe('mapIncidents ongoing state', () => {
  it('marks nothing ongoing while status is operational', () => {
    const items = mapIncidents(
      [
        { start: 100, end: 160 },
        { start: 300, end: 360 },
      ],
      'operational',
      now,
    );
    expect(items.every((item) => item.ongoing === false)).toBe(true);
    expect(items[0].end).toBe(360);
  });

  it('marks nothing ongoing while status is misconfigured', () => {
    const items = mapIncidents(
      [{ start: 100, end: 160 }],
      'misconfigured',
      now,
    );
    expect(items[0].ongoing).toBe(false);
    expect(items[0].end).toBe(160);
  });

  it('extends only the latest span to now when status is down', () => {
    const items = mapIncidents(
      [
        { start: 100, end: 160 },
        { start: 300, end: 360 },
      ],
      'down',
      now,
    );
    expect(items[0]).toEqual<Incident>({
      start: 300,
      end: now,
      ongoing: true,
    });
    expect(items[1]).toEqual<Incident>({
      start: 100,
      end: 160,
      ongoing: false,
    });
  });

  it('extends a single unresolved span to now', () => {
    const items = mapIncidents([{ start: 100, end: 160 }], 'down', now);
    expect(items[0]).toEqual({ start: 100, end: now, ongoing: true });
  });
});
