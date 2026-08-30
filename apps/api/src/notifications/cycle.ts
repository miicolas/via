import type { NotificationCycleClaimStore } from "./cycle-claims";

export type NotificationCycleTick = { now: Date; cycle: number };

/**
 * The pipeline shape every notification poller shares: a process-local poll
 * guard, a wall-clock cycle number, named unit claims against a coordination
 * backend, the APNs circuit breaker, and fan-out in waves of a fixed
 * concurrency. Pipelines keep only their matching and production logic and
 * delegate the shape here.
 */
export class NotificationCycle {
  private isPolling = false;
  private circuitTripped = false;

  constructor(
    private readonly options: {
      /** Length of one cycle; ticks within it share a cycle number. */
      cycleMilliseconds?: number;
      /** Wave size for `forEachWave`. Defaults to serial delivery. */
      concurrency?: number;
      claims?: NotificationCycleClaimStore;
      /** Shared circuit-breaker flag; requires `claims`. */
      circuit?: { key: string; ttlSeconds: number };
      now?: () => Date;
    },
  ) {}

  /** Runs one poll body, or answers `idle` while a poll is already in flight. */
  async poll<T>(
    idle: T,
    body: (tick: NotificationCycleTick) => Promise<T>,
  ): Promise<T> {
    if (this.isPolling) return idle;
    this.isPolling = true;
    this.circuitTripped = false;
    const now = this.options.now?.() ?? new Date();
    const cycle = this.options.cycleMilliseconds
      ? Math.floor(now.getTime() / this.options.cycleMilliseconds)
      : 0;
    try {
      return await body({ now, cycle });
    } finally {
      this.isPolling = false;
    }
  }

  /** Claims a named unit of work; always true without a claim backend. */
  async claim(unit: string, ttlSeconds: number): Promise<boolean> {
    if (!this.options.claims) return true;
    return this.options.claims.claim(unit, ttlSeconds);
  }

  /** Releases a claimed unit so a later cycle can retry it. */
  async release(unit: string): Promise<void> {
    await this.options.claims?.release(unit);
  }

  /** True once the circuit opened during this poll, here or in another worker. */
  get circuitOpen(): boolean {
    return this.circuitTripped;
  }

  /** Reads the shared circuit flag; call at the start of a poll. */
  async checkCircuit(): Promise<boolean> {
    const { circuit, claims } = this.options;
    this.circuitTripped = Boolean(
      circuit && claims && (await claims.isSet(circuit.key)),
    );
    return this.circuitTripped;
  }

  /** Opens the circuit for every worker; local state opens even when the backend write fails. */
  async tripCircuit(): Promise<void> {
    this.circuitTripped = true;
    const { circuit, claims } = this.options;
    if (!circuit || !claims) return;
    await claims.set(circuit.key, circuit.ttlSeconds).catch(() => undefined);
  }

  /** Fans work out in waves of `concurrency`, stopping once the circuit opens. */
  async forEachWave<T>(
    items: readonly T[],
    wave: (batch: T[]) => Promise<unknown>,
  ): Promise<void> {
    const concurrency = this.options.concurrency ?? 1;
    for (let start = 0; start < items.length; start += concurrency) {
      if (this.circuitTripped) return;
      await wave(items.slice(start, start + concurrency));
    }
  }
}
