import { Hono } from 'hono';

import type { AppEnv } from '../../http/app-env';
import { getNetworkMapHandlers } from './handlers/get-network-map';

export const networkRouter = new Hono<AppEnv>().get('/map', ...getNetworkMapHandlers);
