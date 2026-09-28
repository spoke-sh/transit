import type { Request, Response } from "./types";
import { Request as validRequest } from "./validators.js";
import { validateUnifiedQuery } from "./values";
export class QueryError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}
export type Transport = (request: Request, signal?: AbortSignal) => Promise<Response>;
/** One same-origin private host. A native prepared token is frozen on uncertainty;
 * retry only pre-dispatch throttling or explicit conflicts on read/preparation. */
export function httpTransport(endpoint: string, timeoutMs = 6000): Transport {
  if (
    !endpoint.startsWith("/") ||
    endpoint.startsWith("//") ||
    timeoutMs < 1000 ||
    timeoutMs > 60000
  )
    throw new QueryError(0, "InvalidTransport");
  return async (request, signal) => {
    if (!validRequest(request)) throw new QueryError(0, "InvalidRequest");
    const body = JSON.stringify(request);
    if (new TextEncoder().encode(body).length > 49152) throw new QueryError(0, "RequestTooLarge");
    // These operations read or prepare only. Keep this allowlist explicit so a
    // future effectful request cannot inherit read-conflict retry accidentally.
    const readOnly = [
      "describe",
      "suggest",
      "compile",
      "next",
      "next_draft",
      "draft_open",
      "draft_close",
      "draft_status",
      "observe",
      "status",
      "page",
      "prepare_control",
    ].some((operation) => operation in request);
    for (let attempt = 0; ; attempt++) {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body,
        credentials: "same-origin",
        cache: "no-store",
        redirect: "error",
        signal: signal
          ? AbortSignal.any([signal, AbortSignal.timeout(timeoutMs)])
          : AbortSignal.timeout(timeoutMs),
      });
      if (response.status === 429 && attempt < 3 && !signal?.aborted) {
        await response.body?.cancel();
        await new Promise((resolve) => setTimeout(resolve, 250));
        continue;
      }
      const reader = response.body?.getReader();
      if (!reader) throw new QueryError(0, "InvalidResponse");
      let length = 0;
      const bytes = new Uint8Array(1048576);
      try {
        while (true) {
          const chunk = await reader.read();
          if (chunk.done) break;
          if (chunk.value.length > bytes.length - length)
            throw new QueryError(0, "ResponseTooLarge");
          bytes.set(chunk.value, length);
          length += chunk.value.length;
        }
      } finally {
        await reader.cancel();
      }
      let value: unknown;
      try {
        value = JSON.parse(
          new TextDecoder("utf-8", { fatal: true }).decode(bytes.subarray(0, length)),
        );
      } catch {
        throw new QueryError(0, "InvalidResponse");
      }
      if (!response.ok) {
        const code =
          typeof value === "object" &&
          value !== null &&
          "err" in value &&
          typeof value.err === "string" &&
          /^[A-Za-z][A-Za-z0-9_]{0,127}$/.test(value.err)
            ? value.err
            : "InvalidResponse";
        if (
          response.status === 409 &&
          (code === "QueryReadConflict" || code === "QueryExpired") &&
          readOnly &&
          attempt < 3 &&
          !signal?.aborted
        ) {
          await new Promise((resolve) => setTimeout(resolve, 250));
          continue;
        }
        throw new QueryError(response.status, code);
      }
      if (!validateUnifiedQuery(value)) throw new QueryError(0, "InvalidResponse");
      return value;
    }
  };
}
