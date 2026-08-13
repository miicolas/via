import type { FlowScreen } from './flow';

/** The screens where the journey flow replaces the overview sheet. */
export function isJourneyScreen(screen: FlowScreen) {
  return screen === 'planning' || screen === 'results' || screen === 'detail';
}
