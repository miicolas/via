import { join } from 'node:path';
import { Readable, type Writable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

import type { db } from '@via/db';
import { transitShapes } from '@via/db/schema';
import { sql } from 'drizzle-orm';

type Transaction = Parameters<Parameters<typeof db.transaction>[0]>[0];

type CopyClient = {
  (strings: TemplateStringsArray, ...values: readonly unknown[]): {
    writable: () => Promise<Writable>;
  };
};

type TransactionWithClient = Transaction & {
  session: { client: CopyClient };
};

type ImportShapesOptions = {
  gtfsPath: string;
  tx: Transaction;
  shapeIds: ReadonlySet<string>;
  readCsv: (path: string) => AsyncGenerator<Record<string, string>>;
};

/**
 * Streams shape points through a transaction-local staging table, then lets
 * PostGIS build one LineString per shape. The 3.4 M source points never live in
 * the Bun heap and the staging rows generate no WAL.
 */
export async function importShapes({
  gtfsPath,
  tx,
  shapeIds,
  readCsv,
}: ImportShapesOptions) {
  await tx.execute(sql`
    CREATE TEMP TABLE gtfs_shape_points (
      shape_id text NOT NULL,
      sequence integer NOT NULL,
      longitude double precision NOT NULL,
      latitude double precision NOT NULL
    ) ON COMMIT DROP
  `);

  let pointCount = 0;
  const rows = (async function* () {
    for await (const point of readCsv(join(gtfsPath, 'shapes.txt'))) {
      if (!shapeIds.has(point.shape_id)) continue;
      pointCount += 1;
      if (pointCount % 1_000_000 === 0) console.log(`Streamed ${pointCount} shape points…`);
      yield [
        point.shape_id,
        requiredNumber(point.shape_pt_sequence, 'shape_pt_sequence'),
        requiredNumber(point.shape_pt_lon, 'shape_pt_lon'),
        requiredNumber(point.shape_pt_lat, 'shape_pt_lat'),
      ]
        .map(copyTextCell)
        .join('\t') + '\n';
    }
  })();

  const copyClient = (tx as TransactionWithClient).session.client;
  const writer = await copyClient`
    COPY pg_temp.gtfs_shape_points (shape_id, sequence, longitude, latitude)
    FROM STDIN WITH (FORMAT text, DELIMITER E'\\t', NULL '\\N')
  `.writable();
  await pipeline(Readable.from(rows), writer);

  await tx.execute(sql`
    INSERT INTO ${transitShapes} (id, geometry)
    SELECT shape_id,
           ST_MakeLine(
             ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
             ORDER BY sequence
           )
    FROM pg_temp.gtfs_shape_points
    GROUP BY shape_id
    HAVING count(*) >= 2
  `);

  const imported = await tx
    .select({ count: sql<number>`count(*)::int` })
    .from(transitShapes);
  const importedCount = imported[0]?.count ?? 0;
  if (importedCount !== shapeIds.size) {
    throw new Error(
      `Imported ${importedCount}/${shapeIds.size} shapes; missing or one-point shapes make routes unsafe`
    );
  }
  console.log(`Imported ${importedCount} shapes from ${pointCount} points.`);
}

function requiredNumber(value: string | undefined, field: string) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) throw new Error(`Invalid ${field} in shapes.txt: ${value ?? '<missing>'}`);
  return parsed;
}

function copyTextCell(value: string | number) {
  return String(value)
    .replaceAll('\\', '\\\\')
    .replaceAll('\t', '\\t')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r');
}
