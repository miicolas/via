import { crowdingSeverity, type Journey, type JourneyInput, type JourneysResponse } from '@via/contract';

import { createDatabaseReportRepository } from '../../reports/repository';
import type { ReportRepository } from '../../reports/service';
import { StationStatusResolver, type CurrentReportVote } from '../../reports/status-resolver';
import { canonicalStationIDs } from './accessibility';
import { finalizePlan, type JourneyReportOverlay } from './service';

const RAIL_MODES = new Set(['metro', 'rer', 'transilien']);

type Candidate = {
  rawID: string;
  stationName: string;
  passageAt: Date;
  lineId?: string;
  vehicleId?: string;
};

export function createDatabaseJourneyReportOverlay(
  repository: ReportRepository = createDatabaseReportRepository(),
): JourneyReportOverlay {
  return {
    async apply(response, input, at) {
      const candidates = response.journeys.flatMap(journeyCandidates);
      if (candidates.length === 0) return response;
      const canonical = await canonicalStationIDs(candidates.map((candidate) => candidate.rawID));
      const stationIDs = [...new Set(canonical.values())];
      if (stationIDs.length === 0) return response;
      const votes = await repository.loadVotes({ stationIds: stationIDs, at });
      return applyCommunityReportVotes(response, input, at, votes, canonical);
    },
  };
}

/** Pure half of the post-cache overlay; all report rows arrive in one grouped read. */
export function applyCommunityReportVotes(
  response: JourneysResponse,
  input: JourneyInput,
  at: Date,
  votes: CurrentReportVote[],
  canonical: ReadonlyMap<string, string>,
): JourneysResponse {
  const enriched = response.journeys.flatMap((journey) => {
    const candidates = journeyCandidates(journey);
    const live = candidates.flatMap((candidate) => {
      const stationId = canonical.get(candidate.rawID);
      if (!stationId) return [];
      return [{
        candidate,
        status: StationStatusResolver.resolve({
          stationId,
          at,
          votes,
          lineId: candidate.lineId,
          vehicleId: candidate.vehicleId,
        }),
      }];
    });

    const wheelchair = live.find(({ candidate, status }) =>
      status.accessibility?.source === 'reported' &&
      candidate.passageAt <= new Date(status.accessibility.expiresAt));
    if (input.requiresAccessibleStations && wheelchair?.status.wheelchairRouteExcluded) return [];

    const crowding = live
      .flatMap(({ candidate, status }) => status.crowding?.source === 'reported' &&
        candidate.passageAt <= new Date(status.crowding.expiresAt ?? 0)
        ? [{ candidate, crowding: status.crowding }]
        : [])
      .sort((a, b) => crowdingSeverity(b.crowding.level) - crowdingSeverity(a.crowding.level))[0];
    const crowdedStationID = crowding ? canonical.get(crowding.candidate.rawID) : undefined;

    const wheelchairReport = wheelchair?.status.accessibility?.source === 'reported'
      ? {
          stationName: wheelchair.candidate.stationName,
          label: wheelchair.status.accessibility.label,
          reporterCount: wheelchair.status.accessibility.reporterCount,
          confidence: wheelchair.status.accessibility.confidence,
          expiresAt: wheelchair.status.accessibility.expiresAt,
        }
      : undefined;
    const reportedCrowding = crowding ? {
      level: crowding.crowding.level,
      stationName: crowding.candidate.stationName,
      label: crowding.crowding.label,
      reporterCount: crowding.crowding.reporterCount!,
      expiresAt: crowding.crowding.expiresAt!,
    } : undefined;
    // A reported level supersedes the automatic peak of the same station.
    const peak = crowdedStationID && journey.peak?.stationId === crowdedStationID
      ? undefined
      : journey.peak;
    const warning = wheelchairReport
      ? `${wheelchairReport.label} à ${wheelchairReport.stationName}`
      : undefined;
    return [{
      ...journey,
      peak,
      reportedCrowding,
      wheelchairReport,
      warnings: warning && !journey.warnings.includes(warning)
        ? [...journey.warnings, warning]
        : journey.warnings,
    }];
  });

  return finalizePlan(response, enriched, input);
}

function journeyCandidates(journey: Journey): Candidate[] {
  return journey.sections.flatMap((section) => {
    if (section.type !== 'transit' || !section.route || !RAIL_MODES.has(section.route.mode)) return [];
    const route = section.route;
    const endpoints = [section.stops[0], section.stops.at(-1)];
    return endpoints.flatMap((stop, index) => {
      if (!stop || (index === 1 && stop === endpoints[0])) return [];
      const rawAt = index === 0
        ? stop.departureAt ?? stop.arrivalAt ?? section.departureAt
        : stop.arrivalAt ?? stop.departureAt ?? section.arrivalAt;
      if (!rawAt) return [];
      const passageAt = new Date(rawAt);
      if (Number.isNaN(passageAt.getTime())) return [];
      return [{
        rawID: stop.stationId ?? stop.id,
        stationName: stop.name,
        passageAt,
        lineId: route.id,
        vehicleId: section.serviceId,
      }];
    });
  });
}
