import type { Coordinate, NaturalJourneyResponse } from '@via/contract';
import { useCallback, useEffect, useRef, useState } from 'react';

import type { NaturalJourneyChoice } from '@/features/journey/model/clarification-choice';
import { api } from '@/lib/api';

export type NaturalJourneyState =
  | { status: 'idle' }
  | { status: 'interpreting' }
  | { status: 'needs_clarification'; response: Extract<NaturalJourneyResponse, { status: 'needs_clarification' }> }
  | { status: 'ready'; response: Extract<NaturalJourneyResponse, { status: 'ready' }> }
  | { status: 'error'; response: Exclude<NaturalJourneyResponse, { status: 'ready' | 'needs_clarification' }> };

export function useNaturalJourney() {
  const [state, setState] = useState<NaturalJourneyState>({ status: 'idle' });
  const controllerRef = useRef<AbortController | undefined>(undefined);

  useEffect(() => () => controllerRef.current?.abort(), []);

  const run = useCallback(async (input: Parameters<typeof api.naturalJourneys.submit>[0]) => {
    controllerRef.current?.abort();
    const controller = new AbortController();
    controllerRef.current = controller;
    setState({ status: 'interpreting' });
    try {
      const response = await api.naturalJourneys.submit(input, { signal: controller.signal });
      if (controller.signal.aborted) return;
      if (response.status === 'ready') setState({ status: 'ready', response });
      else if (response.status === 'needs_clarification') {
        setState({ status: 'needs_clarification', response });
      } else setState({ status: 'error', response });
    } catch {
      if (controller.signal.aborted) return;
      setState({
        status: 'error',
        response: {
          status: 'unavailable',
          reason: 'ai',
          message: 'La recherche en langage naturel est indisponible. La recherche classique reste accessible.',
        },
      });
    }
  }, []);

  const submit = useCallback(
    (query: string, currentLocation?: Coordinate) =>
      run({ action: 'submit', query: query.trim(), currentLocation }),
    [run]
  );
  const resolve = useCallback(
    (
      response: Extract<NaturalJourneyResponse, { status: 'needs_clarification' }>,
      choice: NaturalJourneyChoice,
      currentLocation?: Coordinate
    ) =>
      run({
        action: 'resolve',
        draft: response.draft,
        currentLocation,
        ...(choice.target === 'origin' ? { origin: choice.result } : {}),
        ...(choice.target === 'destination' ? { destination: choice.result } : {}),
        ...(choice.target === 'time' ? { datetimeRepresents: choice.value } : {}),
      }),
    [run]
  );
  const clear = useCallback(() => {
    controllerRef.current?.abort();
    setState({ status: 'idle' });
  }, []);

  return { state, submit, resolve, clear };
}
