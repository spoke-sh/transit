import { useEffect, useState } from "react";
import { message } from "./state";
import { retryInspectionRead } from "./inspection-read";
export function useMetadata<T>(
  resource: number,
  exchange: string,
  load: (resource: number, exchange: string, signal?: AbortSignal) => Promise<T>,
) {
  const [page, setPage] = useState<T | null>(null);
  const [error, setError] = useState("");
  useEffect(() => {
    const abort = new AbortController();
    let disposed = false;
    let busy = false;
    let timer: ReturnType<typeof setTimeout>;
    async function read() {
      if (disposed || busy || document.hidden) return;
      busy = true;
      try {
        const next = await retryInspectionRead(
          () => load(resource, exchange, abort.signal),
          abort.signal,
          () => !document.hidden,
          (cause) => {
            setPage(null);
            setError(message(cause));
          },
        );
        if (!disposed && !document.hidden) {
          setPage(next);
          setError("");
        }
      } catch (cause) {
        if (!disposed && !document.hidden) {
          setPage(null);
          setError(message(cause));
        }
      } finally {
        busy = false;
        if (!disposed) timer = setTimeout(() => void read(), 5000);
      }
    }
    function visibility() {
      clearTimeout(timer);
      if (document.hidden) setPage(null);
      else timer = setTimeout(() => void read(), 250);
    }
    setPage(null);
    setError("");
    timer = setTimeout(() => void read(), 250);
    document.addEventListener("visibilitychange", visibility);
    return () => {
      disposed = true;
      clearTimeout(timer);
      abort.abort();
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [resource, exchange, load]);
  return { page, error };
}
