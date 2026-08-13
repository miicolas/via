import { createPlanJourneysHandler } from './handlers/plan-journeys';
import type { JourneyPlanner } from './service';

export function createJourneysRouter(planner: JourneyPlanner) {
  return {
    plan: createPlanJourneysHandler(planner),
  };
}
