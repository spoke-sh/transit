/** Optional host scheduling around a complete transport operation, including body
 * consumption. This changes neither authorization nor retry/operation identity. */
export type RequestLane = "read" | "control";
export type RequestScheduler = <T>(
  lane: RequestLane,
  work: () => Promise<T>,
  signal?: AbortSignal,
) => Promise<T>;

let scheduler: RequestScheduler = async (_lane, work, signal) => {
  signal?.throwIfAborted();
  return work();
};

/** Install once at application composition, never inside a request or component. */
export function setRequestScheduler(next: RequestScheduler): () => void {
  const previous = scheduler;
  scheduler = next;
  return () => {
    if (scheduler === next) scheduler = previous;
  };
}

export const scheduleRequest: RequestScheduler = (lane, work, signal) =>
  scheduler(lane, work, signal);
