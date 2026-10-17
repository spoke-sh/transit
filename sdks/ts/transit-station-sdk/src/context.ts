import { TurnExpired } from "@transit/client";
import { Scope } from "./scope.ts";
import type { Bridge } from "./bridge.ts";
import type { GrowingEvent } from "./wire.ts";

export interface Context {
  readonly bridge: Bridge;
  readonly scope: Scope;
  readonly token: number;
  readonly event: GrowingEvent;
}
const contexts = new WeakMap<object, Context>();
export function register(owner: object, value: Context): void {
  contexts.set(owner, value);
}
export function context(owner: object): Context {
  const value = contexts.get(owner);
  if (!value) throw new TurnExpired("Unknown turn");
  return value;
}
export function operation<T>(owner: object, work: (value: Context) => Promise<T>): Promise<T> {
  const current = context(owner);
  return current.scope.operation(() => work(current));
}
export { Scope };
