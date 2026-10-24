import { QueryError, type Transport } from "./transport";
import type { Response } from "./types";

type Compiled = Extract<Response, { compiled: unknown }>["compiled"];

/** Authorize a new finite Table read before uploading its first byte. Persist
 * the returned bundle; accepted-work recovery must never call this function. */
export async function prepareCapture(
  transport: Transport,
  compiled: Compiled,
  operation: string,
  signal?: AbortSignal,
): Promise<Compiled> {
  if (!("table" in compiled.source.source)) return compiled;
  const response = await transport({ capture: { bundle: compiled.bundle, operation } }, signal);
  if (!("compiled" in response)) throw new QueryError(0, "InvalidResponse");
  for (const field of ["source", "plan", "limits", "contract", "schema"] as const)
    if (JSON.stringify(response.compiled[field]) !== JSON.stringify(compiled[field]))
      throw new QueryError(409, "CaptureScopeChanged");
  return response.compiled;
}
