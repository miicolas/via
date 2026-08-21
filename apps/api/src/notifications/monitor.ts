import { env } from '../env';
import { redis } from '../redis';
import { notificationDelivery, notificationJourneySubscriptions } from './index';
import { NotificationDisruptionMonitor } from './disruption-monitor';

let monitor: NotificationDisruptionMonitor | null = null;
let timer: ReturnType<typeof setInterval> | null = null;

/** Starts the process-local poller; Redis makes multiple API replicas safe. */
export function startNotificationDisruptionMonitor(): NotificationDisruptionMonitor | null {
  if (monitor || process.env.NODE_ENV === 'test') return monitor;
  if (!env.APNS_KEY_ID || !env.APNS_PRIVATE_KEY || !env.API_KEY_PRISM_IDFM) {
    return null;
  }

  monitor = new NotificationDisruptionMonitor({
    redis,
    subscriptions: notificationJourneySubscriptions,
    delivery: notificationDelivery,
  });
  const intervalMilliseconds = env.NOTIFICATION_DISRUPTION_POLL_SECONDS * 1_000;
  void monitor.pollOnce();
  timer = setInterval(() => void monitor?.pollOnce(), intervalMilliseconds);
  return monitor;
}

export function stopNotificationDisruptionMonitor() {
  if (timer) clearInterval(timer);
  timer = null;
  monitor = null;
}

