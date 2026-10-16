package io.transit.client;
import io.transit.client.internal.Values;
import java.util.Objects;
public final class PendingSend implements AutoCloseable {
    public record Info(OperationIdentity identity, ProcessRef peer, long principal, long sequence) {
        public Info { Objects.requireNonNull(identity); Objects.requireNonNull(peer); Values.counter(principal, 0); Values.counter(sequence, 1); }
    }
    private final Info info;
    private byte[] bytes;
    /** Advanced construction does not bypass native validation at dispatch. */
    public PendingSend(Info info, byte[] bytes) { this.info = Objects.requireNonNull(info); this.bytes = Values.bytes(bytes, Values.MAX_BODY); }
    public Info info() { return info; }
    public synchronized byte[] export() {
        if (bytes == null) throw new TransitException(TransitException.Kind.CLOSED, "pending");
        return bytes.clone();
    }
    @Override public synchronized void close() { bytes = null; }
    @Override public String toString() { return "PendingSend[" + info.identity().sha256() + "]"; }
}
