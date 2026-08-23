import {
  db,
  reportCurrentVotes,
  reportEvents,
  stationFacts,
  transitStops,
} from '@via/db';
import { and, eq, gte, inArray } from 'drizzle-orm';

import { parisDay, parisDayType } from '../time/paris';
import { ACCESSIBILITY_CONDITION_LABELS } from '../routers/accessibility-labels';
import { stationPeaks } from '../routers/station-peak';
import type { ReportRepository, ReportWrite } from './service';
import {
  REPORT_ACTIVE_WINDOW_MILLISECONDS,
  type CurrentReportVote,
} from './status-resolver';

export function createDatabaseReportRepository(): ReportRepository {
  return {
    async eventExists(id) {
      const rows = await db.select({ id: reportEvents.id }).from(reportEvents)
        .where(eq(reportEvents.id, id)).limit(1);
      return rows.length > 0;
    },

    async commit(write) {
      return db.transaction(async (transaction) => {
        const station = await transaction.select({ id: transitStops.id }).from(transitStops)
          .where(eq(transitStops.id, write.stationId)).limit(1);
        if (!station[0]) return 'station-missing' as const;

        const inserted = await transaction.insert(reportEvents).values({
          id: write.id,
          userId: write.userId,
          stationId: write.stationId,
          category: write.category,
          scopeKind: write.scopeKind,
          scopeId: write.scopeId,
          value: write.value,
          lineId: write.lineId,
          journeyId: write.journeyId,
          vehicleId: write.vehicleId,
          observedAt: write.observedAt,
          createdAt: write.observedAt,
        }).onConflictDoNothing().returning({ id: reportEvents.id });
        if (!inserted[0]) return 'duplicate' as const;

        await transaction.insert(reportCurrentVotes).values({
          userId: write.userId,
          stationId: write.stationId,
          category: write.category,
          scopeKind: write.scopeKind,
          scopeId: write.scopeId,
          value: write.value,
          observedAt: write.observedAt,
          updatedAt: write.observedAt,
        }).onConflictDoUpdate({
          target: [
            reportCurrentVotes.userId,
            reportCurrentVotes.stationId,
            reportCurrentVotes.category,
            reportCurrentVotes.scopeKind,
            reportCurrentVotes.scopeId,
          ],
          set: {
            value: write.value,
            observedAt: write.observedAt,
            updatedAt: write.observedAt,
          },
        });
        return 'written' as const;
      });
    },

    async loadVotes({ stationIds, at }) {
      if (stationIds.length === 0) return [];
      const rows = await db.select().from(reportCurrentVotes).where(and(
        inArray(reportCurrentVotes.stationId, stationIds),
        gte(reportCurrentVotes.observedAt, activeSince(at)),
      ));
      return rows.map(toCurrentVote);
    },

    async loadStation({ stationId, at }) {
      const [stations, votes, facts, peaks] = await Promise.all([
        db.select({ id: transitStops.id }).from(transitStops)
          .where(eq(transitStops.id, stationId)).limit(1),
        db.select().from(reportCurrentVotes).where(and(
          eq(reportCurrentVotes.stationId, stationId),
          gte(reportCurrentVotes.observedAt, activeSince(at)),
        )),
        db.select({ condition: stationFacts.condition }).from(stationFacts).where(and(
          eq(stationFacts.stopId, stationId),
          eq(stationFacts.kind, 'accessibility'),
        )).limit(1),
        stationPeaks([stationId], parisDayType(at), Math.floor(parisDay(at).seconds / 3_600)),
      ]);
      if (!stations[0]) return null;

      const fact = facts[0];
      const peak = peaks.get(stationId);
      return {
        votes: votes.map(toCurrentVote),
        automaticAccessibility: fact ? {
          condition: fact.condition,
          label: ACCESSIBILITY_CONDITION_LABELS[fact.condition],
        } : undefined,
        automaticCrowding: peak ? {
          level: peak.level === 'peak' ? 'high' as const : peak.level === 'moderate' ? 'moderate' as const : 'low' as const,
          label: peak.label,
        } : undefined,
      };
    },
  };
}

type CurrentRow = typeof reportCurrentVotes.$inferSelect;

function activeSince(at: Date) {
  return new Date(at.getTime() - REPORT_ACTIVE_WINDOW_MILLISECONDS);
}

/** The column enums and their CHECK constraints already narrow every field. */
export function toCurrentVote(row: CurrentRow): CurrentReportVote {
  return {
    reporterId: row.userId,
    stationId: row.stationId,
    category: row.category,
    scopeKind: row.scopeKind,
    scopeId: row.scopeId,
    value: row.value,
    observedAt: row.observedAt,
  };
}
