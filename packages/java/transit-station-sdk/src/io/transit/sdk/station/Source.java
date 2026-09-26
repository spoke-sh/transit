package io.transit.sdk.station;
import io.transit.sdk.station.Types.ReadVersion;
public final class Source {
    private final Turn turn;
    private final ReadVersion identity;
    Source(Turn turn, ReadVersion identity) { this.turn = turn; this.identity = identity; }
    public ReadVersion identity() { return identity; }
    public State state() { turn.check(); return new State(turn, identity); }
    public <T> Table<T> table(Table.Schema<T> schema) { return turn.access(true, () -> Table.open(turn, schema, identity)); }
}
