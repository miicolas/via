import type { Coordinate, Journey, JourneyInput, JourneySection } from '@via/contract';

import { toInstant } from '../../../time/paris';

export function parseIdfmJourneys(body: unknown, input: JourneyInput, generatedAt: Date): Journey[] {
  const rows = Array.isArray((body as { journeys?: unknown[] } | null)?.journeys)
    ? ((body as { journeys: unknown[] }).journeys ?? [])
    : [];
  const journeys = rows
    .flatMap((row, index) => parseJourney(row, input, generatedAt, index))
    .slice(0, input.limit);
  return qualifyAlternatives(journeys);
}

function qualifyAlternatives(journeys: Journey[]): Journey[] {
  if (journeys.length === 0) return journeys;
  const qualifiers = new Map<string, Journey['qualifier']>([
    [journeys[0].id, 'recommended'],
  ]);
  const remaining = journeys.slice(1);

  for (const journey of remaining) {
    if (journey.sections.every((section) => section.type === 'walk')) {
      qualifiers.set(journey.id, 'walking');
    }
  }

  assignBest(remaining, qualifiers, 'rapid', (journey) => journey.durationSeconds);
  assignBest(
    remaining,
    qualifiers,
    'less-walking',
    (journey) => journey.walkingDurationSeconds
  );
  assignBest(remaining, qualifiers, 'comfort', (journey) => journey.transferCount);

  return journeys.map((journey) => ({
    ...journey,
    qualifier: qualifiers.get(journey.id) ?? journey.qualifier,
  }));
}

function assignBest(
  journeys: Journey[],
  qualifiers: Map<string, Journey['qualifier']>,
  qualifier: Journey['qualifier'],
  metric: (journey: Journey) => number
) {
  const candidates = journeys.filter((journey) => !qualifiers.has(journey.id));
  const best = candidates.reduce<Journey | undefined>(
    (current, journey) => (!current || metric(journey) < metric(current) ? journey : current),
    undefined
  );
  if (best) qualifiers.set(best.id, qualifier);
}

function parseJourney(
  row: unknown,
  input: JourneyInput,
  generatedAt: Date,
  index: number
): Journey[] {
  const value = row as Record<string, any>;
  const departureAt = navitiaDate(value.departure_date_time);
  const arrivalAt = navitiaDate(value.arrival_date_time);
  if (!departureAt || !arrivalAt) return [];
  const sections = asArray(value.sections).flatMap((section) =>
    toSection(section, input, generatedAt)
  );
  if (sections.length === 0) return [];
  const durationSeconds = Number(value.duration);
  const walkingDurationSeconds = Number(value.durations?.walking ?? value.walking_duration ?? 0);
  const transferCount = Number(value.nb_transfers ?? value.transfers ?? 0);
  const tags = asArray(value.tags).filter((tag): tag is string => typeof tag === 'string');
  return [
    {
      id: `idfm:${index}:${departureAt}:${arrivalAt}`,
      qualifier: qualifierOf(tags, index),
      durationSeconds: Number.isFinite(durationSeconds)
        ? durationSeconds
        : Math.max(0, Date.parse(arrivalAt) - Date.parse(departureAt)) / 1000,
      walkingDurationSeconds: Number.isFinite(walkingDurationSeconds) ? walkingDurationSeconds : 0,
      transferCount: Number.isFinite(transferCount) ? transferCount : 0,
      departureAt,
      arrivalAt,
      status: asArray(value.disruptions).length > 0 ? 'disrupted' : 'normal',
      warnings: asArray(value.disruptions).flatMap((disruption) => {
        const message = (disruption as Record<string, unknown>)?.message;
        return typeof message === 'string' ? [message] : ['Perturbation sur cet itinéraire'];
      }),
      sections,
    },
  ];
}

function toSection(value: unknown, input: JourneyInput, generatedAt: Date): JourneySection[] {
  const section = value as Record<string, any>;
  const type = section.type;
  const from = placeOf(section.from, input.origin, 'Départ');
  const to = placeOf(section.to, input.destination.coordinate, input.destination.name);
  const durationSeconds = Number(section.duration ?? 0);
  const geometry = geometryOf(section.geojson ?? section.shape, from.coordinate, to.coordinate);
  if (type === 'street_network' || type === 'crow_fly') {
    return [{
      type: 'walk',
      durationSeconds: safeSeconds(durationSeconds),
      from,
      to,
      geometry,
      stops: [],
    }];
  }
  if (type === 'transfer') {
    return [{
      type: 'transfer',
      durationSeconds: safeSeconds(durationSeconds),
      from,
      to,
      geometry,
      stops: [],
    }];
  }
  if (type === 'waiting' || type === 'wait') {
    return [{
      type: 'wait',
      durationSeconds: safeSeconds(durationSeconds),
      from,
      to,
      geometry: [],
      stops: [],
    }];
  }
  if (type !== 'public_transport') return [];

  const display = section.display_informations ?? {};
  const line = displayOfLine(display, section);
  const direction = textOf(display.direction) ?? textOf(section.to?.name);
  const stopTimes = asArray(section.stop_date_times).flatMap((stopTime) => stopOf(stopTime));
  return [{
    type: 'transit',
    durationSeconds: safeSeconds(durationSeconds),
    from,
    to,
    departureAt: navitiaDate(section.departure_date_time) ?? navitiaDate(section.boarding_time),
    arrivalAt: navitiaDate(section.arrival_date_time) ?? navitiaDate(section.alighting_time),
    geometry,
    route: line,
    direction,
    platform: textOf(section.from?.platform) ?? textOf(section.boarding?.platform),
    stops: stopTimes,
  }];
}

function displayOfLine(display: Record<string, any>, section: Record<string, any>) {
  const mode = modeOf(display.commercial_mode ?? section.physical_mode ?? display.network);
  return {
    id: textOf(display.code) ?? textOf(display.id) ?? 'unknown',
    shortName: textOf(display.code) ?? textOf(display.name) ?? '?',
    longName: textOf(display.name) ?? textOf(display.code) ?? 'Transport',
    mode,
    color: colorOf(display.color),
    textColor: colorOf(display.text_color, '#FFFFFF'),
  } as const;
}

function stopOf(value: unknown) {
  const stop = value as Record<string, any>;
  const place = stop.stop_point ?? stop.stop_area ?? stop;
  const coordinate = coordinateOf(place.coord);
  if (!coordinate) return [];
  const name = textOf(place.name) ?? 'Arrêt';
  return [{
    id: textOf(place.id) ?? name,
    name,
    coordinate,
    arrivalAt: navitiaDate(stop.arrival_date_time),
    departureAt: navitiaDate(stop.departure_date_time),
  }];
}

function placeOf(value: unknown, fallbackCoordinate: Coordinate, fallbackName: string) {
  const place = value as Record<string, any> | undefined;
  return {
    name: textOf(place?.name) ?? fallbackName,
    coordinate: coordinateOf(place?.coord) ?? fallbackCoordinate,
  };
}

function geometryOf(value: unknown, from: Coordinate, to: Coordinate): Coordinate[] {
  const coordinates = (value as { coordinates?: unknown } | undefined)?.coordinates;
  const points = flattenLineCoordinates(coordinates);
  return points.length > 1 ? points : [from, to];
}

/** Accepts both a LineString and the nested lines of a MultiLineString. */
function flattenLineCoordinates(value: unknown): Coordinate[] {
  if (!Array.isArray(value)) return [];
  if (value.length >= 2 && value.every((part) => typeof part === 'number')) {
    const longitude = Number(value[0]);
    const latitude = Number(value[1]);
    return Number.isFinite(latitude) && Number.isFinite(longitude)
      ? [{ latitude, longitude }]
      : [];
  }
  return value.flatMap(flattenLineCoordinates);
}

function coordinateOf(value: unknown): Coordinate | undefined {
  const coord = value as { lat?: unknown; lon?: unknown } | undefined;
  const latitude = Number(coord?.lat);
  const longitude = Number(coord?.lon);
  return Number.isFinite(latitude) && Number.isFinite(longitude) ? { latitude, longitude } : undefined;
}

function navitiaDate(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const match = /^(\d{8})T(\d{6})/.exec(value);
  if (!match) return undefined;
  const date = `${match[1].slice(0, 4)}-${match[1].slice(4, 6)}-${match[1].slice(6, 8)}`;
  const seconds =
    Number(match[2].slice(0, 2)) * 3600 +
    Number(match[2].slice(2, 4)) * 60 +
    Number(match[2].slice(4, 6));
  return toInstant(date, seconds);
}

function qualifierOf(tags: string[], index: number): Journey['qualifier'] {
  if (tags.includes('less_fallback_walk')) return 'less-walking';
  if (tags.includes('comfort')) return 'comfort';
  if (tags.includes('non_pt_walk')) return 'walking';
  if (tags.includes('rapid') || tags.includes('fastest')) return 'rapid';
  return index === 0 || tags.includes('best') ? 'recommended' : 'comfort';
}

function modeOf(value: unknown): 'metro' | 'rer' | 'bus' {
  const text = String(value ?? '').toLowerCase();
  if (text.includes('bus')) return 'bus';
  if (text.includes('rer') || text.includes('rail')) return 'rer';
  return 'metro';
}

function colorOf(value: unknown, fallback = '#2F6B5B') {
  const text = textOf(value);
  if (!text) return fallback;
  return text.startsWith('#') ? text : `#${text}`;
}

function textOf(value: unknown) {
  if (typeof value === 'string') return value;
  if (value && typeof value === 'object' && 'value' in value) {
    const nested = (value as { value?: unknown }).value;
    return typeof nested === 'string' ? nested : undefined;
  }
  return undefined;
}

function asArray(value: unknown) {
  return Array.isArray(value) ? value : [];
}

function safeSeconds(value: number) {
  return Number.isFinite(value) && value >= 0 ? Math.round(value) : 0;
}
