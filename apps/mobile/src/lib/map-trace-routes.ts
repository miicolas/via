import type { NetworkRoute } from '@via/contract';

/** Bus geometry is never rendered, even if an upstream payload accidentally carries it. */
export function mapTraceRoutes(routes: NetworkRoute[]): NetworkRoute[] {
  return routes.filter((route) => route.mode !== 'bus');
}
