/** The first detent leaves only the native tab bar visible, Find My-style. */
export const MAP_OVERVIEW_SHEET_DETENTS = [0.14, 0.42, 0.70, 0.90] as const;
/** Journey planning keeps the same sheet mechanics, but uses the tall form-sheet stop. */
export const MAP_JOURNEY_SHEET_DETENTS = [0.14, 0.42, 0.70, 0.98] as const;
export const MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX = 0;
export const MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX = 1;
export const MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX = MAP_OVERVIEW_SHEET_DETENTS.length - 1;

export function mapOverviewSheetDetent(index: number) {
  return (
    MAP_OVERVIEW_SHEET_DETENTS[index] ??
    MAP_OVERVIEW_SHEET_DETENTS[MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX]
  );
}
