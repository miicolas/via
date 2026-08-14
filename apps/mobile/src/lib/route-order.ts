import type { RouteBadge } from '@via/contract';

/**
 * The one display order for lines, wherever badges appear: metro, then RER,
 * then bus; within a mode 1, 2, 3, 3bis, 4… — numeric part first, suffix as
 * tie-breaker. Shared so the map, search rows and departure boards can never
 * disagree on it.
 */
export function compareRoutes(
  a: Pick<RouteBadge, 'mode' | 'shortName'>,
  b: Pick<RouteBadge, 'mode' | 'shortName'>
): number {
  const modeDifference = modeOrder(a.mode) - modeOrder(b.mode);
  if (modeDifference !== 0) return modeDifference;
  const [numberA, suffixA] = routeOrder(a.shortName);
  const [numberB, suffixB] = routeOrder(b.shortName);
  return numberA - numberB || suffixA.localeCompare(suffixB);
}

function modeOrder(mode: RouteBadge['mode']) {
  return { metro: 0, rer: 1, bus: 2 }[mode];
}

function routeOrder(shortName: string) {
  const match = /^(\d+)(.*)$/.exec(shortName);
  if (!match) return [Number.MAX_SAFE_INTEGER, shortName] as const;
  return [Number(match[1]), match[2]] as const;
}
