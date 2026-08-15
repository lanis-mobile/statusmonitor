import { mergeDownRanges, type TimeRange } from './downRanges';
import type { HistoryPayload, MonitorStatus } from '../types';

export interface Incident {
  start: number;
  end: number;
  ongoing: boolean;
}

export function buildIncidents(
  recent: HistoryPayload,
  longer: HistoryPayload,
  status: MonitorStatus,
  now: number,
): Incident[] {
  const recentRanges = mergeDownRanges(recent.points, recent.bucketSeconds);
  const olderRanges = mergeDownRanges(longer.points, longer.bucketSeconds);
  const slack = Math.max(recent.bucketSeconds, longer.bucketSeconds);

  const older = olderRanges.filter((range) => range.end < recent.from + slack);
  if (older.length > 0 && recentRanges.length > 0) {
    const lastOlder = older[older.length - 1];
    const firstRecent = recentRanges[0];
    if (lastOlder.end >= firstRecent.start - slack) {
      firstRecent.start = Math.min(lastOlder.start, firstRecent.start);
      older.pop();
    }
  }

  const ranges: TimeRange[] = [...older, ...recentRanges];
  const down = status === 'down';
  if (down) {
    const last = ranges[ranges.length - 1];
    if (last && now - last.end <= slack * 2) {
      last.end = now;
    } else {
      ranges.push({ start: now, end: now, label: 'Nicht erreichbar' });
    }
  }

  return ranges
    .map((range, index) => ({
      start: range.start,
      end: range.end,
      ongoing: down && index === ranges.length - 1,
    }))
    .reverse();
}
