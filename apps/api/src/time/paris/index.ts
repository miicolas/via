/**
 * The single public home for Europe/Paris calendar, clock and formatting.
 *
 * Rules for extending this module:
 * 1. `zone.ts` is private and is never re-exported. Its formatter and timezone
 *    primitives are the only way the leaves talk to Europe/Paris.
 * 2. A leaf never imports `index.ts`; `calendar.ts` imports `day.ts` directly
 *    so the leaves stay acyclic and can be split independently.
 * 3. Callers always import this module (`.../time/paris`), never a leaf. The
 *    internal file layout can therefore evolve without changing call sites.
 */

export * from './calendar';
export * from './day';
export * from './format';
