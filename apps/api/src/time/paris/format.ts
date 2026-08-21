import { parisDay } from './day';
import {
  PARIS_LONG_DATE_FORMATTER,
  PARIS_TIME_FORMATTER,
} from './zone';

/** Paris wall-clock time of an ISO instant, e.g. "9 h 05" or "9h05". */
export function formatParisTime(value: string, separator: ' h ' | 'h' = ' h '): string {
  return PARIS_TIME_FORMATTER.format(new Date(value)).replace(':', separator);
}

/** Paris long date of an ISO instant, e.g. "mercredi 12 août". */
export function formatParisLongDate(value: string): string {
  return PARIS_LONG_DATE_FORMATTER.format(new Date(value));
}

/** Navitia's compact Paris-local datetime, e.g. "20260812T215000". */
export function compactParisDateTime(instant: Date): string {
  const { date, seconds } = parisDay(instant);
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${date.replaceAll('-', '')}T${pad(hours)}${pad(minutes)}${pad(seconds % 60)}`;
}
