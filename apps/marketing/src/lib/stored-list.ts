"use client";

import { useCallback, useMemo, useSyncExternalStore } from "react";

const EMPTY = "[]";
const listeners = new Set<() => void>();

/**
 * A list of strings kept in `localStorage`, read the way React wants an
 * external store read: the server snapshot is empty, so the HTML never claims
 * to know what a particular browser remembers and the stored value arrives on
 * hydration instead of fighting it.
 *
 * Every failure is swallowed on purpose. A browser that refuses storage — a
 * private window, a locked-down profile — costs the memory, never the action
 * the caller was about to take.
 */
export function useStoredList(key: string): readonly [readonly string[], (value: string) => void] {
  const raw = useSyncExternalStore(
    subscribe,
    () => read(key),
    () => EMPTY,
  );

  const values = useMemo<readonly string[]>(() => {
    try {
      const parsed: unknown = JSON.parse(raw);
      return Array.isArray(parsed)
        ? parsed.filter((value): value is string => typeof value === "string")
        : [];
    } catch {
      return [];
    }
  }, [raw]);

  const add = useCallback(
    (value: string) => {
      if (values.includes(value)) return;
      try {
        window.localStorage.setItem(key, JSON.stringify([...values, value]));
      } catch {
        return;
      }
      for (const listener of listeners) listener();
    },
    [key, values],
  );

  return [values, add] as const;
}

function subscribe(onChange: () => void): () => void {
  listeners.add(onChange);
  window.addEventListener("storage", onChange);
  return () => {
    listeners.delete(onChange);
    window.removeEventListener("storage", onChange);
  };
}

function read(key: string): string {
  try {
    return window.localStorage.getItem(key) ?? EMPTY;
  } catch {
    return EMPTY;
  }
}
