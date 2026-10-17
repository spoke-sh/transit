import { Busy, Closed } from "./errors.ts";

/** One admitted operation; closing joins its work before owned cleanup. */
export class Serial {
  #busy = false;
  #closing = false;
  #active: Promise<void> | undefined;
  #close: Promise<void> | undefined;
  run<T>(work: () => Promise<T>): Promise<T> {
    if (this.#closing) return Promise.reject(new Closed("Handle is closing"));
    if (this.#busy) return Promise.reject(new Busy("One operation per handle"));
    this.#busy = true;
    const result = Promise.resolve()
      .then(work)
      .finally(() => {
        this.#busy = false;
      });
    this.#active = result.then(
      () => {},
      () => {},
    );
    return result;
  }
  close(cleanup: () => Promise<void>): Promise<void> {
    if (this.#close) return this.#close;
    this.#closing = true;
    this.#close = (async () => {
      await this.#active;
      await cleanup();
    })();
    return this.#close;
  }
}
