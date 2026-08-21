import { implementer } from '../../../orpc/implementer';
import type { NaturalJourneyService } from '../service';

/** The phrase and its answer are personal and single-use — never cache them. */
const NATURAL_JOURNEYS_CACHE_CONTROL = 'no-store';

/** The oRPC adapter: transport facts in, domain result out. */
export function createSubmitNaturalJourneyHandler(service: NaturalJourneyService) {
  return implementer.naturalJourneys.submit.handler(async ({ input, context, signal }) => {
    context.resHeaders?.set('Cache-Control', NATURAL_JOURNEYS_CACHE_CONTROL);
    return service.submit(input, {
      identity: context.userId ?? 'anonymous',
      signal,
    });
  });
}
