import { implementer } from '../../orpc/implementer';
import type { NaturalJourneyService } from './service';

export function createNaturalJourneyHandler(service: NaturalJourneyService) {
  return implementer.naturalJourneys.submit.handler(async ({ input, context, signal }) => {
    context.resHeaders?.set('Cache-Control', 'private, no-store');
    return service.submit(input, {
      identity: context.viaIdentity ?? 'anonymous',
      signal,
    });
  });
}
