package io.transit.client;
import io.transit.client.internal.Values;
import java.util.Objects;
public final class PendingMutation implements AutoCloseable {
    public record Info(OperationIdentity identity, long realm, long principal, long sequence, String command) {
        public Info {
            Objects.requireNonNull(identity); Values.counter(realm, 1); Values.counter(principal, 0); Values.counter(sequence, 1);
            Values.text(command, 64);
        }
    }
    private final Info info;
    private byte[] bytes;
    public PendingMutation(Info info, byte[] bytes) { this.info = Objects.requireNonNull(info); this.bytes = Values.bytes(bytes, Values.MAX_BODY); }
    public Info info() { return info; }
    public synchronized byte[] export() {
        if (bytes == null) throw new TransitException(TransitException.Kind.CLOSED, "pending");
        return bytes.clone();
    }
    @Override public synchronized void close() { bytes = null; }
    @Override public String toString() { return "PendingMutation[" + info.identity().sha256() + "]"; }
}
