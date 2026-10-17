package io.transit.client;
import io.transit.client.internal.Values;
public record ResourceRef(long realm, long resource) {
    public ResourceRef { Values.counter(realm, 1); Values.counter(resource, 1); }
}
