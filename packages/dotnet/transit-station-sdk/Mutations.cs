using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;
using V = Transit.Client.Internal.Value;
using StationApi = Transit.Station.Sdk.Internal.NativeApi;
using StationBridge = Transit.Station.Sdk.Internal.Bridge;

namespace Transit.Station.Sdk;

/// <summary>Owned Table mutation callers over shared Zig validation and recovery.</summary>
public static class Mutations
{
    private static ulong Positive(ulong value) => value == 0 ? throw new ArgumentException("Expected positive mutation namespace") : value;
    private static string Hex(Bytes bytes) => V.Hex(bytes.Copy());
    private static JsonNode? Field(JsonObject value, string name) => value.TryGetPropertyValue(name, out var field) ? field : throw V.Incompatible("mutation-result");
    private static Bytes Fixed(JsonNode? value, int length) {
        Bytes result = new(V.Unhex(value, length));
        if (result.Length != length) throw V.Incompatible("mutation-byte-width");
        return result;
    }
    private static string Name<T>(T value) where T : struct, Enum {
        if (!Enum.IsDefined(value)) throw new ArgumentException("Invalid mutation variant");
        return string.Concat(value.ToString().Select((c, i) => (i > 0 && char.IsUpper(c) ? "_" : "") + char.ToLowerInvariant(c)));
    }
    private static T Variant<T>(JsonNode? value) where T : struct, Enum {
        string name = V.String(value);
        foreach (T item in Enum.GetValues<T>()) if (Name(item) == name) return item;
        throw V.Incompatible("mutation-variant");
    }
    public sealed record Connection {
        public ProcessRef Writer { get; }
        public ResourceRef Resource { get; }
        public uint Table { get; }
        public Connection(ProcessRef writer, ResourceRef resource, uint table) {
            ArgumentNullException.ThrowIfNull(writer); ArgumentNullException.ThrowIfNull(resource);
            if (writer.Realm != resource.Realm || table == 0) throw new ArgumentException("Invalid mutation connection");
            Writer = writer; Resource = resource; Table = table;
        }
        internal JsonObject Wire(Credential identity) {
            if (identity.Realm != Writer.Realm) throw new ArgumentException("Different credential realm");
            return V.Obj(("realm", Writer.Realm), ("principal", identity.Principal), ("writer", Writer.Pid), ("resource", Resource.Resource), ("table", Table));
        }
    }
    public sealed record Reference {
        public Bytes Bytes { get; }
        public Reference(Bytes bytes) { ArgumentNullException.ThrowIfNull(bytes); if (bytes.Length != 72) throw new ArgumentException("Expected complete mutation reference"); Bytes = bytes; }
    }
    public sealed record Compiled {
        public Bytes Request { get; }
        public Reference Reference { get; }
        public Compiled(Bytes request, Reference reference) {
            ArgumentNullException.ThrowIfNull(request); ArgumentNullException.ThrowIfNull(reference);
            if (request.Length == 0 || request.Length > 799) throw new ArgumentException("Invalid canonical mutation length");
            Request = request; Reference = reference;
        }
    }
    /// <summary>Persist unchanged before submit, including across cancellation.</summary>
    public sealed record Prepared {
        public Bytes Bytes { get; }
        public Prepared(Bytes bytes) {
            ArgumentNullException.ThrowIfNull(bytes);
            if (bytes.Length == 0 || bytes.Length > 8192) throw new ArgumentException("Invalid saved mutation length");
            _ = V.Utf8.GetString(bytes.Copy()); Bytes = bytes;
        }
    }
    public enum Type { Int64, Boolean, Utf8, Binary }
    [Flags] public enum Permissions : byte { None = 0, Insert = 1, Update = 2, Delete = 4 }
    public enum Phase { Uploading, Sealed, Applied, Rejected, Cancelled }
    public enum Reason { None, RowExists, SourceChanged, InvalidRequest, Denied, Budget }
    public enum Observation { Pending, Processed }
    public enum Rejection { InvalidCommand, Denied, IdentityConflict, Busy, NotFound, NotActive, UploadClosed, NotSealed, InvalidPart, IncompleteUpload, SourceChanged, StalePolicy }
    public enum Control { Apply, Cancel }
    public sealed record Description(ResourceRef Resource, uint Table, IReadOnlyList<string> Names, Type ValueType, ulong ResourceRevision, ulong PolicyRevision, Bytes Declaration, Permissions Permissions, ulong? Active);
    public sealed record Status(Reference Reference, ulong Principal, uint Table, Bytes Declaration, ulong PolicyRevision, Phase Phase, byte AffectedRows, Reason Reason, ulong Input);
    private static Prepared? ParsePrepared(JsonNode? value) => value is null ? null : new(new Bytes(V.Utf8.GetBytes(V.String(value))));

    /// <summary>One bounded operation. Dispose joins after local wait cancellation.</summary>
    public sealed class Client : IAsyncDisposable {
        private readonly Worker<StationBridge, object?> worker;
        public Connection Connection { get; }
        private Client(Worker<StationBridge, object?> worker, Connection connection) { this.worker = worker; Connection = connection; }
        public static async Task<Client> OpenAsync(ClientConfig config, Credential identity, Connection connection) {
            connection.Wire(identity);
            return new(await Worker<StationBridge, object?>.OpenAsync(() => StationBridge.OpenMutation(config, identity, connection), StationApi.MinimumStackBytes).ConfigureAwait(false), connection);
        }
        public Task<Description> DescribeAsync(CancellationToken cancellation = default) {
            return worker.Invoke(b => {
                var v = V.Object(b.TableMutation(V.Obj(("describe", V.Obj())))["description"]);
                if (V.Number(v["resource"], 1) != Connection.Resource.Resource || V.Number(v["table"], 1) != Connection.Table) throw V.Incompatible("mutation-target");
                if (v["names"] is not JsonArray { Count: 2 } names) throw V.Incompatible("mutation-columns");
                var ownedNames = System.Array.AsReadOnly(names.Select(n => V.Text(V.String(n), 16)).ToArray());
                ulong bits = V.Number(v["permissions"]); if (bits > 7) throw V.Incompatible("mutation-permissions");
                return new Description(Connection.Resource, Connection.Table, ownedNames, Variant<Type>(v["value_type"]), V.Number(v["resource_revision"]), V.Counter(NativeValues.Wide(v["policy_revision"], true)), Fixed(v["declaration"], 32), (Permissions)bits, v["active"] is null ? null : NativeValues.Wide(v["active"], true));
            }, cancellation);
        }
        public Task<Compiled> CompileSqlAsync(string name, string sql, ulong namespaceId, CancellationToken cancellation = default) {
            var action = V.Obj(("compile", V.Obj(("name", V.Text(name, 16)), ("sql", V.Text(sql, 4096)), ("namespace", Turn.Decimal(Positive(namespaceId))))));
            return worker.Invoke(b => { var v = V.Object(b.TableMutation(action)["compiled"]); return new Compiled(new Bytes(V.Unhex(v["request"], 799)), new Reference(Fixed(v["reference"], 72))); }, cancellation);
        }
        public Task<Prepared?> PrepareNextAsync(Compiled compiled, CancellationToken cancellation = default) {
            var action = V.Obj(("next", V.Obj(("request", Hex(compiled.Request)), ("reference", Hex(compiled.Reference.Bytes)))));
            return worker.Invoke(b => ParsePrepared(Field(b.TableMutation(action), "prepared")), cancellation);
        }
        public Task<Prepared> PrepareControlAsync(Control control, Reference reference, CancellationToken cancellation = default) {
            var action = V.Obj(("prepare", V.Obj((Name(control), Hex(reference.Bytes)))));
            return worker.Invoke(b => ParsePrepared(Field(b.TableMutation(action), "prepared")) ?? throw V.Incompatible("mutation-prepared"), cancellation);
        }
        public Task<AdmissionReceipt> SubmitAsync(Prepared prepared, CancellationToken cancellation = default) {
            var action = V.Obj(("submit", V.Utf8.GetString(prepared.Bytes.Copy())));
            return worker.Invoke(b => {
                var v = b.TableMutation(action);
                try { return new AdmissionReceipt(V.Number(V.Object(v["receipt"])["position"], 1)); }
                catch (Exception) { throw new TransitException(ErrorKind.UnknownOutcome, "mutation-receipt", 6); }
            }, cancellation);
        }
        public Task<Observation> ObserveAsync(Prepared prepared, ulong input, CancellationToken cancellation = default) {
            var action = V.Obj(("observe", V.Obj(("prepared", V.Utf8.GetString(prepared.Bytes.Copy())), ("input", V.Counter(input)))));
            return worker.Invoke(b => Variant<Observation>(b.TableMutation(action)["observation"]), cancellation);
        }
        public Task<Rejection?> RejectionAsync(Prepared prepared, ulong input, CancellationToken cancellation = default) {
            var action = V.Obj(("rejection", V.Obj(("prepared", V.Utf8.GetString(prepared.Bytes.Copy())), ("input", V.Counter(input)))));
            return worker.Invoke(b => Field(b.TableMutation(action), "rejection") is {} v ? (Rejection?)Variant<Rejection>(v) : null, cancellation);
        }
        public Task<Status?> StatusAsync(Reference reference, CancellationToken cancellation = default) {
            var action = V.Obj(("status", Hex(reference.Bytes)));
            return worker.Invoke(b => {
                var result = Field(b.TableMutation(action), "status"); if (result is null) return null; var v = V.Object(result);
                Reference actual = new(Fixed(v["reference"], 72));
                if (actual != reference || V.Number(v["table"], 1) != Connection.Table) throw V.Incompatible("mutation-status-target");
                ulong affected = V.Number(v["affected_rows"]); if (affected > 3) throw V.Incompatible("mutation-row-count");
                return new Status(actual, V.Number(v["principal"], 1), Connection.Table, Fixed(v["declaration"], 32), V.Counter(NativeValues.Wide(v["policy_revision"], true)), Variant<Phase>(v["phase"]), (byte)affected, Variant<Reason>(v["reason"]), V.Number(v["input"]));
            }, cancellation);
        }
        public async ValueTask DisposeAsync() { try { await worker.CloseAsync().ConfigureAwait(false); } finally { worker.CloseSnapshot(); } }
    }
}
