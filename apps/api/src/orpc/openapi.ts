import { OpenAPIGenerator } from '@orpc/openapi';
import { ZodToJsonSchemaConverter } from '@orpc/zod/zod4';
import { contract } from '@via/contract';

const generator = new OpenAPIGenerator({
  schemaConverters: [new ZodToJsonSchemaConverter()],
});

/**
 * Generated from the contract, not from the server — so the document describes
 * what both sides agreed to, and cannot drift from the handlers the way a
 * hand-maintained spec does.
 *
 * Built lazily and kept, because walking the zod schemas is not free and the
 * document only changes when the process restarts.
 */
let document: Promise<object> | undefined;

export function getOpenApiDocument(): Promise<object> {
  document ??= generator
    .generate(contract, {
      info: {
        title: 'Via API',
        version: '1.0.0',
        description: 'Paris metro, RER, Transilien, tram and bus network for the Via app.',
      },
      servers: [{ url: '/api' }],
      components: {
        securitySchemes: {
          bearerAuth: { type: 'http', scheme: 'bearer' },
        },
      },
      // Document-level default; the public health operations opt out below.
      security: [{ bearerAuth: [] }],
    })
    .then((generated) => {
      for (const operation of Object.values(generated.paths?.['/health'] ?? {})) {
        if (operation && typeof operation === 'object') {
          (operation as { security?: Array<Record<string, string[]>> }).security = [];
        }
      }
      return generated;
    });

  return document;
}
