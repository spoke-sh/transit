import { boundedReadTransport } from "./read-http";
import { readDefinition, type ReadRequest, type ReadResponse } from "./read-types";
import { ReadRequest as validRequest, ReadResponse as validResponse } from "./read-validators.js";
import { boundedQueryJson, logicalCellValid, logicalColumnsValid, logicalInteger } from "./logical";
import { QueryError } from "./error";
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

export const readTransport: ReadTransport = boundedReadTransport<ReadRequest, ReadResponse>(
  "/api/v1/sql-read",
  validRequest,
  validateReadResponse,
  (request) => "run" in request.action || "close" in request.action,
);

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
