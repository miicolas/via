/**
 * A full IDFM import spends minutes at a time inside a single step — hashing
 * 1.5 GB of feed, streaming 14.5M stop-times, vacuuming eleven tables. Only the
 * shapes and stop-time loops ever said anything, so the first four minutes were
 * silent, which is indistinguishable from a hung process. The natural reaction
 * is to kill it and start over.
 *
 * Every step therefore announces itself with the time elapsed since the import
 * began: a line that stops advancing tells you which step is stuck, and a line
 * that keeps advancing tells you to wait.
 */
const startedAt = performance.now();

export function formatDuration(milliseconds: number): string {
  const seconds = milliseconds / 1_000;
  if (seconds < 60) return `${seconds.toFixed(1)}s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}m${String(Math.floor(seconds % 60)).padStart(2, '0')}s`;
}

/** Thousands separators: `14512003 rows` is unreadable at a glance. */
export function formatCount(value: number): string {
  return value.toLocaleString('en-US');
}

export function logStep(message: string): void {
  console.log(`[${formatDuration(performance.now() - startedAt)}] ${message}`);
}

/**
 * Times one step and reports it on completion, so a step's cost is visible even
 * when it produces no output of its own.
 */
export async function step<Result>(label: string, run: () => Promise<Result>): Promise<Result> {
  logStep(`${label}…`);
  const stepStartedAt = performance.now();
  const result = await run();
  logStep(`${label} done in ${formatDuration(performance.now() - stepStartedAt)}.`);
  return result;
}
