import { importPKCS8, SignJWT } from "jose";

import type { APNsEnvironment } from "@via/contract";

import {
  deviceNotificationPayload as buildDeviceNotificationPayload,
  type DeviceNotification,
} from "./payload";

export type APNsPriority = 5 | 10;

export type APNsPayload = Record<string, unknown>;

export type APNsFailureScope = "device" | "global";

export interface APNsRequest {
  token: string;
  bundleId: string;
  environment: APNsEnvironment;
  pushType: "alert";
  priority: APNsPriority;
  payload: APNsPayload;
  collapseId?: string;
  expirationAt?: Date;
}

export interface APNsDelivery {
  apnsId: string | null;
}

export interface APNsProvider {
  send(request: APNsRequest): Promise<APNsDelivery>;
}

export class APNsError extends Error {
  constructor(
    readonly statusCode: number,
    readonly reason: string,
    readonly apnsId: string | null,
    readonly invalidatedAt?: Date,
  ) {
    super(`APNs rejected the request: ${reason} (${statusCode})`);
    this.name = "APNsError";
  }

  get isInvalidToken(): boolean {
    return [
      "BadDeviceToken",
      "DeviceTokenNotForTopic",
      "ExpiredToken",
      "Unregistered",
    ].includes(this.reason);
  }

  get isRetryable(): boolean {
    return (
      this.reason === "ExpiredProviderToken" ||
      this.reason === "IdleTimeout" ||
      this.reason === "TooManyRequests" ||
      this.reason === "TooManyProviderTokenUpdates" ||
      this.statusCode === 429 ||
      this.statusCode >= 500
    );
  }

  get failureScope(): APNsFailureScope {
    const globalReasons = [
      "BadCertificate",
      "BadCertificateEnvironment",
      "BadCollapseId",
      "BadExpirationDate",
      "BadMessageId",
      "BadPath",
      "BadPriority",
      "BadTopic",
      "DuplicateHeaders",
      "ExpiredProviderToken",
      "Forbidden",
      "IdleTimeout",
      "InvalidProviderToken",
      "InvalidPushType",
      "MissingProviderToken",
      "MissingDeviceToken",
      "MissingTopic",
      "MethodNotAllowed",
      "PayloadEmpty",
      "PayloadTooLarge",
      "TopicDisallowed",
      "TooManyProviderTokenUpdates",
    ];
    if (globalReasons.includes(this.reason)) return "global";
    if (this.statusCode >= 500) return "global";
    if ([404, 405, 413].includes(this.statusCode)) return "global";
    if (this.statusCode === 429 && this.reason !== "TooManyRequests") {
      return "global";
    }
    return "device";
  }
}

export interface CreateAPNsProviderOptions {
  teamId: string;
  keyId: string;
  privateKey: string;
  fetcher?: APNsFetcher;
  now?: () => Date;
  requestTimeoutMilliseconds?: number;
}

export type APNsRequestInit = RequestInit & {
  protocol?: "http2" | "http1.1";
};

export type APNsFetcher = (
  input: string | URL,
  init?: APNsRequestInit,
) => Promise<Response>;

/**
 * Stateless APNs provider using Apple's token-based authentication. The JWT
 * is cached for 50 minutes, while each request still chooses the APNs host
 * from the token's registered sandbox/production environment.
 */
export function createAPNsProvider(
  options: CreateAPNsProviderOptions,
): APNsProvider {
  const fetcher =
    options.fetcher ??
    ((input: string | URL, init?: APNsRequestInit) =>
      fetch(input, init as RequestInit));
  const now = options.now ?? (() => new Date());
  const requestTimeoutMilliseconds =
    options.requestTimeoutMilliseconds ?? 15_000;
  const normalizedPrivateKey = options.privateKey.replace(/\\n/g, "\n");
  let signingKey: Awaited<ReturnType<typeof importPKCS8>> | undefined;
  let cachedToken: { value: string; expiresAt: number } | undefined;
  let pendingToken: Promise<string> | undefined;

  async function authorizationToken(): Promise<string> {
    const nowSeconds = Math.floor(now().getTime() / 1_000);
    if (cachedToken && cachedToken.expiresAt - nowSeconds > 60) {
      return cachedToken.value;
    }
    const tokenPromise =
      pendingToken ??
      (async () => {
        signingKey ??= await importPKCS8(normalizedPrivateKey, "ES256");
        const value = await new SignJWT({})
          .setProtectedHeader({ alg: "ES256", kid: options.keyId })
          .setIssuer(options.teamId)
          .setIssuedAt(nowSeconds)
          .sign(signingKey);
        cachedToken = { value, expiresAt: nowSeconds + 50 * 60 };
        return value;
      })();
    pendingToken = tokenPromise;
    try {
      return await tokenPromise;
    } finally {
      if (pendingToken === tokenPromise) pendingToken = undefined;
    }
  }

  return {
    async send(request) {
      const host =
        request.environment === "sandbox"
          ? "https://api.sandbox.push.apple.com"
          : "https://api.push.apple.com";
      for (let attempt = 0; attempt < 2; attempt += 1) {
        const apnsId = crypto.randomUUID();
        const providerToken = await authorizationToken();
        const response = await fetcher(`${host}/3/device/${request.token}`, {
          method: "POST",
          protocol: "http2",
          headers: {
            authorization: `bearer ${providerToken}`,
            "apns-topic": request.bundleId,
            "apns-push-type": request.pushType,
            "apns-priority": String(request.priority),
            "apns-id": apnsId,
            "content-type": "application/json",
            ...(request.collapseId
              ? { "apns-collapse-id": request.collapseId }
              : {}),
            ...(request.expirationAt
              ? {
                  "apns-expiration": String(
                    Math.floor(request.expirationAt.getTime() / 1_000),
                  ),
                }
              : {}),
          },
          body: JSON.stringify(request.payload),
          signal: AbortSignal.timeout(requestTimeoutMilliseconds),
        });

        const responseApnsId = response.headers.get("apns-id") ?? apnsId;
        if (response.ok) return { apnsId: responseApnsId };

        const body = await response.text();
        let reason = `HTTP_${response.status}`;
        let invalidatedAt: Date | undefined;
        try {
          const parsed = JSON.parse(body) as {
            reason?: unknown;
            timestamp?: unknown;
          };
          if (typeof parsed.reason === "string" && parsed.reason.length > 0) {
            reason = parsed.reason;
          }
          if (
            typeof parsed.timestamp === "number" &&
            Number.isFinite(parsed.timestamp)
          ) {
            invalidatedAt = new Date(parsed.timestamp);
          }
        } catch {
          // APNs can return an empty body for transport-level failures.
        }
        if (reason === "ExpiredProviderToken" && attempt === 0) {
          if (cachedToken?.value === providerToken) cachedToken = undefined;
          continue;
        }
        throw new APNsError(
          response.status,
          reason,
          responseApnsId,
          invalidatedAt,
        );
      }
      throw new Error("APNs provider token retry exhausted.");
    },
  };
}

export function deviceNotificationPayload(
  notification: DeviceNotification,
): APNsPayload {
  return buildDeviceNotificationPayload(notification);
}

export type { DeviceNotification } from "./payload";
