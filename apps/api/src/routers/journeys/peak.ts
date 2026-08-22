import type { Journey, JourneySection, JourneyStop } from '@via/contract';

import { parisDay, parisDayType } from '../../time/paris';
import { stationPeaks, type StationPeak } from '../station-peak';
import { canonicalStationIDs } from './accessibility';

const RAIL_MODES = new Set(['metro', 'rer', 'transilien']);

type CrowdingCandidate = {
  rawID: string;
  stationName: string;
  at: string;
};

type ProfileGroup = {
  dayType: ReturnType<typeof parisDayType>;
  hour: number;
  stationIDs: Set<string>;
};

/**
 * Adds one habitual-profile annotation for the busiest rail platform the
 * journey uses — boarding, alighting or transfer, whichever is most loaded at
 * the hour the traveller is there.
 */
export async function annotatePeakJourneys(journeys: Journey[]): Promise<Journey[]> {
  const candidatesByJourney = journeys.map(crowdingCandidates);
  const candidates = candidatesByJourney.flat();
  if (candidates.length === 0) return journeys;

  try {
    const canonical = await canonicalStationIDs(candidates.map((candidate) => candidate.rawID));
    const groups = new Map<string, ProfileGroup>();
    const resolved = new Map<CrowdingCandidate, { stationID: string; key: string }>();
    for (const candidate of candidates) {
      const stationID = canonical.get(candidate.rawID);
      if (!stationID) continue;
      const moment = new Date(candidate.at);
      if (Number.isNaN(moment.getTime())) continue;
      const dayType = parisDayType(moment);
      const hour = Math.floor(parisDay(moment).seconds / 3600);
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

/**
 * Every rail platform the journey actually puts someone on: the one they board
 * each train from, and the one they leave it at. A transfer is both at once,
 * which is why it used to be the only case considered — but a direct journey
 * has a platform to wait on too, and that wait is exactly what a busy hour is
 * felt as. The same endpoints accessibility already reasons about.
 */
export function crowdingCandidates(journey: Journey): CrowdingCandidate[] {
  return journey.sections.flatMap((section) => {
    if (
      section.type !== 'transit' ||
      !section.route ||
      !RAIL_MODES.has(section.route.mode)
    ) {
      return [];
    }
    const boarding = section.stops[0];
    const alighting = section.stops.at(-1);
    return [
      candidateAt(boarding, boarding?.departureAt, section.departureAt),
      // One stop is both ends of a section only when the feed gave a single
      // call; counting it twice would weight that station against the others.
      boarding && alighting && boarding !== alighting
        ? candidateAt(alighting, alighting.arrivalAt, section.arrivalAt)
        : undefined,
    ].filter((candidate): candidate is CrowdingCandidate => candidate !== undefined);
  });
}

/** A stop counts only once a usable local time can be put on it. */
function candidateAt(
  stop: JourneyStop | undefined,
  stopTime: string | undefined,
  sectionTime: JourneySection['departureAt']
): CrowdingCandidate | undefined {
  const at = stopTime ?? stop?.arrivalAt ?? stop?.departureAt ?? sectionTime;
  return stop && at ? { rawID: stop.id, stationName: stop.name, at } : undefined;
}
