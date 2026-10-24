import { diagnosticLines } from "@transit/diagnostics";
import {
  ReactiveError,
  Session,
  type Inspection,
  type RefreshView,
  type ServerMessage,
  currentDefinition,
} from "./index";
import { sameRecoveryValue } from "./session-recovery";

type Recovery = {
  version: 1;
  definition: typeof currentDefinition;
  template: string | null;
  key: string;
  limit: number;
  captures: string[] | null;
  closing: boolean;
};
const namespace = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[1-9][0-9]{0,19}$/.test(value) &&
  BigInt(value) <= 18446744073709551615n;

export type Basis = Inspection["observation"]["basis"];
const max = (a: bigint, b: bigint) => (a > b ? a : b);
const sameSource = (a: Basis, b: Basis) =>
  a.resource === b.resource &&
  a.partition === b.partition &&
  a.contract.length === b.contract.length &&
  a.contract.every((v, i) => v === b.contract[i]) &&
  a.schema.length === b.schema.length &&
  a.schema.every((v, i) => v === b.schema[i]);
export type ViewPhase =
  | "paused"
  | "loading"
  | "current"
  | "refreshing"
  | "disconnected"
  | "reset_required"
  | "denied";
export type Snapshot<T> = { value: T; basis: Basis; namespace?: string };
export type ViewState<T> = {
  phase: ViewPhase;
  snapshot: Snapshot<T> | null;
  refresh: RefreshView | null;
  detail: string;
  operationDetail: string;
};
export type ViewReader<T> = (signal: AbortSignal, namespace?: string) => Promise<Snapshot<T>>;
const sleep = (ms: number, signal: AbortSignal) =>
  new Promise<void>((resolve) => {
    if (signal.aborted) return resolve();
    const done = () => {
      clearTimeout(timer);
      signal.removeEventListener("abort", done);
      resolve();
    };
    const timer = setTimeout(done, ms);
    signal.addEventListener("abort", done, { once: true });
  });

/** Bounded live-view owner, independent of rendering. One stream, one read,
 * one newest dirty watermark and one finite refresh intent. An explicit start
 * may open a session; reconnect never does. Hosts call pause on hide/unmount. */
export class LiveView<T> {
  private state: ViewState<T> = {
    phase: "paused",
    snapshot: null,
    refresh: null,
    detail: "Follow is off.",
    operationDetail: "",
  };
  private listeners = new Set<() => void>();
  private abort: AbortController | null = null;
  private task: Promise<void> | null = null;
  private closing: Promise<void> | null = null;
  private dirty = 0n;
  private sentDirty = 0n;
  private observedBasis: Basis | null = null;
  private epoch = 0;
  private intent = 0;
  private starting = false;
  private connected = false;
  private attached = false;
  private needsObservation = false;
  private template: string | null = null;
  private captureKey = "";
  private captures: string[] | null = null;
  private limit = 8;
  private restored = false;
  private closingIntent = false;
  private recoveredSnapshot: string | null = null;
  constructor(
    readonly session: Session,
    private readonly read: ViewReader<T>,
    private readonly prepareCaptures?: (
      key: string,
      template: string,
      limit: number,
      signal: AbortSignal,
    ) => Promise<string[]>,
    private readonly persist: () => void = () => {},
  ) {}
  get recoverable() {
    return this.captureKey !== "" && !this.following;
  }
  get recoveryIdentity() {
    return this.captureKey
      ? {
          key: this.captureKey,
          template: this.template,
          limit: this.limit,
          captures: this.captures ? [...this.captures] : null,
        }
      : null;
  }
  exportRecovery(): string | null {
    if (!this.captureKey) return null;
    return JSON.stringify({
      version: 1,
      definition: currentDefinition,
      template: this.template,
      key: this.captureKey,
      limit: this.limit,
      captures: this.captures,
      closing: this.closingIntent,
    } satisfies Recovery);
  }
  /** Import is inert and retains no displayed data. Explicit resume preserves
   * the original capture identities and finite budget. */
  restoreRecovery(source: string) {
    if (this.captureKey || this.starting || this.task || this.closing)
      throw new ReactiveError(409, "view_recovery_busy");
    let value: Recovery;
    try {
      if (source.length > 4096) throw new Error();
      value = JSON.parse(source) as Recovery;
      if (
        !value ||
        Object.keys(value).sort().join(",") !==
          "captures,closing,definition,key,limit,template,version" ||
        value.version !== 1 ||
        value.definition !== currentDefinition ||
        typeof value.closing !== "boolean" ||
        (value.template !== null && !namespace(value.template)) ||
        typeof value.key !== "string" ||
        !value.key.length ||
        value.key.length > 1024 ||
        !Number.isInteger(value.limit) ||
        value.limit < 1 ||
        value.limit > 8 ||
        (value.captures !== null &&
          (!value.template ||
            !Array.isArray(value.captures) ||
            value.captures.length !== 8 ||
            !value.captures.every((id, i) =>
              i < value.limit ? namespace(id) && id !== value.template : id === "0",
            ) ||
            new Set(value.captures.slice(0, value.limit)).size !== value.limit))
      )
        throw new Error();
    } catch {
      throw new ReactiveError(0, "invalid_view_recovery");
    }
    this.template = value.template;
    this.captureKey = value.key;
    this.limit = value.limit;
    this.captures = value.captures;
    this.closingIntent = value.closing;
    this.restored = true;
    this.publish({
      phase: "paused",
      snapshot: null,
      refresh: null,
      detail: "Saved Follow is paused. Resume explicitly to check its original scope and budget.",
    });
  }
  async resume() {
    if (this.starting || this.task || this.closing) return;
    if (!this.captureKey) throw new ReactiveError(409, "view_recovery_absent");
    if (this.closingIntent) return this.recover();
    this.restored = true;
    this.recoveredSnapshot = null;
    this.launch(this.limit, "Recovering the saved Follow and its original budget…");
  }
  get stopping() {
    return this.closing !== null;
  }
  get following() {
    return this.task !== null && !this.abort?.signal.aborted;
  }
  getSnapshot = () => this.state;
  subscribe = (listener: () => void) => {
    if (this.listeners.size >= 4) throw new ReactiveError(429, "view_listener_capacity");
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  private observe(basis: Basis, changed: string) {
    const previous = this.observedBasis ?? this.state.snapshot?.basis;
    if (previous && !sameSource(previous, basis)) throw new ReactiveError(409, "reset_required");
    this.observedBasis = basis;
    this.dirty = max(this.dirty, BigInt(changed));
  }
  private publish(update: Partial<ViewState<T>>) {
    if (
      update.snapshot &&
      this.observedBasis &&
      !sameSource(update.snapshot.basis, this.observedBasis)
    )
      throw new ReactiveError(409, "reset_required");
    this.state = { ...this.state, ...update };
    for (const listener of this.listeners) listener();
  }
  private fail(error: unknown) {
    if (error instanceof ReactiveError && error.clearsProtectedState) {
      this.publish({
        phase:
          error.status === 403 ||
          error.reason === "denied" ||
          error.scopeFailure?.reason === "denied"
            ? "denied"
            : "paused",
        snapshot: null,
        refresh: null,
        operationDetail: "",
        detail:
          (error.diagnostic ? diagnosticLines(error.diagnostic).join("\n") : error.reason) +
          (error.scopeFailure ? `\nCurrent scope: ${error.scopeFailure.reason}.` : ""),
      });
      this.abort?.abort();
    } else if (error instanceof ReactiveError && error.reason === "reset_required") {
      this.publish({
        phase: "reset_required",
        detail: "Source or session changed. Resnapshot explicitly.",
      });
      this.abort?.abort();
    } else {
      this.publish({
        phase: "disconnected",
        detail:
          error instanceof ReactiveError && error.reason === "follow_recovery_storage_unavailable"
            ? "Follow recovery could not be saved in this tab. Dispatch stopped; the original operation remains available."
            : error instanceof ReactiveError && error.diagnostic
              ? diagnosticLines(error.diagnostic).join("\n")
              : this.session.pending
                ? "Control outcome uncertain; its exact operation is retained."
                : "Connection unavailable; displayed basis is unchanged.",
      });
    }
  }
  /** Only an explicit user action calls this. template is an already completed
   * query, never draft SQL. Each follow budgets at most eight selected starts. */
  async start(template: string | null = null, limit = 8) {
    if (this.starting || this.task) return;
    if (
      !Number.isInteger(limit) ||
      limit < 1 ||
      limit > 8 ||
      (template !== null && !namespace(template))
    )
      throw new ReactiveError(0, "invalid_view_intent");
    const intent = ++this.intent;
    this.starting = true;
    try {
      if (this.closing) await this.closing;
      if (this.session.pending) throw new ReactiveError(409, "control_uncertain");
      if (this.session.scope) await this.stop(false);
      if (intent !== this.intent) return;
      if (this.session.pending) throw new ReactiveError(409, "control_uncertain");
      if (this.session.scope || this.session.selection)
        throw new ReactiveError(409, "closure_incomplete");
      const abort = new AbortController();
      this.abort = abort;
      const epoch = ++this.epoch;
      this.template = template;
      this.captureKey = crypto.randomUUID();
      this.captures = null;
      this.limit = limit;
      this.restored = false;
      this.closingIntent = false;
      this.recoveredSnapshot = null;
      this.dirty = this.sentDirty = 0n;
      this.observedBasis = null;
      this.persist();
      this.publish({
        phase: "loading",
        detail: "Acquiring an authorized snapshot…",
        operationDetail: "",
        refresh: null,
        snapshot:
          template && this.state.snapshot?.namespace !== template ? null : this.state.snapshot,
      });
      this.task = this.run(epoch, abort.signal, limit)
        .catch((error: unknown) => {
          if (epoch === this.epoch && !abort.signal.aborted) this.fail(error);
        })
        .finally(() => {
          this.task = null;
          this.publish({});
        });
      // Errors/progress belong to observable state; ownership outlives render.
    } finally {
      this.starting = false;
    }
  }
  private launch(limit: number, detail: string) {
    const abort = new AbortController();
    this.abort = abort;
    const epoch = ++this.epoch;
    this.publish({ phase: "loading", snapshot: null, refresh: null, detail });
    this.task = this.run(epoch, abort.signal, limit)
      .catch((error: unknown) => {
        if (epoch === this.epoch && !abort.signal.aborted) this.fail(error);
      })
      .finally(() => {
        this.task = null;
        this.publish({});
      });
  }
  private async run(epoch: number, signal: AbortSignal, limit: number) {
    // Opening/subscribing/following can accept before a delayed receipt. Start
    // the same exact-control recovery used after attachment before acquisition.
    // Session.open skips committed steps; a recovered follow retains selection.
    while (!signal.aborted) {
      try {
        if (this.session.pending) await this.session.recover(signal);
        if (this.restored && this.session.selection) {
          const original = await this.session.recoverSelection(signal);
          if (
            original.template !== this.template ||
            original.limit !== limit ||
            !sameRecoveryValue(original.captures, this.captures)
          )
            throw new ReactiveError(409, "reset_required");
          const current = await this.session.refreshStatus(signal);
          if (current.template !== this.template || current.limit !== limit)
            throw new ReactiveError(409, "reset_required");
          if (current.phase === "denied") throw new ReactiveError(403, "denied");
          if (current.phase === "idle" && (current.starts ?? 0) > 0) {
            if (!namespace(current.namespace)) throw new ReactiveError(0, "invalid_response");
            this.recoveredSnapshot = current.namespace;
          }
          if (["paused", "exhausted", "failed"].includes(current.phase ?? "")) {
            this.publish({
              phase: "paused",
              refresh: current,
              detail:
                "The saved Follow has stopped. Its original budget and accepted queries remain unchanged.",
            });
            return;
          }
        }
        if (this.template && !this.captures) {
          if (!this.prepareCaptures)
            throw new ReactiveError(409, "refresh_preparation_unavailable");
          this.captures = await this.prepareCaptures(this.captureKey, this.template, limit, signal);
          this.persist();
        }
        await this.session.open(signal);
        if (signal.aborted) return;
        if (this.template && !this.session.selection) {
          const scope = this.session.scope!;
          await this.session.refresh(
            {
              follow: {
                session: { session: scope.session, generation: scope.generation },
                expected: 0,
                template: this.template,
                captures: this.captures!,
                limit,
              },
            },
            signal,
          );
        }
        this.restored = false;
        break;
      } catch (error) {
        if (signal.aborted) return;
        if (
          !(error instanceof ReactiveError) ||
          !(error.reason === "control_uncertain" || [429, 503, 504].includes(error.status))
        )
          throw error;
        this.fail(error);
        await sleep(500, signal);
      }
    }
    if (signal.aborted) return;
    let acquired = false;
    this.attached = false;
    const streamAbort = new AbortController();
    const joined = AbortSignal.any([signal, streamAbort.signal]);
    const stream = this.stream(epoch, joined);
    const controls = this.keepLease(epoch, joined);
    try {
      while (!signal.aborted) {
        try {
          // A frozen operation is reconciled before preparing any successor.
          if (!this.session.busy) {
            if (this.session.pending) {
              await sleep(100, signal);
              continue;
            }
            if (!this.attached) {
              await sleep(100, signal);
              continue;
            }
            if (!acquired) {
              const initial = await this.read(
                signal,
                this.recoveredSnapshot ?? this.template ?? undefined,
              );
              if (signal.aborted || epoch !== this.epoch) return;
              acquired = true;
              this.publish({
                snapshot: initial,
                phase: "refreshing",
                detail: "Checking acquired snapshot coverage…",
              });
            }
            if (this.needsObservation) {
              const observation = await this.session.inspect(signal);
              this.observe(observation.observation.basis, observation.observation.data_revision);
              this.needsObservation = false;
              this.connected = true;
            }
            if (this.template) await this.queryTick(epoch, signal);
            else if (this.dirty > BigInt(this.state.snapshot?.basis.accepted ?? "0")) {
              this.publish({
                phase: "refreshing",
                detail: "Reading the newest available snapshot…",
              });
              const snapshot = await this.read(signal);
              if (!signal.aborted && epoch === this.epoch) this.publish({ snapshot });
            }
            if (this.connected && !signal.aborted && this.state.phase !== "paused") {
              const covered = BigInt(this.state.snapshot?.basis.accepted ?? "0") >= this.dirty;
              this.publish({
                phase: covered ? "current" : "refreshing",
                detail: covered
                  ? "Displayed snapshot covers observed changes."
                  : "A newer change is waiting for a finite refresh.",
              });
            }
          }
        } catch (error) {
          if (!signal.aborted) this.fail(error);
        }
        await sleep(1000, signal);
      }
    } finally {
      streamAbort.abort();
      await Promise.all([stream, controls]);
    }
  }
  // Renewal must progress while a bounded complete-result verification is
  // awaiting pages. It shares Session's single-control owner, never the reader.
  private async keepLease(epoch: number, signal: AbortSignal) {
    while (!signal.aborted && epoch === this.epoch) {
      try {
        if (!this.session.busy) {
          if (this.session.pending) await this.session.recover(signal);
          if (!this.session.busy && Date.now() + 15000 >= this.session.leaseBefore)
            await this.session.renew(signal);
        }
      } catch (error) {
        if (!signal.aborted && epoch === this.epoch) this.fail(error);
      }
      await sleep(500, signal);
    }
  }
  private async queryTick(epoch: number, signal: AbortSignal) {
    const selection = this.session.selection;
    if (!selection) throw new ReactiveError(0, "invalid_response");
    if (this.dirty > this.sentDirty) {
      const observed = this.dirty;
      await this.session.refresh({ invalidate: selection }, signal);
      this.sentDirty = observed;
    }
    const refresh = await this.session.refreshStatus(signal);
    if (signal.aborted || epoch !== this.epoch) return;
    this.publish({ refresh });
    if (refresh.phase === "denied")
      throw new ReactiveError(403, "denied", refresh.queryDiagnostic ?? refresh.diagnostic);
    const detail = [refresh.diagnostic, refresh.queryDiagnostic]
      .flatMap((value) => (value ? diagnosticLines(value) : []))
      .join("\n");
    if (refresh.phase === "failed") {
      this.publish({
        phase: "paused",
        detail:
          detail ||
          "Refresh stopped without replacement coverage. Inspect the selected query outcome before continuing.",
      });
      this.abort?.abort();
      return;
    }
    if (refresh.phase === "ready") {
      // read() must traverse full coverage, discard prefixes and reread the
      // visible page under current authority. No rows are published in between.
      const snapshot = await this.read(signal, refresh.namespace);
      if (signal.aborted || epoch !== this.epoch || this.session.selection !== selection) return;
      this.publish({ snapshot });
      await this.session.refresh(
        { acknowledged: { selection, namespace: refresh.namespace } },
        signal,
      );
    }
    if (refresh.phase === "exhausted" || refresh.phase === "paused") {
      this.publish({
        phase: "paused",
        detail:
          detail ||
          (refresh.phase === "exhausted"
            ? "Refresh budget used. Inspect the selected query before explicitly granting another budget."
            : "Scheduling paused; selected query work remains independent."),
      });
      this.abort?.abort();
    }
  }
  private accept(message: ServerMessage) {
    if ("attached" in message) {
      this.attached = true;
      this.connected = false;
      this.needsObservation = true;
    }
    if ("event" in message) {
      this.dirty = max(this.dirty, BigInt(message.event.cursor.position.data_revision));
      this.connected = true;
      const outcome = message.event.event.outcome;
      if (outcome)
        this.publish({
          operationDetail:
            (outcome.diagnostic
              ? diagnosticLines(outcome.diagnostic).join("\n")
              : `Serving operation ${outcome.operation}: ${outcome.phase.replaceAll("_", " ")}.`) +
            (outcome.diagnosticInvalid
              ? " Diagnostic detail is invalid; the recorded phase remains unchanged."
              : ""),
        });
    }
    if ("terminal" in message) {
      this.connected = false;
      const reason = message.terminal.reason;
      const failure = new ReactiveError(0, reason, message.terminal.diagnostic);
      if (reason === "denied" || reason === "expired" || reason === "closed") this.fail(failure);
      else if (reason === "reset_required") this.fail(failure);
      else
        this.publish({
          phase: "disconnected",
          detail: failure.diagnostic
            ? diagnosticLines(failure.diagnostic).join("\n")
            : `Stream ended (${reason}); snapshot basis is unchanged.`,
        });
    }
  }
  private async stream(epoch: number, signal: AbortSignal) {
    while (!signal.aborted && epoch === this.epoch) {
      let reportedFailure = false;
      try {
        if (!this.session.pending && !this.session.busy) {
          // Attaching owns the caller sequence until its receipt is known.
          // Give renewal priority before entering that bounded wait.
          if (Date.now() + 20000 >= this.session.leaseBefore) await this.session.renew(signal);
          if (Date.now() + 15000 >= this.session.leaseBefore) {
            await sleep(500, signal);
            continue;
          }
          await this.session.follow((message) => {
            if ("terminal" in message) reportedFailure = true;
            this.accept(message);
          }, signal);
        }
      } catch (error) {
        if (!signal.aborted && epoch === this.epoch) {
          reportedFailure = true;
          this.fail(error);
        }
      }
      this.attached = false;
      this.connected = false;
      // A new attachment attempt does not replace the observed failure with
      // generic connection advice. Successful observation establishes recovery.
      if (!signal.aborted && !reportedFailure && this.state.phase !== "disconnected")
        this.publish({
          phase: "disconnected",
          detail: "Reconnecting the same session; displayed basis is unchanged.",
        });
      await sleep(1000, signal);
    }
  }
  /** Stop local acquisition/renewal first, then join and best-effort durable
   * pause/close. Uncertainty stays in Session; lease expiry bounds abandonment. */
  pause() {
    // Loading a saved owner, hiding it, or unmounting its renderer must not
    // dispatch a previously saved control. Explicit recover/resume may do so.
    if (this.restored && !this.task) return Promise.resolve();
    return this.stop(true);
  }
  private stop(cancelStart: boolean) {
    if (cancelStart) ++this.intent;
    if (this.closing) return this.closing;
    ++this.epoch;
    this.abort?.abort();
    this.connected = false;
    this.publish({
      phase: "paused",
      detail: "Local work stopped; resolving logical closure…",
    });
    const task = this.task;
    this.closing = (async () => {
      await task;
      const signal = AbortSignal.timeout(10000);
      while (true) {
        try {
          if (this.session.pending || this.session.scope) {
            this.closingIntent = true;
            this.persist();
          }
          if (this.session.pending) await this.session.recover(signal);
          if (this.session.selection && this.session.scope) {
            await this.session.refresh({ pause: this.session.selection }, signal);
          }
          await this.session.close(signal);
          this.session.selection = null;
          // Interrupted preparation can still own an uncertain upload. Keep
          // the original intent until explicit resume settles that owner.
          if (this.captures || !this.template) {
            this.captureKey = "";
            this.template = null;
            this.captures = null;
          }
          this.restored = false;
          this.closingIntent = false;
          this.persist();
          this.publish({
            phase: "paused",
            detail: "Follow paused. Accepted queries continue independently.",
          });
          return;
        } catch (error) {
          // Joining a canceled read can briefly retain the server's control
          // slot. Retry preparation only after known capacity/unavailability;
          // an uncertain mutation always goes through exact recovery first.
          const retryable =
            error instanceof ReactiveError &&
            (error.status === 429 ||
              error.status === 503 ||
              error.status === 504 ||
              error.reason === "control_uncertain");
          if (signal.aborted || !retryable) {
            this.fail(error);
            return;
          }
          await sleep(250, signal);
        }
      }
    })().finally(() => {
      this.closing = null;
      this.publish({});
    });
    return this.closing;
  }
  async recover() {
    if (this.task || this.closing) return;
    await this.stop(true);
  }
}
