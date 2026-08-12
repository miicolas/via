import { useEffect, useState } from 'react';

/**
 * 15 s granularity is invisible on a whole-minute display and costs four
 * renders a minute.
 */
const TICK_MS = 15_000;

/**
 * The current time, re-rendered on a coarse tick. Countdowns derive from this
 * so they keep moving between two polls.
 */
export function useNow(): Date {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), TICK_MS);
    return () => clearInterval(timer);
  }, []);

  return now;
}
