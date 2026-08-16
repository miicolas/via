import { implementer } from '../../../orpc/implementer';
import type { JourneyPlanner } from '../service';

const JOURNEYS_CACHE_CONTROL = 'private, max-age=30';

/** The oRPC adapter: transport facts in, domain result out. */
export function createPlanJourneysHandler(planner: JourneyPlanner) {
  return implementer.journeys.plan.handler(async ({ input, context, signal }) => {
    context.resHeaders?.set('Cache-Control', JOURNEYS_CACHE_CONTROL);
    return planner.plan(input, {
      identity: context.userId ?? 'anonymous',
      signal,
    });
  });
}
