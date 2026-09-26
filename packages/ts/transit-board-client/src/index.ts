import type { Response, StateResponse, Capabilities, Error as ErrorBody } from "./types";
export type { Response, StateResponse, Capabilities } from "./types";
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

export class BoardError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
  ) {
    super(code);
  }
}
export const validateResponse = (value: unknown): value is Response => responseValidator(value);
export const validateCapabilities = (value: unknown): value is Capabilities =>
  capabilitiesValidator(value);
export async function request<T>(
  path: string,
  validate: (value: unknown) => value is T,
  options?: { signal?: AbortSignal; body?: QueryRequest },
): Promise<T> {
  if (!path.startsWith("/api/v1/")) throw new BoardError(0, "InvalidPath");
  const abort = AbortSignal.timeout(4000);
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
  const chunks: Uint8Array[] = [];
  try {
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      size += next.value.byteLength;
      if (size > 262144) throw new BoardError(0, "ResponseTooLarge");
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
    const error = errorValidator(value) ? (value as ErrorBody).err : "InvalidResponse";
    throw new BoardError(response.status, error);
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
  return request(base + query, validateResponse, { signal });
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

export type { AtlasResponse, QueryRequest, QueryResponse } from "./types";
import type { AtlasResponse, QueryRequest, QueryResponse } from "./types";
import { AtlasResponse as atlasValidator, QueryResponse as queryValidator } from "./validators.js";
export const validateAtlas = (value: unknown): value is AtlasResponse => atlasValidator(value);
export const validateQuery = (value: unknown): value is QueryResponse => {
  if (!queryValidator(value)) return false;
  const result = value as QueryResponse;
  if (!("page" in result)) return true;
  const page = result.page;
  if (
    page.version !== 1 ||
    page.count > 32 ||
    page.count > page.manifest.rows ||
    page.ordinal >= page.manifest.segments ||
    page.next !== (page.ordinal + 1 < page.manifest.segments ? page.ordinal + 1 : null) ||
    page.columns[0] === null ||
    page.rows.some((row, index) => (row !== null) !== index < page.count)
  )
    return false;
  for (const column of page.columns) {
    if (column && !/^[A-Za-z_][A-Za-z_0-9]{0,15}$/.test(column.name)) return false;
  }
  for (const row of page.rows)
    if (row)
      for (const [index, cell] of row.entries()) {
        const column = page.columns[index];
        if ((cell !== null) !== (column !== null)) return false;
        if (cell && column) {
          if ("null" in cell ? !column.nullable : !(column.type in cell)) return false;
          if ("int64" in cell) {
            if (!/^(0|-?[1-9][0-9]{0,18})$/.test(cell.int64)) return false;
            const integer = BigInt(cell.int64);
            if (integer < -9223372036854775808n || integer > 9223372036854775807n) return false;
          } else if ("binary" in cell) {
            if (cell.binary.length > 440 || !/^(?:[0-9a-f]{2})*$/.test(cell.binary)) return false;
          } else if (
            "utf8" in cell &&
            (new TextEncoder().encode(cell.utf8).length > 220 || /[\uD800-\uDFFF]/u.test(cell.utf8))
          )
            return false;
        }
      }
  return true;
};
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
export async function query(operation: QueryRequest, signal?: AbortSignal): Promise<QueryResponse> {
  // A rate refusal occurs before dispatch. Retry the same body; never compile a
  // replacement for an uncertain signed submission or use a fresh sequence.
  for (let attempt = 0; ; attempt++) {
    try {
      return await request("/api/v1/query", validateQuery, { signal, body: operation });
    } catch (cause) {
      if (!(cause instanceof BoardError) || cause.status !== 429 || attempt >= 3 || signal?.aborted)
        throw cause;
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
}
