import type {
  JourneyDestination,
  JourneysResponse,
  Coordinate,
} from '@via/contract';

export type JourneyRequest = {
  key: string;
  origin: Coordinate;
  destination: JourneyDestination;
};

export type SettledJourney = {
  key: string;
  response?: JourneysResponse;
};

export type JourneyState =
  | { status: 'idle' }
  | { status: 'planning'; request: JourneyRequest }
  | { status: 'ready'; request: JourneyRequest; response: JourneysResponse }
  | { status: 'error'; request: JourneyRequest };

export function journeyState(
  request: JourneyRequest | undefined,
  settled?: SettledJourney
): JourneyState {
  if (!request) return { status: 'idle' };
  if (!settled || settled.key !== request.key) return { status: 'planning', request };
  if (!settled.response) return { status: 'error', request };
  return { status: 'ready', request, response: settled.response };
}

export const journeyRequestKey = (
  origin: Coordinate,
  destination: JourneyDestination,
  nonce = 0
) => {
  return [
    origin.latitude.toFixed(5),
    origin.longitude.toFixed(5),
    destination.kind,
    destination.id,
    destination.coordinate.latitude.toFixed(5),
    destination.coordinate.longitude.toFixed(5),
    nonce,
  ].join(':');
};
