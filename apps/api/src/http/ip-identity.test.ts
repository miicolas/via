import { expect, test } from 'bun:test';

import { requestIPHash, requestIP } from './ip-identity';

test('uses the trusted edge address and returns only a stable HMAC', () => {
  const request = new Request('https://via.example/api/reports', {
    headers: { 'cf-connecting-ip': '203.0.113.7', 'x-forwarded-for': '198.51.100.2' },
  });
  expect(requestIP(request)).toBe('203.0.113.7');
  expect(requestIPHash(request, 'secret')).toBe(requestIPHash(request, 'secret'));
  expect(requestIPHash(request, 'secret')).not.toContain('203.0.113.7');
});
