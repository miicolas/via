import type { Journey } from '@via/contract';

/**
 * Why the first option is on top. The planner ranks by arrival, which regularly puts a
 * longer trip above shorter ones — unexplained, that reads as a bug.
 *
 * Compared to the minute, because that is what the screen shows: three journeys all
 * landing at 22:08 must not let one of them claim it arrives first.
 */
export function recommendationReason(journeys: Journey[]) {
  const [recommended, ...alternatives] = journeys;
  if (!recommended || alternatives.length === 0) return undefined;

  const arrival = atMinute(recommended.arrivalAt);
  if (alternatives.every((other) => arrival < atMinute(other.arrivalAt))) {
    return 'Arrive en premier';
  }
  if (alternatives.every((other) => recommended.transferCount < other.transferCount)) {
    return 'Le moins de correspondances';
  }
  if (
    alternatives.every(
      (other) => recommended.walkingDurationSeconds < other.walkingDurationSeconds
    )
  ) {
    return 'Le moins de marche';
  }

  return undefined;
}

function atMinute(value: string) {
  return Math.floor(Date.parse(value) / 60_000);
}
