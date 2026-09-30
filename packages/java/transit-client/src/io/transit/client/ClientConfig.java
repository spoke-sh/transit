package io.transit.client;
import io.transit.client.internal.Values;
import java.net.URI;
import java.nio.file.Path;
import java.util.Objects;
public record ClientConfig(URI endpoint, Profile profile, int timeoutMillis, Path nativeHost) {
    public enum Profile { NATIVE_V1 }
    public ClientConfig {
        Objects.requireNonNull(endpoint); Objects.requireNonNull(profile);
        Values.text(endpoint.toString(), 4096);
        if (!("http".equals(endpoint.getScheme()) || "https".equals(endpoint.getScheme())) ||
            endpoint.getHost() == null || endpoint.getUserInfo() != null || endpoint.getQuery() != null || endpoint.getFragment() != null ||
            timeoutMillis < 1 || timeoutMillis > 60_000) throw new IllegalArgumentException("Invalid Transit endpoint or timeout");
        if (nativeHost != null) nativeHost = nativeHost.toAbsolutePath();
    }
    public ClientConfig(URI endpoint, Profile profile) { this(endpoint, profile, 5000, null); }
}
