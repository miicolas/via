import { ORPCError } from '@orpc/server';

import { implementer } from '../../orpc/implementer';
import { MeetupServiceError } from './errors';
import type { createMeetupService } from './service';

type MeetupService = ReturnType<typeof createMeetupService>;

function mapped<T>(work: () => Promise<T>): Promise<T> {
  return work().catch((error: unknown) => {
    if (!(error instanceof MeetupServiceError)) throw error;
    switch (error.reason) {
    case 'unauthorized': throw new ORPCError('UNAUTHORIZED');
    case 'forbidden': throw new ORPCError('FORBIDDEN');
    case 'not_found': throw new ORPCError('NOT_FOUND');
    case 'full':
    case 'conflict': throw new ORPCError('CONFLICT');
    case 'corrupt': throw new ORPCError('INTERNAL_SERVER_ERROR');
    case 'expired':
    case 'revoked':
    case 'invalid_time':
    case 'privacy': throw new ORPCError('BAD_REQUEST');
    }
  });
}

export function createMeetupsRouter(service: MeetupService) {
  const create = implementer.meetups.create.handler(async ({ input, context }) =>
    mapped(() => service.create(input, context))
  );
  const list = implementer.meetups.list.handler(async ({ context }) => service.list(context));
  const get = implementer.meetups.get.handler(async ({ input, context }) => {
    context.resHeaders?.set('Cache-Control', 'private, no-store');
    return mapped(() => service.read(input.meetupId, context));
  });
  const update = implementer.meetups.update.handler(async ({ input, context }) =>
    mapped(() => service.update(input, context))
  );
  const cancel = implementer.meetups.cancel.handler(async ({ input, context }) =>
    mapped(() => service.cancel(input.meetupId, context))
  );
  const createInvitation = implementer.meetups.createInvitation.handler(
    async ({ input, context }) => mapped(() => service.createInvitation(input, context)),
  );
  const previewInvitation = implementer.meetups.previewInvitation.handler(async ({ input }) =>
    mapped(() => service.previewInvitation(input.token))
  );
  const acceptInvitation = implementer.meetups.acceptInvitation.handler(
    async ({ input, context }) => mapped(() => service.acceptInvitation(input, context)),
  );
  const declineInvitation = implementer.meetups.declineInvitation.handler(async ({ input }) =>
    mapped(() => service.declineInvitation(input.token))
  );
  const revokeInvitation = implementer.meetups.revokeInvitation.handler(
    async ({ input, context }) => mapped(() =>
      service.revokeInvitation(input.meetupId, input.invitationId, context)
    ),
  );
  const configureParticipant = implementer.meetups.configureParticipant.handler(
    async ({ input, context }) => mapped(() => service.configureParticipant(input, context)),
  );
  const leave = implementer.meetups.leave.handler(async ({ input, context }) =>
    mapped(() => service.leave(input.meetupId, context))
  );
  const removeParticipant = implementer.meetups.removeParticipant.handler(
    async ({ input, context }) => mapped(() =>
      service.removeParticipant(input.meetupId, input.participantId, context)
    ),
  );
  const publishLive = implementer.meetups.publishLive.handler(async ({ input, context }) =>
    mapped(() => service.publishLive(input, context))
  );
  const pollLive = implementer.meetups.pollLive.handler(async ({ input, context }) => {
    context.resHeaders?.set('Cache-Control', 'private, no-store');
    return mapped(() => service.pollLive(input.meetupId, input.sinceRevision, context));
  });
  const registerDeviceKey = implementer.meetups.registerDeviceKey.handler(
    async ({ input, context }) => mapped(() =>
      service.registerDeviceKey(input.meetupId, input.keyId, input.publicKey, context)
    ),
  );
  const uploadKeyEnvelopes = implementer.meetups.uploadKeyEnvelopes.handler(
    async ({ input, context }) => mapped(() =>
      service.uploadKeyEnvelopes(input.meetupId, input.keyRevision, input.envelopes, context)
    ),
  );
  const syncKeys = implementer.meetups.syncKeys.handler(
    async ({ input, context }) => mapped(() => service.syncKeys(input.meetupId, context)),
  );
  const registerActivity = implementer.meetups.registerActivity.handler(
    async ({ input, context }) => mapped(() => service.registerActivity(input, context)),
  );
  const unregisterActivity = implementer.meetups.unregisterActivity.handler(
    async ({ input, context }) => mapped(() => service.unregisterActivity(input, context)),
  );

  return {
    create,
    list,
    get,
    update,
    cancel,
    createInvitation,
    previewInvitation,
    acceptInvitation,
    declineInvitation,
    revokeInvitation,
    configureParticipant,
    leave,
    removeParticipant,
    publishLive,
    pollLive,
    registerDeviceKey,
    uploadKeyEnvelopes,
    syncKeys,
    registerActivity,
    unregisterActivity,
  };
}
