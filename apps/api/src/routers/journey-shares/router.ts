import { ORPCError } from "@orpc/server";

import { implementer } from "../../orpc/implementer";
import { redis } from "../../redis";
import { withinJourneyShareQuota } from "./rate-limit";
import {
  createJourneyShare,
  getJourneyShare,
  JourneyShareLookupError,
} from "./service";

const create = implementer.journeyShares.create.handler(
  async ({ input, context }) => {
    const identityHash = context.requestIPHash?.();
    if (!identityHash) throw new ORPCError("UNAUTHORIZED");
    if (!(await withinJourneyShareQuota(redis, identityHash))) {
      throw new ORPCError("TOO_MANY_REQUESTS");
    }

    return createJourneyShare({
      input,
      ...(context.userId === undefined ? {} : { ownerUserId: context.userId }),
    });
  },
);

const get = implementer.journeyShares.get.handler(
  async ({ input, context }) => {
    context.resHeaders?.set(
      "Cache-Control",
      "public, max-age=60, s-maxage=60, stale-while-revalidate=300",
    );
    try {
      return await getJourneyShare(input.token);
    } catch (error) {
      if (error instanceof JourneyShareLookupError) {
        throw new ORPCError(
          error.reason === "corrupt" ? "INTERNAL_SERVER_ERROR" : "NOT_FOUND",
        );
      }
      throw error;
    }
  },
);

export const journeySharesRouter = { create, get };
