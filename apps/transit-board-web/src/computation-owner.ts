import {
  inspectComputation,
  type ComputationSelection,
  type ComputationResponse,
} from "@transit/board-client/computations";
import { initialObservation, type Observation, type ReadFailure } from "./observation";
import { ObservationOwner } from "./observation-owner";
export type ComputationState = {
  current: Observation<ComputationResponse>;
  selected: Observation<ComputationResponse>;
  revision: string | null;
  failure: ReadFailure | null;
};
export const initialComputation = (): ComputationState => ({
  current: initialObservation(),
  selected: initialObservation(),
  revision: null,
  failure: null,
});

/** Two bounded observations share one disclosure boundary and exact definition.
 * A denial invalidates both, including in-flight replies and inspector evidence. */
export class ComputationOwner {
  state = initialComputation();
  private current: ObservationOwner<ComputationResponse> | null = null;
  private selected: ObservationOwner<ComputationResponse> | null = null;
  private hidden = false;
  private disposed = false;
  constructor(
    private selection: ComputationSelection,
    private readonly publish: (state: ComputationState) => void,
    private readonly read = inspectComputation,
  ) {}
  private observation(kind: "current" | "selected", revision: string | null) {
    return new ObservationOwner<ComputationResponse>(
      async (signal) => {
        const response = await this.read(this.selection, revision, signal);
        signal.throwIfAborted();
        this.selection = { ...this.selection, expected: response.binding.interpretation };
        return response;
      },
      (value) => {
        if (this.disposed) return;
        if (value.failure && ["denied", "expired", "incompatible"].includes(value.failure.kind)) {
          this.stop();
          this.state = {
            ...initialComputation(),
            revision: this.state.revision,
            failure: value.failure,
          };
        } else this.state = { ...this.state, [kind]: value };
        this.publish(this.state);
      },
    );
  }
  private stop() {
    this.current?.send({ type: "dispose" });
    this.selected?.send({ type: "dispose" });
    this.current = null;
    this.selected = null;
  }
  retry() {
    if (this.disposed || this.hidden) return;
    this.stop();
    this.state = { ...initialComputation(), revision: this.state.revision };
    this.current = this.observation("current", null);
    this.current.send({ type: "read" });
    // Revalidate the exact binding before revealing a retained selection.
    if (this.selection.expected && this.state.revision !== null) this.select(this.state.revision);
  }
  select(revision: string | null) {
    if (this.disposed || this.state.failure) return;
    this.selected?.send({ type: "dispose" });
    this.selected = null;
    this.state = { ...this.state, revision, selected: initialObservation() };
    this.publish(this.state);
    if (revision === null || this.hidden || !this.selection.expected) return;
    this.selected = this.observation("selected", revision);
    this.selected.send({ type: "read" });
  }
  visibility(hidden: boolean) {
    if (this.disposed) return;
    this.hidden = hidden;
    if (hidden) {
      this.stop();
      this.state = {
        ...initialComputation(),
        revision: this.state.revision,
        failure: this.state.failure,
      };
      this.publish(this.state);
    } else this.retry();
  }
  dispose() {
    this.disposed = true;
    this.stop();
    this.state = initialComputation();
  }
}
