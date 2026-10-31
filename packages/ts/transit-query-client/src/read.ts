import { readDefinition, type ReadRequest, type ReadResponse } from "./read-types";
import { ReadRequest as validRequest, ReadResponse as validResponse } from "./read-validators.js";
import { boundedQueryJson, logicalCellValid, logicalColumnsValid, logicalInteger } from "./logical";
import { QueryError } from "./transport";
export { readDefinition } from "./read-types";
export type ResultView = Extract<ReadResponse, { result: unknown }>["result"]["view"];
export type ReadDescription = Extract<ReadResponse, { description: unknown }>["description"];
export type ReadTransport = (request: ReadRequest, signal?: AbortSignal) => Promise<ReadResponse>;

export function validateReadResponse(value: unknown): value is ReadResponse {
  if (!boundedQueryJson(value, 4194304) || !validResponse(value)) return false;
  const response = value as ReadResponse;
  if (!("result" in response)) return true;
  const { id, view } = response.result;
  if (
    !/^[0-9a-f]{32}$/.test(id) ||
    !/^[0-9a-f]{64}$/.test(view.result) ||
    !logicalColumnsValid(view.columns) ||
    !logicalInteger(view.start, 64, false) ||
    !logicalInteger(view.delivered, 64, false) ||
    (view.complete_rows !== null && !logicalInteger(view.complete_rows, 64, false))
  )
    return false;
  const start = BigInt(view.start),
    delivered = BigInt(view.delivered);
  if (delivered - start !== BigInt(view.rows.length) || start > delivered) return false;
  if (view.complete_rows !== null && BigInt(view.complete_rows) < delivered) return false;
  if (
    view.stopped === "complete" &&
    (view.complete_rows === null || BigInt(view.complete_rows) !== delivered)
  )
    return false;
  return view.rows.every(
    (row) =>
      row.length === view.columns.length &&
      row.every((cell, index) => logicalCellValid(cell, view.columns[index]!)),
  );
}

/** Retry only explicit pre-dispatch throttling with the exact same request. */
export const readTransport: ReadTransport = async (request, signal) => {
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
      return await readAttempt(body, deadline);
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

/** One bounded attempt; unknown outcomes never cause implicit SQL replay. */
async function readAttempt(body: string, signal: AbortSignal): Promise<ReadResponse> {
  const response = await fetch("/api/v1/sql-read", {
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
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      if (chunk.value.length > bytes.length - size) throw new QueryError(0, "ResponseTooLarge");
      bytes.set(chunk.value, size);
      size += chunk.value.length;
    }
  } finally {
    await reader.cancel();
  }
  const value: unknown = JSON.parse(
    new TextDecoder("utf-8", { fatal: true }).decode(bytes.subarray(0, size)),
  );
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
  if (!validateReadResponse(value)) throw new QueryError(0, "InvalidResponse");
  return value;
}

export async function describeReads(
  signal?: AbortSignal,
  transport = readTransport,
): Promise<ReadDescription> {
  const value = await transport({ definition: readDefinition, action: { describe: {} } }, signal);
  if (!("description" in value)) throw new QueryError(0, "InvalidResponse");
  return value.description;
}

/** A single explicit statement and its result. Closed/uncertain readers never
 * create replacement work. Views render values, not native delivery machinery. */
export class StatementReader {
  readonly id: string;
  private submitted = false;
  private closed = false;
  private busy = false;
  private identity: string | null = null;
  private delivered: string | null = null;
  constructor(
    readonly sql: string,
    private readonly transport: ReadTransport = readTransport,
    id = crypto.randomUUID().replaceAll("-", ""),
    private readonly expectedDefinition: string | null = null,
  ) {
    this.id = id;
  }
  private async request(action: ReadRequest["action"], signal?: AbortSignal): Promise<ResultView> {
    if (this.closed || this.busy) throw new QueryError(0, "ResultUnavailable");
    this.busy = true;
    try {
      const response = await this.transport({ definition: readDefinition, action }, signal);
      if (this.closed || signal?.aborted) throw new QueryError(0, "ResultClosed");
      if (
        !validateReadResponse(response) ||
        !("result" in response) ||
        response.result.id !== this.id
      )
        throw new QueryError(0, "InvalidResponse");
      const view = response.result.view;
      const identity = JSON.stringify([view.result, view.columns, view.observation]);
      if (this.identity !== null && this.identity !== identity)
        throw new QueryError(0, "ResultIdentityChanged");
      this.identity = identity;
      this.delivered = view.delivered;
      return view;
    } finally {
      this.busy = false;
    }
  }
  run(signal?: AbortSignal): Promise<ResultView> {
    if (this.submitted) throw new QueryError(0, "StatementAlreadySubmitted");
    this.submitted = true;
    return this.request(
      { run: { id: this.id, sql: this.sql, expected_definition: this.expectedDefinition } },
      signal,
    );
  }
  refresh(signal?: AbortSignal): Promise<ResultView> {
    return this.request({ observe: this.id }, signal);
  }
  next(signal?: AbortSignal): Promise<ResultView> {
    if (this.delivered === null) throw new QueryError(0, "ResultUnavailable");
    return this.request({ next: { id: this.id, after: this.delivered } }, signal);
  }
  async close(): Promise<void> {
    if (this.closed) return;
    this.closed = true;
    if (this.submitted)
      await this.transport({ definition: readDefinition, action: { close: this.id } });
  }
}
