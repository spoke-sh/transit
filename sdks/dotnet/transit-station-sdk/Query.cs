using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;

namespace Transit.Station.Sdk;

public enum QueryComparison { Eq, Ne, Lt, Le, Gt, Ge }
public enum QueryAggregate { Rows, Count, Sum, CountValues }
public enum QueryCloseReason { Cancelled, Denied }
public sealed class QueryPlan
{
    private readonly JsonObject value;
    public QueryPlan(UnifiedQuery.Plan plan) { ArgumentNullException.ThrowIfNull(plan); value = plan.Wire().DeepClone().AsObject(); }
    internal JsonObject Wire() => value.DeepClone().AsObject();
}
public sealed record QueryJob(ulong Result, ulong Correlation, ReadVersion Source);
public sealed record ResultManifest(ulong Result, ProcessRef Source, ProcessRef Destination, ulong Correlation, ulong Table,
    ulong PolicyRevision, TableBasis Basis, Bytes Plan, ulong Segments, ulong ByteCount, ulong Rows, Bytes Chain, Bytes Schema);
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
            NativeValues.Wide(value["correlation"], true), NativeValues.Wide(value["table"], true), NativeValues.Wide(value["policy_revision"]),
            new TableBasis(new ResourceRef(realm, Value.Number(Value.Object(value["basis"])["resource"], 1)), Value.Number(Value.Object(value["basis"])["revision"], 1), NativeValues.Wide(value["table"], true), NativeValues.Digest(Value.Object(value["basis"])["head"])),
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
