import type { DeparturesResponse } from '@via/contract';

/**
 * A network completion, tagged with the station it answered — the same
 * staleness guard as `SettledSearch`: a response in flight when the user
 * switches stations must not paint under the new name.
 */
export type SettledDepartures = {
  forStationId: string;
  response?: DeparturesResponse;
};

export type DeparturesState =
  | { status: 'loading' }
  | { status: 'error' }
  | { status: 'ready'; response: DeparturesResponse };

/**
 * Derives what the departure rows show. A poll refresh does not pass through
 * `loading`: the previous settled answer keeps painting until the fresh one
 * lands, so the minutes never blink back to placeholders.
 */
export function departuresState(
  stationId: string,
  settled?: SettledDepartures
): DeparturesState {
  if (!settled || settled.forStationId !== stationId) return { status: 'loading' };
  if (!settled.response) return { status: 'error' };
  return { status: 'ready', response: settled.response };
}
