import type { OfficialPayload } from '../types';

export type OfficialService = OfficialPayload['services'][number];

function splitHistory(text: string, marker: RegExp) {
  const index = marker.exec(text)?.index ?? -1;
  return index < 0
    ? { current: text.trim(), history: '' }
    : { current: text.slice(0, index).trim(), history: text.slice(index).trim() };
}

function firstSentence(text: string): string {
  for (const match of text.matchAll(/[.!?](?=\s|$)/g)) {
    const prefix = text.slice(0, match.index! + 1);
    // Dates and common German abbreviations are not sentence endings.
    if (match[0] === '.' && /(?:\d|\b(?:vsl|bzw|ca|ggf|usw|etc|Dr|Prof|z|B|d|h|u|a))\.$/i.test(prefix)) continue;
    return prefix;
  }
  return text;
}

export function presentOfficialService(service: OfficialService) {
  const notice = splitHistory(service.notice, /Letzte Einschränkung\s*:?/i);
  const update = splitHistory(service.update, /Letzte Aktualisierung\s*:?/i);
  const lines = notice.current.split('\n');
  const date = /^\d{1,2}\.\d{1,2}\.\d{4}$/.test(lines[0] ?? '') ? lines.shift()! : '';
  const current = lines.join('\n').trim();
  const noNotice = /^(?:Aktuell )?keine (?:bekannten )?Einschränkung(?:en)?(?: bekannt)?[.!]?$/i.test(current);
  const noMaintenance = /^(?:Aktuell )?(?:(?:ist )?kein Update|(?:sind )?keine Updates) geplant[.!]?$/i.test(update.current);
  const message = noNotice ? '' : current;
  // Shorten only at an actual sentence boundary. Full wording stays available.
  const short = firstSentence(message);
  const maintenance = noMaintenance ? '' : update.current;
  return {
    ...service, date, message, short,
    more: short !== message, maintenanceText: maintenance,
    history: [notice.history, update.history].filter(Boolean).join('\n\n'),
  };
}
