using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;

namespace Transit.Station.Sdk;

public enum QueryColumn { Key, Value }
public enum QueryComparison { Eq, Ne, Lt, Le, Gt, Ge }
public enum QueryProjection { Both, Key, Value }
public enum QueryAggregate { Rows, Count, Sum, CountValues }
public enum QueryCloseReason { Cancelled, Denied }
public abstract record QueryPredicate
{
    private protected QueryPredicate() { }
    internal abstract JsonObject Wire(int bound);
    public sealed record All : QueryPredicate { internal override JsonObject Wire(int bound) => Value.Obj(("all", Value.Obj())); }
    public sealed record IsNull : QueryPredicate
    {
        public QueryColumn Column { get; }
        public IsNull(QueryColumn column) { if (!Enum.IsDefined(column)) throw new ArgumentException("Unknown query column"); Column = column; }
        internal override JsonObject Wire(int bound) => Value.Obj(("is_null", Column == QueryColumn.Key ? 0 : 1));
    }
    public sealed record Compare<T> : QueryPredicate
    {
        public QueryColumn Column { get; }
        public QueryComparison Comparison { get; }
        public CellType<T> Cell { get; }
        public T Expected { get; }
        public Compare(QueryColumn column, QueryComparison comparison, CellType<T> cell, T expected)
        {
            ArgumentNullException.ThrowIfNull(cell);
            if (!Enum.IsDefined(column) || !Enum.IsDefined(comparison) || (column == QueryColumn.Key && cell.WireName != "int64")) throw new ArgumentException("Invalid typed query comparison");
            Column = column; Comparison = comparison; Cell = cell; Expected = expected;
        }
        internal override JsonObject Wire(int bound) => Value.Obj(("compare", Value.Obj(("column", Column == QueryColumn.Key ? 0 : 1),
            ("op", Comparison.ToString().ToLowerInvariant()), ("value", Cell.Encode(Expected, bound)))));
    }
}
public sealed record QueryPlan
{
    public QueryProjection Projection { get; }
    public QueryAggregate Aggregate { get; }
    public ulong? Limit { get; }
    public QueryPredicate Predicate { get; }
    public QueryPlan(QueryProjection projection = QueryProjection.Both, QueryAggregate aggregate = QueryAggregate.Rows, ulong? limit = null, QueryPredicate? predicate = null)
    {
        if (!Enum.IsDefined(projection) || !Enum.IsDefined(aggregate)) throw new ArgumentException("Unknown query plan kind");
        Projection = projection; Aggregate = aggregate; Limit = limit; Predicate = predicate ?? new QueryPredicate.All();
    }
    internal JsonObject Wire(int bound) => Value.Obj(("projection", Projection.ToString().ToLowerInvariant()), ("aggregate", Aggregate == QueryAggregate.CountValues ? "count_values" : Aggregate.ToString().ToLowerInvariant()),
        ("limit", Limit is { } limit ? Turn.Decimal(limit) : null), ("predicate", Predicate.Wire(bound)));
}
public sealed record QueryJob(ulong Result, ulong Correlation, ReadVersion Source);
public sealed record ResultManifest(ulong Result, ProcessRef Source, ProcessRef Destination, ulong Correlation, uint Table,
    ulong PolicyRevision, Basis Basis, Bytes SourceContract, Bytes Plan, ulong Segments, ulong ByteCount, ulong Rows, Bytes Chain, Bytes Schema);
public sealed record IpcSegment(ResultManifest Manifest, ulong Ordinal, byte Rows, Bytes Digest, Bytes Bytes)
{
    public byte[] Ipc() => Bytes.Copy();
    public override string ToString() => $"IpcSegment[Ordinal={Ordinal}, Rows={Rows}]";
}
public sealed class ResultReader
{
    private readonly Turn turn;
    public ulong Correlation { get; }
    internal ResultReader(Turn turn, ulong correlation) { this.turn = turn; Correlation = correlation; }
    private ResultManifest ReadManifest()
    {
        JsonObject value = Value.Object(turn.Raw(Value.Obj(("query_completed", Turn.Decimal(Correlation))))["manifest"]);
        ulong realm = turn.ProcessRef.Realm;
        return new ResultManifest(Value.Number(value["result"], 1), new ProcessRef(realm, Value.Number(value["source"], 1)), new ProcessRef(realm, Value.Number(value["destination"], 1)),
            NativeValues.Wide(value["correlation"], true), checked((uint)Value.Number(value["table"], 1)), NativeValues.Wide(value["policy_revision"]), NativeValues.Basis(value["basis"], realm), NativeValues.Digest(Value.Object(value["basis"])["contract"]),
            NativeValues.Digest(value["plan"]), NativeValues.Wide(value["segments"]), NativeValues.Wide(value["bytes"]), NativeValues.Wide(value["rows"]), NativeValues.Digest(value["chain"]), NativeValues.Digest(value["schema"]));
    }
    public ResultManifest Manifest() => turn.Access(true, ReadManifest);
    public IpcSegment Segment(ulong ordinal) => turn.Access(true, () => {
        ResultManifest manifest = ReadManifest();
        JsonObject value = Value.Object(turn.Raw(Value.Obj(("query_segment", Value.Obj(("correlation", Turn.Decimal(Correlation)), ("ordinal", Turn.Decimal(ordinal))))))["segment"]);
        byte[] bytes = Value.Unhex(value["ipc"], turn.Limit("query_segment_bytes"));
        ulong actual = NativeValues.Wide(value["ordinal"]);
        if ((ulong)bytes.Length != Value.Number(value["bytes"]) || Value.Number(value["result"], 1) != manifest.Result || actual != ordinal) throw Value.Incompatible("native-segment-identity");
        return new IpcSegment(manifest, actual, checked((byte)Value.Number(value["rows"])), NativeValues.Digest(value["digest"]), new Bytes(bytes));
    });
}
