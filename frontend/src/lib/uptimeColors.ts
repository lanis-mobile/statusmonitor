function wrapHue(h: number): number {
  return ((h % 360) + 360) % 360;
}

function hueDistance(a: number, b: number): number {
  return Math.min(wrapHue(a - b), wrapHue(b - a));
}

function hexToHsl(hex: string): [number, number, number] {
  const n = hex.replace('#', '');
  const r = parseInt(n.slice(0, 2), 16) / 255;
  const g = parseInt(n.slice(2, 4), 16) / 255;
  const b = parseInt(n.slice(4, 6), 16) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  if (max === min) return [0, 0, l];
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h = 0;
  if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
  else if (max === g) h = (b - r) / d + 2;
  else h = (r - g) / d + 4;
  return [h * 60, s, l];
}

function hslToHex(h: number, s: number, l: number): string {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  let r = 0;
  let g = 0;
  let b = 0;
  if (h < 60) [r, g, b] = [c, x, 0];
  else if (h < 120) [r, g, b] = [x, c, 0];
  else if (h < 180) [r, g, b] = [0, c, x];
  else if (h < 240) [r, g, b] = [0, x, c];
  else if (h < 300) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  const toHex = (v: number) =>
    Math.round((v + m) * 255)
      .toString(16)
      .padStart(2, '0');
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

function mixViaYellow(up: string, down: string, t: number): string {
  const [h1, s1, l1] = hexToHsl(up);
  const [h2, s2, l2] = hexToHsl(down);
  const short = wrapHue(h2 - h1);
  const long = short > 0 ? short - 360 : short + 360;
  const shortMid = wrapHue(h1 + short / 2);
  const longMid = wrapHue(h1 + long / 2);
  const delta = hueDistance(shortMid, 60) <= hueDistance(longMid, 60) ? short : long;
  const h = wrapHue(h1 + delta * t);
  const s = s1 + (s2 - s1) * t;
  const l = l1 + (l2 - l1) * t;
  return hslToHex(h, s, l);
}

export function mixStatusColor(downRatio: number, up: string, down: string): string {
  if (downRatio <= 0) return up;
  if (downRatio >= 1) return down;
  const t = Math.max(0.45, downRatio ** 0.45);
  return mixViaYellow(up, down, t);
}

export const loginUptimeColors = {
  up: '#1f8b4c',
  down: '#c0392b',
  noData: '#d1d5db',
} as const;
