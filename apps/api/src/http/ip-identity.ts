import { createHmac } from 'node:crypto';
import { isIP } from 'node:net';

const UNAVAILABLE_IP = 'unavailable';

/**
 * Railway's edge is the only trusted source for the remote address. It
 * overwrites X-Real-IP before forwarding the request; the other proxy headers
 * are caller-controlled at this boundary and are deliberately ignored.
 */
export function requestIP(request: Request): string {
  const candidate = request.headers.get('x-real-ip')?.trim();
  return candidate && isIP(candidate) !== 0 ? candidate : UNAVAILABLE_IP;
}

/** The raw network address never leaves this stack frame and is never persisted. */
export function requestIPHash(request: Request, secret: string) {
  return createHmac('sha256', secret).update(requestIP(request)).digest('hex');
}
