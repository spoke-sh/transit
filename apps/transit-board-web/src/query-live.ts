import { BoardError, unifiedQuery as query } from "@rey/transit-board-client";
import { LiveView, ReactiveError, Session } from "@rey/transit-reactive-client";
import { verifiedPage, type ResultPage } from "./unified-result";
import { DraftSession } from "@rey/transit-query-client";

export const liveDraft = new DraftSession(query);

export const querySession = new Session();
let identity: { resource: number; contract: string; schema: string } | null = null;
export function selectLiveTemplate() {
  identity = null;
}
export const liveQuery = new LiveView<ResultPage>(querySession, async (signal, namespace) => {
  if (!namespace) throw new ReactiveError(0, "query_absent");
  try {
    const description = await query({ describe: {} }, signal);
    if (!("description" in description)) throw new ReactiveError(0, "invalid_response");
    const page = await verifiedPage(
      namespace,
      null,
      description.description.budgets.segments,
      signal,
    );
    const basis = page.evidence.manifest.basis;
    const next = {
      resource: basis.cut.resource,
      contract: JSON.stringify(basis.contract),
      schema: JSON.stringify(basis.schema),
    };
    if (
      basis.cut.kind !== "table" ||
      basis.cut.resource !== description.description.source.source.resource
    )
      throw new ReactiveError(409, "reset_required");
    // The durable refresh generation copies the original submitted bundle and
    // verifies its commitment before execution. Its bound plan fingerprint also
    // includes the captured source basis, so it changes on a legitimate refresh.
    // Keep source/contract/schema fixed here; verifiedPage checks the complete
    // manifest, including that execution fingerprint, within each finite result.
    if (identity && JSON.stringify(identity) !== JSON.stringify(next))
      throw new ReactiveError(409, "reset_required");
    identity = next;
    // Follow compares source coverage. The full captured head remains on page;
    // a watch watermark is not an immutable result or a retained source pin.
    return {
      value: page,
      basis,
      namespace,
    };
  } catch (error) {
    if (error instanceof BoardError)
      throw new ReactiveError(
        error.status,
        error.status === 403 ? "denied" : error.status === 410 ? "expired" : "query_unavailable",
      );
    throw error;
  }
});
