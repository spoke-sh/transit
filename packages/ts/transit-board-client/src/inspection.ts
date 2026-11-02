import { QueryError as BoardError } from "@transit/query-client/error";
import { request } from "./request";
import type { StateResponse } from "./types";
import { inspectionResponse, type Response } from "./effects";
import {
  Response as responseValidator,
  StateResponse as stateResponseValidator,
} from "./inspection-validators.js";
export type Page = Response["observation"];
export type Process = NonNullable<Page["processes"][number]>;
export type Event = NonNullable<Page["events"][number]>;
export type Outbox = NonNullable<Page["outbox"][number]>;
export type Resource = Page["resource"] | "journey";
export type Cut = Page["cut"];
export const validateResponse = (value: unknown): value is Response => {
  if (!responseValidator(value)) return false;
  try {
    return !inspectionResponse(value).effectDiagnosticsInvalid;
  } catch {
    return false;
  }
};
export function read(
  resource: Resource,
  pid?: number,
  continuation?: { cut: Cut; after: number },
  signal?: AbortSignal,
) {
  if (pid !== undefined && (!Number.isSafeInteger(pid) || pid <= 0))
    throw new BoardError(0, "InvalidPid");
  const base =
    resource === "processes"
      ? "/api/v1/processes"
      : `/api/v1/processes/${pid}${resource === "process" ? "" : `/${resource}`}`;
  const query = continuation
    ? `?${new URLSearchParams(Object.entries({ after: continuation.after, ...continuation.cut }).map(([key, value]) => [key, String(value)]))}`
    : "";
  return request(base + query, (value: unknown): value is unknown => value !== undefined, {
    signal,
  }).then(inspectionResponse);
}
export type StateResource = "resources" | "associations" | "entries";
export const validateStateResponse = (value: unknown): value is StateResponse =>
  stateResponseValidator(value);
export function readState(
  resource: StateResource,
  id?: number,
  continuation?: { cut: Cut; after: number },
  signal?: AbortSignal,
) {
  if (id !== undefined && (!Number.isSafeInteger(id) || id <= 0))
    throw new BoardError(0, "InvalidResource");
  if (resource !== "resources" && id === undefined) throw new BoardError(0, "InvalidResource");
  const base =
    resource === "associations"
      ? `/api/v1/processes/${id}/associations`
      : `/api/v1/resources${id === undefined ? "" : `/${id}`}${resource === "entries" ? "/entries" : ""}`;
  const query = continuation
    ? `?${new URLSearchParams(Object.entries({ after: continuation.after, ...continuation.cut }).map(([key, value]) => [key, String(value)]))}`
    : "";
  return request(base + query, validateStateResponse, { signal });
}

export { inspectionResponse, type Response } from "./effects";
