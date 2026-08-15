export type MonitorStatus = 'operational' | 'down' | 'misconfigured';
export type HistoryWindow = '24h' | '7d' | '30d' | '90d' | '180d' | '1y' | '2y';

export interface StatusPayload {
  online: boolean;
  status: MonitorStatus;
  checkedAt: number | null;
  responseMs: number | null;
  code: number | null;
  inHolidays: boolean;
  holidayLabel: string | null;
}

export interface WindowStats {
  uptime: number;
  avgMs: number | null;
  checks: number;
  failures: number;
}

export interface SummaryPayload {
  current: StatusPayload;
  windows: Record<HistoryWindow, WindowStats>;
}

export interface HistoryPayload {
  window: HistoryWindow;
  bucketSeconds: number;
  from: number;
  to: number;
  points: Array<[number, number | null, number | null]>;
}

export interface HolidayPeriod {
  start: number;
  end: number;
  name: string;
  label: string;
}

export interface HolidaysPayload {
  state: string;
  updatedAt: number | null;
  periods: HolidayPeriod[];
}
