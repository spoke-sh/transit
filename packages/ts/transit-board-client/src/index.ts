import type { Response, Capabilities, Error as ErrorBody } from "./types";
export type { Response, Capabilities } from "./types";
export type Page = Response["observation"];
export type Process = NonNullable<Page["processes"][number]>;
export type Event = NonNullable<Page["events"][number]>;
export type Outbox = NonNullable<Page["outbox"][number]>;
export type Resource = Page["resource"] | "journey";
export type Cut = Page["cut"];
// Standalone validators are generated at build time: browser CSP forbids eval.
import {
  Response as responseValidator,
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
  options?: { signal?: AbortSignal },
): Promise<T> {
  if (!path.startsWith("/api/v1/")) throw new BoardError(0, "InvalidPath");
  const abort = AbortSignal.timeout(4000);
  const response = await fetch(path, {
    method: "GET",
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
