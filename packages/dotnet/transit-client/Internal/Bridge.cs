using System.Globalization;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text.Json.Nodes;

namespace Transit.Client.Internal;

internal sealed class Bridge : IDisposable
{
    private readonly NativePackage package;
    internal readonly NativeApi Api;
    private IntPtr client;
    internal Bridge(ClientConfig config)
    {
        package = new NativePackage("client", config.NativeDirectory);
        try {
            Api = new NativeApi(package.Library);
            if (Api.transit_client_abi_version() != NativeApi.Version || Api.transit_client_supports_kind(6) != 1 || Api.transit_client_supports_kind(7) != 1)
                throw Value.Incompatible("native-client-version");
            byte[] endpoint = Value.Utf8.GetBytes(config.NativeEndpoint);
            uint status = Api.transit_client_create(NativeApi.Version, endpoint, (nuint)endpoint.Length, config.TimeoutMillis, out client);
            if (status != 0) throw Value.NativeError(status, null, "client-create");
        } catch (Exception error) {
            if (client != IntPtr.Zero) Api?.transit_client_destroy(client);
            package.Dispose();
            if (error is EntryPointNotFoundException or MarshalDirectiveException) throw Value.Incompatible("native-exports");
            throw;
        }
    }
    internal byte[] Buffer(uint status, IntPtr pointer, string phase)
    {
        byte[] bytes;
        try {
            nuint size = pointer == IntPtr.Zero ? 0 : Api.transit_buffer_size(pointer);
            if (size > (nuint)Value.MaxLine) throw Value.Incompatible("native-buffer-bound");
            bytes = new byte[(int)size];
            if (size > 0) Marshal.Copy(Api.transit_buffer_data(pointer), bytes, 0, bytes.Length);
        } finally { Api.transit_buffer_destroy(pointer); }
        if (status != 0) {
            JsonNode? detail = null;
            if (bytes.Length != 0) {
                try { detail = Value.Parse(bytes); } catch (TransitException) { }
            }
            throw Value.NativeError(status, detail, phase);
        }
        return bytes;
    }
    private IntPtr Import(byte[] bytes)
    {
        uint status = Api.transit_operation_import(bytes, (nuint)bytes.Length, out var operation);
        if (status != 0) { Api.transit_operation_destroy(operation); throw Value.NativeError(status, null, "operation-import"); }
        return operation;
    }
    internal byte[] Prepare(uint kind, Credential credential, JsonObject document)
    {
        byte[] json = Value.Json(document), key = Seed(credential.SeedFile);
        IntPtr operation = IntPtr.Zero;
        try {
            uint status = Api.transit_operation_prepare(kind, key, json, (nuint)json.Length, out operation);
            if (status != 0) throw Value.NativeError(status, null, "prepare");
            status = Api.transit_operation_export(operation, out var buffer);
            return Buffer(status, buffer, "operation-export");
        } finally { Api.transit_operation_destroy(operation); CryptographicOperations.ZeroMemory(key); }
    }
    internal static byte[] Seed(string path)
    {
        byte[] encoded = new byte[130];
        Span<char> characters = stackalloc char[64];
        try {
            using FileStream input = File.OpenRead(path);
            int length = 0;
            while (length < encoded.Length) {
                int read = input.Read(encoded, length, encoded.Length - length);
                if (read == 0) break;
                length += read;
            }
            int first = 0, last = length;
            while (first < last && encoded[first] is 9 or 10 or 13 or 32) first++;
            while (last > first && encoded[last - 1] is 9 or 10 or 13 or 32) last--;
            if (length == encoded.Length || last - first != 64) throw new ArgumentException("Expected a bounded 32-byte hex seed file");
            for (int index = 0; index < 64; index++) {
                byte value = encoded[first + index];
                if (value is not (>= 48 and <= 57) and not (>= 65 and <= 70) and not (>= 97 and <= 102)) throw new ArgumentException("Malformed signing seed");
                characters[index] = (char)value;
            }
            return Convert.FromHexString(characters);
        } catch (Exception error) when (error is IOException or UnauthorizedAccessException) {
            throw new TransitException(ErrorKind.ReadFailed, "credential");
        } finally { CryptographicOperations.ZeroMemory(encoded); characters.Clear(); }
    }
    internal JsonObject Metadata(byte[] bytes, bool sendOnly)
    {
        IntPtr operation = Import(bytes);
        try {
            uint status = Api.transit_operation_metadata(operation, out var buffer);
            JsonObject value = Value.Object(Value.Parse(Buffer(status, buffer, "operation-metadata")));
            Schema.Require(Value.Object(Value.Object(Value.Contract["schemas"])["OperationMetadata"]), value);
            if (Value.Number(value["version"], 1) != 1) throw Value.Incompatible("operation-metadata-version");
            if (Value.String(value["profile"]) != "growing_v3" || Value.String(value["kind"]) != "growing_command" || value["command"] is null ||
                (sendOnly && Value.String(value["command"]) != "send")) throw new TransitException(ErrorKind.UnsupportedCapability, "recovery-kind");
            return value;
        } finally { Api.transit_operation_destroy(operation); }
    }
    private static ulong Sequence(JsonNode? value)
    {
        string text = Value.String(value);
        if (!ulong.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out var sequence) || text != sequence.ToString(CultureInfo.InvariantCulture)) throw Value.Incompatible("native-sequence");
        return Value.Counter(sequence);
    }
    internal PendingSend RecoverSend(byte[] bytes)
    {
        JsonObject value = Metadata(bytes, true);
        return new PendingSend(new(new OperationIdentity(Value.String(value["identity"])),
            new ProcessRef(Value.Number(value["realm"], 1), Value.Number(value["destination"], 1)), Value.Number(value["principal"]), Sequence(value["sequence"])), bytes);
    }
    internal PendingMutation RecoverMutation(byte[] bytes)
    {
        JsonObject value = Metadata(bytes, false);
        return new PendingMutation(new(new OperationIdentity(Value.String(value["identity"])), Value.Number(value["realm"], 1),
            Value.Number(value["principal"]), Sequence(value["sequence"]), Value.String(value["command"])), bytes);
    }
    internal JsonObject Call(byte[] bytes, bool mutation)
    {
        IntPtr operation = Import(bytes);
        try {
            uint status = Api.transit_client_call(client, operation, out var buffer);
            try { return Value.Object(Value.Parse(Buffer(status, buffer, "dispatch"))); }
            catch (TransitException error) when (mutation && !error.Rejected && error.Kind != ErrorKind.UnknownOutcome) {
                throw new TransitException(ErrorKind.UnknownOutcome, "receipt", 6);
            } catch (Exception error) when (mutation && error is not TransitException) { throw new TransitException(ErrorKind.UnknownOutcome, "receipt", 6); }
        } finally { Api.transit_operation_destroy(operation); }
    }
    internal Capabilities Capabilities(Credential credential)
    {
        byte[] frozen = Prepare(7, credential, Value.Obj(("realm", credential.Realm), ("principal", credential.Principal), ("kind", Value.Obj(("capabilities", Value.Obj())))));
        JsonObject value = Call(frozen, false), caps = Value.Object(Value.Object(value["body"])["capabilities"]);
        if (Value.Number(value["version"], 1) != 3 || Value.Number(caps["version"], 1) != 3 || Value.String(caps["profile"]) != "growing_v1")
            throw new TransitException(ErrorKind.UnsupportedCapability, "authority-capabilities");
        return new Capabilities(Value.Number(value["realm"], 1), Value.Number(value["position"]), Value.Number(value["principal_sequence"]),
            checked((uint)Value.Number(caps["page_entries"], 1)), checked((uint)Value.Number(caps["mutation_budget"], 1)), checked((uint)Value.Number(caps["output_budget"], 1)),
            Value.Boolean(caps["retained_read_versions"]), Value.Boolean(caps["association_lookup"]), Value.Boolean(caps["scoped_retry"]), Value.Boolean(caps["station"]));
    }
    public void Dispose()
    {
        if (client != IntPtr.Zero) { Api.transit_client_destroy(client); client = IntPtr.Zero; }
        package.Dispose();
    }
}
