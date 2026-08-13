const TIME_FORMAT = new Intl.DateTimeFormat('fr-FR', { hour: '2-digit', minute: '2-digit' });

/** Clock time as a traveller reads it on a platform display. */
export function formatTime(value: string) {
  return TIME_FORMAT.format(new Date(value));
}
