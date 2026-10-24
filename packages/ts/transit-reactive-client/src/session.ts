import { ownedDiagnostic, type Diagnostic } from "@transit/diagnostics";
import { ReactiveError, Transport, type ServerMessage } from "./index";
import { acquireCaller, type AcquireCaller } from "./caller-gate";
import type { Bootstrap, HostRequest, HostResponse, ReactiveRead, SignedCommand } from "./types";
import { currentDefinition } from "./types";
import {
  maxSessionRecoveryBytes,
  readSessionRecovery,
  sameRecoveryValue,
  type SessionRecovery,
} from "./session-recovery";
type Command = Extract<HostRequest, { prepare: unknown }>["prepare"];
export type RefreshCommand = Extract<HostRequest, { refresh_prepare: unknown }>["refresh_prepare"];
type RefreshStatus = Extract<HostResponse, { refresh_status: unknown }>["refresh_status"];
export type RefreshView = RefreshStatus["view"] &
  Pick<RefreshStatus, "resource" | "revision" | "policy_revision"> & {
    diagnostic?: Diagnostic;
    queryDiagnostic?: Diagnostic;
    diagnosticInvalid: boolean;
    queryDiagnosticInvalid: boolean;
  };
export type Selection = Extract<HostRequest, { refresh_status: unknown }>["refresh_status"];
type Control = Command | { refresh: RefreshCommand };
type Read = ReactiveRead["read"];
type Description = Extract<HostResponse, { description: unknown }>["description"];
type Cursor = NonNullable<Read["cursor"]>;
export type Inspection = Extract<HostResponse, { inspection: unknown }>["inspection"];
export type Pending = { signed: SignedCommand; command: Control | null; input: number | null };
const reserved = (command: Control) =>
  "renew" in command ||
  "unsubscribe" in command ||
  "close" in command ||
  ("refresh" in command && "pause" in command.refresh);
const fresh = () => {
  const bytes = crypto.getRandomValues(new Uint32Array(2));
  return bytes[0]! * 2097152 + (bytes[1]! & 2097151) || 1;
};
const invalid = (): never => {
  throw new ReactiveError(0, "invalid_response");
};

/** One bounded host-owned client lifecycle. Keep this object outside disposable
 * render state. Lost mutations keep frozen bytes until explicit recover(). */
export class Session {
  pending: Pending | null = null;
  description: Description | null = null;
  scope: Read["scope"] | null = null;
  cursor: Cursor | null = null;
  attachment = 0;
  nonce = Array<number>(16).fill(0);
  leaseBefore = 0;
  selection: Selection | null = null;
  private selectionControl: SignedCommand | null = null;
  private activeControl = false;
  private restored = false;
  private restoredPending = false;
  get busy() {
    return this.activeControl;
  }
  private releaseCaller: (() => void) | null = null;
  constructor(
    readonly transport = new Transport(),
    private readonly acquire: AcquireCaller = acquireCaller,
    private readonly persist: () => void = () => {},
  ) {}

  exportRecovery(): string {
    const saved: SessionRecovery = {
      version: 1,
      definition: currentDefinition,
      description: this.description,
      pending: this.pending ? { signed: this.pending.signed, input: this.pending.input } : null,
      scope: this.scope,
      cursor: this.cursor,
      attachment: this.attachment,
      nonce: this.nonce,
      leaseBefore: this.leaseBefore,
      selection: this.selection,
      selectionControl: this.selectionControl,
    };
    const bytes = JSON.stringify(saved);
    if (new TextEncoder().encode(bytes).length > maxSessionRecoveryBytes)
      throw new ReactiveError(0, "session_recovery_capacity");
    return bytes;
  }

  /** Import is inert. The host must verify saved controls and current scope
   * before this owner can submit, inspect, attach or resume. No rows are saved. */
  restoreRecovery(bytes: string) {
    if (this.activeControl || this.releaseCaller || this.description || this.pending || this.scope)
      throw new ReactiveError(409, "session_recovery_busy");
    const saved = readSessionRecovery(bytes);
    this.description = saved.description;
    this.pending = saved.pending ? { ...saved.pending, command: null } : null;
    this.scope = saved.scope;
    this.cursor = saved.cursor ?? null;
    this.attachment = saved.attachment;
    this.nonce = saved.nonce;
    this.leaseBefore = saved.leaseBefore;
    this.selection = saved.selection;
    this.selectionControl = saved.selectionControl;
    this.restored = true;
    this.restoredPending = this.pending !== null;
  }

  private async checkRecovery(signal?: AbortSignal, cleanup = false) {
    if (!this.restored) return;
    if (this.restoredPending) throw new ReactiveError(409, "control_uncertain");
    // Closure does not require another source observation. Its freshly prepared
    // token must still match the saved native caller and ingress before dispatch.
    if (cleanup) return;
    const response = await this.transport.host({ describe: {} }, signal);
    if (!("description" in response)) return invalid();
    const previous = this.description,
      current = response.description;
    if (
      previous &&
      (!sameRecoveryValue(
        { ...previous.connection, role: previous.connection.role ?? null },
        { ...current.connection, role: current.connection.role ?? null },
      ) ||
        ["service", "ingress", "resource", "watch_revision"].some((field) => {
          const key = field as "service" | "ingress" | "resource" | "watch_revision";
          return previous.discovery[key] !== current.discovery[key];
        }))
    )
      throw new ReactiveError(409, "reset_required");
    this.description = current;
    this.restored = false;
    this.persist();
  }

  private async recoverSavedControl(signal?: AbortSignal) {
    if (!this.restoredPending || !this.pending || !this.description) return;
    const response = await this.transport.host(
      { recover_control: this.pending.signed },
      signal,
      true,
    );
    if (!("recovered_control" in response)) return invalid();
    const found = response.recovered_control;
    const command: Control =
      "reactive" in found.control ? found.control.reactive : { refresh: found.control.refresh };
    if ("open" in command) {
      if (this.scope) throw new ReactiveError(409, "session_recovery_changed");
    } else {
      const identity =
        "refresh" in command
          ? "follow" in command.refresh
            ? command.refresh.follow.session
            : "acknowledged" in command.refresh
              ? command.refresh.acknowledged.selection.session
              : "pause" in command.refresh
                ? command.refresh.pause.session
                : command.refresh.invalidate.session
          : "close" in command
            ? command.close
            : "attach" in command
              ? command.attach.identity
              : "subscribe" in command
                ? command.subscribe.identity
                : "renew" in command
                  ? command.renew.identity
                  : command.unsubscribe.identity;
      if (
        !this.scope ||
        identity.session !== this.scope.session ||
        identity.generation !== this.scope.generation
      )
        throw new ReactiveError(409, "session_recovery_changed");
    }
    if (
      !sameRecoveryValue(
        { ...found.connection, role: found.connection.role ?? null },
        { ...this.description.connection, role: this.description.connection.role ?? null },
      ) ||
      (this.pending.input !== null && this.pending.input !== found.input)
    )
      throw new ReactiveError(409, "session_recovery_changed");
    this.pending.input = found.input;
    this.pending.command = command;
    if ("attach" in command) {
      this.attachment = command.attach.expected + 1;
      this.nonce = command.attach.nonce;
    }
    this.restoredPending = false;
    this.persist();
  }

  private async lock(signal?: AbortSignal) {
    if (this.releaseCaller) return;
    const description = this.description ?? (await this.describe(signal));
    this.releaseCaller = await this.acquire(description.connection, signal);
  }
  private unlock() {
    this.releaseCaller?.();
    this.releaseCaller = null;
  }

  async describe(signal?: AbortSignal) {
    await this.checkRecovery(signal);
    const value = await this.transport.host({ describe: {} }, signal);
    if (!("description" in value)) return invalid();
    this.description = value.description;
    return value.description;
  }
  private async dispatch(signal?: AbortSignal) {
    const pending = this.pending;
    if (!pending || !pending.command) return invalid();
    const command = pending.command;
    this.persist();
    if (pending.input === null) {
      const sent = await this.transport.host({ submit: pending.signed }, signal, reserved(command));
      if (!("receipt" in sent)) return invalid();
      pending.input = sent.receipt.receipt.position;
      this.persist();
    }
    const deadline = performance.now() + 5000;
    while (performance.now() < deadline) {
      const seen = await this.transport.host({ observe: pending.signed }, signal, true);
      if (!("observation" in seen)) return invalid();
      if ("committed" in seen.observation) {
        this.applied(command, pending.input, pending.signed);
        this.pending = null;
        this.persist();
        this.unlock();
        return pending.input;
      }
      if ("rejected" in seen.observation) {
        const rejected = seen.observation.rejected;
        if (rejected.record.input !== pending.input) return invalid();
        this.pending = null;
        this.persist();
        this.unlock();
        const owned = ownedDiagnostic(rejected.diagnostic);
        const evidence = owned.diagnostic;
        const nativeInput = evidence?.facts.find((fact) => fact?.field === "native_input")?.value;
        const detail =
          evidence &&
          (evidence.outcome !== "input_rejected" ||
            evidence.evidence !== "domain_status" ||
            !nativeInput ||
            !("unsigned" in nativeInput) ||
            nativeInput.unsigned !== String(pending.input))
            ? {}
            : rejected.diagnostic;
        let scopeFailure: ReactiveError | undefined;
        // A current authorization failure clears protected state, but cannot
        // replace the historical input rejection or make it uncertain again.
        if (this.scope && this.attachment > 0) {
          try {
            await this.inspect(signal);
          } catch (error) {
            scopeFailure =
              error instanceof ReactiveError ? error : new ReactiveError(0, "interrupted");
          }
        }
        const failure = new ReactiveError(
          409,
          rejected.record.reason,
          scopeFailure?.clearsProtectedState ? undefined : detail,
        );
        failure.scopeFailure = scopeFailure;
        throw failure;
      }
      await new Promise((resolve) => setTimeout(resolve, 250));
      signal?.throwIfAborted();
    }
    throw new ReactiveError(0, "control_uncertain");
  }
  async recover(signal?: AbortSignal) {
    if (!this.pending) return invalid();
    if (this.activeControl) throw new ReactiveError(429, "control_busy");
    this.activeControl = true;
    try {
      await this.lock(signal);
      await this.recoverSavedControl(signal);
      return await this.dispatch(signal);
    } finally {
      if (!this.pending) this.unlock();
      this.activeControl = false;
    }
  }
  async command(command: Command, signal?: AbortSignal) {
    return this.perform(command, signal);
  }
  async refresh(command: RefreshCommand, signal?: AbortSignal) {
    return this.perform({ refresh: command }, signal);
  }
  async refreshStatus(signal?: AbortSignal): Promise<RefreshView> {
    await this.checkRecovery(signal);
    if (!this.selection) return invalid();
    const response = await this.transport.host({ refresh_status: this.selection }, signal);
    if (!("refresh_status" in response)) return invalid();
    const { view, diagnostic: supplied, query_diagnostic: querySupplied } = response.refresh_status;
    if (
      view.generation !== this.selection.generation ||
      view.session.session !== this.selection.session.session ||
      view.session.generation !== this.selection.session.generation
    )
      return invalid();
    let detail = ownedDiagnostic(supplied);
    const stop = view.failure && "stopped" in view.failure ? view.failure.stopped : null;
    const nativeInput = detail.diagnostic?.facts.find(
      (fact) => fact?.field === "native_input",
    )?.value;
    const generation = detail.diagnostic?.facts.find((fact) => fact?.field === "generation")?.value;
    if (
      detail.diagnostic &&
      (!stop ||
        detail.diagnostic.outcome !== "not_applicable" ||
        detail.diagnostic.evidence !== "domain_status" ||
        detail.diagnostic.identity?.domain !== "reactive" ||
        detail.diagnostic.identity.id !== String(view.session.session) ||
        detail.diagnostic.identity.resource !== String(response.refresh_status.resource) ||
        !nativeInput ||
        !("unsigned" in nativeInput) ||
        nativeInput.unsigned !== String(stop.input) ||
        !generation ||
        !("unsigned" in generation) ||
        generation.unsigned !== String(view.generation))
    )
      detail = { invalid: true };
    let queryDetail = ownedDiagnostic(querySupplied);
    if (
      queryDetail.diagnostic &&
      (view.starts === 0 ||
        queryDetail.diagnostic.evidence !== "domain_status" ||
        !["rejected", "cancelled", "retired"].includes(queryDetail.diagnostic.outcome) ||
        queryDetail.diagnostic.identity?.domain !== "query" ||
        queryDetail.diagnostic.identity.id !== view.namespace)
    )
      queryDetail = { invalid: true };
    return {
      ...view,
      resource: response.refresh_status.resource,
      revision: response.refresh_status.revision,
      policy_revision: response.refresh_status.policy_revision,
      diagnostic: detail.diagnostic,
      queryDiagnostic: queryDetail.diagnostic,
      diagnosticInvalid: detail.invalid,
      queryDiagnosticInvalid: queryDetail.invalid,
    };
  }

  private async perform(command: Control, signal?: AbortSignal) {
    if (this.activeControl || this.pending) throw new ReactiveError(409, "control_uncertain");
    this.activeControl = true;
    try {
      await this.checkRecovery(
        signal,
        "close" in command ||
          "unsubscribe" in command ||
          ("refresh" in command && "pause" in command.refresh),
      );
      await this.lock(signal);
      const value = await this.transport.host(
        "refresh" in command ? { refresh_prepare: command.refresh } : { prepare: command },
        signal,
        reserved(command),
      );
      if (!("prepared" in value)) return invalid();
      const connection = this.description?.connection;
      const request = value.prepared.request;
      if (
        !connection ||
        request.realm !== connection.realm ||
        request.principal !== connection.principal ||
        request.command.send.pid !== connection.ingress ||
        (request.command.send.role ?? null) !== (connection.role ?? null)
      )
        throw new ReactiveError(409, "reset_required");
      this.pending = { signed: value.prepared, command, input: null };
      return await this.dispatch(signal);
    } finally {
      if (!this.pending) this.unlock();
      this.activeControl = false;
    }
  }
  /** Read the original accepted Follow payload. Saved template/pool metadata
   * cannot replace the command identified by the native receipt. */
  async recoverSelection(
    signal?: AbortSignal,
  ): Promise<Extract<RefreshCommand, { follow: unknown }>["follow"]> {
    if (!this.selection || !this.selectionControl)
      throw new ReactiveError(409, "selection_recovery_absent");
    await this.checkRecovery(signal);
    const result = await this.transport.host(
      { recover_control: this.selectionControl },
      signal,
      true,
    );
    if (!("recovered_control" in result)) return invalid();
    const recovered = result.recovered_control;
    if (
      !sameRecoveryValue(
        { ...recovered.connection, role: recovered.connection.role ?? null },
        { ...this.description!.connection, role: this.description!.connection.role ?? null },
      ) ||
      recovered.input !== this.selection.generation ||
      !("refresh" in recovered.control) ||
      !("follow" in recovered.control.refresh) ||
      !sameRecoveryValue(recovered.control.refresh.follow.session, this.selection.session)
    )
      throw new ReactiveError(409, "session_recovery_changed");
    return recovered.control.refresh.follow;
  }
  private applied(command: Control, input: number, signed: SignedCommand) {
    if ("refresh" in command) {
      if ("follow" in command.refresh) {
        this.selection = { session: command.refresh.follow.session, generation: input };
        this.selectionControl = signed;
      }
      return;
    }
    if ("open" in command) {
      if (!this.description) invalid();
      this.scope = {
        realm: this.description!.connection.realm,
        principal: this.description!.connection.principal,
        service: this.description!.connection.service,
        ingress: this.description!.connection.ingress,
        session: command.open.session,
        generation: input,
        subscription: 0,
        subscription_generation: 0,
      };
      this.leaseBefore = command.open.lease_before_ms;
    } else if ("subscribe" in command && this.scope) {
      this.scope = {
        ...this.scope,
        subscription: command.subscribe.subscription,
        subscription_generation: input,
      };
    } else if ("renew" in command) this.leaseBefore = command.renew.lease_before_ms;
    else if ("close" in command) {
      this.scope = null;
      this.cursor = null;
      this.attachment = 0;
      this.nonce = Array<number>(16).fill(0);
      this.selection = null;
      this.selectionControl = null;
      this.description = null;
      this.restored = false;
    }
  }
  async open(signal?: AbortSignal) {
    if (this.pending) throw new ReactiveError(409, "control_uncertain");
    await this.checkRecovery(signal);
    if (!this.scope) {
      const description = await this.describe(signal);
      const session = fresh();
      const lease = description.max_lease_ms;
      if (lease === undefined) return invalid();
      await this.command(
        {
          open: {
            session,
            source_revision: description.discovery.watch_revision,
            lease_before_ms: description.observed_ms + lease - 1000,
          },
        },
        signal,
      );
    }
    if (this.scope && !this.scope.subscription) {
      const { session, generation } = this.scope;
      await this.command(
        {
          subscribe: {
            identity: { session, generation },
            expected: 0,
            subscription: fresh(),
            operation: 0,
          },
        },
        signal,
      );
    }
  }
  private read(kind: Read["kind"], cursor: Cursor | null = null): Read {
    if (!this.scope) throw new ReactiveError(0, "session_absent");
    return { scope: this.scope, kind, attachment: this.attachment, nonce: this.nonce, cursor };
  }
  async signed(kind: Read["kind"], cursor: Cursor | null = null, signal?: AbortSignal) {
    await this.checkRecovery(signal);
    const result = await this.transport.host({ sign_read: this.read(kind, cursor) }, signal);
    if (!("signed_read" in result)) return invalid();
    return result.signed_read;
  }
  async inspect(signal?: AbortSignal): Promise<Inspection> {
    await this.checkRecovery(signal);
    const result = await this.transport.host({ inspect: this.read("events", this.cursor) }, signal);
    if (!("inspection" in result)) return invalid();
    return result.inspection;
  }
  async snapshot(signal?: AbortSignal) {
    return this.transport.read(await this.signed("snapshot", null, signal), signal);
  }
  async renew(signal?: AbortSignal) {
    if (!this.scope) return;
    const response = await this.transport.host({ clock: {} }, signal, true);
    if (!("clock" in response)) return invalid();
    const lease = response.clock.observed_ms + (response.clock.max_lease_ms ?? 30000) - 1000;
    // A repeated committed clock sample grants no additional lease.
    if (lease <= this.leaseBefore) return;
    await this.command(
      {
        renew: {
          identity: { session: this.scope.session, generation: this.scope.generation },
          expected: this.leaseBefore,
          lease_before_ms: lease,
        },
      },
      signal,
    );
    this.leaseBefore = lease;
  }
  async close(signal?: AbortSignal) {
    if (!this.scope) return;
    await this.command(
      { close: { session: this.scope.session, generation: this.scope.generation } },
      signal,
    );
    this.scope = null;
    this.cursor = null;
    this.attachment = 0;
    this.nonce = Array<number>(16).fill(0);
  }
  /** Resolves when the stream closes. The caller owns reconnect/backoff and must
   * stop this task before creating another attachment or hiding the view. */
  async follow(consume: (value: ServerMessage) => void, signal: AbortSignal) {
    if (!this.scope || !this.scope.subscription || this.pending || this.activeControl)
      throw new ReactiveError(409, "control_uncertain");
    this.activeControl = true;
    let attaching = true;
    try {
      await this.lock(signal);
      const scope = this.scope;
      const state = await this.transport.read(await this.signed("session", null, signal), signal);
      if (state.session.phase !== "open")
        throw new ReactiveError(410, state.session.phase === "closed" ? "closed" : "expired");
      this.leaseBefore = state.session.lease_before_ms;
      const challenge = await this.transport.challenge(
        await this.signed("session", null, signal),
        signal,
      );
      const previous = state.session.attachment;
      if (previous === undefined) return invalid();
      const nextAttachment = previous + 1;
      const attach: Command = {
        attach: {
          identity: { session: this.scope.session, generation: this.scope.generation },
          expected: previous,
          nonce: challenge.nonce,
        },
      };
      const command = await this.transport.host({ prepare: attach }, signal);
      if (!("prepared" in command)) return invalid();
      this.pending = { signed: command.prepared, command: attach, input: null };
      this.attachment = nextAttachment;
      this.nonce = challenge.nonce;
      this.persist();
      const bootstrap: Bootstrap = {
        version: 1,
        attach: command.prepared,
        read: await this.signed("events", this.cursor, signal),
      };
      await this.transport.events(
        bootstrap,
        (value) => {
          if (this.scope !== scope || signal.aborted) throw new ReactiveError(409, "fenced");
          if ("attached" in value) {
            if (
              value.attached.session !== scope.session ||
              value.attached.generation !== scope.generation ||
              value.attached.attachment !== this.attachment
            )
              invalid();
            this.pending = null; // Host observed the exact signed attachment commit.
            this.persist();
            attaching = false;
            this.activeControl = false;
            this.unlock();
          }
          if ("event" in value) {
            const next = value.event.cursor;
            for (const field of [
              "realm",
              "principal",
              "service",
              "ingress",
              "session",
              "generation",
              "subscription",
              "subscription_generation",
            ] as const) {
              if (next.position.scope[field] !== scope[field]) invalid();
            }
            const previous = this.cursor?.position;
            if (
              next.position.watch_revision !== this.description?.discovery.watch_revision ||
              (previous &&
                (next.position.resource !== previous.resource ||
                  next.position.schema.some((byte, i) => byte !== previous.schema[i])))
            )
              throw new ReactiveError(409, "reset_required");
            if (
              previous &&
              (BigInt(next.position.data_revision) < BigInt(previous.data_revision) ||
                (next.position.outcome_position ?? 0) < (previous.outcome_position ?? 0))
            )
              invalid();
            this.cursor = next;
            this.persist();
          }
          consume(value);
        },
        signal,
      );
    } finally {
      if (attaching) {
        if (!this.pending) this.unlock();
        this.activeControl = false;
      }
    }
  }
}
