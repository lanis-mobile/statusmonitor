import { clipRanges, mergeDownRanges, type TimeRange } from './downRanges';
import type { HistoryPayload, HistoryWindow } from '../types';

export interface ChartBands {
  holidays: TimeRange[];
  downs: TimeRange[];
  noData: TimeRange[];
}

export interface LatencyStats {
  avg: number | null;
  p95: number | null;
  failures: number;
  measured: number;
}

export function mergeNoDataRanges(
  points: HistoryPayload['points'],
  from: number,
  to: number,
  bucketSeconds: number,
): TimeRange[] {
  const bucket = Math.max(bucketSeconds, 1);
  const ranges: TimeRange[] = [];
  for (const [ts, , ok] of points) {
    if (ok != null) continue;
    const start = ts;
    const end = ts + bucket;
    const last = ranges[ranges.length - 1];
    if (last && start <= last.end + bucket) {
      last.end = Math.max(last.end, end);
    } else {
      ranges.push({ start, end, label: 'Keine Daten' });
    }
  }
  return clipRanges(ranges, from, to);
}

export function buildChartBands(
  history: HistoryPayload,
  holidays: Array<{ start: number; end: number; label: string }>,
): ChartBands {
  const { from, to, points, bucketSeconds } = history;
  return {
    holidays: clipRanges(
      holidays.map((h) => ({ start: h.start, end: h.end, label: h.label })),
      from,
      to,
    ),
    downs: mergeDownRanges(points, bucketSeconds),
    noData: mergeNoDataRanges(points, from, to, bucketSeconds),
  };
}

export function measuredPoints(points: HistoryPayload['points']) {
  return points.filter(([, , ok]) => ok != null);
}

export function successfulLatency(points: HistoryPayload['points']): number[] {
  return points
    .filter(([, ms, ok]) => ok === 1 && ms != null)
    .map(([, ms]) => Number(ms));
}

export function computeLatencyStats(points: HistoryPayload['points']): LatencyStats {
  const values = successfulLatency(points);
  const measured = measuredPoints(points).length;
  const failures = points.filter(([, , ok]) => ok === 0).length;
  if (values.length === 0) {
    return { avg: null, p95: null, failures, measured };
  }
  const sorted = [...values].sort((a, b) => a - b);
  const avg = Math.round(values.reduce((sum, v) => sum + v, 0) / values.length);
  const p95 = sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * 0.95))];
  return { avg, p95, failures, measured };
}

export function axisBounds(
  history: HistoryPayload,
): { min: number; max: number; clamped: boolean } {
  const { from, to, points, bucketSeconds } = history;
  const measured = measuredPoints(points);
  const fullMin = from * 1000;
  const fullMax = to * 1000;
  if (measured.length === 0) {
    return { min: fullMin, max: fullMax, clamped: false };
  }
  const dataMin = measured[0][0] * 1000;
  const dataMax = (measured[measured.length - 1][0] + bucketSeconds) * 1000;
  const span = fullMax - fullMin;
  const coverage = span <= 0 ? 1 : (dataMax - dataMin) / span;
  if (coverage >= 0.85) {
    return { min: fullMin, max: fullMax, clamped: false };
  }
  const pad = Math.max(bucketSeconds * 1000 * 2, span * 0.03);
  return {
    min: Math.max(fullMin, dataMin - pad),
    max: Math.min(fullMax, dataMax + pad),
    clamped: true,
  };
}

export function formatAxisTime(value: number, window: HistoryWindow): string {
  const date = new Date(value);
  if (window === '24h') {
    return date.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
  }
  if (window === '7d' || window === '30d') {
    return date.toLocaleDateString('de-DE', { weekday: 'short', day: 'numeric' });
  }
  return date.toLocaleDateString('de-DE', { month: 'short', year: '2-digit' });
}

export function formatTooltipTime(ts: number): string {
  return new Date(ts).toLocaleString('de-DE', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

export function overlayAt(
  ts: number,
  bands: ChartBands,
  bucketSeconds: number,
): string[] {
  const end = ts + bucketSeconds * 1000;
  const labels: string[] = [];
  for (const band of bands.noData) {
    if (band.end * 1000 > ts && band.start * 1000 < end) {
      labels.push('Keine Daten');
    }
  }
  for (const band of bands.holidays) {
    if (band.end * 1000 > ts && band.start * 1000 < end) {
      labels.push(band.label ?? 'Schulferien');
    }
  }
  for (const band of bands.downs) {
    if (band.end * 1000 > ts && band.start * 1000 < end) {
      labels.push('Nicht erreichbar');
    }
  }
  return [...new Set(labels)];
}

export function windowForIncident(start: number, now: number): HistoryWindow {
  const age = now - start;
  if (age <= 24 * 3600) return '24h';
  if (age <= 7 * 86400) return '7d';
  return '30d';
}

export function chartAriaLabel(
  history: HistoryPayload,
  stats: LatencyStats,
  labels: Record<HistoryWindow, string>,
): string {
  const windowLabel = labels[history.window];
  if (stats.measured === 0) {
    return `Antwortzeit ${windowLabel}: noch keine Messdaten.`;
  }
  const avg = stats.avg != null ? `${stats.avg} Millisekunden im Durchschnitt` : 'kein Durchschnitt';
  const failures =
    stats.failures === 0
      ? 'keine Ausfälle'
      : stats.failures === 1
        ? '1 Ausfall'
        : `${stats.failures} Ausfälle`;
  return `Antwortzeit ${windowLabel}: ${avg}, ${failures}.`;
}

export function useLongRangeTools(window: HistoryWindow): boolean {
  return window === '90d' || window === '180d' || window === '1y' || window === '2y';
}

export function useSmoothLine(window: HistoryWindow): boolean {
  return window !== '24h' && window !== '7d';
}

export function useSampling(window: HistoryWindow): boolean {
  return window === '1y' || window === '2y';
}
