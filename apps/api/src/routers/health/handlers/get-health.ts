import { implementer } from '../../../orpc/implementer';
import { isDatabaseReachable } from '../queries';

export const getHealth = implementer.health.handler(async () => {
  const db = await isDatabaseReachable();

  return { status: 'ok' as const, db, at: new Date().toISOString() };
});
