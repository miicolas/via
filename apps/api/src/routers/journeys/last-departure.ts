import type { Journey, JourneySection, JourneysResponse } from '@via/contract';

import { parisDay, previousDate, toInstant } from '../../time/paris';
import type { JourneyPlanner } from './service';
import { type TimetableRunReader, selectTimetableRuns } from './timetable-runs';

/**
 * « Le dernier train » is a question Navitia cannot be asked directly: it
 * returns the N best itineraries around an instant, never the last feasible
 * one of the service day. This decorator answers it in two moves — plan for an
 * arrival at end of service, then check the GTFS timetable for a later run of
 * the same first leg and replan anchored on it. Every inner plan goes through
 * the real planner, so budgets, caches and the GTFS fallback apply unchanged.
 */
export function withLastDeparture(
  planner: JourneyPlanner,
  dependencies: { readTimetableRuns?: TimetableRunReader } = {}
): JourneyPlanner {
  const readTimetableRuns = dependencies.readTimetableRuns ?? selectTimetableRuns;

  return {
    plan: async (input, context) => {
      if (input.timeAnchor !== 'last_of_day') return planner.plan(input, context);
      const { timeAnchor: _anchor, ...rest } = input;

      const reference = rest.requestedAt ? new Date(rest.requestedAt) : new Date();
      const endOfService = endOfServiceInstant(reference);

      const base = await planner.plan(
        {
          ...rest,
          requestedAt: endOfService.toISOString(),
          datetimeRepresents: 'arrival',
        },
        context
      );
      if (base.status !== 'ready' || base.journeys.length === 0) return base;

      const section = firstTransitSection(base.journeys[0]!);
      if (!section) return base;

      let lastRun;
      try {
        const runs = await readTimetableRuns({
          routeId: section.route!.id,
          boardingStopIds: stopIdentifiers(section.stops[0]!),
          alightingStopIds: stopIdentifiers(section.stops.at(-1)!),
          from: new Date(section.departureAt!),
          to: endOfService,
        });
        lastRun = runs.at(-1);
      } catch {
        // No timetable (horizon, unknown alias): the arrival-anchored plan
        // already is the honest answer.
        return base;
      }
      if (!lastRun) return base;

      const gainMs = Date.parse(lastRun.departureAt) - Date.parse(section.departureAt!);
      if (gainMs < MIN_REPLAN_GAIN_MS) return base;

      // The timetable knows a later run; ask the planner whether it still
      // connects. Navitia arbitrates the rest of the chain — if it cannot, the
      // arrival-anchored answer stands.
      const retimed = await planner.plan(
        {
          ...rest,
          requestedAt: lastRun.departureAt,
          datetimeRepresents: 'departure',
        },
        context
      );
      return latestReady(base, retimed);
    },
  };
}

/** Replanning for less than this gains nothing the traveller can feel. */
const MIN_REPLAN_GAIN_MS = 2 * 60_000;

/**
 * The service day runs past midnight: at 00:30 « ce soir » still means
 * yesterday's service, and its last departures sit around 27:00 ("03:00").
 * Same convention as the timetable reader.
 */
function endOfServiceInstant(reference: Date): Date {
  const { date, seconds } = parisDay(reference);
  const serviceDate = seconds < 3 * 3600 ? previousDate(date) : date;
  return new Date(toInstant(serviceDate, 27 * 3600));
}

function firstTransitSection(journey: Journey): JourneySection | undefined {
  return journey.sections.find(
    (section) =>
      section.type === 'transit' &&
      section.departureAt !== undefined &&
      section.route !== undefined &&
      section.stops.length >= 2
  );
}

function stopIdentifiers(stop: { id: string; stationId?: string }): string[] {
  return [stop.stationId, stop.id].filter((value): value is string => Boolean(value));
}

/** Between the two feasible answers, the later departure wins — that is the question asked. */
function latestReady(base: JourneysResponse, retimed: JourneysResponse): JourneysResponse {
  if (retimed.status !== 'ready' || retimed.journeys.length === 0) return base;
  const baseDeparture = Date.parse(base.journeys[0]!.departureAt);
  const retimedDeparture = Date.parse(retimed.journeys[0]!.departureAt);
  return retimedDeparture > baseDeparture ? retimed : base;
}

