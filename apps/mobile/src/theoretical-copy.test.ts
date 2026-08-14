import { Glob } from 'bun';
import { expect, test } from 'bun:test';

test('runtime copy never mentions scheduled data theory', async () => {
  const sourceFiles = new Glob('**/*.{ts,tsx}');
  const matches: string[] = [];

  for await (const path of sourceFiles.scan({ cwd: import.meta.dir })) {
    if (path.endsWith('.test.ts') || path.endsWith('.test.tsx')) continue;

    const source = await Bun.file(`${import.meta.dir}/${path}`).text();
    if (/théorique/i.test(source)) matches.push(path);
  }

  expect(matches).toEqual([]);
});
