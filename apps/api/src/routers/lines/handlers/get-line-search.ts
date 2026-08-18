import { LINES_CACHE_CONTROL } from './lines-cache-control';
import { implementer } from '../../../orpc/implementer';
import { redis } from '../../../redis';
import { getDisruptionsSnapshot } from '../disruptions/snapshot';
import { selectLinesMatching } from '../queries';
import { toLineStatuses } from '../to-line-statuses';

export const getLineSearch = implementer.lines.search.handler(async ({ input, context }) => {
  const now = new Date();
  const [rows, snapshot] = await Promise.all([
    selectLinesMatching(input.q, input.limit),
    getDisruptionsSnapshot(redis, now),
  ]);

  context.resHeaders?.set('Cache-Control', LINES_CACHE_CONTROL);

  // Relevance ranking comes from the query; a canonical re-sort would undo it.
  return toLineStatuses(rows, snapshot, now, 'given');
});
