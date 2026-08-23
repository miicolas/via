import {
  STATION_ELEVATOR_REASONS,
  STATION_ELEVATOR_STATUSES,
  type StationElevatorReason,
  type StationElevatorStatus,
} from '@via/db/schema';

import { asString } from '../idfm/referential';

type ElevatorSourceRow = Record<string, unknown>;

export type ParsedElevator = {
  id: string;
  stopId: string;
  privateId: string | null;
  situation: string | null;
  direction: string | null;
  status: StationElevatorStatus;
  reason: StationElevatorReason | null;
  stateUpdatedAt: Date | null;
};

const STATUSES = new Set<string>(STATION_ELEVATOR_STATUSES);
const REASONS = new Set<string>(STATION_ELEVATOR_REASONS);

/** Translates PRIM's source vocabulary into the persisted Via snapshot. */
export function parseElevatorRows(payload: unknown): ParsedElevator[] {
  if (!Array.isArray(payload)) throw new Error('Elevator source payload is not an array');

  const rows = new Map<string, ParsedElevator>();
  for (const raw of payload as ElevatorSourceRow[]) {
    const id = sourceString(raw, 'liftid', 'liftId');
    const sourceStopId = sourceString(raw, 'zdcid', 'ZdCId');
    const status = elevatorStatus(sourceString(raw, 'liftstatus', 'liftStatus'));
    if (!id || !sourceStopId || !status) continue;

    const parsed = {
      id,
      stopId: canonicalStopId(sourceStopId),
      privateId: sourceString(raw, 'privateelevatorid', 'liftPrivateId', 'LiftPrivateId') ?? null,
      situation: sourceString(raw, 'liftsituation', 'liftSituation') ?? null,
      direction: sourceString(raw, 'liftdirection', 'liftDirection') ?? null,
      status,
      reason: status === 'notavailable'
        ? elevatorReason(sourceString(raw, 'liftreason', 'liftReason'))
        : null,
      stateUpdatedAt: sourceDate(raw, 'liftstateupdate', 'liftStateUpdate'),
    } satisfies ParsedElevator;

    const previous = rows.get(id);
    if (!previous || isAtLeastAsRecent(parsed.stateUpdatedAt, previous.stateUpdatedAt)) {
      rows.set(id, parsed);
    }
  }

  return [...rows.values()];
}

function sourceString(row: ElevatorSourceRow, ...keys: string[]) {
  for (const key of keys) {
    const value = asString(row[key]);
    if (value) return value.trim();
  }
  return undefined;
}

function sourceDate(row: ElevatorSourceRow, ...keys: string[]) {
  const value = sourceString(row, ...keys);
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function canonicalStopId(value: string) {
  const withoutNavitiaPrefix = value.replace(/^stop_area:/, '');
  return withoutNavitiaPrefix.startsWith('IDFM:')
    ? withoutNavitiaPrefix
    : `IDFM:${withoutNavitiaPrefix}`;
}

function elevatorStatus(value: string | undefined): StationElevatorStatus | undefined {
  const normalized = value?.toLowerCase();
  return normalized && STATUSES.has(normalized)
    ? normalized as StationElevatorStatus
    : undefined;
}

function elevatorReason(value: string | undefined): StationElevatorReason | null {
  if (!value) return null;
  return REASONS.has(value) ? value as StationElevatorReason : null;
}

function isAtLeastAsRecent(candidate: Date | null, current: Date | null) {
  if (!candidate) return !current;
  if (!current) return true;
  return candidate >= current;
}
