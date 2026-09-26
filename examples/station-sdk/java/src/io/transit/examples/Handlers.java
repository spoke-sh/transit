package io.transit.examples;

import io.transit.client.*;
import io.transit.sdk.station.*;
import io.transit.sdk.station.Types.*;
import io.transit.examples.Messages.*;
import java.math.BigInteger;
import java.util.Objects;
import java.util.function.Consumer;

public final class Handlers {
    private Handlers() {}
    public static final Key<BigInteger> TOTAL = new Key<>("total", Codecs.U64);
    public static final Key<BigInteger> REQUEST = new Key<>("request", Codecs.U64);
    public static final Key<BigInteger> OBSERVED = new Key<>("observed", Codecs.U64);
    public static final Table.Schema<Long> TABLE = new Table.Schema<>(1, Table.INT64);
    private static TransitException unexpected() { return new TransitException(TransitException.Kind.HANDLER, "unexpected-application-input"); }
    public static class Counter implements Handler<CounterMessage> {
        @Override public void initialize(Turn turn) { turn.state().put(TOTAL, BigInteger.ZERO); }
        @Override public void onMessage(Turn turn, Incoming<CounterMessage> input) {
            if (input instanceof Cast<CounterMessage> && input.value() instanceof Add add) {
                turn.state().put(TOTAL, Messages.u64(turn.state().require(TOTAL).add(add.value())));
            } else if (input instanceof Call<CounterMessage> && input.value() instanceof Read) {
                turn.reply(new Total(turn.state().require(TOTAL)), Codecs.REPLY);
            } else throw unexpected();
        }
    }
    public static class Requester implements Handler<CounterMessage> {
        private final ProcessRef peer;
        public Requester(ProcessRef peer) { this.peer = Objects.requireNonNull(peer); }
        @Override public void onMessage(Turn turn, Incoming<CounterMessage> input) {
            if (input instanceof Cast<CounterMessage> && input.value() instanceof Start) {
                if (turn.state().find(REQUEST).isPresent()) throw unexpected();
                BigInteger correlation = turn.call(peer, new Read(), Codecs.COUNTER, WaitPolicy.untimed());
                turn.state().put(REQUEST, correlation);
            } else if (input instanceof Reply<CounterMessage> reply && input.value() instanceof Total total) {
                turn.requireReply(reply, peer, turn.state().require(REQUEST));
                turn.state().put(OBSERVED, total.value());
            } else throw unexpected();
        }
    }
    public static class TableService implements Handler<QueryMessage> {
        private final ProcessRef peer;
        public TableService(ProcessRef peer) { this.peer = Objects.requireNonNull(peer); }
        @Override public void initialize(Turn turn) {
            turn.createTable(TABLE); turn.allowQuery(peer, TABLE, 0, true);
        }
        @Override public void onMessage(Turn turn, Incoming<QueryMessage> input) {
            if (input instanceof Cast<QueryMessage> && input.value() instanceof Initialize) return;
            if (input instanceof Cast<QueryMessage> && input.value() instanceof Insert insert) turn.table(TABLE).insert(new Table.Row<>(insert.key(), insert.value()));
            else if (input instanceof Call<QueryMessage> && input.value() instanceof Rows) turn.startQuery(TABLE, new Query.Plan(Query.Projection.BOTH, Query.Aggregate.ROWS, Messages.U64_MAX, new Query.All()));
            else throw unexpected();
        }
    }
    public static class QueryRequester implements Handler<QueryMessage> {
        private final ProcessRef peer;
        private final Consumer<Query.IpcSegment> consume;
        public QueryRequester(ProcessRef peer, Consumer<Query.IpcSegment> consume) { this.peer = Objects.requireNonNull(peer); this.consume = Objects.requireNonNull(consume); }
        @Override public void onMessage(Turn turn, Incoming<QueryMessage> input) {
            if (!(input instanceof Cast<QueryMessage>) || !(input.value() instanceof Start) || turn.state().find(REQUEST).isPresent()) throw unexpected();
            BigInteger correlation = turn.call(peer, new Rows(), Codecs.QUERY_SERVICE, WaitPolicy.untimed());
            turn.state().put(REQUEST, correlation);
        }
        @Override public void onResult(Turn turn, ResultComplete complete) {
            Query.ResultReader reader = turn.result(complete.correlation());
            Query.Manifest manifest = reader.manifest();
            if (!manifest.source().equals(peer) || !manifest.correlation().equals(turn.state().require(REQUEST))) throw unexpected();
            // Consume one bounded segment at a time. External callback effects need application idempotency.
            for (BigInteger ordinal = BigInteger.ZERO; ordinal.compareTo(manifest.segments()) < 0; ordinal = ordinal.add(BigInteger.ONE)) consume.accept(reader.segment(ordinal));
            turn.state().put(OBSERVED, manifest.rows());
        }
    }
}
