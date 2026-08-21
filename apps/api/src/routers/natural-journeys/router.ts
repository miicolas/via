import { createSubmitNaturalJourneyHandler } from './handlers/submit';
import type { NaturalJourneyService } from './service';

export function createNaturalJourneysRouter(service: NaturalJourneyService) {
  return {
    submit: createSubmitNaturalJourneyHandler(service),
  };
}
