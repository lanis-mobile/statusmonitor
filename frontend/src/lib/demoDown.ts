import type { HistoryPayload, SummaryPayload } from '../types';

const ONGOING_SECONDS = 47 * 60;

export function isDownDemo(): boolean {
  return new URLSearchParams(window.location.search).get('demo') === 'down';
}

export function applyDownDemo(
  summary: SummaryPayload,
  histories: HistoryPayload[],
): { summary: SummaryPayload; histories: HistoryPayload[] } {
  const now = summary.current.checkedAt ?? histories[0]?.to ?? 0;
  const since = now - ONGOING_SECONDS;
  const nextHistories = histories.map((history) => failSince(history, since));
  const day = nextHistories.find((item) => item.window === '24h');
  const dayFailures = day
    ? day.points.filter((point) => Number(point[2]) === 0).length
    : summary.windows['24h'].failures;
  const dayChecks = day?.points.length ?? summary.windows['24h'].checks;
  const dayUptime =
    dayChecks === 0 ? 100 : ((dayChecks - dayFailures) / dayChecks) * 100;

  return {
    summary: {
      ...summary,
      current: {
        ...summary.current,
        online: false,
        status: 'down',
        responseMs: null,
        code: 1,
      },
      windows: {
        ...summary.windows,
        '24h': {
          ...summary.windows['24h'],
          failures: dayFailures,
          uptime: Number(dayUptime.toFixed(3)),
        },
      },
    },
    histories: nextHistories,
  };
}

function failSince(history: HistoryPayload, since: number): HistoryPayload {
  return {
    ...history,
    points: history.points.map(([ts, ms, ok]) =>
      ts >= since ? [ts, null, 0] : [ts, ms, ok],
    ),
  };
}
