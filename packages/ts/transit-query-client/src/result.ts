import { QueryError } from "./transport";
import type { Response as UnifiedQueryResponse } from "./types";

export type ResultPage = Extract<UnifiedQueryResponse, { page: unknown }>["page"];
export type ReadPage = (
  namespace: string,
  cursor: string | null,
  signal: AbortSignal,
) => Promise<ResultPage>;
const invalid = (): never => {
  throw new QueryError(0, "InvalidResponse");
};
/** One immutable result, one candidate segment at a time. The server verifies
 * each chained continuation and current policy. Only the null continuation
 * proves full ordered coverage; reread the visible page after that proof. */
export async function verifiedPage(
  namespace: string,
  visibleCursor: string | null,
  segmentBudget: string,
  signal: AbortSignal,
  read: ReadPage,
): Promise<ResultPage> {
  let cursor: string | null = null;
  let identity: string | null = null;
  let rows = 0n;
  let ordinal = 0n;
  const budget = BigInt(segmentBudget);
  do {
    signal.throwIfAborted();
    if (ordinal >= budget) return invalid();
    const page = await read(namespace, cursor, signal);
    const manifest = JSON.stringify(page.evidence.manifest);
    identity ??= manifest;
    if (
      manifest !== identity ||
      BigInt(page.evidence.ordinal) !== ordinal ||
      page.cells.length !== page.evidence.rows
    )
      return invalid();
    rows += BigInt(page.evidence.rows);
    ordinal += 1n;
    cursor = page.evidence.next;
    if (
      cursor === null &&
      (rows !== BigInt(page.evidence.manifest.rows) ||
        ordinal !== BigInt(page.evidence.manifest.segments))
    )
      return invalid();
    // No segment is appended to a resident array or retained for presentation.
  } while (cursor !== null);
  signal.throwIfAborted();
  const visible = await read(namespace, visibleCursor, signal);
  if (JSON.stringify(visible.evidence.manifest) !== identity) return invalid();
  signal.throwIfAborted();
  return visible;
}
