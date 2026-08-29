export function journeyShareQueryKey(token: string) {
  return ["journey-share", token] as const;
}
