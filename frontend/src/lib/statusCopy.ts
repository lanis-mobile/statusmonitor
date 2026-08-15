import type { MonitorStatus } from '../types';

export const statusTitle: Record<MonitorStatus, string> = {
  operational: 'Erreichbar',
  down: 'Login fehlgeschlagen',
  misconfigured: 'Monitor falsch konfiguriert',
};

export const bannerTitle: Record<MonitorStatus, string> = {
  operational: 'Schulportal Erreichbar',
  down: 'Schulportal nicht erreichbar',
  misconfigured: 'Monitor falsch konfiguriert',
};

export function formatCheckedAt(ts: number | null): string {
  if (!ts) return 'kein Check';
  return new Date(ts * 1000).toLocaleString('de-DE', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

export function formatDuration(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  if (total < 60) return total === 1 ? '1 Sekunde' : `${total} Sekunden`;
  if (total < 3600) {
    const minutes = Math.max(1, Math.round(total / 60));
    return minutes === 1 ? '1 Minute' : `${minutes} Minuten`;
  }
  if (total < 86400) {
    const hours = Math.floor(total / 3600);
    const minutes = Math.round((total % 3600) / 60);
    if (minutes === 0) return hours === 1 ? '1 Stunde' : `${hours} Stunden`;
    return `${hours} Std. ${minutes} Min.`;
  }
  const days = Math.floor(total / 86400);
  const hours = Math.round((total % 86400) / 3600);
  if (hours === 0) return days === 1 ? '1 Tag' : `${days} Tage`;
  return `${days} T. ${hours} Std.`;
}
