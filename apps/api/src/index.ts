import { app } from './app';
import { env } from './env';
import { startNotificationDisruptionMonitor } from './notifications/monitor';

startNotificationDisruptionMonitor();

console.log(`[api] http://localhost:${env.PORT}`);

export default {
  port: env.PORT,
  fetch: app.fetch,
};
