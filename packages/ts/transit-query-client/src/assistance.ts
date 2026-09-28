import type { Response } from "./types";
import { QueryError, type Transport } from "./transport";
import { validateUnifiedQuery } from "./values";
export type Assistance = Extract<Response, { assistance: unknown }>["assistance"];
export type EditorInput = { sql: string; cursor: number; generation: number };
export type Assisted = { input: EditorInput; response: Assistance };
export type AssistanceState = { result: Assisted | null; busy: boolean; error: string };
const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });
export function byteCursor(sql: string, utf16: number): number {
  if (
    !Number.isInteger(utf16) ||
    utf16 < 0 ||
    utf16 > sql.length ||
    /[\uD800-\uDFFF]/u.test(sql) ||
    /[\uD800-\uDFFF]/u.test(sql.slice(0, utf16))
  )
    throw new QueryError(0, "InvalidSqlCursor");
  if (encoder.encode(sql).length > 4096) throw new QueryError(0, "StatementTooLarge");
  return encoder.encode(sql.slice(0, utf16)).length;
}
/** Acceptance changes only the draft. It never calls the transport. */
export function applySuggestion(
  current: string,
  selected: Assisted,
  index: number,
): { sql: string; cursor: number } {
  const range = selected.response.range;
  const item = selected.response.items[index];
  if (
    current !== selected.input.sql ||
    selected.response.generation !== selected.input.generation ||
    !range ||
    !item ||
    !Number.isInteger(index)
  )
    throw new QueryError(0, "StaleAssistance");
  const bytes = encoder.encode(current);
  if (range.start > range.end || range.end > bytes.length)
    throw new QueryError(0, "InvalidResponse");
  const before = decoder.decode(bytes.subarray(0, range.start));
  const after = decoder.decode(bytes.subarray(range.end));
  const sql = before + item.text + after;
  byteCursor(sql, sql.length);
  return { sql, cursor: before.length + item.text.length };
}
/** One pending read and one coalesced input. No history, values or disk cache.
 * An open suggestion list refreshes current authority every five seconds. */
export class AssistanceReader {
  private generation = 0;
  private input: EditorInput | null = null;
  private active = false;
  private running = false;
  private controller: AbortController | null = null;
  private timer: ReturnType<typeof setTimeout> | undefined;
  private contract: string | null;
  constructor(
    private readonly query: Transport,
    private readonly resource: number,
    expectedContract: number[] | null,
    private changed: (state: AssistanceState) => void,
    private readonly denied: () => void,
  ) {
    this.contract = expectedContract ? JSON.stringify(expectedContract) : null;
  }
  edit(sql: string, cursor: number, open = false) {
    this.active ||= open;
    this.changed({ result: null, busy: this.running, error: "" });
    clearTimeout(this.timer);
    if (this.generation === 4294967295) {
      this.close();
      throw new QueryError(0, "EditorGenerationExhausted");
    }
    this.input = { sql, cursor: byteCursor(sql, cursor), generation: ++this.generation };
    if (this.active && !this.running) this.schedule(200);
  }
  close() {
    this.active = false;
    this.input = null;
    clearTimeout(this.timer);
    this.controller?.abort();
    this.changed({ result: null, busy: false, error: "" });
  }
  dispose() {
    this.close();
    this.changed = () => {};
  }
  private schedule(ms: number) {
    this.timer = setTimeout(() => void this.read(), ms);
  }
  private async read() {
    if (!this.active || this.running || !this.input) return;
    const captured = this.input;
    const controller = new AbortController();
    this.controller = controller;
    this.running = true;
    this.changed({ result: null, busy: true, error: "" });
    try {
      const value = await this.query({ assist: { ...captured, mode: "sql" } }, controller.signal);
      if (!this.active || controller.signal.aborted || this.input !== captured) return;
      if (
        !validateUnifiedQuery(value) ||
        !("assistance" in value) ||
        value.assistance.resource !== this.resource ||
        value.assistance.generation !== captured.generation
      )
        throw new QueryError(0, "InvalidResponse");
      const response = value.assistance;
      if (this.contract !== null && this.contract !== JSON.stringify(response.contract))
        throw new QueryError(409, "DraftSourceChanged");
      this.contract = JSON.stringify(response.contract);
      if (
        response.range &&
        (response.range.end > encoder.encode(captured.sql).length ||
          response.range.start > captured.cursor ||
          response.range.end < captured.cursor)
      )
        throw new QueryError(0, "InvalidResponse");
      if (response.range) {
        const bytes = encoder.encode(captured.sql);
        decoder.decode(bytes.subarray(0, response.range.start));
        decoder.decode(bytes.subarray(response.range.end));
      }
      this.changed({ result: { input: captured, response }, busy: false, error: "" });
    } catch (error) {
      if (controller.signal.aborted || !this.active) return;
      this.active = false;
      this.input = null;
      this.changed({
        result: null,
        busy: false,
        error: error instanceof Error ? error.message : "Assistance unavailable",
      });
      if (
        typeof error === "object" &&
        error !== null &&
        "status" in error &&
        (error.status === 403 || error.status === 410)
      )
        this.denied();
    } finally {
      this.running = false;
      this.controller = null;
      if (this.active && this.input) this.schedule(this.input === captured ? 5000 : 200);
    }
  }
}
