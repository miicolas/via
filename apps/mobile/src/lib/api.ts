import { hc } from 'hono/client';
import type { AppType } from '@via/api';

/**
 * Typed client for `apps/api`. Routes and response shapes come straight from
 * the server's `AppType`, so a broken route is a type error at build time.
 *
 * `localhost` only resolves from the simulator / web. On a physical device set
 * EXPO_PUBLIC_API_URL to your machine's LAN address (e.g. http://192.168.1.20:3000).
 */
export const apiBaseUrl = process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000';

export const api = hc<AppType>(apiBaseUrl);
