package io.transit.sdk.station;

import io.transit.client.*;
import io.transit.client.internal.Values;
import java.math.BigInteger;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

public final class Types {
    private Types() {}
    public enum FailurePolicy { STOP, BLOCK_INPUT }
    public record Activation(ProcessRef process, long generation, Credential credential) {
        public Activation {
            Objects.requireNonNull(process); Objects.requireNonNull(credential); Values.counter(generation, 1);
            if (process.realm() != credential.realm()) throw new IllegalArgumentException("Activation realm mismatch");
        }
    }
    public record ServiceConfig(ClientConfig client, Activation activation, String association, boolean queryResults) {
        public ServiceConfig {
            Objects.requireNonNull(client); Objects.requireNonNull(activation); Values.text(association, 256);
            if (association.isEmpty()) throw new IllegalArgumentException("Association is required");
        }
        public ServiceConfig(ClientConfig client, Activation activation) { this(client, activation, "data", false); }
    }
    public record WaitPolicy(Long deadlineMillis, ProcessRef observer) {
        public WaitPolicy {
            if ((deadlineMillis == null) != (observer == null)) throw new IllegalArgumentException("Timed waits require deadline and observer");
            if (deadlineMillis != null) Values.counter(deadlineMillis, 1);
        }
        public static WaitPolicy untimed() { return new WaitPolicy(null, null); }
        public static WaitPolicy until(long deadlineMillis, ProcessRef observer) { return new WaitPolicy(deadlineMillis, Objects.requireNonNull(observer)); }
    }
    public sealed interface Origin permits ExternalOrigin, ProcessOrigin, EffectOrigin {}
    public record ExternalOrigin(long principal, long policyRevision) implements Origin {}
    public record ProcessOrigin(ProcessRef process, long turn, long output) implements Origin {}
    public record EffectOrigin(long effect, long attempt, long executor) implements Origin {}
    public sealed interface Incoming<T> permits Cast, Call, Reply {
        T value(); long position(); Origin origin();
    }
    public record Cast<T>(T value, long position, Origin origin) implements Incoming<T> {}
    public record Call<T>(T value, long position, Origin origin, BigInteger correlation) implements Incoming<T> {}
    public record Reply<T>(T value, long position, Origin origin, BigInteger correlation) implements Incoming<T> {}
    public enum ControlKind { CANCEL, TIMEOUT }
    public record Control(ControlKind kind, long position, Origin origin, BigInteger correlation) {}
    public enum QueryFailureReason { RESULT_TOO_LARGE, WORKSPACE_EXCEEDED, OVERFLOW, CANCELLED, DENIED }
    public record QueryFailure(long position, Origin origin, BigInteger correlation, long result, QueryFailureReason reason) {}
    public record ResultComplete(long position, Origin origin, BigInteger correlation) {}
    public record Budgets(int mutations, int outputs, int views, int retainedReads, int retains, int releases) {}
    public record ReadVersion(long pid, long input, int index) {
        public ReadVersion {
            Values.counter(pid, 1); Values.counter(input, 1);
            if (index < 0 || index > 255) throw new IllegalArgumentException("Read-version index exceeds its bound");
        }
    }
    public record Cursor(String opaque) { public Cursor { Values.text(opaque, Values.MAX_BODY); } }
    public record Basis(ResourceRef resource, long revision, Bytes schema) {
        public Basis { Objects.requireNonNull(resource); Values.counter(revision, 0); Objects.requireNonNull(schema); if (schema.size() != 32) throw new IllegalArgumentException("Invalid schema digest"); }
    }
    public record Page<T>(List<T> entries, Cursor cursor, Basis basis) { public Page { entries = List.copyOf(entries); } }
    public record KVEntry(Bytes key, Bytes value, long revision) {}
    public enum Purpose { PERMIT, OPEN, COMMIT }
    public record FrozenMutation(OperationIdentity identity, Purpose purpose, long inputPosition, Bytes bytes) {
        public FrozenMutation { Objects.requireNonNull(identity); Objects.requireNonNull(purpose); Values.counter(inputPosition, 1); Objects.requireNonNull(bytes); }
        public byte[] export() { return bytes.copy(); }
        @Override public String toString() { return "FrozenMutation[" + purpose + ", " + identity.sha256() + "]"; }
    }
    public sealed interface Event permits Committed, Blocked, NeedsRecovery, Idle, Progress, Stopped {}
    public record Committed(long input, Outcomes.MutationReceipt receipt) implements Event {}
    public record Blocked(Long input, Outcomes.MutationReceipt receipt) implements Event {}
    public record NeedsRecovery(FrozenMutation mutation, String phase, TransitException error, Outcomes.MutationReceipt receipt) implements Event {}
    public record Idle() implements Event {}
    public record Progress() implements Event {}
    public record Stopped() implements Event {}
    public record Shutdown(FrozenMutation pending, Event lastEvent) {}
    public static final class StopToken {
        private final AtomicBoolean stopped = new AtomicBoolean();
        public void stop() { stopped.set(true); }
        public boolean stopped() { return stopped.get(); }
    }
}
