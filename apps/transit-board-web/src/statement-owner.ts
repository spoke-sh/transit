import { StatementReader, type ResultView } from "@transit/query-client";
import { readFailure } from "./observation";
import {
  initialStatement,
  statementBusy,
  statementTransition,
  type StatementEvent,
} from "./statement-state";

export class StatementOwner {
  state = initialStatement();
  view: ResultView | null = null;
  submitted = "";
  cleanup = "";
  private reader: StatementReader | null = null;
  private controller: AbortController | null = null;
  private timer: ReturnType<typeof setTimeout> | undefined;
  private failures = 0;
  constructor(
    private readonly changed: () => void,
    private readonly denied: () => void,
  ) {}

  run(sql: string, expected: string | null) {
    if (
      this.state.disposed ||
      !this.state.visible ||
      !this.state.available ||
      statementBusy(this.state)
    )
      return;
    const reader = new StatementReader(sql, undefined, undefined, expected);
    const previous = this.reader;
    this.reader = reader;
    this.submitted = sql;
    this.send({ type: "run", reader: reader.id }, previous);
  }

  send(event: StatementEvent, previous = this.reader) {
    const next = statementTransition(this.state, event);
    if (next.state === this.state) return;
    this.state = next.state;
    if (!this.state.disclosed) this.view = null;
    if (!this.state.reader) this.reader = null;
    let closing: Promise<void> = Promise.resolve();
    for (const effect of next.effects) {
      if (effect.type === "cancel") {
        clearTimeout(this.timer);
        this.controller?.abort();
        this.controller = null;
      } else if (effect.type === "close") {
        if (previous?.id === effect.reader)
          closing = previous.close().then(
            () => {
              this.cleanup = "";
              this.notify();
            },
            () => {
              this.cleanup = "Result release is unconfirmed; its server lifetime still applies.";
              this.notify();
            },
          );
      } else {
        const reader = this.reader;
        if (!reader || reader.id !== effect.reader) continue;
        const controller = new AbortController();
        this.controller = controller;
        void closing
          .then(async () => {
            controller.signal.throwIfAborted();
            if (this.state.reader !== reader.id || this.state.generation !== effect.generation)
              throw new DOMException("Replaced statement presentation", "AbortError");
            return reader[effect.type === "observe" ? "refresh" : effect.type](controller.signal);
          })
          .then(
            (view) => {
              if (
                controller.signal.aborted ||
                this.state.reader !== reader.id ||
                this.state.generation !== effect.generation
              )
                return;
              this.view = view;
              this.failures = 0;
              this.send({ type: "received", reader: reader.id, generation: effect.generation });
              this.schedule(5000);
            },
            (cause: unknown) => {
              if (
                controller.signal.aborted ||
                this.state.reader !== reader.id ||
                this.state.generation !== effect.generation
              )
                return;
              const failure = readFailure(cause);
              this.send({
                type: "failed",
                reader: reader.id,
                generation: effect.generation,
                failure,
              });
              if (failure.kind === "denied") this.denied();
              if (failure.retryable)
                this.schedule(Math.min(30000, 5000 * 2 ** Math.min(3, ++this.failures)));
            },
          );
      }
    }
    this.notify();
  }

  private schedule(delay: number) {
    clearTimeout(this.timer);
    if (this.state.visible && this.state.available && this.state.reader && !this.state.disposed)
      this.timer = setTimeout(() => this.send({ type: "observe" }), delay);
  }
  private notify() {
    if (!this.state.disposed) this.changed();
  }
}
