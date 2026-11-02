import type { Observation, ReadFailure } from "./observation";

export type InspectionEvidence<T> = { scope: string; value: T; failure: ReadFailure | null };
/** Process/resource inspection permits explicitly stale evidence on transient
 * loss. This never supplies a current observation, a result or a new source cut. */
export function inspectionEvidence<T>(
  previous: InspectionEvidence<T> | null,
  scope: string,
  state: Observation<T>,
): InspectionEvidence<T> | null {
  if (state.value !== null) return { scope, value: state.value, failure: null };
  if (previous?.scope !== scope || ["idle", "hidden", "disposed"].includes(state.tag)) return null;
  if (state.failure) {
    if (state.failure.kind !== "unavailable" && state.failure.kind !== "limited") return null;
    return { ...previous, failure: state.failure };
  }
  return previous.failure ? previous : null;
}
