import { app } from './app';
import { env } from './env';
import { startNotificationRuntime } from './notifications/runtime';
import { startReportRuntime } from './reports/runtime';

startNotificationRuntime();
startReportRuntime();

console.log(`[api] http://localhost:${env.PORT}`);

export default {
  port: env.PORT,
  fetch: app.fetch,
};
