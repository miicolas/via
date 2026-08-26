import { Hono } from "hono";
import { z } from "zod";

import type { AppEnv } from "../../http/app-env";
import { errorBody } from "../../http/errors";
import {
  getJourneyShare,
  JourneyShareLookupError,
} from "../../routers/journey-shares/service";
import { journeyShareTokenSchema } from "@via/contract";

const notFoundMessage = "Ce lien de trajet est introuvable.";

/**
 * Browser-facing projection for `/trip/[token]`. It intentionally reuses the
 * service's validated output but stays outside the oRPC contract, in line with
 * ADR-0003: the public surface is a hand-written projection, not a private
 * application response forwarded wholesale.
 */
export const publicJourneySharesRouter = new Hono<AppEnv>().get(
  "/:token",
  async (c) => {
    const parsed = journeyShareTokenSchema.safeParse(c.req.param("token"));
    if (!parsed.success)
      return c.json(
        errorBody(c, "journey_share_not_found", notFoundMessage),
        404,
      );

    try {
      const share = await getJourneyShare(parsed.data);
      c.header(
        "Cache-Control",
        "public, max-age=60, s-maxage=60, stale-while-revalidate=300",
      );
      return c.json({
        snapshot: share.snapshot,
        createdAt: share.createdAt,
        expiresAt: share.expiresAt,
      });
    } catch (error) {
      if (!(error instanceof JourneyShareLookupError)) throw error;

      if (error.reason === "corrupt") {
        return c.json(
          errorBody(
            c,
            "journey_share_unavailable",
            "Ce trajet est temporairement indisponible.",
          ),
          503,
        );
      }

      const code = `journey_share_${error.reason}` as const;
      const message =
        error.reason === "expired"
          ? "Ce lien de trajet a expiré."
          : error.reason === "revoked"
            ? "Ce lien de trajet a été supprimé."
            : notFoundMessage;
      return c.json(
        errorBody(c, code, message),
        error.reason === "expired" ? 410 : 404,
      );
    }
  },
);

