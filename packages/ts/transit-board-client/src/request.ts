import { QueryError as BoardError } from "@transit/query-client/error";
import { scheduleRequest } from "@transit/reactive-client/request-scheduling";
import { Error as errorValidator } from "./host-validators.js";
import type { Error as ErrorBody, UnifiedQueryRequest } from "./types";
export async function request<T>(
  path: string,
  validate: (value: unknown) => value is T,
  options?: {
    signal?: AbortSignal;
    body?:
      | UnifiedQueryRequest
      | import("./types").RelationalRequest
      | import("./types").CatalogRequest
      | import("./types").ComputationRequest;
  },
): Promise<T> {
  if (!path.startsWith("/api/v1/")) throw new BoardError(0, "InvalidPath");
  const query = options?.body && "query" in options.body ? options.body.query : null;
  const lane =
    (options?.body && "recover" in options.body) || (query && ("open" in query || "close" in query))
      ? "control"
      : "read";
  return scheduleRequest(
    lane,
    async () => {
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
      let done = false;
      try {
        while (true) {
          const next = await reader.read();
          if (next.done) {
            done = true;
            break;
          }
          size += next.value.byteLength;
          if (size > maximum) throw new BoardError(0, "ResponseTooLarge");
          chunks.push(next.value);
        }
      } finally {
        if (!done) await reader.cancel();
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
        throw new BoardError(response.ok ? 0 : response.status, "InvalidResponse");
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
    },
    options?.signal,
  );
}
export { QueryError as BoardError } from "@transit/query-client/error";
