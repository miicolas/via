import { createReadStream } from 'node:fs';
import { basename } from 'node:path';

import { parse } from 'csv-parse';

import { formatCount, formatDuration, logStep } from './progress';

export type CsvRow = Record<string, string>;

/**
 * Rows between two heartbeats. Every GTFS file the import reads goes through
 * this module, so one counter here covers the whole run — including trips.txt
 * and stop_times.txt, the two files that used to read in complete silence.
 */
const PROGRESS_EVERY = 500_000;

function parserFor(path: string, columns: boolean) {
  return createReadStream(path).pipe(parse({ bom: true, columns, skip_empty_lines: true }));
}

/** Reports a file's progress while it streams, then its total. */
class ReadProgress {
  readonly #name: string;
  readonly #startedAt = performance.now();
  #rows = 0;

  constructor(path: string) {
    this.#name = basename(path);
  }

  count(): void {
    this.#rows += 1;
    if (this.#rows % PROGRESS_EVERY === 0) {
      logStep(`${this.#name}: ${formatCount(this.#rows)} rows read…`);
    }
  }

  done(): void {
    const elapsed = formatDuration(performance.now() - this.#startedAt);
    logStep(`${this.#name}: ${formatCount(this.#rows)} rows in ${elapsed}.`);
  }
}

export async function* readCsv(path: string): AsyncGenerator<CsvRow> {
  const progress = new ReadProgress(path);
  for await (const row of parserFor(path, true)) {
    progress.count();
    yield row as CsvRow;
  }
  progress.done();
}

export type PositionalCsv<Column extends string> = {
  /** Position of each requested column, resolved once from the header row. */
  column: Readonly<Record<Column, number>>;
  rows: AsyncIterable<readonly string[]>;
};

/**
 * Streams a CSV as raw positional arrays instead of one keyed object per row.
 *
 * `columns: true` is worth the convenience everywhere else, but stop_times.txt
 * is 14.5M rows: it makes csv-parse allocate 14.5M objects carrying ten
 * properties each, and that garbage is what pushed a 16 GB machine into swap
 * until the kernel killed the import. The same strings in an array cost a
 * fraction of it.
 *
 * The caller reads rows through the index map resolved here rather than by
 * hardcoded position, so a column moving in the feed fails once, up front, with
 * the column named — never by silently reading a neighbouring field.
 */
export async function readPositionalCsv<Column extends string>(
  path: string,
  columns: readonly Column[]
): Promise<PositionalCsv<Column>> {
  const source = basename(path);
  const iterator = parserFor(path, false)[Symbol.asyncIterator]();
  const header = await iterator.next();
  if (header.done) throw new Error(`${source} is empty`);

  const positions = header.value as string[];
  const column = {} as Record<Column, number>;
  for (const name of columns) {
    const at = positions.indexOf(name);
    if (at === -1) {
      throw new Error(`Missing column ${name} in ${source}: header is ${positions.join(',')}`);
    }
    column[name] = at;
  }

  const progress = new ReadProgress(path);
  async function* rows(): AsyncGenerator<readonly string[]> {
    for (let next = await iterator.next(); !next.done; next = await iterator.next()) {
      progress.count();
      yield next.value as string[];
    }
    progress.done();
  }

  return { column, rows: rows() };
}
