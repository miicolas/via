import type { DeparturesSource } from '@via/contract';

import type { WaitTimes } from '@/features/home-map/model/wait-times';

/**
 * The small print under the minutes. A theoretical time must never pass for
 * live, so that label outranks everything; live times spend the line on the
 * departures that follow instead.
 */
export function departureQualifier(source: DeparturesSource, wait?: WaitTimes): string {
  if (wait && source === 'theoretical') return 'horaires théoriques';
  if (wait?.followingLabel) return wait.followingLabel;
  if (wait) return 'temps réel';
  if (source === 'realtime') return 'aucun passage annoncé';
  return 'temps réel indisponible';
}
