import { app } from './app';
import { env } from './env';
import { startNotificationRuntime } from './notifications/runtime';
import { startReportRuntime } from './reports/runtime';
import { startJourneyShareRetentionRuntime } from './routers/journey-shares/retention';

startNotificationRuntime();
startReportRuntime();
startJourneyShareRetentionRuntime();

console.log(`[api] http://localhost:${env.PORT}`);

export default {
  port: env.PORT,
  fetch: app.fetch,
};
