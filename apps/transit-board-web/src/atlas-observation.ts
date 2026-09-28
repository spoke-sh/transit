import { useEffect, useState } from "react";
import { atlas, BoardError, type AtlasResponse } from "@rey/transit-board-client";
import { message, useScope } from "./state";
export type AtlasCursor = { position: number; process_after?: number; resource_after?: number };
/** One authorized page and one in-flight acquisition. No global catalog cache. */
export function useAtlasObservation(cursor?: AtlasCursor, revision = 0) {
  const { denied } = useScope();
  const [data, setData] = useState<AtlasResponse | null>(null);
  const [error, setError] = useState("");
  useEffect(() => {
    const abort = new AbortController();
    let timer: ReturnType<typeof setTimeout>;
    let inFlight = false;
    async function refresh() {
      if (abort.signal.aborted || document.hidden || inFlight) return;
      inFlight = true;
      try {
        let next: AtlasResponse | undefined;
        // Definition and data acquisition share the host throttle. Stagger a
        // bounded read retry so equal five-second timers cannot starve a panel.
        for (let attempt = 0; ; attempt++) {
          try {
            next = await atlas(cursor, abort.signal);
            break;
          } catch (cause) {
            if (
              !(cause instanceof BoardError) ||
              cause.status !== 429 ||
              attempt >= 3 ||
              abort.signal.aborted
            )
              throw cause;
            await new Promise((resolve) => setTimeout(resolve, 250));
          }
        }
        if (!abort.signal.aborted && !document.hidden) {
          setData(next);
          setError("");
        }
      } catch (cause) {
        if (!abort.signal.aborted) {
          setData(null);
          setError(message(cause));
          if (cause instanceof BoardError && cause.status === 403) denied();
        }
      } finally {
        inFlight = false;
        if (!abort.signal.aborted && !cursor) timer = setTimeout(() => void refresh(), 5000);
      }
    }
    const visibility = () => {
      clearTimeout(timer);
      if (document.hidden) setData(null);
      else void refresh();
    };
    setData(null);
    void refresh();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      clearTimeout(timer);
      abort.abort();
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [cursor, revision, denied]);
  return { data, error };
}
