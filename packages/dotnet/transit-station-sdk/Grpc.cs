using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;

namespace Transit.Station.Sdk;

internal interface IGrpcOwner
{
    Task<R> GrpcAccess<R>(Func<StationBridge, R> action, CancellationToken cancellation = default);
    void CheckClose();
}

/// <summary>Owned RPC values; shared Zig owns request and replay semantics.</summary>
public static class Grpc
{
    public enum Shape { Unary, ServerStreaming, ClientStreaming, Bidi }
    private static string ShapeName(Shape shape) => shape switch {
        Shape.Unary => "unary", Shape.ServerStreaming => "server_streaming", Shape.ClientStreaming => "client_streaming", Shape.Bidi => "bidi",
        _ => throw new ArgumentException("Unknown RPC shape")
    };
    public sealed record Method
    {
        public string Path { get; }
        public Shape Shape { get; }
        public Bytes DescriptorDigest { get; }
        public Method(string path, Shape shape, Bytes descriptorDigest) {
            Path = Value.Text(path,512); ShapeName(shape); Shape=shape; ArgumentNullException.ThrowIfNull(descriptorDigest);
            if(descriptorDigest.Length!=32) throw new ArgumentException("Expected descriptor SHA-256"); DescriptorDigest=descriptorDigest;
        }
    }
    public abstract record MetadataValue { private protected MetadataValue() { } }
    public sealed record Literal : MetadataValue
    {
        public Bytes Bytes { get; }
        public Literal(Bytes bytes) { ArgumentNullException.ThrowIfNull(bytes); if(bytes.Length>8192) throw new ArgumentException("Oversized metadata"); Bytes=bytes; }
    }
    public sealed record SecretRef : MetadataValue
    {
        public string Binding { get; }
        public ulong Version { get; }
        public SecretRef(string binding, ulong version) { Binding=Value.Text(binding,128); Version=Positive(version); }
    }
    private static IReadOnlyList<T> Copy<T>(IReadOnlyList<T> values, int bound) where T : class
    {
        ArgumentNullException.ThrowIfNull(values);
        if (values.Count > bound) throw new ArgumentException("RPC collection exceeds its bound");
        T[] copied = values.ToArray(); foreach (T item in copied) ArgumentNullException.ThrowIfNull(item); return Array.AsReadOnly(copied);
    }
    public sealed record Metadata
    {
        public string Name { get; }
        public MetadataValue Value { get; }
        public Metadata(string name, MetadataValue value) { Name=Client.Internal.Value.Text(name,8192); ArgumentNullException.ThrowIfNull(value); Value=value; }
    }
    public sealed record Request
    {
        public Method Method { get; }
        public IReadOnlyList<Metadata> Metadata { get; }
        public Request(Method method, IReadOnlyList<Metadata>? metadata=null) { ArgumentNullException.ThrowIfNull(method); Method=method; Metadata=Copy(metadata ?? Array.Empty<Metadata>(),64); }
    }
    public sealed record Options
    {
        public ulong EndpointRevision { get; }
        public ulong ReconcileBeforeMillis { get; }
        public uint MaxAttempts { get; }
        public Options(ulong endpointRevision, ulong reconcileBeforeMillis, uint maxAttempts = 1)
        {
            EndpointRevision = Positive(endpointRevision); ReconcileBeforeMillis = Value.Counter(reconcileBeforeMillis);
            if (maxAttempts == 0) throw new ArgumentException("Expected a positive attempt budget"); MaxAttempts = maxAttempts;
        }
    }
    private static ulong Positive(ulong value) => value == 0 ? throw new ArgumentException("Expected nonzero u64") : value;
    internal static string Hex(Bytes value) => Value.Hex(value.Copy());
    private static JsonArray Wire(IReadOnlyList<Metadata> fields)
    {
        JsonArray result = new();
        foreach (Metadata field in fields) result.Add(Value.Obj(("name",field.Name),("value",field.Value switch {
            Literal literal => Value.Obj(("literal",Hex(literal.Bytes))),
            SecretRef secret => Value.Obj(("secret",Value.Obj(("binding",secret.Binding),("version",Turn.Decimal(secret.Version))))),
            _ => throw new ArgumentException("Unknown RPC metadata")
        })));
        return result;
    }
    public sealed class Prepared
    {
        public ResourceRef Resource { get; }
        public ulong Namespace { get; }
        public Bytes Reference { get; }
        public Bytes Metadata { get; }
        public Bytes Batch { get; }
        internal Prepared(ResourceRef resource, ulong namespaceId, Bytes reference, Bytes metadata, Bytes batch)
        { Resource = resource; Namespace = namespaceId; Reference = reference; Metadata = metadata; Batch = batch; }
    }
    private static async Task<JsonObject> LocalAsync(JsonObject action, string? nativeDirectory, bool release = false)
    {
        var worker = await Worker<StationBridge, object?>.OpenAsync(() => new StationBridge(nativeDirectory), StationApi.MinimumStackBytes).ConfigureAwait(false);
        try { return await worker.Invoke(bridge => {
            if (release) bridge.GrpcCapability("grpc_release");
            return bridge.GrpcCodec(action);
        }).ConfigureAwait(false); }
        finally { await worker.CloseAsync().ConfigureAwait(false); }
    }
    public static async Task<Method> BindMethodAsync(byte[] descriptor, string path, string? nativeDirectory=null)
    {
        Value.Text(path,512); byte[] owned=Value.Bytes(descriptor,65536);
        JsonObject result=await LocalAsync(Value.Obj(("descriptor",Value.Obj(("bytes",Value.Hex(owned)),("method",path)))),nativeDirectory).ConfigureAwait(false);
        JsonObject method=Value.Object(Value.Object(result["descriptor"])["method"]);
        Shape shape=Value.String(method["shape"]) switch {
            "unary"=>Shape.Unary,"server_streaming"=>Shape.ServerStreaming,"client_streaming"=>Shape.ClientStreaming,"bidi"=>Shape.Bidi,
            _=>throw Value.Incompatible("grpc-shape")
        };
        return new(Value.String(method["path"]),shape,new Bytes(Value.Unhex(method["descriptor_digest"],32)));
    }
    public static async Task<Prepared> PrepareAsync(ResourceRef resource, ulong namespaceId, Request request, IReadOnlyList<Bytes> messages, Options options, string? nativeDirectory=null)
    {
        ArgumentNullException.ThrowIfNull(resource); Positive(namespaceId); ArgumentNullException.ThrowIfNull(request); ArgumentNullException.ThrowIfNull(options);
        JsonArray batch=new();
        foreach(Bytes message in Copy(messages,64)) { if(message.Length>16384) throw new ArgumentException("Oversized message"); batch.Add(Hex(message)); }
        Method method=request.Method;
        JsonObject result=await LocalAsync(Value.Obj(("prepare",Value.Obj(("resource",resource.Resource),("namespace",Turn.Decimal(namespaceId)),
            ("request",Value.Obj(("method",Value.Obj(("path",method.Path),("shape",ShapeName(method.Shape)),("descriptor_digest",Hex(method.DescriptorDigest)))),("metadata",Wire(request.Metadata)))),("messages",batch),
            ("endpoint_revision",Turn.Decimal(options.EndpointRevision)),("reconcile_before_ms",options.ReconcileBeforeMillis),("max_attempts",options.MaxAttempts)))),nativeDirectory).ConfigureAwait(false);
        JsonObject prepared=Value.Object(result["prepared"]);
        return new(resource,namespaceId,new Bytes(Value.Unhex(prepared["reference"],145)),new Bytes(Value.Unhex(prepared["metadata"],8192)),new Bytes(Value.Unhex(prepared["batch"],65544)));
    }
    public enum Phase { Observed, ClosedUnknown, NotDispatched }
    public enum Rejection { Denied, InvalidRequest, Busy }
    public abstract record Reply { private protected Reply() { } }
    public sealed record Rejected : Reply
    {
        public Rejection Reason { get; }
        private readonly JsonObject diagnostic;
        public JsonObject Diagnostic => diagnostic.DeepClone().AsObject();
        public Rejected(Rejection reason, JsonObject detail) { Reason = reason; diagnostic = detail.DeepClone().AsObject(); }
    }
    public sealed record Released : Reply
    {
        public ResourceRef Resource { get; }
        public ulong Exchange { get; }
        public Released(ResourceRef resource, ulong exchange)
        { ArgumentNullException.ThrowIfNull(resource); Resource = resource; Exchange = Positive(exchange); }
    }
    public sealed record Outcome : Reply
    {
        public Phase Phase { get; }
        public ResourceRef Resource { get; }
        public ulong Exchange { get; }
        public ulong Effect { get; }
        public ulong Attempt { get; }
        public uint? Status { get; }
        public Bytes? Reference { get; }
        private readonly JsonObject diagnostic;
        public JsonObject Diagnostic => diagnostic.DeepClone().AsObject();
        internal Outcome(ulong realm, JsonObject value)
        {
            diagnostic = Value.Object(value["diagnostic"]).DeepClone().AsObject();
            Phase = Value.String(value["phase"]) switch { "observed" => Phase.Observed, "closed_unknown" => Phase.ClosedUnknown, "not_dispatched" => Phase.NotDispatched, _ => throw Value.Incompatible("grpc-phase") };
            Resource = new ResourceRef(realm, Value.Number(value["resource"], 1)); Exchange = NativeValues.Wide(value["exchange"], true);
            Effect = Value.Number(value["effect"]); Attempt = Value.Number(value["attempt"]);
            Status = value["status"] is null ? null : checked((uint)Value.Number(value["status"], 0, 16));
            Reference = value["reference"] is null ? null : new Bytes(Value.Unhex(value["reference"], 256));
        }
    }
    public static async Task<Reply> DecodeReplyAsync(ulong realm, byte[] bytes, string? nativeDirectory = null)
    {
        Value.Counter(realm);
        byte[] owned = Value.Bytes(bytes, 232);
        bool release = owned.Length >= 4 && owned[0] == 'G' && owned[1] == 'R' && owned[2] == 'K' && owned[3] == '1';
        JsonObject value = await LocalAsync(Value.Obj(("outcome", Value.Hex(owned))), nativeDirectory, release).ConfigureAwait(false);
        if (value["rejected"] is { } rejection) return new Rejected(Value.String(rejection["reason"]) switch {
            "denied" => Rejection.Denied, "invalid_request" => Rejection.InvalidRequest, "busy" => Rejection.Busy, _ => throw Value.Incompatible("grpc-rejection") }, Value.Object(rejection["diagnostic"]));
        if (value["released"] is { } acknowledgement) {
            JsonObject released = Value.Object(acknowledgement);
            return new Released(new ResourceRef(realm, Value.Number(released["resource"], 1)), NativeValues.Wide(released["exchange"], true));
        }
        return new Outcome(realm, Value.Object(value["outcome"]));
    }
    public abstract record Message<T> where T : notnull { private protected Message() { } }
    public sealed record Application<T>(T Value) : Message<T> where T : notnull;
    public sealed record Received<T>(Reply Value) : Message<T> where T : notnull;
    public sealed class ReplyCodec<T> : ICodec<Message<T>> where T : notnull
    {
        private readonly ICodec<T> application;
        private readonly ulong realm;
        private readonly string? directory;
        public ReplyCodec(ICodec<T> application, ulong realm, string? nativeDirectory = null)
        { ArgumentNullException.ThrowIfNull(application); this.application = application; this.realm = Value.Counter(realm); directory = nativeDirectory; }
        public string TypeId => "transit.grpc.reply+" + application.TypeId;
        public uint Version => 1;
        public int MaxEncodedBytes => Math.Max(232, application.MaxEncodedBytes);
        public byte[] Encode(Message<T> value) => value is Application<T> message ? application.Encode(message.Value) : throw new TransitException(ErrorKind.Codec, "receive-only-grpc-outcome");
        public Message<T> Decode(byte[] bytes)
        {
            if (bytes.Length >= 4 && bytes[0] == 'G' && bytes[1] == 'R' && (bytes[2] == 'R' || bytes[2] == 'F' || bytes[2] == 'K') && bytes[3] == '1')
                return new Received<T>(DecodeReplyAsync(realm, bytes, directory).GetAwaiter().GetResult());
            return new Application<T>(application.Decode(bytes));
        }
    }
    public enum ReplayPolicy { Captured, RequireUnredacted }
    public enum PartKind { RequestMetadata, RequestBatch, EndpointPolicy, InitialMetadata, ResponseMessage, ResponseBody, HalfClose, Trailers, Timing, Omission, Completion }
    public sealed record Part(PartKind Kind, Bytes Data, bool Complete);
    public sealed class Reader : IDisposable, IAsyncDisposable
    {
        private readonly IGrpcOwner owner;
        private readonly ulong identity;
        private int failed;
        private volatile bool complete, closed;
        internal Reader(IGrpcOwner owner, ulong identity) { this.owner = owner; this.identity = identity; }
        public bool Complete => complete;
        public async Task<Part?> ReadAsync(CancellationToken cancellation = default)
        {
            try {
                return await owner.GrpcAccess(bridge => {
                    if (closed) throw new TransitException(ErrorKind.Closed, "grpc-reader");
                    if (Volatile.Read(ref failed) != 0) throw new TransitException(ErrorKind.ReadFailed, "grpc-reader", code: "GrpcReplayFailed");
                    try {
                        JsonNode? part = bridge.GrpcRead(Value.Obj(("next", identity)))["part"];
                        if (part is null) { if (!complete) throw Value.Incompatible("grpc-incomplete"); return (Part?)null; }
                        JsonObject value = Value.Object(part);
                        PartKind kind = Value.String(value["kind"]) switch {
                            "request_metadata"=>PartKind.RequestMetadata,"request_batch"=>PartKind.RequestBatch,"endpoint_policy"=>PartKind.EndpointPolicy,
                            "initial_metadata"=>PartKind.InitialMetadata,"response_message"=>PartKind.ResponseMessage,"response_body"=>PartKind.ResponseBody,
                            "half_close"=>PartKind.HalfClose,"trailers"=>PartKind.Trailers,
                            "timing" => PartKind.Timing, "omission" => PartKind.Omission, "completion" => PartKind.Completion, _ => throw Value.Incompatible("grpc-part-kind")
                        };
                        Part result = new(kind, new Bytes(Value.Unhex(value["bytes"], 256)), Value.Boolean(value["complete"]));
                        complete = result.Complete; return result;
                    } catch { Volatile.Write(ref failed, 1); throw; }
                }, cancellation).ConfigureAwait(false);
            } catch (OperationCanceledException) { Volatile.Write(ref failed, 1); throw; }
        }
        public Task CloseAsync() => owner.GrpcAccess(bridge => {
            if (!closed) { if (!Value.Boolean(bridge.GrpcRead(Value.Obj(("close", identity)))["closed"])) throw Value.Incompatible("grpc-close"); closed = true; }
            return true;
        });
        public void Dispose() { owner.CheckClose(); CloseAsync().GetAwaiter().GetResult(); }
        public async ValueTask DisposeAsync() { await CloseAsync().ConfigureAwait(false); }
    }
}
