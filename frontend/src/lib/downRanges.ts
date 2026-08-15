import type { HolidayPeriod } from '../types';

export interface TimeRange {
  start: number;
  end: number;
  label?: string;
}

export function mergeDownRanges(
  points: Array<[number, number | null, number | null]>,
  bucketSeconds: number,
): TimeRange[] {
  const bucket = Math.max(bucketSeconds, 1);
  const ranges: TimeRange[] = [];
  for (const [ts, , ok] of points) {
    if (ok == null || Number(ok) !== 0) continue;
    const start = ts;
    const end = ts + bucket;
    const last = ranges[ranges.length - 1];
    if (last && start <= last.end + bucket) {
      last.end = Math.max(last.end, end);
    } else {
      ranges.push({ start, end, label: 'Nicht erreichbar' });
    }
  }
  return ranges;
}

export function clipRanges(
  ranges: Array<Pick<HolidayPeriod, 'start' | 'end'> & { label?: string }>,
  from: number,
  to: number,
): TimeRange[] {
  return ranges
    .filter((r) => r.end >= from && r.start <= to)
    .map((r) => ({
      start: Math.max(r.start, from),
      end: Math.min(r.end, to),
      label: r.label,
    }));
}
