import { describe, expect, test } from "bun:test";
import { Hono } from "hono";

import type { AppEnv } from "../http/app-env";
import type { AuthSession } from "./auth";
import { createRequireAuth } from "./session";

function authenticatedSession(): AuthSession {
  return {
    session: {
      id: "session",
      userId: "user",
      token: "server-only-token",
      expiresAt: new Date(Date.now() + 60_000),
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    user: {
      id: "user",
      email: "person@example.com",
      emailVerified: true,
      name: "Person",
      image: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  };
}

describe("authentication middleware", () => {
  test("keeps health, OpenAPI and Better Auth routes public", async () => {
    let lookupCount = 0;
    const app = new Hono<AppEnv>();
    app.use(
      "*",
      createRequireAuth(async () => {
        lookupCount += 1;
        return { response: null, headers: new Headers() };
      }),
    );
    app.get("*", (context) => context.text("public"));

    for (const path of [
      "/api/health",
      "/api/openapi.json",
      "/api/auth/get-session",
    ]) {
      expect((await app.request(path)).status).toBe(200);
    }
    expect(lookupCount).toBe(0);
  });

  test("rejects a protected route when Better Auth cannot validate the Bearer", async () => {
    const app = new Hono<AppEnv>();
    app.use(
      "*",
      createRequireAuth(async () => ({
        response: null,
        headers: new Headers(),
      })),
    );
    app.get("*", (context) => context.text("protected"));

    const response = await app.request("/api/search");

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({
      error: {
        code: "unauthorized",
        message: "Une connexion Apple valide est requise.",
      },
    });
  });

  test("forwards a renewed signed Bearer and marks protected responses private", async () => {
    const app = new Hono<AppEnv>();
    app.use(
      "*",
      createRequireAuth(async () => ({
        response: authenticatedSession(),
        headers: new Headers({ "set-auth-token": "header.payload.signature" }),
      })),
    );
    app.get("*", (context) =>
      context.json({ userId: context.var.authSession.user.id }),
    );

    const response = await app.request("/rpc/network.stations");

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private");
    expect(response.headers.get("set-auth-token")).toBe(
      "header.payload.signature",
    );
    expect(await response.json()).toEqual({ userId: "user" });
  });
});
