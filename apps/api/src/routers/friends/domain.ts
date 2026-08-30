export function canonicalFriendPair(first: string, second: string): [string, string] {
  if (first === second) throw new Error('A user cannot befriend self.');
  return first < second ? [first, second] : [second, first];
}

export function friendInitials(displayName: string): string {
  const words = displayName.trim().split(/\s+/u).filter(Boolean);
  if (words.length === 0) return '?';
  return words.slice(0, 2).map((word) => [...word][0]?.toLocaleUpperCase('fr-FR') ?? '').join('');
}
