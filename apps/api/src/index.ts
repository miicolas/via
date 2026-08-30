import { app } from './app';
import { env } from './env';
import { startNotificationRuntime } from './notifications/runtime';
import { startReportRuntime } from './reports/runtime';
import { startJourneyShareRetentionRuntime } from './routers/journey-shares/retention';
import { meetupPlanning, meetupSemanticNotifier } from './routers';
import { startMeetupRuntime } from './routers/meetups/runtime';

startNotificationRuntime();
startReportRuntime();
startJourneyShareRetentionRuntime();
startMeetupRuntime(meetupPlanning, meetupSemanticNotifier);

console.log(`[api] http://localhost:${env.PORT}`);

export default {
  port: env.PORT,
  fetch: app.fetch,
};
