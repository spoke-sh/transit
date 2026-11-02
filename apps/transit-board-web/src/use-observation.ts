import { useEffect, useRef, useState } from "react";
import {
  initialObservation,
  readFailure,
  transition,
  type Observation,
  type ObservationEvent,
} from "./observation";

/** One observation owner per scoped key. Replacements never expose old state. */
export function useRead<T>(
  key: string,
  read: (signal: AbortSignal) => Promise<T>,
  interval = 5000,
  observeVisibility = true,
) {
  const [snapshot, setSnapshot] = useState<{ key: string; state: Observation<T> }>(() => ({
    key,
    state: initialObservation<T>(),
  }));
  const [retry, setRetry] = useState(0);
  const loader = useRef(read);
  loader.current = read;
  useEffect(() => {
    let state = initialObservation<T>();
    let controller: AbortController | null = null;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let deadline: ReturnType<typeof setTimeout> | undefined;
    // Capture this scope's reader. An old effect cannot use a new scope's loader.
    const load = loader.current;
    function send(event: ObservationEvent<T>) {
      const next = transition(state, event, interval);
      state = next.state;
      if (state.tag !== "disposed") setSnapshot({ key, state });
      for (const effect of next.effects) {
        if (effect.type === "cancel") {
          clearTimeout(timer);
          clearTimeout(deadline);
          controller?.abort();
          controller = null;
        } else if (effect.type === "schedule") {
          clearTimeout(timer);
          clearTimeout(deadline);
          timer = setTimeout(() => send({ type: "read" }), effect.delay);
        } else {
          const abort = new AbortController();
          controller = abort;
          deadline = setTimeout(() => {
            abort.abort();
            send({
              type: "failed",
              generation: effect.generation,
              failure: { kind: "unavailable", code: "ReadTimeout", retryable: true },
            });
          }, 15000);
          void Promise.resolve()
            .then(() => {
              abort.signal.throwIfAborted();
              return load(abort.signal);
            })
            .then(
              (value) => {
                if (controller === abort) clearTimeout(deadline);
                send({ type: "received", generation: effect.generation, value });
              },
              (cause: unknown) => {
                if (controller === abort) clearTimeout(deadline);
                send({
                  type: "failed",
                  generation: effect.generation,
                  failure: readFailure(cause),
                });
              },
            );
        }
      }
    }
    const visibility = () => send({ type: document.hidden ? "hide" : "show" });
    send({ type: observeVisibility && document.hidden ? "hide" : "read" });
    if (observeVisibility) document.addEventListener("visibilitychange", visibility);
    return () => {
      document.removeEventListener("visibilitychange", visibility);
      send({ type: "dispose" });
    };
  }, [key, retry, interval, observeVisibility]);
  const state = snapshot.key === key ? snapshot.state : initialObservation<T>();
  return { ...state, retry: () => setRetry((value) => value + 1) };
}
