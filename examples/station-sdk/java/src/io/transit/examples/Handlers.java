package io.transit.examples;

import io.transit.client.*;
import io.transit.sdk.station.*;
import io.transit.sdk.station.Types.*;
import io.transit.examples.Messages.*;
import java.math.BigInteger;
import java.util.*;
import java.util.function.Consumer;

public final class Handlers {
    private Handlers() {}
    public static final Key<BigInteger> TOTAL = new Key<>("total", Codecs.U64);
    public static final Key<BigInteger> REQUEST = new Key<>("request", Codecs.U64);
    public static final Key<BigInteger> OBSERVED = new Key<>("observed", Codecs.U64);
    public static Logical.Cell signed(long value) { return new Logical.Present(new Logical.Signed(BigInteger.valueOf(value))); }
    public static final Catalog.Schema TABLE = new Catalog.Schema(BigInteger.ONE, BigInteger.ONE, BigInteger.valueOf(5), List.of(
        new Catalog.Column(BigInteger.ONE, "id", Logical.Scalar.INT64, false, Optional.empty(), Optional.empty()),
        new Catalog.Column(BigInteger.TWO, "value", Logical.Scalar.INT64),
        new Catalog.Column(BigInteger.valueOf(3), "label", Logical.Scalar.UTF8, false, Optional.of(new Logical.Present(new Logical.Utf8("example"))), Optional.empty()),
        new Catalog.Column(BigInteger.valueOf(4), "tags", new Logical.ListType(new Logical.Element(Logical.Scalar.INT64)), false,
            Optional.of(new Logical.Present(new Logical.Sequence(Logical.SequenceKind.LIST, List.of(signed(1), signed(2))))), Optional.empty())
    ), List.of(BigInteger.ONE));
    public static final Catalog.TableLimits TABLE_LIMITS = new Catalog.TableLimits(65536, BigInteger.valueOf(8388608), 1024);
    public static final Key<BigInteger> NOT_READY = new Key<>("not-ready", Codecs.U64);
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
        private TableWork.Queue queue(Turn turn) { return turn.state().find(TableWork.QUEUE).orElseGet(TableWork.Queue::new); }
        private void wake(Turn turn) { turn.cast(turn.process(), new Advance(), Codecs.QUERY_SERVICE); }
        private void enqueue(Turn turn, long position, QueryMessage command) {
            if (position < 1 || BigInteger.valueOf(position).compareTo(TableWork.MAX_INPUT) > 0) throw unexpected();
            BigInteger identity = BigInteger.valueOf(position);
            TableWork.Queue queue = queue(turn);
            Key<TableWork.Work> key = TableWork.workKey(identity);
            if (turn.state().find(key).isPresent() || turn.state().find(TableWork.outcomeKey(identity)).isPresent()) throw unexpected();
            BigInteger head = identity;
            if (queue.tail().signum() != 0) {
                if (identity.compareTo(queue.tail()) <= 0) throw unexpected();
                TableWork.Work tail = turn.state().require(TableWork.workKey(queue.tail()));
                if (tail.next().signum() != 0) throw unexpected();
                turn.state().put(TableWork.workKey(queue.tail()), new TableWork.Work(identity, tail.command())); head = queue.head();
            } else if (!queue.ready() && !(command instanceof Initialize)) {
                turn.state().put(TableWork.workKey(TableWork.INITIAL), new TableWork.Work(identity, new Initialize())); head = TableWork.INITIAL;
            }
            turn.state().put(key, new TableWork.Work(BigInteger.ZERO, command));
            turn.state().put(TableWork.QUEUE, new TableWork.Queue(head, identity, queue.ready()));
            if (queue.head().signum() == 0) wake(turn);
        }
        private Optional<TableWork.Outcome> step(Turn turn, TableWork.Queue queue, QueryMessage command) {
            if (command instanceof Initialize) {
                Table.Creation status = turn.createTable(TABLE, TABLE_LIMITS);
                if (status.state() == Table.CreationState.BUILDING) return Optional.empty();
                return Optional.of(new TableWork.Outcome(0, status.admittedInput(), status.completedInput().orElseThrow(), BigInteger.ZERO, BigInteger.ZERO, 0));
            }
            if (!queue.ready() || queue.head().equals(TableWork.INITIAL)) throw unexpected();
            long key = switch(command) { case Insert c -> c.key(); case Update c -> c.key(); case Delete c -> c.key(); default -> throw unexpected(); };
            List<Catalog.Predicate> predicate = List.of(new Catalog.Comparison(BigInteger.ONE, Catalog.CompareOperator.EQ, new Logical.Signed(BigInteger.valueOf(key))));
            Catalog.Mutation mutation;
            if (command instanceof Delete) mutation = new Catalog.Delete(Optional.of(predicate));
            else {
                Long cell = command instanceof Insert c ? c.value() : ((Update)command).value();
                Logical.Cell value = cell == null ? new Logical.Null() : signed(cell);
                Catalog.Assignment assignment = new Catalog.Assignment(BigInteger.TWO, new Catalog.CellValue(value));
                mutation = command instanceof Insert ? new Catalog.Insert(List.of(List.of(new Catalog.Assignment(BigInteger.ONE, new Catalog.CellValue(signed(key))), assignment))) :
                    new Catalog.Update(List.of(assignment), Optional.of(predicate));
            }
            Table.MutationStatus status = Table.Mutation.prepare(turn.resource(), 0, queue.head(), TABLE, mutation).step(turn);
            if (status.state() == Table.MutationState.BUILDING) return Optional.empty();
            int code = switch(status.state()) { case APPLIED -> 1; case REJECTED -> 2; case CANCELLED -> 3; case BUILDING -> throw unexpected(); };
            return Optional.of(new TableWork.Outcome(code, status.admittedInput(), status.completedInput().orElseThrow(),
                status.counts().map(Catalog.Counts::matched).orElse(BigInteger.ZERO), status.counts().map(Catalog.Counts::changed).orElse(BigInteger.ZERO), status.rejection().ordinal()));
        }
        private void drive(Turn turn) {
            TableWork.Queue queue = queue(turn);
            if (queue.head().signum() == 0) return;
            TableWork.Work work = turn.state().require(TableWork.workKey(queue.head()));
            if ((work.next().signum() == 0) != queue.head().equals(queue.tail()) ||
                (work.next().signum() != 0 && !queue.head().equals(TableWork.INITIAL) && work.next().compareTo(queue.head()) <= 0)) throw unexpected();
            Optional<TableWork.Outcome> outcome = step(turn, queue, work.command());
            boolean initialize = work.command() instanceof Initialize;
            if (outcome.isEmpty() || turn.budgets().mutations() < 3 + (initialize && !queue.ready() ? 1 : 0)) { wake(turn); return; }
            if (initialize && !queue.ready()) turn.allowQuery(peer, TABLE.object(), BigInteger.ZERO, true);
            turn.state().put(TableWork.outcomeKey(queue.head()), outcome.orElseThrow());
            turn.state().delete(TableWork.workKey(queue.head()));
            turn.state().put(TableWork.QUEUE, new TableWork.Queue(work.next(), work.next().signum() == 0 ? BigInteger.ZERO : queue.tail(), queue.ready() || initialize));
            if (work.next().signum() != 0) wake(turn);
        }
        @Override public void onMessage(Turn turn, Incoming<QueryMessage> input) {
            QueryMessage value = input.value();
            if (input instanceof Cast<QueryMessage> && (value instanceof Initialize || value instanceof Insert || value instanceof Update || value instanceof Delete)) enqueue(turn, input.position(), value);
            else if (input instanceof Cast<QueryMessage> && value instanceof Advance) {
                if (!(input.origin() instanceof ProcessOrigin origin) || !origin.process().equals(turn.process())) throw unexpected();
                drive(turn);
            } else if (input instanceof Call<QueryMessage> && value instanceof Rows) {
                TableWork.Queue queue = queue(turn);
                if (!queue.ready() || queue.head().signum() != 0) turn.reply(new NotReady(), Codecs.QUERY_REPLY);
                else turn.startQuery(TABLE.object(), new Query.Plan(new UnifiedQuery.Plan(List.of(0, 1, 2, 3), new UnifiedQuery.All(), Query.Aggregate.ROWS, Optional.of(Messages.U64_MAX), Optional.empty())));
            } else throw unexpected();
        }
    }
    public static class QueryRequester implements Handler<QueryMessage> {
        private final ProcessRef peer;
        private final Consumer<Query.IpcSegment> consume;
        public QueryRequester(ProcessRef peer, Consumer<Query.IpcSegment> consume) { this.peer = Objects.requireNonNull(peer); this.consume = Objects.requireNonNull(consume); }
        @Override public void onMessage(Turn turn, Incoming<QueryMessage> input) {
            if (input instanceof Reply<QueryMessage> reply && input.value() instanceof NotReady) {
                turn.requireReply(reply, peer, turn.state().require(REQUEST)); turn.state().put(NOT_READY, reply.correlation()); return;
            }
            if (!(input instanceof Cast<QueryMessage>) || !(input.value() instanceof Start)) throw unexpected();
            Optional<BigInteger> previous = turn.state().find(REQUEST), notReady = turn.state().find(NOT_READY);
            if (previous.isPresent() && !notReady.equals(previous)) throw unexpected();
            BigInteger correlation = turn.call(peer, new Rows(), Codecs.QUERY_SERVICE, WaitPolicy.untimed());
            turn.state().put(REQUEST, correlation);
            if (notReady.isPresent()) turn.state().delete(NOT_READY);
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
