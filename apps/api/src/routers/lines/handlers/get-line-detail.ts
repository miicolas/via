import { ORPCError } from '@orpc/server';

import { LINES_CACHE_CONTROL } from './lines-cache-control';
import { implementer } from '../../../orpc/implementer';
import { redis } from '../../../redis';
import { getDisruptionsSnapshot } from '../disruptions/snapshot';
import { selectLineBranchStops, selectLineById, selectLineSchemaStops } from '../queries';
import { toLineBranches, toLineDirections, toLineDisruptions } from '../to-line-detail';
import { toRouteBadge } from '../../route-badge';

export const getLineDetail = implementer.lines.detail.handler(async ({ input, context }) => {
  const now = new Date();
  const [lineRows, branchRows, schemaRows, snapshot] = await Promise.all([
    selectLineById(input.lineId),
    selectLineBranchStops(input.lineId),
    selectLineSchemaStops(input.lineId),
    getDisruptionsSnapshot(redis, now),
  ]);

  const line = lineRows[0];
  if (!line) throw new ORPCError('NOT_FOUND');

  context.resHeaders?.set('Cache-Control', LINES_CACHE_CONTROL);

  return {
    route: toRouteBadge(line),
    branches: toLineBranches(branchRows),
    // Empty until the first import after this deploy fills the schema tables.
    directions: toLineDirections(schemaRows),
    source: snapshot ? ('live' as const) : ('unavailable' as const),
    ...(snapshot ? { fetchedAt: new Date(snapshot.fetchedAt * 1_000).toISOString() } : {}),
    disruptions: snapshot
      ? toLineDisruptions(input.lineId, snapshot.disruptions, Math.floor(now.getTime() / 1_000))
      : [],
  };
});
