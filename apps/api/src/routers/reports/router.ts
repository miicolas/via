import { ORPCError } from '@orpc/server';

import { implementer } from '../../orpc/implementer';
import { redis } from '../../redis';
import { ReportRateLimitError } from '../../reports/rate-limiter';
import { createDatabaseReportRepository } from '../../reports/repository';
import { ReportService, ReportStationNotFoundError } from '../../reports/service';
import { recordReportMetric } from '../../reports/metrics';

export const reportService = new ReportService({
  repository: createDatabaseReportRepository(),
  redis,
  clock: { now: () => new Date() },
  recordMetric: recordReportMetric,
});

const submit = implementer.reports.submit.handler(async ({ input, context }) => {
  if (!context.userId || !context.requestIPHash) throw new ORPCError('UNAUTHORIZED');
  try {
    return await reportService.submit({
      userId: context.userId,
      ipHash: context.requestIPHash(),
      submission: input,
    });
  } catch (error) {
    throw asORPCError(error);
  }
});

const stationStatus = implementer.reports.stationStatus.handler(async ({ input, context }) => {
  context.resHeaders?.set('Cache-Control', 'private, max-age=0, must-revalidate');
  try {
    return await reportService.stationStatus(input);
  } catch (error) {
    throw asORPCError(error);
  }
});

function asORPCError(error: unknown) {
  if (error instanceof ReportStationNotFoundError) return new ORPCError('NOT_FOUND');
  if (error instanceof ReportRateLimitError) {
    return new ORPCError(error.reason === 'unavailable' ? 'SERVICE_UNAVAILABLE' : 'TOO_MANY_REQUESTS');
  }
  return error;
}

export const reportsRouter = { submit, stationStatus };
