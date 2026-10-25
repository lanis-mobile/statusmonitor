import { describe, expect, it } from 'vitest';
import { presentOfficialService, type OfficialService } from './officialPresentation';

const service: OfficialService = {
  id: 'PaedOrg', name: 'Organisation', status: 'restricted', maintenance: true,
  notice: '22.09.2026\niCloud-Zustellung gestört. Wir arbeiten daran.\nLetzte Einschränkung: 21.10.2026\nFrüherer Ausfall.',
  update: '28.10.2026 12:00 - 14:00 Uhr\nNutzung möglich.\n28.10.2026 15:00 - 18:00 Uhr\nNutzung möglich.\nLetzte Aktualisierung: 22.10.2026',
};

describe('official notice presentation', () => {
  it('separates history while retaining complete current notices and both maintenance windows', () => {
    const result = presentOfficialService(service);
    expect(result.date).toBe('22.09.2026');
    expect(result.message).toBe('iCloud-Zustellung gestört. Wir arbeiten daran.');
    expect(result.short).toBe('iCloud-Zustellung gestört.');
    expect(result.more).toBe(true);
    expect(result.maintenanceText).toContain('12:00 - 14:00');
    expect(result.maintenanceText).toContain('15:00 - 18:00');
    expect(result.maintenanceText).not.toContain('Letzte Aktualisierung');
    expect(result.history).toContain('Früherer Ausfall.');
    expect(result.history).toContain('Letzte Aktualisierung: 22.10.2026');
    expect(result.notice).toBe(service.notice);
    expect(result.update).toBe(service.update);
  });
  it('removes repetitive all-clear wording without losing the original', () => {
    const result = presentOfficialService({ ...service, status: 'operational', maintenance: false,
      notice: 'Aktuell keine bekannten Einschränkungen\nLetzte Einschränkung: gestern',
      update: 'Aktuell kein Update geplant\nLetzte Aktualisierung: gestern' });
    expect(result.message).toBe('');
    expect(result.maintenanceText).toBe('');
    expect(result.status).toBe('operational');
    expect(result.history).toContain('gestern');
  });
  it('never converts an empty restricted or unknown notice into an all-clear', () => {
    expect(presentOfficialService({ ...service, notice: '' }).status).toBe('restricted');
    expect(presentOfficialService({ ...service, status: 'unknown', notice: '' }).status).toBe('unknown');
  });
  it('keeps unrecognized text and encoded markup intact as text', () => {
    const text = '<img src=x onerror=alert(1)> No matching structure';
    const result = presentOfficialService({ ...service, notice: text, update: text });
    expect(result.message).toBe(text);
    expect(result.maintenanceText).toBe(text);
    expect(result.history).toBe('');
  });
});

describe('historic WordPress notice wording', () => {
  it('separates older update history without a colon from upcoming maintenance', () => {
    const result = presentOfficialService({ ...service,
      update: '03.04.23 ab 13:00 bis vsl. 20:00 Uhr\nNutzung nicht möglich.\nLetzte Aktualisierung 16.03.2023 ab 14:00 Uhr',
    });
    expect(result.maintenanceText).toContain('03.04.23');
    expect(result.maintenanceText).not.toContain('16.03.2023');
    expect(result.history).toContain('Letzte Aktualisierung 16.03.2023');
  });
  it.each(['aktuell kein Update geplant', 'Aktuell ist kein Update geplant', 'Aktuell sind keine Updates geplant'])(
    'does not present old updates as planned maintenance: %s', (wording) => {
      const result = presentOfficialService({ ...service, update: `${wording}\nLetzte Aktualisierung 20.12.2023 15:15 Uhr` });
      expect(result.maintenanceText).toBe('');
      expect(result.history).toContain('20.12.2023');
    },
  );
  it.each(['keine bekannten Einschränkungen', 'keine Einschränkung bekannt', 'aktuell keine Einschränkungen bekannt'])(
    'handles historic all-clear wording: %s', (wording) => {
      const result = presentOfficialService({ ...service, notice: `${wording}\nLetzte Einschränkung: 17.03.2023` });
      expect(result.message).toBe('');
      expect(result.history).toContain('17.03.2023');
    },
  );
});

it('keeps dates and vsl. inside the current January 2024 outage summary', () => {
  const current = 'Der Bereich “Pädagogische Organisation” steht vom 02.01. (morgens) bis vsl. 04.01 (mittags) vollständig aufgrund einer umfassenden Aktualisierung nicht zur Verfügung.';
  const result = presentOfficialService({ ...service, notice: `${current}\nDas Modul “SPH-Downloads” steht ebenfalls nicht zur Verfügung.\nLetzte Einschränkung: 19.12.2023` });
  expect(result.short).toBe(current);
  expect(result.more).toBe(true);
});
