import { journeyDateFormatter } from "./journey-date-formatter";

export function formatJourneyDate(
  value: string,
  locale: string,
  timeZone: string,
): string {
  return journeyDateFormatter(locale, timeZone, {
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date(value));
}
