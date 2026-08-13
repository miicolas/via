import { formatTime } from '@/lib/format-time';

type TransitStepMetaInput = {
  departureAt?: string;
  minutes: number;
  platform?: string;
  stopCount?: number;
};

/**
 * "20:42 · voie 2 · 15 min · 6 arrêts" — every part the feed didn't provide is
 * omitted, so a theoretical GTFS leg still reads cleanly without a platform.
 */
export function transitStepMeta({
  departureAt,
  minutes,
  platform,
  stopCount,
}: TransitStepMetaInput): string {
  return [
    departureAt ? formatTime(departureAt) : undefined,
    platform ? `voie ${platform}` : undefined,
    `${minutes} min`,
    stopCount ? `${stopCount} ${stopCount > 1 ? 'arrêts' : 'arrêt'}` : undefined,
  ]
    .filter(Boolean)
    .join(' · ');
}
