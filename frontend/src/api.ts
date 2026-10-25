import type {
  OfficialPayload,
  HistoryPayload,
  HistoryWindow,
  HolidaysPayload,
  IncidentsPayload,
  StatusPayload,
  SummaryPayload,
} from './types';

async function getJson<T>(path: string): Promise<T> {
  const response = await fetch(path, { signal: AbortSignal.timeout(15_000) });
  if (!response.ok) {
    throw new Error(`${path} failed: ${response.status}`);
  }
  return (await response.json()) as T;
}

export const api = {
  official: () => getJson<OfficialPayload>('/api/official'),
  status: () => getJson<StatusPayload>('/api/status'),
  summary: () => getJson<SummaryPayload>('/api/summary'),
  incidents: () => getJson<IncidentsPayload>('/api/incidents'),
  history: (window: HistoryWindow) =>
    getJson<HistoryPayload>(`/api/history/${window}`),
  holidays: () => getJson<HolidaysPayload>('/api/holidays'),
};
