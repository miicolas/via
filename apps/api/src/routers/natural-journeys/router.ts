import { createNaturalJourneyHandler } from './handler';
import type { NaturalJourneyService } from './service';

export function createNaturalJourneysRouter(service: NaturalJourneyService) {
  return { submit: createNaturalJourneyHandler(service) };
}
