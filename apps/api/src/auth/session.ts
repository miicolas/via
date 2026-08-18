import type { Context, Next } from "hono";

import type { AppEnv } from "../http/app-env";
// HOTFIX(no-account): ré-importer ErrorBody en réactivant le rejet 401 ci-dessous.
// import type { ErrorBody } from "../http/errors";
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

    // HOTFIX(no-account): l'app doit être utilisable sans compte pour
    // l'instant. La session reste attachée quand elle existe (le routeur
    // account garde son propre garde UNAUTHORIZED), mais les requêtes
    // anonymes passent. Réactiver le bloc ci-dessous pour ré-imposer la
    // connexion.
    // if (!result.response) {
    //   const body: ErrorBody = {
    //     error: {
    //       code: "unauthorized",
    //       message: "Une connexion Apple valide est requise.",
    //       requestId: c.get("requestId"),
    //     },
    //   };
    //   return c.json(body, 401);
    // }
    if (!result.response) {
      await next();
      return;
    }

    c.set("authSession", result.response);
    const renewedBearer = result.headers.get("set-auth-token");
    if (renewedBearer) c.header("set-auth-token", renewedBearer);
    c.header("Cache-Control", "private");
    await next();
  };
}

export const requireAuth = createRequireAuth();
