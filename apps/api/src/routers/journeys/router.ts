import { createPlanJourneysHandler } from './handlers/plan-journeys';
import { createDepartureChoicesHandler } from './handlers/departure-choices';
import type { JourneyDepartureChoicesModule } from './departure-choices';
import type { JourneyPlanner } from './service';

export function createJourneysRouter(
  planner: JourneyPlanner,
  departureChoices: JourneyDepartureChoicesModule
) {
  return {
    plan: createPlanJourneysHandler(planner),
    departureChoices: createDepartureChoicesHandler(departureChoices),
  };
}
