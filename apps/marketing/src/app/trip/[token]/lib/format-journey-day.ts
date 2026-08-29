import { journeyDateFormatter } from "./journey-date-formatter";

export function formatJourneyDay(
  value: string,
  locale: string,
  timeZone: string,
): string {
  return journeyDateFormatter(locale, timeZone, {
    weekday: "long",
    day: "numeric",
    month: "long",
  }).format(new Date(value));
}
