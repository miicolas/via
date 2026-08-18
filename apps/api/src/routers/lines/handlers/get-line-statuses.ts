import { LINES_CACHE_CONTROL } from './lines-cache-control';
import { implementer } from '../../../orpc/implementer';
import { redis } from '../../../redis';
import { getDisruptionsSnapshot } from '../disruptions/snapshot';
import { selectRailLines } from '../queries';
import { toLineStatuses } from '../to-line-statuses';

export const getLineStatuses = implementer.lines.statuses.handler(async ({ context }) => {
  const now = new Date();
  const [rows, snapshot] = await Promise.all([
    selectRailLines(),
    getDisruptionsSnapshot(redis, now),
  ]);

  context.resHeaders?.set('Cache-Control', LINES_CACHE_CONTROL);

  return toLineStatuses(rows, snapshot, now);
});
