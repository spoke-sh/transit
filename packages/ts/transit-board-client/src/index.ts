import type { StateResponse, Capabilities, Error as ErrorBody } from "./types";
import { inspectionResponse, type Response } from "./effects";
export { inspectionResponse, type Response } from "./effects";
export type { StateResponse, Capabilities } from "./types";
export { relationalQuery, validateRelational } from "./relational";
export type {
  RelationalRequest,
  RelationalResponse,
  RelationalReference,
  RelationalPage,
  RelationalOpened,
  RelationalDescription,
  RelationalProfile,
} from "./relational";
export type Page = Response["observation"];
export type Process = NonNullable<Page["processes"][number]>;
export type Event = NonNullable<Page["events"][number]>;
export type Outbox = NonNullable<Page["outbox"][number]>;
export type Resource = Page["resource"] | "journey";
export type Cut = Page["cut"];
// Standalone validators are generated at build time: browser CSP forbids eval.
import {
  Response as responseValidator,
  StateResponse as stateResponseValidator,
  Capabilities as capabilitiesValidator,
  Error as errorValidator,
} from "./validators.js";

import { QueryError as BoardError, httpTransport } from "@rey/transit-query-client";
export { QueryError as BoardError } from "@rey/transit-query-client";
export const validateResponse = (value: unknown): value is Response => {
  if (!responseValidator(value)) return false;
  try {
    return !inspectionResponse(value).effectDiagnosticsInvalid;
  } catch {
    return false;
  }
};
export const validateCapabilities = (value: unknown): value is Capabilities =>
  capabilitiesValidator(value);
export async function request<T>(
  path: string,
  validate: (value: unknown) => value is T,
  options?: {
    signal?: AbortSignal;
    body?: UnifiedQueryRequest | import("./types").RelationalRequest;
  },
): Promise<T> {
  if (!path.startsWith("/api/v1/")) throw new BoardError(0, "InvalidPath");
  // Board permits a five-second request budget; leave bounded time for its
  // response instead of aborting a valid slow page before that deadline.
  const abort = AbortSignal.timeout(6000);
  const response = await fetch(path, {
    method: options?.body ? "POST" : "GET",
    headers: options?.body ? { "content-type": "application/json" } : undefined,
    body: options?.body ? JSON.stringify(options.body) : undefined,
    // Board owns no credentials; allow a deployment's same-origin ingress.
    credentials: "same-origin",
    cache: "no-store",
    redirect: "error",
    signal: options?.signal ? AbortSignal.any([abort, options.signal]) : abort,
  });
  // Bound decoded bytes, including chunked responses, before parsing.
  const reader = response.body?.getReader();
  if (!reader) throw new BoardError(0, "InvalidResponse");
  let size = 0;
  // V1 carries a <=64 KiB Arrow segment as hex plus decoded cells. JSON
  // control-character escaping can expand those cell bytes sixfold; include
  // bounded schema/conflict/provenance overhead without changing row limits.
  const maximum = path === "/api/v1/query" ? 1048576 : 262144;
  const chunks: Uint8Array[] = [];
  try {
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      size += next.value.byteLength;
      if (size > maximum) throw new BoardError(0, "ResponseTooLarge");
      chunks.push(next.value);
    }
  } finally {
    await reader.cancel();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  let value: unknown;
  try {
    value = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new BoardError(0, "InvalidResponse");
  }
  if (!response.ok) {
    const primary =
      typeof value === "object" && value !== null ? { ...value, diagnostic: null } : value;
    const error = errorValidator(primary) ? (primary as ErrorBody).err : "InvalidResponse";
    throw new BoardError(
      response.status,
      error,
      typeof value === "object" && value !== null && "diagnostic" in value
        ? value.diagnostic
        : undefined,
    );
  }
  if (!validate(value)) throw new BoardError(0, "InvalidResponse");
  return value;
}
export function read(
  resource: Resource,
  pid?: number,
  continuation?: { cut: Cut; after: number },
  signal?: AbortSignal,
) {
  if (pid !== undefined && (!Number.isSafeInteger(pid) || pid <= 0))
    throw new BoardError(0, "InvalidPid");
  const base =
    resource === "processes"
      ? "/api/v1/processes"
      : `/api/v1/processes/${pid}${resource === "process" ? "" : `/${resource}`}`;
  const query = continuation
    ? `?${new URLSearchParams(Object.entries({ after: continuation.after, ...continuation.cut }).map(([key, value]) => [key, String(value)]))}`
    : "";
  return request(base + query, (value: unknown): value is unknown => value !== undefined, {
    signal,
  }).then(inspectionResponse);
}
export const capabilities = (signal?: AbortSignal) =>
  request("/api/v1/capabilities", validateCapabilities, { signal });

export type StateResource = "resources" | "associations" | "entries";
export const validateStateResponse = (value: unknown): value is StateResponse =>
  stateResponseValidator(value);
export function readState(
  resource: StateResource,
  id?: number,
  continuation?: { cut: Cut; after: number },
  signal?: AbortSignal,
) {
  if (id !== undefined && (!Number.isSafeInteger(id) || id <= 0))
    throw new BoardError(0, "InvalidResource");
  if (resource !== "resources" && id === undefined) throw new BoardError(0, "InvalidResource");
  const base =
    resource === "associations"
      ? `/api/v1/processes/${id}/associations`
      : `/api/v1/resources${id === undefined ? "" : `/${id}`}${resource === "entries" ? "/entries" : ""}`;
  const query = continuation
    ? `?${new URLSearchParams(Object.entries({ after: continuation.after, ...continuation.cut }).map(([key, value]) => [key, String(value)]))}`
    : "";
  return request(base + query, validateStateResponse, { signal });
}

export type {
  UnifiedQueryRequest,
  UnifiedQueryResponse,
  AtlasResponse,
  ParticipationResponse,
  RecordsResponse,
  HttpResponse,
  GrpcResponse,
  DocumentResponse,
} from "./types";
import type {
  UnifiedQueryRequest,
  UnifiedQueryResponse,
  AtlasResponse,
  ParticipationResponse,
  RecordsResponse,
  HttpResponse,
  GrpcResponse,
  DocumentResponse,
} from "./types";
import {
  AtlasResponse as atlasValidator,
  ParticipationResponse as participationValidator,
  RecordsResponse as recordsValidator,
  HttpResponse as httpValidator,
  GrpcResponse as grpcValidator,
  DocumentResponse as documentValidator,
} from "./validators.js";
export { validateUnifiedQuery, unifiedCellText } from "./unified";
export type { UnifiedCell } from "./unified";
const wide = (text: string, zero = false) =>
  /^(0|[1-9][0-9]{0,19})$/.test(text) &&
  (zero || text !== "0") &&
  BigInt(text) <= 18446744073709551615n;
/** Failure provenance describes capture only; it never resolves remote execution. */
function validCaptureFailure(
  failure: NonNullable<HttpResponse["failure"]>,
  source: HttpResponse["source"],
  exchange: string,
): boolean {
  const f = failure;
  const hasCause =
    f.reason === "transport_failure" ||
    f.reason === "capture_failure" ||
    f.reason === "preparation_failure";
  if (
    f.exchange !== exchange ||
    !wide(exchange) ||
    f.resource !== source.resource ||
    f.owner !== source.pid ||
    f.owner === 0 ||
    f.input === 0 ||
    f.input > source.position ||
    f.origin_input > source.position ||
    !wide(f.bytes, true) ||
    (f.effect === 0) !== (f.attempt === 0) ||
    f.effect > source.position ||
    f.attempt > source.position ||
    !["preparing", "ready", "capturing"].includes(f.phase) ||
    (f.phase === "preparing" && f.effect !== 0) ||
    (f.phase === "capturing" && f.effect === 0) ||
    hasCause !== (f.cause !== null) ||
    (!hasCause && f.cause_truncated) ||
    (f.cause !== null && (f.cause.length === 0 || new TextEncoder().encode(f.cause).length > 96))
  )
    return false;
  if (
    f.reason === "preparation_failure" &&
    (f.phase !== "preparing" || f.origin_input === 0 || f.effect !== 0 || f.attempt !== 0)
  )
    return false;
  if (
    f.reason !== "capture_failure" &&
    (f.operation !== "none" ||
      (f.reason !== "preparation_failure" && f.origin_input !== 0) ||
      f.kind !== 0 ||
      f.member !== 0 ||
      f.chunk !== 0 ||
      f.requested_bytes !== 0)
  )
    return false;
  return f.operation === "append" || f.chunk === 0;
}
function validCapturePage(page: HttpResponse | GrpcResponse): boolean {
  if ((page.phase === "unknown") !== (page.failure !== null)) return false;
  return page.failure === null || validCaptureFailure(page.failure, page.source, page.exchange);
}
export function validateHttp(value: unknown): value is HttpResponse {
  if (!httpValidator(value)) return false;
  const page = value as HttpResponse;
  if (!validCapturePage(page)) return false;
  if (!wide(page.exchange) || page.phase === "retired") return false;
  const prefix = `0045${BigInt(page.exchange).toString(16).padStart(16, "0")}`;
  if (page.source.key !== `${prefix}6400000000`) return false;
  type Member = NonNullable<HttpResponse["policy"]>["member"];
  const member = (m: Member, kind: Member["kind"]) =>
    m.kind === kind && m.key === `${prefix}6d${m.ordinal.toString(16).padStart(8, "0")}`;
  if (page.policy) {
    const p = page.policy;
    if (
      !member(p.member, "request_template") ||
      p.member.ordinal !== 0 ||
      !wide(p.endpoint_revision) ||
      !wide(p.request_bytes, true) ||
      !wide(p.response_bytes, true) ||
      p.tls !== (p.trust_digest !== null)
    )
      return false;
    for (const ref of [p.retry, p.redirect, p.reconcile, p.cancel])
      if (ref && (!wide(ref.id) || !wide(ref.revision))) return false;
  }
  if ((page.phase === "complete") !== (page.terminal !== null)) return false;
  if (page.terminal) {
    const t = page.terminal;
    if (
      !page.policy ||
      !member(t.timing.member, "timing") ||
      !member(t.omission.member, "omission") ||
      !member(t.completion.member, "completion") ||
      t.omission.member.ordinal !== t.timing.member.ordinal + 1 ||
      t.completion.member.ordinal !== t.omission.member.ordinal + 1 ||
      !wide(t.timing.started_ms) ||
      !wide(t.timing.elapsed_ns, true) ||
      !wide(t.completion.request_bytes, true) ||
      !wide(t.completion.response_bytes, true) ||
      t.completion.member.chain.some((byte, index) => byte !== page.coverage[index])
    )
      return false;
  }
  return true;
}
export async function httpMetadata(resource: number, exchange: string, signal?: AbortSignal) {
  if (!Number.isSafeInteger(resource) || resource <= 0 || !wide(exchange))
    throw new BoardError(0, "InvalidResource");
  const page = await request(`/api/v1/resources/${resource}/http/${exchange}`, validateHttp, {
    signal,
  });
  if (page.source.resource !== resource || page.exchange !== exchange)
    throw new BoardError(0, "InvalidResponse");
  return page;
}
export function validateGrpc(value: unknown): value is GrpcResponse {
  if (!grpcValidator(value)) return false;
  const page = value as GrpcResponse;
  if (!validCapturePage(page)) return false;
  if (
    !wide(page.exchange) ||
    page.phase === "retired" ||
    !wide(page.response_body_bytes, true) ||
    page.response_message_records > 64
  )
    return false;
  const prefix = `0045${BigInt(page.exchange).toString(16).padStart(16, "0")}`;
  if (page.source.key !== `${prefix}6400000000`) return false;
  type Member = NonNullable<GrpcResponse["policy"]>["member"];
  const member = (m: Member, kind: Member["kind"]) =>
    m.kind === kind &&
    m.ordinal < 256 &&
    m.key === `${prefix}6d${m.ordinal.toString(16).padStart(8, "0")}`;
  if (page.policy) {
    const p = page.policy;
    if (
      !member(p.member, "endpoint_policy") ||
      !wide(p.endpoint_revision) ||
      p.tls !== (p.trust_digest !== null)
    )
      return false;
    if (p.retry && (!wide(p.retry.id) || !wide(p.retry.revision))) return false;
  }
  if (
    page.half_close &&
    (!member(page.half_close.member, "half_close") ||
      page.half_close.messages > 64 ||
      page.half_close.wire_bytes > 65536 ||
      page.half_close.wire_bytes < page.half_close.messages * 5)
  )
    return false;
  if ((page.phase === "complete") !== (page.terminal !== null)) return false;
  if (page.terminal) {
    const t = page.terminal,
      c = t.completion;
    if (
      !page.policy ||
      !member(t.timing.member, "timing") ||
      !member(t.omission.member, "omission") ||
      !member(c.member, "completion") ||
      t.omission.member.ordinal !== t.timing.member.ordinal + 1 ||
      c.member.ordinal !== t.omission.member.ordinal + 1 ||
      !wide(t.timing.started_ms) ||
      !wide(t.timing.elapsed_ns, true) ||
      c.status > 16 ||
      c.sent_messages > 64 ||
      c.received_messages > 64 ||
      c.sent_bytes > 65536 ||
      c.received_bytes > 262144 ||
      c.sent_bytes < c.sent_messages * 5 ||
      c.received_messages !== page.response_message_records ||
      BigInt(c.received_bytes) !==
        BigInt(page.response_body_bytes) + BigInt(c.received_messages * 5) ||
      c.half_closed !== (page.half_close !== null) ||
      c.member.chain.some((byte, index) => byte !== page.coverage[index])
    )
      return false;
    if (
      page.half_close &&
      (page.half_close.messages !== c.sent_messages || page.half_close.wire_bytes !== c.sent_bytes)
    )
      return false;
  }
  return true;
}
export async function grpcMetadata(resource: number, exchange: string, signal?: AbortSignal) {
  if (!Number.isSafeInteger(resource) || resource <= 0 || !wide(exchange))
    throw new BoardError(0, "InvalidResource");
  const page = await request(`/api/v1/resources/${resource}/grpc/${exchange}`, validateGrpc, {
    signal,
  });
  if (page.source.resource !== resource || page.exchange !== exchange)
    throw new BoardError(0, "InvalidResponse");
  return page;
}
type DocumentDetail = DocumentResponse["declaration"];
function validDocument(detail: DocumentDetail, source: DocumentResponse["source"]) {
  return (
    wide(detail.document) &&
    wide(detail.epoch) &&
    detail.type_revision > 0 &&
    detail.change_format === 1 &&
    wide(detail.revision, true) &&
    wide(detail.floor, true) &&
    BigInt(detail.floor) <= BigInt(detail.revision) &&
    wide(detail.merge_window, true) &&
    wide(detail.active_job, true) &&
    source.key ===
      `0044${BigInt(detail.document).toString(16).padStart(16, "0")}680000000000000000` &&
    source.entry_revision <= source.resource_revision
  );
}
export function validateDocument(value: unknown): value is DocumentResponse {
  if (!documentValidator(value)) return false;
  const page = value as DocumentResponse;
  if (
    !validDocument(page.declaration, page.source) ||
    page.declaration.retired !== (page.registers === null)
  )
    return false;
  const r = page.registers;
  return (
    !r ||
    (r.count <= 8 &&
      r.conflicts <= r.count &&
      r.assignments >= r.conflicts * 2 &&
      r.assignments <= r.count * 8 &&
      (r.next === null || (r.count === 8 && /^52(?:[0-9a-f]{2}){16,81}$/.test(r.next))))
  );
}
export type DocumentCursor = { revision: number; after: string };
export async function documentMetadata(
  resource: number,
  document: string,
  cursor?: DocumentCursor,
  signal?: AbortSignal,
) {
  if (!Number.isSafeInteger(resource) || resource <= 0 || !wide(document))
    throw new BoardError(0, "InvalidResource");
  if (
    cursor &&
    (!Number.isSafeInteger(cursor.revision) ||
      cursor.revision < 0 ||
      !/^([0-9a-f]{2}){1,128}$/.test(cursor.after))
  )
    throw new BoardError(0, "InvalidCursor");
  const suffix = cursor
    ? `?${new URLSearchParams({ revision: String(cursor.revision), after: cursor.after })}`
    : "";
  const page = await request(
    `/api/v1/resources/${resource}/documents/${document}${suffix}`,
    validateDocument,
    { signal },
  );
  if (
    page.source.resource !== resource ||
    page.declaration.document !== document ||
    (cursor && page.source.resource_revision !== cursor.revision)
  )
    throw new BoardError(0, "InvalidResponse");
  return page;
}
export function validateRecords(value: unknown): value is RecordsResponse {
  if (!recordsValidator(value)) return false;
  const page = value as RecordsResponse;
  if (
    !page.documents.every((lens, index) => {
      if (!lens) return true;
      const entry = page.page.entries[index],
        source = lens.source;
      return (
        entry != null &&
        source.realm === page.realm &&
        source.resource === page.resource.id &&
        source.pid === page.resource.writer &&
        source.position === page.position &&
        source.resource_revision === page.resource.revision &&
        source.entry_revision === entry.revision &&
        source.key === entry.key &&
        validDocument(lens.declaration, source)
      );
    })
  )
    return false;
  return page.exchanges.every((lens, index) => {
    if (lens === null) return true;
    const entry = page.page.entries[index];
    const source = lens.source;
    if (
      entry == null ||
      source.realm !== page.realm ||
      source.resource !== page.resource.id ||
      source.pid !== page.resource.writer ||
      source.position !== page.position ||
      source.resource_revision !== page.resource.revision ||
      source.entry_revision !== entry.revision ||
      source.key !== entry.key
    )
      return false;
    const detail = lens.declaration;
    if ("failure" in detail) {
      const f = detail.failure;
      return (
        validCaptureFailure(f, source, f.exchange) &&
        source.key === `0045${BigInt(f.exchange).toString(16).padStart(16, "0")}6600000000`
      );
    }
    if ("capture" in detail) {
      const d = detail.capture;
      return (
        wide(d.exchange) && wide(d.parent, true) && wide(d.bytes, true) && wide(d.capture_bytes)
      );
    }
    if ("lineage" in detail) {
      const d = detail.lineage;
      return (
        wide(d.exchange) &&
        wide(d.root) &&
        wide(d.parent) &&
        wide(d.policy) &&
        wide(d.policy_revision)
      );
    }
    if ("obligations" in detail)
      return wide(detail.obligations.exchange) && wide(detail.obligations.dependents, true);
    return (
      wide(detail.attempts.exchange) &&
      detail.attempts.unsettled < detail.attempts.used &&
      detail.attempts.used <= detail.attempts.limit
    );
  });
}
export function records(
  resource: number,
  cursor?: { revision: number; after: string },
  signal?: AbortSignal,
) {
  if (!Number.isSafeInteger(resource) || resource <= 0) throw new BoardError(0, "InvalidResource");
  if (
    cursor &&
    (!Number.isSafeInteger(cursor.revision) ||
      cursor.revision < 0 ||
      !/^([0-9a-f]{2}){1,32}$/.test(cursor.after))
  )
    throw new BoardError(0, "InvalidCursor");
  const suffix = cursor
    ? `?${new URLSearchParams({ revision: String(cursor.revision), after: cursor.after })}`
    : "";
  return request(`/api/v1/resources/${resource}/records${suffix}`, validateRecords, { signal });
}
export const validateAtlas = (value: unknown): value is AtlasResponse => atlasValidator(value);
export function atlas(
  cursor?: { position: number; process_after?: number; resource_after?: number },
  signal?: AbortSignal,
) {
  const fields = new URLSearchParams();
  for (const [key, value] of Object.entries(cursor ?? {})) {
    if (value === undefined) continue;
    if (!Number.isSafeInteger(value) || value < 0) throw new BoardError(0, "InvalidQuery");
    fields.set(key, String(value));
  }
  return request(`/api/v1/atlas${fields.size ? `?${fields}` : ""}`, validateAtlas, { signal });
}
export type ParticipationCursor = {
  after?: number;
  pid?: number;
  association_after?: number;
  position?: number;
};
export function participation(
  resource: number,
  cursor: ParticipationCursor = {},
  signal?: AbortSignal,
) {
  if (!Number.isSafeInteger(resource) || resource <= 0) throw new BoardError(0, "InvalidQuery");
  const fields = new URLSearchParams();
  for (const [key, value] of Object.entries(cursor)) {
    if (value === undefined) continue;
    if (!Number.isSafeInteger(value) || value <= 0) throw new BoardError(0, "InvalidQuery");
    fields.set(key, String(value));
  }
  return request(
    `/api/v1/resources/${resource}/participation${fields.size ? `?${fields}` : ""}`,
    (value: unknown): value is ParticipationResponse => participationValidator(value),
    { signal },
  );
}
const queryTransport = httpTransport("/api/v1/query");
export const unifiedQuery = (
  operation: UnifiedQueryRequest,
  signal?: AbortSignal,
): Promise<UnifiedQueryResponse> => queryTransport(operation, signal);
