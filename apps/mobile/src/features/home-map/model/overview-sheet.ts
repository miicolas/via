/** The first detent leaves only the native tab bar visible, Find My-style. */
export const MAP_OVERVIEW_SHEET_DETENTS = [0.12, 0.72, 0.94] as const;
export const MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX = 1;

export function mapOverviewSheetDetent(index: number) {
  return (
    MAP_OVERVIEW_SHEET_DETENTS[index] ??
    MAP_OVERVIEW_SHEET_DETENTS[MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX]
  );
}
