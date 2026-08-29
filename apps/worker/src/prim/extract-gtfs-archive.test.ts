import { describe, expect, test } from 'bun:test';
import { lstat, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { ZipFile } from 'yazl';

import { extractGtfsArchive } from './extract-gtfs-archive';

type ZipEntry = { name: string; contents?: string } | { directory: string };

async function zipBytes(entries: ZipEntry[]) {
  const zip = new ZipFile();
  const chunks: Buffer[] = [];
  const result = new Promise<Buffer>((resolve, reject) => {
    zip.outputStream.on('data', (chunk: Buffer) => chunks.push(Buffer.from(chunk)));
    zip.outputStream.on('error', reject);
    zip.outputStream.on('end', () => resolve(Buffer.concat(chunks)));
  });
  for (const entry of entries) {
    if ('directory' in entry) zip.addEmptyDirectory(entry.directory);
    else zip.addBuffer(Buffer.from(entry.contents ?? ''), entry.name);
  }
  zip.end();
  return result;
}

/** Replace a same-length metadata path in both the local and central headers. */
function replaceEntryName(archive: Buffer, current: string, replacement: string) {
  const currentBytes = Buffer.from(current);
  const replacementBytes = Buffer.from(replacement);
  if (currentBytes.length !== replacementBytes.length) throw new Error('fixture names must have equal lengths');
  const patched = Buffer.from(archive);
  for (let offset = 0; offset + 4 <= patched.length; offset += 1) {
    const signature = patched.readUInt32LE(offset);
    const isLocal = signature === 0x04034b50;
    const isCentral = signature === 0x02014b50;
    if (!isLocal && !isCentral) continue;
    const nameLengthOffset = offset + (isLocal ? 26 : 28);
    const nameOffset = offset + (isLocal ? 30 : 46);
    const nameLength = patched.readUInt16LE(nameLengthOffset);
    if (nameLength !== currentBytes.length) continue;
    if (patched.subarray(nameOffset, nameOffset + nameLength).equals(currentBytes)) {
      replacementBytes.copy(patched, nameOffset);
    }
  }
  return patched;
}

function markUnixSymlink(archive: Buffer, name: string) {
  const patched = Buffer.from(archive);
  const nameBytes = Buffer.from(name);
  for (let offset = 0; offset + 46 <= patched.length; offset += 1) {
    if (patched.readUInt32LE(offset) !== 0x02014b50) continue;
    const nameLength = patched.readUInt16LE(offset + 28);
    const nameOffset = offset + 46;
    if (nameLength !== nameBytes.length || !patched.subarray(nameOffset, nameOffset + nameLength).equals(nameBytes)) continue;
    patched.writeUInt16LE((3 << 8) | 20, offset + 4);
    patched.writeUInt32LE((0o120777 << 16) >>> 0, offset + 38);
  }
  return patched;
}

async function withTempDirectory(run: (directory: string) => Promise<void>) {
  const directory = await mkdtemp(join(tmpdir(), 'via-gtfs-extract-test-'));
  try {
    await run(directory);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

describe('extractGtfsArchive', () => {
  test('extracts flat and nested feed files byte-for-byte', async () => {
    await withTempDirectory(async (directory) => {
      const archive = join(directory, 'feed.zip');
      const destination = join(directory, 'feed');
      await writeFile(archive, await zipBytes([
        { name: 'stops.txt', contents: 'stop_id,stop_name\n1,Châtelet\n' },
        { name: 'nested/routes.txt', contents: 'route_id\nM1\n' },
        { directory: 'nested/empty/' },
      ]));

      await extractGtfsArchive(archive, destination);

      expect(await readFile(join(destination, 'stops.txt'), 'utf8')).toBe('stop_id,stop_name\n1,Châtelet\n');
      expect(await readFile(join(destination, 'nested/routes.txt'), 'utf8')).toBe('route_id\nM1\n');
      expect((await lstat(join(destination, 'nested/empty'))).isDirectory()).toBe(true);
    });
  });

  test('rejects POSIX and Windows parent segments without escaping', async () => {
    await withTempDirectory(async (directory) => {
      const sentinel = join(directory, 'escape.txt');
      await writeFile(sentinel, 'untouched');
      for (const [label, name] of [['posix', '../escape.txt'], ['windows', '..\\escape.txt']] as const) {
        const archive = join(directory, `${label}.zip`);
        const bytes = replaceEntryName(
          await zipBytes([{ name: 'safe-file-123', contents: 'secret' }]),
          'safe-file-123',
          name,
        );
        await writeFile(archive, bytes);
        await expect(extractGtfsArchive(archive, join(directory, label))).rejects.toThrow('unsafe path');
      }
      expect(await readFile(sentinel, 'utf8')).toBe('untouched');
    });
  });

  test.each([
    ['/abs-file', 'absolute', 'safe-file'],
    ['C:/drive', 'drive', 'safe1234'],
  ])('rejects %s paths', async (name, label, safeName) => {
    await withTempDirectory(async (directory) => {
      const archive = join(directory, `${label}.zip`);
      const bytes = replaceEntryName(
        await zipBytes([{ name: safeName, contents: 'secret' }]),
        safeName,
        name,
      );
      await writeFile(archive, bytes);

      await expect(extractGtfsArchive(archive, join(directory, label))).rejects.toThrow('unsafe path');
    });
  });

  test('rejects Unix symbolic-link metadata', async () => {
    await withTempDirectory(async (directory) => {
      const archive = join(directory, 'symlink.zip');
      const bytes = markUnixSymlink(
        await zipBytes([{ name: 'link', contents: '../outside' }]),
        'link',
      );
      await writeFile(archive, bytes);

      await expect(extractGtfsArchive(archive, join(directory, 'feed'))).rejects.toThrow('unsupported entry type');
    });
  });

  test('rejects duplicate targets without overwriting the first file', async () => {
    await withTempDirectory(async (directory) => {
      const archive = join(directory, 'duplicate.zip');
      await writeFile(archive, await zipBytes([
        { name: 'same.txt', contents: 'first' },
        { name: 'same.txt', contents: 'second' },
      ]));
      const destination = join(directory, 'feed');

      await expect(extractGtfsArchive(archive, destination)).rejects.toThrow('duplicate');
      expect(await readFile(join(destination, 'same.txt'), 'utf8')).toBe('first');
    });
  });

  test('rejects a truncated archive', async () => {
    await withTempDirectory(async (directory) => {
      const archive = join(directory, 'truncated.zip');
      const bytes = await zipBytes([{ name: 'stops.txt', contents: 'content' }]);
      await writeFile(archive, bytes.subarray(0, -5));

      await expect(extractGtfsArchive(archive, join(directory, 'feed'))).rejects.toThrow();
    });
  });
});
