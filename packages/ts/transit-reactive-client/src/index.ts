import * as validate from "./validators.js";
import type {
  Bootstrap,
  Discovery,
  HostRequest,
  HostResponse,
  ReactiveRead,
  ReactiveResponse,
  ServerMessage,
  SseItem,
} from "./types";
export type * from "./types";

export class ReactiveError extends Error {
  constructor(
    readonly status: number,
    readonly reason: string,
  ) {
    super(reason);
  }
  get clearsProtectedState() {
    return (
      this.status === 403 ||
      this.status === 410 ||
      this.reason === "denied" ||
      this.reason === "expired"
    );
  }
}
function invalid(): never {
  throw new ReactiveError(0, "invalid_response");
}
function integer(value: string) {
  const number = BigInt(value);
  if (number < -9223372036854775808n || number > 9223372036854775807n) invalid();
}
export function response(value: unknown): ReactiveResponse {
  if (!validate.ReactiveResponse(value)) invalid();
  const result = value as ReactiveResponse;
  for (const row of result.snapshot?.rows ?? []) {
    if (!row) continue;
    integer(row.key);
    if (row.value !== null) integer(row.value);
  }
  return result;
}
export function message(value: unknown): ServerMessage {
  if (!validate.ServerMessage(value)) invalid();
  const result = value as ServerMessage;
  if ("observation" in result) response(result.observation);
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
  constructor(private readonly fetcher: typeof fetch = fetch) {}
  private async post(path: string, body: unknown, signal?: AbortSignal) {
    return this.fetcher(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      credentials: "same-origin",
      redirect: "error",
      cache: "no-store",
      signal,
    });
  }
  private async json(path: string, body: unknown, signal?: AbortSignal): Promise<unknown> {
    const timeout = AbortSignal.timeout(5000);
    const result = await this.post(
      path,
      body,
      signal ? AbortSignal.any([signal, timeout]) : timeout,
    );
    if (!result.ok) {
      await result.body?.cancel();
      throw new ReactiveError(
        result.status,
        result.status === 403
          ? "denied"
          : result.status === 410
            ? "expired"
            : result.status === 409
              ? "reset_required"
              : "unavailable",
      );
    }
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
        const part = await reader.read();
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
      await reader.cancel();
      reader.releaseLock();
    }
  }
  async host(request: HostRequest, signal?: AbortSignal, control = false): Promise<HostResponse> {
    if (!validate.HostRequest(request)) throw new ReactiveError(0, "invalid_request");
    const value = await this.json(
      control ? "/reactive/v1/client/control" : "/reactive/v1/client",
      request,
      signal,
    );
    if (!validate.HostResponse(value)) invalid();
    return value as HostResponse;
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
    let timer = setTimeout(() => idle.abort(new ReactiveError(0, "disconnected")), 5000);
    try {
      await this.stream(
        bootstrap,
        (value, id) => {
          clearTimeout(timer);
          timer = setTimeout(() => idle.abort(new ReactiveError(0, "disconnected")), 5000);
          consume(value, id);
        },
        AbortSignal.any([signal, idle.signal, AbortSignal.timeout(31000)]),
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
    if (!result.ok) {
      await result.body?.cancel();
      throw new ReactiveError(
        result.status,
        result.status === 403
          ? "denied"
          : result.status === 410
            ? "expired"
            : result.status === 409
              ? "reset_required"
              : "unavailable",
      );
    }
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
