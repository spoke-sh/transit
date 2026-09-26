using Transit.Client;
using Transit.Station.Sdk;

namespace Transit.Sdk.Examples;

public static class StateKeys
{
    public static Key<ulong> Total { get; } = new("total", Codecs.U64);
    public static Key<ulong> Request { get; } = new("request", Codecs.U64);
    public static Key<ulong> Observed { get; } = new("observed", Codecs.U64);
    public static TableSchema<long?> Table { get; } = new(1, Cells.Int64);
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
    public virtual void Initialize(Turn turn) { turn.CreateTable(StateKeys.Table); turn.AllowQuery(peer, StateKeys.Table, 0, true); }
    public virtual void OnMessage(Turn turn, Incoming<IQueryMessage> input)
    {
        switch (input) {
            case Cast<IQueryMessage> { Value: Examples.Initialize }: break;
            case Cast<IQueryMessage> { Value: Insert row }: turn.Table(StateKeys.Table).Insert(new TableRow<long?>(row.Key, row.Value)); break;
            case Call<IQueryMessage> { Value: Rows }: turn.StartQuery(StateKeys.Table, new QueryPlan(limit: ulong.MaxValue)); break;
            default: throw StateKeys.Unexpected();
        }
    }
}
public class QueryRequester(ProcessRef peer, Action<IpcSegment> consume) : IHandler<IQueryMessage>
{
    public virtual void OnMessage(Turn turn, Incoming<IQueryMessage> input)
    {
        if (input is not Cast<IQueryMessage> { Value: Start } || turn.State.Find(StateKeys.Request) is not null) throw StateKeys.Unexpected();
        ulong correlation = turn.Call<IQueryMessage>(peer, new Rows(), Codecs.QueryService, WaitPolicy.Untimed);
        turn.State.Put(StateKeys.Request, correlation);
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
