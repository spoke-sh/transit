import { BoardError, unifiedQuery as query } from "@rey/transit-board-client";
import { LiveView, ReactiveError, Session } from "@rey/transit-reactive-client";
import { verifiedPage, type ResultPage } from "./unified-result";

export const querySession = new Session();
let identity: { resource: number; contract: string; plan: string } | null = null;
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
      resource: basis.resource,
      contract: JSON.stringify(basis.contract),
      plan: JSON.stringify(page.evidence.manifest.plan),
    };
    if (basis.kind !== "table" || basis.resource !== description.description.source.source.resource)
      throw new ReactiveError(409, "reset_required");
    if (identity && JSON.stringify(identity) !== JSON.stringify(next))
      throw new ReactiveError(409, "reset_required");
    identity = next;
    return { value: page, basis, namespace };
  } catch (error) {
    if (error instanceof BoardError)
      throw new ReactiveError(
        error.status,
        error.status === 403 ? "denied" : error.status === 410 ? "expired" : "query_unavailable",
      );
    throw error;
  }
});
