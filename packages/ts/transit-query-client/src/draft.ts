import { boundedQueryJson } from "./logical";
import { acquireCaller, type AcquireCaller } from "@transit/reactive-client/caller-gate";
import type { Diagnostic, Draft, Request, Response } from "./types";
import { QueryError, type Transport } from "./transport";
import { verifiedPage, type ResultPage } from "./result";
import { Request as validRequest } from "./validators.js";
import { validateUnifiedQuery } from "./values";

type Compiled = Extract<Response, { compiled: unknown }>["compiled"];
type Connection = Extract<Response, { description: unknown }>["description"]["connection"];
type Prepared = NonNullable<Extract<Response, { prepared: unknown }>["prepared"]>;
type Intent = {
  kind: "open" | "close" | "step" | "cancel";
  request: Request;
  prepared: Prepared | null;
  input: number | null;
  generation: string;
};
type Job = {
  namespace: string;
  generation: string;
  sql: string;
  compiled: Compiled;
  uploading: boolean;
  started: number;
  compileMs: number | null;
  recovered: boolean;
};
export type DraftResult = {
  namespace: string;
  sql: string;
  page: ResultPage;
  compileMs: number | null;
  readyMs: number | null;
  verifyMs: number;
};
export type DraftSnapshot = {
  phase:
    | "idle"
    | "opening"
    | "active"
    | "running"
    | "paused"
    | "exhausted"
    | "uncertain"
    | "failed"
    | "denied";
  detail: string;
  diagnostic: Diagnostic | null;
  budget: Draft | null;
  result: DraftResult | null;
  namespace: string | null;
  recoverable: boolean;
  acceptedWork: boolean;
};
const namespace = () => {
  const bytes = crypto.getRandomValues(new Uint32Array(2));
  return ((BigInt(bytes[0]!) << 32n) | BigInt(bytes[1]!) | 1n).toString();
};
const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);
const record = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const wide = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[1-9][0-9]{0,19}$/.test(value) &&
  BigInt(value) <= 18446744073709551615n;
const fields = (value: Record<string, unknown>, expected: string[]) =>
  Object.keys(value).sort().join(",") === expected.sort().join(",");
type Recovery = {
  version: 1;
  connection: Connection;
  budget: Draft | null;
  job: Pick<Job, "namespace" | "generation" | "compiled" | "uploading"> | null;
  intent: Intent | null;
  closeWanted: boolean;
  cancelWanted: boolean;
  cancelling: boolean;
  namespace: string | null;
};

/** One latest edit, one accepted finite query, one frozen native command. Keep
 * this owner above routes. Native generations, not timers, bound query starts. */
export class DraftSession {
  private listeners = new Set<() => void>();
  private view: DraftSnapshot = {
    phase: "idle",
    detail: "Live draft is off.",
    diagnostic: null,
    budget: null,
    result: null,
    namespace: null,
    recoverable: false,
    acceptedWork: false,
  };
  private connection: Connection | null = null;
  private intent: Intent | null = null;
  private job: Job | null = null;
  private release: (() => void) | null = null;
  private timer: ReturnType<typeof setTimeout> | null = null;
  private busy = false;
  private enabled = false;
  private stopped = false;
  private closeWanted = false;
  private cancelWanted = false;
  private cancelling = false;
  private observeWanted = false;
  private latest = "";
  private editedAt = 0;
  private lastSubmitted = "";
  private reader: AbortController | null = null;
  private restored = false;
  constructor(
    private transport: Transport,
    private coordinate: AcquireCaller = acquireCaller,
  ) {}
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  getSnapshot = () => this.view;
  exportRecovery(): string {
    if (!this.connection || (!this.job && !this.intent))
      throw new QueryError(409, "NoDraftRecovery");
    const job = this.job;
    return JSON.stringify({
      version: 1,
      connection: this.connection,
      budget: this.view.budget,
      job: job
        ? {
            namespace: job.namespace,
            generation: job.generation,
            compiled: job.compiled,
            uploading: job.uploading,
          }
        : null,
      intent: this.intent,
      closeWanted: this.closeWanted,
      cancelWanted: this.cancelWanted,
      cancelling: this.cancelling,
      namespace: this.view.namespace,
    } satisfies Recovery);
  }
  /** Saved bookkeeping supplies no authority. The configured Zig host validates
   * the native token and every continuation; no key or result page is imported. */
  restoreRecovery(source: string) {
    if (
      this.busy ||
      this.job ||
      this.intent ||
      this.enabled ||
      source.length > 131072 ||
      new TextEncoder().encode(source).length > 131072
    )
      throw new QueryError(409, "DraftRecoveryUnavailable");
    const input: unknown = JSON.parse(source);
    if (
      !boundedQueryJson(input) ||
      !record(input) ||
      !fields(input, [
        "version",
        "connection",
        "budget",
        "job",
        "intent",
        "closeWanted",
        "cancelWanted",
        "cancelling",
        "namespace",
      ]) ||
      input.version !== 1 ||
      !record(input.connection) ||
      !fields(input.connection, [
        "realm",
        "principal",
        "role",
        "source",
        "resource",
        "requester",
        "requests",
      ]) ||
      !Object.entries(input.connection).every(
        ([name, value]) =>
          (name === "role" && value === null) ||
          (typeof value === "number" && Number.isSafeInteger(value) && value > 0),
      ) ||
      !validateUnifiedQuery({ draft: input.budget }) ||
      ![input.closeWanted, input.cancelWanted, input.cancelling].every(
        (value) => typeof value === "boolean",
      ) ||
      (input.namespace !== null && !wide(input.namespace))
    )
      throw new QueryError(0, "InvalidDraftRecovery");
    if (
      input.job !== null &&
      (!record(input.job) ||
        !fields(input.job, ["namespace", "generation", "compiled", "uploading"]) ||
        !wide(input.job.namespace) ||
        !wide(input.job.generation) ||
        typeof input.job.uploading !== "boolean" ||
        !validateUnifiedQuery({ compiled: input.job.compiled }))
    )
      throw new QueryError(0, "InvalidDraftRecovery");
    if (
      input.intent !== null &&
      (!record(input.intent) ||
        !fields(input.intent, ["kind", "request", "prepared", "input", "generation"]) ||
        !["open", "close", "step", "cancel"].includes(String(input.intent.kind)) ||
        !validRequest(input.intent.request) ||
        !wide(input.intent.generation) ||
        !validateUnifiedQuery({ prepared: input.intent.prepared }) ||
        (input.intent.input !== null &&
          (typeof input.intent.input !== "number" ||
            !Number.isSafeInteger(input.intent.input) ||
            input.intent.input <= 0 ||
            input.intent.prepared === null)))
    )
      throw new QueryError(0, "InvalidDraftRecovery");
    const value = input as unknown as Recovery;
    if (this.connection && !same(this.connection, value.connection))
      throw new QueryError(409, "DraftScopeChanged");
    if (!value.job && !value.intent) throw new QueryError(0, "InvalidDraftRecovery");
    if (value.intent) {
      const { kind, request, generation } = value.intent;
      if (
        !(
          kind === "open" &&
          "draft_open" in request &&
          (request.draft_open.expected === "0" || wide(request.draft_open.expected)) &&
          wide((BigInt(request.draft_open.expected) + 1n).toString()) &&
          generation === (BigInt(request.draft_open.expected) + 1n).toString()
        ) &&
        !(kind === "close" && "draft_close" in request && request.draft_close === generation) &&
        !(
          kind === "step" &&
          value.job &&
          "next_draft" in request &&
          request.next_draft.namespace === value.job.namespace &&
          request.next_draft.generation === generation &&
          generation === value.job.generation &&
          request.next_draft.bundle === value.job.compiled.bundle
        ) &&
        !(
          kind === "cancel" &&
          value.job &&
          "prepare_control" in request &&
          request.prepare_control.operation === "cancel" &&
          request.prepare_control.namespace === value.job.namespace &&
          generation === value.job.generation
        )
      )
        throw new QueryError(0, "InvalidDraftRecovery");
    }
    this.connection = structuredClone(value.connection);
    this.job = value.job
      ? {
          ...structuredClone(value.job),
          sql: "",
          compileMs: null,
          started: performance.now(),
          recovered: true,
        }
      : null;
    this.intent = structuredClone(value.intent);
    this.closeWanted = value.closeWanted;
    this.cancelWanted = value.cancelWanted;
    this.cancelling = value.cancelling;
    this.stopped = true;
    this.enabled = false;
    this.restored = true;
    this.latest = "";
    this.lastSubmitted = "";
    this.change({
      phase: "paused",
      result: null,
      budget: null,
      namespace: value.namespace,
      detail:
        "Original native identity and bundle restored. Recover explicitly; saved SQL and timing are not treated as execution evidence.",
    });
  }
  private change(value: Partial<DraftSnapshot>) {
    const next = {
      ...this.view,
      diagnostic: null,
      ...value,
      recoverable: this.intent !== null,
      acceptedWork: this.job !== null || this.intent !== null,
      namespace: this.job?.namespace ?? this.view.namespace ?? this.view.result?.namespace ?? null,
    };
    if (
      Object.entries(next).every(([key, value]) => this.view[key as keyof DraftSnapshot] === value)
    )
      return;
    this.view = next;
    for (const listener of this.listeners) listener();
  }
  private wake(delay = 500) {
    if (this.timer !== null) clearTimeout(this.timer);
    if (this.stopped) return;
    this.timer = setTimeout(() => {
      this.timer = null;
      void this.pump();
    }, delay);
  }
  edit(sql: string) {
    if (sql === this.latest) return;
    this.latest = sql;
    this.editedAt = performance.now();
    if (this.enabled) this.wake(1000);
  }
  private async describe() {
    const value = await this.transport({ describe: {} });
    if (!("description" in value) || !("table" in value.description.source.source.source))
      throw new QueryError(409, "DraftRequiresTable");
    if (this.connection && !same(this.connection, value.description.connection))
      throw new QueryError(409, "DraftScopeChanged");
    this.connection = value.description.connection;
    return value.description;
  }
  private async budget(generation: string | null) {
    const value = await this.transport({ draft_status: generation });
    if (!("draft" in value)) throw new QueryError(0, "InvalidResponse");
    return value.draft;
  }
  /** Only a user action may open or explicitly resume a generation. */
  async open(limit = 2) {
    if (
      this.busy ||
      this.intent ||
      this.job ||
      this.cancelWanted ||
      this.cancelling ||
      (this.closeWanted && this.view.budget?.enabled)
    )
      throw new QueryError(409, "RecoverAcceptedDraftFirst");
    if (!Number.isInteger(limit) || limit < 1 || limit > 8)
      throw new QueryError(0, "InvalidDraftLimit");
    this.busy = true;
    try {
      const description = await this.describe();
      if (description.source.active !== null) throw new QueryError(409, "RecoverActiveQueryFirst");
      const current = await this.budget(null);
      this.stopped = false;
      this.enabled = true;
      this.closeWanted = false;
      this.cancelWanted = false;
      if (current?.enabled && current.starts < current.limit) {
        this.change({
          budget: current,
          phase: "active",
          detail: "Resumed the recorded generation; its consumed budget is unchanged.",
        });
      } else {
        this.lastSubmitted = "";
        const expected = current?.generation ?? "0";
        this.intent = {
          kind: "open",
          request: { draft_open: { expected, limit } },
          generation: (BigInt(expected) + 1n).toString(),
          prepared: null,
          input: null,
        };
        this.change({ phase: "opening", detail: "Opening an explicit finite draft generation." });
      }
    } catch (error) {
      this.fail(error);
      throw error;
    } finally {
      this.busy = false;
    }
    this.wake(0);
  }
  /** Local scheduling stops immediately; exact native close follows any already
   * accepted input. Closing cannot cancel or erase a running query. */
  pause() {
    this.enabled = false;
    this.closeWanted = true;
    if (!this.intent?.prepared || this.intent.input !== null) this.stopped = false;
    this.reader?.abort();
    this.change({
      phase: this.stopped ? this.view.phase : "paused",
      detail:
        "Paused locally; native closure remains observable independently of query completion.",
    });
    this.wake(0);
  }
  cancel() {
    this.enabled = false;
    this.cancelWanted = true;
    this.closeWanted = true;
    if (!this.intent?.prepared || this.intent.input !== null) this.stopped = false;
    this.reader?.abort();
    this.wake(0);
  }
  recover() {
    // Explicit recovery settles the retained signature and continues only its
    // original plan. It cannot allocate a replacement namespace or generation.
    this.stopped = false;
    this.observeWanted = true;
    this.wake(0);
  }
  invalidate() {
    this.reader?.abort();
    this.fail(new QueryError(403, "QueryAccessDenied"));
  }
  private fail(error: unknown) {
    // Preparation alone has no native effect. Keep accepted work and signatures,
    // but do not trap recovery behind a failed unsubmitted preparation.
    if (this.intent && !this.intent.prepared && this.intent.input === null) this.intent = null;
    this.stopped = true;
    this.enabled = false;
    const denied = error instanceof QueryError && (error.status === 403 || error.status === 410);
    const changed =
      error instanceof QueryError &&
      ["DraftSourceChanged", "DraftScopeChanged"].includes(error.code);
    if (denied) {
      this.latest = "";
      this.lastSubmitted = "";
    }
    this.change({
      phase: denied
        ? "denied"
        : this.intent?.prepared && this.intent.input === null
          ? "uncertain"
          : "failed",
      detail: error instanceof Error ? error.message : "Draft operation unavailable.",
      diagnostic: error instanceof QueryError ? (error.diagnostic ?? null) : null,
      ...(denied || changed ? { result: null } : {}),
    });
  }
  private async drive(): Promise<boolean> {
    const intent = this.intent;
    if (!intent) return true;
    if (!intent.prepared) {
      if (!this.connection) await this.describe();
      this.release ??= await this.coordinate(this.connection!, AbortSignal.timeout(5000));
      const response = await this.transport(intent.request);
      if (!("prepared" in response)) throw new QueryError(0, "InvalidResponse");
      if (!response.prepared) {
        if (intent.kind !== "step" || !this.job) throw new QueryError(0, "InvalidResponse");
        this.job.uploading = false;
        this.intent = null;
        return true;
      }
      intent.prepared = structuredClone(response.prepared);
      if (
        intent.kind === "step" &&
        (this.closeWanted || this.cancelWanted || (!this.enabled && !this.observeWanted))
      ) {
        this.intent = null;
        return true;
      }
    }
    if (intent.input === null) {
      this.release ??= await this.coordinate(this.connection!, AbortSignal.timeout(5000));
      const response = await this.transport({ submit: structuredClone(intent.prepared) });
      if (!("receipt" in response)) throw new QueryError(0, "InvalidResponse");
      intent.input = response.receipt.position;
      this.release?.();
      this.release = null;
    }
    const value = await this.transport({ observe: intent.input });
    if (!("observation" in value)) throw new QueryError(0, "InvalidResponse");
    if ("pending" in value.observation) return false;
    if ("rejected" in value.observation) {
      // A committed rejection is settled, never an uncertain native submission.
      this.intent = null;
      this.closeWanted = false;
      this.cancelWanted = false;
      throw new QueryError(409, `DraftInputRejected:${intent.input}`);
    }
    if (intent.kind === "open" || intent.kind === "close") {
      const budget = await this.budget(intent.generation);
      if (!budget || budget.generation !== intent.generation)
        throw new QueryError(0, "InvalidResponse");
      this.change({
        budget,
        phase: this.enabled ? "active" : "paused",
        detail: "Native draft generation observed; its recorded budget is unchanged by recovery.",
      });
      if (intent.kind === "close") this.closeWanted = false;
    }
    if (intent.kind === "cancel") {
      this.cancelWanted = false;
      this.cancelling = true;
      if (this.job) this.job.uploading = false;
    }
    this.intent = null;
    return true;
  }
  private async pump() {
    if (this.busy || this.stopped) return;
    this.busy = true;
    try {
      if (
        (this.closeWanted || this.cancelWanted) &&
        this.intent?.kind === "step" &&
        !this.intent.prepared
      )
        this.intent = null;
      if (!(await this.drive())) return;
      if (this.restored && this.job) {
        const current = await this.budget(this.job.generation);
        if (!current || !same(current.contract, this.job.compiled.contract))
          throw new QueryError(409, "DraftSourceChanged");
        this.job.compiled.limits = current.budgets;
        this.change({ budget: current });
      }
      this.restored = false;
      if (!this.job && !this.intent) this.observeWanted = false;
      const selected = this.view.budget;
      if (this.closeWanted) {
        if (selected?.enabled) {
          this.intent = {
            kind: "close",
            request: { draft_close: selected.generation },
            generation: selected.generation,
            prepared: null,
            input: null,
          };
          return;
        }
        this.closeWanted = false;
      }
      if (this.cancelWanted) {
        if (this.job) {
          const current = await this.transport({ status: this.job.namespace });
          if (!("status" in current)) throw new QueryError(0, "InvalidResponse");
          if (current.status === null) {
            this.job = null;
            this.cancelWanted = false;
            return;
          }
          this.intent = {
            kind: "cancel",
            request: { prepare_control: { namespace: this.job.namespace, operation: "cancel" } },
            generation: this.job.generation,
            prepared: null,
            input: null,
          };
          return;
        }
        this.cancelWanted = false;
      }
      if (this.job) {
        const job = this.job;
        if (job.uploading) {
          if (!this.enabled && !this.observeWanted) return;
          this.intent = {
            kind: "step",
            request: {
              next_draft: {
                namespace: job.namespace,
                generation: job.generation,
                bundle: job.compiled.bundle,
              },
            },
            generation: job.generation,
            prepared: null,
            input: null,
          };
          return;
        }
        if (!this.enabled && !this.cancelling && !this.observeWanted) return;
        const observed = await this.transport({ status: job.namespace });
        if (!("status" in observed)) throw new QueryError(0, "InvalidResponse");
        if (
          (observed.status?.phase === "cancelled" && observed.status.collected) ||
          (this.cancelling && observed.status?.phase === "complete")
        ) {
          this.job = null;
          this.cancelling = false;
          this.observeWanted = false;
          this.change({
            phase: "paused",
            detail:
              "The query is terminal. Cancellation cannot undo a completed result; consumed intents remain retained.",
          });
          return;
        }
        if (observed.status?.phase === "denied")
          throw new QueryError(403, "DraftQueryDenied", observed.status.diagnostic);
        if (observed.status?.phase === "rejected" || observed.status?.phase === "retired")
          throw new QueryError(409, "DraftQueryClosed", observed.status.diagnostic);
        if (observed.status?.phase !== "complete") return;
        if (!this.enabled && !this.observeWanted) return;
        const readyMs = job.recovered ? null : performance.now() - job.started;
        const start = performance.now();
        const reader = new AbortController();
        this.reader = reader;
        const page = await verifiedPage(
          job.namespace,
          null,
          job.compiled.limits.segments,
          reader.signal,
          async (namespace, cursor, signal) => {
            const value = await this.transport({ page: { namespace, cursor } }, signal);
            if (!("page" in value)) throw new QueryError(0, "InvalidResponse");
            return value.page;
          },
        );
        if ((!this.enabled && !this.observeWanted) || reader.signal.aborted) return;
        const basis = page.evidence.manifest.basis;
        if (
          basis.cut.kind !== "table" ||
          basis.cut.resource !== job.compiled.source.resource ||
          !same(basis.contract, job.compiled.contract)
        )
          throw new QueryError(409, "DraftSourceChanged");
        const budget = await this.budget(job.generation);
        this.job = null;
        this.observeWanted = false;
        this.change({
          budget,
          phase: this.enabled ? "active" : "paused",
          detail: "Complete finite result verified under current access.",
          result: {
            namespace: job.namespace,
            sql: job.sql,
            page,
            compileMs: job.compileMs,
            readyMs,
            verifyMs: performance.now() - start,
          },
        });
        return;
      }
      if (!this.enabled || !selected) return;
      if (!selected.enabled || selected.starts >= selected.limit) {
        this.enabled = false;
        this.change({
          phase: selected.enabled ? "exhausted" : "paused",
          detail:
            "The recorded generation cannot start more queries. Opening another requires an explicit action.",
        });
        return;
      }
      if (
        !this.latest.trim() ||
        this.latest === this.lastSubmitted ||
        performance.now() - this.editedAt < 1000
      )
        return;
      const sql = this.latest;
      const start = performance.now();
      const value = await this.transport({ compile: { sql } });
      if (!("compiled" in value)) throw new QueryError(0, "InvalidResponse");
      if (!this.enabled || this.latest !== sql) return;
      if (
        !("table" in value.compiled.source.source) ||
        !same(value.compiled.contract, selected.contract)
      )
        throw new QueryError(409, "DraftSourceChanged");
      this.job = {
        namespace: namespace(),
        generation: selected.generation,
        sql,
        compiled: value.compiled,
        uploading: true,
        started: performance.now(),
        compileMs: performance.now() - start,
        recovered: false,
      };
      this.lastSubmitted = sql;
      this.change({
        phase: "running",
        detail:
          "One exact draft is in progress. New edits coalesce without replacing accepted work.",
      });
    } catch (error) {
      if (!(this.reader?.signal.aborted && !this.enabled)) this.fail(error);
    } finally {
      this.reader = null;
      if (!this.intent?.prepared || this.intent.input !== null) {
        this.release?.();
        this.release = null;
      }
      this.busy = false;
      this.change({});
      if (
        this.enabled ||
        this.intent ||
        this.closeWanted ||
        this.cancelWanted ||
        this.cancelling ||
        this.observeWanted
      )
        this.wake();
    }
  }
}
