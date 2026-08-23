"use client";

import { useCallback, useSyncExternalStore } from "react";

/**
 * A media query as React state, server-safe: the server snapshot is always
 * `false`, so the first client paint matches the HTML and the query only takes
 * effect once the browser has one to answer with.
 */
export function useMediaQuery(query: string): boolean {
  const subscribe = useCallback(
    (onChange: () => void) => {
      const list = window.matchMedia(query);
      list.addEventListener("change", onChange);
      return () => list.removeEventListener("change", onChange);
    },
    [query],
  );

  return useSyncExternalStore(
    subscribe,
    () => window.matchMedia(query).matches,
    () => false,
  );
}
