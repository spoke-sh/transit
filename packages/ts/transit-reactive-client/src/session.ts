import { ReactiveError, Transport } from "./index";
import { acquireCaller, type AcquireCaller } from "./caller-gate";
import type {
  Bootstrap,
  HostRequest,
  HostResponse,
  ReactiveRead,
  ServerMessage,
  SignedCommand,
} from "./types";
type Command = Extract<HostRequest, { prepare: unknown }>["prepare"];
export type RefreshCommand = Extract<HostRequest, { refresh_prepare: unknown }>["refresh_prepare"];
export type RefreshView = Extract<HostResponse, { refresh_status: unknown }>["refresh_status"];
export type Selection = Extract<HostRequest, { refresh_status: unknown }>["refresh_status"];
type Control = Command | { refresh: RefreshCommand };
type Read = ReactiveRead["read"];
type Description = Extract<HostResponse, { description: unknown }>["description"];
type Cursor = NonNullable<Read["cursor"]>;
export type Inspection = Extract<HostResponse, { inspection: unknown }>["inspection"];
export type Pending = { signed: SignedCommand; command: Control; input: number | null };
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
  private activeControl = false;
  get busy() {
    return this.activeControl;
  }
  private releaseCaller: (() => void) | null = null;
  constructor(
    readonly transport = new Transport(),
    private readonly acquire: AcquireCaller = acquireCaller,
  ) {}

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
    const value = await this.transport.host({ describe: {} }, signal);
    if (!("description" in value)) return invalid();
    this.description = value.description;
    return value.description;
  }
  private async dispatch(signal?: AbortSignal) {
    const pending = this.pending;
    if (!pending) return invalid();
    if (pending.input === null) {
      const sent = await this.transport.host(
        { submit: pending.signed },
        signal,
        reserved(pending.command),
      );
      if (!("receipt" in sent)) return invalid();
      pending.input = sent.receipt.receipt.position;
    }
    const deadline = performance.now() + 5000;
    while (performance.now() < deadline) {
      const seen = await this.transport.host({ observe: pending.input }, signal, true);
      if (!("observation" in seen)) return invalid();
      if ("committed" in seen.observation) {
        this.applied(pending.command, pending.input);
        this.pending = null;
        this.unlock();
        return pending.input;
      }
      if ("rejected" in seen.observation) {
        this.pending = null;
        this.unlock();
        throw new ReactiveError(409, "control_rejected");
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
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
    if (!this.selection) return invalid();
    const response = await this.transport.host({ refresh_status: this.selection }, signal);
    if (!("refresh_status" in response)) return invalid();
    if (
      response.refresh_status.generation !== this.selection.generation ||
      response.refresh_status.session.session !== this.selection.session.session ||
      response.refresh_status.session.generation !== this.selection.session.generation
    )
      return invalid();
    return response.refresh_status;
  }
  private async perform(command: Control, signal?: AbortSignal) {
    if (this.activeControl || this.pending) throw new ReactiveError(409, "control_uncertain");
    this.activeControl = true;
    try {
      await this.lock(signal);
      const value = await this.transport.host(
        "refresh" in command ? { refresh_prepare: command.refresh } : { prepare: command },
        signal,
        reserved(command),
      );
      if (!("prepared" in value)) return invalid();
      this.pending = { signed: value.prepared, command, input: null };
      return await this.dispatch(signal);
    } finally {
      if (!this.pending) this.unlock();
      this.activeControl = false;
    }
  }
  private applied(command: Control, input: number) {
    if ("refresh" in command) {
      if ("follow" in command.refresh)
        this.selection = { session: command.refresh.follow.session, generation: input };
      return;
    }
    if ("open" in command) {
      if (!this.description) invalid();
      this.scope = {
        ...this.description!.connection,
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
    }
  }
  async open(signal?: AbortSignal) {
    if (this.pending) throw new ReactiveError(409, "control_uncertain");
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
    const result = await this.transport.host({ sign_read: this.read(kind, cursor) }, signal);
    if (!("signed_read" in result)) return invalid();
    return result.signed_read;
  }
  async inspect(signal?: AbortSignal): Promise<Inspection> {
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
      if (state.session.phase !== "open") throw new ReactiveError(410, "expired");
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
              (next.position.data_revision < previous.data_revision ||
                (next.position.outcome_position ?? 0) < (previous.outcome_position ?? 0))
            )
              invalid();
            this.cursor = next;
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
