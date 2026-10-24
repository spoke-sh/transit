import { ownedDiagnostic } from "@transit/diagnostics";
import { ReactiveError } from "./error";
export { ReactiveError } from "./error";
import * as validate from "./validators.js";
import type {
  Bootstrap,
  Discovery,
  HostRequest,
  HostResponse,
  ReactiveRead,
  ReactiveResponse as WireResponse,
  ServerMessage as WireMessage,
  SseItem,
  Error as ErrorResponse,
} from "./types";
export type * from "./types";
export { currentDefinition } from "./types";

export type OperationOutcome = NonNullable<NonNullable<WireResponse["event"]>["outcome"]> & {
  diagnosticInvalid?: boolean;
};
type Event = Omit<NonNullable<WireResponse["event"]>, "outcome"> & {
  outcome?: OperationOutcome | null;
};
export type ReactiveResponse = Omit<WireResponse, "event"> & { event?: Event | null };
export type ServerMessage =
  | Exclude<WireMessage, { event: unknown } | { observation: unknown }>
  | { observation: ReactiveResponse }
  | { event: { cursor: NonNullable<WireResponse["cursor"]>; event: Event } };

function primaryResponse(value: unknown): unknown {
  if (
    !value ||
    typeof value !== "object" ||
    !("event" in value) ||
    !value.event ||
    typeof value.event !== "object"
  )
    return value;
  const event = value.event;
  if (!("outcome" in event) || !event.outcome || typeof event.outcome !== "object") return value;
  return { ...value, event: { ...event, outcome: { ...event.outcome, diagnostic: null } } };
}
function ownOutcome(
  value: OperationOutcome,
  cursor: NonNullable<WireResponse["cursor"]> | null | undefined,
): OperationOutcome {
  const owned = ownedDiagnostic(value.diagnostic);
  const detail = owned.diagnostic;
  const scope = cursor?.position.scope;
  const outcomes = {
    admitted: "pending",
    completed: "completed",
    cancelled: "cancelled",
    timed_out: "closed_unknown",
    failed: "failed",
  };
  const fact = (field: string) => detail?.facts.find((item) => item?.field === field)?.value;
  const number = (field: string, expected: number) => {
    const value = fact(field);
    return value && "unsigned" in value && value.unsigned === String(expected);
  };
  const matching =
    !detail ||
    (scope &&
      detail.evidence === "domain_status" &&
      detail.outcome === outcomes[value.phase] &&
      detail.identity?.domain === "serving" &&
      detail.identity.id === String(value.operation) &&
      detail.identity.realm === String(scope.realm) &&
      detail.identity.resource === String(value.resource) &&
      number("object", scope.service) &&
      number("scope", scope.principal) &&
      (value.phase === "admitted" || number("native_input", value.resolution_input)));
  return {
    ...value,
    diagnostic: matching ? (detail ?? null) : null,
    diagnosticInvalid: owned.invalid || !matching,
  };
}

function requestFailure(status: number, value?: unknown): ReactiveError {
  const fallback =
    status === 403
      ? "denied"
      : status === 410
        ? "gone"
        : status === 409
          ? "conflict"
          : status === 429
            ? "capacity"
            : "unavailable";
  if (!value || typeof value !== "object") return new ReactiveError(status, fallback);
  const primary = { ...value, diagnostic: null };
  if (!validate.Error(primary)) return new ReactiveError(status, fallback);
  const response = value as ErrorResponse;
  const reason = response.reason;
  const statuses: Record<NonNullable<ErrorResponse["reason"]>, number[]> = {
    denied: [403],
    closed: [410],
    expired: [410],
    fenced: [409],
    reset_required: [409],
    not_found: [404],
    conflict: [409],
    result_not_completed: [409],
    unavailable: [409, 410, 503, 504],
    capacity: [429],
    invalid_request: [400, 408, 413],
    internal_failure: [502, 503],
  };
  if (reason && !statuses[reason].includes(status)) return new ReactiveError(status, fallback, {});
  return new ReactiveError(status, reason ?? fallback, response.diagnostic);
}

function invalid(): never {
  throw new ReactiveError(0, "invalid_response");
}
function integer(value: string) {
  const number = BigInt(value);
  if (number < -9223372036854775808n || number > 9223372036854775807n) invalid();
}
function counter(value: string, positive = false): bigint {
  if (!/^(0|[1-9][0-9]{0,19})$/.test(value)) invalid();
  const result = BigInt(value);
  if (result > 18446744073709551615n || (positive && result === 0n)) invalid();
  return result;
}
function source(value: NonNullable<WireResponse["source"]>) {
  counter(value.catalog, true);
  counter(value.object, true);
  counter(value.interpretation_revision, true);
  if (value.branch !== 1 || value.interpretation_digest.every((b) => b === 0)) invalid();
}
function observation(value: NonNullable<WireResponse["snapshot"]>["observation"]) {
  const basis = value.basis;
  counter(basis.partition, true);
  const accepted = counter(basis.accepted, true);
  if (
    basis.resource === 0 ||
    counter(value.data_revision) > accepted ||
    basis.contract.every((b) => b === 0) ||
    basis.schema.every((b) => b === 0)
  )
    invalid();
}
function progress(result: Pick<WireResponse, "cursor" | "event" | "snapshot">) {
  if (result.cursor) counter(result.cursor.position.data_revision);
  if (result.event) {
    counter(result.event.data_revision);
    if (
      result.cursor &&
      (result.event.data_revision !== result.cursor.position.data_revision ||
        result.event.resource !== result.cursor.position.resource)
    )
      invalid();
  }
  if (result.snapshot) {
    const current = result.snapshot.observation;
    observation(current);
    const basis = current.basis;
    if (
      result.cursor &&
      (basis.resource !== result.cursor.position.resource ||
        current.data_revision !== result.cursor.position.data_revision ||
        basis.schema.some((b, i) => b !== result.cursor!.position.schema[i]))
    )
      invalid();
  }
}
export function response(value: unknown): ReactiveResponse {
  if (!validate.ReactiveResponse(primaryResponse(value))) invalid();
  const result = value as ReactiveResponse;
  if (result.source) source(result.source);
  progress(result);
  for (const row of result.snapshot?.rows ?? []) {
    if (!row) continue;
    integer(row.key);
    if (row.value !== null) integer(row.value);
  }
  if (result.event?.outcome)
    return {
      ...result,
      event: { ...result.event, outcome: ownOutcome(result.event.outcome, result.cursor) },
    };
  return result;
}
export function message(value: unknown): ServerMessage {
  let primary: unknown = value;
  if (value && typeof value === "object") {
    if ("terminal" in value && value.terminal && typeof value.terminal === "object")
      primary = { ...value, terminal: { ...value.terminal, diagnostic: null } };
    else if ("event" in value) primary = { ...value, event: primaryResponse(value.event) };
    else if ("observation" in value)
      primary = { ...value, observation: primaryResponse(value.observation) };
  }
  if (!validate.ServerMessage(primary)) invalid();
  const result = value as ServerMessage;
  if ("event" in result) progress(result.event);
  if ("observation" in result) return { observation: response(result.observation) };
  if ("event" in result && result.event.event.outcome)
    return {
      event: {
        ...result.event,
        event: {
          ...result.event.event,
          outcome: ownOutcome(result.event.event.outcome, result.event.cursor),
        },
      },
    };
  return result;
}

/** Bounded parser for the advertised single-line JSON SSE profile. The host
 * delivers UTF-8 chunks; no buffer or queue grows with stream history. */
export class SseDecoder {
  private bytes = new Uint8Array(9216);
  private length = 0;
  private decoder = new TextDecoder("utf-8", { fatal: true });
  push(chunk: Uint8Array, consume: (item: SseItem, value: ServerMessage) => void) {
    for (const byte of chunk) {
      if (this.length === this.bytes.length) throw new ReactiveError(0, "message_too_large");
      this.bytes[this.length++] = byte;
      if (this.length < 2 || this.bytes[this.length - 2] !== 10 || byte !== 10) continue;
      let text: string;
      try {
        text = this.decoder.decode(this.bytes.subarray(0, this.length));
      } catch {
        return invalid();
      }
      this.length = 0;
      const fields: Record<string, string> = {};
      for (const line of text.slice(0, -2).split("\n")) {
        const match = /^(event|data|id): (.*)$/.exec(line);
        if (!match || match[1]! in fields) invalid();
        fields[match[1]!] = match[2]!;
      }
      if (!validate.SseItem(fields)) invalid();
      const item = fields as SseItem;
      let value: unknown;
      try {
        value = JSON.parse(item.data);
      } catch {
        return invalid();
      }
      const decoded = message(value);
      if (!(item.event in decoded) || (item.event === "event") !== (item.id !== undefined))
        invalid();
      consume(item, decoded);
    }
  }
  end() {
    if (this.length !== 0) throw new ReactiveError(0, "interrupted");
  }
}

export class Transport {
  constructor(private readonly fetcher: typeof fetch = globalThis.fetch.bind(globalThis)) {}
  private async post(path: string, body: unknown, signal?: AbortSignal) {
    return this.fetcher(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      credentials: "same-origin",
      redirect: "error",
      cache: "no-store",
      signal,
    }).catch((error: unknown) => {
      if (signal?.aborted && signal.reason?.name !== "TimeoutError") throw error;
      throw new ReactiveError(503, "unavailable");
    });
  }
  private async json(path: string, body: unknown, signal?: AbortSignal): Promise<unknown> {
    // The qualified host permits 30 seconds of joined work. Leave room for its
    // terminal response; an early abort can retain the server control slot.
    const timeout = AbortSignal.timeout(35000);
    const result = await this.post(
      path,
      body,
      signal ? AbortSignal.any([signal, timeout]) : timeout,
    );
    if (!result.ok) return this.rejectResponse(result, signal);
    return this.decodeJson(result, signal);
  }
  private async rejectResponse(result: Response, signal?: AbortSignal): Promise<never> {
    let value: unknown;
    try {
      value = await this.decodeJson(result, signal);
    } catch {
      // The known status survives malformed or interrupted optional detail.
      const failure = requestFailure(result.status);
      throw new ReactiveError(failure.status, failure.reason, {});
    }
    throw requestFailure(result.status, value);
  }
  private async decodeJson(result: Response, signal?: AbortSignal): Promise<unknown> {
    if (!result.headers.get("content-type")?.startsWith("application/json")) {
      await result.body?.cancel();
      invalid();
    }
    const reader = result.body?.getReader();
    if (!reader) invalid();
    const bytes = new Uint8Array(16384);
    let length = 0;
    try {
      while (true) {
        const part = await reader.read().catch((error: unknown) => {
          if (signal?.aborted) throw error;
          throw new ReactiveError(503, "unavailable");
        });
        if (part.done) break;
        if (length + part.value.length > bytes.length)
          throw new ReactiveError(0, "response_too_large");
        bytes.set(part.value, length);
        length += part.value.length;
      }
      try {
        return JSON.parse(
          new TextDecoder("utf-8", { fatal: true }).decode(bytes.subarray(0, length)),
        );
      } catch {
        return invalid();
      }
    } finally {
      await reader.cancel().catch(() => {});
      reader.releaseLock();
    }
  }
  async host(request: HostRequest, signal?: AbortSignal, control = false): Promise<HostResponse> {
    if (!validate.HostRequest(request)) throw new ReactiveError(0, "invalid_request");
    const readOnly =
      "describe" in request ||
      "clock" in request ||
      "inspect" in request ||
      "covered" in request ||
      "observe" in request ||
      "recover_control" in request ||
      "sign_read" in request ||
      "refresh_status" in request;
    for (let attempt = 0; ; attempt++) {
      try {
        const value = await this.json(
          control ? "/reactive/v1/client/control" : "/reactive/v1/client",
          request,
          signal,
        );
        const rejected =
          value &&
          typeof value === "object" &&
          "observation" in value &&
          value.observation &&
          typeof value.observation === "object" &&
          "rejected" in value.observation
            ? value.observation.rejected
            : null;
        let primary =
          rejected && typeof rejected === "object" && "diagnostic" in rejected
            ? { ...(value as object), observation: { rejected: { ...rejected, diagnostic: null } } }
            : value;
        if (
          primary &&
          typeof primary === "object" &&
          "refresh_status" in primary &&
          primary.refresh_status &&
          typeof primary.refresh_status === "object"
        )
          primary = {
            ...primary,
            refresh_status: { ...primary.refresh_status, diagnostic: null, query_diagnostic: null },
          };
        if (!validate.HostResponse(primary)) invalid();
        const result = value as HostResponse;
        if ("inspection" in result) {
          progress({
            cursor: result.inspection.response.cursor,
            snapshot: { observation: result.inspection.observation },
          });
          return {
            inspection: { ...result.inspection, response: response(result.inspection.response) },
          };
        }
        if ("refresh_status" in result && result.refresh_status.view) {
          const view = result.refresh_status.view;
          source(view.source);
          counter(view.template, true);
          counter(view.namespace, true);
          counter(view.dirty);
          counter(view.covered);
        }
        return result;
      } catch (error) {
        if (
          "submit" in request &&
          error instanceof ReactiveError &&
          error.diagnostic &&
          (error.diagnostic.stage === "submit" ||
            ["unknown", "pending"].includes(error.diagnostic.outcome))
        ) {
          const identity = error.diagnostic.identity;
          if (
            error.diagnostic.stage !== "submit" ||
            identity?.domain !== "transport" ||
            identity.id !== String(request.submit.request.sequence) ||
            identity.sequence !== String(request.submit.request.sequence) ||
            identity.realm !== String(request.submit.request.realm)
          )
            error = new ReactiveError(error.status, error.reason, {});
        }
        if (
          !readOnly ||
          attempt >= 2 ||
          signal?.aborted ||
          !(error instanceof ReactiveError) ||
          (error.status !== 429 && error.status !== 503) ||
          !["capacity", "unavailable"].includes(error.reason) ||
          error.diagnostic?.category === "unsupported"
        )
          throw error;
        await new Promise((resolve) => setTimeout(resolve, 100 * (attempt + 1)));
        signal?.throwIfAborted();
      }
    }
  }
  async read(request: ReactiveRead, signal?: AbortSignal): Promise<ReactiveResponse> {
    if (!validate.ReactiveRead(request)) throw new ReactiveError(0, "invalid_request");
    return response(await this.json("/reactive/v1/read", request, signal));
  }
  async challenge(request: ReactiveRead, signal?: AbortSignal) {
    if (!validate.ReactiveRead(request)) throw new ReactiveError(0, "invalid_request");
    const value = message(await this.json("/reactive/v1/challenge", request, signal));
    if (!("challenge" in value)) invalid();
    return value.challenge;
  }
  async events(
    bootstrap: Bootstrap,
    consume: (value: ServerMessage, id: string | null) => void,
    signal: AbortSignal,
  ) {
    const idle = new AbortController();
    let timer = setTimeout(() => idle.abort(new ReactiveError(0, "disconnected")), 35000);
    try {
      await this.stream(
        bootstrap,
        (value, id) => {
          clearTimeout(timer);
          timer = setTimeout(() => idle.abort(new ReactiveError(0, "disconnected")), 35000);
          consume(value, id);
        },
        AbortSignal.any([signal, idle.signal, AbortSignal.timeout(35000)]),
      );
    } finally {
      clearTimeout(timer);
      idle.abort();
    }
  }
  private async stream(
    bootstrap: Bootstrap,
    consume: (value: ServerMessage, id: string | null) => void,
    signal: AbortSignal,
  ) {
    if (!validate.Bootstrap(bootstrap)) throw new ReactiveError(0, "invalid_request");
    const result = await this.post("/reactive/v1/events", bootstrap, signal);
    if (!result.ok) return this.rejectResponse(result, signal);
    if (!result.headers.get("content-type")?.startsWith("text/event-stream")) {
      await result.body?.cancel();
      invalid();
    }
    const reader = result.body?.getReader();
    if (!reader) invalid();
    const parser = new SseDecoder();
    let terminal = false;
    try {
      while (!terminal) {
        const part = await reader.read();
        if (part.done) {
          parser.end();
          throw new ReactiveError(0, "interrupted");
        }
        if (part.value.length > 65536) throw new ReactiveError(0, "transport_chunk_too_large");
        parser.push(part.value, (item, value) => {
          if (terminal) invalid();
          terminal = "terminal" in value;
          consume(value, item.id ?? null);
        });
      }
    } finally {
      await reader.cancel();
      reader.releaseLock();
    }
  }
}
export function discovery(value: unknown): Discovery {
  if (!validate.Discovery(value)) invalid();
  return value as Discovery;
}
export {
  Session,
  type Inspection,
  type Pending,
  type RefreshView,
  type RefreshCommand,
  type Selection,
} from "./session";
export { acquireCaller, type AcquireCaller, type Caller } from "./caller-gate";

export {
  LiveView,
  type ViewState,
  type Snapshot,
  type ViewReader,
  type Basis,
  type ViewPhase,
} from "./view";
