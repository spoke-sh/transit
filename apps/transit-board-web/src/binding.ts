import type { Definition } from "@transit/application";
import { BoardError, type UnifiedQueryResponse } from "@transit/board-client";
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
    binding.profile !== "unified_v1" ||
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
    basis.cut.resource !== binding.resource ||
    basis.cut.kind !== binding.source_kind ||
    !sameDigest(basis.contract, binding.schema)
  )
    mismatch();
}
