import type { HistoryPayload } from '../types';

const HOUR_SECONDS = 3600;

export function historyLastHour(history: HistoryPayload): HistoryPayload {
  const from = history.to - HOUR_SECONDS;
  return {
    ...history,
    from,
    points: history.points.filter(([ts]) => ts >= from),
  };
}

export function uptimeFromPoints(points: HistoryPayload['points']): number | null {
  const measured = points.filter((p) => p[2] != null);
  if (measured.length === 0) return null;
  const failures = measured.filter((p) => p[2] === 0).length;
  return ((measured.length - failures) / measured.length) * 100;
}

export function formatUptimePercent(value: number | null): string {
  if (value == null) return '—';
  return `${value.toFixed(2)}%`;
}
