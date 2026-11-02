import {
  initialObservation,
  readFailure,
  transition,
  type Observation,
  type ObservationEvent,
} from "./observation";

/** Effect boundary shared by React and deterministic replay/race checks. Only
 * this owner schedules metadata reads; domain result/control owners stay separate. */
export class ObservationOwner<T> {
  state = initialObservation<T>();
  private controller: AbortController | null = null;
  private timer: ReturnType<typeof setTimeout> | undefined;
  private deadline: ReturnType<typeof setTimeout> | undefined;
  constructor(
    private readonly read: (signal: AbortSignal) => Promise<T>,
    private readonly publish: (state: Observation<T>) => void,
    private readonly interval = 5000,
  ) {}

  send(event: ObservationEvent<T>) {
    const next = transition(this.state, event, this.interval);
    this.state = next.state;
    if (this.state.tag !== "disposed") this.publish(this.state);
    for (const effect of next.effects) {
      if (effect.type === "cancel") {
        clearTimeout(this.timer);
        clearTimeout(this.deadline);
        this.controller?.abort();
        this.controller = null;
      } else if (effect.type === "schedule") {
        clearTimeout(this.timer);
        clearTimeout(this.deadline);
        this.timer = setTimeout(() => this.send({ type: "read" }), effect.delay);
      } else {
        const abort = new AbortController();
        this.controller = abort;
        this.deadline = setTimeout(() => {
          abort.abort();
          this.send({
            type: "failed",
            generation: effect.generation,
            failure: { kind: "unavailable", code: "ReadTimeout", retryable: true },
          });
        }, 15000);
        void Promise.resolve()
          .then(() => {
            abort.signal.throwIfAborted();
            return this.read(abort.signal);
          })
          .then(
            (value) => {
              if (this.controller === abort) clearTimeout(this.deadline);
              this.send({ type: "received", generation: effect.generation, value });
            },
            (cause: unknown) => {
              if (this.controller === abort) clearTimeout(this.deadline);
              this.send({
                type: "failed",
                generation: effect.generation,
                failure: readFailure(cause),
              });
            },
          );
      }
    }
  }
}
