import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { access, mkdtemp, rm, writeFile } from "node:fs/promises";
import { constants } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Ajv, type AnySchema, type ValidateFunction } from "ajv";
import {
  Busy,
  Closed,
  IncompatibleNative,
  ReadFailed,
  UnknownOutcome,
  TransitError,
  nativeError,
} from "./errors.ts";
import contract from "./contract.json" with { type: "json" };

export const maximumLine = contract.limits.host_line_bytes;
const utf8 = new TextDecoder("utf-8", { fatal: true });
export function validators(schemas: Record<string, unknown>): Record<string, ValidateFunction> {
  const ajv = new Ajv({ strict: true });
  return Object.fromEntries(
    Object.entries(schemas).map(([name, schema]) => [name, ajv.compile(schema as AnySchema)]),
  );
}
interface Pending {
  readonly resolve: (value: unknown) => void;
  readonly reject: (error: TransitError) => void;
  readonly complete: () => void;
  readonly done: Promise<void>;
  readonly timer: ReturnType<typeof setTimeout>;
  readonly phase: string;
  readonly mutation: boolean;
  readonly validator?: ValidateFunction;
}

/** Internal package interface. No caller protocol or Station semantics live here. */
export class Port {
  readonly #child: ChildProcessWithoutNullStreams;
  readonly #directory: string;
  readonly #requestValidator: ValidateFunction;
  readonly #exit: Promise<void>;
  #pending: Pending | undefined;
  #incoming = Buffer.alloc(0);
  #closed = false;
  #closing: Promise<void> | undefined;
  private constructor(
    executable: string,
    file: string,
    directory: string,
    validate: ValidateFunction,
  ) {
    this.#directory = directory;
    this.#requestValidator = validate;
    this.#child = spawn(executable, [file], { stdio: ["pipe", "pipe", "pipe"] });
    // Drain without retaining or backpressuring control on the caller's stderr.
    this.#child.stderr.on("data", () => {});
    this.#exit = new Promise((resolve) => {
      this.#child.once("close", () => {
        this.#fail("Native host closed");
        resolve();
      });
    });
    this.#child.on("error", () => this.#fail("Native host unavailable"));
    this.#child.stdin.on("error", () => this.#fail("Native input closed"));
    this.#child.stdout.on("data", (chunk: Buffer) => this.#receive(chunk));
  }
  static async open(
    executable: string,
    configuration: object,
    validate: ValidateFunction,
  ): Promise<Port> {
    try {
      await access(executable, constants.X_OK);
    } catch {
      throw new IncompatibleNative(
        "Missing executable native artifact; install its matching package or supply nativeHost",
      );
    }
    const document = JSON.stringify(configuration);
    if (Buffer.byteLength(document) > contract.limits.host_config_bytes)
      throw new TypeError("Native configuration exceeds its bound");
    const directory = await mkdtemp(join(tmpdir(), "transit-node-"));
    try {
      const file = join(directory, "host.json");
      await writeFile(file, document, { mode: 0o600 });
      return new Port(executable, file, directory, validate);
    } catch (error) {
      await rm(directory, { recursive: true, force: true });
      throw error;
    }
  }
  #fail(message: string, status = 7): void {
    const pending = this.#pending;
    this.#closed = true;
    this.#pending = undefined;
    this.#incoming = Buffer.alloc(0);
    if (pending) {
      clearTimeout(pending.timer);
      const options = { status: pending.mutation ? 6 : status, phase: pending.phase };
      pending.reject(
        pending.mutation ? new UnknownOutcome(message, options) : new ReadFailed(message, options),
      );
      pending.complete();
    }
    this.#child.kill("SIGTERM");
  }
  #receive(chunk: Buffer): void {
    if (this.#incoming.length + chunk.length > maximumLine) {
      this.#fail("Native response exceeds the port bound", 8);
      return;
    }
    this.#incoming = Buffer.concat([this.#incoming, chunk]);
    const end = this.#incoming.indexOf(10);
    if (end < 0) return;
    const pending = this.#pending;
    if (!pending || end !== this.#incoming.length - 1) {
      this.#fail("Unsolicited native response", 8);
      return;
    }
    let status: number, value: unknown;
    try {
      const result: unknown = JSON.parse(utf8.decode(this.#incoming.subarray(0, end)));
      if (
        result === null ||
        typeof result !== "object" ||
        Array.isArray(result) ||
        Object.keys(result).sort().join(",") !== "status,value" ||
        !("status" in result) ||
        !("value" in result) ||
        typeof result.status !== "number" ||
        !Number.isInteger(result.status) ||
        result.status < 0 ||
        result.status > 14
      )
        throw new TypeError();
      status = result.status;
      value = result.value;
      if (status === 0 && pending.validator && !pending.validator(value)) throw new TypeError();
    } catch {
      this.#fail("Invalid native response", 8);
      return;
    }
    this.#incoming = Buffer.alloc(0);
    this.#pending = undefined;
    clearTimeout(pending.timer);
    if (status === 0) pending.resolve(value);
    else pending.reject(nativeError(status, value, pending.phase));
    pending.complete();
  }
  request(
    input: object,
    options: { phase: string; mutation?: boolean; validator?: ValidateFunction },
  ): Promise<unknown> {
    if (this.#closed || this.#closing) return Promise.reject(new Closed("Native host is closed"));
    if (this.#pending) return Promise.reject(new Busy("One native request per host"));
    if (!this.#requestValidator(input))
      return Promise.reject(new TypeError("Invalid native request"));
    const line = JSON.stringify(input) + "\n";
    if (Buffer.byteLength(line) > maximumLine)
      return Promise.reject(new TypeError("Native request exceeds the port bound"));
    return new Promise((resolve, reject) => {
      let complete!: () => void;
      const done = new Promise<void>((finished) => {
        complete = finished;
      });
      const timer = setTimeout(() => this.#fail("Native request deadline elapsed"), 65000);
      this.#pending = {
        resolve,
        reject,
        complete,
        done,
        timer,
        phase: options.phase,
        mutation: options.mutation ?? false,
        validator: options.validator,
      };
      this.#child.stdin.write(line);
    });
  }
  close(): Promise<void> {
    if (this.#closing) return this.#closing;
    this.#closing = (async () => {
      await this.#pending?.done;
      this.#closed = true;
      this.#child.stdin.end();
      const timer = setTimeout(() => this.#child.kill("SIGKILL"), 2000);
      try {
        await this.#exit;
      } finally {
        clearTimeout(timer);
        await rm(this.#directory, { recursive: true, force: true });
      }
    })();
    return this.#closing;
  }
}
