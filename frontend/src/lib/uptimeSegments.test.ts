import { describe, expect, it } from 'vitest';
import {
  HOUR_CELL_COUNT,
  applyOptimisticLatest,
  buildHourCells,
  hourPointTooltip,
  padHourPoints,
  segmentTooltip,
} from './uptimeSegments';

const up = '#1f8b4c';
const down = '#c0392b';
const noData = '#d1d5db';

describe('padHourPoints', () => {
  it('pads on the left when there are fewer than 60 points', () => {
    const padded = padHourPoints([[100, 200, 1]], 60);
    expect(padded).toHaveLength(60);
    expect(padded.slice(0, 59).every((p) => p == null)).toBe(true);
    expect(padded[59]).toEqual([100, 200, 1]);
  });

  it('keeps the latest 60 points when there are more', () => {
    const points: Array<[number, number | null, number | null]> = Array.from(
      { length: 90 },
      (_, i) => [i, 10, 1],
    );
    const padded = padHourPoints(points, 60);
    expect(padded).toHaveLength(60);
    expect(padded[0]).toEqual([30, 10, 1]);
    expect(padded[59]).toEqual([89, 10, 1]);
  });
});

describe('hourPointTooltip', () => {
  it('includes check time, status, and latency for a successful check', () => {
    const tip = hourPointTooltip([1_788_182_760, 541, 1]);
    expect(tip.lines[1]).toBe('Erreichbar');
    expect(tip.lines[2]).toBe('541 ms');
    expect(tip.title).toContain('541 ms');
  });

  it('shows kein Wert when a failure has no latency', () => {
    const tip = hourPointTooltip([1_788_182_760, null, 0]);
    expect(tip.lines[1]).toBe('Login fehlgeschlagen');
    expect(tip.lines[2]).toBe('kein Wert');
  });

  it('shows Keine Daten for a missing sample', () => {
    expect(hourPointTooltip(null).lines).toEqual(['Keine Daten']);
    expect(hourPointTooltip([100, null, null]).lines[1]).toBe('Keine Daten');
  });
});

describe('applyOptimisticLatest', () => {
  it('copies the previous measured check onto a trailing empty cell', () => {
    const filled = applyOptimisticLatest([
      [1, 100, 1],
      [2, 541, 1],
      [3, null, null],
    ]);
    expect(filled[2]).toEqual([3, 541, 1]);
  });

  it('does not fill when the previous cell is also empty', () => {
    const points: Array<[number, number | null, number | null] | null> = [
      [1, 100, 1],
      [2, null, null],
      [3, null, null],
    ];
    expect(applyOptimisticLatest(points)).toEqual(points);
  });

  it('leaves a gap in the middle unchanged', () => {
    const points: Array<[number, number | null, number | null] | null> = [
      [1, 100, 1],
      [2, null, null],
      [3, 90, 1],
    ];
    expect(applyOptimisticLatest(points)).toEqual(points);
  });
});

describe('buildHourCells', () => {
  it('returns 60 cells with per-point colors', () => {
    const points: Array<[number, number | null, number | null]> = [
      [1, 100, 1],
      [2, null, null],
      [3, null, 0],
    ];
    const cells = buildHourCells(points, up, down, noData);
    expect(cells).toHaveLength(HOUR_CELL_COUNT);
    expect(cells[57].background).toBe(up);
    expect(cells[58].background).toBe(noData);
    expect(cells[59].background).toBe(down);
    expect(cells[0].background).toBe(noData);
    expect(cells[57].lines[2]).toBe('100 ms');
  });

  it('paints the newest empty cell from the previous check', () => {
    const cells = buildHourCells(
      [
        [1, 100, 1],
        [2, null, null],
      ],
      up,
      down,
      noData,
    );
    expect(cells[58].background).toBe(up);
    expect(cells[59].background).toBe(up);
    expect(cells[59].lines[2]).toBe('100 ms');
    expect(cells[59].lines[1]).toBe('Erreichbar');
  });
});

describe('segmentTooltip', () => {
  it('shows the time range, status, and average latency', () => {
    const tip = segmentTooltip([
      [1_788_182_760, 200, 1],
      [1_788_182_820, 400, 1],
    ]);
    expect(tip.lines[1]).toBe('Erreichbar');
    expect(tip.lines[2]).toBe('300 ms');
    expect(tip.lines[0]).toContain('–');
  });

  it('reports partial outages and missing latency', () => {
    const tip = segmentTooltip([
      [100, 200, 1],
      [160, null, 0],
    ]);
    expect(tip.lines[1]).toBe('50% Ausfall');
    expect(tip.lines[2]).toBe('200 ms');
  });
});
