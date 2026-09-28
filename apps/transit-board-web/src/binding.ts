import type { Definition } from "@rey/transit-application";
import {
  BoardError,
  type QueryResponse,
  type UnifiedQueryResponse,
} from "@rey/transit-board-client";
export type QueryBinding = Extract<
  Definition["bindings"][number]["source"],
  { query: unknown }
>["query"];
export const sameDigest = (a: number[], b: number[]) =>
  a.length === 32 && b.length === 32 && a.every((byte, i) => byte === b[i]);
export function mismatch(): never {
  throw new BoardError(409, "BindingChanged");
}
export function unifiedContract(
  binding: QueryBinding,
  value: Extract<UnifiedQueryResponse, { compiled: unknown }>["compiled"],
) {
  if (
    binding.profile !== "unified_v2" ||
    value.source.resource !== binding.resource ||
    !(binding.source_kind in value.source.source) ||
    !sameDigest(binding.schema, value.contract)
  )
    mismatch();
}
export function unifiedPage(
  binding: QueryBinding,
  page: Extract<UnifiedQueryResponse, { page: unknown }>["page"],
) {
  const basis = page.evidence.manifest.basis;
  if (
    basis.resource !== binding.resource ||
    basis.kind !== binding.source_kind ||
    !sameDigest(basis.contract, binding.schema)
  )
    mismatch();
}
export type TableContract = Extract<QueryResponse, { contract: unknown }>["contract"];
export function tableContract(binding: QueryBinding, value: TableContract) {
  if (
    binding.profile !== "table_v1" ||
    binding.source_kind !== "table" ||
    value.source.connection.resource !== binding.resource ||
    value.source.connection.name !== binding.name ||
    !sameDigest(value.fingerprint, binding.schema)
  )
    mismatch();
}
export function tablePage(
  contract: TableContract,
  page: Extract<QueryResponse, { page: unknown }>["page"],
) {
  if (
    page.manifest.table !== contract.source.connection.table ||
    page.manifest.basis.resource !== contract.source.connection.resource ||
    !sameDigest(page.manifest.basis.schema, contract.schema)
  )
    mismatch();
}
