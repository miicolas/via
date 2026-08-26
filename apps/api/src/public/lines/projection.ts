import type { LineDetailResponse, LineStatusesResponse } from '@via/contract';
import type { PublicLineDetail, PublicLineStatuses } from '@via/contract/public';

/**
 * What the blog is allowed to know about a line.
 *
 * The contract is the agreement with the iOS app; nothing here re-exports it.
 * The functions below narrow it on purpose — a browser gets the line's
 * identity, its condition, and the dates and cut segments of what is
 * disrupting it, and not one field more. Adding a procedure to the contract
 * must never widen what a page can read.
 *
 * The shapes themselves live in `@via/contract/public`, a separate entry point
 * the app contract never touches: the site parses what this file produces, and
 * the two must be the same declaration or a renamed field typechecks green on
 * both sides and reaches the browser as `undefined`.
 */

export function toPublicLineStatuses(response: LineStatusesResponse): PublicLineStatuses {
  return {
    source: response.source,
    ...(response.fetchedAt === undefined ? {} : { fetchedAt: response.fetchedAt }),
    lines: response.lines.map((line) => ({
      id: line.route.id,
      mode: line.route.mode,
      shortName: line.route.shortName,
      condition: line.condition,
      activeCount: line.activeCount,
      ...(line.summary === undefined ? {} : { summary: line.summary }),
      ...(line.upcoming === undefined ? {} : { upcoming: line.upcoming }),
    })),
  };
}

/**
 * The line schema is deliberately dropped: the site ships its own committed
 * snapshot of station order, so a strip draws with no network at all and this
 * response only ever adds what is happening today. `message` is dropped too —
 * it is IDFM's prose, and an article that quotes the feed verbatim is exactly
 * the thin content the blog exists not to be.
 */
export function toPublicLineDetail(
  response: Pick<LineDetailResponse, 'route' | 'source' | 'fetchedAt' | 'disruptions'>
): PublicLineDetail {
  return {
    line: {
      id: response.route.id,
      mode: response.route.mode,
      shortName: response.route.shortName,
    },
    source: response.source,
    ...(response.fetchedAt === undefined ? {} : { fetchedAt: response.fetchedAt }),
    disruptions: response.disruptions.map((disruption) => ({
      id: disruption.id,
      severity: disruption.severity,
      activity: disruption.activity,
      ...(disruption.cause === undefined ? {} : { cause: disruption.cause }),
      ...(disruption.title === undefined ? {} : { title: disruption.title }),
      periods: disruption.periods,
      impactedSections: disruption.impactedSections.map((section) => ({
        fromName: section.fromName,
        toName: section.toName,
      })),
    })),
  };
}
