import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

import { client, db } from '@via/db';
import { drawnRouteCondition } from '@via/db/network-scope';
import {
  networkMode,
  transitLineDirections,
  transitLineSchemaStops,
  transitRoutes,
  transitStopRoutes,
  transitStops,
} from '@via/db/schema';
import { and, asc, eq, sql } from 'drizzle-orm';

/**
 * The station order of every rail line, frozen into a file the marketing site
 * ships.
 *
 * A blog article's line strip is its main illustration, and it has to draw
 * before anything is fetched: the site sleeps between visits, the API sleeps
 * too, and a page that renders its diagram only when a request succeeds is a
 * page Googlebot can catch empty. So geometry is committed and live data is an
 * overlay — `/public/lines/detail` adds what is cut today, on top of a strip
 * that was already correct.
 *
 * Run `bun run snapshot:line-schemas` after a network import changes the
 * schema. That is rare: stations move when lines are extended, not weekly.
 */

const OUTPUT = resolve(import.meta.dir, '../apps/marketing/src/data/line-schemas.json');

type SnapshotStop = {
  id: string;
  name: string;
  /** Served by at least one other drawn line — where a detour can start. */
  isInterchange: boolean;
};

type SnapshotSection = {
  role: 'trunk' | 'branch';
  label?: string;
  stops: SnapshotStop[];
};

type SnapshotDirection = {
  directionId: number;
  label: string;
  sections: SnapshotSection[];
};

type SnapshotLine = {
  id: string;
  mode: string;
  shortName: string;
  color: string;
  textColor: string;
  directions: SnapshotDirection[];
};

async function main() {
  const routes = await db
    .select({
      id: transitRoutes.id,
      shortName: transitRoutes.shortName,
      routeType: transitRoutes.routeType,
      color: transitRoutes.color,
      textColor: transitRoutes.textColor,
    })
    .from(transitRoutes)
    .where(drawnRouteCondition())
    .orderBy(asc(transitRoutes.routeType), asc(transitRoutes.shortName));

  const lines: SnapshotLine[] = [];

  for (const route of routes) {
    const rows = await db
      .select({
        directionId: transitLineSchemaStops.directionId,
        directionLabel: transitLineDirections.label,
        sectionIndex: transitLineSchemaStops.sectionIndex,
        sectionRole: transitLineSchemaStops.sectionRole,
        sectionLabel: transitLineSchemaStops.sectionLabel,
        stopId: transitStops.id,
        stopName: transitStops.name,
        isInterchange: sql<boolean>`EXISTS (
          SELECT 1
          FROM ${transitStopRoutes}
          INNER JOIN ${transitRoutes} ON ${transitRoutes.id} = ${transitStopRoutes.routeId}
          WHERE ${transitStopRoutes.stopId} = ${transitStops.id}
            AND ${transitStopRoutes.routeId} <> ${route.id}
            AND ${drawnRouteCondition()}
        )`,
      })
      .from(transitLineSchemaStops)
      .innerJoin(transitStops, eq(transitLineSchemaStops.stopId, transitStops.id))
      .innerJoin(
        transitLineDirections,
        and(
          eq(transitLineDirections.routeId, transitLineSchemaStops.routeId),
          eq(transitLineDirections.directionId, transitLineSchemaStops.directionId)
        )
      )
      .where(eq(transitLineSchemaStops.routeId, route.id))
      .orderBy(
        asc(transitLineSchemaStops.directionId),
        asc(transitLineSchemaStops.sectionIndex),
        asc(transitLineSchemaStops.position)
      );

    const directions = groupIntoDirections(rows);
    // A line whose schema has never been built would ship an empty strip.
    if (directions.length === 0) continue;

    // The same naming the app's own map uses, and deliberately not a local
    // re-reading of the route type: `networkMode` is what keeps ORLYVAL, the
    // CDG VAL and TER outside the network, and a second rule here would let the
    // blog draw a line the map refuses to.
    const mode = networkMode(route.routeType, route.shortName);
    if (!mode) continue;

    lines.push({
      id: route.id,
      mode,
      shortName: route.shortName,
      color: `#${route.color}`,
      textColor: `#${route.textColor}`,
      directions,
    });
  }

  await mkdir(dirname(OUTPUT), { recursive: true });
  await writeFile(OUTPUT, `${JSON.stringify({ lines }, null, 2)}\n`, 'utf8');

  const stops = lines.reduce(
    (total, line) =>
      total +
      line.directions.reduce(
        (perLine, direction) =>
          perLine + direction.sections.reduce((perDirection, section) => perDirection + section.stops.length, 0),
        0
      ),
    0
  );
  console.log(`${lines.length} lignes, ${stops} arrêts → ${OUTPUT}`);
}

type SchemaRow = {
  directionId: number;
  directionLabel: string;
  sectionIndex: number;
  sectionRole: 'trunk' | 'branch';
  sectionLabel: string | null;
  stopId: string;
  stopName: string;
  isInterchange: boolean;
};

/**
 * Rows arrive already ordered by direction, section and position, so grouping
 * is a single pass: a new key simply opens a new bucket.
 */
function groupIntoDirections(rows: readonly SchemaRow[]): SnapshotDirection[] {
  const directions: SnapshotDirection[] = [];
  let direction: SnapshotDirection | undefined;
  let section: SnapshotSection | undefined;
  let sectionIndex = -1;

  for (const row of rows) {
    if (!direction || direction.directionId !== row.directionId) {
      direction = { directionId: row.directionId, label: row.directionLabel, sections: [] };
      directions.push(direction);
      section = undefined;
      sectionIndex = -1;
    }

    if (!section || sectionIndex !== row.sectionIndex) {
      section = {
        role: row.sectionRole,
        ...(row.sectionLabel === null ? {} : { label: row.sectionLabel }),
        stops: [],
      };
      direction.sections.push(section);
      sectionIndex = row.sectionIndex;
    }

    section.stops.push({
      id: row.stopId,
      name: row.stopName,
      isInterchange: row.isInterchange,
    });
  }

  return directions;
}

try {
  await main();
} finally {
  await client.end();
}
