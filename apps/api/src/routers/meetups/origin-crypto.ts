import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from 'node:crypto';

import {
  journeySchema,
  meetupOriginSchema,
  type Journey,
  type MeetupOrigin,
} from '@via/contract';
import type { EncryptedMeetupOrigin } from '@via/db/schema';

export type MeetupOriginEncryptionKey = {
  version: number;
  key: Uint8Array;
};

export type MeetupOriginCipher = {
  encrypt(origin: MeetupOrigin): EncryptedMeetupOrigin;
  decrypt(value: EncryptedMeetupOrigin): MeetupOrigin;
  encryptJourney(journey: Journey): EncryptedMeetupOrigin;
  decryptJourney(value: EncryptedMeetupOrigin): Journey;
};

/** AES-GCM is for server-side encryption at rest; live coordinates use E2EE on iOS. */
export function createMeetupOriginCipher(
  keys: MeetupOriginEncryptionKey[],
): MeetupOriginCipher {
  const normalized = new Map(
    keys.map(({ version, key }) => {
      if (!Number.isInteger(version) || version <= 0) {
        throw new Error('Meetup origin encryption key versions must be positive integers.');
      }
      if (key.byteLength !== 32) {
        throw new Error(`Meetup origin encryption key ${version} must contain 32 bytes.`);
      }
      return [version, Buffer.from(key)] as const;
    }),
  );
  const activeVersion = Math.max(...normalized.keys());
  const activeKey = normalized.get(activeVersion);
  if (!activeKey || !Number.isFinite(activeVersion)) {
    throw new Error('At least one meetup origin encryption key is required.');
  }
  const encryptionKey = Buffer.from(activeKey);

  return {
    encrypt(origin) {
      return encryptJSON(meetupOriginSchema.parse(origin));
    },
    decrypt(value) {
      return meetupOriginSchema.parse(decryptJSON(value));
    },
    encryptJourney(journey) {
      return encryptJSON(journeySchema.parse(journey));
    },
    decryptJourney(value) {
      return journeySchema.parse(decryptJSON(value));
    },
  };

  function encryptJSON(value: unknown): EncryptedMeetupOrigin {
    const nonce = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', encryptionKey, nonce);
    const plaintext = Buffer.from(JSON.stringify(value), 'utf8');
    const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    return {
      keyVersion: activeVersion,
      nonce: nonce.toString('base64url'),
      ciphertext: ciphertext.toString('base64url'),
      authenticationTag: cipher.getAuthTag().toString('base64url'),
    };
  }

  function decryptJSON(value: EncryptedMeetupOrigin): unknown {
    const key = normalized.get(value.keyVersion);
    if (!key) throw new Error(`Unknown meetup origin encryption key ${value.keyVersion}.`);
    const decipher = createDecipheriv(
      'aes-256-gcm',
      key,
      Buffer.from(value.nonce, 'base64url'),
    );
    decipher.setAuthTag(Buffer.from(value.authenticationTag, 'base64url'));
    const plaintext = Buffer.concat([
      decipher.update(Buffer.from(value.ciphertext, 'base64url')),
      decipher.final(),
    ]);
    return JSON.parse(plaintext.toString('utf8')) as unknown;
  }
}

/**
 * Production can rotate comma-separated `version:base64url-key` entries. A
 * deterministic fallback keeps local/test environments usable while still
 * preventing readable origins in a database dump.
 */
export function meetupOriginKeys(raw: string, fallbackSecret: string): MeetupOriginEncryptionKey[] {
  const configured = raw
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => {
      const separator = item.indexOf(':');
      if (separator <= 0) throw new Error('Invalid MEETUP_DATA_ENCRYPTION_KEYS entry.');
      return {
        version: Number(item.slice(0, separator)),
        key: Buffer.from(item.slice(separator + 1), 'base64url'),
      };
    });
  if (configured.length > 0) return configured;
  return [{
    version: 1,
    key: createHash('sha256').update(`meetup-origin:${fallbackSecret}`).digest(),
  }];
}
