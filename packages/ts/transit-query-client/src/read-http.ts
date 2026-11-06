import { scheduleRequest } from "@transit/reactive-client/request-scheduling";
import { boundedQueryJson } from "./logical";
import { QueryError } from "./error";
/** Retry only explicit pre-dispatch throttling with the exact same request. */
export function boundedReadTransport<Q, R>(
  path: string,
  validRequest: (value: unknown) => boolean,
  validResponse: (value: unknown) => value is R,
  control: (request: Q) => boolean,
) {
  return async (request: Q, signal?: AbortSignal): Promise<R> => {
    if (!boundedQueryJson(request) || !validRequest(request))
      throw new QueryError(0, "InvalidRequest");
    const body = JSON.stringify(request);
    if (new TextEncoder().encode(body).length > 65536) throw new QueryError(0, "RequestTooLarge");
    const deadline = signal
      ? AbortSignal.any([signal, AbortSignal.timeout(6000)])
      : AbortSignal.timeout(6000);
    for (let attempt = 0; ; attempt++) {
      deadline.throwIfAborted();
      try {
        return await scheduleRequest(
          control(request) ? "control" : "read",
          () => readAttempt(path, body, deadline, validResponse),
          deadline,
        );
      } catch (cause) {
        if (
          !(cause instanceof QueryError) ||
          cause.status !== 429 ||
          cause.code !== "RateLimited" ||
          attempt >= 3 ||
          deadline.aborted
        )
          throw cause;
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
    }
  };
}

/** One bounded attempt; unknown outcomes never cause implicit SQL replay. */
async function readAttempt<R>(
  path: string,
  body: string,
  signal: AbortSignal,
  validResponse: (value: unknown) => value is R,
): Promise<R> {
  const response = await fetch(path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body,
    credentials: "same-origin",
    cache: "no-store",
    redirect: "error",
    signal,
  });
  const reader = response.body?.getReader();
  if (!reader) throw new QueryError(0, "InvalidResponse");
  const bytes = new Uint8Array(4194304);
  let size = 0;
  let done = false;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) {
        done = true;
        break;
      }
      if (chunk.value.length > bytes.length - size) throw new QueryError(0, "ResponseTooLarge");
      bytes.set(chunk.value, size);
      size += chunk.value.length;
    }
  } finally {
    if (!done) await reader.cancel();
  }
  let value: unknown;
  try {
    value = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes.subarray(0, size)));
  } catch {
    throw new QueryError(response.ok ? 0 : response.status, "InvalidResponse");
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
    throw new QueryError(response.status, code);
  }
  if (!validResponse(value)) throw new QueryError(0, "InvalidResponse");
  return value;
}
