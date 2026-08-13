import { normalizeHex } from '@/lib/normalize-hex';

/** Line colors ship opaque; tinting glass with one means asking for a fraction of it. */
export function withAlpha(color: string, alpha: number) {
  const channel = Math.round(Math.min(1, Math.max(0, alpha)) * 255)
    .toString(16)
    .padStart(2, '0')
    .toUpperCase();

  return `${normalizeHex(color)}${channel}`;
}
