import { describe, expect, it } from 'vitest';
import { formatCheckedAt, formatDuration } from './statusCopy';

describe('formatDuration for incident lengths', () => {
  it('formats a 1-minute measured outage as 1 Minute', () => {
    expect(formatDuration(60)).toBe('1 Minute');
  });

  it('formats a 6-minute measured outage as 6 Minuten', () => {
    expect(formatDuration(360)).toBe('6 Minuten');
  });

  it('does not present a 1-minute outage as 5 Minuten or 1 Stunde', () => {
    expect(formatDuration(60)).not.toBe('5 Minuten');
    expect(formatDuration(60)).not.toBe('1 Stunde');
  });

  it('formats sub-minute leftovers in seconds', () => {
    expect(formatDuration(0)).toBe('0 Sekunden');
    expect(formatDuration(1)).toBe('1 Sekunde');
    expect(formatDuration(59)).toBe('59 Sekunden');
  });

  it('rounds 90 seconds to 2 Minuten', () => {
    expect(formatDuration(90)).toBe('2 Minuten');
  });

  it('clamps negative durations to 0 Sekunden', () => {
    expect(formatDuration(-12)).toBe('0 Sekunden');
  });

  it('formats whole hours without leftover minutes', () => {
    expect(formatDuration(3600)).toBe('1 Stunde');
    expect(formatDuration(7200)).toBe('2 Stunden');
  });

  it('formats hours with leftover minutes', () => {
    expect(formatDuration(3660)).toBe('1 Std. 1 Min.');
    expect(formatDuration(5430)).toBe('1 Std. 31 Min.');
  });

  it('formats whole days without leftover hours', () => {
    expect(formatDuration(86400)).toBe('1 Tag');
    expect(formatDuration(172800)).toBe('2 Tage');
  });

  it('formats days with leftover hours', () => {
    expect(formatDuration(86400 + 3600)).toBe('1 T. 1 Std.');
  });
});

describe('formatCheckedAt', () => {
  it('returns kein Check for missing timestamps', () => {
    expect(formatCheckedAt(null)).toBe('kein Check');
    expect(formatCheckedAt(0)).toBe('kein Check');
  });

  it('formats a unix timestamp with the German date style', () => {
    const label = formatCheckedAt(1_788_182_760);
    expect(label).toContain('2026');
    expect(label).toMatch(/\d{1,2}:\d{2}/);
    expect(label).not.toBe('kein Check');
  });
});
