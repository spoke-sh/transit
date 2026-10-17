package io.transit.client;
import io.transit.client.internal.Values;
public record ProcessRef(long realm, long pid) {
    public ProcessRef { Values.counter(realm, 1); Values.counter(pid, 1); }
}
