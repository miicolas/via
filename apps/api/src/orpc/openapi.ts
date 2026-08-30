import { OpenAPIGenerator } from '@orpc/openapi';
import { ZodToJsonSchemaConverter } from '@orpc/zod/zod4';
import { contract } from '@via/contract';

const generator = new OpenAPIGenerator({
  schemaConverters: [new ZodToJsonSchemaConverter()],
});

const meetupCapabilityOperations = new Set([
  'meetups.get',
  'meetups.update',
  'meetups.cancel',
  'meetups.createInvitation',
  'meetups.revokeInvitation',
  'meetups.configureParticipant',
  'meetups.leave',
  'meetups.removeParticipant',
  'meetups.publishLive',
  'meetups.pollLive',
  'meetups.registerDeviceKey',
  'meetups.uploadKeyEnvelopes',
  'meetups.syncKeys',
  'meetups.registerActivity',
  'meetups.unregisterActivity',
]);

const invitationCapabilityOperations = new Set([
  'meetups.previewInvitation',
  'meetups.acceptInvitation',
  'meetups.declineInvitation',
  'friends.previewInvitation',
  'friends.acceptInvitation',
]);

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
          meetupCapability: {
            type: 'apiKey',
            in: 'header',
            name: 'x-via-meetup-token',
            description: 'Capacité privée du Participant, jamais placée dans une URL.',
          },
        },
      },
      // Document-level default; the public health operations opt out below.
      security: [{ bearerAuth: [] }],
    })
    .then((generated) => {
      for (const path of Object.values(generated.paths ?? {})) {
        if (!path || typeof path !== 'object') continue;
        for (const candidate of Object.values(path)) {
          if (!candidate || typeof candidate !== 'object') continue;
          const operation = candidate as {
            operationId?: string;
            parameters?: Array<Record<string, unknown>>;
            security?: Array<Record<string, string[]>>;
          };
          if (operation.operationId === 'health' ||
              (operation.operationId && invitationCapabilityOperations.has(operation.operationId))) {
            operation.security = [];
          }
          if (operation.operationId && meetupCapabilityOperations.has(operation.operationId)) {
            operation.parameters = [
              ...(operation.parameters ?? []),
              {
                name: 'x-via-meetup-token',
                in: 'header',
                required: false,
                description: 'Capacité privée du Participant. Un compte authentifié peut aussi autoriser la requête.',
                schema: { type: 'string', pattern: '^[A-Za-z0-9_-]{43}$' },
              },
            ];
            operation.security = [{ bearerAuth: [] }, { meetupCapability: [] }];
          }
        }
      }
      return generated;
    });

  return document;
}
