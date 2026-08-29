import { createWriteStream } from 'node:fs';
import { lstat, mkdir, unlink } from 'node:fs/promises';
import { basename, dirname, isAbsolute, resolve, sep } from 'node:path';
import { pipeline } from 'node:stream/promises';

import { openPromise, type Entry } from 'yauzl';

const UNIX_PLATFORM = 3;
const DOS_DIRECTORY_BIT = 0x10;
const UNIX_TYPE_MASK = 0o170000;
const UNIX_DIRECTORY = 0o040000;
const UNIX_REGULAR_FILE = 0o100000;

/**
 * Extract a ZIP one entry at a time into a caller-owned temporary directory.
 * Archive metadata is treated as hostile: paths are resolved and every output
 * is created exclusively, with no links or archived permissions involved.
 */
export async function extractGtfsArchive(
  archive: string,
  destination: string,
): Promise<void> {
  const root = resolve(destination);
  await mkdir(root, { recursive: true });
  let zip;
  try {
    zip = await openPromise(archive, {
      autoClose: false,
      lazyEntries: true,
      decodeStrings: true,
      validateEntrySizes: true,
      strictFileNames: false,
    });
  } catch (error) {
    throw normalizeArchiveError(error);
  }
  const seenTargets = new Set<string>();

  try {
    for await (const entry of zip.eachEntry()) {
      const target = targetForEntry(entry, root, seenTargets);
      const directory = isDirectoryEntry(entry);
      if (directory) {
        await mkdir(target, { recursive: true, mode: 0o700 });
        await ensureDirectory(target);
        continue;
      }

      await mkdir(dirname(target), { recursive: true, mode: 0o700 });
      await ensureDirectory(dirname(target));
      let outputCreated = false;
      try {
        const output = createWriteStream(target, { flags: 'wx', mode: 0o600 });
        outputCreated = true;
        const input = await zip.openReadStreamPromise(entry);
        await pipeline(input, output);
      } catch (error) {
        if (outputCreated) await unlink(target).catch(() => undefined);
        throw error;
      }
    }
  } catch (error) {
    throw normalizeArchiveError(error);
  } finally {
    zip.close();
  }
}

function normalizeArchiveError(error: unknown): Error {
  if (
    error instanceof Error &&
    /invalid relative path|absolute path|invalid characters in fileName/.test(error.message)
  ) {
    return new Error('unsafe path in GTFS archive');
  }
  return error instanceof Error ? error : new Error('invalid GTFS archive');
}

function targetForEntry(entry: Entry, root: string, seenTargets: Set<string>): string {
  const rawName = entry.fileName;
  const normalizedName = rawName.replaceAll('\\', '/');
  if (
    normalizedName.length === 0 ||
    normalizedName.includes('\0') ||
    isAbsolute(normalizedName) ||
    /^[A-Za-z]:/.test(normalizedName) ||
    normalizedName.split('/').some((segment) => segment === '..')
  ) {
    throw new Error(`unsafe path in GTFS archive: ${categoryName(rawName)}`);
  }

  const target = resolve(root, normalizedName);
  const rootPrefix = root.endsWith(sep) ? root : `${root}${sep}`;
  if (target === root || !target.startsWith(rootPrefix)) {
    throw new Error(`unsafe path in GTFS archive: ${categoryName(rawName)}`);
  }
  if (seenTargets.has(target)) {
    throw new Error(`duplicate entry in GTFS archive: ${categoryName(rawName)}`);
  }
  seenTargets.add(target);
  return target;
}

function categoryName(name: string) {
  return basename(name).slice(0, 80) || 'unnamed';
}

function isDirectoryEntry(entry: Entry): boolean {
  const normalizedName = entry.fileName.replaceAll('\\', '/');
  const namedDirectory = normalizedName.endsWith('/');
  const unixMode = (entry.externalFileAttributes >>> 16) & 0xffff;
  const madeByUnix = (entry.versionMadeBy >>> 8) === UNIX_PLATFORM;
  const unixType = madeByUnix ? unixMode & UNIX_TYPE_MASK : 0;
  if (unixType !== 0 && unixType !== UNIX_DIRECTORY && unixType !== UNIX_REGULAR_FILE) {
    throw new Error(`unsupported entry type in GTFS archive: ${categoryName(entry.fileName)}`);
  }
  if (unixType === UNIX_DIRECTORY && !namedDirectory) return true;
  if (unixType === UNIX_REGULAR_FILE && namedDirectory) {
    throw new Error(`unsupported entry type in GTFS archive: ${categoryName(entry.fileName)}`);
  }

  const dosDirectory = !madeByUnix && (entry.externalFileAttributes & DOS_DIRECTORY_BIT) !== 0;
  return namedDirectory || dosDirectory;
}

async function ensureDirectory(path: string) {
  const info = await lstat(path);
  if (!info.isDirectory() || info.isSymbolicLink()) {
    throw new Error(`unsupported entry type in GTFS archive: ${categoryName(path)}`);
  }
}
