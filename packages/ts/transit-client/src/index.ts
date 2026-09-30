import { Port, maximumLine } from "./port.ts";
import { inspect } from "node:util";
import { Serial } from "./serial.ts";
import {
  IncompatibleNative,
  UnsupportedCapability,
  AuthorityRejected,
  UnknownOutcome,
  TransitError,
} from "./errors.ts";
import {
  AdmissionReceipt,
  MutationReceipt,
  Credential,
  ProcessRef,
  configuration,
  integer,
  limits,
  owned,
  record,
  type ClientConfig,
} from "./values.ts";
import {
  PendingSend,
  PendingMutation,
  validation,
  prepare,
  frozenText,
  recoverSend,
  recoverMutation,
  authorityCapabilities,
  type Capabilities,
} from "./operations.ts";
export * from "./errors.ts";
export {
  AdmissionReceipt,
  MutationReceipt,
  Credential,
  ProcessRef,
  ResourceRef,
  OperationIdentity,
  limits,
  type ClientConfig,
} from "./values.ts";
export {
  PendingSend,
  PendingMutation,
  type SendInfo,
  type MutationInfo,
  type Capabilities,
} from "./operations.ts";

export type Rejected = { readonly kind: "rejected"; readonly error: AuthorityRejected };
export class Uncertain {
  readonly kind = "uncertain";
  readonly error: UnknownOutcome;
  readonly #recovery: Uint8Array;
  constructor(bytes: Uint8Array, error?: unknown) {
    this.#recovery = owned(bytes, limits.max_body);
    this.error =
      error instanceof UnknownOutcome
        ? error
        : new UnknownOutcome("Mutation outcome is unknown; retain exact recovery material", {
            status: 6,
            phase: "dispatch",
          });
    Object.freeze(this);
  }
  get recovery(): Uint8Array {
    return new Uint8Array(this.#recovery);
  }
  [inspect.custom](): object {
    return { kind: this.kind, status: this.error.status, code: this.error.code };
  }
}
export type DispatchResult =
  | { readonly kind: "admitted"; readonly receipt: AdmissionReceipt }
  | Rejected
  | Uncertain;
export type MutationResult =
  | { readonly kind: "confirmed"; readonly receipt: MutationReceipt }
  | Rejected
  | Uncertain;

function uncertain(bytes: Uint8Array, error?: unknown): Uncertain {
  return new Uncertain(bytes, error);
}
function localWait<T>(
  work: Promise<T>,
  bytes: Uint8Array,
  signal?: AbortSignal,
): Promise<T | Uncertain> {
  if (!signal) return work;
  return new Promise((resolve, reject) => {
    const abort = () => resolve(uncertain(bytes));
    signal.addEventListener("abort", abort, { once: true });
    work.then(resolve, reject).finally(() => signal.removeEventListener("abort", abort));
    if (signal.aborted) abort();
  });
}

/** Typed raw Transit; native signing/recovery remain independent of Station. */
export class Client {
  readonly #port: Port;
  readonly #serial = new Serial();
  #lastReceipt: AdmissionReceipt | undefined;
  #lastMutationReceipt: MutationReceipt | undefined;
  private constructor(port: Port) {
    this.#port = port;
  }
  static async open(input: ClientConfig): Promise<Client> {
    const config = configuration(input);
    let executable = config.nativeHost;
    if (!executable) {
      try {
        const native = await import("@transit/native-client");
        if (native.version !== "0.2.0") throw new Error();
        executable = native.hostPath;
      } catch {
        throw new IncompatibleNative(
          "Install the version-matched @transit/native-client artifact or supply nativeHost",
        );
      }
    }
    const requestValidator = validation.ClientHostRequest;
    if (!requestValidator) throw new IncompatibleNative("Missing generated client request schema");
    const port = await Port.open(
      executable,
      { url: config.url, timeout_ms: config.timeoutMs },
      requestValidator,
    );
    try {
      const hello = record(await port.request({ hello: {} }, { phase: "hello" }));
      if (
        Object.keys(hello).sort().join(",") !== "host_version,transit_version" ||
        hello.host_version !== 1 ||
        hello.transit_version !== 1
      ) {
        throw new IncompatibleNative("Native client protocol version mismatch");
      }
      const caps = record(
        await port.request(
          { capabilities: {} },
          { phase: "native-capabilities", validator: validation.ClientCapabilities },
        ),
      );
      if (
        caps.version !== 1 ||
        !caps.operation_metadata ||
        !caps.opaque_retry ||
        !caps.native_v1 ||
        caps.max_line_bytes !== maximumLine ||
        caps.value_bytes !== limits.value_bytes ||
        caps.max_counter !== limits.max_counter
      ) {
        throw new UnsupportedCapability(
          "Native client lacks required operation/profile capabilities",
        );
      }
      return new Client(port);
    } catch (error) {
      await port.close();
      throw error;
    }
  }
  capabilities(credential: Credential): Promise<Capabilities> {
    if (!(credential instanceof Credential)) throw new TypeError("Expected Credential");
    return this.#serial.run(() => authorityCapabilities(this.#port, credential));
  }
  prepareSend(
    peer: ProcessRef,
    data: Uint8Array,
    options: { credential: Credential; sequence: number },
  ): Promise<PendingSend> {
    if (!(peer instanceof ProcessRef) || !(options.credential instanceof Credential))
      throw new TypeError("Expected ProcessRef and Credential");
    const payload = owned(data, limits.value_bytes);
    const next = integer(options.sequence, "sequence");
    const credential = options.credential;
    if (peer.realm !== credential.realm)
      throw new TypeError("Destination and credential must share a realm");
    return this.#serial.run(async () => {
      const frozen = await prepare(this.#port, 6, credential, {
        realm: credential.realm,
        principal: credential.principal,
        sequence: next,
        command: { send: { pid: peer.pid, value: Buffer.from(payload).toString("hex") } },
      });
      return recoverSend(this.#port, frozen);
    });
  }
  recoverSend(bytes: Uint8Array): Promise<PendingSend> {
    const frozen = owned(bytes, limits.max_body);
    return this.#serial.run(() => recoverSend(this.#port, frozen));
  }
  recoverMutation(bytes: Uint8Array): Promise<PendingMutation> {
    const frozen = owned(bytes, limits.max_body);
    return this.#serial.run(() => recoverMutation(this.#port, frozen));
  }
  dispatch(pending: PendingSend, options: { signal?: AbortSignal } = {}): Promise<DispatchResult> {
    if (!(pending instanceof PendingSend)) throw new TypeError("Expected PendingSend");
    options.signal?.throwIfAborted();
    const frozen = pending.export();
    const work = this.#serial.run(async (): Promise<DispatchResult> => {
      await recoverSend(this.#port, frozen); // Revalidate canonical kind before any dispatch.
      options.signal?.throwIfAborted();
      this.#lastReceipt = undefined;
      try {
        const value = record(
          await this.#port.request(
            { call: frozenText(frozen) },
            { phase: "dispatch", mutation: true },
          ),
        );
        const receipt = new AdmissionReceipt(integer(value.position, "receipt position"));
        this.#lastReceipt = receipt;
        return Object.freeze({ kind: "admitted", receipt });
      } catch (error) {
        if (error instanceof AuthorityRejected) return Object.freeze({ kind: "rejected", error });
        if (error instanceof TransitError && error.status !== 6) throw error;
        return uncertain(frozen, error);
      }
    });
    return localWait(work, frozen, options.signal);
  }
  dispatchMutation(
    pending: PendingMutation,
    options: { signal?: AbortSignal } = {},
  ): Promise<MutationResult> {
    if (!(pending instanceof PendingMutation)) throw new TypeError("Expected PendingMutation");
    options.signal?.throwIfAborted();
    const frozen = pending.export();
    const work = this.#serial.run(async (): Promise<MutationResult> => {
      await recoverMutation(this.#port, frozen);
      options.signal?.throwIfAborted();
      this.#lastMutationReceipt = undefined;
      try {
        const value = record(
          await this.#port.request(
            { call: frozenText(frozen) },
            { phase: "dispatch", mutation: true },
          ),
        );
        const receipt = new MutationReceipt(integer(value.position, "receipt position"));
        this.#lastMutationReceipt = receipt;
        return Object.freeze({ kind: "confirmed", receipt });
      } catch (error) {
        if (error instanceof AuthorityRejected) return Object.freeze({ kind: "rejected", error });
        if (error instanceof TransitError && error.status !== 6) throw error;
        return uncertain(frozen, error);
      }
    });
    return localWait(work, frozen, options.signal);
  }
  get lastReceipt(): AdmissionReceipt | undefined {
    return this.#lastReceipt;
  }
  get lastMutationReceipt(): MutationReceipt | undefined {
    return this.#lastMutationReceipt;
  }
  close(): Promise<void> {
    return this.#serial.close(() => this.#port.close());
  }
  [Symbol.asyncDispose](): Promise<void> {
    return this.close();
  }
}
