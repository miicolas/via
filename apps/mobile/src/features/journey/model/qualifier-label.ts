import type { Journey } from '@via/contract';

const LABELS = new Map<Journey['qualifier'], string>([
  ['recommended', 'Recommandé'],
  ['rapid', 'Rapide'],
  ['less-walking', 'Moins à pied'],
  ['comfort', 'Assis'],
  ['walking', 'À pied'],
]);

/** What sets this option apart, in the words the rest of the app already uses. */
export function journeyQualifierLabel(qualifier: Journey['qualifier']) {
  return LABELS.get(qualifier) ?? 'Option';
}
