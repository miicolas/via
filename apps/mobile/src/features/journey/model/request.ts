import type { Coordinate, JourneyDestination } from '@via/contract';

export type JourneyRequest = {
  key: string;
  origin: Coordinate;
  destination: JourneyDestination;
};

export const journeyRequestKey = (
  origin: Coordinate,
  destination: JourneyDestination,
  retryGeneration = 0
) => {
  return [
    origin.latitude.toFixed(5),
    origin.longitude.toFixed(5),
    destination.kind,
    destination.id,
    destination.coordinate.latitude.toFixed(5),
    destination.coordinate.longitude.toFixed(5),
    retryGeneration,
  ].join(':');
};
