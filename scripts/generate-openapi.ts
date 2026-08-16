import { getOpenApiDocument } from '../apps/api/src/orpc/openapi';

const snapshotUrl = new URL(
  '../apps/via/via/Shared/Networking/OpenAPI/openapi.json',
  import.meta.url
);

const document = normalizeForSwiftGenerator(await getOpenApiDocument());
const serialized = `${JSON.stringify(document, null, 2)}\n`;

if (process.argv.includes('--check')) {
  const existing = await Bun.file(snapshotUrl).text().catch(() => '');
  if (existing !== serialized) {
    console.error('Le snapshot OpenAPI iOS est obsolète. Exécutez bun run generate:openapi.');
    process.exit(1);
  }
} else {
  await Bun.write(snapshotUrl, serialized);
}

/**
 * Swift OpenAPI Generator aborts on an unconstrained empty schema instead of
 * mapping it to an opaque value, so the iOS snapshot makes that opacity explicit.
 */
function normalizeForSwiftGenerator(value: unknown, parentKey?: string): unknown {
  if (Array.isArray(value)) {
    return value.map((item, index) => normalizeForSwiftGenerator(item, String(index)));
  }

  if (!value || typeof value !== 'object') return value;

  const record = value as Record<string, unknown>;
  if (Object.keys(record).length === 0) {
    if (parentKey === 'latitude' || parentKey === 'longitude') return { type: 'number' };
    return { type: 'object', additionalProperties: true };
  }

  return Object.fromEntries(
    Object.entries(record).map(([key, item]) => [key, normalizeForSwiftGenerator(item, key)])
  );
}
