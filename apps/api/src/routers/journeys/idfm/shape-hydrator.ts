import type { Coordinate, Journey, JourneyMode } from '@via/contract';

export type JourneyShapeRequest = {
  mode: JourneyMode;
  shortName: string;
};

export type JourneyShapeCandidate = JourneyShapeRequest & {
  coordinates: Coordinate[];
};

export type JourneyShapeLoader = (
  requests: JourneyShapeRequest[]
) => Promise<JourneyShapeCandidate[]>;

const MAX_ENDPOINT_DISTANCE_METERS = 1_000;

export async function hydrateSparseJourneyGeometry(
  journeys: Journey[],
  loadShapes: JourneyShapeLoader
): Promise<Journey[]> {
  const requests = uniqueRequests(
    journeys.flatMap((journey) =>
      journey.sections.flatMap((section) =>
        isSparseTransitSection(section) && section.route
          ? [{ mode: section.route.mode, shortName: section.route.shortName }]
          : []
      )
    )
  );
  if (requests.length === 0) return journeys;

  const candidates = await loadShapes(requests);
  const candidatesByLine = Map.groupBy(candidates, lineKey);

  return journeys.map((journey) => ({
    ...journey,
    sections: journey.sections.map((section) => {
      if (!isSparseTransitSection(section) || !section.route) return section;
      const detailed = bestSegment(
        candidatesByLine.get(lineKey(section.route)) ?? [],
        section.from.coordinate,
        section.to.coordinate,
        section.stops.map((stop) => stop.coordinate)
      );
      if (!detailed || detailed.length <= section.geometry.length) return section;
      return { ...section, geometry: detailed };
    }),
  }));
}

function isSparseTransitSection(section: Journey['sections'][number]) {
  return section.type === 'transit' &&
    section.geometry.length <= Math.max(2, section.stops.length + 1);
}

function uniqueRequests(requests: JourneyShapeRequest[]) {
  return [...new Map(requests.map((request) => [lineKey(request), request])).values()];
}

function lineKey(line: JourneyShapeRequest) {
  return `${line.mode}\u0000${line.shortName.trim().toLocaleUpperCase('fr-FR')}`;
}

function bestSegment(
  candidates: JourneyShapeCandidate[],
  from: Coordinate,
  to: Coordinate,
  stops: Coordinate[]
) {
  let best: { score: number; coordinates: Coordinate[] } | undefined;

  for (const candidate of candidates) {
    if (candidate.coordinates.length < 2) continue;
    const fromIndex = closestCoordinateIndex(candidate.coordinates, from);
    const toIndex = closestCoordinateIndex(candidate.coordinates, to);
    const fromDistance = distanceMeters(candidate.coordinates[fromIndex]!, from);
    const toDistance = distanceMeters(candidate.coordinates[toIndex]!, to);
    if (Math.max(fromDistance, toDistance) > MAX_ENDPOINT_DISTANCE_METERS) continue;

    const sliced = fromIndex <= toIndex
      ? candidate.coordinates.slice(fromIndex, toIndex + 1)
      : candidate.coordinates.slice(toIndex, fromIndex + 1).reverse();
    const stopDistance = stops.length === 0
      ? 0
      : stops.reduce((total, stop) => total + distanceToShape(stop, sliced), 0) / stops.length;
    const score = fromDistance + toDistance + stopDistance;
    const coordinates = deduplicatedCoordinates([from, ...sliced, to]);
    if (!best || score < best.score) best = { score, coordinates };
  }

  return best?.coordinates;
}

function closestCoordinateIndex(coordinates: Coordinate[], target: Coordinate) {
  let bestIndex = 0;
  let bestDistance = Number.POSITIVE_INFINITY;
  for (let index = 0; index < coordinates.length; index += 1) {
    const distance = distanceMeters(coordinates[index]!, target);
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = index;
    }
  }
  return bestIndex;
}

function distanceToShape(coordinate: Coordinate, shape: Coordinate[]) {
  return shape.reduce(
    (nearest, point) => Math.min(nearest, distanceMeters(coordinate, point)),
    Number.POSITIVE_INFINITY
  );
}

function distanceMeters(first: Coordinate, second: Coordinate) {
  const latitudeRadians = (first.latitude * Math.PI) / 180;
  const latitudeScale = 111_320;
  const longitudeScale = latitudeScale * Math.cos(latitudeRadians);
  return Math.hypot(
    (first.latitude - second.latitude) * latitudeScale,
    (first.longitude - second.longitude) * longitudeScale
  );
}

function deduplicatedCoordinates(coordinates: Coordinate[]) {
  return coordinates.filter((coordinate, index) => {
    const previous = coordinates[index - 1];
    return !previous ||
      previous.latitude !== coordinate.latitude ||
      previous.longitude !== coordinate.longitude;
  });
}
