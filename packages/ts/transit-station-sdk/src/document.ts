import { ResourceRef, IncompatibleNative, UnsupportedCapability } from "@transit/client";
import { integer, owned, text } from "@transit/client/internal";
import { Bridge, result } from "./bridge.ts";
import { operation, context } from "./context.ts";
import { hex, unhex } from "./framing.ts";
import { wide, nativeWide } from "./values.ts";
import type { Turn } from "./turn.ts";
import type {
  DocumentCodecAction,
  DocumentCodecResult,
  DocumentReadAction,
  DocumentReadResult,
  GrowingAction,
  GrowingResult,
} from "./wire.ts";

export interface DocumentDot {
  readonly counter: bigint;
  readonly replica: bigint;
}
export const documentRoot: DocumentDot = Object.freeze({ counter: 0n, replica: 0n });
export type DocumentValue =
  | { readonly kind: "null" | "map" | "list" | "text" }
  | { readonly kind: "boolean"; readonly value: boolean }
  | { readonly kind: "signed" | "unsigned"; readonly value: bigint }
  | { readonly kind: "float"; readonly value: number }
  | { readonly kind: "string" | "character"; readonly value: string }
  | { readonly kind: "binary"; readonly value: Uint8Array };
export type DocumentOperation =
  | {
      readonly kind: "assign";
      readonly object?: DocumentDot;
      readonly field: string;
      readonly observed?: readonly DocumentDot[];
      readonly value: DocumentValue;
    }
  | {
      readonly kind: "remove";
      readonly object?: DocumentDot;
      readonly field: string;
      readonly observed: readonly DocumentDot[];
    }
  | {
      readonly kind: "insert";
      readonly object: DocumentDot;
      readonly after?: DocumentDot;
      readonly value: DocumentValue;
    }
  | {
      readonly kind: "set-element";
      readonly object: DocumentDot;
      readonly element: DocumentDot;
      readonly observed: readonly DocumentDot[];
      readonly value: DocumentValue;
    }
  | {
      readonly kind: "delete-element";
      readonly object: DocumentDot;
      readonly element: DocumentDot;
    };
export interface DocumentChange {
  readonly document: bigint;
  readonly epoch: bigint;
  readonly typeRevision?: number;
  readonly replica: bigint;
  readonly previous?: bigint;
  readonly first: bigint;
  readonly operations: readonly DocumentOperation[];
}
type WireChange = Extract<DocumentCodecResult, { change: unknown }>["change"];
type WireOperation = WireChange["operations"][number];
type WireDot = Extract<WireOperation, { insert: unknown }>["insert"]["object"];
type WireValue = Extract<WireOperation, { insert: unknown }>["insert"]["value"];
function dot(value: DocumentDot): WireDot {
  const counter = wide(value.counter),
    replica = wide(value.replica);
  if ((counter === 0n) !== (replica === 0n)) throw new TypeError("Root has both identities zero");
  return { counter: counter.toString(), replica: replica.toString() };
}
function fromDot(value: WireDot): DocumentDot {
  const out = Object.freeze({
    counter: nativeWide(value.counter),
    replica: nativeWide(value.replica),
  });
  dot(out);
  return out;
}
function scalar(value: DocumentValue): WireValue {
  switch (value?.kind) {
    case "null":
      return { null_value: {} };
    case "map":
      return { map: {} };
    case "list":
      return { list: {} };
    case "text":
      return { text: {} };
    case "boolean":
      if (typeof value.value !== "boolean") throw new TypeError("Expected boolean");
      return { boolean: value.value };
    case "signed":
      if (typeof value.value !== "bigint" || value.value < -(1n << 63n) || value.value >= 1n << 63n)
        throw new TypeError("Expected signed int64");
      return { signed: value.value.toString() };
    case "unsigned":
      return { unsigned: wide(value.value).toString() };
    case "float": {
      if (typeof value.value !== "number" || !Number.isFinite(value.value))
        throw new TypeError("Expected finite float64");
      const bytes = new Uint8Array(8);
      new DataView(bytes.buffer).setFloat64(0, value.value, true);
      return { float_bits: hex(bytes, 8) };
    }
    case "string":
      return { string: text(value.value, 96) };
    case "character":
      return { character: text(value.value, 4) };
    case "binary":
      return { binary: hex(value.value, 96) };
    default:
      throw new TypeError("Expected Document value");
  }
}
function fromScalar(v: WireValue): DocumentValue {
  if ("null_value" in v) return Object.freeze({ kind: "null" });
  if ("map" in v) return Object.freeze({ kind: "map" });
  if ("list" in v) return Object.freeze({ kind: "list" });
  if ("text" in v) return Object.freeze({ kind: "text" });
  if ("boolean" in v) return Object.freeze({ kind: "boolean", value: v.boolean });
  if ("signed" in v) {
    const value = BigInt(v.signed);
    const out = { kind: "signed", value } as const;
    scalar(out);
    if (value.toString() !== v.signed) throw new IncompatibleNative("Noncanonical integer");
    return Object.freeze(out);
  }
  if ("unsigned" in v) return Object.freeze({ kind: "unsigned", value: nativeWide(v.unsigned) });
  if ("float_bits" in v) {
    const bytes = unhex(v.float_bits, 8);
    if (bytes.length !== 8) throw new IncompatibleNative("Invalid float64 bytes");
    const value = new DataView(bytes.buffer, bytes.byteOffset, 8).getFloat64(0, true);
    if (!Number.isFinite(value)) throw new IncompatibleNative("Nonfinite Document scalar");
    return Object.freeze({ kind: "float", value });
  }
  if ("string" in v) return Object.freeze({ kind: "string", value: v.string });
  if ("character" in v) return Object.freeze({ kind: "character", value: v.character });
  if ("binary" in v) return Object.freeze({ kind: "binary", value: unhex(v.binary, 96) });
  throw new IncompatibleNative("Unknown Document scalar");
}
function observed(values: readonly DocumentDot[]): WireDot[] {
  if (!Array.isArray(values) || values.length > 8)
    throw new TypeError("Expected at most eight observed identities");
  return values.map(dot);
}
function operationWire(op: DocumentOperation): WireOperation {
  switch (op?.kind) {
    case "assign":
      return {
        assign: {
          object: dot(op.object ?? documentRoot),
          field: text(op.field, 64),
          observed: observed(op.observed ?? []),
          value: scalar(op.value),
        },
      };
    case "remove":
      return {
        remove: {
          object: dot(op.object ?? documentRoot),
          field: text(op.field, 64),
          observed: observed(op.observed),
        },
      };
    case "insert":
      return {
        insert: {
          object: dot(op.object),
          after: dot(op.after ?? documentRoot),
          value: scalar(op.value),
        },
      };
    case "set-element":
      return {
        set_element: {
          object: dot(op.object),
          element: dot(op.element),
          observed: observed(op.observed),
          value: scalar(op.value),
        },
      };
    case "delete-element":
      return { delete_element: { object: dot(op.object), element: dot(op.element) } };
    default:
      throw new TypeError("Expected Document operation");
  }
}
function fromOperation(op: WireOperation): DocumentOperation {
  if ("assign" in op)
    return Object.freeze({
      kind: "assign",
      object: fromDot(op.assign.object),
      field: op.assign.field,
      observed: Object.freeze(op.assign.observed.map(fromDot)),
      value: fromScalar(op.assign.value),
    });
  if ("remove" in op)
    return Object.freeze({
      kind: "remove",
      object: fromDot(op.remove.object),
      field: op.remove.field,
      observed: Object.freeze(op.remove.observed.map(fromDot)),
    });
  if ("insert" in op)
    return Object.freeze({
      kind: "insert",
      object: fromDot(op.insert.object),
      after: fromDot(op.insert.after),
      value: fromScalar(op.insert.value),
    });
  if ("set_element" in op)
    return Object.freeze({
      kind: "set-element",
      object: fromDot(op.set_element.object),
      element: fromDot(op.set_element.element),
      observed: Object.freeze(op.set_element.observed.map(fromDot)),
      value: fromScalar(op.set_element.value),
    });
  return Object.freeze({
    kind: "delete-element",
    object: fromDot(op.delete_element.object),
    element: fromDot(op.delete_element.element),
  });
}
function fromChange(v: WireChange): DocumentChange {
  return Object.freeze({
    document: nativeWide(v.document),
    epoch: nativeWide(v.epoch),
    typeRevision: v.type_revision,
    replica: nativeWide(v.replica),
    previous: nativeWide(v.previous),
    first: nativeWide(v.first),
    operations: Object.freeze(v.operations.map(fromOperation)),
  });
}
type CodecCall = (action: DocumentCodecAction) => Promise<DocumentCodecResult>;
async function local(
  action: DocumentCodecAction,
  nativeHost?: string,
): Promise<DocumentCodecResult> {
  const bridge = await Bridge.local(nativeHost);
  try {
    return await bridge.documentCodec(action);
  } finally {
    await bridge.close();
  }
}
const construction = Symbol("validated-document");
export class PreparedDocumentChange {
  readonly document: bigint;
  readonly #data: Uint8Array;
  constructor(secret: typeof construction, document: bigint, data: Uint8Array) {
    if (secret !== construction) throw new TypeError("Use prepareDocument or decodeDocument");
    this.document = wide(document);
    this.#data = owned(data, 4096);
    Object.freeze(this);
  }
  get data(): Uint8Array {
    return new Uint8Array(this.#data);
  }
}
export async function prepareDocument(
  change: DocumentChange,
  options: { nativeHost?: string } = {},
): Promise<PreparedDocumentChange> {
  if (
    !Array.isArray(change.operations) ||
    change.operations.length < 1 ||
    change.operations.length > 8
  )
    throw new TypeError("Expected one to eight operations");
  const identity = wide(change.document);
  const action: DocumentCodecAction = {
    prepare: {
      document: wide(change.document).toString(),
      epoch: wide(change.epoch).toString(),
      type_revision: integer(change.typeRevision ?? 1, "type revision", 1, 0xffffffff),
      replica: wide(change.replica).toString(),
      first: wide(change.first).toString(),
      previous: wide(change.previous ?? 0n).toString(),
      operations: change.operations.map(operationWire),
    },
  };
  const out = await local(action, options.nativeHost);
  if (!("prepared" in out)) throw new IncompatibleNative("Expected prepared Document change");
  return new PreparedDocumentChange(construction, identity, unhex(out.prepared.bytes, 4096));
}
export async function decodeDocument(
  data: Uint8Array,
  options: { nativeHost?: string } = {},
): Promise<DocumentChange> {
  const out = await local({ decode: hex(data, 4096) }, options.nativeHost);
  if (!("change" in out)) throw new IncompatibleNative("Expected Document change");
  return fromChange(out.change);
}
export class DocumentReference {
  readonly resource: ResourceRef;
  readonly document: bigint;
  readonly epoch: bigint;
  readonly typeRevision: number;
  readonly revision: bigint;
  readonly #data: Uint8Array;
  constructor(
    secret: typeof construction,
    realm: number,
    v: Extract<DocumentCodecResult, { inspected_reference: unknown }>["inspected_reference"],
    bytes: Uint8Array,
  ) {
    if (secret !== construction) throw new TypeError("Use DocumentReference.decode");
    this.resource = new ResourceRef(realm, v.resource);
    this.document = nativeWide(v.document);
    this.epoch = nativeWide(v.epoch);
    this.typeRevision = v.type_revision;
    this.revision = nativeWide(v.revision);
    this.#data = owned(bytes, 40);
    Object.freeze(this);
  }
  get data(): Uint8Array {
    return new Uint8Array(this.#data);
  }
  static async decode(
    realm: number,
    data: Uint8Array,
    options: { nativeHost?: string } = {},
  ): Promise<DocumentReference> {
    return reference(realm, hex(data, 40), (action) => local(action, options.nativeHost));
  }
}
async function reference(
  realm: number,
  bytes: string,
  codec: CodecCall,
): Promise<DocumentReference> {
  const out = await codec({ inspect_reference: bytes });
  if (!("inspected_reference" in out)) throw new IncompatibleNative("Expected Document reference");
  return new DocumentReference(construction, realm, out.inspected_reference, unhex(bytes, 40));
}
export type DocumentStatus = "missing" | "null" | "scalar" | "object" | "conflict";
export interface DocumentAssignment {
  readonly id: DocumentDot;
  readonly value: DocumentValue;
}
export interface DocumentField {
  readonly status: DocumentStatus;
  readonly assignments: readonly DocumentAssignment[];
}
type WireField = Extract<DocumentReadResult, { field: unknown }>["field"]["value"];
function field(v: WireField): DocumentField {
  if (
    v.assignments.length > 8 ||
    (v.status === "missing") !== (v.assignments.length === 0) ||
    (v.status === "conflict") !== v.assignments.length > 1
  )
    throw new IncompatibleNative("Invalid Document field");
  return Object.freeze({
    status: v.status === "null_value" ? "null" : v.status,
    assignments: Object.freeze(
      v.assignments.map((v) => Object.freeze({ id: fromDot(v.id), value: fromScalar(v.value) })),
    ),
  });
}
export interface DocumentDescription {
  readonly reference: DocumentReference;
  readonly sourceRevision: number;
  readonly floor: bigint;
  readonly mergeWindow: bigint;
  readonly retired: boolean;
  readonly activeJob: bigint;
  readonly changeFormat: number;
}
export interface DocumentPath {
  readonly reference: DocumentReference;
  readonly sourceRevision: number;
  readonly field: DocumentField;
}
export interface DocumentItem {
  readonly id: DocumentDot;
  readonly field: DocumentField;
}
export interface DocumentPage {
  readonly reference: DocumentReference;
  readonly sourceRevision: number;
  readonly items: readonly DocumentItem[];
  readonly next: string | undefined;
}
export interface DocumentResynchronization {
  readonly reference: DocumentReference;
  readonly floor: bigint;
  readonly replica: bigint;
  readonly previousCounter: bigint;
  readonly clock: bigint;
}
export interface DocumentProgress {
  readonly phase: "progress" | "accepted" | "duplicate" | "checkpoint_complete";
  readonly revision: bigint | undefined;
}
type OwnerAction = Extract<GrowingAction, { document: unknown }>["document"];
type OwnerResult = Extract<GrowingResult, { document: unknown }>["document"];
function progress(v: OwnerResult): DocumentProgress {
  if (!("progress" in v)) throw new IncompatibleNative("Expected private Document progress");
  return Object.freeze({
    phase: v.progress.phase,
    revision: v.progress.revision === null ? undefined : nativeWide(v.progress.revision),
  });
}
export class DocumentOwner {
  readonly #turn: Turn;
  readonly document: bigint;
  constructor(turn: Turn, document: bigint) {
    context(turn).scope.check();
    this.#turn = turn;
    this.document = wide(document);
  }
  #apply<T>(action: () => OwnerAction, decode: (value: OwnerResult) => T): Promise<T> {
    return operation(this.#turn, async ({ bridge, token }) => {
      if (!bridge.caps.document_owner)
        throw new UnsupportedCapability("Native Document owner is unavailable");
      return decode(result(await bridge.apply(token, { document: action() }), "document"));
    });
  }
  create(
    options: {
      typeRevision?: number;
      recordBytes?: number;
      stagingBytes?: bigint;
      stagingRecords?: number;
    } = {},
  ): Promise<void> {
    return this.#apply(
      () => ({
        create: {
          document: this.document.toString(),
          type_revision: integer(options.typeRevision ?? 1, "type revision", 1, 0xffffffff),
          record_bytes: integer(options.recordBytes ?? 4096, "record bytes", 1, 0xffffffff),
          staging_bytes: wide(options.stagingBytes ?? 8192n).toString(),
          staging_records: integer(options.stagingRecords ?? 2, "staging records", 1, 0xffffffff),
        },
      }),
      () => {},
    );
  }
  stage(job: bigint, change: PreparedDocumentChange, nodeLimit: number): Promise<DocumentProgress> {
    return this.#apply(() => {
      if (!(change instanceof PreparedDocumentChange) || change.document !== this.document)
        throw new TypeError("Change belongs to another Document");
      return {
        stage: {
          document: this.document.toString(),
          job: wide(job).toString(),
          change: hex(change.data, 4096),
          node_limit: integer(nodeLimit, "node limit", 1, 0xffffffff),
        },
      };
    }, progress);
  }
  checkpoint(job: bigint): Promise<DocumentProgress> {
    return this.#apply(
      () => ({ checkpoint: { document: this.document.toString(), job: wide(job).toString() } }),
      progress,
    );
  }
  mergeWindow(revisions: bigint): Promise<void> {
    return this.#apply(
      () => ({
        merge_window: { document: this.document.toString(), revisions: wide(revisions).toString() },
      }),
      () => {},
    );
  }
  reject(job: bigint, checkpoint = false): Promise<void> {
    return this.#apply(
      () => {
        if (typeof checkpoint !== "boolean") throw new TypeError("Expected checkpoint flag");
        return {
          reject: { document: this.document.toString(), job: wide(job).toString(), checkpoint },
        };
      },
      () => {},
    );
  }
  collect(
    job: bigint,
    options: { checkpoint?: boolean; retired?: boolean } = {},
  ): Promise<boolean> {
    return this.#apply(
      () => {
        const checkpoint = options.checkpoint ?? false,
          retired = options.retired ?? false;
        if (typeof checkpoint !== "boolean" || typeof retired !== "boolean")
          throw new TypeError("Expected collection flags");
        return {
          collect: {
            document: this.document.toString(),
            job: wide(job).toString(),
            checkpoint,
            retired,
          },
        };
      },
      (v) => {
        if (!("collected" in v)) throw new IncompatibleNative("Expected cleanup progress");
        return v.collected;
      },
    );
  }
  retire(): Promise<void> {
    return this.#apply(
      () => ({ retire: this.document.toString() }),
      () => {},
    );
  }
}
export class DocumentReader {
  readonly #read: (action: DocumentReadAction) => Promise<DocumentReadResult>;
  readonly #codec: CodecCall;
  readonly #realm: number;
  constructor(
    realm: number,
    read: (action: DocumentReadAction) => Promise<DocumentReadResult>,
    codec: CodecCall,
  ) {
    this.#realm = realm;
    this.#read = read;
    this.#codec = codec;
  }
  #identity(resource: ResourceRef, document: bigint): { resource: number; document: string } {
    if (!(resource instanceof ResourceRef) || resource.realm !== this.#realm)
      throw new TypeError("Document belongs to another realm");
    return { resource: resource.resource, document: wide(document).toString() };
  }
  #reference(ref: DocumentReference): string {
    if (!(ref instanceof DocumentReference) || ref.resource.realm !== this.#realm)
      throw new TypeError("Document belongs to another realm");
    return hex(ref.data, 40);
  }
  async describe(resource: ResourceRef, document: bigint): Promise<DocumentDescription> {
    const out = await this.#read({ describe: this.#identity(resource, document) });
    if (!("description" in out)) throw new IncompatibleNative("Expected Document description");
    const v = out.description;
    return Object.freeze({
      reference: await reference(this.#realm, v.reference, this.#codec),
      sourceRevision: v.source_revision,
      floor: nativeWide(v.floor),
      mergeWindow: nativeWide(v.merge_window),
      retired: v.retired,
      activeJob: nativeWide(v.active_job),
      changeFormat: v.change_format,
    });
  }
  async path(ref: DocumentReference, names: readonly string[]): Promise<DocumentPath> {
    if (!Array.isArray(names) || names.length < 1 || names.length > 16)
      throw new TypeError("Expected one to sixteen path segments");
    const encoded = this.#reference(ref);
    const out = await this.#read({
      path: { reference: encoded, names: names.map((v: string) => text(v, 64)) },
    });
    if (!("field" in out) || out.field.reference !== encoded)
      throw new IncompatibleNative("Document revision changed");
    return Object.freeze({
      reference: ref,
      sourceRevision: out.field.source_revision,
      field: field(out.field.value),
    });
  }
  async sequence(
    ref: DocumentReference,
    object: DocumentDot,
    cursor?: string,
  ): Promise<DocumentPage> {
    const encoded = this.#reference(ref);
    const out = await this.#read({
      sequence: {
        reference: encoded,
        object: dot(object),
        cursor: cursor === undefined ? null : text(cursor, 1024),
      },
    });
    if (!("page" in out) || out.page.reference !== encoded || out.page.items.length > 8)
      throw new IncompatibleNative("Invalid Document page");
    return Object.freeze({
      reference: ref,
      sourceRevision: out.page.source_revision,
      items: Object.freeze(
        out.page.items.map((v) => Object.freeze({ id: fromDot(v.id), field: field(v.values) })),
      ),
      next: out.page.next ?? undefined,
    });
  }
  async resynchronize(
    resource: ResourceRef,
    document: bigint,
    replica: bigint,
  ): Promise<DocumentResynchronization> {
    const out = await this.#read({
      resynchronize: {
        identity: this.#identity(resource, document),
        replica: wide(replica).toString(),
      },
    });
    if (!("resynchronization" in out))
      throw new IncompatibleNative("Expected replica resynchronization");
    const v = out.resynchronization;
    return Object.freeze({
      reference: await reference(this.#realm, v.reference, this.#codec),
      floor: nativeWide(v.floor),
      replica: nativeWide(v.replica),
      previousCounter: nativeWide(v.previous_counter),
      clock: nativeWide(v.clock),
    });
  }
  async acceptedChange(ref: DocumentReference): Promise<DocumentChange> {
    const out = await this.#read({ accepted_change: this.#reference(ref) });
    if (!("change" in out)) throw new IncompatibleNative("Expected accepted Document change");
    return fromChange(out.change);
  }
}
