import type { ComputationRequest, ComputationResponse } from "./types";
import {
  ComputationRequest as validRequest,
  ComputationResponse as validResponse,
} from "./computation-validators.js";
import { readDefinition } from "@transit/query-client/definition";
import { QueryError } from "@transit/query-client/error";
import { boundedQueryJson } from "@transit/query-client/logical";
import { request } from "./request";
export type { ComputationResponse } from "./types";
export type ComputationSelection = Omit<ComputationRequest, "definition" | "revision">;
export function definitionKey(value: ComputationResponse["binding"]["interpretation"]) {
  const object = value.object;
  return JSON.stringify([
    object.scope.realm,
    object.scope.resource,
    object.scope.catalog,
    object.branch,
    object.object,
    value.revision,
    value.digest,
  ]);
}
export function positiveRevision(value: string) {
  return /^[1-9][0-9]{0,19}$/.test(value) && BigInt(value) <= 18446744073709551615n;
}
export async function inspectComputation(
  selection: ComputationSelection,
  revision: string | null,
  signal?: AbortSignal,
): Promise<ComputationResponse> {
  const body: ComputationRequest = { definition: readDefinition, ...selection, revision };
  if (
    (revision !== null && !positiveRevision(revision)) ||
    !boundedQueryJson(body, 4096) ||
    !validRequest(body)
  )
    throw new QueryError(0, "InvalidComputationRequest");
  const value = await request(
    "/api/v1/computations",
    (input: unknown): input is ComputationResponse =>
      boundedQueryJson(input, 262144) && validResponse(input),
    { body, signal },
  );
  if (
    value.definition !== readDefinition ||
    value.binding.namespace !== selection.namespace ||
    value.binding.name !== selection.name ||
    (selection.expected &&
      definitionKey(selection.expected) !== definitionKey(value.binding.interpretation)) ||
    (revision === null
      ? value.current === null
      : value.current !== null || value.completed?.revision !== revision) ||
    (value.completed &&
      (value.completed.decision.outcome !== "committed" ||
        !positiveRevision(value.completed.revision) ||
        definitionKey(value.completed.source) !== definitionKey(value.source.interpretation) ||
        definitionKey(value.completed.output) !== definitionKey(value.output.interpretation)))
  )
    throw new QueryError(0, "ResultIdentityChanged");
  return value;
}
