import { QueryError } from "@transit/query-client";
import type { RequestLane } from "@transit/reactive-client";

type Job = { run: () => Promise<void>; cancel: () => void; signal?: AbortSignal };
export type RequestCounts = { read: number; control: number };
export const requestLimits: RequestCounts = { read: 2, control: 1 };

/** Pure admission owner, also exercised by the finite model replay. */
export function admitRequest(
  state: RequestCounts,
  lane: RequestLane,
  event: "start" | "finish",
): RequestCounts {
  if (event === "start")
    return state[lane] < requestLimits[lane] ? { ...state, [lane]: state[lane] + 1 } : state;
  return state[lane] > 0 ? { ...state, [lane]: state[lane] - 1 } : state;
}

/** One tab, bounded FIFO queues. A permit lasts through body consumption, even
 * when an aborted transport settles late. Controls cannot be starved by reads. */
export class RequestScheduler {
  private active: RequestCounts = { read: 0, control: 0 };
  private pending: Record<RequestLane, Job[]> = { read: [], control: [] };
  private timer: ReturnType<typeof setTimeout> | undefined;
  constructor(private readonly staggerMs = 75) {}

  readonly run = <T>(
    lane: RequestLane,
    work: () => Promise<T>,
    signal?: AbortSignal,
  ): Promise<T> => {
    if (signal?.aborted) return Promise.reject(signal.reason);
    if (this.pending[lane].length >= (lane === "read" ? 60 : 4))
      return Promise.reject(new QueryError(429, "ReadQueueCapacity"));
    return new Promise<T>((resolve, reject) => {
      const job: Job = {
        signal,
        cancel: () => {
          const index = this.pending[lane].indexOf(job);
          if (index < 0) return;
          this.pending[lane].splice(index, 1);
          signal?.removeEventListener("abort", job.cancel);
          reject(signal?.reason);
          this.wake();
        },
        run: async () => {
          try {
            signal?.throwIfAborted();
            resolve(await work());
          } catch (cause) {
            reject(cause);
          } finally {
            this.active = admitRequest(this.active, lane, "finish");
            this.wake();
          }
        },
      };
      this.pending[lane].push(job);
      signal?.addEventListener("abort", job.cancel, { once: true });
      this.wake();
    });
  };

  private start(lane: RequestLane) {
    if (!this.pending[lane].length) return;
    const next = admitRequest(this.active, lane, "start");
    if (next === this.active) return;
    this.active = next;
    const job = this.pending[lane].shift()!;
    job.signal?.removeEventListener("abort", job.cancel);
    void job.run();
  }

  private wake() {
    this.start("control");
    if (!this.pending.read.length) {
      clearTimeout(this.timer);
      this.timer = undefined;
    } else if (this.active.read < requestLimits.read && this.timer === undefined) {
      this.timer = setTimeout(() => {
        this.timer = undefined;
        this.start("read");
        this.wake();
      }, this.staggerMs);
    }
  }

  snapshot() {
    return { ...this.active, queued: this.pending.read.length + this.pending.control.length };
  }
}
