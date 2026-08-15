import type {
  HistoryPayload,
  HistoryWindow,
  HolidaysPayload,
  StatusPayload,
  SummaryPayload,
} from './types';

async function getJson<T>(path: string): Promise<T> {
  const response = await fetch(path);
  if (!response.ok) {
    throw new Error(`${path} failed: ${response.status}`);
  }
  return (await response.json()) as T;
}

export const api = {
  status: () => getJson<StatusPayload>('/api/status'),
  summary: () => getJson<SummaryPayload>('/api/summary'),
  history: (window: HistoryWindow) =>
    getJson<HistoryPayload>(`/api/history/${window}`),
  holidays: () => getJson<HolidaysPayload>('/api/holidays'),
};
