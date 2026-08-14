import type { Coordinate, NetworkStation, RouteBadge, StationsInArea } from '@via/contract';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { api } from '@/lib/api';
import {
  tileBounds,
  tilesForRegion,
  TILE_SIZE_DEGREES,
  type TileBounds,
  type ViewportRegion,
} from '@/lib/viewport-tiles';

/**
 * Station markers start fading in at `STATION_HIDE_DELTA` (0.012°, metro-map).
 * Fetching from twice that zoom means a tile's stations are already in memory
 * by the time its markers become visible — the loading is real but the user
 * never sees it happen.
 */
const AREA_FETCH_MAX_LONGITUDE_DELTA = 0.024;

/** Long enough to skip fetches mid-gesture, short beside the pre-fetch zoom margin. */
const VIEWPORT_DEBOUNCE_MS = 250;

/** The one remote operation viewport loading needs. */
export type AreaStationsPort = {
  load: (bounds: TileBounds, signal: AbortSignal) => Promise<StationsInArea>;
};

export type AreaStations = {
  /** Every station the visited tiles brought in, deduplicated. */
  stations: NetworkStation[];
  /** The badges those stations' `routeIds` point to, deduplicated. */
  routes: RouteBadge[];
  /** Feed it every camera movement; it decides what, and whether, to fetch. */
  reportViewport: (region: ViewportRegion) => void;
  /** Loads the tiles around a point right away — for the nearest-station lookup. */
  ensureArea: (coordinate: Coordinate) => void;
};

/**
 * Loads stations tile by tile as the user moves the map, so only what is (about
 * to be) on screen is ever requested. Visited tiles stay cached for the session
 * — panning back is free — and each tile request is small and HTTP-cacheable.
 */
export function useAreaStations(port: AreaStationsPort = apiAreaStationsPort): AreaStations {
  const loadedTiles = useRef(new Map<string, StationsInArea>());
  const inFlightTiles = useRef(new Set<string>());
  const debounceTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const abort = useRef<AbortController>(undefined);
  const [loadedVersion, setLoadedVersion] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    abort.current = controller;
    return () => {
      controller.abort();
      if (debounceTimer.current) clearTimeout(debounceTimer.current);
    };
  }, []);

  const fetchTiles = useCallback(
    (keys: string[]) => {
      const signal = abort.current?.signal;
      if (!signal) return;

      for (const key of keys) {
        if (loadedTiles.current.has(key) || inFlightTiles.current.has(key)) continue;
        inFlightTiles.current.add(key);
        port
          .load(tileBounds(key), signal)
          .then((area) => {
            loadedTiles.current.set(key, area);
            setLoadedVersion((version) => version + 1);
          })
          .catch(() => {
            // Transient by construction: the tile stays unloaded, and the next
            // viewport report retries it. No error surface — the map without
            // this tile's stations is exactly the map one zoom level out.
          })
          .finally(() => inFlightTiles.current.delete(key));
      }
    },
    [port]
  );

  const reportViewport = useCallback(
    (region: ViewportRegion) => {
      if (region.longitudeDelta > AREA_FETCH_MAX_LONGITUDE_DELTA) return;
      if (debounceTimer.current) clearTimeout(debounceTimer.current);
      debounceTimer.current = setTimeout(
        () => fetchTiles(tilesForRegion(region)),
        VIEWPORT_DEBOUNCE_MS
      );
    },
    [fetchTiles]
  );

  const ensureArea = useCallback(
    (coordinate: Coordinate) => {
      fetchTiles(
        tilesForRegion({
          ...coordinate,
          latitudeDelta: TILE_SIZE_DEGREES,
          longitudeDelta: TILE_SIZE_DEGREES,
        })
      );
    },
    [fetchTiles]
  );

  const { stations, routes } = useMemo(() => {
    const stationById = new Map<string, NetworkStation>();
    const routeById = new Map<string, RouteBadge>();
    for (const area of loadedTiles.current.values()) {
      for (const station of area.stations) stationById.set(station.id, station);
      for (const route of area.routes) routeById.set(route.id, route);
    }
    return { stations: [...stationById.values()], routes: [...routeById.values()] };
    // loadedVersion is the change signal for the ref-held tile map.
  }, [loadedVersion]);

  return { stations, routes, reportViewport, ensureArea };
}

const apiAreaStationsPort: AreaStationsPort = {
  load: (bounds, signal) => api.network.stationsInArea(bounds, { signal }),
};
