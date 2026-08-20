import type { Journey, JourneyInput } from '@via/contract';
import { db } from '@via/db';
import { importMeta, stationAccessibility, transitStopAliases } from '@via/db/schema';
import { inArray } from 'drizzle-orm';

export type AccessibilityCondition = 'reservationRequired' | 'staffAssistance' | 'autonomous';

export type JourneyAccessibility = {
  condition: AccessibilityCondition;
  label: string;
};

const ACCESSIBILITY_LEVELS = new Map<number, JourneyAccessibility>([
  [3, { condition: 'reservationRequired', label: 'Réservation requise' }],
  [4, { condition: 'staffAssistance', label: 'Agent requis' }],
  [6, { condition: 'autonomous', label: 'Gares PMR vérifiées' }],
]);

const META_IMPORTED_AT = 'accessibility:imported-at';

export async function accessibilitySnapshotAvailable() {
  const rows = await db
    .select({ value: importMeta.value })
    .from(importMeta)
    .where(inArray(importMeta.key, [META_IMPORTED_AT]));
  return rows.length > 0;
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
    const withoutNavitiaPrefix = value.replace(/^(?:stop_point|stop_area):/, '');
    if (withoutNavitiaPrefix !== value && withoutNavitiaPrefix.startsWith('IDFM:')) {
      result.set(value, withoutNavitiaPrefix);
    }
  }
  return result;
}

export async function accessibilityForStationIDs(ids: Iterable<string>) {
  const values = [...new Set([...ids].filter(Boolean))];
  if (values.length === 0) return new Map<string, JourneyAccessibility>();
  const rows = await db
    .select({ stopId: stationAccessibility.stopId, levelId: stationAccessibility.levelId })
    .from(stationAccessibility)
    .where(inArray(stationAccessibility.stopId, values));
  return new Map(
    rows.flatMap((row) => {
      const accessibility = ACCESSIBILITY_LEVELS.get(row.levelId);
      return accessibility ? [[row.stopId, accessibility] as const] : [];
    })
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
