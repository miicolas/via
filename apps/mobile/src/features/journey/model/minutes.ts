/** Never round a real leg down to nothing: a 40-second hop is still "1 min". */
export function journeyMinutes(durationSeconds: number) {
  return Math.max(1, Math.round(durationSeconds / 60));
}
