package io.transit.client;
import io.transit.client.internal.Values;
import java.util.Objects;
public final class Outcomes {
    private Outcomes() {}
    public record AdmissionReceipt(long position) { public AdmissionReceipt { Values.counter(position, 1); } }
    public record MutationReceipt(long position) { public MutationReceipt { Values.counter(position, 1); } }
    public sealed interface SendOutcome permits Admitted, Rejected, Uncertain {}
    public sealed interface MutationOutcome permits Confirmed, Rejected, Uncertain {}
    public record Admitted(AdmissionReceipt receipt) implements SendOutcome { public Admitted { Objects.requireNonNull(receipt); } }
    public record Confirmed(MutationReceipt receipt) implements MutationOutcome { public Confirmed { Objects.requireNonNull(receipt); } }
    public record Rejected(TransitException error) implements SendOutcome, MutationOutcome { public Rejected { Objects.requireNonNull(error); } }
    public static final class Uncertain implements SendOutcome, MutationOutcome {
        private final byte[] bytes;
        private final TransitException error;
        public Uncertain(byte[] bytes, TransitException error) { this.bytes = Values.bytes(bytes, Values.MAX_BODY); this.error = Objects.requireNonNull(error); }
        public byte[] recovery() { return bytes.clone(); }
        public TransitException error() { return error; }
        @Override public String toString() { return "Uncertain[status=" + error.status() + "]"; }
    }
    public record Shutdown(AdmissionReceipt lastAdmission, MutationReceipt lastMutation) {}
    public record Capabilities(long realm, long observedAt, long principalSequence, int pageSize,
                               int mutationsPerTurn, int outputsPerTurn, boolean retainedVersions,
                               boolean associationLookup, boolean scopedRetry, boolean station) {}
}
