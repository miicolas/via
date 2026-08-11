type Coordinate = { latitude: number; longitude: number };

type NetworkMap = {
  routes: Array<{
    id: string;
    shortName: string;
    segments: Array<{ coordinates: Coordinate[] }>;
  }>;
  stations: Array<{
    id: string;
    name: string;
    routeIds: string[];
    positions: Record<string, Coordinate>;
  }>;
};

const apiUrl = process.env.API_URL ?? 'http://localhost:3010';
const response = await fetch(`${apiUrl}/api/network/map`);
if (!response.ok) throw new Error(`Map API returned ${response.status}`);

const network = (await response.json()) as NetworkMap;
const routesById = new Map(network.routes.map((route) => [route.id, route]));

function distanceToSegment(point: Coordinate, start: Coordinate, end: Coordinate) {
  const latitudeRadians = (point.latitude * Math.PI) / 180;
  const longitudeScale = 111_320 * Math.cos(latitudeRadians);
  const latitudeScale = 111_320;
  const startX = (start.longitude - point.longitude) * longitudeScale;
  const startY = (start.latitude - point.latitude) * latitudeScale;
  const endX = (end.longitude - point.longitude) * longitudeScale;
  const endY = (end.latitude - point.latitude) * latitudeScale;
  const deltaX = endX - startX;
  const deltaY = endY - startY;
  const denominator = deltaX * deltaX + deltaY * deltaY;
  const progress = Math.max(
    0,
    Math.min(1, denominator === 0 ? 0 : -(startX * deltaX + startY * deltaY) / denominator)
  );
  return Math.hypot(startX + progress * deltaX, startY + progress * deltaY);
}

function distanceToRoute(point: Coordinate, route: NetworkMap['routes'][number]) {
  let nearest = Number.POSITIVE_INFINITY;
  for (const segment of route.segments) {
    for (let index = 1; index < segment.coordinates.length; index += 1) {
      nearest = Math.min(
        nearest,
        distanceToSegment(point, segment.coordinates[index - 1]!, segment.coordinates[index]!)
      );
    }
  }
  return nearest;
}

const failures: Array<{ station: string; line: string; distance: number }> = [];
for (const station of network.stations) {
  for (const routeId of station.routeIds) {
    const route = routesById.get(routeId);
    const position = station.positions?.[routeId];
    if (!route || !position) {
      failures.push({ station: station.name, line: route?.shortName ?? routeId, distance: Infinity });
      continue;
    }
    const distance = distanceToRoute(position, route);
    if (distance > 1) failures.push({ station: station.name, line: route.shortName, distance });
  }
}

if (failures.length > 0) {
  console.error(
    JSON.stringify(
      failures
        .sort((first, second) => second.distance - first.distance)
        .slice(0, 20)
        .map((failure) => ({ ...failure, distance: Math.round(failure.distance) })),
      null,
      2
    )
  );
  throw new Error(`${failures.length} station/line positions are not aligned`);
}

console.log(`${network.stations.length} shared stations are aligned on every serving line.`);
