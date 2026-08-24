import { expect, test } from 'bun:test';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import {
  boardingPositions,
  stationElevators,
  stationExits,
  stationFacts,
  stationHourProfiles,
  transitRoutes,
  transitStopRoutes,
  transitStops,
} from '@via/db/schema';
import { asc, eq } from 'drizzle-orm';

const integrationDatabaseUrl = process.env.GTFS_INTEGRATION_DATABASE_URL;
const integrationTest = integrationDatabaseUrl ? test : test.skip;

async function writeFixture(directory: string) {
  const files: Record<string, string> = {
    'routes.txt': [
      'route_id,agency_id,route_short_name,route_long_name,route_type,route_color,route_text_color',
      'new-route,IDFM,1,New current network,1,FFCD00,000000',
    ].join('\n'),
    'trips.txt': [
      'route_id,service_id,trip_id,trip_headsign,direction_id,shape_id',
      'new-route,daily,new-trip,Second Station,0,new-shape',
    ].join('\n'),
    'stops.txt': [
      'stop_id,stop_name,stop_lat,stop_lon,location_type,parent_station',
      'current-stop,Current Station Renamed,48.8566,2.3522,1,',
      'current-platform,Current Platform,48.8566,2.3522,0,current-stop',
      'second-stop,Second Station,48.8600,2.3600,1,',
      'second-platform,Second Platform,48.8600,2.3600,0,second-stop',
    ].join('\n'),
    'stop_times.txt': [
      'trip_id,arrival_time,departure_time,stop_id,stop_sequence',
      'new-trip,08:00:00,08:00:00,current-platform,1',
      'new-trip,08:05:00,08:05:00,second-platform,2',
    ].join('\n'),
    'shapes.txt': [
      'shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence',
      'new-shape,48.8566,2.3522,1',
      'new-shape,48.8600,2.3600,2',
    ].join('\n'),
    'calendar.txt': [
      'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date',
      'daily,1,1,1,1,1,1,1,20260824,20260930',
    ].join('\n'),
    'calendar_dates.txt': 'service_id,date,exception_type\n',
  };
  await Promise.all(
    Object.entries(files).map(([filename, contents]) =>
      writeFile(join(directory, filename), `${contents}\n`)
    )
  );
}

integrationTest(
  'a GTFS replacement preserves every enrichment and hides an absent seasonal station',
  async () => {
    const databaseName = new URL(integrationDatabaseUrl!).pathname.slice(1);
    if (!databaseName.toLowerCase().includes('test')) {
      throw new Error('GTFS_INTEGRATION_DATABASE_URL must target a disposable database containing "test"');
    }
    process.env.DATABASE_URL = integrationDatabaseUrl;
    process.env.REDIS_URL = '';

    const [{ client, db }, { importGtfsSnapshot }] = await Promise.all([
      import('@via/db'),
      import('./import-gtfs'),
    ]);
    const fixture = await mkdtemp(join(tmpdir(), 'via-gtfs-import-test-'));
    const importedAt = new Date('2026-08-24T07:00:00Z');
    const sourceUpdatedAt = new Date('2026-08-23T07:00:00Z');

    try {
      await writeFixture(fixture);
      await client.unsafe(
        'TRUNCATE transit_routes, transit_stops, boarding_positions, import_meta CASCADE'
      );
      await db.insert(transitStops).values([
        { id: 'current-stop', name: 'Old Current Name', location: { lon: 2.3, lat: 48.8 } },
        { id: 'seasonal-stop', name: 'Seasonal Station', location: { lon: 2.4, lat: 48.9 } },
      ]);
      await db.insert(transitRoutes).values({
        id: 'seasonal-route',
        agencyId: 'IDFM',
        shortName: '1',
        longName: 'Seasonal route',
        routeType: 1,
        color: '000000',
        textColor: 'FFFFFF',
        importedAt,
      });
      await db.insert(transitStopRoutes).values({
        stopId: 'seasonal-stop',
        routeId: 'seasonal-route',
      });
      await db.insert(stationFacts).values([
        {
          stopId: 'seasonal-stop',
          kind: 'accessibility',
          condition: 'staffAssistance',
          detail: 'Call ahead',
          source: 'test:accessibility',
          sourceRef: 'seasonal-pmr',
          sourceUpdatedAt,
          importedAt,
        },
        {
          stopId: 'seasonal-stop',
          kind: 'toilets',
          condition: 'available',
          detail: 'Hall',
          source: 'test:toilets',
          sourceRef: 'seasonal-toilets',
          sourceUpdatedAt,
          importedAt,
        },
      ]);
      await db.insert(stationHourProfiles).values({
        stopId: 'seasonal-stop',
        dayType: 'weekday',
        hour: 8,
        share: 0.12,
        peakRatio: 1.4,
        source: 'test:affluence',
        sourceUpdatedAt,
        importedAt,
      });
      await db.insert(stationExits).values({
        id: 'seasonal-exit',
        stopId: 'seasonal-stop',
        name: 'Main exit',
        number: 1,
        detail: 'Square',
        location: { lon: 2.4, lat: 48.9 },
        source: 'test:wayfinding',
        sourceRef: 'seasonal-exit-ref',
        sourceUpdatedAt,
        importedAt,
      });
      await db.insert(boardingPositions).values({
        fromQuayId: 'seasonal-platform',
        targetId: 'seasonal-exit',
        targetKind: 'exit',
        routeId: 'seasonal-route',
        car: 1,
        carCount: 5,
        zone: 'front',
        equipment: 'stairs',
        source: 'test:wayfinding',
        sourceUpdatedAt,
        importedAt,
      });
      await db.insert(stationElevators).values({
        id: 'seasonal-lift',
        stopId: 'seasonal-stop',
        status: 'available',
        situation: 'Platform',
        source: 'test:elevators',
        stateUpdatedAt: sourceUpdatedAt,
        importedAt,
      });

      const enrichmentBefore = await Promise.all([
        db.select().from(stationFacts).orderBy(asc(stationFacts.kind)),
        db.select().from(stationHourProfiles),
        db.select().from(stationExits),
        db.select().from(boardingPositions),
        db.select().from(stationElevators),
      ]);

      await importGtfsSnapshot(fixture, true);

      const enrichmentAfter = await Promise.all([
        db.select().from(stationFacts).orderBy(asc(stationFacts.kind)),
        db.select().from(stationHourProfiles),
        db.select().from(stationExits),
        db.select().from(boardingPositions),
        db.select().from(stationElevators),
      ]);
      expect(enrichmentAfter).toEqual(enrichmentBefore);

      const [seasonal] = await db
        .select()
        .from(transitStops)
        .where(eq(transitStops.id, 'seasonal-stop'));
      expect(seasonal?.name).toBe('Seasonal Station');
      expect(
        await db
          .select()
          .from(transitStopRoutes)
          .where(eq(transitStopRoutes.stopId, 'seasonal-stop'))
      ).toEqual([]);

      const [current] = await db
        .select()
        .from(transitStops)
        .where(eq(transitStops.id, 'current-stop'));
      expect(current?.name).toBe('Current Station Renamed');
      expect(
        await db
          .select()
          .from(transitStopRoutes)
          .where(eq(transitStopRoutes.stopId, 'current-stop'))
      ).toHaveLength(1);
    } finally {
      await rm(fixture, { recursive: true, force: true });
      await client.end();
    }
  },
  60_000
);
