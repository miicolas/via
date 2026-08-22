import type {
  NotificationCategory,
  NotificationInterruptionLevel,
  NotificationSeverity,
} from '@via/contract';

import { fitDeviceNotification, type DeviceNotification } from './payload';

export type NotificationCandidate = {
  category: NotificationCategory;
  severity?: NotificationSeverity;
  title?: string;
  body?: string;
  label?: string;
  lineName?: string;
  stationName?: string;
  event?: 'disruption' | 'restored' | 'digest' | 'recommendation' | 'reminder';
  deepLink?: string;
  topicKind?: 'line' | 'station';
  topicId?: string;
  badge?: number;
  interruptionLevel?: NotificationInterruptionLevel;
  relevanceScore?: number;
  data?: Record<string, unknown>;
};

export function renderNotification(candidate: NotificationCandidate): DeviceNotification {
  const title =
    candidate.title ??
    titleFor(candidate.category, candidate.event, candidate.lineName, candidate.stationName);
  const body =
    candidate.body ??
    bodyFor(candidate.category, candidate.event, candidate.label, candidate.lineName, candidate.stationName);
  const threadId = `via.notification.${candidate.topicKind ?? candidate.category}.${candidate.topicId ?? 'general'}`;
  const data = {
    type: 'notification',
    category: candidate.category,
    ...(candidate.severity ? { severity: candidate.severity } : {}),
    ...(candidate.topicKind ? { topicKind: candidate.topicKind } : {}),
    ...(candidate.topicId ? { topicId: candidate.topicId } : {}),
    ...(candidate.deepLink ? { deepLink: candidate.deepLink, url: candidate.deepLink } : {}),
    ...(candidate.data ?? {}),
  };

  return fitDeviceNotification({
    title,
    body,
    badge: candidate.badge,
    threadId,
    categoryId: `via.notification.${candidate.category}`,
    interruptionLevel: candidate.interruptionLevel ?? 'active',
    relevanceScore: candidate.relevanceScore,
    data,
  });
}

function titleFor(
  category: NotificationCategory,
  event: NotificationCandidate['event'],
  lineName?: string,
  stationName?: string,
): string {
  if (event === 'restored') {
    if (lineName) return `Trafic rétabli · ligne ${lineName}`;
    if (stationName) return `Trafic rétabli · ${stationName}`;
    return 'Trafic rétabli';
  }
  switch (category) {
    case 'line':
      return `Perturbation · ligne ${lineName ?? 'suivie'}`;
    case 'station':
      return `Perturbation · ${stationName ?? 'station suivie'}`;
    case 'digest':
      return 'Votre résumé transport';
    case 'recommendation':
      return 'Une suggestion pour votre trajet';
    case 'commute':
      return `Votre trajet${lineName ? ` · ligne ${lineName}` : ''}`;
    case 'journey':
      return `Perturbation · ${lineName ?? 'votre trajet'}`;
  }
}

function bodyFor(
  category: NotificationCategory,
  event: NotificationCandidate['event'],
  label?: string,
  lineName?: string,
  stationName?: string,
): string {
  if (event === 'restored') {
    if (lineName) return `Le trafic est rétabli sur la ligne ${lineName}.`;
    if (stationName) return `La situation est rétablie à ${stationName}.`;
    return 'Le trafic est rétabli.';
  }
  if (label) return label;
  switch (category) {
    case 'line':
      return `Une perturbation touche la ligne ${lineName ?? 'que vous suivez'}.`;
    case 'station':
      return `Une perturbation concerne ${stationName ?? 'la station que vous suivez'}.`;
    case 'digest':
      return 'Retrouvez les informations importantes pour aujourd’hui.';
    case 'recommendation':
      return 'Une option peut vous aider à mieux organiser votre trajet.';
    case 'commute':
      return 'Votre rappel de trajet est disponible.';
    case 'journey':
      return 'Une perturbation concerne une ligne de votre trajet.';
  }
}
