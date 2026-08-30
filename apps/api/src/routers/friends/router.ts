import { ORPCError } from '@orpc/server';

import { implementer, type ApiContext } from '../../orpc/implementer';
import {
  acceptFriendInvitation,
  createFriendInvitation,
  FriendServiceError,
  listFriends,
  previewFriendInvitation,
  removeFriend,
} from './service';

function accountUser(context: ApiContext): string {
  if (!context.userId || context.isAnonymous) throw new ORPCError('UNAUTHORIZED');
  return context.userId;
}

function mapped<T>(work: () => Promise<T>): Promise<T> {
  return work().catch((error: unknown) => {
    if (!(error instanceof FriendServiceError)) throw error;
    if (error.reason === 'not_found') throw new ORPCError('NOT_FOUND');
    if (error.reason === 'self' || error.reason === 'already_claimed') {
      throw new ORPCError('CONFLICT');
    }
    throw new ORPCError('BAD_REQUEST');
  });
}

const list = implementer.friends.list.handler(async ({ context }) =>
  listFriends(accountUser(context))
);

const createInvitation = implementer.friends.createInvitation.handler(async ({ input, context }) =>
  mapped(() => createFriendInvitation({
    userId: accountUser(context),
    idempotencyKey: input.idempotencyKey,
  }))
);

const previewInvitation = implementer.friends.previewInvitation.handler(async ({ input }) =>
  mapped(() => previewFriendInvitation(input.token))
);

const acceptInvitation = implementer.friends.acceptInvitation.handler(async ({ input, context }) =>
  mapped(() => acceptFriendInvitation({ token: input.token, userId: accountUser(context) }))
);

const remove = implementer.friends.remove.handler(async ({ input, context }) => ({
  removed: await removeFriend(accountUser(context), input.userId),
}));

export const friendsRouter = {
  list,
  createInvitation,
  previewInvitation,
  acceptInvitation,
  remove,
};
