import type { SearchResult } from '@via/contract';
import type { Dispatch } from 'react';
import { useCallback, useEffect, useRef } from 'react';

import { useNaturalJourney } from '@/features/journey/hooks/use-natural-journey';
import type { NaturalJourneyChoice } from '@/features/journey/model/clarification-choice';
import type { MapFlowEvent } from '@/features/map/model/flow';
import type { UserLocationState } from '@/features/map/model/types';

export function useNaturalJourneyFlow(options: {
  query: string;
  location: UserLocationState;
  dispatch: Dispatch<MapFlowEvent>;
  rememberDestination: (result: SearchResult) => void;
}) {
  const natural = useNaturalJourney();
  const { dispatch, location, query, rememberDestination } = options;
  const rememberRef = useRef(rememberDestination);
  rememberRef.current = rememberDestination;

  useEffect(() => {
    if (natural.state.status === 'needs_clarification') {
      dispatch({ type: 'natural-journey-needs-clarification' });
    } else if (natural.state.status === 'ready') {
      rememberRef.current(natural.state.response.interpretation.destinationResult);
      dispatch({
        type: 'natural-journey-ready',
        destination: natural.state.response.interpretation.destination,
      });
    } else if (natural.state.status === 'error') {
      dispatch({ type: 'natural-journey-failed' });
    }
  }, [dispatch, natural.state]);

  const submit = useCallback(() => {
    const phrase = query.trim();
    if (!phrase) return;
    dispatch({ type: 'natural-journey-submitted' });
    void natural.submit(phrase, coordinate(location));
  }, [dispatch, location, natural.submit, query]);

  const resolve = useCallback(
    (choice: NaturalJourneyChoice) => {
      if (natural.state.status !== 'needs_clarification') return;
      dispatch({ type: 'natural-journey-submitted' });
      void natural.resolve(natural.state.response, choice, coordinate(location));
    },
    [dispatch, location, natural.resolve, natural.state]
  );

  return { state: natural.state, submit, resolve, clear: natural.clear };
}

function coordinate(location: UserLocationState) {
  return location.status === 'ready' ? location.coordinate : undefined;
}
