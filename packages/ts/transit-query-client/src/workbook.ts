import { readDefinition, type WorkbookRequest, type WorkbookResponse } from "./read-types";
import {
  WorkbookRequest as validRequest,
  WorkbookResponse as validResponse,
} from "./read-validators.js";
import { boundedQueryJson } from "./logical";
import { QueryError } from "./error";
import { boundedReadTransport } from "./read-http";
import { validateReadResponse } from "./read";
export type WorkbookCell = Extract<
  WorkbookRequest["action"],
  { evaluate: unknown }
>["evaluate"]["cells"][number];
export type WorkbookStatus = Extract<WorkbookResponse, { status: unknown }>["status"];
export type WorkbookBinding = WorkbookStatus["results"][number];
export type WorkbookValidation = Extract<WorkbookResponse, { validation: unknown }>["validation"];
export type WorkbookView = Extract<WorkbookResponse, { result: unknown }>["result"];
export type WorkbookTransport = (
  request: WorkbookRequest,
  signal?: AbortSignal,
) => Promise<WorkbookResponse>;
const idValid = (value: string) => /^[0-9a-f]{32}$/.test(value);
const resultValid = (value: string) => /^[0-9a-f]{64}$/.test(value);
const bindingValid = (value: WorkbookBinding) =>
  idValid(value.cell) &&
  resultValid(value.result) &&
  (value.input === null || resultValid(value.input));
export function validateWorkbookResponse(value: unknown): value is WorkbookResponse {
  if (!boundedQueryJson(value, 4194304) || !validResponse(value)) return false;
  const response = value as WorkbookResponse;
  if ("result" in response) {
    const result = response.result;
    return (
      bindingValid(result.binding) &&
      result.cell === result.binding.cell &&
      result.view.result === result.binding.result &&
      validateReadResponse({ result: { id: result.id, view: result.view } })
    );
  }
  if ("status" in response)
    return (
      idValid(response.status.id) &&
      response.status.remaining <= 32 &&
      response.status.results.every(bindingValid) &&
      new Set(response.status.results.map((item) => item.cell)).size ===
        response.status.results.length
    );
  return true;
}
export const workbookTransport: WorkbookTransport = boundedReadTransport<
  WorkbookRequest,
  WorkbookResponse
>(
  "/api/v1/workbook",
  validRequest,
  validateWorkbookResponse,
  (request) =>
    "evaluate" in request.action || "open" in request.action || "close" in request.action,
);
export async function validateWorkbook(
  cells: WorkbookCell[],
  signal?: AbortSignal,
  transport = workbookTransport,
): Promise<WorkbookValidation> {
  const response = await transport(
    { definition: readDefinition, action: { validate: { cells } } },
    signal,
  );
  if (!("validation" in response)) throw new QueryError(0, "InvalidResponse");
  return response.validation;
}

/** Original session and monotonic attempt. Lost replies admit observation only. */
export class WorkbookSession {
  readonly id: string;
  sequence = 0;
  unresolved = false;
  private opened = false;
  private closed = false;
  constructor(
    private readonly transport = workbookTransport,
    id = crypto.randomUUID().replaceAll("-", ""),
  ) {
    this.id = id;
  }
  private async statusReply(response: WorkbookResponse): Promise<WorkbookStatus> {
    if (
      !("status" in response) ||
      response.status.id !== this.id ||
      response.status.sequence !== this.sequence
    )
      throw new QueryError(0, "InvalidResponse");
    this.unresolved = false;
    return response.status;
  }
  async open() {
    if (this.closed || this.opened) throw new QueryError(0, "InvalidTransition");
    this.opened = true;
    this.unresolved = true;
    return this.statusReply(
      await this.transport({ definition: readDefinition, action: { open: this.id } }),
    );
  }
  async evaluate(cells: WorkbookCell[], targets: string[], affected: boolean, force: boolean) {
    if (!this.opened || this.closed || this.unresolved)
      throw new QueryError(0, "InvalidTransition");
    this.sequence++;
    this.unresolved = true;
    return this.statusReply(
      await this.transport({
        definition: readDefinition,
        action: {
          evaluate: { id: this.id, sequence: this.sequence, cells, targets, affected, force },
        },
      }),
    );
  }
  async status() {
    if (!this.opened || this.closed) throw new QueryError(0, "InvalidTransition");
    return this.statusReply(
      await this.transport({
        definition: readDefinition,
        action: { status: { id: this.id, sequence: this.sequence } },
      }),
    );
  }
  async observe(binding: WorkbookBinding, offset = 0, signal?: AbortSignal): Promise<WorkbookView> {
    if (!this.opened || this.closed) throw new QueryError(0, "InvalidTransition");
    const response = await this.transport(
      {
        definition: readDefinition,
        action: { observe: { id: this.id, cell: binding.cell, result: binding.result, offset } },
      },
      signal,
    );
    if (
      !("result" in response) ||
      response.result.id !== this.id ||
      response.result.cell !== binding.cell ||
      response.result.binding.result !== binding.result ||
      response.result.sequence !== this.sequence ||
      response.result.view.start !== String(offset) ||
      JSON.stringify(response.result.binding) !== JSON.stringify(binding)
    )
      throw new QueryError(0, "InvalidResponse");
    return response.result;
  }
  async close() {
    if (this.closed) return;
    this.closed = true;
    if (!this.opened) return;
    const response = await this.transport({
      definition: readDefinition,
      action: { close: this.id },
    });
    if (!("closed" in response)) throw new QueryError(0, "InvalidResponse");
  }
}
