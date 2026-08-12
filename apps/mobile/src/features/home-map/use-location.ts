import * as Location from 'expo-location';
import { useCallback, useEffect, useRef, useState } from 'react';

import type { UserLocationState } from '@/features/home-map/types';

export function useUserLocation() {
  const mounted = useRef(true);
  const [state, setState] = useState<UserLocationState>({ status: 'loading' });

  const refresh = useCallback(async () => {
    setState({ status: 'loading' });
    try {
      const next = await resolveLocation((cached) => {
        if (mounted.current) setState(cached);
      });
      if (mounted.current) setState(next);
    } catch {
      if (mounted.current) setState({ status: 'error' });
    }
  }, []);

  useEffect(() => {
    mounted.current = true;
    void resolveLocation((cached) => {
      if (mounted.current) setState(cached);
    })
      .then((next) => {
        if (mounted.current) setState(next);
      })
      .catch(() => {
        if (mounted.current) setState({ status: 'error' });
      });

    return () => {
      mounted.current = false;
    };
  }, []);

  return { refresh, state };
}

async function resolveLocation(onCached: (state: UserLocationState) => void) {
  const currentPermission = await Location.getForegroundPermissionsAsync();
  const permission = currentPermission.granted
    ? currentPermission
    : await Location.requestForegroundPermissionsAsync();

  if (!permission.granted) return { status: 'denied' } as const;

  const cached = await Location.getLastKnownPositionAsync({ maxAge: 60_000 });
  if (cached) onCached(toReadyState(cached));

  const current = await Location.getCurrentPositionAsync({
    accuracy: Location.Accuracy.Balanced,
  });
  return toReadyState(current);
}

function toReadyState(location: Location.LocationObject): UserLocationState {
  return {
    status: 'ready',
    coordinate: {
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
    },
  };
}
