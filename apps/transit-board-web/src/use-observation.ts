import { useEffect, useRef, useState } from "react";
import { initialObservation, type Observation } from "./observation";
import { ObservationOwner } from "./observation-owner";

/** One owner per scoped key; replacement clears disclosure during render. */
export function useRead<T>(
  key: string,
  read: (signal: AbortSignal) => Promise<T>,
  interval = 5000,
  observeVisibility = true,
  active = true,
) {
  const [snapshot, setSnapshot] = useState<{ key: string; state: Observation<T> }>(() => ({
    key,
    state: initialObservation<T>(),
  }));
  const loader = useRef(read);
  loader.current = read;
  const owner = useRef<ObservationOwner<T> | null>(null);
  useEffect(() => {
    const current = new ObservationOwner(
      loader.current,
      (state) => setSnapshot({ key, state }),
      interval,
    );
    owner.current = current;
    const visibility = () => current.send({ type: !active || document.hidden ? "hide" : "show" });
    current.send({ type: !active || (observeVisibility && document.hidden) ? "hide" : "read" });
    if (observeVisibility) document.addEventListener("visibilitychange", visibility);
    return () => {
      document.removeEventListener("visibilitychange", visibility);
      current.send({ type: "dispose" });
      if (owner.current === current) owner.current = null;
    };
  }, [key, interval, observeVisibility, active]);
  const state = snapshot.key === key ? snapshot.state : initialObservation<T>();
  return { ...state, retry: () => owner.current?.send({ type: "read" }) };
}
