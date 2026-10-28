import type { RelationalRequest, RelationalResponse } from "./types";
import {
  RelationalRequest as requestSchema,
  RelationalResponse as responseSchema,
} from "./validators.js";
import { request, BoardError } from "./index";
export type { RelationalRequest, RelationalResponse } from "./types";
type Result = Extract<RelationalResponse, { query: unknown }>["query"];
type Description = Extract<Result, { explained: unknown }>["explained"];
export type RelationalReference = Extract<Result, { opened: unknown }>["opened"]["reference"];
export type RelationalPage = Extract<Result, { page: unknown }>["page"];
export type RelationalOpened = Extract<Result, { opened: unknown }>["opened"];
export type RelationalDescription = Description;
export type RelationalStorage = Extract<RelationalResponse, { storage: unknown }>["storage"];
export type RelationalProfile = Extract<
  RelationalResponse,
  { description: unknown }
>["description"];
const hex = (value: string, bytes: number) => new RegExp(`^[0-9a-f]{${bytes * 2}}$`).test(value);
function decimal(value: string, signed = false, nonzero = false): boolean {
  if (!/^(0|-?[1-9][0-9]*)$/.test(value) || value.length > 20) return false;
  const number = BigInt(value);
  return signed
    ? number >= -(1n << 63n) && number < 1n << 63n
    : number >= (nonzero ? 1n : 0n) && number < 1n << 64n;
}
function textScalar(value: string): boolean {
  if (value.length > 1024 * 1024) return false;
  const encoded = new TextEncoder().encode(value);
  return encoded.length <= 1024 * 1024 && new TextDecoder().decode(encoded) === value;
}
function reference(value: RelationalReference): boolean {
  return hex(value.id, 16) && !/^0+$/.test(value.id) && hex(value.plan, 32) && hex(value.basis, 32);
}
type Binding = Description["sources"][number]["binding"];
function sameScope(a: Binding["connection"]["scope"], b: Binding["connection"]["scope"]): boolean {
  return a.realm === b.realm && a.resource === b.resource && a.catalog === b.catalog;
}
function sameObject(
  a: Binding["interpretation"]["interpretation"]["object"],
  b: Binding["interpretation"]["interpretation"]["object"],
): boolean {
  return sameScope(a.scope, b.scope) && a.branch === b.branch && a.object === b.object;
}
function sameConnection(a: Binding["connection"], b: Binding["connection"]): boolean {
  return (
    sameScope(a.scope, b.scope) &&
    a.branch === b.branch &&
    a.audience === b.audience &&
    a.principal === b.principal &&
    a.role === b.role
  );
}
function sameBinding(a: Binding, b: Binding): boolean {
  return (
    a.definition === b.definition &&
    sameConnection(a.connection, b.connection) &&
    a.namespace === b.namespace &&
    a.name === b.name &&
    sameObject(a.interpretation.interpretation.object, b.interpretation.interpretation.object) &&
    a.interpretation.interpretation.revision === b.interpretation.interpretation.revision &&
    a.interpretation.interpretation.digest === b.interpretation.interpretation.digest &&
    a.interpretation.content.bytes === b.interpretation.content.bytes &&
    a.interpretation.content.sha256 === b.interpretation.content.sha256 &&
    a.interpretation.schema_fingerprint === b.interpretation.schema_fingerprint &&
    a.interpretation.retired === b.interpretation.retired
  );
}
function validBinding(b: Binding): boolean {
  const object = b.interpretation.interpretation.object;
  return (
    sameScope(b.connection.scope, object.scope) &&
    b.connection.branch === object.branch &&
    b.connection.audience > 0 &&
    b.connection.principal > 0 &&
    b.namespace > 0 &&
    decimal(object.scope.catalog, false, true) &&
    decimal(object.branch, false, true) &&
    decimal(object.object, false, true) &&
    decimal(b.interpretation.interpretation.revision, false, true) &&
    decimal(b.interpretation.content.bytes, false, true) &&
    hex(b.interpretation.interpretation.digest, 32) &&
    b.interpretation.interpretation.digest === b.interpretation.content.sha256 &&
    hex(b.interpretation.schema_fingerprint, 32)
  );
}
function description(value: Description): boolean {
  return (
    !value.executed &&
    hex(value.plan, 32) &&
    value.sources.length >= 1 &&
    value.sources.length <= 2 &&
    value.sources.every(
      (source) =>
        source.binding.definition === value.definition &&
        validBinding(source.binding) &&
        decimal(source.position.partition, false, true) &&
        decimal(source.position.next_lsn, false, true) &&
        sameConnection(source.binding.connection, value.sources[0]!.binding.connection),
    ) &&
    value.columns.length >= 1 &&
    value.columns.every(
      (c) => !c.optional && ("int64" in c.type || "uint64" in c.type || "utf8" in c.type),
    )
  );
}
export function validateRelational(value: unknown): value is RelationalResponse {
  if (!responseSchema(value)) return false;
  const response = value as RelationalResponse;
  if ("description" in response) {
    const { capabilities, routes, recovery, active } = response.description;
    return (
      capabilities.interactive &&
      capabilities.page_rows === 1 &&
      capabilities.active_queries === 1 &&
      capabilities.consistency === "independent_table_snapshots" &&
      routes.length >= 1 &&
      routes.length <= 2 &&
      (recovery === null ||
        (hex(recovery.id, 16) && !/^0+$/.test(recovery.id) && recovery.remaining_pins <= 2)) &&
      (active === null || (recovery !== null && recovery.id === active.opened.reference.id)) &&
      (response.description.active === null ||
        (decimal(response.description.active.ordinal) &&
          validateRelational({ query: { opened: response.description.active.opened } }))) &&
      routes.every(
        (r) =>
          decimal(r.connection.scope.catalog, false, true) &&
          r.description.policy_revision > 0 &&
          sameScope(r.connection.scope, r.description.configuration.scope) &&
          r.connection.branch === r.description.configuration.branch &&
          r.connection.audience === r.description.configuration.audience &&
          r.connection.scope.realm > 0 &&
          r.connection.scope.resource > 0 &&
          r.connection.audience > 0 &&
          r.connection.principal > 0 &&
          sameConnection(r.connection, routes[0]!.connection),
      )
    );
  }
  if ("storage" in response) {
    const { binding, observed } = response.storage;
    if (!validBinding(binding)) return false;
    for (const [key, value] of Object.entries(observed)) {
      if (key === "position" || key === "pending_complete") continue;
      if (value !== null && (typeof value !== "string" || !decimal(value))) return false;
    }
    return (
      decimal(observed.position.partition, false, true) &&
      decimal(observed.position.next_lsn, false, true) &&
      BigInt(observed.changed_lsn) <= BigInt(observed.position.next_lsn) &&
      BigInt(observed.pending_rows) <= BigInt(observed.live_rows) &&
      BigInt(observed.history_floor) <= BigInt(observed.position.next_lsn) &&
      BigInt(observed.archive_through) < BigInt(observed.position.next_lsn) &&
      BigInt(observed.next_segment) > 0n &&
      BigInt(observed.pending_rows) <= 1024n &&
      (observed.pending_rows === "0") === (observed.oldest_pending_lsn === null) &&
      (observed.pending_rows === "0") === (observed.pending_bytes === "0") &&
      (observed.pending_complete ||
        (observed.pending_rows === "1024" && BigInt(observed.live_rows) > 1024n)) &&
      (observed.oldest_pending_lsn === null ||
        BigInt(observed.oldest_pending_lsn) < BigInt(observed.position.next_lsn)) &&
      (observed.recovery_through === null ||
        (BigInt(observed.recovery_through) > 0n &&
          BigInt(observed.recovery_through) < BigInt(observed.position.next_lsn)))
    );
  }
  if ("recovered" in response) return true;
  const result = response.query;
  if ("explained" in result) return description(result.explained);
  if ("opened" in result) {
    const value = result.opened;
    return (
      reference(value.reference) &&
      description(value.description) &&
      value.reference.plan === value.description.plan &&
      !value.complete_coverage &&
      value.cuts.length === value.description.sources.length &&
      value.cuts.every(
        (cut, i) =>
          sameObject(
            cut.object,
            value.description.sources[i]!.binding.interpretation.interpretation.object,
          ) &&
          cut.position.partition === value.description.sources[i]!.position.partition &&
          cut.position.next_lsn === value.description.sources[i]!.position.next_lsn &&
          cut.schema === value.description.sources[i]!.binding.interpretation.schema_fingerprint &&
          hex(cut.commitment, 32),
      )
    );
  }
  if ("page" in result) {
    const value = result.page;
    if (
      !reference(value.reference) ||
      !decimal(value.ordinal) ||
      value.complete_coverage !== (value.row === null)
    )
      return false;
    if (!value.row) return true;
    const identity = value.row.identity;
    if ("pair" in identity) {
      if (
        !hex(identity.pair.left, 20) ||
        (identity.pair.right !== null && !hex(identity.pair.right, 20))
      )
        return false;
    } else if (
      !identity.group.every(
        (key) =>
          key === null || ("signed" in key ? decimal(key.signed, true) : textScalar(key.utf8)),
      )
    )
      return false;
    return (
      value.row.cells.length >= 1 &&
      value.row.cells.every((cell) => {
        if ("null" in cell) return true;
        if (!("value" in cell) || !("atom" in cell.value)) return false;
        const atom = cell.value.atom;
        return "signed" in atom
          ? decimal(atom.signed, true)
          : "unsigned" in atom
            ? decimal(atom.unsigned)
            : "utf8" in atom && textScalar(atom.utf8);
      })
    );
  }
  return true;
}
function sameReference(a: RelationalReference, b: RelationalReference): boolean {
  return a.definition === b.definition && a.id === b.id && a.plan === b.plan && a.basis === b.basis;
}
/** One explicit request. Errors never trigger query creation or page advancement. */
export async function relationalQuery(
  operation: RelationalRequest,
  signal?: AbortSignal,
): Promise<RelationalResponse> {
  const owned = structuredClone(operation);
  if (!requestSchema(owned) || new TextEncoder().encode(JSON.stringify(owned)).length > 16384)
    throw new BoardError(0, "InvalidQuery");
  let response: RelationalResponse;
  for (let attempt = 0; ; attempt++) {
    signal?.throwIfAborted();
    try {
      response = await request("/api/v1/relational", validateRelational, { body: owned, signal });
      break;
    } catch (error) {
      // Rate refusal precedes session work. Only this identical operation retries.
      if (!(error instanceof BoardError) || error.status !== 429 || attempt === 3) throw error;
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  if ("describe" in owned) {
    if (!("description" in response)) throw new BoardError(0, "InvalidResponse");
  } else if ("storage" in owned) {
    if (!("storage" in response) || !sameBinding(owned.storage.binding, response.storage.binding))
      throw new BoardError(0, "InvalidResponse");
  } else if ("recover" in owned) {
    if (!("recovered" in response)) throw new BoardError(0, "InvalidResponse");
  } else {
    if (!("query" in response)) throw new BoardError(0, "InvalidResponse");
    const action = owned.query,
      result = response.query;
    if ("open" in action) {
      if (
        !("opened" in result) ||
        result.opened.reference.id !== action.open.id ||
        result.opened.description.sources.length !== action.open.statement.routes.length ||
        result.opened.description.sources.some(
          (source, index) =>
            !action.open.sources[index] ||
            source.alias !== action.open.sources[index]!.alias ||
            !sameBinding(source.binding, action.open.sources[index]!.binding) ||
            source.position.partition !== action.open.sources[index]!.position.partition ||
            source.position.next_lsn !== action.open.sources[index]!.position.next_lsn,
        )
      )
        throw new BoardError(0, "InvalidResponse");
    } else if ("page" in action) {
      if (
        !("page" in result) ||
        result.page.ordinal !== action.page.ordinal ||
        !sameReference(result.page.reference, action.page.reference)
      )
        throw new BoardError(0, "InvalidResponse");
    } else if ("explain" in action) {
      if (!("explained" in result)) throw new BoardError(0, "InvalidResponse");
    } else if ("close" in action) {
      if (!("closed" in result)) throw new BoardError(0, "InvalidResponse");
    } else if (!("capabilities" in result)) throw new BoardError(0, "InvalidResponse");
  }
  return response;
}
