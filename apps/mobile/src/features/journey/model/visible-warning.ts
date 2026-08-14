import type { Journey } from '@via/contract';

export function visibleJourneyWarning(journey: Journey): string | undefined {
  return journey.status === 'theoretical' ? undefined : journey.warnings[0];
}
