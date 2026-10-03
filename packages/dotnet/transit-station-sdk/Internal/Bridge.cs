using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using RawBridge = Transit.Client.Internal.Bridge;

namespace Transit.Station.Sdk.Internal;

internal sealed class Bridge : IWorkerState<object?>
{
    private static readonly JsonObject Schemas = Value.Object(Value.ReadContract(typeof(Bridge).Assembly, "transit.station.contract.json")["schemas"]);
    private readonly NativePackage package;
    internal readonly NativeApi Api;
    internal readonly JsonObject Caps;
    private RawBridge? raw;
    private IntPtr server;
    private IntPtr queryClient;
    private IntPtr mutationClient;
    private IntPtr catalogClient;
    internal Bridge(string? nativeDirectory)
    {
        if (typeof(Transit.Client.Client).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion != "0.2.0") throw Value.Incompatible("client-sdk-version");
        package = new NativePackage("station", nativeDirectory);
        try {
            Api = new NativeApi(package.Library);
            if (Api.station_abi_definition_matches(Value.Utf8.GetBytes(NativeApi.Definition), (nuint)NativeApi.Definition.Length) != 1 || Api.station_abi_version() != NativeApi.Version) throw Value.Incompatible("station-version");
            uint status = Api.station_growing_capabilities(out var buffer);
            Caps = Result(status, buffer, "native-capabilities", schema: "GrowingCapabilities");
            if (Value.Number(Caps["version"], 1) != 1 || Value.String(Caps["profile"]) != "native_v1") throw Value.Incompatible("station-profile");
            foreach (string name in new[] { "gated_dispatch", "retained_confirmation", "scoped_turns", "paged_state", "tables", "retained_sources" }) {
                if (!Value.Boolean(Caps[name])) throw new TransitException(ErrorKind.UnsupportedCapability, "native-capabilities");
            }
        } catch (Exception error) {
            package.Dispose();
            if (error is EntryPointNotFoundException or MarshalDirectiveException) throw Value.Incompatible("native-exports");
            throw;
        }
    }
    internal static Bridge Open(ServiceConfig config, FailurePolicy failure)
    {
        if (failure is not (FailurePolicy.Stop or FailurePolicy.BlockInput)) throw new ArgumentException("Select a handler failure policy");
        Bridge bridge = new(config.Client.NativeDirectory);
        try {
            if (config.QueryResults && !Value.Boolean(bridge.Caps["query_results"])) throw new TransitException(ErrorKind.UnsupportedCapability, "query-results");
            bridge.raw = new RawBridge(config.Client);
            var authority = bridge.raw.Capabilities(config.Activation.Credential);
            if (!authority.AssociationLookup || !authority.ScopedRetry || !authority.RetainedVersions) throw new TransitException(ErrorKind.UnsupportedCapability, "authority-capabilities");
            var activation = config.Activation;
            byte[] endpoint = Value.Utf8.GetBytes(config.Client.NativeEndpoint);
            byte[] document = Value.Json(Value.Obj(("profile", "native_v1"), ("realm", activation.Process.Realm), ("principal", activation.Credential.Principal),
                ("pid", activation.Process.Pid), ("generation", activation.Generation), ("association", config.Association), ("timeout_ms", config.Client.TimeoutMillis),
                ("failure_policy", failure == FailurePolicy.Stop ? "stop" : "block_input"), ("query_results", config.QueryResults)));
            byte[] seed = RawBridge.Seed(activation.Credential.SeedFile);
            try {
                uint status = bridge.Api.station_growing_create(NativeApi.Version, endpoint, (nuint)endpoint.Length, seed, document, (nuint)document.Length, out bridge.server);
                if (status != 0) throw Value.NativeError(status, null, "runner-create");
                if (bridge.server == IntPtr.Zero) throw Value.Incompatible("runner-create");
            } finally { CryptographicOperations.ZeroMemory(seed); }
            return bridge;
        } catch (Exception) { bridge.Dispose(); throw; }
    }
    internal int Limit(string name) => checked((int)Value.Number(Caps[name], 1));
    internal static Bridge OpenQuery(ClientConfig config, Credential identity, UnifiedQuery.Connection connection)
    {
        Bridge bridge = new(config.NativeDirectory);
        try {
            byte[] endpoint = Value.Utf8.GetBytes(config.NativeEndpoint);
            byte[] document = Value.Json(Value.Obj(("connection", connection.Wire(identity)), ("timeout_ms", config.TimeoutMillis)));
            byte[] seed = RawBridge.Seed(identity.SeedFile);
            try {
                uint status = bridge.Api.station_unified_query_create(NativeApi.Version, endpoint, (nuint)endpoint.Length, seed, document, (nuint)document.Length, out bridge.queryClient);
                if (status != 0) throw Value.NativeError(status, null, "query-create");
                if (bridge.queryClient == IntPtr.Zero) throw Value.Incompatible("query-create");
            } finally { CryptographicOperations.ZeroMemory(seed); }
            var caps = Value.Object(bridge.UnifiedQuery(Value.Obj(("capabilities", Value.Obj())))["capabilities"]);
            if (Value.Number(caps["version"], 1) != 1) throw Value.Incompatible("query-version");
            foreach (string kind in new[] { "kv", "table", "document" }) if (!Value.Boolean(caps[kind])) throw Value.Incompatible("query-source");
            return bridge;
        } catch (Exception) { bridge.Dispose(); throw; }
    }
    internal JsonObject UnifiedCodec(JsonObject action)
    {
        HttpCapability("unified_query_codecs");
        Schema.Require(Value.Object(Schemas["UnifiedQueryCodecAction"]), action);
        byte[] bytes = Value.Json(action);
        if (bytes.Length > Value.MaxBody) throw new ArgumentException("Query codec action exceeds its bound");
        uint status = Api.station_unified_query_codec(bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "query-codec", schema: "UnifiedQueryCodecResult");
    }
    internal static Bridge OpenMutation(ClientConfig config, Credential identity, Mutations.Connection connection)
    {
        Bridge bridge = new(config.NativeDirectory);
        try {
            byte[] endpoint = Value.Utf8.GetBytes(config.NativeEndpoint);
            byte[] document = Value.Json(Value.Obj(("connection", connection.Wire(identity)), ("timeout_ms", config.TimeoutMillis)));
            byte[] seed = RawBridge.Seed(identity.SeedFile);
            try {
                uint status = bridge.Api.station_table_mutation_create(NativeApi.Version, endpoint, (nuint)endpoint.Length, seed, document, (nuint)document.Length, out bridge.mutationClient);
                if (status != 0) throw Value.NativeError(status, null, "mutation-create");
                if (bridge.mutationClient == IntPtr.Zero) throw Value.Incompatible("mutation-create");
            } finally { CryptographicOperations.ZeroMemory(seed); }
            var caps = Value.Object(bridge.TableMutation(Value.Obj(("capabilities", Value.Obj())))["capabilities"]);
            if (Value.Number(caps["version"], 1) != 1 || Value.Number(caps["max_rows"], 1) != 3 || Value.Number(caps["max_request_bytes"], 1) != 799 || Value.Number(caps["max_saved_bytes"], 1) != 8192) throw Value.Incompatible("mutation-capabilities");
            foreach (string operation in new[] { "insert", "update_primary_key", "delete_primary_key" }) if (!Value.Boolean(caps[operation])) throw Value.Incompatible("mutation-capabilities");
            return bridge;
        } catch (Exception) { bridge.Dispose(); throw; }
    }
    internal JsonObject TableMutation(JsonObject action)
    {
        Schema.Require(Value.Object(Schemas["TableMutationAction"]), action);
        byte[] bytes = Value.Json(action);
        if (bytes.Length > Value.MaxBody) throw new ArgumentException("Mutation action exceeds its bound");
        uint status = Api.station_table_mutation_call(mutationClient, bytes, (nuint)bytes.Length, out var buffer);
        // Preserve uncertainty if copying/validating an admitted or already
        // uncertain response fails; explicit preflight rejections stay distinct.
        return Result(status, buffer, "table-mutation", action.ContainsKey("submit") && (status is 0 or 6), "TableMutationResult");
    }
    internal static Bridge OpenCatalog(ClientConfig config, Credential identity, Catalog.Connection connection)
    {
        Bridge bridge = new(config.NativeDirectory);
        try {
            byte[] endpoint = Value.Utf8.GetBytes(config.NativeEndpoint);
            byte[] document = Value.Json(Value.Obj(("connection", connection.Wire(identity)), ("timeout_ms", config.TimeoutMillis)));
            byte[] seed = RawBridge.Seed(identity.SeedFile);
            try {
                uint status = bridge.Api.station_catalog_create(NativeApi.Version, endpoint, (nuint)endpoint.Length, seed, document, (nuint)document.Length, out bridge.catalogClient);
                if (status != 0) throw Value.NativeError(status, null, "catalog-create");
                if (bridge.catalogClient == IntPtr.Zero) throw Value.Incompatible("catalog-create");
            } finally { CryptographicOperations.ZeroMemory(seed); }
            var caps = Sdk.Catalog.ParseCapabilities(bridge.Catalog(Value.Obj(("capabilities", Value.Obj())))["capabilities"]);
            if (!caps.Initialize || !caps.CreateTable || !caps.ConditionalPolicy || !caps.CurrentMetadata) throw new TransitException(ErrorKind.UnsupportedCapability, "catalog-capabilities");
            return bridge;
        } catch (Exception) { bridge.Dispose(); throw; }
    }
    internal JsonObject Catalog(JsonObject action)
    {
        Schema.Require(Value.Object(Schemas["CatalogAction"]), action);
        byte[] bytes = Value.Json(action);
        if (bytes.Length > Value.MaxBody) throw new ArgumentException("Catalog action exceeds its bound");
        uint status = Api.station_catalog_call(catalogClient, bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "catalog", action.ContainsKey("submit") && (status is 0 or 6), "CatalogResult");
    }
    internal JsonObject UnifiedQuery(JsonObject action, bool mutation = false)
    {
        Schema.Require(Value.Object(Schemas["UnifiedQueryAction"]), action);
        byte[] bytes = Value.Json(action);
        if (bytes.Length > Value.MaxBody) throw new ArgumentException("Query action exceeds its bound");
        uint status = Api.station_unified_query_call(queryClient, bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "query", mutation && status == 0, "UnifiedQueryResult");
    }
    internal void HttpCapability(string name)
    {
        if (!Value.Boolean(Caps[name])) throw new TransitException(ErrorKind.UnsupportedCapability, name);
    }
    internal JsonObject HttpCodec(JsonObject action)
    {
        HttpCapability("http_requests"); byte[] bytes = Value.Json(action);
        if (bytes.Length > Value.MaxBody) throw new ArgumentException("HTTP action exceeds its bound");
        uint status = Api.station_http_codec(bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "http-codec", schema: "HttpCodecResult");
    }
    internal JsonObject HttpRead(JsonObject action)
    {
        HttpCapability("http_replay"); byte[] bytes = Value.Json(action);
        if (bytes.Length > 2048) throw new ArgumentException("HTTP replay action exceeds its bound");
        uint status = Api.station_growing_http_read(server, bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "http-replay", schema: "HttpReadResult");
    }
    internal void GrpcCapability(string name)
    {
        if (!Value.Boolean(Caps[name])) throw new TransitException(ErrorKind.UnsupportedCapability, name);
    }
    internal JsonObject GrpcCodec(JsonObject action)
    {
        GrpcCapability("grpc_requests"); byte[] bytes = Value.Json(action);
        if (bytes.Length > Value.MaxBody) throw new ArgumentException("RPC action exceeds its bound");
        uint status = Api.station_grpc_codec(bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "grpc-codec", schema: "GrpcCodecResult");
    }
    internal JsonObject GrpcRead(JsonObject action)
    {
        GrpcCapability("grpc_replay"); byte[] bytes = Value.Json(action);
        if (bytes.Length > 2048) throw new ArgumentException("RPC replay action exceeds its bound");
        uint status = Api.station_growing_grpc_read(server, bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "grpc-replay", schema: "GrpcReadResult");
    }
    internal JsonObject DocumentCodec(JsonObject action)
    {
        HttpCapability("document_codecs"); byte[] bytes = Value.Json(action);
        if (bytes.Length > 32768) throw new ArgumentException("Document codec action exceeds its bound");
        uint status = Api.station_document_codec(bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "document-codec", schema: "DocumentCodecResult");
    }
    internal JsonObject DocumentRead(JsonObject action)
    {
        HttpCapability("document_reads"); byte[] bytes = Value.Json(action);
        if (bytes.Length > 4096) throw new ArgumentException("Document read action exceeds its bound");
        uint status = Api.station_growing_document_read(server, bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "document-read", schema: "DocumentReadResult");
    }
    internal byte[] Buffer(uint status, IntPtr pointer, string phase)
    {
        byte[] bytes;
        try {
            nuint size = pointer == IntPtr.Zero ? 0 : Api.station_buffer_size(pointer);
            if (size > (nuint)Value.MaxLine) throw Value.Incompatible("native-buffer-bound");
            bytes = new byte[(int)size];
            if (size > 0) Marshal.Copy(Api.station_buffer_data(pointer), bytes, 0, bytes.Length);
        } finally { Api.station_buffer_destroy(pointer); }
        if (status != 0) {
            JsonNode? detail = null;
            if (bytes.Length != 0) { try { detail = Value.Parse(bytes); } catch (TransitException) { } }
            throw Value.NativeError(status, detail, phase, payload => Api.station_diagnostic_validate(payload, (nuint)payload.Length) == 1);
        }
        return bytes;
    }
    private JsonObject Result(uint status, IntPtr pointer, string phase, bool mutation = false, string? schema = null)
    {
        try {
            JsonObject value = Value.Object(Value.Parse(Buffer(status, pointer, phase)));
            if (schema is not null) Schema.Require(Value.Object(Schemas[schema]), value);
            return value;
        }
        catch (TransitException error) when (mutation && !error.Rejected && error.Kind != ErrorKind.UnknownOutcome) {
            throw new TransitException(ErrorKind.UnknownOutcome, "receipt", 6);
        } catch (Exception error) when (mutation && error is not TransitException) { throw new TransitException(ErrorKind.UnknownOutcome, "receipt", 6); }
    }
    internal JsonObject Prepare()
    {
        ulong deadline = checked((ulong)DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() + 30000);
        uint status = Api.station_growing_prepare(server, deadline, out var buffer);
        return Result(status, buffer, "prepare-turn", schema: "GrowingEvent");
    }
    internal JsonObject Apply(ulong scope, JsonObject action)
    {
        byte[] bytes = Value.Json(action);
        if (bytes.Length > Value.MaxBody) throw new ArgumentException("Action exceeds its bound");
        uint status = Api.station_growing_apply(server, scope, bytes, (nuint)bytes.Length, out var buffer);
        return Result(status, buffer, "apply", schema: "GrowingResult");
    }
    internal void Finish(ulong scope, bool failed)
    {
        uint status = Api.station_growing_finish_result(server, scope, failed ? 1u : 0u, out var buffer);
        Buffer(status, buffer, "finish");
    }
    internal void Discard(ulong scope)
    {
        uint status = Api.station_growing_discard(server, scope);
        if (status != 0) throw Value.NativeError(status, null, "discard");
    }
    internal JsonObject Dispatch()
    {
        uint status = Api.station_growing_dispatch(server, out var buffer);
        return Result(status, buffer, "dispatch", true, "GrowingEvent");
    }
    internal FrozenMutation Pending(JsonObject value)
    {
        Purpose purpose = Value.String(value["pending_kind"]) switch { "permit" => Purpose.Permit, "open" => Purpose.Open, "commit" => Purpose.Commit, _ => throw Value.Incompatible("pending-purpose") };
        uint status = Api.station_growing_pending(server, out var buffer);
        byte[] bytes = Buffer(status, buffer, "pending");
        using var pending = raw!.RecoverMutation(bytes);
        bool matches = purpose switch { Purpose.Permit => pending.Info.Command == "begin_turn", Purpose.Open => pending.Info.Command == "open_view", _ => pending.Info.Command is "turn" or "turn_with_versions" };
        if (!matches) throw Value.Incompatible("pending-command");
        return new(pending.Info.Identity, purpose, Value.Number(value["pending_input"], 1), new Bytes(bytes));
    }
    internal static bool Matches(JsonObject value, FrozenMutation pending) => Value.String(value["kind"]) == pending.Purpose.ToString().ToLowerInvariant() && Value.Number(value["input"], 1) == pending.InputPosition;
    internal JsonObject? Confirmation(FrozenMutation pending)
    {
        try {
            uint status = Api.station_growing_confirmation(server, out var buffer);
            JsonObject result = Result(status, buffer, "observe-confirmation", schema: "GrowingEvent");
            return result["confirmation"] is JsonObject value && Matches(value, pending) ? result : null;
        } catch (TransitException error) when (error.Kind == ErrorKind.TurnExpired) { return null; }
    }
    public object? Evidence() => null;
    public void Dispose()
    {
        if (catalogClient != IntPtr.Zero) { Api.station_catalog_destroy(catalogClient); catalogClient = IntPtr.Zero; }
        if (mutationClient != IntPtr.Zero) { Api.station_table_mutation_destroy(mutationClient); mutationClient = IntPtr.Zero; }
        if (queryClient != IntPtr.Zero) { Api.station_unified_query_destroy(queryClient); queryClient = IntPtr.Zero; }
        try { if (server != IntPtr.Zero) { Api.station_growing_destroy(server); server = IntPtr.Zero; } }
        finally { try { raw?.Dispose(); } finally { package.Dispose(); } }
    }
}
