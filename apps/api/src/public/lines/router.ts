import { Hono } from 'hono';
import { z } from 'zod';

import { toPublicLineDetail, toPublicLineStatuses } from './projection';
import type { AppEnv } from '../../http/app-env';
import { errorBody } from '../../http/errors';
import { redis } from '../../redis';
import { getDisruptionsSnapshot } from '../../routers/lines/disruptions/snapshot';
import { selectLineById, selectRailLines } from '../../routers/lines/queries';
import { toLineDisruptions } from '../../routers/lines/to-line-detail';
import { toLineStatuses } from '../../routers/lines/to-line-statuses';
import { toRouteBadge } from '../../routers/route-badge';

const detailQuery = z.object({ lineId: z.string().min(1).max(64) });

/**
 * Five minutes is the hub's own revalidation window; matching it here means a
 * redeploy of the site cannot stampede the feed. Both routes answer on the same
 * clock, so they read it from the same place.
 */
const LINES_CACHE_CONTROL = 'public, max-age=300, s-maxage=300, stale-while-revalidate=1800';

/**
 * Line conditions for the marketing site's blog, beside the coverage poll and
 * for the same reason: the site is a browser, it holds no session, and the
 * contract above `/api` belongs to the app. Read-only, and narrowed by
 * `projection.ts` so this mount can never become a second public contract.
 *
 * Both routes degrade rather than fail. The pages that call them draw their
 * line strips from a committed snapshot and treat this as an overlay, so
 * `source: 'unavailable'` costs an article its live banner and nothing else.
 */
export function createPublicLinesRouter() {
  return new Hono<AppEnv>()
    .get('/statuses', async (c) => {
      const now = new Date();
      const [rows, snapshot] = await Promise.all([
        selectRailLines(),
        getDisruptionsSnapshot(redis, now),
      ]);

      c.header('Cache-Control', LINES_CACHE_CONTROL);
      return c.json(toPublicLineStatuses(toLineStatuses(rows, snapshot, now)));
    })

    .get('/detail', async (c) => {
      const parsed = detailQuery.safeParse(c.req.query());
      if (!parsed.success) {
        return c.json(errorBody(c, 'malformed_line', 'A lineId is required.'), 400);
      }

      const now = new Date();
      const lineId = parsed.data.lineId;
      const [lineRows, snapshot] = await Promise.all([
        selectLineById(lineId),
        getDisruptionsSnapshot(redis, now),
      ]);

      const line = lineRows[0];
      if (!line) {
        return c.json(errorBody(c, 'unknown_line', 'No such line.'), 404);
      }

      c.header('Cache-Control', LINES_CACHE_CONTROL);
      return c.json(
        toPublicLineDetail({
          route: toRouteBadge(line),
          source: snapshot ? 'live' : 'unavailable',
          ...(snapshot ? { fetchedAt: new Date(snapshot.fetchedAt * 1_000).toISOString() } : {}),
          disruptions: snapshot
            ? toLineDisruptions(lineId, snapshot.disruptions, Math.floor(now.getTime() / 1_000))
            : [],
        })
      );
    });
}

export const publicLinesRouter = createPublicLinesRouter();
