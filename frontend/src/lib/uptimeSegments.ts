import { mixStatusColor } from './uptimeColors';
import { formatCheckedAt, statusTitle } from './statusCopy';
import type { HistoryPayload } from '../types';

export interface UptimeSegment {
  title: string;
  background: string;
  lines: string[];
}

export const HOUR_CELL_COUNT = 60;

type HistoryPoint = HistoryPayload['points'][number];

function isNoData(point: HistoryPoint | null): boolean {
  return point == null || point[2] == null;
}

/** If the newest cell is empty, reuse the previous measured check. */
export function applyOptimisticLatest(
  points: Array<HistoryPoint | null>,
): Array<HistoryPoint | null> {
  if (points.length < 2) return points;
  const last = points[points.length - 1];
  const prev = points[points.length - 2];
  if (!isNoData(last) || isNoData(prev) || prev == null) return points;
  const next = points.slice();
  next[next.length - 1] = last ? [last[0], prev[1], prev[2]] : prev;
  return next;
}

export function hourPointTooltip(point: HistoryPoint | null): {
  title: string;
  lines: string[];
} {
  if (!point) {
    return { title: 'Keine Daten', lines: ['Keine Daten'] };
  }
  const [ts, ms, ok] = point;
  const time = formatCheckedAt(ts);
  const status =
    ok == null ? 'Keine Daten' : ok === 0 ? statusTitle.down : statusTitle.operational;
  const latency = ms == null ? 'kein Wert' : `${ms} ms`;
  return {
    title: `${time} · ${status} · ${latency}`,
    lines: [time, status, latency],
  };
}

export function padHourPoints(
  points: HistoryPayload['points'],
  count = HOUR_CELL_COUNT,
): Array<HistoryPoint | null> {
  const latest = points.slice(-count);
  const missing = count - latest.length;
  return [...Array<HistoryPoint | null>(Math.max(0, missing)).fill(null), ...latest];
}

export function buildHourCells(
  points: HistoryPayload['points'],
  upColor: string,
  downColor: string,
  noDataColor: string,
  count = HOUR_CELL_COUNT,
): UptimeSegment[] {
  return applyOptimisticLatest(padHourPoints(points, count)).map((point) => {
    const tip = hourPointTooltip(point);
    const ok = point?.[2];
    return {
      ...tip,
      background:
        point == null || ok == null
          ? noDataColor
          : Number(ok) === 0
            ? downColor
            : upColor,
    };
  });
}

export function segmentTooltip(slice: HistoryPayload['points']): {
  title: string;
  lines: string[];
} {
  if (slice.length === 0) {
    return { title: 'Keine Daten', lines: ['Keine Daten'] };
  }
  const from = formatCheckedAt(slice[0][0]);
  const to = formatCheckedAt(slice[slice.length - 1][0]);
  const range = from === to ? from : `${from} – ${to}`;
  const measured = slice.filter((p) => p[2] != null);
  const failed = measured.filter((p) => Number(p[2]) === 0).length;
  const latencies = measured
    .map((p) => p[1])
    .filter((ms): ms is number => ms != null);
  const latency =
    latencies.length === 0
      ? 'kein Wert'
      : `${Math.round(latencies.reduce((a, b) => a + b, 0) / latencies.length)} ms`;

  let status = 'Keine Daten';
  if (measured.length > 0) {
    if (failed === 0) status = statusTitle.operational;
    else if (failed === measured.length) status = statusTitle.down;
    else status = `${Math.round((failed / measured.length) * 100)}% Ausfall`;
  }

  return {
    title: `${range} · ${status} · ${latency}`,
    lines: [range, status, latency],
  };
}

export function buildUptimeSegments(
  points: HistoryPayload['points'],
  segmentCount: number,
  upColor: string,
  downColor: string,
  noDataColor: string,
): UptimeSegment[] {
  if (points.length === 0 || segmentCount <= 0) return [];
  const size = Math.max(1, Math.ceil(points.length / segmentCount));
  const out: UptimeSegment[] = [];
  for (let i = 0; i < points.length; i += size) {
    const slice = points.slice(i, i + size);
    const measured = slice.filter((p) => p[2] != null);
    const failed = measured.filter((p) => Number(p[2]) === 0).length;
    const downRatio = measured.length === 0 ? 0 : failed / measured.length;
    const tip = segmentTooltip(slice);
    out.push({
      ...tip,
      background:
        measured.length === 0
          ? noDataColor
          : mixStatusColor(downRatio, upColor, downColor),
    });
  }
  return out;
}
