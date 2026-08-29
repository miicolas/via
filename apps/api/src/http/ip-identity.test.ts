import { expect, test } from 'bun:test';

import { requestIP, requestIPHash } from './ip-identity';

const SECRET = 'test-only-quota-secret';

test('uses a valid Railway IPv4 address and returns only a stable HMAC', () => {
  const request = new Request('https://via.example/api/reports', {
    headers: { 'x-real-ip': '203.0.113.7' },
  });
  expect(requestIP(request)).toBe('203.0.113.7');
  expect(requestIPHash(request, SECRET)).toBe(requestIPHash(request, SECRET));
  expect(requestIPHash(request, SECRET)).not.toContain('203.0.113.7');
});

test('accepts a valid Railway IPv6 address', () => {
  const request = new Request('https://via.example/api/reports', {
    headers: { 'x-real-ip': '2001:db8::7' },
  });

  expect(requestIP(request)).toBe('2001:db8::7');
});

test('ignores forged proxy headers when the Railway address is stable', () => {
  const first = new Request('https://via.example/api/reports', {
    headers: {
      'x-real-ip': '203.0.113.7',
      'cf-connecting-ip': '198.51.100.2',
      'x-forwarded-for': '192.0.2.1, 198.51.100.9',
    },
  });
  const second = new Request('https://via.example/api/reports', {
    headers: {
      'x-real-ip': '203.0.113.7',
      'cf-connecting-ip': '192.0.2.2',
      'x-forwarded-for': '192.0.2.3',
    },
  });

  expect(requestIP(first)).toBe(requestIP(second));
  expect(requestIPHash(first, SECRET)).toBe(requestIPHash(second, SECRET));
});

test('does not invent an identity from untrusted or malformed headers', () => {
  const cases: Record<string, string>[] = [
    {},
    { 'cf-connecting-ip': '203.0.113.7' },
    { 'x-forwarded-for': '198.51.100.2' },
    { 'x-real-ip': '' },
    { 'x-real-ip': '203.0.113.7, 198.51.100.2' },
    { 'x-real-ip': '203.0.113.7:443' },
    { 'x-real-ip': 'not-an-ip' },
  ];

  for (const headers of cases) {
    expect(requestIP(new Request('https://via.example/api/reports', { headers }))).toBe('unavailable');
  }
});

test('hashes different addresses differently without exposing either address', () => {
  const first = new Request('https://via.example/api/reports', {
    headers: { 'x-real-ip': '203.0.113.7' },
  });
  const second = new Request('https://via.example/api/reports', {
    headers: { 'x-real-ip': '2001:db8::8' },
  });

  const firstHash = requestIPHash(first, SECRET);
  const secondHash = requestIPHash(second, SECRET);
  expect(firstHash).not.toBe(secondHash);
  expect(firstHash).not.toContain('203.0.113.7');
  expect(secondHash).not.toContain('2001:db8::8');
});
