import { journeyDateFormatter } from "./journey-date-formatter";

export function formatJourneyTime(
  value: string,
  locale: string,
  timeZone: string,
): string {
  return journeyDateFormatter(locale, timeZone, {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}
