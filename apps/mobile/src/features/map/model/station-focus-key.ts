/**
 * Identity of a station-focus request; the map skips refocusing when the key
 * matches the last one it handled.
 */
export function stationFocusKey(stationId: string, detentIndex: number) {
  return `${stationId}:${detentIndex}`;
}
