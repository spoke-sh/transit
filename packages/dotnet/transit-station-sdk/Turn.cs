using System.Globalization;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;

namespace Transit.Station.Sdk;

public sealed class Turn
{
    internal readonly StationBridge Bridge;
    internal readonly JsonObject Event;
    internal readonly ProcessRef ProcessRef;
    internal readonly ResourceRef ResourceRef;
    internal readonly ulong Scope;
    private readonly StopToken stop;
    private readonly Thread owner = Thread.CurrentThread;
    private bool active = true, busy;
    internal TransitException? Poison;
    internal Turn(StationBridge bridge, JsonObject value, ProcessRef process, StopToken stop)
    {
        Bridge = bridge; Event = value; ProcessRef = process; this.stop = stop;
        Scope = Value.Number(value["scope"], 1);
        ResourceRef = new ResourceRef(process.Realm, Value.Number(value["resource"], 1));
    }
    internal void EndScope() => Volatile.Write(ref active, false);
    internal void Check()
    {
        if (!Volatile.Read(ref active)) throw new TransitException(ErrorKind.TurnExpired, "turn-scope");
        if (Thread.CurrentThread != owner || busy) throw new TransitException(ErrorKind.Busy, "turn-owner");
        if (stop.Stopped) throw new TransitException(ErrorKind.Closed, "turn-stop");
        if (Poison is not null) throw Poison;
    }
    internal R Access<R>(bool read, Func<R> operation)
    {
        Check(); busy = true;
        try { return operation(); }
        catch (Exception failure) {
            var error = NativeValues.Normalize(failure, read ? "read" : "turn-operation");
            if (read) Poison ??= error;
            throw error;
        } finally { busy = false; }
    }
    internal JsonObject Raw(JsonObject action) => Bridge.Apply(Scope, action);
    internal int Limit(string name) => Bridge.Limit(name);
    internal ulong Peer(ProcessRef peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        if (peer.Realm != ProcessRef.Realm) throw new ArgumentException("Peer must be in this realm");
        return peer.Pid;
    }
    internal static string Decimal(ulong value) => value.ToString(CultureInfo.InvariantCulture);
    internal static string Decimal(long value) => value.ToString(CultureInfo.InvariantCulture);
    internal static ulong Positive(ulong value) => value == 0 ? throw new ArgumentException("Correlation must be nonzero") : value;
    public ProcessRef Process { get { Check(); return ProcessRef; } }
    public ResourceRef Resource { get { Check(); return ResourceRef; } }
    public ulong ResourceRevision { get { Check(); return Value.Number(Event["resource_revision"]); } }
    public Document.Owner Document(ulong identity) { Check(); return new Sdk.Document.Owner(this, identity); }
    public State State { get { Check(); return new State(this, null); } }
    public Budgets Budgets() => Access(false, () => {
        JsonObject value = Value.Object(Raw(Value.Obj(("budgets", Value.Obj())))["budgets"]);
        return new Budgets(checked((uint)Value.Number(value["mutations"])), checked((uint)Value.Number(value["outputs"])), checked((uint)Value.Number(value["views"])),
            checked((uint)Value.Number(value["retained_reads"])), checked((uint)Value.Number(value["retains"])), checked((uint)Value.Number(value["releases"])));
    });
    public void Cast<T>(ProcessRef peer, T value, ICodec<T> codec) where T : notnull => Access(false, () => {
        ulong pid = Peer(peer); byte[] bytes = NativeValues.Encode(codec, value, Limit("message_bytes"));
        Raw(Value.Obj(("cast", Value.Obj(("pid", pid), ("value", Value.Hex(bytes)))))); return true;
    });
    public ulong Call<T>(ProcessRef peer, T value, ICodec<T> codec, WaitPolicy wait) where T : notnull => Access(false, () => {
        ulong pid = Peer(peer); ArgumentNullException.ThrowIfNull(wait);
        ulong? observer = wait.Observer is null ? null : Peer(wait.Observer);
        byte[] bytes = NativeValues.Encode(codec, value, Limit("message_bytes"));
        return NativeValues.Wide(Raw(Value.Obj(("call", Value.Obj(("pid", pid), ("value", Value.Hex(bytes)), ("deadline_ms", wait.DeadlineMillis), ("observer", observer)))))["correlation"], true);
    });
    public void Reply<T>(T value, ICodec<T> codec) where T : notnull => Access(false, () => {
        byte[] bytes = NativeValues.Encode(codec, value, Limit("message_bytes")); Raw(Value.Obj(("reply", Value.Hex(bytes)))); return true;
    });
    public void RequireReply<T>(Reply<T> reply, ProcessRef peer, ulong correlation) where T : notnull => Access(false, () => {
        ulong pid = Peer(peer); Positive(correlation); ArgumentNullException.ThrowIfNull(reply);
        JsonObject input = Value.Object(Event["input"]); Origin origin = NativeValues.Origin(input["origin"], ProcessRef.Realm);
        if (Value.String(input["kind"]) != "reply" || origin is not ProcessOrigin source || source.Process.Pid != pid ||
            NativeValues.Wide(input["correlation"], true) != correlation || reply.Correlation != correlation || reply.Position != Value.Number(input["position"], 1))
            throw new TransitException(ErrorKind.Handler, "reply-identity");
        return true;
    });
    public bool CancelCall(ulong correlation) => Access(false, () => Value.Boolean(Raw(Value.Obj(("cancel", Decimal(Positive(correlation)))))["cancelled"]));
    private void HttpRequest(Http.Prepared request)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (request.Resource != ResourceRef) throw new ArgumentException("HTTP request must use this writable resource");
        Bridge.HttpCapability("http_requests");
    }
    public bool StageHttp(Http.Prepared request) => Access(false, () => {
        HttpRequest(request);
        return Value.Boolean(Raw(Value.Obj(("http_stage", Value.Obj(("reference", Http.Hex(request.Reference)), ("metadata", Http.Hex(request.Metadata)), ("body", Http.Hex(request.Body))))))["staged"]);
    });
    public ulong CallHttp(ProcessRef connector, Http.Prepared request) => Access(false, () => {
        HttpRequest(request);
        return NativeValues.Wide(Raw(Value.Obj(("http_call", Value.Obj(("pid", Peer(connector)), ("reference", Http.Hex(request.Reference))))))["correlation"], true);
    });
    /// <summary>Request durable hold disposal; authenticate the correlated Http.Released reply.</summary>
    public ulong ReleaseHttp(ProcessRef connector, ResourceRef capture, ulong exchange) => Access(false, () => {
        ArgumentNullException.ThrowIfNull(capture); Positive(exchange);
        if (capture.Realm != ResourceRef.Realm) throw new ArgumentException("HTTP capture must belong to this realm");
        Bridge.HttpCapability("http_release");
        return NativeValues.Wide(Raw(Value.Obj(("http_release", Value.Obj(("pid", Peer(connector)), ("resource", capture.Resource), ("exchange", Decimal(exchange))))))["correlation"], true);
    });
    /// <summary>Submit an explicit linked attempt; the service decides current admission.</summary>
    public ulong FollowupHttp(ProcessRef connector, Http.Outcome parent, Http.FollowupReason reason, Http.Prepared request) => Access(false, () => {
        ArgumentNullException.ThrowIfNull(parent); HttpRequest(request);
        if (parent.Resource.Realm != ResourceRef.Realm) throw new ArgumentException("HTTP parent must belong to this realm");
        if (reason is not (Http.FollowupReason.Retry or Http.FollowupReason.Redirect or Http.FollowupReason.Reconcile or Http.FollowupReason.Cancel)) throw new ArgumentException("Select an HTTP followup reason");
        Bridge.HttpCapability("http_followup");
        return NativeValues.Wide(Raw(Value.Obj(("http_followup", Value.Obj(("pid", Peer(connector)), ("resource", parent.Resource.Resource),
            ("parent", Decimal(parent.Exchange)), ("reason", reason.ToString().ToLowerInvariant()), ("reference", Http.Hex(request.Reference))))))["correlation"], true);
    });
    private void GrpcRequest(Grpc.Prepared request)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (request.Resource != ResourceRef) throw new ArgumentException("RPC request must use this writable resource");
        Bridge.GrpcCapability("grpc_requests");
    }
    public bool StageGrpc(Grpc.Prepared request) => Access(false, () => {
        GrpcRequest(request);
        return Value.Boolean(Raw(Value.Obj(("grpc_stage", Value.Obj(("reference", Grpc.Hex(request.Reference)), ("metadata", Grpc.Hex(request.Metadata)), ("batch", Grpc.Hex(request.Batch))))))["staged"]);
    });
    public ulong CallGrpc(ProcessRef connector, Grpc.Prepared request) => Access(false, () => {
        GrpcRequest(request);
        return NativeValues.Wide(Raw(Value.Obj(("grpc_call", Value.Obj(("pid", Peer(connector)), ("reference", Grpc.Hex(request.Reference))))))["correlation"], true);
    });
    /// <summary>Request durable hold disposal; authenticate the correlated Grpc.Released reply.</summary>
    public ulong ReleaseGrpc(ProcessRef connector, ResourceRef capture, ulong exchange) => Access(false, () => {
        ArgumentNullException.ThrowIfNull(capture); Positive(exchange);
        if (capture.Realm != ResourceRef.Realm) throw new ArgumentException("RPC capture must belong to this realm");
        Bridge.GrpcCapability("grpc_release");
        return NativeValues.Wide(Raw(Value.Obj(("grpc_release", Value.Obj(("pid", Peer(connector)), ("resource", capture.Resource), ("exchange", Decimal(exchange))))))["correlation"], true);
    });
    /// <summary>Submit an explicit linked attempt; the service decides current admission.</summary>
    public ulong RetryGrpc(ProcessRef connector, Grpc.Outcome parent, Grpc.Prepared request) => Access(false, () => {
        ArgumentNullException.ThrowIfNull(parent); GrpcRequest(request);
        if (parent.Resource.Realm != ResourceRef.Realm) throw new ArgumentException("RPC parent must belong to this realm");
        Bridge.GrpcCapability("grpc_followup");
        return NativeValues.Wide(Raw(Value.Obj(("grpc_followup", Value.Obj(("pid", Peer(connector)), ("resource", parent.Resource.Resource),
            ("parent", Decimal(parent.Exchange)), ("reference", Grpc.Hex(request.Reference))))))["correlation"], true);
    });
    public Table<T> Table<T>(TableSchema<T> schema) => Access(true, () => Sdk.Table<T>.Open(this, schema, null));
    public Table<T> CreateTable<T>(TableSchema<T> schema)
    {
        Access(false, () => {
            ArgumentNullException.ThrowIfNull(schema); Value.Text(schema.KeyName, Limit("table_name_bytes")); Value.Text(schema.ValueName, Limit("table_name_bytes"));
            Raw(Value.Obj(("table_create", Value.Obj(("id", schema.Id), ("key_name", schema.KeyName), ("value_name", schema.ValueName), ("value_type", schema.Cell.WireName))))); return true;
        });
        return Table(schema);
    }
    public ReadVersion Retain() => Access(false, () => NativeValues.ReadVersion(Raw(Value.Obj(("retain", Value.Obj())))["version"]));
    public Source OpenVersion(ReadVersion identity) { Check(); ArgumentNullException.ThrowIfNull(identity); return new Source(this, identity); }
    public void Release(ReadVersion identity) => Access(false, () => { Raw(Value.Obj(("release", NativeValues.Wire(identity)))); return true; });
    public void AllowQuery<T>(ProcessRef peer, TableSchema<T> table, ulong expectedRevision, bool allow) => Access(false, () => {
        Raw(Value.Obj(("query_policy", Value.Obj(("peer", Peer(peer)), ("table", table.Id), ("expected_revision", Value.Counter(expectedRevision, 0)), ("allow", allow))))); return true;
    });
    public QueryJob StartQuery<T>(TableSchema<T> table, QueryPlan plan)
    {
        Table(table);
        return Access(false, () => {
            JsonObject value = Value.Object(Raw(Value.Obj(("query_start", Value.Obj(("id", table.Id), ("plan", plan.Wire(Limit("table_cell_bytes")))))))["query"]);
            return new QueryJob(Value.Number(value["result"], 1), NativeValues.Wide(value["correlation"], true), NativeValues.ReadVersion(value["source"]));
        });
    }
    public void CloseQuery(ulong result, QueryCloseReason reason) => Access(false, () => {
        if (reason is not (QueryCloseReason.Cancelled or QueryCloseReason.Denied)) throw new ArgumentException("Select a query closure reason");
        Raw(Value.Obj(("query_close", Value.Obj(("result", Value.Counter(result)), ("reason", reason.ToString().ToLowerInvariant()))))); return true;
    });
    public ResultReader Result(ulong correlation) { Check(); return new ResultReader(this, Positive(correlation)); }
}
