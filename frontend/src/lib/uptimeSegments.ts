import { mixStatusColor } from './uptimeColors';
import type { HistoryPayload } from '../types';

export interface UptimeSegment {
  title: string;
  background: string;
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
    const start = new Date(slice[0][0] * 1000).toLocaleString('de-DE');
    const percent = Math.round(downRatio * 100);
    out.push({
      title:
        measured.length === 0
          ? `${start} · Keine Daten`
          : downRatio <= 0
            ? start
            : `${start} · ${percent}% Ausfall`,
      background:
        measured.length === 0
          ? noDataColor
          : mixStatusColor(downRatio, upColor, downColor),
    });
  }
  return out;
}
