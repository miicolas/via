import type { Journey, JourneyInput } from '@via/contract';
import { db } from '@via/db';
import {
  stationFacts,
  transitStopAliases,
  type StationFactCondition,
} from '@via/db/schema';
import { and, eq, inArray, sql } from 'drizzle-orm';

import { ACCESSIBILITY_CONDITION_LABELS } from '../accessibility-labels';

export type JourneyAccessibility = {
  condition: StationFactCondition;
  label: string;
};

export async function accessibilitySnapshotAvailable() {
  const [row] = await db.execute<{ available: boolean }>(sql`
    select exists(
      select 1 from ${stationFacts} where ${stationFacts.kind} = 'accessibility'
    ) as available
  `);
  return row?.available ?? false;
}

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
    .select({ stopId: stationFacts.stopId, condition: stationFacts.condition })
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

export async function explicitStationsAreAccessible(input: JourneyInput) {
  const requested = [
    input.originStationId,
    input.destination.kind === 'station' ? input.destination.id : undefined,
  ].filter((value): value is string => Boolean(value));
  if (requested.length === 0) return true;
  const canonical = await canonicalStationIDs(requested);
  const accessibility = await accessibilityForStationIDs(canonical.values());
  return requested.every((id) => {
    const canonicalID = canonical.get(id);
    return canonicalID !== undefined && accessibility.has(canonicalID);
  });
}

/** Only boarding/alighting stops matter; intermediate calls are not user-used stations. */
export function usedStationIDs(journey: Journey) {
  const ids: string[] = [];
  for (const section of journey.sections) {
    if (section.type !== 'transit' || section.stops.length === 0) continue;
    ids.push(section.stops[0]!.id, section.stops.at(-1)!.id);
  }
  return ids;
}

export async function filterAndAnnotateAccessibleJourneys(journeys: Journey[]) {
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
    if (levels.length !== used.length || levels.length === 0) return [];
    const summary = levels.find((value) => value.condition === 'reservationRequired')
      ?? levels.find((value) => value.condition === 'staffAssistance')
      ?? levels[0]!;
    return [{ ...journey, accessibility: summary }];
  });
}
