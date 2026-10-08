import { ReactiveError } from "./error";

export type Caller = { realm: number; principal: number };
export type AcquireCaller = (caller: Caller, signal?: AbortSignal) => Promise<() => void>;

/** Native preparation/receipt coordination across same-origin tabs. This is not
 * query admission or authority: the durable requester still owns those bounds.
 * Hold the lease across an uncertain mutation until its exact retry resolves. */
export const acquireCaller: AcquireCaller = (caller, signal) => {
  if (!globalThis.navigator?.locks) throw new ReactiveError(0, "caller_coordination_unavailable");
  return new Promise((resolve, reject) => {
    let release!: () => void;
    const held = new Promise<void>((done) => {
      release = done;
    });
    void navigator.locks
      .request(
        `transit-caller-v1:${caller.realm}:${caller.principal}`,
        { mode: "exclusive", ...(signal ? { signal } : {}) },
        async () => {
          resolve(release);
          await held;
        },
      )
      .catch(reject);
  });
};
