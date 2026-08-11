import { createFactory } from 'hono/factory';

import type { AppEnv } from '../../../http/app-env';
import { isDatabaseReachable } from '../queries';

const factory = createFactory<AppEnv>();

export const getHealthHandlers = factory.createHandlers(async (c) => {
  const db = await isDatabaseReachable();

  return c.json({ status: 'ok' as const, db, at: new Date().toISOString() });
});
