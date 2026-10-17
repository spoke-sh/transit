package io.transit.client;
public record OperationIdentity(String sha256) {
    public OperationIdentity {
        if (sha256 == null || !sha256.matches("[0-9a-f]{64}")) throw new IllegalArgumentException("Invalid operation identity");
    }
}
