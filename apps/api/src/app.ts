import { type Context, Hono, type Next } from "hono";
import { compress } from "hono/compress";
import { etag } from "hono/etag";
import { logger } from "hono/logger";
import { requestId } from "hono/request-id";

import type { AppEnv } from "./http/app-env";
import { onError } from "./http/error-handler";
import { notFound } from "./http/not-found";
import type { FetchHandler } from "@orpc/server/fetch";

import { openApiHandler, rpcHandler } from "./orpc/handler";
import type { ApiContext } from "./orpc/implementer";
import { getOpenApiDocument } from "./orpc/openapi";
import { auth } from "./auth/auth";
import { requireAuth } from "./auth/session";
import { redis } from "./redis";
import { transitNetworkCacheVersion } from "./routers/departures/network-version";
import { versionedPayloadCache } from "./http/versioned-payload-cache";
import { requestIPHash } from "./http/ip-identity";
import { clientCors, createClientGate } from "./http/client-gate";
import { cityDemandRouter } from "./public/city-demand/router";
import { publicLinesRouter } from "./public/lines/router";
import { publicJourneySharesRouter } from "./public/journey-shares/router";
import { env } from "./env";
import { RAIL_MAP_PATH, RAIL_MAP_RPC_PATH } from "@via/contract";

const app = new Hono<AppEnv>();

app.use(requestId());
app.use(logger());
app.use("/api/*", compress());
app.use("/rpc/*", compress());

/**
 * Two callers exist, and they prove themselves differently.
 *
 * The app ships a shared client key: extractable from any binary by anyone who
 * wants it badly enough, which is exactly why it sits in front of authentication
 * rather than in place of it. What it buys is that the contract, the PRIM quota
 * and the OpenAI budget stop being a public utility for scrapers and cloned
 * clients. The site runs in a browser and can keep no secret at all, so it is
 * recognised by its origin for what it does from the page, and by a server-side
 * key for what it renders.
 *
 * Both gates sit above every router — including Better Auth — so a route added
 * later is private without anyone remembering to make it so.
 */
const clientOrigins = env.VIA_ALLOWED_ORIGINS;
const appCors = clientCors(clientOrigins);
const appGate = createClientGate({
  label: "app",
  keys: env.VIA_APP_CLIENT_KEYS,
  // The platform health probe carries no key and learns nothing from the answer.
  exempt: ["/api/health"],
});

app.use("/api/*", appCors);
app.use("/rpc/*", appCors);
app.use("/api/*", appGate);
app.use("/rpc/*", appGate);

/** Better Auth keeps its native ID-token flow outside the oRPC contract. */
app.on(["GET", "POST"], "/api/auth/*", (c) => auth.handler(c.req.raw));

/**
 * The marketing site's own surface: the coverage poll, and the line conditions
 * its blog renders beside articles about network works. Mounted above
 * `requireAuth` because the caller is a browser with no account and no app —
 * everything under `/public` is reachable without a session, and says so in its
 * prefix. It is the site's surface, though, not everyone's: the gate below asks
 * for the site's origin, or for its server-side key when Next renders.
 *
 * Each mount is a hand-written projection, never the contract re-exported.
 * That is what keeps ADR 0003 true — a procedure added to the contract must
 * not become public because a route here happened to forward it.
 */
app.use("/public/*", clientCors(clientOrigins));
app.use(
  "/public/*",
  createClientGate({
    label: "site",
    keys: env.VIA_SITE_CLIENT_KEYS,
    origins: clientOrigins,
  }),
);
app.route("/public/city-demand", cityDemandRouter);
app.route("/public/lines", publicLinesRouter);
app.route("/public/journey-shares", publicJourneySharesRouter);

app.use("/api/*", requireAuth);
app.use("/rpc/*", requireAuth);

/**
 * The rail map is the one payload big enough for re-encoding it per request to
 * show up: 1.14 MB that only changes when a scheduled network import bumps the
 * network version. Mounted here — inside `compress()`, outside `etag()` — so
 * the miss path still produces hono's own ETag while hits skip the handler,
 * the zod revalidation, the digest and the gzip entirely. Both transports
 * serve the same procedure, so both get their own entry.
 */
const railMapCache = versionedPayloadCache(() =>
  transitNetworkCacheVersion(redis),
);
app.use(`/api${RAIL_MAP_PATH}`, railMapCache);
app.use(`/rpc${RAIL_MAP_RPC_PATH}`, railMapCache);

app.use("/api/*", etag());
app.use("/rpc/*", etag());

/**
 * The contract, as a document — behind the app gate like the routes it
 * describes, because handing a stranger the map is most of the work of cloning
 * the client. `bun run generate:openapi` reads it from the module, not over HTTP.
 */
app.get("/api/openapi.json", async (c) => c.json(await getOpenApiDocument()));

/**
 * Hono keeps the HTTP edge — logging, CORS, request ids, error envelope — and
 * oRPC owns the two mounts below, both dispatching to the same implemented
 * contract.
 *
 * `matched: false` means no procedure claimed the path, so the request falls
 * through to Hono's `notFound` rather than being swallowed here.
 */
function mount(handler: FetchHandler<ApiContext>, prefix: "/api" | "/rpc") {
  return async (c: Context<AppEnv>, next: Next) => {
    const authSession = c.var.authSession;
    const { matched, response } = await handler.handle(c.req.raw, {
      prefix,
      context: {
        userId: authSession?.user.id,
        isAnonymous: authSession?.user.isAnonymous ?? undefined,
        // Lazy: only a procedure that needs to tell callers apart pays the HMAC.
        requestIPHash: () => requestIPHash(c.req.raw, env.BETTER_AUTH_SECRET),
      },
    });

    if (matched) return response;

    await next();
  };
}

app.use("/api/*", mount(openApiHandler, "/api"));
app.use("/rpc/*", mount(rpcHandler, "/rpc"));

app.onError(onError);
app.notFound(notFound);

export { app };
