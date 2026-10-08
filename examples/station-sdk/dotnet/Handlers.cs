using Transit.Client;
using Transit.Station.Sdk;
using C = Transit.Station.Sdk.Catalog;
using L = Transit.Station.Sdk.Logical;

namespace Transit.Sdk.Examples;

public static class StateKeys
{
    public static Key<ulong> Total { get; } = new("total", Codecs.U64);
    public static Key<ulong> Request { get; } = new("request", Codecs.U64);
    public static Key<ulong> Observed { get; } = new("observed", Codecs.U64);
    public static L.Cell Signed(long value) => new L.Present(new L.Signed(value));
    public static C.Schema Table { get; } = new(1, 1, 5, [
        new(1, "id", new L.Scalar(L.ScalarKind.Int64), false),
        new(2, "value", new L.Scalar(L.ScalarKind.Int64)),
        new(3, "label", new L.Scalar(L.ScalarKind.Utf8), false, new L.Present(new L.Utf8("example"))),
        new(4, "tags", new L.ListType(new(new L.Scalar(L.ScalarKind.Int64))), false,
            new L.Present(new L.Sequence(L.SequenceKind.List, [Signed(1), Signed(2)])))
    ], [1]);
    public static C.TableLimits TableLimits { get; } = new(65536, 8388608, 1024);
    public static Key<ulong> NotReady { get; } = new("not-ready", Codecs.U64);
    internal static TransitException Unexpected() => new(ErrorKind.Handler, "unexpected-application-input");
}
public class Counter : IHandler<ICounterMessage>
{
    public virtual void Initialize(Turn turn) => turn.State.Put(StateKeys.Total, 0UL);
    public virtual void OnMessage(Turn turn, Incoming<ICounterMessage> input)
    {
        switch (input) {
            case Cast<ICounterMessage> { Value: Add add }: turn.State.Put(StateKeys.Total, checked(turn.State.Require(StateKeys.Total) + add.Value)); break;
            case Call<ICounterMessage> { Value: Read }: turn.Reply<ICounterMessage>(new Total(turn.State.Require(StateKeys.Total)), Codecs.Reply); break;
            default: throw StateKeys.Unexpected();
        }
    }
}
public class Requester(ProcessRef peer) : IHandler<ICounterMessage>
{
    public virtual void OnMessage(Turn turn, Incoming<ICounterMessage> input)
    {
        switch (input) {
            case Cast<ICounterMessage> { Value: Start }:
                if (turn.State.Find(StateKeys.Request) is not null) throw StateKeys.Unexpected();
                ulong correlation = turn.Call<ICounterMessage>(peer, new Read(), Codecs.Counter, WaitPolicy.Untimed);
                turn.State.Put(StateKeys.Request, correlation); break;
            case Reply<ICounterMessage> { Value: Total total } reply:
                turn.RequireReply(reply, peer, turn.State.Require(StateKeys.Request));
                turn.State.Put(StateKeys.Observed, total.Value); break;
            default: throw StateKeys.Unexpected();
        }
    }
}
public class TableService(ProcessRef peer) : IHandler<IQueryMessage>
{
    private static TableWork.Queue Queue(Turn turn) => turn.State.Find(TableWork.Metadata)?.Value ?? new();
    private static void Wake(Turn turn) => turn.Cast<IQueryMessage>(turn.Process, new Advance(), Codecs.QueryService);
    private static void Enqueue(Turn turn, ulong identity, IQueryMessage command) {
        if (identity == 0 || identity > TableWork.MaxInput) throw StateKeys.Unexpected();
        TableWork.Queue queue = Queue(turn);
        Key<TableWork.Work> key = TableWork.WorkKey(identity);
        if (turn.State.Find(key) is not null || turn.State.Find(TableWork.OutcomeKey(identity)) is not null) throw StateKeys.Unexpected();
        ulong head = identity;
        if (queue.Tail != 0) {
            if (identity <= queue.Tail) throw StateKeys.Unexpected();
            TableWork.Work tail = turn.State.Require(TableWork.WorkKey(queue.Tail));
            if (tail.Next != 0) throw StateKeys.Unexpected();
            turn.State.Put(TableWork.WorkKey(queue.Tail), new TableWork.Work(identity, tail.Command)); head = queue.Head;
        } else if (!queue.Ready && command is not Examples.Initialize) {
            turn.State.Put(TableWork.WorkKey(TableWork.Initial), new TableWork.Work(identity, new Examples.Initialize())); head = TableWork.Initial;
        }
        turn.State.Put(key, new TableWork.Work(0, command));
        turn.State.Put(TableWork.Metadata, new TableWork.Queue(head, identity, queue.Ready));
        if (queue.Head == 0) Wake(turn);
    }
    private static TableWork.Outcome? Step(Turn turn, TableWork.Queue queue, IQueryMessage command) {
        if (command is Examples.Initialize) {
            TableCreation status = turn.CreateTable(StateKeys.Table, StateKeys.TableLimits);
            if (status.State == TableCreationState.Building) return null;
            return new(0, status.AdmittedInput, status.CompletedInput ?? throw StateKeys.Unexpected());
        }
        if (!queue.Ready || queue.Head == TableWork.Initial) throw StateKeys.Unexpected();
        long key = command switch { Insert c => c.Key, Update c => c.Key, Delete c => c.Key, _ => throw StateKeys.Unexpected() };
        C.Predicate[] predicate = [new C.Comparison(1, C.CompareOperator.Eq, new L.Signed(key))];
        C.Mutation mutation;
        if (command is Delete) mutation = new C.Delete(predicate);
        else {
            long? cell = command is Insert c ? c.Value : ((Update)command).Value;
            L.Cell value = cell is {} number ? StateKeys.Signed(number) : new L.Null();
            mutation = command is Insert ? new C.Insert([[new(1, StateKeys.Signed(key)), new(2, value)]]) : new C.Update([new(2, value)], predicate);
        }
        TableMutationStatus result = TableMutation.Prepare(turn.Resource, 0, queue.Head, StateKeys.Table, mutation).Step(turn);
        if (result.State == TableMutationState.Building) return null;
        byte state = result.State switch { TableMutationState.Applied => 1, TableMutationState.Rejected => 2, TableMutationState.Cancelled => 3, _ => throw StateKeys.Unexpected() };
        return new(state, result.AdmittedInput, result.CompletedInput ?? throw StateKeys.Unexpected(), result.Counts?.Matched ?? 0, result.Counts?.Changed ?? 0, (byte)result.Rejection);
    }
    private void Drive(Turn turn) {
        TableWork.Queue queue = Queue(turn);
        if (queue.Head == 0) return;
        TableWork.Work work = turn.State.Require(TableWork.WorkKey(queue.Head));
        if ((work.Next == 0) != (queue.Head == queue.Tail) || (work.Next != 0 && queue.Head != TableWork.Initial && work.Next <= queue.Head)) throw StateKeys.Unexpected();
        TableWork.Outcome? outcome = Step(turn, queue, work.Command);
        bool initialize = work.Command is Examples.Initialize;
        if (outcome is null || turn.Budgets().Mutations < 3 + (initialize && !queue.Ready ? 1 : 0)) { Wake(turn); return; }
        if (initialize && !queue.Ready) turn.AllowQuery(peer, StateKeys.Table.ObjectId, 0, true);
        turn.State.Put(TableWork.OutcomeKey(queue.Head), outcome);
        turn.State.Delete(TableWork.WorkKey(queue.Head));
        turn.State.Put(TableWork.Metadata, new TableWork.Queue(work.Next, work.Next == 0 ? 0 : queue.Tail, queue.Ready || initialize));
        if (work.Next != 0) Wake(turn);
    }
    public virtual void OnMessage(Turn turn, Incoming<IQueryMessage> input) {
        if (input is Cast<IQueryMessage> && input.Value is Examples.Initialize or Insert or Update or Delete) Enqueue(turn, input.Position, input.Value);
        else if (input is Cast<IQueryMessage> { Value: Advance }) {
            if (input.Origin is not ProcessOrigin origin || origin.Process != turn.Process) throw StateKeys.Unexpected();
            Drive(turn);
        } else if (input is Call<IQueryMessage> { Value: Rows }) {
            TableWork.Queue queue = Queue(turn);
            if (!queue.Ready || queue.Head != 0) turn.Reply<IQueryMessage>(new NotReady(), Codecs.QueryReply);
            else turn.StartQuery(StateKeys.Table.ObjectId, new QueryPlan(new UnifiedQuery.Plan([0, 1, 2, 3], limit: ulong.MaxValue)));
        } else throw StateKeys.Unexpected();
    }
}
public class QueryRequester(ProcessRef peer, Action<IpcSegment> consume) : IHandler<IQueryMessage>
{
    public virtual void OnMessage(Turn turn, Incoming<IQueryMessage> input)
    {
        if (input is Reply<IQueryMessage> { Value: NotReady } reply) {
            turn.RequireReply(reply, peer, turn.State.Require(StateKeys.Request)); turn.State.Put(StateKeys.NotReady, reply.Correlation); return;
        }
        if (input is not Cast<IQueryMessage> { Value: Start }) throw StateKeys.Unexpected();
        var previous = turn.State.Find(StateKeys.Request); var notReady = turn.State.Find(StateKeys.NotReady);
        if (previous is not null && previous.Value != notReady?.Value) throw StateKeys.Unexpected();
        ulong correlation = turn.Call<IQueryMessage>(peer, new Rows(), Codecs.QueryService, WaitPolicy.Untimed);
        turn.State.Put(StateKeys.Request, correlation);
        if (notReady is not null) turn.State.Delete(StateKeys.NotReady);
    }
    public virtual void OnResult(Turn turn, ResultComplete complete)
    {
        ResultReader reader = turn.Result(complete.Correlation);
        ResultManifest manifest = reader.Manifest();
        if (manifest.Source != peer || manifest.Correlation != turn.State.Require(StateKeys.Request)) throw StateKeys.Unexpected();
        // Stream bounded owned segments; callback effects need application idempotency.
        for (ulong ordinal = 0; ordinal < manifest.Segments; ordinal++) consume(reader.Segment(ordinal));
        turn.State.Put(StateKeys.Observed, manifest.Rows);
    }
}
