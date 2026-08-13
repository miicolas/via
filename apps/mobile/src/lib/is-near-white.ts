import { relativeLuminance } from '@/lib/relative-luminance';

const NEAR_WHITE_LUMINANCE = 0.82;

/** A bus badge is white on a white sheet: it needs an outline to exist at all. */
export function isNearWhite(color: string) {
  return relativeLuminance(color) >= NEAR_WHITE_LUMINANCE;
}
