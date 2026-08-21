import { createHmac } from 'node:crypto';

/**
 * OpenAI's `safety_identifier` lets abuse tooling correlate a user's requests
 * without us handing over a real account id. We send an HMAC of the identity
 * keyed by a server secret, never the raw id — so even OpenAI's logs cannot map
 * it back to a Via account, and rotating the secret breaks the correlation.
 */
export function safetyIdentifier(identity: string, secret: string): string {
  return createHmac('sha256', secret).update(identity).digest('hex');
}
