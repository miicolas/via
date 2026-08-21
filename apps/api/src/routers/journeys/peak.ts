import type { Journey } from '@via/contract';

import { parisDay, parisDayType } from '../../time/paris';
import { stationPeaks, type StationPeak } from '../station-peak';
import { canonicalStationIDs } from './accessibility';

const RAIL_MODES = new Set(['metro', 'rer', 'transilien']);

type TransferCandidate = {
  rawID: string;
  stationName: string;
  arrivalAt: string;
};

type ProfileGroup = {
  dayType: ReturnType<typeof parisDayType>;
  hour: number;
  stationIDs: Set<string>;
};

/** Adds one habitual-profile annotation for the most loaded rail transfer. */
export async function annotatePeakJourneys(journeys: Journey[]): Promise<Journey[]> {
  const candidatesByJourney = journeys.map(transferCandidates);
  const candidates = candidatesByJourney.flat();
  if (candidates.length === 0) return journeys;

  try {
    const canonical = await canonicalStationIDs(candidates.map((candidate) => candidate.rawID));
    const groups = new Map<string, ProfileGroup>();
    const resolved = new Map<TransferCandidate, { stationID: string; key: string }>();
    for (const candidate of candidates) {
      const stationID = canonical.get(candidate.rawID);
      if (!stationID) continue;
      const arrival = new Date(candidate.arrivalAt);
      if (Number.isNaN(arrival.getTime())) continue;
      const dayType = parisDayType(arrival);
      const hour = Math.floor(parisDay(arrival).seconds / 3600);
      const key = `${dayType}:${hour}`;
      const group = groups.get(key) ?? { dayType, hour, stationIDs: new Set() };
      group.stationIDs.add(stationID);
      groups.set(key, group);
      resolved.set(candidate, { stationID, key });
    }

    const profiles = new Map<string, StationPeak>();
    await Promise.all(
      [...groups].map(async ([key, group]) => {
        const values = await stationPeaks(group.stationIDs, group.dayType, group.hour);
        for (const [stationID, value] of values) profiles.set(`${key}:${stationID}`, value);
      })
    );

    return journeys.map((journey, index) => {
      const best = (candidatesByJourney[index] ?? [])
        .flatMap((candidate) => {
          const resolution = resolved.get(candidate);
          if (!resolution) return [];
          const peak = profiles.get(`${resolution.key}:${resolution.stationID}`);
          if (!peak || peak.level === 'off') return undefined;
          return [{
            ...peak,
            level: peak.level as 'moderate' | 'peak',
            stationName: candidate.stationName,
          }];
        })
        .filter((value): value is StationPeak & { level: 'moderate' | 'peak'; stationName: string } => value !== undefined)
        .sort((a, b) => b.ratio - a.ratio)[0];
      return best ? { ...journey, peak: best } : journey;
    });
  } catch (cause) {
    // Profile data is an enrichment. A migration/import outage must not hide a
    // valid itinerary or turn a departure board into an API error.
    console.error('[journeys] station peak annotation unavailable', cause);
    return journeys;
  }
}

/** Rail section endpoints that are used as transfer stations in the journey. */
export function transferCandidates(journey: Journey): TransferCandidate[] {
  return journey.sections.flatMap((section, index) => {
    if (
      section.type !== 'transit' ||
      !section.route ||
      !RAIL_MODES.has(section.route.mode) ||
      !journey.sections.slice(index + 1).some((next) => next.type === 'transit')
    ) {
      return [];
    }
    const stop = section.stops.at(-1);
    return stop?.arrivalAt
      ? [{ rawID: stop.id, stationName: stop.name, arrivalAt: stop.arrivalAt }]
      : [];
  });
}
