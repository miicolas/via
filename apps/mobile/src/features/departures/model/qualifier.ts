import type { DeparturesSource } from '@via/contract';

import type { WaitTimes } from '@/features/departures/model/wait-times';

/** The small print under the minutes, without presenting scheduled times as live. */
export function departureQualifier(source: DeparturesSource, wait?: WaitTimes): string {
  if (wait?.followingLabel) return wait.followingLabel;
  if (wait) return source === 'realtime' ? 'temps réel' : '';
  if (source === 'realtime') return 'aucun passage annoncé';
  return 'temps réel indisponible';
}
