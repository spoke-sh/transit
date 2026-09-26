package io.transit.client;
import io.transit.client.internal.Values;
import java.nio.file.Path;
import java.util.Objects;
public record Credential(long realm, long principal, Path seedFile) {
    public Credential {
        Values.counter(realm, 1); Values.counter(principal, 0);
        Objects.requireNonNull(seedFile); Values.text(seedFile.toString(), 4096);
        if (seedFile.toString().isEmpty()) throw new IllegalArgumentException("An explicit seed file is required");
        seedFile = seedFile.toAbsolutePath();
    }
    @Override public String toString() { return "Credential[realm=" + realm + ", principal=" + principal + "]"; }
}
