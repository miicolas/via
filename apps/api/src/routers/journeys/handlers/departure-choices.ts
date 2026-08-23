import { ORPCError } from '@orpc/server';

import { implementer } from '../../../orpc/implementer';
import {
  DepartureChoiceUnavailableError,
  type JourneyDepartureChoicesModule,
} from '../departure-choices';

export function createDepartureChoicesHandler(module: JourneyDepartureChoicesModule) {
  return implementer.journeys.departureChoices.handler(async ({ input, context, signal }) => {
    context.resHeaders?.set('Cache-Control', 'private, no-store');
    try {
      return await module.resolve(input, {
        identity: context.userId ?? context.requestIPHash?.() ?? 'anonymous',
        signal,
      });
    } catch (error) {
      if (error instanceof DepartureChoiceUnavailableError) {
        throw new ORPCError('BAD_REQUEST', { message: error.message });
      }
      throw error;
    }
  });
}
