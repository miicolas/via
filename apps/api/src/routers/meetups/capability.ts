import { createHash, createHmac } from 'node:crypto';

export function capabilityToken(namespace: string, idempotencyKey: string, secret: string): string {
  return createHmac('sha256', secret)
    .update(`${namespace}:${idempotencyKey}`)
    .digest('base64url');
}

export function capabilityTokenHash(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
