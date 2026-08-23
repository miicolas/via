import { createHmac } from 'node:crypto';

export function requestIP(request: Request) {
  return request.headers.get('cf-connecting-ip')?.trim() ||
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    'unavailable';
}

/** The raw network address never leaves this stack frame and is never persisted. */
export function requestIPHash(request: Request, secret: string) {
  return createHmac('sha256', secret).update(requestIP(request)).digest('hex');
}
