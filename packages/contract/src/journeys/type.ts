import * as z from 'zod';

import {
  boardingPositionSchema,
  journeyDestinationSchema,
  journeyExitSchema,
  journeyInputSchema,
  journeyModeSchema,
  journeySchema,
  journeysResponseSchema,
  journeySectionSchema,
  journeyStopSchema,
  journeyDepartureChoiceGroupSchema,
  journeyDepartureChoicesInputSchema,
  journeyDepartureChoicesResponseSchema,
  journeyDepartureChoiceSchema,
  journeyDepartureSelectionSchema,
  journeyPlanningPolicySchema,
} from './schema';

export type BoardingPosition = z.infer<typeof boardingPositionSchema>;
export type JourneyExit = z.infer<typeof journeyExitSchema>;
export type JourneyDestination = z.infer<typeof journeyDestinationSchema>;
export type JourneyInput = z.infer<typeof journeyInputSchema>;
export type JourneyMode = z.infer<typeof journeyModeSchema>;
export type Journey = z.infer<typeof journeySchema>;
export type JourneySection = z.infer<typeof journeySectionSchema>;
export type JourneyStop = z.infer<typeof journeyStopSchema>;
export type JourneysResponse = z.infer<typeof journeysResponseSchema>;
export type JourneyPlanningPolicy = z.infer<typeof journeyPlanningPolicySchema>;
export type JourneyDepartureSelection = z.infer<typeof journeyDepartureSelectionSchema>;
export type JourneyDepartureChoicesInput = z.infer<typeof journeyDepartureChoicesInputSchema>;
export type JourneyDepartureChoice = z.infer<typeof journeyDepartureChoiceSchema>;
export type JourneyDepartureChoiceGroup = z.infer<typeof journeyDepartureChoiceGroupSchema>;
export type JourneyDepartureChoicesResponse = z.infer<typeof journeyDepartureChoicesResponseSchema>;
