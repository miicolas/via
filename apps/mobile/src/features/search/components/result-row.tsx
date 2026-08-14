import type { SearchResult } from '@via/contract';

import { AddressResultRow } from '@/features/search/components/address-row';
import { StationResultRow } from '@/features/search/components/station-row';

type SearchResultRowProps = {
  onPress: () => void;
  result: SearchResult;
};

/** Dispatches a result to its kind-specific row, so callers never re-implement the switch. */
export function SearchResultRow({ onPress, result }: SearchResultRowProps) {
  return result.kind === 'station' ? (
    <StationResultRow onPress={onPress} result={result} />
  ) : (
    <AddressResultRow onPress={onPress} result={result} />
  );
}
