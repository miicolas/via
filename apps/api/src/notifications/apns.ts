import { importPKCS8, SignJWT } from "jose";

import type { APNsEnvironment } from "@via/contract";

export type APNsPushType = "alert" | "liveactivity";
export type APNsPriority = 5 | 10;

export type APNsPayload = Record<string, unknown>;

export interface APNsRequest {
  token: string;
  bundleId: string;
  environment: APNsEnvironment;
  pushType: APNsPushType;
  priority: APNsPriority;
  payload: APNsPayload;
  collapseId?: string;
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
  ) {
    super(`APNs rejected the request: ${reason} (${statusCode})`);
    this.name = "APNsError";
  }

  get isInvalidToken(): boolean {
    return [
      "BadDeviceToken",
      "DeviceTokenNotForTopic",
      "Unregistered",
    ].includes(this.reason);
  }
}

export interface CreateAPNsProviderOptions {
  teamId: string;
  keyId: string;
  privateKey: string;
  fetcher?: APNsFetcher;
  now?: () => Date;
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
  const normalizedPrivateKey = options.privateKey.replace(/\\n/g, "\n");
  let signingKey: Awaited<ReturnType<typeof importPKCS8>> | undefined;
  let cachedToken: { value: string; expiresAt: number } | undefined;

  async function authorizationToken(): Promise<string> {
    const nowSeconds = Math.floor(now().getTime() / 1_000);
    if (cachedToken && cachedToken.expiresAt - nowSeconds > 60) {
      return cachedToken.value;
    }

    signingKey ??= await importPKCS8(normalizedPrivateKey, "ES256");
    const value = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: options.keyId })
      .setIssuer(options.teamId)
      .setIssuedAt(nowSeconds)
      .sign(signingKey);

    cachedToken = { value, expiresAt: nowSeconds + 50 * 60 };
    return value;
  }

  return {
    async send(request) {
      const host =
        request.environment === "sandbox"
          ? "https://api.sandbox.push.apple.com"
          : "https://api.push.apple.com";
      const apnsId = crypto.randomUUID();
      const response = await fetcher(`${host}/3/device/${request.token}`, {
        method: "POST",
        protocol: "http2",
        headers: {
          authorization: `bearer ${await authorizationToken()}`,
          "apns-topic":
            request.pushType === "liveactivity"
              ? `${request.bundleId}.push-type.liveactivity`
              : request.bundleId,
          "apns-push-type": request.pushType,
          "apns-priority": String(request.priority),
          "apns-id": apnsId,
          "content-type": "application/json",
          ...(request.collapseId
            ? { "apns-collapse-id": request.collapseId }
            : {}),
        },
        body: JSON.stringify(request.payload),
      });

      const responseApnsId = response.headers.get("apns-id") ?? apnsId;
      if (response.ok) return { apnsId: responseApnsId };

      const body = await response.text();
      let reason = `HTTP_${response.status}`;
      try {
        const parsed = JSON.parse(body) as { reason?: unknown };
        if (typeof parsed.reason === "string" && parsed.reason.length > 0) {
          reason = parsed.reason;
        }
      } catch {
        // APNs can return an empty body for transport-level failures.
      }
      throw new APNsError(response.status, reason, responseApnsId);
    },
  };
}

export interface DeviceNotification {
  title: string;
  body: string;
  subtitle?: string;
  sound?: string;
  badge?: number;
  collapseId?: string;
  data?: Record<string, unknown>;
}

export function deviceNotificationPayload(
  notification: DeviceNotification,
): APNsPayload {
  const alert = {
    title: notification.title,
    body: notification.body,
    ...(notification.subtitle ? { subtitle: notification.subtitle } : {}),
  };

  return {
    aps: {
      alert,
      sound: notification.sound ?? "default",
      ...(notification.badge === undefined
        ? {}
        : { badge: notification.badge }),
    },
    ...(notification.data ?? {}),
  };
}

export type JourneyActivityContentState = {
  phaseTitle: string;
  instructionTitle: string;
  instructionDetail?: string;
  nextAction?: string;
  line?: {
    shortName: string;
    colorHex: string;
    textColorHex: string;
  };
  nextLine?: {
    shortName: string;
    colorHex: string;
    textColorHex: string;
  };
  /** Swift's default JSONEncoder date strategy: seconds since 2001-01-01. */
  arrivalAt: Date | number;
  isOffline: boolean;
  isArrived: boolean;
  progressFraction: number;
  stopsRemaining?: number;
  alightStopName?: string;
};

export interface JourneyActivityAttributesPayload {
  journeyID: string;
}

/** Matches Foundation's default JSON encoding for `Date` in Codable state. */
export function swiftReferenceDateSeconds(date: Date): number {
  return date.getTime() / 1_000 - 978_307_200;
}

function encodeActivityContentState(state: JourneyActivityContentState) {
  return {
    ...state,
    ...(state.arrivalAt instanceof Date
      ? { arrivalAt: swiftReferenceDateSeconds(state.arrivalAt) }
      : {}),
  };
}

export function liveActivityPayload(input: {
  event: "start" | "update" | "end";
  contentState?: JourneyActivityContentState;
  attributes?: JourneyActivityAttributesPayload;
  dismissalDate?: Date;
  alert?: { title: string; body: string };
  now?: Date;
}): APNsPayload {
  const aps: Record<string, unknown> = {
    timestamp: Math.floor((input.now ?? new Date()).getTime() / 1_000),
    event: input.event,
    ...(input.contentState
      ? { "content-state": encodeActivityContentState(input.contentState) }
      : {}),
    ...(input.dismissalDate
      ? { "dismissal-date": Math.floor(input.dismissalDate.getTime() / 1_000) }
      : {}),
    ...(input.alert ? { alert: input.alert } : {}),
  };

  if (input.event === "start") {
    if (!input.attributes)
      throw new Error("A Live Activity start needs attributes.");
    aps["attributes-type"] = "JourneyActivityAttributes";
    aps.attributes = input.attributes;
  }

  return { aps };
}
