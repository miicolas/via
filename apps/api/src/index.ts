import { app } from './app';
import { env } from './env';
import { startNotificationRuntime } from './notifications/runtime';

startNotificationRuntime();

console.log(`[api] http://localhost:${env.PORT}`);

export default {
  port: env.PORT,
  fetch: app.fetch,
};
