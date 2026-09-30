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
import { CatalogBridge } from "./bridge.ts";
import { unhex } from "./framing.ts";
import { wide, nativeWide } from "./values.ts";
import type { CellType } from "./table.ts";
import type { CatalogAction, CatalogResult } from "./wire.ts";

type NativeRequest = Extract<CatalogAction, { prepare_create: unknown }>["prepare_create"];
type NativeScope = NativeRequest["scope"];
type NativeConfiguration = Extract<
  CatalogAction,
  { prepare_initialize: unknown }
>["prepare_initialize"];
type NativePolicy = Extract<CatalogAction, { prepare_policy: unknown }>["prepare_policy"]["policy"];
type Tags<T> = T extends unknown ? keyof T : never;
function field<K extends Tags<CatalogResult>>(
  value: CatalogResult,
  key: K,
): Extract<CatalogResult, Record<K, unknown>>[K] {
  if (!(key in value)) throw new IncompatibleNative("Unexpected catalog action result");
  return (value as Extract<CatalogResult, Record<K, unknown>>)[key];
}
function positive(value: bigint): bigint {
  const result = wide(value);
  if (result === 0n) throw new TypeError("Catalog identity must be positive");
  return result;
}
function decoded<T>(decode: () => T): T {
  try {
    return decode();
  } catch {
    throw new IncompatibleNative("Invalid native catalog value");
  }
}

export class Scope {
  readonly resource: ResourceRef;
  readonly catalog: bigint;
  constructor(resource: ResourceRef, catalog: bigint) {
    if (!(resource instanceof ResourceRef)) throw new TypeError("Expected resource reference");
    this.resource = resource;
    this.catalog = positive(catalog);
    Object.freeze(this);
  }
}
export class Connection {
  readonly owner: ProcessRef;
  readonly scope: Scope;
  constructor(owner: ProcessRef, scope: Scope) {
    if (
      !(owner instanceof ProcessRef) ||
      !(scope instanceof Scope) ||
      owner.realm !== scope.resource.realm
    )
      throw new TypeError("Catalog connection requires one realm");
    this.owner = owner;
    this.scope = scope;
    Object.freeze(this);
  }
}
export class Configuration {
  readonly scope: Scope;
  readonly owner: ProcessRef;
  readonly administrator: number;
  constructor(scope: Scope, owner: ProcessRef, administrator: number) {
    new Connection(owner, scope);
    this.scope = scope;
    this.owner = owner;
    this.administrator = integer(administrator, "administrator");
    Object.freeze(this);
  }
}
export class Schema {
  readonly names: readonly [string, string];
  readonly valueType: CellType;
  constructor(names: readonly [string, string], valueType: CellType) {
    if (
      !Array.isArray(names) ||
      names.length !== 2 ||
      !["int64", "boolean", "utf8", "binary"].includes(valueType)
    )
      throw new TypeError("Expected two-column Table schema");
    this.names = Object.freeze([text(names[0], 16), text(names[1], 16)] as const);
    this.valueType = valueType;
    Object.freeze(this);
  }
}
export class CreateTable {
  readonly scope: Scope;
  readonly operation: bigint;
  readonly objectId: bigint;
  readonly table: number;
  readonly name: string;
  readonly schema: Schema;
  constructor(
    scope: Scope,
    operation: bigint,
    objectId: bigint,
    table: number,
    name: string,
    schema: Schema,
  ) {
    if (!(scope instanceof Scope) || !(schema instanceof Schema))
      throw new TypeError("Expected catalog scope and schema");
    this.scope = scope;
    this.operation = positive(operation);
    this.objectId = positive(objectId);
    this.table = integer(table, "table", 1, 0xffffffff);
    this.name = text(name, 16);
    this.schema = schema;
    Object.freeze(this);
  }
}
export class Compiled {
  readonly request: CreateTable;
  readonly #canonical: Uint8Array;
  constructor(request: CreateTable, canonical: Uint8Array) {
    if (!(request instanceof CreateTable)) throw new TypeError("Expected catalog creation request");
    this.request = request;
    this.#canonical = owned(canonical, 256);
    if (!this.#canonical.length) throw new TypeError("Empty canonical request");
    Object.freeze(this);
  }
  get canonical(): Uint8Array {
    return new Uint8Array(this.#canonical);
  }
}
export class Policy {
  readonly scope: Scope;
  readonly principal: number;
  readonly revision: bigint;
  readonly inspect: boolean;
  readonly create: boolean;
  constructor(
    scope: Scope,
    principal: number,
    revision: bigint,
    inspect: boolean,
    create: boolean,
  ) {
    if (!(scope instanceof Scope) || typeof inspect !== "boolean" || typeof create !== "boolean")
      throw new TypeError("Expected catalog scope and boolean rights");
    this.scope = scope;
    this.principal = integer(principal, "principal", 0);
    this.revision = positive(revision);
    this.inspect = inspect;
    this.create = create;
    Object.freeze(this);
  }
}
export class PolicyChange {
  readonly expectedRevision: bigint;
  readonly policy: Policy;
  constructor(expectedRevision: bigint, policy: Policy) {
    if (!(policy instanceof Policy)) throw new TypeError("Expected catalog policy");
    this.expectedRevision = wide(expectedRevision);
    this.policy = policy;
    Object.freeze(this);
  }
}
/** Opaque exact signed text. Persist unchanged before attempting submission. */
export class Prepared {
  readonly #data: string;
  constructor(data: string) {
    this.#data = text(data, 8192);
    if (!this.#data.length || Buffer.from(this.#data).toString("utf8") !== this.#data)
      throw new TypeError("Invalid saved catalog command text");
    Object.freeze(this);
  }
  get data(): string {
    return this.#data;
  }
}
export class Uncertain extends UnknownOutcome {
  readonly prepared: Prepared;
  constructor(prepared: Prepared, cause: UnknownOutcome) {
    super("Catalog admission is uncertain; retain the identical prepared command", {
      status: 6,
      ...(cause.code === undefined ? {} : { code: cause.code }),
      phase: "submit-catalog",
    });
    this.prepared = prepared;
  }
}
export interface Capabilities {
  readonly version: number;
  readonly definition: string;
  readonly initialize: boolean;
  readonly createTable: boolean;
  readonly conditionalPolicy: boolean;
  readonly currentMetadata: boolean;
  readonly maxSavedBytes: number;
  readonly tableColumns: number;
}
export interface Description {
  readonly configuration: Configuration;
  readonly policy: Policy;
  readonly resourceRevision: number;
}
export type Observation = "pending" | "processed";
export type Outcome = "applied" | "name_conflict" | "object_conflict" | "table_conflict";
export interface Receipt {
  readonly request: CreateTable;
  readonly principal: number;
  readonly input: number;
  readonly outcome: Outcome;
}
export type DispositionOutcome =
  | "initialized"
  | "policy_applied"
  | "invalid_command"
  | "denied"
  | "identity_conflict"
  | "stale_policy";
export interface Disposition {
  readonly scope: Scope;
  readonly origin: "external" | "process" | "effect";
  readonly principal: number;
  readonly input: number;
  readonly payload: Uint8Array;
  readonly outcome: DispositionOutcome;
}
function scope(value: Scope): NativeScope {
  if (!(value instanceof Scope)) throw new TypeError("Expected catalog scope");
  return {
    realm: value.resource.realm,
    resource: value.resource.resource,
    catalog: value.catalog.toString(),
  };
}
function fromScope(value: NativeScope): Scope {
  return new Scope(new ResourceRef(value.realm, value.resource), nativeWide(value.catalog));
}
function request(value: CreateTable): NativeRequest {
  if (!(value instanceof CreateTable)) throw new TypeError("Expected creation request");
  return {
    scope: scope(value.scope),
    operation: value.operation.toString(),
    object: value.objectId.toString(),
    table: value.table,
    name: value.name,
    schema: { names: [...value.schema.names], value_type: value.schema.valueType },
  };
}
function fromRequest(value: NativeRequest): CreateTable {
  const names = value.schema.names;
  if (names.length !== 2 || names[0] === undefined || names[1] === undefined)
    throw new IncompatibleNative("Expected two column names");
  return new CreateTable(
    fromScope(value.scope),
    nativeWide(value.operation),
    nativeWide(value.object),
    value.table,
    value.name,
    new Schema([names[0], names[1]], value.schema.value_type),
  );
}
function policy(value: Policy): NativePolicy {
  if (!(value instanceof Policy)) throw new TypeError("Expected catalog policy");
  return {
    scope: scope(value.scope),
    principal: value.principal,
    revision: value.revision.toString(),
    inspect: value.inspect,
    create: value.create,
  };
}
function fromPolicy(value: NativePolicy): Policy {
  return new Policy(
    fromScope(value.scope),
    value.principal,
    nativeWide(value.revision),
    value.inspect,
    value.create,
  );
}
function fromConfiguration(value: NativeConfiguration): Configuration {
  return new Configuration(
    fromScope(value.scope),
    new ProcessRef(value.scope.realm, value.owner),
    value.administrator,
  );
}
function saved(value: Prepared): string {
  if (!(value instanceof Prepared)) throw new TypeError("Expected saved catalog command");
  return value.data;
}
/** One owned native port; no automatic retry or principal sequence coordinator. */
export class Client {
  readonly connection: Connection;
  readonly #bridge: CatalogBridge;
  private constructor(connection: Connection, bridge: CatalogBridge) {
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
      credential.realm !== connection.scope.resource.realm
    )
      throw new TypeError("Catalog credential must match the connection realm");
    const bridge = await CatalogBridge.open(
      text(config.url, 2048),
      credential.seedFile,
      {
        connection: {
          scope: scope(connection.scope),
          owner: connection.owner.pid,
          principal: credential.principal,
        },
        timeout_ms: config.timeoutMs,
      },
      config.nativeHost,
    );
    return new Client(connection, bridge);
  }
  async capabilities(): Promise<Capabilities> {
    const value = field(await this.#bridge.call({ capabilities: {} }), "capabilities");
    return Object.freeze({
      version: value.version,
      definition: value.definition,
      initialize: value.initialize,
      createTable: value.create_table,
      conditionalPolicy: value.conditional_policy,
      currentMetadata: value.current_metadata,
      maxSavedBytes: value.max_saved_bytes,
      tableColumns: value.table_columns,
    });
  }
  async describe(): Promise<Description> {
    const value = field(await this.#bridge.call({ describe: {} }), "description");
    return decoded(() =>
      Object.freeze({
        configuration: fromConfiguration(value.configuration),
        policy: fromPolicy(value.policy),
        resourceRevision: integer(value.resource_revision, "revision", 0),
      }),
    );
  }
  async compileSql(
    sql: string,
    operation: bigint,
    objectId: bigint,
    table: number,
  ): Promise<Compiled> {
    const value = field(
      await this.#bridge.call({
        compile: {
          sql: text(sql, 4096),
          operation: positive(operation).toString(),
          object: positive(objectId).toString(),
          table: integer(table, "table", 1, 0xffffffff),
        },
      }),
      "compiled",
    );
    return decoded(() => new Compiled(fromRequest(value.request), unhex(value.canonical, 256)));
  }
  async prepareInitialize(configuration: Configuration): Promise<Prepared> {
    if (!(configuration instanceof Configuration))
      throw new TypeError("Expected catalog configuration");
    const value = field(
      await this.#bridge.call({
        prepare_initialize: {
          scope: scope(configuration.scope),
          owner: configuration.owner.pid,
          administrator: configuration.administrator,
        },
      }),
      "prepared",
    );
    return decoded(() => new Prepared(value));
  }
  async prepareCreate(value: CreateTable): Promise<Prepared> {
    const result = field(await this.#bridge.call({ prepare_create: request(value) }), "prepared");
    return decoded(() => new Prepared(result));
  }
  async preparePolicy(change: PolicyChange): Promise<Prepared> {
    if (!(change instanceof PolicyChange))
      throw new TypeError("Expected conditional policy change");
    const value = field(
      await this.#bridge.call({
        prepare_policy: {
          expected_revision: change.expectedRevision.toString(),
          policy: policy(change.policy),
        },
      }),
      "prepared",
    );
    return decoded(() => new Prepared(value));
  }
  async submit(prepared: Prepared): Promise<AdmissionReceipt> {
    const token = saved(prepared);
    try {
      const value = await this.#bridge.call({ submit: token });
      if (!("receipt" in value) || value.receipt.position < 1)
        throw new UnknownOutcome("Missing catalog admission receipt");
      return new AdmissionReceipt(value.receipt.position);
    } catch (error) {
      if (error instanceof UnknownOutcome) throw new Uncertain(prepared, error);
      throw error;
    }
  }
  async observe(prepared: Prepared, position: number): Promise<Observation> {
    return field(
      await this.#bridge.call({
        observe: { prepared: saved(prepared), input: integer(position, "input") },
      }),
      "observation",
    );
  }
  async inputDisposition(prepared: Prepared, position: number): Promise<Disposition | undefined> {
    const value = field(
      await this.#bridge.call({
        input_disposition: { prepared: saved(prepared), input: integer(position, "input") },
      }),
      "disposition",
    );
    if (value === null) return undefined;
    return decoded(() => {
      const payload = unhex(value.payload, 32);
      if (payload.length !== 32) throw new IncompatibleNative("Invalid input digest");
      return Object.freeze({
        scope: fromScope(value.scope),
        origin: value.origin,
        principal: integer(value.principal, "principal", 0),
        input: integer(value.input, "input"),
        payload,
        outcome: value.outcome,
      });
    });
  }
  async status(original: CreateTable): Promise<Receipt | undefined> {
    const expected = request(original);
    const value = field(await this.#bridge.call({ status: expected }), "status");
    if (value === null) return undefined;
    return decoded(() => {
      const restored = fromRequest(value.request);
      if (JSON.stringify(request(restored)) !== JSON.stringify(expected))
        throw new IncompatibleNative("Catalog receipt changed the original request");
      return Object.freeze({
        request: restored,
        principal: integer(value.principal, "principal", 0),
        input: integer(value.input, "input"),
        outcome: value.outcome,
      });
    });
  }
  close(): Promise<void> {
    return this.#bridge.close();
  }
}
