import { describe, expect, test } from 'bun:test';
import { join } from 'node:path';

const repositoryRoot = join(import.meta.dir, '..');

type RailwayConfig = {
  build?: { watchPatterns?: string[] };
};

const configurations = [
  {
    file: 'railway.marketing.json',
    required: ['/apps/marketing/**', '/packages/contract/**', '/railway.marketing.json'],
  },
  {
    file: 'railway.disruptions.json',
    required: ['/apps/api/**', '/packages/**', '/railway.disruptions.json'],
  },
  {
    file: 'railway.gtfs.json',
    required: ['/apps/worker/**', '/packages/contract/**', '/packages/db/**', '/railway.gtfs.json'],
  },
  {
    file: 'railway.toilets.json',
    required: ['/apps/worker/**', '/packages/contract/**', '/packages/db/**', '/railway.toilets.json'],
  },
  {
    file: 'railway.fountains.json',
    required: ['/apps/worker/**', '/packages/contract/**', '/packages/db/**', '/railway.fountains.json'],
  },
  {
    file: 'apps/worker/railway.elevators.json',
    required: ['/apps/worker/**', '/packages/contract/**', '/packages/db/**'],
  },
] as const;

async function watchPatterns(file: string) {
  const config = await Bun.file(join(repositoryRoot, file)).json() as RailwayConfig;
  return config.build?.watchPatterns ?? [];
}

describe('Railway watch patterns', () => {
  for (const configuration of configurations) {
    test(`${configuration.file} watches its runtime dependencies`, async () => {
      const patterns = await watchPatterns(configuration.file);
      for (const required of configuration.required) {
        expect(patterns, `${configuration.file} is missing ${required}`).toContain(required);
      }
    });
  }

  test('IaC marketing and worker blocks keep the same workspace dependencies', async () => {
    const source = await Bun.file(join(repositoryRoot, '.railway/railway.ts')).text();
    const marketing = source.slice(source.indexOf('const viaMarketing'), source.indexOf('const workerCronBuild'));
    const worker = source.slice(source.indexOf('const workerCronBuild'), source.indexOf('const workerCronDeploy'));

    expect(marketing).toContain('/packages/contract/**');
    expect(worker).toContain('/packages/contract/**');
    expect(worker).toContain('/packages/db/**');
  });

  test('the user-provided fountains service remains wired in IaC', async () => {
    const source = await Bun.file(join(repositoryRoot, '.railway/railway.ts')).text();

    expect(source).toContain('viaFountainsCron');
    expect(source).toContain('railway.fountains.json');
  });
});
