import type { MonitorStatus } from '../types';

export interface Incident {
  start: number;
  end: number;
  ongoing: boolean;
}

export function mapIncidents(
  incidents: Array<{ start: number; end: number }>,
  status: MonitorStatus,
  now: number,
): Incident[] {
  if (incidents.length === 0) return [];

  const ordered = [...incidents].sort((a, b) => a.start - b.start);
  const lastIndex = ordered.length - 1;

  return ordered
    .map((incident, index) => {
      const ongoing = status === 'down' && index === lastIndex;
      return {
        start: incident.start,
        end: ongoing ? now : incident.end,
        ongoing,
      };
    })
    .reverse();
}
