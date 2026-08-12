/**
 * Conversions between our GTFS ids and the STIF refs PRIM speaks.
 *
 * Rules from the official « OpenData_TR » identification annex: a stop zone is
 * `STIF:StopArea:SP:{n}:`, a line is `STIF:Line::{code}:` — where `n`/`code`
 * are the GTFS ids without their `IDFM:` prefix (our parent stations are
 * `IDFM:71264`, our routes `IDFM:C01371`). Validated against the live API by
 * `scripts/spike-prim-mapping.ts`.
 */

export function toMonitoringRef(stationId: string): string {
  return `STIF:StopArea:SP:${bareId(stationId)}:`;
}

/** Reads a `STIF:Line::{code}:` ref off a PRIM response. Null when the ref is not a line. */
export function routeIdOfLineRef(lineRef: string): string | null {
  const match = /^STIF:Line::([^:]+):$/.exec(lineRef);
  return match ? `IDFM:${match[1]}` : null;
}

function bareId(prefixedId: string): string {
  return prefixedId.replace(/^IDFM:/, '');
}
