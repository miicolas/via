import { mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { describe, expect, test } from 'bun:test';

import { readPositionalCsv } from './csv';

async function csvFile(name: string, content: string): Promise<string> {
  const directory = await mkdtemp(join(tmpdir(), 'via-csv-'));
  const path = join(directory, name);
  await writeFile(path, content);
  return path;
}

async function collect(rows: AsyncIterable<readonly string[]>): Promise<string[][]> {
  const collected: string[][] = [];
  for await (const row of rows) collected.push([...row]);
  return collected;
}

describe('readPositionalCsv', () => {
  test('resolves the requested columns from the header and streams the rest', async () => {
    const path = await csvFile(
      'stop_times.txt',
      'trip_id,arrival_time,departure_time,stop_id\nt1,08:00:00,08:00:30,stop-a\nt1,08:05:00,08:05:00,stop-b\n'
    );

    const { column, rows } = await readPositionalCsv(path, ['stop_id', 'trip_id']);

    expect(column).toEqual({ stop_id: 3, trip_id: 0 });
    expect(await collect(rows)).toEqual([
      ['t1', '08:00:00', '08:00:30', 'stop-a'],
      ['t1', '08:05:00', '08:05:00', 'stop-b'],
    ]);
  });

  /** Positional reads are only safe because a moved column fails loudly here. */
  test('names the missing column rather than reading a neighbouring field', async () => {
    const path = await csvFile('stop_times.txt', 'trip_id,stop_id\nt1,stop-a\n');

    await expect(readPositionalCsv(path, ['trip_id', 'departure_time'])).rejects.toThrow(
      'Missing column departure_time in stop_times.txt'
    );
  });

  test('rejects an empty file instead of yielding its header as data', async () => {
    const path = await csvFile('stop_times.txt', '');

    await expect(readPositionalCsv(path, ['trip_id'])).rejects.toThrow(
      'stop_times.txt is empty'
    );
  });
});
