import type { HistoryWindow, SummaryPayload } from '../types';

export const windows: HistoryWindow[] = [
  '24h',
  '7d',
  '30d',
  '90d',
  '180d',
  '1y',
  '2y',
];

export const windowLabels: Record<HistoryWindow, string> = {
  '24h': '24 Stunden',
  '7d': '7 Tage',
  '30d': '30 Tage',
  '90d': '90 Tage',
  '180d': '180 Tage',
  '1y': '1 Jahr',
  '2y': '2 Jahre',
};

export function windowsWithAdditionalData(
  ids: HistoryWindow[],
  summary: SummaryPayload,
): HistoryWindow[] {
  if (ids.length === 0) return [];
  const visible: HistoryWindow[] = [ids[0]];
  for (let i = 1; i < ids.length; i++) {
    const previous = summary.windows[ids[i - 1]].checks;
    const current = summary.windows[ids[i]].checks;
    if (current > previous) visible.push(ids[i]);
    else break;
  }
  return visible;
}
