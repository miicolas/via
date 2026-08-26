import { writeFile } from 'node:fs/promises';

import { client } from '@via/db';

import { runDisruptionsHistory } from './run';

/**
 * The scheduled pass, as Railway runs it: `bun apps/api/src/jobs/disruptions-history/cli.ts`.
 *
 * `--out <path>` writes the subject report to a file for the drafting workflow
 * to read; without it the report goes to stdout, which is what you want when
 * running it by hand.
 */
const args = process.argv.slice(2);
const outIndex = args.indexOf('--out');
const outPath = outIndex === -1 ? null : args[outIndex + 1];

if (outIndex !== -1 && !outPath) {
  throw new Error('--out needs a path.');
}

try {
  const { report, written } = await runDisruptionsHistory();

  const serialised = `${JSON.stringify(report, null, 2)}\n`;
  if (outPath) await writeFile(outPath, serialised, 'utf8');
  else process.stdout.write(serialised);

  console.error(
    `[disruptions-history] ${written} perturbations enregistrées, ${report.topics.length} sujets retenus sur ${report.seen}`
  );
} finally {
  await client.end();
}
