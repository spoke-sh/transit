import {
  AdmissionReceipt,
  Credential,
  ProcessRef,
  ResourceRef,
  IncompatibleNative,
  UnknownOutcome,
} from "@transit/client";
import type { ClientConfig } from "@transit/client";
import { configuration, integer, owned, text } from "@transit/client/internal";
import { MutationBridge } from "./bridge.ts";
import { hex, unhex } from "./framing.ts";
import { wide, nativeWide } from "./values.ts";
import type { Diagnostic } from "./unified.ts";
import type { CellType } from "./table.ts";

/** An explicit target; read-query access does not enable mutation. */
export class Connection {
  readonly writer: ProcessRef;
  readonly resource: ResourceRef;
  readonly table: number;
  constructor(writer: ProcessRef, resource: ResourceRef, table: number) {
    if (
      !(writer instanceof ProcessRef) ||
      !(resource instanceof ResourceRef) ||
      writer.realm !== resource.realm
    )
      throw new TypeError("Mutation connection requires one realm");
    this.writer = writer;
    this.resource = resource;
    this.table = integer(table, "table", 1, 0xffffffff);
    Object.freeze(this);
  }
}

/** Complete immutable publication commitment, never an authorization token. */
export class Reference {
  readonly #data: Uint8Array;
  constructor(data: Uint8Array) {
    this.#data = owned(data, 72);
    if (this.#data.length !== 72) throw new TypeError("Mutation reference requires 72 bytes");
    Object.freeze(this);
  }
  get data(): Uint8Array {
    return new Uint8Array(this.#data);
  }
}

/** Persist both fields unchanged before preparing upload commands. */
export class Compiled {
  readonly #request: Uint8Array;
  readonly reference: Reference;
  constructor(request: Uint8Array, reference: Reference) {
    this.#request = owned(request, 799);
    if (!this.#request.length || !(reference instanceof Reference))
      throw new TypeError("Invalid compiled mutation");
    this.reference = reference;
    Object.freeze(this);
  }
  get request(): Uint8Array {
    return new Uint8Array(this.#request);
  }
}

/** Exact opaque recovery text; do not parse or re-encode after uncertainty. */
export class Prepared {
  readonly #data: string;
  constructor(data: string) {
    this.#data = text(data, 8192);
    if (!this.#data.length || Buffer.from(this.#data).toString("utf8") !== this.#data)
      throw new TypeError("Invalid saved mutation text");
    Object.freeze(this);
  }
  get data(): string {
    return this.#data;
  }
}
export class Uncertain extends UnknownOutcome {
  readonly prepared: Prepared;
  constructor(prepared: Prepared, cause: UnknownOutcome) {
    super("Mutation admission is uncertain; retain the identical prepared command", {
      status: 6,
      ...(cause.code === undefined ? {} : { code: cause.code }),
      ...(cause.diagnostic === undefined ? {} : { diagnostic: cause.diagnostic }),
      diagnosticInvalid: cause.diagnosticInvalid,
      phase: "submit-mutation",
    });
    this.prepared = prepared;
  }
}
export const Permissions = Object.freeze({ INSERT: 1, UPDATE: 2, DELETE: 4 });
export type Phase = "uploading" | "sealed" | "applied" | "rejected" | "cancelled";
export type Reason =
  | "none"
  | "row_exists"
  | "source_changed"
  | "invalid_request"
  | "denied"
  | "budget";
export type Observation = "pending" | "processed";
export type Rejection =
  | "invalid_command"
  | "denied"
  | "identity_conflict"
  | "busy"
  | "not_found"
  | "not_active"
  | "upload_closed"
  | "not_sealed"
  | "invalid_part"
  | "incomplete_upload"
  | "source_changed"
  | "stale_policy";
export interface Description {
  readonly resource: ResourceRef;
  readonly table: number;
  readonly names: readonly [string, string];
  readonly valueType: CellType;
  readonly resourceRevision: number;
  readonly policyRevision: bigint;
  readonly declaration: Uint8Array;
  readonly permissions: number;
  readonly active: bigint | undefined;
}
export interface Conflict {
  readonly key: bigint;
  /** One-based input row in the rejected INSERT. */
  readonly row: number;
}
export interface Disposition {
  readonly principal: number;
  readonly input: number;
  readonly payload: Uint8Array;
  readonly reason: Rejection;
  readonly diagnostic: Diagnostic;
}
export interface Status {
  readonly reference: Reference;
  readonly principal: number;
  readonly table: number;
  readonly declaration: Uint8Array;
  readonly policyRevision: bigint;
  readonly phase: Phase;
  readonly affectedRows: number;
  readonly conflict: Conflict | undefined;
  readonly reason: Reason;
  readonly input: number;
  readonly diagnostic: Diagnostic;
}
function positive(value: bigint): string {
  const checked = wide(value);
  if (checked === 0n) throw new TypeError("Namespace must be positive");
  return checked.toString();
}
function reference(value: Reference): string {
  if (!(value instanceof Reference)) throw new TypeError("Expected mutation reference");
  return hex(value.data, 72);
}
function saved(value: Prepared): string {
  if (!(value instanceof Prepared)) throw new TypeError("Expected saved mutation command");
  return value.data;
}
function digest(value: string): Uint8Array {
  const data = unhex(value, 32);
  if (data.length !== 32) throw new IncompatibleNative("Invalid mutation declaration digest");
  return data;
}
function revision(value: string): bigint {
  const parsed = nativeWide(value);
  integer(Number(parsed), "policy revision");
  return parsed;
}
/** One native port and one active operation; no implicit retry or upload loop. */
export class Client {
  readonly connection: Connection;
  readonly #bridge: MutationBridge;
  private constructor(connection: Connection, bridge: MutationBridge) {
    this.connection = connection;
    this.#bridge = bridge;
    Object.freeze(this);
  }
  static async open(
    input: ClientConfig,
    credential: Credential,
    connection: Connection,
  ): Promise<Client> {
    const config = configuration(input);
    if (
      !(credential instanceof Credential) ||
      !(connection instanceof Connection) ||
      credential.realm !== connection.writer.realm
    )
      throw new TypeError("Mutation credential must match the connection realm");
    integer(credential.principal, "principal");
    const bridge = await MutationBridge.open(
      config.url,
      credential.seedFile,
      {
        connection: {
          realm: credential.realm,
          principal: credential.principal,
          writer: connection.writer.pid,
          resource: connection.resource.resource,
          table: connection.table,
        },
        timeout_ms: config.timeoutMs,
      },
      config.nativeHost,
    );
    return new Client(connection, bridge);
  }
  async describe(): Promise<Description> {
    const result = await this.#bridge.call({ describe: {} });
    if (!("description" in result)) throw new IncompatibleNative("Expected mutation description");
    const v = result.description;
    if (
      v.resource !== this.connection.resource.resource ||
      v.table !== this.connection.table ||
      v.names.length !== 2 ||
      v.names[0] === undefined ||
      v.names[1] === undefined ||
      !(
        v.value_type === "int64" ||
        v.value_type === "boolean" ||
        v.value_type === "utf8" ||
        v.value_type === "binary"
      )
    )
      throw new IncompatibleNative("Invalid mutation Table description");
    return Object.freeze({
      resource: this.connection.resource,
      table: v.table,
      names: Object.freeze([text(v.names[0], 16), text(v.names[1], 16)] as const),
      valueType: v.value_type,
      resourceRevision: integer(v.resource_revision, "revision", 0),
      policyRevision: revision(v.policy_revision),
      declaration: digest(v.declaration),
      permissions: integer(v.permissions, "permissions", 0, 7),
      active: v.active === null ? undefined : nativeWide(v.active),
    });
  }
  async compileSql(name: string, sql: string, namespace: bigint): Promise<Compiled> {
    const value = await this.#bridge.call({
      compile: { name: text(name, 16), sql: text(sql, 4096), namespace: positive(namespace) },
    });
    if (!("compiled" in value)) throw new IncompatibleNative("Expected compiled mutation");
    return new Compiled(
      unhex(value.compiled.request, 799),
      new Reference(unhex(value.compiled.reference, 72)),
    );
  }
  async prepareNext(compiled: Compiled): Promise<Prepared | undefined> {
    if (!(compiled instanceof Compiled)) throw new TypeError("Expected compiled mutation");
    const result = await this.#bridge.call({
      next: { request: hex(compiled.request, 799), reference: reference(compiled.reference) },
    });
    if (!("prepared" in result)) throw new IncompatibleNative("Expected prepared mutation command");
    return result.prepared === null ? undefined : new Prepared(result.prepared);
  }
  private async control(kind: "apply" | "cancel", ref: Reference): Promise<Prepared> {
    const id = reference(ref);
    const value = await this.#bridge.call({
      prepare: kind === "apply" ? { apply: id } : { cancel: id },
    });
    if (!("prepared" in value) || value.prepared === null)
      throw new IncompatibleNative("Missing prepared mutation control");
    return new Prepared(value.prepared);
  }
  prepareApply(ref: Reference): Promise<Prepared> {
    return this.control("apply", ref);
  }
  prepareCancel(ref: Reference): Promise<Prepared> {
    return this.control("cancel", ref);
  }
  async submit(prepared: Prepared): Promise<AdmissionReceipt> {
    const token = saved(prepared);
    try {
      const value = await this.#bridge.call({ submit: token });
      if (!("receipt" in value) || value.receipt.position < 1)
        throw new UnknownOutcome("Missing mutation admission receipt");
      return new AdmissionReceipt(value.receipt.position);
    } catch (error) {
      if (error instanceof UnknownOutcome) throw new Uncertain(prepared, error);
      throw error;
    }
  }
  async observe(prepared: Prepared, position: number): Promise<Observation> {
    const value = await this.#bridge.call({
      observe: { prepared: saved(prepared), input: integer(position, "input") },
    });
    if (!("observation" in value)) throw new IncompatibleNative("Expected input observation");
    return value.observation;
  }
  async rejection(prepared: Prepared, position: number): Promise<Disposition | undefined> {
    const value = await this.#bridge.call({
      rejection: { prepared: saved(prepared), input: integer(position, "input") },
    });
    if (!("rejection" in value))
      throw new IncompatibleNative("Expected input rejection observation");
    const v = value.rejection;
    if (v === null) return undefined;
    return Object.freeze({
      principal: integer(v.principal, "principal", 0),
      input: integer(v.input, "input"),
      payload: digest(v.payload),
      reason: v.reason,
      diagnostic: v.diagnostic,
    });
  }
  async status(ref: Reference): Promise<Status | undefined> {
    const value = await this.#bridge.call({ status: reference(ref) });
    if (!("status" in value)) throw new IncompatibleNative("Expected durable mutation status");
    const v = value.status;
    if (v === null) return undefined;
    if (v.reference !== reference(ref) || v.table !== this.connection.table)
      throw new IncompatibleNative("Status does not match the mutation reference");
    return Object.freeze({
      reference: new Reference(unhex(v.reference, 72)),
      principal: integer(v.principal, "principal"),
      table: v.table,
      declaration: digest(v.declaration),
      policyRevision: revision(v.policy_revision),
      phase: v.phase,
      affectedRows: integer(v.affected_rows, "affected rows", 0, 3),
      conflict:
        v.conflict === null
          ? undefined
          : Object.freeze({
              key: nativeWide(v.conflict.key, true),
              row: integer(v.conflict.row, "conflict row", 1, 3),
            }),
      reason: v.reason,
      input: integer(v.input, "input", 0),
      diagnostic: v.diagnostic,
    });
  }
  close(): Promise<void> {
    return this.#bridge.close();
  }
}
