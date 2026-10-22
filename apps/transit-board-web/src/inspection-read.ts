import { BoardError } from "@transit/board-client";

/** Recover a throttled read without synchronizing with the five-second polls. */
export async function retryInspectionRead<T>(
  load: () => Promise<T>,
  signal: AbortSignal,
  visible: () => boolean,
  throttled: (cause: BoardError) => void = () => {},
): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    signal.throwIfAborted();
    if (!visible()) throw new DOMException("Inspection hidden", "AbortError");
    try {
      return await load();
    } catch (cause) {
      if (
        !(cause instanceof BoardError) ||
        cause.status !== 429 ||
        cause.code !== "RateLimited" ||
        attempt >= 3
      )
        throw cause;
      signal.throwIfAborted();
      if (!visible()) throw new DOMException("Inspection hidden", "AbortError");
      throttled(cause);
      await new Promise<void>((resolve, reject) => {
        signal.throwIfAborted();
        const abort = () => {
          clearTimeout(timer);
          reject(signal.reason);
        };
        const timer = setTimeout(() => {
          signal.removeEventListener("abort", abort);
          resolve();
        }, 250);
        signal.addEventListener("abort", abort, { once: true });
      });
    }
  }
}
