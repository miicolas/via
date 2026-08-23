type PendingTask = () => void;

/** Runs async work with a bounded number of active tasks. */
export function createAsyncGate(limit: number) {
  if (!Number.isInteger(limit) || limit < 1) {
    throw new Error('An async gate needs a positive integer limit');
  }

  let active = 0;
  const pending: PendingTask[] = [];

  const drain = () => {
    while (active < limit) {
      const next = pending.shift();
      if (!next) return;
      active += 1;
      next();
    }
  };

  return {
    run<T>(work: () => Promise<T>): Promise<T> {
      return new Promise<T>((resolve, reject) => {
        pending.push(() => {
          Promise.resolve()
            .then(work)
            .then(resolve, reject)
            .finally(() => {
              active -= 1;
              drain();
            });
        });
        drain();
      });
    },
  };
}
