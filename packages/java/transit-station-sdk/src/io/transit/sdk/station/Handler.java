package io.transit.sdk.station;
import io.transit.client.TransitException;
import io.transit.sdk.station.Types.*;
public interface Handler<T> {
    default void initialize(Turn turn) {}
    void onMessage(Turn turn, Incoming<T> input);
    default void onControl(Turn turn, Control input) { throw new TransitException(TransitException.Kind.HANDLER, "unhandled-control"); }
    default void onResult(Turn turn, ResultComplete input) { throw new TransitException(TransitException.Kind.HANDLER, "unhandled-result"); }
}
