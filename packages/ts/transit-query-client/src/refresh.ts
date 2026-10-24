import { acquireCaller, type AcquireCaller } from "@transit/reactive-client/caller-gate";
import { QueryError, type Transport } from "./transport";
import type { Response } from "./types";
import { boundedQueryJson } from "./logical";
import { validateUnifiedQuery } from "./values";

type Connection = Extract<Response, { description: unknown }>["description"]["connection"];
type Compiled = Extract<Response, { compiled: unknown }>["compiled"];
type Frozen = NonNullable<Extract<Response, { prepared: unknown }>["prepared"]>;
type Slot = { namespace: string; operation: string; compiled: Compiled | null; ready: boolean };
type Work = { key: string; template: string; connection: Connection; slots: Slot[] };
type Pending = { namespace: string; token: Frozen; input: number | null };
type Recovery = { version: 1; work: Work; pending: Pending | null };
const wide = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[1-9][0-9]{0,19}$/.test(value) &&
  BigInt(value) <= 18446744073709551615n;
const record = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const fields = (value: Record<string, unknown>, names: string[]) =>
  Object.keys(value).sort().join(",") === names.sort().join(",");
const maxRecoveryBytes = 1048576;
const identity = () => {
  const bytes = crypto.getRandomValues(new Uint32Array(2));
  return ((BigInt(bytes[0]!) << 32n) | BigInt(bytes[1]!) | 1n).toString();
};

/** Prepares a bounded set of independent finite captures before Follow opens.
 * Keep this owner above routes. An uncertain native command retains its exact
 * token and caller lease; another preparation cannot silently replace it. */
export class RefreshPreparation {
  private work: Work | null = null;
  private pending: Pending | null = null;
  private release: (() => void) | null = null;
  private busy = false;
  private restored = false;
  constructor(
    private readonly transport: Transport,
    private readonly coordinate: AcquireCaller = acquireCaller,
  ) {}
  get uncertain() {
    return this.pending !== null;
  }
  /** Save this before leaving the caller. The application owns persistence;
   * exported signatures confer only their original, independently checked rights. */
  exportRecovery(): string {
    if (!this.work) throw new QueryError(409, "NoRefreshRecovery");
    const bytes = JSON.stringify({
      version: 1,
      work: this.work,
      pending: this.pending,
    } satisfies Recovery);
    if (new TextEncoder().encode(bytes).length > maxRecoveryBytes)
      throw new QueryError(0, "RefreshRecoveryTooLarge");
    return bytes;
  }
  /** Import performs no I/O. Explicit prepare resumes only these saved bytes;
   * readiness is rechecked against the host before returning captures. */
  restoreRecovery(source: string) {
    if (this.busy || this.work || this.pending)
      throw new QueryError(409, "RefreshRecoveryUnavailable");
    if (
      source.length > maxRecoveryBytes ||
      new TextEncoder().encode(source).length > maxRecoveryBytes
    )
      throw new QueryError(0, "InvalidRefreshRecovery");
    let input: unknown;
    try {
      input = JSON.parse(source);
    } catch {
      throw new QueryError(0, "InvalidRefreshRecovery");
    }
    if (
      !boundedQueryJson(input) ||
      !record(input) ||
      !fields(input, ["version", "work", "pending"]) ||
      input.version !== 1 ||
      !record(input.work) ||
      !fields(input.work, ["key", "template", "connection", "slots"])
    )
      throw new QueryError(0, "InvalidRefreshRecovery");
    const work = input.work;
    if (
      typeof work.key !== "string" ||
      work.key.length > 1024 ||
      !wide(work.template) ||
      !record(work.connection) ||
      !fields(work.connection, [
        "realm",
        "principal",
        "role",
        "source",
        "resource",
        "requester",
        "requests",
      ]) ||
      !Object.entries(work.connection).every(
        ([name, value]) =>
          (name === "role" && value === null) ||
          (typeof value === "number" && Number.isSafeInteger(value) && value > 0),
      ) ||
      !Array.isArray(work.slots) ||
      work.slots.length < 1 ||
      work.slots.length > 8
    )
      throw new QueryError(0, "InvalidRefreshRecovery");
    const identities = new Set([work.template]);
    let unfinished = false;
    for (const slot of work.slots) {
      if (
        !record(slot) ||
        !fields(slot, ["namespace", "operation", "compiled", "ready"]) ||
        !wide(slot.namespace) ||
        !wide(slot.operation) ||
        typeof slot.ready !== "boolean" ||
        (slot.compiled !== null && !validateUnifiedQuery({ compiled: slot.compiled })) ||
        (slot.ready && (unfinished || slot.compiled === null))
      )
        throw new QueryError(0, "InvalidRefreshRecovery");
      for (const value of [slot.namespace, slot.operation]) {
        if (identities.has(value)) throw new QueryError(0, "InvalidRefreshRecovery");
        identities.add(value);
      }
      if (!slot.ready) unfinished = true;
    }
    if (input.pending !== null) {
      const pending = input.pending,
        first = work.slots.find((slot) => !slot.ready);
      if (
        !record(pending) ||
        !fields(pending, ["namespace", "token", "input"]) ||
        !first ||
        pending.namespace !== first.namespace ||
        first.compiled === null ||
        !record(pending.token) ||
        !validateUnifiedQuery({ prepared: pending.token }) ||
        (pending.input !== null &&
          (typeof pending.input !== "number" ||
            !Number.isSafeInteger(pending.input) ||
            pending.input <= 0))
      )
        throw new QueryError(0, "InvalidRefreshRecovery");
    }
    const saved = input as unknown as Recovery;
    this.work = structuredClone(saved.work);
    this.pending = structuredClone(saved.pending);
    this.restored = true;
  }
  async prepare(
    key: string,
    template: string,
    limit: number,
    signal: AbortSignal,
  ): Promise<string[]> {
    if (this.busy) throw new QueryError(409, "RefreshPreparationBusy");
    if (!Number.isInteger(limit) || limit < 1 || limit > 8 || !wide(template) || key.length > 1024)
      throw new QueryError(0, "InvalidRefreshPreparation");
    this.busy = true;
    try {
      signal.throwIfAborted();
      const description = await this.transport({ describe: {} }, signal);
      if (!("description" in description)) throw new QueryError(0, "InvalidResponse");
      const connection = description.description.connection;
      if (this.work && JSON.stringify(this.work.connection) !== JSON.stringify(connection))
        throw new QueryError(409, "RefreshScopeChanged");
      if (this.work?.key !== key) {
        if (this.work && !this.work.slots.every((slot) => slot.ready)) {
          if (this.work.template !== template || this.work.slots.length !== limit)
            throw new QueryError(409, "RecoverRefreshPreparationFirst");
          // No Follow has consumed an unfinished plan. Resume its original
          // prepared identities after an interrupted explicit start.
          this.work.key = key;
        } else {
          const used = new Set([template]);
          const fresh = () => {
            let value: string;
            do {
              value = identity();
            } while (used.has(value));
            used.add(value);
            return value;
          };
          this.work = {
            key,
            template,
            connection,
            slots: Array.from({ length: limit }, () => ({
              namespace: fresh(),
              operation: fresh(),
              compiled: null,
              ready: false,
            })),
          };
        }
      }
      const work = this.work!;
      if (work.template !== template || work.slots.length !== limit)
        throw new QueryError(409, "RefreshPreparationConflict");
      for (const slot of work.slots) {
        if (slot.ready) {
          if (this.restored) {
            const next = await this.transport(
              {
                next: {
                  namespace: slot.namespace,
                  bundle: slot.compiled!.bundle,
                  prepare_only: true,
                },
              },
              signal,
            );
            const current = await this.transport({ status: slot.namespace }, signal);
            if (
              !("prepared" in next) ||
              next.prepared !== null ||
              !("status" in current) ||
              current.status?.phase !== "prepared"
            )
              throw new QueryError(409, "RefreshRequestAlreadyUsed");
          }
          continue;
        }
        if (!slot.compiled) {
          const compiled = await this.transport(
            { refresh: { template, operation: slot.operation } },
            signal,
          );
          if (!("compiled" in compiled)) throw new QueryError(0, "InvalidResponse");
          slot.compiled = compiled.compiled;
        }
        while (!slot.ready) {
          signal.throwIfAborted();
          if (!this.pending) {
            this.release ??= await this.coordinate(connection, signal);
            const next = await this.transport(
              {
                next: {
                  namespace: slot.namespace,
                  bundle: slot.compiled.bundle,
                  prepare_only: true,
                },
              },
              signal,
            );
            if (!("prepared" in next)) throw new QueryError(0, "InvalidResponse");
            if (!next.prepared) {
              const current = await this.transport({ status: slot.namespace }, signal);
              if (!("status" in current) || current.status?.phase !== "prepared")
                throw new QueryError(409, "RefreshRequestAlreadyUsed");
              slot.ready = true;
              this.unlock();
              continue;
            }
            this.pending = {
              namespace: slot.namespace,
              token: structuredClone(next.prepared),
              input: null,
            };
          }
          const pending = this.pending;
          if (pending.input === null) {
            this.release ??= await this.coordinate(connection, signal);
            const result = await this.transport({ submit: structuredClone(pending.token) }, signal);
            if (!("receipt" in result)) throw new QueryError(0, "InvalidResponse");
            pending.input = result.receipt.position;
            this.unlock();
          }
          const result = await this.transport({ observe: pending.input }, signal);
          if (!("observation" in result)) throw new QueryError(0, "InvalidResponse");
          if ("pending" in result.observation) {
            // Return with exact recovery state instead of spinning or preparing
            // another principal sequence while the requester's outcome is unknown.
            throw new QueryError(503, "RefreshPreparationPending");
          }
          this.pending = null;
          if ("rejected" in result.observation)
            throw new QueryError(409, "RefreshPreparationRejected");
        }
      }
      this.restored = false;
      return [...work.slots.map((slot) => slot.namespace), ...Array<string>(8 - limit).fill("0")];
    } finally {
      if (!this.pending || this.pending.input !== null) this.unlock();
      this.busy = false;
    }
  }
  private unlock() {
    this.release?.();
    this.release = null;
  }
}
