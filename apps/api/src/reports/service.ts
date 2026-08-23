import type { RedisClient } from '../redis';
import { enforceReportWriteLimits, ReportRateLimitError } from './rate-limiter';
import type { ReportMetric } from './metrics';
import {
  StationStatusResolver,
  type AutomaticAccessibility,
  type AutomaticCrowding,
  type CurrentReportVote,
  type ReportCategory,
  type ReportValue,
  type ReportScopeKind,
  type StationStatus,
} from './status-resolver';

export type ReportSubmission = {
  id: string;
  stationId: string;
  category: ReportCategory;
  value: ReportValue;
  lineId?: string;
  journeyId?: string;
  vehicleId?: string;
};

export type ReportWrite = ReportSubmission & {
  userId: string;
  scopeKind: ReportScopeKind;
  scopeId: string;
  observedAt: Date;
};

export type ReportRepository = {
  eventExists(id: string): Promise<boolean>;
  commit(write: ReportWrite): Promise<'written' | 'duplicate' | 'station-missing'>;
  /** Every still-weighing vote for these stations, in one read. */
  loadVotes(input: { stationIds: string[]; at: Date }): Promise<CurrentReportVote[]>;
  loadStation(input: { stationId: string; at: Date }): Promise<{
    votes: CurrentReportVote[];
    automaticAccessibility?: AutomaticAccessibility;
    automaticCrowding?: AutomaticCrowding;
  } | null>;
};

export class ReportStationNotFoundError extends Error {}

type Dependencies = {
  repository: ReportRepository;
  redis: RedisClient;
  clock: { now(): Date };
  recordMetric?: (metric: ReportMetric) => void;
};

export class ReportService {
  constructor(private readonly dependencies: Dependencies) {}

  async submit(input: { userId: string; ipHash: string; submission: ReportSubmission }) {
    const startedAt = performance.now();
    const { repository, redis } = this.dependencies;
    if (await repository.eventExists(input.submission.id)) {
      const status = await this.stationStatus({
        stationId: input.submission.stationId,
        lineId: input.submission.lineId,
        vehicleId: input.submission.vehicleId,
      });
      this.emit('submit', 'idempotent', startedAt, status);
      return status;
    }

    const scope = StationStatusResolver.deriveScope(input.submission);
    try {
      await enforceReportWriteLimits(redis, {
        userId: input.userId,
        ipHash: input.ipHash,
        stationId: input.submission.stationId,
        category: input.submission.category,
        scopeKind: scope.kind,
        scopeId: scope.id,
      });
    } catch (error) {
      if (error instanceof ReportRateLimitError) {
        this.emit(
          'submit',
          error.reason === 'unavailable' ? 'redis-unavailable' : 'rate-limited',
          startedAt,
        );
      }
      throw error;
    }

    const outcome = await repository.commit({
      ...input.submission,
      userId: input.userId,
      scopeKind: scope.kind,
      scopeId: scope.id,
      observedAt: this.dependencies.clock.now(),
    });
    if (outcome === 'station-missing') {
      this.emit('submit', 'not-found', startedAt);
      throw new ReportStationNotFoundError();
    }
    await redis.incr(versionKey(input.submission.stationId));
    const status = await this.stationStatus({
      stationId: input.submission.stationId,
      lineId: input.submission.lineId,
      vehicleId: input.submission.vehicleId,
    });
    this.emit('submit', outcome === 'duplicate' ? 'idempotent' : 'accepted', startedAt, status);
    return status;
  }

  async stationStatus(input: { stationId: string; lineId?: string; vehicleId?: string }) {
    const startedAt = performance.now();
    const cached = await this.cachedStatus(input).catch(() => null);
    if (cached) {
      this.emit('read', 'cache-hit', startedAt, cached);
      return cached;
    }
    const status = await this.resolve(input);
    await this.cacheStatus(input, status).catch(() => undefined);
    this.emit('read', 'cache-miss', startedAt, status);
    return status;
  }

  private async resolve(input: { stationId: string; lineId?: string; vehicleId?: string }) {
    const at = this.dependencies.clock.now();
    const station = await this.dependencies.repository.loadStation({ stationId: input.stationId, at });
    if (!station) throw new ReportStationNotFoundError();
    return StationStatusResolver.resolve({ ...input, ...station, at });
  }

  private async cachedStatus(input: { stationId: string; lineId?: string; vehicleId?: string }) {
    const version = await this.dependencies.redis.get<number>(versionKey(input.stationId)) ?? 0;
    return this.dependencies.redis.get<StationStatus>(statusKey(input, version));
  }

  private async cacheStatus(
    input: { stationId: string; lineId?: string; vehicleId?: string },
    status: StationStatus,
  ) {
    const version = await this.dependencies.redis.get<number>(versionKey(input.stationId)) ?? 0;
    await this.dependencies.redis.set(statusKey(input, version), JSON.stringify(status), { ex: 15 });
  }

  private emit(
    operation: ReportMetric['operation'],
    outcome: ReportMetric['outcome'],
    startedAt: number,
    status?: StationStatus,
  ) {
    this.dependencies.recordMetric?.({
      operation,
      outcome,
      latencyMs: Math.max(0, performance.now() - startedAt),
      activeStates: status ? activeStateCount(status) : 0,
    });
  }
}

function activeStateCount(status: StationStatus) {
  return Number(status.accessibility?.source === 'reported') +
    Number(status.crowding?.source === 'reported') +
    status.incidents.filter((incident) => incident.state === 'active').length;
}

function versionKey(stationId: string) {
  return `reports:station:${encodeURIComponent(stationId)}:version`;
}

function statusKey(input: { stationId: string; lineId?: string; vehicleId?: string }, version: number) {
  return [
    'reports:status',
    encodeURIComponent(input.stationId),
    version,
    encodeURIComponent(input.lineId ?? '-'),
    encodeURIComponent(input.vehicleId ?? '-'),
  ].join(':');
}
