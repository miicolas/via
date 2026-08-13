import { normalizeHex } from '@/lib/normalize-hex';

/** WCAG relative luminance, so a fill can be judged light or dark before it is drawn. */
export function relativeLuminance(value: string) {
  const hex = normalizeHex(value).slice(1);
  const channels = (hex.match(/.{2}/g) ?? ['00', '00', '00'])
    .map((channel) => Number.parseInt(channel, 16) / 255)
    .map((channel) => (channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4));

  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}
