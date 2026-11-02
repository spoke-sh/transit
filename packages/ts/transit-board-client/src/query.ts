import { httpTransport } from "@transit/query-client/transport";
import type { UnifiedQueryRequest, UnifiedQueryResponse } from "./types";
export type { UnifiedQueryRequest, UnifiedQueryResponse } from "./types";
const queryTransport = /* @__PURE__ */ httpTransport("/api/v1/query");
export const unifiedQuery = (
  operation: UnifiedQueryRequest,
  signal?: AbortSignal,
): Promise<UnifiedQueryResponse> => queryTransport(operation, signal);
