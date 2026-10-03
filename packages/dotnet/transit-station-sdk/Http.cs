using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;

namespace Transit.Station.Sdk;

internal interface IHttpOwner
{
    Task<R> HttpAccess<R>(Func<StationBridge, R> action, CancellationToken cancellation = default);
    void CheckClose();
}

/// <summary>Owned HTTP values; shared Zig owns request and replay semantics.</summary>
public static class Http
{
    public enum Method { Get, Head, Post, Put, Patch, Delete, Options }
    public abstract record Piece { private protected Piece() { } }
    public sealed record Literal : Piece
    {
        public string Value { get; }
        public Literal(string value) { Value = Client.Internal.Value.Text(value, 8192); }
    }
    public sealed record Variable : Piece
    {
        public string Name { get; }
        public string Value { get; }
        public Variable(string name, string value) { Name = Client.Internal.Value.Text(name, 128); Value = Client.Internal.Value.Text(value, 8192); }
    }
    public sealed record SecretRef : Piece
    {
        public string Binding { get; }
        public ulong Version { get; }
        public SecretRef(string binding, ulong version) { Binding = Value.Text(binding, 128); Version = Positive(version); }
    }
    private static IReadOnlyList<T> Copy<T>(IReadOnlyList<T> values, int bound) where T : class
    {
        ArgumentNullException.ThrowIfNull(values);
        if (values.Count > bound) throw new ArgumentException("HTTP collection exceeds its bound");
        T[] copied = values.ToArray(); foreach (T item in copied) ArgumentNullException.ThrowIfNull(item); return Array.AsReadOnly(copied);
    }
    public sealed record Header
    {
        public string Name { get; }
        public IReadOnlyList<Piece> Pieces { get; }
        public Header(string name, IReadOnlyList<Piece> pieces) { Name = Value.Text(name, 8192); Pieces = Copy(pieces, 128); }
    }
    public sealed record Request
    {
        public Method Method { get; }
        public IReadOnlyList<Piece> Target { get; }
        public IReadOnlyList<Header> Headers { get; }
        public Request(Method method, IReadOnlyList<Piece> target, IReadOnlyList<Header>? headers = null)
        {
            if (!Enum.IsDefined(method)) throw new ArgumentException("Unsupported HTTP method");
            Method = method; Target = Copy(target, 128); Headers = Copy(headers ?? Array.Empty<Header>(), 64);
        }
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
    private static JsonArray Wire(IReadOnlyList<Piece> pieces)
    {
        JsonArray result = new();
        foreach (Piece piece in pieces) result.Add(piece switch {
            Literal literal => Value.Obj(("literal", literal.Value)),
            Variable variable => Value.Obj(("variable", Value.Obj(("name", variable.Name), ("value", variable.Value)))),
            SecretRef secret => Value.Obj(("secret", Value.Obj(("binding", secret.Binding), ("version", Turn.Decimal(secret.Version))))),
            _ => throw new ArgumentException("Unknown HTTP piece")
        });
        return result;
    }
    public sealed class Prepared
    {
        public ResourceRef Resource { get; }
        public ulong Namespace { get; }
        public Bytes Reference { get; }
        public Bytes Metadata { get; }
        public Bytes Body { get; }
        internal Prepared(ResourceRef resource, ulong namespaceId, Bytes reference, Bytes metadata, Bytes body)
        { Resource = resource; Namespace = namespaceId; Reference = reference; Metadata = metadata; Body = body; }
    }
    private static async Task<JsonObject> LocalAsync(JsonObject action, string? nativeDirectory, bool release = false)
    {
        var worker = await Worker<StationBridge, object?>.OpenAsync(() => new StationBridge(nativeDirectory), StationApi.MinimumStackBytes).ConfigureAwait(false);
        try { return await worker.Invoke(bridge => {
            if (release) bridge.HttpCapability("http_release");
            return bridge.HttpCodec(action);
        }).ConfigureAwait(false); }
        finally { await worker.CloseAsync().ConfigureAwait(false); }
    }
    public static async Task<Prepared> PrepareAsync(ResourceRef resource, ulong namespaceId, Request request, byte[] body, Options options, string? nativeDirectory = null)
    {
        ArgumentNullException.ThrowIfNull(resource); Positive(namespaceId); ArgumentNullException.ThrowIfNull(request); ArgumentNullException.ThrowIfNull(options);
        Bytes owned = new(Value.Bytes(body, 65536)); JsonArray headers = new();
        foreach (Header header in request.Headers) headers.Add(Value.Obj(("name", header.Name), ("value", Wire(header.Pieces))));
        JsonObject result = await LocalAsync(Value.Obj(("prepare", Value.Obj(("resource", resource.Resource), ("namespace", Turn.Decimal(namespaceId)),
            ("request", Value.Obj(("method", request.Method.ToString().ToUpperInvariant()), ("target", Wire(request.Target)), ("headers", headers))), ("body", Hex(owned)),
            ("endpoint_revision", Turn.Decimal(options.EndpointRevision)), ("reconcile_before_ms", options.ReconcileBeforeMillis), ("max_attempts", options.MaxAttempts)))), nativeDirectory).ConfigureAwait(false);
        JsonObject prepared = Value.Object(result["prepared"]);
        return new(resource, namespaceId, new Bytes(Value.Unhex(prepared["reference"], 112)), new Bytes(Value.Unhex(prepared["metadata"], 8192)), owned);
    }
    public enum Phase { Observed, ClosedUnknown, NotDispatched }
    public enum FollowupReason { Retry, Redirect, Reconcile, Cancel }
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
        public ushort? Status { get; }
        public Bytes? Reference { get; }
        private readonly JsonObject diagnostic;
        public JsonObject Diagnostic => diagnostic.DeepClone().AsObject();
        internal Outcome(ulong realm, JsonObject value)
        {
            diagnostic = Value.Object(value["diagnostic"]).DeepClone().AsObject();
            Phase = Value.String(value["phase"]) switch { "observed" => Phase.Observed, "closed_unknown" => Phase.ClosedUnknown, "not_dispatched" => Phase.NotDispatched, _ => throw Value.Incompatible("http-phase") };
            Resource = new ResourceRef(realm, Value.Number(value["resource"], 1)); Exchange = NativeValues.Wide(value["exchange"], true);
            Effect = Value.Number(value["effect"]); Attempt = Value.Number(value["attempt"]);
            Status = value["status"] is null ? null : checked((ushort)Value.Number(value["status"], 200, 599));
            Reference = value["reference"] is null ? null : new Bytes(Value.Unhex(value["reference"], 256));
        }
    }
    public static async Task<Reply> DecodeReplyAsync(ulong realm, byte[] bytes, string? nativeDirectory = null)
    {
        Value.Counter(realm);
        byte[] owned = Value.Bytes(bytes, 232);
        bool release = owned.Length >= 4 && owned[0] == 'H' && owned[1] == 'T' && owned[2] == 'K' && owned[3] == '1';
        JsonObject value = await LocalAsync(Value.Obj(("outcome", Value.Hex(owned))), nativeDirectory, release).ConfigureAwait(false);
        if (value["rejected"] is { } rejection) return new Rejected(Value.String(rejection["reason"]) switch {
            "denied" => Rejection.Denied, "invalid_request" => Rejection.InvalidRequest, "busy" => Rejection.Busy, _ => throw Value.Incompatible("http-rejection") }, Value.Object(rejection["diagnostic"]));
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
        public string TypeId => "transit.http.reply+" + application.TypeId;
        public uint Version => 1;
        public int MaxEncodedBytes => Math.Max(232, application.MaxEncodedBytes);
        public byte[] Encode(Message<T> value) => value is Application<T> message ? application.Encode(message.Value) : throw new TransitException(ErrorKind.Codec, "receive-only-http-outcome");
        public Message<T> Decode(byte[] bytes)
        {
            if (bytes.Length >= 4 && bytes[0] == 'H' && bytes[1] == 'T' && (bytes[2] == 'R' || bytes[2] == 'F' || bytes[2] == 'K') && bytes[3] == '1')
                return new Received<T>(DecodeReplyAsync(realm, bytes, directory).GetAwaiter().GetResult());
            return new Application<T>(application.Decode(bytes));
        }
    }
    public enum ReplayPolicy { Captured, RequireUnredacted }
    public enum PartKind { RequestTemplate, RequestHead, RequestBody, ResponseHead, ResponseBody, ResponseTrailers, Timing, Omission, Completion }
    public sealed record Part(PartKind Kind, Bytes Data, bool Complete);
    public sealed class Reader : IDisposable, IAsyncDisposable
    {
        private readonly IHttpOwner owner;
        private readonly ulong identity;
        private int failed;
        private volatile bool complete, closed;
        internal Reader(IHttpOwner owner, ulong identity) { this.owner = owner; this.identity = identity; }
        public bool Complete => complete;
        public async Task<Part?> ReadAsync(CancellationToken cancellation = default)
        {
            try {
                return await owner.HttpAccess(bridge => {
                    if (closed) throw new TransitException(ErrorKind.Closed, "http-reader");
                    if (Volatile.Read(ref failed) != 0) throw new TransitException(ErrorKind.ReadFailed, "http-reader", code: "HttpReplayFailed");
                    try {
                        JsonNode? part = bridge.HttpRead(Value.Obj(("next", identity)))["part"];
                        if (part is null) { if (!complete) throw Value.Incompatible("http-incomplete"); return (Part?)null; }
                        JsonObject value = Value.Object(part);
                        PartKind kind = Value.String(value["kind"]) switch {
                            "request_template" => PartKind.RequestTemplate, "request_head" => PartKind.RequestHead, "request_body" => PartKind.RequestBody,
                            "response_head" => PartKind.ResponseHead, "response_body" => PartKind.ResponseBody, "response_trailers" => PartKind.ResponseTrailers,
                            "timing" => PartKind.Timing, "omission" => PartKind.Omission, "completion" => PartKind.Completion, _ => throw Value.Incompatible("http-part-kind")
                        };
                        Part result = new(kind, new Bytes(Value.Unhex(value["bytes"], 256)), Value.Boolean(value["complete"]));
                        complete = result.Complete; return result;
                    } catch { Volatile.Write(ref failed, 1); throw; }
                }, cancellation).ConfigureAwait(false);
            } catch (OperationCanceledException) { Volatile.Write(ref failed, 1); throw; }
        }
        public Task CloseAsync() => owner.HttpAccess(bridge => {
            if (!closed) { if (!Value.Boolean(bridge.HttpRead(Value.Obj(("close", identity)))["closed"])) throw Value.Incompatible("http-close"); closed = true; }
            return true;
        });
        public void Dispose() { owner.CheckClose(); CloseAsync().GetAwaiter().GetResult(); }
        public async ValueTask DisposeAsync() { await CloseAsync().ConfigureAwait(false); }
    }
}
