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
function reference(value: RelationalReference): boolean {
  return hex(value.id, 16) && !/^0+$/.test(value.id) && hex(value.plan, 32) && hex(value.basis, 32);
}
function description(value: Description): boolean {
  return (
    !value.executed &&
    hex(value.plan, 32) &&
    value.sources.length >= 1 &&
    value.sources.length <= 2 &&
    value.sources.every(
      (s) =>
        s.realm > 0 &&
        s.resource > 0 &&
        s.owner > 0 &&
        decimal(s.catalog, false, true) &&
        decimal(s.object, false, true) &&
        hex(s.schema, 32) &&
        s.realm === value.sources[0]!.realm,
    ) &&
    value.columns.length >= 1 &&
    value.columns.every((c) => !c.optional && ("int64" in c.type || "uint64" in c.type))
  );
}
export function validateRelational(value: unknown): value is RelationalResponse {
  if (!responseSchema(value)) return false;
  const response = value as RelationalResponse;
  if ("description" in response) {
    const { capabilities, routes } = response.description;
    return (
      capabilities.interactive &&
      capabilities.page_rows === 1 &&
      capabilities.active_queries === 1 &&
      capabilities.consistency === "per_resource_snapshot_vector" &&
      routes.length >= 1 &&
      routes.length <= 2 &&
      (response.description.active === null ||
        (decimal(response.description.active.ordinal) &&
          validateRelational({ query: { opened: response.description.active.opened } }))) &&
      routes.every(
        (r) =>
          decimal(r.connection.scope.catalog, false, true) &&
          decimal(r.policy_revision, false, true) &&
          r.connection.scope.realm > 0 &&
          r.connection.scope.resource > 0 &&
          r.connection.owner > 0 &&
          r.connection.principal > 0 &&
          r.connection.principal === routes[0]!.connection.principal &&
          r.connection.scope.realm === routes[0]!.connection.scope.realm,
      )
    );
  }
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
          cut.resource === value.description.sources[i]!.resource &&
          cut.schema === value.description.sources[i]!.schema &&
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
    } else if (!identity.group.every((key) => key === null || decimal(key, true))) return false;
    return (
      value.row.cells.length >= 1 &&
      value.row.cells.every((cell) => {
        if ("null" in cell) return true;
        if (!("value" in cell) || !("atom" in cell.value)) return false;
        const atom = cell.value.atom;
        return "signed" in atom
          ? decimal(atom.signed, true)
          : "unsigned" in atom && decimal(atom.unsigned);
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
  } else {
    if (!("query" in response)) throw new BoardError(0, "InvalidResponse");
    const action = owned.query,
      result = response.query;
    if ("open" in action) {
      if (
        !("opened" in result) ||
        result.opened.reference.id !== action.open.id ||
        result.opened.description.sources.length !== action.open.statement.routes.length
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
