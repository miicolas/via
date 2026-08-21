/**
 * IDFM ids reach us wearing whatever prefix the feed that carried them uses:
 * `stop_area:IDFM:71135` from the disruptions bulk, `stop_point:IDFM:463060`
 * from Navitia, bare `IDFM:71135` from our own GTFS import. Strip the prefix and
 * every source lines up with the ids the database stores.
 *
 * The prefix is not noise, though — it says which level of the referential the
 * id names. `stop_area` is a station, `stop_point` is one direction's quay, and
 * the two must not be confused: carriage advice is keyed by quay precisely
 * because it flips between a station's two platforms.
 */
export function bareStopId(stopId: string | null | undefined) {
  const match = /^(?:stop_area:|stop_point:)?IDFM:(.+)$/.exec(stopId ?? '');
  return match ? `IDFM:${match[1]}` : undefined;
}
