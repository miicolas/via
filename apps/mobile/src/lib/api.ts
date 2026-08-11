import { hc } from 'hono/client';
import type { AppType } from '@via/api';

export const apiBaseUrl = process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000';

export const api = hc<AppType>(apiBaseUrl);
