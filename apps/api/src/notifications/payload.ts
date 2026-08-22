import { createHash } from 'node:crypto';

const encoder = new TextEncoder();

export type DeviceNotification = {
  title: string;
  body: string;
  subtitle?: string;
  sound?: string;
  badge?: number;
  threadId?: string;
  categoryId?: string;
  interruptionLevel?: 'passive' | 'active' | 'timeSensitive' | 'critical';
  relevanceScore?: number;
  collapseId?: string;
  expirationAt?: Date;
  data?: Record<string, unknown>;
};

/** Stable, short identifiers are safe for both Redis keys and APNs headers. */
export function stableIdentifierHash(value: string): string {
  return createHash('sha256').update(value).digest('hex').slice(0, 16);
}

/** Truncates by UTF-8 bytes without splitting a Unicode scalar. */
export function truncateUTF8(value: string, maximumBytes: number): string {
  if (maximumBytes <= 0) return '';
  if (encoder.encode(value).byteLength <= maximumBytes) return value;

  const suffix = '…';
  const suffixBytes = encoder.encode(suffix).byteLength;
  if (maximumBytes <= suffixBytes) return '';

  let result = '';
  let byteLength = 0;
  for (const character of value) {
    const characterBytes = encoder.encode(character).byteLength;
    if (byteLength + characterBytes + suffixBytes > maximumBytes) break;
    result += character;
    byteLength += characterBytes;
  }
  return result + suffix;
}

export function deviceNotificationPayload(
  notification: DeviceNotification,
): Record<string, unknown> {
  const alert = {
    title: notification.title,
    body: notification.body,
    ...(notification.subtitle ? { subtitle: notification.subtitle } : {}),
  };

  return {
    aps: {
      alert,
      sound: notification.sound ?? 'default',
      ...(notification.badge === undefined ? {} : { badge: notification.badge }),
      ...(notification.threadId ? { 'thread-id': notification.threadId } : {}),
      ...(notification.categoryId ? { category: notification.categoryId } : {}),
      ...(notification.interruptionLevel
        ? { 'interruption-level': notification.interruptionLevel }
        : {}),
      ...(notification.relevanceScore === undefined
        ? {}
        : { 'relevance-score': notification.relevanceScore }),
    },
    ...(notification.data ?? {}),
  };
}

export function payloadByteLength(notification: DeviceNotification): number {
  return encoder.encode(JSON.stringify(deviceNotificationPayload(notification))).byteLength;
}

/** Fits the whole APNs JSON envelope, not just the alert body. */
export function fitDeviceNotification(
  notification: DeviceNotification,
  maximumBytes = 4_096,
): DeviceNotification {
  const fits = (candidate: DeviceNotification) =>
    payloadByteLength(candidate) <= maximumBytes &&
    encoder.encode(JSON.stringify(candidate)).byteLength <= maximumBytes;

  if (fits(notification)) return notification;

  let low = 0;
  let high = encoder.encode(notification.body).byteLength;
  let best = truncateUTF8(notification.body, 1);

  while (low <= high) {
    const middle = Math.floor((low + high) / 2);
    const candidate = {
      ...notification,
      body: truncateUTF8(notification.body, middle),
    };
    if (fits(candidate)) {
      best = candidate.body;
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }

  const fitted = { ...notification, body: best };
  if (fits(fitted)) return fitted;

  // A pathological title/data payload can leave no room for the body. Keep a
  // valid, useful alert by trimming the title as a final bounded fallback.
  low = 0;
  high = encoder.encode(notification.title).byteLength;
  let title = '';
  while (low <= high) {
    const middle = Math.floor((low + high) / 2);
    const candidate = {
      ...fitted,
      title: truncateUTF8(notification.title, middle),
    };
    if (fits(candidate)) {
      title = candidate.title;
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }
  const bounded = { ...fitted, title };
  if (fits(bounded)) return bounded;

  // Caller-supplied metadata is not trusted to be small. Once the human
  // text has been exhausted, discard optional custom data before allowing a
  // provider-sized payload to escape this boundary.
  const metadataFree: DeviceNotification = {
    title: bounded.title,
    body: bounded.body,
    sound: bounded.sound,
    badge: bounded.badge,
    threadId: bounded.threadId,
    categoryId: bounded.categoryId,
    interruptionLevel: bounded.interruptionLevel,
    relevanceScore: bounded.relevanceScore,
    collapseId: bounded.collapseId,
    expirationAt: bounded.expirationAt,
  };
  if (fits(metadataFree)) return metadataFree;

  // Thread/category identifiers are controlled by Via, but this final guard
  // keeps the helper total if a future caller passes an oversized identifier.
  return { title: '', body: '' };
}

export { encoder as notificationTextEncoder };
