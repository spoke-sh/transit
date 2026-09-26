import { AsyncLocalStorage } from "node:async_hooks";
import { Busy, Closed, HandlerError, TurnExpired } from "@transit/client";

const context = new AsyncLocalStorage<Scope>();

/** A thenable records observation without retaining an unbounded list of calls. */
class Operation<T> implements Promise<T> {
  readonly [Symbol.toStringTag] = "Promise";
  readonly #value: Promise<T>;
  readonly #observe: () => void;
  #observed = false;
  constructor(value: Promise<T>, observe: () => void) {
    this.#value = value;
    this.#observe = observe;
  }
  #observing(): void {
    if (!this.#observed) {
      this.#observed = true;
      this.#observe();
    }
  }
  // This intentional thenable lets await record observation of a scoped call.
  // oxlint-disable-next-line unicorn/no-thenable
  then<TResult1 = T, TResult2 = never>(
    fulfilled?: ((value: T) => TResult1 | PromiseLike<TResult1>) | null,
    rejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): Promise<TResult1 | TResult2> {
    this.#observing();
    return this.#value.then(fulfilled, rejected);
  }
  catch<TResult = never>(
    rejected?: ((reason: unknown) => TResult | PromiseLike<TResult>) | null,
  ): Promise<T | TResult> {
    this.#observing();
    return this.#value.catch(rejected);
  }
  finally(finished?: (() => void) | null): Promise<T> {
    this.#observing();
    return this.#value.finally(finished);
  }
}

export class Scope {
  readonly #stopped: () => boolean;
  #active = true;
  #busy = false;
  #unobserved = 0;
  #owned: Promise<void> | undefined;
  constructor(stopped: () => boolean) {
    this.#stopped = stopped;
  }
  invoke<T>(handler: () => Promise<T>): Promise<T> {
    return context.run(this, handler);
  }
  check(): void {
    if (!this.#active) throw new TurnExpired("Turn scope has ended");
    if (context.getStore() !== this)
      throw new Busy("Turn operations belong to their handler context");
    if (this.#stopped()) throw new Closed("Local stop requested; no implicit acknowledgement");
  }
  operation<T>(work: () => Promise<T>): Promise<T> {
    this.check();
    if (this.#busy) throw new Busy("One operation per private turn");
    this.#busy = true;
    this.#unobserved++;
    let started: Promise<T>;
    // Start synchronously so codecs and owned-byte copies precede an async boundary.
    try {
      started = work();
    } catch (error) {
      started = Promise.reject(error);
    }
    const value = started.finally(() => {
      this.#busy = false;
    });
    // Observe native completion internally even if the application drops its task.
    this.#owned = value.then(
      () => {},
      () => {},
    );
    return new Operation(value, () => {
      this.#unobserved--;
    });
  }
  async seal(): Promise<HandlerError | undefined> {
    const unfinished = this.#busy || this.#unobserved !== 0;
    this.#active = false;
    await this.#owned;
    return unfinished
      ? new HandlerError("A turn operation outlived the handler or was not observed")
      : undefined;
  }
}
