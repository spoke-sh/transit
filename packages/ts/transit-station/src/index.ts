import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { Ajv, type ValidateFunction } from "ajv";
import schemas from "./schemas.json" with { type: "json" };
import type { Action, Result, Event, ArrowCell, HostRequest } from "./types.ts";
export type * from "./types.ts";

const maximum = 256 * 1024 * 2 + 16384;
const ajv = new Ajv({ strict: true });
const validators: Record<string, ValidateFunction> = Object.fromEntries(
  Object.entries(schemas).map(([name, schema]) => [name, ajv.compile(schema)]),
);
const utf8 = new TextDecoder("utf-8", { fatal: true });
export class TransitError extends Error {
  readonly status: number;
  readonly detail: unknown;
  constructor(status: number, detail: unknown) {
    super(`Transit status ${status}`);
    this.status = status;
    this.detail = detail;
  }
}
type Pending = {
  resolve: (value: unknown) => void;
  reject: (error: Error) => void;
  cleanup: () => void;
  schema?: string;
  uncertain: boolean;
};

/** One owned native child, one request in flight, no implicit retries or queue. */
export class NativeHost {
  private readonly child: ChildProcessWithoutNullStreams;
  private pending?: Pending;
  private incoming = Buffer.alloc(0);
  private closed = false;
  private readonly exited: Promise<void>;
  private constructor(executable: string, config: string) {
    this.child = spawn(executable, [config], { stdio: ["pipe", "pipe", "pipe"] });
    // Drain diagnostics without retaining them or contaminating protocol stdout.
    this.child.stderr.pipe(process.stderr, { end: false });
    this.exited = new Promise((resolve) => {
      this.child.once("close", () => {
        this.fail(new TransitError(this.pending?.uncertain ? 6 : 7, "Native host closed"));
        resolve();
      });
    });
    this.child.on("error", () => this.fail(new TransitError(7, "Native host unavailable")));
    this.child.stdin.on("error", () =>
      this.fail(new TransitError(this.pending?.uncertain ? 6 : 7, "Native input closed")),
    );
    this.child.stdout.on("data", (chunk: Buffer) => this.receive(chunk));
  }
  static async open(executable: string, config: string): Promise<NativeHost> {
    const host = new NativeHost(executable, config);
    try {
      const hello = await host.request({ hello: {} });
      if (
        !hello ||
        typeof hello !== "object" ||
        Object.keys(hello).length !== 3 ||
        !("host_version" in hello) ||
        hello.host_version !== 1 ||
        !("station_version" in hello) ||
        hello.station_version !== 1 ||
        !("transit_version" in hello) ||
        hello.transit_version !== 1
      ) {
        throw new TransitError(10, "Native protocol version mismatch");
      }
      return host;
    } catch (error) {
      await host.close();
      throw error;
    }
  }
  private fail(error: Error): void {
    this.closed = true;
    const pending = this.pending;
    if (
      pending?.uncertain &&
      error instanceof TransitError &&
      (error.status === 7 || error.status === 8)
    ) {
      error = new TransitError(6, error.detail);
    }
    this.pending = undefined;
    pending?.cleanup();
    pending?.reject(error);
    this.child.kill("SIGTERM");
  }
  private receive(chunk: Buffer): void {
    if (this.incoming.length + chunk.length > maximum) {
      this.fail(new TransitError(8, "Oversized native response"));
      return;
    }
    this.incoming = Buffer.concat([this.incoming, chunk]);
    const end = this.incoming.indexOf(10);
    if (end < 0) return;
    const pending = this.pending;
    if (!pending || end !== this.incoming.length - 1) {
      this.fail(new TransitError(8, "Unsolicited native response"));
      return;
    }
    try {
      const response: unknown = JSON.parse(utf8.decode(this.incoming.subarray(0, end)));
      if (
        !response ||
        typeof response !== "object" ||
        Array.isArray(response) ||
        Object.keys(response).sort().join(",") !== "status,value" ||
        !("status" in response) ||
        !("value" in response) ||
        !Number.isInteger(response.status) ||
        (response.status as number) < 0 ||
        (response.status as number) > 14
      ) {
        throw new TransitError(8, "Malformed native envelope");
      }
      if (
        response.status === 0 &&
        pending.schema &&
        !validators[pending.schema]?.(response.value)
      ) {
        throw new TransitError(8, "Invalid native response schema");
      }
      this.incoming = Buffer.alloc(0);
      this.pending = undefined;
      pending.cleanup();
      if (response.status !== 0)
        pending.reject(new TransitError(response.status as number, response.value));
      else pending.resolve(response.value);
    } catch {
      this.fail(new TransitError(8, "Malformed native response"));
    }
  }
  request(input: HostRequest, schema?: string, signal?: AbortSignal): Promise<unknown> {
    if (this.closed) return Promise.reject(new TransitError(7, "Native host closed"));
    if (this.pending) return Promise.reject(new TransitError(9, "One operation per native host"));
    if (signal?.aborted) return Promise.reject(signal.reason);
    if (!validators.HostRequest?.(input))
      return Promise.reject(new TransitError(1, "Invalid host request"));
    const line = JSON.stringify(input) + "\n";
    if (Buffer.byteLength(line) > maximum)
      return Promise.reject(new TransitError(1, "Oversized host request"));
    return new Promise((resolve, reject) => {
      const uncertain = "next" in input || "call" in input;
      const abort = () =>
        this.fail(
          new TransitError(uncertain ? 6 : 7, "Local wait abandoned; native host terminated"),
        );
      const timer = setTimeout(abort, 65000);
      const cleanup = () => {
        clearTimeout(timer);
        signal?.removeEventListener("abort", abort);
      };
      this.pending = { resolve, reject, cleanup, schema, uncertain };
      signal?.addEventListener("abort", abort, { once: true });
      this.child.stdin.write(line);
    });
  }
  async next(deadline = Date.now() + 30000, signal?: AbortSignal): Promise<Event> {
    return (await this.request({ next: deadline }, "Event", signal)) as Event;
  }
  async apply(action: Action): Promise<Result> {
    return (await this.request({ apply: action }, "Result")) as Result;
  }
  async finish(failed = false): Promise<void> {
    await this.request({ finish: failed });
  }
  async pendingRequest(): Promise<string> {
    const value = await this.request({ pending: {} });
    if (typeof value !== "string") throw new TransitError(8, "Invalid frozen request");
    return value;
  }
  async arrowCell(ipc: Uint8Array, row: number, column: number): Promise<ArrowCell> {
    return (await this.request(
      { arrow_cell: { ipc: Buffer.from(ipc).toString("hex"), row, column } },
      "ArrowCell",
    )) as ArrowCell;
  }
  async prepare(kind: number, seedFile: string, document: unknown): Promise<string> {
    const json = JSON.stringify(document);
    if (json === undefined) throw new TransitError(1, "Missing request document");
    const value = await this.request({ prepare: { kind, seed_file: seedFile, document: json } });
    if (typeof value !== "string") throw new TransitError(8, "Invalid frozen request");
    return value;
  }
  async call(frozen: string, signal?: AbortSignal): Promise<unknown> {
    return this.request({ call: frozen }, undefined, signal);
  }
  async close(): Promise<void> {
    this.closed = true;
    this.child.stdin.end();
    const timer = setTimeout(() => this.child.kill("SIGKILL"), 2000);
    try {
      await this.exited;
    } finally {
      clearTimeout(timer);
    }
  }
}
