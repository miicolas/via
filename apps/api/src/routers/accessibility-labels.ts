import type { AccessibilityStationFactCondition } from '@via/db/schema';

/** One user-facing label for each accessibility condition exposed by Via. */
export const ACCESSIBILITY_CONDITION_LABELS: Record<AccessibilityStationFactCondition, string> = {
  reservationRequired: 'Sur réservation',
  staffAssistance: 'Avec un agent',
  autonomous: 'En autonomie',
};
