import { Credential, ResourceRef, IncompatibleNative, UnknownOutcome } from "@transit/client";
import { isDeepStrictEqual } from "node:util";
import type { ClientConfig } from "@transit/client";
import { configuration, integer, text, validators } from "@transit/client/internal";
import { CatalogBridge } from "./bridge.ts";
import { wide, nativeWide as decodeNativeWide } from "./values.ts";
import { hex, unhex } from "./framing.ts";
import { encodeType, decodeType, encodeCell, decodeCell, encodeAtom } from "./logical-values.ts";
import type { Descriptor, Cell, Atom } from "./logical-values.ts";
import type { CatalogAction, CatalogResult, CatalogConfig } from "./wire.ts";
import contract from "./contract.json" with { type: "json" };
import catalogSchemas from "./schemas.json" with { type: "json" };

type Action<K extends PropertyKey> = Extract<CatalogAction, Record<K, unknown>>[K];
type Result<K extends PropertyKey> = Extract<CatalogResult, Record<K, unknown>>[K];
type NativeSchema = Extract<Action<"prepare">["action"], { create: unknown }>["create"]["schema"];
type NativeMetadata = NonNullable<Result<"metadata">>;
type NativeBasis = NativeMetadata["binding"];
type NativeStored = NativeBasis["interpretation"];
type NativeInterpretation = NativeStored["interpretation"];
type NativePosition = NativeMetadata["position"];
type NativeScope = CatalogConfig["connection"]["scope"];
type CatalogRead = Result<"catalog">;
type CatalogReadResult<K extends PropertyKey> = Extract<CatalogRead, Record<K, unknown>>[K];
type NativeObservation = Result<"observation">;
type NativeEvidence = Extract<
  Extract<NativeObservation, { rows: unknown }>["rows"],
  { committed: unknown }
>["committed"];
const currentDefinition = contract.definition as NativeSchema["definition"];
const validateAction = validators(catalogSchemas).CatalogAction!;
type Tags<T> = T extends unknown ? keyof T : never;
function field<K extends Tags<CatalogResult>>(value: CatalogResult, key: K): Result<K> {
  if (!(key in value)) throw new IncompatibleNative("Unexpected catalog result");
  return (value as Extract<CatalogResult, Record<K, unknown>>)[key];
}
function positive(value: bigint): bigint {
  if (wide(value) === 0n) throw new TypeError("Catalog identity must be positive");
  return value;
}
function nativeWide(value: string): bigint {
  try {
    return decodeNativeWide(value);
  } catch {
    throw new IncompatibleNative("Invalid native full-width catalog integer");
  }
}
function name(value: string): string {
  text(value, 255);
  if (!value.length || value.includes("\0") || Buffer.from(value).toString("utf8") !== value)
    throw new TypeError("Expected a UTF-8 catalog name");
  return value;
}
function definition(value: string): void {
  if (value !== currentDefinition)
    throw new IncompatibleNative("Foreign or missing catalog definition");
}
function digest(value: string): string {
  if (typeof value !== "string" || !/^[0-9a-f]{64}$/.test(value))
    throw new IncompatibleNative("Expected a complete catalog digest");
  return value;
}
function parseSaved(input: string): unknown {
  text(input, contract.limits.catalog_action_bytes);
  return JSON.parse(input) as unknown;
}
function checked<T>(value: unknown, action: (value: T) => CatalogAction): T {
  if (!validateAction(action(value as T)))
    throw new IncompatibleNative("Invalid saved catalog value");
  return structuredClone(value) as T;
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
/** Explicit direct service audience and branch; credentials supply the principal. */
export class Connection {
  readonly scope: Scope;
  readonly audience: number;
  readonly branch: bigint;
  readonly role: number | undefined;
  constructor(scope: Scope, audience: number, branch = 1n, role?: number) {
    if (!(scope instanceof Scope)) throw new TypeError("Expected catalog scope");
    this.scope = scope;
    this.audience = integer(audience, "service audience");
    this.branch = positive(branch);
    this.role = role === undefined ? undefined : integer(role, "selected role", 0);
    Object.freeze(this);
  }
}
export class Identity {
  readonly operation: bigint;
  readonly namespace: number;
  constructor(operation: bigint, namespace = 1) {
    this.operation = positive(operation);
    this.namespace = integer(namespace, "namespace");
    Object.freeze(this);
  }
}
export interface Position {
  readonly partition: bigint;
  readonly nextLsn: bigint;
}
export interface ObjectIdentity {
  readonly scope: Scope;
  readonly branch: bigint;
  readonly objectId: bigint;
}
export interface Interpretation {
  readonly object: ObjectIdentity;
  readonly revision: bigint;
  readonly digest: string;
}
export interface StoredDefinition {
  readonly interpretation: Interpretation;
  readonly contentBytes: bigint;
  readonly contentDigest: string;
  readonly schemaFingerprint: string;
  readonly retired: boolean;
}
function position(value: NativePosition): Position {
  return Object.freeze({
    partition: nativeWide(value.partition),
    nextLsn: nativeWide(value.next_lsn),
  });
}
function interpretation(value: NativeInterpretation): Interpretation {
  return Object.freeze({
    object: Object.freeze({
      scope: fromScope(value.object.scope),
      branch: nativeWide(value.object.branch),
      objectId: nativeWide(value.object.object),
    }),
    revision: nativeWide(value.revision),
    digest: digest(value.digest),
  });
}
function stored(value: NativeStored): StoredDefinition {
  return Object.freeze({
    interpretation: interpretation(value.interpretation),
    contentBytes: nativeWide(value.content.bytes),
    contentDigest: digest(value.content.sha256),
    schemaFingerprint: digest(value.schema_fingerprint),
    retired: value.retired,
  });
}
const bases = new WeakMap<Basis, NativeBasis>();
/** Complete prepared identity, including its original name and connection. */
export class Basis {
  readonly namespace: number;
  readonly name: string;
  readonly definition: StoredDefinition;
  private constructor(value: NativeBasis) {
    this.namespace = value.namespace;
    this.name = value.name;
    this.definition = stored(value.interpretation);
    bases.set(this, structuredClone(value));
    Object.freeze(this);
  }
  static restore(input: string): Basis {
    const value = checked<NativeBasis>(parseSaved(input), (basis) => ({
      prepare: {
        definition: currentDefinition,
        namespace: basis?.namespace,
        operation: "1",
        name: basis?.name,
        action: { drop: { basis, if_exists: false } },
      },
    }));
    return new Basis(value);
  }
  save(): string {
    return JSON.stringify(basis(this));
  }
}
function basis(value: Basis): NativeBasis {
  const found = bases.get(value);
  if (!found) throw new TypeError("Expected a complete prepared Table basis");
  return structuredClone(found);
}
export interface Metadata {
  readonly basis: Basis;
  readonly schema: Schema;
  readonly authorization: number;
  readonly position: Position;
  readonly changedLsn: bigint;
  readonly rowCount: bigint;
}
function metadata(value: NativeMetadata): Metadata {
  return Object.freeze({
    basis: Basis.restore(JSON.stringify(value.binding)),
    schema: schemaValue(value.schema),
    authorization: value.authorization,
    position: position(value.position),
    changedLsn: nativeWide(value.changed_lsn),
    rowCount: nativeWide(value.row_count),
  });
}
export interface TableLimits {
  readonly recordBytes: number;
  readonly stagingBytes: bigint;
  readonly stagingRecords: number;
}
export type Encoding = NativeSchema["columns"][number]["encoding"];
export type Collation = NativeSchema["columns"][number]["collation"];
type NativeSemantics = NativeSchema["columns"][number]["semantics"];
export interface TimezoneRules {
  readonly version: string;
  readonly digest: Uint8Array;
  readonly zone: string;
  readonly tzif: Uint8Array;
}
export interface SpatialSemantics {
  readonly srid: number;
  readonly verticalDatum: number;
  readonly unitScaleNm: bigint;
  readonly axisOrientation: "right_handed_z_up" | "right_handed_y_up";
  readonly manifold: "planar" | "geodesic_wgs84";
  readonly snapGridScale: number;
  readonly exactPredicates: "shewchuk_adaptive";
  readonly curveOrder: "none" | "s2_hilbert" | "h3" | "hilbert_3d";
}
export interface ColumnSemantics {
  readonly rounding?: "reject" | "half_even" | "toward_zero";
  readonly metric?: "l2_squared" | "cosine" | "dot_product" | "hamming";
  readonly timezone?: TimezoneRules;
  readonly spatial?: SpatialSemantics;
}
function semanticsWire(value: ColumnSemantics = {}): NativeSemantics {
  const zone = value.timezone,
    spatial = value.spatial;
  if (zone && (zone.digest.byteLength !== 32 || zone.tzif.byteLength > 128 * 1024))
    throw new TypeError("Invalid pinned timezone artifact");
  return {
    rounding: value.rounding ?? null,
    metric: value.metric ?? null,
    timezone: zone
      ? {
          version: { version_id: text(zone.version, 64), digest: Array.from(zone.digest) },
          zone: name(zone.zone),
          tzif_hex: hex(zone.tzif, 128 * 1024),
        }
      : null,
    spatial: spatial
      ? {
          srid: spatial.srid,
          vertical_datum: spatial.verticalDatum,
          unit_scale_nm: positive(spatial.unitScaleNm).toString(),
          axis_orientation: spatial.axisOrientation,
          manifold: spatial.manifold,
          snap_grid_scale: spatial.snapGridScale,
          exact_predicates: spatial.exactPredicates,
          curve_order: spatial.curveOrder,
        }
      : null,
  };
}
function semanticsValue(value: NativeSemantics): ColumnSemantics {
  const zone = value.timezone,
    spatial = value.spatial;
  return {
    ...(value.rounding === null ? {} : { rounding: value.rounding }),
    ...(value.metric === null ? {} : { metric: value.metric }),
    ...(zone === null
      ? {}
      : {
          timezone: {
            version: zone.version.version_id,
            digest: Uint8Array.from(zone.version.digest),
            zone: zone.zone,
            tzif: unhex(zone.tzif_hex, 128 * 1024),
          },
        }),
    ...(spatial === null
      ? {}
      : {
          spatial: {
            srid: spatial.srid,
            verticalDatum: spatial.vertical_datum,
            unitScaleNm: nativeWide(spatial.unit_scale_nm),
            axisOrientation: spatial.axis_orientation,
            manifold: spatial.manifold,
            snapGridScale: spatial.snap_grid_scale,
            exactPredicates: spatial.exact_predicates,
            curveOrder: spatial.curve_order,
          },
        }),
  };
}
export interface Column {
  readonly id: bigint;
  readonly name: string;
  readonly type: Descriptor;
  readonly nullable?: boolean;
  readonly default?: Cell;
  readonly maxCharacters?: number;
  readonly encoding?: Encoding;
  readonly collation?: Collation;
  readonly semantics?: ColumnSemantics;
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
export type CheckComparison = "lt" | "lte" | "eq" | "gte" | "gt" | "neq";
export type CheckAtom =
  | {
      readonly kind: "compareLiteral";
      readonly column: bigint;
      readonly op: CheckComparison;
      readonly literal: Atom;
    }
  | {
      readonly kind: "compareColumns";
      readonly left: bigint;
      readonly op: CheckComparison;
      readonly right: bigint;
    }
  | { readonly kind: "isNull" | "isNotNull"; readonly column: bigint };
export interface CheckConstraint {
  readonly id: number;
  readonly name: string;
  readonly atoms: readonly CheckAtom[];
  readonly validated: boolean;
}
export type ReferentialAction = "restrict" | "no_action" | "cascade" | "set_null";
export interface ForeignKeyConstraint {
  readonly id: number;
  readonly name: string;
  readonly localColumns: readonly bigint[];
  readonly targetDefinition: Interpretation;
  readonly targetSchemaRevision: bigint;
  readonly targetColumns: readonly bigint[];
  readonly onDelete: ReferentialAction;
  readonly onUpdate: ReferentialAction;
  readonly enforcement: "staged_awaiting_index";
}
export interface TableIntegrity {
  readonly nextId: number;
  readonly checks: readonly CheckConstraint[];
  readonly foreignKeys: readonly ForeignKeyConstraint[];
}
type NativeIntegrity = NonNullable<NativeSchema["integrity"]>;
function integrityWire(value: TableIntegrity): NativeIntegrity {
  if (value.checks.length + value.foreignKeys.length > 64)
    throw new TypeError("Too many Table constraints");
  return {
    next_id: integer(value.nextId, "constraint identity", 1, 0xffffffff),
    checks: (value.checks ?? []).map((check) => {
      if (!check.atoms.length || check.atoms.length > 32)
        throw new TypeError("Invalid CHECK atom count");
      return {
        id: integer(check.id, "constraint identity", 1, 0xffffffff),
        name: name(check.name),
        validated: check.validated,
        atoms: check.atoms.map((atom) => {
          if (atom.kind === "compareLiteral")
            return {
              compare_literal: {
                column: positive(atom.column).toString(),
                op: atom.op,
                literal: { value: { atom: encodeAtom(atom.literal) } },
              },
            };
          if (atom.kind === "compareColumns")
            return {
              compare_columns: {
                left_column: positive(atom.left).toString(),
                op: atom.op,
                right_column: positive(atom.right).toString(),
              },
            };
          return atom.kind === "isNull"
            ? { is_null: positive(atom.column).toString() }
            : { is_not_null: positive(atom.column).toString() };
        }),
      };
    }),
    foreign_keys: value.foreignKeys.map((fk) => {
      const d = fk.targetDefinition,
        o = d.object,
        s = scope(o.scope);
      if (fk.enforcement !== "staged_awaiting_index")
        throw new TypeError("Foreign-key enforcement is unavailable");
      if (
        !fk.localColumns.length ||
        fk.localColumns.length > 128 ||
        fk.localColumns.length !== fk.targetColumns.length
      )
        throw new TypeError("Invalid foreign-key column count");
      return {
        id: integer(fk.id, "constraint identity", 1, 0xffffffff),
        name: name(fk.name),
        local_columns: fk.localColumns.map((v) => positive(v).toString()),
        target_object: positive(o.objectId).toString(),
        target_revision: positive(fk.targetSchemaRevision).toString(),
        target_columns: fk.targetColumns.map((v) => positive(v).toString()),
        target_definition: {
          realm: s.realm.toString(),
          resource: s.resource.toString(),
          catalog: s.catalog,
          branch: positive(o.branch).toString(),
          object: positive(o.objectId).toString(),
          revision: positive(d.revision).toString(),
          digest: digest(d.digest),
        },
        on_delete: fk.onDelete,
        on_update: fk.onUpdate,
        enforcement: fk.enforcement,
      };
    }),
  };
}
function integrity(value: NativeIntegrity): TableIntegrity {
  return Object.freeze({
    nextId: value.next_id ?? 1,
    checks: Object.freeze(
      (value.checks ?? []).map((check) =>
        Object.freeze({
          id: check.id,
          name: check.name,
          validated: check.validated,
          atoms: Object.freeze(
            check.atoms.map((atom): CheckAtom => {
              if ("compare_literal" in atom) {
                const c = atom.compare_literal,
                  cell = decodeCell(c.literal);
                if (cell.state !== "value" || cell.value.kind !== "atom")
                  throw new IncompatibleNative("Invalid CHECK literal");
                return Object.freeze({
                  kind: "compareLiteral",
                  column: nativeWide(c.column),
                  op: c.op,
                  literal: cell.value.atom,
                });
              }
              if ("compare_columns" in atom)
                return Object.freeze({
                  kind: "compareColumns",
                  left: nativeWide(atom.compare_columns.left_column),
                  op: atom.compare_columns.op,
                  right: nativeWide(atom.compare_columns.right_column),
                });
              return Object.freeze(
                "is_null" in atom
                  ? { kind: "isNull", column: nativeWide(atom.is_null) }
                  : { kind: "isNotNull", column: nativeWide(atom.is_not_null) },
              );
            }),
          ),
        }),
      ),
    ),
    foreignKeys: Object.freeze(
      (value.foreign_keys ?? []).map((fk): ForeignKeyConstraint => {
        const d = fk.target_definition;
        if (fk.enforcement !== "staged_awaiting_index" || d.object !== fk.target_object)
          throw new IncompatibleNative("Invalid staged foreign key");
        return Object.freeze({
          id: fk.id,
          name: fk.name,
          localColumns: Object.freeze(fk.local_columns.map(nativeWide)),
          targetSchemaRevision: nativeWide(fk.target_revision),
          targetColumns: Object.freeze(fk.target_columns.map(nativeWide)),
          targetDefinition: Object.freeze({
            object: Object.freeze({
              scope: new Scope(
                new ResourceRef(Number(nativeWide(d.realm)), Number(nativeWide(d.resource))),
                nativeWide(d.catalog),
              ),
              branch: nativeWide(d.branch),
              objectId: nativeWide(d.object),
            }),
            revision: nativeWide(d.revision),
            digest: digest(d.digest),
          }),
          onDelete: fk.on_delete,
          onUpdate: fk.on_update,
          enforcement: fk.enforcement,
        });
      }),
    ),
  });
}

export class Schema {
  readonly objectId: bigint;
  readonly revision: bigint;
  readonly nextColumn: bigint;
  get integrity(): TableIntegrity {
    return integrity(schemaWire(this).integrity!);
  }
  constructor(
    objectId: bigint,
    revision: bigint,
    nextColumn: bigint,
    columns: readonly Column[],
    primaryKey: readonly bigint[] = [],
    constraints: TableIntegrity = { nextId: 1, checks: [], foreignKeys: [] },
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
      integrity: budget.take(integrityWire(constraints)),
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
          semantics: semanticsWire(column.semantics),
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
      semantics: semanticsValue(column.semantics),
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
    semantics: semanticsValue(column.semantics),
    ...(column.default === null ? {} : { default: decodeCell(column.default) }),
    ...(column.max_characters === null ? {} : { maxCharacters: column.max_characters }),
  }));
  return new Schema(
    nativeWide(value.object),
    nativeWide(value.revision),
    nativeWide(value.next_column),
    columns,
    value.primary_key.map((value) => nativeWide(value)),
    integrity(value.integrity ?? {}),
  );
}

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
  | { readonly kind: "integrity"; readonly schema: Schema }
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
      readonly semantics?: ColumnSemantics;
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
  | {
      readonly kind: "mutate";
      readonly basis: Basis;
      readonly mutation: Mutation;
      readonly ingestion?: "point" | "bulk";
    };
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
        case "integrity":
          change = { integrity: schemaWire(item.schema) };
          break;
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
              semantics: semanticsWire(item.column.semantics),
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
              semantics: item.semantics === undefined ? null : semanticsWire(item.semantics),
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
      return {
        mutate: {
          basis: basis(value.basis),
          mutation: mutationWire(value.mutation),
          ingestion: value.ingestion ?? "point",
        },
      };
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

const savedValues = new WeakMap<SavedIntent, string>();
/** Persist before staging. Restoration does not resolve names or submit work. */
export class SavedIntent {
  private constructor(value: Action<"load">) {
    savedValues.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): SavedIntent {
    return new SavedIntent(checked<Action<"load">>(parseSaved(input), (load) => ({ load })));
  }
  save(): string {
    return savedValue(this);
  }
}
function savedValue(value: SavedIntent): string {
  const found = savedValues.get(value);
  if (found === undefined) throw new TypeError("Expected saved immutable catalog work");
  return found;
}
const references = new WeakMap<Reference, string>();
/** Complete durable recovery binding. A local loaded-work digest is not this reference. */
export class Reference {
  readonly kind: "table" | "name_assertion";
  readonly operation: bigint;
  readonly namespace: number;
  private constructor(value: Action<"admit">) {
    this.kind = "table" in value ? "table" : "name_assertion";
    this.operation = nativeWide(
      "table" in value ? value.table.binding.identity.operation : value.name_assertion.operation,
    );
    this.namespace = "table" in value ? value.table.namespace : value.name_assertion.namespace;
    references.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): Reference {
    return new Reference(checked<Action<"admit">>(parseSaved(input), (admit) => ({ admit })));
  }
  save(): string {
    return referenceValue(this);
  }
}
function referenceValue(value: Reference): string {
  const found = references.get(value);
  if (found === undefined) throw new TypeError("Expected original recovery reference");
  return found;
}
function reference(value: Reference): Action<"admit"> {
  return JSON.parse(referenceValue(value)) as Action<"admit">;
}
export interface Intent {
  readonly digest: string;
  readonly namespace: number;
  readonly operation: bigint;
  readonly kind: "table" | "name_assertion";
  readonly saved: SavedIntent;
}
const intents = new WeakMap<Intent, Result<"loaded">>();
function localIntent(value: Result<"loaded">, saved: SavedIntent): Intent {
  definition(value.id.definition);
  const result: Intent = Object.freeze({
    digest: digest(value.id.digest),
    namespace: value.namespace,
    operation: nativeWide(
      "table" in value.binding
        ? value.binding.table.identity.operation
        : value.binding.name_assertion.operation,
    ),
    kind: "table" in value.binding ? "table" : "name_assertion",
    saved,
  });
  intents.set(result, structuredClone(value));
  return result;
}
function localId(value: Intent): Action<"forget"> {
  const found = intents.get(value);
  if (!found) throw new TypeError("Expected work loaded by a catalog caller");
  return structuredClone(found.id);
}
export interface Compiled {
  readonly intent: Intent;
  readonly saved: SavedIntent;
}
function compiled(value: Result<"compiled">): Compiled {
  const saved = SavedIntent.restore(JSON.stringify(value.saved));
  return Object.freeze({ intent: localIntent(value.summary, saved), saved });
}
export interface Commit {
  readonly definition: StoredDefinition;
  readonly position: Position;
  readonly matched: bigint;
  readonly affected: bigint;
  readonly liveRows: bigint;
}
function commit(value: NativeEvidence): Commit {
  return Object.freeze({
    definition: stored(value.resulting),
    position: position(value.outcome.position),
    matched: nativeWide(value.outcome.matched),
    affected: nativeWide(value.outcome.affected),
    liveRows: nativeWide(value.outcome.live_rows),
  });
}
type NativeRowState = Extract<NativeObservation, { rows: unknown }>["rows"];
type NativeDdlState = Extract<NativeObservation, { ddl: unknown }>["ddl"];
type RowProgress = Extract<NativeRowState, { admitted: unknown }>["admitted"];
type DdlProgress = Extract<NativeDdlState, { admitted: unknown }>["admitted"];
type AssertionOutcome = Extract<
  Extract<NativeObservation, { name_assertion: unknown }>["name_assertion"],
  { outcome: unknown }
>["outcome"];
export type Observation =
  | {
      readonly kind: "table" | "name_assertion";
      readonly state: "not_observed";
      readonly reference: Reference;
    }
  | {
      readonly kind: "table";
      readonly state: "committed" | "finalizing";
      readonly reference: Reference;
      readonly commit: Commit;
    }
  | {
      readonly kind: "table";
      readonly state: "admitted" | "rejected" | "cancelled";
      readonly reference: Reference;
      readonly phase: RowProgress["phase"] | DdlProgress["phase"];
      readonly reason: RowProgress["reason"] | DdlProgress["reason"];
    }
  | {
      readonly kind: "name_assertion";
      readonly state: AssertionOutcome["state"];
      readonly reference: Reference;
      readonly reason: AssertionOutcome["reason"];
      readonly position: Position;
    };
function observation(value: NativeObservation, original: Reference): Observation {
  const selected = reference(original);
  if (
    "table" in selected &&
    ["insert", "update", "delete"].includes(selected.table.binding.action) !== "rows" in value
  )
    throw new IncompatibleNative("Observation changed the Table operation kind");
  const actual =
    "name_assertion" in value ? value.name_assertion : "rows" in value ? value.rows : value.ddl;
  if (!("not_observed" in actual)) {
    const record = (
      "finalizing" in actual ? actual.finalizing.evidence : Object.values(actual)[0]
    ) as { binding: unknown };
    const expected = "table" in selected ? selected.table.binding : selected.name_assertion;
    if (!isDeepStrictEqual(record.binding, expected))
      throw new IncompatibleNative("Observation changed the original operation binding");
  }
  if ("name_assertion" in value !== (original.kind === "name_assertion"))
    throw new IncompatibleNative("Observation changed the operation kind");
  if ("name_assertion" in value) {
    if ("not_observed" in value.name_assertion)
      return Object.freeze({ kind: "name_assertion", state: "not_observed", reference: original });
    const found = value.name_assertion.outcome;
    return Object.freeze({
      kind: "name_assertion",
      state: found.state,
      reference: original,
      reason: found.reason,
      position: position(found.position),
    });
  }
  const found = "rows" in value ? value.rows : value.ddl;
  if ("not_observed" in found)
    return Object.freeze({ kind: "table", state: "not_observed", reference: original });
  if ("finalizing" in found) {
    if (
      !found.finalizing.operation.requires_settlement ||
      !["admitted", "ready"].includes(found.finalizing.operation.phase)
    )
      throw new IncompatibleNative("Invalid finalizing operation phase");
    if (!isDeepStrictEqual(found.finalizing.operation.binding, found.finalizing.evidence.binding))
      throw new IncompatibleNative("Changed finalizing operation binding");
    return Object.freeze({
      kind: "table",
      state: "finalizing",
      reference: original,
      commit: commit(found.finalizing.evidence),
    });
  }
  if ("committed" in found)
    return Object.freeze({
      kind: "table",
      state: "committed",
      reference: original,
      commit: commit(found.committed),
    });
  if ("admitted" in found)
    return Object.freeze({
      kind: "table",
      state: "admitted",
      reference: original,
      phase: found.admitted.phase,
      reason: found.admitted.reason,
    });
  if ("rejected" in found)
    return Object.freeze({
      kind: "table",
      state: "rejected",
      reference: original,
      phase: found.rejected.phase,
      reason: found.rejected.reason,
    });
  return Object.freeze({
    kind: "table",
    state: "cancelled",
    reference: original,
    phase: found.cancelled.phase,
    reason: found.cancelled.reason,
  });
}
type NativePreview = Result<"preview">;
type PreviewCurrent = NonNullable<Extract<NativePreview, { ddl: unknown }>["ddl"]["current"]>;
export interface CurrentBasis {
  readonly definition: StoredDefinition;
  readonly position: Position;
  readonly changedLsn: bigint;
  readonly rowCount: bigint;
}
function currentBasis(value: PreviewCurrent): CurrentBasis {
  return Object.freeze({
    definition: stored(value.interpretation),
    position: position(value.position),
    changedLsn: nativeWide(value.changed_lsn),
    rowCount: nativeWide(value.row_count),
  });
}
export type Preview =
  | {
      readonly kind: "ddl";
      readonly intent: Intent;
      readonly directoryPosition: Position;
      readonly current?: CurrentBasis;
      readonly reason: Extract<NativePreview, { ddl: unknown }>["ddl"]["reason"];
      readonly work?: "metadata" | "validate_rows" | "rewrite_rows";
      readonly rebuildKey: boolean;
      readonly schemaFingerprint?: string;
    }
  | {
      readonly kind: "rows";
      readonly intent: Intent;
      readonly directoryPosition: Position;
      readonly current: CurrentBasis;
      readonly reason: Extract<NativePreview, { rows: unknown }>["rows"]["reason"];
    }
  | {
      readonly kind: "name_assertion";
      readonly intent: Intent;
      readonly position: Position;
      readonly current?: Interpretation;
      readonly matches: boolean;
    };
function preview(value: NativePreview, intent: Intent): Preview {
  const selected = intents.get(intent);
  if (!selected) throw new TypeError("Expected loaded catalog work");
  const expected =
    "table" in selected.binding ? selected.binding.table : selected.binding.name_assertion;
  const actual =
    "ddl" in value
      ? value.ddl.binding
      : "rows" in value
        ? value.rows.binding
        : value.name_assertion.binding;
  if (
    !isDeepStrictEqual(actual, expected) ||
    "name_assertion" in value !== (intent.kind === "name_assertion")
  )
    throw new IncompatibleNative("Preview changed the original operation binding");
  if ("ddl" in value)
    return Object.freeze({
      kind: "ddl",
      intent,
      directoryPosition: position(value.ddl.directory_position),
      ...(value.ddl.current === null ? {} : { current: currentBasis(value.ddl.current) }),
      reason: value.ddl.reason,
      ...(value.ddl.work === null ? {} : { work: value.ddl.work }),
      rebuildKey: value.ddl.rebuild_key,
      ...(value.ddl.schema_fingerprint === null
        ? {}
        : { schemaFingerprint: digest(value.ddl.schema_fingerprint) }),
    });
  if ("rows" in value)
    return Object.freeze({
      kind: "rows",
      intent,
      directoryPosition: position(value.rows.directory_position),
      current: currentBasis(value.rows.current),
      reason: value.rows.reason,
    });
  return Object.freeze({
    kind: "name_assertion",
    intent,
    position: position(value.name_assertion.position),
    matches: value.name_assertion.matches,
    ...(value.name_assertion.current === null
      ? {}
      : { current: interpretation(value.name_assertion.current) }),
  });
}
type RetentionAction = Action<"retention">;
type RetentionResult = Result<"retention">;
type RetentionInput<K extends PropertyKey> = Extract<RetentionAction, Record<K, unknown>>[K];
type RetentionOutput<K extends PropertyKey> = Extract<RetentionResult, Record<K, unknown>>[K];
const snapshotOwners = new WeakMap<SnapshotOwner, string>();
const acquisitions = new WeakMap<SnapshotAcquisition, string>();
const snapshots = new WeakMap<Snapshot, string>();
export class SnapshotOwner {
  readonly operation: bigint;
  private constructor(value: RetentionInput<"status">) {
    this.operation = nativeWide(value.operation);
    snapshotOwners.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): SnapshotOwner {
    return new SnapshotOwner(
      checked<RetentionInput<"status">>(parseSaved(input), (status) => ({ retention: { status } })),
    );
  }
  save(): string {
    const value = snapshotOwners.get(this);
    if (value === undefined) throw new TypeError("Expected original snapshot owner");
    return value;
  }
}
/** Persist before acquireSnapshot; the expected frontier is exact. */
export class SnapshotAcquisition {
  readonly owner: SnapshotOwner;
  readonly expected: Position;
  private constructor(value: RetentionInput<"acquire">) {
    this.owner = SnapshotOwner.restore(JSON.stringify(value.owner));
    this.expected = position(value.expected);
    acquisitions.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): SnapshotAcquisition {
    return new SnapshotAcquisition(
      checked<RetentionInput<"acquire">>(parseSaved(input), (acquire) => ({
        retention: { acquire },
      })),
    );
  }
  save(): string {
    const value = acquisitions.get(this);
    if (value === undefined) throw new TypeError("Expected saved snapshot acquisition");
    return value;
  }
}
/** A durable retention reference. Local disposal does not release its owner. */
export class Snapshot {
  readonly owner: SnapshotOwner;
  readonly contentBytes: bigint;
  readonly contentDigest: string;
  private constructor(value: RetentionInput<"metadata">) {
    this.owner = SnapshotOwner.restore(JSON.stringify(value.owner));
    this.contentBytes = nativeWide(value.content.bytes);
    this.contentDigest = digest(value.content.sha256);
    snapshots.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): Snapshot {
    return new Snapshot(
      checked<RetentionInput<"metadata">>(parseSaved(input), (metadata) => ({
        retention: { metadata },
      })),
    );
  }
  save(): string {
    const value = snapshots.get(this);
    if (value === undefined) throw new TypeError("Expected retained snapshot reference");
    return value;
  }
}
export interface ReadAuthority {
  readonly database: number;
  readonly schema: number;
  readonly table: number;
}
export interface SnapshotStatus {
  readonly owner: SnapshotOwner;
  readonly currentInterpretation: Interpretation;
  readonly currentPosition: Position;
  readonly retired: boolean;
  readonly snapshot?: Snapshot;
  readonly released: boolean;
  readonly authority: ReadAuthority;
}
export interface SnapshotMetadata {
  readonly snapshot: Snapshot;
  readonly definition: StoredDefinition;
  readonly accepted: Position;
  readonly changedLsn: bigint;
  readonly rowCount: bigint;
  readonly schema: Schema;
  readonly authority: ReadAuthority;
}
function retentionField<K extends Tags<RetentionResult>>(
  value: CatalogResult,
  key: K,
): RetentionOutput<K> {
  const result = field(value, "retention");
  if (!(key in result)) throw new IncompatibleNative("Unexpected snapshot retention result");
  return (result as Extract<RetentionResult, Record<K, unknown>>)[key];
}
type HistoryAction = Action<"history">;
type HistoryResult = Result<"history">;
type HistoryInput<K extends PropertyKey> = Extract<HistoryAction, Record<K, unknown>>[K];
type HistoryOutput<K extends PropertyKey> = Extract<HistoryResult, Record<K, unknown>>[K];
type NativeHistoryStatus = NonNullable<HistoryOutput<"status">>;
type NativeHistorySnapshot = NonNullable<NativeHistoryStatus["snapshot"]>;
export interface HistoryContent {
  readonly bytes: bigint;
  readonly digest: string;
}
export interface HistoryOperation {
  readonly scope: Scope;
  readonly principal: number;
  readonly operation: bigint;
}
export interface HistoryDirectory {
  readonly content: HistoryContent;
  readonly count: bigint;
}
export interface HistoryCommonCut {
  readonly transaction: HistoryOperation;
  readonly acquired: Position;
  readonly sources: HistoryContent;
  readonly sourceCount: bigint;
}
export interface HistoryBudget {
  readonly operations: bigint;
  readonly bytes: bigint;
  readonly pending: bigint;
  readonly chargeBytes: bigint;
}
const historySaved = new WeakMap<object, string>();
function savedHistory(value: object): string {
  const saved = historySaved.get(value);
  if (saved === undefined) throw new TypeError("Expected an owned historical catalog value");
  return saved;
}
function historyContent(value: NativeHistorySnapshot["catalog_root"]): HistoryContent {
  return Object.freeze({ bytes: nativeWide(value.bytes), digest: digest(value.sha256) });
}
function historyOperation(value: NativeHistorySnapshot["owner"]): HistoryOperation {
  return Object.freeze({
    scope: fromScope(value.scope),
    principal: value.principal,
    operation: nativeWide(value.operation),
  });
}
function historyDirectory(
  value: NonNullable<HistoryOutput<"selection">["directory"]>,
): HistoryDirectory {
  return Object.freeze({ content: historyContent(value.content), count: nativeWide(value.count) });
}
function historyCut(
  value: NonNullable<HistoryInput<"acquire">["intent"]["common"]>["cut"],
): HistoryCommonCut {
  return Object.freeze({
    transaction: historyOperation(value.transaction),
    acquired: position(value.acquired),
    sources: historyContent(value.sources),
    sourceCount: nativeWide(value.source_count),
  });
}
/** A selected immutable directory; selection alone does not retain data. */
export class HistorySelection {
  readonly owner: HistoryOperation;
  readonly branch: bigint;
  readonly directory: HistoryDirectory | undefined;
  private constructor(value: HistoryOutput<"selection">) {
    definition(value.definition);
    this.owner = historyOperation(value.owner);
    this.branch = nativeWide(value.branch);
    this.directory = value.directory === null ? undefined : historyDirectory(value.directory);
    historySaved.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): HistorySelection {
    return new HistorySelection(
      checked<HistoryOutput<"selection">>(parseSaved(input), (selection) => ({
        history: { select: { selection, namespace: 1, name: "validation" } },
      })),
    );
  }
  save(): string {
    return savedHistory(this);
  }
}
/** Original account/token and connection; this is attribution, never authority. */
export class HistoryKey {
  readonly account: string;
  readonly token: string;
  private constructor(value: HistoryInput<"inspect">) {
    definition(value.definition);
    this.account = digest(value.account);
    if (!/^[0-9a-f]{32}$/.test(value.token)) throw new IncompatibleNative("Invalid history token");
    this.token = value.token;
    historySaved.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): HistoryKey {
    return new HistoryKey(
      checked<HistoryInput<"inspect">>(parseSaved(input), (inspect) => ({ history: { inspect } })),
    );
  }
  save(): string {
    return savedHistory(this);
  }
}
/** Save before dispatch. An uncertain selection may be retried, but is not acceptance. */
export class HistorySelectionStep {
  readonly selection: HistorySelection;
  readonly namespace: number;
  readonly name: string;
  private constructor(value: HistoryInput<"select">) {
    this.selection = HistorySelection.restore(JSON.stringify(value.selection));
    this.namespace = value.namespace;
    this.name = name(value.name);
    historySaved.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): HistorySelectionStep {
    return new HistorySelectionStep(
      checked<HistoryInput<"select">>(parseSaved(input), (select) => ({ history: { select } })),
    );
  }
  save(): string {
    return savedHistory(this);
  }
}
/** Complete acquisition input, including frozen selection, budget and optional common cut. */
export class HistoryAcquisition {
  readonly key: HistoryKey;
  readonly operation: bigint;
  readonly namespace: number;
  readonly selection: HistoryDirectory;
  readonly common: HistoryCommonCut | undefined;
  readonly commonKey: HistoryKey | undefined;
  private constructor(value: HistoryInput<"acquire">) {
    definition(value.intent.definition);
    this.key = HistoryKey.restore(JSON.stringify(value.key));
    if (!isDeepStrictEqual(value.key.connection, value.intent.connection))
      throw new IncompatibleNative("Foreign historical acquisition connection");
    this.operation = nativeWide(value.intent.operation);
    this.namespace = value.intent.namespace;
    this.selection = historyDirectory(value.intent.selection);
    this.common = value.intent.common === null ? undefined : historyCut(value.intent.common.cut);
    this.commonKey =
      value.intent.common === null
        ? undefined
        : HistoryKey.restore(JSON.stringify(value.intent.common.key));
    historySaved.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): HistoryAcquisition {
    return new HistoryAcquisition(
      checked<HistoryInput<"acquire">>(parseSaved(input), (acquire) => ({ history: { acquire } })),
    );
  }
  save(): string {
    return savedHistory(this);
  }
}
/** Exact bounded control action, preserved if its outcome is uncertain. */
export class HistoryControl {
  readonly key: HistoryKey;
  readonly command: "advance" | "abandon" | "release";
  private constructor(value: HistoryAction) {
    if ("advance" in value) {
      this.command = "advance";
      this.key = HistoryKey.restore(JSON.stringify(value.advance));
    } else if ("abandon" in value) {
      this.command = "abandon";
      this.key = HistoryKey.restore(JSON.stringify(value.abandon));
    } else if ("release" in value) {
      this.command = "release";
      this.key = HistoryKey.restore(JSON.stringify(value.release));
    } else throw new IncompatibleNative("Expected a historical control action");
    historySaved.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): HistoryControl {
    return new HistoryControl(
      checked<HistoryAction>(parseSaved(input), (history) => ({ history })),
    );
  }
  save(): string {
    return savedHistory(this);
  }
}
/** Opaque selector. The shared owner validates compatibility and retained coverage on every call. */
export class HistoricalSnapshot {
  readonly selector: string;
  constructor(selector: string) {
    text(selector, 594);
    if (!/^[0-9a-f]{594}$/.test(selector))
      throw new TypeError("Expected a canonical historical selector");
    this.selector = selector;
    Object.freeze(this);
  }
  static restore(input: string): HistoricalSnapshot {
    const value = parseSaved(input);
    if (
      typeof value !== "object" ||
      value === null ||
      Object.keys(value).length !== 1 ||
      !("selector" in value) ||
      typeof value.selector !== "string"
    )
      throw new IncompatibleNative("Invalid saved historical selector");
    return new HistoricalSnapshot(value.selector);
  }
  save(): string {
    return JSON.stringify({ selector: this.selector });
  }
}
export interface HistoryBasis {
  readonly definition: string;
  readonly snapshot: HistoricalSnapshot;
  readonly owner: HistoryOperation;
  readonly branch: bigint;
  readonly catalogRoot: HistoryContent;
  readonly sourcesRoot: HistoryContent;
  readonly sourceCount: bigint;
  readonly consistency:
    | { readonly kind: "single_partition"; readonly position: Position }
    | { readonly kind: "independent" }
    | { readonly kind: "common_transaction"; readonly cut: HistoryCommonCut };
}
function historyBasis(value: NativeHistorySnapshot, selected?: HistoricalSnapshot): HistoryBasis {
  definition(value.definition);
  if (selected && value.selector !== selected.selector)
    throw new IncompatibleNative("Changed historical snapshot");
  return Object.freeze({
    definition: value.definition,
    snapshot: selected ?? new HistoricalSnapshot(value.selector),
    owner: historyOperation(value.owner),
    branch: nativeWide(value.branch),
    catalogRoot: historyContent(value.catalog_root),
    sourcesRoot: historyContent(value.sources_root),
    sourceCount: nativeWide(value.source_count),
    consistency: Object.freeze(
      "independent" in value.consistency
        ? { kind: "independent" as const }
        : "single_partition" in value.consistency
          ? {
              kind: "single_partition" as const,
              position: position(value.consistency.single_partition),
            }
          : {
              kind: "common_transaction" as const,
              cut: historyCut(value.consistency.common_transaction),
            },
    ),
  });
}
export interface HistoryIntent {
  readonly operation: bigint;
  readonly namespace: number;
  readonly selection: HistoryDirectory;
  readonly common?: { readonly key: HistoryKey; readonly cut: HistoryCommonCut };
}
export interface HistoryStatus {
  readonly key: HistoryKey;
  readonly intent: HistoryIntent;
  readonly admitted: Position;
  readonly revision: Position;
  readonly phase:
    | "acquiring"
    | "verifying"
    | "published"
    | "abandoning"
    | "cancelled"
    | "releasing"
    | "released";
  readonly retained: HistoryDirectory | undefined;
  readonly after: bigint | undefined;
  readonly inflight: bigint | undefined;
  readonly verifiedAfter: bigint | undefined;
  readonly policyEpoch: bigint | undefined;
  readonly releasedAfter: bigint | undefined;
  readonly basis: HistoryBasis | undefined;
}
function historyStatus(
  value: HistoryOutput<"status">,
  key: HistoryKey,
  original?: HistoryAcquisition,
): HistoryStatus | undefined {
  if (value === null) return undefined;
  if (
    !isDeepStrictEqual(value.key, JSON.parse(key.save())) ||
    (original &&
      !isDeepStrictEqual(
        value.intent,
        (JSON.parse(original.save()) as HistoryInput<"acquire">).intent,
      ))
  )
    throw new IncompatibleNative("Changed original historical acquisition");
  definition(value.intent.definition);
  if (!isDeepStrictEqual(value.intent.connection, value.key.connection))
    throw new IncompatibleNative("Changed history intent connection");
  const intent: HistoryIntent = Object.freeze({
    operation: nativeWide(value.intent.operation),
    namespace: value.intent.namespace,
    selection: historyDirectory(value.intent.selection),
    ...(value.intent.common === null
      ? {}
      : {
          common: Object.freeze({
            key: HistoryKey.restore(JSON.stringify(value.intent.common.key)),
            cut: historyCut(value.intent.common.cut),
          }),
        }),
  });
  const published =
    value.phase === "published" || value.phase === "releasing" || value.phase === "released";
  if (published !== (value.snapshot !== null))
    throw new IncompatibleNative("Missing or premature history publication");
  if (value.snapshot !== null) {
    const snapshot = value.snapshot;
    const common = value.intent.common;
    if (
      !isDeepStrictEqual(snapshot.owner.scope, value.key.connection.scope) ||
      snapshot.owner.principal !== value.key.connection.principal ||
      snapshot.owner.operation !== value.intent.operation ||
      snapshot.branch !== value.key.connection.branch ||
      snapshot.source_count !== value.intent.selection.count ||
      !isDeepStrictEqual(snapshot.catalog_root, value.intent.selection.content) ||
      (common !== null
        ? !("common_transaction" in snapshot.consistency) ||
          !isDeepStrictEqual(snapshot.consistency.common_transaction, common.cut)
        : "common_transaction" in snapshot.consistency)
    )
      throw new IncompatibleNative("Changed published history basis");
  }
  const optional = (v: string | null): bigint | undefined =>
    v === null ? undefined : nativeWide(v);
  return Object.freeze({
    key,
    intent,
    admitted: position(value.admitted),
    revision: position(value.revision),
    phase: value.phase,
    retained: value.retained === null ? undefined : historyDirectory(value.retained),
    after: optional(value.after),
    inflight: optional(value.inflight),
    verifiedAfter: optional(value.verified_after),
    policyEpoch: optional(value.policy_epoch),
    releasedAfter: optional(value.released_after),
    basis: value.snapshot === null ? undefined : historyBasis(value.snapshot),
  });
}
export interface HistoryNamespace {
  readonly scope: Scope;
  readonly id: number;
  readonly authorization: number;
  readonly name: string;
  readonly revision: bigint;
}
function historyNamespace(value: NonNullable<HistoryOutput<"namespace">>): HistoryNamespace {
  return Object.freeze({
    scope: fromScope(value.scope),
    id: value.id,
    authorization: value.authorization,
    name: value.name,
    revision: nativeWide(value.revision),
  });
}
export interface HistoryEntry {
  readonly namespace: HistoryNamespace;
  readonly name: string;
  readonly definition: StoredDefinition;
  readonly accepted: Position;
  readonly catalog: Position;
}
function historyEntry(value: HistoryOutput<"listing">["entries"][number]): HistoryEntry {
  return Object.freeze({
    namespace: historyNamespace(value.namespace),
    name: value.name,
    definition: stored(value.declaration),
    accepted: position(value.accepted),
    catalog: position(value.catalog),
  });
}
export class HistoryCursor {
  readonly snapshot: HistoricalSnapshot;
  readonly namespace: number;
  private constructor(value: NonNullable<HistoryInput<"list">["after"]>) {
    this.snapshot = new HistoricalSnapshot(value.selector);
    this.namespace = value.namespace;
    historyDirectory(value.directory);
    nativeWide(value.after);
    historySaved.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): HistoryCursor {
    return new HistoryCursor(
      checked<NonNullable<HistoryInput<"list">["after"]>>(parseSaved(input), (after) => ({
        history: { list: { selector: after?.selector, namespace: after?.namespace, after } },
      })),
    );
  }
  save(): string {
    return savedHistory(this);
  }
}
export interface HistoryPage {
  readonly basis: HistoryBasis;
  readonly namespace: number;
  readonly entries: readonly HistoryEntry[];
  readonly next?: HistoryCursor;
}
export interface HistorySource {
  readonly basis: HistoryBasis;
  readonly binding: HistoryEntry;
  readonly schema: Schema;
  readonly rowCount: bigint;
  readonly changedLsn: bigint;
  readonly authority: ReadAuthority;
}
export interface ProjectionColumn {
  readonly column: bigint;
  readonly source:
    | { readonly physical: bigint }
    | { readonly initial: { readonly definition: Interpretation; readonly state: string } };
}
export interface ProjectionDefinition {
  readonly physical: StoredDefinition;
  readonly schemaRevision: bigint;
  readonly rows: bigint;
  readonly columns: readonly ProjectionColumn[];
}
export interface ProjectionLocation {
  readonly origin: bigint;
  readonly operation: bigint;
  readonly ordinal: number;
  readonly physical: StoredDefinition;
  readonly schemaRevision: bigint;
  readonly location:
    | {
        readonly wal: {
          readonly lsn: bigint;
          readonly offset: number;
          readonly bytes: number;
          readonly rowDigest: string;
        };
      }
    | {
        readonly segment: {
          readonly id: bigint;
          readonly row: number;
          readonly contentBytes: bigint;
          readonly contentDigest: string;
        };
      };
}
export class HistoryCoverageCursor {
  readonly snapshot: HistoricalSnapshot;
  readonly objectId: bigint;
  readonly kind: "definitions" | "locations";
  private constructor(value: NonNullable<HistoryInput<"definitions">["after"]>) {
    this.snapshot = new HistoricalSnapshot(value.selector);
    this.objectId = positive(nativeWide(value.object));
    this.kind = value.kind;
    nativeWide(value.source.bytes);
    digest(value.source.sha256);
    if (value.kind === "definitions") positive(nativeWide(value.after));
    else if (!/^[0-9a-f]{40}$/.test(value.after))
      throw new IncompatibleNative("Invalid placement continuation");
    historySaved.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): HistoryCoverageCursor {
    return new HistoryCoverageCursor(
      checked<NonNullable<HistoryInput<"definitions">["after"]>>(parseSaved(input), (after) => ({
        history: { definitions: { selector: after?.selector, object: after?.object, after } },
      })),
    );
  }
  save(): string {
    return savedHistory(this);
  }
}
export interface HistoryCoverage {
  readonly basis: HistoryBasis;
  readonly logical: StoredDefinition;
  readonly accepted: Position;
  readonly totalRows: bigint;
  readonly definition?: ProjectionDefinition;
  readonly locations: readonly ProjectionLocation[];
  readonly next?: HistoryCoverageCursor;
}
function historyField<K extends Tags<HistoryResult>>(
  value: CatalogResult,
  key: K,
): HistoryOutput<K> {
  const result = field(value, "history");
  if (!(key in result)) throw new IncompatibleNative("Unexpected historical catalog result");
  return (result as Extract<HistoryResult, Record<K, unknown>>)[key];
}
function historyBudget(value?: HistoryBudget): HistoryInput<"acquire">["budget"] {
  return value === undefined
    ? { operations: "1000000", bytes: "4294967296", pending: "1024", charge_bytes: "4608" }
    : {
        operations: positive(value.operations).toString(),
        bytes: positive(value.bytes).toString(),
        pending: positive(value.pending).toString(),
        charge_bytes: positive(value.chargeBytes).toString(),
      };
}

export type Recovery =
  | SavedIntent
  | Reference
  | SnapshotAcquisition
  | Snapshot
  | HistorySelectionStep
  | HistoryAcquisition
  | HistoryControl;
export class Uncertain extends UnknownOutcome {
  readonly recovery: Recovery;
  constructor(recovery: Recovery, cause: UnknownOutcome) {
    super("Catalog outcome is uncertain; preserve the original saved work and recovery binding", {
      status: 6,
      ...(cause.code === undefined ? {} : { code: cause.code }),
      ...(cause.diagnostic === undefined ? {} : { diagnostic: cause.diagnostic }),
      diagnosticInvalid: cause.diagnosticInvalid,
      phase: cause.phase,
    });
    this.recovery = recovery;
  }
}
export interface CatalogClientConfig extends ClientConfig {
  readonly serviceUrl?: string;
}
export interface CompileOptions {
  readonly createObject?: bigint;
  readonly dialect?: "transit" | "mysql";
  readonly ingestion?: "point" | "bulk";
}
export interface Capabilities {
  readonly version: number;
  readonly definition: string;
  readonly maxColumns: number;
  readonly maxRows: number;
  readonly maxSqlBytes: number;
  readonly maxIntentBytes: number;
  readonly maxActionBytes: number;
  readonly metadataPageEntries: number;
  readonly residentIntents: number;
}
export interface AuthorityProfile {
  readonly databaseDomain: number;
  readonly schemaDomain: number;
  readonly tableDomain: number;
  readonly streamDomain: number;
  readonly queueDomain: number;
  readonly kvDomain: number;
  readonly database: number;
  readonly initialSchema: number;
  readonly initialSchemaAuthority: number;
}
export interface Configuration {
  readonly scope: Scope;
  readonly branch: bigint;
  readonly partition: bigint;
  readonly audience: number;
  readonly authority: AuthorityProfile;
  readonly databaseName: string;
  readonly initialSchemaName: string;
}
/** Observed authenticated identity; this value grants no authority. */
export interface Subject {
  readonly principal: number;
  readonly loginRole: number;
  readonly role: number;
  readonly credentialEpoch: number;
  readonly audience: number;
  readonly context: string;
}
export interface Description {
  readonly configuration: Configuration;
  readonly subject: Subject;
  readonly policyRevision: number;
}
export interface Namespace {
  readonly scope: Scope;
  readonly id: number;
  readonly authorization: number;
  readonly name: string;
  readonly revision: number;
  readonly retired: boolean;
}
function namespace(value: NonNullable<CatalogReadResult<"namespace">>): Namespace {
  return Object.freeze({
    scope: fromScope(value.scope),
    id: value.id,
    authorization: value.authorization,
    name: value.name,
    revision: value.revision,
    retired: value.retired,
  });
}
export interface Entry {
  readonly interpretation: Interpretation;
  readonly namespace: number;
  readonly name: string;
  readonly position: Position;
  readonly changedLsn: bigint;
}
type NativeCursor = NonNullable<CatalogReadResult<"namespaces">["next"]>;
const cursors = new WeakMap<Cursor, string>();
/** Save only with the original selection; a prefix is not a complete directory. */
export class Cursor {
  private constructor(value: NativeCursor) {
    cursors.set(this, JSON.stringify(value));
    Object.freeze(this);
  }
  static restore(input: string): Cursor {
    return new Cursor(
      checked<NativeCursor>(parseSaved(input), (namespaces) => ({ catalog: { namespaces } })),
    );
  }
  save(): string {
    const value = cursors.get(this);
    if (value === undefined) throw new TypeError("Expected catalog cursor");
    return value;
  }
}
function cursor(value?: Cursor): NativeCursor | null {
  return value === undefined ? null : (JSON.parse(value.save()) as NativeCursor);
}
export interface Page<T> {
  readonly entries: readonly T[];
  readonly next?: Cursor;
  readonly position: Position;
}
export interface TablePage extends Page<Entry> {
  readonly consistency: "independent";
}
function catalogField<K extends Tags<CatalogRead>>(
  value: CatalogResult,
  key: K,
): CatalogReadResult<K> {
  const read = field(value, "catalog");
  if (!(key in read)) throw new IncompatibleNative("Unexpected catalog inspection result");
  return (read as Extract<CatalogRead, Record<K, unknown>>)[key];
}
/** One direct caller. Every method is one explicit host action, without retry or settlement. */
export class Client {
  readonly #bridge: CatalogBridge;
  readonly #principal: number;
  readonly connection: Connection;
  private constructor(connection: Connection, principal: number, bridge: CatalogBridge) {
    this.connection = connection;
    this.#bridge = bridge;
    this.#principal = principal;
    Object.freeze(this);
  }
  static async open(
    input: CatalogClientConfig,
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
    const serviceUrl =
      input.serviceUrl === undefined
        ? null
        : text(configuration({ ...input, url: input.serviceUrl }).url, 2048);
    return new Client(
      connection,
      credential.principal,
      await CatalogBridge.open(
        text(config.url, 2048),
        credential.seedFile,
        {
          definition: currentDefinition,
          connection: {
            scope: scope(connection.scope),
            branch: connection.branch.toString(),
            audience: connection.audience,
            principal: credential.principal,
            role: connection.role ?? null,
          },
          timeout_ms: config.timeoutMs,
          service_url: serviceUrl,
        },
        config.nativeHost,
      ),
    );
  }
  async capabilities(): Promise<Capabilities> {
    const result = field(await this.#bridge.call({ catalog: { capabilities: {} } }), "catalog");
    if (!("capabilities" in result)) throw new IncompatibleNative("Expected catalog capabilities");
    const v = result.capabilities;
    return Object.freeze({
      version: v.version,
      definition: v.definition,
      maxColumns: v.max_columns,
      maxRows: v.max_rows,
      maxSqlBytes: v.max_sql_bytes,
      maxIntentBytes: v.max_intent_bytes,
      maxActionBytes: v.max_action_bytes,
      metadataPageEntries: v.metadata_page_entries,
      residentIntents: v.resident_intents,
    });
  }
  async describe(): Promise<Description> {
    const value = catalogField(
      await this.#bridge.call({ catalog: { describe: {} } }),
      "description",
    );
    const config = value.configuration;
    const authority = config.authority;
    const domains = [
      authority.database_domain,
      authority.schema_domain,
      authority.table_domain,
      authority.stream_domain,
      authority.queue_domain,
      authority.kv_domain,
    ];
    if (
      new Set(domains).size !== domains.length ||
      authority.database === authority.initial_schema_authority
    ) {
      throw new IncompatibleNative("Invalid catalog authority profile");
    }
    const subject = value.subject;
    return Object.freeze({
      configuration: Object.freeze({
        scope: fromScope(config.scope),
        branch: nativeWide(config.branch),
        partition: nativeWide(config.partition),
        audience: config.audience,
        databaseName: config.database_name,
        initialSchemaName: config.initial_schema_name,
        authority: Object.freeze({
          databaseDomain: authority.database_domain,
          schemaDomain: authority.schema_domain,
          tableDomain: authority.table_domain,
          streamDomain: authority.stream_domain,
          queueDomain: authority.queue_domain,
          kvDomain: authority.kv_domain,
          database: authority.database,
          initialSchema: authority.initial_schema,
          initialSchemaAuthority: authority.initial_schema_authority,
        }),
      }),
      subject: Object.freeze({
        principal: subject.principal,
        loginRole: subject.login_role,
        role: subject.role,
        credentialEpoch: subject.credential_epoch,
        audience: subject.audience,
        context: Buffer.from(subject.context).toString("hex"),
      }),
      policyRevision: value.policy_revision,
    });
  }
  async namespace(id: number): Promise<Namespace | undefined> {
    const value = catalogField(
      await this.#bridge.call({ catalog: { namespace: integer(id, "namespace") } }),
      "namespace",
    );
    return value === null ? undefined : namespace(value);
  }
  async namespaces(previous?: Cursor): Promise<Page<Namespace>> {
    const value = catalogField(
      await this.#bridge.call({ catalog: { namespaces: cursor(previous) } }),
      "namespaces",
    );
    return Object.freeze({
      entries: Object.freeze(value.entries.filter((item) => item !== null).map(namespace)),
      position: position(value.position),
      ...(value.next === null ? {} : { next: Cursor.restore(JSON.stringify(value.next)) }),
    });
  }
  async tables(namespaceId: number, previous?: Cursor): Promise<TablePage> {
    const value = catalogField(
      await this.#bridge.call({
        catalog: {
          tables: {
            namespace: integer(namespaceId, "namespace"),
            cursor: cursor(previous),
          },
        },
      }),
      "tables",
    );
    return Object.freeze({
      entries: Object.freeze(
        value.entries
          .filter((item) => item !== null)
          .map((item) =>
            Object.freeze({
              interpretation: interpretation(item.interpretation),
              namespace: item.namespace,
              name: item.name,
              position: position(item.position),
              changedLsn: nativeWide(item.changed_lsn),
            }),
          ),
      ),
      position: position(value.position),
      consistency: value.consistency,
      ...(value.next === null ? {} : { next: Cursor.restore(JSON.stringify(value.next)) }),
    });
  }
  async lookup(tableName: string, namespace = 1): Promise<Metadata | undefined> {
    const found = field(
      await this.#bridge.call({
        lookup: { namespace: integer(namespace, "namespace"), name: name(tableName) },
      }),
      "metadata",
    );
    if (found !== null) {
      const binding = found.binding;
      const expected = {
        scope: scope(this.connection.scope),
        branch: this.connection.branch.toString(),
        audience: this.connection.audience,
        principal: this.#principal,
        role: this.connection.role ?? null,
      };
      if (
        !isDeepStrictEqual(binding.connection, expected) ||
        binding.namespace !== namespace ||
        binding.name !== tableName ||
        found.schema.object !== binding.interpretation.interpretation.object.object
      )
        throw new IncompatibleNative(
          "Metadata changed the requested connection, name or stable Table identity",
        );
    }
    return found === null ? undefined : metadata(found);
  }
  async compileSql(sql: string, ids: Identity, options: CompileOptions = {}): Promise<Compiled> {
    if (!(ids instanceof Identity)) throw new TypeError("Expected operation identity");
    return this.compilation(
      field(
        await this.#bridge.call({
          compile: {
            namespace: ids.namespace,
            operation: ids.operation.toString(),
            create_object:
              options.createObject === undefined ? null : positive(options.createObject).toString(),
            sql: text(sql, 4096),
            dialect: options.dialect ?? "transit",
            ingestion: options.ingestion ?? "point",
          },
        }),
        "compiled",
      ),
      ids,
    );
  }
  async prepare(tableName: string, ids: Identity, action: Operation): Promise<Compiled> {
    if (!(ids instanceof Identity)) throw new TypeError("Expected operation identity");
    return this.compilation(
      field(
        await this.#bridge.call({
          prepare: {
            definition: currentDefinition,
            namespace: ids.namespace,
            operation: ids.operation.toString(),
            name: name(tableName),
            action: operation(action),
          },
        }),
        "compiled",
      ),
      ids,
    );
  }
  async load(saved: SavedIntent): Promise<Intent> {
    const load = JSON.parse(savedValue(saved)) as Action<"load">;
    return localIntent(field(await this.#bridge.call({ load }), "loaded"), saved);
  }
  async forget(intent: Intent): Promise<void> {
    field(await this.#bridge.call({ forget: localId(intent) }), "forgotten");
  }
  async preview(intent: Intent): Promise<Preview> {
    return preview(field(await this.#bridge.call({ preview: localId(intent) }), "preview"), intent);
  }
  async stage(intent: Intent): Promise<Reference> {
    return this.mutation({ stage: localId(intent) }, intent.saved, (result) => {
      const staged = field(result, "staged");
      const expected = intents.get(intent)!.binding;
      if (
        "table" in staged
          ? !("table" in expected) || !isDeepStrictEqual(staged.table.binding, expected.table)
          : !("name_assertion" in expected) ||
            !isDeepStrictEqual(staged.name_assertion, expected.name_assertion)
      )
        throw new IncompatibleNative("Staging changed the original operation binding");
      return Reference.restore(JSON.stringify(staged));
    });
  }
  async admit(original: Reference): Promise<Observation> {
    return this.mutation({ admit: reference(original) }, original, (result) =>
      observation(field(result, "observation"), original),
    );
  }
  async inspect(original: Reference): Promise<Observation> {
    return observation(
      field(
        await this.#bridge.call({
          operation: { reference: reference(original), command: "inspect", steps: 1 },
        }),
        "observation",
      ),
      original,
    );
  }
  async execute(original: Reference, steps: number): Promise<Observation> {
    return this.mutation(
      {
        operation: {
          reference: reference(original),
          command: "execute",
          steps: integer(steps, "step budget", 1, 65535),
        },
      },
      original,
      (result) => observation(field(result, "observation"), original),
    );
  }
  async cancel(original: Reference): Promise<Observation> {
    return this.mutation(
      { operation: { reference: reference(original), command: "cancel", steps: 1 } },
      original,
      (result) => observation(field(result, "observation"), original),
    );
  }
  prepareHistorySelection(operation: bigint): HistorySelection {
    return HistorySelection.restore(
      JSON.stringify({
        definition: currentDefinition,
        owner: {
          scope: scope(this.connection.scope),
          principal: this.#principal,
          operation: positive(operation).toString(),
        },
        branch: this.connection.branch.toString(),
        directory: null,
      }),
    );
  }
  prepareHistoryKey(account: Uint8Array, token: Uint8Array): HistoryKey {
    if (account.byteLength !== 32 || token.byteLength !== 16)
      throw new TypeError("Expected 32-byte account and 16-byte token");
    return HistoryKey.restore(
      JSON.stringify({
        definition: currentDefinition,
        connection: this.historyConnection(),
        account: hex(account, 32),
        token: hex(token, 16),
      }),
    );
  }
  prepareHistoryStep(
    selection: HistorySelection,
    namespace: number,
    selectedName: string,
  ): HistorySelectionStep {
    return HistorySelectionStep.restore(
      JSON.stringify({
        selection: JSON.parse(selection.save()),
        namespace: integer(namespace, "namespace"),
        name: name(selectedName),
      }),
    );
  }
  async selectHistory(original: HistorySelectionStep): Promise<HistorySelection> {
    const select = JSON.parse(original.save()) as HistoryInput<"select">;
    if (
      !isDeepStrictEqual(select.selection.owner.scope, scope(this.connection.scope)) ||
      select.selection.owner.principal !== this.#principal ||
      select.selection.branch !== this.connection.branch.toString()
    )
      throw new TypeError("Foreign history selection");
    return this.mutation({ history: { select } }, original, (result) => {
      const selected = historyField(result, "selection");
      if (
        !isDeepStrictEqual(selected.owner, select.selection.owner) ||
        selected.branch !== select.selection.branch ||
        selected.directory === null
      )
        throw new IncompatibleNative("Changed history selection owner");
      return HistorySelection.restore(JSON.stringify(selected));
    });
  }
  prepareHistoryAcquisition(
    selection: HistorySelection,
    key: HistoryKey,
    namespace = 1,
    budget?: HistoryBudget,
  ): HistoryAcquisition {
    const selected = JSON.parse(selection.save()) as HistoryOutput<"selection">;
    this.historyKey(key);
    if (
      selected.directory === null ||
      !isDeepStrictEqual(selected.owner.scope, scope(this.connection.scope)) ||
      selected.owner.principal !== this.#principal ||
      selected.branch !== this.connection.branch.toString()
    )
      throw new TypeError("Expected a selected history directory on this connection");
    return HistoryAcquisition.restore(
      JSON.stringify({
        key: JSON.parse(key.save()),
        intent: {
          definition: currentDefinition,
          connection: this.historyConnection(),
          namespace: integer(namespace, "namespace"),
          operation: selected.owner.operation,
          selection: selected.directory,
          common: null,
        },
        budget: historyBudget(budget),
      }),
    );
  }
  prepareCommonHistoryAcquisition(
    key: HistoryKey,
    operation: bigint,
    namespace: number,
    selection: HistoryDirectory,
    transaction: HistoryKey,
    cut: HistoryCommonCut,
    budget?: HistoryBudget,
  ): HistoryAcquisition {
    const common = {
      key: this.historyKey(transaction),
      cut: {
        transaction: {
          scope: scope(cut.transaction.scope),
          principal: cut.transaction.principal,
          operation: positive(cut.transaction.operation).toString(),
        },
        acquired: {
          partition: positive(cut.acquired.partition).toString(),
          next_lsn: positive(cut.acquired.nextLsn).toString(),
        },
        sources: {
          bytes: positive(cut.sources.bytes).toString(),
          sha256: digest(cut.sources.digest),
        },
        source_count: positive(cut.sourceCount).toString(),
      },
    };
    return HistoryAcquisition.restore(
      JSON.stringify({
        key: this.historyKey(key),
        intent: {
          definition: currentDefinition,
          connection: this.historyConnection(),
          namespace: integer(namespace, "namespace"),
          operation: positive(operation).toString(),
          selection: {
            content: {
              bytes: positive(selection.content.bytes).toString(),
              sha256: digest(selection.content.digest),
            },
            count: positive(selection.count).toString(),
          },
          common,
        },
        budget: historyBudget(budget),
      }),
    );
  }
  async acquireHistory(original: HistoryAcquisition): Promise<HistoryStatus> {
    this.historyKey(original.key);
    const acquire = JSON.parse(original.save()) as HistoryInput<"acquire">;
    return this.mutation({ history: { acquire } }, original, (result) => {
      const status = historyStatus(historyField(result, "status"), original.key, original);
      if (!status) throw new IncompatibleNative("Missing history admission");
      return status;
    });
  }
  async inspectHistory(key: HistoryKey): Promise<HistoryStatus | undefined> {
    return historyStatus(
      historyField(
        await this.#bridge.call({ history: { inspect: this.historyKey(key) } }),
        "status",
      ),
      key,
    );
  }
  async advanceHistory(key: HistoryKey): Promise<HistoryStatus | undefined> {
    return this.changeHistory("advance", key);
  }
  async abandonHistory(key: HistoryKey): Promise<HistoryStatus | undefined> {
    return this.changeHistory("abandon", key);
  }
  async releaseHistory(key: HistoryKey): Promise<HistoryStatus | undefined> {
    return this.changeHistory("release", key);
  }
  private async changeHistory(
    command: "advance" | "abandon" | "release",
    key: HistoryKey,
  ): Promise<HistoryStatus | undefined> {
    const native = this.historyKey(key);
    const history: HistoryAction =
      command === "advance"
        ? { advance: native }
        : command === "abandon"
          ? { abandon: native }
          : { release: native };
    return this.resumeHistoryControl(HistoryControl.restore(JSON.stringify(history)));
  }
  prepareHistoryControl(
    key: HistoryKey,
    command: "advance" | "abandon" | "release",
  ): HistoryControl {
    const native = this.historyKey(key);
    return HistoryControl.restore(JSON.stringify({ [command]: native }));
  }
  async resumeHistoryControl(original: HistoryControl): Promise<HistoryStatus | undefined> {
    this.historyKey(original.key);
    const history = JSON.parse(original.save()) as HistoryAction;
    return this.mutation({ history }, original, (result) =>
      historyStatus(historyField(result, "status"), original.key),
    );
  }
  async historicalLookup(
    snapshot: HistoricalSnapshot,
    namespace: number,
    selectedName: string,
  ): Promise<bigint | undefined> {
    const result = historyField(
      await this.#bridge.call({
        history: {
          lookup: {
            selector: snapshot.selector,
            namespace: integer(namespace, "namespace"),
            name: name(selectedName),
          },
        },
      }),
      "object",
    );
    return result === null ? undefined : nativeWide(result);
  }
  async historicalNamespace(
    snapshot: HistoricalSnapshot,
    selectedName: string,
  ): Promise<HistoryNamespace | undefined> {
    const result = historyField(
      await this.#bridge.call({
        history: { namespace: { selector: snapshot.selector, name: name(selectedName) } },
      }),
      "namespace",
    );
    if (result === null) return undefined;
    if (
      result.name !== selectedName ||
      !isDeepStrictEqual(result.scope, scope(this.connection.scope))
    )
      throw new IncompatibleNative("Changed historical namespace");
    return historyNamespace(result);
  }
  async historicalTables(
    snapshot: HistoricalSnapshot,
    namespace: number,
    cursor?: HistoryCursor,
  ): Promise<HistoryPage> {
    integer(namespace, "namespace");
    if (
      cursor &&
      (cursor.snapshot.selector !== snapshot.selector || cursor.namespace !== namespace)
    )
      throw new TypeError("History cursor belongs to a different selection");
    const value = historyField(
      await this.#bridge.call({
        history: {
          list: {
            selector: snapshot.selector,
            namespace,
            after: cursor ? (JSON.parse(cursor.save()) as HistoryInput<"list">["after"]) : null,
          },
        },
      }),
      "listing",
    );
    const basis = historyBasis(value.snapshot, snapshot);
    if (
      value.namespace !== namespace ||
      value.entries.some(
        (entry) =>
          entry.namespace.id !== namespace ||
          !isDeepStrictEqual(entry.namespace.scope, scope(this.connection.scope)),
      )
    )
      throw new IncompatibleNative("Changed historical page scope");
    const next =
      value.next === null ? undefined : HistoryCursor.restore(JSON.stringify(value.next));
    if (next && (next.snapshot.selector !== snapshot.selector || next.namespace !== namespace))
      throw new IncompatibleNative("Changed historical continuation");
    if (
      value.next !== null &&
      (!isDeepStrictEqual(value.next.directory.content, value.snapshot.sources_root) ||
        value.next.directory.count !== value.snapshot.source_count ||
        (cursor &&
          nativeWide(value.next.after) <=
            nativeWide(
              (JSON.parse(cursor.save()) as NonNullable<HistoryInput<"list">["after"]>).after,
            )))
    )
      throw new IncompatibleNative(
        "Historical continuation changed directory or failed to advance",
      );
    return Object.freeze({
      basis,
      namespace,
      entries: Object.freeze(value.entries.map(historyEntry)),
      ...(next ? { next } : {}),
    });
  }
  async historicalSource(snapshot: HistoricalSnapshot, objectId: bigint): Promise<HistorySource> {
    const value = historyField(
      await this.#bridge.call({
        history: { source: { selector: snapshot.selector, object: positive(objectId).toString() } },
      }),
      "source",
    );
    const basis = historyBasis(value.snapshot, snapshot);
    if (
      value.binding.declaration.interpretation.object.object !== objectId.toString() ||
      value.schema.object !== objectId.toString() ||
      !isDeepStrictEqual(
        value.binding.declaration.interpretation.object.scope,
        value.snapshot.owner.scope,
      ) ||
      value.binding.declaration.interpretation.object.branch !== value.snapshot.branch
    )
      throw new IncompatibleNative("Changed historical source object");
    return Object.freeze({
      basis,
      binding: historyEntry(value.binding),
      schema: schemaValue(value.schema),
      rowCount: nativeWide(value.rows),
      changedLsn: nativeWide(value.changed_lsn),
      authority: Object.freeze({ ...value.authority }),
    });
  }
  async historicalCoverage(
    snapshot: HistoricalSnapshot,
    objectId: bigint,
    kind: "definitions" | "locations" = "definitions",
    cursor?: HistoryCoverageCursor,
  ): Promise<HistoryCoverage> {
    if (
      cursor &&
      (cursor.snapshot.selector !== snapshot.selector ||
        cursor.objectId !== objectId ||
        cursor.kind !== kind)
    )
      throw new TypeError("Coverage cursor belongs to a different selection");
    const input = {
      selector: snapshot.selector,
      object: positive(objectId).toString(),
      after: cursor ? (JSON.parse(cursor.save()) as HistoryInput<"definitions">["after"]) : null,
    };
    const value = historyField(
      await this.#bridge.call({
        history: kind === "definitions" ? { definitions: input } : { locations: input },
      }),
      "coverage",
    );
    const basis = historyBasis(value.snapshot, snapshot),
      logical = stored(value.logical);
    if (
      value.logical.interpretation.object.object !== objectId.toString() ||
      !isDeepStrictEqual(value.logical.interpretation.object.scope, value.snapshot.owner.scope) ||
      value.logical.interpretation.object.branch !== value.snapshot.branch ||
      (kind === "definitions" && value.locations.length !== 0) ||
      (kind === "locations" && value.definitions !== null)
    )
      throw new IncompatibleNative("Changed coverage source or kind");
    const next = value.next ? HistoryCoverageCursor.restore(JSON.stringify(value.next)) : undefined;
    if (
      next &&
      (next.snapshot.selector !== snapshot.selector ||
        next.objectId !== objectId ||
        next.kind !== kind)
    )
      throw new IncompatibleNative("Changed coverage continuation");
    if (
      value.next &&
      input.after &&
      (!isDeepStrictEqual(value.next.source, input.after.source) ||
        (kind === "definitions"
          ? nativeWide(value.next.after) <= nativeWide(input.after.after)
          : value.next.after <= input.after.after))
    )
      throw new IncompatibleNative("Coverage continuation failed to advance");
    const physical = value.definitions;
    return Object.freeze({
      basis,
      logical,
      accepted: position(value.accepted),
      totalRows: nativeWide(value.total_rows),
      ...(physical
        ? {
            definition: Object.freeze({
              physical: stored(physical.physical),
              schemaRevision: nativeWide(physical.schema_revision),
              rows: nativeWide(physical.rows),
              columns: Object.freeze(
                physical.columns.map((column) =>
                  Object.freeze({
                    column: nativeWide(column.column),
                    source:
                      "physical" in column.source
                        ? Object.freeze({ physical: nativeWide(column.source.physical) })
                        : Object.freeze({
                            initial: Object.freeze({
                              definition: interpretation(column.source.initial.definition),
                              state: column.source.initial.state,
                            }),
                          }),
                  }),
                ),
              ),
            }),
          }
        : {}),
      locations: Object.freeze(
        value.locations.map((entry) =>
          Object.freeze({
            origin: nativeWide(entry.identity.origin),
            operation: nativeWide(entry.identity.operation),
            ordinal: entry.identity.ordinal,
            physical: stored(entry.physical),
            schemaRevision: nativeWide(entry.schema_revision),
            location:
              "wal" in entry.location
                ? Object.freeze({
                    wal: Object.freeze({
                      lsn: nativeWide(entry.location.wal.lsn),
                      offset: entry.location.wal.offset,
                      bytes: entry.location.wal.bytes,
                      rowDigest: digest(entry.location.wal.row_digest),
                    }),
                  })
                : Object.freeze({
                    segment: Object.freeze({
                      id: nativeWide(entry.location.segment.id),
                      row: entry.location.segment.row,
                      contentBytes: nativeWide(entry.location.segment.content.bytes),
                      contentDigest: digest(entry.location.segment.content.sha256),
                    }),
                  }),
          }),
        ),
      ),
      ...(next ? { next } : {}),
    });
  }
  private historyConnection(): HistoryInput<"inspect">["connection"] {
    return {
      scope: scope(this.connection.scope),
      branch: this.connection.branch.toString(),
      audience: this.connection.audience,
      principal: this.#principal,
      role: this.connection.role ?? null,
    };
  }
  private historyKey(key: HistoryKey): HistoryInput<"inspect"> {
    const value = JSON.parse(key.save()) as HistoryInput<"inspect">;
    if (!isDeepStrictEqual(value.connection, this.historyConnection()))
      throw new TypeError("Foreign history recovery connection");
    return value;
  }
  prepareSnapshot(
    current: Pick<Metadata, "basis" | "position">,
    operation: bigint,
  ): SnapshotAcquisition {
    const selected = basis(current.basis);
    return SnapshotAcquisition.restore(
      JSON.stringify({
        owner: {
          definition: currentDefinition,
          connection: selected.connection,
          object: selected.interpretation.interpretation.object,
          operation: positive(operation).toString(),
        },
        expected: {
          partition: current.position.partition.toString(),
          next_lsn: current.position.nextLsn.toString(),
        },
      }),
    );
  }
  async acquireSnapshot(acquisition: SnapshotAcquisition): Promise<Snapshot> {
    const acquire = JSON.parse(acquisition.save()) as RetentionInput<"acquire">;
    return this.mutation({ retention: { acquire } }, acquisition, (result) => {
      const value = retentionField(result, "acquired");
      if (!isDeepStrictEqual(value.owner, acquire.owner))
        throw new IncompatibleNative("Acquisition changed the original snapshot owner");
      return Snapshot.restore(JSON.stringify(value));
    });
  }
  async snapshotStatus(original: SnapshotOwner): Promise<SnapshotStatus> {
    const status = JSON.parse(original.save()) as RetentionInput<"status">;
    const value = retentionField(await this.#bridge.call({ retention: { status } }), "status");
    if (
      !isDeepStrictEqual(value.owner, status) ||
      (value.snapshot !== null && !isDeepStrictEqual(value.snapshot.owner, status))
    )
      throw new IncompatibleNative("Status changed the original snapshot owner");
    return Object.freeze({
      owner: original,
      currentInterpretation: interpretation(value.current_interpretation),
      currentPosition: position(value.current_position),
      retired: value.retired,
      released: value.released,
      ...(value.snapshot === null
        ? {}
        : { snapshot: Snapshot.restore(JSON.stringify(value.snapshot)) }),
      authority: Object.freeze({ ...value.authority }),
    });
  }
  async snapshotMetadata(original: Snapshot): Promise<SnapshotMetadata> {
    const metadata = JSON.parse(original.save()) as RetentionInput<"metadata">;
    const value = retentionField(await this.#bridge.call({ retention: { metadata } }), "metadata");
    if (
      !isDeepStrictEqual(value.snapshot, metadata) ||
      !isDeepStrictEqual(value.interpretation.interpretation.object, metadata.owner.object) ||
      value.schema.object !== metadata.owner.object.object
    )
      throw new IncompatibleNative("Metadata changed the retained snapshot");
    return Object.freeze({
      snapshot: original,
      definition: stored(value.interpretation),
      accepted: position(value.accepted),
      changedLsn: nativeWide(value.changed_lsn),
      rowCount: nativeWide(value.row_count),
      schema: schemaValue(value.schema),
      authority: Object.freeze({ ...value.authority }),
    });
  }
  async releaseSnapshot(original: Snapshot): Promise<void> {
    const release = JSON.parse(original.save()) as RetentionInput<"release">;
    return this.mutation({ retention: { release } }, original, (result) => {
      if (!isDeepStrictEqual(retentionField(result, "released"), release))
        throw new IncompatibleNative("Release changed the retained snapshot");
    });
  }
  private compilation(value: Result<"compiled">, ids: Identity): Compiled {
    const binding = value.summary.binding;
    const selected =
      "table" in binding
        ? binding.table.identity
        : {
            scope: binding.name_assertion.connection.scope,
            principal: binding.name_assertion.connection.principal,
            operation: binding.name_assertion.operation,
          };
    if (
      value.summary.namespace !== ids.namespace ||
      selected.operation !== ids.operation.toString() ||
      selected.principal !== this.#principal ||
      !isDeepStrictEqual(selected.scope, scope(this.connection.scope))
    )
      throw new IncompatibleNative("Compilation changed the selected operation identity");
    return compiled(value);
  }
  private async mutation<T>(
    action: CatalogAction,
    recovery: Recovery,
    project: (result: CatalogResult) => T,
  ): Promise<T> {
    let result: CatalogResult;
    try {
      result = await this.#bridge.call(action);
    } catch (error) {
      if (error instanceof UnknownOutcome) throw new Uncertain(recovery, error);
      throw error;
    }
    try {
      return project(result);
    } catch {
      throw new Uncertain(
        recovery,
        new UnknownOutcome("The catalog response did not preserve its original request evidence", {
          status: 6,
          phase: "catalog",
        }),
      );
    }
  }
  close(): Promise<void> {
    return this.#bridge.close();
  }
}
