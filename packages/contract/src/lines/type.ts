import * as z from 'zod';

import {
  lineBranchSchema,
  lineConditionSchema,
  lineDetailInputSchema,
  lineDetailResponseSchema,
  lineDisruptionSchema,
  lineSearchInputSchema,
  lineStatusSchema,
  lineStatusesResponseSchema,
  lineStopSchema,
  upcomingClosureSchema,
} from './schema';

export type LineCondition = z.infer<typeof lineConditionSchema>;
export type UpcomingClosure = z.infer<typeof upcomingClosureSchema>;
export type LineStatus = z.infer<typeof lineStatusSchema>;
export type LineStatusesResponse = z.infer<typeof lineStatusesResponseSchema>;
export type LineSearchInput = z.infer<typeof lineSearchInputSchema>;
export type LineDetailInput = z.infer<typeof lineDetailInputSchema>;
export type LineStop = z.infer<typeof lineStopSchema>;
export type LineBranch = z.infer<typeof lineBranchSchema>;
export type LineDisruption = z.infer<typeof lineDisruptionSchema>;
export type LineDetailResponse = z.infer<typeof lineDetailResponseSchema>;
