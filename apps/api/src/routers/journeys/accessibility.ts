import type { Journey } from '@via/contract';
import { db } from '@via/db';
import {
  stationFacts,
  transitStopAliases,
  type AccessibilityStationFactCondition,
} from '@via/db/schema';
import { and, eq, inArray, sql } from 'drizzle-orm';

import { ACCESSIBILITY_CONDITION_LABELS } from '../accessibility-labels';

export type JourneyAccessibility = {
  condition: AccessibilityStationFactCondition;
  label: string;
};

const MODES_WITH_STATION_ACCESSIBILITY_FACTS = new Set([
  'metro',
  'rer',
  'transilien',
]);

/** Returns the canonical Via station IDs for raw GTFS/Navitia stop IDs. */
export async function canonicalStationIDs(ids: Iterable<string>) {
  const values = [...new Set([...ids].filter(Boolean))];
  if (values.length === 0) return new Map<string, string>();

  const aliases = await db
    .select({ sourceId: transitStopAliases.sourceId, stopId: transitStopAliases.stopId })
    .from(transitStopAliases)
    .where(inArray(transitStopAliases.sourceId, values));
  const result = new Map(aliases.map((row) => [row.sourceId, row.stopId]));
  for (const value of values) {
    if (value.startsWith('IDFM:')) result.set(value, value);
  }
  return result;
}

export async function accessibilityForStationIDs(ids: Iterable<string>) {
  const values = [...new Set([...ids].filter(Boolean))];
  if (values.length === 0) return new Map<string, JourneyAccessibility>();
  const rows = await db
    .select({
      stopId: stationFacts.stopId,
      condition: sql<AccessibilityStationFactCondition>`${stationFacts.condition}`,
    })
    .from(stationFacts)
    .where(
      and(eq(stationFacts.kind, 'accessibility'), inArray(stationFacts.stopId, values))
    );
  return new Map(
    rows.map((row) => [
      row.stopId,
      { condition: row.condition, label: ACCESSIBILITY_CONDITION_LABELS[row.condition] },
    ])
  );
}

/** Only boarding/alighting stops matter; intermediate calls are not user-used stations. */
export function usedStationIDs(journey: Journey) {
  const ids: string[] = [];
  for (const section of journey.sections) {
    if (
      section.type !== 'transit' ||
      !section.route ||
      !MODES_WITH_STATION_ACCESSIBILITY_FACTS.has(section.route.mode) ||
      section.stops.length === 0
    ) continue;
    ids.push(section.stops[0]!.id, section.stops.at(-1)!.id);
  }
  return ids;
}

/** IDFM already applies `wheelchair=true`; local facts only enrich its answer. */
export async function annotateAccessibleJourneys(journeys: Journey[]) {
  return accessibleJourneys(journeys, false);
}

export async function filterAndAnnotateAccessibleJourneys(journeys: Journey[]) {
  return accessibleJourneys(journeys, true);
}

async function accessibleJourneys(journeys: Journey[], requiresLocalProof: boolean) {
  const rawIDs = journeys.flatMap(usedStationIDs);
  const canonical = await canonicalStationIDs(rawIDs);
  const accessibility = await accessibilityForStationIDs(canonical.values());
  return journeys.flatMap((journey) => {
    const used = usedStationIDs(journey);
    const levels = used.flatMap((id) => {
      const canonicalID = canonical.get(id);
      const value = canonicalID ? accessibility.get(canonicalID) : undefined;
      return value ? [value] : [];
    });
    if (levels.length !== used.length || levels.length === 0) {
      return requiresLocalProof && used.length > 0 ? [] : [journey];
    }
    const summary = levels.find((value) => value.condition === 'reservationRequired')
      ?? levels.find((value) => value.condition === 'staffAssistance')
      ?? levels[0]!;
    return [{ ...journey, accessibility: summary }];
  });
}
