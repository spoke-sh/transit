package io.transit.sdk.station;
import io.transit.client.OperationIdentity;
import io.transit.client.Outcomes.MutationReceipt;
import io.transit.sdk.station.Types.FrozenMutation;
import java.util.Objects;
public sealed interface Recovery permits Recovery.FreshOwnership, Recovery.PersistBeforeDispatch {
    record FreshOwnership() implements Recovery {}
    record PersistBeforeDispatch(Store store) implements Recovery { public PersistBeforeDispatch { Objects.requireNonNull(store); } }
    interface Store {
        void beforeDispatch(FrozenMutation mutation);
        void confirmed(OperationIdentity identity, MutationReceipt receipt);
    }
}
