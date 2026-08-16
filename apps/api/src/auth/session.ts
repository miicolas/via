import type { Context, Next } from "hono";

import type { AppEnv } from "../http/app-env";
import type { ErrorBody } from "../http/errors";
import { auth, type AuthSession } from "./auth";

const PUBLIC_API_PATHS = new Set(["/api/health", "/api/openapi.json"]);

type SessionLookup = (headers: Headers) => Promise<{
  response: AuthSession | null;
  headers: Headers;
}>;

const lookupSession: SessionLookup = async (headers) =>
  auth.api.getSession({ headers, returnHeaders: true });

export function createRequireAuth(lookup: SessionLookup = lookupSession) {
  return async function requireAuth(c: Context<AppEnv>, next: Next) {
    if (
      c.req.path.startsWith("/api/auth/") ||
      PUBLIC_API_PATHS.has(c.req.path)
    ) {
      await next();
      return;
    }

    const result = await lookup(c.req.raw.headers);

    if (!result.response) {
      const body: ErrorBody = {
        error: {
          code: "unauthorized",
          message: "Une connexion Apple valide est requise.",
          requestId: c.get("requestId"),
        },
      };
      return c.json(body, 401);
    }

    c.set("authSession", result.response);
    const renewedBearer = result.headers.get("set-auth-token");
    if (renewedBearer) c.header("set-auth-token", renewedBearer);
    c.header("Cache-Control", "private");
    await next();
  };
}

export const requireAuth = createRequireAuth();
