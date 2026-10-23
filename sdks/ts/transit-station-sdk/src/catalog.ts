import {
  AdmissionReceipt,
  Credential,
  ProcessRef,
  ResourceRef,
  IncompatibleNative,
  UnknownOutcome,
} from "@transit/client";
import type { ClientConfig } from "@transit/client";
import { configuration, integer, text } from "@transit/client/internal";
import { CatalogBridge } from "./bridge.ts";
import { hex, unhex } from "./framing.ts";
import { wide, nativeWide } from "./values.ts";
import { encodeType, decodeType, encodeCell, decodeCell, encodeAtom } from "./logical-values.ts";
import type { Descriptor, Cell, Atom } from "./logical-values.ts";
import type { CatalogAction, CatalogResult } from "./wire.ts";
import contract from "./contract.json" with { type: "json" };

type Action<K extends PropertyKey> = Extract<CatalogAction, Record<K, unknown>>[K];
type Result<K extends PropertyKey> = Extract<CatalogResult, Record<K, unknown>>[K];
type NativeSchema = Extract<Action<"prepare">["action"], { create: unknown }>["create"]["schema"];
type NativeMetadata = NonNullable<Result<"definition">>["metadata"];
type NativeOutcome = NonNullable<Result<"state">["outcome"]>;
type NativeScope = NativeMetadata["scope"];
const currentDefinition = contract.definition as NativeSchema["definition"];
type Tags<T> = T extends unknown ? keyof T : never;
function field<K extends Tags<CatalogResult>>(value: CatalogResult, key: K): Result<K> {
  if (!(key in value)) throw new IncompatibleNative("Unexpected catalog result");
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
function name(value: string): string {
  text(value, 255);
  if (!value.length || value.includes("\0") || Buffer.from(value).toString("utf8") !== value)
    throw new TypeError("Expected a UTF-8 Table or column name");
  return value;
}
function definition(value: string): string {
  if (value !== contract.definition)
    throw new IncompatibleNative("Foreign or missing catalog definition");
  return value;
}
function digest(value: string): string {
  if (!/^[0-9a-f]{64}$/.test(value)) throw new TypeError("Expected a complete catalog digest");
  return value;
}
function sameScope(a: Scope, b: Scope): boolean {
  return (
    a.catalog === b.catalog &&
    a.resource.realm === b.resource.realm &&
    a.resource.resource === b.resource.resource
  );
}
export class Scope {
  readonly catalog: bigint;
  readonly resource: ResourceRef;
  constructor(resource: ResourceRef, catalog: bigint) {
    this.resource = resource;
    if (!(resource instanceof ResourceRef)) throw new TypeError("Expected resource reference");
    this.catalog = positive(catalog);
    Object.freeze(this);
  }
}
export class Connection {
  readonly owner: ProcessRef;
  readonly scope: Scope;
  readonly role: number | undefined;
  readonly namespace: number;
  constructor(owner: ProcessRef, scope: Scope, role?: number, namespace = 1) {
    this.owner = owner;
    this.scope = scope;
    this.role = role === undefined ? undefined : integer(role, "selected role", 0);
    this.namespace = integer(namespace, "schema namespace");
    if (
      !(owner instanceof ProcessRef) ||
      !(scope instanceof Scope) ||
      owner.realm !== scope.resource.realm
    )
      throw new TypeError("Catalog connection requires one realm");
    Object.freeze(this);
  }
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
export interface TableLimits {
  readonly recordBytes: number;
  readonly stagingBytes: bigint;
  readonly stagingRecords: number;
}
export class Configuration {
  readonly administrator: number;
  readonly tableLimits: TableLimits;
  readonly scope: Scope;
  readonly owner: ProcessRef;
  readonly authority: AuthorityProfile;
  readonly databaseName: string;
  constructor(
    scope: Scope,
    owner: ProcessRef,
    administrator: number,
    limits: TableLimits,
    authority: AuthorityProfile,
    databaseName: string,
  ) {
    this.scope = scope;
    this.owner = owner;
    new Connection(owner, scope);
    this.administrator = integer(administrator, "administrator", 0);
    if (!(authority instanceof AuthorityProfile))
      throw new TypeError("Expected native authorization bindings");
    this.authority = authority;
    this.databaseName = name(databaseName);
    text(databaseName, 63);
    this.tableLimits = Object.freeze({
      recordBytes: integer(limits.recordBytes, "record bytes", 1, 0xffffffff),
      stagingBytes: positive(limits.stagingBytes),
      stagingRecords: integer(limits.stagingRecords, "staging records", 1, 0xffffffff),
    });
    if (this.tableLimits.stagingBytes < BigInt(this.tableLimits.recordBytes))
      throw new TypeError("Staging quota cannot be smaller than one record");
    Object.freeze(this);
  }
}
/** Stable bindings allocated by the native authority, never inferred from names. */
export class AuthorityProfile {
  readonly databaseDomain: number;
  readonly schemaDomain: number;
  readonly tableDomain: number;
  readonly database: number;
  readonly initialSchema: number;
  readonly initialSchemaAuthority: number;
  constructor(
    databaseDomain: number,
    schemaDomain: number,
    tableDomain: number,
    database: number,
    initialSchema: number,
    initialSchemaAuthority: number,
  ) {
    this.databaseDomain = integer(databaseDomain, "database domain");
    this.schemaDomain = integer(schemaDomain, "schema domain");
    this.tableDomain = integer(tableDomain, "Table domain");
    this.database = integer(database, "database object");
    this.initialSchema = integer(initialSchema, "initial schema");
    this.initialSchemaAuthority = integer(initialSchemaAuthority, "initial schema authority");
    if (
      new Set([databaseDomain, schemaDomain, tableDomain]).size !== 3 ||
      database === initialSchemaAuthority
    )
      throw new TypeError("Distinct native authorization bindings are required");
    Object.freeze(this);
  }
}
function authority(value: AuthorityProfile): Action<"prepare_initialize">["authority"] {
  if (!(value instanceof AuthorityProfile))
    throw new TypeError("Expected native authorization bindings");
  return {
    database_domain: value.databaseDomain,
    schema_domain: value.schemaDomain,
    table_domain: value.tableDomain,
    database: value.database,
    initial_schema: value.initialSchema,
    initial_schema_authority: value.initialSchemaAuthority,
  };
}
/** Observed authenticated identity; this value itself grants no authority. */
export class Subject {
  readonly principal: number;
  readonly loginRole: number;
  readonly role: number;
  readonly credentialEpoch: number;
  readonly audience: number;
  readonly #context: string;
  constructor(
    principal: number,
    loginRole: number,
    role: number,
    credentialEpoch: number,
    audience: number,
    context: Uint8Array,
  ) {
    this.principal = integer(principal, "principal", 0);
    this.loginRole = integer(loginRole, "login role", 0);
    this.role = integer(role, "selected role", 0);
    this.credentialEpoch = integer(credentialEpoch, "credential epoch");
    this.audience = integer(audience, "audience");
    this.#context = hex(context, 32);
    if (this.#context.length !== 64) throw new TypeError("Expected subject context digest");
    Object.freeze(this);
  }
  get context(): Uint8Array {
    return unhex(this.#context, 32);
  }
}
export type Encoding = NativeSchema["columns"][number]["encoding"];
export type Collation = NativeSchema["columns"][number]["collation"];
export interface Column {
  readonly id: bigint;
  readonly name: string;
  readonly type: Descriptor;
  readonly nullable?: boolean;
  readonly default?: Cell;
  readonly maxCharacters?: number;
  readonly encoding?: Encoding;
  readonly collation?: Collation;
}
const schemas = new WeakMap<Schema, NativeSchema>();
// Charge completed fragments before constructing another owned logical tree.
// The complete frame encoder still counts the enclosing punctuation/fields.
class WireBudget {
  private remaining: number;
  constructor(remaining: number) {
    this.remaining = remaining;
  }
  take<T>(value: T): T {
    this.remaining -= Buffer.byteLength(JSON.stringify(value));
    if (this.remaining < 0) throw new TypeError("Table wire budget exceeded");
    return value;
  }
}
export function schemaWire(value: Schema): NativeSchema {
  const result = schemas.get(value);
  if (!result) throw new TypeError("Expected Table schema");
  return structuredClone(result);
}
export class Schema {
  readonly objectId: bigint;
  readonly revision: bigint;
  readonly nextColumn: bigint;
  constructor(
    objectId: bigint,
    revision: bigint,
    nextColumn: bigint,
    columns: readonly Column[],
    primaryKey: readonly bigint[] = [],
  ) {
    this.objectId = positive(objectId);
    this.revision = positive(revision);
    this.nextColumn = positive(nextColumn);
    if (!columns.length || columns.length > 128 || primaryKey.length > columns.length)
      throw new TypeError("Invalid Table column count");
    const budget = new WireBudget(2 * 1024 * 1024);
    const value: NativeSchema = {
      definition: currentDefinition,
      object: this.objectId.toString(),
      revision: this.revision.toString(),
      next_column: this.nextColumn.toString(),
      columns: columns.map((column) =>
        budget.take({
          id: positive(column.id).toString(),
          name: name(column.name),
          type: encodeType(column.type),
          nullable: column.nullable ?? true,
          default: column.default === undefined ? null : encodeCell(column.default),
          max_characters: column.maxCharacters ?? null,
          encoding: column.encoding ?? "plain",
          collation: column.collation ?? "none",
        }),
      ),
      primary_key: primaryKey.map((value) => positive(value).toString()),
    };
    if (Buffer.byteLength(JSON.stringify(value)) > 2 * 1024 * 1024)
      throw new TypeError("Table schema exceeds its JSON bound");
    schemas.set(this, structuredClone(value));
    Object.freeze(this);
  }
  get columns(): readonly Column[] {
    return schemaWire(this).columns.map((column) => ({
      id: nativeWide(column.id),
      name: column.name,
      type: decodeType(column.type),
      nullable: column.nullable,
      encoding: column.encoding,
      collation: column.collation,
      ...(column.default === null ? {} : { default: decodeCell(column.default) }),
      ...(column.max_characters === null ? {} : { maxCharacters: column.max_characters }),
    }));
  }
  get primaryKey(): readonly bigint[] {
    return schemaWire(this).primary_key.map((value) => nativeWide(value));
  }
}
export function schemaValue(value: NativeSchema): Schema {
  definition(value.definition);
  const columns = value.columns.map((column) => ({
    id: nativeWide(column.id),
    name: column.name,
    type: decodeType(column.type),
    nullable: column.nullable,
    encoding: column.encoding,
    collation: column.collation,
    ...(column.default === null ? {} : { default: decodeCell(column.default) }),
    ...(column.max_characters === null ? {} : { maxCharacters: column.max_characters }),
  }));
  return new Schema(
    nativeWide(value.object),
    nativeWide(value.revision),
    nativeWide(value.next_column),
    columns,
    value.primary_key.map((value) => nativeWide(value)),
  );
}
export class Identity {
  readonly operation: bigint;
  readonly namespace: bigint;
  constructor(operation: bigint, namespace: bigint) {
    this.operation = positive(operation);
    this.namespace = positive(namespace);
    Object.freeze(this);
  }
}
function identity(value: Identity): Action<"compile">["identity"] {
  if (!(value instanceof Identity)) throw new TypeError("Expected Table operation identity");
  return { operation: value.operation.toString(), namespace: value.namespace.toString() };
}
export class Basis {
  readonly objectId: bigint;
  readonly revision: bigint;
  readonly schemaFingerprint: string;
  constructor(objectId: bigint, revision: bigint, schemaFingerprint: string) {
    this.objectId = positive(objectId);
    this.revision = positive(revision);
    this.schemaFingerprint = digest(schemaFingerprint);
    Object.freeze(this);
  }
}
function basis(value: Basis) {
  if (!(value instanceof Basis)) throw new TypeError("Expected frozen Table basis");
  return {
    object: value.objectId.toString(),
    revision: value.revision.toString(),
    schema_fingerprint: value.schemaFingerprint,
  };
}
/** Immutable catalog record commitment supplied by the shared implementation. */
export class MetadataCommitment {
  readonly bytes: number;
  readonly digest: string;
  constructor(bytes: number, hash: string) {
    this.bytes = integer(bytes, "metadata bytes", 1, 444);
    this.digest = digest(hash);
    Object.freeze(this);
  }
}
export class Metadata {
  readonly namespace: number;
  readonly commitment: MetadataCommitment;
  readonly scope: Scope;
  readonly objectId: bigint;
  readonly revision: bigint;
  readonly name: string;
  readonly schemaFingerprint: string;
  readonly principal: number;
  readonly operation: bigint;
  readonly admittedInput: number;
  constructor(value: {
    namespace: number;
    commitment: MetadataCommitment;
    scope: Scope;
    objectId: bigint;
    revision: bigint;
    name: string;
    schemaFingerprint: string;
    principal: number;
    operation: bigint;
    admittedInput: number;
  }) {
    if (!(value.scope instanceof Scope)) throw new TypeError("Expected catalog scope");
    if (!(value.commitment instanceof MetadataCommitment))
      throw new TypeError("Expected metadata commitment");
    this.namespace = integer(value.namespace, "schema namespace");
    this.commitment = value.commitment;
    this.scope = value.scope;
    this.objectId = positive(value.objectId);
    this.revision = positive(value.revision);
    this.name = name(value.name);
    this.schemaFingerprint = digest(value.schemaFingerprint);
    this.principal = integer(value.principal, "principal", 0);
    this.operation = positive(value.operation);
    this.admittedInput = integer(value.admittedInput, "admitted input");
    Object.freeze(this);
  }
  get basis(): Basis {
    return new Basis(this.objectId, this.revision, this.schemaFingerprint);
  }
}
function fromMetadata(value: NativeMetadata): Metadata {
  if (value.commitment.format !== 0x54434d01 || value.commitment.digest.length !== 32)
    throw new TypeError("Invalid metadata commitment");
  return new Metadata({
    namespace: value.namespace,
    commitment: new MetadataCommitment(
      value.commitment.length,
      hex(new Uint8Array(value.commitment.digest), 32),
    ),
    scope: fromScope(value.scope),
    objectId: nativeWide(value.object),
    revision: nativeWide(value.revision),
    name: value.name,
    schemaFingerprint: value.schema_fingerprint,
    principal: value.principal,
    operation: nativeWide(value.operation),
    admittedInput: value.admitted_input,
  });
}
export interface Head {
  readonly revision: bigint;
  readonly rows: bigint;
  readonly pending: bigint;
}
function fromHead(value: NonNullable<Result<"definition">>["head"]): Head {
  return Object.freeze({
    revision: positive(nativeWide(value.revision)),
    rows: nativeWide(value.rows),
    pending: nativeWide(value.pending),
  });
}
export interface Entry {
  readonly metadata: Metadata;
  readonly head: Head;
}
export interface Definition extends Entry {
  readonly authorization: number;
  readonly schema: Schema;
}
export interface HistoricalDefinition {
  readonly metadata: Metadata;
  readonly schema: Schema;
}
export class Cursor {
  readonly definition: string;
  readonly afterObject: bigint;
  readonly resourceRevision: number;
  readonly scope: Scope;
  constructor(
    currentDefinition: string,
    scope: Scope,
    resourceRevision: number,
    afterObject: bigint,
  ) {
    this.scope = scope;
    this.definition = definition(currentDefinition);
    if (!(scope instanceof Scope)) throw new TypeError("Expected catalog scope");
    this.resourceRevision = integer(resourceRevision, "resource revision", 0);
    this.afterObject = positive(afterObject);
    Object.freeze(this);
  }
}
function cursor(value: Cursor): NonNullable<Action<"list">> {
  if (!(value instanceof Cursor)) throw new TypeError("Expected catalog cursor");
  return {
    definition: currentDefinition,
    scope: scope(value.scope),
    resource_revision: value.resourceRevision,
    after_object: value.afterObject.toString(),
  };
}
export class Page {
  readonly resourceRevision: number;
  readonly entries: readonly Entry[];
  readonly next: Cursor | undefined;
  constructor(resourceRevision: number, entries: readonly Entry[], next?: Cursor) {
    this.next = next;
    this.resourceRevision = integer(resourceRevision, "resource revision", 0);
    if (entries.length > 8) throw new TypeError("Expected at most eight entries");
    let previous: Metadata | undefined;
    for (const entry of entries) {
      if (
        !(entry.metadata instanceof Metadata) ||
        (previous &&
          (!sameScope(previous.scope, entry.metadata.scope) ||
            previous.objectId >= entry.metadata.objectId))
      )
        throw new TypeError("Expected ordered metadata in one scope");
      previous = entry.metadata;
    }
    if (
      next &&
      (!(next instanceof Cursor) ||
        next.resourceRevision !== this.resourceRevision ||
        (previous &&
          (!sameScope(next.scope, previous.scope) || next.afterObject < previous.objectId)))
    )
      throw new TypeError("Continuation does not match the page");
    this.entries = Object.freeze(
      entries.map((entry) =>
        Object.freeze({ metadata: entry.metadata, head: Object.freeze({ ...entry.head }) }),
      ),
    );
    Object.freeze(this);
  }
}
export class Reference {
  readonly definition: string;
  readonly digest: string;
  constructor(currentDefinition: string, hash: string) {
    this.definition = definition(currentDefinition);
    this.digest = digest(hash);
    Object.freeze(this);
  }
}
function reference(value: Reference): Action<"status"> {
  if (!(value instanceof Reference)) throw new TypeError("Expected exact intent reference");
  return { definition: currentDefinition, digest: value.digest };
}
export class SavedIntent {
  readonly definition: string;
  readonly #bytes: string;
  constructor(currentDefinition: string, bytes: Uint8Array) {
    this.definition = definition(currentDefinition);
    this.#bytes = hex(bytes, contract.limits.catalog_intent_bytes);
    if (!this.#bytes.length) throw new TypeError("Empty Table intent");
    Object.freeze(this);
  }
  get bytes(): Uint8Array {
    return unhex(this.#bytes, contract.limits.catalog_intent_bytes);
  }
}
export interface Intent {
  readonly reference: Reference;
  readonly scope: Scope;
  readonly owner: ProcessRef;
  readonly principal: number;
  readonly identity: Identity;
  readonly objectId: bigint;
  readonly kind: "create" | "alter" | "rename" | "drop" | "insert" | "update" | "delete";
}
function fromIntent(value: Result<"loaded">): Intent {
  return Object.freeze({
    reference: new Reference(value.reference.definition, value.reference.digest),
    scope: fromScope(value.scope),
    owner: new ProcessRef(value.scope.realm, value.owner),
    principal: integer(value.principal, "principal", 0),
    identity: new Identity(nativeWide(value.operation), nativeWide(value.namespace)),
    objectId: nativeWide(value.object),
    kind: value.kind,
  });
}
export interface Compiled {
  readonly intent: Intent;
  readonly saved: SavedIntent;
}
export class Prepared {
  readonly #data: string;
  constructor(data: string) {
    this.#data = text(data, contract.limits.catalog_prepared_bytes);
    if (!data.length || Buffer.from(data).toString("utf8") !== data)
      throw new TypeError("Invalid saved catalog command text");
    Object.freeze(this);
  }
  get data(): string {
    return this.#data;
  }
}
function prepared(value: Prepared): string {
  if (!(value instanceof Prepared)) throw new TypeError("Expected saved catalog command");
  return value.data;
}
export class Uncertain extends UnknownOutcome {
  readonly prepared: Prepared;
  constructor(prepared: Prepared, cause: UnknownOutcome) {
    super("Catalog admission is uncertain; retain the identical prepared command", {
      status: 6,
      ...(cause.code === undefined ? {} : { code: cause.code }),
      ...(cause.diagnostic === undefined ? {} : { diagnostic: cause.diagnostic }),
      diagnosticInvalid: cause.diagnosticInvalid,
      phase: "submit-catalog",
    });
    this.prepared = prepared;
  }
}
export type Diagnostic = import("./unified.ts").Diagnostic;
export interface Outcome {
  readonly kind: Intent["kind"];
  readonly operation: bigint;
  readonly objectId: bigint;
  readonly actualObject?: bigint;
  readonly phase:
    | "preparing"
    | "delegated"
    | "building"
    | "applied"
    | "unchanged"
    | "rejected"
    | "cancelled";
  readonly terminal: boolean;
  readonly counts?: { readonly matched: bigint; readonly changed: bigint };
  readonly admittedInput: number;
  readonly completedInput?: number;
  readonly diagnostic: Diagnostic;
}
function fromOutcome(value: NativeOutcome): Outcome {
  const terminal = ["applied", "unchanged", "rejected", "cancelled"].includes(value.phase);
  const hasCounts =
    value.phase === "applied" && ["insert", "update", "delete"].includes(value.kind);
  if (
    terminal !== value.terminal ||
    hasCounts !== (value.counts !== null) ||
    (value.counts !== null && nativeWide(value.counts.changed) > nativeWide(value.counts.matched))
  )
    throw new TypeError("Inconsistent Table outcome");
  return Object.freeze({
    kind: value.kind,
    operation: positive(nativeWide(value.operation)),
    objectId: nativeWide(value.object),
    ...(value.actual_object === null ? {} : { actualObject: nativeWide(value.actual_object) }),
    phase: value.phase,
    terminal,
    ...(value.counts === null
      ? {}
      : {
          counts: Object.freeze({
            matched: nativeWide(value.counts.matched),
            changed: nativeWide(value.counts.changed),
          }),
        }),
    admittedInput: integer(value.admitted_input, "admitted input"),
    ...(value.completed_input === null
      ? {}
      : { completedInput: integer(value.completed_input, "completed input") }),
    diagnostic: value.diagnostic,
  });
}
export interface Upload {
  readonly phase: "uploading" | "sealed" | "ready" | "cancelled";
  readonly received: number;
  readonly total: number;
}
export interface State {
  readonly outcome?: Outcome;
  readonly upload?: Upload;
}
export interface Disposition {
  readonly input: number;
  readonly outcome: NonNullable<Result<"disposition">>["outcome"];
  readonly diagnostic: Diagnostic;
}
export type Next =
  | { readonly kind: "send"; readonly prepared: Prepared }
  | { readonly kind: "running" | "upload_cancelled" }
  | { readonly kind: "terminal"; readonly outcome: Outcome };
export type Progress =
  | { readonly kind: "pending" }
  | {
      readonly kind: "processed";
      readonly disposition?: Disposition;
      readonly outcome?: Outcome;
      readonly upload?: Upload;
    };
export interface Assignment {
  readonly column: bigint;
  readonly value: Cell | "default";
}
export type Predicate =
  | { readonly kind: "all" | "negate" | "conjunction" | "disjunction" }
  | { readonly kind: "state"; readonly column: bigint; readonly state: Cell["state"] }
  | {
      readonly kind: "compare";
      readonly column: bigint;
      readonly op: "eq" | "ne" | "lt" | "le" | "gt" | "ge";
      readonly value: Atom;
    };
export type Mutation =
  | { readonly kind: "insert"; readonly rows: readonly (readonly Assignment[])[] }
  | {
      readonly kind: "update";
      readonly assignments: readonly Assignment[];
      readonly predicate?: readonly Predicate[];
    }
  | { readonly kind: "delete"; readonly predicate?: readonly Predicate[] };
export type Change =
  | { readonly kind: "add"; readonly column: Omit<Column, "id"> }
  | { readonly kind: "drop"; readonly column: bigint }
  | { readonly kind: "rename"; readonly column: bigint; readonly name: string }
  | { readonly kind: "default"; readonly column: bigint; readonly value?: Cell }
  | { readonly kind: "nullable"; readonly column: bigint; readonly value: boolean }
  | {
      readonly kind: "physical";
      readonly column: bigint;
      readonly encoding: Encoding;
      readonly collation: Collation;
    }
  | {
      readonly kind: "type";
      readonly column: bigint;
      readonly type: Descriptor;
      readonly maxCharacters?: number;
    };
export type Operation =
  | { readonly kind: "create"; readonly schema: Schema; readonly ifNotExists?: boolean }
  | { readonly kind: "alter"; readonly basis: Basis; readonly change: Change }
  | { readonly kind: "rename"; readonly basis: Basis; readonly name: string }
  | { readonly kind: "drop"; readonly basis?: Basis; readonly ifExists?: boolean }
  | { readonly kind: "mutate"; readonly basis: Basis; readonly mutation: Mutation };
function operation(value: Operation): Action<"prepare">["action"] {
  switch (value.kind) {
    case "create":
      return {
        create: { schema: schemaWire(value.schema), if_not_exists: value.ifNotExists ?? false },
      };
    case "rename":
      return { rename: { basis: basis(value.basis), name: name(value.name) } };
    case "drop":
      return {
        drop: {
          basis: value.basis === undefined ? null : basis(value.basis),
          if_exists: value.ifExists ?? false,
        },
      };
    case "alter": {
      type NativeChange = Extract<
        Action<"prepare">["action"],
        { alter: unknown }
      >["alter"]["change"];
      const item = value.change;
      let change: NativeChange;
      switch (item.kind) {
        case "add":
          change = {
            add: {
              name: name(item.column.name),
              type: encodeType(item.column.type),
              nullable: item.column.nullable ?? true,
              default: item.column.default === undefined ? null : encodeCell(item.column.default),
              max_characters: item.column.maxCharacters ?? null,
              encoding: item.column.encoding ?? "plain",
              collation: item.column.collation ?? "none",
            },
          };
          break;
        case "drop":
          change = { drop: positive(item.column).toString() };
          break;
        case "rename":
          change = { rename: { column: positive(item.column).toString(), name: name(item.name) } };
          break;
        case "default":
          change = {
            default: {
              column: positive(item.column).toString(),
              value: item.value === undefined ? null : encodeCell(item.value),
            },
          };
          break;
        case "nullable":
          change = { nullable: { column: positive(item.column).toString(), value: item.value } };
          break;
        case "physical":
          change = {
            physical: {
              column: positive(item.column).toString(),
              encoding: item.encoding,
              collation: item.collation,
            },
          };
          break;
        case "type":
          change = {
            type: {
              column: positive(item.column).toString(),
              type: encodeType(item.type),
              max_characters: item.maxCharacters ?? null,
            },
          };
          break;
      }
      return { alter: { basis: basis(value.basis), change } };
    }
    case "mutate":
      return { mutate: { basis: basis(value.basis), mutation: mutationWire(value.mutation) } };
  }
}
export interface Capabilities {
  readonly version: number;
  readonly definition: string;
  readonly maxColumns: number;
  readonly maxRows: number;
  readonly maxSqlBytes: number;
  readonly maxIntentBytes: number;
  readonly maxActionBytes: number;
  readonly maxPreparedBytes: number;
  readonly residentIntents: number;
}
export interface Description {
  readonly configuration: Configuration;
  readonly subject: Subject;
  readonly authorizationRevision: number;
  readonly resourceRevision: number;
}
export type Control = "cancel_operation" | "cleanup_operation" | "cancel_upload" | "collect_upload";
export interface Dependency {
  readonly scope: Scope;
  readonly objectId: bigint;
  readonly identity: bigint;
  readonly owner: ProcessRef;
  readonly kind: "query_source" | "writer" | "watch" | "maintained_relation" | "history";
}
export interface CatalogClientConfig extends ClientConfig {
  readonly tableServiceUrl?: string;
}
/** One owned native port. Persist immutable intent and every exact signed step separately. */
export class Client {
  readonly #bridge: CatalogBridge;
  readonly #principal: number;
  readonly connection: Connection;
  private constructor(connection: Connection, principal: number, bridge: CatalogBridge) {
    this.connection = connection;
    this.#principal = principal;
    this.#bridge = bridge;
    Object.freeze(this);
  }
  static async open(
    input: CatalogClientConfig,
    credential: Credential,
    connection: Connection,
  ): Promise<Client> {
    const config = configuration(input);
    const serviceUrl =
      input.tableServiceUrl === undefined
        ? null
        : text(configuration({ ...input, url: input.tableServiceUrl }).url, 2048);
    if (
      !(credential instanceof Credential) ||
      !(connection instanceof Connection) ||
      credential.realm !== connection.scope.resource.realm
    )
      throw new TypeError("Catalog credential must match the connection realm");
    return new Client(
      connection,
      credential.principal,
      await CatalogBridge.open(
        text(config.url, 2048),
        credential.seedFile,
        {
          connection: {
            scope: scope(connection.scope),
            owner: connection.owner.pid,
            principal: credential.principal,
            role: connection.role ?? null,
            namespace: connection.namespace,
          },
          timeout_ms: config.timeoutMs,
          table_service_url: serviceUrl,
        },
        config.nativeHost,
      ),
    );
  }
  async capabilities(): Promise<Capabilities> {
    const v = field(await this.#bridge.call({ capabilities: {} }), "capabilities");
    return Object.freeze({
      version: v.version,
      definition: v.definition,
      maxColumns: v.max_columns,
      maxRows: v.max_rows,
      maxSqlBytes: v.max_sql_bytes,
      maxIntentBytes: v.max_intent_bytes,
      maxActionBytes: v.max_action_bytes,
      maxPreparedBytes: v.max_prepared_bytes,
      residentIntents: v.resident_intents,
    });
  }
  async describe(): Promise<Description> {
    const v = field(await this.#bridge.call({ describe: {} }), "description");
    return decoded(() => {
      const conf = v.configuration,
        subject = v.subject;
      if (
        !sameScope(fromScope(conf.scope), this.connection.scope) ||
        conf.owner !== this.connection.owner.pid ||
        subject.principal !== this.#principal ||
        subject.audience !== this.connection.owner.pid ||
        (this.connection.role !== undefined && subject.role !== this.connection.role)
      )
        throw new TypeError("Foreign catalog description");
      return Object.freeze({
        configuration: new Configuration(
          fromScope(conf.scope),
          new ProcessRef(conf.scope.realm, conf.owner),
          conf.administrator,
          {
            recordBytes: conf.table_limits.record_bytes,
            stagingBytes: nativeWide(conf.table_limits.staging_bytes),
            stagingRecords: conf.table_limits.staging_records,
          },
          new AuthorityProfile(
            conf.authority.database_domain,
            conf.authority.schema_domain,
            conf.authority.table_domain,
            conf.authority.database,
            conf.authority.initial_schema,
            conf.authority.initial_schema_authority,
          ),
          conf.database_name,
        ),
        subject: new Subject(
          subject.principal,
          subject.login_role,
          subject.role,
          subject.credential_epoch,
          subject.audience,
          new Uint8Array(subject.context),
        ),
        authorizationRevision: integer(v.authorization_revision, "authorization revision", 0),
        resourceRevision: integer(v.resource_revision, "resource revision", 0),
      });
    });
  }
  async lookup(requestedName: string): Promise<Definition | undefined> {
    const v = field(await this.#bridge.call({ lookup: name(requestedName) }), "definition");
    if (v === null) return undefined;
    return decoded(() => {
      const metadata = fromMetadata(v.metadata),
        schema = schemaValue(v.schema);
      if (
        !sameScope(metadata.scope, this.connection.scope) ||
        metadata.namespace !== this.connection.namespace ||
        metadata.name !== requestedName ||
        metadata.objectId !== schema.objectId
      )
        throw new TypeError("Definition does not match its request");
      return Object.freeze({
        authorization: integer(v.authorization, "Table authorization"),
        metadata,
        schema,
        head: fromHead(v.head),
      });
    });
  }
  async definition(objectId: bigint, revision: bigint): Promise<HistoricalDefinition | undefined> {
    const value = field(
      await this.#bridge.call({
        definition: {
          object: positive(objectId).toString(),
          revision: positive(revision).toString(),
        },
      }),
      "historical",
    );
    if (value === null) return undefined;
    return decoded(() => {
      const metadata = fromMetadata(value.metadata),
        schema = schemaValue(value.schema);
      if (
        !sameScope(metadata.scope, this.connection.scope) ||
        metadata.objectId !== objectId ||
        metadata.revision !== revision ||
        schema.objectId !== objectId
      )
        throw new TypeError("Historical definition does not match its request");
      return Object.freeze({ metadata, schema });
    });
  }
  async list(previous?: Cursor): Promise<Page> {
    if (previous && !sameScope(previous.scope, this.connection.scope))
      throw new TypeError("Foreign catalog cursor");
    const v = field(
      await this.#bridge.call({ list: previous === undefined ? null : cursor(previous) }),
      "page",
    );
    return decoded(() => {
      const entries: Entry[] = [];
      let ended = false;
      for (const slot of v.entries) {
        if (slot === null) ended = true;
        else {
          const metadata = fromMetadata(slot.metadata);
          if (
            ended ||
            !sameScope(metadata.scope, this.connection.scope) ||
            metadata.namespace !== this.connection.namespace
          )
            throw new TypeError("Page has a hole or foreign scope");
          entries.push({ metadata, head: fromHead(slot.head) });
        }
      }
      const next =
        v.next === null
          ? undefined
          : new Cursor(
              v.next.definition,
              fromScope(v.next.scope),
              v.next.resource_revision,
              nativeWide(v.next.after_object),
            );
      if (next && !sameScope(next.scope, this.connection.scope))
        throw new TypeError("Foreign continuation scope");
      const page = new Page(v.resource_revision, entries, next);
      if (
        previous &&
        (page.resourceRevision !== previous.resourceRevision ||
          (entries[0] && entries[0].metadata.objectId <= previous.afterObject) ||
          (next && next.afterObject <= previous.afterObject))
      )
        throw new TypeError("Response does not continue the requested page");
      return page;
    });
  }
  #compiled(value: Result<"compiled">): Compiled {
    return decoded(() =>
      Object.freeze({
        intent: this.#intent(value.intent),
        saved: new SavedIntent(
          value.saved.definition,
          unhex(value.saved.bytes, contract.limits.catalog_intent_bytes),
        ),
      }),
    );
  }
  #intent(value: Result<"loaded">): Intent {
    const result = fromIntent(value);
    if (
      !sameScope(result.scope, this.connection.scope) ||
      result.owner.pid !== this.connection.owner.pid ||
      result.principal !== this.#principal
    )
      throw new TypeError("Foreign intent connection");
    return result;
  }
  async compileSql(sql: string, ids: Identity, createObject?: bigint): Promise<Compiled> {
    const result = this.#compiled(
      field(
        await this.#bridge.call({
          compile: {
            sql: text(sql, 4096),
            identity: identity(ids),
            create_object: createObject === undefined ? null : positive(createObject).toString(),
          },
        }),
        "compiled",
      ),
    );
    if (
      result.intent.identity.operation !== ids.operation ||
      result.intent.identity.namespace !== ids.namespace ||
      (createObject !== undefined &&
        (result.intent.objectId !== createObject || result.intent.kind !== "create"))
    )
      throw new IncompatibleNative("Compiled intent does not match its request");
    return result;
  }
  async prepare(tableName: string, ids: Identity, action: Operation): Promise<Compiled> {
    const kind = action.kind === "mutate" ? action.mutation.kind : action.kind;
    const objectId =
      action.kind === "create" ? action.schema.objectId : (action.basis?.objectId ?? 0n);
    const result = this.#compiled(
      field(
        await this.#bridge.call({
          prepare: {
            definition: currentDefinition,
            identity: identity(ids),
            name: name(tableName),
            action: operation(action),
          },
        }),
        "compiled",
      ),
    );
    if (
      result.intent.identity.operation !== ids.operation ||
      result.intent.identity.namespace !== ids.namespace ||
      result.intent.kind !== kind ||
      result.intent.objectId !== objectId
    )
      throw new IncompatibleNative("Prepared intent does not match its request");
    return result;
  }
  async load(saved: SavedIntent): Promise<Intent> {
    if (!(saved instanceof SavedIntent)) throw new TypeError("Expected saved Table intent");
    const value = field(
      await this.#bridge.call({
        load: {
          definition: currentDefinition,
          bytes: hex(saved.bytes, contract.limits.catalog_intent_bytes),
        },
      }),
      "loaded",
    );
    return decoded(() => this.#intent(value));
  }
  async forget(intent: Reference): Promise<void> {
    field(await this.#bridge.call({ forget: reference(intent) }), "forgotten");
  }
  async next(intent: Reference): Promise<Next> {
    const v = field(await this.#bridge.call({ next: reference(intent) }), "next");
    return decoded(() =>
      "send" in v
        ? { kind: "send", prepared: new Prepared(v.send) }
        : "terminal" in v
          ? { kind: "terminal", outcome: fromOutcome(v.terminal) }
          : "running" in v
            ? { kind: "running" }
            : { kind: "upload_cancelled" },
    );
  }
  async status(intent: Reference): Promise<State> {
    const v = field(await this.#bridge.call({ status: reference(intent) }), "state");
    return decoded(() => ({
      ...(v.outcome === null ? {} : { outcome: fromOutcome(v.outcome) }),
      ...(v.upload === null ? {} : { upload: Object.freeze(v.upload) }),
    }));
  }
  async prepareResume(intent: Reference): Promise<Prepared> {
    return new Prepared(
      field(await this.#bridge.call({ prepare_resume: reference(intent) }), "prepared"),
    );
  }
  async prepareControl(intent: Reference, control: Control): Promise<Prepared> {
    return new Prepared(
      field(
        await this.#bridge.call({ prepare_control: { intent: reference(intent), control } }),
        "prepared",
      ),
    );
  }
  async prepareInitialize(value: Configuration): Promise<Prepared> {
    if (!(value instanceof Configuration)) throw new TypeError("Expected catalog configuration");
    return new Prepared(
      field(
        await this.#bridge.call({
          prepare_initialize: {
            scope: scope(value.scope),
            owner: value.owner.pid,
            administrator: value.administrator,
            authority: authority(value.authority),
            database_name: value.databaseName,
            table_limits: {
              record_bytes: value.tableLimits.recordBytes,
              staging_bytes: value.tableLimits.stagingBytes.toString(),
              staging_records: value.tableLimits.stagingRecords,
            },
          },
        }),
        "prepared",
      ),
    );
  }
  async prepareDependency(value: Dependency, present: boolean): Promise<Prepared> {
    if (!(value.owner instanceof ProcessRef) || value.owner.realm !== value.scope.resource.realm)
      throw new TypeError("Dependency owner must share its catalog realm");
    return new Prepared(
      field(
        await this.#bridge.call({
          prepare_dependency: {
            scope: scope(value.scope),
            object: positive(value.objectId).toString(),
            identity: positive(value.identity).toString(),
            owner: value.owner.pid,
            kind: value.kind,
            present,
          },
        }),
        "prepared",
      ),
    );
  }
  async submit(value: Prepared): Promise<AdmissionReceipt> {
    const bytes = prepared(value);
    try {
      const v = await this.#bridge.call({ submit: bytes });
      if (!("receipt" in v) || v.receipt.position < 1)
        throw new UnknownOutcome("Missing catalog admission receipt");
      return new AdmissionReceipt(v.receipt.position);
    } catch (error) {
      if (error instanceof UnknownOutcome) throw new Uncertain(value, error);
      throw error;
    }
  }
  async observe(value: Prepared, position: number, wait = false): Promise<"pending" | "processed"> {
    const input = { prepared: prepared(value), input: integer(position, "input") };
    return field(
      await this.#bridge.call(wait ? { wait_observe: input } : { observe: input }),
      "observation",
    );
  }
  async inputDisposition(value: Prepared, position: number): Promise<Disposition | undefined> {
    return (
      field(
        await this.#bridge.call({
          input_disposition: { prepared: prepared(value), input: integer(position, "input") },
        }),
        "disposition",
      ) ?? undefined
    );
  }
  async progress(
    intent: Reference,
    value: Prepared,
    position: number,
    wait = false,
  ): Promise<Progress> {
    const input = {
      intent: reference(intent),
      prepared: prepared(value),
      input: integer(position, "input"),
    };
    const v = field(
      await this.#bridge.call(wait ? { wait_progress: input } : { progress: input }),
      "progress",
    );
    if ("pending" in v) return { kind: "pending" };
    return decoded(() => ({
      kind: "processed",
      ...(v.processed.disposition === null ? {} : { disposition: v.processed.disposition }),
      ...(v.processed.outcome === null ? {} : { outcome: fromOutcome(v.processed.outcome) }),
      ...(v.processed.upload === null ? {} : { upload: Object.freeze(v.processed.upload) }),
    }));
  }
  close(): Promise<void> {
    return this.#bridge.close();
  }
}

export function mutationWire(item: Mutation, bytes = contract.limits.catalog_action_bytes) {
  const budget = new WireBudget(bytes);
  type NativeMutation = Extract<
    Action<"prepare">["action"],
    { mutate: unknown }
  >["mutate"]["mutation"];
  const assignments = (values: readonly Assignment[]) => {
    if (values.length > 128) throw new TypeError("Too many Table assignments");
    return values.map((item) =>
      budget.take({
        column: positive(item.column).toString(),
        value: item.value === "default" ? { default: {} } : { cell: encodeCell(item.value) },
      }),
    );
  };
  if (
    item.kind === "insert"
      ? item.rows.length === 0 || item.rows.length > 1024
      : (item.predicate?.length ?? 0) > 64
  )
    throw new TypeError("Table mutation exceeds its row or predicate bound");
  const action: NativeMutation["action"] =
    item.kind === "insert"
      ? { insert: item.rows.map(assignments) }
      : item.kind === "update"
        ? { update: assignments(item.assignments) }
        : { delete: {} };
  const predicate: NativeMutation["predicate"] =
    item.kind === "insert" || item.predicate === undefined
      ? null
      : item.predicate.map((entry) =>
          budget.take(
            (() => {
              switch (entry.kind) {
                case "all":
                  return { atom: { all: {} } };
                case "negate":
                  return { negate: {} };
                case "conjunction":
                  return { conjunction: {} };
                case "disjunction":
                  return { disjunction: {} };
                case "state":
                  return {
                    atom: {
                      state: { column: positive(entry.column).toString(), value: entry.state },
                    },
                  };
                case "compare":
                  return {
                    atom: {
                      compare: {
                        column: positive(entry.column).toString(),
                        op: entry.op,
                        value: encodeAtom(entry.value),
                      },
                    },
                  };
              }
            })(),
          ),
        );
  return { action, predicate };
}
