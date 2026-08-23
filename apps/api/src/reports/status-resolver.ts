import { CROWDING_LEVELS } from '@via/contract';
import type {
  AccessibilityCondition,
  CrowdingLevel,
  EffectiveAccessibility,
  EffectiveCrowding,
  EffectiveIncident,
  ReportCategory,
  ReportScopeKind,
  ReportValue,
  StationStatus,
} from '@via/contract';

/** The wire contract owns this vocabulary; the resolver never restates it. */
export type {
  CrowdingLevel,
  EffectiveAccessibility,
  EffectiveCrowding,
  EffectiveIncident,
  ReportCategory,
  ReportScopeKind,
  ReportValue,
  StationStatus,
};

/** How far back a vote can still weigh on a resolution. */
export const REPORT_ACTIVE_WINDOW_MILLISECONDS = 6 * 60 * 60 * 1_000;

export type CurrentReportVote = {
  reporterId: string;
  stationId: string;
  category: ReportCategory;
  scopeKind: ReportScopeKind;
  scopeId: string;
  value: ReportValue;
  observedAt: Date;
};

export type AutomaticAccessibility = {
  condition: AccessibilityCondition;
  label: string;
};

export type AutomaticCrowding = {
  level: CrowdingLevel;
  label: string;
};

type ResolveStationStatusInput = {
  stationId: string;
  at: Date;
  votes: CurrentReportVote[];
  automaticAccessibility?: AutomaticAccessibility;
  automaticCrowding?: AutomaticCrowding;
  lineId?: string;
  vehicleId?: string;
};

type ReportScopeInput = {
  stationId: string;
  category: ReportCategory;
  lineId?: string;
  vehicleId?: string;
};

const MINUTE = 60_000;
const CROWDING_LABELS: Record<CrowdingLevel, string> = {
  low: 'Affluence faible signalée',
  moderate: 'Affluence modérée signalée',
  high: 'Affluence forte signalée',
  saturated: 'Affluence saturée signalée',
};
const INCIDENT_LABELS: Record<Exclude<ReportCategory, 'crowding'>, { active: string; recovered: string }> = {
  pickpocket: { active: 'Pickpocket signalé', recovered: 'Situation terminée' },
  restroomsClosed: { active: 'WC signalés fermés', recovered: 'WC signalés rouverts' },
  ticketMachinesUnavailable: { active: 'Distributeurs signalés indisponibles', recovered: 'Distributeurs signalés rétablis' },
  wheelchairAccessUnavailable: { active: 'Accès PMR signalé indisponible', recovered: 'Accès PMR rétabli' },
  elevatorsUnavailable: { active: 'Ascenseurs signalés indisponibles', recovered: 'Ascenseurs signalés rétablis' },
  escalatorUnavailable: { active: 'Escalator signalé indisponible', recovered: 'Escalator signalé rétabli' },
  validatorsUnavailable: { active: 'Portiques signalés indisponibles', recovered: 'Portiques signalés rétablis' },
  entranceOrExitClosed: { active: 'Entrée ou sortie signalée fermée', recovered: 'Entrée ou sortie signalée rouverte' },
  stopRelocated: { active: 'Arrêt signalé déplacé', recovered: 'Arrêt signalé rétabli' },
  stopNotServed: { active: 'Arrêt signalé non desservi', recovered: 'Desserte signalée rétablie' },
  passengerInformationUnavailable: { active: 'Information voyageurs signalée indisponible', recovered: 'Information voyageurs signalée rétablie' },
  passageObstructed: { active: 'Passage signalé obstrué', recovered: 'Passage signalé dégagé' },
};

export function deriveReportScope(input: ReportScopeInput): { kind: ReportScopeKind; id: string } {
  if (input.category === 'crowding' || input.category === 'pickpocket') {
    if (input.vehicleId) return { kind: 'vehicle', id: input.vehicleId };
    if (input.lineId) return { kind: 'line', id: input.lineId };
  }
  return { kind: 'station', id: input.stationId };
}

/** Public deep-module seam; callers do not need to know weighting or consensus rules. */
export const StationStatusResolver = {
  deriveScope: deriveReportScope,
  resolve: resolveStationStatus,
} as const;

export function resolveStationStatus(input: ResolveStationStatusInput): StationStatus {
  const wheelchairVotes = latestVotesByReporter(input.votes.filter(
    (vote) =>
      vote.stationId === input.stationId &&
      vote.category === 'wheelchairAccessUnavailable' &&
      vote.scopeKind === 'station' &&
      vote.scopeId === input.stationId
  ));
  const occurrenceVotes = wheelchairVotes
    .filter((vote) => vote.value === 'occurrence')
    .sort((a, b) => b.observedAt.getTime() - a.observedAt.getTime());
  const recoveryVotes = wheelchairVotes
    .filter((vote) => vote.value === 'resolved')
    .sort((a, b) => b.observedAt.getTime() - a.observedAt.getTime());
  const latest = occurrenceVotes[0];
  const reporterCount = latest
    ? occurrenceVotes.filter(
        (vote) => latest.observedAt.getTime() - vote.observedAt.getTime() <= 60 * MINUTE
      ).length
    : 0;
  const durationMinutes = Math.min(6 * 60, 60 + Math.max(0, reporterCount - 1) * 30);
  const expiresAt = latest
    ? new Date(latest.observedAt.getTime() + durationMinutes * MINUTE)
    : undefined;
  const latestRecovery = recoveryVotes[0];
  const recoveryCount = latestRecovery
    ? recoveryVotes.filter(
        (vote) => latestRecovery.observedAt.getTime() - vote.observedAt.getTime() <= 60 * MINUTE
      ).length
    : 0;
  const recoveryDurationMinutes = Math.min(6 * 60, 60 + Math.max(0, recoveryCount - 1) * 30);
  const recoveryExpiresAt = latestRecovery
    ? new Date(latestRecovery.observedAt.getTime() + recoveryDurationMinutes * MINUTE)
    : undefined;
  const occurrenceScore = weightedScore(occurrenceVotes, input.at, 6 * 60);
  const recoveryScore = weightedScore(recoveryVotes, input.at, 6 * 60);
  const isRecovered = Boolean(
    latestRecovery &&
    recoveryExpiresAt &&
    recoveryExpiresAt > input.at &&
    recoveryCount >= 2 &&
    recoveryScore > occurrenceScore
  );
  const hasActiveReport = !isRecovered && latest && expiresAt && expiresAt > input.at;

  const accessibility: EffectiveAccessibility | undefined = hasActiveReport
    ? {
        state: 'unavailable',
        source: 'reported',
        label: 'Accès PMR signalé indisponible',
        reporterCount,
        observedAt: latest.observedAt.toISOString(),
        expiresAt: expiresAt.toISOString(),
        confidence: reporterCount >= 2 ? 'confirmed' : 'observed',
      }
    : input.automaticAccessibility
      ? {
          state: 'available',
          source: 'automatic',
          ...input.automaticAccessibility,
        }
      : undefined;

  const crowdingResolution = resolveCrowding(input);

  const accessibilityIncidents: EffectiveIncident[] = isRecovered && latestRecovery && recoveryExpiresAt
    ? [{
        category: 'wheelchairAccessUnavailable',
        scopeKind: 'station',
        scopeId: input.stationId,
        state: 'recovered',
        label: `Rétabli selon ${recoveryCount} ${recoveryCount === 1 ? 'personne' : 'personnes'}`,
        reporterCount: recoveryCount,
        observedAt: latestRecovery.observedAt.toISOString(),
        expiresAt: recoveryExpiresAt.toISOString(),
      }]
    : [];
  const incidents = [
    ...accessibilityIncidents,
    ...resolveOtherIncidents(input),
  ];

  return {
    stationId: input.stationId,
    generatedAt: input.at.toISOString(),
    accessibility,
    crowding: crowdingResolution ?? (input.automaticCrowding
      ? { ...input.automaticCrowding, source: 'automatic' }
      : undefined),
    incidents,
    wheelchairRouteExcluded: Boolean(hasActiveReport && reporterCount >= 2),
  };
}

function resolveOtherIncidents(input: ResolveStationStatusInput): EffectiveIncident[] {
  const groups = new Map<string, CurrentReportVote[]>();
  for (const vote of input.votes) {
    if (
      vote.stationId !== input.stationId ||
      vote.category === 'crowding' ||
      vote.category === 'wheelchairAccessUnavailable' ||
      !scopeMatches(input, vote)
    ) continue;
    const key = `${vote.category}\u0000${vote.scopeKind}\u0000${vote.scopeId}`;
    const values = groups.get(key) ?? [];
    values.push(vote);
    groups.set(key, values);
  }

  return [...groups.values()].flatMap((groupVotes) => {
    const votes = latestVotesByReporter(groupVotes);
    const first = votes[0];
    if (!first || first.category === 'crowding') return [];
    const category = first.category as Exclude<ReportCategory, 'crowding'>;
    const occurrences = votes
      .filter((vote) => vote.value === 'occurrence')
      .sort((a, b) => b.observedAt.getTime() - a.observedAt.getTime());
    const recoveries = category === 'pickpocket'
      ? []
      : votes
          .filter((vote) => vote.value === 'resolved')
          .sort((a, b) => b.observedAt.getTime() - a.observedAt.getTime());
    const occurrence = incidentWindow(occurrences, 60, 15, 180);
    const recovery = incidentWindow(recoveries, 60, 15, 180);
    const recovered = Boolean(
      recovery &&
      recovery.reporterCount >= 2 &&
      recovery.expiresAt > input.at &&
      weightedScore(recoveries, input.at, 180) > weightedScore(occurrences, input.at, 180)
    );
    const winning = recovered ? recovery : occurrence;
    if (!winning || winning.expiresAt <= input.at) return [];
    return [{
      category,
      scopeKind: first.scopeKind,
      scopeId: first.scopeId,
      state: recovered ? 'recovered' as const : 'active' as const,
      label: INCIDENT_LABELS[category][recovered ? 'recovered' : 'active'],
      reporterCount: winning.reporterCount,
      observedAt: winning.latest.observedAt.toISOString(),
      expiresAt: winning.expiresAt.toISOString(),
    }];
  });
}

function incidentWindow(
  votes: CurrentReportVote[],
  baseMinutes: number,
  extensionMinutes: number,
  maximumMinutes: number
) {
  const latest = votes[0];
  if (!latest) return undefined;
  const reporterCount = votes.filter(
    (vote) => latest.observedAt.getTime() - vote.observedAt.getTime() <= baseMinutes * MINUTE
  ).length;
  const durationMinutes = Math.min(
    maximumMinutes,
    baseMinutes + Math.max(0, reporterCount - 1) * extensionMinutes
  );
  return {
    latest,
    reporterCount,
    expiresAt: new Date(latest.observedAt.getTime() + durationMinutes * MINUTE),
  };
}

function resolveCrowding(input: ResolveStationStatusInput): EffectiveCrowding | undefined {
  const all = input.votes.filter(
    (vote) => vote.stationId === input.stationId && vote.category === 'crowding'
  ).filter(
    (vote): vote is CurrentReportVote & { value: CrowdingLevel } =>
      CROWDING_LEVELS.includes(vote.value as CrowdingLevel) &&
      input.at.getTime() - vote.observedAt.getTime() <= 90 * MINUTE
  );
  const scopes: Array<[ReportScopeKind, string | undefined]> = [
    ['vehicle', input.vehicleId],
    ['line', input.lineId],
    ['station', input.stationId],
  ];
  const scoped = scopes
    .filter((entry): entry is [ReportScopeKind, string] => Boolean(entry[1]))
    .map(([kind, id]) => latestVotesByReporter(
      all.filter((vote) => vote.scopeKind === kind && vote.scopeId === id)
    ))
    .find((votes) => votes.length > 0);
  if (!scoped?.length) return undefined;

  const level = weightedMedianCrowding(scoped, input.at);
  const matching = scoped
    .filter((vote) => vote.value === level)
    .sort((a, b) => b.observedAt.getTime() - a.observedAt.getTime());
  const latest = matching[0];
  if (!latest) return undefined;
  const reporterCount = matching.filter(
    (vote) => latest.observedAt.getTime() - vote.observedAt.getTime() <= 30 * MINUTE
  ).length;
  const durationMinutes = Math.min(90, 30 + Math.max(0, reporterCount - 1) * 10);
  const expiresAt = new Date(latest.observedAt.getTime() + durationMinutes * MINUTE);
  if (expiresAt <= input.at) return undefined;
  return {
    level,
    source: 'reported',
    label: CROWDING_LABELS[level],
    reporterCount,
    observedAt: latest.observedAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
  };
}

function weightedMedianCrowding(
  votes: Array<CurrentReportVote & { value: CrowdingLevel }>,
  at: Date
) {
  const weighted = CROWDING_LEVELS.flatMap((level) => {
    const matching = votes.filter((vote) => vote.value === level);
    if (matching.length === 0) return [];
    return [{
      level,
      weight: weightedScore(matching, at, 90),
      latestAt: Math.max(...matching.map((vote) => vote.observedAt.getTime())),
    }];
  });
  const midpoint = weighted.reduce((sum, item) => sum + item.weight, 0) / 2;
  let accumulated = 0;
  for (const [index, item] of weighted.entries()) {
    accumulated += item.weight;
    if (Math.abs(accumulated - midpoint) < Number.EPSILON * 16) {
      const next = weighted[index + 1];
      if (!next) return item.level;
      return item.latestAt >= next.latestAt ? item.level : next.level;
    }
    if (accumulated > midpoint) return item.level;
  }
  return weighted.at(-1)?.level ?? 'low';
}

function scopeMatches(input: ResolveStationStatusInput, vote: CurrentReportVote) {
  if (vote.scopeKind === 'station') return vote.scopeId === input.stationId;
  if (vote.scopeKind === 'line') return Boolean(input.lineId && vote.scopeId === input.lineId);
  return Boolean(input.vehicleId && vote.scopeId === input.vehicleId);
}

function latestVotesByReporter<T extends CurrentReportVote>(votes: T[]): T[] {
  const latest = new Map<string, T>();
  for (const vote of votes) {
    const previous = latest.get(vote.reporterId);
    if (!previous || vote.observedAt > previous.observedAt) latest.set(vote.reporterId, vote);
  }
  return [...latest.values()];
}

function weightedScore(votes: CurrentReportVote[], at: Date, maximumAgeMinutes: number) {
  return votes.reduce((score, vote) => {
    const ageMinutes = Math.max(0, (at.getTime() - vote.observedAt.getTime()) / MINUTE);
    if (ageMinutes > maximumAgeMinutes) return score;
    return score + 2 ** (-ageMinutes / 15);
  }, 0);
}
