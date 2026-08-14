import type { FlowScreen } from './flow';

/** The screens where the journey flow replaces the overview sheet. */
export function isJourneyScreen(screen: FlowScreen) {
  return (
    screen === 'planning' ||
    screen === 'clarification' ||
    screen === 'results' ||
    screen === 'detail'
  );
}
