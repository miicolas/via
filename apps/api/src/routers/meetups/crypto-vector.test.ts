import { readFileSync } from 'node:fs';
import { chacha20poly1305 } from '@noble/ciphers/chacha.js';
import { expect, test } from 'bun:test';

type Vector = {
  key: string;
  nonce: string;
  aad: string;
  plaintext: string;
  combined: string;
};

const vector = JSON.parse(readFileSync(
  new URL('../../../../../fixtures/meetup-crypto-vectors.json', import.meta.url),
  'utf8',
)) as Vector;

test('backend and CryptoKit agree on the opaque precise-presence vector', () => {
  const combined = Buffer.from(vector.combined, 'base64url');
  const nonce = combined.subarray(0, 12);
  const ciphertextAndTag = combined.subarray(12);
  const decipher = chacha20poly1305(
    Buffer.from(vector.key, 'base64url'),
    nonce,
    Buffer.from(vector.aad),
  );
  const plaintext = decipher.decrypt(ciphertextAndTag);

  expect(nonce.toString('base64url')).toBe(vector.nonce);
  expect(Buffer.from(plaintext).toString()).toBe(vector.plaintext);
});
