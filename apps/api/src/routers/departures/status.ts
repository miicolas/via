import type { DepartureStatus } from '@via/contract';

export type PrimDepartureStatus =
  | 'on_time'
  | 'delayed'
  | 'early'
  | 'cancelled'
  | 'missed'
  | 'arrived'
  | 'departed'
  | 'no_report';

const operationalStatuses = new Set<PrimDepartureStatus>([
  'cancelled',
  'missed',
  'arrived',
  'departed',
]);

const primStatusMap: Record<string, PrimDepartureStatus> = {
  ontime: 'on_time',
  on_time: 'on_time',
  early: 'early',
  delayed: 'delayed',
  cancelled: 'cancelled',
  canceled: 'cancelled',
  missed: 'missed',
  arrived: 'arrived',
  departed: 'departed',
  noreport: 'no_report',
  no_report: 'no_report',
  notexpected: 'no_report',
  not_expected: 'no_report',
};

export function normalizePrimDepartureStatus(value: string | null): PrimDepartureStatus | undefined {
  if (!value) return undefined;
  return primStatusMap[value.replace(/[-\s]/g, '_').toLowerCase()];
}

export function qualifyDepartureStatus(input: {
  scheduledAt?: number;
  expectedAt?: number;
  providerStatus?: PrimDepartureStatus;
}): { status: DepartureStatus; delaySeconds?: number } {
  if (input.providerStatus && operationalStatuses.has(input.providerStatus)) {
    return { status: input.providerStatus };
  }

  if (input.scheduledAt !== undefined && input.expectedAt !== undefined) {
    const delaySeconds = input.expectedAt - input.scheduledAt;
    if (delaySeconds >= 120) return { status: 'delayed', delaySeconds };
    if (delaySeconds <= -120) return { status: 'early', delaySeconds };
    return { status: 'on_time', delaySeconds };
  }

  // PRIM documents `onTime` as the default status. Without an Aimed time it is
  // not evidence that the vehicle follows a schedule, so keep the estimate
  // neutral. Non-default early/delayed reports remain useful qualitatively,
  // but still carry no manufactured delaySeconds.
  switch (input.providerStatus) {
    case 'delayed':
    case 'early':
      return { status: input.providerStatus };
    default:
      return { status: 'no_report' };
  }
}
